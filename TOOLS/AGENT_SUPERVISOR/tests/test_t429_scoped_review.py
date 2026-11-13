"""T429 (2026-11-13): a re-evaluation demanded by the operator must answer, even paused."""
import json
import time

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor

EVIDENCE = 'Lot validé et enregistré.'
COMMENT = 'C est corrige'


def wait(predicate, timeout=6):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate():
            return
        time.sleep(.01)
    assert predicate()


def write(path, role, text):
    with path.open('a', encoding='utf-8') as stream:
        stream.write(json.dumps({'type': role, 'message': {'content': text}}, ensure_ascii=False) + '\n')


def service(tmp_path, judge):
    root = tmp_path / 'sources'
    root.mkdir()
    source = root / 'session-a.jsonl'
    source.touch()
    svc = Supervisor(tmp_path / 'state.json', roots={'claude': [root]}, judge=judge,
                     poll_interval=.01, strict_assignments=True)
    sid = svc.command({'action': 'add', 'platform': 'claude', 'native_id': 'session-a',
                       'mission': 'Mission'})['sessions'][0]['id']
    return svc, source, sid


def alerting(judge):
    def wrapped(model, messages):
        return judge(model, messages)
    return wrapped


def test_re_evaluate_on_a_paused_session_returns_a_visible_verdict(tmp_path):
    """The operator asked for a verdict and never got one: the session was paused, so the
    full judge could not run. A scoped re-evaluation must answer and update the finding."""
    holder = {}
    seen = []

    def judge(model, messages):
        seen.append([m.get('role') for m in messages])
        if any(m.get('role') == 'user_comment' for m in messages):
            comment = next(m['text'] for m in messages if m.get('role') == 'user_comment')
            return {'alert': False, 'reviews': [{'alert_id': holder.get('id'),
                                                 'status': 'resolution_proposed',
                                                 'reason': 'Correction confirmee par l operateur.',
                                                 'evidence': comment.strip()}]}
        return {'alert': True, 'severity': 'warning', 'category': 'other',
                'reason': 'Preuve a verifier', 'evidence': EVIDENCE}

    svc, source, sid = service(tmp_path, judge)
    try:
        svc.command({'action': 'start'})
        write(source, 'assistant', EVIDENCE)
        wait(lambda: bool(svc.snapshot()['sessions'][0]['alerts']))
        alert = svc.snapshot()['sessions'][0]['alerts'][0]
        holder['id'] = alert['id']
        svc.command({'action': 'pause', 'id': sid})
        svc.command({'action': 'comment_alert', 'id': sid, 'alert_id': alert['id'], 'comment': COMMENT})
        wait(lambda: svc.snapshot()['sessions'][0]['alerts'][0]['review_state'] == 'complete')
        item = svc.snapshot()['sessions'][0]['alerts'][0]
        assert item['assessment']['status'] == 'resolution_proposed'
        assert item['version'] >= 2
        assert any('user_comment' in roles for roles in seen)
    finally:
        svc.close()


def test_scoped_review_without_a_citable_verdict_stays_unavailable(tmp_path):
    """An unverifiable verdict never invents a resolution."""

    def judge(model, messages):
        if any(m.get('role') == 'user_comment' for m in messages):
            return {'alert': False, 'reviews': [{'alert_id': 'inconnu', 'status': 'resolution_proposed',
                                                 'reason': 'Sans objet', 'evidence': 'texte absent'}]}
        return {'alert': True, 'severity': 'warning', 'category': 'other',
                'reason': 'Preuve a verifier', 'evidence': EVIDENCE}

    svc, source, sid = service(tmp_path, judge)
    try:
        svc.command({'action': 'start'})
        write(source, 'assistant', EVIDENCE)
        wait(lambda: bool(svc.snapshot()['sessions'][0]['alerts']))
        alert = svc.snapshot()['sessions'][0]['alerts'][0]
        svc.command({'action': 'pause', 'id': sid})
        svc.command({'action': 'comment_alert', 'id': sid, 'alert_id': alert['id'], 'comment': COMMENT})
        wait(lambda: svc.snapshot()['sessions'][0]['alerts'][0]['review_state'] == 'unavailable')
        item = svc.snapshot()['sessions'][0]['alerts'][0]
        assert item['assessment']['status'] != 'resolution_proposed'
    finally:
        svc.close()


def test_scoped_review_never_creates_a_new_finding(tmp_path):
    """A re-evaluation of one finding must not open another one."""
    created = []

    def judge(model, messages):
        if any(m.get('role') == 'user_comment' for m in messages):
            created.append(1)
            return {'alert': False, 'reviews': []}
        return {'alert': True, 'severity': 'warning', 'category': 'other',
                'reason': 'Preuve a verifier', 'evidence': EVIDENCE}

    svc, source, sid = service(tmp_path, judge)
    try:
        svc.command({'action': 'start'})
        write(source, 'assistant', EVIDENCE)
        wait(lambda: bool(svc.snapshot()['sessions'][0]['alerts']))
        count = len(svc.snapshot()['sessions'][0]['alerts'])
        alert = svc.snapshot()['sessions'][0]['alerts'][0]
        svc.command({'action': 'pause', 'id': sid})
        svc.command({'action': 'comment_alert', 'id': sid, 'alert_id': alert['id'], 'comment': COMMENT})
        wait(lambda: svc.snapshot()['sessions'][0]['alerts'][0]['review_state'] == 'unavailable')
        assert len(svc.snapshot()['sessions'][0]['alerts']) == count
    finally:
        svc.close()
