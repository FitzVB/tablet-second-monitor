# Contributing to Tablet Second Monitor

¡Gracias por la intención de contribuir! Este documento explica cómo hacerlo.

## Código de Conducta

Esperamos que todos los contribuyentes sigan nuestro código de conducta: sé respetuoso, inclusivo y profesional.

## ¿Cómo Contribuir?

### Reportar Bugs

1. **Verifica si ya existe** un issue similar en la sección "Issues"
2. **Crea un nuevo issue** con título descriptivo
3. **Incluye**:
   - SO (Windows 10/11, versión)
   - Versión de Rust (`rustc --version`)
   - Paso a paso para reproducir
   - Error exacto (stack trace si aplica)
   - Evidencia (logs, screenshots)

Ejemplo:
```
Título: H.264 stream fails on Intel iGPU

Descripción:
- Windows 11 22H2
- Rust 1.78.0
- Intel UHD Graphics 770

Pasos:
1. cargo run
2. adb shell am start -n com.example.tabletmonitor/.MainActivity
3. Pulsa Conectar

Error:
ERROR: h264_qsv encoder not found, falling back to libx264
```

### Sugerir Features

1. **Abre un Discussion** en lugar de Issue
2. **Describe**: Use case, por qué lo necesitas, alternativas consideradas
3. **Etiqueta**: enhancement

### Pull Requests

#### Antes de empezar:

1. **Fork** el repositorio
2. **Crea branch** con nombre descriptivo:
   ```bash
   git checkout -b feature/add-bitrate-limiter
   git checkout -b fix/websocket-reconnection
   ```

#### Workflow de cambios:

```bash
# Clone tu fork
git clone https://github.com/YOUR_USERNAME/tablet-second-monitor.git
cd tablet-second-monitor

# Crea branch
git checkout -b feature/your-feature

# Haz cambios
# Rust: host-windows/src/
# Android: android-client/app/src/main/

# Compile y prueba
cd host-windows && cargo build && cargo test
cd ../android-client && ./gradlew assembleDebug

# Commit con mensaje descriptivo
git commit -m "Add feature: description"
git commit -m "Fix: issue description"
git commit -m "Docs: update README.md"

# Push a tu fork
git push origin feature/your-feature

# Abre Pull Request
```

#### Mensajes de Commit:

Usa conventional commits:
```
feat: add H.264 bitrate adaptive streaming
fix: resolve WebSocket timeout on reconnect
docs: update installation guide
test: add MediaCodec decoder tests
chore: update dependencies
perf: optimize GDI capture resolution
```

#### Checklist para PR:

- [ ] El código compila sin warnings (`cargo build --all`)
- [ ] Tests pasan (`cargo test`)
- [ ] Android APK compila (`./gradlew assembleDebug`)
- [ ] Se probó en dispositivo(s) Android
- [ ] Se agregaron tests si es feature nuevo
- [ ] Se actualizó documentación
- [ ] Se agregó CHANGELOG.md entry
- [ ] No hay conflictos con master

#### Criterios de revisión:

✅ **Será aprobado si**:
- Código es legible y bien documentado
- Cumple con estilo del proyecto
- No introduce regresiones
- Tiene tests (si aplica)
- Documentación está actualizada

❌ **No será aprobado si**:
- Tiene conflictos no resueltos
- No compila sin warnings
- No se probó funcionalmente
- Cambia arbitrariamente estilos sin razón

## Guías de Desarrollo

### Estilo de Código Rust

```rust
// ✓ Bien
fn encode_h264_frame(buffer: &[u8], encoder: &FFmpegEncoder) -> Result<Vec<u8>> {
    encoder.encode(buffer)
}

// ✗ No
fn encodeH264Frame(buffer: &[u8], encoder: &FFmpegEncoder) -> Result<Vec<u8>> {
    let result = encoder.encode(buffer);
    result
}
```

**Reglas**:
- Snake_case para funciones y variables
- CamelCase para tipos
- Imports ordenados: std → external → local
- 100 caracteres max de línea (preferiblemente)
- `cargo fmt` antes de commit

### Estilo Android Kotlin

```kotlin
// ✓ Bien
class H264Decoder(private val surface: Surface) {
    fun feedNalUnit(data: ByteArray) {
        mediaCodec.queueInputBuffer(...)
    }
}

// ✗ No
class h264decoder(surface: Surface) {
    fun feed_nal_unit(data: ByteArray) {
        mediaCodec.queueInputBuffer(...)
    }
}
```

**Reglas**:
- PascalCase para clases
- camelCase para funciones
- `ktlint` para formateo automático
- Nullable types con `?` (use `?:` operator)

### Comentarios y Documentación

```rust
/// Encodes screen capture using FFmpeg with H.264 codec
///
/// # Arguments
/// * `width` - Frame width in pixels
/// * `height` - Frame height in pixels
/// * `fps` - Frames per second
///
/// # Returns
/// Raw H.264 Annex-B stream
pub fn start_encoding(width: u32, height: u32, fps: u32) -> Result<()> {
    // Critical section: spawn FFmpeg process
    // ...
}
```

### Logging

```rust
// Host
tracing::info!("H.264 stream started: {}x{} @ {} fps", width, height, fps);
tracing::warn!("GPU encoder not available, falling back to software");
tracing::error!("FFmpeg process crashed: {}", err);

// Android Kotlin
Log.i("H264Decoder", "NAL unit queued: size=${data.size}")
Log.w("MediaCodec", "Decoder stalled, resetting")
Log.e("TabletMonitor", "Surface not ready: $error")
```

### Testing

Rust:
```bash
cargo test
cargo test --release
cargo test -- --nocapture  # Ver output
```

Android:
```bash
./gradlew test
./gradlew connectedAndroidTest  # En dispositivo
```

## Configuración Local

```powershell
# Setup completo
.\setup.ps1 -Full

# IDE recomendados:
# - IntelliJ IDEA Community (Android)
# - VS Code + rust-analyzer (Rust)

# Extensions recomendadas:
# - rust-analyzer
# - Kotlin Language
# - Android Resources
```

## Flujo de Desarrollo Típico

```powershell
# Terminal 1: Monitor host
cd host-windows
cargo watch -x run

# Terminal 2: Monitor Android logs
adb logcat -s "TabletMonitor"

# Terminal 3: Build y deploy
cd android-client
./gradlew assemble
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## Areas de Contribución Necesitadas

- [ ] **Streaming**: Audio support, RTMP/RTSP transport
- [ ] **Performance**: Motion detection, adaptive bitrate
- [ ] **Seguridad**: Certificate pinning, OAuth auth
- [ ] **UI**: Dark mode, settings persistence
- [ ] **Docs**: Tutorial videos, architecture diagrams
- [ ] **Testing**: Unit tests, integration tests
- [ ] **Platforms**: Support Linux/macOS host

## Preguntas?

- 💬 GitHub Discussions
- 🐛 GitHub Issues
- 📧 Pull Request description

¡Gracias por contribuir! 🙏
