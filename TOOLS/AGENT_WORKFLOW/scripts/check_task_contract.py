#!/usr/bin/env python3
"""Gate du contrat de tache : refuse les objectifs non testables.

Classe de bug couverte (REX 2026-07-29) : sur 53 taches deleguees a Pi, les
criteres d'acceptation etaient 3 phrases generiques reutilisees telles quelles
("implement the requested change without widening scope"). Un agent rendait donc
un rapport « conforme » a rien. On peut rendre une verification obligatoire :
si elle ne porte sur aucun objectif, elle reste creuse.

Ce script verifie qu'un contrat existe et qu'il est REELLEMENT specifique :

  T1  contrat present et exploitable a partir de C2
  T2  objectif metier renseigne (pas le gabarit)
  T3  au moins un critere d'acceptation, chacun avec un `verified_by` concret
  T4  aucun critere generique (liste noire issue des 53 taches observees)
  T5  perimetre declare (allowed / forbidden)
  T6  contrat de conservation present et rempli si strategy = rebuild
  T7  preuves attendues declarees

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <TASK_CONTEXT.yaml>
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier> --release
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Formulations observees dans .pi-subagents/artifacts/ : elles ne disent rien
# de ce que le code doit FAIRE. Un critere qui ressemble a ca est refuse.
GENERIC_PATTERNS = [
    r"without widening scope",
    r"implement the requested change",
    r"return evidence sufficient",
    r"return concrete findings",
    r"independent acceptance review",
    r"^\s*(le code|la fonction)?\s*(fonctionne|marche|est correct)\s*\.?\s*$",
    r"^\s*(ok|conforme|valide|termine)\s*\.?\s*$",
    r"respecte(r)? les (regles|standards|conventions)",
    r"sans regression",
]

# Restes de gabarit : si on les retrouve, le contrat n'a pas ete rempli.
PLACEHOLDERS = ["…", "...", "LOT_XX", "FB_Xxx", "Comportement observable attendu",
                "En une phrase :", "commande exacte, test PLC"]

CRITICALITY_REQUIRING_CONTRACT = {"C2", "C3", "C4"}


def load_yaml(path: Path) -> dict | None:
    """Charge le YAML. PyYAML si dispo, sinon repli sur un mini-parseur."""
    text = path.read_text(encoding="utf-8", errors="replace")
    try:
        import yaml  # type: ignore

        return yaml.safe_load(text) or {}
    except ImportError:
        return None


def scan_raw(text: str) -> dict:
    """Analyse textuelle de secours quand PyYAML est absent."""
    return {
        "has_contract": bool(re.search(r"^\s*contract\s*:", text, re.M)),
        "criticality": (m.group(1) if (m := re.search(r"criticality\s*:\s*(C[0-4])", text)) else ""),
        "strategy": (m.group(1) if (m := re.search(r"strategy\s*:\s*(patch|rebuild)", text)) else ""),
        "statements": re.findall(r"statement\s*:\s*[\"']?(.+?)[\"']?\s*$", text, re.M),
        "verified": re.findall(r"verified_by\s*:\s*[\"']?(.+?)[\"']?\s*$", text, re.M),
        "has_scope": bool(re.search(r"^\s*scope\s*:", text, re.M)),
        "has_conservation": bool(re.search(r"must_survive\s*:", text)),
        "has_evidence": bool(re.search(r"evidence_required\s*:", text)),
        "objective": (m.group(1).strip() if (m := re.search(r"objective\s*:\s*>?\s*\n?\s*(.+)", text)) else ""),
    }


def is_generic(statement: str) -> bool:
    low = statement.strip().lower()
    return any(re.search(p, low) for p in GENERIC_PATTERNS)


def has_placeholder(value: str) -> bool:
    return any(ph.lower() in value.lower() for ph in PLACEHOLDERS)


def check(path: Path, release: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")

    data = load_yaml(path)
    if data is None:
        warnings.append("PyYAML absent : analyse textuelle degradee (pip install pyyaml)")
        raw = scan_raw(text)
        contract_present = raw["has_contract"]
        criticality = raw["criticality"]
        strategy = raw["strategy"]
        statements = raw["statements"]
        verified = raw["verified"]
        objective = raw["objective"]
        has_scope = raw["has_scope"]
        has_conservation = raw["has_conservation"]
        has_evidence = raw["has_evidence"]
    else:
        contract = data.get("contract") or {}
        contract_present = bool(contract)
        criticality = str(contract.get("criticality") or "").strip()
        strategy = str(contract.get("strategy") or "").strip()
        objective = str(contract.get("objective") or "").strip()
        acceptance = contract.get("acceptance") or []
        statements = [str(a.get("statement", "")) for a in acceptance if isinstance(a, dict)]
        verified = [str(a.get("verified_by", "")) for a in acceptance if isinstance(a, dict)]
        scope = contract.get("scope") or {}
        has_scope = bool(scope.get("allowed"))
        conservation = contract.get("conservation") or {}
        must = conservation.get("must_survive") or []
        has_conservation = bool([m for m in must if not has_placeholder(str(m))])
        has_evidence = bool(contract.get("evidence_required"))

    # T1 — presence
    if not contract_present:
        if criticality in CRITICALITY_REQUIRING_CONTRACT or not criticality:
            errors.append(
                "T1: aucune section `contract:` — obligatoire a partir de C2. "
                "Gabarit : TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml"
            )
        return errors, warnings

    if criticality and criticality not in CRITICALITY_REQUIRING_CONTRACT:
        warnings.append(f"T1: criticite {criticality} — contrat facultatif, controle allege")

    # T2 — objectif
    if not objective:
        errors.append("T2: `objective` vide — l'effet attendu sur la machine doit etre ecrit")
    elif has_placeholder(objective):
        errors.append(f"T2: `objective` encore au gabarit : {objective[:70]!r}")

    # T3 — criteres et verification
    if not statements:
        errors.append("T3: aucun critere d'acceptation (`acceptance:`)")
    for i, statement in enumerate(statements):
        label = f"AC{i + 1}"
        if not statement.strip() or has_placeholder(statement):
            errors.append(f"T3: {label} vide ou au gabarit : {statement[:70]!r}")
            continue
        # T4 — generique
        if is_generic(statement):
            errors.append(
                f"T4: {label} generique — {statement[:70]!r}. "
                "Un critere doit dire ce que la MACHINE fait, pas que le travail est bien fait."
            )
        proof = verified[i] if i < len(verified) else ""
        if not proof.strip() or has_placeholder(proof):
            errors.append(f"T3: {label} sans `verified_by` exploitable — comment le prouve-t-on ?")

    # T5 — perimetre
    if not has_scope:
        errors.append("T5: `scope.allowed` vide — le perimetre autorise doit etre explicite")

    # T6 — conservation (rebuild uniquement)
    if strategy == "rebuild" and not has_conservation:
        errors.append(
            "T6: strategy=rebuild sans `conservation.must_survive` rempli. "
            "Ce qui doit survivre s'ecrit AVANT de couper le moindre lien."
        )

    # T7 — preuves
    if not has_evidence:
        errors.append("T7: `evidence_required` vide — quelles sorties doivent figurer en restitution ?")

    if release and errors:
        errors.append("--release : lot INCOMPLET, ne pas annoncer termine")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("contract", type=Path, help="TASK_CONTEXT.yaml portant la section contract:")
    parser.add_argument("--release", action="store_true", help="Controle de restitution finale")
    args = parser.parse_args()

    if not args.contract.is_file():
        print(f"[ERROR] fichier introuvable : {args.contract}", file=sys.stderr)
        return 2

    errors, warnings = check(args.contract, args.release)

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {args.contract.name}: {error}", file=sys.stderr)

    print(
        f"\nTask contract check: {'FAIL' if errors else 'PASS'} "
        f"({len(errors)} erreur(s), {len(warnings)} avertissement(s))"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
