$ErrorActionPreference = 'Stop'

$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPython = Join-Path $env:LOCALAPPDATA 'TwinBenchM3Live\Python\Scripts\python.exe'
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchM3Udp'
$PidPath = Join-Path $StateDir 'plant.pid'
$RunId = Get-Date -Format 'yyyyMMdd_HHmmss'
$StdOutPath = Join-Path $StateDir ("plant_${RunId}.stdout.log")
$StdErrPath = Join-Path $StateDir ("plant_${RunId}.stderr.log")

Write-Host '=== T407 - PLANTE M3 UDP LOCALE ===' -ForegroundColor Cyan
Write-Host '[SECURITE] 127.0.0.1:29030 uniquement. Aucun PLC ni CODESYS n est contacte par ce programme.'

if (-not (Test-Path -LiteralPath $VenvPython)) {
    throw 'Environnement TwinBench M3 absent. Lancer d abord Start_M3_Live.ps1 une fois.'
}

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$Existing = $null
$Ready = $false
if (Test-Path -LiteralPath $PidPath) {
    $RawPid = Get-Content -LiteralPath $PidPath -Raw
    if ($RawPid -match '^\d+$') {
        $Existing = Get-Process -Id ([int]$RawPid) -ErrorAction SilentlyContinue
    }
}

if ($null -eq $Existing) {
    $ServerPath = Join-Path $ToolDir 'udp_m3_plant.py'
    $Process = Start-Process -FilePath $VenvPython -ArgumentList @($ServerPath, '--duration-s', '300') `
        -WindowStyle Hidden -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -PassThru
    [System.IO.File]::WriteAllText($PidPath, [string]$Process.Id)
    $Existing = $Process
    Write-Host '[EN COURS] Demarrage de la plante OpenModelica locale...'
}
else {
    Write-Host '[INFO] Une plante locale est deja active. Reutilisation du serveur existant.'
    $StdOutPath = '(journal du lancement precedent)'
    $StdErrPath = '(journal du lancement precedent)'
    $Ready = $true
}

for ($Index = 0; $Index -lt 60; $Index++) {
    if ($Ready) { break }
    Start-Sleep -Seconds 1
    $Running = Get-Process -Id $Existing.Id -ErrorAction SilentlyContinue
    if ($null -eq $Running) {
        $ErrorText = if (Test-Path -LiteralPath $StdErrPath) { Get-Content -LiteralPath $StdErrPath -Raw } else { '' }
        throw "La plante locale n a pas demarre. Journal : $StdErrPath`n$ErrorText"
    }
    if (($StdOutPath -ne '(journal du lancement precedent)') -and (Test-Path -LiteralPath $StdOutPath) -and (Select-String -LiteralPath $StdOutPath -SimpleMatch 'Plante M3 OpenModelica prete' -Quiet)) {
        $Ready = $true
        break
    }
}

if (-not $Ready) {
    throw "La plante locale ne confirme pas son demarrage apres 60 s. Journal : $StdOutPath"
}

Write-Host '[OK] Plante M3 prete en arriere-plan pour 5 min.' -ForegroundColor Green
Write-Host ''
Write-Host 'Maintenant, dans la COPIE TwinBench Control Win deja ONLINE :'
Write-Host 'Tools > Scripting > choisir :'
Write-Host 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_m3_udp_shadow.py' -ForegroundColor Yellow
Write-Host ''
Write-Host "Journal plante : $StdOutPath"
