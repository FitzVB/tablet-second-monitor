# Tablet Monitor (Windows + Android)

Turn an Android tablet into a touch-enabled second monitor for Windows over USB (recommended) or Wi-Fi.

## Current status

- Touch input on extended monitor: fixed.
- Android UI with menu, HUD, and FAQ: updated.
- Single startup launcher: `START.bat`.
- Stop utility: `scripts\STOP.bat`.

## Single structure (source of truth)

- `START.bat`: main startup entry point.
- `scripts\STOP.bat`: stops host and clears `adb reverse`.
- `scripts\launcher.ps1`: launcher logic (USB/Wi-Fi).
- `docs\SETUP.md`: environment setup.
- `host-windows\`: Rust host server.
- `android-client\`: Android app.

## Quick start

1. Run `START.bat` from the project root.
2. Choose mode:
   - `1` USB (recommended)
   - `2` Wi-Fi
3. Open the Android app and connect.

### Recommended USB mode

- Enable USB debugging on Android.
- Connect via USB cable.
- If needed, run manually:

```powershell
adb reverse tcp:9001 tcp:9001
```

- In the app, use host `127.0.0.1`.

### Wi-Fi

- PC and tablet must be on the same network.
- The launcher tries to show the PC LAN IP.
- In the app, use that IP and port `9001`.

## Stop

To stop everything and clean the USB tunnel:

```bat
scripts\STOP.bat
```

## In-app FAQ

From the `FAQ` button you can choose language:

- Spanish
- English

Content is shown in the selected language, independent from system language.

## Is it plug and play for non-technical users?

It is **close**, but still not 100% zero-friction.

### Already solved

- Single startup file (`START.bat`).
- Single stop file (`scripts\STOP.bat`).
- Stable USB workflow for daily use.

### Still requires minimal technical steps

- Enable USB debugging on Android.
- Accept ADB authorization on first use.
- Have PC dependencies ready (Rust/cargo/ffmpeg/adb, depending on scenario).

## Next milestone for true non-technical use

- Package a Windows installer with verified dependencies.
- Bundle `adb`/runtime in final distribution.
- Add first-run setup wizard with automatic checks.

## Development

### Android

```powershell
Set-Location android-client
.\gradlew.bat assembleDebug
```

### Host (Rust)

```powershell
Set-Location host-windows
cargo build --release
```

## Additional documentation

- Detailed setup: `docs\SETUP.md`
- Maintenance utilities: `scripts\health-check.ps1`, `scripts\setup.ps1`
