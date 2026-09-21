#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T353 — Parseur des cartographies de diagnostic (lot C2, outil de LECTURE seule).

Lit les 3 documents source (LECTURE SEULE ABSOLUE) :
  - DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md
  - DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md
  - DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md

Produit le format pivot JSON consomme par le front-end :
  data/graph.json  (canonique, lisible)
  data/graph.js    (meme contenu, embarque en global -> fonctionne en file:// sans aucune requete)

Principes NON NEGOCIABLES appliques par ce parseur :
  1. Seuls les tableaux de chaine a 5 colonnes (`| # | Variable | Producteur fichier:ligne |
     Consommateur fichier:ligne | Role |`) alimentent le graphe. Les tableaux d'AUDIT a 4 colonnes
     de l'annexe (§2.1/§2.2) sont DETECTES et REJETES explicitement (jamais injectes).
  2. Un code Mnn/Cnn n'a de sens qu'avec son DOCUMENT : chaque maillon porte `document`.
  3. Aucune reference n'est devinee : resolution par index construit sur `git ls-files`,
     scope sur la source active (CODE/** hors CODE_BACKUP), + chemins declares par les blocs
     d'ancrage, + DOC/** hors ARCHIVES. Hors de ces perimetres -> AMBIGU ou NON_RESOLUE, jamais
     tranche par supposition.
  4. La fraicheur des references M3 (T334) s'ancre sur la table de blobs du §1.3 de l'ANNEXE :
     cet ancrage est etiquete DERIVE, jamais presente comme un ancrage de T334 (qui n'en a aucun).

Sortie : ecrit uniquement sous TOOLS/CMD_PATH_VIEWER/data/ + rapport sur stdout.
Aucun fichier de CODE/ n'est lu en ecriture ; aucun CODE/ n'est modifie.
"""

from __future__ import annotations

import datetime as _dt
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

ICI = Path(__file__).resolve().parent
RACINE = ICI.parents[1]
DATA = ICI / "data"

DOCS = {
    "treuils": "DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md",
    "t334": "DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md",
    "annexe": "DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md",
}

DOC_TITRES = {
    "treuils": "T351 — Treuils M1/M2 : du geste joystick au contacteur",
    "t334": "T334 — Translation M3 : deux chemins (MANUEL / CYCLE)",
    "annexe": "T351 annexe — audit M3 des trous de T334",
}

# ── 8e constat de cadrage : perimetres d'index (exclusions obligatoires) ─────────────────────
PREFIXES_EXCLUS = ("CODE_BACKUP/", "ARCHIVES/", "TOOLS/TEST_AUTO_CI/", ".git/")
TIERS_FIXES = (
    ("SOURCE_ACTIVE_CODE", "CODE/"),
    ("DOC_ACTIF", "DOC/"),
)
# Tier intermediaire : chemins EXPLICITEMENT declares par les blocs d'ancrage des documents
# (c'est la source de verite des chemins, ex. TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv).
TIER_ANC = "ANCRAGE_DECLARE"
# Dernier tier : fichiers PRESENTS sur le disque mais NON SUIVIS par Git. Les 3 documents source
# eux-memes sont dans ce cas. Ils sont resolus (le fichier existe, c'est verifiable) mais le tier
# est TRACE, et ils restent NON_ANCRABLE cote fraicheur tant qu'aucun blob n'est consigne.
TIER_NON_SUIVI = "PRESENT_NON_SUIVI"

# ── Ancrages declares (source de verite des chemins + blobs) ─────────────────────────────────
ANCRAGE_DECLARE = {
    "treuils": {
        "id": "BLOC_ANCRAGE_REVISION_T351",
        "etiquette": "PROPRE",
        "libelle": "§1 — Bloc d'ancrage de révision (AC2) de la fiche treuils",
        "head_ligne": 52,
        "head_motif": "HEAD",
        "tables": ["Fichier cité+blob"],
    },
    "annexe": {
        "id": "ANNEXE_1_3",
        "etiquette": "DERIVE",
        "libelle": "§1.3 — table de blobs de l'ANNEXE (T334 n'a AUCUN bloc d'ancrage)",
        "tables": ["Fichier+Blob disque"],
    },
}

RE_ISO = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:[+-]\d{2}:\d{2})?")
RE_HMS = re.compile(r"\b(\d{2}:\d{2}:\d{2})\b")
RE_SHA1 = re.compile(r"\b([0-9a-f]{40})\b")
RE_CODE = re.compile(r"^\s*([MC]\d{2})\s*$")
RE_LIGNE_CHAINE = re.compile(r"^\s*\|\s*([MC])(\d{2})\s*\|")

# ── References fichier:ligne (les 4 formes exigees par AC2) ──────────────────────────────────
RE_REF_PATH = re.compile(r"(?<![\w./\\-])((?:[\w.\-]+/)+[\w.\-]+\.[A-Za-z][A-Za-z0-9]{0,5}):(\d[\d,\-]*)")
RE_REF_BASENAME = re.compile(r"(?<![\w./\\-])([A-Za-z][\w.\-]*\.[A-Za-z][A-Za-z0-9]{0,5}):(\d[\d,\-]*)")
RE_REF_TOKEN = re.compile(r"(?<![\w./\\-])([A-Za-z][A-Za-z0-9_]{1,48}):(\d[\d,\-]*)")
RE_REF_COURTE = re.compile(r"(?<![\w./:\-])(?<![A-Za-z0-9]):(\d[\d,\-]*)")
RE_ALIAS = re.compile(r"^[MC]\d{1,2}$")
RE_ALIAS_AVANT = re.compile(r"(?:^|[\s(«'`])([MC][123])\s*`?\s*$")
# Mots qui DESIGNENT un autre objet que le fichier nommé avant : interdiction d'heriter.
RE_MOT_DESIGNATION = re.compile(r"\b(arbitres?|d[ée]codeur|barri[èe]re)\b", re.I)


def mot_designation(inter: str) -> str | None:
    """
    Detecte un mot qui DESIGNERAIT un autre objet que le fichier herite (ex. « → décodeur `:73-74` »).
    Les annotations entre parentheses sont neutralisees (« :455 (safety) » annote la reference
    PRECEDENTE, il ne designe pas la suivante) ; les alias M1/M2 et les nombres aussi.
    Seul le DERNIER mot restant est examine : c'est celui qui precede immediatement la reference.
    """
    t = re.sub(r"\([^()]*\)", " ", inter)
    t = re.sub(r"`", " ", t)
    t = re.sub(r"[:;,\-–—→/|()\[\].]", " ", t)
    t = re.sub(r"\b[MC][123]\b", " ", t)
    t = re.sub(r"\d+", " ", t)
    mots = re.findall(r"[A-Za-zÀ-ÿ_]{3,}", t)
    if not mots:
        return None
    dernier = mots[-1]
    return dernier if RE_MOT_DESIGNATION.match(dernier) else None

# ── Alias de contexte DOCUMENTES : le document nomme lui-meme la cible de l'alias ────────────
# Chaque entree porte une preuve (document + ligne + motif) VERIFIEE mecaniquement au parsing.
# Si la preuve echoue (document modifie), l'alias n'est PAS utilise : la reference redevient
# AMBIGUE et un ecart est signale. Aucun alias n'est jamais devine.
ALIAS_DOCUMENTES = [
    {"alias": "M1", "document": "treuils", "cible": "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st",
     "libelle": "« arbitre M1 » — FB d'arbitrage de commande du treuil M1",
     "preuve": {"document": "treuils", "ligne": 21, "motif_attendu": "FB_WinchCmdArbitrationM1"}},
    {"alias": "M2", "document": "treuils", "cible": "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st",
     "libelle": "« arbitre M2 » — FB d'arbitrage de commande du treuil M2",
     "preuve": {"document": "treuils", "ligne": 28, "motif_attendu": "FB_WinchCmdArbitrationM2.st"}},
    {"alias": "M3", "document": "t334", "cible": "CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st",
     "libelle": "« arbitre M3 » — FB d'arbitrage de commande de la translation M3",
     "preuve": {"document": "t334", "ligne": 64, "motif_attendu": "FB_TranslationCmdArbitrationM3.st"}},
]

MOTIFS = (
    "⚠️ASYM", "⚠️", "🔴", "🟠", "🟡", "🟢", "✅", "❌", "NON VERIFIABLE", "NON SÉPARABLE",
)

# ── 9e constat : la 4e forme de reference (ABREVIATION) et ses faux positifs ────────────────
# Un token `T01` precede d'une date ISO (`2026-09-21T01:31:44`) n'est PAS un nom de fichier.
# ⚠️ Ne PAS exclure `M1`/`M2` : ce sont des alias de contexte, traites par la table curee.
RE_TOKEN_NON_FICHIER = re.compile(r"^(?:[Tt]\d{1,4}|\d+[A-Za-z]{1,3}|[A-Za-z]{1,2}\d{1,4}[A-Za-z]{2,})$")
# Troncature de prose : `M2.st` = un alias suivi d'une extension (defaut de redaction, pas un fichier).
RE_TRONCATURE = re.compile(r"^([A-Za-z][A-Za-z0-9]*)\.(st|csv|md)$")
# Libelle normalise de la regle de resolution (`resolved_by` demande par le 9e constat).
RESOLVED_BY = {
    "A_CHEMIN_EXACT": "chemin_exact",
    "B_CHEMIN_DECLARE_ANC": "chemin_declare_ancrage",
    "E_ALIAS_DOCUMENTE_CITE": "alias_documente_cure",
    "C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE": "basename_unique",
    "C_BASENAME_UNIQUE_ANCRAGE_DECLARE": "basename_unique_chemin_declare",
    "C_BASENAME_UNIQUE_DOC_ACTIF": "basename_unique_doc",
    "D_STEM_UNIQUE_SOURCE_ACTIVE_CODE": "prefix_unique",
    "D_STEM_UNIQUE_ANCRAGE_DECLARE": "prefix_unique_chemin_declare",
    "D_STEM_UNIQUE_DOC_ACTIF": "prefix_unique_doc",
    "D_STEM_UNIQUE_PRESENT_NON_SUIVI": "prefix_unique_non_suivi",
    "C_BASENAME_UNIQUE_PRESENT_NON_SUIVI": "basename_unique_non_suivi",
    "D_STEM_MULTIPLE_SOURCE_ACTIVE_CODE": "prefix_ambigu",
    "D_STEM_INTROUVABLE": "prefix_sans_match",
    "C_BASENAME_INTROUVABLE": "nom_sans_match",
    "C_BASENAME_MULTIPLE_SOURCE_ACTIVE_CODE": "nom_ambigu",
    "C_BASENAME_HORS_TIERS": "nom_hors_index_actif",
    "A_CHEMIN_INTROUVABLE": "chemin_introuvable",
    "A_CHEMIN_HORS_INDEX_ACTIF": "chemin_hors_index_actif",
    "ALIAS_CONTEXTE_Mnn_Cnn": "alias_non_documente",
    "ALIAS_CONTEXTE_Mnn_Cnn_NON_DOCUMENTE": "alias_non_documente",
    "ALIAS_CONTEXTE_CANDIDATS_DOCUMENTES_HORS_DOCUMENT": "alias_candidats_documentes",
    "ALIAS_NON_DETERMINABLE_SANS_SECTION": "alias_non_determinable",
    "CONTINUATION_SANS_ANTECEDENT_CELLULE": "continuation_sans_antecedent",
    "HERITAGE_REFUSE_MOT_DESIGNATION": "heritage_refuse_mot_designation",
    "HERITAGE_REFUSE_HORS_BORNES": "contestee_hors_bornes",
    "TRONCATURE_PROSE": "troncature_prose",
    "DESIGNATION_PLURIELLE_AMBIGUE": "designation_plurielle_ambigue",
    "LIGNE_HORS_FICHIER_EXPLICITE": "contestee_ligne_hors_fichier",
    "E_CONTINUATION_HORS_BORNES_REROUTAGE": "continuation_reroutee_ligne",
    "E_CONTINUATION_HORS_BORNES_AUTRE_FICHIER_CELLULE": "continuation_reroutee_ligne",
}


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Utilitaires
# ═══════════════════════════════════════════════════════════════════════════════════════════

def sans_accents(txt: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", txt) if unicodedata.category(c) != "Mn")


def norm_header(cell: str) -> str:
    """Normalise une cellule d'en-tete : minuscules, sans accents, sans markdown."""
    t = sans_accents(cell).lower()
    t = t.replace("*", "").replace("`", "").replace("’", "'")
    t = re.sub(r"\s+", " ", t).strip()
    return t


def norm_texte(txt: str) -> str:
    """Normalise un texte pour comparaison de motif (apostrophes typographiques, espaces fines)."""
    t = txt.replace("\u2019", "'").replace("\u00a0", " ").replace("\u202f", " ")
    return re.sub(r"\s+", " ", t).strip()


def split_row(ligne: str) -> list[str]:
    """
    Decoupe une ligne de tableau Markdown en cellules, en respectant les backticks :
    un `|` situe ENTRE deux backticks est un caractere litteral, pas un separateur
    (cas reel : la cellule de role de T334 M57 contient `|fAct| > 0,5 Hz`).
    """
    s = ligne.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    cellules, buf, dans_code = [], [], False
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s) and s[i + 1] == "|":
            buf.append("|")
            i += 2
            continue
        if c == "`":
            dans_code = not dans_code
            buf.append(c)
        elif c == "|" and not dans_code:
            cellules.append("".join(buf).strip())
            buf = []
        else:
            buf.append(c)
        i += 1
    cellules.append("".join(buf).strip())
    return cellules


RE_SEPARATEUR = re.compile(r"^\s*\|[\s:\-|]+\|\s*$")


def iter_tables(lignes: list[str], fences: list[bool]):
    """Itere les tableaux Markdown en conservant l'etat de fence de chaque ligne."""
    i = 0
    while i < len(lignes) - 1:
        if fences[i]:
            i += 1
            continue
        if lignes[i].lstrip().startswith("|") and RE_SEPARATEUR.match(lignes[i + 1]):
            header = split_row(lignes[i])
            rows = []
            j = i + 2
            while j < len(lignes) and lignes[j].lstrip().startswith("|"):
                rows.append({"ligne": j + 1, "cellules": split_row(lignes[j])})
                j += 1
            yield {"header_ligne": i + 1, "header": header, "rows": rows}
            i = j
        else:
            i += 1


def marqueurs_de(cellules: list[str]) -> list[str]:
    trouves = []
    for c in cellules:
        for m in MOTIFS:
            if m in c:
                trouves.append(m)
    return sorted(set(trouves))


def nettoyer_code(txt: str) -> str:
    """Retire le markdown d'une cellule pour l'affichage."""
    t = txt.replace("**", "").replace("`", "")
    return re.sub(r"\s+", " ", t).strip()


def variable_principale(txt: str) -> str:
    """Extrait le premier identifiant en code inline (nom exact de variable)."""
    m = re.findall(r"`([^`]+)`", txt)
    for cand in m:
        c = cand.strip()
        if not c or "/" in c and "." not in c:
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_.\[\]]*$", c):
            return c
    return nettoyer_code(txt)[:80]


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Index de resolution (git ls-files, scope sur la source active)
# ═══════════════════════════════════════════════════════════════════════════════════════════

class Index:
    def __init__(self, racine: Path, chemins_declares: set[str] | None = None):
        self.racine = racine
        self.tous = self._ls_files()
        # fichiers PRESENTS mais NON SUIVIS (les 3 documents source eux-memes sont dans ce cas) :
        # indexables, mais dans un tier TRACE et de plus basse priorite.
        self.non_suivis = self._ls_others()
        self.indexables = self.tous + self.non_suivis
        self.par_chemin = {p.lower(): p for p in self.indexables}
        self.par_basename: dict[str, list[str]] = {}
        for p in self.indexables:
            self.par_basename.setdefault(Path(p).name.lower(), []).append(p)
        # index par tier (source active) ; l'ordre des tiers est l'ordre de resolution
        declares = {p.replace("\\", "/") for p in (chemins_declares or set())}
        declares = {self.par_chemin[p.lower()] for p in declares if p.lower() in self.par_chemin}
        self.chemins_declares = declares
        groupes: dict[str, list[str]] = {nom: [p for p in self.tous if p.startswith(pref)] for nom, pref in TIERS_FIXES}
        groupes[TIER_ANC] = sorted(declares)
        groupes[TIER_NON_SUIVI] = sorted(p for p in self.non_suivis if not p.startswith(PREFIXES_EXCLUS))
        self.tiers = [("SOURCE_ACTIVE_CODE", None), (TIER_ANC, None), ("DOC_ACTIF", None),
                      (TIER_NON_SUIVI, None)]
        self.tier_de: dict[str, str] = {}
        self.stems_tier: dict[str, dict[str, list[str]]] = {}
        for nom_tier, _ in self.tiers:
            fichiers = groupes[nom_tier]
            self.stems_tier[nom_tier] = {}
            for p in fichiers:
                if p in self.tier_de:
                    continue          # le tier le plus prioritaire gagne (trace dans tier_de)
                self.tier_de[p] = nom_tier
                stem = Path(p).stem.lower()
                self.stems_tier[nom_tier].setdefault(stem, []).append(p)
        self.exclus = [p for p in self.tous if p.startswith(PREFIXES_EXCLUS)]

    def _ls_files(self) -> list[str]:
        out = subprocess.run(
            ["git", "-c", "core.quotepath=false", "ls-files"],
            cwd=str(self.racine), capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if out.returncode != 0:
            raise SystemExit("ERREUR : `git ls-files` a echoue — l'index de resolution est obligatoire.")
        return [l.strip().replace("\\", "/") for l in out.stdout.splitlines() if l.strip()]

    def _ls_others(self) -> list[str]:
        """Fichiers presents sur le disque et NON SUIVIS par Git (hors ignorés)."""
        out = subprocess.run(
            ["git", "-c", "core.quotepath=false", "ls-files", "--others", "--exclude-standard"],
            cwd=str(self.racine), capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if out.returncode != 0:
            return []
        return [l.strip().replace("\\", "/") for l in out.stdout.splitlines() if l.strip()]

    def lignes_de(self, chemin: str) -> int | None:
        p = self.racine / chemin
        try:
            with open(p, "rb") as f:
                return f.read().count(b"\n")
        except OSError:
            return None

    # -- resolution d'un token fichier ------------------------------------------------------
    def resoudre(self, token: str) -> dict:
        """
        Ordre de resolution TRACE (8e constat) :
          (a) chemin complet fourni -> utilise verbatim s'il existe dans l'index
          (b) nom declare dans un bloc d'ancrage -> chemin declare
          (c) nom unique dans CODE/** -> resolu
          (d) nom unique dans le tier des chemins declares par ancrage
          (e) nom unique dans DOC/** -> resolu (references documentaires)
          (f) sinon AMBIGU (plusieurs candidats) ou NON_RESOLUE (aucun)
        """
        tok = token.replace("\\", "/").strip()
        tok_l = tok.lower()
        avec_chemin = "/" in tok
        res = {
            "token": token, "avec_chemin": avec_chemin,
            "categorie": None, "chemin": None, "regle": None, "candidats": [], "tier": None,
        }
        # (a) chemin complet verbatim
        if avec_chemin:
            if tok_l in self.par_chemin:
                res.update(categorie="RESOLUE", chemin=self.par_chemin[tok_l], regle="A_CHEMIN_EXACT",
                           tier=self.tier_de.get(self.par_chemin[tok_l], "HORS_TIER"))
                return res
            cands = [p for p in self.tous if p.lower().endswith(tok_l)]
            if cands:
                res.update(categorie="AMBIGUE", regle="A_CHEMIN_HORS_INDEX_ACTIF", candidats=sorted(cands))
            else:
                res.update(categorie="NON_RESOLUE", regle="A_CHEMIN_INTROUVABLE")
            return res
        # (b) declare dans un bloc d'ancrage
        if tok_l in self.par_chemin:
            res.update(categorie="RESOLUE", chemin=self.par_chemin[tok_l], regle="B_CHEMIN_DECLARE_ANC",
                       tier=self.tier_de.get(self.par_chemin[tok_l], "HORS_TIER"))
            return res
        if "." in Path(tok).name:
            # nom de fichier avec extension : unicite par basename, tier par tier
            cands = self.par_basename.get(Path(tok).name.lower(), [])
            cands_actifs = [p for p in cands if not p.startswith(PREFIXES_EXCLUS)]
            for nom_tier, _ in self.tiers:
                uniq = [p for p in cands_actifs if self.tier_de.get(p) == nom_tier]
                if len(uniq) == 1:
                    res.update(categorie="RESOLUE", chemin=uniq[0], regle="C_BASENAME_UNIQUE_" + nom_tier,
                               tier=nom_tier, candidats=cands)
                    return res
                if len(uniq) > 1:
                    res.update(categorie="AMBIGUE", regle="C_BASENAME_MULTIPLE_" + nom_tier,
                               candidats=sorted(uniq))
                    return res
            if cands:
                res.update(categorie="AMBIGUE", regle="C_BASENAME_HORS_TIERS", candidats=sorted(cands))
            else:
                res.update(categorie="NON_RESOLUE", regle="C_BASENAME_INTROUVABLE")
            return res
        # nom nu sans extension
        if RE_ALIAS.match(tok):
            res.update(categorie="AMBIGUE", regle="ALIAS_CONTEXTE_Mnn_Cnn",
                       candidats=[], note=("alias de contexte (M1/M2/M3) : la cible depend du document "
                                           "et de la section — un code n'a de sens qu'avec son document"))
            return res
        for nom_tier, _ in self.tiers:
            cands = []
            for stem, chemins in self.stems_tier[nom_tier].items():
                if stem == tok_l or stem.startswith(tok_l + "_") or stem.startswith(tok_l + "-"):
                    cands.extend(chemins)
            cands = sorted(set(cands))
            if len(cands) == 1:
                res.update(categorie="RESOLUE", chemin=cands[0], regle="D_STEM_UNIQUE_" + nom_tier, tier=nom_tier)
                return res
            if len(cands) > 1:
                res.update(categorie="AMBIGUE", regle="D_STEM_MULTIPLE_" + nom_tier, candidats=cands)
                return res
        res.update(categorie="NON_RESOLUE", regle="D_STEM_INTROUVABLE")
        return res


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Extraction des references d'une cellule (avec propagation des continuations)
# ═══════════════════════════════════════════════════════════════════════════════════════════

def charger_alias() -> tuple[dict, list[dict]]:
    """Verifie mecaniquement les preuves des alias documentes. Un alias non prouve est desactive."""
    actifs, ecarts = {}, []
    for a in ALIAS_DOCUMENTES:
        p = a["preuve"]
        lg = (RACINE / DOCS[p["document"]]).read_text(encoding="utf-8").splitlines()
        ok = 1 <= p["ligne"] <= len(lg) and norm_texte(p["motif_attendu"]) in norm_texte(lg[p["ligne"] - 1])
        entree = dict(a, citation_verifiee=ok,
                      citation_extrait=(lg[p["ligne"] - 1][:200] if 1 <= p["ligne"] <= len(lg) else ""))
        if ok:
            actifs[(a["document"], a["alias"])] = entree
        else:
            ecarts.append({"id": "ALIAS_NON_Prouve", "alias": a["alias"], "document": a["document"],
                           "ligne": p["ligne"], "motif": "citation d'alias non verifiee — alias desactive"})
    return actifs, ecarts


def _scinder_hors_bornes(ref: dict, idx: Index) -> list[dict]:
    """
    INVARIANT : une référence `RESOLUE` ne peut pas porter une ligne hors des bornes du fichier.
    Quand une LISTE de lignes (`:431-432,650`) mélange des numéros valides et un numéro impossible,
    elle est SCINDÉE : la partie valide reste `RESOLUE`, le numéro impossible devient une référence
    `CONTESTEE_HORS_BORNES` distincte (trouvaille de diagnostic, jamais affichée comme résolue).
    """
    hors = ref.get("lignes_hors_bornes") or []
    if ref.get("categorie") != "RESOLUE" or not hors:
        return []
    dedans = [l for l in ref["lignes"] if l not in hors]
    chemin = ref.get("chemin_resolu")
    motif = ("ligne(s) %s citée(s) pour `%s` : ce fichier n'a que %s lignes — le couple "
             "(fichier, ligne) est IMPOSSIBLE. La fiche désigne probablement un AUTRE fichier "
             "(constat de rédaction, à re-vérifier par l'auteur de la fiche)"
             % (hors, Path(chemin or "").name, idx.lignes_de(chemin or "")))
    if not dedans:
        ref.update({"categorie": "CONTESTEE_HORS_BORNES", "regle": "LIGNE_HORS_FICHIER_EXPLICITE",
                    "resolved_by": "contestee_ligne_hors_fichier",
                    "chemin_resolu_ecarte": chemin, "chemin_resolu": None,
                    "candidats": [], "motif": motif})
        return []
    conteste = dict(ref)
    conteste.update({"categorie": "CONTESTEE_HORS_BORNES", "regle": "LIGNE_HORS_FICHIER_EXPLICITE",
                     "resolved_by": "contestee_ligne_hors_fichier", "lignes": hors,
                     "lignes_hors_bornes": hors, "chemin_resolu": None,
                     "chemin_resolu_ecarte": chemin, "candidats": [], "note": None, "motif": motif})
    ref["lignes"] = dedans
    ref["lignes_hors_bornes"] = []      # les lignes impossibles sont portees par la references CONTESTEE
    ref["note"] = ("scission : ligne(s) %s retirée(s) de cette référence (hors fichier) et isolée(s) "
                   "en référence CONTESTÉE distincte" % hors)
    return [conteste]


def extraire_refs(cellule: str, idx: Index, doc: str, ligne_doc: int, champ: str,
                  alias_actifs: dict | None = None, contexte_ligne: str = "") -> list[dict]:
    """
    Extrait les references fichier:ligne d'une cellule.
    Regle de propagation DOCUMENTEE : une reference COURTE (`:NNN` sans nom de fichier) herite
    du DERNIER fichier nomme AVANT ELLE dans LA MEME CELLULE (jamais du dernier fichier de la
    cellule, jamais d'une autre cellule). Si la cellule ne nomme aucun fichier :
      - un alias de contexte (`arbitre M1 :93,98`) precede immediatement la reference -> il est
        utilise SI sa preuve documentaire est verifiee (regle E_ALIAS_DOCUMENTE_CITE) ;
      - sinon la reference reste NON_RESOLUE. Elle n'est JAMAIS rattachee au fichier d'une autre
        cellule : ce serait une supposition, et le contrat AC2 l'interdit explicitement.

    `contexte_ligne` : texte de la LIGNE DE TABLEAU complete, utilise UNIQUEMENT par la regle
    nommee E_CONTINUATION_HORS_BORNES_REROUTAGE quand l'heritage sort des bornes.
    """
    alias_actifs = alias_actifs or {}
    refs: list[dict] = []
    consomme: list[tuple[int, int]] = []
    tokens_pos: list[tuple[int, int, str]] = []

    def libre(a: int, b: int) -> bool:
        return all(b <= c or a >= d for c, d in consomme)

    for rx, forme in ((RE_REF_PATH, "CHEMIN_COMPLET"), (RE_REF_BASENAME, "ABREGE"), (RE_REF_TOKEN, "ABREGE")):
        for m in rx.finditer(cellule):
            if not libre(m.start(), m.end()):
                continue
            consomme.append((m.start(), m.end()))
            token, numeros = m.group(1), m.group(2)
            ref = _fabriquer_ref(token, numeros, forme, idx, doc, ligne_doc, champ, m.group(0),
                                 alias_actifs=alias_actifs)
            refs.append(ref)
            refs += _scinder_hors_bornes(ref, idx)
            tokens_pos.append((m.start(), m.end(), token))

    # Propagation des references COURTES (regle documentee, constat n°8) : une reference `:NNN`
    # herite du DERNIER FICHIER NOMME AVANT ELLE dans la meme cellule. Deux garde-fous mecaniques
    # empechent d'afficher un chemin FAUX avec assurance :
    #   (1) MOT_DE_DESIGNATION : si un mot designant un AUTRE objet (arbitre, decodeur, barriere…)
    #       s'intercale entre le fichier herite et la reference, l'heritage est refuse ;
    #   (2) BORNE : si la ligne heritee sort du fichier, l'heritage est faux par construction.
    def antecedent(position: int) -> tuple[str | None, str]:
        cands = [t for t in tokens_pos if t[1] <= position]
        if not cands:
            return None, ""
        t = max(cands, key=lambda x: x[0])
        return t[2], cellule[t[1]:position]

    for m in RE_REF_COURTE.finditer(cellule):
        if not libre(m.start(), m.end()):
            continue
        consomme.append((m.start(), m.end()))
        numeros = m.group(1)
        ant, inter = antecedent(m.start())
        design = mot_designation(inter) if ant is not None else None
        if ant is not None and design is not None:
            refs.append({
                "brut": ":" + numeros, "champ": champ, "ligne_document": ligne_doc,
                "forme": "CONTINUATION",
                "fichier_texte": None, "fichier_token": ant, "plages": numeros, "lignes": _lignes(numeros),
                "liste": "," in numeros, "categorie": "NON_RESOLUE", "chemin_resolu": None,
                "regle": "HERITAGE_REFUSE_MOT_DESIGNATION", "tier": None, "candidats": [],
                "note": None, "fiable": None, "alias_source": None, "lignes_hors_bornes": [],
                "resolved_by": "heritage_refuse_mot_designation",
                "antecedent_rejete": ant,
                "motif": ("le mot de désignation « %s » précède immédiatement la référence : elle désigne "
                          "un autre objet que `%s` — l'héritage afficherait un chemin FAUX avec assurance, "
                          "il est REFUSÉ" % (design, ant)),
            })
            continue
        if ant is not None:
            ref = _fabriquer_ref(ant, numeros, "CONTINUATION", idx, doc, ligne_doc, champ,
                                 ":" + numeros, fichier_explicite=False, alias_actifs=alias_actifs)
            ref["propagation"] = True
            if ref["categorie"] == "RESOLUE" and ref["lignes_hors_bornes"]:
                # INVARIANT : une reference RESOLUE ne peut pas sortir des bornes du fichier resolu.
                # Regle NOMMEE `E_CONTINUATION_HORS_BORNES_REROUTAGE` (jamais d'inference silencieuse) :
                #   etape 1 = autres fichiers cites dans la MEME CELLULE ;
                #   etape 2 = fichiers cites dans la MEME LIGNE DE TABLEAU ;
                #   reroutage accepte SEULEMENT si EXACTEMENT UN candidat contient toute la plage ;
                #   sinon -> CONTESTEE_HORS_BORNES avec la liste des candidats examines.
                rb_initial = ref.get("resolved_by")
                examines: dict[str, str] = {}
                for tok in sorted({t for _, _, t in tokens_pos if t != ant}):
                    examines[tok] = "meme_cellule"
                if contexte_ligne:
                    for rx in (RE_REF_PATH, RE_REF_BASENAME, RE_REF_TOKEN):
                        for m2 in rx.finditer(contexte_ligne):
                            tok = m2.group(1)
                            if tok != ant and tok not in examines:
                                examines[tok] = "meme_ligne_tableau"
                valides, candidats_vus = [], []
                for tok, origine in examines.items():
                    info_alias = alias_actifs.get((doc, tok))
                    chemin = info_alias["cible"] if info_alias else idx.resoudre(tok)["chemin"]
                    if not chemin:
                        continue
                    n2 = idx.lignes_de(chemin)
                    contient = bool(n2 is not None and all(1 <= l <= n2 for l in ref["lignes"]))
                    candidats_vus.append({"token": tok, "chemin": chemin, "lignes": n2,
                                          "origine": origine, "contient_la_plage": contient})
                    if contient:
                        valides.append(chemin)
                valides = sorted(set(valides))
                if len(valides) == 1:
                    ref.update({
                        "regle": "E_CONTINUATION_HORS_BORNES_REROUTAGE",
                        "resolved_by": "continuation_reroutee_ligne",
                        "chemin_resolu": valides[0], "categorie": "RESOLUE",
                        "fiable": "REROUTAGE_VERIFIABLE", "lignes_hors_bornes": [],
                        "antecedent_ecarte": ant, "candidats": candidats_vus,
                        "note": "héritage initial écarté : `%s:%s` (hors bornes du fichier)" % (ant, ref["plages"]),
                        "motif": ("l'héritage de `%s` sortait du fichier : reroutage vers `%s`, SEUL autre "
                                  "fichier cité dans la même cellule ou la même ligne de tableau dont la "
                                  "plage contient la ligne (règle E_CONTINUATION_HORS_BORNES_REROUTAGE — "
                                  "aucun choix arbitraire)" % (ant, valides[0])),
                    })
                else:
                    ref.update({
                        "categorie": "CONTESTEE_HORS_BORNES",
                        "regle": "HERITAGE_REFUSE_HORS_BORNES",
                        "resolved_by": "contestee_hors_bornes",
                        "resolved_by_initial": rb_initial,
                        "chemin_resolu_ecarte": ref["chemin_resolu"],
                        "antecedent_ecarte": ant, "candidats": candidats_vus,
                        "note": "héritage initial écarté : `%s:%s` (hors bornes du fichier)" % (ant, ref["plages"]),
                        "motif": ("couple (fichier, ligne) IMPOSSIBLE : `%s` n'a pas la ligne %s (%s lignes) "
                                  "et AUCUN candidat de la cellule ni de la ligne de tableau ne la contient "
                                  "de façon unique (%s candidat(s) examiné(s)) — référence CONTESTÉE, jamais "
                                  "présentée comme résolue"
                                  % (ant, ref["lignes_hors_bornes"], idx.lignes_de(ref["chemin_resolu"]),
                                     len(candidats_vus))),
                    })
            refs.append(ref)
            continue
        ma = RE_ALIAS_AVANT.search(cellule[:m.start()])
        alias = ma.group(1) if ma else None
        if alias and (doc, alias) in alias_actifs:
            info = alias_actifs[(doc, alias)]
            lignes = _lignes(numeros)
            n = idx.lignes_de(info["cible"])
            refs.append({
                "brut": ":" + numeros, "champ": champ, "ligne_document": ligne_doc,
                "forme": "CONTINUATION",
                "fichier_texte": None, "fichier_token": alias, "plages": numeros, "lignes": lignes,
                "liste": "," in numeros, "categorie": "RESOLUE", "chemin_resolu": info["cible"],
                "regle": "E_ALIAS_DOCUMENTE_CITE", "tier": "ALIAS_DOCUMENTE", "candidats": [],
                "note": info["libelle"], "fiable": "DOCUMENTE_ALIAS",
                "resolved_by": "alias_documente_cure",
                "alias_source": {"alias": alias, "document": info["preuve"]["document"],
                                 "ligne": info["preuve"]["ligne"],
                                 "extrait": info["citation_extrait"],
                                 "corroboration": _corroboration_alias(doc, info["cible"], numeros)},
                "lignes_hors_bornes": [l for l in lignes if n is not None and (l < 1 or l > n)],
                "motif": None,
            })
            continue
        # Désignation PLURIELLE non résolue : « arbitres `:114-115` » — le mot « arbitres » admet
        # PLUSIEURS cibles (M1 ET M2) : la référence est AMBIGUE, candidats LISTÉS, aucun choix.
        pre = norm_texte(cellule[max(0, m.start() - 40):m.start()])
        if re.search(r"\barbitres\b", pre, re.I):
            cands = sorted({(a["alias"], a["cible"]) for (d, _al), a in alias_actifs.items() if d == doc})
            if len(cands) >= 2:
                refs.append({
                    "brut": ":" + numeros, "champ": champ, "ligne_document": ligne_doc,
                    "forme": "CONTINUATION", "fichier_texte": None, "fichier_token": None,
                    "plages": numeros, "lignes": _lignes(numeros), "liste": "," in numeros,
                    "categorie": "AMBIGUE", "chemin_resolu": None,
                    "regle": "DESIGNATION_PLURIELLE_AMBIGUE", "resolved_by": "designation_plurielle_ambigue",
                    "tier": None, "fiable": None, "alias_source": None, "lignes_hors_bornes": [],
                    "candidats": [{"alias": al, "chemin": ch} for al, ch in cands],
                    "note": ("le mot « arbitres » désigne la pluralité des arbitres du document : "
                             "%d cibles possibles, aucune n'est choisie" % len(cands)),
                    "motif": ("désignation PLURIELLE non résolue : la cellule n'identifie aucun arbitre "
                              "précis — %d candidats listés, aucun tranché silencieusement" % len(cands)),
                })
                continue
        refs.append({
            "brut": m.group(0), "champ": champ, "ligne_document": ligne_doc, "forme": "CONTINUATION",
            "fichier_texte": None, "fichier_token": alias, "plages": numeros, "lignes": _lignes(numeros),
            "liste": "," in numeros, "categorie": "AMBIGUE" if alias else "NON_RESOLUE",
            "chemin_resolu": None,
            "regle": "ALIAS_CONTEXTE_Mnn_Cnn_NON_DOCUMENTE" if alias else "CONTINUATION_SANS_ANTECEDENT_CELLULE",
            "tier": None, "candidats": [], "note": None, "fiable": None, "lignes_hors_bornes": [],
            "resolved_by": RESOLVED_BY.get("ALIAS_CONTEXTE_Mnn_Cnn_NON_DOCUMENTE" if alias
                                           else "CONTINUATION_SANS_ANTECEDENT_CELLULE"),
            "motif": ("alias de contexte `%s` non documente pour ce document : cible non devinee" % alias)
                     if alias else "reference courte sans nom de fichier dans la cellule",
        })

    refs.sort(key=lambda r: cellule.find(r["brut"]) if r["brut"] in cellule else 10 ** 6)
    return refs


def _lignes(numeros: str) -> list[int]:
    out: list[int] = []
    for part in numeros.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, _, b = part.partition("-")
            try:
                ia, ib = int(a), int(b)
            except ValueError:
                continue
            out.extend(range(ia, ib + 1) if ia <= ib else [ia, ib])
        else:
            try:
                out.append(int(part))
            except ValueError:
                continue
    return out


_CACHE_CORROBORATION: dict[tuple, dict | None] = {}


def _corroboration_alias(doc: str, cible: str, plages: str) -> dict | None:
    """
    Corroboration INDEPENDANTE d'un alias : le document cite-t-il, sur UNE MEME LIGNE, le nom
    explicite du fichier cible ET le meme groupe de lignes ? C'est une preuve plus forte que la
    simple definition de l'alias (ex. « M1 `:91-92` » d'un cote, `FB_WinchCmdArbitrationM1.st:…, :91-92`
    de l'autre). Retourne la ligne de corroboration, ou None si aucune.
    """
    cle = (doc, cible, plages)
    if cle in _CACHE_CORROBORATION:
        return _CACHE_CORROBORATION[cle]
    basename = Path(cible).name
    motif = re.compile(r"(?<![\d-])" + re.escape(plages) + r"(?![\d])")
    trouve = None
    for i, l in enumerate((RACINE / DOCS[doc]).read_text(encoding="utf-8").splitlines(), start=1):
        if basename in l and motif.search(l):
            trouve = {"ligne": i, "extrait": l[:160]}
            break
    _CACHE_CORROBORATION[cle] = trouve
    return trouve


def _fabriquer_ref(token, numeros, forme, idx: Index, doc: str, ligne_doc: int, champ: str, brut: str,
                   fichier_explicite: bool = True, alias_actifs: dict | None = None) -> dict:
    alias_actifs = alias_actifs or {}
    lignes = _lignes(numeros)
    # Alias de contexte CURÉ (`M1:91-92` écrit tel quel) : même traitement que la forme
    # « arbitres M1 `:91-92` » — sinon le même alias serait résolu dans un cas et pas dans l'autre.
    if token in [a["alias"] for a in alias_actifs.values()] and (doc, token) in alias_actifs:
        info = alias_actifs[(doc, token)]
        n = idx.lignes_de(info["cible"])
        corroboration = _corroboration_alias(doc, info["cible"], numeros)
        return {
            "brut": brut, "champ": champ, "ligne_document": ligne_doc, "forme": forme,
            "fichier_texte": token if fichier_explicite else None, "fichier_token": token,
            "plages": numeros, "lignes": lignes, "liste": "," in numeros,
            "categorie": "RESOLUE", "chemin_resolu": info["cible"],
            "regle": "E_ALIAS_DOCUMENTE_CITE", "tier": "ALIAS_DOCUMENTE", "candidats": [],
            "note": info["libelle"], "fiable": "DOCUMENTE_ALIAS", "resolved_by": "alias_documente_cure",
            "alias_source": {"alias": token, "document": info["preuve"]["document"],
                             "ligne": info["preuve"]["ligne"], "extrait": info["citation_extrait"],
                             "corroboration": corroboration},
            "propagation": False,
            "lignes_hors_bornes": [l for l in lignes if n is not None and (l < 1 or l > n)],
            "motif": None,
        }
    r = idx.resoudre(token)
    # Alias de contexte NON documente dans CE document : on expose quand meme les CANDIDATS
    # documentes ailleurs (avec leur provenance), plutot qu'une liste vide silencieuse.
    if r["categorie"] == "AMBIGUE" and r["regle"] in ("ALIAS_CONTEXTE_Mnn_Cnn",
                                                      "ALIAS_CONTEXTE_Mnn_Cnn_NON_DOCUMENTE"):
        candidats = [{"alias": a["alias"], "chemin": a["cible"],
                      "provenance": "%s ligne %s" % (a["preuve"]["document"], a["preuve"]["ligne"])}
                     for a in sorted(alias_actifs.values(), key=lambda x: x["alias"])]
        if candidats:
            r = dict(r, regle="ALIAS_CONTEXTE_CANDIDATS_DOCUMENTES_HORS_DOCUMENT",
                     candidats=candidats,
                     note=("l'alias `%s` n'est pas défini dans le document `%s` : %d candidat(s) "
                           "documenté(s) ailleurs, listés avec leur provenance, AUCUN choisi"
                           % (token, doc, len(candidats))),
                     motif=("alias de contexte non résolu pour ce document — candidats documentés "
                            "listés, aucun tranché silencieusement"))
        else:
            r = dict(r, regle="ALIAS_NON_DETERMINABLE_SANS_SECTION", candidats=[],
                     motif=("aucun candidat déterminable : l'alias `%s` n'est défini par AUCUN "
                            "document — refus explicite, jamais une liste vide silencieuse" % token))
    lignes = _lignes(numeros)
    hors = None
    if r["categorie"] == "RESOLUE" and r["chemin"]:
        n = idx.lignes_de(r["chemin"])
        if n is not None:
            hors = [l for l in lignes if l < 1 or l > n]
    return {
        "brut": brut,
        "champ": champ,
        "ligne_document": ligne_doc,
        "forme": forme,
        "fichier_texte": token if fichier_explicite else None,
        "fichier_token": token,
        "plages": numeros,
        "lignes": lignes,
        "liste": "," in numeros,
        "categorie": r["categorie"],
        "chemin_resolu": r["chemin"],
        "regle": r["regle"],
        "tier": r.get("tier"),
        "candidats": r["candidats"],
        "note": r.get("note"),
        "fiable": "INDEX" if r["categorie"] == "RESOLUE" else None,
        "resolved_by": RESOLVED_BY.get(r["regle"], r["regle"]),
        "alias_source": None,
        "lignes_hors_bornes": hors or [],
        "motif": ("aucun candidat dans l'index (CODE/** hors CODE_BACKUP + DOC/** hors ARCHIVES)"
                  if r["categorie"] == "NON_RESOLUE" else None),
    }


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Table de gestes CUREE — chaque entree cite sa source, verifiee mecaniquement
# ═══════════════════════════════════════════════════════════════════════════════════════════

GESTES_CURES = [
    {
        "id": "G01_MANU_TREUILS", "libelle": "Chaîne MANU / MAINTENANCE — treuils M1 & M2",
        "type": "CHAINE", "document": "treuils", "chaine": "M",
        "source": {"document": "treuils", "ligne": 160, "motif_attendu": "CHAÎNE MANU / MAINTENANCE",
                   "section": "§3"},
        "sens": "M1 et M2 (chaîne commune ; dissymétries portées par les marqueurs ⚠️ASYM du document)",
        "statut": "CURE_SOURCE",
    },
    {
        "id": "G02_CYCLE_TREUILS", "libelle": "Chaîne AUTO / SEMI_AUTO — treuils M1 & M2",
        "type": "CHAINE", "document": "treuils", "chaine": "C",
        "source": {"document": "treuils", "ligne": 246, "motif_attendu": "CHAÎNE AUTO / SEMI_AUTO",
                   "section": "§4"},
        "sens": "M1 et M2 (chaîne commune)",
        "statut": "CURE_SOURCE",
    },
    {
        "id": "G03_MANU_M3", "libelle": "Chaîne MANU / MAINTENANCE — translation M3",
        "type": "CHAINE", "document": "t334", "chaine": "M",
        "source": {"document": "t334", "ligne": 62, "motif_attendu": "CHAÎNE MANUELLE", "section": "§4"},
        "sens": "Trémie et Maintenance (points de séparation : M23 / M24 — aval commun)",
        "statut": "CURE_SOURCE",
        "complements_annexe": True,
    },
    {
        "id": "G04_CYCLE_M3", "libelle": "Chaîne CYCLE AUTO / SEMI_AUTO — translation M3",
        "type": "CHAINE", "document": "t334", "chaine": "C",
        "source": {"document": "t334", "ligne": 141, "motif_attendu": "CHAÎNE CYCLE AUTO", "section": "§5"},
        "sens": "Trémie (AX14) et P1 (AX2)",
        "statut": "CURE_SOURCE",
    },
    {
        "id": "G05_FAMILLE_A", "libelle": "Famille de source (a) — geste joystick",
        "type": "FAMILLE", "document": "treuils", "chaine": "M",
        "source": {"document": "treuils", "ligne": 528, "motif_attendu": "Geste joystick", "section": "§8.a"},
        "sens": "MANU/MAINT uniquement, si TglJoystickMaster ET Select",
        "statut": "CURE_SOURCE_FILTRE_HEURISTIQUE",
    },
    {
        "id": "G06_FAMILLE_B", "libelle": "Famille de source (b) — boutons IHM",
        "type": "FAMILLE", "document": "treuils", "chaine": "M",
        "source": {"document": "treuils", "ligne": 529, "motif_attendu": "Boutons IHM", "section": "§8.b"},
        "sens": "MANU/MAINT, si TglJoystickMaster = FALSE ou bouton « both »",
        "statut": "CURE_SOURCE_FILTRE_HEURISTIQUE",
    },
    {
        "id": "G07_FAMILLE_C", "libelle": "Famille de source (c) — actions de la BENNE (M2 seul)",
        "type": "FAMILLE", "document": "treuils", "chaine": "C",
        "source": {"document": "treuils", "ligne": 530, "motif_attendu": "Actions de la BENNE M2", "section": "§8.c"},
        "sens": "M2 uniquement — manuel si Select = 2, SEMI_AUTO si BucketBusy AND BucketM2RunRequest",
        "statut": "CURE_SOURCE_FILTRE_HEURISTIQUE",
    },
    {
        "id": "G08_FAMILLE_D", "libelle": "Famille de source (d) — demande du SÉQUENCEUR de cycle",
        "type": "FAMILLE", "document": "treuils", "chaine": "C",
        "source": {"document": "treuils", "ligne": 531, "motif_attendu": "Demande du SÉQUENCEUR de cycle",
                   "section": "§8.d"},
        "sens": "SEMI_AUTO uniquement (M1 et M2 sous condition benne)",
        "statut": "CURE_SOURCE_FILTRE_HEURISTIQUE",
    },
    # ── Entrees declarees NON SEPARABLES : les documents ne portent PAS cette granularite ────
    {
        "id": "NS01_SENS_GESTE_TREUILS",
        "libelle": "Sens du geste treuil — « joystick M1 monte » / « M1 descend » / « M2 … »",
        "type": "NON_SEPARABLE", "document": "treuils", "chaine": None,
        "source": {"document": "treuils", "ligne": 173, "motif_attendu": "Sens du geste treuil", "section": "§3 M07"},
        "statut": "NON_SEPARABLE",
        "motif": ("Les documents livrent une chaîne LINÉAIRE au niveau VARIABLE, pas un arbre de décision "
                  "par geste/sens : M01→M66 est une seule chaîne, commune à la montée et à la descente. "
                  "Les seuls points qui portent le sens sont M07 (`AxisCmdY.Direction`) et M08 "
                  "(`.DirectionPositive` / `.DirectionNegative`) ; tout l'aval (M09→M66) est partagé. "
                  "Séparer « monte » de « descend » exigerait une lecture du code non consignée par les "
                  "documents — cette surcouche serait INVENTÉE (faute la plus grave du lot)."),
        "points_de_separation_documentes": ["M07", "M08"],
    },
    {
        "id": "NS02_SENS_GESTE_M3",
        "libelle": "Sens du geste M3 — « vers Trémie » / « vers Maintenance »",
        "type": "NON_SEPARABLE", "document": "t334", "chaine": None,
        "source": {"document": "t334", "ligne": 92, "motif_attendu": "ReqMaintenance", "section": "§4 M24"},
        "statut": "NON_SEPARABLE",
        "motif": ("Même limite : les documents donnent des chaînes linéaires par variable. Les points de "
                  "séparation documentés sont M23 (`instArbM3.ReqTremie`) et M24 (`instArbM3.ReqMaintenance`) ; "
                  "en aval, M28→M66 puis M67→M73 (compléments de l'annexe) sont COMMUNS aux deux sens. "
                  "Aucun document ne fournit la liste des maillons distincts par sens : ne pas la deviner."),
        "points_de_separation_documentes": ["M23", "M24"],
    },
    {
        "id": "NS03_BRANCHES_MAINT",
        "libelle": "Sous-branches MAINT_N1 / MAINT_N2 (treuils)",
        "type": "NON_SEPARABLE", "document": "treuils", "chaine": None,
        "source": {"document": "treuils", "ligne": 519, "motif_attendu": "tout sauf SEMI_AUTO", "section": "§7.12"},
        "statut": "NON_SEPARABLE",
        "motif": ("Le document déclare explicitement que les FB d'arbitrage ne testent QUE `E_Mode.SEMI_AUTO` : "
                  "MAINT_N1, MAINT_N2, DISABLE et AUTO tombent tous dans la même branche ELSE dite "
                  "« manuelle ». Il n'existe donc AUCUN chemin MAINT_N1/N2 séparé à afficher (§7.12)."),
    },
    {
        "id": "NS04_BENNE_M2_DETAILLEE",
        "libelle": "Actions de la benne M2 détaillées geste par geste",
        "type": "NON_SEPARABLE", "document": "treuils", "chaine": None,
        "source": {"document": "treuils", "ligne": 625, "motif_attendu": "l'intérieur de `FB_Bucket`",
                   "section": "§11 U10"},
        "statut": "NON_SEPARABLE",
        "motif": ("Le document déclare l'intérieur de `FB_Bucket` VOLONTAIREMENT HORS COUVERTURE (§11-U10). "
                  "Le lot ne dispose que de la frontière M2 (codes C18, C19, C20, C23) : détailler les gestes "
                  "de la benne serait une invention."),
    },
]


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Parsing d'un document
# ═══════════════════════════════════════════════════════════════════════════════════════════

def lire(path: Path) -> tuple[list[str], list[bool]]:
    txt = path.read_text(encoding="utf-8")
    lignes = txt.splitlines()
    fences, dedans = [], False
    for l in lignes:
        if l.lstrip().startswith("```"):
            fences.append(dedans)
            dedans = not dedans
        else:
            fences.append(dedans)
    return lignes, fences


def section_de(lignes: list[str], jusqu: int) -> str:
    for i in range(jusqu - 1, -1, -1):
        s = lignes[i].strip()
        if s.startswith("#"):
            return s.lstrip("# ").strip()
    return ""


def classer_tableau(header: list[str]) -> str:
    """Classe un tableau Markdown par SIGNATURE D'EN-TETE (jamais par position)."""
    h = [norm_header(c) for c in header]
    n = len(header)
    if n == 5 and h[0] == "#" and h[1] == "variable" and any("producteur" in c for c in h) \
            and any("consommateur" in c for c in h):
        return "CHAINE_5COL"
    if n == 5 and h[1] == "divergence":
        return "DIVERGENCES"
    if n == 5 and h[1] == "asymetrie":
        return "ASYMETRIES"
    if n == 4 and any("ref. t334" in c or "ligne citée par t334" in c for c in h):
        return "AUDIT_4COL"
    if n == 3 and h[0] == "code" and any(("corrig" in c or "correcte" in c or "valeur" in c) for c in h):
        return "CORRECTIONS_3COL"
    if n >= 2 and "fichier" in h[0] and any("blob" in c for c in h):
        return "ANCRAGE_BLOBS"
    return "AUTRE"


# Motif de rejet NOMME par categorie de tableau : aucune ligne portant un code de chaine ne peut
# echapper au rapport de parsing (AC1 : « chaque ligne non parsable est listee avec son motif »).
MOTIF_REJET_PAR_CATEGORIE = {
    "AUDIT_4COL": "TABLE_AUDIT_4_COLONNES_NON_INJECTEE",
    "CORRECTIONS_3COL": "TABLE_CORRECTION_3_COLONNES_NON_INJECTEE",
}
RE_LIGNE_CODE_SOUPLE = re.compile(r"^\s*([MC]\d{2})\b")
# Tous les codes presents dans une cellule (regle UNIFORME : independante de l'espacement).
RE_CODE_DANS_CELLULE = re.compile(r"(?<![\w])[MC]\d{2}(?![\w])")


def zones_document(lignes: list[str], fences: list[bool]) -> dict[int, str]:
    """Numero de ligne -> zone (CHAINE_5COL / AUDIT_4COL / DIVERGENCES / ASYMETRIES / ZONE_CODE / PROSE)."""
    zones: dict[int, str] = {}
    for t in iter_tables(lignes, fences):
        cat = classer_tableau(t["header"])
        for r in t["rows"]:
            zones[r["ligne"]] = cat
    for i in range(1, len(lignes) + 1):
        if i in zones:
            continue
        zones[i] = "ZONE_CODE" if fences[i - 1] else "PROSE"
    return zones


def parser_document(doc_id: str, idx: Index, alias_actifs: dict | None = None) -> dict:
    alias_actifs = alias_actifs or {}
    chemin = DOCS[doc_id]
    lignes, fences = lire(RACINE / chemin)
    resultat = {
        "id": doc_id, "chemin": chemin, "titre": DOC_TITRES[doc_id], "lignes_totales": len(lignes),
        "chaines": [], "maillons": [], "complements": [], "rejets": [], "tableaux": [],
        "corrections_references_perimees": [], "corrections_entete": None, "corrections_ancre_head": None,
        "ancrage": None, "ancrages_rejetes": [], "familles": [], "divergences": [], "asymetries": [],
    }
    maillons: list[dict] = []
    codes_vus: dict[str, int] = {}
    for t in iter_tables(lignes, fences):
        h = [norm_header(c) for c in t["header"]]
        n = len(t["header"])
        cat = classer_tableau(t["header"])
        resultat["tableaux"].append({
            "header_ligne": t["header_ligne"], "categorie": cat, "colonnes": n,
            "header": [nettoyer_code(c) for c in t["header"]], "lignes": len(t["rows"]),
            "section": section_de(lignes, t["header_ligne"]),
        })

        if cat == "CHAINE_5COL":
            chaine = None
            for r in t["rows"]:
                cellules = r["cellules"]
                m = RE_CODE.match(cellules[0]) if cellules else None
                if not m:
                    resultat["rejets"].append({
                        "ligne": r["ligne"], "document": doc_id, "code": cellules[0] if cellules else "",
                        "cellules": len(cellules), "motif": "PREMIERE_CELLULE_NON_CONFORME_Mnn_Cnn",
                        "extrait": lignes[r["ligne"] - 1][:160],
                    })
                    continue
                code = m.group(1)
                if len(cellules) != len(t["header"]):
                    resultat["rejets"].append({
                        "ligne": r["ligne"], "document": doc_id, "code": code,
                        "cellules": len(cellules), "motif": "CELLULES_INCOHERENTES",
                        "extrait": lignes[r["ligne"] - 1][:160],
                    })
                    continue
                lettre = code[0]
                if chaine is None:
                    chaine = lettre
                maillon = _fabriquer_maillon(doc_id, code, lettre, r, t, lignes, idx, alias_actifs)
                maillons.append(maillon)
                codes_vus[code] = codes_vus.get(code, 0) + 1
                if codes_vus[code] > 1:
                    maillon["alerte"] = "DOUBLON_CODE"
                    resultat["rejets"].append({
                        "ligne": r["ligne"], "document": doc_id, "code": code, "cellules": len(cellules),
                        "motif": "DOUBLON_CODE", "extrait": lignes[r["ligne"] - 1][:160],
                    })
        elif cat == "AUDIT_4COL":
            # AC3 : lignes de CONTRE-VERIFICATION, jamais des chaines -> rejetees explicitement.
            # ⚠️ SEULES les lignes dont la PREMIERE CELLULE commence par un code Mnn/Cnn sont des
            # candidates ; les autres (references de section `§6.1`, identifiants d'affirmation
            # `H6`/`A03`) ne portent AUCUN code de chaine et ne gonflent donc pas le denominateur.
            for r in t["rows"]:
                c0 = r["cellules"][0] if r["cellules"] else ""
                m = RE_LIGNE_CODE_SOUPLE.match(c0)
                if not m:
                    resultat["lignes_non_candidates_hors_audit"] = resultat.get("lignes_non_candidates_hors_audit", 0) + 1
                    continue
                resultat["rejets"].append({
                    "ligne": r["ligne"], "document": doc_id, "code": m.group(1),
                    "cellules": len(r["cellules"]), "categorie_tableau": cat,
                    "motif": "TABLE_AUDIT_4_COLONNES_NON_INJECTEE",
                    "extrait": lignes[r["ligne"] - 1][:160],
                })
        elif cat == "CORRECTIONS_3COL":
            # §4.10 de l'annexe : table de CORRECTION des references perimees de T334
            # (`| Code | Référence dans T334 | Valeur correcte |`). Ce ne sont PAS des chaines :
            # exposee SEPAREMENT, marquee NON FUSIONNEE, et chaque ligne est aussi REJETEE du graphe.
            entete = " ".join(t["header"])
            anc = re.search(r"disque[\s`'\"]*([0-9a-f]{7,12})", entete)
            resultat["corrections_entete"] = nettoyer_code(entete)[:200]
            resultat["corrections_ancre_head"] = anc.group(1) if anc else None
            for r in t["rows"]:
                cells = r["cellules"]
                if len(cells) != 3:
                    continue
                ancienne = extraire_refs(cells[1], idx, doc_id, r["ligne"], "correction_ancienne", alias_actifs,
                                         " ; ".join(cells))
                # La colonne « Valeur correcte » porte un NUMERO DE LIGNE DU MEME FICHIER que la
                # reference perimee (forme `:481`) : l'heritage se fait donc depuis le fichier de la
                # colonne precedente, avec une regle NOMMEE et tracee.
                fichier = next((x["chemin_resolu"] for x in reversed(ancienne) if x.get("chemin_resolu")), None)
                corrigee = []
                for x in extraire_refs(cells[2], idx, doc_id, r["ligne"], "correction_nouvelle",
                                       alias_actifs, cells[1] + " ; " + cells[2]):
                    y = dict(x)
                    if fichier and y["lignes"]:
                        n = idx.lignes_de(fichier)
                        hors = [l for l in y["lignes"] if n is not None and (l < 1 or l > n)]
                        y.update({"chemin_resolu": None if hors else fichier,
                                  "categorie": "CONTESTEE_HORS_BORNES" if hors else "RESOLUE",
                                  "regle": "CORRECTION_MEME_FICHIER",
                                  "resolved_by": "correction_meme_fichier",
                                  "lignes_hors_bornes": hors, "candidats": [],
                                  "fiable": "DOCUMENTE_CORRECTION_ANNEXE",
                                  "note": "valeur de correction fournie par l'annexe §4.10 (même fichier)"})
                    corrigee.append(y)
                resultat["corrections_references_perimees"].append({
                    "code": nettoyer_code(cells[0]), "document": doc_id, "ligne": r["ligne"],
                    "table_ligne": t["header_ligne"], "section": section_de(lignes, r["ligne"]),
                    "ancienne_reference": nettoyer_code(cells[1]),
                    "nouvelle_reference": nettoyer_code(cells[2]),
                    "refs_anciennes": ancienne, "refs_corrigees": corrigee,
                    "statut": "TABLE_CORRECTION_NON_FUSIONNEE",
                    "marqueurs": marqueurs_de(cells),
                })
        elif cat in ("DIVERGENCES", "ASYMETRIES"):
            cle = "divergences" if cat == "DIVERGENCES" else "asymetries"
            for r in t["rows"]:
                cells = r["cellules"]
                if len(cells) < 5:
                    continue
                resultat[cle].append({
                    "id": nettoyer_code(cells[0]), "document": doc_id, "ligne": r["ligne"],
                    "section": section_de(lignes, r["ligne"]),
                    "titre": nettoyer_code(cells[1]),
                    "col3": nettoyer_code(cells[2]), "col4": nettoyer_code(cells[3]),
                    "pourquoi": nettoyer_code(cells[4]),
                    "marqueurs": marqueurs_de(cells),
                    "refs": extraire_refs(cells[2] + " ; " + cells[3] + " ; " + cells[4], idx, doc_id,
                                          r["ligne"], cle, alias_actifs, " ; ".join(cells)),
                })
        elif cat == "ANCRAGE_BLOBS":
            for r in t["rows"]:
                cells = r["cellules"]
                if len(cells) < 2:
                    continue
                ch = re.findall(r"`([^`]+)`", cells[0])
                fichier = ch[0] if ch else nettoyer_code(cells[0])
                h = RE_SHA1.search(cells[1]) or RE_SHA1.search(" ".join(cells[1:]))
                if not h:
                    resultat["ancrages_rejetes"].append({
                        "ligne": r["ligne"], "motif": "BLOB_ABREGE_NON_40_HEX", "extrait": lignes[r["ligne"] - 1][:160],
                    })
                    continue
                nl = re.search(r"\((\d+)\s*l\)", " ".join(cells[1:]))
                resultat.setdefault("_blobs", []).append({
                    "fichier": fichier.replace("\\", "/"),
                    "blob": h.group(1), "lignes_doc": int(nl.group(1)) if nl else None,
                    "ligne_doc": r["ligne"], "table_ligne": t["header_ligne"],
                })

    # ── maillons : ordre + identifiants ─────────────────────────────────────────────────────
    for i, ma in enumerate(maillons):
        ma["ordre"] = i + 1
    resultat["maillons"] = maillons

    # ── chaines (regroupees par lettre, dans l'ordre du document) ───────────────────────────
    for lettre in ("M", "C"):
        sel = [m for m in maillons if m["chaine"] == lettre]
        if not sel:
            continue
        resultat["chaines"].append({
            "id": f"{doc_id}/{lettre}",
            "lettre": lettre,
            "libelle": _libelle_chaine(doc_id, lettre),
            "mode": _mode_chaine(doc_id, lettre),
            "codes": [m["code"] for m in sel],
            "nb_maillons": len(sel),
            "table_ligne": sel[0]["table_ligne"],
            "section": sel[0]["section"],
        })

    # ── complements explicitement declares (§4.2-4.6 de l'annexe, en zone code) ─────────────
    resultat["complements"] = _parser_complements(doc_id, lignes, fences, idx, alias_actifs)

    # ── PASSAGE EXHAUSTIF (AC1) ────────────────────────────────────────────────────────────
    # TOUTE ligne de tableau commencant par un code Mnn/Cnn qui n'est NI un maillon accepte NI un
    # complement declare est REJETEE avec un motif NOMME, quelle que soit la forme du tableau
    # (4 colonnes d'audit, 3 colonnes de correction, ou toute autre). Aucune ligne portant un code
    # de chaine ne peut donc echapper au rapport de parsing.
    lignes_vues = {m["ligne_document"] for m in maillons}
    lignes_vues |= {c["ligne"] for c in resultat["complements"]}
    lignes_vues |= {r["ligne"] for r in resultat["rejets"]}
    for t in iter_tables(lignes, fences):
        cat = classer_tableau(t["header"])
        for r in t["rows"]:
            if r["ligne"] in lignes_vues:
                continue
            c0 = r["cellules"][0] if r["cellules"] else ""
            m = RE_LIGNE_CODE_SOUPLE.match(c0)
            if not m:
                continue
            motif = MOTIF_REJET_PAR_CATEGORIE.get(cat, "LIGNE_CODE_HORS_TABLEAU_DE_CHAINE_NON_INJECTEE")
            resultat["rejets"].append({
                "ligne": r["ligne"], "document": doc_id, "code": m.group(1),
                "cellules": len(r["cellules"]), "categorie_tableau": cat, "motif": motif,
                "extrait": lignes[r["ligne"] - 1][:160],
            })
            lignes_vues.add(r["ligne"])
    resultat["rejets"].sort(key=lambda x: x["ligne"])

    # ── DEUX GRANDEURS, EXPLICITEMENT ETIQUETEES (jamais un nombre nu) ─────────────────────
    # (a) "LIGNES DE TABLEAU" : 1 candidat par ligne dont la 1re cellule commence par un code,
    #     + 1 par complement declare. Une ligne a codes combines (`M07 / M08`) = 1 candidat.
    # (b) "OCCURRENCES DE CODES" : tous les codes presents dans la 1re cellule, quel que soit
    #     l'espacement autour du `/` (regle UNIFORME : rien ne depend du formatage).
    lignes_cand = {m["ligne_document"] for m in maillons}
    lignes_cand |= {c["ligne"] for c in resultat["complements"]}
    lignes_cand |= {r["ligne"] for r in resultat["rejets"]}
    codes_cand = 0
    for t in iter_tables(lignes, fences):
        for r in t["rows"]:
            if r["ligne"] not in lignes_cand:
                continue
            c0 = r["cellules"][0] if r["cellules"] else ""
            codes_cand += len(RE_CODE_DANS_CELLULE.findall(c0))
    codes_cand += len(resultat["complements"])   # 1 code par complement declare
    resultat["comptage"] = {
        "lignes_candidates_Mnn_Cnn": len(lignes_cand),
        "codes_candidats_occurrences": codes_cand,
        "unite_par_defaut": "LIGNES DE TABLEAU (une ligne a codes combinés = 1 candidat)",
        "regle_codes": ("occurrences = tous les codes de la 1re cellule, règle uniforme : "
                        "l'espacement autour du `/` n'a AUCUN effet"),
        "lignes_non_candidates": resultat.get("lignes_non_candidates_hors_audit", 0),
    }

    # ── ancrage ────────────────────────────────────────────────────────────────────────────
    resultat["ancrage"] = _ancrage(doc_id, lignes, resultat)
    return resultat


# ── Branche NON empruntee (AC8) : la chaine sœur, avec sa source citee et verifiee ───────────
NON_EMPRUNTEES = {
    ("treuils", "M"): {"seur": "treuils/C", "ligne": 163, "motif_attendu": "branche dédiée",
                       "motif": ("En SEMI_AUTO, l'arbitre de chaque treuil bascule sur sa branche cycle "
                                 "(§4). La chaîne cycle n'est donc PAS empruntée en MANU/MAINT.")},
    ("treuils", "C"): {"seur": "treuils/M", "ligne": 162, "motif_attendu": "MAINT_N1",
                       "motif": ("L'arbitre n'emprunte sa branche cycle que sous `Mode = E_Mode.SEMI_AUTO` "
                                 "(§4). Hors SEMI_AUTO, c'est la chaîne manuelle (§3, branche ELSE) qui est "
                                 "empruntée : la chaîne cycle n'est PAS empruntée.")},
    ("t334", "M"): {"seur": "t334/C", "ligne": 143, "motif_attendu": "SEMI_AUTO",
                    "motif": ("La chaîne cycle de M3 n'est active qu'en SEMI_AUTO, et seulement sur les "
                              "étapes AX2 et AX14 : elle n'est PAS empruntée en MAINT_N1/MAINT_N2.")},
    ("t334", "C"): {"seur": "t334/M", "ligne": 64, "motif_attendu": "MAINT_N1",
                    "motif": ("La chaîne manuelle de M3 couvre MAINT_N1/MAINT_N2 : elle n'est PAS "
                              "empruntée en SEMI_AUTO.")},
}


def ajouter_non_empruntees(docs: dict) -> None:
    for (doc_id, lettre), info in NON_EMPRUNTEES.items():
        lg = (RACINE / DOCS[doc_id]).read_text(encoding="utf-8").splitlines()
        ok = 1 <= info["ligne"] <= len(lg) and norm_texte(info["motif_attendu"]) in norm_texte(lg[info["ligne"] - 1])
        for c in docs[doc_id]["chaines"]:
            if c["lettre"] == lettre:
                c["non_empruntee"] = {
                    "chaine_id": info["seur"], "motif": info["motif"],
                    "citation_verifiee": ok,
                    "source": {"document": doc_id, "ligne": info["ligne"], "section": section_de(lg, info["ligne"])},
                    "extrait": lg[info["ligne"] - 1][:200] if ok else "",
                }


def _libelle_chaine(doc_id: str, lettre: str) -> str:
    if lettre == "M":
        return "Chaîne MANU / MAINTENANCE" + ("" if doc_id != "treuils" else " — treuils M1/M2")
    return "Chaîne AUTO / SEMI_AUTO" + (" — treuils M1/M2" if doc_id == "treuils" else " — translation M3")


def _mode_chaine(doc_id: str, lettre: str) -> str:
    if doc_id == "treuils":
        return "MAINT_N1 / MAINT_N2 (branche ELSE de l'arbitre)" if lettre == "M" else "SEMI_AUTO exclusivement"
    return "MAINT_N1 / MAINT_N2" if lettre == "M" else "SEMI_AUTO exclusivement"


def _fabriquer_maillon(doc_id, code, lettre, r, table, lignes, idx, alias_actifs=None) -> dict:
    cells = r["cellules"]
    var_c, prod_c, cons_c, role_c = cells[1], cells[2], cells[3], cells[4]
    # LIGNE DE TABLEAU complete : contexte de secours de la regle nommee
    # E_CONTINUATION_HORS_BORNES_REROUTAGE (jamais utilise pour heriter directement).
    contexte_ligne = " ; ".join(cells)
    refs = []
    refs += extraire_refs(var_c, idx, doc_id, r["ligne"], "variable", alias_actifs, contexte_ligne)
    refs += extraire_refs(prod_c, idx, doc_id, r["ligne"], "producteur", alias_actifs, contexte_ligne)
    refs += extraire_refs(cons_c, idx, doc_id, r["ligne"], "consommateur", alias_actifs, contexte_ligne)
    refs += extraire_refs(role_c, idx, doc_id, r["ligne"], "role", alias_actifs, contexte_ligne)
    manquantes = []
    if not nettoyer_code(prod_c) or nettoyer_code(prod_c) in ("—", "--", "-"):
        manquantes.append("producteur")
    if not nettoyer_code(cons_c) or nettoyer_code(cons_c) in ("—", "--", "-"):
        manquantes.append("consommateur")
    return {
        "id": f"{doc_id}/{code}",
        "document": doc_id,
        "code": code,
        "chaine": lettre,
        "chaine_id": f"{doc_id}/{lettre}",
        "ligne_document": r["ligne"],
        "table_ligne": table["header_ligne"],
        "section": section_de(lignes, r["ligne"]),
        "variable": nettoyer_code(var_c),
        "variable_principale": variable_principale(var_c),
        "producteur": nettoyer_code(prod_c),
        "consommateur": nettoyer_code(cons_c),
        "role": nettoyer_code(role_c),
        "refs_manquantes": manquantes,
        "refs": refs,
        "refs_resolues": sum(1 for x in refs if x["categorie"] == "RESOLUE"),
        "refs_ambigues": sum(1 for x in refs if x["categorie"] == "AMBIGUE"),
        "refs_non_resolues": sum(1 for x in refs if x["categorie"] == "NON_RESOLUE"),
        "marqueurs": marqueurs_de(cells[1:]),
        "statut": "MAILLON_DOCUMENT",
    }


RE_COMPLEMENT = re.compile(r"^\s*\|\s*([MC]\d{2})\s*\|")


def _parser_complements(doc_id: str, lignes: list[str], fences: list[bool], idx: Index,
                        alias_actifs: dict | None = None) -> list[dict]:
    """
    Complements de l'annexe (§4.2 a §4.6) : lignes a 5 colonnes placees DANS un bloc de code,
    donc sans tableau Markdown hote. Le document les declare explicitement « a ajouter/corriger
    a la chaine de T334 ». Ils ne sont JAMAIS fusionnes dans les chaines de T334 (AC3) : ils
    portent `statut = COMPLEMENT_NON_FUSIONNE`.
    """
    out = []
    for i, l in enumerate(lignes):
        if not fences[i]:
            continue
        if not RE_COMPLEMENT.match(l):
            continue
        cellules = split_row(l)
        code = cellules[0].strip()
        if len(cellules) != 5:
            out.append({"document": doc_id, "ligne": i + 1, "code": code, "cellules": len(cellules),
                        "statut": "REJETE", "motif": "CELLULES_INCOHERENTES"})
            continue
        sect = section_de(lignes, i)
        nature = "CORRECTION" if re.search(r"corriger|correction", sect, re.I) else "AJOUT"
        refs = []
        contexte_ligne = " ; ".join(cellules)
        for j, champ in ((1, "variable"), (2, "producteur"), (3, "consommateur"), (4, "role")):
            refs += extraire_refs(cellules[j], idx, doc_id, i + 1, champ, alias_actifs, contexte_ligne)
        out.append({
            "document": doc_id, "ligne": i + 1, "code": code, "chaine": code[0],
            "section": sect, "nature": nature,
            "statut": "COMPLEMENT_NON_FUSIONNE",
            "cible": "chaîne manuelle M de T334" if "MANUELLE" in sect.upper() else "chaîne de T334 (voir section)",
            "variable": nettoyer_code(cellules[1]), "variable_principale": variable_principale(cellules[1]),
            "producteur": nettoyer_code(cellules[2]), "consommateur": nettoyer_code(cellules[3]),
            "role": nettoyer_code(cellules[4]),
            "refs": refs, "marqueurs": marqueurs_de(cellules[1:]),
            "refs_manquantes": [],
        })
    return out


def _ancrage(doc_id: str, lignes: list[str], resultat: dict) -> dict:
    blobs = resultat.pop("_blobs", [])
    infos = ANCRAGE_DECLARE.get(doc_id)
    head = None
    horodatage = None
    if doc_id == "treuils":
        for i in range(40, 60):
            if i < len(lignes):
                m = re.search(r"HEAD\s*=\s*([0-9a-f]{40})", lignes[i])
                if m:
                    head = m.group(1)
                    break
        for l in lignes[45:60]:
            m = re.search(r"Horodatage final\s*=\s*(%s)" % RE_ISO.pattern, l)
            if m:
                horodatage = m.group(1)
                break
    elif doc_id == "annexe":
        # contexte : HEAD court mesure PENDANT l'audit (n'est PAS l'ancrage de contenu)
        for l in lignes[60:75]:
            m = re.search(r"rev-parse --short HEAD`?\s*\|\s*\*\*`?([0-9a-f]{7,12})`?\*\*", l)
            if m:
                head = m.group(1)
                break
        # l'horodatage d'ancrage de contenu est celui marque « fait foi » (§1.3)
        for l in lignes[60:75]:
            if "fait foi" in l:
                pos = l.index("fait foi")
                avant = l[max(0, pos - 90):pos]
                hms = re.findall(r"(\d{2}:\d{2}:\d{2})", avant)
                dates = RE_ISO.findall(l)
                if hms and dates:
                    horodatage = f"{dates[0][:10]}T{hms[-1]}+02:00"
                elif dates:
                    horodatage = dates[0]
                break
    return {
        "document": doc_id,
        "statut": "PRESENT" if infos else "ABSENT",
        "id": infos["id"] if infos else None,
        "etiquette": infos["etiquette"] if infos else None,
        "libelle": infos["libelle"] if infos else (
            "T334 ne porte AUCUN bloc d'ancrage de révision — trou n°1 relevé par l'annexe (§3)"),
        "head_document": head,
        "horodatage_mesure": horodatage,
        "derive_de": "annexe §1.3" if doc_id == "t334" else None,
        "note_derive": (
            "Les fichiers cités par T334 reposent sur un ancrage DÉRIVÉ de la table de blobs du §1.3 de "
            "l'ANNEXE. Cet ancrage n'est JAMAIS présenté comme un ancrage de T334.") if doc_id == "t334" else None,
        "blobs": blobs,
        "nb_fichiers_declares": len({b["fichier"] for b in blobs}),
        "rejets": resultat["ancrages_rejetes"],
    }


# ═══════════════════════════════════════════════════════════════════════════════════════════
# AUDIT GLOBAL DES REFERENCES (9e constat) — toutes zones des 3 documents
# ═══════════════════════════════════════════════════════════════════════════════════════════

def _forme_audit(ref: dict) -> str:
    tok = ref.get("fichier_token") or ""
    if "/" in tok:
        return "CHEMIN_COMPLET"
    if "." in Path(tok).name and tok:
        return "EXTENSION"
    if RE_ALIAS.match(tok):
        return "ABREVIATION_ALIAS"
    if tok:
        return "ABREVIATION_PREFIXE"
    return "CONTINUATION"


def _traitement_audit(ref: dict) -> str:
    rb = ref.get("resolved_by") or ""
    if rb in ("prefix_unique", "prefix_unique_chemin_declare", "prefix_unique_doc",
              "prefix_unique_non_suivi"):
        return "PREFIXE_UNIQUE"
    if rb == "prefix_ambigu":
        return "PREFIXE_AMBIGU"
    if rb == "alias_documente_cure":
        return "ALIAS_CONTEXTE_CURE"
    if rb == "alias_non_documente":
        return "ALIAS_NON_RESOLUE"
    if rb == "alias_candidats_documentes":
        return "AMBIGU_MULTIPLE_CANDIDATS"
    if rb == "alias_non_determinable":
        return "ALIAS_NON_DETERMINABLE"
    if rb == "designation_plurielle_ambigue":
        return "AMBIGU_MULTIPLE_CANDIDATS"
    if rb == "prefix_sans_match":
        return "PREFIXE_SANS_MATCH"
    if rb == "nom_sans_match":
        return "TRONCATURE_OU_NOM_INTROUVABLE"
    if rb == "nom_ambigu":
        return "NOM_AMBIGU"
    if rb == "nom_hors_index_actif":
        return "NOM_HORS_INDEX_ACTIF"
    if rb == "chemin_introuvable":
        return "CHEMIN_INTROUVABLE"
    if rb == "chemin_hors_index_actif":
        return "CHEMIN_HORS_INDEX_ACTIF"
    if rb == "troncature_prose":
        return "TRONCATURE_OU_NOM_INTROUVABLE"
    if rb == "continuation_reroutee_cellule" or rb == "continuation_reroutee_ligne":
        return "CONTINUATION_REROUTEE_LIGNE"
    if rb == "contestee_hors_bornes" or rb == "contestee_ligne_hors_fichier":
        return "CONTESTEE_HORS_BORNES"
    if rb in ("continuation_sans_antecedent", "heritage_refuse_mot_designation",
              "heritage_refuse_hors_bornes"):
        return "CONTINUATION_REFUSEE"
    if rb in ("chemin_exact", "chemin_declare_ancrage", "basename_unique",
              "basename_unique_chemin_declare", "basename_unique_doc",
              "basename_unique_non_suivi", "prefix_unique_non_suivi"):
        return "RESOLUE_AUTRE"
    return "NON_RESOLUE_AUTRE"


def audit_global(idx: Index, alias_actifs: dict) -> dict:
    """
    Audit de TOUTES les references `fichier:ligne` des 3 documents, TOUTES ZONES (chaines,
    tableaux d'audit, prose, journal, annexes) — donc un perimetre plus large que le graphe,
    qui ne porte que les maillons des tableaux de chaine + les complements declares.

    Classe chaque occurrence selon les 4 formes du 9e constat et les 4 traitements attendus :
      PREFIXE_UNIQUE (abreviation -> un seul fichier CODE/** commence par <prefixe>. ou <prefixe>_)
      PREFIXE_AMBIGU (plusieurs candidats -> AMBIGU, jamais tranche silencieusement)
      ALIAS_CONTEXTE_CURE (M1/M2 -> alias CURÉ dont la provenance est citée et vérifiée)
      TRONCATURE_OU_NOM_INTROUVABLE (`M2.st` : troncature de prose, jamais un fichier)
    Aucun token n'est jamais converti en chemin inventé.
    """
    par_doc = {}
    exclus = []
    refs_complets: list[tuple[str, dict]] = []
    for doc_id, chemin in DOCS.items():
        lignes, fences = lire(RACINE / chemin)
        zones = zones_document(lignes, fences)
        refs = []
        for i, l in enumerate(lignes, start=1):
            cellules = split_row(l) if l.lstrip().startswith("|") else [l]
            for c in cellules:
                if not c.strip():
                    continue
                for r in extraire_refs(c, idx, doc_id, i, "audit", alias_actifs):
                    tok = r.get("fichier_token") or ""
                    if tok and RE_TOKEN_NON_FICHIER.match(tok):
                        exclus.append({"document": doc_id, "ligne": i, "token": tok,
                                       "brut": r["brut"], "motif": "TOKEN_NON_FICHIER (horodatage / numéro)",
                                       "extrait": l[:160]})
                        continue
                    r = dict(r, zone=zones.get(i, "PROSE"))
                    tronc = RE_TRONCATURE.match(tok) if "." in Path(tok).name and tok else None
                    if tronc and r["categorie"] != "RESOLUE":
                        r = dict(r, regle="TRONCATURE_PROSE", resolved_by="troncature_prose",
                                 motif=("troncature de prose : `%s` n'existe pas — le document écrit `%s` "
                                        "là où il désigne l'objet de l'alias `%s` (défaut de rédaction "
                                        "de la fiche, ce n'est PAS un fichier manquant)"
                                        % (tok, tok, tronc.group(1))))
                    refs.append(r)
        buckets: dict[str, list] = {}
        par_traitement: dict[str, int] = {}
        par_forme: dict[str, int] = {}
        par_zone: dict[str, int] = {}
        par_zone_traitement: dict[str, dict[str, int]] = {}
        for r in refs:
            f, t = _forme_audit(r), _traitement_audit(r)
            refs_complets.append(("audit:%s" % doc_id, r))
            par_forme[f] = par_forme.get(f, 0) + 1
            par_traitement[t] = par_traitement.get(t, 0) + 1
            z = r.get("zone", "PROSE")
            par_zone[z] = par_zone.get(z, 0) + 1
            par_zone_traitement.setdefault(z, {})
            par_zone_traitement[z][f] = par_zone_traitement[z].get(f, 0) + 1
            buckets.setdefault(t, []).append({
                "ligne": r.get("ligne_document"), "zone": r.get("zone"), "brut": r["brut"],
                "token": r.get("fichier_token"), "champ": r["champ"],
                "categorie": r["categorie"], "regle": r["regle"], "resolved_by": r.get("resolved_by"),
                "chemin": r["chemin_resolu"], "motif": r.get("motif"),
                "candidats": r.get("candidats", [])[:6],
            })
        par_doc[doc_id] = {
            "chemin": chemin, "occurrences": len(refs), "par_forme": par_forme,
            "par_traitement": par_traitement, "par_zone": par_zone,
            "par_zone_forme": par_zone_traitement,
            "occurrences_avec_token_fichier": sum(v for k, v in par_forme.items() if k != "CONTINUATION"),
            "occurrences_continuation": par_forme.get("CONTINUATION", 0),
            # Listes detaillees : les compteurs restent EXACTS (colonnes `totaux`), mais les listes
            # volumineuses sont bornees pour ne pas alourdir la charge utile embarquee (mode file://).
            "prefixe_unique": buckets.get("PREFIXE_UNIQUE", [])[:60],
            "prefixe_unique_total": len(buckets.get("PREFIXE_UNIQUE", [])),
            "prefixe_ambigu": buckets.get("PREFIXE_AMBIGU", []),
            "alias_contexte_cure": buckets.get("ALIAS_CONTEXTE_CURE", [])[:60],
            "alias_contexte_cure_total": len(buckets.get("ALIAS_CONTEXTE_CURE", [])),
            "alias_non_resolue": buckets.get("ALIAS_NON_RESOLUE", []),
            "prefixe_sans_match": buckets.get("PREFIXE_SANS_MATCH", []),
            "troncature_ou_nom_introuvable": buckets.get("TRONCATURE_OU_NOM_INTROUVABLE", []),
            "continuation_refusee": buckets.get("CONTINUATION_REFUSEE", [])[:60],
            "continuation_refusee_total": len(buckets.get("CONTINUATION_REFUSEE", [])),
            "resolues_autre": buckets.get("RESOLUE_AUTRE", [])[:30],
            "resolues_autre_total": len(buckets.get("RESOLUE_AUTRE", [])),
            "buckets_par_traitement_compteurs": {k: len(v) for k, v in buckets.items()},
        }
    totaux = {
        "occurrences": sum(d["occurrences"] for d in par_doc.values()),
        "prefixe_unique": sum(d["prefixe_unique_total"] for d in par_doc.values()),
        "prefixe_ambigu": sum(len(d["prefixe_ambigu"]) for d in par_doc.values()),
        "alias_contexte_cure": sum(d["alias_contexte_cure_total"] for d in par_doc.values()),
        "alias_non_resolue": sum(len(d["alias_non_resolue"]) for d in par_doc.values()),
        "prefixe_sans_match": sum(len(d["prefixe_sans_match"]) for d in par_doc.values()),
        "troncature_ou_nom_introuvable": sum(len(d["troncature_ou_nom_introuvable"]) for d in par_doc.values()),
        "continuation_refusee": sum(d["continuation_refusee_total"] for d in par_doc.values()),
        "resolues_autre": sum(d["resolues_autre_total"] for d in par_doc.values()),
        "tokens_exclus_non_fichier": len(exclus),
        "note_listes_bornees": ("les listes prefixe_unique / alias_contexte_cure / continuation_refusee / "
                                "resolues_autre sont bornees dans le JSON ; les compteurs (ici et dans "
                                "`buckets_par_traitement_compteurs`) restent EXACTS"),
        "occurrences_par_zone": {
            z: sum(d["par_zone"].get(z, 0) for d in par_doc.values())
            for z in ("CHAINE_5COL", "AUDIT_4COL", "DIVERGENCES", "ASYMETRIES", "ZONE_CODE", "PROSE")
        },
    }
    # Contrôle anti-invention : aucun chemin résolu ne doit être un ALIAS affublé d'une extension
    # (`M1.st`, `M2.st`, `PRG_04.st`…). Les vrais fichiers `FB_Winch.st` / `FB_Translation.st` sont légitimes.
    inventions = []
    for doc in par_doc.values():
        for cle, lst in doc.items():
            if not isinstance(lst, list):
                continue
            for e in lst:
                ch = e.get("chemin") if isinstance(e, dict) else None
                if not ch:
                    continue
                nom = Path(ch).name.lower()
                if re.fullmatch(r"[mc]\d{1,2}\.(st|csv|md)|prg_\d{2}\.(st|csv)", nom):
                    inventions.append(e)
    return {"defini": ("Toutes zones des 3 documents (chaînes + tableaux d'audit + prose + journal). "
                       "Périmètre PLUS LARGE que `rapport_resolution`, qui ne porte que les références "
                       "du graphe (maillons + compléments + dissymétries/divergences)."),
            "par_document": par_doc, "totaux": totaux,
            "exclus_non_fichier": exclus[:40],
            # Liste COMPLETE (non exportée dans le JSON, bornée à l'export) : elle alimente
            # l'auto-contrôle des invariants sur TOUTES les références produites par le parseur.
            "_refs_complets": refs_complets,
            "controle_anti_invention": {
                "methode": ("aucun chemin resolu ne doit etre un alias affuble d'une extension "
                            "(M1.st / M2.st / PRG_04.st) — les vrais fichiers FB_Winch.st et "
                            "FB_Translation.st sont legitimes"),
                "chemins_inventes": len(inventions), "exemples": inventions[:10]}}


# ═══════════════════════════════════════════════════════════════════════════════════════════
# Assemblage
# ═══════════════════════════════════════════════════════════════════════════════════════════

def verifier_invariants(graphe: dict, refs_extra: list | None = None) -> dict:
    """
    AUTO-CONTROLE DU PARSEUR — invariants TESTABLES. Un invariant casse est SIGNALE FORTEMENT et
    fait echouer le parseur (code retour 1) : mieux vaut un parseur qui crie qu'un outil qui affiche
    un chemin faux avec assurance.

      1. AUCUNE reference `RESOLUE` ne peut avoir une plage de lignes vide OU hors des bornes du
         fichier resolu (toutes zones : maillons, complements, dissymetries, divergences, familles).
      2. Toute reference `RESOLUE` porte un `chemin_resolu`.
      3. Toute categorie appartient a l'ensemble autorise.
      4. Aucun chemin resolu ne peut etre un alias affuble d'une extension (M1.st / PRG_04.st).
    """
    CATEGORIES = {"RESOLUE", "AMBIGUE", "NON_RESOLUE", "CONTESTEE_HORS_BORNES"}
    refs = []
    for m in graphe["maillons"] + graphe["complements"]:
        for r in m.get("refs", []):
            refs.append((m.get("id") or ("%s/%s" % (m["document"], m["code"])), r))
    for cle in ("divergences", "asymetries", "familles"):
        for x in graphe.get(cle, []):
            for r in x.get("refs", []):
                refs.append(("%s:%s" % (cle, x.get("id")), r))
    zones = ["maillons", "complements", "divergences", "asymetries", "familles"]
    # Zone d'AUDIT (toutes occurrences des 3 documents) : controlee ELLE AUSSI.
    n_audit = 0
    for src, r in (refs_extra or []):
        refs.append((src, r))
        n_audit += 1
    if n_audit:
        zones.append("audit (toutes zones des 3 documents)")
    # Table de CORRECTION §4.10 : controlee ELLE AUSSI.
    n_corr = 0
    for x in graphe.get("corrections_references_perimees", []):
        for cle in ("refs_anciennes", "refs_corrigees"):
            for r in x.get(cle, []):
                refs.append(("corrections:%s" % x.get("code"), r))
                n_corr += 1
    if n_corr:
        zones.append("corrections §4.10")

    violations = {"RESOLUE_hors_bornes": [], "RESOLUE_sans_chemin": [], "categorie_inconnue": [],
                  "alias_converti_en_fichier": []}
    for source, r in refs:
        cat = r.get("categorie")
        if cat not in CATEGORIES:
            violations["categorie_inconnue"].append({"source": source, "brut": r.get("brut"), "categorie": cat})
            continue
        if cat == "RESOLUE":
            if r.get("lignes_hors_bornes"):
                violations["RESOLUE_hors_bornes"].append({"source": source, "brut": r.get("brut"),
                                                         "chemin": r.get("chemin_resolu"),
                                                         "hors": r["lignes_hors_bornes"]})
            if not r.get("chemin_resolu"):
                violations["RESOLUE_sans_chemin"].append({"source": source, "brut": r.get("brut")})
            ch = r.get("chemin_resolu") or ""
            if re.fullmatch(r"[mc]\d{1,2}\.(st|csv|md)|prg_\d{2}\.(st|csv)", Path(ch).name.lower()):
                violations["alias_converti_en_fichier"].append({"source": source, "chemin": ch})
    total = sum(len(v) for v in violations.values())
    return {
        "refs_controlees": len(refs),
        "zones_couvertes": zones,
        "note_perimetre": ("le contrôle porte sur TOUTES les références produites par le parseur : "
                           "graphe + zone d'audit (toutes zones des 3 documents) + table de correction"),
        "invariants": [
            "1. aucune reference RESOLUE avec lignes_hors_bornes non vide",
            "2. toute reference RESOLUE porte chemin_resolu",
            "3. categorie dans {RESOLUE, AMBIGUE, NON_RESOLUE, CONTESTEE_HORS_BORNES}",
            "4. aucun chemin resolu de type M1.st / M2.st / PRG_04.st (alias converti en fichier)",
        ],
        "violations": violations,
        "total_violations": total,
        "verdict": "PASS" if total == 0 else "FAIL",
    }


# ── Attendus de RESOLUTION verifies mecaniquement (non-regression) ──────────────────────────
# Valeurs fournies par la revue orchestrateur et VERIFIEES dans les fiches : elles verrouillent
# l'heritage des continuations pour TOUTES les formes d'antecedent (chemin complet, nom nu,
# ABREVIATION de prefixe, ALIAS documente). Toute regression fait ECHOUER le parseur.
ATTENDUS_RESOLUTION = [
    {"maillon": "M20", "brut": ":114-115", "attendu": "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st",
     "forme_antecedent": "alias documenté M1", "lignes_max": None},
    {"maillon": "M20", "brut": ":141-142", "attendu": "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st",
     "forme_antecedent": "alias documenté M2", "lignes_max": None},
    {"maillon": "M21", "brut": ":1611-1612", "attendu": "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
     "forme_antecedent": "abréviation de préfixe (PRG_04:1462-1463)", "lignes_max": None},
    {"maillon": "M34", "brut": ":1527", "attendu": "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
     "forme_antecedent": "abréviation de préfixe (PRG_04:1461)", "lignes_max": None},
    {"maillon": "M34", "brut": ":1596", "attendu": "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
     "forme_antecedent": "abréviation de préfixe", "lignes_max": None},
    {"maillon": "M34", "brut": ":1617", "attendu": "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
     "forme_antecedent": "abréviation de préfixe", "lignes_max": None},
    # Cas qui doit RESTER refuse : « arbitres :114-115 » n'identifie NI M1 NI M2 -> jamais devine.
    {"maillon": "M21", "brut": ":114-115", "attendu": None, "forme_antecedent": "mot « arbitres » seul",
     "categorie_attendue": ["NON_RESOLUE", "AMBIGUE"], "lignes_max": None},
]


def verifier_attendus(graphe: dict) -> dict:
    """Confronte le graphe aux attendus de resolution (verrou de non-regression)."""
    index_refs = {}
    for m in graphe["maillons"]:
        for r in m.get("refs", []):
            index_refs.setdefault((m["code"], r.get("brut")), []).append(r)
    resultats, ko = [], 0
    for a in ATTENDUS_RESOLUTION:
        trouves = index_refs.get((a["maillon"], a["brut"]), [])
        r = trouves[0] if trouves else None
        if r is None:
            resultats.append(dict(a, obtenu=None, pass_=False, motif="référence absente du graphe"))
            ko += 1
            continue
        if a.get("attendu") is None:
            ok = r["categorie"] in a.get("categorie_attendue", [])
            obtenu = "%s (%s)" % (r["categorie"], r["regle"])
        else:
            ok = r["chemin_resolu"] == a["attendu"]
            obtenu = r["chemin_resolu"]
        resultats.append(dict(a, obtenu=obtenu, regle=r["regle"], pass_=ok,
                              motif=None if ok else "valeur attendue non obtenue"))
        ko += 0 if ok else 1
    return {"verrou": "attendus de résolution fournis par la revue et vérifiés dans les fiches",
            "attendus": resultats, "total": len(resultats), "conformes": len(resultats) - ko,
            "verdict": "PASS" if ko == 0 else "FAIL"}


def git_head(racine: Path) -> str:
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(racine), capture_output=True, text=True).stdout.strip()


def chemins_declares_ancrage() -> set[str]:
    """
    Pre-scan (1er passage) : chemins EXPLICITEMENT declares par les blocs d'ancrage des documents.
    Ils alimentent le tier ANCRAGE_DECLARE de l'index de resolution (ex. le CSV d'E/S, qui vit
    sous TOOLS/AGENT_WORKFLOW/config/ et ne serait sinon jamais resolu).
    """
    out: set[str] = set()
    for doc_id, chemin in DOCS.items():
        lignes, fences = lire(RACINE / chemin)
        for t in iter_tables(lignes, fences):
            h = [norm_header(c) for c in t["header"]]
            if len(h) >= 2 and "fichier" in h[0] and any("blob" in c for c in h):
                for r in t["rows"]:
                    ch = re.findall(r"`([^`]+)`", r["cellules"][0]) if r["cellules"] else []
                    for c in ch:
                        c = c.strip().replace("\\", "/")
                        if c.endswith((".st", ".csv", ".md", ".json", ".txt", ".bat", ".py")):
                            out.add(c)
            if h and h[0] not in ("fichier", "fichier cité") and "fichier" in h[0]:
                pass
    return out


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    DATA.mkdir(parents=True, exist_ok=True)
    declares = chemins_declares_ancrage()
    idx = Index(RACINE, declares)
    alias_actifs, ecarts_alias = charger_alias()
    docs = {d: parser_document(d, idx, alias_actifs) for d in DOCS}
    ajouter_non_empruntees(docs)

    maillons = [m for d in docs.values() for m in d["maillons"]]
    complements = [c for d in docs.values() for c in d["complements"]]
    rejets = [r for d in docs.values() for r in d["rejets"]]

    # ── ancrage consolide ──────────────────────────────────────────────────────────────────
    fichiers: dict[str, dict] = {}
    conflits = []
    for doc_id, d in docs.items():
        anc = d["ancrage"]
        for b in anc["blobs"]:
            ent = fichiers.setdefault(b["fichier"], {
                "chemin": b["fichier"], "blob_consigne": b["blob"], "lignes_doc": b["lignes_doc"],
                "sources": [], "utilise_par": [],
            })
            if ent["blob_consigne"] != b["blob"]:
                conflits.append({"fichier": b["fichier"], "blob_a": ent["blob_consigne"],
                                 "blob_b": b["blob"], "document_b": doc_id, "ligne_b": b["ligne_doc"]})
            else:
                ent["sources"].append({
                    "source": anc["id"], "etiquette": anc["etiquette"], "document": doc_id,
                    "ligne_document": b["ligne_doc"],
                })
            if doc_id not in ent["utilise_par"]:
                ent["utilise_par"].append(doc_id)

    cited = {}
    for m in maillons + complements:
        for r in m["refs"]:
            if r["categorie"] == "RESOLUE" and r["chemin_resolu"]:
                cited.setdefault(r["chemin_resolu"], set()).add(m.get("document"))

    for chemin, docs_src in cited.items():
        ent = fichiers.get(chemin)
        if ent:
            for ds in sorted(docs_src):
                if ds not in ent["utilise_par"]:
                    ent["utilise_par"].append(ds)
        else:
            fichiers[chemin] = {
                "chemin": chemin, "blob_consigne": None, "lignes_doc": None, "sources": [],
                "utilise_par": sorted(docs_src), "sans_ancrage": True,
            }

    for ent in fichiers.values():
        etiquettes = {s["etiquette"] for s in ent["sources"]}
        ent["ancrage_derive"] = bool(ent["sources"]) and etiquettes == {"DERIVE"}
        ent["sans_ancrage"] = not ent["sources"]
        ent["etiquettes"] = sorted(etiquettes)

    # ── rapport de parsing (P1) ────────────────────────────────────────────────────────────
    rapport = {"par_document": {}, "totaux": {}, "rejets": rejets}
    for doc_id, d in docs.items():
        par_chaine = {}
        for c in d["chaines"]:
            sel = [m for m in d["maillons"] if m["chaine"] == c["lettre"]]
            par_chaine[c["lettre"]] = {
                "codes": c["codes"], "nb": len(sel),
                "contigu": c["codes"] == _codes_attendus(c["lettre"]),
                "doublons": len(c["codes"]) - len(set(c["codes"])),
                "sans_reference": [m["code"] for m in sel if not m["refs"]],
                "sans_ref_producteur": [m["code"] for m in sel if not any(r["champ"] == "producteur" for r in m["refs"])],
                "sans_ref_consommateur": [m["code"] for m in sel if not any(r["champ"] == "consommateur" for r in m["refs"])],
            }
        par_chaine = {k: v for k, v in par_chaine.items()}
        compl_ok = [c for c in d["complements"] if c.get("statut") == "COMPLEMENT_NON_FUSIONNE"]
        compt = d.get("comptage", {})
        candidates = compt.get("lignes_candidates_Mnn_Cnn", len(d["maillons"]) + len(d["rejets"]) + len(compl_ok))
        rapport["par_document"][doc_id] = {
            "chemin": d["chemin"], "lignes_document": d["lignes_totales"],
            "lignes_candidates_Mnn_Cnn": candidates,
            "codes_candidats_occurrences": compt.get("codes_candidats_occurrences"),
            "unite_de_comptage": compt.get("unite_par_defaut"),
            "regle_de_comptage": compt.get("regle_codes"),
            "lignes_non_candidates_hors_audit": compt.get("lignes_non_candidates", 0),
            "lignes_chaine_acceptees": len(d["maillons"]),
            "complements_non_fusionnes": len(compl_ok),
            "rejets": d["rejets"],
            "par_chaine": par_chaine,
            "taux_chaine": (round(len(d["maillons"]) / candidates, 4) if candidates else None),
            "taux_global": (round((len(d["maillons"]) + len(compl_ok)) / candidates, 4) if candidates else None),
        }
    rapport["totaux"] = {
        "lignes_candidates_Mnn_Cnn": sum(d["lignes_candidates_Mnn_Cnn"] for d in rapport["par_document"].values()),
        "codes_candidats_occurrences": sum((d["codes_candidats_occurrences"] or 0)
                                           for d in rapport["par_document"].values()),
        "unite_par_defaut": "LIGNES DE TABLEAU (voir par_document[*].unite_de_comptage)",
        "lignes_chaine_acceptees": len(maillons),
        "dont_treuils": len(docs["treuils"]["maillons"]),
        "dont_t334": len(docs["t334"]["maillons"]),
        "complements_annexe_non_fusionnes": len([c for c in complements if c.get("statut") == "COMPLEMENT_NON_FUSIONNE"]),
        "lignes_rejetees": len(rejets),
        "rejets_audit_4col": len([r for r in rejets if r["motif"] == "TABLE_AUDIT_4_COLONNES_NON_INJECTEE"]),
    }

    # ── rapport de resolution (P2) ─────────────────────────────────────────────────────────
    refs_tot = [r for m in maillons + complements for r in m["refs"]]
    par_forme: dict[str, dict] = {}
    for r in refs_tot:
        f = par_forme.setdefault(r["forme"], {"total": 0, "RESOLUE": 0, "AMBIGUE": 0, "NON_RESOLUE": 0,
                                              "CONTESTEE_HORS_BORNES": 0, "liste": 0, "exemples": []})
        f["total"] += 1
        f[r["categorie"]] += 1
        if r["liste"]:
            f["liste"] += 1
        if len(f["exemples"]) < 12:
            f["exemples"].append({"brut": r["brut"], "document": None, "chemin": r["chemin_resolu"],
                                  "regle": r["regle"], "categorie": r["categorie"]})
    par_regle: dict[str, int] = {}
    for r in refs_tot:
        par_regle[r["regle"]] = par_regle.get(r["regle"], 0) + 1
    resolution = {
        "refs_totales": len(refs_tot),
        "par_categorie": {c: sum(1 for r in refs_tot if r["categorie"] == c)
                          for c in ("RESOLUE", "AMBIGUE", "NON_RESOLUE", "CONTESTEE_HORS_BORNES")},
        "par_forme": par_forme,
        "par_regle": dict(sorted(par_regle.items(), key=lambda kv: -kv[1])),
        "fichiers_distincts_resolus": len({r["chemin_resolu"] for r in refs_tot if r["chemin_resolu"]}),
        "refs_hors_bornes": sum(1 for r in refs_tot if r["lignes_hors_bornes"]),
        "refs_hors_bornes_toutes_zones": None,   # renseigne apres l'audit global (voir main)
        "refs_contestees_detail": [],
        "refs_reroutees_detail": [],
        "ambigues_detail": _echantillon([r for r in refs_tot if r["categorie"] == "AMBIGUE"], 20),
        "non_resolues_detail": _echantillon([r for r in refs_tot if r["categorie"] == "NON_RESOLUE"], 20),
        "par_document": {},
    }
    for doc_id, d in docs.items():
        rr = [r for m in d["maillons"] + d["complements"] for r in m["refs"]]
        resolution["par_document"][doc_id] = {
            "refs": len(rr),
            "RESOLUE": sum(1 for r in rr if r["categorie"] == "RESOLUE"),
            "AMBIGUE": sum(1 for r in rr if r["categorie"] == "AMBIGUE"),
            "NON_RESOLUE": sum(1 for r in rr if r["categorie"] == "NON_RESOLUE"),
            "CONTESTEE_HORS_BORNES": sum(1 for r in rr if r["categorie"] == "CONTESTEE_HORS_BORNES"),
            "fichiers_distincts": len({r["chemin_resolu"] for r in rr if r["chemin_resolu"]}),
            "refs_courtes": sum(1 for r in rr if r["forme"] == "CONTINUATION"),
            "tokens_fichier": len({(m.get("id") or (m["document"] + "/" + m["code"]), r["fichier_token"])
                                   for m in d["maillons"] + d["complements"]
                                   for r in m.get("refs", []) if r.get("fichier_token")}),
        }

    # ── gestes cures : verification mecanique des citations ────────────────────────────────
    gestes = []
    for g in GESTES_CURES:
        g2 = dict(g)
        src = g["source"]
        d = docs.get(src["document"])
        ok = False
        extrait = ""
        if d:
            p = RACINE / d["chemin"]
            lg = p.read_text(encoding="utf-8").splitlines()
            if 1 <= src["ligne"] <= len(lg):
                extrait = lg[src["ligne"] - 1][:200]
                ok = norm_texte(src["motif_attendu"]) in norm_texte(lg[src["ligne"] - 1])
        g2["citation_verifiee"] = ok
        g2["citation_extrait"] = extrait
        if g["type"] == "CHAINE":
            sel = [m["id"] for m in docs[g["document"]]["maillons"] if m["chaine"] == g["chaine"]]
            g2["maillons_inclus"] = sel
        else:
            g2["maillons_inclus"] = None
        gestes.append(g2)

    # ── familles de sources (§8) et divergences : enrichissement AC8 ───────────────────────
    familles = []
    for g in gestes:
        if g["type"] == "FAMILLE":
            doc = docs[g["source"]["document"]]
            refs_ligne = []
            for t in doc["tableaux"]:
                pass
            src_ligne = g["source"]["ligne"]
            refs_ligne = extraire_refs(g["citation_extrait"], idx, g["source"]["document"], src_ligne,
                                       "famille", alias_actifs)
            familles.append({
                "id": g["id"], "libelle": g["libelle"], "document": g["source"]["document"],
                "ligne": src_ligne, "section": g["source"]["section"],
                "extrait": g["citation_extrait"], "regimes": g["sens"],
                "marqueurs": marqueurs_de([g["citation_extrait"]]),
                "refs": refs_ligne,
                "chemin": "§8 de la fiche treuils (4 familles de sources de demande d'un treuil)",
                "statut": g["statut"],
            })

    # ── assemblage du JSON pivot ───────────────────────────────────────────────────────────
    maintenant = _dt.datetime.now().astimezone().replace(microsecond=0).isoformat()
    head = git_head(RACINE)
    limite_t334 = docs["t334"]["ancrage"]
    limites = [
        {"id": "L1", "gravite": "BLOQUANT", "titre": "T334 ne porte AUCUN bloc d'ancrage de révision",
         "detail": ("T334 n'a ni `HEAD` ni blob : la fraîcheur de ses références repose sur le §1.3 de "
                    "l'ANNEXE, mesuré à " + str(limite_t334.get("horodatage_mesure")) + ". Cet ancrage est "
                    "étiqueté DÉRIVÉ partout dans l'outil et n'est jamais présenté comme un ancrage de T334."),
         "source": "annexe §3, trou 🔴 n°1"},
        {"id": "L2", "gravite": "BLOQUANT", "titre": "Le geste n'existe pas dans les documents",
         "detail": ("Les documents livrent des chaînes LINÉAIRES par variable, pas un arbre de décision par "
                    "geste. Les entrées de geste sont une surcouche CURÉE, chacune citant sa source ; tout ce "
                    "que les sources ne séparent pas est affiché NON SÉPARABLE avec la raison."),
         "source": "treuils §2 et §3 ; t334 §4 et §5"},
        {"id": "L3", "gravite": "MAJEUR", "titre": "Un HTML en file:// ne peut pas recalculer les blobs",
         "detail": ("En mode statique, les badges de fraîcheur sont FIGÉS : leur horodatage est affiché et un "
                    "bandeau signale explicitement « fraîcheur non recalculée en direct ». Le recalcul réel "
                    "exige le mode live (serveur de fichiers statique)."),
         "source": "constat n°3 du cadrage"},
        {"id": "L4", "gravite": "MAJEUR", "titre": "`git hash-object` applique le filtre CRLF du dépôt",
         "detail": ("`core.autocrlf = true` : git convertit CRLF→LF AVANT de calculer le blob. Le hash exact "
                    "est SHA1(\"blob \" + taille_apres_normalisation + \"\\0\" + contenu_normalisé). Sans cette "
                    "normalisation, ~47 fichiers sortent en faux ROUGE (`PRG_04` brut = a50024aa… contre "
                    "31760d59… pour git). L'outil affiche les deux valeurs plutôt que de trancher en silence."),
         "source": "mesure 7e constat + mesure propre du lot (voir PREUVE_T353.md §P4)"},
        {"id": "L5", "gravite": "MAJEUR", "titre": "Un code Mnn/Cnn n'a de sens qu'avec son document",
         "detail": ("L'annexe réutilise C02/C03 pour des objets de PRG_03 alors que T334 définit C02 comme "
                    "l'instance `instCycleSemiAuto` appelée `PRG_03:190`. L'outil ne compare jamais deux codes "
                    "de documents différents et affiche toujours le document d'origine."),
         "source": "constat n°4 du cadrage ; annexe §2.2"},
        {"id": "L6", "gravite": "MINEUR", "titre": "Références non résolues et alias de contexte",
         "detail": ("Les alias `M1:`/`M2:`/`M3:` désignent un FB du contexte de section, pas un fichier de "
                    "l'index : ils sont classés AMBIGU, jamais devinés. Les références sans ancrage blob ne "
                    "peuvent pas être datées : elles sont affichées « non ancrable », jamais vertes."),
         "source": "contrat AC2 + 8e constat de cadrage"},
        {"id": "L7", "gravite": "MINEUR", "titre": "Ce que l'outil NE fait PAS",
         "detail": ("Il ne lit pas le contenu des lignes citées, ne vérifie pas que le motif annoncé est bien "
                    "à la ligne citée (seule la borne du fichier est contrôlée), ne corrige aucun document, "
                    "ne produit aucun bundle, ne mesure aucune fraîcheur en file://, et ne remplace pas la "
                    "lecture du code réel avant une intervention machine."),
         "source": "déclaration de limites du lot T353"},
    ]

    graphe = {
        "meta": {
            "outil": "T353 — CMD_PATH_VIEWER",
            "version": "1.0",
            "genere_le": maintenant,
            "head_mesure": head,
            "racine": ".",
            "source_unique": "3 documents de troubleshooting T351/T334 (LECTURE SEULE)",
            "doctrine": ("Ancrage par BLOB, jamais par HEAD ni par numéro de ligne ; un code Mnn/Cnn n'a de "
                         "sens qu'avec son document ; aucune référence devinée."),
            "hash_exact": "SHA1(\"blob \" + taille_apres_normalisation_CRLF + \"\\0\" + contenu_normalisé_CRLF)",
        },
        "documents": [
            {"id": d["id"], "chemin": d["chemin"], "titre": d["titre"], "lignes_totales": d["lignes_totales"],
             "chaines": d["chaines"], "ancrage": d["ancrage"], "tableaux": d["tableaux"]}
            for d in docs.values()
        ],
        "chaines": [c for d in docs.values() for c in d["chaines"]],
        "maillons": maillons,
        "complements": complements,
        "ancrage": {
            "head_documents": {d: docs[d]["ancrage"]["head_document"] for d in docs},
            "horodatages_documents": {d: docs[d]["ancrage"]["horodatage_mesure"] for d in docs},
            "head_mesure_generation": head,
            "blobs": sorted(fichiers.values(), key=lambda e: e["chemin"]),
            "nb_fichiers": len(fichiers),
            "blobs_avec_ancrage": len([e for e in fichiers.values() if e["sources"]]),
            "blobs_derives_seulement": len([e for e in fichiers.values() if e["ancrage_derive"]]),
            "blobs_sans_ancrage": len([e for e in fichiers.values() if e["sans_ancrage"]]),
            "conflits": conflits,
        },
        "corrections_references_perimees": [x for d in docs.values() for x in d["corrections_references_perimees"]],
        "corrections_meta": {
            "source": "annexe §4.10 « Table de correction des références périmées » (tableau 3 colonnes)",
            "statut": "TABLE_CORRECTION_NON_FUSIONNEE — jamais fusionnée dans les maillons",
            "entete": next((d["corrections_entete"] for d in docs.values() if d["corrections_entete"]), None),
            "ancrage_declare": next((d["corrections_ancre_head"] for d in docs.values()
                                     if d["corrections_ancre_head"]), None),
            "avertissement": ("les « valeurs correctes » de cette table ont été mesurées par l'annexe sur "
                              "un HEAD ANTÉRIEUR (" + str(next((d["corrections_ancre_head"] for d in docs.values()
                                                                if d["corrections_ancre_head"]), "—")) +
                              "). HEAD a bougé depuis (" + head[:8] + ") et des fichiers cités ont changé de "
                              "blob : ces corrections sont INDICATIVES et doivent être re-vérifiées par blob "
                              "avant usage — même doctrine que partout ailleurs dans cet outil."),
        },
        "gestes": gestes,
        "familles": familles,
        "divergences": [x for d in docs.values() for x in d["divergences"]],
        "asymetries": [x for d in docs.values() for x in d["asymetries"]],
        "limites": limites,
        "rapport_parsing": rapport,
        "rapport_resolution": resolution,
        "audit_references": audit_global(idx, alias_actifs),
        "index_resolution": {
            "fichiers_indexes": len(idx.tous),
            "exclus": {"prefixes": list(PREFIXES_EXCLUS), "nb_exclus": len(idx.exclus)},
            "tiers": {nom: len(v) for nom, v in idx.stems_tier.items()},
            "fichiers_par_tier": {nom: sum(len(v) for v in idx.stems_tier[nom].values())
                                  for nom, _ in idx.tiers},
            "note_tiers": "`tiers` = nombre de NOMS DÉCLARÉS distincts (stems) ; `fichiers_par_tier` = nombre de chemins",
            "chemins_declares_ancrage": sorted(idx.chemins_declares),
            "regles": ["A_CHEMIN_EXACT", "B_CHEMIN_DECLARE_ANC", "C_BASENAME_UNIQUE_TIER",
                       "D_STEM_UNIQUE_TIER", "E_ALIAS_DOCUMENTE_CITE", "AMBIGU", "NON_RESOLUE",
                       "ALIAS_CONTEXTE_Mnn_Cnn", "ALIAS_CONTEXTE_Mnn_Cnn_NON_DOCUMENTE"],
        },
        "alias_documentes": sorted(alias_actifs.values(), key=lambda a: a["alias"]),
        "ecarts_alias": ecarts_alias,
    }

    # ── auto-controle des invariants + compteur hors bornes TOUTES ZONES ───────────────────
    # La zone d'AUDIT (toutes occurrences des 3 documents) et la table de CORRECTION §4.10 sont
    # INCLUSES dans le contrôle, alors que leurs listes détaillées sont bornées à l'export.
    audit_complet = graphe["audit_references"].pop("_refs_complets", [])
    audit_refs_complets = [(src, r) for src, r in audit_complet]
    corrections_refs = [("corrections:%s" % x.get("code"), r)
                        for x in graphe["corrections_references_perimees"]
                        for cle in ("refs_anciennes", "refs_corrigees") for r in x.get(cle, [])]
    toutes_zones = [(m.get("id") or ("%s/%s" % (m["document"], m["code"])), "maillon", r)
                    for m in maillons + complements for r in m.get("refs", [])]
    for cle in ("divergences", "asymetries", "familles"):
        for x in graphe.get(cle, []):
            for r in x.get("refs", []):
                toutes_zones.append(("%s:%s" % (cle, x.get("id")), cle, r))
    graphe["rapport_resolution"]["refs_hors_bornes_toutes_zones"] = sum(
        1 for _, _, r in toutes_zones if r.get("lignes_hors_bornes"))
    graphe["rapport_resolution"]["refs_controlees_toutes_zones"] = len(toutes_zones)
    graphe["rapport_resolution"]["refs_contestees_detail"] = [
        {"maillon": src, "zone": zone, "champ": r["champ"], "brut": r["brut"],
         "ligne_document": r.get("ligne_document"), "lignes_hors_bornes": r.get("lignes_hors_bornes"),
         "antecedent_ecarte": r.get("antecedent_ecarte"), "chemin_resolu_ecarte": r.get("chemin_resolu_ecarte"),
         "candidats_examines": r.get("candidats", []), "motif": r.get("motif")}
        for src, zone, r in toutes_zones if r["categorie"] == "CONTESTEE_HORS_BORNES"]
    graphe["rapport_resolution"]["refs_reroutees_detail"] = [
        {"maillon": src, "zone": zone, "champ": r["champ"], "brut": r["brut"],
         "ligne_document": r.get("ligne_document"), "antecedent_ecarte": r.get("antecedent_ecarte"),
         "chemin_resolu": r["chemin_resolu"], "note": r.get("note"),
         "candidats_examines": r.get("candidats", []), "motif": r.get("motif")}
        for src, zone, r in toutes_zones
        if r.get("regle") in ("E_CONTINUATION_HORS_BORNES_REROUTAGE",
                              "E_CONTINUATION_HORS_BORNES_AUTRE_FICHIER_CELLULE")]
    graphe["controle_invariants"] = verifier_invariants(graphe, audit_refs_complets + corrections_refs)
    graphe["controle_attendus"] = verifier_attendus(graphe)
    (DATA / "graph.json").write_text(json.dumps(graphe, ensure_ascii=False, indent=1),
                                     encoding="utf-8", newline="\n")
    (DATA / "graph.js").write_text(
        "/* GÉNÉRÉ par parse_cartographies.py — ne pas éditer à la main.\n"
        "   Embarqué en global pour que le mode statique (file://) ne fasse AUCUNE requête. */\n"
        "window.CMD_PATH_VIEWER_GRAPH = " + json.dumps(graphe, ensure_ascii=False) + ";\n",
        encoding="utf-8", newline="\n")

    _rapport_console(rapport, resolution, graphe)
    ci = graphe["controle_invariants"]
    print()
    print("=" * 78)
    print("AUTO-CONTRÔLE DES INVARIANTS")
    print("=" * 78)
    for inv in ci["invariants"]:
        print("   ", inv)
    print(f"    références contrôlées : {ci['refs_controlees']} · violations : {ci['total_violations']}"
          f" · verdict : {ci['verdict']}")
    print(f"    zones couvertes par l'auto-contrôle : {' + '.join(ci.get('zones_couvertes', []))}")
    print(f"    hors bornes — graphe (maillons+compléments) : {resolution['refs_hors_bornes']}"
          f" · graphe élargi : {graphe['rapport_resolution']['refs_hors_bornes_toutes_zones']}"
          f" (sur {graphe['rapport_resolution']['refs_controlees_toutes_zones']} références de graphe)"
          f" · ensemble contrôlé : {ci['refs_controlees']} références")
    ca = graphe["controle_attendus"]
    print()
    print("=" * 78)
    print("VERROU DES ATTENDUS DE RÉSOLUTION (valeurs de la revue, vérifiées dans les fiches)")
    print("=" * 78)
    for a in ca["attendus"]:
        print(f"    {'OK  ' if a['pass_'] else 'FAIL'} {a['maillon']} {a['brut']:12} "
              f"→ {str(a['obtenu'])[-52:]:54} [{a['forme_antecedent']}]")
    print(f"    conformes : {ca['conformes']}/{ca['total']} · verdict : {ca['verdict']}")
    if ca["verdict"] != "PASS" or ci["verdict"] != "PASS":
        print("    ⛔ ÉCART D'INVARIANT OU D'ATTENDU :", json.dumps(
            {"invariants": ci["violations"], "attendus": [a for a in ca["attendus"] if not a["pass_"]]},
            ensure_ascii=False)[:1500])
        return 1
    return 0


def _codes_attendus(lettre: str) -> list[str]:
    n = 66 if lettre == "M" else 35
    return [f"{lettre}{i:02d}" for i in range(1, n + 1)]


def _echantillon(refs: list[dict], n: int) -> list[dict]:
    out = []
    for r in refs[:n]:
        out.append({"brut": r["brut"], "token": r.get("fichier_token"), "regle": r["regle"],
                    "candidats": r["candidats"][:8], "regle_nb": len(r["candidats"])})
    return out


def _rapport_console(rapport: dict, resolution: dict, graphe: dict) -> None:
    print("=" * 78)
    print("P1 — TAUX DE PARSING")
    print("=" * 78)
    for doc_id, d in rapport["par_document"].items():
        print(f"  {doc_id:8} chaîne acceptée {d['lignes_chaine_acceptees']:3} / candidates {d['lignes_candidates_Mnn_Cnn']:3}"
              f" (codes {d.get('codes_candidats_occurrences'):3})  taux_chaine {d['taux_chaine']}"
              f"  taux_global {d['taux_global']}  rejets {len(d['rejets'])}"
              f"  compléments {d['complements_non_fusionnes']}"
              f"  hors-candidats {d.get('lignes_non_candidates_hors_audit', 0)}")
        for l, c in d["par_chaine"].items():
            print(f"      chaîne {l} : {c['nb']:3} maillons  contigu={c['contigu']}  doublons={c['doublons']}"
                  f"  sans_ref={len(c['sans_reference'])}")
    print("  TOTAUX :", json.dumps(rapport["totaux"], ensure_ascii=False))
    print(f"  rejets par motif : "
          f"{ {m: sum(1 for r in rapport['rejets'] if r['motif'] == m) for m in sorted({r['motif'] for r in rapport['rejets']})} }")
    print()
    print("=" * 78)
    print("P2 — RÉSOLUTION DES RÉFÉRENCES")
    print("=" * 78)
    print("  global :", json.dumps(resolution["par_categorie"], ensure_ascii=False),
          " total =", resolution["refs_totales"],
          " fichiers distincts =", resolution["fichiers_distincts_resolus"])
    for f, v in resolution["par_forme"].items():
        print(f"    forme {f:14} total {v['total']:4}  résolues {v['RESOLUE']:4}  ambiguës {v['AMBIGUE']:4}"
              f"  non résolues {v['NON_RESOLUE']:4}  (listes {v['liste']})")
    for doc_id, v in resolution["par_document"].items():
        print(f"    {doc_id:8} refs {v['refs']:4}  R {v['RESOLUE']:4} / A {v['AMBIGUE']:3}"
              f" / NR {v['NON_RESOLUE']:3} / CONTESTÉES {v['CONTESTEE_HORS_BORNES']:3}"
              f"  fichiers {v['fichiers_distincts']:3}  courtes {v['refs_courtes']:3}")
    print(f"  références CONTESTÉES (couple fichier:ligne impossible) : {resolution['refs_hors_bornes']}"
          f" · reroutées par la règle E_CONTINUATION_HORS_BORNES_REROUTAGE : "
          f"{len(resolution['refs_reroutees_detail'])}")
    print("  règles :", json.dumps(resolution["par_regle"], ensure_ascii=False))
    ag = graphe["audit_references"]
    print()
    print("  AUDIT GLOBAL (toutes zones des 3 documents — 9e constat) :")
    for doc_id, d in ag["par_document"].items():
        print(f"    {doc_id:8} occurrences {d['occurrences']:4}  tokens-fichier {d['occurrences_avec_token_fichier']:4}"
              f"  continuations {d['occurrences_continuation']:4}  | préfixe unique {len(d['prefixe_unique']):4}"
              f"  ambigu {len(d['prefixe_ambigu']):3}  alias curé {len(d['alias_contexte_cure']):3}"
              f"  alias NON résolu {len(d['alias_non_resolue']):3}  sans match {len(d['prefixe_sans_match']):3}"
              f"  troncature {len(d['troncature_ou_nom_introuvable']):2}")
    print("    TOTAUX :", json.dumps(ag["totaux"], ensure_ascii=False))
    print("    contrôle anti-invention (chemins de type M1.st/PRG_04.st) :",
          json.dumps(ag["controle_anti_invention"], ensure_ascii=False))
    print()
    print("=" * 78)
    print("ANCRAGE")
    print("=" * 78)
    a = graphe["ancrage"]
    print(f"  fichiers cités avec ancrage : {a['blobs_avec_ancrage']}  (dérivés seuls : {a['blobs_derives_seulement']},"
          f" sans ancrage : {a['blobs_sans_ancrage']}, total {a['nb_fichiers']})  conflits : {len(a['conflits'])}")
    for d, anc in [(x["id"], x["ancrage"]) for x in graphe["documents"]]:
        print(f"  {d:8} ancrage={anc['statut']:7} head={str(anc['head_document'])[:12]:12} "
              f"horodatage={anc['horodatage_mesure']} fichiers={anc['nb_fichiers_declares']}")
    print()
    gestes_ko = [g["id"] for g in graphe["gestes"] if not g["citation_verifiee"]]
    print(f"GESTES : {len(graphe['gestes'])} entrées · citations non vérifiées : {gestes_ko or 'aucune'}")
    print(f"LIMITES déclarées : {len(graphe['limites'])}")
    print(f"Écrit : {DATA/'graph.json'} et {DATA/'graph.js'}")


if __name__ == "__main__":
    sys.exit(main())
