#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Automation of naming style checks for IEC 61131-3 ST code (G110_check_naming_style.py)
Référentiel : DOC/STDS/NAMING_CONVENTION.md (Règles NC-010 à NC-070)
Audit d'origine : DOC/WFLOW/AUDITS/AUDIT_Nommage_Mecanisable_v1.0.md
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from pathlib import Path

# Force UTF-8 stdout if possible to avoid CP1252 printing errors on Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

def get_rel_path(p: str | Path, root: str | Path) -> str:
    return os.path.relpath(str(p), str(root)).replace("\\", "/")

def load_baseline(baseline_path: Path) -> dict[str, list[dict]]:
    if not baseline_path.exists():
        return {}
    try:
        with open(baseline_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data.get("recenses", {})
    except Exception as e:
        print(f"WARNING: Unable to load baseline {baseline_path}: {e}", file=sys.stderr)
        return {}

def save_baseline(baseline_path: Path, recenses: dict[str, list[dict]]) -> None:
    baseline_path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "version": "1.0",
        "description": "Baseline des occurrences de nommage recensees lors de l'audit (DOC/WFLOW/AUDITS/AUDIT_Nommage_Mecanisable_v1.0.md)",
        "recenses": recenses
    }
    with open(baseline_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"[OK] Baseline sauvegardee dans {get_rel_path(baseline_path, Path('.'))}")

