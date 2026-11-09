import json
import threading
import time

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor


def wait_for(predicate, timeout=3):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if predicate(): return
        time.sleep(.01)
    assert predicate()


def make_service(tmp_path, judge):
    root=tmp_path/'sources'; root.mkdir()
    source=root/'session-a.jsonl'; source.touch()
    service=Supervisor(tmp_path/'state.json', roots={'claude':[root]}, judge=judge, poll_interval=.01, strict_assignments=True)
    session_id=service.command({'action':'add','platform':'claude','native_id':'session-a','alias':'TEST','mission':'Mission de test'})['sessions'][0]['id']
    return service, source, session_id


def append_message(path, role, text):
    with path.open('a',encoding='utf-8') as stream:
        stream.write(json.dumps({'type':role,'message':{'content':text}},ensure_ascii=False)+'\n')


def test_resume_offers_choice_and_normal_mode_skips_confirmed_gap(tmp_path):
    calls=[]
    service,source,sid=make_service(tmp_path,lambda _model,messages:(calls.append(messages) or {'alert':False}))
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        append_message(source,'user','Le lot 2 peut commencer ?')
        append_message(source,'assistant','Oui, je prépare le lot 2.')
        service.command({'action':'resume','id':sid})
        item=service.snapshot()['sessions'][0]
        assert item['state']=='paused'
        assert item['recovery']['status']=='gap_available'
        assert item['recovery']['message_count']==2
        assert item['recovery']['can_catch_up'] is True
        assert calls==[], 'la détection du delta ne doit pas appeler le juge'
        service.command({'action':'resume','id':sid,'mode':'normal'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        item=service.snapshot()['sessions'][0]
        assert item['recovery']['status']=='skipped'
        assert len(calls)==0, 'la reprise normale ne doit pas analyser les messages ignorés'
    finally:
        service.close()


def test_resume_without_gap_does_not_prompt_or_call_judge(tmp_path):
    calls=[]
    service,_source,sid=make_service(tmp_path,lambda _model,messages:(calls.append(messages) or {'alert':False}))
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        service.command({'action':'resume','id':sid})
        item=service.snapshot()['sessions'][0]
        assert item['state']=='active'
        assert item['recovery']['status']=='none'
        assert calls==[]
    finally:
        service.close()


def test_restored_jsonl_cursor_reads_delta_and_rejects_rewritten_prefix(tmp_path):
    from TOOLS.AGENT_SUPERVISOR.scripts.session_watcher import JsonlAppendWatcher
    source=tmp_path/'transcript.jsonl'
    source.write_text('{"type":"user","message":{"content":"before"}}\n',encoding='utf-8')
    watcher=JsonlAppendWatcher(source)
    checkpoint=watcher.checkpoint()
    append_message(source,'assistant','after')
    restored=JsonlAppendWatcher.restore(source,checkpoint)
    result=restored.poll()
    assert result.state=='active'
    assert [event['message']['content'] for event in result.events]==['after']

    changed=tmp_path/'rewritten.jsonl'
    changed.write_text('{"type":"user","message":{"content":"before"}}\n',encoding='utf-8')
    old=JsonlAppendWatcher(changed).checkpoint()
    changed.write_text('{"type":"user","message":{"content":"other"}}\n',encoding='utf-8')
    try:
        JsonlAppendWatcher.restore(changed,old)
    except ValueError as exc:
        assert str(exc)=='continuity_unverified'
    else:
        raise AssertionError('same-size prefix rewrite must invalidate the cursor')


def test_history_choice_analyzes_exact_gap_in_order_and_persists_completion(tmp_path):
    calls=[]
    service,source,sid=make_service(tmp_path,lambda _model,messages:(calls.append(messages) or {'alert':False}))
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        append_message(source,'user','Question historique exacte')
        append_message(source,'assistant','Réponse historique exacte')
        service.command({'action':'resume','id':sid})
        service.command({'action':'resume','id':sid,'mode':'history'})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='complete')
        assert len(calls)==1
        observed=[(item['role'],item['text']) for item in calls[0] if item['role'] in ('user','assistant')]
        assert observed==[('user','Question historique exacte'),('assistant','Réponse historique exacte')]
        persisted=json.loads(service.state_path.read_text(encoding='utf-8'))['sessions'][0]
        assert persisted['recovery']['status']=='complete'
        assert persisted['recovery']['message_count']==2
    finally:
        service.close()


def test_historical_batches_survive_judge_error_and_retry_without_skipping(tmp_path):
    calls=[]
    def judge(_model,messages):
        observed=[item['text'] for item in messages if item['role'] in ('user','assistant')]
        calls.append(observed)
        if len(calls)==1:
            raise TimeoutError('synthetic judge timeout')
        return {'alert':False}
    service,source,sid=make_service(tmp_path,judge)
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        for index in range(13):
            append_message(source,'user',f'Historique {index:02d}')
        service.command({'action':'resume','id':sid})
        assert service.snapshot()['sessions'][0]['recovery']['batch_count']==2
        service.command({'action':'resume','id':sid,'mode':'history'})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='error')
        persisted=json.loads(service.state_path.read_text(encoding='utf-8'))['sessions'][0]['recovery']
        assert persisted['batch_index']==0 and persisted['batches'][0][0]['text']=='Historique 00'
        service.command({'action':'retry_recovery','id':sid})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='complete')
        assert calls[0]==calls[1], 'timeout retry replays the same deterministic first batch'
        assert calls[2]==[f'Historique {index:02d}' for index in range(12,13)]
    finally:
        service.close()


