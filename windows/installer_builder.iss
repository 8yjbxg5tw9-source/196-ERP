; ============================================================================
; FinAI Studio - Enterprise Windows Installer (Inno Setup 6)
; ============================================================================
; Produces a standalone, offline FinAI_Studio_Setup_v1.0.exe that bundles the
; Flutter release build and (optionally) the Visual C++ Redistributable.
;
; Prerequisites
;   1. flutter build windows --release
;   2. Place vc_redist.x64.exe under windows\redist\ (optional; the [Run]
;      entry is guarded so the installer still works without it).
;   3. Compile with Inno Setup (ISCC.exe windows\installer_builder.iss).
;
; Silent enterprise rollout:
;   FinAI_Studio_Setup_v1.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
; ============================================================================

#define MyAppName "FinAI Studio"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FinAI Studio Systems LLC"
#define MyAppExeName "finai_studio.exe"

[Setup]
AppId={{9E4F3B7A-2C1D-4E6B-8F0A-7D5C6B9A1E2F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=FinAI_Studio_Setup_v1.0
SetupIconFile=..\assets\icons\app_logo.png
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion=1.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Enterprise accounting AI copilot

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter Windows release bundle (built with `flutter build windows --release`).
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs
; Optional bundled VC++ runtime for offline enterprise rollout.
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; \
    Flags: deleteafterinstall; Check: RedistFileExists

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
; Install the bundled VC++ runtime silently when present.
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing Visual C++ Redistributable..."; \
    Flags: runhidden waituntilterminated; Check: RedistFileExists
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
    Flags: nowait postinstall skipifsilent

[Code]
function RedistFileExists: Boolean;
begin
  Result := FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'));
end;