def scan_naming(target_dir: Path, repo_root: Path) -> tuple[dict, dict]:
    st_files = sorted(target_dir.rglob("*.st"))
    
    re_decl = re.compile(r"^\s*([a-zA-Z0-9_]+)\s*:\s*([^;]+);", re.MULTILINE)
    re_fb_inst = re.compile(r"^\s*([a-zA-Z0-9_]+)\s*:\s*(FB_[a-zA-Z0-9_]+)\s*;", re.MULTILINE)
    re_hongrois = re.compile(r"\b([birw]|dw|str)([A-Z][a-zA-Z0-9_]*)\b")
    KEYWORDS_EXCLUDED = {"REAL", "INT", "BOOL", "BYTE", "WORD", "DWORD", "STRING", "R_TRIG", "F_TRIG", "LREAL", "SINT", "USINT", "UINT", "UDINT", "ULINT", "WSTRING"}
    
    UNITS = ["M", "Pct", "Hz", "Ms", "Mps", "Sec", "Deg"]
    EXCLUDED_M_WORDS = {
        "SYSTEM", "PARAM", "ALARM", "DIAG", "BOOM", "BEAM", "STREAM", "MAX", "MIN", 
        "MEDIUM", "INFORM", "FIRM", "TERM", "FORM", "SLIM", "TRIM", "PROGRAM", "ENUM",
        "CHECKSUM", "TELEGRAM", "CUSTOM", "BOTTOM", "TOPM", "FSM", "HMI", "RAM", "ROM",
        "NORM", "PERM", "TRANSFORM", "SPECTRUM", "MAXIMUM", "MINIMUM", "OPTIMUM"
    }

    LEGACY_BASELINE_EXCEPTIONS = {
        "BrakeCmd", "M1BrakeCmd", "M2BrakeCmd", "TranslationBrakeCmd",
        "OpenReq", "CloseReq",
        "WinchM1Cmd", "WinchM2Cmd", "TranslationCmd", "BucketCmd",
        "PresetTriggerCmd", "CodeSeqTriggerCmd", "KoboldContactorCmd"
    }

    EXEMPT_SUBSTRUCT_NAMES_060 = {
        "Cmd", "Bypass", "Safety", "Preflight", "WinchSymmetry", "Bucket", 
        "BusCanOpen", "Joystick", "EncoderM1", "EncoderM2", "VariateurM3", "InputModules"
    }

    EXEMPT_FIELD_PATTERNS_060 = [
        r"^(Ready|Busy|Done|Error|Fault|State|FBState|MechState)$",
        r"^(Homed|HomingBusy|HomingDone|HomingError|HomingSuspect)$",
        r"^(PreflightOk|PreflightDone|PreflightBusy|SymmetryOk|SymmetryValid)$",
        r"^(LocalDigitalIoOk|Vh0800EndOk|Vh0808EtpOk|CanError|EcatError|SlaveOperational)$",
        r"^(HeartbeatIhmOk|HeartbeatIhmTimeout|ConfigRestoredFromPersistent)$",
        r"^(TopPositionSensorActive|BrakeThermalFault|PhaseRotationFault|LimitLegalReached|HydraulicThermalFault)$",
        r"^(SimTopSensorBypassActive|SimSlackCableBypassActive|KoboldImmersionConfirmed|KoboldBottomTouchLatched)$",
        r"^(CloseActive|OpenActive|AutoBucketSeqActive|CoupledDiveOpenArmed|CoupledAscentCloseArmed|ControlAscentActive|CoupledMotionBlockedByBucket)$",
        r"^(Position.*|Speed.*|CablePos.*|RawPos|PresetValueOut|Alarms|Warnings|.*ErrorId|.*ErrorId.*)$",
        r"^(HomingState|HomingStateAtError|HomingRefRaw|HomingErrorId|M2PositionCorrected)$",
        r"^(DeltaStartDelay_Ms|DeltaBrakeReleaseTime_Ms|DeltaBrakeApplyTime_Ms|DeltaStopTime_Ms|HeartbeatIhmElapsed)$",
    ]

    VALID_IHM_PREFIXES_060 = ("Btn", "Sel", "Set", "Tgl", "Cfg", "Tst")

    results = {
        "NC-010": {"conf": 0, "recenses": [], "total": 0},
        "NC-020": {"conf": 0, "recenses": [], "total": 0},
        "NC-030": {"conf": 0, "recenses": [], "total": 0},
        "NC-050": {"conf": 0, "legacy": 0, "recenses": [], "total": 0},
        "NC-060": {"conf": 0, "exemptes": 0, "recenses": [], "total": 0},
        "NC-070": {"conf": 0, "recenses": [], "total": 0},
        "NC-080": {"conf": 0, "recenses": [], "total": 0},
    }

    for fpath in st_files:
        rel_path = get_rel_path(fpath, repo_root)
        try:
            with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
        except Exception:
            continue

        is_gvl_persistent = (fpath.name == "GVL_PERSISTENT.st")
        is_st_hmi = ("SUPERVISION" in str(fpath) and "_TYPES" in str(fpath) and fpath.name.startswith("ST_") and "HMI" in fpath.name)

        in_var = False
        in_struct = False

        for idx, line in enumerate(lines, 1):
            line_str = line.strip()
            
            # Context tracking
            if re.search(r"\b(VAR|VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR_STAT|VAR_TEMP|VAR_EXTERNAL|VAR_GLOBAL)\b", line):
                in_var = True
            elif re.search(r"\bEND_VAR\b", line):
                in_var = False

            if "STRUCT" in line:
                in_struct = True
            elif "END_STRUCT" in line:
                in_struct = False

            # --- NC-010 : FB instances ---
            if in_var:
                m_fb = re_fb_inst.search(line)
                if m_fb:
                    vname, fb_type = m_fb.group(1), m_fb.group(2)
                    results["NC-010"]["total"] += 1
                    if vname.startswith("inst"):
                        results["NC-010"]["conf"] += 1
                    else:
                        results["NC-010"]["recenses"].append({
                            "file": rel_path, "line": idx, "name": vname, "type": fb_type, "snippet": line_str
                        })

            # --- NC-020 : Notation hongroise ---
            if in_var or in_struct:
                m_d = re_decl.search(line)
                if m_d:
                    vname = m_d.group(1)
                    hm = re_hongrois.search(vname)
                    results["NC-020"]["total"] += 1
                    if hm and hm.group(0) not in KEYWORDS_EXCLUDED:
                        results["NC-020"]["recenses"].append({
                            "file": rel_path, "line": idx, "name": vname, "snippet": line_str
                        })
                    else:
                        results["NC-020"]["conf"] += 1

            # --- NC-030 : Suffixe unité avec '_' ---
            if in_var or in_struct:
                m_d = re_decl.search(line)
                if m_d:
                    vname = m_d.group(1)
                    matched_unit = None
                    for u in UNITS:
                        if vname.endswith(u) or ("_" + u + "_") in vname or ("_" + u) in vname:
                            if u == "M":
                                if re.search(r"M[123]($|_)", vname):
                                    continue
                                upper_v = vname.upper()
                                if any(upper_v.endswith(w) for w in EXCLUDED_M_WORDS):
                                    continue
                            matched_unit = u
                            break
                    if matched_unit:
                        results["NC-030"]["total"] += 1
                        if ("_" + matched_unit) in vname:
                            results["NC-030"]["conf"] += 1
                        else:
                            results["NC-030"]["recenses"].append({
                                "file": rel_path, "line": idx, "name": vname, "unit": matched_unit, "snippet": line_str
                            })

            # --- NC-050 : Cmd/Req préfixe vs suffixe ---
            if in_var or in_struct:
                m_d = re_decl.search(line)
                if m_d:
                    vname = m_d.group(1)
                    if not (vname.endswith("_DI") or vname.endswith("_DQ") or vname.endswith("_RQ")):
                        has_cmd = "Cmd" in vname
                        has_req = "Req" in vname or "Request" in vname
                        if has_cmd or has_req:
                            is_prefix = vname.startswith("Cmd") or vname.startswith("Req") or vname.startswith("Request")
                            is_suffix = vname.endswith("Cmd") or vname.endswith("Req") or vname.endswith("Request") or vname.endswith("_Cmd")
                            results["NC-050"]["total"] += 1
                            if is_prefix:
                                results["NC-050"]["conf"] += 1
                            elif is_suffix:
                                if vname in LEGACY_BASELINE_EXCEPTIONS or any(vname.endswith(ex) for ex in ["BrakeCmd", "OpenReq", "CloseReq"]):
                                    results["NC-050"]["legacy"] += 1
                                else:
                                    results["NC-050"]["recenses"].append({
                                        "file": rel_path, "line": idx, "name": vname, "snippet": line_str
                                    })
                            else:
                                results["NC-050"]["recenses"].append({
                                    "file": rel_path, "line": idx, "name": vname, "snippet": line_str
                                })

            # --- NC-060 : Champs ST_*HMI ---
            if is_st_hmi and in_struct:
                m_d = re_decl.search(line)
                if m_d:
                    fname, ftype = m_d.group(1).strip(), m_d.group(2).strip()
                    results["NC-060"]["total"] += 1
                    
                    if fname in EXEMPT_SUBSTRUCT_NAMES_060 or ftype.startswith("ST_"):
                        results["NC-060"]["exemptes"] += 1
                        continue
                    is_ex = False
                    for pat in EXEMPT_FIELD_PATTERNS_060:
                        if re.match(pat, fname):
                            is_ex = True
                            break
                    if is_ex:
                        results["NC-060"]["exemptes"] += 1
                        continue

                    has_valid = any(fname.startswith(p) for p in VALID_IHM_PREFIXES_060)
                    has_us = any(fname.startswith(p + "_") for p in VALID_IHM_PREFIXES_060)
                    has_cr = ("Cmd" in fname) or ("Req" in fname)

                    if has_valid and not has_us and not has_cr:
                        results["NC-060"]["conf"] += 1
                    else:
                        results["NC-060"]["recenses"].append({
                            "file": rel_path, "line": idx, "name": fname, "type": ftype, "snippet": line_str
                        })

            # --- NC-070 : GVL_PERSISTENT préfixé '_' ---
            if is_gvl_persistent and in_var:
                m_d = re_decl.search(line)
                if m_d:
                    vname = m_d.group(1)
                    results["NC-070"]["total"] += 1
                    if vname.startswith("_"):
                        results["NC-070"]["conf"] += 1
                    else:
                        results["NC-070"]["recenses"].append({
                            "file": rel_path, "line": idx, "name": vname, "snippet": line_str
                        })

            # --- NC-080 : Bannissement de Ref pour les consignes (IEC/PLCopen) ---
            if in_var or in_struct:
                m_d = re_decl.search(line)
                if m_d:
                    vname = m_d.group(1)
                    results["NC-080"]["total"] += 1
                    is_banned_ref = any(term in vname for term in ["SpeedRef", "DriveFreqRef", "CablePosRef", "PosRef", "ActiveSpeedRef", "Ref_Pct", "RefPct"])
                    if is_banned_ref:
                        results["NC-080"]["recenses"].append({
                            "file": rel_path, "line": idx, "name": vname, "snippet": line_str
                        })
                    else:
                        results["NC-080"]["conf"] += 1

    return results, {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Vérification du nommage IEC 61131-3 (NC-010 à NC-070)")
    parser.add_argument("target", nargs="?", default="CODE", help="Dossier cible à scanner (défaut: CODE)")
    parser.add_argument("--update-baseline", action="store_true", help="Mettre à jour le fichier de baseline config/naming_baseline.json")
    parser.add_argument("--report", action="store_true", help="Afficher le détail de toutes les occurrences recensées")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[3]
    target_dir = repo_root / args.target if not Path(args.target).is_absolute() else Path(args.target)
    baseline_path = repo_root / "TOOLS" / "AGENT_WORKFLOW" / "config" / "naming_baseline.json"

    if not target_dir.exists():
        print(f"ERROR: Dossier cible introuvable: {target_dir}", file=sys.stderr)
        return 0  # Non-blocking per specification

    results, _ = scan_naming(target_dir, repo_root)

    # Extract all recensés for baseline storage
    raw_recenses = {rule: data["recenses"] for rule, data in results.items()}

    if args.update_baseline:
        save_baseline(baseline_path, raw_recenses)
        return 0

    baseline_recenses = load_baseline(baseline_path)

    # Filter recensés against baseline
    new_findings: dict[str, list[dict]] = {}
    baseline_count = 0
    new_count = 0

    for rule, items in raw_recenses.items():
        base_items = baseline_recenses.get(rule, [])
        # Set of (file, name) in baseline
        base_set = {(b["file"], b["name"]) for b in base_items}
        
        new_items = []
        for item in items:
            if (item["file"], item["name"]) in base_set:
                baseline_count += 1
            else:
                new_items.append(item)
                new_count += 1
        new_findings[rule] = new_items

    # Affichage du tableau récapitulatif
    print("=" * 100)
    print("AUDIT DE NOMMAGE IEC 61131-3 (G110_check_naming_style.py)")
    print("Référentiel : DOC/STDS/NAMING_CONVENTION.md (Règles NC-010 à NC-070)")
    print("=" * 100)
    print(f"{'Règle':<8} | {'Description':<52} | {'Conformes':<9} | {'Exemptés/Legacy':<15} | {'Baseline':<9} | {'Nouveaux':<8}")
    print("-" * 100)

    total_conf = 0
    total_ex_leg = 0
    total_base = 0
    total_new = 0

    for rule in ["NC-010", "NC-020", "NC-030", "NC-050", "NC-060", "NC-070", "NC-080"]:
        data = results[rule]
        conf = data["conf"]
        ex_leg = data.get("legacy", 0) + data.get("exemptes", 0)
        
        base_items = baseline_recenses.get(rule, [])
        base_set = {(b["file"], b["name"]) for b in base_items}
        
        rule_base = sum(1 for item in data["recenses"] if (item["file"], item["name"]) in base_set)
        rule_new = sum(1 for item in data["recenses"] if (item["file"], item["name"]) not in base_set)

        total_conf += conf
        total_ex_leg += ex_leg
        total_base += rule_base
        total_new += rule_new

        desc_map = {
            "NC-010": "FB inst préfixée 'inst'",
            "NC-020": "Pas de notation hongroise (b/i/r/w/dw)",
            "NC-030": "Suffixe d'unité avec '_'",
            "NC-050": "Cmd/Req toujours en préfixe (hors legacy)",
            "NC-060": "Champs ST_*HMI préfixés (hors exemptés)",
            "NC-070": "GVL_PERSISTENT préfixé '_'",
            "NC-080": "Zéro 'Ref' pour consigne (SpeedTgt/Cmd/SP)",
        }
        print(f"{rule:<8} | {desc_map[rule]:<52} | {conf:<9} | {ex_leg:<15} | {rule_base:<9} | {rule_new:<8}")

    print("-" * 100)
    print(f"{'TOTAL':<8} | {'Ensemble des 7 règles analysées':<52} | {total_conf:<9} | {total_ex_leg:<15} | {total_base:<9} | {total_new:<8}")
    print("=" * 100)

    if new_count > 0:
        print(f"\n[WARNING] {new_count} NOUVEAU(X) SIGNALEMENT(S) DE NOMMAGE (hors baseline) :")
        for rule, items in new_findings.items():
            for item in items:
                print(f"  [{rule}] {item['file']}:L{item['line']} -> {item['snippet']}")
    else:
        print(f"\n[OK] AUCUN NOUVEAU SIGNALEMENT DE NOMMAGE ({baseline_count} occurrences connues masquées par la baseline).")

    if args.report:
        print("\n--- DÉTAIL DES OCCURRENCES DÉTECTÉES ---")
        for rule, data in results.items():
            if data["recenses"]:
                print(f"\n[{rule}] {len(data['recenses'])} occurrence(s) :")
                for item in data["recenses"]:
                    in_b = " (Baseline)" if (item["file"], item["name"]) in {(b["file"], b["name"]) for b in baseline_recenses.get(rule, [])} else " [NEW]"
                    print(f"  {item['file']}:L{item['line']} -> {item['snippet']}{in_b}")

    # NON-BLOCKING: Always exit 0 per AC2 requirement
    return 0

if __name__ == "__main__":
    sys.exit(main())
