param([string]$InputPath = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

if ([string]::IsNullOrWhiteSpace($InputPath) -or -not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Sélectionner une trace CODESYS"
    $dialog.Filter = "Traces CODESYS (*.trace)|*.trace|Tous les fichiers (*.*)|*.*"
    $dialog.Multiselect = $false
    # Ouvre directement dans le dossier canonique des traces du projet.
    $traceDirectory = Join-Path $PSScriptRoot "..\RESULTS\trace"
    if (Test-Path -LiteralPath $traceDirectory -PathType Container) {
        $dialog.InitialDirectory = (Resolve-Path -LiteralPath $traceDirectory).Path
    }
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
    $InputPath = $dialog.FileName
}

$InputPath = (Resolve-Path -LiteralPath $InputPath).Path
$choice = [System.Windows.Forms.MessageBox]::Show(
    "Oui : CSV large (Excel)`nNon : CSV long (analyse/partage)",
    "Format d'export",
    [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question
)
if ($choice -eq [System.Windows.Forms.DialogResult]::Cancel) { exit 0 }
$format = if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { "wide" } else { "long" }

$suffix = if ($format -eq "wide") { "_wide" } else { "" }
$output = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName($InputPath),
    [System.IO.Path]::GetFileNameWithoutExtension($InputPath) + $suffix + ".csv"
)
$force = @()
if (Test-Path -LiteralPath $output) {
    $overwrite = [System.Windows.Forms.MessageBox]::Show(
        "Le fichier existe déjà :`n$output`n`nVoulez-vous le remplacer ?",
        "Confirmation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($overwrite -ne [System.Windows.Forms.DialogResult]::Yes) { exit 0 }
    $force = @("--force")
}

$converter = Join-Path $PSScriptRoot "trace_to_csv.py"
& py -3.13 $converter $InputPath -o $output --format $format @force
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "Export terminé :`n$output",
        "Trace CODESYS",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
exit $exitCode
