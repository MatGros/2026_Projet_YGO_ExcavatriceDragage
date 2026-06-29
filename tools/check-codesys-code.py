#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Validation CODESYS Guardrails — Avant injection dans Device.export

Usage:
    python tools/check-codesys-code.py [--audit] [files...]
    python tools/check-codesys-code.py --audit CODE/FB_*.xml
    python tools/check-codesys-code.py [fichier]

Vérifications strictes :
    OK Nommage PascalCase
    OK Interface FB complète (Enable, SafeStop, ErrorId, etc.)
    OK Reset sur front
    OK SafeStop prioritaire
    FAIL Redémarrage auto après défaut
"""

import re
import sys
import io
import xml.etree.ElementTree as ET
from pathlib import Path

# Force UTF-8 output on Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Couleurs terminal
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"
BOLD = "\033[1m"

class CodesysValidator:
    def __init__(self, guardrails_path=".claude/guardrails-codesys.md"):
        self.guardrails_path = Path(guardrails_path)
        self.violations = []
        self.warnings = []
        self.passed = []

    def audit_file(self, filepath):
        """Audit un fichier XML CODESYS pour conformité."""
        filepath = Path(filepath)
        if not filepath.exists():
            print(f"{RED}✗ Fichier non trouvé: {filepath}{RESET}")
            return False

        try:
            tree = ET.parse(filepath)
            root = tree.getroot()

            # Extraire nom et type
            name_elem = root.find(".//Single[@Name='Name']")
            name = name_elem.text if name_elem is not None else "UNKNOWN"

            # Extraire contenu IEC
            text_elem = root.find(".//Single[@Name='TextBlobForSerialisation']")
            code = text_elem.text if text_elem is not None else ""

            print(f"\n{BOLD}Audit: {name}{RESET}")
            print("─" * 60)

            violations = self._check_conformity(name, code, filepath)

            if violations:
                self.violations.extend(violations)
                return False
            else:
                self.passed.append(name)
                print(f"{GREEN}✓ Conforme{RESET}")
                return True

        except ET.ParseError as e:
            print(f"{RED}✗ Erreur XML: {e}{RESET}")
            return False

    def _check_conformity(self, name, code, filepath):
        """Vérifications strictes conformité."""
        found = []

        # 1. Nommage PascalCase
        if not self._is_pascal_case(name):
            found.append(f"{RED}✗ Nom non-PascalCase: '{name}'{RESET}")

        # 2. Interface FB si FB_*
        if name.startswith("FB_"):
            fb_violations = self._check_fb_interface(code)
            found.extend(fb_violations)

        # 3. Reset sur front
        if "Reset" in code:
            if not self._has_front_reset(code):
                found.append(f"{YELLOW}⚠ Reset détecté mais pas sur front (besoin vérification){RESET}")

        # 4. SafeStop prioritaire
        if "SafeStop" in code and "Enable" in code:
            if not self._is_safestop_first(code):
                found.append(f"{YELLOW}⚠ SafeStop présent mais priorité sur Enable à vérifier{RESET}")

        # 5. Pas de redémarrage auto après défaut
        if self._has_auto_restart(code):
            found.append(f"{RED}✗ Détecté : redémarrage auto après défaut (INTERDIT){RESET}")

        # Afficher les violations
        for violation in found:
            print(violation)

        return found

    def _is_pascal_case(self, name):
        """Vérifie PascalCase (pas hongrois, pas snake_case)."""
        # Doit commencer par majuscule
        if not name[0].isupper():
            return False
        # Pas de snake_case
        if "_" in name and not name.startswith(("ST_", "E_", "FB_", "PRG_")):
            return False
        return True

    def _check_fb_interface(self, code):
        """Vérifie interface FB complète."""
        violations = []
        required_inputs = ["Enable", "Reset", "SafeStop", "SafetyOk"]
        required_outputs = ["Ready", "Busy", "Done", "Error", "ErrorId", "State"]

        for inp in required_inputs:
            if inp not in code:
                violations.append(f"{RED}✗ Entrée manquante: {inp}{RESET}")

        for out in required_outputs:
            if out not in code:
                violations.append(f"{RED}✗ Sortie manquante: {out}{RESET}")

        # ErrorId doit être bitfield (INT ou DWORD)
        if "ErrorId" in code:
            if not re.search(r"ErrorId\s*:\s*(INT|DWORD|WORD)", code, re.IGNORECASE):
                violations.append(f"{YELLOW}⚠ ErrorId détecté mais type à vérifier (doit être bitfield){RESET}")

        return violations

    def _has_front_reset(self, code):
        """Détecte si Reset est sur front obligatoire."""
        # Pattern simple : F_TRIG ou front_rising
        return bool(re.search(r"F_TRIG|front|rising", code, re.IGNORECASE))

    def _is_safestop_first(self, code):
        """Vérifie si SafeStop est prioritaire."""
        # Simple : SafeStop doit apparaître avant ou indépendamment de Enable
        safestop_idx = code.find("SafeStop")
        enable_idx = code.find("Enable")
        return safestop_idx < enable_idx if enable_idx > 0 else True

    def _has_auto_restart(self, code):
        """Détecte redémarrage auto (INTERDIT)."""
        patterns = [
            r"Error\s*:=\s*FALSE",  # Efface auto l'erreur
            r"IF.*Error.*THEN.*Reset",  # Reset auto si erreur
            r"AUTO.*RESTART",  # Mots-clés
        ]
        return any(re.search(p, code, re.IGNORECASE) for p in patterns)

    def report(self):
        """Affiche résumé."""
        print("\n" + "=" * 60)
        print(f"{BOLD}RÉSUMÉ AUDIT{RESET}")
        print("=" * 60)

        if self.passed:
            print(f"{GREEN}✓ Conformes ({len(self.passed)}):{RESET}")
            for name in self.passed:
                print(f"  • {name}")

        if self.violations:
            print(f"\n{RED}✗ Violations ({len(self.violations)}):{RESET}")
            for v in self.violations:
                print(f"  • {v}")

        if self.warnings:
            print(f"\n{YELLOW}⚠ À vérifier ({len(self.warnings)}):{RESET}")
            for w in self.warnings:
                print(f"  • {w}")

        if not self.violations:
            print(f"\n{GREEN}{BOLD}✓ Tous les fichiers sont conformes!{RESET}")
            return 0
        else:
            print(f"\n{RED}{BOLD}✗ Violations détectées. Corriger avant injection.{RESET}")
            return 1

if __name__ == "__main__":
    validator = CodesysValidator()

    # Lire fichiers depuis CLI ou depuis CODE/
    files = []
    if len(sys.argv) > 1:
        if sys.argv[1] == "--audit":
            files = sys.argv[2:] if len(sys.argv) > 2 else list(Path("CODE").glob("FB_*.xml"))
        else:
            files = sys.argv[1:]
    else:
        files = list(Path("CODE").glob("*.xml"))

    for f in files:
        validator.audit_file(f)

    sys.exit(validator.report())
