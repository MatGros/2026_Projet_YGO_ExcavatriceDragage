import json
import threading
import time

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor


def wait(predicate):
    end = time.monotonic() + 3
    while time.monotonic() < end:
        if predicate():
            return
        time.sleep(.01)
    assert predicate()


def write_message(path, role, text):
    with path.open('a', encoding='utf8') as stream:
        stream.write(json.dumps({'type': role, 'message': {'content': text}}) + '\n')


def make_service(tmp_path, judge=None, interval=.02):
    root = tmp_path / 'sources'
    root.mkdir(exist_ok=True)
    source = root / 'session-a.jsonl'
    source.touch()
    svc = Supervisor(tmp_path / 'state.json', roots={'claude': [root]}, judge=judge or (lambda m, x: {'alert': False}), poll_interval=interval, strict_assignments=True)
    snapshot = svc.command({'action': 'add', 'platform': 'claude', 'native_id': 'session-a', 'mission': 'Mission initiale'})
    return svc, source, snapshot['sessions'][0]['id']


def test_candidates_require_unique_existing_explicit_id(tmp_path):
    svc, source, sid = make_service(tmp_path)
    try:
        candidates = svc.candidates()['candidates']
        assert [(x['platform'], x['native_id'], x['matches']) for x in candidates] == [('claude', 'session-a', 1)]
        with pytest.raises(ValueError, match='introuvable'):
            svc.command({'action': 'add', 'platform': 'claude', 'native_id': 'unknown'})
        with pytest.raises(ValueError, match='claude.ai'):
            svc.command({'action': 'add', 'platform': 'claude', 'native_id': 'session_cloud_id'})
        sub = source.parent / 'duplicate'
        sub.mkdir()
        (sub / source.name).touch()
        assert svc.candidates()['candidates'][0]['matches'] == 2
        with pytest.raises(ValueError, match='ambigue'):
            svc.command({'action': 'add', 'platform': 'claude', 'native_id': 'session-a'})
    finally:
        svc.close()


def test_correct_id_preserves_mission_and_paused_state(tmp_path):
    svc, source, sid = make_service(tmp_path)
    other = source.parent / 'session-correcte.jsonl'
    other.touch()
    try:
        svc.command({'action':'pause', 'id':sid})
        with pytest.raises(ValueError):
            svc.command({'action':'reassign', 'id':sid, 'native_id':'inconnu'})
        assert svc.snapshot()['sessions'][0]['native_id'] == 'session-a'
        item = svc.command({'action':'reassign', 'id':sid, 'native_id':'session-correcte'})['sessions'][0]
        assert item['native_id'] == 'session-correcte'
        assert item['mission'] == 'Mission initiale' and item['state'] == 'paused'
        svc.command({'action':'start'})
        svc.command({'action':'resume', 'id':sid})
        wait(lambda: svc.snapshot()['sessions'][0]['state'] == 'active')
        assert svc.snapshot()['sessions'][0]['source'] == str(other)
    finally:
        svc.close()


def test_mission_edit_keeps_cursor_and_restore_preserves_alerts(tmp_path):
    judge = lambda model, messages: {'alert': True, 'severity': 'warning', 'reason': 'Preuve à vérifier', 'evidence': 'CLAIM NEEDS REVIEW'}
    svc, source, sid = make_service(tmp_path, judge)
    try:
        assert svc.snapshot()['sessions'][0]['context_truncated']
        write_message(source, 'assistant', 'CLAIM NEEDS REVIEW')
        svc.command({'action': 'set_mission', 'id': sid, 'mission': 'Cadrage actualisé'})
        svc.command({'action': 'start'})
        wait(lambda: bool(svc.snapshot()['alerts']))
        alert = svc.snapshot()['alerts'][0]
        svc.command({'action': 'acknowledge', 'id': sid, 'alert_id': alert['id'], 'disposition': 'seen'})
        restored = Supervisor(svc.state_path, roots=svc.roots, judge=judge)
        try:
            item = restored.snapshot()['sessions'][0]
            assert item['state'] == 'paused'
            assert item['initial_mission'] == 'Mission initiale'
            assert item['mission'] == 'Cadrage actualisé'
            assert item['alerts'][0]['disposition'] == 'seen'
        finally:
            restored.close()
    finally:
        svc.close()


