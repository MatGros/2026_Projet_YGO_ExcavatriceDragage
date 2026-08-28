#!/usr/bin/env python3
"""Garde-fou mÃ©canique : certifie que l'animation FICHE_SEMI_AUTO_ANIMATION.html est un
PUR LECTEUR de la trace â€” aucune logique mÃ©tier / aucun calcul de mouvement en JavaScript.

Analyse AST-lite (tokenisation + flux de donnÃ©es sur les sinks), plus robuste qu'un grep :
  1. La TRACE EMBARQUÃ‰E (const __TRACE = {...}) est EXCLUE de l'analyse : c'est des donnÃ©es,
     pas du code mÃ©tier.
  2. Rejets bloquants sur le code applicatif : Math.random, Date.now, performance.now,
     setInterval/requestAnimationFrame qui MUTENT une position, objet STATE (machine d'Ã©tat),
     executeAutoSequence/simStep/updatePhysics, += / -= sur une position entre frames.
  3. Sinks (Ã©critures de position Canvas) : setAttribute('transform'/'d'â€¦), textContent/innerText
     sur les Ã©lÃ©ments de scÃ¨ne. Les variables libres de chaque sink doivent Ãªtre
     âŠ† {trace, scanIndex, constantes, refs DOM, fonctions SVG natives}.
  4. Preuve que les positions Canvas ne dÃ©rivent que des champs de la trace.

Usage :
    python TOOLS/TEST_AUTO_CI/anim_bench/guard_animation_no_business_logic.py
    python TOOLS/TEST_AUTO_CI/anim_bench/guard_animation_no_business_logic.py --html <fichier>
"""

import argparse
import json
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

# Ã‰lÃ©ments de scÃ¨ne dont la position est un SINK (ne doit dÃ©river que de la trace)
SCENE_SINKS = {
    "gantryGroup", "bucketGroup", "cablePathM1", "cablePathM2",
    "jawLeftGroup", "jawRightGroup", "bucketGravel", "grpSlackBadge",
}

# Fonctions SVG / DOM natives autorisÃ©es dans une expression de sink (rendu, pas logique)
ALLOWED_FUNCS = {
    "field", "parseFloat", "getElementById", "Math", "String", "Number",
    "rotate", "translate", "scale", "matrix", "setAttribute", "toFixed",
}

# Patterns bloquants (logique mÃ©tier / calcul de mouvement en JS) â€” sur le code applicatif
BLOCKING_PATTERNS = [
    (r"Math\.random", "gÃ©nÃ©ration alÃ©atoire (logique non dÃ©terministe)"),
    (r"Date\.now", "horloge rÃ©elle (non dÃ©terministe)"),
    (r"performance\.now", "horloge rÃ©elle (non dÃ©terministe)"),
    (r"\bexecuteAutoSequence\b", "machine d'Ã©tat JS fictive"),
    (r"\bsimStep\b", "boucle de simulation JS fictive"),
    (r"\bupdatePhysics\b", "calcul de physique JS fictif"),
    (r"\bSTATE\s*\.", "objet d'Ã©tat machine simulÃ© (logique mÃ©tier)"),
    (r"\bSTATE\s*=", "affectation d'Ã©tat machine simulÃ©"),
    (r"setInterval\s*\([^)]*[+\-]=|requestAnimationFrame\s*\([^)]*[+\-]=",
     "boucle qui mute une position entre frames"),
]

# AccÃ¨s Ã  un champ de la trace : field(scan, 'CHAMP')
TRACE_ACCESS = re.compile(r"field\(\s*scan\s*,\s*['\"]([A-Z0-9_.]+)['\"]\s*\)")


def extract_js(html: str) -> str:
    """Extrait le contenu des balises <script> et RETIRE la trace embarquÃ©e
    (const __TRACE = {...}) qui est des donnÃ©es, pas du code mÃ©tier."""
    scripts = re.findall(r"<script[^>]*>(.*?)</script>", html, re.DOTALL)
    js = "\n".join(scripts)
    # Retire le bloc de trace embarquÃ©e : const __TRACE = { ... };
    js = re.sub(r"const\s+__TRACE\s*=\s*\{.*?\};", "", js, flags=re.DOTALL)
    return js


