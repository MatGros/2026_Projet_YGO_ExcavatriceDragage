import json
import copy
import time

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor
from TOOLS.AGENT_SUPERVISOR.scripts.finding_lifecycle import prepare_alert
from TOOLS.AGENT_SUPERVISOR.tests.test_reliability import make_service, wait, write_message


def test_same_quote_different_categories_remain_distinct(tmp_path):
    calls = []
    def judge(_model, messages):
        calls.append(messages)
        return {'alert': True, 'severity': 'warning', 'category': 'contradiction' if len(calls) == 1 else 'ignored_instruction',
                'reason': 'Point a verifier', 'evidence': 'Phrase commune suffisamment longue.'}
    service, source, sid = make_service(tmp_path, judge)
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Phrase commune suffisamment longue.')
        wait(lambda: len(service.snapshot()['sessions'][0]['alerts']) == 1)
        write_message(source, 'user', 'Merci de verifier aussi la consigne.')
        wait(lambda: len(service.snapshot()['sessions'][0]['alerts']) == 2)
        alerts = service.snapshot()['sessions'][0]['alerts']
        assert {a['category'] for a in alerts} == {'contradiction', 'ignored_instruction'}
        assert len({a['id'] for a in alerts}) == 2
    finally:
        service.close()


def test_correction_review_updates_same_finding_without_closing_user_decision(tmp_path, monkeypatch):
    deliveries = []
    monkeypatch.setattr('TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service.deliver_agent_message', lambda *args: deliveries.append(args))
    aid = []
    def judge(_model, messages):
        if any(m['role'] == 'tool' for m in messages):
            return {'alert': False, 'reviews': [{'alert_id': aid[0], 'status': 'resolution_proposed', 'reason': 'Le contrat est corrigé, essais distincts.', 'evidence': 'status: PENDING'}]}
        return {'alert': True, 'severity': 'warning', 'reason': 'Validation sans preuve. ' * 40, 'evidence': 'Tout est validé.'}
    service, source, sid = make_service(tmp_path, judge)
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: bool(service.snapshot()['alerts']))
        alert = service.snapshot()['alerts'][0]; aid.append(alert['id'])
        assert len(alert['reason']) > 500
        assert deliveries == []
        with source.open('a', encoding='utf8') as stream:
            stream.write(json.dumps({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 'fix-contract', 'content': 'status: PENDING'}]}}) + '\n')
        wait(lambda: service.snapshot()['alerts'][0]['assessment']['status'] == 'resolution_proposed')
        snapshot = service.snapshot(); revised = snapshot['alerts'][0]
        assert revised['id'] == aid[0] and revised['version'] == 2
        assert revised['disposition'] == 'new' and revised['business_state'] == 'open'
        assert len(revised['history']) == 1
        assert snapshot['counts']['resolution_proposed'] == 1
        assert snapshot['counts']['warnings'] == 0
        assert service.notification_snapshot()['counts'] == snapshot['counts']
    finally:
        service.close()


def test_comment_and_human_close_persist_without_model_permission(tmp_path):
    service, _, sid = make_service(tmp_path)
    alert = prepare_alert(dict(id='stable', fingerprint='f', model='mock', reason='Avis initial', evidence='Citation initiale', severity='warning', disposition='new', created_at='now', last_occurrence='now', occurrences=1, acknowledged_at=None))
    service.sessions[sid]['alerts'].append(alert)
    service.command({'action': 'comment_alert', 'id': sid, 'alert_id': 'stable', 'comment': 'Voici ma justification.', 'review': True})
    service.command({'action': 'acknowledge', 'id': sid, 'alert_id': 'stable', 'disposition': 'resolved'})
    snapshot = service.snapshot()['sessions'][0]
    assert snapshot['counts']['closed'] == 1
    assert snapshot['counts']['follow_up'] == 0
    assert snapshot['analysis_state'] == 'review_pending'
    ref = snapshot['events'][0]['ref']
    restored = Supervisor(service.state_path, roots=service.roots, judge=lambda *_: {'alert': False})
    try:
        alert = restored.snapshot()['alerts'][0]
        assert alert['comments'][0]['text'] == 'Voici ma justification.'
        assert alert['business_state'] == 'closed'
        assert restored.snapshot()['sessions'][0]['events'][0]['ref'] == ref
    finally:
        restored.close(); service.close()