@pytest.mark.parametrize('new_record', ['user', 'tool', 'missing'])
def test_inflight_result_is_discarded_on_source_change(tmp_path, new_record, monkeypatch):
    entered, release = threading.Event(), threading.Event()
    calls = []
    def judge(model, messages):
        calls.append(messages)
        if len(calls) == 1:
            entered.set()
            assert release.wait(3)
        return {'alert': True, 'severity': 'warning', 'reason': 'Proposition à vérifier', 'evidence': 'ANCIENNE REPONSE'}
    svc, source, sid = make_service(tmp_path, judge, interval=30)
    try:
        svc.command({'action': 'start'})
        write_message(source, 'assistant', 'ANCIENNE REPONSE')
        svc._wake.set()
        assert entered.wait(3)
        if new_record == 'user':
            write_message(source, 'user', 'Pivot : nouvelle instruction')
        elif new_record == 'tool':
            with source.open('a', encoding='utf8') as stream:
                stream.write(json.dumps({'type': 'tool', 'content': 'metadata'}) + '\n')
        else:
            original_stat = type(source).stat
            def failing_stat(path, *args, **kwargs):
                if path == source:
                    raise FileNotFoundError('test')
                return original_stat(path, *args, **kwargs)
            monkeypatch.setattr(type(source), 'stat', failing_stat)
        release.set()
        if new_record == 'missing':
            wait(lambda: svc.snapshot()['sessions'][0]['state'] == 'source_missing')
            assert not svc.snapshot()['alerts']
        else:
            wait(lambda: len(calls) >= 2)
            if new_record == 'user':
                assert any(m['text'] == 'Pivot : nouvelle instruction' for m in calls[1])
    finally:
        release.set()
        svc.close()


def test_context_budget_and_user_message_remains_private(tmp_path):
    calls = []
    svc, source, sid = make_service(tmp_path, lambda model, messages: calls.append(messages) or {'alert': False})
    try:
        svc.command({'action': 'start'})
        for n in range(8):
            write_message(source, 'user', f'PRIVATE-{n}-' + '界' * 3000)
        write_message(source, 'assistant', 'Réponse de travail')
        wait(lambda: bool(calls))
        assert len(json.dumps(calls[-1], ensure_ascii=False).encode('utf8')) <= 11000
        assert any('Historique partiel' in m['text'] for m in calls[-1])
        assert 'PRIVATE-' not in svc.state_path.read_text(encoding='utf8')
    finally:
        svc.close()


def test_valid_records_before_bad_json_remain_observable(tmp_path):
    svc, source, sid = make_service(tmp_path)
    try:
        with source.open('a', encoding='utf8') as stream:
            stream.write(json.dumps({'type': 'user', 'message': {'content': 'Instruction valide'}}) + '\n{bad json}\n')
        svc.command({'action': 'start'})
        wait(lambda: svc.snapshot()['sessions'][0]['state'] == 'parse_error')
        assert any(m['text'] == 'Instruction valide' for m in svc.sessions[sid]['context'])
        assert svc.snapshot()['sessions'][0]['analysis_state'] == 'unavailable'
    finally:
        svc.close()


def test_invalid_quote_retry_cannot_be_downgraded_to_clean(monkeypatch):
    import TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service as module
    class Response:
        def __init__(self, result): self.result = result
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, size): return json.dumps({'response': json.dumps(self.result)}).encode()
    invalid = {'alert': True, 'severity': 'warning', 'reason': 'A vérifier', 'evidence': 'citation inventée'}
    responses = iter([invalid, {'alert': False}])
    monkeypatch.setattr(module, 'check_model_consent', lambda *args: None)
    monkeypatch.setattr(module.urllib.request, 'urlopen', lambda *args, **kwargs: Response(next(responses)))
    result = module.ollama_judge('local', [{'role': 'assistant', 'text': 'Citation réelle.'}])
    assert result == invalid



def test_omniroute_judge_requires_explicit_consent_before_network(monkeypatch):
    import TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service as module
    called = []
    monkeypatch.setattr(module.urllib.request, "urlopen", lambda *a, **k: called.append(True))
    with pytest.raises(module.CloudConsentRequired):
        module.omniroute_judge("nvidia/nvidia/nemotron-3.5-bolt-e4b", [], allow_cloud=False)
    assert not called


