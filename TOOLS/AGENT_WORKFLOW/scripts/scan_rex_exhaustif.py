#!/usr/bin/env python3
"""Scan exhaustif des commentaires REX / journal intime dans CODE/*.st.

Plus large que le gate G430 : détecte aussi les faux négatifs (ajoutées, demande
utilisateur, récits de correctif, etc.). Usage : python scan_rex_exhaustif.py
"""
import re, sys
from pathlib import Path

# Patterns REX larges
HARD = re.compile(
    r"\b(?:T\d{2,3}|L\d|MES-\d+|Fiche\s+\d+|REX|WINCH-CORE|TASK-\d+)\b"
    r"|demande\s+(?:client|utilisateur)"
    r"|correctif|corrigé|corrigée"
    r"|\(20\d\d-\d\d\)|2026-\d\d"
    r"|avant\s+ce\s+lot|avant\s+Fiche|lot\s+précédent"
    r"|\(9\)|\(10\)|\(14\)|\(18\)|\(18bis\)|\(21bis\)|\(25\)|\(26\)|\(27\)|\(4\)"
)
SOFT = re.compile(
    r"\b(?:ajouté|ajoutée|ajoutés|ajoutées|supprimé|supprimée|supprimés|supprimées|"
    r"renommé|renommée|déplacé|déplacés|déplacée|rapatrié|rapatriés|orphelin|orphelines)\b"
    r"|ex-[A-Za-z]|FIX\s*:"
    r"|n'était|n'étaient|restait|restaient|faisait|faisaient|était|étaient"
    r"|n'a\s+visiblement\s+pas\s+suffi|ne\s+matchait|jamais\s+appelée|jamais\s+câblé"
    r"|comportement\s+identique\s+à\s+avant|avant\s+ce\s+lot"
)

def extract_comments(text):
    comments = []
    i, n, in_str = 0, len(text), False
    while i < n:
        c = text[i]
        if c == "'":
            in_str = not in_str; i += 1; continue
        if in_str:
            i += 1; continue
        if text.startswith("(*", i):
            end = text.find("*)", i+2)
            if end == -1: end = n
            comments.append((text[:i].count("\n")+1, text[i+2:end]))
            i = end+2; continue
        if text.startswith("//", i):
            end = text.find("\n", i+2)
            if end == -1: end = n
            comments.append((text[:i].count("\n")+1, text[i+2:end]))
            i = end; continue
        i += 1
    return comments

root = Path("CODE")
total = 0
for st in sorted(root.rglob("*.st")):
    text = st.read_text(encoding="utf-8")
    hits = []
    for ln, cm in extract_comments(text):
        for m in HARD.finditer(cm):
            hits.append((ln, "HARD", m.group(0), cm.strip()[:80]))
        for m in SOFT.finditer(cm):
            hits.append((ln, "soft", m.group(0), cm.strip()[:80]))
    if hits:
        print(f"=== {st} ({len(hits)}) ===")
        for ln, kind, pat, snip in hits:
            print(f"  L{ln} [{kind}:{pat}] {snip}")
        total += len(hits)
print(f"\nTOTAL: {total} hits")
