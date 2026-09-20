#!/usr/bin/env python3
"""T255-D — reproduction exploratoire hors registre CI officiel.

Registre EPHEMERE construit a partir des entrees officielles du registry.yaml ; rien
n'est ecrit dans le CI officiel. Deux ajustements locaux, jamais officiels :
  - le fichier de test est remplace par celui du cas courant ;
  - pour FB_Hmi_BannerFormatter, la source absente ST_ChainDredgingAssist.st (entree
    officielle cassee, cf. decision D4) est retiree localement pour rendre le cas
    executable.

Cas :
  producer     FB_Safety_Winch     -> la limite basse cable SEULE allume-t-elle Fault.Error
                                      (vue LIVE) sans aucun defaut latche ?
  consumer     PRG_07_Supervision  -> le bandeau expose-t-il cette cause active ?
  banner-ref   FB_Hmi_BannerFormatter -> baseline REELLE des TC officiels du bandeau
                                      (fichier de test officiel, non modifie)
  banner-hyp   FB_Hmi_BannerFormatter -> mecanisme (A) : cause latchée bloquante masquee
                                      par une validite materielle a FALSE

Usage :
  python tests/run.py --case producer
  python tests/run.py --case consumer
  python tests/run.py --case banner-ref
  python tests/run.py --case banner-hyp
"""
from __future__ import annotations

import pathlib
import sys
import tempfile

import yaml


HERE = pathlib.Path(__file__).resolve()
REPO_ROOT = next(parent for parent in HERE.parents if (parent / "TOOLS" / "TEST_AUTO_CI").is_dir())
SCRIPTS = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "scripts"
TESTS = HERE.parent

CASES = {
    "producer": ("FB_Safety_Winch", TESTS / "test_t255d_fdc_bas_producer.st"),
    "consumer": ("PRG_07_Supervision", TESTS / "test_t255d_fdc_bas_exploratory.st"),
    "banner-ref": (
        "FB_Hmi_BannerFormatter",
        REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / "J_SUPERVISION" / "tests" / "test_fb_hmi_bannerformatter.st",
    ),
    "banner-hyp": ("FB_Hmi_BannerFormatter", TESTS / "test_t255d_fdc_bas_hypotheses.st"),
}
DOMAIN = "_TROUBLESHOOTING/DSH01_T255D_FDC_BAS"
# Sources que l'entree officielle oublie alors qu'elle compile des types qui en dependent
# (constat 2026-09-20 : ST_CycleCfg.st est liste, E_CycleDepthStopMode.st ne l'est pas).
EXTRA_SOURCES = {
    "FB_Hmi_BannerFormatter": ["CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/E_CycleDepthStopMode.st"],
}

sys.path.insert(0, str(SCRIPTS))
import run_tests  # noqa: E402  (runner canonique du projet)


def main() -> int:
    case = "producer"
    extra = sys.argv[1:]
    rest: list[str] = []
    i = 0
    while i < len(extra):
        if extra[i] == "--case" and i + 1 < len(extra):
            case = extra[i + 1]
            i += 2
            continue
        rest.append(extra[i])
        i += 1
    if case not in CASES:
        print(f"[ERREUR] cas inconnu '{case}' ; attendu : {', '.join(CASES)}", file=sys.stderr)
        return 2

    fb_name, test_file = CASES[case]
    official = yaml.safe_load(run_tests.REGISTRY.read_text(encoding="utf-8"))
    if fb_name not in official:
        print(f"[ERREUR] {fb_name} absent du registre officiel", file=sys.stderr)
        return 2
    entry = {fb_name: dict(official[fb_name])}
    entry[fb_name]["domain"] = DOMAIN
    entry[fb_name]["test"] = str(test_file)
    kept: list[str] = []
    dropped: list[str] = []
    for src in entry[fb_name].get("sources", []):
        if (REPO_ROOT / str(src)).is_file():
            kept.append(src)
        else:
            dropped.append(str(src))
    entry[fb_name]["sources"] = kept
    for extra_src in EXTRA_SOURCES.get(fb_name, []):
        if extra_src not in kept and (REPO_ROOT / extra_src).is_file():
            kept.append(extra_src)
            print(f"[source ajoutee localement] {extra_src}")
    if dropped:
        print("[sources absentes, retirees du registre ephemere uniquement]")
        for src in dropped:
            print(f"  - {src}")

    # Registre ephemere hors depot : le fichier systeme est laisse au nettoyage de l'OS.
    fd, registry_name = tempfile.mkstemp(prefix="dsh01_t255d_registry_", suffix=".yaml")
    pathlib.Path(registry_name).write_text(yaml.safe_dump(entry, sort_keys=False), encoding="utf-8")
    pathlib.Path(registry_name).chmod(0o600)
    run_tests.REGISTRY = pathlib.Path(registry_name)

    print(f"[cas] {case} -> {fb_name} :: {test_file.name}")
    sys.argv = [str(SCRIPTS / "run_tests.py"), "--fb", fb_name, *rest]
    return run_tests.main()


if __name__ == "__main__":
    raise SystemExit(main())
