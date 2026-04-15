# Tablet Second Monitor (Windows + Android) - USB First

MVP base para convertir una tablet Android en pantalla remota de Windows con foco en baja latencia por USB.

## Que cambia en este enfoque

- Conexion por USB con ADB reverse.
- Sin IP local, sin abrir puertos en firewall, sin configurar red Wi-Fi.
- La app Android siempre conecta a `ws://127.0.0.1:9001/ws`.

## Estructura

- `host-windows/`: host en Rust.
- `android-client/`: app Android (Kotlin).
- `scripts/start-usb.ps1`: inicia host + tunel USB.
- `scripts/stop-usb.ps1`: cierra tunel USB.
- `start-usb.bat`: atajo para usuarios finales.

## Requisitos

### PC Windows
- Rust estable (cargo/rustc)
- Android SDK Platform-Tools (adb)

### Tablet Android
- Depuracion USB habilitada
- Cable USB de datos

## Uso para cualquier persona (flujo recomendado)

1. Conecta la tablet por USB.
2. Activa depuracion USB y acepta la clave RSA en la tablet.
3. En la raiz del proyecto ejecuta `start-usb.bat`.
4. Abre la app en Android y pulsa `Conectar`.

Para detener la sesion USB:
- Ejecuta `stop-usb.bat`.

## Flujo tecnico

1. `adb reverse tcp:9001 tcp:9001` crea un tunel desde la tablet al host.
2. El host escucha en `127.0.0.1:9001`.
3. La app Android se conecta a `ws://127.0.0.1:9001/ws`.

## Estado actual

Este scaffold deja resuelto el transporte USB y la senalizacion. El streaming de escritorio (DXGI + track de video) se implementa en la siguiente iteracion.