def test_omniroute_judge_parses_sse_and_keeps_exact_source_citation(monkeypatch):
    import TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service as module
    class Response:
        headers = {"Content-Type": "text/event-stream"}
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, size):
            content = json.dumps({"alerts": [{"event_id": "e1", "evidence_span": "Je propose de modifier le code.",
                                               "priority": "warning", "reason": "Hors cadrage",
                                               "category": "scope_drift"}], "state_update": ""})
            chunks = [content[:41], content[41:83], content[83:]]
            frames = [{"choices": [{"delta": {"content": chunk}}]} for chunk in chunks]
            return ("\n".join("data: " + json.dumps(frame) for frame in frames) + "\ndata: [DONE]\n").encode()
    captured = []
    monkeypatch.setattr(module, "_openai_api_key", lambda: "test-secret")
    monkeypatch.setattr(module.urllib.request, "urlopen", lambda request, **kwargs: (captured.append(request), Response())[1])
    sent = []
    messages = [{"role": "mission", "text": "Demande: explication seulement, sans solution."},
                {"role": "assistant", "text": "Je propose de modifier le code."}]
    result = module.omniroute_judge("nvidia/nvidia/nemotron-3.5-bolt-e4b", messages,
                                    allow_cloud=True, on_request=lambda payload, attempt: sent.append((payload, attempt)))
    assert result["evidence"] == messages[1]["text"]
    assert result["severity"] == "warning"
    assert result["context_evidence"] == messages[0]["text"]
    assert module.alert_basis(result, messages)
    assert captured[0].full_url == "http://127.0.0.1:20128/v1/chat/completions"
    assert captured[0].get_header("Authorization") == "Bearer test-secret"
    assert len(sent) == 1 and sent[0][1] == 1
    assert "test-secret" not in json.dumps(sent[0][0])


def test_pivot_appended_between_poll_and_judge_is_not_published(tmp_path):
    calls = []
    def judge(model, messages):
        calls.append(messages)
        return {'alert': True, 'severity': 'warning', 'reason': 'Ancien contexte', 'evidence': 'ANCIENNE REPONSE'}
    svc, source, sid = make_service(tmp_path, judge)
    worker = None
    try:
        svc.running = True
        write_message(source, 'assistant', 'ANCIENNE REPONSE')
        with svc._lock:
            svc._poll_session(svc.sessions[sid])
        write_message(source, 'user', 'PIVOT ENTRE LECTURE ET JUGE')
        worker = threading.Thread(target=svc._judge_loop, daemon=True)
        svc._threads.append(worker)
        worker.start()
        wait(lambda: svc.sessions[sid].get('_rejudge_after_poll', False))
        assert not svc.snapshot()['alerts']
        with svc._lock:
            svc._poll_session(svc.sessions[sid])
        wait(lambda: len(calls) >= 2)
        assert any(m['text'] == 'PIVOT ENTRE LECTURE ET JUGE' for m in calls[1])
    finally:
        svc.close()


def test_history_is_explicit_bounded_and_session_specific(tmp_path):
    svc, first, first_id = make_service(tmp_path)
    second = first.parent / 'session-b.jsonl'
    second.touch()
    try:
        second_id = svc.command({'action':'add','platform':'claude','native_id':'session-b','mission':'Autre mission'})['sessions'][1]['id']
        write_message(first, 'user', 'Message de la première session')
        write_message(second, 'user', 'Message de la deuxième session')
        result = svc.history(first_id)
        assert result['session_id'] == first_id
        assert [m['text'] for m in result['messages']] == ['Message de la première session']
        assert svc.history(second_id)['messages'][0]['text'] == 'Message de la deuxième session'
        with pytest.raises(ValueError):
            svc.history('unknown')
        assert not svc.running, 'reading history does not start collection'
    finally:
        svc.close()


