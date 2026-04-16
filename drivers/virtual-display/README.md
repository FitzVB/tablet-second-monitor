Coloca aqui un paquete de driver virtual basado en INF si quieres distribuirlo junto al instalador.

Opciones soportadas por el proyecto:

1. Instalacion por winget:
   .\scripts\install-virtual-display.ps1

2. Instalacion por INF local:
   .\scripts\install-virtual-display.ps1 -Provider inf -InfPath .\drivers\virtual-display\TuDriver.inf

Notas:
- El modo `extended` real requiere un display virtual o un segundo monitor ya presente en Windows.
- El proyecto autodetecta nombres como `Virtual`, `IDD`, `Indirect`, `Mtt Virtual`, `Parsec`, `RustDesk` y `usbmmidd`.