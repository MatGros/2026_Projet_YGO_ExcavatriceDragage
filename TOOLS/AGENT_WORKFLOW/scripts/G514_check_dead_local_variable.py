#!/usr/bin/env python3
"""G514 — Variable locale ecrite et jamais lue : code mort silencieux (T346).

Classe de bug couverte (T346, 2026-09-20) : ``FB_Bucket.st`` porte SIX variables locales
declarees, ecrites, et **jamais lues** — dont quatre laissees par le commit ``2a307b5b``
(2026-09-05) qui a retire les branches d'arret qui les consommaient ::

    LeftStartSinceArm  : BOOL;   (* ecrite :501 et :561 — jamais lue  *)
    M2StartPosM        : REAL;   (* lue :560 UNIQUEMENT pour alimenter la morte ci-dessus *)
    WasOpenAtStart     : BOOL;   (* ecrite :499 — jamais lue *)
    WasClosedAtStart   : BOOL;   (* ecrite :500 — jamais lue *)

et deux autres, **independantes** de ce commit ::

    BandLatchConcord   : BOOL;   (* :115 — jamais lue *)
    StateOffsetM       : REAL;   (* :116 — orpheline du « filet 5a », jamais lue *)

Pourquoi c'est un vrai risque et pas du rangement : une variable morte est le **temoin d'un
comportement disparu**. ``LeftStartSinceArm`` etait le drapeau d'une borne de recul de securite
machine : sa presence inerte a fait croire pendant 15 jours que la protection existait encore
(``DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md:415``). Une suppression non nettoyee
jusqu'au bout est indistinguishable, a la lecture, d'une fonctionnalite presente.

Regles :

- **A (variable locale ecrite et jamais lue)** : dans un bloc ``VAR`` (et non ``VAR CONSTANT``,
  ``VAR_INPUT``, ``VAR_OUTPUT``, ``VAR_IN_OUT``, ``VAR_GLOBAL``, ``VAR_TEMP``), toute variable
  dont le nom n'apparait **nulle part en position de lecture** est signalee.
- **B (POU de type PROGRAM)** : une ``VAR`` de ``PROGRAM`` est lisible de l'exterieur, sous la
  forme ``<POU>.<Variable>`` (ex. ``PRG_02_Acquisition.st:285`` lit
  ``PRG_06_Outputs.M1RelayFwd``). Une reference croisee de cette forme compte donc comme une
  LECTURE : sans cette regle, la gate produirait une cinquantaine de faux positifs sur
  ``PRG_06_Outputs.st`` et serait inutilisable. Pour un ``FUNCTION_BLOCK``, la ``VAR`` est
  privee, donc l'analyse fichier-local est exacte par construction.

Sont neutralises avant analyse, car ils ne constituent pas des lectures : les commentaires
(``//`` et ``(* ... *)``, y compris multi-lignes), les lignes de declaration, et les cibles
d'affectation (``Nom :=``). Une variable citée seulement dans un commentaire reste donc
correctement signalee.

LIMITE CONNUE, assumee et prouvee par le selftest : la regle A detecte « ecrite et jamais lue »,
pas « lue uniquement par une autre variable morte ». ``FB_Bucket.st`` porte les deux cas :
``BandLatchConcord``, ``StateOffsetM``, ``WasOpenAtStart``, ``WasClosedAtStart`` et
``LeftStartSinceArm`` sont detectees (5 sur 6), mais ``M2StartPosM`` est **lue** (``:560``) — sa
seule lecture alimentant une variable morte, elle releve d'une CHAINE morte qu'une analyse
fichier-local ne peut pas resoudre sans suivi de flux de controle. Ce cas reste donc du ressort
de la revue humaine : la gate ne remplace pas la lecture d'un diff.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G514_check_dead_local_variable.py [racine]
  python TOOLS/AGENT_WORKFLOW/scripts/G514_check_dead_local_variable.py --selftest
  python TOOLS/AGENT_WORKFLOW/scripts/G514_check_dead_local_variable.py --files CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Ouverture de bloc. `VAR` seul (bloc local) est distingue de toutes ses variantes.
RE_VAR_LOCAL = re.compile(r"^\s*VAR\s*$", re.IGNORECASE)
RE_VAR_OPEN = re.compile(r"^\s*VAR\b", re.IGNORECASE)
RE_VAR_END = re.compile(r"^\s*END_VAR\b", re.IGNORECASE)
RE_DECL = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:")
RE_POU_KIND = re.compile(r"^\s*(FUNCTION_BLOCK|PROGRAM|FUNCTION)\b", re.IGNORECASE)
RE_STRUCT_OPEN = re.compile(r"^\s*STRUCT\b", re.IGNORECASE)
RE_STRUCT_END = re.compile(r"^\s*END_STRUCT\b", re.IGNORECASE)

# Cible d'affectation : `Nom :=` ou `Nom[i] :=`. Deux precautions :
#  - le suffixe `.champ` est VOLONTAIREMENT exclu (`Nom.champ :=` est une utilisation de Nom) :
#    cela evite de declarer morte une instance de structure ecrite champ par champ ;
#  - le CONTENU du crochet est CONSERVE par la substitution (`\2`) : `Tab[i] := ...` laisse `[i]`
#    dans le texte des lectures, sinon un simple indice de boucle (`FB_Hmi_BannerFormatter.st:122`)
#    serait declare mort a tort.
RE_WRITE_TARGET = re.compile(r"(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)(\s*\[[^\]]*\])?\s*:=")


def strip_comments(text: str) -> str:
    """Retire commentaires ligne et bloc (multi-lignes), en preservant les numeros de ligne."""
    out: list[str] = []
    in_block = False
    for line in text.splitlines():
        work = line
        result = ""
        while work:
            if in_block:
                end = work.find("*)")
                if end < 0:
                    work = ""
                else:
                    work = work[end + 2:]
                    in_block = False
                continue
            start_c = work.find("//")
            start_b = work.find("(*")
            if start_b >= 0 and (start_c < 0 or start_b < start_c):
                result += work[:start_b]
                work = work[start_b + 2:]
                in_block = True
                continue
            if start_c >= 0:
                result += work[:start_c]
                work = ""
                continue
            result += work
            work = ""
        out.append(result)
    return "\n".join(out)


def pou_kind(code_text: str) -> str:
    """Type de POU du fichier, deduit de sa declaration (le nom vient du nom de fichier)."""
    for line in code_text.splitlines()[:60]:
        match = RE_POU_KIND.match(line)
        if match:
            return match.group(1).upper()
    return ""


def local_declarations(code_text: str) -> list[tuple[str, int]]:
    """Variables locales (bloc `VAR` nu) : (nom, numero de ligne 1-base)."""
    found: list[tuple[str, int]] = []
    kind: str | None = None
    in_struct = 0
    for index, line in enumerate(code_text.splitlines(), start=1):
        if RE_VAR_END.match(line):
            kind = None
            in_struct = 0
            continue
        if RE_VAR_LOCAL.match(line):
            kind = "LOCAL"
            continue
        if RE_VAR_OPEN.match(line):
            kind = "OTHER"
            continue
        if kind is None:
            continue
        if RE_STRUCT_OPEN.match(line):
            in_struct += 1
            continue
        if RE_STRUCT_END.match(line):
            in_struct = max(0, in_struct - 1)
            continue
        if in_struct:
            continue
        if kind == "LOCAL":
            match = RE_DECL.match(line)
            if match:
                found.append((match.group(1), index))
    return found


def read_only_text(code_text: str, declaration_lines: set[int]) -> str:
    """Texte reduit aux LECTURES : sans commentaires, sans declarations, sans cibles d'ecriture."""
    kept: list[str] = []
    for index, line in enumerate(code_text.splitlines(), start=1):
        if index in declaration_lines:
            continue
        kept.append(line)
    return RE_WRITE_TARGET.sub(r"\2", "\n".join(kept))


