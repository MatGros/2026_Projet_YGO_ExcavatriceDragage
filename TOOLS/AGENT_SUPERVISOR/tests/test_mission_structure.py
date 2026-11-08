from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor
from TOOLS.AGENT_SUPERVISOR.tests.test_reliability import make_service


def test_structured_mission_survives_restart_without_replacing_original(tmp_path):
    service, _, sid = make_service(tmp_path)
    try:
        original = service.snapshot()['sessions'][0]['initial_mission']
        structure = {'subject': 'T428', 'primary_goal': 'Lire le flux', 'current_goal': 'J5', 'unknowns': ''}
        service.command({'action': 'set_mission_structure', 'id': sid, 'structure': structure})
        restored = Supervisor(service.state_path, roots=service.roots, judge=lambda *_: {'alert': False})
        try:
            session = restored.snapshot()['sessions'][0]
            assert session['mission_structure'] == structure
            assert session['initial_mission'] == original
            assert session['mission'] == original
        finally:
            restored.close()
    finally:
        service.close()
