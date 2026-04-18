# Contributing to FlexDisplay

Thanks for your interest in contributing. This document explains how.

## Code of Conduct

We expect all contributors to follow our code of conduct: be respectful, inclusive, and professional.

## How to Contribute

### Report Bugs

1. **Check first** if a similar issue already exists in "Issues"
2. **Open a new issue** with a descriptive title
3. **Include**:
    - OS (Windows 10/11, version)
   - Versión de Rust (`rustc --version`)
    - Step-by-step reproduction
    - Exact error (stack trace if available)
    - Evidence (logs, screenshots)

Example:
```
Título: H.264 stream fails on Intel iGPU

Description:
- Windows 11 22H2
- Rust 1.78.0
- Intel UHD Graphics 770

Steps:
1. cargo run
2. adb shell am start -n com.example.tabletmonitor/.MainActivity
3. Tap Connect

Error:
ERROR: h264_qsv encoder not found, falling back to libx264
```

### Suggest Features

1. **Open a Discussion** instead of an Issue
2. **Describe**: use case, why you need it, alternatives considered
3. **Tag**: enhancement

### Pull Requests

#### Before you start:

1. **Fork** el repositorio
2. **Create a branch** with a descriptive name:
   ```bash
   git checkout -b feature/add-bitrate-limiter
   git checkout -b fix/websocket-reconnection
   ```

#### Change workflow:

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/tablet-second-monitor.git
cd tablet-second-monitor

# Create branch
git checkout -b feature/your-feature

# Make changes
# Rust: host-windows/src/
# Android: android-client/app/src/main/

# Build and test
cd host-windows && cargo build && cargo test
cd ../android-client && ./gradlew assembleDebug

# Commit with descriptive message
git commit -m "Add feature: description"
git commit -m "Fix: issue description"
git commit -m "Docs: update README.md"

# Push to your fork
git push origin feature/your-feature

# Open pull request
```

#### Commit messages:

Use conventional commits:
```
feat: add H.264 bitrate adaptive streaming
fix: resolve WebSocket timeout on reconnect
docs: update installation guide
test: add MediaCodec decoder tests
chore: update dependencies
perf: optimize GDI capture resolution
```

#### PR checklist:

- [ ] El código compila sin warnings (`cargo build --all`)
- [ ] Tests pasan (`cargo test`)
- [ ] Android APK compila (`./gradlew assembleDebug`)
- [ ] Tested on Android device(s)
- [ ] Added tests for new features when needed
- [ ] Updated documentation
- [ ] Added CHANGELOG.md entry
- [ ] No conflicts with master

#### Review criteria:

✅ **Will be approved if**:
- Code is readable and well documented
- Follows project style
- Does not introduce regressions
- Includes tests when applicable
- Documentation is updated

❌ **Will not be approved if**:
- Contains unresolved conflicts
- Does not build without warnings
- Was not functionally tested
- Changes style arbitrarily without reason

## Development Guidelines

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

**Rules**:
- snake_case for functions and variables
- CamelCase for types
- Ordered imports: std -> external -> local
- 100 chars max per line (preferred)
- Run `cargo fmt` before commit

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

**Rules**:
- PascalCase for classes
- camelCase for functions
- `ktlint` for automatic formatting
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
cargo test -- --nocapture  # Show output
```

Android:
```bash
./gradlew test
./gradlew connectedAndroidTest  # On device
```

## Local Setup

```powershell
# Full setup
.\setup.ps1 -Full

# Recommended IDEs:
# - IntelliJ IDEA Community (Android)
# - VS Code + rust-analyzer (Rust)

# Recommended extensions:
# - rust-analyzer
# - Kotlin Language
# - Android Resources
```

## Typical Development Flow

```powershell
# Terminal 1: Host monitor
cd host-windows
cargo watch -x run

# Terminal 2: Android logs
adb logcat -s "TabletMonitor"

# Terminal 3: Build and deploy
cd android-client
./gradlew assemble
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## Needed Contribution Areas

- [ ] **Streaming**: Audio support, RTMP/RTSP transport
- [ ] **Performance**: Motion detection, adaptive bitrate
- [ ] **Security**: Certificate pinning, OAuth auth
- [ ] **UI**: Dark mode, settings persistence
- [ ] **Docs**: Tutorial videos, architecture diagrams
- [ ] **Testing**: Unit tests, integration tests
- [ ] **Platforms**: Support Linux/macOS host

## Questions?

- 💬 GitHub Discussions
- 🐛 GitHub Issues
- 📧 Pull Request description

Thanks for contributing.
