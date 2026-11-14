#!/usr/bin/env python3
"""Profil de vigilance : ce que le Superviseur exige, selon la CRITICITE de la tache.

La criticite est un attribut de la fiche structuree (rempli depuis le contrat). Elle
selectionne un profil deterministe :

  C0/C1 : observation seule, aucun blocage, socle minimal, pas de spécialiste impose
  C2     : contrat + criteres mesurables exiges, perimetre signale (pas refuse),
           socle exige, revue periodique, notification des constats
  C3     : perimetre REFUSE, gates materiaux bloquants, spécialiste safety obligatoire
           sur toute ecriture CODE/**, l agent ne clot rien, notification obligatoire
  C4     : aucune ecriture autonome par l agent, tout passe par l exploitant,
           socle complet (STDS), safety + standards en permanence, l agent ne clot rien

Aucun modele n intervient : le profil est une table, l effet est mecanique.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
CONTRAT_DIR = ROOT / "DOC" / "STDS"

PROFILES = {
    "C0": {"niveau": "C0", "socle_min": False, "perimetre_refuse": False, "gates_materiel": False,
           "specialistes": [], "revue_periodique": False, "notification_obligatoire": False,
           "cloture_par_agent": True, "lecture_seule": False},
    "C1": {"niveau": "C1", "socle_min": False, "perimetre_refuse": False, "gates_materiel": False,
           "specialistes": [], "revue_periodique": False, "notification_obligatoire": False,
           "cloture_par_agent": True, "lecture_seule": False},
    "C2": {"niveau": "C2", "socle_min": True, "perimetre_refuse": False, "gates_materiel": False,
           "specialistes": [], "revue_periodique": True, "notification_obligatoire": True,
           "cloture_par_agent": False, "lecture_seule": False},
    "C3": {"niveau": "C3", "socle_min": True, "perimetre_refuse": True, "gates_materiel": True,
           "specialistes": ["safety"], "revue_periodique": True, "notification_obligatoire": True,
           "cloture_par_agent": False, "lecture_seule": False},
    "C4": {"niveau": "C4", "socle_min": True, "perimetre_refuse": True, "gates_materiel": True,
           "specialistes": ["safety", "standards"], "revue_periodique": True, "notification_obligatoire": True,
           "cloture_par_agent": False, "lecture_seule": True},
}

STDS_SOCLE = ("DOC/STDS/CODE_QUALITY_STANDARDS.md", "DOC/STDS/NAMING_CONVENTION.md")


def task_id_from_alias(alias: str) -> str:
    """TXXX tire de l alias de session (T429-MMX01 -> T429)."""
    match = re.match(r"^(T\d{3})", str(alias or "").strip(), re.IGNORECASE)
    return match.group(1).upper() if match else ""


def normalize(value) -> str:
    text = str(value or "").strip().upper()
    match = re.fullmatch(r"C([0-4])", text)
    return f"C{match.group(1)}" if match else "C2"


def contract_for(task_id: str) -> Path | None:
    if not task_id:
        return None
    for folder in sorted(TASKS_DIR.glob(f"{task_id}*")):
        if not folder.is_dir():
            continue
        for candidate in sorted(folder.glob("*CONTRAT*.yaml")):
            return candidate
    return None


def criticality_for_task(task_id: str) -> str:
    """Criticalite declaree dans le contrat de la tache (C2 par defaut)."""
    path = contract_for(task_id)
    if path is None:
        return "C2"
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, ValueError, ImportError):
        return "C2"
    contract = data.get("contract") if isinstance(data, dict) else None
    value = (contract or {}).get("criticality") if isinstance(contract, dict) else None
    return normalize(value)


def profile_for(criticality) -> dict:
    """Profil de vigilance associe a une criticalite."""
    base = dict(PROFILES[normalize(criticality)])
    if base["socle_min"]:
        base["socle_ajoute"] = [path for path in STDS_SOCLE if (ROOT / path).is_file()]
    else:
        base["socle_ajoute"] = []
    return base


def profile_for_task(task_id: str) -> dict:
    return profile_for(criticality_for_task(task_id))
