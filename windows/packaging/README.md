# FinAI Studio — Windows Packaging (Step 40)

This folder contains the enterprise Windows installer pipeline for FinAI Studio.

## Outputs

| Artifact | Command | Location |
| --- | --- | --- |
| Release executable | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| MSIX installer | `dart run msix:create` | `build/windows/x64/runner/Release/` |
| Inno Setup EXE | `ISCC.exe windows/installer_builder.iss` | `build/installer/FinAI_Studio_Setup_v1.0.exe` |

## One-shot build

```powershell
.\windows\packaging\build_installer.ps1
```

Add `-SkipMsix` to only produce the release bundle.

## MSIX configuration

The installer branding lives in the `msix_config:` node of `pubspec.yaml`:

- **Display name:** FinAI Studio
- **Identity:** `com.finaistudio.desktop`
- **Logo:** `assets/icons/app_logo.png`
- **Capabilities:** `internetClient`, `runFullTrust`
- **File association:** `.finai` (encrypted backup archives)
- **Protocol handler:** `finai://` deep links

## Inno Setup (offline EXE)

`windows/installer_builder.iss` produces `FinAI_Studio_Setup_v1.0.exe` with a
desktop shortcut, Start Menu entries, and an optional bundled Visual C++
Redistributable (`windows/redist/vc_redist.x64.exe`, guarded so it is optional).

Silent enterprise rollout:

```
FinAI_Studio_Setup_v1.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

## File association & protocol handler notes

- Opening a `.finai` archive should route to the Backup & Recovery workspace
  (`AppSection.disasterRecovery`) for integrity verification and restore.
- `finai://` deep links are consumed by `SearchResultItemEntity.deepLinkRoute`
  (`finai://<entityType>/<id>`) for instant navigation from search results.

> The runtime `finai://` / `.finai` launch arguments are delivered through the
> platform channel; wire them in `lib/main.dart` when the Windows runner is
> scaffolded (`flutter create --platforms=windows .`).
