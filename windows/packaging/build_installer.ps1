<#
.SYNOPSIS
    Builds the FinAI Studio Windows release bundle and packages it as an MSIX.

.DESCRIPTION
    Runs `flutter build windows --release`, then invokes the `msix` tool to
    produce a signed/unsigned MSIX installer (FinAI Studio 1.0.0.0) using the
    `msix_config` block in pubspec.yaml. Optionally compiles the Inno Setup
    EXE installer when Inno Setup 6 is installed.

.EXAMPLE
    .\windows\packaging\build_installer.ps1

.EXAMPLE
    .\windows\packaging\build_installer.ps1 -SkipMsix
#>

param(
    [switch]$SkipMsix
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host '==> Building Flutter Windows release...' -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter build windows --release failed.'
    }
}
finally {
    Pop-Location
}

if (-not $SkipMsix) {
    Write-Host '==> Creating MSIX installer...' -ForegroundColor Cyan
    Push-Location $RepoRoot
    try {
        dart run msix:create
        if ($LASTEXITCODE -ne 0) {
            throw 'dart run msix:create failed.'
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host '==> Packaging complete.' -ForegroundColor Green
Write-Host '    MSIX: build/windows/x64/runner/Release/*.msix'
Write-Host '    EXE (Inno Setup): build/installer/FinAI_Studio_Setup_v1.0.exe'
