#!/usr/bin/env python3
"""Runner de tests automatises pour FB CODESYS, base sur registry.yaml (source unique des
dependances -- jamais devinees a la volee). Pipeline par FB :

    sources (registry.yaml) --[moulinette COMPILER_ST2C_STruCpp]--> .st IEC standard
                             --[strucpp.exe --test]--> compile C++ + execute les ASSERT

Usage :
    python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_Joystick
    python TOOLS/TEST_AUTO_CI/run_tests.py --all

Necessite g++ (MinGW-w64) dans le PATH -- voir TOOLS/COMPILER_ST2C_STruCpp/README.md.
"""

import argparse
import datetime as _dt
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

import yaml

import chronogram
import prod_wiring
from af_coverage import check_af_coverage, check_extra_tests
from html_report import render_group_report, render_html_report

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
REGISTRY = TEST_AUTO_CI / "registry.yaml"
CONFIG = TEST_AUTO_CI / "config.yaml"
RUNTIME_INCLUDE = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "test"


_COLOR_OK = os.environ.get("NO_COLOR") is None and sys.stdout.isatty()


def _c(text: str, ok: bool) -> str:
    """Colore PASS (vert) / FAIL (rouge) dans le terminal -- desactive si NO_COLOR est
    positionne ou si stdout n'est pas un vrai terminal (redirection vers fichier/pipe)."""
    if not _COLOR_OK:
        return text
    code = "32" if ok else "31"
    return f"\033[{code}m{text}\033[0m"


def _warn(text: str) -> str:
    """Jaune/orange -- ecart de perimetre AF<->tests (non bloquant), distinct du rouge FAIL."""
    if not _COLOR_OK:
        return text
    return f"\033[33m{text}\033[0m"


def _ensure_gpp_in_path(debug: bool = False) -> None:
    """Si g++ n'est pas trouve dans le PATH (cas frequent : winget vient de l'installer mais
    le terminal/VS Code en cours n'a pas recharge son PATH), cherche dans les emplacements
    d'installation connus et l'ajoute pour CE process seulement -- evite de devoir fermer/
    rouvrir VS Code a chaque fois. N'ecrit jamais dans le PATH systeme/utilisateur."""
    if shutil.which("g++"):
        return
    candidates = []
    local_appdata = os.environ.get("LOCALAPPDATA")
    if local_appdata:
        candidates += list(pathlib.Path(local_appdata).glob(
            "Microsoft/WinGet/Packages/BrechtSanders.WinLibs*/mingw64/bin/g++.exe"))
    for fixed in (r"C:\mingw64\bin\g++.exe", r"C:\msys64\mingw64\bin\g++.exe"):
        p = pathlib.Path(fixed)
        if p.exists():
            candidates.append(p)
    if not candidates:
        return
    bin_dir = str(candidates[0].parent)
    os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")
    if debug:
        print(f"[info] g++ absent du PATH -- trouve automatiquement dans {bin_dir} (ajoute pour cette execution uniquement)")


def load_registry() -> dict:
    return yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))


def load_config() -> dict:
    if not CONFIG.exists():
        return {"cycle_time_ms": 10}
    return yaml.safe_load(CONFIG.read_text(encoding="utf-8"))


def _archive_previous(reports_dir: pathlib.Path, fb_name: str) -> None:
    """Deplace le dernier rapport (html/json) + le .st de test qui l'a produit vers
    reports/archive/, horodates ensemble -- pour que la racine reports/ ne contienne toujours
    que le DERNIER run, tout en gardant l'historique complet et tracable (quel .st a produit
    quel rapport, meme si le .st a ete modifie depuis)."""
    existing = [p for p in reports_dir.glob(f"{fb_name}.*") if p.is_file()] + \
               [p for p in reports_dir.glob(f"{fb_name}_test.*") if p.is_file()]
    if not existing:
        return
    archive_dir = reports_dir / "archive"
    archive_dir.mkdir(parents=True, exist_ok=True)
    timestamp = _dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    for p in existing:
        p.rename(archive_dir / f"{timestamp}_{p.name}")


def _find_strucpp_temp_dir(before: set, tmp_root: pathlib.Path) -> pathlib.Path | None:
    """STruCpp --test compile+build+execute dans un dossier strucpp-test-XXXXXX du TEMP
    systeme, jamais nettoye (constate empiriquement). On diffe avant/apres pour retrouver
    celui de CET appel (pas un dossier residuel d'un run precedent)."""
    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before
    candidates = new_dirs or after
    if not candidates:
        return None
    return max(candidates, key=lambda p: p.stat().st_mtime)


