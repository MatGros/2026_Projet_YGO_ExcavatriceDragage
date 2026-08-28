#!/usr/bin/env python3
"""Génère la trace scan-par-scan du cycle complet FB_Cycle depuis la COPIE DE TRAVAIL.

SOURCE_TESTÉE = WORKING_COPY/FB_Cycle.st (corrigé F1/F2/F6) — jamais CODE/.
Produit : RESULTS/G_CYCLE/reports/trace_semi_auto_cycle.json

Sémantique de la trace : logique de décision du séquenceur sous stimuli de harnais
scan-par-scan — PAS une dynamique physique réelle ni une cadence automate.

Chaque champ est étiqueté avec sa provenance :
  COMPILED          = calculé par le binaire ST compilé (sorties, états, décisions)
  HARNESS_STIMULUS  = injecté par le harnais (entrées capteurs/positions) — simulé
  CONFIG            = constante de configuration fournie au harnais
  DERIVED           = dérivé à la génération (Python, hors JS) pour le rendu

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/generate_trace_cycle.py
"""

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import chronogram

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
RUNTIME_INCLUDE = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "test"

# Copie de travail (source testée) — jamais CODE/
WORKING_COPY = TEST_AUTO_CI / "WORKING_COPY"
FB_SOURCE = WORKING_COPY / "CODE" / "G_CYCLE" / "FB_Cycle.st"
TEST_FILE = WORKING_COPY / "tests" / "test_fb_cycle_full.st"
OUT_JSON = TEST_AUTO_CI / "RESULTS" / "G_CYCLE" / "reports" / "trace_semi_auto_cycle.json"

# Fermeture de types complète de FB_Cycle (ordre de compilation = registry.yaml)
SOURCES = [
    "CODE/A_COMMUN/_TYPES/E_State.st",
    "CODE/A_COMMUN/_TYPES/ST_Fault.st",
    "CODE/A_COMMUN/_TYPES/ST_FaultCause.st",
    "CODE/A_COMMUN/_TYPES/ST_Lifecycle.st",
    "CODE/A_COMMUN/FB_FaultCore.st",
    "CODE/F_MODES/E_Mode.st",
    "CODE/G_CYCLE/_TYPES/E_CycleStep.st",
    "CODE/G_CYCLE/_TYPES/E_OperatorAxis.st",
    "CODE/G_CYCLE/_TYPES/E_ProgramSequence.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbCycle_WinchCmdDemand.st",
    "CODE/I_TRANSLATION/ST_fbCycle_TranslationCmdDemand.st",
    "CODE/H_TREUILS_BENNE/BENNE/_TYPES/ST_fbCycle_BucketCmdDemand.st",
    "CODE/G_CYCLE/FB_Cycle.st",
]

# Test cible pour la trace du cycle complet
TARGET_TEST = "TC-P04-100"

# Provenance des champs (source : interface FB_Cycle.st)
# COMPILED = sorties/états calculés par le binaire
COMPILED_FIELDS = {
    "Ready", "CycleStep", "CycleStateStr", "CycleStepAtError",
    "OperatorActionId", "OperatorAction", "ExpectedAxis", "ExpectedDirection",
    "WaitingForOperator", "WaitingForProcess", "RequestActive",
    "SpeedMismatchMps", "SpeedMismatchActive", "SpeedMismatchConfirmed",
    "WinchM1Cmd.StartStop", "WinchM1Cmd.Direction", "WinchM1Cmd.SpeedPct",
    "WinchM2Cmd.StartStop", "WinchM2Cmd.Direction", "WinchM2Cmd.SpeedPct",
    "TranslationCmd.Start", "TranslationCmd.Target",
    "BucketCmd.Open", "BucketCmd.Close", "BucketCmd.KoboldContactorCmd",
    "Fault.Error", "Fault.Latched", "Lifecycle.Busy", "Lifecycle.Done",
}
# HARNESS_STIMULUS = entrées capteurs/positions injectées par le harnais (simulé)
HARNESS_FIELDS = {
    "M1_CablePosM", "M2_CablePosM", "M1_MeasuredSpeedMps", "M2_MeasuredSpeedMps",
    "KoboldContactFond", "WinchSyncError", "WinchSyncDeltaM",
    "Translation_At_P1", "Translation_At_Tremie", "Translation_At_Maintenance",
    "Translation_Busy", "Translation_Done",
    "Benne_Busy", "Benne_Done", "Benne_IsOpen", "Benne_IsClosed", "Benne_IsRoughlyClosed",
    "HomedM1", "HomedM2", "TopPositionSensor", "HomingRequest",
    "LimitLegalReached", "PowerContactorEngaged", "DeadmanArmed",
    "CycleMotionPermit", "HeartbeatIhmOk", "StartCycle", "AbortCycle", "Enable", "Reset",
}
# CONFIG = constantes de configuration
CONFIG_FIELDS = {
    "SelTarget", "SetDepthM", "SetOffsetM", "LimitLegalDepthM",
    "SpeedMismatchThresholdMps", "SpeedMismatchTimeout", "CableLimitM1AscentM",
}


