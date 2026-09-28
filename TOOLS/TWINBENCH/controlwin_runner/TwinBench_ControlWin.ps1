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
        Write-Host ("[INFO] {0} : fichier indisponible ({1})" -f $Label, $Path) -ForegroundColor Yellow
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
    Write-Host ("Etat courant : {0}" -f $state) -ForegroundColor Cyan
    switch ($state) {
        'EMPTY' {
            Write-WorkflowLine 'A FAIRE' '1. Choisir et copier un projet source' Yellow
            Write-WorkflowLine 'VERROUILLE' '2. Preparer - aucun projet importe' DarkGray
            Write-WorkflowLine 'VERROUILLE' '3. Deployer - aucune copie preparee' DarkGray
            Write-WorkflowLine 'VERROUILLE' '4. Ouvrir - aucune copie disponible' DarkGray
        }
        'IMPORTED' {
            Write-WorkflowLine 'FAIT' '1. Projet source copie et empreinte verifiee' Green
            Write-WorkflowLine 'A FAIRE' '2. Preparer et compiler la copie Control Win' Yellow
            Write-WorkflowLine 'VERROUILLE' '3. Deployer - preparation non validee' DarkGray
            Write-WorkflowLine 'VERROUILLE' '4. Ouvrir - copie Control Win non validee' DarkGray
        }
        'PREPARE_FAILED' {
            Write-WorkflowLine 'FAIT' '1. Projet source copie et empreinte verifiee' Green
            Write-WorkflowLine 'ECHEC' '2. Preparation refusee - nouvelle tentative verrouillee' Red
            Write-WorkflowLine 'VERROUILLE' '3. Deployer - compilation non validee' DarkGray
            Write-WorkflowLine 'DISPONIBLE' '4. Ouvrir la copie uniquement pour diagnostic' Yellow
            Write-WorkflowLine 'ACTION' '7. Rearmer une tentative, uniquement apres correction' Yellow
        }
        'PREPARED' {
            Write-WorkflowLine 'FAIT' '1. Projet source copie et empreinte verifiee' Green
            Write-WorkflowLine 'FAIT' '2. Copie Control Win compilee sans erreur' Green
            Write-WorkflowLine 'A FAIRE' '3. Deployer et demarrer Control Win local' Yellow
            Write-WorkflowLine 'DISPONIBLE' '4. Ouvrir la copie dans CODESYS' Yellow
        }
        'DEPLOYED' {
            Write-WorkflowLine 'FAIT' '1. Projet source copie et empreinte verifiee' Green
            Write-WorkflowLine 'FAIT' '2. Copie Control Win compilee sans erreur' Green
            Write-WorkflowLine 'FAIT' '3. Copie deployee sur Control Win local' Green
            Write-WorkflowLine 'A FAIRE' '4. Ouvrir la copie pour visualisation en ligne' Yellow
        }
        default {
            Write-WorkflowLine 'INCONNU' 'Etat non reconnu : seules les actions de diagnostic sont autorisees' Red
        }
    }
}

function Assert-SourceUnchanged {
    $manifest = Read-Manifest
    if ($null -eq $manifest -or [string]::IsNullOrWhiteSpace([string]$manifest.source_path)) { return }
    if (-not (Test-Path -LiteralPath $manifest.source_path)) {
        throw 'ALERTE INTEGRITE : le projet source a disparu.'
    }
    $actual = Get-FileHashHex ([string]$manifest.source_path)
    if ($actual -ne [string]$manifest.source_sha256) {
        throw 'ALERTE INTEGRITE : le projet source a ete modifie. Toute action est bloquee.'
    }
}

function Find-Codesys {
    if (Test-Path -LiteralPath $CodesysExe) { return $CodesysExe }
    throw "CODESYS.exe 3.5.19.10 introuvable : $CodesysExe"
}

