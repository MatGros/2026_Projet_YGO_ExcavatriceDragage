param(
    [switch]$PlcReadonly
)

$ErrorActionPreference = 'Stop'

$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchM3Live'
$VenvDir = Join-Path $StateDir 'Python'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'

Write-Host '=== TWINBENCH M3 LIVE - POC LOCAL ===' -ForegroundColor Cyan
if ($PlcReadonly) {
    Write-Host '[INFO] Mode PLC LECTURE SEULE : aucune ecriture PLC.'
} else {
    Write-Host '[INFO] Aucun PLC ni CODESYS ne sera contacte.'
}

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

# Fermer proprement uniquement l'instance de cette application lancée avec le
# Python TwinBench dédié. Ne jamais terminer un Python global, CODESYS ou un PLC.
$AppPath = [System.IO.Path]::GetFullPath((Join-Path $ToolDir 'app.py'))
$PythonPath = [System.IO.Path]::GetFullPath($VenvPython)
$TwinBenchProcesses = @()
try {
    $TwinBenchProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" |
        Where-Object {
            $_.ExecutablePath -and
            [string]::Equals([System.IO.Path]::GetFullPath($_.ExecutablePath), $PythonPath,
                [System.StringComparison]::OrdinalIgnoreCase) -and
            $_.CommandLine -and
            $_.CommandLine.IndexOf($AppPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        })
}
catch {
    throw "Impossible de vérifier les instances TwinBench M3 ; aucun processus ne sera fermé. Détail : $($_.Exception.Message)"
}

foreach ($TwinBenchProcess in $TwinBenchProcesses) {
    $WindowProcess = Get-Process -Id $TwinBenchProcess.ProcessId -ErrorAction SilentlyContinue
    if (-not $WindowProcess) { continue }

    Write-Host "[INFO] Fermeture normale de TwinBench M3 (PID $($WindowProcess.Id))..."
    if (-not $WindowProcess.CloseMainWindow()) {
        throw "La fenêtre TwinBench M3 (PID $($WindowProcess.Id)) ne répond pas à la demande de fermeture. Ferme-la manuellement ; aucune fermeture forcée n'a été tentée."
    }
    $WindowProcess.WaitForExit(10000) | Out-Null
    if (-not $WindowProcess.HasExited) {
        throw "TwinBench M3 (PID $($WindowProcess.Id)) est encore ouvert après 10 s. Ferme-le manuellement ; aucune fermeture forcée n'a été tentée."
    }
    Write-Host '[OK] Ancienne fenêtre TwinBench M3 fermée proprement.' -ForegroundColor Green
}

if ($PlcReadonly) {
    # La vue lecture seule ne crée ni ne charge de FMU : elle attend uniquement
    # des trames UDP déjà publiées par la copie Control Win.
    Write-Host '[INFO] FMU non construite : la vue attend la télémétrie UDP locale.'
} else {
    Write-Host '[EN COURS] Verification/construction de la FMU OpenModelica...'
    & $VenvPython (Join-Path $ToolDir 'build_fmu.py')
    if ($LASTEXITCODE -ne 0) { throw 'Construction FMU impossible.' }
}

Write-Host '[OK] Demarrage interface M3 live.' -ForegroundColor Green
$AppArgs = @()
if ($PlcReadonly) { $AppArgs += '--plc-readonly' }
& $VenvPython (Join-Path $ToolDir 'app.py') @AppArgs
if ($LASTEXITCODE -ne 0) { throw "L interface s est arretee avec le code $LASTEXITCODE." }