def _ensure_gpp_in_path() -> None:
    import shutil
    if shutil.which("g++"):
        return
    candidates = []
    local_appdata = __import__("os").environ.get("LOCALAPPDATA")
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
    __import__("os").environ["PATH"] = bin_dir + __import__("os").pathsep + __import__("os").environ.get("PATH", "")


def _find_strucpp_temp_dir(before: set, tmp_root: pathlib.Path) -> pathlib.Path | None:
    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before
    if not new_dirs:
        return None
    return max(new_dirs, key=lambda p: p.stat().st_mtime)


def _provenance(field: str) -> str:
    """Détermine la provenance d'un champ. Les clés extraites par chronogram sont en
    MAJUSCULES (ex: M1_CABLEPOSM, WINCHM1CMD.STARTSTOP) — on normalise en majuscules."""
    f = field.upper()
    if f in {x.upper() for x in COMPILED_FIELDS}:
        return "COMPILED"
    if f in {x.upper() for x in HARNESS_FIELDS}:
        return "HARNESS_STIMULUS"
    if f in {x.upper() for x in CONFIG_FIELDS}:
        return "CONFIG"
    return "DERIVED"


def _check_coherence(entries: list) -> list:
    """Contrôle de cohérence commande↔delta-position (garde-fou, hors JS).
    Pour chaque commande exigeant un mouvement, vérifie que la position captée évolue
    dans le bon sens entre scans consécutifs. Retourne la liste des incohérences.
    Clés en MAJUSCULES (chronogram)."""
    problems = []
    for i in range(1, len(entries)):
        prev, cur = entries[i - 1], entries[i]
        pf, cf = prev["fields"], cur["fields"]
        # M1 : StartStop + Direction -> M1_CablePosM doit évoluer dans le bon sens
        if pf.get("WINCHM1CMD.STARTSTOP") == "1" and cf.get("WINCHM1CMD.STARTSTOP") == "1":
            try:
                ppos = float(pf.get("M1_CABLEPOSM", "0"))
                cpos = float(cf.get("M1_CABLEPOSM", "0"))
                direction = int(cf.get("WINCHM1CMD.DIRECTION", "0"))
                if direction == 1 and cpos < ppos - 1e-6:
                    problems.append(f"scan {cur['scan']}: M1 commandé montée (dir=1) mais position décroît")
                if direction == -1 and cpos > ppos + 1e-6:
                    problems.append(f"scan {cur['scan']}: M1 commandé descente (dir=-1) mais position croît")
            except (ValueError, TypeError):
                pass
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(OUT_JSON), help="Chemin du JSON de sortie")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    if not FB_SOURCE.exists():
        print(f"[ERREUR] Source introuvable : {FB_SOURCE}")
        return 1
    if not STRUCPP.exists():
        print(f"[ERREUR] strucpp.exe introuvable : {STRUCPP}")
        return 1

    _ensure_gpp_in_path()

    src_paths = [WORKING_COPY / s for s in SOURCES]
    # Dossier temp DANS le workspace (writable) pour la conversion — le tempdir système
    # peut être bloqué pour l'écriture Python, mais STruCpp y crée ses strucpp-test-*.
    tmp_root = TEST_AUTO_CI / ".tmp_trace"
    tmp_root.mkdir(parents=True, exist_ok=True)
    import uuid
    work_dir = tmp_root / f"run_{uuid.uuid4().hex[:8]}"
    work_dir.mkdir(parents=True, exist_ok=True)
    # STruCpp crée ses dossiers strucpp-test-* dans le tempdir système
    sys_tmp_root = pathlib.Path(tempfile.gettempdir())

    try:
        converted_dir = work_dir
        subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0

        # 1. Conversion ST -> IEC
        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in src_paths], "--out", str(converted_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8",
                                creationflags=subproc_flags)
        if result.returncode != 0:
            print("[ERREUR] Conversion échouée")
            print(result.stderr)
            return 1

        converted_files = [str(converted_dir / s.name) for s in src_paths]
        out_cpp = converted_dir / "FB_Cycle.cpp"
        before = {p for p in sys_tmp_root.glob("strucpp-test-*") if p.is_dir()}

        # 2. Compilation STruCpp --test (cwd = dossier converti, comme run_tests.py)
        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "-O", "0",
                       "--cxx-flags", "-O0 -pipe", "--test", str(TEST_FILE)]
        proc = subprocess.Popen(strucpp_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", cwd=str(converted_dir), bufsize=1,
                                creationflags=subproc_flags)
        lines = list(proc.stdout)
        proc.wait()
        text_report = "".join(lines)

        strucpp_temp_dir = _find_strucpp_temp_dir(before, sys_tmp_root)
        if strucpp_temp_dir is None:
            print("[ERREUR] Dossier temp STruCpp introuvable")
            if args.debug:
                print(text_report[-3000:])
            return 1

        # 3. Trace scan-par-scan via chronogram (instrumentation)
        try:
            entries, field_types = chronogram.build_and_run_traced(
                strucpp_temp_dir, RUNTIME_INCLUDE, RUNTIME_TEST, "FB_CYCLE")
        except Exception as exc:
            print(f"[ERREUR] chronogram : {exc}")
            return 1

        # 4. Filtrer le test cible (préfixe : le nom de test inclut le titre complet)
        target_entries = [e for e in entries if e.get("test", "").startswith(TARGET_TEST)]
        if not target_entries:
            print(f"[ERREUR] Aucune trace pour le test '{TARGET_TEST}'")
            print(f"  Tests tracés : {sorted({e.get('test') for e in entries})}")
            return 1

        # 5. Contrôle de cohérence
        problems = _check_coherence(target_entries)
        if problems:
            print("[ERREUR] Incohérences commande↔position détectées :")
            for p in problems[:20]:
                print(f"  - {p}")
            return 1

        # 6. Étiqueter la provenance + construire le JSON
        scans = []
        for e in target_entries:
            fields = {}
            for k, v in e.get("fields", {}).items():
                fields[k] = {"value": v, "provenance": _provenance(k)}
            scans.append({"test": e.get("test"), "scan": e.get("scan"),
                          "t_ns": e.get("t_ns"), "fields": fields})

        source_sha = hashlib.sha256(FB_SOURCE.read_bytes()).hexdigest()
        payload = {
            "meta": {
                "generated_by": "generate_trace_cycle.py",
                "source": "WORKING_COPY/FB_Cycle.st (compilé STruCpp)",
                "source_sha256": source_sha,
                "semantics": "logique de décision du séquenceur sous stimuli de harnais scan-par-scan — PAS une dynamique physique réelle ni une cadence automate",
                "test": TARGET_TEST,
                "n_scans": len(scans),
            },
            "scans": scans,
        }
        payload_sha = hashlib.sha256(json.dumps(payload, ensure_ascii=False).encode("utf-8")).hexdigest()
        payload["meta"]["sha256"] = payload_sha

        out_path = pathlib.Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

        print(f"✅ Trace générée : {out_path}")
        print(f"   SOURCE_TESTÉE = WORKING_COPY/FB_Cycle.st")
        print(f"   source_sha256 = {source_sha}")
        print(f"   sha256 (trace) = {payload_sha}")
        print(f"   scans = {len(scans)} · test = {TARGET_TEST}")
        return 0
    finally:
        # Nettoyage best-effort (le sandbox peut bloquer la suppression)
        try:
            import shutil
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
