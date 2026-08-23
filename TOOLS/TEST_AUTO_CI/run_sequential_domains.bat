@echo off
setlocal
echo ==========================================================
echo   TEST_AUTO_CI : Sequenceur Unitaires par Domaine
echo ==========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$startTotal = [System.Diagnostics.Stopwatch]::StartNew();" ^
    "$scripts = Get-ChildItem -Path '%~dp0RESULTS' -Filter 'run.py' -Recurse;" ^
    "foreach ($s in $scripts) {" ^
    "    Write-Host '----------------------------------------------------------' -ForegroundColor Cyan;" ^
    "    Write-Host ('[EXECUTION DOMAINE] ' + $s.Directory.Parent.Name + ' (' + $s.FullName + ')') -ForegroundColor Yellow;" ^
    "    Write-Host '----------------------------------------------------------' -ForegroundColor Cyan;" ^
    "    $p = Start-Process -FilePath 'python' -ArgumentList @($s.FullName, '-j', '12') -NoNewWindow -Wait -PassThru;" ^
    "    Write-Host '';" ^
    "}" ^
    "$startTotal.Stop();" ^
    "$ts = $startTotal.Elapsed;" ^
    "$fmt = if ($ts.TotalMinutes -ge 1) { ('{0}m {1:d2}.{2:d2}s' -f [int]$ts.TotalMinutes, $ts.Seconds, [int]($ts.Milliseconds/10)) } else { ('{0:d2}.{1:d2}s' -f $ts.Seconds, [int]($ts.Milliseconds/10)) };" ^
    "Write-Host '==========================================================' -ForegroundColor Green;" ^
    "Write-Host ('  TEMPS TOTAL CUMULE DE TOUS LES DOMAINES : ' + $fmt) -ForegroundColor Green;" ^
    "Write-Host '==========================================================' -ForegroundColor Green;"

echo.
pause
