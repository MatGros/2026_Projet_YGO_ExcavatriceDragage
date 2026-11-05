import pytest

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor


def test_storage_lock_rejects_second_server(tmp_path):
    state = tmp_path / 'state.json'
    first = create_server(0, state)
    try:
        with pytest.raises(OSError):
            create_server(0, state)
    finally:
        first.supervision.close()
        first.server_close()
    second = create_server(0, state)
    second.supervision.close()
    second.server_close()


def test_invalid_configuration_is_not_overwritten(tmp_path):
    state = tmp_path / 'state.json'
    state.write_text('{broken', encoding='utf-8')
    service = Supervisor(state)
    with pytest.raises(ValueError, match='ecriture refusee'):
        service.command({'action': 'configure', 'model': 'local', 'allow_cloud': False})
    assert state.read_text(encoding='utf-8') == '{broken'
    service.close()