function Select-ProjectFile {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choisir le projet CODESYS a COPIER pour TwinBench'
    $dialog.Filter = 'Projet CODESYS (*.project;*.projectarchive)|*.project;*.projectarchive'
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Selection annulee. Aucun fichier modifie.'
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

    Write-Host ("[EN COURS] CODESYS : {0}. Cette etape peut prendre quelques minutes..." -f $Mode) -ForegroundColor Cyan
    Write-Host ("Journal : {0}" -f $textLog)

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
                Write-Host ("[EN COURS] CODESYS : {0} - {1} s ecoulees..." -f $Mode, $elapsedSeconds) -ForegroundColor Cyan
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
        throw "CODESYS n'a produit aucun rapport. Voir $textLog"
    }
    $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Write-Host ("Rapport : {0}" -f $report)
    if (-not $result.success) {
        throw ("Echec {0} : {1}" -f $Mode, $result.error)
    }
    if ($null -ne $exitCode -and -not [string]::IsNullOrWhiteSpace([string]$exitCode) -and [int]$exitCode -ne 0) {
        throw "CODESYS a retourne le code $exitCode. Voir $textLog"
    }
    Write-Host ("[TERMINE] CODESYS : {0}." -f $Mode) -ForegroundColor Green
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
    Write-Host ("[ARCHIVE] {0} artefact(s) candidat deplaces vers : {1}" -f $candidateFiles.Count, $archiveDir) -ForegroundColor DarkCyan
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
            throw ("Refus securite : PID suivi {0} n est pas CODESYS ({1})." -f $pidValue, $process.ProcessName)
        }
        Write-Host ("[RECUPERATION] Arret du CODESYS TwinBench suivi (PID {0})." -f $pidValue) -ForegroundColor Yellow
        Stop-Process -Id $pidValue -Force
    }
}

