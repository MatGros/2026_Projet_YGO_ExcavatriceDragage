"""Tests unitaires et d'intégration pour review_session.py (T429)."""
from __future__ import annotations

import json
from unittest.mock import patch
import pytest

from TOOLS.AGENT_SUPERVISOR.scripts import review_session


def fake_state_clean():
    return {
        "running": True,
        "last_poll_at": "2026-11-09T09:00:00Z",
        "sessions": [
            {
                "id": "s1",
                "native_id": "92b06c8f-5797-438b-b97f-8534e7a81953",
                "platform": "agy",
                "alias": "T429-AGY01 Fiabilisation Veilleur",
                "enabled": True,
                "state": "active",
                "alerts": [
                    {
                        "id": "a0_closed",
                        "severity": "warning",
                        "business_state": "closed",
                        "disposition": "resolved",
                        "reason": "Ancien point réglé"
                    }
                ]
            }
        ]
    }


def fake_state_with_alerts():
    return {
        "running": True,
        "last_poll_at": "2026-11-09T09:15:00Z",
        "sessions": [
            {
                "id": "s1",
                "native_id": "92b06c8f-5797-438b-b97f-8534e7a81953",
                "platform": "agy",
                "alias": "T429-AGY01 Fiabilisation Veilleur",
                "enabled": True,
                "state": "active",
                "alerts": [
                    {
                        "id": "a1_warning_old",
                        "severity": "warning",
                        "business_state": "open",
                        "title": "Avertissement ancien",
                        "reason": "Détail warning 1",
                        "evidence": "Citation W1",
                        "created_at": "2026-11-09T08:00:00Z",
                        "version": 1
                    },
                    {
                        "id": "a2_alarm_recent",
                        "severity": "error",
                        "business_state": "open",
                        "title": "Alarme critique",
                        "reason": "Détail alarme 2",
                        "evidence": "Citation A2",
                        "created_at": "2026-11-09T08:30:00Z",
                        "version": 2
                    },
                    {
                        "id": "a3_warning_recent",
                        "severity": "warning",
                        "business_state": "open",
                        "title": "Avertissement récent",
                        "reason": "Détail warning 3",
                        "evidence": "Citation W3",
                        "created_at": "2026-11-09T09:00:00Z",
                        "version": 1
                    }
                ]
            }
        ]
    }


def fake_state_ambiguous():
    return {
        "running": True,
        "sessions": [
            {
                "id": "s1",
                "native_id": "92b06c8f-5797-438b-b97f-8534e7a81953",
                "platform": "agy",
                "alias": "Session AGY",
                "enabled": True,
                "state": "active",
                "alerts": []
            },
            {
                "id": "s2",
                "native_id": "4819768b-5d7e-4c21-acf7-463ccf2d7093",
                "platform": "claude",
                "alias": "Session Claude",
                "enabled": True,
                "state": "active",
                "alerts": []
            }
        ]
    }


def test_help_text():
    out = review_session.run_review("help")
    assert "Usage :" in out
    assert "/review-session-supervisor" in out
    assert "help" in out


def test_clean_session_returns_healthy_summary():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_clean()):
        out = review_session.run_review()
        assert "✅ Supervisor — Aucun point ouvert" in out
        assert "Session saine" in out
        assert "1 constat(s) clos" in out


def test_default_picks_alarm_first():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_with_alerts()):
        out = review_session.run_review()
        # Doit choisir l'alarme a2_alarm_recent en priorité malgré qu'elle soit plus récente que a1
        assert "Point prioritaire [1/3]" in out
        assert "🔴 Alarm" in out
        assert "Alarme critique" in out
        assert "a2_alarm" in out
        assert "Citation A2" in out
        assert "Reste 2 autre(s) alerte(s) en attente" in out


def test_filter_all_returns_full_list():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_with_alerts()):
        out = review_session.run_review("all")
        assert "3 point(s) à examiner" in out
        assert "1 Alarm · 2 Warning" in out
        assert "1. 🔴 Alarm" in out
        assert "2. ⚠️ Warning" in out
        assert "3. ⚠️ Warning" in out
        assert "3/3 références" in out


def test_filter_warning_picks_first_warning():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_with_alerts()):
        out = review_session.run_review("warning")
        assert "⚠️ Warning" in out
        assert "Avertissement ancien" in out
        assert "a1_warni" in out


def test_filter_index_picks_specific_item():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_with_alerts()):
        out = review_session.run_review("2")
        assert "Point prioritaire [2/3]" in out
        assert "Avertissement ancien" in out


def test_filter_short_id():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_with_alerts()):
        out = review_session.run_review("a3_warn")
        assert "Avertissement récent" in out
        assert "Citation W3" in out


def test_ambiguous_session_fails_closed_with_remedy():
    # Deux sessions actives, sans requested_id, et sans lock exclusif discriminant
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_ambiguous()), \
         patch("pathlib.Path.exists", return_value=False):
        out = review_session.run_review()
        assert "⚠️ Supervisor — Session ambiguë" in out
        assert "--session 92b06c8f" in out
        assert "--session 4819768b" in out


def test_explicit_session_resolves_ambiguity():
    with patch("TOOLS.AGENT_SUPERVISOR.scripts.review_session.fetch_supervision_state", return_value=fake_state_ambiguous()):
        out = review_session.run_review(session_id="4819768b")
        assert "✅ Supervisor — Aucun point ouvert" in out
        assert "Session Claude" in out


def test_review_session_cli_encoding_cp1252():
    import os
    import subprocess
    import sys
    env = os.environ.copy()
    env["PYTHONIOENCODING"] = "cp1252"
    res = subprocess.run([sys.executable, review_session.__file__, "help"], capture_output=True, env=env)
    assert res.returncode == 0
    assert b"Agent Supervisor" in res.stdout
