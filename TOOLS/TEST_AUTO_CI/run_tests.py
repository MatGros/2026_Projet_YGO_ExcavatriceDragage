#!/usr/bin/env python3
"""Runner de tests automatises pour FB CODESYS, base sur registry.yaml (source unique des
dependances -- jamais devinees a la volee). Pipeline par FB :

    sources (registry.yaml) --[moulinette COMPILER_ST2C_STruCpp]--> .st IEC standard
                             --[strucpp.exe --test]--> compile C++ + execute les ASSERT

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_Joystick
    python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --all

Necessite g++ (MinGW-w64) dans le PATH -- voir TOOLS/COMPILER_ST2C_STruCpp/README.md.
"""

import argparse
import datetime as _dt
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time as _time

# Configuration encodage UTF-8 sous Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Ajout du sous-dossier scripts au sys.path pour les modules internes
SCRIPT_DIR = pathlib.Path(__file__).resolve().parent / "scripts"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

# Module de post-traitement du test_main.cpp généré par STruCpp (T181-21) :
# injection du copy-out des VAR_IN_OUT après chaque appel s.FB().
COMPILER_DIR = pathlib.Path(__file__).resolve().parents[2] / "TOOLS" / "COMPILER_ST2C_STruCpp"
if str(COMPILER_DIR) not in sys.path:
    sys.path.insert(0, str(COMPILER_DIR))

import yaml

import chronogram
import prod_wiring
from af_coverage_v2 import check_af_coverage, check_extra_tests
from encapsulation_check import check_encapsulation_chain
from html_report import render_group_report, render_html_report
import inject_var_in_out_copyout

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


import threading


def _archive_previous(reports_dir: pathlib.Path, fb_name: str) -> None:
    """Archive une copie du rapport precedent vers reports/archive/ avec horodatage,
    tout en maintenant le dernier rapport actif a la racine pour le suivi Git."""
    existing = [p for p in reports_dir.glob(f"{fb_name}.*") if p.is_file()] + \
               [p for p in reports_dir.glob(f"{fb_name}_test.*") if p.is_file()]
    if not existing:
        return
    archive_dir = reports_dir / "archive"
    archive_dir.mkdir(parents=True, exist_ok=True)
    timestamp = _dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    for p in existing:
        try:
            shutil.copy2(p, archive_dir / f"{timestamp}_{p.name}")
        except Exception:
            pass


def _archive_previous_async(reports_dir: pathlib.Path, fb_name: str) -> None:
    """Lance l'archivage disque en arrière-plan sans bloquer la compilation CPU."""
    threading.Thread(target=_archive_previous, args=(reports_dir, fb_name), daemon=True).start()


def _find_strucpp_temp_dir(before: set, tmp_root: pathlib.Path) -> pathlib.Path | None:
    """STruCpp --test compile+build+execute dans un dossier strucpp-test-XXXXXX du TEMP
    systeme, jamais nettoye (constate empiriquement). On diffe avant/apres pour retrouver
    celui de CET appel (pas un dossier residuel d'un run precedent)."""
    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before
    if not new_dirs:
        return None
    return max(new_dirs, key=lambda p: p.stat().st_mtime)



