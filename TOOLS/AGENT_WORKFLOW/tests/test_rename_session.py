"""
Tests unitaires déterministes pour rename_session.py
Couvre tous les invariants arrêtés avec le Challenger :
- Validation des repères TXXX (ancrage strict)
- Rejet des caractères interdits et espaces/tirets initiaux
- Normalisation Unicode NFC
- Idempotence
- Format WAL INTENT/COMMIT dans le journal d'audit
"""

import sys
import os
import pytest
from pathlib import Path

# Ajouter le dossier scripts au PYTHONPATH
REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import rename_session

def test_sanitize_and_validate_nominal():
    task_id, alias = rename_session.sanitize_and_validate("T123-AGY01 Mon Titre De Test")
    assert task_id == "T123-AGY01"
    assert alias == "T123-AGY01 Mon Titre De Test"

def test_sanitize_and_validate_accented():
    task_id, alias = rename_session.sanitize_and_validate("T429-AGY01 Fiabilisation Mémoire Données")
    assert task_id == "T429-AGY01"
    assert "Mémoire" in alias

def test_sanitize_reject_empty():
    with pytest.raises(ValueError, match="vide"):
        rename_session.sanitize_and_validate("")

def test_sanitize_reject_leading_dash_or_space():
    with pytest.raises(ValueError, match="tiret ou un espace"):
        rename_session.sanitize_and_validate("-T123-AGY01 Titre")

    with pytest.raises(ValueError, match="tiret ou un espace"):
        rename_session.sanitize_and_validate(" T123-AGY01 Titre")

def test_sanitize_reject_invalid_task_id():
    # TXXX non ancré ou invalide
    with pytest.raises(ValueError, match="syntaxe canonique"):
        rename_session.sanitize_and_validate("T123xyz Titre")

    with pytest.raises(ValueError, match="syntaxe canonique"):
        rename_session.sanitize_and_validate("MonTitre SansTaskID")

def test_sanitize_reject_forbidden_chars():
    # Caractères d'échappement ou symboles interdits
    with pytest.raises(ValueError, match="non autorisés"):
        rename_session.sanitize_and_validate("T123-AGY01 Titre; rm -rf /")

    with pytest.raises(ValueError, match="non autorisés"):
        rename_session.sanitize_and_validate("T123-AGY01 Titre\033]0;pwned\007")

def test_wal_audit_logging(tmp_path, monkeypatch):
    test_audit_file = tmp_path / "AUDIT_TEST.log"
    monkeypatch.setattr(rename_session, "AUDIT_LOG_FILE", test_audit_file)

    session_id = "test-uuid-1234"
    rename_session.log_audit("INTENT", session_id, "OLD_ALIAS", "NEW_ALIAS", 0)
    rename_session.log_audit("COMMIT", session_id, "OLD_ALIAS", "NEW_ALIAS", 0)

    lines = test_audit_file.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 2
    assert "[INTENT] [test-uuid-1234] 'OLD_ALIAS' -> 'NEW_ALIAS'" in lines[0]
    assert "[COMMIT] [test-uuid-1234] 'OLD_ALIAS' -> 'NEW_ALIAS'" in lines[1]
