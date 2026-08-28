#!/usr/bin/env python3
"""Gate CI unifiÃ© du domaine TEST_AUTO_CI (T171) â€” point d'entrÃ©e unique.

ExÃ©cute la chaÃ®ne de validation complÃ¨te du harnais compilÃ© et de l'animation :

  1. Harnais complet FB_Cycle (TC-P04-100..105) sur WORKING_COPY  -> 6/6 requis
  2. Tests nÃ©gatifs sur CODE/ original (dÃ©fauts F1/F2/F6 prouvÃ©s) -> 3/3 requis
  3. Garde-fou animation : pur lecteur + trace embarquÃ©e Ã  jour   -> PASS requis

TraÃ§age : chaque Ã©tape affiche sa commande, son code retour et son verdict.
Sortie : 0 si TOUT est vert, 1 sinon (convention gates).

Usage :
    python TOOLS/TEST_AUTO_CI/anim_bench/run_ci_gates.py
    python TOOLS/TEST_AUTO_CI/anim_bench/run_ci_gates.py --skip-slow   # saute les compilations (2,3)
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
        print(f"â­ï¸  {label} : SAUTÃ‰ (--skip-slow)")
        return True
    print(f"\nâ–¶ {tag}{label}")
    print(f"  $ {' '.join(cmd)}")
    rc = subprocess.call([sys.executable, *cmd])
    if rc == 0:
        print(f"âœ… {label} : PASS")
        return True
    print(f"âŒ {label} : FAIL (rc={rc})")
    return False


def main() -> int:
    skip_slow = "--skip-slow" in sys.argv
    print("=" * 60)
    print("ðŸ§ª GATES CI â€” TOOLS/TEST_AUTO_CI (T171)")
    print("=" * 60)

    results = [
        _run("G-CI-1 Harnais complet FB_Cycle (TC-P04-100..105)",
             [str(SCRIPTS / "run_cycle_tests.py")], slow=True, skip_slow=skip_slow),
        _run("G-CI-2 Tests nÃ©gatifs CODE/ original (F1/F2/F6 prouvÃ©s)",
             [str(SCRIPTS / "run_negative_tests.py")], slow=True, skip_slow=skip_slow),
        _run("G-CI-3 Garde animation : pur lecteur + fraÃ®cheur trace",
             [str(SCRIPTS / "guard_animation_no_business_logic.py")], slow=False, skip_slow=skip_slow),
    ]

    n_ok = sum(1 for r in results if r)
    print("\n" + "=" * 60)
    print(f"RÃ‰SULTAT : {n_ok}/{len(results)} gates CI PASS")
    print("=" * 60)
    return 0 if n_ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())