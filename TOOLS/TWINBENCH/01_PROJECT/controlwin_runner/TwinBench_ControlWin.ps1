[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Import', 'Prepare', 'Deploy', 'Open', 'Status', 'SelfTest', 'Assistant')]
    [string]$Action = 'Menu',
    [string]$ProjectPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RunnerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $env:LOCALAPPDATA 'TwinBenchControlWin'
$ArchiveRoot = Join-Path $DataRoot 'Archives'
$CurrentRoot = Join-Path $DataRoot 'Current'
$LogRoot = Join-Path $DataRoot 'Logs'
$ImportedProject = Join-Path $CurrentRoot 'Imported_Source.project'
$CurrentProject = Join-Path $CurrentRoot 'TwinBench_ControlWin.project'
$ManifestPath = Join-Path $DataRoot 'manifest.json'
$HeadlessScript = Join-Path $RunnerRoot 'codesys_headless.py'
$SelfTestScript = Join-Path $RunnerRoot 'self_test.py'
$CodesysExe = 'C:\Program Files\CODESYS 3.5.19.10\CODESYS\Common\CODESYS.exe'
$CodesysProfile = 'CODESYS V3.5 SP19 Patch 1'
$ControlWinService = 'CODESYS Control Win V3 - x64'

function Initialize-Workspace {
    foreach ($path in @($DataRoot, $ArchiveRoot, $CurrentRoot, $LogRoot)) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
        }
    }
}

