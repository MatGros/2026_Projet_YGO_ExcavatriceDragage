$ErrorActionPreference = 'Stop'

$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchM3Live'
$VenvDir = Join-Path $StateDir 'Python'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'

Write-Host '=== TWINBENCH M3 LIVE - POC LOCAL ===' -ForegroundColor Cyan
Write-Host '[INFO] Aucun PLC ni CODESYS ne sera contacte.'

if (-not (Test-Path -LiteralPath $VenvPython)) {
    Write-Host '[EN COURS] Creation de l environnement Python isole...'
    python -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) { throw 'Creation environnement Python impossible.' }
}

$previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
$PSNativeCommandUseErrorActionPreference = $false
try {
    & $VenvPython -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('PySide6') else 1)" 2>$null
    $PySideReady = ($LASTEXITCODE -eq 0)
}
finally {
    $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
}

if (-not $PySideReady) {
    Write-Host '[EN COURS] Installation de PySide6 dans l environnement TwinBench...'
    & $VenvPython -m pip install --disable-pip-version-check 'PySide6>=6.10,<7'
    if ($LASTEXITCODE -ne 0) { throw 'Installation PySide6 impossible.' }
}

Write-Host '[EN COURS] Verification/construction de la FMU OpenModelica...'
& $VenvPython (Join-Path $ToolDir 'build_fmu.py')
if ($LASTEXITCODE -ne 0) { throw 'Construction FMU impossible.' }

Write-Host '[OK] Demarrage interface M3 live.' -ForegroundColor Green
& $VenvPython (Join-Path $ToolDir 'app.py')
if ($LASTEXITCODE -ne 0) { throw "L interface s est arretee avec le code $LASTEXITCODE." }
