#!/usr/bin/env python3
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
PS = (ROOT / "TwinBench_ControlWin.ps1").read_text(encoding="utf-8")
HEADLESS = (ROOT / "codesys_headless.py").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
START_CMD = (ROOT / "Start_ControlWin.cmd").read_text(encoding="utf-8")


CHECKS = {
    "workspace hors depot": "TwinBenchControlWin" in PS and "LOCALAPPDATA" in PS,
    "empreinte source avant apres": PS.count("sourceHash") >= 4 and "Get-FileHash" in PS,
    "original interdit au headless": "$env:TB_PROJECT = $WorkingProject" in PS and "REFUS SECURITE" in HEADLESS,
    "hash source controle chaque action": PS.count("Assert-SourceUnchanged") >= 6,
    "headless confine au workspace": "REFUS SECURITE: CODESYS ne peut ouvrir que la copie TwinBench Current" in HEADLESS,
    "cible nommee Control Win": 'CONTROL_WIN_TYPE_NAME = "CODESYS Control Win V3 x64"' in HEADLESS,
    "poste local impose": 'CONTROL_WIN_DEVICE_NAME = "PC-Z-VICTUS"' in HEADLESS,
    "target id impose": 'CONTROL_WIN_ID = "0000 0004"' in HEADLESS,
    "adresse loopback preparee": '"127.0.0.1"' in HEADLESS,
    "scan loopback impose": 'LOOPBACK_TARGET_ADDRESSES = ("127.0.0.1", "::1", "[::1]")' in HEADLESS and "target_address in LOOPBACK_TARGET_ADDRESSES" in HEADLESS,
    "adresse externe refusee": "Toute adresse non locale est refusee" in HEADLESS,
    "pas de fallback auth interactif": "CredentialSourceKind.none" in HEADLESS,
    "download complet explicite": "OnlineChangeOption.Never" in HEADLESS,
    "compilation avant download": HEADLESS.index("build_project(project)", HEADLESS.index("def deploy")) < HEADLESS.index("online_application.login", HEADLESS.index("def deploy")),
    "aucun forcage variable": "force_prepared_values" not in HEADLESS,
    "limite IO documentee": "symboles" in README and "HW_SIM" in README,
    "menu persistant": "while ($true)" in PS and "Show-Menu" in PS,
    "progression headless visible": "[IN PROGRESS] CODESYS" in PS and "[DONE] CODESYS" in PS,
    "progression temporelle periodique": "nextProgressAt" in PS and "seconds elapsed" in PS,
    "prochaine etape proposee": "Show-NextRecommendedAction" in PS and "Recommended next step" in PS,
    "deploiement jamais automatique": "'IMPORTED' {\n            Write-Host 'Recommended next step: 2" in PS,
    "codesys lance directement": "Start-Process -FilePath $exe" in PS and "$env:ComSpec" not in PS,
    "reimport identique sans perte etat": "This project is already imported" in PS and "State preserved" in PS,
    "parcours pilote par etat": "Get-AllowedChoices" in PS and "Invoke-SimpleWorkflow" in PS and "ENTER   Continue" in PS,
    "statuts explicites": all(marker in PS for marker in ("TODO", "DONE", "FAIL", "LOCKED")),
    "historique actions": "Add-ActionHistory" in PS and "Recent actions" in PS,
    "ancien manifeste sans historique": "PSObject.Properties.Name -contains 'history'" in PS,
    "deploiement limite a prepared": "'PREPARED'" in PS and "Deploy-ControlWinCopy" in PS and "build_errors" in PS,
    "prepare verrouille apres echec": "'PREPARE_FAILED'" in PS and "Get-AllowedChoices" in PS and "Unlock-PrepareRetry" in PS,
    "rearmement explicite apres correction": "Unlock-PrepareRetry" in PS and "Type RETRY" in PS,
    "mode guide sequentiel": "Invoke-GuidedWorkflow" in PS and "GUIDE 1/4" in PS and "GUIDE 4/4" in PS,
    "mode guide stoppe sur echec": "Guided workflow stopped" in PS,
    "mode guide protege deploiement": "Type DEPLOY" in PS and "Deploy-ControlWinCopy" in PS,
    "mode guide indisponible apres echec": "'PREPARE_FAILED' { return @('1', '4', '5', '6', '7', '9', '10', '0') }" in PS,
    "recuperation processus suivis": "Stop-TrackedTwinBenchProcess" in PS and "headless_pid" in PS and "ide_pid" in PS,
    "recuperation archive sans suppression": "Recover-TwinBenchWorkspace" in PS and "Move-Item" in PS and "recovery_archive" in PS,
    "recuperation conserve source": "Source project preserved" in PS and "Assert-SourceUnchanged" in PS,
    "menu redessine en haut": "Clear-Host" in PS and "Show-RecentEvents" in PS,
    "erreurs recentes visibles": "details:" in PS and "RECENT EVENTS" in PS,
    "annulations explicites": "Nothing was changed" in PS and "Deployment cancelled" in PS,
    "rapport success prioritaire au code vide": "success" in PS and "IsNullOrWhiteSpace([string]$exitCode)" in PS,
    "adaptateur limite export derive": "derived_native_export_only" in HEADLESS and "apply_hw_sim_compat(native_path, result)" in HEADLESS,
    "adaptateur apres export source": HEADLESS.index("apply_hw_sim_compat(native_path, result)", HEADLESS.index("def prepare_from_import")) > HEADLESS.index("source.export_native", HEADLESS.index("def prepare_from_import")),
    "valeurs hw sim typees": "HW_SIM_BOOL_SYMBOLS" in HEADLESS and "HW_SIM_TYPED_SYMBOLS" in HEADLESS,
    "joystick simule neutre": '("JoyXRaw_ANA1", "INT", "INT#5000")' in HEADLESS and '("JoyYRaw_ANA2", "INT", "INT#5000")' in HEADLESS,
    "diagnostic compilation complet": 'result["messages"] = messages' in HEADLESS,
    "rapport hw sim dans manifeste": "hw_sim_bool_symbols" in PS and "hw_sim_typed_symbols" in PS,
    "candidats archives sans suppression": "Archive-CandidateArtifacts" in PS and "prepare_echec" in PS and "prepare_terminee" in PS and "Move-Item" in PS,
    "assistant etat reel": "Invoke-WorkspaceAssistant" in PS and "Actual state" in PS and "Manifest:" in PS,
    "liberation confirmee": "Type ARCHIVE" in PS and "No files or processes were touched" in PS,
    "menu simplifie": "ENTER   Continue: load the project into Control Win" in PS and "Invoke-SimpleWorkflow" in PS,
    "reparation guidee": "Type REPAIR to continue" in PS and "Recover-TwinBenchWorkspace -Confirmed" in PS,
    "deploiement confirme": "Type DEPLOY to load it on local Control Win" in PS,
    "preuve deploiement lisible": all(token in PS for token in ("[PROOF] Loaded copy", "[PROOF] Target", "[PROOF] Application state", "[PROOF] Local user")),
    "liens terminal copies": "function Write-FileLink" in PS and "Open Control Win copy" in PS and "]8;;" in PS,
    "wrapper returns without pause": "pause" not in START_CMD.lower() and "exit /b %errorlevel%" in START_CMD.lower(),
}


def main():
    failed = []
    for name, passed in CHECKS.items():
        print("%s %s" % ("PASS" if passed else "FAIL", name))
        if not passed:
            failed.append(name)
    print("Resultat: %s/%s PASS" % (len(CHECKS) - len(failed), len(CHECKS)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
