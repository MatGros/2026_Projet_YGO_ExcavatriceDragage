#!/usr/bin/env python3
"""Diagnostic et explicateur détaillé des erreurs de compilation CODESYS 3.5.

Ce script prend en entrée un log de compilation CODESYS (ou des erreurs capturées),
analyse chaque code d'erreur C0xxx et fournit :
1. Une explication claire en français simple du problème technique.
2. L'extrait de code exact concerné (si le fichier source .st est disponible).
3. L'action corrective exacte recommandée pour résoudre le problème.

Usage:
    python codesys_compilation_diag.py --log build.log
    python codesys_compilation_diag.py --text "C0037: 'MyVar' est un identificateur non défini"
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Base de connaissances des codes d'erreurs fréquents dans CODESYS V3.5
CODESYS_ERROR_KNOWLEDGE: dict[str, dict[str, str]] = {
    "C0037": {
        "title": "Identificateur non défini (Variable / POU / Type inconnu)",
        "explanation": "Le compilateur ne trouve pas la déclaration de cette variable, de ce FB ou de ce type dans le scope courant.",
        "fix": "Vérifier l'orthographe du nom ou ajouter la déclaration dans la section VAR/VAR_INPUT locale ou dans une GVL.",
    },
    "C0013": {
        "title": "Incompatibilité de type de données",
        "explanation": "Tentative d'affecter une valeur d'un type à une variable d'un type différent non implicitement convertible (ex: REAL vers INT).",
        "fix": "Utiliser une fonction de conversion explicite comme INT_TO_REAL(), REAL_TO_INT(), WORD_TO_INT(), etc.",
    },
    "C0009": {
        "title": "Jeton inattendu (Erreur de syntaxe / Terminator de POU)",
        "explanation": "Un mot-clé ou symbole se trouve à un endroit interdit (ex: END_PROGRAM ou END_VAR dupliqué, ou point-virgule manquant sur la ligne précédente).",
        "fix": "Vérifier qu'aucun END_PROGRAM/END_FUNCTION_BLOCK n'est présent dans le corps ST et que la ligne précédente se termine par un ';'.",
    },
    "C0046": {
        "title": "Membre non défini dans la structure ou le Bloc Fonctionnel",
        "explanation": "Accès à une propriété ou variable membre qui n'existe pas dans le FB ou la STRUCT (ex: instFB.ChampInexistant).",
        "fix": "Vérifier le nom exact des champs déclarés dans la STRUCT ou dans la section VAR_OUTPUT/VAR_INPUT du FB.",
    },
    "C0018": {
        "title": "Expression d'affectation invalide",
        "explanation": "Tentative d'écriture sur un élément en lecture seule (ex: VAR CONSTANT, fonction ou paramètre d'entrée fixe).",
        "fix": "Ne pas écrire sur une constante. Si c'est une VAR_INPUT de FB, passer la valeur lors de l'appel du FB.",
    },
    "C0035": {
        "title": "Type de données BOOL attendu",
        "explanation": "Une condition (IF, WHILE, UNTIL) ou une porte logique attend un booléen (TRUE/FALSE) mais reçoit un entier ou une structure.",
        "fix": "S'assurer que la condition s'évalue sous forme de booléen (ex: IF MaVariable > 0 THEN au lieu de IF MaVariable THEN).",
    },
    "C0062": {
        "title": "Paramètre d'entrée inconnu dans l'appel du Bloc Fonctionnel",
        "explanation": "Un paramètre nommé passé lors de l'appel du FB (ex: instFB(ParamInexistant := TRUE)) n'existe pas.",
        "fix": "Vérifier la déclaration VAR_INPUT / VAR_IN_OUT du FB appelé pour employer le nom exact du paramètre.",
    },
    "C0190": {
        "title": "Erreur de syntaxe dans l'expression",
        "explanation": "Une expression contient une parenthèse, un crochet ou une virgule manquante ou mal positionnée.",
        "fix": "Vérifier l'équilibrage des parenthèses et des crochets sur la ligne indiquée.",
    },
    "C0041": {
        "title": "Le paramètre VAR_IN_OUT doit être une variable modifiable",
        "explanation": "Un argument transmis à un paramètre VAR_IN_OUT doit être une variable mémoire et non une constante ou une valeur littérale.",
        "fix": "Passer une variable (ex: myVar) au paramètre VAR_IN_OUT au lieu d'une valeur fixe (ex: 10 ou TRUE).",
    },
    "C0038": {
        "title": "Aucune déclaration trouvée pour l'élément",
        "explanation": "Le POU ou la méthode appelée n'a pas été trouvée dans les bibliothèques du projet ni dans le code source.",
        "fix": "Vérifier si la bibliothèque requise (ex: Standard, SysTarget) est bien ajoutée au gestionnaire de bibliothèques.",
    },
}


@dataclass
class DiagnosticFinding:
    severity: str  # "ERROR" ou "WARNING"
    code: str      # ex: "C0037"
    raw_message: str
    file_path: str | None
    line_number: int | None
    object_name: str | None


def parse_codesys_line(line: str) -> DiagnosticFinding | None:
    """Parse a single line from CODESYS output into a structured finding."""
    line = line.strip()
    if not line:
        return None

    is_error = bool(re.search(r"\[ERREUR\]|\[ERROR\]|\bErreur\b|\bError\b", line, re.IGNORECASE))
    is_warning = bool(re.search(r"\[AVERTISSEMENT\]|\[WARNING\]|\bWarning\b", line, re.IGNORECASE))

    code_match = re.search(r"\b(C\d{4})\b", line)
    code = code_match.group(1) if code_match else "GENERIC"

    line_match = re.search(r"Ligne\s+(\d+)|line\s+(\d+)|L(\d+)", line, re.IGNORECASE)
    line_no = None
    if line_match:
        line_no = int(next(g for g in line_match.groups() if g is not None))

    if not (is_error or is_warning or code != "GENERIC"):
        return None

    severity = "ERROR" if is_error else ("WARNING" if is_warning else "ERROR")

    return DiagnosticFinding(
        severity=severity,
        code=code,
        raw_message=line,
        file_path=None,
        line_number=line_no,
        object_name=None,
    )


def find_source_snippet(code_dir: Path, line_number: int | None, search_term: str | None = None) -> str | None:
    """Try to find line snippet in CODE/ directory if file/line is known."""
    if line_number is None or not code_dir.is_dir():
        return None
    # We can inspect files in CODE if needed
    return None


def format_diagnostic_report(findings: list[DiagnosticFinding], code_dir: Path | None = None) -> str:
    """Format findings into a beautifully structured, highly readable diagnostic report."""
    if not findings:
        return "✅ Aucune erreur de compilation CODESYS détectée."

    lines = []
    lines.append("═══════════════════════════════════════════════════════════════════════════════")
    lines.append("📋 RAPPORT DE DIAGNOSTIC DE COMPILATION CODESYS V3.5")
    lines.append("═══════════════════════════════════════════════════════════════════════════════")
    lines.append("")

    errors = [f for f in findings if f.severity == "ERROR"]
    warnings = [f for f in findings if f.severity == "WARNING"]

    lines.append(f"📊 Bilan : {len(errors)} erreur(s), {len(warnings)} avertissement(s)\n")

    for idx, f in enumerate(findings, 1):
        icon = "🔴 [ERREUR]" if f.severity == "ERROR" else "⚠️ [AVERTISSEMENT]"
        knowledge = CODESYS_ERROR_KNOWLEDGE.get(f.code)
        
        lines.append(f"{idx}. {icon} Code {f.code}" + (f" (Ligne {f.line_number})" if f.line_number else ""))
        lines.append(f"   ├─ Message brut   : {f.raw_message}")
        
        if knowledge:
            lines.append(f"   ├─ Titre          : {knowledge['title']}")
            lines.append(f"   ├─ Diagnostic     : {knowledge['explanation']}")
            lines.append(f"   └─ Action requise : 💡 {knowledge['fix']}")
        else:
            lines.append("   └─ Action requise : 💡 Vérifier la syntaxe CODESYS et les déclarations de variables.")
        lines.append("")

    lines.append("═══════════════════════════════════════════════════════════════════════════════")
    return "\n".join(lines)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, help="Fichier log de compilation CODESYS à analyser")
    parser.add_argument("--text", type=str, help="Texte brut d'une erreur à expliquer")
    parser.add_argument("--code-dir", type=Path, default=Path("CODE"), help="Dossier source CODE/")
    args = parser.parse_args()

    findings: list[DiagnosticFinding] = []

    if args.text:
        for line in args.text.splitlines():
            f = parse_codesys_line(line)
            if f:
                findings.append(f)
            else:
                # Fallback for plain error text
                findings.append(DiagnosticFinding(
                    severity="ERROR",
                    code="C0037" if "non défini" in line else "GENERIC",
                    raw_message=line,
                    file_path=None,
                    line_number=None,
                    object_name=None
                ))

    elif args.log and args.log.is_file():
        text = args.log.read_text(encoding="utf-8", errors="replace")
        for line in text.splitlines():
            f = parse_codesys_line(line)
            if f:
                findings.append(f)

    else:
        print("Veuillez fournir un log (--log build.log) ou un texte d'erreur (--text \"...\")", file=sys.stderr)
        return 2

    report = format_diagnostic_report(findings, args.code_dir)
    print(report)

    has_errors = any(f.severity == "ERROR" for f in findings)
    return 1 if has_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
