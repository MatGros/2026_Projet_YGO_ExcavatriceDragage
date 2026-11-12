"""Règles déterministes de conformité (prototype). Aucun LLM, aucune lecture disque.

Entrée : une écriture proposée (chemin relatif au dépôt) + un catalogue d'outils existants (noms de fichiers).
Sortie : liste de signaux. Les cas sont synthétiques et étiquetés à la main dans cas.json.
"""
import re

ALLOWED_PREFIXES = ("DOC/WFLOW/", "CODE/", "TOOLS/", "TOOLS/AGENT_SUPERVISOR/poc/")
SCRATCH_RE = re.compile(r"(brouillon|draft|tmp|scratch|test_?old|copie)", re.IGNORECASE)


def _stem(path):
    name = path.rsplit("/", 1)[-1]
    return name.rsplit(".", 1)[0].lower()


def _tokens(s):
    return {t for t in re.split(r"[_\-]+", s.lower()) if len(t) >= 4}


def check_write(path, catalog):
    signals = []
    if not path.startswith(ALLOWED_PREFIXES):
        signals.append("zone_hors_perimetre")
    if SCRATCH_RE.search(path.rsplit("/", 1)[-1]):
        signals.append("nom_brouillon")
    if path.endswith((".py", ".ps1", ".mjs", ".sh")) and path.startswith("TOOLS/"):
        tok = _tokens(_stem(path))
        if tok and any(_stem(c) != _stem(path) and len(tok & _tokens(_stem(c))) >= max(1, len(tok) - 1) for c in catalog):
            signals.append("doublon_outil_probable")
    return signals


def evaluate(cases, catalog):
    tp = fp = fn = tn = 0
    misses = []
    for case in cases:
        got = bool(check_write(case["path"], catalog))
        want = case["violation"]
        if got and want: tp += 1
        elif got and not want: fp += 1; misses.append(("FP", case["id"]))
        elif not got and want: fn += 1; misses.append(("FN", case["id"]))
        else: tn += 1
    return {"tp": tp, "fp": fp, "fn": fn, "tn": tn, "erreurs": misses}
