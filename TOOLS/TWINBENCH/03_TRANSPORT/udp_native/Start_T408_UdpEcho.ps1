$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = (Get-Command python -ErrorAction Stop).Source
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchT408'
$PidPath = Join-Path $StateDir 'echo.pid'
$RunId = Get-Date -Format 'yyyyMMdd_HHmmss'
$StdOutPath = Join-Path $StateDir ("echo_${RunId}.stdout.log")
$StdErrPath = Join-Path $StateDir ("echo_${RunId}.stderr.log")

Write-Host '=== T408 - ECHO UDP NATIF ===' -ForegroundColor Cyan
Write-Host '[SECURITE] 127.0.0.1 uniquement : ports UDP 29031, 29041 et 29051. Aucun PLC ni CODESYS n est contacte.'
Write-Host '[INFO] Lancer ensuite PRG_TwinBenchNativeUdpMulti dans la COPIE Control Win, tache 10 ms.'

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$Existing = $null
if (Test-Path -LiteralPath $PidPath) {
    $RawPid = Get-Content -LiteralPath $PidPath -Raw
    if ($RawPid -match '^\d+$') { $Existing = Get-Process -Id ([int]$RawPid) -ErrorAction SilentlyContinue }
}

$Ready = $false
if ($null -eq $Existing) {
    $ServerPath = Join-Path $ToolDir 'udp_echo_t408.py'
    $Process = Start-Process -FilePath $Python -ArgumentList @($ServerPath, '--duration-s', '120') `
        -WindowStyle Hidden -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -PassThru
    [System.IO.File]::WriteAllText($PidPath, [string]$Process.Id)
    $Existing = $Process
    Write-Host '[EN COURS] Demarrage echo UDP local...'
}
else {
    $Ready = $true
    $StdOutPath = '(journal du lancement precedent)'
    Write-Host '[INFO] Echo UDP deja actif. Reutilisation.'
}

for ($Index = 0; $Index -lt 15; $Index++) {
    if ($Ready) { break }
    Start-Sleep -Seconds 1
    if ($null -eq (Get-Process -Id $Existing.Id -ErrorAction SilentlyContinue)) {
        throw "Echo UDP non demarre. Journal : $StdErrPath"
    }
    if ((Test-Path -LiteralPath $StdOutPath) -and (Select-String -LiteralPath $StdOutPath -SimpleMatch 'Echo UDP pret' -Quiet)) {
        $Ready = $true
    }
}
if (-not $Ready) { throw "Echo UDP non pret apres 15 s. Journal : $StdOutPath" }

Write-Host '[OK] Echo multi-flux pret en arriere-plan pour 2 min.' -ForegroundColor Green
Write-Host "Journal : $StdOutPath"