def is_read(name: str, read_only: str) -> bool:
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", read_only) is not None


def scan_text(text: str, filename: str, external: str = "") -> list[tuple[int, str]]:
    """Violations d'un fichier : (ligne, message). `external` = code du reste du depot (regle B)."""
    code = strip_comments(text)
    kind = pou_kind(code)
    declarations = local_declarations(code)
    if not declarations:
        return []

    declaration_lines = {line for _, line in declarations}
    read_only = read_only_text(code, declaration_lines)
    pou_name = Path(filename).stem

    findings: list[tuple[int, str]] = []
    for name, line in declarations:
        if is_read(name, read_only):
            continue
        if kind == "PROGRAM" and external:
            # Regle B : une VAR de PROGRAM est lisible comme <POU>.<Variable>.
            if re.search(
                rf"(?<![A-Za-z0-9_]){re.escape(pou_name)}\s*\.\s*{re.escape(name)}(?![A-Za-z0-9_])",
                external,
                re.IGNORECASE,
            ):
                continue
        findings.append((
            line,
            f"regle A : `{name}` est declaree et ecrite mais JAMAIS lue "
            f"(POU {kind or 'inconnu'} {pou_name}) — temoin d'un comportement disparu : "
            f"la purger ou la relire, jamais la laisser inerte",
        ))
    return findings


