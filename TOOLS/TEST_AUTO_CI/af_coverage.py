#!/usr/bin/env python3
"""Verifie la coherence entre le catalogue de tests d'une AF (tableau "Points de validation")
et les tests reellement presents dans le .st de TEST_AUTO_CI.

Non bloquant par design (retourne toujours une liste, jamais d'exception qui casserait un run) :
un warning "TC-Pxx-nnn attendu par l'AF mais absent des tests" n'empeche jamais le pipeline de
passer -- seul G200/le contenu des tests fait foi pour le statut PASS/FAIL. Ce module sert a
signaler un ECART DE PERIMETRE (test manquant), pas une regression de comportement.

Limite assumee : seuls les ID de type contenant "AUTO" (AUTO, AUTO_PLC, SITE+AUTO...) sont
verifiables automatiquement -- un ID purement SITE (verification terrain) ne peut jamais avoir
de contrepartie logicielle et n'est donc jamais remonte comme manquant.
"""

import re

_ID_RE = re.compile(r"TC-P\d+-\d+")
_ROW_ID_RE = re.compile(r"<nobr><code>(TC-P\d+-\d+)</code></nobr>")
_CELL_RE = re.compile(r"`([^`]*)`")
_TYPE_TOKEN_RE = re.compile(r"^(SITE|AUTO_PLC|AUTO)(\+(SITE|AUTO_PLC|AUTO))*$")
_TEST_TITLE_RE = re.compile(r"TEST\s+'([^']*)'")
_TEST_ID_RE = re.compile(r"TC-P(\d+)-(\d+(?:/\d+)*)")


def parse_af_catalog(af_text: str) -> list:
    """Retourne [(id, type_str, intention), ...] pour chaque ligne de tableau markdown
    contenant un ID TC-Pxx-nnn. type_str = cellule contenant SITE/AUTO/AUTO_PLC (vide si non
    trouvee -- ligne alors ignoree par l'appelant plutot que de deviner)."""
    rows = []
    for line in af_text.splitlines():
        m = _ROW_ID_RE.search(line)
        if not m:
            continue
        tc_id = m.group(1)
        type_str = ""
        for cell in _CELL_RE.findall(line):
            stripped = re.sub(r"^[^A-Za-z]+", "", cell.strip())
            if _TYPE_TOKEN_RE.match(stripped):
                type_str = stripped
                break
        cells = [c.strip(" `") for c in line.split("|")]
        intention = cells[2] if len(cells) > 2 else ""
        rows.append((tc_id, type_str, intention))
    return rows


def extract_test_ids(test_st_text: str) -> set:
    """Retourne l'ensemble des ID TC-Pxx-nnn references dans les titres TEST du .st -- gere le
    format combine 'TC-P01-004/009' (une meme fonction TEST peut prouver 2 ID du catalogue)."""
    ids = set()
    for title in _TEST_TITLE_RE.findall(test_st_text):
        for prefix, nums in _TEST_ID_RE.findall(title):
            for n in nums.split("/"):
                ids.add(f"TC-P{prefix}-{n}")
    return ids


def check_af_coverage(af_doc_path, test_st_path) -> list:
    """Retourne [(id, intention), ...] pour chaque ID de type AUTO/AUTO_PLC/SITE+AUTO du
    catalogue AF absent des tests. Jamais d'exception : AF/doc illisible -> liste vide (le
    coverage-check est un bonus, pas une dependance dure du pipeline)."""
    try:
        af_text = af_doc_path.read_text(encoding="utf-8")
        test_text = test_st_path.read_text(encoding="utf-8")
    except OSError:
        return []

    catalog = parse_af_catalog(af_text)
    tested_ids = extract_test_ids(test_text)

    missing = []
    for tc_id, type_str, intention in catalog:
        if "AUTO" in type_str and tc_id not in tested_ids:
            missing.append((tc_id, intention))
    return missing
