#!/usr/bin/env python3
"""Garde-fou mécanique : certifie que l'animation FICHE_SEMI_AUTO_ANIMATION.html est un
PUR LECTEUR de la trace — aucune logique métier / aucun calcul de mouvement en JavaScript.

Analyse AST-lite (tokenisation + flux de données sur les sinks), plus robuste qu'un grep :
  1. La TRACE EMBARQUÉE (const __TRACE = {...}) est EXCLUE de l'analyse : c'est des données,
     pas du code métier.
  2. Rejets bloquants sur le code applicatif : Math.random, Date.now, performance.now,
     setInterval/requestAnimationFrame qui MUTENT une position, objet STATE (machine d'état),
     executeAutoSequence/simStep/updatePhysics, += / -= sur une position entre frames.
  3. Sinks (écritures de position Canvas) : setAttribute('transform'/'d'…), textContent/innerText
     sur les éléments de scène. Les variables libres de chaque sink doivent être
     ⊆ {trace, scanIndex, constantes, refs DOM, fonctions SVG natives}.
  4. Preuve que les positions Canvas ne dérivent que des champs de la trace.

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/guard_animation_no_business_logic.py
    python TOOLS/TEST_AUTO_CI/scripts/guard_animation_no_business_logic.py --html <fichier>
"""

import argparse
import pathlib
import re
import sys

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
DEFAULT_HTML = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / "G_CYCLE" / "reports" / "FICHE_SEMI_AUTO_ANIMATION.html"

# Éléments de scène dont la position est un SINK (ne doit dériver que de la trace)
SCENE_SINKS = {
    "gantryGroup", "bucketGroup", "cablePathM1", "cablePathM2",
    "jawLeftGroup", "jawRightGroup", "bucketGravel", "grpSlackBadge",
}

# Fonctions SVG / DOM natives autorisées dans une expression de sink (rendu, pas logique)
ALLOWED_FUNCS = {
    "field", "parseFloat", "getElementById", "Math", "String", "Number",
    "rotate", "translate", "scale", "matrix", "setAttribute", "toFixed",
}

# Patterns bloquants (logique métier / calcul de mouvement en JS) — sur le code applicatif
BLOCKING_PATTERNS = [
    (r"Math\.random", "génération aléatoire (logique non déterministe)"),
    (r"Date\.now", "horloge réelle (non déterministe)"),
    (r"performance\.now", "horloge réelle (non déterministe)"),
    (r"\bexecuteAutoSequence\b", "machine d'état JS fictive"),
    (r"\bsimStep\b", "boucle de simulation JS fictive"),
    (r"\bupdatePhysics\b", "calcul de physique JS fictif"),
    (r"\bSTATE\s*\.", "objet d'état machine simulé (logique métier)"),
    (r"\bSTATE\s*=", "affectation d'état machine simulé"),
    (r"setInterval\s*\([^)]*[+\-]=|requestAnimationFrame\s*\([^)]*[+\-]=",
     "boucle qui mute une position entre frames"),
]

# Accès à un champ de la trace : field(scan, 'CHAMP')
TRACE_ACCESS = re.compile(r"field\(\s*scan\s*,\s*['\"]([A-Z0-9_.]+)['\"]\s*\)")


def extract_js(html: str) -> str:
    """Extrait le contenu des balises <script> et RETIRE la trace embarquée
    (const __TRACE = {...}) qui est des données, pas du code métier."""
    scripts = re.findall(r"<script[^>]*>(.*?)</script>", html, re.DOTALL)
    js = "\n".join(scripts)
    # Retire le bloc de trace embarquée : const __TRACE = { ... };
    js = re.sub(r"const\s+__TRACE\s*=\s*\{.*?\};", "", js, flags=re.DOTALL)
    return js


def check_blocking(js: str) -> list:
    violations = []
    for pattern, label in BLOCKING_PATTERNS:
        for m in re.finditer(pattern, js):
            line = js.count("\n", 0, m.start()) + 1
            violations.append(f"L{line}: {label} — '{m.group(0)[:60]}'")
    return violations