def scan_file(path: Path, external: str = "") -> list[tuple[int, str]]:
    return scan_text(path.read_text(encoding="utf-8", errors="replace"), path.name, external)


def repo_code(root: Path) -> str:
    """Code de tout le depot, commentaires retires (support de la regle B)."""
    chunks: list[str] = []
    for st in sorted((root / "CODE").rglob("*.st")):
        chunks.append(strip_comments(st.read_text(encoding="utf-8", errors="replace")))
    return "\n".join(chunks)


def scan_repo(root: Path) -> list[str]:
    external = repo_code(root)
    errors: list[str] = []
    for st in sorted((root / "CODE").rglob("*.st")):
        rel = st.relative_to(root).as_posix()
        for line, message in scan_file(st, external):
            errors.append(f"{rel}:{line}: {message}")
    return errors


# ── Selftest ────────────────────────────────────────────────────────────────────────────────
# 1. Forme REELLE de FB_Bucket.st : les 6 variables mortes du lot T346, dans leur contexte exact.
#    Attendu : 5 detectees, `M2StartPosM` NON detectee (elle est lue :560 — chaine morte, limite
#    documentee de la regle A).
SELFTEST_REAL_SHAPE = """FUNCTION_BLOCK PUBLIC FB_Bucket
VAR
    BandLatchConcord  : BOOL;
    StateOffsetM      : REAL;
    M2StartPosM       : REAL;
    WasOpenAtStart    : BOOL;
    WasClosedAtStart  : BOOL;
    LeftStartSinceArm : BOOL;
END_VAR
    M2StartPosM := CablePosM2;
    WasOpenAtStart := BucketState.IsOpen;
    WasClosedAtStart := BucketState.IsClosed;
    LeftStartSinceArm := FALSE;
    IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
        LeftStartSinceArm := TRUE;
    END_IF;
END_FUNCTION_BLOCK
"""
SELFTEST_REAL_EXPECTED = (
    "BandLatchConcord",
    "StateOffsetM",
    "WasOpenAtStart",
    "WasClosedAtStart",
    "LeftStartSinceArm",
)
SELFTEST_REAL_CASCADE_BOUNDARY = "M2StartPosM"

# 2. Forme CONFORME (contre-preuve) : chaque variable est ecrite PUIS relue -> aucun signalement.
SELFTEST_FB_LEGIT = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR
    M1RefPosM       : REAL;
    M1SlipDetected  : BOOL;
END_VAR
    M1RefPosM := CablePosM1;
    M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM);
    IF M1SlipDetected THEN
        M1SlipFaultLatched := TRUE;
    END_IF;
END_FUNCTION_BLOCK
"""

# 3. Regle B : VAR de PROGRAM ecrite localement, lue UNIQUEMENT de l'exterieur
#    (`PRG_02_Acquisition.st:285` lit `PRG_06_Outputs.M1RelayFwd`) -> PAS de faux positif.
SELFTEST_PRG_EXTERNAL = """PROGRAM PRG_Outputs_Selftest
VAR
    PublishedOrdre  : BOOL;
END_VAR
    PublishedOrdre := instInterlock.RelayFwd;
END_PROGRAM
"""
SELFTEST_PRG_EXTERNAL_REF = "PRG_Outputs_Selftest.PublishedOrdre := TRUE;"

# 4. Regle B negative : VAR de PROGRAM jamais lue, meme de l'exterieur -> signalee.
SELFTEST_PRG_DEAD = """PROGRAM PRG_Orphan_Selftest
VAR
    NeverUsedAnywhere : BOOL;
END_VAR
    NeverUsedAnywhere := TRUE;
END_PROGRAM
"""

# 5. Le nom n'apparait QUE dans un commentaire : ne compte pas comme lecture.
SELFTEST_COMMENT_ONLY = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR
    GhostFlag       : BOOL;   (* GhostFlag est mentionnee ici, et nulle part ailleurs *)
END_VAR
    GhostFlag := TRUE;
    // GhostFlag sert a quelque chose, promis.
END_FUNCTION_BLOCK
"""


# 6. Indice de boucle utilise SEULEMENT dans un crochet d'affectation : `Tab[i] := ''`.
#    Le contenu du crochet est une LECTURE de `i` (cas reel FB_Hmi_BannerFormatter.st:174-176).
SELFTEST_ARRAY_INDEX = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR
    i               : INT;
    AlarmArray      : ARRAY[0..49] OF STRING;
END_VAR
    FOR i := 0 TO 49 DO
        AlarmArray[i] := '';
    END_FOR;
