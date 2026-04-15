# Changelog

Todos los cambios significativos en este proyecto están documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-14

### Added

#### Host (Rust)
- ✨ H.264 hardware encoding con FFmpeg
- 🎬 Soporte para múltiples encoders GPU: h264_nvenc, h264_qsv, h264_amf
- 📹 Fallback automático a libx264 (software)
- 🔄 WebSocket servidor con Warp
- 📊 GDI screen capture con escalado dinámico
- 🎛️ Query parameters: resolución, FPS, bitrate, fit mode
- 📝 Logging con tracing

#### Android Client
- 📱 MediaCodec hardware H.264 decoder
- 🎨 SurfaceView para renderizado de video
- 📡 WebSocket client con OkHttp3
- 🔍 Annex-B H.264 NAL unit parser
- 🔗 Signaling con room-based coordination
- 📊 Logs en tiempo real en UI
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

## Notas de Versión Futura

### [1.1.0] - Roadmap

- [ ] Audio streaming (AAC codec)
- [ ] WiFi direct support (fallback)
- [ ] Cursor tracking overlay
- [ ] Mouse/keyboard input from tablet
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
- [ ] Web client (browser-based tablet)
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
