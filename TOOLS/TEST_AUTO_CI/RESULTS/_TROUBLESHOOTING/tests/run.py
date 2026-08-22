#!/usr/bin/env python3
"""🕵️ RUN — Test CI ad hoc du domaine _TROUBLESHOOTING.

Autonome, sans registry.yaml : l'agent de dépannage définit ici l'entrée ad hoc
(sources + test) d'un FB, puis appelle run_tests.run_one() qui compile + exécute
+ génère le rapport (reports/) et ARCHIVE automatiquement l'ancien rapport.

Usage :
    python TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/tests/run.py

Le rapport est écrit dans RESULTS/_TROUBLESHOOTING/reports/ (archive/ pour l'historique).
⚠️ Dossier jetable : nettoyer après chaque dépannage (ne pas commiter les tests).
"""
import pathlib
import sys

# --- Racine du dépôt + accès aux modules du runner -------------------------
REPO_ROOT = pathlib.Path(__file__).resolve().parents[5]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"))

import run_tests  # noqa: E402

# ===========================================================================
# ⚙️ ENTRÉE AD HOC — à adapter à chaque dépannage
# ===========================================================================
FB_NAME = "FB_Joystick"
DOMAIN = "_TROUBLESHOOTING"

# Sources du domaine JOYSTICK (miroir du registry.yaml FB_Joystick) : FB_Joystick
# + toutes ses dépendances (enum/DUT d'abord, FB en dernier). Couvre : E_Mode,
# E_Diag_State, ST_Diag_Device, E_State, ST_FbStatus, FB_FbStatus,
# ST_Joystick_AxisCmd, FB_AxisScale, FB_Joystick.
ENTRY = {
    "domain": DOMAIN,
    "sources": [
        "CODE/F_MODES/E_Mode.st",
        "CODE/C_DIAG_RESEAUX/E_Diag_State.st",
        "CODE/C_DIAG_RESEAUX/ST_Diag_Device.st",
        "CODE/A_COMMUN/E_State.st",
        "CODE/A_COMMUN/ST_FbStatus.st",
        "CODE/A_COMMUN/FB_FbStatus.st",
        "CODE/D_JOYSTICK/ST_Joystick_AxisCmd.st",
        "CODE/D_JOYSTICK/FB_AxisScale.st",
        "CODE/D_JOYSTICK/FB_Joystick.st",
    ],
    "test": "TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/tests/test_fb_sim_joystick.st",
}


def main() -> int:
    # run_one() archive automatiquement l'ancien rapport dans reports/archive/.
    result = run_tests.run_one(FB_NAME, ENTRY, cycle_time_ms=10, debug=True)
    n_pass = sum(1 for t in result["tests"] if t["passed"])
    print(f"\n{'='*60}")
    print(f"Résultat {FB_NAME} : {n_pass}/{len(result['tests'])} PASS")
    for t in result["tests"]:
        status = "PASS" if t["passed"] else "FAIL"
        print(f"  {status}  {t['name']}")
        if not t["passed"] and t["detail"]:
            print(f"        {t['detail']}")
    print(f"{'='*60}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
