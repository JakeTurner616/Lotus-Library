; -- Inno Setup Script for Flutter Windows Application --

; Define the app name and version
#define MyAppName "Lotus Library"
#define MyAppVersion "0.0.1"
#define MyAppPublisher "serverboi.org"
#define MyAppURL "https://serverboi.org"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=LotusLibrary-setup
OutputDir=output
Compression=lzma
SolidCompression=yes
LicenseFile=C:\Users\jaked\Documents\lotus_library\LICENSE.txt

; Specify files to include in the installer
[Files]
Source: "C:\Users\jaked\Documents\lotus_library\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Define the application's main executable to be installed in the Start Menu and desktop
[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\lotus_library.exe"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\lotus_library.exe"; Tasks: desktopicon

; Optional: Add an uninstaller
[UninstallDelete]
Type: files; Name: "{app}\*"

; Optional: Create additional tasks
[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

; Registry entries for uninstallation
[Registry]
Root: HKLM; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey
