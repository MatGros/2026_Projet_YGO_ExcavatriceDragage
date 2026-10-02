param([int]$DurationSeconds = 0)

$ErrorActionPreference = 'Stop'
$PrototypeDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TwinBenchRoot = (Resolve-Path (Join-Path $PrototypeDir '..\..')).Path
$Live = Join-Path $TwinBenchRoot '02_SIM\modelica\live_poc'
$Link = Join-Path $TwinBenchRoot '90_PROTOTYPES\m3_link'
$VenvPython = Join-Path $env:LOCALAPPDATA 'TwinBenchM3Live\Python\Scripts\python.exe'
if (-not (Test-Path $VenvPython)) { throw 'L environnement TwinBench n est pas encore cree. Lancer Start_M3_Live.ps1 une fois.' }

$env:QT_QPA_PLATFORM = 'windows'
$demo = Start-Process -FilePath $VenvPython -ArgumentList @((Join-Path $Link 'plc_telemetry_demo.py'), '--duration-s', $DurationSeconds) -PassThru
try {
    & (Join-Path $Live 'Start_M3_Live.ps1') -PlcReadonly
} finally {
    if ($demo -and -not $demo.HasExited) { Stop-Process -Id $demo.Id -Force }
}
