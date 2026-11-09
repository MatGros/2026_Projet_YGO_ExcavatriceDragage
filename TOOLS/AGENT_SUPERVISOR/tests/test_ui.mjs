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
const {window, document} = parseHTML(html);window.HTMLElement.prototype.scrollIntoView=()=>{};
const deepLinkTest = Boolean(process.env.VEILLEUR_UI_DEEP_LINK && process.env.VEILLEUR_UI_DEEP_LINK.trim() === '1');window.location={search:deepLinkTest?'?session=s1&alert=a1':''};
for (const select of document.querySelectorAll('select')) Object.defineProperty(select, 'value', {configurable:true, get(){return this._value ?? this.options?.[0]?.value ?? '';}, set(value){this._value=String(value);}});
const posts = [];
const snapshot = {running:true,token:'token',model:'local',allow_cloud:false,sessions:deepLinkTest?[{id:'s1',platform:'claude',native_id:'session-a',alias:'A',state:'active',analysis_state:'alert',mission:'Mission A',alerts:[{id:'a1',severity:'warning',reason:'Constat TEST',evidence:'Citation TEST',disposition:'seen',workflow:{status:'legacy'}}],chat_messages:[],judge_request:null}]:[],chat:{messages:[]}};
const fetch = async (url, options={}) => {
  if (url.includes('/history?id=')) return {ok:true,json:async()=>({session_id:'s1',partial:false,messages:[{role:'user',text:'Historique A'}]})};
  if (url.endsWith('/candidates')) return {ok:true,json:async()=>({candidates:[
    {platform:'codex',native_id:'11111111-1111-1111-1111-111111111111',modified:1730000000,matches:1},
    {platform:'claude',native_id:'duplicate',modified:1730000000,matches:2}],incomplete:false})};
  if(options.method==='POST') posts.push(JSON.parse(options.body));
  return {ok:true,status:200,json:async()=>snapshot};
};
const deliveredNotifications=[];class FakeNotification{constructor(title,options){this.close=()=>{};deliveredNotifications.push({title,options,note:this});}}FakeNotification.permission='granted';FakeNotification.requestPermission=async()=> 'granted';window.Notification=FakeNotification;class FakeAudioContext{state='suspended';async resume(){this.state='running';}}window.AudioContext=FakeAudioContext;
const localStorage={getItem:()=>null,setItem:()=>{}};
const sandbox={window,document,Notification:FakeNotification,navigator:{},localStorage,AbortController,URLSearchParams,fetch,console,Date,JSON,Set,Map,Promise,setTimeout:()=>1,clearTimeout:()=>{}};
const ctx=vm.createContext(sandbox);
vm.runInContext(script,ctx);
const tick=async()=>{for(let i=0;i<5;i++) await new Promise(resolve=>setImmediate(resolve));};
await tick();
snapshot.sessions.push({id:'notification-test',alias:'TEST',state:'active',mission:'Test',alerts:[],chat_messages:[]});
vm.runInContext("preferences.desktop=true;initialAlerts=false;processAlerts([{id:'notification-test',alias:'TEST',alerts:[{id:'new-warning',severity:'warning',disposition:'new',reason:'Warning test'}]}])",ctx);
assert.equal(deliveredNotifications.length,1,'a new warning triggers a desktop notification');
if(deliveredNotifications[0].note && typeof deliveredNotifications[0].note.onclick === 'function'){
  deliveredNotifications[0].note.onclick();
  assert.equal(vm.runInContext('selectedSideSessionId', ctx), 'notification-test', 'clicking desktop notification selects the target session');
}
vm.runInContext("processAlerts([{id:'notification-test',alias:'TEST',alerts:[{id:'new-warning',severity:'warning',disposition:'new',reason:'Warning test'}]}])",ctx);
assert.equal(deliveredNotifications.length,1,'the same warning must not notify twice');
vm.runInContext('preferences.desktop=false',ctx);
const fire=async(id,type='click')=>{document.getElementById(id).dispatchEvent(new window.Event(type,{bubbles:true,cancelable:true}));await tick();};
// Editing advanced settings survives polling and the same config submit sends real parameters.
snapshot.judge_settings={temperature:0,output_tokens:1600,timeout_seconds:30,context_messages:12,context_chars:6000,model_context_tokens:16384};sandbox.snapshot=snapshot;vm.runInContext('render(snapshot)',ctx);
assert.equal(document.getElementById('judge-context-chars').value,'6000');
document.getElementById('judge-context-chars').value='18000';document.getElementById('judge-context-chars').dispatchEvent(new window.Event('input',{bubbles:true}));
snapshot.judge_settings.context_chars=8000;vm.runInContext('render(snapshot)',ctx);assert.equal(document.getElementById('judge-context-chars').value,'18000','poll does not overwrite edited advanced settings');
assert.match(document.getElementById('judge-effective-settings').textContent,/8000 caractères/,'effective settings stay distinct from the draft');
await fire('config-form','submit');assert.deepEqual(posts.at(-1).judge_settings,{temperature:0,output_tokens:1600,timeout_seconds:30,context_messages:12,context_chars:18000,model_context_tokens:16384});posts.length=0;

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
snapshot.sessions=[{id:'s1',platform:'claude',native_id:'session-a',alias:'A',state:'active',mission:'Mission A',alerts:deepLinkTest?[{id:'a1',severity:'warning',category:'other',reason:'Constat TEST',evidence:'Citation TEST',disposition:'seen',workflow:{status:'legacy'}}]:[],chat_messages:[],judge_request:null}];
snapshot.collector={sessions_enabled:1,messages_seen:2,cycles:7,sessions_unavailable:0,last_cycle_at:'2026-11-06T10:00:00Z'};
snapshot.poll_interval_seconds=8;
sandbox.snapshot=snapshot;
vm.runInContext('render(snapshot)',ctx);
const collectorStep=document.querySelector('[data-flow-node="collector"]');
collectorStep.dispatchEvent(new window.Event('click',{bubbles:true,cancelable:true}));await tick();
assert.equal(document.getElementById('flow-details').hasAttribute('open'),true,'selecting a flow node opens its compact details');
assert.match(document.getElementById('flow-detail-content').textContent,/1 session/);
assert.match(document.getElementById('flow-detail-content').textContent,/cycles : 7/);
assert.equal(collectorStep.getAttribute('aria-pressed'),'true','selected flow node is accessible');
const judgeStep=document.querySelector('[data-flow-node="judge"]');
judgeStep.dispatchEvent(new window.Event('focusin',{bubbles:true}));await tick();
assert.match(document.getElementById('flow-detail-content').textContent,/[Uu]n seul juge partag/);
assert.match(document.getElementById('flow-detail-content').textContent,/Challenge A\/B/);
assert.equal(judgeStep.getAttribute('aria-pressed'),'true','keyboard focus updates the active flow details');
const originalCard=document.querySelector('#sessions article');
if(deepLinkTest){assert.equal(document.querySelector('#sessions .session-fold').open,true,'deep link expands the requested session');const linkedAlert=document.querySelector('#sessions [data-alert-id="a1"]');assert.ok(linkedAlert,'deep link finds the requested alert');assert.equal(Array.from(document.querySelectorAll('#sessions details.mission summary')).some(item=>item.textContent.includes('Constats')),true,'deep link opens the findings panel');assert.equal(linkedAlert.open,true,'deep link expands an already-seen alert');}
assert.match(document.title,/Agent Supervisor/,'browser tab uses the English product name');assert.match(document.getElementById('notification-status').textContent,/Bureau inactif.*Son inactif/,'notification and sound states are visible beside the session list');
assert.equal(document.getElementById('notification-status').parentElement.classList.contains('sidebar-session-heading'),true,'notification controls sit beside the session count');let statusToggle=Array.from(document.querySelectorAll('#notification-status button'));assert.equal(statusToggle.length,2,'notification and sound indicators are actionable buttons');statusToggle[0].click();await tick();assert.match(document.getElementById('notification-status').textContent,/Bureau actif/);assert.match(document.getElementById('enable-notifications').textContent,/D?sactiver/);statusToggle=Array.from(document.querySelectorAll('#notification-status button'));statusToggle[0].click();await tick();assert.match(document.getElementById('notification-status').textContent,/Bureau inactif/);statusToggle=Array.from(document.querySelectorAll('#notification-status button'));statusToggle[1].click();await tick();assert.match(document.getElementById('notification-status').textContent,/Son actif/);assert.equal(document.getElementById('sound-enabled').checked,true);statusToggle=Array.from(document.querySelectorAll('#notification-status button'));statusToggle[1].click();await tick();assert.match(document.getElementById('notification-status').textContent,/Son inactif/);assert.equal(document.getElementById('sound-enabled').checked,false);
const sideMarker=document.querySelector('#side-sessions .session-marker'),cardMarker=document.querySelector('#sessions .session-marker');
assert.ok(sideMarker&&cardMarker);assert.equal(sideMarker.parentElement.style.getPropertyValue('--session-color'),cardMarker.parentElement.parentElement.style.getPropertyValue('--session-color'),'session sidebar and card share one color marker');
assert.equal(document.querySelector('#side-sessions .treatment-badges'),null,'sidebar keeps treatment counts out of the compact session list');assert.match(sideMarker.parentElement.title,/open.*deferred.*closed.*resolution proposed/,'full treatment counts remain available on hover');
assert.equal(document.querySelector('#sessions .session-fold').open,true,'selected session is expanded');
const collapsible=Array.from(originalCard.children).filter(item=>item.tagName==='DETAILS');
assert.equal(collapsible.length,4,'T429 L2: findings, chat, mission and one folded Détails et réglages');if(deepLinkTest){assert.equal(collapsible.filter(item=>item.open).length,1,'only the findings panel opens for a deep link');}else assert.ok(collapsible.every(item=>!item.open),'without findings to follow, every panel begins collapsed');assert.ok(originalCard.querySelector('.session-more .event-journal'),'event journal lives in Détails et réglages');
const eventJournal=originalCard.querySelector('.event-journal');assert.match(eventJournal.querySelector('summary').textContent,/Journal de session · 0 événement/);assert.match(eventJournal.textContent,/Références aux messages, décisions.*chat Supervisor/);assert.match(eventJournal.textContent,/Le « 0 » ne compte ni les alertes ni les messages du chat/,'empty event journal explains its count and where alerts/chat are shown');
const judgePanel=Array.from(originalCard.querySelectorAll('details')).find(x=>x.querySelector('summary')?.textContent.includes('Ce que le juge a reçu'));judgePanel.open=true;judgePanel.dispatchEvent(new window.Event('toggle'));
vm.runInContext('render(snapshot)',ctx);
assert.equal(document.querySelector('#sessions article'),originalCard,'unchanged polling must not replace the card');
snapshot.sessions[0].state='waiting';vm.runInContext('render(snapshot)',ctx);
assert.equal(Array.from(document.querySelectorAll('#sessions details')).find(x=>x.querySelector('summary')?.textContent.includes('Ce que le juge a reçu')).open,true,'open judge details survive a real state change');
snapshot.update_available=false;snapshot.sessions[0].alerts=[{id:'a1',severity:'warning',category:'unsupported_success',reason:'À vérifier',evidence:'Extrait exact',disposition:'new',workflow:{status:'awaiting_choice',delivery_status:'delivered',choice:null}}];
vm.runInContext('render(snapshot)',ctx);
const alertPanel=Array.from(document.querySelectorAll('#sessions details')).find(x=>x.querySelector('summary')?.textContent.includes('Constats ·'));
assert.ok(alertPanel);assert.equal(Boolean(alertPanel.open),true,'T429 L2: findings open as soon as one needs follow-up');assert.match(alertPanel.textContent,/1 new/);
assert.match(alertPanel.textContent,/Warning.*Réussite sans preuve/);assert.ok(alertPanel.querySelector('.finding-status-chip.read-new'),'new alert has its own read-state color class');
vm.runInContext("selectedFlowNode='alerts';updateFlow(snapshot,snapshot.sessions)",ctx);
assert.match(document.getElementById('flow-detail-content').textContent,/Conversation fermée : tour ajouté/,'message delivery state appears in the message-flow details');
const review=Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent==='Re-evaluate');review.click();await tick();
assert.equal(posts.at(-1).action,'comment_alert');assert.equal(posts.at(-1).review,true);assert.equal(posts.at(-1).alert_id,'a1');
const deferButton=Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent==='Confirm defer'),condition=alertPanel.querySelector('.finding-defer textarea');
const beforeEmptyDefer=posts.length;deferButton.click();await tick();assert.equal(posts.length,beforeEmptyDefer,'defer requires a usable resume condition');condition.value='Après la revue J4';deferButton.click();await tick();assert.equal(posts.at(-1).disposition,'deferred');assert.equal(posts.at(-1).rationale,'Après la revue J4');
const treated=Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent.startsWith('Resolved'));assert.ok(treated.classList.contains('action-confirm'),'resolution uses confirmation palette');assert.ok(review.classList.contains('action-attention'),'review uses attention palette');assert.ok(Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent==='Send comment').classList.contains('action-neutral'),'comment is neutral');assert.ok(Array.from(alertPanel.querySelectorAll('button')).find(x=>x.textContent.startsWith('Dismissed')).classList.contains('action-reject'),'rejection palette is distinct');treated.click();await tick();
assert.equal(posts.at(-1).disposition,'resolved');
snapshot.sessions[0].alerts=[{id:'legacy-alert',severity:'warning',reason:'Alerte ancienne',evidence:'Extrait',disposition:'new',workflow:{status:'legacy',delivery_status:'not_sent'}}];
vm.runInContext('render(snapshot)',ctx);
const copyBtn=Array.from(document.querySelectorAll('#sessions button')).find(x=>x.textContent.includes('Copier pour le chat'));
assert.ok(copyBtn,'review panel has a copy button');assert.match(document.querySelector('.finding-delivery').textContent,/claude \/ session-a/);assert.match(document.querySelector('.finding-delivery').textContent,/\/review-session-supervisor/);
 snapshot.sessions[0].alerts=[{id:'seen-alert',severity:'warning',category:'unsupported_success',reason:'Le resume annonce huit echecs de gates.',evidence:'Extrait probant conserve.',disposition:'seen',workflow:{status:'legacy',delivery_status:'not_sent'}}];
 vm.runInContext('render(snapshot)',ctx);
 const seenPanel=Array.from(document.querySelectorAll('#sessions details')).find(x=>x.querySelector('summary')?.textContent.includes('Constats ·'));
 assert.match(seenPanel.querySelector('summary').textContent,/Constats · 1/,'seen alert remains in the total');assert.doesNotMatch(seenPanel.querySelector('summary').textContent,/new/,'a seen alert is not counted as new');
 const compactSeen=seenPanel.querySelector('details.alert-history-fold');assert.ok(compactSeen,'seen alert remains in history as a compact row');assert.equal(Boolean(compactSeen.open),false,'seen row starts collapsed');
 assert.equal(compactSeen.querySelector('.treatment-open'),null,'T429 L3: Open is the default state, no chip');assert.equal(compactSeen.querySelector('.read-new'),null,'T429 L2: only unread findings carry a read chip');compactSeen.open=true;
 assert.match(compactSeen.textContent,/Extrait probant conserve\./,'opening the row reveals the complete alert and citation');
