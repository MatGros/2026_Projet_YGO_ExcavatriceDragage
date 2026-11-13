#!/usr/bin/env python3
"""Gate du contrat de tache : refuse les objectifs non testables.

Classe de bug couverte (REX 2026-07-29) : sur 53 taches deleguees, les
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
  T8  une tache touchant CODE/MAIN declare les deux preuves structurelles :
      nom de fichier = nom de POU et suffixe de langage = langage bundle
  T9  execution_plan present des C2 : au moins un jalon avec title et
      done_when non vides (T427-AC3 ; defaut = WARN, T426-AC7)
  T10 chaque entree test_feedback tient sur une ligne <= 120 caracteres :
      le sas d'essais n'accepte ni code a chaud ni paragraphe (T427-AC3)
  T11 tracking.budget coherent (0 <= used <= total, 1 <= parallel_max <=
      total) et companion_doc cite comme chemin de projet sans restes de
      gabarit — l'existence physique du fichier relve de G530 (T427-AC3)

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <TASK_CONTEXT.yaml>
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier> --release
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# Formulations observees dans les artefacts de sous-agents : elles ne disent rien
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
# Seuil du sas d'essais (T427-AC2) : une entree test_feedback = 1 ligne courte.
TEST_FEEDBACK_MAX_CHARS = 120

# Un contrat touchant un PROGRAM doit rendre les deux controles structurels
# explicites AVANT ecriture. Ce gate ne parse jamais le code : il valide que
# l'orchestrateur a formule les preuves attendues dans le contrat.
STRUCTURAL_SCOPE_PREFIXES = ("CODE/M_MAIN/", "CODE/MAIN/")
# Une cooccurrence de mots est insuffisante : l'operateur relationnel doit
# relier LOCALement les deux termes. Les motifs interdisent notamment de faire
# passer « fichier est identique dans la revue ; POU documente » : un point, un
# point-virgule ou un retour ligne coupe la relation.
EQUALITY = r"(?:=|est\s+)?(?:identique|egal|égale?|correspond(?:ance)?|associe)"
LOCAL = r"[^.;\n]{0,50}"
FILE_POU_RELATIONS = (
    re.compile(rf"\b(?:nom\s+d(?:e|u)\s+)?fichier\b{LOCAL}{EQUALITY}{LOCAL}\bnom\s+d(?:e|u)\s+POU\b", re.IGNORECASE),
    re.compile(rf"\bnom\s+d(?:e|u)\s+POU\b{LOCAL}{EQUALITY}{LOCAL}\b(?:nom\s+d(?:e|u)\s+)?fichier\b", re.IGNORECASE),
    re.compile(rf"\bPOU\b{LOCAL}\bnom\b{LOCAL}{EQUALITY}{LOCAL}\b(?:nom\s+d(?:e|u)\s+)?fichier\b", re.IGNORECASE),
)
SUFFIX_LANGUAGE_RELATIONS = (
    re.compile(rf"\bsuffixe\b{LOCAL}{EQUALITY}{LOCAL}\blangage\b{LOCAL}\bbundle\b", re.IGNORECASE),
    re.compile(rf"\blangage\b{LOCAL}{EQUALITY}{LOCAL}\bsuffixe\b{LOCAL}\bbundle\b", re.IGNORECASE),
)


def load_yaml(path: Path) -> dict | None:
    """Charge le YAML. PyYAML si dispo, sinon repli sur un mini-parseur.

    CHECK_TASK_CONTRACT_DISABLE_PYYAML=1 permet de tester le repli en CI.
    """
    if os.environ.get("CHECK_TASK_CONTRACT_DISABLE_PYYAML") == "1":
        return None
    text = path.read_text(encoding="utf-8", errors="replace")
    try:
        import yaml  # type: ignore

        return yaml.safe_load(text) or {}
    except ImportError:
        return None


def raw_scope_allowed(text: str) -> list[str]:
    """Retourne exclusivement scope.allowed du YAML standard du projet.

    Le repli ne doit jamais confondre une entree forbidden avec une entree
    allowed : cela transformerait une tache documentaire en tache CODE/MAIN.
    Indentation des items toleree a partir de 4 espaces : les contrats ecrits
    par l'API Task Manager (ex. fusion T426->T427) indentent les listes au
    niveau de la cle, contrairement au gabarit (6 espaces). REX 2026-11-12 :
    le repli declarait T5 a tort sur le contrat fusionne actif.
    """
    scope = re.search(r"(?ms)^  scope:\s*\n(?P<body>.*?)(?=^  [A-Za-z_]\w*:\s*|\Z)", text)
    if not scope:
        return []
    allowed = re.search(r"(?ms)^    allowed:\s*\n(?P<items>.*?)(?=^    [A-Za-z_]\w*:\s*|\Z)", scope.group("body"))
    if not allowed:
        return []
    return re.findall(r"^[ \t]+-\s+['\"]?([^'\"\n]+)", allowed.group("items"), re.MULTILINE)


def raw_acceptance_values(text: str, field: str) -> list[str]:
    """Extrait les valeurs inline ou repliees du bloc acceptance standard.

    Une valeur YAML repliee commence par ``>`` ou ``|``. Elle ne doit jamais
    etre aussi capturee comme valeur inline : cela decalerait statements et
    verified_by, donc creerait de faux T3 quand PyYAML est indisponible.
    """
    # ``\s`` inclut les retours ligne : ne l'utiliser ni autour de l'ancre,
    # ni dans le lookahead, sinon ``statement: >`` est encore capture comme
    # inline apres backtracking a travers une ligne suivante.
    inline = re.findall(
        rf"^[ \t]*{field}:(?![ \t]*[>|][ \t]*$)[ \t]*[\"']?(.+?)[\"']?[ \t]*$",
        text,
        re.MULTILINE,
    )
    folded = re.findall(
        rf"(?ms)^[ \t]*{field}:[ \t]*[>|][ \t]*\n(?P<value>.*?)(?=^[ \t]*verified_by:|^[ \t]*-[ \t]+id:|\Z)",
        text,
    )
    return [" ".join(value.split()) for value in [*inline, *folded]]


def scan_raw(text: str) -> dict:
    """Analyse textuelle de secours quand PyYAML est absent."""
    return {
        "has_contract": bool(re.search(r"^\s*contract\s*:", text, re.M)),
        "criticality": (m.group(1) if (m := re.search(r"criticality\s*:\s*(C[0-4])", text)) else ""),
        "strategy": (m.group(1) if (m := re.search(r"strategy\s*:\s*(patch|rebuild)", text)) else ""),
        "statements": raw_acceptance_values(text, "statement"),
        "verified": raw_acceptance_values(text, "verified_by"),
        "allowed": raw_scope_allowed(text),
        # T5 impose le contenu de scope.allowed, pas seulement un marqueur
        # ``scope:`` qui peut etre vide ou ne contenir que forbidden.
        "has_scope": bool(raw_scope_allowed(text)),
        "has_conservation": bool(re.search(r"must_survive\s*:", text)),
        "has_evidence": bool(re.search(r"evidence_required\s*:", text)),
        "objective": (m.group(1).strip() if (m := re.search(r"objective\s*:\s*>?\s*\n?\s*(.+)", text)) else ""),
    }


def is_generic(statement: str) -> bool:
    low = statement.strip().lower()
    return any(re.search(p, low) for p in GENERIC_PATTERNS)


def has_placeholder(value: str) -> bool:
    return any(ph.lower() in value.lower() for ph in PLACEHOLDERS)


def normalize_entry(value: object) -> str:
    """Aplatit une entree YAML (inline, repliee ou multi-ligne) en une ligne."""
    return " ".join(str(value).split()) if value is not None else ""


def scan_execution_plan(text: str) -> list[dict]:
    """Extrait les jalons du bloc `execution_plan:` replie standard du projet.

    Le bloc attendu, au niveau racine ou de `contract:`, porte des jalons en
    liste : `- id: M1` / `title:` / `done_when:` (gabarit et contrat T427).
    """
    block = re.search(
        r"(?ms)^(?:execution_plan:|  execution_plan:)\s*\n(?P<body>.*?)(?=^[A-Za-z_]\w*:\s*|^  [A-Za-z_]\w*:\s*|\Z)",
        text,
    )
    if not block:
        return []
    milestones: list[dict] = []
    current: dict = {}
    for line in block.group("body").splitlines():
        stripped = line.strip()
        if line.startswith("  - "):
            if current:
                milestones.append(current)
            current = {}
        m = re.match(r"(id|title|done_when|done-when)\s*:\s*(.*)", stripped)
        if m:
            current["id" if m.group(1) == "id" else ("title" if m.group(1) == "title" else "done_when")] = m.group(2).strip()
    if current:
        milestones.append(current)
    return [jalon for jalon in milestones if jalon]


def scan_test_feedback(text: str) -> list[str]:
    """Extrait les entrees test_feedback (inline simples ou items de liste)."""
    block = re.search(r"(?ms)^test_feedback:\s*(\[)\s*(.*?)\]", text)
    if block:
        return [normalize_entry(item) for item in block.group(2).split(",") if item.strip()]
    block = re.search(r"(?ms)^test_feedback:\s*\n(?P<body>.*?)(?=^[A-Za-z_]\w*:\s*|\Z)", text)
    if not block:
        return []
    return [
        normalize_entry(m.group(1))
        for m in re.finditer(r"^[ \t]+-\s+(.+)$", block.group("body"), re.MULTILINE)
    ]


def check_workflow_fields(data: dict | None, text: str) -> list[str]:
    """Contrôles T9-T11 (T427-AC3) sous la forme d'AVERTISSEMENTS uniquement.

    T426-AC7 : « Les contrôles nouveaux démarrent en avertissement et ne
    changent pas silencieusement les hooks actifs. » Aucune de ces infractions
    ne bascule donc l'exit code : les contrats antérieurs restent valides.
    """
    findings: list[str] = []

    # T9 — execution_plan des C2 : jalons avec title et done_when.
    milestones: list[dict] = []
    if data is not None:
        plan = data.get("execution_plan") or (data.get("contract") or {}).get("execution_plan") or {}
        if isinstance(plan, dict):
            raw = plan.get("milestones")
            if isinstance(raw, list):
                milestones = [dict(m) for m in raw if isinstance(m, dict)]
            elif raw is None and plan:
                # Forme directe d'un jalon unique : execution_plan.title/done_when.
                milestones = [plan]
        elif isinstance(plan, list):
            milestones = [dict(m) for m in plan if isinstance(m, dict)]
    if not milestones:
        milestones = scan_execution_plan(text)
    if not milestones:
        findings.append(
            "T9: aucun `execution_plan` — des C2, le contrat declare au moins un jalon "
            "testable (id, title, done_when) pour cadrer le suivi."
        )
    else:
        for m in milestones:
            mid = normalize_entry(m.get("id")) or "?"
            title = normalize_entry(m.get("title"))
            done = normalize_entry(m.get("done_when"))
            if not title:
                findings.append(f"T9: jalon {mid} sans `title` — un jalon anonyme ne cadre rien.")
            if not done or has_placeholder(done):
                findings.append(
                    f"T9: jalon {mid} sans `done_when` exploitable — comment saura-t-on qu'il est atteint ?"
                )

    # T10 — sas d'essais : une entree = une ligne <= 120 caracteres.
    feedback: list[str] = []
    if data is not None:
        raw_fb = data.get("test_feedback")
        if isinstance(raw_fb, list):
            feedback = [normalize_entry(e) for e in raw_fb]
        elif isinstance(raw_fb, str) and raw_fb.strip():
            feedback = [normalize_entry(raw_fb)]
    if not feedback:
        feedback = scan_test_feedback(text)
    for entry in feedback:
        if len(entry) > TEST_FEEDBACK_MAX_CHARS:
            findings.append(
                f"T10: entree test_feedback de {len(entry)} caracteres (limite "
                f"{TEST_FEEDBACK_MAX_CHARS}) — le sas d'essais n'accepte qu'une ligne courte : "
                f"{entry[:70]!r}..."
            )

    # T11 — budget sous-agents coherent + companion_doc comme chemin de projet.
    tracking = (data or {}).get("tracking") if data is not None else {}
    budget = (tracking or {}).get("budget") if isinstance(tracking, dict) else {}
    if isinstance(budget, dict):
        total = budget.get("total")
        used = budget.get("used")
        parallel_max = budget.get("parallel_max")
        numbers = {
            name: value
            for name, value in (("total", total), ("used", used), ("parallel_max", parallel_max))
            if isinstance(value, (int, float))
        }
        if set(numbers) != {"total", "used", "parallel_max"}:
            findings.append("T11: `tracking.budget` incomplet — total, used et parallel_max attendus.")
        elif not (0 <= used <= total):
            findings.append(f"T11: budget incoherent — used ({used}) hors [0, total={total}].")
        elif not (1 <= parallel_max <= total):
            findings.append(
                f"T11: budget incoherent — parallel_max ({parallel_max}) doit tenir dans [1, total={total}]."
            )
    companion = data.get("companion_doc") if data is not None else None
    if not companion:
        block = re.search(r"(?m)^\s*(?:companion_doc|  companion_doc):\s*['\"]?([^\n]+)", text)
        companion = block.group(1).strip() if block else None
    companion = normalize_entry(companion)
    if companion:
        if companion.startswith(("'", '"')):
            companion = companion.strip("'\"")
        if has_placeholder(companion) or not re.match(r"^(DOC|TOOLS)/", companion):
            findings.append(
                f"T11: `companion_doc` n'est pas un chemin de projet (DOC/ ou TOOLS/) : "
                f"{companion[:70]!r} — l'existence physique du fichier est l'affaire de G530."
            )
    return findings


def touches_program_main(allowed: list[str]) -> bool:
    """Retourne True si scope.allowed autorise une ecriture dans CODE/MAIN ou CODE/M_MAIN."""
    normalized = [entry.replace("\\", "/").lstrip("./").upper() for entry in allowed]
    return any(entry.startswith(STRUCTURAL_SCOPE_PREFIXES) for entry in normalized)


def has_file_pou_criterion(statements: list[str]) -> bool:
    return any(any(pattern.search(statement) for pattern in FILE_POU_RELATIONS) for statement in statements)


def has_suffix_language_criterion(statements: list[str]) -> bool:
    return any(any(pattern.search(statement) for pattern in SUFFIX_LANGUAGE_RELATIONS) for statement in statements)


def check(path: Path, release: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")

    data = load_yaml(path)
    if data is not None:
        # T429 (revue GLM 2026-11-13) : aucun contrat ne peut autoriser un chemin interdit global.
        errors.extend(check_absolute_deny(data))
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
        allowed = raw["allowed"]
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
        allowed = [str(entry) for entry in (scope.get("allowed") or [])]
        has_scope = bool(allowed)
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

    # T8 — objectif structurel obligatoire pour toute ecriture CODE/MAIN.
    # Il doit etre explicite dans les acceptance, jamais seulement suppose dans
    # une convention ou une revue ulterieure.
    if touches_program_main(allowed):
        missing: list[str] = []
        if not has_file_pou_criterion(statements):
            missing.append("nom de fichier = nom de POU")
        if not has_suffix_language_criterion(statements):
            missing.append("suffixe = langage genere dans le bundle")
        if missing:
            errors.append(
                "T8: scope CODE/MAIN sans critere structurel explicite : "
                + "; ".join(missing)
            )

    # T9-T11 — workflow fields (T427-AC3) : avertissements progressifs, jamais
    # bloquants (T426-AC7) ; uniquement des C2, comme le contrat lui-meme.
    if criticality in CRITICALITY_REQUIRING_CONTRACT:
        warnings.extend(check_workflow_fields(data, text))

    if release and errors:
        errors.append("--release : lot INCOMPLET, ne pas annoncer termine")

    return errors, warnings


# Interdits GLOBAUX : aucun contrat de tache ne peut les declarer "autorises"
# (revue GLM 2026-11-13). Source unique : task_scope.ABSOLUTE_DENY.
ABSOLUTE_DENY = (
    "CODE/**", "CODE_XML/**", "PRJ_CODESYS/**",
    ".claude/settings.json", ".claude/settings.local.json", ".claude/settings*.json",
    ".claude/hooks/**", "TOOLS/AGENT_WORKFLOW/hooks/**",
    "TOOLS/AGENT_WORKFLOW/skills/**", ".claude/skills/**", ".agents/skills/**", ".dsh/skills/**",
)


def _deny_hits(entries) -> list:
    hits = []
    for entry in entries or []:
        text = str(entry)
        for denied in ABSOLUTE_DENY:
            base = denied[:-3] if denied.endswith("/**") else denied
            if text == base or text.startswith(base + "/") or base in text:
                hits.append((text, denied))
                break
    return hits


def check_absolute_deny(data) -> list:
    """Un `scope.allowed` qui touche un interdit global = erreur de contrat."""
    problems = []
    contract = (data or {}).get("contract") or {}
    scope = contract.get("scope") or {}
    for entry, denied in _deny_hits(scope.get("allowed")):
        problems.append(f"T9: scope.allowed contient « {entry} » qui touche l'interdit global « {denied} »")
    return problems


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
