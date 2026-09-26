# -*- coding: utf-8 -*-
"""
Inventaire MECANIQUE des transitions du GRAFCET semi-auto.

Compare :
  - les transitions DECLAREES dans le GEL (DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md,
    lignes de tableau « | **AT<step>** | ... -> **AX<n>** | »)
  - les transitions CODEES dans CODE/G_CYCLE/FB_CycleSemiAuto.st
    (affectations `State := E_AutoCycleStep.X`, rattachees au `CASE` courant)

Sortie : tableau source -> cible + verdict (CONFORME / NON DECLAREE / SAUT ARRIERE).
Lecture seule stricte : aucun fichier n'est modifie.
"""
import io
import re

CODE = "CODE/G_CYCLE/FB_CycleSemiAuto.st"
GEL = "DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md"

# --- 1. GEL : transitions declarees -------------------------------------------------
gel = io.open(GEL, encoding="utf-8", errors="replace").read()
declarees = {}  # (source_step, cible) -> ligne GEL
courant = None
for n, ligne in enumerate(gel.split("\n"), 1):
    m = re.match(r"\|\s*\*\*(AX[0-9A-Z_]+)\*\*\s*\((\d+)\)", ligne)
    if m:
        courant = m.group(1)
        continue
    m = re.match(r"\|\s*\*\*(AT[0-9A-Za-z_\-]+)\*\*", ligne)
    if m:
        cible = re.search(r"\*\*(AX[0-9A-Z_]+)\s*(\*\*|\()", ligne)
        if courant and cible:
            declarees[(courant, cible.group(1))] = n

# --- 2. CODE : transitions codees --------------------------------------------------
src = io.open(CODE, encoding="utf-8", errors="replace").read().split("\n")
step = None
codees = []  # (ligne, source, cible)
for n, ligne in enumerate(src, 1):
    m = re.match(r"\s*E_AutoCycleStep\.(AX[0-9A-Z_]+)\s*:", ligne)
    if m:
        step = m.group(1)
        continue
    for c in re.finditer(r"State\s*:=\s*E_AutoCycleStep\.(AX[0-9A-Z_]+)", ligne):
        codees.append((n, step or "?", c.group(1)))

print("=" * 90)
print("TRANSITIONS DECLAREES AU GEL : %d" % len(declarees))
print("TRANSITIONS CODEES (State := AX...) : %d" % len(codees))
print("=" * 90)
print("%-6s %-26s %-26s %s" % ("LIGNE", "SOURCE (etape courante)", "CIBLE", "VERDICT"))
print("-" * 90)
hors, arriere = 0, 0
for n, s, c in codees:
    if s == c:
        verdict = "AUTO (init/reinit)"
    elif (s, c) in declarees:
        verdict = "CONFORME AU GEL (L%d)" % declarees[(s, c)]
    else:
        verdict = "*** NON DECLAREE AU GEL ***"
        hors += 1
        ms = re.match(r"AX(\d+)", s)
        mc = re.match(r"AX(\d+)", c)
        if ms and mc and int(mc.group(1)) < int(ms.group(1)):
            verdict += "  <<< SAUT ARRIERE"
            arriere += 1
    print("%-6d %-26s %-26s %s" % (n, s, c, verdict))
print("-" * 90)
print("RESULTAT : %d transition(s) NON declaree(s) au GEL, dont %d SAUT(S) ARRIERE" % (hors, arriere))
print("=" * 90)
print("(lecture seule : aucun fichier modifie)")
