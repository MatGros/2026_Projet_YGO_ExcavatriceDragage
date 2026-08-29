#!/usr/bin/env python3
"""Coherence catalogue AF <-> tests, conforme au standard HTML-rigide (v2).

Meme contrat que `af_coverage.py` (meme interface : `parse_af_catalog`, `extract_test_ids`,
`check_af_coverage`, `check_extra_tests`) -- cette v2 corrige le parsing des tables catalogue
écrites en HTML rigide `<span style="writing-mode: vertical-rl; ...">` (GUIDE_EDITION_AF §2).

Pourquoi une v2 (bug 2026-08-29) :
  - L'ancien parseur (`af_coverage.py`) ne lisait que `<nobr><code>TC-Pxx-nnn</code></nobr>`,
    format qui n'existe plus QUE dans du texte courant (historique/TBD). Les vraies tables
    catalogue TC sont désormais toutes en `<span>` vertical (213 occurrences dans DOC/AF).
  - Bilan : le catalogue lu était vide -> `check_extra_tests` déclarait "absent du catalogue AF"
    des TC pourtant documentés (faux WARN, ex. FB_Safety_EmergencyManagement TC-P01-001..010).

Correctifs apportés par la v2 :
  1. `_ROW_ID_RE` : reconnaît la signature `<span ... writing-mode vertical-rl ...>` de la
     colonne ID d'un tableau catalogue (fiable, zéro faux positif car ce span vertical
     n'apparaît nulle part en prose) + garde `<nobr><code>` en rétro-compat (tables markdown).
  2. `parse_af_catalog` : 2 passes -- blocs `<tr>...</tr>` (HTML, une cellule par ligne) puis
     lignes markdown `| ... |` (blocs `<tr>` masqués pour éviter tout double comptage).
  3. Type lu aussi en `<code>💻 AUTO</code>` (HTML) ; intention/état extraits des `<td>`.
  4. `extract_test_ids` : suffixes d'ID symétriques du catalogue (001, 004/009, SCEN-NOM/DYN,
     014.1, TSV-01).

Non bloquant par design (retourne une liste, jamais d'exception) : un WARN "TC attendu/absent"
n'empeche jamais le pipeline de passer -- seul G200/le contenu des tests fait foi.
"""

import re

_ID_RE = re.compile(r"TC-P\d+-\d+")
# Deux balisages coexistent dans les docs AF :
#   - `<span style="writing-mode: vertical-rl; ...">TC-Pxx-nnn</span>` : format STANDARD des
#     tables catalogue "Points de validation" (GUIDE_EDITION_AF §2, HTML rigide). Signature
#     exclusive de la colonne ID d'un tableau catalogue (jamais en prose).
#   - `<nobr><code>TC-Pxx-nnn</code></nobr>` : conservation rétro-compatible (tables markdown).
_ROW_ID_RE = re.compile(
    r"<nobr><code>(TC-P\d+-\d+)</code></nobr>"
    r"|<span[^>]*writing-mode:\s*vertical-rl[^>]*>(TC-P\d+-[^<\s]+)</span>"
)
_CELL_RE = re.compile(r"`([^`]*)`")
# Type en cellule HTML (`<small><code>💻 AUTO</code></small>`) en plus du backtick markdown.
_HTML_CODE_RE = re.compile(r"<code>([^<]*?)</code>")
_TYPE_TOKEN_RE = re.compile(r"^(SITE|AUTO_PLC|AUTO)(\+(SITE|AUTO_PLC|AUTO))*$")
_TEST_TITLE_RE = re.compile(r"TEST\s+'([^']*)'")
# Un ID TC dans un titre de TEST : suffixe numérique (001), groupe (004/009), scénario nommé
# (SCEN-NOM/DYN), sous-cas (014.1) ou code métier (TSV-01). Parsing symétrique du catalogue.
_TEST_ID_RE = re.compile(r"TC-P(\d+)-([A-Za-z0-9\.\-\/]+)")
_ETAT_VALUES = {"V", "V-I", "NV", "NV-I", "R", "NA"}
_COVERAGE_REQUIRED_STATES = {"V", "V-I"}


def _strip_tags(text: str) -> str:
    """Retire les balises HTML d'une cellule et normalise les espaces (les `<br>` deviennent
    des espaces pour préserver la lecture d'une intention multi-ligne)."""
    text = re.sub(r"<br\s*/?>", " ", text)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def _type_from(text: str) -> str:
    """Extrait le jeton de type (SITE/AUTO/AUTO_PLC, éventuellement A+B) d'une cellule de
    tableau, qu'elle soit en backtick markdown (`` `💻 AUTO` ``) ou en HTML (``<code>...``)."""
    for cell in _CELL_RE.findall(text) + _HTML_CODE_RE.findall(text):
        stripped = re.sub(r"^[^A-Za-z]+", "", cell.strip())
        if _TYPE_TOKEN_RE.match(stripped):
            return stripped
    return ""


