$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = (Get-Command python -ErrorAction Stop).Source
$tests = @(
    'check_t409_pou_static.py',
    'test_t409_protocol.py',
    'test_t409_fmu_scenarios.py',
    'test_t409_gateway_roundtrip.py',
    'test_t409_recovery.py'
)
Write-Host '=== T409 - VERIFICATION FMU M3 COMPLETE ===' -ForegroundColor Cyan
Write-Host '[SECURITE] Tests locaux uniquement ; aucun PLC/CODESYS contacte.'
$failed = @()
foreach ($test in $tests) {
    Write-Host "[EN COURS] $test"
    & $Python (Join-Path $ToolDir $test)
    if ($LASTEXITCODE -ne 0) {
        $failed += $test
        Write-Host "[FAIL] $test" -ForegroundColor Red
    } else {
        Write-Host "[PASS] $test" -ForegroundColor Green
    }
}
if ($failed.Count -gt 0) {
    Write-Host "[VERDICT] ECHEC : $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host '[VERDICT] PASS : protocole, cinematique, UDP 10 ms et reprise valides.' -ForegroundColor Green