def test_scoped_chat_retains_separate_conversations_in_memory(tmp_path):
    svc, first, first_id = make_service(tmp_path)
    svc.chat = lambda model, messages, allow_cloud=False: 'Réponse consultative'
    second = first.parent / 'session-b.jsonl'
    second.touch()
    try:
        second_id = svc.command({'action':'add','platform':'claude','native_id':'session-b','mission':'Autre'})['sessions'][1]['id']
        svc.command({'action':'start'})
        svc.command({'action':'chat','session_id':first_id,'text':'Question A'})
        wait(lambda: svc.snapshot()['chat']['state'] == 'idle')
        svc.command({'action':'chat','session_id':second_id,'text':'Question B'})
        wait(lambda: svc.snapshot()['chat']['state'] == 'idle')
        sessions = {s['id']:s for s in svc.snapshot()['sessions']}
        assert sessions[first_id]['chat_messages'][0]['text'] == 'Question A'
        assert sessions[second_id]['chat_messages'][0]['text'] == 'Question B'
        assert 'Question A' not in svc.state_path.read_text(encoding='utf8')
    finally:
        svc.close()


def test_scoped_chat_is_restored_only_when_persistence_enabled(tmp_path):
    svc, source, sid = make_service(tmp_path)
    svc.persist_chat = True
    svc.chat = lambda model, messages, allow_cloud=False: 'Réponse sauvegardée'
    try:
        svc.command({'action':'start'})
        svc.command({'action':'chat','session_id':sid,'text':'Question sauvegardée'})
        wait(lambda: svc.snapshot()['chat']['state'] == 'idle')
        restored = Supervisor(svc.state_path, roots=svc.roots, persist_chat=True)
        try:
            messages = restored.snapshot()['sessions'][0]['chat_messages']
            assert [m['text'] for m in messages] == ['Question sauvegardée', 'Réponse sauvegardée']
            assert restored.snapshot()['sessions'][0]['state'] == 'paused'
        finally:
            restored.close()
    finally:
        svc.close()


def test_legacy_chat_import_never_overwrites_existing_messages(tmp_path):
    svc, _, sid = make_service(tmp_path)
    svc.persist_chat = True
    old = [{'role':'user', 'text':'Message conservé', 'created_at':'2026-11-04T00:00:00Z'}]
    try:
        svc.command({'action':'import_chat','session_id':sid,'messages':old})
        with pytest.raises(ValueError, match='ecrasement'):
            svc.command({'action':'import_chat','session_id':sid,'messages':old})
        restored = Supervisor(svc.state_path, roots=svc.roots, persist_chat=True)
        try:
            assert restored.snapshot()['sessions'][0]['chat_messages'] == old
        finally:
            restored.close()
    finally:
        svc.close()


def test_visible_judge_input_matches_attempted_ollama_request(tmp_path, monkeypatch):
    import TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service as module
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, size): return json.dumps({'response':'{"alert":false}'}).encode()
    captured=[]
    monkeypatch.setattr(module, 'check_model_consent', lambda *args: None)
    def open_request(request, **kwargs):
        captured.append(json.loads(request.data))
        return Response()
    monkeypatch.setattr(module.urllib.request, 'urlopen', open_request)
    root = tmp_path / 'sources'; root.mkdir()
    source = root / 'session-a.jsonl'; source.touch()
    svc = Supervisor(tmp_path / 'state.json', roots={'claude':[root]}, poll_interval=.02, strict_assignments=True)
    try:
        item=svc.command({'action':'add','platform':'claude','native_id':'session-a','mission':'Objectif visible'})['sessions'][0]
        assert item['judge_request'] is None
        svc.command({'action':'start'})
        write_message(source, 'assistant', 'Message réellement présenté')
        wait(lambda: svc.snapshot()['sessions'][0]['analysis_state'] == 'no_alert')
        request=svc.snapshot()['sessions'][0]['judge_request']
        assert request['status'] == 'analyse'
        assert request['payload'] == captured[-1]
        assert 'Message réellement présenté' in request['payload']['prompt']
    finally:
        svc.close()


