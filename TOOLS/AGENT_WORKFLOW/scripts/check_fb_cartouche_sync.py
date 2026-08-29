#!/usr/bin/env python3
"""Etat de synchronisation des cartouches d'en-tete des FB_*.st avec leur fiche AF.

Pour chaque ``CODE/**/FB_*.st`` (glob recursif), lit le bloc de commentaire
d'en-tete ``(* ... *)`` et en extrait :

  - ``pou_name`` : le ``FUNCTION_BLOCK <Nom>`` reel du fichier (source de verite).
  - ``emoji`` + nom affiche : ligne ``   <emoji> FB_Xxx  Titre court`` du cartouche.
  - ``role``  : 1re phrase de la ligne ``   <emoji> Role : <texte>`` (ou variante
    ``Responsabilite`` / ``Invariant`` ...). Coupee au premier ``.`` ou fin de ligne.
    Seule la ligne portant le marqueur est lue ; les lignes de continuation
    indentees en dessous sont ignorees.
  - ``doc_pointer`` : chemin ``.md`` de la ligne ``   <emoji> Doc metier : <chemin>``
    (ou ``Doc :``). ``None`` si absente.

Si ``doc_pointer`` vise un ``.md`` sous ``DOC/`` :

  - ``fiche_existe`` : le fichier existe sur disque.
  - ``nom_match``  : le H1 de la fiche (``# ...``) contient ``pou_name``.
  - ``role_match`` : la section Role de la fiche (heading ``## ... Role`` /
    ``## N  Role``) contient, sous forme normalisee, le ``role`` normalise du .st.

  - ``statut`` :
      * ``synced``     si (fiche_existe ET nom_match ET role_match)
      * ``drift``      si doc_pointer + fiche presente mais un des deux match echoue
      * ``no_fiche``   si doc_pointer present mais fichier absent
      * ``no_pointer`` si aucun doc_pointer dans le cartouche

--- NORMALISATION (choix a valider par l'orchestrateur, cf. alert_duty T089) ---
``_normalize(s)`` applique, dans l'ordre :
  1. suppression du balisage Markdown leger : backticks, ``**gras**``, ``<tag>``,
     ``[texte](url)`` -> ``texte`` ;
  2. minuscules ;
  3. repliage des accents (NFKD + suppression des diacritiques) ->
     ``executions`` == ``exEcutions`` ;
  4. espaces compactes (tout run d'espaces/nbsp/tab/newline -> un espace) ;
  5. ponctuation de fin retiree ( . , ; : ! ? tirets em/en ).
``role_match`` teste ensuite : ``role_norm`` est une sous-chaine du texte
normalise de la section Role de la fiche. C'est volontairement permissif (le
role du .st est une paraphrase courte du role de la fiche). Comparaison connue
comme fragile (ponctuation, reformulation) -> ne PAS durcir en silence, remonter.

Sortie : ``TOOLS/AGENT_WORKFLOW/config/fb_cartouche_sync.json``.
Code retour toujours 0 (informatif, ne bloque aucun gate).
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import Any

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
        sys.stderr.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except Exception:  # pragma: no cover - best effort
        pass

REPO_ROOT = Path(__file__).resolve().parents[3]
OUT_PATH = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "fb_cartouche_sync.json"

# --- Regex cartouche -------------------------------------------------------
# Ligne nom : "<emoji ...> FB_Xxx  Titre" (tiret em/en/simple entre nom et titre)
RE_NAME_LINE = re.compile(r"^\s*(?P<emoji>.*?)\s*(?P<name>FB_[A-Za-z0-9_]+)\s+[—–-]\s+(?P<title>.+?)\s*$")
RE_POU = re.compile(
    r"^\s*FUNCTION_BLOCK\s+(?:(?:PUBLIC|PRIVATE|INTERNAL|FINAL|ABSTRACT)\s+)*(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)
# Ligne role : un marqueur emoji puis "Role" / "Responsabilite" ... puis ":"
# (labels dubieux -- Invariant, Mot valide -- volontairement exclus : ce ne sont
#  pas le role du FB, cf. alert_duty T089 -> ne pas fabriquer de contenu de role)
RE_ROLE_LINE = re.compile(
    r"^\s*(?P<marker>\S+)\s*"
    r"(?P<label>R[oô]le et profil|R[oô]le|Responsabilit[eé])\s*:\s*"
    r"(?P<text>.+?)\s*$",
    re.IGNORECASE,
)
# Ligne doc : marqueur emoji puis "Doc metier" ou "Doc" puis ":" puis un chemin .md
RE_DOC_LINE = re.compile(r"Doc(?:\s+m[eé]tier)?\s*:\s*(?P<path>\S+\.md)", re.IGNORECASE)

RE_MD_H1 = re.compile(r"^#\s+(?P<txt>.+?)\s*$", re.MULTILINE)
RE_MD_ROLE_HEADING = re.compile(r"^#{2,3}\s+.*(?:r[oô]le|responsabilit)", re.IGNORECASE)
RE_MD_ANY_HEADING = re.compile(r"^#{1,6}\s+")


def _strip_markdown(text: str) -> str:
    text = re.sub(r"</?[a-zA-Z0-9]+(?:\s+[^>]*)?>", "", text)          # <tag>
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)               # [txt](url)
    text = re.sub(r"`([^`]+)`", r"\1", text)                           # `code`
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)                     # **bold**
    text = text.replace("`", "")
    return text


def _fold_accents(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def _normalize(text: str) -> str:
    """cf. docstring module : demarque -> minuscules -> sans accents -> espaces compactes -> sans ponctuation finale."""
    text = _strip_markdown(text)
    text = text.lower()
    text = _fold_accents(text)
    text = re.sub(r"\s+", " ", text).strip()
    text = text.strip(" .,;:!?—–-")
    return text


def _first_sentence(text: str) -> str:
    text = text.strip()
    # coupe a la premiere fin de phrase ". " ou "." final ; garde les "." internes de type "1.0"
    m = re.search(r"\.(?:\s|$)", text)
    if m:
        text = text[: m.start()]
    return text.strip()


def _header_block(lines: list[str]) -> tuple[int, int]:
    """Retourne (start_idx, end_idx) 0-based inclus du bloc commentaire d'en-tete, ou (-1,-1)."""
    start = -1
    for i, ln in enumerate(lines[:6]):
        if ln.lstrip().startswith("(*"):
            start = i
            break
    if start == -1:
        return -1, -1
    for j in range(start, min(len(lines), start + 60)):
        if "*)" in lines[j]:
            return start, j
    return start, min(len(lines) - 1, start + 59)