def test_no_alert_without_explicit_review_does_not_claim_resolution(tmp_path):
    service, source, sid = make_service(tmp_path, lambda *_: {'alert': False})
    service.sessions[sid]['alerts'].append(prepare_alert(dict(id='stable', fingerprint='f', model='mock', reason='Avis initial', evidence='Citation initiale', severity='warning', disposition='pending', created_at='now', last_occurrence='now', occurrences=1, acknowledged_at=None)))
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', "J'attends votre décision.")
        wait(lambda: service.snapshot()['sessions'][0]['last_analysis'] is not None)
        assert service.snapshot()['alerts'][0]['assessment']['status'] == 'active'
    finally:
        service.close()


def test_history_carries_prior_user_framing_without_future_go_and_excludes_ack(tmp_path):
    calls = []
    service, source, sid = make_service(tmp_path, lambda _, messages: (calls.append(messages) or {'alert': False}))
    try:
        service.command({'action': 'start'})
        wait(lambda: service.snapshot()['sessions'][0]['state'] == 'active')
        service.command({'action': 'pause', 'id': sid})
        write_message(source, 'user', 'GO J3 seulement ; J4 attend ma décision.')
        for i in range(12): write_message(source, 'assistant', f'Étape de diagnostic {i}.')
        write_message(source, 'assistant', 'VEILLEUR_ACK')
        write_message(source, 'user', 'GO J4 maintenant.')
        service.command({'action': 'resume', 'id': sid})
        service.command({'action': 'resume', 'id': sid, 'mode': 'history'})
        wait(lambda: service.snapshot()['sessions'][0]['recovery']['status'] == 'complete')
        assert len(calls) >= 2
        first_notices = '\n'.join(m['text'] for m in calls[0] if m['role'] == 'context_notice')
        second_notices = '\n'.join(m['text'] for m in calls[1] if m['role'] == 'context_notice')
        assert 'GO J4 maintenant' not in first_notices
        assert 'GO J3 seulement' in second_notices
        assert not any(m['text'] == 'VEILLEUR_ACK' for batch in calls for m in batch)
        assert len(service.snapshot()['sessions'][0]['framing']) == 2
    finally:
        service.close()


def test_more_than_twenty_findings_survive_reload(tmp_path):
    service, _, sid = make_service(tmp_path)
    for i in range(25):
        service.sessions[sid]['alerts'].append(prepare_alert(dict(id=str(i), fingerprint=str(i), model='mock', reason='Avis', evidence='Citation', severity='warning', disposition='seen', created_at='now', last_occurrence='now', occurrences=1, acknowledged_at=None)))
    service._persist()
    restored = Supervisor(service.state_path, roots=service.roots)
    try:
        assert restored.load_error is None
        assert len(restored.snapshot()['sessions'][0]['alerts']) == 25
        assert restored.notification_snapshot()['counts']['follow_up'] == 25
    finally:
        restored.close(); service.close()


