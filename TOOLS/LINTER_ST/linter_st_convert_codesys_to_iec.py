#!/usr/bin/env python3
"""Moulinette : convertit les idiomes CODESYS 3.5 non reconnus par STruCpp (compilateur
ST -> C++17, https://github.com/Autonomy-Logic/STruCpp) vers de l'IEC 61131-3 equivalent.
Ne touche jamais aux fichiers CODE/ sources -- ecrit une copie dans un dossier de sortie.

Copie independante de TOOLS/COMPILER_ST2C_STruCpp/convert_codesys_to_iec.py : LINTER_ST est
un outil encapsule, sans dependance d'execution vers les autres dossiers de TOOLS/ (consigne
utilisateur 2026-08-23 -- pas de lien inter-outils, chaque outil porte sa propre copie).

3 transformations, toutes mecaniques et semantiquement neutres pour la logique du FB :

1. TYPE x : ENUM lit := val, ... END_ENUM END_TYPE
   -> TYPE x : (lit := val, ...); END_TYPE
   (forme lisible CODESYS -> forme parenthesee standard ; valeurs explicites CONSERVEES)

2. {region "..."} / {endregion} / {attribute '...'} / {warning ...}
   -> supprimes (pragmas de pliage/annotation IDE, aucun effet sur la logique)

3. FUNCTION_BLOCK PUBLIC Name / PROGRAM INTERNAL Name / ...
   -> FUNCTION_BLOCK Name (qualificatif de visibilite CODESYS retire ; sans effet sur le
      comportement d'un FB analyse en boite noire hors compilation multi-unites)

4. END_xxx absent (fragments CODESYS colles dans l'editeur, qui fournit sa propre enveloppe)
   -> ajoute automatiquement

5. GVL_Xxx.Membre -> Membre
   (Sans cette transformation, STruCpp traite `GVL_Test.Foo` comme une variable non declaree
   nommee 'GVL_TEST' -- seul l'acces non qualifie `Foo` compile. Verifie empiriquement par test
   isole, session 2026-08-23. ATTENTION : la doc officielle STruCpp (IEC_COMPLIANCE.md, lue
   apres coup) liste "Pragmas {...} -- Supported" ET "Namespace configuration -- Supported --
   Via pragmas" -- il existe donc PEUT-ETRE un vrai mecanisme de pragma pour l'acces qualifie
   qu'on n'a pas explore (piste non testee, cf. lien dans TOOLS/LINTER_ST/README.md). Notre test
   isole a echoue sur {attribute 'qualified_only'} precisement, pas sur {...} en general -- le
   contenu du pragma etait peut-etre juste le mauvais. Cette transformation ne touche jamais le
   fichier source -- uniquement la copie temporaire compilee par STruCpp.)

6. VAR_GLOBAL PERSISTENT [RETAIN] -> VAR_GLOBAL [RETAIN]
   (STruCpp ne supporte PAS du tout le qualificatif PERSISTENT sur VAR_GLOBAL -- meme seul,
   sans RETAIN. RETAIN seul compile. Verifie empiriquement par test isole, session 2026-08-23 :
   `VAR_GLOBAL PERSISTENT` echoue "Expected Colon, found identifier", `VAR_GLOBAL RETAIN`
   compile. PERSISTENT est un attribut de deploiement CODESYS (survit aux downloads) --
   invisible pour un check de syntaxe/typage, retire sans risque sur la copie temporaire.)

7. ARRAY[a..b] OF ARRAY[c..d] OF Type -> ARRAY[a..b, c..d] OF Type
   (STruCpp ne supporte pas la forme imbriquee CODESYS pour un tableau multi-dimensions, mais
   supporte la forme virgule standard IEC -- meme forme geometrique, syntaxe equivalente.
   Verifie empiriquement, session 2026-08-23 : `ARRAY[1..5] OF ARRAY[1..5] OF REAL` echoue
   "Expected Identifier, found ARRAY", `ARRAY[1..5, 1..5] OF REAL` compile. Trouve sur
   ST_WinchLoadEstimateTable.st (matrice 5x5). Applique en boucle pour gerer 3+ dimensions.)

BINAIRE VENDORE : strucpp.exe v0.6.3 (mis a jour depuis v0.6.2, session 2026-08-23) -- le
changelog GitHub n'est pas consulte, mais teste empiriquement AVANT/APRES sur les 4 limites
connues (voir README.md). v0.6.3 corrige nativement les initialiseurs de struct/array par
litteral nomme (`X : Type := (Champ := Val, ...)`, y compris imbriques) -- l'ancienne
transformation 8 qui les retirait avant compilation a ete SUPPRIMEE car devenue inutile (moins de
transformations = moins de risque de sur-filtrer une vraie erreur, cf. demande utilisateur
"eviter d'inhiber des erreurs"). Les 3 autres limites (PERSISTENT, ARRAY imbrique, acces qualifie
GVL/PROGRAM) restent identiques en v0.6.3, testees explicitement avant de mettre a jour.
"""

import argparse
import pathlib
import re
import sys

ENUM_BLOCK_RE = re.compile(
    r"TYPE\s+(?P<name>\w+)\s*:\s*ENUM\s*(?P<body>.*?)END_ENUM\s*END_TYPE",
    re.DOTALL | re.IGNORECASE,
)

PRAGMA_RE = re.compile(r"\{[^}]*\}")