def run_one(fb_name: str, entry: dict, cycle_time_ms: float = 10, debug: bool = False,
            enable_chronogram: bool = True, generate_reports: bool = True) -> dict:
    """Retourne {"ok": bool, "tests": [{"name", "passed", "detail"}, ...], "report": path|None}.
    Le detail par test (pas seulement le statut global du FB) permet a un agent de lire le
    resultat complet depuis le seul stdout, sans devoir ouvrir le rapport HTML. En mode normal
    (debug=False), aucun log intermediaire n'est imprime -- seul le resume final compte."""
    t_start_total = _time.perf_counter()
    domain = entry["domain"]
    sources = [REPO_ROOT / p for p in entry["sources"]]
    test_file = REPO_ROOT / entry["test"]

    # Archivage asynchrone immédiat : tourne en tâche de fond pendant que le CPU compile
    reports_dir = TEST_AUTO_CI / "RESULTS" / domain / "reports"
    if generate_reports:
        reports_dir.mkdir(parents=True, exist_ok=True)
        _archive_previous_async(reports_dir, fb_name)

    def _log(*a):
        if debug:
            try:
                print(*a)
            except UnicodeEncodeError:
                safe_str = " ".join(str(x) for x in a).encode("ascii", errors="replace").decode("ascii")
                print(safe_str)


    try:
        n_tests_declared = len(re.findall(r"^TEST\s+'", test_file.read_text(encoding="utf-8"), re.MULTILINE))
    except OSError:
        n_tests_declared = None

    def _progress_line(phase: str) -> str:
        return f"-> {fb_name} ({domain})... {phase}".ljust(70)

    if debug:
        print(_progress_line("conversion"), flush=True)
    _log(f"\n=== {fb_name} (domaine {domain}) ===")

    t_conv_start = _time.perf_counter()
    # STruCpp peut conserver brièvement un handle Windows dans le dossier de conversion.
    # Le résultat compilation/ASSERT fait foi ; un nettoyage différé ne doit pas le masquer.
    with tempfile.TemporaryDirectory(prefix=f"st2c_{fb_name}_", ignore_cleanup_errors=True) as tmp:
        converted_dir = pathlib.Path(tmp)
        # Flag de priorité basse sous Windows pour préserver 100% de la réactivité du PC
        subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0

        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in sources], "--out", str(converted_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8",
                                creationflags=subproc_flags)
        _log(result.stdout)
        t_conv = _time.perf_counter() - t_conv_start

        if result.returncode != 0:
            if debug:
                print(f"[ERREUR] Conversion echouee pour {fb_name}")
                print(result.stderr, file=sys.stderr)
            return {"ok": False, "tests": [{"name": "(conversion)", "passed": False, "detail": "echec conversion moulinette"}], "report": None, "timings": {"conversion": t_conv}}

        converted_files = [str(converted_dir / s.name) for s in sources]
        out_cpp = converted_dir / f"{fb_name}.cpp"
        # Dossier TEMP dedie a ce job : STruCpp cree son strucpp-test-XXXXXX DANS %TEMP%, jamais
        # nettoye (cf chronogram.py). Sous execution parallele (-j > 1, defaut = CPU-4), plusieurs
        # process STruCpp partagent le meme TEMP systeme -- le diff avant/apres de
        # _find_strucpp_temp_dir peut alors recuperer le dossier d'un AUTRE FB en cours de
        # compilation concurrente (contamination croisee : JSON manquant, chronogramme vide,
        # ASSERT non-deterministes, WinError 32 constates le 2026-08-26). On isole donc chaque job
        # dans son propre sous-dossier TEMP via l'env TEMP/TMP (respecte par STruCpp comme tout
        # binaire Windows standard) : le diff avant/apres ne voit plus alors que SES propres
        # sous-dossiers strucpp-test-*, quel que soit le nombre de jobs concurrents.
        job_tmp_root = pathlib.Path(tempfile.mkdtemp(prefix=f"ci_job_{fb_name}_"))
        job_env = dict(os.environ, TEMP=str(job_tmp_root), TMP=str(job_tmp_root))
        tmp_root = job_tmp_root
        before = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}

        if debug:
            print(_progress_line("compilation"), flush=True)
        t_comp_start = _time.perf_counter()
        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "-O", "0", "--cxx-flags", "-O0 -pipe", "--test", str(test_file)]
        proc = subprocess.Popen(strucpp_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, encoding="utf-8", cwd=str(converted_dir), bufsize=1,
                                 creationflags=subproc_flags, env=job_env)
        lines = list(proc.stdout)
        proc.wait()
        t_comp = _time.perf_counter() - t_comp_start
        result = subprocess.CompletedProcess(strucpp_cmd, proc.returncode, "".join(lines), "")
        text_report = result.stdout + result.stderr
        _log(text_report)

        strucpp_temp_dir = _find_strucpp_temp_dir(before, tmp_root)
        json_data = None
        test_runner_rc = None
        trace_entries = []
        field_types = {}
        t_exec = 0.0
        t_chrono = 0.0
        if strucpp_temp_dir is not None:
            # --- T181-21 : post-traitement VAR_IN_OUT (copy-out) ---
            # STruCpp génère un copy-in seul (s.FB.X = s.X;) avant chaque appel,
            # sans jamais le copy-out (s.X = s.FB.X;). Or CODESYS 3.5 passe les
            # VAR_IN_OUT par référence. On injecte le copy-out des VAR_IN_OUT du
            # FB testé après chaque appel, puis on recompile le runner avec g++.
            # Le mapping est sans ambiguïté (ligne de copy-in s.FB.X = s.Y;).
            copyout_exe = None
            fb_st_path = next((s for s in sources if s.name == f"{fb_name}.st"), None)
            if fb_st_path is not None:
                try:
                    modified = inject_var_in_out_copyout.postprocess_file(
                        strucpp_temp_dir / "test_main.cpp", fb_st_path, fb_var="FB")
                    if modified:
                        copyout_exe = inject_var_in_out_copyout.recompile_test_runner(
                            strucpp_temp_dir, RUNTIME_INCLUDE, RUNTIME_TEST)
                        if copyout_exe is None:
                            _log(f"[var_in_out] recompilation copy-out échouée pour {fb_name} -- "
                                 f"retour au test_runner.exe original de STruCpp")
                except Exception as exc:
                    _log(f"[var_in_out] post-traitement indisponible pour {fb_name} : {exc}")
            test_runner = copyout_exe or (strucpp_temp_dir / "test_runner.exe")
            if test_runner.exists():
                t_exec_start = _time.perf_counter()
                json_result = subprocess.run([str(test_runner), "--json"], capture_output=True, text=True, encoding="utf-8",
                                             creationflags=subproc_flags)
                test_runner_rc = json_result.returncode
                t_exec = _time.perf_counter() - t_exec_start
                try:
                    json_data = json.loads(json_result.stdout)
                except json.JSONDecodeError:
                    json_data = None
            if enable_chronogram:
                if debug:
                    print(_progress_line("chronogramme"), flush=True)
                t_chrono_start = _time.perf_counter()
                try:
                    trace_entries, field_types = chronogram.build_and_run_traced(
                        strucpp_temp_dir, RUNTIME_INCLUDE, RUNTIME_TEST, fb_name.upper())
                except Exception as exc:  # chronogramme = bonus, ne doit jamais casser le run
                    _log(f"[chronogram] indisponible pour {fb_name} : {exc}")
                    trace_entries, field_types = [], {}
                t_chrono = _time.perf_counter() - t_chrono_start

        # prod_instances (liste) : plusieurs instances production du meme FB (ex: instEncoderM1/
        # instEncoderM2, un FB par treuil). prod_instance (singulier) reste supporte pour les FB
        # mono-instance (ex: FB_Joystick) -- retro-compat, converti en liste a 1 element ici.
        prod_instances = entry.get("prod_instances")
        if prod_instances is None:
            # Mono-instance (legacy prod_instance) : pas de label -- une seule instance donc pas
            # d'ambiguite a lever dans le rapport.
            single = entry.get("prod_instance")
            prod_instances = [dict(single, label=None)] if single else [
                {"file": None, "name": None, "label": None}]
        else:
            prod_instances = [dict(pi, label=pi.get("label", pi.get("name"))) for pi in prod_instances]

        t_wiring_start = _time.perf_counter()
        wirings = []
        if strucpp_temp_dir is not None:
            # Extraction des pins (verite compilateur) toujours tentee, meme sans prod_instances :
            # build_wiring degrade proprement en pinout nu (tous les pins "non cable en
            # production") quand prod_file est None -- c'est le seul moyen de voir la boite
            # noire IN/OUT d'un FB pas encore instancie dans un PRG.
            print(f"\r{_progress_line('cablage production')}", end="", flush=True)
            for pi in prod_instances:
                try:
                    w = prod_wiring.build_wiring(
                        strucpp_temp_dir / "generated.hpp", fb_name.upper(),
                        REPO_ROOT / pi["file"] if pi.get("file") else None,
                        pi.get("name"),
                        search_root=REPO_ROOT / "CODE")
                except Exception as exc:  # cablage prod = bonus, ne doit jamais casser le run
                    _log(f"[prod_wiring] indisponible pour {fb_name} ({pi.get('label')}) : {exc}")
                    w = None
                wirings.append({"label": pi.get("label"), "wiring": w})
        else:
            wirings = [{"label": pi.get("label"), "wiring": None} for pi in prod_instances]
        t_wiring = _time.perf_counter() - t_wiring_start

        if generate_reports:
            print(f"\r{_progress_line('rapport')}", end="", flush=True)

        t_af_start = _time.perf_counter()
        af_warnings = []
        extra_test_warnings = []
        af_doc = entry.get("af_doc")
        if af_doc:
            af_warnings = check_af_coverage(REPO_ROOT / af_doc, test_file, ignore=entry.get("af_ignore"))
            extra_test_warnings = check_extra_tests(REPO_ROOT / af_doc, test_file)

        try:
            encapsulation_report = check_encapsulation_chain(sources)
        except Exception as exc:  # bonus, ne doit jamais casser le run
            _log(f"[encapsulation_check] indisponible pour {fb_name} : {exc}")
            encapsulation_report = []
        t_af = _time.perf_counter() - t_af_start

        report_path = None
        report_group = entry.get("report_group") if generate_reports else None

        section_kwargs = dict(fb_name=fb_name, domain=domain, sources=entry["sources"],
                               json_data=json_data or {}, text_report=text_report,
                               test_st_path=test_file, trace_entries=trace_entries,
                               source_paths=sources, cycle_time_ms=cycle_time_ms,
                               field_types=field_types, af_warnings=af_warnings,
                               extra_test_warnings=extra_test_warnings, wirings=wirings,
                               encapsulation_report=encapsulation_report,
                               source_prg=entry.get("source_prg"))

        t_rep_start = _time.perf_counter()
        if generate_reports:
            base = reports_dir / fb_name
            shutil.copyfile(test_file, reports_dir / f"{fb_name}_test.st")
            if json_data is not None:
                (base.with_suffix(".json")).write_text(json.dumps(json_data, indent=2), encoding="utf-8")
                html = render_html_report(**section_kwargs, test_file=str(entry["test"]))
                base.with_suffix(".html").write_text(html, encoding="utf-8")
                report_path = base.with_suffix(".html")
            else:
                base.with_suffix(".txt").write_text(text_report, encoding="utf-8")
                report_path = base.with_suffix(".txt")
            _log(f"Rapport : {report_path}")
        t_rep = _time.perf_counter() - t_rep_start

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

        t_total = _time.perf_counter() - t_start_total

        timings = {
            "conversion": t_conv,
            "compilation": t_comp,
            "execution": t_exec,
            "chronogram": t_chrono,
            "wiring": t_wiring,
            "af_encapsulation": t_af,
            "report_generation": t_rep,
            "total": t_total,
        }

        n_pass = sum(1 for t in tests if t["passed"])
        counter = f" {n_pass}/{len(tests)}" if n_tests_declared else ""
        print(f"\r{f'-> {fb_name} ({domain})...{counter}'.ljust(70)}")

        ok = result.returncode == 0 and test_runner_rc == 0 and bool(json_data) and all(t["passed"] for t in tests)
        return {"ok": ok, "tests": tests, "report": report_path,
                "af_warnings": af_warnings, "extra_test_warnings": extra_test_warnings,
                "encapsulation_report": encapsulation_report,
                "report_group": report_group, "section_kwargs": section_kwargs,
                "timings": timings}


