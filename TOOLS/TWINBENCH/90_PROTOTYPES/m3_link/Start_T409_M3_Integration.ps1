$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ToolDir '..\..\..\..')).Path
$Gateway = Join-Path $ToolDir 'Start_T409_FmuGateway.ps1'
$LiveView = Join-Path $RepoRoot 'TOOLS\TWINBENCH\02_SIM\modelica\live_poc\Start_M3_Live.ps1'

Write-Host '=== T409 - INTEGRATION M3 CONTROL WIN + FMU ===' -ForegroundColor Cyan
Write-Host '[SECURITE] Gateway UDP loopback uniquement ; interface en lecture seule.'
Write-Host '[AUTO] Aucun bouton Start ni script Tools > Scripting requis pour animer la vue.'
Write-Host '[INFO] La passerelle copie vers l interface la meme reponse FMU deja renvoyee au Control Win.'

& $Gateway -ResetPlant
if (-not (Test-Path -LiteralPath $LiveView)) {
    throw "Interface M3 introuvable : $LiveView"
}

Write-Host '[EN COURS] Ouverture de la vue M3 connectee (lecture seule)...'
& $LiveView -FmuViaPlc
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "L interface M3 s est arretee avec le code $LASTEXITCODE."
}