def _git_short_head() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_ROOT, capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except Exception:
        return "unknown"


def _iso_now_local() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def _extract_role_section(md_text: str) -> str:
    lines = md_text.splitlines()
    collecting = False
    buf: list[str] = []
    for ln in lines:
        if RE_MD_ROLE_HEADING.match(ln.strip()):
            collecting = True
            continue
        if collecting:
            if RE_MD_ANY_HEADING.match(ln.strip()):
                break
            buf.append(ln)
    return "\n".join(buf)


def analyze_fb(st_path: Path) -> dict[str, Any]:
    rel = st_path.relative_to(REPO_ROOT).as_posix()
    raw = st_path.read_text(encoding="utf-8", errors="replace")
    lines = raw.splitlines()

    pou_m = RE_POU.search(raw)
    pou_name = pou_m.group("name") if pou_m else st_path.stem

    h_start, h_end = _header_block(lines)
    header_lines = lines[h_start : h_end + 1] if h_start >= 0 else []
    header_offset = h_start if h_start >= 0 else 0

    emoji: str | None = None
    title: str | None = None
    role: str | None = None
    role_label: str | None = None
    doc_pointer: str | None = None
    st_line = 0
    doc_line: int | None = None

    for k, ln in enumerate(header_lines):
        lineno = header_offset + k + 1  # 1-based
        if title is None:
            m = RE_NAME_LINE.match(ln)
            if m and (m.group("name") == pou_name or m.group("name").startswith("FB_")):
                emoji = m.group("emoji").strip() or None
                title = m.group("title").strip()
                st_line = lineno
        if role is None:
            mr = RE_ROLE_LINE.match(ln)
            if mr:
                role_label = mr.group("label")
                role = _first_sentence(mr.group("text"))
        if doc_pointer is None:
            md = RE_DOC_LINE.search(ln)
            if md:
                doc_pointer = md.group("path")
                doc_line = lineno

    entry: dict[str, Any] = {
        "file": rel,
        "st_line": st_line,
        "pou_name": pou_name,
        "emoji": emoji,
        "title": title,
        "role": role,
        "role_label": role_label,
        "doc_pointer": doc_pointer,
        "doc_line": doc_line,
        "fiche_existe": None,
        "nom_match": None,
        "role_match": None,
        "statut": None,
    }

    if not doc_pointer:
        entry["statut"] = "no_pointer"
        return entry

    fiche_path = (REPO_ROOT / doc_pointer).resolve()
    is_under_doc = doc_pointer.replace("\\", "/").startswith("DOC/") and doc_pointer.endswith(".md")
    fiche_existe = is_under_doc and fiche_path.is_file()
    entry["fiche_existe"] = bool(fiche_existe)

    if not fiche_existe:
        entry["statut"] = "no_fiche"
        return entry

    md_text = fiche_path.read_text(encoding="utf-8", errors="replace")
    h1_m = RE_MD_H1.search(md_text)
    h1 = h1_m.group("txt") if h1_m else ""
    nom_match = _normalize(pou_name) in _normalize(h1)
    entry["nom_match"] = bool(nom_match)

    role_section_norm = _normalize(_extract_role_section(md_text))
    role_norm = _normalize(role) if role else ""
    role_match = bool(role_norm) and role_norm in role_section_norm
    entry["role_match"] = bool(role_match)

    entry["statut"] = "synced" if (nom_match and role_match) else "drift"
    return entry


def main() -> int:
    fb_files = sorted(
        (p for p in REPO_ROOT.glob("CODE/**/FB_*.st") if p.is_file()),
        key=lambda p: p.relative_to(REPO_ROOT).as_posix(),
    )
    entries = [analyze_fb(p) for p in fb_files]

    counts: dict[str, int] = {"synced": 0, "drift": 0, "no_fiche": 0, "no_pointer": 0}
    for e in entries:
        counts[e["statut"]] = counts.get(e["statut"], 0) + 1

    payload = {
        "generated_at": _iso_now_local(),
        "source_head": _git_short_head(),
        "counts": counts,
        "total": len(entries),
        "fb": entries,
    }
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    try:
        out_disp = OUT_PATH.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        out_disp = str(OUT_PATH)
    print(f"check_fb_cartouche_sync : {len(entries)} FB analyses -> {out_disp}")
    print(
        "  synced={synced}  drift={drift}  no_fiche={no_fiche}  no_pointer={no_pointer}".format(**counts)
    )
    for e in entries:
        if e["statut"] in ("drift", "no_fiche"):
            print(f"  [{e['statut']:9}] {e['pou_name']:<34} pointeur={e['doc_pointer']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