// The complete reason is retained; comment actions target Supervisor, never the CLI.
const fullReason='Fait vérifié très long. '.repeat(45)+'FIN DU MOTIF';
snapshot.sessions[0].alerts=[{id:'comment-alert',review_state:'unavailable',review_error:'Preuve manquante',version:2,severity:'warning',reason:fullReason,evidence:'Citation exacte',disposition:'seen',business_state:'open',assessment:{status:'resolution_proposed',reason:'Correction observée. '.repeat(20)},comments:[{id:'c1',text:'Preuve utilisateur',created_at:'2026-11-08T12:00:00Z'}],workflow:{delivery_status:'not_sent'}}];
snapshot.sessions[0].counts={unread:0,open:1,deferred:0,closed:0,follow_up:1,warnings:0,alarms:0,resolution_proposed:1};
vm.runInContext('render(snapshot)',ctx);
assert.equal(document.querySelector('.finding-reason').textContent,fullReason,'full source reason remains readable beyond preview');
assert.match(document.querySelector('.finding-card>summary span').textContent,/…$/,'compact preview visibly announces omission');
assert.ok(document.querySelector('.finding-card').classList.contains('is-resolution'),'resolution proposal is distinct from an active warning');
assert.match(document.querySelector('.finding-comments-history').textContent,/Preuve utilisateur/);
assert.match(document.querySelector('.finding-card').textContent,/Réévaluation indisponible.*Preuve manquante/,'an unavailable review is not presented as a resolution');
assert.match(Array.from(document.querySelectorAll('#sessions details.mission>summary')).find(x=>x.textContent.startsWith('Constats ·')).title,/1 resolution proposed/);
const commentInput=document.querySelector('[data-finding-comment]');commentInput.value='Les preuves sont dans le résultat e123.';commentInput.dispatchEvent(new window.Event('input',{bubbles:true}));
Object.defineProperty(document,'activeElement',{configurable:true,value:commentInput});snapshot.sessions[0].last_event='2026-11-08T12:02:00Z';vm.runInContext('render(snapshot)',ctx);
assert.equal(document.querySelector('[data-finding-comment]'),commentInput,'polling preserves the focused comment node');
assert.equal(commentInput.value,'Les preuves sont dans le résultat e123.','polling preserves the comment draft');
const commentBefore=posts.length,commentShift=new window.Event('keydown',{bubbles:true,cancelable:true});Object.assign(commentShift,{key:'Enter',shiftKey:true,isComposing:false});commentInput.dispatchEvent(commentShift);await tick();assert.equal(posts.length,commentBefore);
const commentEnter=new window.Event('keydown',{bubbles:true,cancelable:true});Object.assign(commentEnter,{key:'Enter',shiftKey:false,isComposing:false});commentInput.dispatchEvent(commentEnter);await tick();
assert.equal(posts.at(-1).action,'comment_alert');assert.equal(posts.at(-1).comment,'Les preuves sont dans le résultat e123.');assert.equal(posts.at(-1).alert_id,'comment-alert');assert.equal(commentInput.value,'','successful send clears the draft');
Object.defineProperty(document,'activeElement',{configurable:true,value:null});delete snapshot.sessions[0].counts;
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
snapshot.sessions[0].alerts=[{id:'alarm-sidebar',severity:'error',reason:'Action interdite',disposition:'new'}];snapshot.sessions.push({id:'s2',platform:'agy',native_id:'session-b',alias:'B',state:'active',mission:'Mission B',alerts:[{id:'warning-sidebar',severity:'warning',reason:'A verifier',disposition:'new'}],chat_messages:[],judge_request:null});
vm.runInContext('render(snapshot)',ctx);
const sessionLinks=Array.from(document.querySelectorAll('#side-sessions [data-side-session-id]'));assert.equal(document.getElementById('side-session-count').textContent,'2','sidebar heading shows the current session count');assert.ok(sessionLinks[0].classList.contains('has-alarm'),'unread alarm is highlighted in the session list');assert.ok(sessionLinks[1].classList.contains('has-warning'),'unread warning gets a distinct softer highlight');for(const card of document.querySelectorAll('#sessions article'))card.scrollIntoView=()=>{};
sessionLinks.find(x=>x.dataset.sideSessionId==='s2').click();await tick();
const sessionFolds=Array.from(document.querySelectorAll('#sessions .session-fold'));
assert.equal(sessionFolds.length,2);assert.equal(sessionFolds.find(x=>x.querySelector('article')?.dataset.sessionId==='s1').open,false,'selecting another session collapses the previous card');
assert.equal(sessionFolds.find(x=>x.querySelector('article')?.dataset.sessionId==='s2').open,true,'selected session remains expanded');
// Treatment stays visible with collapsed sessions/findings, independently of notification preferences.
snapshot.sessions[0].alerts=[{id:'seen-open',severity:'warning',reason:'Lu mais non traité',disposition:'seen',business_state:'open',assessment:{status:'active'},review_state:'pending'},{id:'deferred',severity:'warning',reason:'Reporté',disposition:'deferred',business_state:'deferred',assessment:{status:'active'}},{id:'closed',severity:'warning',reason:'Corrigé',disposition:'resolved',business_state:'closed',assessment:{status:'resolution_proposed'},review_state:'complete'},{id:'proposal',severity:'warning',reason:'Correction à confirmer',disposition:'seen',business_state:'open',assessment:{status:'resolution_proposed'}}];
snapshot.sessions[0].counts={unread:0,open:2,deferred:1,closed:1,follow_up:3,warnings:1,alarms:0,resolution_proposed:1};
snapshot.sessions[0].enabled=false;snapshot.sessions[1].alerts=[];snapshot.sessions[1].counts={unread:0,open:0,deferred:0,closed:0,follow_up:0,warnings:0,alarms:0,resolution_proposed:0};vm.runInContext('render(snapshot)',ctx);
const treatmentSide=Array.from(document.querySelectorAll('[data-side-session-id]')).find(x=>x.dataset.sideSessionId==='s1');assert.match(treatmentSide.title,/2 open.*1 deferred.*1 closed.*1 resolution proposed/,'hover distinguishes every treatment count including read-but-open');
const treatmentFold=Array.from(document.querySelectorAll('.session-fold')).find(x=>x.querySelector('article')?.dataset.sessionId==='s1');treatmentFold.open=false;assert.match(treatmentFold.querySelector(':scope>summary .severity-counts').title,/2 open.*1 deferred.*1 closed.*1 resolution proposed/,'compact session counts retain full labels on hover');assert.match(treatmentFold.querySelector(':scope>summary .severity-counts').textContent,/⚠️ 1 Warning/,'session header shows only non-zero labelled counters');assert.doesNotMatch(treatmentFold.querySelector(':scope>summary .severity-counts').textContent,/0 /,'zero counters are hidden');assert.equal(treatmentFold.querySelector(':scope>summary .session-collection-state').textContent,'⏸ Paused','paused state is labelled, not a bare icon');assert.equal(treatmentFold.querySelector(':scope>summary .session-collection-state').title,'Paused','hover explains the pause icon');
const zeroSide=Array.from(document.querySelectorAll('[data-side-session-id]')).find(x=>x.dataset.sideSessionId==='s2');assert.match(zeroSide.title,/0 open.*0 deferred.*0 closed.*0 resolution proposed/,'empty treatment counts remain available on hover');
const seenHeading=document.querySelector('[data-alert-id="seen-open"]>summary'),seenState=seenHeading.querySelector('.finding-status-chip.treatment-open')||{textContent:'Open (implicite)'},seenRead=seenHeading.querySelector('.finding-status-chip.read-seen'),seenAssessment=seenHeading.querySelector('.finding-status-chip.assessment-active'),seenReview=seenHeading.querySelector('.finding-status-chip.review-pending');assert.match(seenState.textContent,/Open/,'business treatment remains visible');assert.equal(seenRead,null,'T429 L2: seen is the default, no chip');assert.equal(seenAssessment,null,'T429 L2: default judge assessment adds no chip');assert.equal(seenReview.textContent,'Review · en attente');assert.ok(document.querySelector('[data-alert-id="proposal"]>summary .assessment-resolution_proposed'),'a non-default assessment keeps its distinct chip');assert.match(document.querySelector('[data-alert-id="closed"]>summary .finding-status-chip').textContent,/Closed/);assert.match(document.querySelector('[data-alert-id="deferred"]>summary .finding-status-chip').textContent,/Deferred/);
assert.match(document.querySelector('#notification-status button').title,/Préférence de notification.*uniquement/,'notification indicator explains its independent meaning');delete snapshot.sessions[0].counts;delete snapshot.sessions[1].counts;
// Optional mission structure: isolated drafts, cancellation, literal text and explicit confirmation.
const structureSession=snapshot.sessions[0];structureSession.initial_mission='Source initiale intacte';structureSession.mission_structure={};vm.runInContext('render(snapshot)',ctx);
let structureCard=Array.from(document.querySelectorAll('#sessions article')).find(x=>x.dataset.sessionId==='s1');assert.match(structureCard.querySelector('.mission-lines').textContent,/Fiche structurée vide/);assert.ok(Array.from(structureCard.querySelectorAll('details.mission>summary')).some(x=>x.textContent.includes('Mission · fiche vide')),'empty structure is announced in one line');
const startStructure=()=>{structureCard=Array.from(document.querySelectorAll('#sessions article')).find(x=>x.dataset.sessionId==='s1');Array.from(structureCard.querySelectorAll('button')).find(x=>x.textContent==='Create structure').click();};startStructure();await tick();
let subjectInput=document.querySelector('[data-mission-structure="s1"][data-structure-field="subject"]');subjectInput.value='T428 <script>alert(1)</script>';subjectInput.dispatchEvent(new window.Event('input',{bubbles:true}));
Object.defineProperty(document,'activeElement',{configurable:true,value:subjectInput});snapshot.sessions[0].last_event='2026-11-08T18:00:00Z';vm.runInContext('render(snapshot)',ctx);assert.equal(document.querySelector('[data-mission-structure="s1"][data-structure-field="subject"]'),subjectInput,'poll preserves focused mission field');
Object.defineProperty(document,'activeElement',{configurable:true,value:null});
const structureBeforeCancel=posts.length;Array.from(document.querySelector('[data-mission-structure-form="s1"]').querySelectorAll('button')).find(x=>x.textContent==='Cancel').click();await tick();assert.equal(posts.length,structureBeforeCancel,'cancel does not save');assert.equal(document.querySelector('[data-mission-structure-form="s1"]'),null);
startStructure();await tick();subjectInput=document.querySelector('[data-mission-structure="s1"][data-structure-field="subject"]');assert.equal(subjectInput.value,'','cancel discarded draft');
subjectInput.value='T428 <script>alert(1)</script>';subjectInput.dispatchEvent(new window.Event('input',{bubbles:true}));const goalInput=document.querySelector('[data-mission-structure="s1"][data-structure-field="current_goal"]');goalInput.value='Livrer J5';goalInput.dispatchEvent(new window.Event('input',{bubbles:true}));
const s2Card=Array.from(document.querySelectorAll('#sessions article')).find(x=>x.dataset.sessionId==='s2');Array.from(s2Card.querySelectorAll('button')).find(x=>x.textContent==='Create structure').click();await tick();assert.equal(document.querySelector('[data-mission-structure="s2"][data-structure-field="subject"]').value,'','other session gets isolated draft');assert.equal(document.querySelector('[data-mission-structure="s1"][data-structure-field="subject"]').value,'T428 <script>alert(1)</script>','switch preserves first draft');
document.querySelector('[data-mission-structure-form="s1"]').dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.equal(posts.at(-1).action,'set_mission_structure');assert.equal(posts.at(-1).id,'s1');assert.equal(posts.at(-1).structure.current_goal,'Livrer J5');assert.equal(posts.at(-1).structure.subject,'T428 <script>alert(1)</script>');assert.equal(snapshot.sessions[0].mission,'Mission A','structured save leaves legacy text alone');assert.equal(snapshot.sessions[0].initial_mission,'Source initiale intacte');assert.equal(document.querySelector('.mission-structure-form script'),null,'typed markup never becomes DOM');
snapshot.sessions[0].mission_structure=posts.at(-1).structure;vm.runInContext('render(snapshot)',ctx);assert.match(document.querySelector('[data-session-id="s1"] .mission-lines').textContent,/Objectif courant : Livrer J5/);assert.match(document.querySelector('[data-session-id="s1"] .mission-lines').textContent,/Non renseignés : /,'empty fields are grouped on one line');
snapshot.sessions[0].recovery={status:'gap_available',message_count:2,characters:54,can_catch_up:true};
vm.runInContext('render(snapshot)',ctx);
assert.match(document.getElementById('sessions').textContent,/Historique manqué vérifié : 2 message/);
const historyResume=Array.from(document.querySelectorAll('#sessions button')).find(x=>x.textContent.includes('Reprise avec historique'));
assert.ok(historyResume,'historical replay is offered only for a verified gap');historyResume.click();await tick();
assert.deepEqual(posts.at(-1),{id:'s1',action:'resume',mode:'history'});
snapshot.sessions[0].recovery={status:'unverified',reason:'continuity_unverified',can_catch_up:false};
snapshot.sessions[0].events=[
  {id:'e-1',ref:'E-1',kind:'session_handover',text:'Passage de relais',created_at:'2026-11-09T05:30:00Z'}
];
vm.runInContext('render(snapshot)',ctx);
const eventSmall = document.querySelector('[data-session-id="s1"] .event-journal .chat-message small');
assert.ok(eventSmall, 'session event entry rendered in DOM');
assert.match(eventSmall.textContent, /E-1 · session_handover · /, 'event ref and kind rendered');
assert.match(eventSmall.textContent, /2026/, 'event created_at timestamp rendered');
assert.equal(Array.from(document.querySelectorAll('#sessions button')).some(x=>x.textContent.includes('Reprise avec historique')),false,'unknown continuity never offers catch-up');
assert.ok(Array.from(document.querySelectorAll('#sessions button')).some(x=>x.textContent.includes('sans rattrapage historique')));
snapshot.sessions[0].alerts=[
 {id:'old-finding',severity:'warning',reason:'Ancien',evidence:'ancien',disposition:'new',created_at:'2026-01-01T00:00:00Z'},
 {id:'new-finding',severity:'warning',reason:'Récent',evidence:'recent',disposition:'new',created_at:'2026-02-01T00:00:00Z'}
];
vm.runInContext('render(snapshot,true)',ctx);
const sortedFindings=Array.from(document.querySelectorAll('#sessions [data-alert-id]')).map(x=>x.dataset.alertId);
assert.ok(sortedFindings.indexOf('new-finding') < sortedFindings.indexOf('old-finding'),'newest finding is shown first');
if (deepLinkTest) {
  assert.equal(vm.runInContext('requestedSupervisorSession', ctx), 's1', 'deep link target session is s1');
  assert.equal(vm.runInContext('requestedSupervisorAlert', ctx), 'a1', 'deep link target alert is a1');
  console.log('Agent Supervisor UI: DEEP-LINK TEST PASSED (target session=s1, alert=a1 verified).');
} else {
  console.log('Agent Supervisor UI: candidate discovery, ambiguity and explicit confirmation passed.');
}
