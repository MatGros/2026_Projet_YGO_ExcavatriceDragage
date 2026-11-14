#!/usr/bin/env python3
"""Create or report a task plan without inferring execution or validation (T000)."""
from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - the project Python environment provides PyYAML
    yaml = None

ROOT = Path(__file__).resolve().parents[3]
TASKS_FILE = ROOT / "DOC" / "WFLOW" / "TASKS.yaml"
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
EXECUTION = {"NOT_STARTED", "IN_PROGRESS", "DONE", "BLOCKED", "CANCELED"}
VALIDATION = {"NOT_REVIEWED", "ACCEPTED", "REJECTED", "WAIVED"}


def load_task(task_id: str) -> dict:
    if yaml is None:
        raise RuntimeError("PyYAML requis pour lire DOC/WFLOW/TASKS.yaml")
    data = yaml.safe_load(TASKS_FILE.read_text(encoding="utf-8")) or {}
    found = [t for t in data.get("tasks", []) if isinstance(t, dict)
             and str(t.get("id", "")).upper() == task_id.upper()]
    if len(found) != 1:
        raise ValueError(f"Tâche {task_id} absente ou ambiguë dans TASKS.yaml")
    return found[0]


def task_folder(task: dict) -> Path:
    contract_ref = str(task.get("contrat", "")).split(" (", 1)[0].strip()
    contract = ROOT / contract_ref if contract_ref else None
    if contract and contract.is_file():
        return contract.parent
    candidates = sorted(p for p in TASKS_DIR.glob(f"{task['id']}*") if p.is_dir())
    if len(candidates) != 1:
        raise ValueError(f"Dossier de tâche absent ou ambigu pour {task['id']}")
    return candidates[0]


def plan_files(folder: Path) -> list[Path]:
    return sorted(p for p in folder.glob("*.md")
                  if "PLAN" in p.name.upper() and not p.name.upper().startswith("README"))


def new_plan(task: dict, folder: Path) -> Path:
    task_id = str(task["id"]).upper()
    title = str(task.get("titre") or task_id).strip()
    safe_title = re.sub(r"[^A-Za-z0-9_-]+", "_", title).strip("_")[:70] or "PLAN"
    plan = folder / f"{task_id}_{safe_title}_PLAN_{date.today():%Y%m%d}_v1.0.md"
    if plan.exists():
        raise FileExistsError(f"Le fichier cible existe déjà : {plan.relative_to(ROOT)}")
    plan.write_text(f'''---
plan_project:
  schema: 1
  task_id: {task_id}
  updated_at: {date.today().isoformat()}
  milestones:
    - id: M0
      title: "Cadrage du plan"
      done_when: "Périmètre, étapes et critères de réussite consignés"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: ""
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
---

# {task_id} — {title}

> Plan de travail unique. `DONE` décrit l'exécution ; seule une validation explicite avec auteur et date compte comme validée.

## 1. Besoin et résultat attendu

À compléter après lecture de la fiche, du contrat et des références de la tâche.

## 2. Périmètre et dépendances

- Inclus : à préciser.
- Exclus : à préciser.
- Dépendances / décisions attendues : à préciser.

## 3. Jalons

Compléter les jalons dans `plan_project.milestones` ci-dessus. Chaque jalon porte séparément son état d'exécution, sa preuve, et son état de validation.

## 4. Journal des décisions et commentaires

Ajouter les commentaires datés et attribués dans le champ `comments` du jalon concerné.
''', encoding="utf-8")
    return plan


def frontmatter(text: str) -> dict | None:
    match = re.match(r"\A---\s*\n(.*?)\n---\s*(?:\n|$)", text, re.S)
    if not match or yaml is None:
        return None
    try:
        data = yaml.safe_load(match.group(1)) or {}
        value = data.get("plan_project")
        return value if isinstance(value, dict) else None
    except (yaml.YAMLError, AttributeError):
        return None


def legacy_rows(text: str) -> list[dict]:
    rows = []
    in_table = False
    in_milestones = False
    in_mermaid = False
    for line in text.splitlines():
        if line.strip().startswith("## "):
            in_milestones = bool(re.match(r"##\s+4\.\s+.*(?:[ÉE]tapes|jalons)", line, re.I))
            in_table = in_milestones
            in_mermaid = False
            continue
        if in_milestones and line.strip().startswith("```"):
            in_mermaid = not in_mermaid
            continue
        if in_milestones and in_mermaid:
            # Older plans may express the milestone list as a Mermaid graph.
            for match in re.finditer(r'\b(M\d+)\["([^"]+)"\]', line):
                title = re.sub(r"<br\s*/?>", " — ", match.group(2), flags=re.I)
                rows.append({"id": match.group(1), "title": title,
                             "execution": "NOT_RECORDED", "validation": "NOT_RECORDED",
                             "evidence": "", "validated_by": "", "validated_at": "", "legacy": True})
            continue
        if not in_table or not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4 or set("-: ") >= set("".join(cells)):
            continue
        if cells[0] in {"#", "#️⃣"} or cells[0].lower() in {"#", "id"}:
            continue
        rows.append({"id": cells[0], "title": cells[1], "done_when": cells[2],
                     "execution": "NOT_RECORDED" if not cells[3] else cells[3],
                     "validation": "NOT_RECORDED", "evidence": "",
                     "validated_by": "", "validated_at": "", "legacy": True})
    return rows


