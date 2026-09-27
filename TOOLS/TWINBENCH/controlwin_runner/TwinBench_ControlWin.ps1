[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Import', 'Prepare', 'Deploy', 'Open', 'Status', 'SelfTest')]
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

    $oldAction = $env:TB_ACTION
    $oldProject = $env:TB_PROJECT
    $oldInput = $env:TB_INPUT
    $oldReport = $env:TB_REPORT
    $oldUser = $env:TB_USERNAME
    $oldPassword = $env:TB_PASSWORD
    try {
        $env:TB_ACTION = $Mode
        $env:TB_PROJECT = $WorkingProject
        $env:TB_INPUT = $InputPath
        $env:TB_REPORT = $report
        $commandLine = ('"{0}" --profile="{1}" --runscript="{2}" --noUI' -f $exe, $CodesysProfile, $HeadlessScript)
        $savedErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $env:ComSpec /d /c $commandLine 2>&1 |
                Tee-Object -FilePath $textLog |
                Out-Null
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $savedErrorAction
        }
    }
    finally {
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
    if ($exitCode -ne 0) {
        throw "CODESYS a retourne le code $exitCode. Voir $textLog"
    }
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
    Write-Host "Copie source : $ImportedProject"
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
        Write-Manifest @{
            state = 'PREPARE_FAILED'
            prepared_sha256 = ''
            deployed_sha256 = ''
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
    $hash = Get-FileHashHex $CurrentProject
    Write-Manifest @{
        prepared_sha256 = $hash
        deployed_sha256 = ''
        state = 'PREPARED'
        prepare_report = $result.report_path
        build_errors = $result.error_count
        build_warnings = $result.warning_count
    }
    Write-Host ("[PASS] Copie ciblee Control Win. Erreurs={0}, avertissements={1}" -f $result.error_count, $result.warning_count) -ForegroundColor Green
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
    }
    Write-Host '[PASS] Copie deployee et demarree sur Control Win local.' -ForegroundColor Green
}

function Open-CurrentCopy {
    Assert-SourceUnchanged
    if (-not (Test-Path -LiteralPath $CurrentProject)) { throw 'Aucune copie TwinBench disponible.' }
    $exe = Find-Codesys
    Start-Process -FilePath $exe -ArgumentList @("--profile=$CodesysProfile", $CurrentProject)
    Write-Host 'CODESYS ouvre la copie TwinBench. Utiliser Online > Login pour la visualisation.' -ForegroundColor Green
}

function Show-Status {
    Initialize-Workspace
    Write-Host "Workspace : $DataRoot"
    $manifest = Read-Manifest
    if ($null -eq $manifest) { Write-Host 'Etat : aucun projet importe.'; return }
    $manifest | ConvertTo-Json -Depth 6
    if (Test-Path -LiteralPath $CurrentProject) {
        Write-Host ("SHA-256 actuel : {0}" -f (Get-FileHashHex $CurrentProject))
    }
}

function Invoke-SelfTest {
    & python $SelfTestScript
    if ($LASTEXITCODE -ne 0) { throw 'Autotest du runner en echec.' }
}

function Show-Menu {
    while ($true) {
        Write-Host ''
        Write-Host '=== TWINBENCH CONTROL WIN — COPIE ISOLEE ===' -ForegroundColor Cyan
        Write-Host '1. Importer un projet et diagnostiquer la copie'
        Write-Host '2. Preparer la copie pour Control Win'
        Write-Host '3. Deployer et demarrer sur Control Win local'
        Write-Host '4. Ouvrir la copie dans CODESYS'
        Write-Host '5. Afficher l etat'
        Write-Host '6. Autotest des garde-fous'
        Write-Host '0. Quitter'
        $choice = Read-Host 'Choix'
        try {
            switch ($choice) {
                '1' { Import-Project '' }
                '2' { Prepare-ControlWinCopy }
                '3' { Deploy-ControlWinCopy }
                '4' { Open-CurrentCopy }
                '5' { Show-Status }
                '6' { Invoke-SelfTest }
                '0' { return }
                default { Write-Host 'Choix invalide.' -ForegroundColor Yellow }
            }
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
}