def parse_af_catalog(af_text: str) -> list:
    """Retourne [(id, type_str, intention, etat), ...] pour chaque entrée du catalogue de tests
    d'une AF. Sait lire les tables catalogue en HTML rigide (bloc `<tr>...</tr>`, une cellule
    par ligne) ET en Markdown (`| ... |`, une ligne = une entrée)."""
    rows: list = []

    # Passe 1 : tables HTML rigides (chaque `<tr>...</tr>` porte une entrée, multi-lignes).
    for tr in re.finditer(r"<tr(?:\s[^>]*)?>(.*?)</tr>", af_text, re.S):
        block = tr.group(1)
        m = _ROW_ID_RE.search(block)
        if not m:
            continue
        tc_id = m.group(1) or m.group(2)
        cells_html = [
            _strip_tags(c) for c in re.findall(r"<td[^>]*>(.*?)</td>", block, re.S)
        ]
        type_str = _type_from(block)
        intention = cells_html[1] if len(cells_html) > 1 else ""
        etat = next((c for c in reversed(cells_html) if c in _ETAT_VALUES), "")
        rows.append((tc_id, type_str, intention, etat))

    # Passe 2 : tables Markdown ; on masque d'abord les blocs `<tr>` pour ne pas re-lire les
    # cellules `<td>` HTML déjà vues en passe 1 (évite tout double comptage).
    masked = re.sub(r"<tr(?:\s[^>]*)?>.*?</tr>", "\n", af_text, flags=re.S)
    for line in masked.splitlines():
        m = _ROW_ID_RE.search(line)
        if not m:
            continue
        cells = [c.strip(" `") for c in line.split("|")]
        if len(cells) < 3:
            continue
        tc_id = m.group(1) or m.group(2)
        type_str = _type_from(line)
        intention = cells[2] if len(cells) > 2 else ""
        etat = next((cell for cell in reversed(cells) if cell in _ETAT_VALUES), "")
        rows.append((tc_id, type_str, intention, etat))

    return rows


def extract_test_ids(test_st_text: str) -> set:
    """Retourne l'ensemble des ID TC-Pxx-nnn references dans les titres TEST du .st. Un ID peut
    etre numerique simple (001), un groupe (004/009 -- une meme fonction TEST prouve alors 2 ID),
    un scenario nomme (SCEN-NOM/DYN), un sous-cas (.1) ou un code metier (TSV-01)."""
    ids = set()
    for title in _TEST_TITLE_RE.findall(test_st_text):
        for prefix, suffix in _TEST_ID_RE.findall(title):
            suffix = suffix.rstrip(".,;:()")
            if re.fullmatch(r"\d+(?:/\d+)+", suffix):
                ids.update(f"TC-P{prefix}-{s}" for s in suffix.split("/"))
            else:
                ids.add(f"TC-P{prefix}-{suffix}")
    return ids


def check_af_coverage(af_doc_path, test_st_path, ignore=None) -> list:
    """Retourne [(id, intention), ...] pour chaque ID de type AUTO/AUTO_PLC/SITE+AUTO du
    catalogue AF absent des tests. Jamais d'exception : AF/doc illisible -> liste vide (le
    coverage-check est un bonus, pas une dependance dure du pipeline).

    `ignore` : ID explicitement hors perimetre de CE fichier de test (ex: un point de
    validation qui teste en realite la reaction d'un AUTRE FB consommateur -- responsabilite
    unique, cf. registry.yaml). Toujours une decision humaine explicite et documentee (raison
    en commentaire dans registry.yaml), jamais une omission silencieuse : l'ID reste visible
    dans le catalogue AF, seul le WARN de CE FB est supprime."""
    try:
        af_text = af_doc_path.read_text(encoding="utf-8")
        test_text = test_st_path.read_text(encoding="utf-8")
    except OSError:
        return []

    ignore = set(ignore or [])
    catalog = parse_af_catalog(af_text)
    tested_ids = extract_test_ids(test_text)

    missing = []
    for tc_id, type_str, intention, etat in catalog:
        # Absence de colonne Etat : comportement historique conservé.
        if etat and etat not in _COVERAGE_REQUIRED_STATES:
            continue
        if "AUTO" in type_str and tc_id not in tested_ids and tc_id not in ignore:
            missing.append((tc_id, intention))
    return missing


def check_extra_tests(af_doc_path, test_st_path) -> list:
    """Sens inverse de check_af_coverage : retourne les ID references par des TEST du .st mais
    absents du catalogue AF (n'importe quel type, y compris SITE) -- on teste quelque chose qui
    n'est plus (ou jamais ete) documente dans l'AF comme point de validation. Meme garantie
    non-bloquante/jamais-d-exception que check_af_coverage."""
    try:
        af_text = af_doc_path.read_text(encoding="utf-8")
        test_text = test_st_path.read_text(encoding="utf-8")
    except OSError:
        return []

    catalog_ids = {tc_id for tc_id, _type, _intent, _etat in parse_af_catalog(af_text)}
    tested_ids = extract_test_ids(test_text)

    # Les tests transverses de contrat AF03 (TC-P03-*) sont universels et légitimes sur tout composant
    return sorted(tc_id for tc_id in tested_ids if tc_id not in catalog_ids and not tc_id.startswith("TC-P03-"))