def test_historical_user_choice_is_applied_once_without_outgoing_turn(tmp_path, monkeypatch):
    deliveries, calls = [], []
    monkeypatch.setattr('TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service.deliver_agent_message', lambda *args: deliveries.append(args))
    service, source, sid = make_service(tmp_path, lambda _, messages: (calls.append(messages) or {'alert': False}))
    alert = prepare_alert(dict(id='stable', fingerprint='f', model='mock', reason='Avis', evidence='Citation', severity='warning', disposition='new', created_at='now', last_occurrence='now', occurrences=1, acknowledged_at=None, workflow={'status': 'awaiting_choice', 'delivery_status': 'delivered'}))
    service.sessions[sid]['alerts'].append(alert)
    try:
        service.command({'action': 'start'})
        wait(lambda: service.snapshot()['sessions'][0]['state'] == 'active')
        service.command({'action': 'pause', 'id': sid})
        write_message(source, 'user', '2')
        write_message(source, 'assistant', 'Je propose une analyse, aucune modification.')
        service.command({'action': 'resume', 'id': sid})
        service.command({'action': 'resume', 'id': sid, 'mode': 'history'})
        wait(lambda: service.snapshot()['sessions'][0]['recovery']['status'] == 'complete')
        actual = service.snapshot()['alerts'][0]
        assert actual['disposition'] == 'pending'
        assert actual['workflow']['choice_source'] == 'history'
        assert actual['workflow']['delivery_status'] == 'not_sent_historical_decision'
        assert deliveries == []
        assert not any(m['text'] == '2' for batch in calls for m in batch)
        assert len([e for e in service.snapshot()['sessions'][0]['events'] if e['kind'] == 'historical_user_decision']) == 1
    finally:
        service.close()


def test_requested_review_with_missing_model_review_is_explicitly_unavailable(tmp_path):
    service, source, sid = make_service(tmp_path, lambda *_: {'alert': False})
    service.sessions[sid]['alerts'].append(prepare_alert(dict(id='stable', fingerprint='f', model='mock', reason='Avis', evidence='Citation', severity='warning', disposition='pending', created_at='now', last_occurrence='now', occurrences=1, acknowledged_at=None)))
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Éléments observables mais sans avis ciblé.')
        wait(lambda: service.snapshot()['sessions'][0]['last_analysis'] is not None)
        service.command({'action': 'comment_alert', 'id': sid, 'alert_id': 'stable', 'comment': 'Merci de réexaminer.', 'review': True})
        wait(lambda: service.snapshot()['alerts'][0].get('review_state') == 'unavailable')
        actual = service.snapshot()['alerts'][0]
        assert actual['review_error'] == 'review_missing_or_unverifiable'
        assert actual['assessment']['status'] == 'active'
        assert actual['comments'][0]['text'] == 'Merci de réexaminer.'
    finally:
        service.close()


def test_old_occurrence_after_close_preserves_entire_human_decision(tmp_path):
    calls = []
    def judge(_, messages):
        calls.append(messages)
        return dict(alert=True, severity='warning', category='unsupported_success', reason='Validation non étayée.', evidence='Tout est validé.')
    service, source, sid = make_service(tmp_path, judge)
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: bool(service.snapshot()['alerts']))
        aid = service.snapshot()['alerts'][0]['id']
        service.command({'action': 'acknowledge', 'id': sid, 'alert_id': aid, 'disposition': 'resolved', 'comment': 'Décision humaine conservée.'})
        before = copy.deepcopy(service.snapshot()['alerts'][0])
        assert before['closed_source']['max_event_index'] == 0
        old_calls = len(calls)
        write_message(source, 'user', 'Explique le contexte précédent.')
        wait(lambda: len(calls) > old_calls and service.snapshot()['sessions'][0]['last_analysis'] is not None)
        assert service.snapshot()['alerts'] == [before]
        assert service.snapshot()['counts']['follow_up'] == 0
    finally:
        service.close()


def test_verified_new_occurrence_after_close_creates_linked_idempotent_finding(tmp_path):
    def judge(_, messages):
        last = [m for m in messages if m['role'] == 'assistant'][-1]
        return dict(alert=True, severity='warning', category='unsupported_success', reason='Validation non étayée.', evidence='Tout est validé.', event_id=last['event_id'])
    service, source, sid = make_service(tmp_path, judge)
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: bool(service.snapshot()['alerts']))
        aid = service.snapshot()['alerts'][0]['id']
        service.command({'action': 'acknowledge', 'id': sid, 'alert_id': aid, 'disposition': 'resolved', 'comment': 'Premier problème traité.'})
        before = copy.deepcopy(service.snapshot()['alerts'][0])
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: len(service.snapshot()['alerts']) == 2)
        alerts = service.snapshot()['alerts']
        assert alerts[0] == before
        assert alerts[1]['previous_alert_id'] == aid
        assert alerts[1]['source_event_index'] == 1
        assert alerts[1]['workflow']['delivery_status'] == 'not_sent'
        assert service.snapshot()['counts']['closed'] == 1
        assert service.snapshot()['counts']['follow_up'] == 1
        service.command({'action': 'comment_alert', 'id': sid, 'alert_id': alerts[1]['id'], 'review': True})
        wait(lambda: service.snapshot()['alerts'][1]['occurrences'] == 2)
        assert len(service.snapshot()['alerts']) == 2
        assert service.snapshot()['alerts'][0] == before
    finally:
        service.close()


