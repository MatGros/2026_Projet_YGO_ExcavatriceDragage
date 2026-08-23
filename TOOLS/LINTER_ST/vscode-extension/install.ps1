# Compile, package et installe (ou reinstalle) l'extension Linter ST en local -- sans
# Marketplace, sans etapes manuelles VSCode. A relancer a chaque changement de version.
#
# Usage :
#   powershell -File TOOLS/LINTER_ST/vscode-extension/install.ps1
#
# Puis dans VSCode : Ctrl+Shift+P -> "Developer: Reload Window" pour activer.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

try {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        throw "La commande 'code' (CLI VSCode) est introuvable dans le PATH. Dans VSCode : Ctrl+Shift+P -> 'Shell Command: Install code command in PATH', puis relancer ce script."
    }

    Write-Host "==> npm install" -ForegroundColor Cyan
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install a echoue" }

    Write-Host "==> npm run compile" -ForegroundColor Cyan
    npm run compile
    if ($LASTEXITCODE -ne 0) { throw "npm run compile a echoue" }

    if (-not (Get-Command vsce -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installation de @vscode/vsce (globale, une seule fois)" -ForegroundColor Cyan
        npm install -g @vscode/vsce
        if ($LASTEXITCODE -ne 0) { throw "npm install -g @vscode/vsce a echoue" }
    }

    Write-Host "==> vsce package" -ForegroundColor Cyan
    Get-ChildItem -Filter "*.vsix" | Remove-Item -Force
    vsce package --allow-missing-repository --skip-license
    if ($LASTEXITCODE -ne 0) { throw "vsce package a echoue" }

    $vsix = Get-ChildItem -Filter "linter-st-*.vsix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $vsix) { throw "Aucun .vsix genere par vsce package" }

    Write-Host "==> code --install-extension $($vsix.Name) --force" -ForegroundColor Cyan
    code --install-extension $vsix.FullName --force
    if ($LASTEXITCODE -ne 0) { throw "code --install-extension a echoue" }

    Write-Host ""
    Write-Host "OK -- $($vsix.Name) installe." -ForegroundColor Green
    Write-Host "Dans VSCode : Ctrl+Shift+P -> 'Developer: Reload Window' pour l'activer." -ForegroundColor Yellow
}
finally {
    Pop-Location
}