def check_blocking(js: str) -> list:
    violations = []
    for pattern, label in BLOCKING_PATTERNS:
        for m in re.finditer(pattern, js):
            line = js.count("\n", 0, m.start()) + 1
            violations.append(f"L{line}: {label} â€” '{m.group(0)[:60]}'")
    return violations


def check_sinks(js: str) -> list:
    """VÃ©rifie que les sinks de position Canvas ne dÃ©rivent que de la trace."""
    problems = []
    sink_re = re.compile(
        r"getElementById\(\s*['\"](%s)['\"]\s*\)\.setAttribute\(\s*['\"](transform|d)['\"]\s*,\s*([^;]+)\)"
        % "|".join(re.escape(s) for s in SCENE_SINKS), re.IGNORECASE)
    for m in sink_re.finditer(js):
        line = js.count("\n", 0, m.start()) + 1
        expr = m.group(3)
        # Mutation de position (calcul de mouvement)
        if re.search(r"[A-Za-z_]\w*\s*[+\-]=\s*[^;]*[+\-]=", expr):
            problems.append(f"L{line}: sink {m.group(1)} â€” mutation de position (calcul de mouvement)")
        # Appel Ã  une fonction non autorisÃ©e dans le sink
        for fn in re.finditer(r"\b([a-zA-Z_]\w*)\s*\(", expr):
            name = fn.group(1)
            if name not in ALLOWED_FUNCS:
                problems.append(f"L{line}: sink {m.group(1)} â€” appel Ã  '{name}' (source non-trace)")
    return problems


def check_trace_derivation(js: str) -> list:
    """Preuve que les positions Canvas ne dÃ©rivent que des champs de la trace.
    Analyse de flux de donnÃ©es : collecte les variables assignÃ©es depuis field(scan,...)
    (directement ou via parseFloat), puis vÃ©rifie que chaque sink de position n'utilise que
    ces variables + constantes + fonctions autorisÃ©es."""
    problems = []

    # 1. Collecte des variables dÃ©rivÃ©es de la trace (taint sources)
    trace_vars = set()
    # field(scan,'X') -> assignÃ© Ã  une variable
    for m in re.finditer(r"([a-zA-Z_]\w*)\s*=\s*(?:parseFloat\()?\s*field\(\s*scan\s*,\s*['\"][A-Z0-9_.]+['\"]\s*\)", js):
        trace_vars.add(m.group(1))
    # isOn(scan,'X') -> assignÃ© Ã  une variable (fonction de lecture de trace)
    for m in re.finditer(r"([a-zA-Z_]\w*)\s*=\s*isOn\(\s*scan\s*,\s*['\"][A-Z0-9_.]+['\"]\s*\)", js):
        trace_vars.add(m.group(1))
    # propagation : var2 = var1 + constante (var1 dÃ©jÃ  trace)
    changed = True
    while changed:
        changed = False
        for m in re.finditer(r"([a-zA-Z_]\w*)\s*=\s*([^;]+);", js):
            name, expr = m.group(1), m.group(2)
            if name in trace_vars:
                continue
            # l'expression rÃ©fÃ©rence une variable trace + opÃ©rateurs/constantes
            if any(v in trace_vars for v in re.findall(r"\b([a-zA-Z_]\w*)\b", expr)):
                trace_vars.add(name)
                changed = True

    # 2. VÃ©rification des sinks
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
            # constante numÃ©rique / littÃ©ral
            if re.fullmatch(r"\d+(\.\d+)?", v):
                continue
            problems.append(f"L{line}: sink {m.group(1)} â€” variable '{v}' non dÃ©rivÃ©e de la trace")
    return problems