def test_repeat_with_same_exact_quote_keeps_user_disposition(tmp_path):
    calls=[]
    def judge(model,messages):
        calls.append(messages)
        return {'alert':True,'severity':'warning','reason':'Formulation '+str(len(calls)),'evidence':'Même constat vérifiable'}
    svc, source, sid = make_service(tmp_path, judge)
    try:
        svc.command({'action':'start'})
        write_message(source,'assistant','Même constat vérifiable')
        wait(lambda: len(svc.snapshot()['alerts'])==1)
        alert=svc.snapshot()['alerts'][0]
        svc.command({'action':'acknowledge','id':sid,'alert_id':alert['id'],'disposition':'resolved'})
        write_message(source,'assistant','Même constat vérifiable')
        wait(lambda: svc.snapshot()['alerts'][0]['occurrences']==2)
        assert len(svc.snapshot()['alerts'])==1
        assert svc.snapshot()['alerts'][0]['disposition']=='resolved'
        assert any('Alertes précédentes' in m['text'] and 'resolved' in m['text'] for m in calls[-1])
    finally:
        svc.close()


def test_alert_basis_requires_explicit_claim_and_relevant_counterquote():
    from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import alert_basis
    messages=[{'role':'user','text':'Ne relance plus ce test.'},
              {'role':'assistant','text':'Je relance encore ce test.'}]
    assert not alert_basis({'category':'unsupported_success','evidence':'le résultat reste à vérifier'}, messages)
    assert alert_basis({'category':'unsupported_success','evidence':'Tout est validé, même si le journal reste à vérifier'}, messages)
    assert alert_basis({'category':'unsupported_success','evidence':'Le test a réussi ; aucun journal consulté'}, messages)
    assert not alert_basis({'category':'unsupported_success','evidence':'Le résultat est non validé'}, messages)
    assert alert_basis({'category':'ignored_instruction','evidence':'Je relance encore ce test.','context_evidence':'Ne relance plus ce test.'}, messages)
    assert not alert_basis({'category':'ignored_instruction','evidence':'Je relance encore ce test.','context_evidence':'Consigne inventée'}, messages)


def test_unauthorized_action_requires_completed_action_and_exact_anchor():
    from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import alert_basis
    mission={"role":"mission","text":"Interdiction: ne pas modifier CODE ni pousser sur main."}
    positives=["J'ai modifie CODE malgre l'interdiction.", "Le fichier a ete modifie malgre l'interdiction.", "J'ai pousse sur main malgre l'interdiction."]
    for quote in positives:
        messages=[mission,{"role":"assistant","text":quote}]
        assert alert_basis({"category":"unauthorized_action","evidence":quote, "context_evidence":mission["text"]}, messages)
    messages=[mission,{"role":"assistant","text":"Je vais modifier CODE."}]
    assert not alert_basis({"category":"unauthorized_action","evidence":"Je vais modifier CODE", "context_evidence":mission["text"]}, messages)
    assert not alert_basis({"category":"unauthorized_action","evidence":"J'ai pousse sur main", "context_evidence":"Autorisation donnee."}, messages)


@pytest.mark.parametrize('text,expected', [
    ('Le résultat reste à vérifier dans son journal', 'uncertain'),
    ('Le résultat reste à vérifier mais tout est validé', 'alert'),
])
def test_production_judge_insufficient_basis_is_visible_not_silenced(tmp_path, monkeypatch, text, expected):
    import TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service as module
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, size):
            return json.dumps({'response':json.dumps({'alert':True,'severity':'warning','reason':'À vérifier','evidence':text,'category':'unsupported_success'})}).encode()
    monkeypatch.setattr(module,'check_model_consent',lambda *a:None)
    monkeypatch.setattr(module.urllib.request,'urlopen',lambda *a,**kw:Response())
    root=tmp_path/'sources';root.mkdir();source=root/'session-a.jsonl';source.touch()
    svc=Supervisor(tmp_path/'state.json',roots={'claude':[root]},poll_interval=.02,strict_assignments=True)
    try:
        svc.command({'action':'add','platform':'claude','native_id':'session-a','mission':'Vérifier'})
        svc.command({'action':'start'});write_message(source,'assistant',text)
        wait(lambda: svc.snapshot()['sessions'][0]['analysis_state']==expected)
        result=svc.snapshot()['sessions'][0]
        if expected=='uncertain':
            assert not result['alerts'] and result['judge_proposal']['evidence']==text
        else:
            assert len(result['alerts'])==1
    finally:
        svc.close()
