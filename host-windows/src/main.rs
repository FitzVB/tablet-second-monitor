mod capture;

use std::collections::HashMap;
use std::sync::Arc;

use futures::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::io::AsyncReadExt;
use tokio::process::Command;
use tokio::sync::{mpsc, RwLock};
use tracing::{error, info};
use uuid::Uuid;
use warp::ws::{Message, WebSocket};
use warp::Filter;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum SignalMessage {
    Join { room: String, role: String },
    Offer { room: String, sdp: String },
    Answer { room: String, sdp: String },
    IceCandidate { room: String, candidate: String },
    PeerJoined { peer_id: String, role: String },
    PeerLeft { peer_id: String },
    Error { message: String },
}

#[derive(Clone)]
struct Peer {
    id: String,
    tx: mpsc::UnboundedSender<Message>,
}

type Rooms = Arc<RwLock<HashMap<String, Vec<Peer>>>>;

#[derive(Clone, Copy)]
struct StreamConfig {
    jpeg_quality: u8,
    scale: u32,
    fps: u32,
}

#[derive(Clone, Debug, Deserialize, Default)]
struct StreamQuery {
    w: Option<u32>,
    h: Option<u32>,
    fps: Option<u32>,
    q: Option<u8>,
    fit: Option<String>,
    bitrate_kbps: Option<u32>,
    encoder: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .with_target(false)
        .init();

    let rooms: Rooms = Arc::new(RwLock::new(HashMap::new()));
    let rooms_filter = warp::any().map(move || rooms.clone());

    let health = warp::path("health").map(|| "ok");

    let ws_route = warp::path("ws")
        .and(warp::ws())
        .and(rooms_filter)
        .map(|ws: warp::ws::Ws, rooms| ws.on_upgrade(move |socket| handle_socket(socket, rooms)));

    let stream_config = StreamConfig {
        jpeg_quality: env_or("TABLET_MONITOR_JPEG_QUALITY", 58u8).clamp(15, 90),
        scale: env_or("TABLET_MONITOR_SCALE", 2u32).max(1),
        fps: env_or("TABLET_MONITOR_FPS", 18u32).clamp(5, 60),
    };
    let stream_cfg_filter = warp::any().map(move || stream_config);
    let stream_query_filter = warp::query::<StreamQuery>()
        .or(warp::any().map(StreamQuery::default))
        .unify();

    let stream_route = warp::path("stream")
        .and(warp::ws())
        .and(stream_query_filter.clone())
        .and(stream_cfg_filter)
        .map(|ws: warp::ws::Ws, query: StreamQuery, cfg: StreamConfig| {
            ws.on_upgrade(move |socket| handle_stream(socket, cfg, query))
        });

    let h264_route = warp::path("h264")
        .and(warp::ws())
        .and(stream_query_filter)
        .map(|ws: warp::ws::Ws, query: StreamQuery| {
            ws.on_upgrade(move |socket| handle_h264_stream(socket, query))
        });

    let listen_host = std::env::var("TABLET_MONITOR_LISTEN").unwrap_or_else(|_| "127.0.0.1".to_string());
    let listen_ip: std::net::Ipv4Addr = listen_host
        .parse()
        .unwrap_or(std::net::Ipv4Addr::LOCALHOST);

    info!(%listen_ip, "signaling server listening on {}:9001", listen_ip);
    warp::serve(health.or(ws_route).or(stream_route).or(h264_route))
        .run((listen_ip.octets(), 9001))
        .await;

    Ok(())
}

