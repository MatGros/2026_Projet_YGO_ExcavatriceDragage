#!/usr/bin/env python3
"""Gate CI unifié du domaine TEST_AUTO_CI (T171) — point d'entrée unique.

Exécute la chaîne de validation complète du harnais compilé et de l'animation :

  1. Harnais complet FB_Cycle (TC-P04-100..105) sur WORKING_COPY  -> 6/6 requis
  2. Tests négatifs sur CODE/ original (défauts F1/F2/F6 prouvés) -> 3/3 requis
  3. Garde-fou animation : pur lecteur + trace embarquée à jour   -> PASS requis

Traçage : chaque étape affiche sa commande, son code retour et son verdict.
Sortie : 0 si TOUT est vert, 1 sinon (convention gates).

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/run_ci_gates.py
    python TOOLS/TEST_AUTO_CI/scripts/run_ci_gates.py --skip-slow   # saute les compilations (2,3)
"""

import subprocess
import sys
import pathlib

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPTS = pathlib.Path(__file__).resolve().parent


def _run(label: str, cmd: list, slow: bool = False, skip_slow: bool = False) -> bool:
    tag = "[LENT] " if slow else ""
    if slow and skip_slow:
        print(f"⏭️  {label} : SAUTÉ (--skip-slow)")
        return True
    print(f"\n▶ {tag}{label}")
    print(f"  $ {' '.join(cmd)}")
    rc = subprocess.call([sys.executable, *cmd])
    if rc == 0:
        print(f"✅ {label} : PASS")
        return True
    print(f"❌ {label} : FAIL (rc={rc})")
    return False


def main() -> int:
    skip_slow = "--skip-slow" in sys.argv
    print("=" * 60)
    print("🧪 GATES CI — TOOLS/TEST_AUTO_CI (T171)")
    print("=" * 60)

    results = [
        _run("G-CI-1 Harnais complet FB_Cycle (TC-P04-100..105)",
             [str(SCRIPTS / "run_cycle_tests.py")], slow=True, skip_slow=skip_slow),
        _run("G-CI-2 Tests négatifs CODE/ original (F1/F2/F6 prouvés)",
             [str(SCRIPTS / "run_negative_tests.py")], slow=True, skip_slow=skip_slow),
        _run("G-CI-3 Garde animation : pur lecteur + fraîcheur trace",
             [str(SCRIPTS / "guard_animation_no_business_logic.py")], slow=False, skip_slow=skip_slow),
    ]

    n_ok = sum(1 for r in results if r)
    print("\n" + "=" * 60)
    print(f"RÉSULTAT : {n_ok}/{len(results)} gates CI PASS")
    print("=" * 60)
    return 0 if n_ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())