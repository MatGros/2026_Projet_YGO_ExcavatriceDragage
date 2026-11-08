import json
from types import SimpleNamespace

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts import agent_chat


@pytest.mark.parametrize("text,expected", [
    ("1 — Le point est déjà corrigé", {"choice": "1", "rationale": "Le point est déjà corrigé"}),
    ("2", {"choice": "2", "rationale": ""}),
    ("3: Après le résultat G200", {"choice": "3", "rationale": "Après le résultat G200"}),
    ("2\nmerci", None),
    ("1", None),
    ("3 - ok", None),
])
def test_choice_parser_requires_explicit_compact_response(text, expected):
    assert agent_chat.parse_user_choice(text) == expected


def test_alert_message_requests_one_line_ack_and_waits_for_user():
    text = agent_chat.initial_alert_message({
        "severity": "warning", "category": "unsupported_success",
        "reason": "Validation annoncée, preuve absente.", "evidence": "G200 non lancé",
    })
    assert text.startswith("⚠️ Avertissement — Réussite sans preuve —")
    assert "une seule ligne" in text
    assert "VEILLEUR_ACK" in text
    assert "Ignorer" in text and "Examiner maintenant" in text and "Reporter" in text
    assert "motif obligatoire" in text and "condition obligatoire" in text
    assert "Attends ensuite le choix explicite de l’utilisateur" in text


@pytest.mark.parametrize("platform,expected_exe,expected_flag", [
    ("claude", "claude.exe", "--tools"),
    ("agy", "agy.exe", "--sandbox"),
])
def test_delivery_targets_the_exact_session_without_shell(platform, expected_exe, expected_flag, monkeypatch):
    session_id = "bb64a023-b104-436a-8d49-69ce0b715092"
    monkeypatch.setattr(agent_chat.shutil, "which", lambda name: expected_exe)
    captured = {}

    def fake_run(args, **kwargs):
        captured.update(args=args, kwargs=kwargs)
        key = "session_id" if platform == "claude" else "conversation_id"
        response = "VEILLEUR_ACK" if platform == "claude" else "VEILLEUR_ACK"
        value = {key: session_id, "result" if platform == "claude" else "response": response}
        return SimpleNamespace(returncode=0, stdout=json.dumps(value))

    result = agent_chat.deliver(platform, session_id, "Alerte synthétique", runner=fake_run)
    assert result == {"session_id": session_id, "response": "VEILLEUR_ACK"}
    assert captured["args"][0] == expected_exe
    assert session_id in captured["args"]
    assert expected_flag in captured["args"]
    assert captured["kwargs"]["stdin"] is agent_chat.subprocess.DEVNULL
    assert "shell" not in captured["kwargs"]


def test_delivery_rejects_mismatched_session_response(monkeypatch):
    session_id = "bb64a023-b104-436a-8d49-69ce0b715092"
    monkeypatch.setattr(agent_chat.shutil, "which", lambda _name: "claude.exe")
    def fake_run(_args, **_kwargs):
        return SimpleNamespace(returncode=0, stdout=json.dumps({"session_id": "00000000-0000-0000-0000-000000000001", "result": "VEILLEUR_ACK"}))
    with pytest.raises(agent_chat.DeliveryError, match="identifiant"):
        agent_chat.deliver("claude", session_id, "Alerte synthétique", runner=fake_run)


def test_dsh_is_explicitly_deferred():
    with pytest.raises(agent_chat.UnsupportedPlatform, match="DSH mis de côté"):
        agent_chat.deliver("dsh", "bb64a023-b104-436a-8d49-69ce0b715092", "Alerte")


def test_delivery_surfaces_bounded_cli_error_detail(monkeypatch):
    session_id = 'bb64a023-b104-436a-8d49-69ce0b715092'
    monkeypatch.setattr(agent_chat.shutil, 'which', lambda _name: 'claude.exe')
    def fake_run(_args, **_kwargs):
        return SimpleNamespace(returncode=1, stdout='', stderr='Could not resume session from another project directory')
    with pytest.raises(agent_chat.DeliveryError, match='another project directory'):
        agent_chat.deliver('claude', session_id, 'Alerte', runner=fake_run)


def test_background_stop_uses_full_uuid_and_checks_cli_result(monkeypatch):
    sid = "ebe3ca88-d30f-4113-a9eb-51df9de93f4d"
    monkeypatch.setattr(agent_chat.shutil, "which", lambda _name: "claude.exe")
    calls = []
    def run(args, **kwargs):
        calls.append(args)
        return SimpleNamespace(returncode=0, stdout=json.dumps([{"sessionId": sid, "kind": "background", "id": "ebe3ca88"}]) if "agents" in args else "stopped ebe3ca88", stderr="")
    agent_chat.stop_claude_background(sid, runner=run)
    assert calls == [["claude.exe", "agents", "--json"], ["claude.exe", "stop", "ebe3ca88"]]
    def failed(*args, **kwargs):
        return SimpleNamespace(returncode=1, stdout="", stderr="Session not found")
    with pytest.raises(agent_chat.DeliveryError, match="identifiee exactement"):
        agent_chat.stop_claude_background(sid, runner=failed)
