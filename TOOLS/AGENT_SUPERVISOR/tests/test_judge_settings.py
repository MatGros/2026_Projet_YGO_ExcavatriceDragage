import pytest
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor, validate_judge_settings
from TOOLS.AGENT_SUPERVISOR.tests.test_reliability import make_service


def test_settings_persist_and_invalid_update_does_not_change_config(tmp_path):
    path = tmp_path / 'state.json'
    service = Supervisor(path, judge=lambda *_: {'alert': False})
    try:
        settings = validate_judge_settings(dict(context_messages=24, context_chars=9000, model_context_tokens=32768, output_tokens=2000))
        service.command(dict(action='configure', model='qwen3:8b', allow_cloud=False, judge_settings=settings))
        assert service.snapshot()['judge_settings'] == settings
        with pytest.raises(ValueError):
            service.command(dict(action='configure', model='other', allow_cloud=False, judge_settings={'context_chars':100000}))
        assert service.snapshot()['model'] == 'qwen3:8b'
        restored = Supervisor(path, judge=lambda *_: {'alert': False})
        try:
            assert restored.snapshot()['judge_settings'] == settings
        finally:
            restored.close()
    finally:
        service.close()


def test_reducing_context_limits_preserves_loadable_state(tmp_path):
    service, _, sid = make_service(tmp_path)
    try:
        session = service.sessions[sid]
        session['context'] = [{'role': 'assistant', 'text': str(i) * 600} for i in range(8)]
        settings = validate_judge_settings({'context_messages': 4, 'context_chars': 2000})
        service.command({'action': 'configure', 'model': 'qwen3:8b', 'allow_cloud': False, 'judge_settings': settings})
        restored = Supervisor(service.state_path, roots=service.roots, judge=lambda *_: {'alert': False})
        try:
            assert restored.load_error is None
            context = restored.sessions[sid]['context']
            assert [item['text'][0] for item in context] == ['5', '6', '7']
            assert restored.sessions[sid]['context_truncated'] is True
        finally:
            restored.close()
    finally:
        service.close()