def run_one(fb_name: str, entry: dict, cycle_time_ms: float = 10, debug: bool = False) -> dict:
    """Retourne {"ok": bool, "tests": [{"name", "passed", "detail"}, ...], "report": path|None}.
    Le detail par test (pas seulement le statut global du FB) permet a un agent de lire le
    resultat complet depuis le seul stdout, sans devoir ouvrir le rapport HTML. En mode normal
    (debug=False), aucun log intermediaire n'est imprime -- seul le resume final compte."""
    domain = entry["domain"]
    sources = [REPO_ROOT / p for p in entry["sources"]]
    test_file = REPO_ROOT / entry["test"]

    def _log(*a):
        if debug:
            print(*a)

    print(f"-> {fb_name} ({domain})...", flush=True)
    _log(f"\n=== {fb_name} (domaine {domain}) ===")

    with tempfile.TemporaryDirectory(prefix=f"st2c_{fb_name}_") as tmp:
        converted_dir = pathlib.Path(tmp)
        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in sources], "--out", str(converted_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8")
        _log(result.stdout)
        if result.returncode != 0:
            print(f"[ERREUR] Conversion echouee pour {fb_name}")
            print(result.stderr, file=sys.stderr)
            return {"ok": False, "tests": [{"name": "(conversion)", "passed": False, "detail": "echec conversion moulinette"}], "report": None}

        converted_files = [str(converted_dir / s.name) for s in sources]
        out_cpp = converted_dir / f"{fb_name}.cpp"
        tmp_root = pathlib.Path(tempfile.gettempdir())
        before = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}

        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "--test", str(test_file)]
        result = subprocess.run(strucpp_cmd, capture_output=True, text=True, encoding="utf-8", cwd=str(converted_dir))
        text_report = result.stdout + result.stderr
        _log(text_report)

        strucpp_temp_dir = _find_strucpp_temp_dir(before, tmp_root)
        json_data = None
        trace_entries = []
        field_types = {}
        if strucpp_temp_dir is not None:
            test_runner = strucpp_temp_dir / "test_runner.exe"
            if test_runner.exists():
                json_result = subprocess.run([str(test_runner), "--json"], capture_output=True, text=True, encoding="utf-8")
                try:
                    json_data = json.loads(json_result.stdout)
                except json.JSONDecodeError:
                    json_data = None
            try:
                trace_entries, field_types = chronogram.build_and_run_traced(
                    strucpp_temp_dir, RUNTIME_INCLUDE, RUNTIME_TEST, fb_name.upper())
            except Exception as exc:  # chronogramme = bonus, ne doit jamais casser le run
                _log(f"[chronogram] indisponible pour {fb_name} : {exc}")
                trace_entries, field_types = [], {}

        wiring = None
        prod_instance = entry.get("prod_instance")
        if strucpp_temp_dir is not None and prod_instance:
            try:
                wiring = prod_wiring.build_wiring(
                    strucpp_temp_dir / "generated.hpp", fb_name.upper(),
                    REPO_ROOT / prod_instance["file"], prod_instance["name"],
                    search_root=REPO_ROOT / "CODE")
            except Exception as exc:  # cablage prod = bonus, ne doit jamais casser le run
                _log(f"[prod_wiring] indisponible pour {fb_name} : {exc}")
                wiring = None

        af_warnings = []
        extra_test_warnings = []
        af_doc = entry.get("af_doc")
        if af_doc:
            af_warnings = check_af_coverage(REPO_ROOT / af_doc, test_file, ignore=entry.get("af_ignore"))
            extra_test_warnings = check_extra_tests(REPO_ROOT / af_doc, test_file)

        reports_dir = TEST_AUTO_CI / "RESULTS" / domain / "reports"
        reports_dir.mkdir(parents=True, exist_ok=True)
        _archive_previous(reports_dir, fb_name)
        status = "PASS" if result.returncode == 0 else "FAIL"
        base = reports_dir / fb_name
        shutil.copyfile(test_file, reports_dir / f"{fb_name}_test.st")
        report_path = None
        report_group = entry.get("report_group")

        section_kwargs = dict(fb_name=fb_name, domain=domain, sources=entry["sources"],
                               json_data=json_data or {}, text_report=text_report,
                               test_st_path=test_file, trace_entries=trace_entries,
                               source_paths=sources, cycle_time_ms=cycle_time_ms,
                               field_types=field_types, af_warnings=af_warnings,
                               extra_test_warnings=extra_test_warnings, wiring=wiring)

        if json_data is not None:
            (base.with_suffix(".json")).write_text(json.dumps(json_data, indent=2), encoding="utf-8")
            if not report_group:
                html = render_html_report(**section_kwargs, test_file=str(entry["test"]))
                base.with_suffix(".html").write_text(html, encoding="utf-8")
                report_path = base.with_suffix(".html")
        else:
            base.with_suffix(".txt").write_text(text_report, encoding="utf-8")
            report_path = base.with_suffix(".txt")
        _log(f"Rapport : {report_path}")

        tests = []
        for r in (json_data or {}).get("results", []):
            detail = ""
            failure = r.get("failure")
            if failure:
                detail = f"{failure.get('assertType', '')}: {failure.get('detail', '')}"
                if failure.get("message"):
                    detail += f" -- {failure['message']}"
            tests.append({"name": r.get("name", ""), "passed": r.get("passed", False), "detail": detail})
        if not tests:
            tests = [{"name": "(pas de resultat JSON)", "passed": result.returncode == 0, "detail": ""}]

        return {"ok": result.returncode == 0, "tests": tests, "report": report_path,
                "af_warnings": af_warnings, "extra_test_warnings": extra_test_warnings,
                "report_group": report_group, "section_kwargs": section_kwargs}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--fb", help="Nom du FB a tester (cle du registry.yaml)")
    group.add_argument("--domain", help="Tester tous les FB d'un domaine (ex: AU_SECURITE, JOYSTICK)")
    group.add_argument("--all", action="store_true", help="Tester tous les FB du registre (defaut si aucune option)")
    parser.add_argument("--debug", action="store_true",
                         help="Affiche tous les logs intermediaires (conversion, sortie brute strucpp). "
                              "Sans cette option : uniquement le resultat final.")
    args = parser.parse_args()
    if not args.fb and not args.domain and not args.all:
        args.all = True

    _ensure_gpp_in_path(args.debug)

    if not STRUCPP.exists():
        print(f"[ERREUR] strucpp.exe introuvable : {STRUCPP}")
        return 1

    registry = load_registry()
    cycle_time_ms = load_config().get("cycle_time_ms", 10)

    if args.domain:
        selected = {name: e for name, e in registry.items() if e["domain"] == args.domain}
        if not selected:
            domains = sorted({e["domain"] for e in registry.values()})
            print(f"[ERREUR] Aucun FB dans le domaine '{args.domain}' -- domaines disponibles : {', '.join(domains)}")
            return 1
        results = {name: run_one(name, entry, cycle_time_ms, args.debug) for name, entry in selected.items()}
    elif args.fb:
        if args.fb not in registry:
            print(f"[ERREUR] '{args.fb}' absent de {REGISTRY} -- entrees disponibles : {', '.join(registry)}")
            return 1
        results = {args.fb: run_one(args.fb, registry[args.fb], cycle_time_ms, args.debug)}
    else:
        results = {name: run_one(name, entry, cycle_time_ms, args.debug) for name, entry in registry.items()}

    # Fiches de rapport groupees : plusieurs FB independants (compiles/testes separement)
    # partagent UNE seule page HTML -- registry.yaml en decide via "report_group".
    groups: dict = {}
    for name, res in results.items():
        rg = res.get("report_group")
        if rg:
            groups.setdefault(rg, []).append(name)
    group_report_paths = {}
    for group_name, members in groups.items():
        domain = registry[members[0]]["domain"]
        reports_dir = TEST_AUTO_CI / "RESULTS" / domain / "reports"
        reports_dir.mkdir(parents=True, exist_ok=True)
        _archive_previous(reports_dir, group_name)
        html = render_group_report(group_name, [results[m]["section_kwargs"] for m in members])
        path = reports_dir / f"{group_name}.html"
        path.write_text(html, encoding="utf-8")
        for m in members:
            results[m]["report"] = path
        group_report_paths[group_name] = path

    print("=== RESUME ===")
    for name, res in results.items():
        print(f"{_c('PASS' if res['ok'] else 'FAIL', res['ok'])}  {name}")
        for t in res["tests"]:
            line = f"  {_c('PASS' if t['passed'] else 'FAIL', t['passed'])}  {t['name']}"
            if not t["passed"] and t["detail"]:
                line += f"\n        {t['detail']}"
            print(line)
        for tc_id, intention in res.get("af_warnings", []):
            print(f"  {_warn('WARN')}  {tc_id} attendu par l AF (type AUTO) mais absent des tests -- {intention}")
        for tc_id in res.get("extra_test_warnings", []):
            print(f"  {_warn('WARN')}  {tc_id} teste mais absent du catalogue AF (ID inconnu ou retire)")
        if res["report"] and not res.get("report_group"):
            print(f"  Rapport : {res['report']}")
    for group_name, path in group_report_paths.items():
        print(f"Rapport groupe {group_name} : {path}")
    n_fail = sum(1 for res in results.values() if not res["ok"])
    summary = f"{len(results)} FB testes, {len(results) - n_fail} PASS, {n_fail} FAIL"
    print(f"\n{_c(summary, n_fail == 0)}")

    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
