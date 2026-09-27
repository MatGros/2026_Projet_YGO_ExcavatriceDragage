#!/usr/bin/env python3
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
PS = (ROOT / "TwinBench_ControlWin.ps1").read_text(encoding="utf-8")
HEADLESS = (ROOT / "codesys_headless.py").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")


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
    "pas de fallback auth interactif": "CredentialSourceKind.none" in HEADLESS,
    "download complet explicite": "OnlineChangeOption.Never" in HEADLESS,
    "compilation avant download": HEADLESS.index("build_project(project)", HEADLESS.index("def deploy")) < HEADLESS.index("online_application.login", HEADLESS.index("def deploy")),
    "aucun forcage variable": "force_prepared_values" not in HEADLESS,
    "limite IO documentee": "symboles" in README and "HW_SIM" in README,
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
