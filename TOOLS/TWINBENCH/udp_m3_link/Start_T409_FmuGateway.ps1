$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = (Get-Command python -ErrorAction Stop).Source
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchT409'
$RunId = Get-Date -Format 'yyyyMMdd_HHmmss'
$Out = Join-Path $StateDir "fmu_${RunId}.stdout.log"
$Err = Join-Path $StateDir "fmu_${RunId}.stderr.log"
$Trace = Join-Path $StateDir "fmu_${RunId}.trace.csv"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
Write-Host '=== T409 - FMU M3 UDP LOOPBACK ===' -ForegroundColor Cyan
Write-Host '[SECURITE] 127.0.0.1:29061 uniquement. Aucun PLC reel.'
$existing = Get-NetUDPEndpoint -LocalAddress '127.0.0.1' -LocalPort 29061 -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Host '[INFO] Une passerelle T409 est deja active sur 127.0.0.1:29061.' -ForegroundColor Yellow
    Write-Host '[ACTION] Reutilisation de l instance existante ; aucun second processus lance.'
    return
}
$script = Join-Path $ToolDir 'udp_m3_fmu_gateway.py'
$p = Start-Process -FilePath $Python -ArgumentList @($script, '--duration-s', '300', '--trace-file', $Trace) -WindowStyle Hidden -RedirectStandardOutput $Out -RedirectStandardError $Err -PassThru
Start-Sleep -Seconds 5
if ($p.HasExited) { throw "Gateway FMU arrete. Journal : $Err" }
Write-Host '[OK] Gateway FMU actif pour 5 min.' -ForegroundColor Green
Write-Host "Journal : $Out"
Write-Host "Trace  : $Trace"