def test_source_rewrite_keeps_staged_recovery_and_allows_explicit_retry(tmp_path):
    entered, release = threading.Event(), threading.Event()
    calls=[]
    def judge(_model, messages):
        calls.append([item['text'] for item in messages if item['role'] in ('user','assistant')])
        if len(calls)==1:
            entered.set()
            assert release.wait(3)
        return {'alert':False}
    service,source,sid=make_service(tmp_path,judge)
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        append_message(source,'user','Historique à garder')
        service.command({'action':'resume','id':sid})
        service.command({'action':'resume','id':sid,'mode':'history'})
        assert entered.wait(3)

        source.write_text(json.dumps({'type':'user','message':{'content':'Réécriture'}})+'\n',encoding='utf-8')
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery'].get('source_unverified') is True)
        staged=service.sessions[sid]['recovery']
        assert staged['status']=='error'
        assert staged['batch_index']==0
        assert staged['batches'][0][0]['text']=='Historique à garder'
        release.set()

        service.command({'action':'retry_recovery','id':sid})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='complete')
        item=service.snapshot()['sessions'][0]
        assert item['enabled'] is False
        assert item['state']=='source_reset'
        assert calls[-1]==['Historique à garder']
    finally:
        release.set()
        service.close()


def test_source_rewrite_after_preview_preserves_delta_for_retry(tmp_path):
    calls=[]
    service,source,sid=make_service(tmp_path,lambda _model,messages:(calls.append([m['text'] for m in messages if m['role'] in ('user','assistant')]) or {'alert':False}))
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        append_message(source,'user','Delta vérifié avant choix')
        service.command({'action':'resume','id':sid})
        assert service.snapshot()['sessions'][0]['recovery']['status']=='gap_available'

        source.write_text(json.dumps({'type':'user','message':{'content':'Transcript remplacé'}})+'\n',encoding='utf-8')
        service.command({'action':'resume','id':sid,'mode':'history'})
        item=service.snapshot()['sessions'][0]
        assert item['state']=='paused' and item['recovery']['status']=='error'
        assert item['recovery']['source_unverified'] is True
        assert service.sessions[sid]['recovery']['batches'][0][0]['text']=='Delta vérifié avant choix'
        assert calls==[]

        service.command({'action':'retry_recovery','id':sid})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='complete')
        item=service.snapshot()['sessions'][0]
        assert item['state']=='source_reset' and item['enabled'] is False
        assert calls==[['Delta vérifié avant choix']]
    finally:
        service.close()