def main() -> int:
    # Calibrage CPU puissant & fluide :
    # Sur 16 threads logiques -> 12 workers en parallèle, 4 threads entièrement préservés pour Windows/IHM
    cpu_total = os.cpu_count() or 4
    default_workers = max(1, cpu_total - 4) if cpu_total > 4 else max(1, cpu_total - 1)

    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--fb", help="Nom du FB a tester (cle du registry.yaml)")
    group.add_argument("--domain", nargs="+", help="Tester tous les FB d'un ou plusieurs domaines (ex: A_COMMUN B_AU_SECURITE)")
    group.add_argument("--all", action="store_true", help="Tester tous les FB du registre (defaut si aucune option)")
    parser.add_argument("-j", "--jobs", type=int, default=default_workers,
                        help=f"Nombre d'instances de test en parallele (defaut calibre : {default_workers} threads)")
    parser.add_argument("--fast", "--no-chronogram", dest="fast", action="store_true",
                        help="CI rapide : simulation/assertions, sans chronogramme ni écriture de rapports")
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
    enable_chronogram = not args.fast
    generate_reports = not args.fast

    start_time = _time.perf_counter()

    if args.domain:
        req_domains = set(args.domain)
        targets = {name: e for name, e in registry.items() if e["domain"] in req_domains}
        if not targets:
            domains = sorted({e["domain"] for e in registry.values()})
            print(f"[ERREUR] Aucun FB dans les domaines '{args.domain}' -- domaines disponibles : {', '.join(domains)}")
            return 1
    elif args.fb:
        if args.fb not in registry:
            print(f"[ERREUR] '{args.fb}' absent de {REGISTRY} -- entrees disponibles : {', '.join(registry)}")
            return 1
        targets = {args.fb: registry[args.fb]}
    else:
        targets = registry

    # Exécution des tests (Parallèle si plusieurs cibles, séquentiel si debug ou 1 seul)
    results = {}
    if len(targets) > 1 and not args.debug and args.jobs > 1:
        from concurrent.futures import ProcessPoolExecutor, as_completed
        workers = min(len(targets), args.jobs)
        print(f">> Lancement de {len(targets)} tests en parallele sur {workers} threads CPU...\n")
        with ProcessPoolExecutor(max_workers=workers) as executor:
            future_to_name = {
                executor.submit(run_one, name, entry, cycle_time_ms, False, enable_chronogram, generate_reports): name
                for name, entry in targets.items()
            }
            completed_count = 0
            total_count = len(targets)
            for future in as_completed(future_to_name):
                name = future_to_name[future]
                completed_count += 1
                try:
                    res = future.result()
                    results[name] = res
                    ok = res.get("ok", False)
                    status_tag = _c("PASS", ok) if ok else _c("FAIL", False)
                    n_p = sum(1 for t in res.get("tests", []) if t.get("passed"))
                    n_t = len(res.get("tests", []))
                    print(f"  [{completed_count:2d}/{total_count:2d}] {status_tag} {name:28s} ({n_p}/{n_t} test(s) OK)")
                except Exception as exc:
                    print(f"  [{completed_count:2d}/{total_count:2d}] {_c('FAIL', False)} {name:28s} (Erreur : {exc})")
                    results[name] = {"ok": False, "tests": [{"name": str(exc), "passed": False, "detail": ""}],
                                     "report": None, "report_group": None, "section_kwargs": {}}
        print()
    else:
        results = {name: run_one(name, entry, cycle_time_ms, args.debug, enable_chronogram, generate_reports) for name, entry in targets.items()}

    # Fiches de rapport groupees : plusieurs FB independants (compiles/testes separement)
    # partagent UNE seule page HTML -- registry.yaml en decide via "report_group".
    groups: dict = {}
    for name, res in results.items():
        rg = res.get("report_group")
        if rg:
            groups.setdefault(rg, []).append(name)
    group_report_paths = {}
    for group_name, members in groups.items():
        if not generate_reports:
            continue
        if len(members) > 1 or args.all or args.domain:
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
        n_pass = sum(1 for t in res["tests"] if t["passed"])
        print(f"{_c('PASS' if res['ok'] else 'FAIL', res['ok'])}  {name} ({n_pass}/{len(res['tests'])})")
        for t in res["tests"]:
            line = f"  {_c('PASS' if t['passed'] else 'FAIL', t['passed'])}  {t['name']}"
            if not t["passed"] and t["detail"]:
                line += f"\n        {t['detail']}"
            print(line)
        for tc_id, intention in res.get("af_warnings", []):
            print(f"  {_warn('WARN')}  {tc_id} attendu par l AF (type AUTO) mais absent des tests -- {intention}")
        for tc_id in res.get("extra_test_warnings", []):
            print(f"  {_warn('WARN')}  {tc_id} teste mais absent du catalogue AF (ID inconnu ou retire)")
        encaps = res.get("encapsulation_report", [])
        if encaps:
            print("  -- Encapsulation (interface FB) --")
            for e in encaps:
                ok = not e["has_violation"]
                tag = _c("PASS" if ok else "FAIL", ok)
                print(f"    {tag}  {e['fb_name']:24s} IN={e['n_input']} OUT={e['n_output']} "
                      f"IN_OUT={e['n_inout']} LOCAL={e['n_local']}")
                for w in e["external_writes"]:
                    print(f"        ecriture externe non declaree : {w}")
                for g in e["gvl_refs"]:
                    print(f"        acces GVL direct (bypass interface) : {g}")
        timings = res.get("timings")
        if timings:
            print("  -- [PROFILING] Temps des etapes --")
            print(f"    * Conversion ST->IEC        : {timings.get('conversion', 0.0):.2f}s")
            print(f"    * Compilation STruCpp/g++   : {timings.get('compilation', 0.0):.2f}s (CPU)")
            print(f"    * Execution binaire ASSERTs : {timings.get('execution', 0.0):.2f}s")
            if timings.get('chronogram', 0.0) > 0:
                print(f"    * Chronogramme (recomp g++) : {timings.get('chronogram', 0.0):.2f}s")
            print(f"    * Cablage production        : {timings.get('wiring', 0.0):.2f}s")
            print(f"    * Rapport HTML / JSON       : {timings.get('report_generation', 0.0):.2f}s")
            print(f"    * Total FB                  : {timings.get('total', 0.0):.2f}s")
        if res["report"] and not res.get("report_group"):
            try:
                uri = pathlib.Path(res["report"]).resolve().as_uri()
            except Exception:
                uri = str(res["report"])
            print(f"  Rapport HTML : {uri}")
    for group_name, path in group_report_paths.items():
        try:
            uri = pathlib.Path(path).resolve().as_uri()
        except Exception:
            uri = str(path)
        print(f"Rapport groupe {group_name} : {uri}")

    # Génération du dashboard index.html à la racine de TEST_AUTO_CI (Maintien de l'intégralité des briques)
    if generate_reports:
        from html_report import render_index_dashboard
        index_state_file = TEST_AUTO_CI / "RESULTS" / ".index_state.json"
        saved_state = {}
        if index_state_file.exists():
            try:
                import json
                saved_state = json.loads(index_state_file.read_text(encoding="utf-8"))
            except Exception:
                saved_state = {}
        
        # Pour chaque FB de tout le registre, s'il n'a pas encore de state, l'initialiser
        for reg_name, reg_entry in registry.items():
            if reg_name not in saved_state:
                r_dom = reg_entry.get("domain", "AUTRES")
                r_rg = reg_entry.get("report_group")
                if r_rg:
                    r_rep = TEST_AUTO_CI / "RESULTS" / r_dom / "reports" / f"{r_rg}.html"
                else:
                    r_rep = TEST_AUTO_CI / "RESULTS" / r_dom / "reports" / f"{reg_name}.html"
                r_exists = r_rep.exists()
                saved_state[reg_name] = {
                    "ok": False,
                    "report": str(r_rep) if r_exists else None,
                    "report_group": r_rg,
                    "section_kwargs": {"domain": r_dom},
                    "tests": []
                }

        # Mettre à jour avec les résultats fraîchement exécutés
        now_str = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        for name, res in results.items():
            saved_state[name] = {
                "ok": res.get("ok", False),
                "report": str(res["report"]) if res.get("report") else None,
                "report_group": res.get("report_group"),
                "section_kwargs": res.get("section_kwargs", {}),
                "tests": res.get("tests", []),
                "updated_at": now_str
            }

        try:
            import json
            index_state_file.parent.mkdir(parents=True, exist_ok=True)
            index_state_file.write_text(json.dumps(saved_state, indent=2), encoding="utf-8")
        except Exception:
            pass

        index_html = render_index_dashboard(saved_state, group_report_paths)
        index_path = TEST_AUTO_CI / "index.html"
        index_path.write_text(index_html, encoding="utf-8")
        try:
            d_uri = index_path.resolve().as_uri()
        except Exception:
            d_uri = str(index_path)
        print(f"\n[DASHBOARD GLOBAL] : {d_uri}")

    elapsed = _time.perf_counter() - start_time
    minutes = int(elapsed // 60)
    seconds = elapsed % 60
    time_str = f"{minutes}m {seconds:.2f}s" if minutes > 0 else f"{seconds:.2f}s"

    n_fail = sum(1 for res in results.values() if not res["ok"])
    summary = f"{len(results)} FB testes, {len(results) - n_fail} PASS, {n_fail} FAIL"
    print(f"\n{_c(summary, n_fail == 0)}")
    print(f"[TEMPS D'EXECUTION] : {time_str}")

    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
