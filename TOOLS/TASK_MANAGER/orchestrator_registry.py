"""Ajout d'une entree au registre d'orchestration DOC/WFLOW/TASKS_ORCHESTRATOR.yaml.

Choix de conception : ajout en FIN de fichier, sans reecrire le contenu existant.
Une reecriture complete (yaml.safe_dump) perd les commentaires et reformate tout le fichier.
Le fichier est relu et valide AVANT ecriture ; l'ecriture passe par un fichier temporaire.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import yaml

ID_PATTERN = re.compile(r"^[A-Z0-9][A-Z0-9_-]{2,80}$")
REQUIRED_FIELDS = ("id", "sujet", "statut")


def append_entry(registry_path: Path, entry: dict) -> str:
    """Ajoute une entree en fin de registre. Retourne l'id ajoute.

    Leve ValueError si la donnee est invalide, FileExistsError si l'id existe deja.
    """
    if not isinstance(entry, dict):
        raise ValueError("entree attendue : objet JSON")
    for field in REQUIRED_FIELDS:
        if not str(entry.get(field, "")).strip():
            raise ValueError(f"champ requis absent : {field}")
    entry_id = str(entry["id"]).strip()
    if not ID_PATTERN.match(entry_id):
        raise ValueError("id invalide : majuscules, chiffres, tirets ou underscores (3 a 81 caracteres)")

    text = registry_path.read_text(encoding="utf-8")
    current = yaml.safe_load(text) or []
    if not isinstance(current, list) or any(not isinstance(item, dict) for item in current):
        raise ValueError("registre existant invalide : liste d'entrees attendue")
    if any(str(item.get("id", "")) == entry_id for item in current):
        raise FileExistsError(f"id deja present dans le registre : {entry_id}")

    block = yaml.safe_dump([{**entry, "id": entry_id}], allow_unicode=True, sort_keys=False, width=200)
    separator = "" if (not text or text.endswith("\n")) else "\n"
    new_text = text + separator + block

    # Verification AVANT ecriture : le nouveau contenu doit se relire avec une entree de plus.
    check = yaml.safe_load(new_text)
    if not isinstance(check, list) or len(check) != len(current) + 1:
        raise ValueError("verification echouee : le registre resultant serait invalide")

    tmp_path = registry_path.with_name(registry_path.name + ".tmp")
    tmp_path.write_text(new_text, encoding="utf-8")
    os.replace(tmp_path, registry_path)
    return entry_id