def test_source_move_after_preview_preserves_delta_until_retry(tmp_path):
    calls=[]
    service,source,sid=make_service(tmp_path,lambda _model,messages:(calls.append([m['text'] for m in messages if m['role'] in ('user','assistant')]) or {'alert':False}))
    moved_dir=source.parent/'renamed-worktree'
    moved_dir.mkdir()
    moved_source=moved_dir/source.name
    try:
        service.command({'action':'start'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        service.command({'action':'pause','id':sid})
        append_message(source,'user','Delta conservé malgré le déplacement')
        service.command({'action':'resume','id':sid})
        assert service.snapshot()['sessions'][0]['recovery']['status']=='gap_available'

        source.rename(moved_source)
        service.command({'action':'resume','id':sid,'mode':'history'})
        item=service.snapshot()['sessions'][0]
        assert item['state']=='paused' and item['recovery']['status']=='error'
        assert item['recovery']['source_unverified'] is True
        assert service.sessions[sid]['recovery']['batches'][0][0]['text']=='Delta conservé malgré le déplacement'
        assert calls==[]

        service.command({'action':'retry_recovery','id':sid})
        wait_for(lambda:service.snapshot()['sessions'][0]['recovery']['status']=='complete')
        item=service.snapshot()['sessions'][0]
        assert item['state']=='source_reset' and item['enabled'] is False
        assert calls==[['Delta conservé malgré le déplacement']]

        service.command({'action':'resume','id':sid,'mode':'normal'})
        wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
        assert service.snapshot()['sessions'][0]['source']==str(moved_source)
    finally:
        service.close()


def test_restart_preserves_context_and_detects_only_new_verified_delta(tmp_path):
    calls=[]
    judge=lambda _model,messages:(calls.append(messages) or {'alert':False})
    service,source,sid=make_service(tmp_path,judge)
    service.command({'action':'start'})
    wait_for(lambda:service.snapshot()['sessions'][0]['state']=='active')
    append_message(source,'user','Message observé avant pause')
    wait_for(lambda:service.snapshot()['sessions'][0]['messages_observed']==1)
    service.command({'action':'pause','id':sid})
    before_context=service.snapshot()['sessions'][0]['memory']
    append_message(source,'assistant','Message apparu pendant arrêt')
    state_path=service.state_path
    service.close()

    restored=Supervisor(state_path,roots={'claude':[source.parent]},judge=judge,poll_interval=.01,strict_assignments=True)
    try:
        restored.command({'action':'start'})
        restored.command({'action':'resume','id':sid})
        item=restored.snapshot()['sessions'][0]
        assert item['recovery']['status']=='gap_available'
        assert item['recovery']['message_count']==1
        assert item['memory']==before_context
        restored.command({'action':'resume','id':sid,'mode':'history'})
        wait_for(lambda:restored.snapshot()['sessions'][0]['recovery']['status']=='complete')
        assert calls[-1][-1]['text']=='Message apparu pendant arrêt'
    finally:
        restored.close()


def test_restart_requeues_durable_context_not_yet_analyzed(tmp_path):
    entered,release=threading.Event(),threading.Event()
    calls=[]
    def judge(_model,messages):
        calls.append(messages)
        if len(calls)==1:
            entered.set(); assert release.wait(3)
        return {'alert':False}
    service,source,sid=make_service(tmp_path,judge)
    service.command({'action':'start'})
    append_message(source,'assistant','Réponse avant arrêt')
    assert entered.wait(3)
    service.command({'action':'pause','id':sid})
    persisted_context=json.loads(service.state_path.read_text(encoding='utf-8'))['sessions'][0]
    assert persisted_context['context_revision']>persisted_context['analyzed_revision']
    release.set(); service.close()

    restored=Supervisor(service.state_path,roots={'claude':[source.parent]},judge=judge,poll_interval=.01,strict_assignments=True)
    try:
        restored.command({'action':'start'})
        restored.command({'action':'resume','id':sid})
        wait_for(lambda:restored.snapshot()['sessions'][0]['analysis_state']=='no_alert')
        assert len(calls)>=2
        assert any(item['text']=='Réponse avant arrêt' for item in calls[-1])
        saved=json.loads(restored.state_path.read_text(encoding='utf-8'))['sessions'][0]
        assert saved['analyzed_revision']==saved['context_revision']
    finally:
        restored.close()


def test_recovery_adaptive_partition_when_batch_exceeds_budget(tmp_path):
    calls = []
    judge = lambda _model, messages: (calls.append([m['text'] for m in messages if m['role'] in ('user', 'assistant')]) or {'alert': False})
    service, source, sid = make_service(tmp_path, judge)
    # Réduire artificiellement le budget du juge pour forcer le partitionnement
    service.judge_settings["context_chars"] = 200
    try:
        service.command({'action': 'start'})
        wait_for(lambda: service.snapshot()['sessions'][0]['state'] == 'active')
        service.command({'action': 'pause', 'id': sid})
        # Ajouter 6 messages volumineux qui dépassent le budget de 200 + 4800 caractères
        for i in range(6):
            append_message(source, 'user', f"Message de test numéro {i} avec du texte suffisant pour garnir le lot " + ("X" * 1200))
        service.command({'action': 'resume', 'id': sid})
        assert service.snapshot()['sessions'][0]['recovery']['status'] == 'gap_available'
        service.command({'action': 'resume', 'id': sid, 'mode': 'history'})
        # Vérifier que le rattrapage se termine avec succès (complete) et JAMAIS avec recovery_batch_exceeds_judge_budget
        wait_for(lambda: service.snapshot()['sessions'][0]['recovery']['status'] == 'complete', timeout=10)
        item = service.snapshot()['sessions'][0]
        assert item['recovery'].get('last_error') != 'recovery_batch_exceeds_judge_budget'
        assert item['state'] == 'active'
        assert len(calls) >= 2  # A été partitionné en au moins 2 sous-lots
    finally:
        service.close()