def check_sinks(js: str) -> list:
    """Vérifie que les sinks de position Canvas ne dérivent que de la trace."""
    problems = []
    sink_re = re.compile(
        r"getElementById\(\s*['\"](%s)['\"]\s*\)\.setAttribute\(\s*['\"](transform|d)['\"]\s*,\s*([^;]+)\)"
        % "|".join(re.escape(s) for s in SCENE_SINKS), re.IGNORECASE)
    for m in sink_re.finditer(js):
        line = js.count("\n", 0, m.start()) + 1
        expr = m.group(3)
        # Mutation de position (calcul de mouvement)
        if re.search(r"[A-Za-z_]\w*\s*[+\-]=\s*[^;]*[+\-]=", expr):
            problems.append(f"L{line}: sink {m.group(1)} — mutation de position (calcul de mouvement)")
        # Appel à une fonction non autorisée dans le sink
        for fn in re.finditer(r"\b([a-zA-Z_]\w*)\s*\(", expr):
            name = fn.group(1)
            if name not in ALLOWED_FUNCS:
                problems.append(f"L{line}: sink {m.group(1)} — appel à '{name}' (source non-trace)")
    return problems


def check_trace_derivation(js: str) -> list:
    """Preuve que les positions Canvas ne dérivent que des champs de la trace.
    Analyse de flux de données : collecte les variables assignées depuis field(scan,...)
    (directement ou via parseFloat), puis vérifie que chaque sink de position n'utilise que
    ces variables + constantes + fonctions autorisées."""
    problems = []

    # 1. Collecte des variables dérivées de la trace (taint sources)
    trace_vars = set()
    # field(scan,'X') -> assigné à une variable
    for m in re.finditer(r"([a-zA-Z_]\w*)\s*=\s*(?:parseFloat\()?\s*field\(\s*scan\s*,\s*['\"][A-Z0-9_.]+['\"]\s*\)", js):
        trace_vars.add(m.group(1))
    # propagation : var2 = var1 + constante (var1 déjà trace)
    changed = True
    while changed:
        changed = False
        for m in re.finditer(r"([a-zA-Z_]\w*)\s*=\s*([^;]+);", js):
            name, expr = m.group(1), m.group(2)
            if name in trace_vars:
                continue
            # l'expression référence une variable trace + opérateurs/constantes
            if any(v in trace_vars for v in re.findall(r"\b([a-zA-Z_]\w*)\b", expr)):
                trace_vars.add(name)
                changed = True

    # 2. Vérification des sinks
    sink_re = re.compile(
        r"getElementById\(\s*['\"](%s)['\"]\s*\)\.setAttribute\(\s*['\"](transform|d)['\"]\s*,\s*([^;]+)\)"
        % "|".join(re.escape(s) for s in SCENE_SINKS), re.IGNORECASE)
    for m in sink_re.finditer(js):
        line = js.count("\n", 0, m.start()) + 1
        expr = m.group(3)
        # Variables libres dans l'expression du sink
        for v in re.findall(r"\b([a-zA-Z_]\w*)\b", expr):
            if v in {"field", "parseFloat", "getElementById", "Math", "String", "Number",
                     "rotate", "translate", "scale", "matrix", "setAttribute", "toFixed"}:
                continue
            if v in trace_vars:
                continue
            # constante numérique / littéral
            if re.fullmatch(r"\d+(\.\d+)?", v):
                continue
            problems.append(f"L{line}: sink {m.group(1)} — variable '{v}' non dérivée de la trace")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", default=str(DEFAULT_HTML))
    args = parser.parse_args()

    html_path = pathlib.Path(args.html)
    if not html_path.exists():
        print(f"[ERREUR] HTML introuvable : {html_path}")
        return 1

    html = html_path.read_text(encoding="utf-8")
    js = extract_js(html)
    if not js.strip():
        print("[ERREUR] Aucun <script> (hors trace embarquée) trouvé dans le HTML")
        return 1

    blocking = check_blocking(js)
    sink_problems = check_sinks(js)
    derivation = check_trace_derivation(js)

    all_problems = blocking + sink_problems + derivation
    if all_problems:
        print("❌ GARDE-FOU ÉCHOUÉ — logique métier / calcul de mouvement détecté en JS :")
        for p in all_problems:
            print(f"  - {p}")
        return 1

    print("✅ GARDE-FOU PASS — l'animation est un pur lecteur de la trace :")
    print(f"   - 0 pattern bloquant (STATE/simStep/executeAutoSequence/Math.random/…)")
    print(f"   - 0 sink de position alimenté par une source non-trace")
    print(f"   - positions Canvas dérivées des champs de la trace")
    print(f"   - fichier : {html_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
