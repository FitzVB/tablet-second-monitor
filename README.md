# Tablet Second Monitor (Windows + Android) - USB First

Convierte una tablet Android en pantalla remota de baja latencia para Windows usando conexión USB y codec H.264 hardware.

Ahora soporta dos modos de trabajo:
- `mirror`: duplica una pantalla existente de Windows.
- `extended`: intenta usar una pantalla no primaria, priorizando un monitor virtual si existe.

## 🚀 Quick Start

**Para instalación y configuración completa, ver [SETUP.md](SETUP.md)**

```powershell
# Verificar dependencias
.\setup.ps1 -Verify

# Instalar requisitos faltantes
.\setup.ps1 -Install

# Compilar y ejecutar
cd host-windows
cargo run
```

## 📋 Requisitos del Sistema

### PC Windows
- **OS**: Windows 10/11 (x64)
- **Rust**: 1.70.0+ (Descargar: https://rustup.rs)
- **ADB**: Para comunicación USB (Descargar: https://developer.android.com/tools/releases/platform-tools)
- **Java**: JDK 11+ para compilar Android (Descargar: https://adoptium.net)
- **FFmpeg**: Para codificación H.264 (Descargar: https://ffmpeg.org)
- **Espacio**: ~2GB en disco

### Tablet Android
- **Version**: Android 7.0+ (API 24+)
- **Cable**: USB datos (no solo carga)
- **Configuración**: USB Debugging habilitado

**→ [Todas las instrucciones de instalación en SETUP.md](SETUP.md)**

## 🏗 Estructura del Proyecto

- `host-windows/`: Servidor WebSocket + FFmpeg en Rust
- `android-client/`: App Android nativa en Kotlin
- `setup.ps1`: Script automatizado de instalación
- `requirements.json`: Configuración legible para IA
- `SETUP.md`: Guía completa de instalación
- `scripts/`: Scripts de inicio/parada USB
- `scripts/install-virtual-display.ps1`: Instalación de driver virtual por `INF`

## ✨ Características

### Codec de Video
- **H.264** hardware-acelerado
- Fallback automático: NVENC → QSV → AMF → libx264
- **60 FPS** objetivo, mínimo 30 FPS

### Transporte
- **USB** con ADB reverse tunnel
- WebSocket binary frames
- Zero firewall configuration
- Latencia ultra-baja < 100ms

### Interfaz Android
- **SurfaceView** nativo para máximo rendimiento
- Landscape fullscreen immersive
- Logs en tiempo real
- Control conexión desde botones
- Selector de modo `mirror` / `extended`

## 🔧 ¿Por qué este enfoque?

| Aspecto | USB+ADB | WiFi Directo | VPN |
|--------|---------|-------------|-----|
| Latencia | Ultra-baja | Media | Variable |
| Firewall | No necesita | Abierto | Abierto |
| Configuración | Automática | Manual | Compleja |
| Costo de energía | Bajo | Alto | Medio |
| Estabilidad | Muy estable | Intermitente | Estable |

## 📱 Workflow de Uso

```powershell
# 1. Conectar tablet por USB
# 2. Habilitar USB Debugging en tablet (Settings → Developer Options)

# 3. Compilar (solo primera vez)
cd host-windows && cargo build
cd ../android-client && .\gradlew assembleDebug

# 4. Instalar APK
adb install -r android-client\app\build\outputs\apk\debug\app-debug.apk

# 5. Iniciar servidor
cd host-windows
$env:TABLET_MONITOR_LISTEN = "127.0.0.1"
cargo run

# 6. En la tablet:
# - Abrir app "Tablet Monitor"
# - Elegir modo: `mirror` o `extended`
# - Pulsar "Conectar"
# - Video aparece en pantalla completa
```

### Selección de displays

- Si dejas el campo `Auto`, el host elige la pantalla principal en modo `mirror`.
- En modo `extended`, el host intenta usar primero un display virtual, luego el primer display no primario.
- Si quieres forzar un monitor concreto, escribe su índice en la app o usa `TABLET_MONITOR_EXTENDED_DISPLAY`.
- Para instalar un driver virtual empaquetado como `INF`, usa `scripts/install-virtual-display.ps1`.
- Por defecto, `scripts/install-virtual-display.ps1` intenta instalar `VirtualDrivers.Virtual-Display-Driver` via `winget`.

## 🎯 Flujo Técnico

1. **Iniciación USB**: `adb reverse tcp:9001 tcp:9001` (host → tablet en puerto virtual)
2. **Server**: Host escucha en `127.0.0.1:9001` (desde perspectiva de tablet)
3. **Conexión**: Android abre WebSocket a `ws://127.0.0.1:9001/h264`
4. **Captura**: FFmpeg captura pantalla de Windows con `gdigrab`
5. **Codificación**: FFmpeg codifica a H.264 en hardware (GPU)
6. **Transmisión**: Raw H.264 Annex-B NAL units sobre WebSocket
7. **Decodificación**: MediaCodec hardware en Android decodifica
8. **Renderizado**: SurfaceView muestra video sin latencia

## 🚀 Instalación Rápida

**Opción A: Automatizado (Recomendado)**
```powershell
.\setup.ps1 -Full
```

**Opción B: Manual**
```powershell
# Instalar Rust
Invoke-WebRequest -Uri https://rustup.rs | Invoke-Expression

# Instalar Java y ADB
winget install OpenJDK.17
winget install Google.AndroidStudio.Tools
winget install FFmpeg

# Verificar
rustc --version
adb version
java -version
ffmpeg -version
```

Ver [SETUP.md](SETUP.md) para instrucciones detalladas.

## 📊 Estado del Proyecto

| Componente | Estado | Notas |
|-----------|---------|-------|
| Captura de pantalla | ✅ | GDI con soporte DXGI plannned |
| Codec H.264 | ✅ | Hardware + fallback software |
| Media Codec Android| ✅ | Con parser Annex-B |
| Transporte USB | ✅ | ADB reverse tunnel |
| Señalización | ✅ | WebSocket room-based |
| Fullscreen Android | ✅ | Landscape immersive mode |
| Latencia optimización | ✅ | Tuning de bitrate/FPS |
| Interfaz UI | ✅ | Logs + control de conexión |

## 🔍 Debugging & Logs

```powershell
# Ver logs del servidor
cd host-windows && cargo run

# Ver logs de Android
adb logcat -s "TabletMonitor|H264|MediaCodec"

# Verificar conexión WiFi inverse
adb reverse -l

# Reestablecer túnel
adb reverse tcp:9001 tcp:9001
```

## ⚙️ Tuning de Rendimiento

### Reducir latencia
```powershell
$env:TABLET_MONITOR_FPS = "30"           # Menor FPS = menor latencia
$env:TABLET_MONITOR_BITRATE = "2000"     # Bitrate más bajo
```

### Mejor calidad
```powershell
$env:TABLET_MONITOR_FPS = "60"
$env:TABLET_MONITOR_BITRATE = "5000"
```

### GPU específica
```powershell
$env:TABLET_MONITOR_HW_ENCODER = "h264_nvenc"  # NVIDIA
$env:TABLET_MONITOR_HW_ENCODER = "h264_qsv"   # Intel
$env:TABLET_MONITOR_HW_ENCODER = "h264_amf"   # AMD
```

### Modo de pantalla
```powershell
$env:TABLET_MONITOR_MODE = "mirror"               # duplicar pantalla principal
$env:TABLET_MONITOR_MODE = "extended"             # preferir monitor no primario / virtual
$env:TABLET_MONITOR_EXTENDED_DISPLAY = "2"        # forzar índice para modo extended
```

### Driver virtual
```powershell
# Instala Virtual Display Driver desde winget
.\scripts\install-virtual-display.ps1

# O instala un INF concreto
.\scripts\install-virtual-display.ps1 -Provider inf -InfPath .\drivers\virtual-display\MyDriver.inf
```

### Input tactil basico

- La app Android ahora abre un canal `/input` ademas del stream de video.
- Un toque se traduce a movimiento y click izquierdo sobre el display seleccionado.
- La primera version es tactil simple, equivalente a raton absoluto; no incluye gestos multitouch ni teclado.

## 🐛 Troubleshooting

| Problema | Solución |
|----------|----------|
| ADB device not found | `adb connect <ip>` o reconectar USB |
| FFmpeg not found | `winget install FFmpeg` y agregar PATH |
| Android app crashes | `adb logcat` para ver detalles |
| Latencia alta | Reducir bitrate o FPS |
| Sin video | Verificar `adb reverse -l` y puertos |

Ver [SETUP.md - Troubleshooting](SETUP.md#troubleshooting) para soluciones completas.

## 🔗 Endpoints WebSocket

```
/stream   → JPEG streaming (legacy, bajo rendimiento)
/h264    → H.264 video (recomendado, hardware codec)
/input   → Eventos tactiles / raton absoluto hacia Windows
/ws      → Señalización WebSocket
/displays → Lista JSON de displays detectados por Windows
```

Ejemplo:
```
ws://127.0.0.1:9001/h264?w=960&h=540&fps=60&bitrate_kbps=3500&fit=cover&mode=extended
```

## 📦 Automatización e IA

Para integración con herramientas de IA/CI-CD:

- **requirements.json**: Definición parseable de dependencias
- **setup.ps1**: Script de instalación automatizado
- **SETUP.md**: Instrucciones legibles para máquinas

Ejemplo de lectura:
```json
{
  "dependencies": {...},
  "build_targets": [...],
  "deployment": [...]
}
```

## 📝 Licencia

MIT - Usa libremente para proyectos personales y comerciales.

## 🤝 Contribuciones

Contributions welcome! Por favor:
1. Fork el repo
2. Crea branch para tu feature
3. Commit cambios
4. Push a branch
5. Abre Pull Request

## 📞 Soporte

- GitHub Issues: Reportar bugs
- Discussions: Preguntas y ideas
- Ver SETUP.md para FAQ
