import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';

const require = createRequire(process.env.SUPERVISION_DOM_MODULES || path.join(os.tmpdir(), 'supervision-dom-tests', 'package.json'));
const {parseHTML} = require('linkedom');
const html = fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const {window, document} = parseHTML(html);
for (const select of document.querySelectorAll('select')) Object.defineProperty(select, 'value', {configurable:true, get(){return this._value ?? this.options?.[0]?.value ?? '';}, set(value){this._value=String(value);}});
const posts = [];
const snapshot = {running:true,token:'token',model:'local',allow_cloud:false,sessions:[],chat:{messages:[]}};
const fetch = async (url, options={}) => {
  if (url.includes('/history?id=')) return {ok:true,json:async()=>({session_id:'s1',partial:false,messages:[{role:'user',text:'Historique A'}]})};
  if (url.endsWith('/candidates')) return {ok:true,json:async()=>({candidates:[
    {platform:'codex',native_id:'11111111-1111-1111-1111-111111111111',modified:1730000000,matches:1},
    {platform:'claude',native_id:'duplicate',modified:1730000000,matches:2}],incomplete:false})};
  if(options.method==='POST') posts.push(JSON.parse(options.body));
  return {ok:true,status:200,json:async()=>snapshot};
};
const localStorage={getItem:()=>null,setItem:()=>{}};
const sandbox={window,document,navigator:{},localStorage,AbortController,fetch,console,Date,JSON,Set,Map,Promise,setTimeout:()=>1,clearTimeout:()=>{}};
const ctx=vm.createContext(sandbox);
vm.runInContext(script,ctx);
const tick=async()=>{for(let i=0;i<5;i++) await new Promise(resolve=>setImmediate(resolve));};
await tick();
const fire=async(id,type='click')=>{document.getElementById(id).dispatchEvent(new window.Event(type,{bubbles:true,cancelable:true}));await tick();};
await fire('load-candidates');
const options=document.getElementById('candidates').options;
assert.equal(options.length,3);
assert.match(options[1].textContent,/codex.*11111111/);
assert.equal(options[2].disabled,true);
assert.equal(posts.length,0,'listing does not attach');
document.getElementById('candidates').value=options[1].value;
await fire('use-candidate');
assert.equal(document.getElementById('native-id').value,'11111111-1111-1111-1111-111111111111');
assert.equal(document.getElementById('platform').value,'codex');
assert.equal(posts.length,0,'selecting does not attach');
document.getElementById('alias').value='Travail';
await fire('add-form','submit');
assert.equal(posts.length,1);
assert.equal(posts[0].native_id,'11111111-1111-1111-1111-111111111111');
document.getElementById('native-id').value='ancien-id';
document.getElementById('alias').value='Ancien alias';
document.getElementById('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: inconnu\ntask: Nouvelle mission\nEND_VEILLEUR_ASSIGN_V1';
await fire('apply-agent-response');
assert.equal(document.getElementById('native-id').value,'','unknown ID cannot retain a previous assignment');
assert.equal(document.getElementById('alias').value,'','unknown identity cannot retain a previous alias');
assert.match(document.getElementById('notice').textContent,/ID non fourni/);
document.getElementById('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: session_cloud\ntask: Mission\nEND_VEILLEUR_ASSIGN_V1';
await fire('apply-agent-response');
assert.match(document.getElementById('notice').textContent,/claude.ai/);
for(const bad of [
  'VEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: x\nunknown_field: value\ntask: test\nEND_VEILLEUR_ASSIGN_V1',
  'VEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: x\nmalformed line\ntask: test\nEND_VEILLEUR_ASSIGN_V1',
  'VEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: x\ntask: test\nEND_VEILLEUR_ASSIGN_V1\nVEILLEUR_ASSIGN_V1\nplatform: codex\nEND_VEILLEUR_ASSIGN_V1'
]){
  document.getElementById('native-id').value='do-not-overwrite';
  document.getElementById('assignment-response').value=bad;
  await fire('apply-agent-response');
  assert.equal(document.getElementById('native-id').value,'do-not-overwrite');
  assert.equal(document.getElementById('notice').className,'error');
}
// JSON is a prefill format, so identity ambiguity must never alter existing fields.
const assignmentId='11111111-1111-4111-8111-111111111111';
for(const badJson of [
  `{"platform":"agy","native_id":"${assignmentId}","native_id":"22222222-2222-4222-8222-222222222222","task":"T999"}`,
  `{"platform":"agy","native_id":"${assignmentId}","native_\\u0069d":"22222222-2222-4222-8222-222222222222","task":"T999"}`,
  '{"platform":"agy","native_id":"11111111-1111-4111-\n  8111-111111111111","task":"T999"}',
  '{"platform":"agy","native_id":"abc\\tdef","task":"T999"}'
]){
  document.getElementById('native-id').value='do-not-overwrite';
  document.getElementById('alias').value='do-not-overwrite';
  document.getElementById('mission').value='do-not-overwrite';
  document.getElementById('assignment-response').value=`VEILLEUR_ASSIGN_V1\n${badJson}\nEND_VEILLEUR_ASSIGN_V1`;
  await fire('apply-agent-response');
  assert.equal(document.getElementById('notice').className,'error');
  assert.equal(document.getElementById('native-id').value,'do-not-overwrite');
  assert.equal(document.getElementById('alias').value,'do-not-overwrite');
  assert.equal(document.getElementById('mission').value,'do-not-overwrite');
}
document.getElementById('platform').value='agy';
document.getElementById('native-id').value='old-id';
document.getElementById('alias').value='Ancien alias';
document.getElementById('assignment-response').value=`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform:'agy',native_id:assignmentId,task:'T999 — sujet',user_goal:'Texte valide : "cité" et {accolades}'})}\nEND_VEILLEUR_ASSIGN_V1`;
await fire('apply-agent-response');
assert.equal(document.getElementById('native-id').value,assignmentId);
assert.equal(document.getElementById('alias').value,'','a changed identity without alias clears the prior alias');
assert.match(document.getElementById('mission').value,/Texte valide/);
document.getElementById('alias').value='Alias courant';
await fire('apply-agent-response');
assert.equal(document.getElementById('alias').value,'Alias courant','same identity may keep its existing alias');
for(const [platform,id] of [['agy','../abc'],['agy','abc/def'],['agy','abc\u0000def'],['agy','abc\u200bdef'],['codex','non-uuid']]){
  document.getElementById('native-id').value='do-not-overwrite';
  document.getElementById('assignment-response').value=`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform,native_id:id,task:'T999'})}\nEND_VEILLEUR_ASSIGN_V1`;
  await fire('apply-agent-response');
  assert.equal(document.getElementById('notice').className,'error',`${platform}: malformed identity rejected`);
  assert.equal(document.getElementById('native-id').value,'do-not-overwrite');
}
for(const [platform,id] of [['agy','agy_abc-123'],['claude','abc_123-DEF'],['codex',assignmentId],['codex','inconnu']]){
  document.getElementById('assignment-response').value=`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform,native_id:id,task:'T999'})}\nEND_VEILLEUR_ASSIGN_V1`;
  await fire('apply-agent-response');
  assert.notEqual(document.getElementById('notice').className,'error',`${platform}: valid identity accepted`);
  assert.equal(document.getElementById('native-id').value,id==='inconnu'?'':id);
}
snapshot.sessions=[{id:'s1',platform:'claude',native_id:'session-a',alias:'A',state:'active',mission:'Mission A',alerts:[],chat_messages:[],judge_request:null}];
sandbox.snapshot=snapshot;
vm.runInContext('render(snapshot)',ctx);
const originalCard=document.querySelector('#sessions article');
const collapsible=Array.from(originalCard.querySelectorAll('details'));
assert.equal(collapsible.length,4);assert.ok(collapsible.every(item=>!item.open),'judge context, history, chat and alerts begin collapsed');
collapsible[0].open=true;collapsible[0].dispatchEvent(new window.Event('toggle'));
vm.runInContext('render(snapshot)',ctx);
assert.equal(document.querySelector('#sessions article'),originalCard,'unchanged polling must not replace the card');
snapshot.sessions[0].state='waiting';vm.runInContext('render(snapshot)',ctx);
assert.equal(document.querySelector('#sessions details').open,true,'open history must survive a real state change');
snapshot.update_available=false;snapshot.sessions[0].alerts=[{id:'a1',severity:'warning',reason:'À vérifier',evidence:'Extrait exact',disposition:'new'}];
vm.runInContext('render(snapshot)',ctx);
const alertPanel=Array.from(document.querySelectorAll('#sessions details')).find(x=>x.querySelector('summary')?.textContent.includes('Alertes :'));
assert.ok(alertPanel);assert.equal(Boolean(alertPanel.open),false);assert.match(alertPanel.textContent,/1 non lue/);
const treated=Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent==='Traitée');treated.click();await tick();
assert.equal(posts.at(-1).disposition,'resolved');
const judgeButton=Array.from(document.querySelectorAll('#sessions summary')).find(x=>x.textContent.includes('Ce que le juge a reçu'));
judgeButton.click();await tick();assert.match(document.getElementById('sessions').textContent,/Aucune requête au juge/);
snapshot.sessions[0].judge_request={attempted_at:'2026-11-04T00:00:00Z',attempt:1,status:'analyse',payload:{model:'local',system:'Règle système',prompt:JSON.stringify([{role:'user',text:'Texte effectivement envoyé'}]),options:{}}};
vm.runInContext('render(snapshot)',ctx);assert.match(document.getElementById('sessions').textContent,/Texte effectivement envoyé/);
const judgeContent=Array.from(document.querySelectorAll('#sessions pre')).find(x=>x.textContent.includes('Texte effectivement envoyé'));
assert.equal(judgeContent.style.maxHeight,'320px');assert.equal(judgeContent.style.overflow,'auto');assert.equal(judgeContent.style.font,'inherit');assert.ok(judgeContent.classList.contains('chat-message'));
snapshot.sessions[0].judge_request={attempted_at:'2026-11-04T00:00:00Z',attempt:1,status:'analyse',payload:{model:'nvidia/nvidia/nemotron-3.5-bolt-e4b',messages:[{role:'system',content:'Consigne OmniRoute'},{role:'user',content:JSON.stringify({events:[{id:'e1',text:'Evenement OmniRoute'}]})}],stream:true}};
vm.runInContext('render(snapshot)',ctx);
assert.match(document.getElementById('sessions').textContent,/Consigne OmniRoute/);
assert.match(document.getElementById('sessions').textContent,/Evenement OmniRoute/);
assert.match(document.getElementById('sessions').textContent,/OmniRoute/);
const historyButton=Array.from(document.querySelectorAll('#sessions button')).find(x=>x.textContent.includes('historique de cette session'));
historyButton.click();await tick();
assert.match(document.getElementById('sessions').textContent,/Historique A/);
const chatInput=document.querySelector('[data-chat-id="s1"]');chatInput.value='Question propre à A';
const before=posts.length;
const shiftEnter=new window.Event('keydown',{bubbles:true,cancelable:true});Object.assign(shiftEnter,{key:'Enter',shiftKey:true,isComposing:false});chatInput.dispatchEvent(shiftEnter);await tick();
assert.equal(posts.length,before,'Shift+Enter does not send');
const enter=new window.Event('keydown',{bubbles:true,cancelable:true});Object.assign(enter,{key:'Enter',shiftKey:false,isComposing:false});chatInput.dispatchEvent(enter);await tick();
assert.equal(posts.at(-1).session_id,'s1');assert.equal(posts.at(-1).text,'Question propre à A');
const globalInput=document.getElementById('chat-text');globalInput.value='Question générale';
const globalEnter=new window.Event('keydown',{bubbles:true,cancelable:true});Object.assign(globalEnter,{key:'Enter',shiftKey:false,isComposing:false});globalInput.dispatchEvent(globalEnter);await tick();
assert.equal(posts.at(-1).text,'Question générale');assert.equal(posts.at(-1).session_id,undefined);
console.log('Veilleur UI: candidate discovery, ambiguity and explicit confirmation passed.');