def render(task: dict, plan: Path) -> str:
    text = plan.read_text(encoding="utf-8")
    meta = frontmatter(text)
    milestones = meta.get("milestones", []) if meta else legacy_rows(text)
    normalized = []
    for item in milestones if isinstance(milestones, list) else []:
        if not isinstance(item, dict):
            continue
        ex = str(item.get("execution", "NOT_RECORDED")).upper()
        val = str(item.get("validation", "NOT_RECORDED")).upper()
        # A validation is counted only when it has an explicit disposition, reviewer and date.
        complete_validation = val in VALIDATION and bool(str(item.get("validated_by", "")).strip()) \
            and bool(str(item.get("validated_at", "")).strip())
        normalized.append((item, ex, val if complete_validation else
                           (val if val != "ACCEPTED" else "ACCEPTED_INCOMPLETE"), complete_validation))

    done = sum(ex == "DONE" for _, ex, _, _ in normalized)
    in_progress = sum(ex == "IN_PROGRESS" for _, ex, _, _ in normalized)
    blocked = sum(ex == "BLOCKED" for _, ex, _, _ in normalized)
    unrecorded = sum(ex not in EXECUTION for _, ex, _, _ in normalized)
    accepted = sum(val == "ACCEPTED" and complete for _, _, val, complete in normalized)
    pending = sum(not complete or val == "NOT_REVIEWED" for _, _, val, complete in normalized)
    try:
        plan_label = plan.relative_to(ROOT).as_posix()
    except ValueError:
        plan_label = str(plan)
    lines = [f"PLAN-PROJECT | {task['id']} — {task.get('titre', '(titre absent)')}",
             f"Task Manager : {task.get('statut', 'inconnu')} · agent {task.get('agent', '—')}",
             f"Plan : {plan_label}",
             f"Avancement : {done}/{len(normalized)} DONE · {in_progress} en cours · {blocked} bloqué(s) · {unrecorded} sans état explicite",
             f"Validation : {accepted}/{len(normalized)} acceptée(s) avec auteur+date · {pending} à examiner / données manquantes",
             "Jalons :"]
    if not normalized:
        lines.append("- Aucun jalon structuré détecté ; le contenu du plan doit être détaillé.")
    for item, ex, val, complete in normalized:
        lines.append(f"- {item.get('id', '?')} — {item.get('title', '(sans titre)')} | exécution={ex} | validation={val}")
        for label, key in (("Preuve", "evidence"), ("Exécuté par", "execution_by"),
                           ("Validé par", "validated_by"), ("Validé le", "validated_at"),
                           ("Commentaire", "validation_comment"), ("Commentaire exécution", "execution_comment")):
            value = str(item.get(key, "")).strip()
            if value:
                lines.append(f"  {label} : {value}")
        comments = item.get("comments", [])
        if isinstance(comments, list):
            for comment in comments:
                if isinstance(comment, dict):
                    who = comment.get("by", "?")
                    when = comment.get("at", "date absente")
                    body = comment.get("text", "")
                    lines.append(f"  Commentaire ({who}, {when}) : {body}")
    lines.append("Validation non renseignée ou incomplète = non comptée comme validée.")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_id", nargs="?", help="ID exact, ex. T427; sinon PLAN_PROJECT_TASK_ID")
    parser.add_argument("--report-only", action="store_true", help="ne pas créer de plan manquant")
    args = parser.parse_args(argv)
    task_id = (args.task_id or os.environ.get("PLAN_PROJECT_TASK_ID", "")).strip().upper()
    if not re.fullmatch(r"T\d{3}", task_id):
        print("ERREUR : tâche courante indéterminée. Le skill doit résoudre la tâche formelle du chat et passer son ID exact (T###).", file=sys.stderr)
        return 2
    try:
        task = load_task(task_id)
        folder = task_folder(task)
        plans = plan_files(folder)
        if len(plans) > 1:
            raise ValueError("Plusieurs plans candidats : " + ", ".join(p.name for p in plans))
        if not plans:
            if args.report_only:
                raise FileNotFoundError(f"Aucun plan trouvé dans {folder.relative_to(ROOT)}")
            plan = new_plan(task, folder)
            print(f"PLAN CRÉÉ : {plan.relative_to(ROOT).as_posix()}")
            print("Compléter les jalons après lecture de la tâche et du contrat, puis relancer pour le rapport.")
            return 0
        print(render(task, plans[0]))
        return 0
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"ERREUR : {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