function Recover-TwinBenchWorkspace([switch]$Confirmed) {
    Initialize-Workspace
    Assert-SourceUnchanged
    $state = Get-WorkflowState
    if ($state -eq 'EMPTY') { throw 'Aucun workspace TwinBench a recuperer.' }
    if (-not $Confirmed) {
        $confirmation = Read-Host 'Tape ARCHIVER pour liberer la copie et archiver ses restes, ou ENTREE pour annuler'
        if ($confirmation -cne 'ARCHIVER') {
            Write-Host '[INFO] Recuperation annulee. Aucun fichier ni processus n est touche.' -ForegroundColor Yellow
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
    Write-Host ("[PASS] Workspace libere. Restes archives dans : {0}" -f $recoveryDir) -ForegroundColor Green
    Write-Host '[PASS] Projet source conserve. Une nouvelle preparation propre est autorisee.' -ForegroundColor Green
}

function Invoke-WorkspaceAssistant {
    Initialize-Workspace
    $manifest = Read-Manifest
    $state = Get-WorkflowState
    Write-Host '=== ASSISTANT TWINBENCH : DIAGNOSTIC SANS RISQUE ===' -ForegroundColor Cyan
    Write-Host ("Manifest lu : {0}" -f $ManifestPath)
    Write-Host ("Etat reel : {0}" -f $state)
    if ($null -eq $manifest) {
        Write-Host '[ACTION] Aucun projet importe : choisir 1.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'PREPARED') {
        if (-not (Test-Path -LiteralPath $CurrentProject)) {
            Write-Host '[ECHEC] La copie preparee est absente. Choisir 9 puis ARCHIVER pour repartir proprement.' -ForegroundColor Red
            return
        }
        $actualHash = Get-FileHashHex $CurrentProject
        if ($actualHash -ne [string]$manifest.prepared_sha256) {
            Write-Host '[ECHEC] La copie a change depuis preparation. Choisir 9 puis ARCHIVER ; ne pas deployer.' -ForegroundColor Red
            return
        }
        Write-Host '[PASS] Copie preparee saine : aucune liberation necessaire.' -ForegroundColor Green
        Write-Host '[ACTION] Le seul prochain essai est 3 : deployer Control Win local.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'PREPARE_FAILED') {
        Write-Host '[BLOQUE] Preparation en echec : ne pas recommencer au hasard.' -ForegroundColor Red
        Write-Host '[ACTION] Ouvrir 4 pour diagnostic, puis 9 et ARCHIVER seulement apres correction prouvee.' -ForegroundColor Yellow
        return
    }
    if ($state -eq 'DEPLOYED') {
        Write-Host '[PASS] Control Win est deja deploye ; choisir 4 pour ouvrir la copie.' -ForegroundColor Green
        return
    }
    Write-Host '[ACTION] Suivre l etape recommandee affichee par le menu.' -ForegroundColor Yellow
}

function Invoke-SimpleWorkflow {
    while ($true) {
        $state = Get-WorkflowState
        switch ($state) {
            'EMPTY' {
                Write-Host '[EN COURS] Choisis le projet a charger dans Control Win.' -ForegroundColor Cyan
                Import-Project ''
                continue
            }
            'IMPORTED' {
                Write-Host '[EN COURS] Preparation et compilation de la copie Control Win.' -ForegroundColor Cyan
                Prepare-ControlWinCopy
                continue
            }
            'PREPARE_FAILED' {
                Write-Host '[ACTION REQUISE] Une ancienne copie a echoue. Je peux archiver uniquement cette copie et relancer proprement.' -ForegroundColor Yellow
                $repair = Read-Host 'Tape REPARER pour continuer, ou ENTREE pour annuler'
                if ($repair -cne 'REPARER') {
                    Write-Host '[INFO] Rien n est modifie.' -ForegroundColor Yellow
                    return
                }
                Recover-TwinBenchWorkspace -Confirmed
                continue
            }
            'PREPARED' {
                Write-Host '[ACTION REQUISE] Copie compilee. Tape DEPLOYER pour la charger sur Control Win local, ou ENTREE pour annuler.' -ForegroundColor Yellow
                $deploy = Read-Host 'Confirmation'
                if ($deploy -cne 'DEPLOYER') {
                    Write-Host '[INFO] Deploiement annule. Le PLC reel n a pas ete contacte.' -ForegroundColor Yellow
                    return
                }
                Deploy-ControlWinCopy
                continue
            }
            'DEPLOYED' {
                Write-Host '[EN COURS] Ouverture de la copie Control Win deployee.' -ForegroundColor Cyan
                Open-CurrentCopy
                return
            }
            default {
                throw ("Etat TwinBench inconnu : {0}. Utilise l action Assistant pour le diagnostic." -f $state)
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
        throw 'Seuls les fichiers .project et .projectarchive sont acceptes.'
    }
    if ($source.StartsWith($DataRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Le fichier source ne doit pas provenir du workspace TwinBench.'
    }

    $sourceHashBefore = Get-FileHashHex $source
    $existingManifest = Read-Manifest
    if ($null -ne $existingManifest `
        -and [string]::Equals([string]$existingManifest.source_path, $source, [StringComparison]::OrdinalIgnoreCase) `
        -and [string]$existingManifest.source_sha256 -eq $sourceHashBefore `
        -and (Test-Path -LiteralPath $ImportedProject) `
        -and (Get-FileHashHex $ImportedProject) -eq [string]$existingManifest.imported_sha256) {
        Write-Host '[INFO] Ce projet est deja importe et son empreinte est identique.' -ForegroundColor Green
        Write-Host ("Etat conserve : {0}" -f $existingManifest.state)
        Write-Host 'Aucune copie ni preparation n est recommencee.'
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
        throw 'ALERTE : empreinte du projet source modifiee pendant la copie.'
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
    Write-Host '[PASS] Original inchange. Copie TwinBench creee.' -ForegroundColor Green
    Write-FileLink 'Ouvrir la copie source' $ImportedProject
    $result = Invoke-CodesysHeadless -Mode 'inspect' -WorkingProject $ImportedProject
    Write-Host ("Device actuel : {0}" -f $result.device_identification)
}

function Prepare-ControlWinCopy {
    Initialize-Workspace
    Assert-SourceUnchanged
    if (-not (Test-Path -LiteralPath $ImportedProject)) { throw 'Aucune copie source importee.' }
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
    Write-Host ("[PASS] Copie ciblee Control Win. Erreurs={0}, avertissements={1}" -f $result.error_count, $result.warning_count) -ForegroundColor Green
    Write-Host ("[HW_SIM] {0} BOOL + {1} valeurs typees adaptees uniquement dans la copie." -f $result.hw_sim_compat.bool_symbols, $result.hw_sim_compat.typed_symbols) -ForegroundColor Green
    Write-FileLink 'Ouvrir la copie Control Win' $CurrentProject
}

function Start-ControlWin {
    $service = Get-Service -Name $ControlWinService -ErrorAction Stop
    if ($service.Status -eq 'Running') { return }
    try {
        Start-Service -Name $ControlWinService
    }
    catch {
        Write-Host 'Elevation Windows necessaire pour demarrer Control Win.' -ForegroundColor Yellow
        $command = "Start-Service -Name '$ControlWinService'"
        $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile', '-Command', $command)
        if ($process.ExitCode -ne 0) { throw 'Demarrage eleve de Control Win refuse ou en echec.' }
    }
    (Get-Service -Name $ControlWinService).WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
}

function Deploy-ControlWinCopy {
    Initialize-Workspace
    Assert-SourceUnchanged
    $manifest = Read-Manifest
    if ($null -eq $manifest -or $manifest.state -ne 'PREPARED') {
        throw 'La copie doit etre preparee avec succes avant deploiement.'
    }
    $currentHash = Get-FileHashHex $CurrentProject
    if ($currentHash -ne $manifest.prepared_sha256) {
        throw 'La copie a change depuis la preparation. Relancer PREPARER.'
    }
    if ([int]$manifest.build_errors -ne 0) {
        throw 'Le deploiement est refuse : la compilation contient des erreurs.'
    }

    Start-ControlWin
    $credential = Get-Credential -Message 'Compte LOCAL de CODESYS Control Win (jamais le PLC reel)'
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
    Write-Host '[PASS] Copie deployee et demarree sur Control Win local.' -ForegroundColor Green
    Write-Host '[PREUVE] Copie chargee (lien ci-dessous) :' -ForegroundColor Green
    Write-FileLink 'Ouvrir la copie Control Win deployee' $CurrentProject
    Write-Host ("[PREUVE] Cible : {0}" -f $result.scanned_target) -ForegroundColor Green
    Write-Host ("[PREUVE] Etat application : {0}" -f $result.application_state) -ForegroundColor Green
    Write-Host ("[PREUVE] Utilisateur local : {0}" -f $result.logged_user) -ForegroundColor Green
}

function Open-CurrentCopy {
    Assert-SourceUnchanged
    if (-not (Test-Path -LiteralPath $CurrentProject)) { throw 'Aucune copie TwinBench disponible.' }
    $exe = Find-Codesys
    $process = Start-Process -FilePath $exe -ArgumentList @("--profile=$CodesysProfile", $CurrentProject) -PassThru
    if (Test-Path -LiteralPath $ManifestPath) {
        Write-Manifest @{ ide_pid = $process.Id }
    }
    Write-Host 'CODESYS ouvre la copie TwinBench. Utiliser Online > Login pour la visualisation.' -ForegroundColor Green
}

function Show-Status {
    Initialize-Workspace
    Write-Host "Workspace : $DataRoot"
    $manifest = Read-Manifest
    if ($null -eq $manifest) { Write-Host 'Etat : aucun projet importe.'; return }
    Show-WorkflowStatus
    Write-Host ("Source : {0}" -f $manifest.source_path)
    Write-Host ("Derniere mise a jour : {0}" -f $manifest.updated_at)
    if (Test-Path -LiteralPath $CurrentProject) {
        Write-Host ("SHA-256 actuel : {0}" -f (Get-FileHashHex $CurrentProject))
        Write-FileLink 'Ouvrir la copie Control Win' $CurrentProject
    }
    if ($manifest.PSObject.Properties.Name -contains 'hw_sim_bool_symbols') {
        Write-Host ("Adaptateur HW_SIM : {0} BOOL + {1} valeurs typees (copie uniquement)" -f $manifest.hw_sim_bool_symbols, $manifest.hw_sim_typed_symbols)
    }
    if ($manifest.PSObject.Properties.Name -contains 'deployed_target') {
        Write-Host ("Cible deployee : {0}" -f $manifest.deployed_target)
        Write-Host ("Etat application : {0}" -f $manifest.deployed_application_state)
        Write-Host ("Utilisateur local : {0}" -f $manifest.deployed_local_user)
    }
    if ($manifest.PSObject.Properties.Name -contains 'history') {
        Write-Host 'Dernieres actions :'
        @($manifest.history) | Select-Object -Last 5 | ForEach-Object {
            Write-Host ("  {0} | {1} | {2} | {3} -> {4}" -f $_.at, $_.outcome, $_.action, $_.state_before, $_.state_after)
        }
    }
}

function Show-RecentEvents {
    $manifest = Read-Manifest
    if ($null -eq $manifest -or $manifest.PSObject.Properties.Name -notcontains 'history') { return }
    Write-Host '--- EVENEMENTS RECENTS ---' -ForegroundColor DarkCyan
    @($manifest.history) | Select-Object -Last 6 | ForEach-Object {
        $color = if ([string]$_.outcome -eq 'FAIL') { [ConsoleColor]::Red } else { [ConsoleColor]::Gray }
        Write-Host ("{0} | {1} | choix {2} | {3} -> {4}" -f $_.at, $_.outcome, $_.action, $_.state_before, $_.state_after) -ForegroundColor $color
        if (-not [string]::IsNullOrWhiteSpace([string]$_.detail)) {
            Write-Host ("  detail: {0}" -f $_.detail) -ForegroundColor $color
        }
    }
}

function Invoke-SelfTest {
    & python $SelfTestScript
    if ($LASTEXITCODE -ne 0) { throw 'Autotest du runner en echec.' }
}

function Unlock-PrepareRetry {
    if ((Get-WorkflowState) -ne 'PREPARE_FAILED') {
        throw 'Le rearmement est disponible uniquement apres un echec de preparation.'
    }
    $confirmation = Read-Host 'Tape REESSAYER uniquement si la cause de l echec a ete corrigee'
    if ($confirmation -cne 'REESSAYER') {
        throw 'Rearmement annule. Etat PREPARE_FAILED conserve.'
    }
    Write-Manifest @{
        state = 'IMPORTED'
        prepared_sha256 = ''
        deployed_sha256 = ''
    }
    Write-Host '[PASS] Nouvelle tentative de preparation autorisee. Aucun fichier projet modifie.' -ForegroundColor Green
}

function Invoke-GuidedWorkflow {
    Write-Host '=== MODE GUIDE : PARCOURS COMPLET ===' -ForegroundColor Cyan
    $state = Get-WorkflowState

    if ($state -eq 'EMPTY') {
        Write-Host '[GUIDE 1/4] Import et diagnostic de la copie source.' -ForegroundColor Cyan
        Import-Project ''
        $state = Get-WorkflowState
    }
    elseif ($state -eq 'IMPORTED') {
        Write-Host '[GUIDE 1/4] Copie source deja disponible.' -ForegroundColor Green
    }
    elseif ($state -eq 'PREPARE_FAILED') {
        throw 'Parcours guide arrete : preparation en echec. Corriger la cause puis utiliser 7 avant de relancer 8.'
    }
    elseif ($state -eq 'PREPARED' -or $state -eq 'DEPLOYED') {
        Write-Host '[GUIDE 1/4] Copie deja preparee.' -ForegroundColor Green
    }

    $state = Get-WorkflowState
    if ($state -eq 'IMPORTED') {
        Write-Host '[GUIDE 2/4] Preparation et compilation Control Win.' -ForegroundColor Cyan
        Prepare-ControlWinCopy
        $state = Get-WorkflowState
    }
    if ($state -ne 'PREPARED' -and $state -ne 'DEPLOYED') {
        throw ("Parcours guide arrete dans l etat {0}." -f $state)
    }

    if ($state -eq 'PREPARED') {
        Write-Host '[GUIDE 3/4] Preparation validee.' -ForegroundColor Green
        $confirmation = Read-Host 'Tape DEPLOYER pour demarrer Control Win local, ou ENTREE pour arreter ici'
        if ($confirmation -cne 'DEPLOYER') {
            Write-Host '[GUIDE] Arret volontaire avant deploiement. Etat PREPARED conserve.' -ForegroundColor Yellow
            return
        }
        Deploy-ControlWinCopy
    }
    else {
        Write-Host '[GUIDE 3/4] Copie deja deployee.' -ForegroundColor Green
    }

    Write-Host '[GUIDE 4/4] Ouverture de la copie dans CODESYS.' -ForegroundColor Cyan
    Open-CurrentCopy
    Write-Host '[GUIDE TERMINE] Parcours complet execute.' -ForegroundColor Green
}

function Show-NextRecommendedAction {
    $manifest = Read-Manifest
    if ($null -eq $manifest) {
        Write-Host 'Etape recommandee : 1 - Importer un projet.' -ForegroundColor Yellow
        return
    }
    switch ([string]$manifest.state) {
        'IMPORTED' {
            Write-Host 'Etape recommandee : 2 - Preparer la copie pour Control Win.' -ForegroundColor Yellow
        }
        'PREPARE_FAILED' {
            Write-Host 'Preparation bloquee : consulter le diagnostic. Ne pas deployer.' -ForegroundColor Red
        }
        'PREPARED' {
            Write-Host 'Etape recommandee : 3 - Deployer sur Control Win local.' -ForegroundColor Yellow
        }
        'DEPLOYED' {
            Write-Host 'Etape recommandee : 4 - Ouvrir la copie dans CODESYS.' -ForegroundColor Yellow
        }
        default {
            Write-Host ("Etat actuel : {0}" -f $manifest.state) -ForegroundColor Yellow
        }
    }
}

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Host '=== TWINBENCH CONTROL WIN - COPIE ISOLEE ===' -ForegroundColor Cyan
        $state = Get-WorkflowState
        Write-Host ("Etat reel : {0}" -f $state) -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'ENTREE  Continuer : charger le projet dans Control Win' -ForegroundColor Green
        Write-Host '0       Quitter' -ForegroundColor DarkGray
        $choice = Read-Host 'Action'
        if ($choice -eq '0') { return }
        if (-not [string]::IsNullOrWhiteSpace($choice)) {
            Write-Host '[INFO] Utilise simplement ENTREE pour continuer.' -ForegroundColor Yellow
            continue
        }
        try {
            Invoke-SimpleWorkflow
        }
        catch {
            Write-Host ("[REFUS/ERREUR] {0}" -f $_.Exception.Message) -ForegroundColor Red
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