POU_QUALIFIER_RE = re.compile(
    r"\b(FUNCTION_BLOCK|PROGRAM|FUNCTION)\s+(PUBLIC|INTERNAL|PROTECTED|ABSTRACT|FINAL)\b",
    re.IGNORECASE,
)

LITERAL_RE = re.compile(r"(?P<lit>\w+)\s*(?::=\s*(?P<val>-?\d+))?")

GVL_QUALIFIER_RE = re.compile(r"\bGVL_\w+\.")

VAR_GLOBAL_QUALIFIER_RE = re.compile(r"VAR_GLOBAL((?:\s+(?:PERSISTENT|RETAIN))*)", re.IGNORECASE)

NESTED_ARRAY_RE = re.compile(
    r"ARRAY\s*\[(?P<dim1>[^\]]+)\]\s+OF\s+ARRAY\s*\[(?P<dim2>[^\]]+)\]\s+OF\s+",
    re.IGNORECASE,
)


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def _parse_literals(body: str):
    body_clean = _strip_comments(body)
    literals = []
    for chunk in body_clean.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = LITERAL_RE.match(chunk)
        if not m:
            continue
        lit = m.group("lit")
        val = m.group("val")
        literals.append((lit, int(val) if val is not None else None))
    return literals


def _convert_enum_blocks(text: str, source_name: str, warnings: list) -> str:
    def _replace(match):
        name = match.group("name")
        body = match.group("body")
        literals = _parse_literals(body)
        if not literals:
            warnings.append(f"{source_name}: {name} -- aucun litteral trouve, bloc ENUM laisse tel quel")
            return match.group(0)

        rendered = ", ".join(
            f"{lit} := {val}" if val is not None else lit
            for lit, val in literals
        )
        return f"TYPE {name} :\n    ({rendered});\nEND_TYPE"

    return ENUM_BLOCK_RE.sub(_replace, text)


def _strip_pragmas(text: str) -> str:
    return PRAGMA_RE.sub("", text)


def _strip_pou_qualifiers(text: str) -> str:
    return POU_QUALIFIER_RE.sub(lambda m: m.group(1), text)


POU_OPEN_RE = re.compile(r"^\s*(FUNCTION_BLOCK|PROGRAM|FUNCTION)\b", re.IGNORECASE | re.MULTILINE)


def _close_missing_pou_end(text: str, source_name: str, warnings: list) -> str:
    """Les .st du projet sont des fragments colles dans l'editeur CODESYS (qui fournit
    lui-meme l'enveloppe) -- il leur manque systematiquement le END_xxx de fermeture.
    Ajoute le mot-cle correspondant s'il est absent, sans toucher au fichier source."""
    m = POU_OPEN_RE.search(_strip_comments(text))
    if not m:
        return text
    kw = m.group(1).upper()
    end_kw = f"END_{kw}"
    if re.search(rf"^\s*{end_kw}\b", text, re.MULTILINE | re.IGNORECASE):
        return text
    warnings.append(f"{source_name}: {end_kw} absent -- ajoute en fin de fichier")
    return text.rstrip() + f"\n{end_kw}\n"


def _strip_gvl_qualifiers(text: str) -> str:
    return GVL_QUALIFIER_RE.sub("", text)


def _strip_persistent_qualifier(text: str, source_name: str, warnings: list) -> str:
    def _replace(match):
        quals = re.findall(r"PERSISTENT|RETAIN", match.group(1), re.IGNORECASE)
        kept = [q.upper() for q in quals if q.upper() == "RETAIN"]
        if any(q.upper() == "PERSISTENT" for q in quals):
            warnings.append(f"{source_name}: qualificatif PERSISTENT retire (non supporte par STruCpp)")
        return "VAR_GLOBAL" + "".join(f" {q}" for q in kept)

    return VAR_GLOBAL_QUALIFIER_RE.sub(_replace, text)


def _merge_nested_arrays(text: str, source_name: str, warnings: list) -> str:
    merged_any = False
    while True:
        new_text, n = NESTED_ARRAY_RE.subn(
            lambda m: f"ARRAY[{m.group('dim1')}, {m.group('dim2')}] OF ", text
        )
        if n == 0:
            break
        text = new_text
        merged_any = True
    if merged_any:
        warnings.append(f"{source_name}: ARRAY[..] OF ARRAY[..] fusionne en ARRAY[..,..] (non supporte par STruCpp)")
    return text


def convert_text(text: str, source_name: str, warnings: list) -> str:
    text = _convert_enum_blocks(text, source_name, warnings)
    text = _strip_pragmas(text)
    text = _strip_pou_qualifiers(text)
    text = _strip_gvl_qualifiers(text)
    text = _strip_persistent_qualifier(text, source_name, warnings)
    text = _merge_nested_arrays(text, source_name, warnings)
    text = _close_missing_pou_end(text, source_name, warnings)
    return text


def convert_file(src: pathlib.Path, dst: pathlib.Path, warnings: list) -> None:
    text = src.read_text(encoding="utf-8")
    converted = convert_text(text, src.name, warnings)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(converted, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="Fichier(s) .st source a convertir")
    parser.add_argument("--out", required=True, help="Dossier de sortie (copies converties)")
    args = parser.parse_args()

    out_dir = pathlib.Path(args.out)
    warnings: list = []

    for raw in args.inputs:
        src = pathlib.Path(raw)
        dst = out_dir / src.name
        convert_file(src, dst, warnings)
        print(f"OK  {src} -> {dst}")

    if warnings:
        print("\n--- AVERTISSEMENTS ---")
        for w in warnings:
            print(f"[WARN] {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