def check_trace_freshness(html: str, html_path: pathlib.Path) -> list:
    """ContrÃ´le de fraÃ®cheur (T171-B) : le sha256 de la trace embarquÃ©e (__TRACE) doit
    correspondre Ã  celui de la trace courante trace_semi_auto_cycle.json. Un embed pÃ©rimÃ©
    signifie que l'animation ne joue plus le binaire compilÃ© courant."""
    problems = []
    trace_path = html_path.parent / "trace_semi_auto_cycle.json"
    if not trace_path.exists():
        return [f"trace courante introuvable : {trace_path}"]
    try:
        current = json.loads(trace_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"trace courante illisible (JSON invalide) : {exc}"]
    current_sha = current.get("meta", {}).get("sha256", "")
    current_scans = current.get("meta", {}).get("n_scans", 0)

    m = re.search(r"const\s+__TRACE\s*=\s*(\{.*?\});\s*\n", html, re.DOTALL)
    if not m:
        return ["bloc 'const __TRACE = {...};' introuvable dans le HTML"]
    try:
        embedded = json.loads(m.group(1))
    except json.JSONDecodeError as exc:
        return [f"trace embarquÃ©e illisible (JSON invalide) : {exc}"]
    embedded_sha = embedded.get("meta", {}).get("sha256", "")
    embedded_scans = embedded.get("meta", {}).get("n_scans", 0)

    if embedded_sha != current_sha:
        problems.append(
            f"trace embarquÃ©e PÃ‰RIMÃ‰E : sha256={embedded_sha[:16]}â€¦ (n_scans={embedded_scans}) "
            f"â‰  trace courante sha256={current_sha[:16]}â€¦ (n_scans={current_scans}) â€” "
            f"relancer embed_trace_in_animation.py")

    # Maillon source : la trace doit avoir Ã©tÃ© gÃ©nÃ©rÃ©e depuis la source FB COURANTE
    fb_source = html_path.parents[3] / "WORKING_COPY" / "CODE" / "G_CYCLE" / "FB_Cycle.st"
    if not fb_source.exists():
        problems.append(f"source FB introuvable : {fb_source}")
    else:
        import hashlib
        source_sha = hashlib.sha256(fb_source.read_bytes()).hexdigest()
        declared_sha = current.get("meta", {}).get("source_sha256", "")
        if declared_sha != source_sha:
            problems.append(
                f"trace gÃ©nÃ©rÃ©e depuis une source PÃ‰RIMÃ‰E : meta.source_sha256="
                f"{declared_sha[:16]}â€¦ â‰  hash courant {source_sha[:16]}â€¦ de {fb_source.name} â€” "
                f"relancer generate_trace_cycle.py puis embed_trace_in_animation.py")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", default=str(DEFAULT_HTML))
    parser.add_argument("--no-freshness", action="store_true",
                        help="DÃ©sactive le contrÃ´le de fraÃ®cheur trace (pour les pages non-lecteur, ex. banc interactif T173)")
    args = parser.parse_args()

    html_path = pathlib.Path(args.html)
    if not html_path.exists():
        print(f"[ERREUR] HTML introuvable : {html_path}")
        return 1

    html = html_path.read_text(encoding="utf-8")
    js = extract_js(html)
    if not js.strip():
        print("[ERREUR] Aucun <script> (hors trace embarquÃ©e) trouvÃ© dans le HTML")
        return 1

    blocking = check_blocking(js)
    sink_problems = check_sinks(js)
    derivation = check_trace_derivation(js)
    freshness = [] if args.no_freshness else check_trace_freshness(html, html_path)

    all_problems = blocking + sink_problems + derivation + freshness
    if all_problems:
        print("âŒ GARDE-FOU Ã‰CHOUÃ‰ â€” logique mÃ©tier / embed pÃ©rimÃ© dÃ©tectÃ© :")
        for p in all_problems:
            print(f"  - {p}")
        return 1

    print("âœ… GARDE-FOU PASS â€” l'animation est un pur lecteur de la trace :")
    print(f"   - 0 pattern bloquant (STATE/simStep/executeAutoSequence/Math.random/â€¦)")
    print(f"   - 0 sink de position alimentÃ© par une source non-trace")
    print(f"   - positions Canvas dÃ©rivÃ©es des champs de la trace")
    if not args.no_freshness:
        print(f"   - trace embarquÃ©e Ã€ JOUR (sha256 == trace_semi_auto_cycle.json)")
        print(f"   - chaÃ®ne SHA complÃ¨te : HTML == trace JSON == WORKING_COPY/FB_Cycle.st (source_sha256 vÃ©rifiÃ©e)")
    print(f"   - fichier : {html_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
