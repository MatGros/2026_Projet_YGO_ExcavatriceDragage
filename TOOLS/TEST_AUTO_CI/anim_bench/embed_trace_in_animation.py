#!/usr/bin/env python3
"""Ré-embedde la trace fraîche (trace_semi_auto_cycle.json) dans FICHE_SEMI_AUTO_ANIMATION.html.

Remplace le bloc `const __TRACE = { ... };` du HTML par le contenu courant du JSON de trace.
Le HTML reste un PUR LECTEUR : cette opération ne touche que la constante de données,
jamais le code applicatif (le garde-fou guard_animation_no_business_logic.py exclut __TRACE
de son analyse pour cette raison exacte).

Chaîne de fraîcheur imposée (T171-B) :
    1. python TOOLS/TEST_AUTO_CI/anim_bench/generate_trace_cycle.py     # trace fraîche
    2. python TOOLS/TEST_AUTO_CI/anim_bench/embed_trace_in_animation.py # ré-embed
    3. python TOOLS/TEST_AUTO_CI/anim_bench/guard_animation_no_business_logic.py  # certification

Usage :
    python TOOLS/TEST_AUTO_CI/anim_bench/embed_trace_in_animation.py
    python TOOLS/TEST_AUTO_CI/anim_bench/embed_trace_in_animation.py --check  # 0 si déjà à jour
"""

import argparse
import json
import pathlib
import sys

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
REPORTS = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / "G_CYCLE" / "reports"
TRACE_JSON = REPORTS / "trace_semi_auto_cycle.json"
HTML = REPORTS / "FICHE_SEMI_AUTO_ANIMATION.html"

MARKER = "const __TRACE = "


def _find_block_end(text: str, start: int) -> int:
    """Retourne l'index du ';' fermant le bloc objet commençant à `start` ('{').
    Comptage d'accolades en ignorant les littéraux de chaîne (pas de commentaire JS
    dans le JSON embarqué — sortie de json.dumps)."""
    depth = 0
    i = start
    in_str = False
    esc = False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    # avancer jusqu'au ';' qui ferme l'instruction
                    j = text.index(";", i)
                    return j
        i += 1
    raise ValueError("Fin du bloc __TRACE introuvable")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Ne modifie rien : retourne 1 si l'embed est périmé")
    args = parser.parse_args()

    if not TRACE_JSON.exists():
        print(f"[ERREUR] Trace introuvable : {TRACE_JSON}")
        return 1
    if not HTML.exists():
        print(f"[ERREUR] HTML introuvable : {HTML}")
        return 1

    trace_text = TRACE_JSON.read_text(encoding="utf-8")
    trace = json.loads(trace_text)
    trace_sha = trace.get("meta", {}).get("sha256", "")
    n_scans = trace.get("meta", {}).get("n_scans", 0)

    html = HTML.read_text(encoding="utf-8")
    pos = html.find(MARKER)
    if pos < 0:
        print("[ERREUR] Bloc 'const __TRACE = ' introuvable dans le HTML")
        return 1
    brace_start = html.index("{", pos)
    block_end = _find_block_end(html, brace_start)
    embedded = html[brace_start:block_end]  # sans le ';' fermant
    try:
        embedded_trace = json.loads(embedded)
    except json.JSONDecodeError as exc:
        print(f"[ERREUR] JSON embarqué invalide : {exc}")
        return 1
    embedded_sha = embedded_trace.get("meta", {}).get("sha256", "")
    embedded_scans = embedded_trace.get("meta", {}).get("n_scans", 0)

    print(f"Trace JSON    : sha256={trace_sha[:16]}… · n_scans={n_scans}")
    print(f"Trace embarquée: sha256={embedded_sha[:16]}… · n_scans={embedded_scans}")

    if embedded_sha == trace_sha:
        print("✅ Embed déjà à jour — rien à faire")
        return 0

    if args.check:
        print("❌ Embed PÉRIMÉ — relancer embed_trace_in_animation.py (sans --check)")
        return 1

    new_html = html[:brace_start] + trace_text.rstrip("\n") + html[block_end:]
    HTML.write_text(new_html, encoding="utf-8")
    print(f"✅ Trace ré-embeddée dans {HTML.name} ({embedded_scans} -> {n_scans} scans)")
    return 0


if __name__ == "__main__":
    sys.exit(main())