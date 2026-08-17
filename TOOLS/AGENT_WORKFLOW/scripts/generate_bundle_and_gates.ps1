# ═══════════════════════════════════════════════════════════════════════════
# 🚀 generate_bundle_and_gates.ps1 — Génère le bundle PLCopenXML + tous les gates
# ───────────────────────────────────────────────────────────────────────────
# Usage :  powershell -ExecutionPolicy Bypass -File TOOLS/AGENT_WORKFLOW/scripts/generate_bundle_and_gates.ps1
# Rôle :   régénère CODE_XML/CODE_Bundle.xml, vérifie la liaison (G200) et
#          lance tous les gates (run_all_gates.py) en une seule commande.
# ═══════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# scripts → AGENT_WORKFLOW → TOOLS → racine projet (4 niveaux)
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))
Set-Location $root
Write-Host "=== Répertoire projet : $root ===" -ForegroundColor Cyan

$fail = 0

# ── 1. Génération du bundle ────────────────────────────────────────────────
Write-Host "`n=== 1. Génération du bundle PLCopenXML ===" -ForegroundColor Cyan
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Bundle : ÉCHEC (code $LASTEXITCODE)" -ForegroundColor Red
    $fail = 1
} else {
    Write-Host "  ✅ Bundle : OK" -ForegroundColor Green
}

# ── 2. Liaison (G200) ─────────────────────────────────────────────────────
Write-Host "`n=== 2. Vérification liaison (G200) ===" -ForegroundColor Cyan
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Liaison : ÉCHEC (code $LASTEXITCODE)" -ForegroundColor Red
    $fail = 1
} else {
    Write-Host "  ✅ Liaison : OK" -ForegroundColor Green
}

# ── 3. Tous les gates ─────────────────────────────────────────────────────
Write-Host "`n=== 3. Tous les gates (run_all_gates) ===" -ForegroundColor Cyan
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Gates : ÉCHEC (code $LASTEXITCODE)" -ForegroundColor Red
    $fail = 1
} else {
    Write-Host "  ✅ Gates : OK" -ForegroundColor Green
}

# ── Bilan ─────────────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Cyan
if ($fail -eq 0) {
    Write-Host "✅ BILAN : bundle + liaison + gates = TOUT OK" -ForegroundColor Green
} else {
    Write-Host "❌ BILAN : au moins une étape a échoué (voir ci-dessus)" -ForegroundColor Red
}
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
exit $fail