END_FUNCTION_BLOCK
"""


def selftest() -> int:
    """Le detecteur doit voir le code mort REEL et ne rien lever sur les formes conformes."""
    failures: list[str] = []

    # 1. Forme reelle : 5 detectees, la 6e explicitement NON detectee (limite prouvee, pas subie).
    real = scan_text(SELFTEST_REAL_SHAPE, "FB_Bucket.st")
    names = {message.split("`")[1] for _, message in real}
    for expected in SELFTEST_REAL_EXPECTED:
        if expected not in names:
            failures.append(f"mutation NON detectee : `{expected}` ecrite et jamais lue (regle A)")
    if SELFTEST_REAL_CASCADE_BOUNDARY in names:
        failures.append(
            f"limite regle A : `{SELFTEST_REAL_CASCADE_BOUNDARY}` est lue dans le code, elle ne "
            f"doit PAS etre signalee par une analyse fichier-local (chaine morte = revue humaine)"
        )
    if len(names) != len(SELFTEST_REAL_EXPECTED):
        failures.append(f"forme reelle : {len(names)} signalement(s) au lieu de {len(SELFTEST_REAL_EXPECTED)}")

    # 2. Contre-preuve : ecrite puis relue -> aucun signalement.
    if scan_text(SELFTEST_FB_LEGIT, "FB_Selftest.st"):
        failures.append("faux positif : variable ecrite PUIS RELUE signalee a tort")

    # 3. Regle B : lecture croisee <POU>.<Variable> reconnue.
    prg_ext = scan_text(SELFTEST_PRG_EXTERNAL, "PRG_Outputs_Selftest.st", external=SELFTEST_PRG_EXTERNAL_REF)
    if prg_ext:
        failures.append(
            "faux positif regle B : VAR de PROGRAM lue sous <POU>.<Variable> signalee a tort "
            "(c'est le cas PRG_06_Outputs.st / M1RelayFwd)"
        )

    # 4. Regle B negative : plus aucune lecture nulle part -> signalee.
    if not scan_text(SELFTEST_PRG_DEAD, "PRG_Orphan_Selftest.st", external="PRG_Autre.X := 1;"):
        failures.append("mutation NON detectee regle B : VAR de PROGRAM jamais lue nulle part")

    # 5. Un commentaire ne vaut pas une lecture.
    if not scan_text(SELFTEST_COMMENT_ONLY, "FB_Selftest.st"):
        failures.append(
            "mutation NON detectee : un nom cite seulement dans un COMMENTAIRE ne doit pas "
            "compter comme une lecture"
        )

    # 6. `Tab[i] := ...` : le contenu du crochet est une lecture, l'indice ne doit pas etre signale.
    index_findings = scan_text(SELFTEST_ARRAY_INDEX, "FB_Selftest.st")
    index_names = {message.split("`")[1] for _, message in index_findings}
    if "i" in index_names:
        failures.append(
            "faux positif : `i` est un indice de boucle LU dans `AlarmArray[i] := ...` "
            "(cas reel FB_Hmi_BannerFormatter.st:174-176)"
        )
    if len(index_names) != 1:
        failures.append(f"indice de boucle : {len(index_names)} signalement(s) au lieu de 1 (AlarmArray)")

    if failures:
        print("[G514] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "[G514] SELFTEST PASS — forme reelle de FB_Bucket.st : "
        f"{len(SELFTEST_REAL_EXPECTED)}/6 detectees, `{SELFTEST_REAL_CASCADE_BOUNDARY}` "
        "correctement NON signalee (chaine morte = revue humaine) ; regle B sans faux positif ; "
        "commentaires neutralises"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations")
    parser.add_argument(
        "--files",
        nargs="+",
        default=None,
        help="limite l'analyse a ces fichiers (chemins .st) au lieu de tout CODE/",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G514] FAIL — dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest()

    external = repo_code(root)

    if args.files:
        targets = []
        for entry in args.files:
            candidate = (root / entry) if not Path(entry).is_absolute() else Path(entry)
            if candidate.is_file():
                targets.append(candidate)
            else:
                print(f"[G514] FAIL — fichier introuvable : {entry}")
                return 2
    else:
        targets = sorted((root / "CODE").rglob("*.st"))

    errors: list[str] = []
    for st in targets:
        try:
            rel = st.resolve().relative_to(root).as_posix()
        except ValueError:
            rel = st.as_posix()
        for line, message in scan_file(st, external):
            errors.append(f"{rel}:{line}: {message}")

    if errors:
        scope = "--files" if args.files else "CODE/"
        print(f"[G514] FAIL — variable locale ecrite et jamais lue ({len(errors)} site(s), perimetre {scope}) :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("[G514] PASS — aucune variable locale ecrite et jamais lue dans le perimetre analyse")
    return 0


if __name__ == "__main__":
    sys.exit(main())
