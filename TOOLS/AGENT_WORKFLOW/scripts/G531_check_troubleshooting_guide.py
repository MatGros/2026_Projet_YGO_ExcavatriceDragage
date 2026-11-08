#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""G531 - Guide de depannage FB_TroubleshootingGuide : chemins vivants, structure, texte de fonctionnement.

Controles :
  1. Le FB existe, en contrat light, et ne contient qu'une ligne de code : Ready := Enable;
  2. Il est instancie et appele par PRG_07_Supervision.
  3. Sommaire et sections §0 a §6 presents ; les 10 etapes dans l'ordre pour M1, M2, M3.
  4. Toute variable citee existe dans la liste du snapshot et se resout dans les declarations ST.
  5. Corps en commentaires // uniquement (aucun commentaire bloc), sans date, nom de tache ni REX.

Usage : python G531_check_troubleshooting_guide.py [--guide <fichier.st>]
Code retour 1 si un controle echoue.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CODE = ROOT / "CODE"
GUIDE = CODE / "J_SUPERVISION" / "FB_TroubleshootingGuide.st"
PRG07 = CODE / "M_MAIN" / "PRG_07_Supervision.st"
LISTE = ROOT / "TOOLS" / "PLC_CSV_SNAPSHOT" / "variable_lists" / "troubleshooting_variables.txt"
PREFIX = "GVL_Troubleshooting."
ROOTS = ("GVL_Troubleshooting", "GVL_IHM", "PRG_02_Acquisition", "PRG_03_Modes_Cycle", "PRG_04_Treuils_Benne",
         "PRG_05_Translation", "PRG_06_Outputs", "PRG_07_Supervision")
GROUPS = r"[A-T]_[A-Za-z0-9]+"
PATH_RE = re.compile(r"\b(?:(?:%s)\.|%s\.)[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*" % ("|".join(ROOTS), GROUPS))
DECL = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:AT\s+%\S+\s*)?:\s*(?:ARRAY\s*\[[^\]]*\]\s*OF\s*)?([A-Za-z_][\w.]*)", re.I)
HEAD = re.compile(r"^\s*(?:\{[^}]*\}\s*)*(PROGRAM|FUNCTION_BLOCK|TYPE|VAR_GLOBAL)\b\s*(?:(?:ABSTRACT|FINAL|PUBLIC|INTERNAL)\s+)*([A-Za-z_]\w*)?(?:\s+EXTENDS\s+([A-Za-z_]\w*))?", re.I)
KW = {"VAR", "VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT", "VAR_TEMP", "VAR_STAT", "VAR_INST", "END_VAR", "STRUCT",
      "END_STRUCT", "END_TYPE", "TYPE", "CONSTANT", "RETAIN", "PERSISTENT"}


def build_scopes() -> tuple[dict, dict]:
    scopes: dict[str, dict] = {}
    parent: dict[str, str] = {}
    for f in CODE.rglob("*.st"):
        cur = None
        for raw in f.read_text(encoding="utf-8", errors="replace").splitlines():
            line = re.sub(r"//.*|\(\*.*?\*\)", "", raw)
            m = HEAD.match(line)
            if m:
                name = f.stem if m.group(1).upper() == "VAR_GLOBAL" else m.group(2)
                if name:
                    cur = name
                    scopes.setdefault(cur, {})
                    if m.group(3):
                        parent[cur] = m.group(3)
                continue
            if cur is None:
                continue
            if re.match(r"^\s*(METHOD|PROPERTY|ACTION)\b", line, re.I):
                cur = None
                continue
            d = DECL.match(line)
            if d and d.group(1).upper() not in KW:
                scopes[cur].setdefault(d.group(1), d.group(2))
    return scopes, parent