function Get-IsoTimestamp {
    return (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Get-FileHashHex([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return $null }
    return Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

function Write-Manifest([hashtable]$Values) {
    $current = @{}
    $old = Read-Manifest
    if ($null -ne $old) {
        foreach ($property in $old.PSObject.Properties) {
            $current[$property.Name] = $property.Value
        }
    }
    foreach ($key in $Values.Keys) { $current[$key] = $Values[$key] }
    $current['updated_at'] = Get-IsoTimestamp
    $current | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Get-WorkflowState {
    $manifest = Read-Manifest
    if ($null -eq $manifest -or [string]::IsNullOrWhiteSpace([string]$manifest.state)) {
        return 'EMPTY'
    }
    return [string]$manifest.state
}

function Add-ActionHistory(
    [string]$ActionName,
    [string]$Outcome,
    [string]$StateBefore,
    [string]$StateAfter,
    [string]$Detail
) {
    $manifest = Read-Manifest
    if ($null -eq $manifest) { return }
    $history = @()
    if ($manifest.PSObject.Properties.Name -contains 'history') {
        $history = @($manifest.history)
    }
    $history += [ordered]@{
        at = Get-IsoTimestamp
        action = $ActionName
        outcome = $Outcome
        state_before = $StateBefore
        state_after = $StateAfter
        detail = $Detail
    }
    if ($history.Count -gt 30) { $history = @($history | Select-Object -Last 30) }
    Write-Manifest @{ history = $history }
}

function Get-AllowedChoices([string]$State) {
    switch ($State) {
        'EMPTY' { return @('1', '5', '6', '8', '10', '0') }
        'IMPORTED' { return @('1', '2', '5', '6', '8', '9', '10', '0') }
        'PREPARE_FAILED' { return @('1', '4', '5', '6', '7', '9', '10', '0') }
        'PREPARED' { return @('1', '2', '3', '4', '5', '6', '8', '9', '10', '0') }
        'DEPLOYED' { return @('1', '4', '5', '6', '8', '10', '0') }
        default { return @('1', '5', '6', '8', '10', '0') }
    }
}

function Write-WorkflowLine([string]$Marker, [string]$Text, [ConsoleColor]$Color) {
    Write-Host ("[{0}] {1}" -f $Marker, $Text) -ForegroundColor $Color
}

function Write-FileLink([string]$Label, [string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host ("[INFO] {0}: file unavailable ({1})" -f $Label, $Path) -ForegroundColor Yellow
        return
    }
    $absolutePath = (Resolve-Path -LiteralPath $Path).Path
    $uri = [Uri]::new($absolutePath).AbsoluteUri
    $escape = [char]27
    Write-Host ("{0}]8;;{1}{0}\{2}{0}]8;;{0}\" -f $escape, $uri, $Label) -ForegroundColor Cyan
    Write-Host ("  {0}" -f $absolutePath) -ForegroundColor DarkGray
}

function Show-WorkflowStatus {
    $state = Get-WorkflowState
    Write-Host ("Current state: {0}" -f $state) -ForegroundColor Cyan
    switch ($state) {
        'EMPTY' {
            Write-WorkflowLine 'TODO' '1. Select and copy a source project' Yellow
            Write-WorkflowLine 'LOCKED' '2. Prepare - no project imported' DarkGray
            Write-WorkflowLine 'LOCKED' '3. Deploy - no prepared copy' DarkGray
            Write-WorkflowLine 'LOCKED' '4. Open - no copy available' DarkGray
        }
        'IMPORTED' {
            Write-WorkflowLine 'DONE' '1. Source project copied and fingerprint verified' Green
            Write-WorkflowLine 'TODO' '2. Prepare and compile the Control Win copy' Yellow
            Write-WorkflowLine 'LOCKED' '3. Deploy - preparation not validated' DarkGray
            Write-WorkflowLine 'LOCKED' '4. Open - Control Win copy not validated' DarkGray
        }
        'PREPARE_FAILED' {
            Write-WorkflowLine 'DONE' '1. Source project copied and fingerprint verified' Green
            Write-WorkflowLine 'FAILED' '2. Preparation rejected - retry locked' Red
            Write-WorkflowLine 'LOCKED' '3. Deploy - compilation not validated' DarkGray
            Write-WorkflowLine 'AVAILABLE' '4. Open the copy for diagnostics only' Yellow
            Write-WorkflowLine 'ACTION' '7. Unlock a retry only after fixing the cause' Yellow
        }
        'PREPARED' {
            Write-WorkflowLine 'DONE' '1. Source project copied and fingerprint verified' Green
            Write-WorkflowLine 'DONE' '2. Control Win copy compiled without errors' Green
            Write-WorkflowLine 'TODO' '3. Deploy and start local Control Win' Yellow
            Write-WorkflowLine 'AVAILABLE' '4. Open the copy in CODESYS' Yellow
        }
        'DEPLOYED' {
            Write-WorkflowLine 'DONE' '1. Source project copied and fingerprint verified' Green
            Write-WorkflowLine 'DONE' '2. Control Win copy compiled without errors' Green
            Write-WorkflowLine 'DONE' '3. Copy deployed to local Control Win' Green
            Write-WorkflowLine 'TODO' '4. Open the copy for online monitoring' Yellow
        }
        default {
            Write-WorkflowLine 'UNKNOWN' 'Unrecognized state: diagnostic actions only' Red
        }
    }
}

function Assert-SourceUnchanged {
    $manifest = Read-Manifest
    if ($null -eq $manifest -or [string]::IsNullOrWhiteSpace([string]$manifest.source_path)) { return }
    if (-not (Test-Path -LiteralPath $manifest.source_path)) {
        throw 'INTEGRITY ALERT: source project is missing.'
    }
    $actual = Get-FileHashHex ([string]$manifest.source_path)
    if ($actual -ne [string]$manifest.source_sha256) {
        throw 'INTEGRITY ALERT: source project changed. All actions are blocked.'
    }
}

function Find-Codesys {
    if (Test-Path -LiteralPath $CodesysExe) { return $CodesysExe }
    throw "CODESYS.exe 3.5.19.10 was not found: $CodesysExe"
}

function Select-ProjectFile {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select the CODESYS project to COPY for TwinBench'
    $dialog.Filter = 'CODESYS project (*.project;*.projectarchive)|*.project;*.projectarchive'
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Selection cancelled. No file was changed.'
    }
    return $dialog.FileName
}

function Invoke-CodesysHeadless([string]$Mode, [string]$InputPath = '', [string]$WorkingProject = $CurrentProject) {
    $exe = Find-Codesys
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $report = Join-Path $LogRoot ("{0}_{1}.json" -f $stamp, $Mode.ToLowerInvariant())
    $textLog = Join-Path $LogRoot ("{0}_{1}.log" -f $stamp, $Mode.ToLowerInvariant())
    $stdoutLog = Join-Path $LogRoot ("{0}_{1}_stdout.log" -f $stamp, $Mode.ToLowerInvariant())
    $stderrLog = Join-Path $LogRoot ("{0}_{1}_stderr.log" -f $stamp, $Mode.ToLowerInvariant())

    Write-Host ("[IN PROGRESS] CODESYS: {0}. This may take a few minutes..." -f $Mode) -ForegroundColor Cyan
    Write-Host ("Log: {0}" -f $textLog)

    $oldAction = $env:TB_ACTION
    $oldProject = $env:TB_PROJECT
    $oldInput = $env:TB_INPUT
    $oldReport = $env:TB_REPORT
    $oldUser = $env:TB_USERNAME
    $oldPassword = $env:TB_PASSWORD
    $process = $null
    try {
        $env:TB_ACTION = $Mode
        $env:TB_PROJECT = $WorkingProject
        $env:TB_INPUT = $InputPath
        $env:TB_REPORT = $report
        $codesysArguments = @(
            ('--profile="{0}"' -f $CodesysProfile)
            ('--runscript="{0}"' -f $HeadlessScript)
            '--noUI'
        )
        $process = Start-Process -FilePath $exe `
            -ArgumentList $codesysArguments `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError $stderrLog `
            -WindowStyle Hidden `
            -PassThru
        if (Test-Path -LiteralPath $ManifestPath) {
            Write-Manifest @{ headless_pid = $process.Id; headless_action = $Mode }
        }
        $startedAt = Get-Date
        $nextProgressAt = 5
        while (-not $process.HasExited) {
            Start-Sleep -Seconds 1
            $elapsedSeconds = [int]((Get-Date) - $startedAt).TotalSeconds
            if ($elapsedSeconds -ge $nextProgressAt) {
                Write-Host ("[IN PROGRESS] CODESYS: {0} - {1} seconds elapsed..." -f $Mode, $elapsedSeconds) -ForegroundColor Cyan
                $nextProgressAt += 5
            }
        }
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        @(
            Get-Content -LiteralPath $stdoutLog -ErrorAction SilentlyContinue
            Get-Content -LiteralPath $stderrLog -ErrorAction SilentlyContinue
        ) | Set-Content -LiteralPath $textLog -Encoding UTF8
    }
    finally {
        if (Test-Path -LiteralPath $ManifestPath) {
            Write-Manifest @{ headless_pid = $null; headless_action = $null }
        }
        $env:TB_ACTION = $oldAction
        $env:TB_PROJECT = $oldProject
        $env:TB_INPUT = $oldInput
        $env:TB_REPORT = $oldReport
        $env:TB_USERNAME = $oldUser
        $env:TB_PASSWORD = $oldPassword
    }

    if (-not (Test-Path -LiteralPath $report)) {
        throw "CODESYS produced no report. See $textLog"
    }
    $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Write-Host ("Report: {0}" -f $report)
    if (-not $result.success) {
        throw ("Failed {0}: {1}" -f $Mode, $result.error)
    }
    if ($null -ne $exitCode -and -not [string]::IsNullOrWhiteSpace([string]$exitCode) -and [int]$exitCode -ne 0) {
        throw "CODESYS returned exit code $exitCode. See $textLog"
    }
    Write-Host ("[DONE] CODESYS: {0}." -f $Mode) -ForegroundColor Green
    return $result
}

function Backup-CurrentCopy([string]$Reason) {
    if (-not (Test-Path -LiteralPath $CurrentProject)) { return }
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $dir = Join-Path $ArchiveRoot ("{0}_{1}" -f $stamp, $Reason)
    New-Item -ItemType Directory -Path $dir | Out-Null
    Copy-Item -LiteralPath $CurrentProject -Destination (Join-Path $dir 'TwinBench_ControlWin.project')
    Get-ChildItem -LiteralPath $CurrentRoot -Filter '*.compileinfo' -ErrorAction SilentlyContinue |
        Copy-Item -Destination $dir
}

function Archive-CandidateArtifacts([string]$Reason) {
    $candidateFiles = @(Get-ChildItem -LiteralPath $CurrentRoot -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'TwinBench_ControlWin_candidate_*' })
    if ($candidateFiles.Count -eq 0) { return '' }
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $archiveDir = Join-Path $ArchiveRoot ("{0}_{1}" -f $stamp, $Reason)
    New-Item -ItemType Directory -Path $archiveDir | Out-Null
    foreach ($file in $candidateFiles) {
        Move-Item -LiteralPath $file.FullName -Destination (Join-Path $archiveDir $file.Name)
    }
    Write-Host ("[ARCHIVED] {0} candidate artifact(s) moved to: {1}" -f $candidateFiles.Count, $archiveDir) -ForegroundColor DarkCyan
    return $archiveDir
}

function Stop-TrackedTwinBenchProcess {
    $manifest = Read-Manifest
    if ($null -eq $manifest) { return }
    foreach ($propertyName in @('headless_pid', 'ide_pid')) {
        if ($manifest.PSObject.Properties.Name -notcontains $propertyName) { continue }
        $pidValue = [int]$manifest.$propertyName
        if ($pidValue -le 0) { continue }
        $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        if ($process.ProcessName -notlike 'CODESYS*') {
            throw ("Safety refusal: tracked PID {0} is not CODESYS ({1})." -f $pidValue, $process.ProcessName)
        }
        Write-Host ("[RECOVERY] Stopping tracked TwinBench CODESYS process (PID {0})." -f $pidValue) -ForegroundColor Yellow
        Stop-Process -Id $pidValue -Force
    }
}

function Recover-TwinBenchWorkspace([switch]$Confirmed) {
    Initialize-Workspace
    Assert-SourceUnchanged
    $state = Get-WorkflowState
    if ($state -eq 'EMPTY') { throw 'There is no TwinBench workspace to recover.' }
    if (-not $Confirmed) {
        $confirmation = Read-Host 'Type ARCHIVE to release the copy and archive its leftovers, or press ENTER to cancel'
        if ($confirmation -cne 'ARCHIVE' -and $confirmation -cne 'ARCHIVER') {
            Write-Host '[INFO] Recovery cancelled. No files or processes were touched.' -ForegroundColor Yellow
            return
        }
    }
    Stop-TrackedTwinBenchProcess
    Start-Sleep -Milliseconds 500
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $recoveryDir = Join-Path $ArchiveRoot ("{0}_recovery" -f $stamp)
    New-Item -ItemType Directory -Path $recoveryDir | Out-Null
    $staleFiles = Get-ChildItem -LiteralPath $CurrentRoot -File | Where-Object {
        $_.Name -match '^TwinBench_ControlWin' -or
        $_.Name -match '_candidate_' -or
        $_.Name -match '\.~u$' -or
        $_.Name -match '\.precompilecache$'
    }
    foreach ($file in $staleFiles) {
        Move-Item -LiteralPath $file.FullName -Destination (Join-Path $recoveryDir $file.Name)
    }
    Write-Manifest @{
        state = 'IMPORTED'
        prepared_sha256 = ''
        deployed_sha256 = ''
        recovery_archive = $recoveryDir
        recovery_at = Get-IsoTimestamp
    }
    Write-Host ("[PASS] Workspace released. Leftovers archived in: {0}" -f $recoveryDir) -ForegroundColor Green
    Write-Host '[PASS] Source project preserved. A clean preparation can now start.' -ForegroundColor Green
}

function Invoke-WorkspaceAssistant {
    Initialize-Workspace
    $manifest = Read-Manifest
    $state = Get-WorkflowState
    Write-Host '=== TWINBENCH ASSISTANT: SAFE DIAGNOSTIC ===' -ForegroundColor Cyan
    Write-Host ("Manifest: {0}" -f $ManifestPath)
    Write-Host ("Actual state: {0}" -f $state)
    if ($null -eq $manifest) {
        Write-Host '[ACTION] No project imported: choose 1.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'PREPARED') {
        if (-not (Test-Path -LiteralPath $CurrentProject)) {
            Write-Host '[FAIL] Prepared copy is missing. Choose 9, then ARCHIVE, to recover safely.' -ForegroundColor Red
            return
        }
        $actualHash = Get-FileHashHex $CurrentProject
        if ($actualHash -ne [string]$manifest.prepared_sha256) {
            Write-Host '[FAIL] Copy changed after preparation. Choose 9, then ARCHIVE; do not deploy.' -ForegroundColor Red
            return
        }
        Write-Host '[PASS] Prepared copy is healthy; no recovery is needed.' -ForegroundColor Green
        Write-Host '[ACTION] Next step: choose 3 to deploy to local Control Win.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'PREPARE_FAILED') {
        Write-Host '[BLOCKED] Preparation failed; do not retry blindly.' -ForegroundColor Red
        Write-Host '[ACTION] Choose 4 to inspect the failure. Choose 9 and ARCHIVE only after fixing its cause.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'DEPLOYED') {
        Write-Host '[PASS] Control Win is already deployed; choose 4 to open the copy.' -ForegroundColor Green
        return
    }
    Write-Host '[ACTION] Follow the next step shown in the menu.' -ForegroundColor Yellow
}

function Invoke-SimpleWorkflow {
    while ($true) {
        $state = Get-WorkflowState
        switch ($state) {
            'EMPTY' {
                Write-Host '[IN PROGRESS] Select the project to load into Control Win.' -ForegroundColor Cyan
                Import-Project ''
                continue
            }
            'IMPORTED' {
                Write-Host '[IN PROGRESS] Preparing and compiling the Control Win copy.' -ForegroundColor Cyan
                Prepare-ControlWinCopy
                continue
            }
            'PREPARE_FAILED' {
                Write-Host '[ACTION REQUIRED] A previous copy failed. I can archive that copy and retry cleanly.' -ForegroundColor Yellow
                $repair = Read-Host 'Type REPAIR to continue, or press ENTER to cancel'
                if ($repair -cne 'REPAIR' -and $repair -cne 'REPARER') {
                    Write-Host '[INFO] Nothing was changed.' -ForegroundColor Yellow
                    return
                }
                Recover-TwinBenchWorkspace -Confirmed
                continue
            }
            'PREPARED' {
                Write-Host '[ACTION REQUIRED] Copy compiled. Type DEPLOY to load it on local Control Win, or press ENTER to cancel.' -ForegroundColor Yellow
                $deploy = Read-Host 'Confirmation'
                if ($deploy -cne 'DEPLOY' -and $deploy -cne 'DEPLOYER') {
                    Write-Host '[INFO] Deployment cancelled. The real PLC was not contacted.' -ForegroundColor Yellow
                    return
                }
                Deploy-ControlWinCopy
                continue
            }
            'DEPLOYED' {
                Write-Host '[IN PROGRESS] Opening the deployed Control Win copy.' -ForegroundColor Cyan
                Open-CurrentCopy
                return
            }
            default {
                throw ("Unknown TwinBench state: {0}. Use the Assistant action for diagnostics." -f $state)
            }
        }
    }
}

function Import-Project([string]$SourcePath) {
    Initialize-Workspace
    if ([string]::IsNullOrWhiteSpace($SourcePath)) { $SourcePath = Select-ProjectFile }
    $source = (Resolve-Path -LiteralPath $SourcePath).Path
    $extension = [IO.Path]::GetExtension($source).ToLowerInvariant()
    if ($extension -notin @('.project', '.projectarchive')) {
        throw 'Only .project and .projectarchive files are supported.'
    }
    if ($source.StartsWith($DataRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The source file must not come from the TwinBench workspace.'
    }

    $sourceHashBefore = Get-FileHashHex $source
    $existingManifest = Read-Manifest
    if ($null -ne $existingManifest `
        -and [string]::Equals([string]$existingManifest.source_path, $source, [StringComparison]::OrdinalIgnoreCase) `
        -and [string]$existingManifest.source_sha256 -eq $sourceHashBefore `
        -and (Test-Path -LiteralPath $ImportedProject) `
        -and (Get-FileHashHex $ImportedProject) -eq [string]$existingManifest.imported_sha256) {
        Write-Host '[INFO] This project is already imported and its fingerprint matches.' -ForegroundColor Green
        Write-Host ("State preserved: {0}" -f $existingManifest.state)
        Write-Host 'No copy or preparation was repeated.'
        return
    }

    Backup-CurrentCopy 'avant_import'
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $archiveDir = Join-Path $ArchiveRoot ("{0}_source" -f $stamp)
    New-Item -ItemType Directory -Path $archiveDir | Out-Null
    $archivedSource = Join-Path $archiveDir ([IO.Path]::GetFileName($source))
    Copy-Item -LiteralPath $source -Destination $archivedSource

    if ($extension -eq '.project') {
        Copy-Item -LiteralPath $archivedSource -Destination $ImportedProject -Force
    }
    else {
        $null = Invoke-CodesysHeadless -Mode 'extract' -InputPath $archivedSource -WorkingProject $ImportedProject
    }

    $sourceHashAfter = Get-FileHashHex $source
    if ($sourceHashBefore -ne $sourceHashAfter) {
        throw 'ALERT: source project fingerprint changed during copying.'
    }
    $copyHash = Get-FileHashHex $ImportedProject
    Write-Manifest @{
        source_path = $source
        source_sha256 = $sourceHashBefore
        archived_source = $archivedSource
        imported_project = $ImportedProject
        current_project = $CurrentProject
        imported_sha256 = $copyHash
        prepared_sha256 = ''
        deployed_sha256 = ''
        state = 'IMPORTED'
    }
    Write-Host '[PASS] Original unchanged. TwinBench copy created.' -ForegroundColor Green
    Write-FileLink 'Open source copy' $ImportedProject
    $result = Invoke-CodesysHeadless -Mode 'inspect' -WorkingProject $ImportedProject
    Write-Host ("Current device: {0}" -f $result.device_identification)
}

function Prepare-ControlWinCopy {
    Initialize-Workspace
    Assert-SourceUnchanged
    if (-not (Test-Path -LiteralPath $ImportedProject)) { throw 'No source copy has been imported.' }
    Backup-CurrentCopy 'avant_prepare'
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $candidate = Join-Path $CurrentRoot ("TwinBench_ControlWin_candidate_{0}.project" -f $stamp)
    try {
        $result = Invoke-CodesysHeadless -Mode 'prepare' -InputPath $ImportedProject -WorkingProject $candidate
    }
    catch {
        $failedArchive = Archive-CandidateArtifacts 'prepare_echec'
        Write-Manifest @{
            state = 'PREPARE_FAILED'
            prepared_sha256 = ''
            deployed_sha256 = ''
            candidate_archive = $failedArchive
        }
        throw
    }
    finally {
        Assert-SourceUnchanged
    }
    if (Test-Path -LiteralPath $CurrentProject) {
        $oldDir = Join-Path $ArchiveRoot ("{0}_ancien_controlwin" -f $stamp)
        New-Item -ItemType Directory -Path $oldDir | Out-Null
        Move-Item -LiteralPath $CurrentProject -Destination (Join-Path $oldDir 'TwinBench_ControlWin.project')
    }
    Move-Item -LiteralPath $candidate -Destination $CurrentProject
    $candidateArchive = Archive-CandidateArtifacts 'prepare_terminee'
    $hash = Get-FileHashHex $CurrentProject
    Write-Manifest @{
        prepared_sha256 = $hash
        deployed_sha256 = ''
        state = 'PREPARED'
        prepare_report = $result.report_path
        build_errors = $result.error_count
        build_warnings = $result.warning_count
        hw_sim_bool_symbols = $result.hw_sim_compat.bool_symbols
        hw_sim_typed_symbols = $result.hw_sim_compat.typed_symbols
        candidate_archive = $candidateArchive
    }
    Write-Host ("[PASS] Control Win copy prepared. Errors={0}, warnings={1}" -f $result.error_count, $result.warning_count) -ForegroundColor Green
    Write-Host ("[HW_SIM] Adapted {0} BOOL + {1} typed values in the copy only." -f $result.hw_sim_compat.bool_symbols, $result.hw_sim_compat.typed_symbols) -ForegroundColor Green
    Write-FileLink 'Open Control Win copy' $CurrentProject
}

function Start-ControlWin {
    $service = Get-Service -Name $ControlWinService -ErrorAction Stop
    if ($service.Status -eq 'Running') { return }
    try {
        Start-Service -Name $ControlWinService
    }
    catch {
        Write-Host 'Windows elevation is required to start Control Win.' -ForegroundColor Yellow
        $command = "Start-Service -Name '$ControlWinService'"
        $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile', '-Command', $command)
        if ($process.ExitCode -ne 0) { throw 'Elevated Control Win startup was refused or failed.' }
    }
    (Get-Service -Name $ControlWinService).WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
}

function Deploy-ControlWinCopy {
    Initialize-Workspace
    Assert-SourceUnchanged
    $manifest = Read-Manifest
    if ($null -eq $manifest -or $manifest.state -ne 'PREPARED') {
        throw 'The copy must be prepared successfully before deployment.'
    }
    $currentHash = Get-FileHashHex $CurrentProject
    if ($currentHash -ne $manifest.prepared_sha256) {
        throw 'The copy changed after preparation. Run PREPARE again.'
    }
    if ([int]$manifest.build_errors -ne 0) {
        throw 'Deployment refused: compilation has errors.'
    }

    Start-ControlWin
    $credential = Get-Credential -Message 'LOCAL CODESYS Control Win account (never the real PLC)'
    $env:TB_USERNAME = $credential.UserName
    $env:TB_PASSWORD = $credential.GetNetworkCredential().Password
    try {
        $result = Invoke-CodesysHeadless -Mode 'deploy'
    }
    finally {
        $env:TB_USERNAME = $null
        $env:TB_PASSWORD = $null
        Assert-SourceUnchanged
    }
    $hash = Get-FileHashHex $CurrentProject
    Write-Manifest @{
        deployed_sha256 = $hash
        prepared_sha256 = $hash
        state = 'DEPLOYED'
        deploy_report = $result.report_path
        deployed_target = $result.scanned_target
        deployed_application_state = $result.application_state
        deployed_local_user = $result.logged_user
    }
    Write-Host '[PASS] Copy deployed and started on local Control Win.' -ForegroundColor Green
    Write-Host '[PROOF] Loaded copy (link below):' -ForegroundColor Green
    Write-FileLink 'Open deployed Control Win copy' $CurrentProject
    Write-Host ("[PROOF] Target: {0}" -f $result.scanned_target) -ForegroundColor Green
    Write-Host ("[PROOF] Application state: {0}" -f $result.application_state) -ForegroundColor Green
    Write-Host ("[PROOF] Local user: {0}" -f $result.logged_user) -ForegroundColor Green
}

function Open-CurrentCopy {
    Assert-SourceUnchanged
    if (-not (Test-Path -LiteralPath $CurrentProject)) { throw 'No TwinBench copy is available.' }
    $exe = Find-Codesys
    $process = Start-Process -FilePath $exe -ArgumentList @("--profile=$CodesysProfile", $CurrentProject) -PassThru
    if (Test-Path -LiteralPath $ManifestPath) {
        Write-Manifest @{ ide_pid = $process.Id }
    }
    Write-Host 'CODESYS opened the TwinBench copy. Use Online > Login to monitor it.' -ForegroundColor Green
}

function Show-Status {
    Initialize-Workspace
    Write-Host "Workspace: $DataRoot"
    $manifest = Read-Manifest
    if ($null -eq $manifest) { Write-Host 'State: no project imported.'; return }
    Show-WorkflowStatus
    Write-Host ("Source: {0}" -f $manifest.source_path)
    Write-Host ("Last updated: {0}" -f $manifest.updated_at)
    if (Test-Path -LiteralPath $CurrentProject) {
        Write-Host ("SHA-256 actuel : {0}" -f (Get-FileHashHex $CurrentProject))
    Write-FileLink 'Open Control Win copy' $CurrentProject
    }
    if ($manifest.PSObject.Properties.Name -contains 'hw_sim_bool_symbols') {
        Write-Host ("HW_SIM adapter: {0} BOOL + {1} typed values (copy only)" -f $manifest.hw_sim_bool_symbols, $manifest.hw_sim_typed_symbols)
    }
    if ($manifest.PSObject.Properties.Name -contains 'deployed_target') {
        Write-Host ("Deployed target: {0}" -f $manifest.deployed_target)
        Write-Host ("Application state: {0}" -f $manifest.deployed_application_state)
        Write-Host ("Local user: {0}" -f $manifest.deployed_local_user)
    }
    if ($manifest.PSObject.Properties.Name -contains 'history') {
        Write-Host 'Recent actions:'
        @($manifest.history) | Select-Object -Last 5 | ForEach-Object {
            Write-Host ("  {0} | {1} | {2} | {3} -> {4}" -f $_.at, $_.outcome, $_.action, $_.state_before, $_.state_after)
        }
    }
}

function Show-RecentEvents {
    $manifest = Read-Manifest
    if ($null -eq $manifest -or $manifest.PSObject.Properties.Name -notcontains 'history') { return }
    Write-Host '--- RECENT EVENTS ---' -ForegroundColor DarkCyan
    @($manifest.history) | Select-Object -Last 6 | ForEach-Object {
        $color = if ([string]$_.outcome -eq 'FAIL') { [ConsoleColor]::Red } else { [ConsoleColor]::Gray }
        Write-Host ("{0} | {1} | action {2} | {3} -> {4}" -f $_.at, $_.outcome, $_.action, $_.state_before, $_.state_after) -ForegroundColor $color
        if (-not [string]::IsNullOrWhiteSpace([string]$_.detail)) {
            Write-Host ("  details: {0}" -f $_.detail) -ForegroundColor $color
        }
    }
}

function Invoke-SelfTest {
    & python $SelfTestScript
    if ($LASTEXITCODE -ne 0) { throw 'Runner self-test failed.' }
}

function Unlock-PrepareRetry {
    if ((Get-WorkflowState) -ne 'PREPARE_FAILED') {
        throw 'Retry is only available after a preparation failure.'
    }
    $confirmation = Read-Host 'Type RETRY only after fixing the cause of the failure'
    if ($confirmation -cnotin @('RETRY', 'REESSAYER')) {
        throw 'Retry cancelled. PREPARE_FAILED state preserved.'
    }
    Write-Manifest @{
        state = 'IMPORTED'
        prepared_sha256 = ''
        deployed_sha256 = ''
    }
    Write-Host '[PASS] A new preparation attempt is enabled. No project file was changed.' -ForegroundColor Green
}

function Invoke-GuidedWorkflow {
    Write-Host '=== GUIDED MODE: COMPLETE WORKFLOW ===' -ForegroundColor Cyan
    $state = Get-WorkflowState

    if ($state -eq 'EMPTY') {
        Write-Host '[GUIDE 1/4] Import and diagnose the source copy.' -ForegroundColor Cyan
        Import-Project ''
        $state = Get-WorkflowState
    }
    elseif ($state -eq 'IMPORTED') {
        Write-Host '[GUIDE 1/4] Source copy is already available.' -ForegroundColor Green
    }
    elseif ($state -eq 'PREPARE_FAILED') {
        throw 'Guided workflow stopped: preparation failed. Fix the cause, choose 7, then retry 8.'
    }
    elseif ($state -eq 'PREPARED' -or $state -eq 'DEPLOYED') {
        Write-Host '[GUIDE 1/4] Copy is already prepared.' -ForegroundColor Green
    }

    $state = Get-WorkflowState
    if ($state -eq 'IMPORTED') {
        Write-Host '[GUIDE 2/4] Prepare and compile for Control Win.' -ForegroundColor Cyan
        Prepare-ControlWinCopy
        $state = Get-WorkflowState
    }
    if ($state -ne 'PREPARED' -and $state -ne 'DEPLOYED') {
        throw ("Guided workflow stopped in state {0}." -f $state)
    }

    if ($state -eq 'PREPARED') {
        Write-Host '[GUIDE 3/4] Preparation validated.' -ForegroundColor Green
        $confirmation = Read-Host 'Type DEPLOY to start local Control Win, or press ENTER to stop here'
        if ($confirmation -cnotin @('DEPLOY', 'DEPLOYER')) {
            Write-Host '[GUIDE] Stopped before deployment. PREPARED state preserved.' -ForegroundColor Yellow
            return
        }
        Deploy-ControlWinCopy
    }
    else {
        Write-Host '[GUIDE 3/4] Copy is already deployed.' -ForegroundColor Green
    }

    Write-Host '[GUIDE 4/4] Open the copy in CODESYS.' -ForegroundColor Cyan
    Open-CurrentCopy
    Write-Host '[GUIDE COMPLETE] Workflow finished.' -ForegroundColor Green
}

function Show-NextRecommendedAction {
    $manifest = Read-Manifest
    if ($null -eq $manifest) {
        Write-Host 'Recommended next step: 1 - Import a project.' -ForegroundColor Yellow
        return
    }
    switch ([string]$manifest.state) {
        'IMPORTED' {
            Write-Host 'Recommended next step: 2 - Prepare the Control Win copy.' -ForegroundColor Yellow
        }
        'PREPARE_FAILED' {
            Write-Host 'Preparation blocked: inspect the diagnostic. Do not deploy.' -ForegroundColor Red
        }
        'PREPARED' {
            Write-Host 'Recommended next step: 3 - Deploy to local Control Win.' -ForegroundColor Yellow
        }
        'DEPLOYED' {
            Write-Host 'Recommended next step: 4 - Open the copy in CODESYS.' -ForegroundColor Yellow
        }
        default {
            Write-Host ("Current state: {0}" -f $manifest.state) -ForegroundColor Yellow
        }
    }
}

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Host '=== TWINBENCH CONTROL WIN - ISOLATED COPY ===' -ForegroundColor Cyan
        $state = Get-WorkflowState
        Write-Host ("Current state: {0}" -f $state) -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'ENTER   Continue: load the project into Control Win' -ForegroundColor Green
        Write-Host '0       Exit' -ForegroundColor DarkGray
        $choice = Read-Host 'Action'
        if ($choice -eq '0') { return }
        if (-not [string]::IsNullOrWhiteSpace($choice)) {
            Write-Host '[INFO] Press ENTER to continue.' -ForegroundColor Yellow
            continue
        }
        try {
            Invoke-SimpleWorkflow
        }
        catch {
            Write-Host ("[REFUSED/ERROR] {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
}

Initialize-Workspace
switch ($Action) {
    'Menu' { Show-Menu }
    'Import' { Import-Project $ProjectPath }
    'Prepare' { Prepare-ControlWinCopy }
    'Deploy' { Deploy-ControlWinCopy }
    'Open' { Open-CurrentCopy }
    'Status' { Show-Status }
    'SelfTest' { Invoke-SelfTest }
    'Assistant' { Invoke-WorkspaceAssistant }
}
