import json

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts import upgrade_legacy as upgrade


def test_stable_sessions_ignores_only_added_legacy_workflow_defaults():
    alert = {'id': 'a1', 'fingerprint': 'f1', 'reason': 'text', 'evidence': 'quote'}
    old = {'sessions': [{'id': 's1', 'alerts': [alert]}]}
    new_alert = dict(alert, workflow=dict(upgrade.LEGACY_ALERT_WORKFLOW))
    new = {'sessions': [{'id': 's1', 'alerts': [new_alert]}]}
    assert upgrade.stable_sessions(old) == upgrade.stable_sessions(new)
    changed = {'sessions': [{'id': 's1', 'alerts': [dict(new_alert, reason='changed')]}]}
    assert upgrade.stable_sessions(old) != upgrade.stable_sessions(changed)


def test_upgrade_backs_up_before_stop_and_restores_chat(tmp_path, monkeypatch):
    monkeypatch.setenv('LOCALAPPDATA', str(tmp_path))
    messages = [{'role':'user','text':'conversation à préserver','created_at':'2026-11-04T00:00:00Z'}]
    legacy = {'sessions':[], 'running':True, 'token':'old', 'chat':{'state':'idle','session_id':None,'messages':messages}}
    frozen = dict(legacy, running=False)
    replies = iter([{'service':'agent-supervisor','version':1}, legacy, frozen, frozen,
                    {'service':'agent-supervisor','service_version':2,'build_id':'test'}, {'token':'new','chat':{'messages':[]}}])
    monkeypatch.setattr(upgrade, 'get', lambda path: next(replies))
    calls = []
    def post(token, payload):
        calls.append(payload['action'])
        return {'chat':{'messages':messages}}
    monkeypatch.setattr(upgrade, 'post', post)
    pids = iter([12345,12345,None])
    def listener():
        value = next(pids)
        if value is None:
            raise RuntimeError('no listener')
        return value
    monkeypatch.setattr(upgrade, 'listener_pid', listener)
    def kill(pid, sig):
        backups = list((tmp_path / 'ExcavatriceDragage' / 'supervision-backups').glob('*.json'))
        assert len(backups) == 1
        assert json.loads(backups[0].read_text(encoding='utf8'))['chat']['messages'] == messages
        calls.append('kill')
    monkeypatch.setattr(upgrade.os, 'kill', kill)
    monkeypatch.setattr(upgrade.subprocess, 'Popen', lambda *a, **kw: object())
    upgrade.main()
    assert calls == ['stop','kill','import_chat']


def test_upgrade_refuses_analysis_in_progress_before_mutation(monkeypatch):
    replies = iter([{'service':'agent-supervisor','version':1}, {'sessions':[{'id':'active','analysis_state':'analyzing'}],'chat':{'state':'idle'}}])
    monkeypatch.setattr(upgrade, 'get', lambda path: next(replies))
    monkeypatch.setattr(upgrade, 'post', lambda *a: pytest.fail('must not stop active service'))
    with pytest.raises(RuntimeError, match='analyse'):
        upgrade.main()


def test_upgrade_restores_active_assignment_chat_and_memory(tmp_path, monkeypatch):
    monkeypatch.setenv('LOCALAPPDATA', str(tmp_path))
    source=tmp_path/'source.jsonl';source.touch()
    memory=[{'kind':'user_message','text':'Consigne observée','observed_at':'2026-11-04T00:00:00Z'}]
    chat=[{'role':'user','text':'Question','created_at':'2026-11-04T00:00:00Z'}]
    session={'id':'sid','alias':'CC-test','state':'active','source':str(source),'analysis_state':'no_alert','memory':memory,'chat_messages':chat}
    old={'sessions':[session], 'running':True,'token':'old','chat':{'state':'idle','session_id':'sid','messages':chat}}
    new_session=dict(session,state='paused',memory=[])
    new={'sessions':[new_session], 'running':True,'token':'new','chat':{'state':'idle','session_id':None,'messages':[]}}
    phase={'new':False};actions=[]
    def get(path):
        if path=='/health':
            return {'service':'agent-supervisor','service_version':2,'build_id':'new'} if phase['new'] else {'service':'agent-supervisor','version':1}
        return new if phase['new'] else old
    def post(token,payload):
        action=payload['action'];actions.append(action)
        if action=='stop': old['running']=False;old['sessions'][0]['state']='paused'
        if action=='resume': new['sessions'][0]['state']='active'
        if action=='restore_memory': new['sessions'][0]['memory']=payload['memory']
        return new if phase['new'] else old
    monkeypatch.setattr(upgrade,'get',get);monkeypatch.setattr(upgrade,'post',post)
    pids=iter([123,123,None])
    def listener():
        item=next(pids)
        if item is None: raise RuntimeError('closed')
        return item
    monkeypatch.setattr(upgrade,'listener_pid',listener)
    def kill(pid,sig):
        backups=list((tmp_path/'ExcavatriceDragage'/'supervision-backups').glob('*.json'))
        assert len(backups)==1
        saved=json.loads(backups[0].read_text(encoding='utf8'))
        assert saved['sessions'][0]['memory']==memory and saved['sessions'][0]['chat_messages']==chat
        phase['new']=True
    monkeypatch.setattr(upgrade.os,'kill',kill)
    monkeypatch.setattr(upgrade.subprocess,'Popen',lambda *a,**kw: object())
    upgrade.main()
    assert actions==['stop','resume','restore_memory']
    assert new['sessions'][0]['state']=='active' and new['sessions'][0]['memory']==memory
def test_migration_comparison_allows_additive_fields_but_rejects_data_loss():
    from TOOLS.AGENT_SUPERVISOR.scripts.upgrade_legacy import preserves_previous
    previous = [{'id': 'a', 'disposition': 'seen', 'workflow': {'choice': '2'}}]
    assert preserves_previous(previous, [{'id': 'a', 'disposition': 'seen', 'workflow': {'choice': '2'}, 'version': 1}])
    assert not preserves_previous(previous, [])
    assert not preserves_previous(previous, [{'id': 'a', 'disposition': 'resolved', 'workflow': {'choice': '2'}}])
    assert not preserves_previous(previous, [{'id': 'a', 'disposition': 'seen', 'workflow': {}}])