async fn handle_socket(socket: WebSocket, rooms: Rooms) {
    let peer_id = Uuid::new_v4().to_string();
    let (mut ws_tx, mut ws_rx) = socket.split();

    let (tx, mut rx) = mpsc::unbounded_channel::<Message>();
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if ws_tx.send(msg).await.is_err() {
                break;
            }
        }
    });

    let mut joined_room: Option<String> = None;
    let mut my_role = String::from("unknown");

    while let Some(result) = ws_rx.next().await {
        match result {
            Ok(msg) if msg.is_text() => {
                let text = match msg.to_str() {
                    Ok(t) => t,
                    Err(_) => continue,
                };

                let parsed: Result<SignalMessage, _> = serde_json::from_str(text);
                let signal = match parsed {
                    Ok(s) => s,
                    Err(e) => {
                        let _ = tx.send(Message::text(
                            serde_json::to_string(&SignalMessage::Error {
                                message: format!("invalid json: {e}"),
                            })
                            .unwrap_or_else(|_| "{\"type\":\"error\",\"message\":\"parse\"}".into()),
                        ));
                        continue;
                    }
                };

                match signal {
                    SignalMessage::Join { room, role } => {
                        my_role = role.clone();
                        joined_room = Some(room.clone());

                        {
                            let mut map = rooms.write().await;
                            let peers = map.entry(room.clone()).or_default();

                            peers.push(Peer {
                                id: peer_id.clone(),
                                tx: tx.clone(),
                            });
                        }

                        broadcast(
                            &rooms,
                            &room,
                            &peer_id,
                            &SignalMessage::PeerJoined {
                                peer_id: peer_id.clone(),
                                role,
                            },
                        )
                        .await;

                        info!(%peer_id, %room, "peer joined room");
                    }
                    SignalMessage::Offer { room, sdp } => {
                        let outbound = SignalMessage::Offer {
                            room: room.clone(),
                            sdp,
                        };
                        relay(
                            &rooms,
                            &room,
                            &peer_id,
                            &outbound,
                        )
                        .await;
                    }
                    SignalMessage::Answer { room, sdp } => {
                        let outbound = SignalMessage::Answer {
                            room: room.clone(),
                            sdp,
                        };
                        relay(
                            &rooms,
                            &room,
                            &peer_id,
                            &outbound,
                        )
                        .await;
                    }
                    SignalMessage::IceCandidate { room, candidate } => {
                        let outbound = SignalMessage::IceCandidate {
                            room: room.clone(),
                            candidate,
                        };
                        relay(
                            &rooms,
                            &room,
                            &peer_id,
                            &outbound,
                        )
                        .await;
                    }
                    _ => {}
                }
            }
            Ok(msg) if msg.is_close() => break,
            Ok(_) => {}
            Err(e) => {
                error!(%peer_id, "websocket error: {e}");
                break;
            }
        }
    }

    if let Some(room) = joined_room {
        let mut map = rooms.write().await;
        if let Some(peers) = map.get_mut(&room) {
            peers.retain(|p| p.id != peer_id);
        }
        drop(map);

        broadcast(
            &rooms,
            &room,
            &peer_id,
            &SignalMessage::PeerLeft {
                peer_id: peer_id.clone(),
            },
        )
        .await;

        info!(%peer_id, %room, role = %my_role, "peer left room");
    }

    send_task.abort();
}

async fn relay(rooms: &Rooms, room: &str, sender: &str, message: &SignalMessage) {
    let payload = match serde_json::to_string(message) {
        Ok(v) => v,
        Err(_) => return,
    };

    let map = rooms.read().await;
    if let Some(peers) = map.get(room) {
        for peer in peers {
            if peer.id != sender {
                let _ = peer.tx.send(Message::text(payload.clone()));
            }
        }
    }
}

fn env_or<T: std::str::FromStr>(name: &str, default: T) -> T {
    std::env::var(name)
        .ok()
        .and_then(|v| v.parse::<T>().ok())
        .unwrap_or(default)
}

async fn handle_stream(socket: warp::ws::WebSocket, cfg: StreamConfig, query: StreamQuery) {
        use std::sync::{
            atomic::{AtomicBool, Ordering},
            Arc,
        };

        let (mut ws_tx, mut ws_rx) = socket.split();
        let running = Arc::new(AtomicBool::new(true));
        let running2 = running.clone();

        // Detectar cierre de la conexión
        tokio::spawn(async move {
            while let Some(Ok(msg)) = ws_rx.next().await {
                if msg.is_close() {
                    break;
                }
            }
            running2.store(false, Ordering::Relaxed);
        });

        let (screen_w, screen_h) = capture::screen_size();
        let out_w = query.w.unwrap_or((screen_w / cfg.scale).max(1)).clamp(320, screen_w);
        let out_h = query.h.unwrap_or((screen_h / cfg.scale).max(1)).clamp(240, screen_h);
        let fps = query.fps.unwrap_or(cfg.fps).clamp(5, 60);
        let quality = query.q.unwrap_or(cfg.jpeg_quality).clamp(15, 90);
        let fit_mode = match query.fit.as_deref() {
            Some("contain") => capture::FitMode::Contain,
            _ => capture::FitMode::Cover,
        };

        info!(out_w, out_h, fps, quality, fit = ?query.fit, "stream client connected");

        let frame_ms = (1000 / fps.max(1)) as u64;
        let mut interval = tokio::time::interval(tokio::time::Duration::from_millis(frame_ms));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

        loop {
            interval.tick().await;

            if !running.load(Ordering::Relaxed) {
                break;
            }

            let frame = tokio::task::spawn_blocking(move || {
                capture::capture_jpeg_to_size(quality, out_w, out_h, fit_mode)
            })
            .await;

            match frame {
                Ok(Ok(jpeg)) => {
                    if ws_tx.send(Message::binary(jpeg)).await.is_err() {
                        break;
                    }
                }
                Ok(Err(e)) => {
                    error!("capture error: {e}");
                }
                Err(e) => {
                    error!("spawn_blocking error: {e}");
                    break;
                }
            }
        }

        info!("stream client disconnected");
    }

