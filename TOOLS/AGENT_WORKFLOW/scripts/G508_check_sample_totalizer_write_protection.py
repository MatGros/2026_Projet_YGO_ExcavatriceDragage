#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""G508 - Totalisateur de prelevements (T299) : ecriture UNIQUE, aucune RAZ, IHM lecture seule.

Invariant de surete operationnelle : le compteur TOTALISATEUR de prelevements
(`_CycleSampleCountTotal`, PERSISTENT) est de type "compteur kilometrique" — il ne doit
JAMAIS pouvoir etre remis a zero ni force, par quelque chemin que ce soit (IHM, code,
bypass, test). Il s'incremente au MEME evenement que le compteur journalier : la depose
a la tremie, etape AX18_DONE_SYNC de FB_CycleSemiAuto, une seule fois par cycle.

Controles (analyse textuelle, commentaires neutralises) :
  1. L'incrément dans FB_CycleSemiAuto.st est EXACTEMENT `SampleCountTotal := SampleCountTotal + 1;`,
     il n'existe qu'UNE seule affectation a `SampleCountTotal` dans tout le FB, et cet incrément
     est bien DANS la garde de front `IF NOT SampleCountDone THEN` ET dans la branche AX18_DONE_SYNC
     (preuve outillee de l'AC « meme evenement que le journalier »).
  2. Dans tout CODE/**, aucune affectation dont la cible se termine par `SampleCountTotal` hors des
     3 sites legitimes : incrément (FB), branchement VAR_IN_OUT (PRG_03), publication IHM (PRG_07).
     1 site = 1 fichier autorise : un 4e site, une RAZ (`:= 0`), un decrement ou un alias -> FAIL.
  3. La declaration est DANS le bloc `VAR_GLOBAL PERSISTENT RETAIN` de GVL_PERSISTENT.st (non
     volatile) et d'un type non debordant pour un compteur a vie (UDINT).
  4. Aucun champ nomme comme une commande de RAZ du totalisateur dans TOUT `CODE/` (pas
     seulement les DUT IHM) : `...Btn...Total`, `...Reset...Total`, `...Total...Reset`.
  5. Sur l'artefact EXPORTE (`CODE_XML/CODE_Bundle.xml`, s'il est present) : la liste des
     affectations au totalisateur est EXACTEMENT les 3 memes instructions — preuve que le
     programme reellement telecharge ne contient aucun chemin d'ecriture supplementaire.
  6. Aucun chemin d'ecriture INDIRECT par REFERENCE : une declaration `REFERENCE TO` /
     `REF_TO` dont le nom designe le totalisateur, une liaison `X REF= _CycleSampleCountTotal`,
     ou une ecriture par dereferencement `X^ := ...` sur un alias declare reference -> FAIL.
  7. Aucune liaison INDIRECTE du totalisateur : toute occurrence de `_CycleSampleCountTotal`
     hors des 3 sites legitimes (declaration persistante, branchement VAR_IN_OUT PRG_03,
     publication IHM PRG_07) -> FAIL. Toute nouvelle liaison (alias `VAR_IN_OUT`, argument
     d'appel de FB, reference) doit etre validee humainement puis ajoutee a la liste blanche :
     sans cela, une ecriture faite DANS le FB appele serait invisible au controle textuel.

Le gate embarque un auto-test du detecteur (jeux conformes et violants reellement detectes) :
un garde-fou qui ne sait pas detecter ne prouve rien.

Usage : python TOOLS/AGENT_WORKFLOW/scripts/G508_check_sample_totalizer_write_protection.py [racine]
Sortie : 0 si PASS, 1 si FAIL.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[3]

FB_CYCLE = "CODE/G_CYCLE/FB_CycleSemiAuto.st"
GVL_PERSISTENT = "CODE/GVL_PERSISTENT.st"
PRG_03 = "CODE/M_MAIN/PRG_03_Modes_Cycle.st"
PRG_07 = "CODE/M_MAIN/PRG_07_Supervision.st"
BUNDLE = "CODE_XML/CODE_Bundle.xml"

TOTAL_FIELD = "SampleCountTotal"          # membre d'interface du FB (VAR_IN_OUT)
TOTAL_GLOBAL = "_CycleSampleCountTotal"   # variable persistante (GVL_PERSISTENT)

BLOCK_COMMENT_RE = re.compile(r"\(\*.*?\*\)", re.DOTALL)
LINE_COMMENT_RE = re.compile(r"//.*$", re.MULTILINE)

INCREMENT = "SampleCountTotal := SampleCountTotal + 1;"
JOURNALIER_INCREMENT = "SampleCount := SampleCount + 1;"
GUARD = "IF NOT SampleCountDone THEN"
AX18_LABEL = "E_AutoCycleStep.AX18_DONE_SYNC:"
PERSISTENT_BLOCK = "VAR_GLOBAL PERSISTENT RETAIN"

# Les 3 seules instructions legitimes du totalisateur, en forme canonique.
STMT_INCREMENT = "SampleCountTotal := SampleCountTotal + 1"
STMT_BIND = "SampleCountTotal := _CycleSampleCountTotal"                                  # PRG_03
STMT_PUBLISH = "GVL_IHM.CycleSemiAuto.State.SampleCountTotal := _CycleSampleCountTotal"   # PRG_07

# 1 statement -> 1 seul fichier autorise (une copie ailleurs = un 4e site d'ecriture).
ALLOWED_BY_FILE = {
    FB_CYCLE: {STMT_INCREMENT},
    PRG_03: {STMT_BIND},
    PRG_07: {STMT_PUBLISH},
}
ALLOWED_STATEMENTS = {STMT_INCREMENT, STMT_BIND, STMT_PUBLISH}

# Tout champ dont le nom melange une commande/RAZ et le totalisateur est une porte d'ecriture.
CMD_FIELD_RE = re.compile(
    r"(?<![\w.])(\w*(?:Btn|Reset|Raz|Clear|Force)\w*Total\w*|\w*Total\w*(?:Btn|Reset|Raz|Clear))\s*:",
    re.IGNORECASE,
)

# ── Controles 6/7 — chemins d'ecriture INDIRECTS ────────────────────────────────────────
# Une reference (REFERENCE TO / REF_TO) est un pointeur : l'ecriture se fait au
# dereferencement (`p^ := ...`), donc la cible textuelle du `:=` n'est plus le totalisateur.
REF_DECL_RE = re.compile(r"(?<![\w.])(\w+)\s*:\s*(?:REFERENCE\s+TO|REF_TO)\b", re.IGNORECASE)
REF_BIND_RE = re.compile(rf"(?<![\w.])(\w+)\s*REF=\s*{re.escape(TOTAL_GLOBAL)}\b")
DEREF_WRITE_RE = re.compile(r"(?<![\w.])(\w+)\s*\^\s*:=")
OCCURRENCE_RE = re.compile(rf"(?<![\w.]){re.escape(TOTAL_GLOBAL)}\b")

# Les 3 seuls sites ou le TOTALISATEUR peut apparaitre, en forme canonique par fichier.
# Toute autre occurrence = une liaison potentiellement ecrivante (alias VAR_IN_OUT, argument
# d'appel de FB, reference) : FAIL, avec obligation de validation humaine de la liste blanche.
ALLOWED_OCCURRENCES = {
    GVL_PERSISTENT: {f"{TOTAL_GLOBAL} : UDINT := 0"},
    PRG_03: {f"{TOTAL_FIELD} := {TOTAL_GLOBAL}"},
    PRG_07: {f"GVL_IHM.CycleSemiAuto.State.{TOTAL_FIELD} := {TOTAL_GLOBAL}"},
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def strip_comments(source: str) -> str:
    """Neutralise // et (* *) en preservant les numeros de ligne."""
    source = BLOCK_COMMENT_RE.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), source)
    return LINE_COMMENT_RE.sub("", source)


def normalize(text: str) -> str:
    """Vue canonique : espaces internes reduits et ';' final retire (l'alignement des := ne
    doit pas faire echouer le gate)."""
    return re.sub(r"\s+", " ", text).strip().rstrip(";").strip()


def assignments_to(source: str, target: str) -> list[str]:
    """Toutes les affectations dont la CIBLE se termine par `target` (vue canonique).

    Capture la cible QUALIFIEE complete (`GVL_IHM.CycleSemiAuto.State.SampleCountTotal`)
    et l'expression affectee jusqu'au `;` ou a la virgule suivante (les arguments d'appel
    FB sont separes par des virgules, pas des points-virgules)."""
    pattern = re.compile(rf"((?:[A-Za-z_]\w*\.)*){re.escape(target)}\s*:=\s*([^;,]+)")
    return [normalize(f"{m.group(1)}{target} := {m.group(2)}") for m in pattern.finditer(source)]


def _index(source: str, needle: str, start: int = 0) -> int:
    """Position de `needle` a partir de `start`, ou -1 : jamais d'exception, l'appelant decide."""
    return source.find(needle, start)


def indirect_write_findings(rel: str, src: str) -> list[str]:
    """(6) chemins d'ecriture INDIRECTS par REFERENCE — commentaires deja neutralises.

    Trois formes violees :
      a. une liaison `X REF= _CycleSampleCountTotal` : X peut alors ecrire le totalisateur
         par simple dereferencement, hors de toute cible textuelle nommee ;
      b. une ecriture par dereferencement `X^ := ...` sur un alias declare reference
         (REFERENCE TO / REF_TO) : l'ecriture n'est decid able par aucune analyse de cible ;
      c. une declaration de reference dont le NOM designe le totalisateur (une reference
         nommee d'apres une donnee en lecture seule est un piege de maintenance).
    """
    findings: list[str] = []
    for m in REF_BIND_RE.finditer(src):
        findings.append(
            f"{rel}: le totalisateur est lie a la REFERENCE `{m.group(1)}` (REF=) — "
            "un dereferencement `^ :=` ecrirait le compteur hors de l'increment AX18"
        )
    # Perimetre PRECIS : seules les references REELLEMENT rattachees au totalisateur (liaison
    # REF=, ou nom designant le totalisateur). Une reference legitime vers une AUTRE donnee
    # n'est jamais signalee — un gate qui mord sur du code conforme est inutilisable.
    bound_refs = {m.group(1).upper() for m in REF_BIND_RE.finditer(src)}
    suspect_refs = {
        m.group(1).upper()
        for m in REF_DECL_RE.finditer(src)
        if TOTAL_FIELD.upper() in m.group(1).upper() or TOTAL_GLOBAL.upper() in m.group(1).upper()
    }
    for m in DEREF_WRITE_RE.finditer(src):
        name = m.group(1).upper()
        if name in bound_refs or name in suspect_refs:
            findings.append(
                f"{rel}: ecriture par dereferencement `{m.group(1)}^ :=` sur une reference "
                "rattachee au totalisateur — cible d'ecriture non tracable par son nom"
            )
    for name in sorted(suspect_refs):
        findings.append(
            f"{rel}: declaration d'une reference `{name}` nommee d'apres le totalisateur — "
            "une reference vers un compteur en LECTURE SEULE ne doit pas exister"
        )
    return findings


def totalizer_occurrences(src: str) -> list[str]:
    """Instructions canoniques contenant une occurrence du TOTALISATEUR (commentaires retires)."""
    found: list[str] = []
    for line in strip_comments(src).splitlines():
        if not OCCURRENCE_RE.search(line):
            continue
        stmt = normalize(line.rstrip(" \t,;"))
        if stmt:
            found.append(stmt)
    return found


def indirect_binding_findings(rel: str, src: str) -> list[str]:
    """(7) toute liaison du totalisateur hors des 3 sites legitimes -> FAIL.

    Capte les chemins qu'une recherche d'affectation nommee ne voit JAMAIS : alias
    `VAR_IN_OUT` passe en argument d'appel (`InstX(Tot := _CycleSampleCountTotal)`),
    affectation a un alias local, reference (controle 6), etc. Le nombre d'occurrences
    par site legitime est EXACTEMENT 1 : une duplication est aussi un signal.
    """
    findings: list[str] = []
    allowed = ALLOWED_OCCURRENCES.get(rel, set())
    for stmt in totalizer_occurrences(src):
        if stmt in allowed:
            continue
        findings.append(
            f"{rel}: liaison INDIRECTE du totalisateur hors des 3 sites legitimes -> {stmt} "
            "(alias VAR_IN_OUT, argument d'appel de FB ou reference : une ecriture faite DANS "
            "le POU appele serait invisible au controle textuel — validation humaine requise "
            "avant toute mise a jour de la liste blanche)"
        )
    counts: dict[str, int] = {}
    for stmt in totalizer_occurrences(src):
        if stmt in allowed:
            counts[stmt] = counts.get(stmt, 0) + 1
    for stmt, count in sorted(counts.items()):
        if count != 1:
            findings.append(f"{rel}: site legitime du totalisateur present {count} fois -> {stmt}")
    return findings


def check_fb(errors: list[str], fb_src: str) -> None:
    """(1) incrément unique, dans la garde de front ET dans la branche AX18."""
    fb_writes = assignments_to(fb_src, TOTAL_FIELD)
    if INCREMENT not in fb_src:
        errors.append(f"{FB_CYCLE}: increment exact '{INCREMENT}' introuvable")
    if len(fb_writes) != 1:
        errors.append(
            f"{FB_CYCLE}: {len(fb_writes)} affectation(s) a {TOTAL_FIELD} (attendu : 1, l'increment AX18) "
            f"-> {fb_writes}"
        )
    for write in fb_writes:
        if write != STMT_INCREMENT:
            errors.append(f"{FB_CYCLE}: affectation non conforme au totalisateur -> {write}")

    inc = _index(fb_src, INCREMENT)
    guard = _index(fb_src, GUARD)
    ax18 = _index(fb_src, AX18_LABEL)
    if inc < 0 or guard < 0 or ax18 < 0:
        errors.append(
            f"{FB_CYCLE}: repere introuvable (increment={inc}, garde='{GUARD}'={guard}, "
            f"etape '{AX18_LABEL}'={ax18}) — preuve 'meme evenement' impossible"
        )
        return

    # L'etape AX18 se termine au prochain libelle de CASE du Grafcet.
    next_label = _index(fb_src, "E_AutoCycleStep.", inc + 1)
    if not (ax18 < inc < (next_label if next_label > 0 else len(fb_src))):
        errors.append(
            f"{FB_CYCLE}: l'increment du totalisateur n'est PAS dans la branche de l'etape AX18 "
            "(AC3 'meme evenement' viole)"
        )
    end_if = _index(fb_src, "END_IF;", guard)
    guard_block = fb_src[guard:end_if] if end_if > guard else ""
    if inc > end_if > 0:
        errors.append(
            f"{FB_CYCLE}: l'increment du totalisateur est HORS de la garde de front '{GUARD}' "
            "(risque de comptage multiple par cycle)"
        )
    if JOURNALIER_INCREMENT not in guard_block:
        errors.append(
            f"{FB_CYCLE}: l'increment du JOURNALIER n'est pas dans la MEME garde que le totalisateur "
            "-> les deux compteurs ne comptent plus le meme evenement"
        )


def check_code_tree(errors: list[str]) -> None:
    """(2)+(4)+(6)+(7) aucun site d'ecriture, de liaison ni de champ de commande hors des
    3 sites legitimes."""
    seen: set[tuple[str, str]] = set()
    for path in sorted((ROOT / "CODE").rglob("*.st")):
        rel = path.relative_to(ROOT).as_posix()
        src = strip_comments(read(path))
        for write in assignments_to(src, TOTAL_FIELD):
            if write in ALLOWED_BY_FILE.get(rel, set()):
                seen.add((rel, write))
                continue
            errors.append(
                f"{rel}: ecriture du totalisateur hors increment AX18 -> {write} "
                "(aucune RAZ, aucun forcage, aucune commande IHM)"
            )
        for m in CMD_FIELD_RE.finditer(src):
            errors.append(
                f"{rel}: champ nomme comme une commande sur le totalisateur -> {m.group(1)} "
                "(aucune commande de RAZ ne doit exister)"
            )
        # (6)+(7) chemins INDIRECTS : reference, dereferencement, alias VAR_IN_OUT.
        errors.extend(indirect_write_findings(rel, src))
        errors.extend(indirect_binding_findings(rel, src))
    for rel, statements in sorted(ALLOWED_BY_FILE.items()):
        for stmt in sorted(statements):
            if (rel, stmt) not in seen:
                errors.append(f"branchement legitime absent (cable casse) -> {rel}: {stmt}")


def check_persistent_declaration(errors: list[str], gvl_raw: str) -> None:
    """(3) declaration DANS le bloc PERSISTENT et de type non debordant."""
    if PERSISTENT_BLOCK not in gvl_raw:
        errors.append(f"{GVL_PERSISTENT}: bloc '{PERSISTENT_BLOCK}' introuvable")
        return
    block = gvl_raw.split(PERSISTENT_BLOCK, 1)[1]
    block = block.split("END_VAR", 1)[0]
    decl = re.search(rf"^\s*{TOTAL_GLOBAL}\s*:\s*(\w+)", block, re.MULTILINE)
    if not decl:
        errors.append(
            f"{GVL_PERSISTENT}: {TOTAL_GLOBAL} n'est pas declare DANS le bloc "
            f"'{PERSISTENT_BLOCK}' (une declaration hors bloc n'est pas persistante)"
        )
        return
    if decl.group(1).upper() != "UDINT":
        errors.append(
            f"{GVL_PERSISTENT}: {TOTAL_GLOBAL} declare en {decl.group(1)} "
            "(UDINT attendu : un INT deborde en ~3 mois a 200..400 cycles/jour)"
        )


def check_bundle(errors: list[str]) -> None:
    """(5) l'artefact exporte ne contient que les 3 memes instructions."""
    path = ROOT / BUNDLE
    if not path.is_file():
        return  # bundle absent : rien a prouver ici (G390 verifie deja sa fraicheur)
    src = strip_comments(read(path))
    statements = assignments_to(src, TOTAL_FIELD)
    counts = {stmt: statements.count(stmt) for stmt in ALLOWED_STATEMENTS}
    for stmt, count in sorted(counts.items()):
        if count != 1:
            errors.append(f"{BUNDLE}: instruction legitime attendue 1 fois, trouvee {count} -> {stmt}")
    unexpected = [s for s in statements if s not in ALLOWED_STATEMENTS]
    for stmt in unexpected:
        errors.append(f"{BUNDLE}: ecriture du totalisateur dans l'artefact exporte -> {stmt}")


def selftest() -> list[str]:
    """Verifie que le detecteur n'est pas aveugle : chaque jeu violant DOIT etre detecte."""
    failures: list[str] = []

    # Conforme : une seule instruction, exactement l'increment attendu.
    ok = assignments_to(f"IF NOT Done THEN\n    {INCREMENT}\nEND_IF;", TOTAL_FIELD)
    if ok != [STMT_INCREMENT]:
        failures.append(f"auto-test detection conforme -> {ok}")

    # Violants : RAZ, decrement, second site d'ecriture (4e site).
    cases = {
        "RAZ du totalisateur": f"{TOTAL_FIELD} := 0;",
        "decrement": f"{TOTAL_FIELD} := {TOTAL_FIELD} - 1;",
        "cible qualifiee (GVL)": f"GVL_PERSISTENT.{TOTAL_GLOBAL} := 0;",
    }
    for label, sample in cases.items():
        found = assignments_to(sample, TOTAL_FIELD)
        if len(found) != 1 or found[0] == STMT_INCREMENT:
            failures.append(f"auto-test detection violante manquee ({label}) -> {found}")
    two_sites = assignments_to(f"{INCREMENT}\n{TOTAL_FIELD} := 7;", TOTAL_FIELD)
    if len(two_sites) != 2:
        failures.append(f"auto-test second site non detecte -> {two_sites}")

    # Le compteur journalier ne doit PAS etre confondu avec le totalisateur.
    if assignments_to("SampleCount := 0;", TOTAL_FIELD):
        failures.append("auto-test : le journalier est confondu avec le totalisateur")
    if assignments_to(f"{TOTAL_FIELD} := {TOTAL_FIELD} + 1;", "SampleCount"):
        failures.append("auto-test : le totalisateur est confondu avec le journalier")

    # Detecteur de champ de commande : doit mordre, et ne pas mordre sur le champ legitime.
    for label, sample in {
        "BtnResetSampleCountTotal": "BtnResetSampleCountTotal : BOOL;",
        "ResetTotalSampleCount": "ResetTotalSampleCount : BOOL;",
    }.items():
        if not CMD_FIELD_RE.search(sample):
            failures.append(f"auto-test champ de commande non detecte ({label})")
    if CMD_FIELD_RE.search("SampleCountResetMode : E_CycleSampleCountResetMode;"):
        failures.append("auto-test : faux positif sur SampleCountResetMode (champ legitime)")

    # ── Controles 6/7 : chemins d'ecriture INDIRECTS ────────────────────────────────────
    # Chaque forme violante DOIT etre detectee — c'est la seule preuve que le detecteur
    # n'est pas aveugle a ce qu'il pretend interdire.
    indirect_cases = {
        "REFERENCE TO lie au totalisateur (REF=)":
            f"pTot : REFERENCE TO UDINT;\npTot REF= {TOTAL_GLOBAL};",
        "ecriture par dereferencement de l'alias":
            f"pTot : REFERENCE TO UDINT;\npTot REF= {TOTAL_GLOBAL};\npTot^ := 0;",
        "reference nommee d'apres le totalisateur":
            f"{TOTAL_FIELD}Ref : REF_TO UDINT;",
        "alias VAR_IN_OUT en argument d'appel de FB":
            f"instAutre(Tot := {TOTAL_GLOBAL});",
        "affectation a un alias local":
            f"localTot := {TOTAL_GLOBAL};",
        "second branchement VAR_IN_OUT du global":
            f"instAutre2(SampleCountTotal := {TOTAL_GLOBAL});",
    }
    for label, sample in indirect_cases.items():
        found = indirect_write_findings("CODE/AUTO_TEST.st", sample) + indirect_binding_findings(
            "CODE/AUTO_TEST.st", sample
        )
        if not found:
            failures.append(f"auto-test chemin INDIRECT non detecte ({label})")

    # Les 3 sites LEGITIMES ne doivent JAMAIS etre signales (sinon le gate est inutilisable).
    for rel, legit in ALLOWED_OCCURRENCES.items():
        for stmt in legit:
            sample = f"{stmt};"
            found = indirect_write_findings(rel, sample) + indirect_binding_findings(rel, sample)
            if found:
                failures.append(f"auto-test faux positif sur un site legitime -> {rel}: {stmt} -> {found}")

    # Une reference vers une AUTRE donnee, dereferencee en ecriture, ne doit PAS mordre.
    innocent = "pAutre : REFERENCE TO REAL;\npAutre REF= GVL_Global.BlinkClock;\npAutre^ := 1.0;"
    if indirect_write_findings("CODE/AUTO_TEST.st", innocent):
        failures.append("auto-test : faux positif sur une reference vers une AUTRE donnee")

    return failures


def scan() -> list[str]:
    errors: list[str] = []

    fb_path = ROOT / FB_CYCLE
    if not fb_path.is_file():
        return [f"{FB_CYCLE} introuvable"]
    check_fb(errors, strip_comments(read(fb_path)))

    check_code_tree(errors)

    gvl_raw = read(ROOT / GVL_PERSISTENT)
    check_persistent_declaration(errors, gvl_raw)
    if TOTAL_GLOBAL not in strip_comments(read(ROOT / PRG_03)):
        errors.append(f"{PRG_03}: {TOTAL_GLOBAL} non branche au FB (VAR_IN_OUT)")

    check_bundle(errors)
    return errors


def main() -> int:
    errors = selftest() + scan()
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)
    print(f"Totalisateur prelevements (T299): {'FAIL' if errors else 'PASS'} ({len(errors)} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
