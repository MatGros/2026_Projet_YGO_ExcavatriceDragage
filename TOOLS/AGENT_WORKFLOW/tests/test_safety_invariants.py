"""Tests Pytest automatisés pour les invariants de sécurité machine critiques (AGENTS.md & CODE_QUALITY_STANDARDS.md).

Vérifie mécaniquement :
1. Absence totale de termes obsolètes (ex: CoupeEnable, FB_Watchdog).
2. Absence de SafeStop / StartStop sur les FB hors-mouvement (FB_Joystick, FB_Diag_*, etc.).
3. Respect de la convention des IDs 3 chiffres dans TASKS.yaml.
"""

import re
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = REPO_ROOT / "CODE"


@pytest.mark.safety
def test_no_banned_keywords_in_code():
    """Aucun fichier ST ne doit réintroduire le vocabulaire interdit (CoupeEnable, FB_Watchdog)."""
    banned_patterns = [
        (re.compile(r"\bCoupeEnable\b", re.IGNORECASE), "CoupeEnable est un vocabulaire interdit (AGENTS.md)"),
        (re.compile(r"\bFB_Watchdog\b", re.IGNORECASE), "FB_Watchdog applicatif interdit (CODESYS gère la périodicité)"),
    ]

    violations = []
    for st_file in CODE_DIR.rglob("*.st"):
        text = st_file.read_text(encoding="utf-8", errors="ignore")
        for pattern, msg in banned_patterns:
            matches = pattern.findall(text)
            if matches:
                violations.append(f"{st_file.relative_to(REPO_ROOT)}: {msg}")

    assert not violations, "Mots-clés interdits détectés dans le code source :\n" + "\n".join(violations)


@pytest.mark.safety
def test_no_safestop_on_non_movement_fbs():
    """SafeStop et StartStop sont réservés aux FB de mouvement (Treuils, Translation, Benne).

    Ne doivent PAS apparaître sur les FB d'acquisition, de joystick, de diagnostic ou de supervision.
    """
    non_movement_dirs = [
        CODE_DIR / "C_DIAG_RESEAUX",
        CODE_DIR / "D_JOYSTICK",
        CODE_DIR / "J_SUPERVISION",
    ]

    violations = []
    forbidden_vars = re.compile(r"^\s*(SafeStop|StartStop)\s*:\s*BOOL\b", re.MULTILINE | re.IGNORECASE)

    for d in non_movement_dirs:
        if not d.exists():
            continue
        # Uniquement sur les Function Blocks (FB_*.st), pas sur les DUTs / STRUCTs
        for st_file in d.glob("FB_*.st"):
            text = st_file.read_text(encoding="utf-8", errors="ignore")
            for match in forbidden_vars.finditer(text):
                violations.append(f"{st_file.relative_to(REPO_ROOT)} déclare {match.group(1)} (interdit hors mouvement)")

    assert not violations, "SafeStop/StartStop détecté sur un FB non-mouvement :\n" + "\n".join(violations)


@pytest.mark.safety
def test_tasks_yaml_ids_are_three_digits():
    """Tous les IDs de tâches dans TASKS.yaml doivent être normalisés sur 3 chiffres (ex: T001..T151)."""
    tasks_file = REPO_ROOT / "DOC" / "WFLOW" / "TASKS.yaml"
    if not tasks_file.exists():
        pytest.skip("TASKS.yaml non trouvé")

    text = tasks_file.read_text(encoding="utf-8")
    id_matches = re.findall(r'^\s*-\s*id:\s*"([^"]+)"', text, re.MULTILINE)

    invalid_ids = []
    for tid in id_matches:
        if re.match(r"^T\d{1,2}(-[A-Z0-9]+)?$", tid):
            invalid_ids.append(f"{tid} (doit être sur 3 chiffres ex: T{int(tid[1:].split('-')[0]):03d})")

    assert not invalid_ids, "Identifiants de tâches non conformes (moins de 3 chiffres) :\n" + "\n".join(invalid_ids)