async fn handle_h264_stream(socket: warp::ws::WebSocket, query: StreamQuery) {
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    };

    let (mut ws_tx, mut ws_rx) = socket.split();
    let running = Arc::new(AtomicBool::new(true));
    let running2 = running.clone();

    tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_rx.next().await {
            if msg.is_close() {
                break;
            }
        }
        running2.store(false, Ordering::Relaxed);
    });

    let (screen_w, screen_h) = capture::screen_size();
    let out_w = query.w.unwrap_or(960).clamp(320, screen_w);
    let out_h = query.h.unwrap_or(540).clamp(240, screen_h);
    let fps = query.fps.unwrap_or(60).clamp(10, 60);
    let bitrate = query.bitrate_kbps.unwrap_or(3500).clamp(1000, 20000);

    let preferred = query
        .encoder
        .clone()
        .or_else(|| std::env::var("TABLET_MONITOR_HW_ENCODER").ok());

    let mut encoders = vec!["h264_nvenc", "h264_qsv", "h264_amf", "libx264"];
    if let Some(pref) = preferred.as_deref() {
        encoders.retain(|e| *e != pref);
        encoders.insert(0, pref);
    }

    info!(out_w, out_h, fps, bitrate, "h264 stream client connected");

    let mut started = false;
    for encoder in encoders {
        if !running.load(Ordering::Relaxed) {
            return;
        }

        match stream_with_ffmpeg(
            &mut ws_tx,
            &running,
            out_w,
            out_h,
            fps,
            bitrate,
            encoder,
        )
        .await
        {
            Ok(sent_any) => {
                started = sent_any;
                if started || !running.load(Ordering::Relaxed) {
                    break;
                }
            }
            Err(e) => {
                error!(encoder, "ffmpeg stream failed: {e}");
            }
        }
    }

    if !started {
        let _ = ws_tx
            .send(Message::text(
                "{\"type\":\"error\",\"message\":\"No H.264 encoder available (ffmpeg)\"}",
            ))
            .await;
    }

    info!("h264 stream client disconnected");
}

async fn stream_with_ffmpeg(
    ws_tx: &mut futures::stream::SplitSink<warp::ws::WebSocket, Message>,
    running: &std::sync::Arc<std::sync::atomic::AtomicBool>,
    out_w: u32,
    out_h: u32,
    fps: u32,
    bitrate_kbps: u32,
    encoder: &str,
) -> anyhow::Result<bool> {
    let mut cmd = Command::new("ffmpeg");
    cmd.args([
        "-f",
        "gdigrab",
        "-framerate",
        &fps.to_string(),
        "-i",
        "desktop",
        "-vf",
        &format!(
            "scale={}:{}:force_original_aspect_ratio=increase,crop={}:{}",
            out_w, out_h, out_w, out_h
        ),
        "-an",
        "-c:v",
        encoder,
        "-pix_fmt",
        "yuv420p",
        "-tune",
        "ll",
        "-g",
        &(fps * 2).to_string(),
        "-b:v",
        &format!("{}k", bitrate_kbps),
        "-maxrate",
        &format!("{}k", bitrate_kbps),
        "-bufsize",
        &format!("{}k", bitrate_kbps * 2),
        "-f",
        "h264",
        "-",
    ])
    .stdin(std::process::Stdio::null())
    .stderr(std::process::Stdio::null())
    .stdout(std::process::Stdio::piped());

    let mut child = cmd.spawn()?;
    let mut stdout = child
        .stdout
        .take()
        .ok_or_else(|| anyhow::anyhow!("ffmpeg stdout unavailable"))?;

    let mut buf = vec![0u8; 64 * 1024];
    let mut sent_any = false;

    while running.load(std::sync::atomic::Ordering::Relaxed) {
        let n = stdout.read(&mut buf).await?;
        if n == 0 {
            break;
        }

        sent_any = true;
        if ws_tx.send(Message::binary(buf[..n].to_vec())).await.is_err() {
            break;
        }
    }

    let _ = child.kill().await;
    Ok(sent_any)
}

async fn broadcast(rooms: &Rooms, room: &str, sender: &str, message: &SignalMessage) {
    let payload = match serde_json::to_string(message) {
        Ok(v) => v,
        Err(_) => return,
    };

    let map = rooms.read().await;
    if let Some(peers) = map.get(room) {
        for peer in peers {
            if peer.id != sender {
                let _ = peer.tx.send(Message::text(payload.clone()));
            }
        }
    }
}