def test_ambiguous_or_broken_occurrence_is_visible_after_restart_not_silently_clear(tmp_path):
    judge = lambda *_: dict(alert=True, severity='warning', category='unsupported_success', reason='Validation non étayée.', evidence='Tout est validé.')
    service, source, sid = make_service(tmp_path, judge)
    restored = None
    try:
        service.command({'action': 'start'})
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: bool(service.snapshot()['alerts']))
        aid = service.snapshot()['alerts'][0]['id']
        service.command({'action': 'acknowledge', 'id': sid, 'alert_id': aid, 'disposition': 'resolved'})
        before = copy.deepcopy(service.snapshot()['alerts'][0])
        service.command({'action': 'pause', 'id': sid})
        service.close()
        restored = Supervisor(service.state_path, roots=service.roots, judge=judge, poll_interval=.01, strict_assignments=True)
        assert restored.sessions[sid]['source_generation'] == before['closed_source']['generation']
        restored.command({'action': 'start'})
        restored.command({'action': 'resume', 'id': sid})
        write_message(source, 'assistant', 'Tout est validé.')
        wait(lambda: restored.snapshot()['sessions'][0]['analysis_error'] == 'closed_finding_occurrence_unverified')
        assert restored.snapshot()['alerts'] == [before]
        assert restored.snapshot()['sessions'][0]['analysis_state'] == 'uncertain'
        assert restored.snapshot()['sessions'][0]['judge_proposal']['previous_alert_id'] == aid
        # Same size rewrite invalidates the closure prefix even with a uniquely named source event.
        source.write_text(source.read_text().replace('Tout est', 'Rien est'), encoding='utf8')
        result = dict(judge(None, None), event_id='exact')
        state, event = restored._closed_occurrence(restored.sessions[sid], before, result, [dict(role='assistant', text='Tout est validé.', event_id='exact', event_index=2)])
        assert (state, event) == ('uncertain', None)
        missing = copy.deepcopy(before); missing['closed_source'] = None
        assert restored._closed_occurrence(restored.sessions[sid], missing, result, [])[0] == 'uncertain'
    finally:
        if restored: restored.close()
        service.close()


def test_current_mission_cannot_authorize_earlier_historical_batch(tmp_path):
    calls = []
    service, source, sid = make_service(tmp_path, lambda _, messages: (calls.append(messages) or {'alert': False}))
    try:
        service.command({'action': 'start'})
        wait(lambda: service.snapshot()['sessions'][0]['state'] == 'active')
        service.command({'action': 'pause', 'id': sid})
        write_message(source, 'assistant', "J'ai réalisé une modification avant de demander l'accord.")
        service.command({'action': 'set_mission', 'id': sid, 'mission': 'AUTORISATION_FUTURE_UNIQUE : toutes les modifications sont désormais permises.'})
        service.command({'action': 'resume', 'id': sid})
        service.command({'action': 'resume', 'id': sid, 'mode': 'history'})
        wait(lambda: service.snapshot()['sessions'][0]['recovery']['status'] == 'complete')
        assert calls
        historical = calls[0]
        assert not any('AUTORISATION_FUTURE_UNIQUE' in m['text'] for m in historical)
        assert any('fiche manuelle actuelle est exclue' in m['text'] for m in historical)
    finally:
        service.close()
