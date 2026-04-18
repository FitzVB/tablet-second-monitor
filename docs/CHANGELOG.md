# Changelog

All notable changes to this project are documented in this file.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-14

### Fixed
- **Invisible Android UI**: The transparent theme background (`windowBackground=transparent`) made text fields and labels invisible on black backgrounds. Explicit dark backgrounds were added in `activity_main.xml` (`#121212` on root layout, `#1E1E1E` on top panel) and white/gray text colors were applied to controls.
- **Black screen on Wi-Fi connect**: The server listened only on `127.0.0.1`, rejecting incoming Wi-Fi clients. Changed default to `0.0.0.0` (configurable with `FLEXDISPLAY_LISTEN`). USB still works through ADB reverse tunnel.

### Changed

#### Host (Rust)
- **H.264 encoder level**: Added `-level 5.1` to NVENC to support 1890x1080 @ 60 fps (Level 4.1 limited throughput to around 245 MB/s).
- **VBV buffer**: Reverted to `bitrate/4` (250ms) from `/8` to remove compression artifacts.
- **FPS filter**: Removed `fps=fps=N` from the filtergraph (it added a ~16ms latency FIFO). Replaced with output `-r {fps}` + `fps_mode cfr`.
- **Listen address**: Default changed to `0.0.0.0` instead of `127.0.0.1`.

#### Android Client
- **Render path**: Reemplazado `TextureView` por `SurfaceView` para aprovechar el overlay HWC directo (sin copia GPU intermedia), reduciendo latencia y uso de CPU.
- **Drain thread**: Cambiado de `HandlerThread+postDelayed(4ms)` a thread dedicado con `dequeueOutputBuffer(4000µs)` bloqueante + prioridad `THREAD_PRIORITY_URGENT_DISPLAY`.
- **Submit thread**: Prioridad `THREAD_PRIORITY_URGENT_AUDIO`, `nalQueue.take()` bloqueante en lugar de `poll(1ms)` para wakeup instantáneo.
- **MediaFormat**: Añadidos `KEY_PRIORITY=0` y `KEY_OPERATING_RATE=60f` (float, no int) para que el codec reserve el máximo throughput del hardware.
- **HUD / FPS display**: Suavizado EMA (alpha=0.25) sobre ventana de 1 segundo para evitar jitter visual en el contador.

### Added

#### Android Client
- **Auto-reconnect**: Automatic exponential backoff on connection loss (1s -> 2s -> 4s -> 8s -> 16s -> 30s max).
- **Display selection**: `Display` field in UI; sent as `?display=N` -> `ddagrab=N` in FFmpeg to choose capture monitor.
- **Server IP field**: `PC IP` replaces room signaling; accepts `127.0.0.1` (USB over ADB) or LAN IPv4 for Wi-Fi.
- **Orientation handling**: `onConfigurationChanged` closes sockets and schedules automatic reconnect on rotation, avoiding Activity restart.
- **Dark UI theme**: `#121212` / `#1E1E1E` with white text, compatible with required `windowBackground=transparent` for SurfaceView.

### Technical Details (updated)
- **Latencia medida**: 14–18 ms (USB)
- **FPS**: 60 estables (Level 5.1 + KEY_OPERATING_RATE)
- **Wi-Fi**: Working; server listens on `0.0.0.0:9001`
- **USB**: ADB reverse tunnel `tcp:9001 -> tcp:9001` unchanged

---

## [1.0.0] - 2026-04-14

### Added

#### Host (Rust)
- ✨ H.264 hardware encoding with FFmpeg
- 🎬 Multi-GPU encoder support: h264_nvenc, h264_qsv, h264_amf
- 📹 Automatic fallback to libx264 (software)
- 🔄 Warp-based WebSocket server
- 📊 GDI screen capture with dynamic scaling
- 🎛️ Query parameters: resolution, FPS, bitrate, fit mode
- 📝 Logging with tracing

#### Android Client
- 📱 MediaCodec hardware H.264 decoder
- 🎨 SurfaceView video rendering
- 📡 WebSocket client with OkHttp3
- 🔍 Annex-B H.264 NAL unit parser
- 🔗 Room-based signaling coordination
- 📊 Real-time UI logs
- ⬜ Fullscreen landscape immersive mode

#### Infrastructure
- 🔌 ADB reverse tunnel USB
- 📋 Setup automation script (PowerShell)
- 📖 Comprehensive SETUP.md documentation
- 🤖 Machine-readable requirements.json
- 📝 README with quick start

### Technical Details

- **Transport**: WebSocket binary frames over USB/ADB
- **Codec**: H.264 Annex-B NAL units
- **Target Performance**: 60 FPS, 3500 kbps, <100ms latency
- **Tested On**: Windows 11, Android 7.0+

### Known Limitations

- ⚠️ Single display capture (primary monitor)
- ⚠️ No audio support yet
- ⚠️ No cursor tracking
- ⚠️ USB-only (WiFi planned)

---

## Future Release Notes

### [1.1.0] - Roadmap

- [ ] Audio streaming (AAC codec)
- [ ] WiFi direct support (fallback)
- [ ] Cursor tracking overlay
- [ ] Mouse/keyboard input from device
- [ ] Settings persistence on Android
- [ ] Recording mode (save stream to file)

### [1.2.0] - Roadmap

- [ ] Linux host support
- [ ] macOS host support
- [ ] Multiple display support
- [ ] Adaptive bitrate based on network
- [ ] Motion detection optimization
- [ ] Thermal throttling protection

### [2.0.0] - Roadmap (Long term)

- [ ] HEVC (H.265) codec support
- [ ] RTMP/RTSP streaming output
- [ ] Web client (browser-based device)
- [ ] Cloud streaming (low latency WebRTC)
- [ ] Network resilience (auto-reconnect)
- [ ] 4K streaming support

---

## Cómo Reportar Cambios

Al hacer commits, usa conventional commits:

```
feat: add feature description
fix: fix bug description
docs: update documentation
test: add tests
perf: improve performance
chore: maintenance tasks
```

Ejemplo:
```
feat: add adaptive bitrate streaming

- Monitorea ancho de banda
- Reduce bitrate if congestion detected
- Recovers to target bitrate when stable

Fixes #123
```
