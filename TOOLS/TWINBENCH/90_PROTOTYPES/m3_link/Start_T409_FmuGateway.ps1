param(
    [double]$DurationSeconds = 0,
    [switch]$ResetPlant
)

$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = (Get-Command python -ErrorAction Stop).Source
$StateDir = Join-Path $env:LOCALAPPDATA 'TwinBenchT409'
$RunId = Get-Date -Format 'yyyyMMdd_HHmmss'
$Out = Join-Path $StateDir "fmu_${RunId}.stdout.log"
$Err = Join-Path $StateDir "fmu_${RunId}.stderr.log"
$Trace = Join-Path $StateDir "fmu_${RunId}.trace.csv"
$script = [System.IO.Path]::GetFullPath((Join-Path $ToolDir 'udp_m3_fmu_gateway.py'))
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
Write-Host '=== T409 - FMU M3 UDP LOOPBACK ===' -ForegroundColor Cyan
Write-Host '[SECURITE] 127.0.0.1:29061 uniquement. Aucun PLC reel.'
$existing = Get-NetUDPEndpoint -LocalAddress '127.0.0.1' -LocalPort 29061 -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    if (-not $ResetPlant) {
        Write-Host '[INFO] Une passerelle T409 est deja active sur 127.0.0.1:29061.' -ForegroundColor Yellow
        Write-Host '[ACTION] Reutilisation de l instance existante ; aucun second processus lance.'
        return
    }
    $expectedPython = [System.IO.Path]::GetFullPath($Python)
    $verifiedOwners = @()
    foreach ($endpoint in $existing) {
        $ownerPid = [int]$endpoint.OwningProcess
        $owner = Get-CimInstance Win32_Process -Filter "ProcessId = $ownerPid" -ErrorAction SilentlyContinue
        $exeMatches = $false
        if ($owner -and $owner.ExecutablePath) {
            $exeMatches = [string]::Equals([System.IO.Path]::GetFullPath($owner.ExecutablePath), $expectedPython,
                [System.StringComparison]::OrdinalIgnoreCase)
        }
        $commandMatches = $false
        if ($owner -and $owner.CommandLine) {
            $scriptMatches = $owner.CommandLine.IndexOf($script, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            $explicitDefaultPort = $owner.CommandLine -match '--listen-port(?:\s+|=)["'']?29061(?:["'']?)(?:\s|$)'
            # Les anciennes instances T409 n'avaient pas --listen-port et
            # utilisaient explicitement le port par défaut 29061 du protocole.
            $legacyDefaultPort = $owner.CommandLine -notmatch '--listen-port(?:\s+|=)'
            $commandMatches = $scriptMatches -and ($explicitDefaultPort -or $legacyDefaultPort)
        }
        if (-not $owner -or -not $exeMatches -or -not $commandMatches) {
            throw "Le port 29061 appartient au PID $ownerPid, qui n'est pas identifiable comme la passerelle T409 attendue. Aucun processus n'a ete arrete."
        }
        $verifiedOwners += $ownerPid
    }
    # Valider tous les propriétaires avant d'arrêter le moindre processus.
    foreach ($ownerPid in ($verifiedOwners | Select-Object -Unique)) {
        Write-Host "[RESET] Arret du seul processus passerelle T409 identifie (PID $ownerPid) pour repartir a P1..." -ForegroundColor Yellow
        Stop-Process -Id $ownerPid -Force
    }
    $deadline = (Get-Date).AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 200
        $existing = Get-NetUDPEndpoint -LocalAddress '127.0.0.1' -LocalPort 29061 -ErrorAction SilentlyContinue
    } while ($null -ne $existing -and (Get-Date) -lt $deadline)
    if ($null -ne $existing) { throw 'La passerelle T409 ne libere pas le port 29061. Aucun nouveau processus ne sera lance.' }
}
$p = Start-Process -FilePath $Python -ArgumentList @('"' + $script + '"', '--duration-s', $DurationSeconds, '--trace-file', $Trace, '--listen-port', '29061', '--ui-port', '29072') -WindowStyle Hidden -RedirectStandardOutput $Out -RedirectStandardError $Err -PassThru
Start-Sleep -Seconds 5
if ($p.HasExited) { throw "Gateway FMU arrete. Journal : $Err" }
if ($DurationSeconds -le 0) {
    Write-Host '[OK] Gateway FMU actif sans limite. Arret : Ctrl+C ou fermeture du processus.' -ForegroundColor Green
} else {
    Write-Host "[OK] Gateway FMU actif pour $DurationSeconds s." -ForegroundColor Green
}
Write-Host "Journal : $Out"
Write-Host "Trace  : $Trace"
