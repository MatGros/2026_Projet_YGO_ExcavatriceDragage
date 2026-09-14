"""
===============================================================================
🧠 OMNIDIAG — Moteur de Données Fiables (Code ST Strict & Validations)
===============================================================================
🎯 Rôle : AUCUNE invention d'action ou de cause non vérifiée.
   - Restitue strictement les données fiables extraites du code source CODESYS
   - Permet d'intégrer uniquement les causes/actions explicitement renseignées
     et validées ensemble dans knowledge_base.json
===============================================================================
"""

import json
from pathlib import Path
from typing import Dict, Any, List


def enrich_item(item: Dict[str, Any], custom_kb: Dict[str, Any]) -> Dict[str, Any]:
    """Enrichit uniquement avec ce qui a été validé ou extrait du code."""
    item_id = item.get("id", "")
    item_text = item.get("text", "")

    # 1. Si une entrée a été validée dans la base de connaissances
    override = custom_kb.get(item_id) or custom_kb.get(item_text)
    if override:
        item["cause_racine"] = override.get("cause_racine", "")
        item["action_conducteur"] = override.get("action_conducteur", "")
        item["action_maintenance"] = override.get("action_maintenance", "")
        item["points_test"] = override.get("points_test", "")
        item["statut_validation"] = "VALIDÉ"
        return item

    # 2. Données brutes fiables issues du code ST (zéro invention)
    item["cause_racine"] = item.get("condition", "-")
    item["action_conducteur"] = ""  # Laissé vide tant que pas défini ensemble
    item["action_maintenance"] = "" # Laissé vide tant que pas défini ensemble
    item["points_test"] = ""
    item["statut_validation"] = "À DÉFINIR"
    item["keywords"] = [
        item.get("organ", "").lower(),
        item.get("code", "").lower(),
        item.get("category", "").lower()
    ]

    return item


def enrich_all(items: List[Dict[str, Any]], kb_path: Path) -> List[Dict[str, Any]]:
    """Charge la base validée si existante et associe les données."""
    custom_kb = {}
    if kb_path.exists():
        try:
            with open(kb_path, "r", encoding="utf-8") as f:
                custom_kb = json.load(f)
        except Exception:
            pass

    enriched = []
    for it in items:
        enriched.append(enrich_item(it, custom_kb))

    return enriched