def resolve(path: str, scopes: dict, parent: dict) -> str | None:
    seg = path.split(".")
    if seg[0] not in scopes:
        return "racine inconnue " + seg[0]
    t = seg[0]
    for s in seg[1:]:
        members: dict = {}
        cur = t
        while cur:
            members = {**scopes.get(cur, {}), **members}
            cur = parent.get(cur)
        if s not in members:
            return "membre absent %s dans %s" % (s, t)
        t = members[s]
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--guide", type=Path, default=GUIDE)
    args = ap.parse_args()
    errors: list[str] = []
    if not args.guide.exists():
        print("[ERROR] guide absent : %s" % args.guide)
        return 1
    text = args.guide.read_text(encoding="utf-8")
    lines = text.splitlines()

    # 1. Contrat light et code reduit a une ligne
    if not re.search(r"^\s*Enable\s*:\s*BOOL\s*;", text, re.M) or not re.search(r"^\s*Ready\s*:\s*BOOL\s*;", text, re.M):
        errors.append("contrat light incomplet : Enable et Ready attendus")
    end_decl = max(i for i, l in enumerate(lines) if l.strip().upper() == "END_VAR")
    code = [l.strip() for l in lines[end_decl + 1:] if l.strip() and not l.strip().startswith("//")
            and not re.match(r"^\{(region|endregion)\b", l.strip())]
    if code != ["Ready := Enable;"]:
        errors.append("le corps doit contenir une seule ligne de code 'Ready := Enable;' : %s" % code[:3])

    # 2. Instanciation et appel par PRG_07
    prg = PRG07.read_text(encoding="utf-8", errors="replace")
    inst = re.search(r"^\s*(\w+)\s*:\s*FB_TroubleshootingGuide\s*;", prg, re.M)
    if not inst or not re.search(r"^\s*%s\s*\(" % inst.group(1), prg, re.M):
        errors.append("FB_TroubleshootingGuide non instancie ou non appele dans PRG_07_Supervision")

    # 3. Structure
    body = "\n".join(lines[end_decl + 1:])
    for n in ("§0", "§1", "§2", "§3", "§4", "§5", "§6"):
        if not re.search(r'\{region "%s ' % n, body):
            errors.append("section %s absente" % n)
    if "SOMMAIRE" not in body:
        errors.append("sommaire absent")
    for n, axe in (("§2", "M1"), ("§3", "M2"), ("§4", "M3")):
        m = re.search(r'\{region "%s .*?\{endregion\}' % n, body, re.S)
        steps = [int(x) for x in re.findall(r"Étape (\d+) ·", m.group(0))] if m else []
        if steps != list(range(1, 11)):
            errors.append("axe %s : etapes %s au lieu de 1 a 10 dans l'ordre" % (axe, steps))

    # 4. Chemins vivants
    liste = set(LISTE.read_text(encoding="ascii").split())
    scopes, parent = build_scopes()
    cited = sorted({p.rstrip(".") for p in PATH_RE.findall(body)})
    for p in cited:
        full = p if p.split(".")[0] in ROOTS else PREFIX + p
        if full not in liste:
            errors.append("chemin hors liste du snapshot : %s" % full)
        why = resolve(full, scopes, parent)
        if why:
            errors.append("chemin non resolu dans le code : %s (%s)" % (full, why))

    # 4bis. Noms abreges (sans groupe) : chaque IdxNNN_Nom cite doit exister comme feuille dans la liste
    leaves = {x.rsplit(".", 1)[-1] for x in liste}
    for tok in sorted(set(re.findall(r"(?<![\w.])Idx\d{3}_[A-Za-z0-9_]+", body))):
        if tok not in leaves:
            errors.append("nom abrege inconnu de la liste du snapshot : %s" % tok)

    # 5. Texte de fonctionnement
    if "(*" in body or "*)" in body:
        errors.append("commentaire bloc dans le corps : // uniquement")
    for pat, what in ((r"\b20\d\d-\d\d-\d\d\b", "date"), (r"\bT\d{3}\b", "nom de tache"), (r"\bREX\b", "REX")):
        if re.search(pat, body):
            errors.append("%s interdit dans le guide : %s" % (what, re.search(pat, body).group(0)))

    for e in errors:
        print("[ERROR] " + e)
    print("G531 guide de depannage : %s (%d chemins cites, %d erreur(s))" % ("PASS" if not errors else "FAIL", len(cited), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
