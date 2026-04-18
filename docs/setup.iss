; FlexDisplay - Inno Setup Script
; Script de instalación para usuarios no técnicos

[Setup]
AppName=FlexDisplay
AppVersion=1.0.0
AppPublisher=FlexDisplay Project
AppPublisherURL=https://github.com/FitzVB/FlexDisplay
AppSupportURL=https://github.com/FitzVB/FlexDisplay
AppUpdatesURL=https://github.com/FitzVB/FlexDisplay/releases
AppId={{F9E1C5D0-9E0A-4B6E-8A16-4D5FD94B1AF2}
DefaultDirName={pf}\FlexDisplay
DefaultGroupName=FlexDisplay
OutputDir=.\dist
OutputBaseFilename=FlexDisplay-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=
LicenseFile=
; Requiere Windows 7+
MinVersion=6.1
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el &Escritorio"; GroupDescription: "Accesos directos:"; Flags: checkedonce

[Files]
; Host executable
Source: "host-windows\target\release\host-windows.exe"; DestDir: "{app}"; Flags: ignoreversion
; FFmpeg binary
Source: "ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
; ADB binaries
Source: "adb.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "AdbWinApi.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "AdbWinUsbApi.dll"; DestDir: "{app}"; Flags: ignoreversion
; Android APK
Source: "android-client\app\build\outputs\apk\debug\app-debug.apk"; DestDir: "{app}"; Flags: ignoreversion
; Launcher batch files
Source: "START.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "STOP.bat"; DestDir: "{app}"; Flags: ignoreversion
; Documentation
Source: "GUIDE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
; Driver integration scripts and optional packaged driver files
Source: "scripts\install-virtual-display.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\remove-virtual-display.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "drivers\virtual-display\*"; DestDir: "{app}\drivers\virtual-display"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start menu icon
Name: "{group}\FlexDisplay"; Filename: "{app}\START.bat"; WorkingDir: "{app}"; IconIndex: 0
Name: "{group}\Detener FlexDisplay"; Filename: "{app}\STOP.bat"; WorkingDir: "{app}"; IconIndex: 0
Name: "{group}\Ver Guía"; Filename: "notepad.exe"; Parameters: """{app}\GUIDE.txt"""; IconIndex: 0
Name: "{group}\Desinstalar"; Filename: "{uninstallexe}"
; Desktop icon (si el usuario lo elige)
Name: "{userdesktop}\FlexDisplay"; Filename: "{app}\START.bat"; WorkingDir: "{app}"; Tasks: desktopicon; IconIndex: 0

[Run]
; No ejecutar nada automáticamente después de la instalación

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
