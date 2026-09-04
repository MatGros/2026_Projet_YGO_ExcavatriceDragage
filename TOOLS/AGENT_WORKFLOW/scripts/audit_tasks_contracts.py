#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit de coherence taches <-> contrats (rapport de synthese, aucune ecriture).

Croise DOC/WFLOW/TASKS.yaml (champ `contrat:`) avec les fichiers de
DOC/WFLOW/CONTRACTS/ et ARCHIVES/Doc/WFLOW/CONTRACTS/.

Produit un rapport textuel des ecarts :
  - taches sans contrat (champ vide) et leur criticite
  - taches dont le champ `contrat:` pointe vers un fichier inexistant
  - contrats orphelins (fichier present mais aucune tache ne le reference)
  - contrats dont le task_id interne ne correspond a aucune tache
  - doublons de contrats (plusieurs fichiers pour une meme tache)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]
TASKS = REPO / "DOC" / "WFLOW" / "TASKS.yaml"
CONTRACTS_DIRS = (
    REPO / "DOC" / "WFLOW" / "CONTRACTS",
    REPO / "ARCHIVES" / "Doc" / "WFLOW" / "CONTRACTS",
)

# Criticites qui exigent un contrat (cf. check_task_contract.py)
CRIT_REQUIRING = {"C2", "C3", "C4"}


def parse_tasks(text: str) -> list[dict]:
    """Parse les blocs de taches de TASKS.yaml (mini-parseur, sans PyYAML)."""
    tasks = []
    # Decoupe sur chaque ligne "- id:"
    blocks = re.split(r"(?m)^- id:\s*", text)
    for block in blocks[1:]:
        lines = block.splitlines()
        tid = lines[0].strip()
        task = {"id": tid, "contrat": "", "criticite": "", "statut": ""}
        for line in lines[1:]:
            m = re.match(r"^\s+(statut|criticite|contrat):\s*(.*)$", line)
            if m:
                key, val = m.group(1), m.group(2).strip().strip("'\"")
                task[key] = val
        tasks.append(task)
    return tasks


def main() -> int:
    text = TASKS.read_text(encoding="utf-8", errors="replace")
    tasks = parse_tasks(text)

    # Index des fichiers contrats par basename
    contract_files: dict[str, Path] = {}
    for d in CONTRACTS_DIRS:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("TASK_CONTRACT_*.yaml")):
            contract_files[f.name] = f

    # 1. Taches sans contrat
    no_contract = [t for t in tasks if not t["contrat"]]
    no_contract_crit = [t for t in no_contract if t["criticite"] in CRIT_REQUIRING]

    # 2. Taches dont le champ contrat pointe vers un fichier inexistant
    broken = []
    for t in tasks:
        if not t["contrat"]:
            continue
        p = REPO / t["contrat"]
        if not p.is_file():
            broken.append((t["id"], t["contrat"]))

    # 3. Contrats orphelins : fichier present mais aucune tache ne le reference
    referenced = set()
    for t in tasks:
        if t["contrat"]:
            referenced.add(Path(t["contrat"]).name)
    orphans = [name for name in contract_files if name not in referenced]
    # Distinguer DOC (actif, ecart reel) vs ARCHIVES (archive, normal)
    orphans_doc = [n for n in orphans if (CONTRACTS_DIRS[0] / n).is_file()]
    orphans_arch = [n for n in orphans if (CONTRACTS_DIRS[1] / n).is_file()]

    # 4. Contrats dont le task_id interne ne correspond a aucune tache
    task_ids = {t["id"] for t in tasks}
    mismatched_taskid = []
    for name, path in contract_files.items():
        content = path.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"task_id\s*:\s*([^\s]+)", content)
        if m:
            internal = m.group(1).strip()
            # Le task_id interne peut etre T084_RETRO alors que la tache est T084
            base = re.split(r"[_-]", internal)[0]
            if internal not in task_ids and base not in task_ids:
                mismatched_taskid.append((name, internal))

    # 5. Doublons : plusieurs contrats pour une meme tache (par prefixe Txxx)
    prefix_map: dict[str, list[str]] = {}
    for name in contract_files:
        m = re.match(r"TASK_CONTRACT_(T\d+(?:-\d+)?)", name)
        if m:
            prefix_map.setdefault(m.group(1), []).append(name)
    duplicates = {k: v for k, v in prefix_map.items() if len(v) > 1}

    # ---- Rapport ----
    print("=" * 70)
    print("AUDIT COHERENCE TACHES <-> CONTRATS")
    print("=" * 70)
    print(f"Taches dans TASKS.yaml        : {len(tasks)}")
    print(f"Fichiers contrat (DOC+ARCH)   : {len(contract_files)}")
    print()

    print(f"[1] Taches SANS contrat (champ vide) : {len(no_contract)}")
    print(f"    dont criticite C2-C4 (obligatoire) : {len(no_contract_crit)}")
    for t in no_contract_crit:
        print(f"      - {t['id']}  (criticite={t['criticite']}, statut={t['statut']})")
    print()

    print(f"[2] Champ contrat -> fichier INEXISTANT : {len(broken)}")
    for tid, val in broken:
        print(f"      - {tid} -> {val}")
    print()

    print(f"[3] Contrats ORPHELINS (aucune tache ne les reference) : {len(orphans)}")
    print(f"    dont DOC/ (actif, ecart reel) : {len(orphans_doc)}")
    for name in orphans_doc:
        print(f"      [DOC] {name}")
    print(f"    dont ARCHIVES/ (archive, normal) : {len(orphans_arch)}")
    for name in orphans_arch:
        print(f"      [ARCH] {name}")
    print()

    print(f"[4] Contrats dont task_id interne ne matche aucune tache : {len(mismatched_taskid)}")
    for name, internal in mismatched_taskid:
        print(f"      - {name}  (task_id={internal})")
    print()

    print(f"[5] Doublons de contrats (meme prefixe Txxx) : {len(duplicates)}")
    for prefix, names in sorted(duplicates.items()):
        print(f"      - {prefix}: {', '.join(names)}")
    print()

    # Synthese
    total_issues = len(no_contract_crit) + len(broken) + len(orphans_doc) + len(mismatched_taskid) + len(duplicates)
    print("=" * 70)
    print(f"SYNTHESE : {total_issues} ecart(s) detecte(s)")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
