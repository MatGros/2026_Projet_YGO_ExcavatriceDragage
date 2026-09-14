"""
===============================================================================
🛠️ OMNIDIAG — Parser Automatique des Diagnostics, Alarmes et Messages
===============================================================================
🎯 Rôle : Parse de manière reproductible et déterministe les fichiers sources
   CODESYS (.st) du projet pour en extraire l'intégralité des :
   - Alarmes bloquantes et historisées du carrousel IHM (FB_Hmi_BannerFormatter)
   - Messages d'action opérateur et interlocks directionnels
   - Messages d'abandon de séquence de réarmement AU
   - Conditions spéciales, bypass et bridages
   - Progression du cycle semi-automatique et homing machine
   - Messages de gestion d'urgence (FB_Safety_EmergencyManagement)
   - Bits de qualification machine arrêtée (FB_Acquisition_Preflight)
   - Causes de blocage terrain horodatées (Trace Treuils et Translation)
   - Causes des socles de défauts transverses (FB_FaultCore)
===============================================================================
"""

import os
import re
from pathlib import Path
from typing import List, Dict, Any


def extract_alarms_from_banner(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait les alarmes publiées dans AlarmArray[...] dans FB_Hmi_BannerFormatter.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_condition = ""
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Détection des blocs IF conditionnels
        if stripped.startswith("IF ") and "THEN" in stripped:
            cond_match = re.search(r"IF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("ELSIF ") and "THEN" in stripped:
            cond_match = re.search(r"ELSIF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()

        # Recherche de l'affectation à AlarmArray
        match = re.search(r"AlarmArray\[(?:AlarmCount|\w+)\]\s*:=\s*(?:CONCAT\([^,]+,\s*)?'([^']+)'", line)
        if match:
            raw_text = match.group(1)
            
            # Détection de l'organe entre crochets
            organ_match = re.search(r"\[([A-Za-z0-9_+\- ]+)\]", raw_text)
            organ = organ_match.group(1) if organ_match else "GÉNÉRAL"
            
            # Détection du code ErrorID
            code_match = re.search(r"ErrorID:?(\d+)", raw_text, re.IGNORECASE)
            err_code = f"ErrorID:{code_match.group(1)}" if code_match else "-"
            
            is_histo = "[HISTO]" in raw_text or "Histo" in current_condition
            
            items.append({
                "id": f"ALM_{len(items)+1:03d}",
                "category": "HISTO_ALARM" if is_histo else "ACTIVE_ALARM",
                "organ": organ,
                "code": err_code,
                "text": raw_text,
                "condition": current_condition,
                "source_file": filepath.name,
                "line": idx,
                "blocking": not is_histo,
                "level": "HISTORISÉ (Reset requis)" if is_histo else "BLOQUANT (SafeStop/Coupure)"
            })
            
    return items


def extract_operator_actions_from_banner(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait les OperatorActionCandidate dans FB_Hmi_BannerFormatter.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_condition = ""
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        
        if stripped.startswith("IF ") and "THEN" in stripped:
            cond_match = re.search(r"IF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("ELSIF ") and "THEN" in stripped:
            cond_match = re.search(r"ELSIF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("CASE ") or stripped.endswith(":"):
            case_match = re.search(r"(E_AutoCycleStep\.\w+|\w+):", stripped)
            if case_match:
                current_condition = f"Étape {case_match.group(1)}"

        # OperatorActionCandidate := '...'
        match = re.search(r"OperatorActionCandidate\s*:=\s*(?:CONCAT\([^,]+,\s*)?'([^']+)'", line)
        if match:
            raw_text = match.group(1)
            organ_match = re.search(r"\[([A-Za-z0-9_+\- ]+)\]", raw_text)
            organ = organ_match.group(1) if organ_match else "OPÉRATEUR"
            
            # Détection de priorité
            if "Boucle urgence" in raw_text or "Coupure" in raw_text or "AU" in raw_text:
                prio = "CRITIQUE (Sécurité / AU)"
            elif "interdite" in raw_text or "bloqu" in raw_text or "DirectionBlocked" in current_condition:
                prio = "INTERLOCK (Mouvement refusé)"
            elif "Cycle" in current_condition or "AX" in current_condition:
                prio = "GUIDAGE_CYCLE (Semi-Auto)"
            else:
                prio = "CONDUITE (Manuel / Standard)"

            items.append({
                "id": f"ACT_{len(items)+1:03d}",
                "category": "OPERATOR_ACTION",
                "organ": organ,
                "code": "-",
                "text": raw_text,
                "condition": current_condition,
                "source_file": filepath.name,
                "line": idx,
                "blocking": "interdite" in raw_text or "CRITIQUE" in prio,
                "level": prio
            })
            
        # AbortMsgText := '...' (causes d'abandon AU)
        abort_match = re.search(r"AbortMsgText\s*:=\s*'([^']+)'", line)
        if abort_match:
            raw_text = abort_match.group(1)
            organ_match = re.search(r"\[([A-Za-z0-9_+\- ]+)\]", raw_text)
            organ = organ_match.group(1) if organ_match else "AU"
            items.append({
                "id": f"ABORT_{len(items)+1:03d}",
                "category": "ABORT_REARMEMENT_AU",
                "organ": organ,
                "code": "ABORT_AU",
                "text": raw_text,
                "condition": current_condition,
                "source_file": filepath.name,
                "line": idx,
                "blocking": True,
                "level": "ÉCHEC RÉARMEMENT AU"
            })
            
    return items


def extract_special_conditions(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait les SpecialConditionCandidate dans FB_Hmi_BannerFormatter.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_condition = ""
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("IF ") and "THEN" in stripped:
            cond_match = re.search(r"IF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("ELSIF ") and "THEN" in stripped:
            cond_match = re.search(r"ELSIF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()

        match = re.search(r"SpecialConditionCandidate\s*:=\s*'([^']+)'", line)
        if match:
            raw_text = match.group(1)
            if raw_text:
                items.append({
                    "id": f"SPEC_{len(items)+1:03d}",
                    "category": "SPECIAL_CONDITION",
                    "organ": "MACHINE / POSITION",
                    "code": "-",
                    "text": raw_text,
                    "condition": current_condition,
                    "source_file": filepath.name,
                    "line": idx,
                    "blocking": "verrouillee" in raw_text or "refuse" in raw_text,
                    "level": "DÉROGATION / VERROU"
                })
    return items


def extract_homing_instructions(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait les MachineHomingInstruction dans FB_CycleMachineHoming.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_condition = ""
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("IF ") and "THEN" in stripped:
            cond_match = re.search(r"IF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("ELSIF ") and "THEN" in stripped:
            cond_match = re.search(r"ELSIF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()

        match = re.search(r"MachineHomingInstruction\s*:=\s*'([^']*)'", line)
        if match:
            raw_text = match.group(1)
            if raw_text:
                items.append({
                    "id": f"HOM_{len(items)+1:03d}",
                    "category": "GUIDAGE_HOMING",
                    "organ": "HOMING / CODEURS",
                    "code": "HOMING",
                    "text": raw_text,
                    "condition": current_condition,
                    "source_file": filepath.name,
                    "line": idx,
                    "blocking": "Erreur" in raw_text or "Echec" in raw_text or "Arret" in raw_text,
                    "level": "GUIDAGE RÉFÉRENCEMENT"
                })
    return items


def extract_emergency_messages(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait Status.OperatorMessage dans FB_Safety_EmergencyManagement.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_condition = ""
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("IF ") and "THEN" in stripped:
            cond_match = re.search(r"IF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()
        elif stripped.startswith("ELSIF ") and "THEN" in stripped:
            cond_match = re.search(r"ELSIF\s+(.*?)\s+THEN", stripped)
            if cond_match:
                current_condition = cond_match.group(1).strip()

        match = re.search(r"Status\.OperatorMessage\s*:=\s*'([^']+)'", line)
        if match:
            raw_text = match.group(1)
            items.append({
                "id": f"EMG_{len(items)+1:03d}",
                "category": "SECURITE_AU",
                "organ": "ARRÊT D'URGENCE",
                "code": "AU_STATUS",
                "text": raw_text,
                "condition": current_condition,
                "source_file": filepath.name,
                "line": idx,
                "blocking": "echec" in raw_text or "ouverte" in raw_text or "coupure" in raw_text,
                "level": "ÉTAT SÉCURITÉ AU"
            })
    return items


def extract_preflight_checks(filepath: Path) -> List[Dict[str, Any]]:
    """Extrait les 16 vérifications de FB_Acquisition_Preflight.st."""
    items = []
    if not filepath.exists():
        return items

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    preflight_meta = {
        "16#0001": ("TREUIL M1", "Frein treuil M1 non serré machine à l'arrêt"),
        "16#0002": ("TREUIL M2", "Frein treuil M2 non serré machine à l'arrêt"),
        "16#0004": ("TRANSLATION M3", "Frein translation M3 non serré machine à l'arrêt"),
        "16#0008": ("TREUIL M1", "Contacteurs M1 non retombés (détection collage contacteur)"),
        "16#0010": ("TREUIL M2", "Contacteurs M2 non retombés (détection collage contacteur)"),
        "16#0020": ("TREUIL M1", "Protection thermique moteur treuil M1 déclenchée"),
        "16#0040": ("TREUIL M2", "Protection thermique moteur treuil M2 déclenchée"),
        "16#0080": ("FREINS", "Protection thermique freins déclenchée"),
        "16#0100": ("ALIMENTATION", "Relais ordre des phases réseau KO (inversion ou manque phase)"),
        "16#0200": ("TREUIL M2", "Câble treuil M2 détendu (détecteur anti-mou câble actif)"),
        "16#0400": ("TRANSLATION M3", "Incohérence capteurs fin de course translation M3"),
        "16#0800": ("SÉCURITÉ AU", "Contacteur puissance enclenché alors que chaîne AU ouverte"),
        "16#1000": ("TREUIL M1", "Codeur treuil M1 non opérationnel"),
        "16#2000": ("TREUIL M2", "Codeur treuil M2 non opérationnel"),
        "16#4000": ("TREUIL M1", "Treuil M1 non référencé (homing requis) ou position hors bornes"),
        "16#8000": ("TREUIL M2", "Treuil M2 non référencé (homing requis) ou position hors bornes"),
    }

    for idx, line in enumerate(lines, 1):
        match = re.search(r"IF\s+(.*?)\s+THEN\s+PreflightErrorId\s*:=\s*PreflightErrorId\s+OR\s+(16#[0-9A-Fa-f]+);", line)
        if match:
            condition = match.group(1).strip()
            mask_hex = match.group(2).strip()
            organ, desc = preflight_meta.get(mask_hex, ("PREFLIGHT", f"Contrôle E/S : {condition}"))
            
            items.append({
                "id": f"PRE_{len(items)+1:02d}",
                "category": "CHECKLIST_PREFLIGHT",
                "organ": organ,
                "code": mask_hex,
                "text": desc,
                "condition": f"Défaut si {condition}",
                "source_file": filepath.name,
                "line": idx,
                "blocking": True,
                "level": "CONTRÔLE MACHINE ARRÊTÉE"
            })
    return items


def extract_trace_reasons(base_dir: Path) -> List[Dict[str, Any]]:
    """Extrait les raisons de blocage terrain (Winch et Translation)."""
    items = []
    
    # Treuils
    winch_trace_file = base_dir / "CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/E_WinchTraceBlockReason.st"
    if winch_trace_file.exists():
        with open(winch_trace_file, "r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                match = re.search(r"(\w+)\s*:=\s*(\d+),\s*//\s*(.*)", line)
                if match:
                    name = match.group(1)
                    val = match.group(2)
                    comment = match.group(3).strip()
                    items.append({
                        "id": f"TRC_W_{val}",
                        "category": "TRACE_BLOCAGE_TERRAIN",
                        "organ": "TREUILS M1/M2",
                        "code": f"Prio {val}",
                        "text": f"Blocage treuil : {name} ({comment})",
                        "condition": f"E_WinchTraceBlockReason.{name}",
                        "source_file": winch_trace_file.name,
                        "line": idx,
                        "blocking": val != "0",
                        "level": f"PRIORITÉ {val}"
                    })

    # Translation
    trans_trace_file = base_dir / "CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/E_TranslationTraceBlockReason.st"
    if trans_trace_file.exists():
        with open(trans_trace_file, "r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                match = re.search(r"(\w+)\s*:=\s*(\d+),\s*//\s*(.*)", line)
                if match:
                    name = match.group(1)
                    val = match.group(2)
                    comment = match.group(3).strip()
                    items.append({
                        "id": f"TRC_T_{val}",
                        "category": "TRACE_BLOCAGE_TERRAIN",
                        "organ": "TRANSLATION M3",
                        "code": f"Prio {val}",
                        "text": f"Blocage translation : {name} ({comment})",
                        "condition": f"E_TranslationTraceBlockReason.{name}",
                        "source_file": trans_trace_file.name,
                        "line": idx,
                        "blocking": val != "0",
                        "level": f"PRIORITÉ {val}"
                    })

    return items


def extract_fault_core_causes(base_dir: Path) -> List[Dict[str, Any]]:
    """Extrait les instCauses[i].Texte des FB métier (FB_Bucket, FB_WinchSync, FB_Translation, FB_CycleSemiAuto)."""
    items = []
    targets = [
        ("CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st", "BENNE"),
        ("CODE/H_TREUILS_BENNE/FB_WinchSync.st", "SYNCHRO M1/M2"),
        ("CODE/I_TRANSLATION/FB_Translation.st", "TRANSLATION M3"),
        ("CODE/G_CYCLE/FB_CycleSemiAuto.st", "CYCLE SEMI-AUTO"),
    ]

    for rel_path, organ in targets:
        filepath = base_dir / rel_path
        if not filepath.exists():
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()

        current_cause_idx = ""
        current_latching = ""
        for idx, line in enumerate(lines, 1):
            m_idx = re.search(r"instCauses\[(\d+)\]\.Active", line)
            if m_idx:
                current_cause_idx = m_idx.group(1)
            
            m_latch = re.search(r"instCauses\[\d+\]\.Latching\s*:=\s*(TRUE|FALSE);", line)
            if m_latch:
                current_latching = m_latch.group(1)

            m_txt = re.search(r"instCauses\[(\d+)\]\.Texte\s*:=\s*'([^']+)';", line)
            if m_txt:
                c_idx = m_txt.group(1)
                text = m_txt.group(2)
                bit_val = 1 << int(c_idx)
                items.append({
                    "id": f"FC_{organ[:3]}_{c_idx}",
                    "category": "SOCLE_DEFAUTS_FB",
                    "organ": organ,
                    "code": f"Bit {c_idx} (16#{bit_val:04X})",
                    "text": text,
                    "condition": f"instCauses[{c_idx}].Active",
                    "source_file": filepath.name,
                    "line": idx,
                    "blocking": True,
                    "level": "DÉFAUT LATCHÉ (Reset)" if current_latching == "TRUE" else "AVERTISSEMENT LIVE"
                })

    return items


def run_full_extraction(repo_root: Path) -> List[Dict[str, Any]]:
    """Exécute l'extraction complète sur tous les fichiers sources du dépôt."""
    all_data = []

    banner_st = repo_root / "CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st"
    homing_st = repo_root / "CODE/G_CYCLE/FB_CycleMachineHoming.st"
    emergency_st = repo_root / "CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st"
    preflight_st = repo_root / "CODE/A_COMMUN/FB_Acquisition_Preflight.st"

    all_data.extend(extract_alarms_from_banner(banner_st))
    all_data.extend(extract_operator_actions_from_banner(banner_st))
    all_data.extend(extract_special_conditions(banner_st))
    all_data.extend(extract_homing_instructions(homing_st))
    all_data.extend(extract_emergency_messages(emergency_st))
    all_data.extend(extract_preflight_checks(preflight_st))
    all_data.extend(extract_trace_reasons(repo_root))
    all_data.extend(extract_fault_core_causes(repo_root))

    return all_data
