/** DOM smoke only. linkedom is a system-temp test dependency, never app runtime. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';

const dependencyRoot=process.env.SUPERVISION_DOM_MODULES||path.join(os.tmpdir(),'supervision-dom-tests','package.json');
const require=createRequire(dependencyRoot);
const {parseHTML}=require('linkedom');
const html=fs.readFileSync('DOC/WFLOW/AGENT_SUPERVISION.html','utf8');
const taskViewer=fs.readFileSync('TOOLS/TASK_MANAGER/ui/TASK_VIEWER.html','utf8');
const orchestratorHtml=fs.readFileSync('TOOLS/TASK_MANAGER/ui/ORCHESTRATOR_VIEWER.html','utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const tick=async()=>{for(let n=0;n<5;n++)await new Promise(resolve=>setImmediate(resolve));};
const clone=value=>JSON.parse(JSON.stringify(value));

async function environment({preferences={},permission='granted'}={}){
 const {window,document}=parseHTML(html),posts=[],notifications=[],timers=new Map(),storage=new Map();
 storage.set('agent-supervision.notifications.v1',JSON.stringify(preferences));
 const localStorage={getItem:key=>storage.get(key)||null,setItem:(key,value)=>storage.set(key,String(value))};
 // linkedom implements select.value as getter only; emulate browser selection for the smoke.
 for(const select of document.querySelectorAll('select'))Object.defineProperty(select,'value',{configurable:true,get(){return this._value??this.options?.[0]?.value??'';},set(value){this._value=String(value);}});
 let audioStarts=0,permissionRequests=0,failFetch=false,nextTimer=1;
 class Notice{static permission=permission;static async requestPermission(){permissionRequests++;return Notice.permission;}constructor(title,options){notifications.push({title,...options});}close(){}}
 class Audio{state='suspended';currentTime=0;destination={};async resume(){this.state='running';}createOscillator(){return{connect(){},frequency:{value:0},start(){audioStarts++;},stop(){}};}createGain(){return{connect(){},gain:{setValueAtTime(){},exponentialRampToValueAtTime(){}}};}}
 const snapshot={token:'test-token',running:false,model:'deepseek-v4.1-flash:cloud',allow_cloud:false,sessions:[{id:'s1',alias:'Claude T417',platform:'claude',native_id:'session-one',state:'paused',mission:'Objectif initial',alerts:[{id:'old',severity:'error',reason:'Ancienne alerte',evidence:'texte ancien',occurrences:1,disposition:'new'}]}],chat:{state:'idle',messages:[],error:null,session_id:null}};
 const fetch=async(_url,options={})=>{
  if(failFetch)throw Error('test offline');
  if(options.method==='POST'){
   assert.equal(options.headers['X-Supervision-Token'],'test-token');
   const payload=JSON.parse(options.body);posts.push(payload);
   const session=snapshot.sessions.find(s=>s.id===payload.id);
   switch(payload.action){
    case 'add':snapshot.sessions.push({id:'s2',alias:payload.alias,platform:payload.platform,native_id:payload.native_id,mission:payload.mission,state:'waiting',alerts:[]});break;
    case 'set_mission':session.mission=payload.mission;break;
    case 'chat':snapshot.chat={state:'idle',session_id:payload.session_id||null,error:null,messages:[{role:'user',text:payload.text,created_at:'2026-11-02T12:00:00Z'},{role:'assistant',text:'Réponse du veilleur',created_at:'2026-11-02T12:00:01Z'}]};break;
    case 'reset_chat':snapshot.chat={state:'idle',messages:[],error:null,session_id:null};break;
    case 'acknowledge':session.alerts.find(a=>a.id===payload.alert_id).disposition=payload.disposition;break;
    case 'export_note':session.exchange_path='C:/notes/session-one.md';break;
    case 'start':snapshot.running=true;break;
    case 'stop':snapshot.running=false;break;
   }
  }
  return{ok:true,status:200,json:async()=>clone(snapshot)};
 };
 window.Notification=Notice;window.AudioContext=Audio;window.focus=()=>{};
 const sandbox={window,document,navigator:{clipboard:{writeText:async text=>{sandbox.copied=text;}}},localStorage,Notification:Notice,AbortController,fetch,console,Date,JSON,Set,Map,Promise,setTimeout:(callback,delay)=>{const id=nextTimer++;timers.set(id,{callback,delay});return id;},clearTimeout:id=>timers.delete(id)};
 const context=vm.createContext(sandbox);vm.runInContext(script,context);await tick();
 const dispatch=async(id,type='click')=>{document.getElementById(id).dispatchEvent(new window.Event(type,{bubbles:true,cancelable:true}));await tick();};
 return{window,document,posts,snapshot,notifications,timers,dispatch,refresh:async()=>{await vm.runInContext('refresh()',context);await tick();},context,getAudioStarts:()=>audioStarts,getPermissionRequests:()=>permissionRequests,setOffline:value=>{failFetch=value;},cleanup(){window.dispatchEvent(new window.Event('pagehide'));assert.equal(timers.size,0);}};
}

const app=await environment({preferences:{desktop:true,sound:true}});
try{
 const get=id=>app.document.getElementById(id);
 assert.equal(get('assignment-response').closest('form'),null,'exchange area must be outside configuration form');
 assert.notEqual(get('assignment-response').closest('section'),get('platform').closest('section'),'exchange and configuration must be independent panels');
 assert.equal(get('copy-agent-brief').closest('section'),get('assignment-response').closest('section'),'prompt and response must share the exchange panel');
 assert.equal(app.notifications.length,0,'initial snapshot must not notify old alerts');
 assert.equal(get('model').value,'deepseek-v4.1-flash:cloud','DeepSeek V4.1 is selected by default');
 assert.ok(Array.from(get('model').options).some(option=>option.value==='qwen3.8:27b'),'installed local models remain selectable');
 assert.equal(get('allow-cloud').checked,false,'cloud model selection does not enable transcript sharing');
 app.snapshot.sessions[0].analysis_error='cloud_consent_required';await app.refresh();
 assert.match(get('sessions').textContent,/Aucun transcript n’a été envoyé/);
 app.snapshot.sessions[0].analysis_error=null;await app.refresh();
 assert.match(get('unread-count').textContent,/1 non lue/);
 assert.ok(Array.from(app.timers.values()).every(t=>t.delay===8000),'lightweight polling cadence');
 assert.match(get('mission').value,/Objectif : surveiller les écarts/,'general mission template is prefilled');
 get('mission-template').value='simulation';await app.dispatch('apply-mission-template');assert.match(get('mission').value,/Objectif : suivre un essai de simulation/);
 get('alias').value='Claude T417';await app.dispatch('copy-agent-brief');
  assert.match(app.context.copied,/VEILLEUR_ASSIGN_V1/);assert.match(app.context.copied,/native_id: inconnu/);assert.match(app.context.copied,/acceptance_criteria/);
  get('platform').value='codex';get('native-id').value='manual-thread';get('alias').value='Manual config';
   get('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: codex\nnative_id: manual-thread\nalias: Manual config\ntask: T417-C\nuser_goal: Tester le POC\ncurrent_step: Capturer une trace\nscope_and_permissions: Lecture seule\nconstraints: Aucun changement au code automate\nacceptance_criteria: Trace identifiable\nevidence_observed: CI P5\nhypotheses_and_unknowns: ID a confirmer\nnext_step: Affecter la session\nEND_VEILLEUR_ASSIGN_V1';
  await app.dispatch('apply-agent-response');
  assert.match(get('mission').value,/T417-C/);assert.match(get('mission').value,/Capturer une trace/);
   assert.equal(get('platform').value,'codex');assert.equal(get('native-id').value,'manual-thread');assert.equal(get('alias').value,'Manual config');
   assert.match(get('notice').textContent,/manual-thread/);assert.equal(get('notice').className,'');
   const missionBeforeBadBlock=get('mission').value;
   get('assignment-response').value='```\nVEILLEUR_ASSIGN_V1\nplatform: claude\nnative_id: declared-thread\nalias: Agent returned\ntask: T417-C\nuser_goal: Tester le POC\nEND_VEILLEUR_ASSIGN_V1\n```';
   await app.dispatch('apply-agent-response');assert.match(get('notice').textContent,/différaient/);assert.equal(get('platform').value,'claude');assert.equal(get('native-id').value,'declared-thread');assert.equal(get('alias').value,'Agent returned');
   get('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: codex\nnative_id: inconnu\ntask: T417-C\nEND_VEILLEUR_ASSIGN_V1';
   await app.dispatch('apply-agent-response');assert.match(get('notice').textContent,/inconnu/);assert.match(get('mission').value,/T417-C/);
   const missionBeforeMalformed=get('mission').value;
   get('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: codex\nnative_id: manual-thread\ntask: premier\ntask: doublon\nEND_VEILLEUR_ASSIGN_V1';
   await app.dispatch('apply-agent-response');assert.match(get('notice').textContent,/dupliqu/);assert.equal(get('mission').value,missionBeforeMalformed);
   get('assignment-response').value='VEILLEUR_ASSIGN_V1\nplatform: codex\nnative_id: manual-thread\ntask: '+'x'.repeat(1600)+'\nEND_VEILLEUR_ASSIGN_V1';
   await app.dispatch('apply-agent-response');assert.match(get('notice').textContent,/1 500 caractères/);assert.equal(get('mission').value,missionBeforeMalformed);
 get('platform').value='claude';get('native-id').value='session-two';get('alias').value='Second agent';get('mission').value='Objectif: test. Contraintes: lecture seule. Preuve: trace. Limites: CI.';
 await app.dispatch('add-form','submit');
 assert.equal(app.posts.at(-1).action,'add');assert.match(app.posts.at(-1).mission,/Objectif: test/);
 const mission=app.document.querySelector('[data-mission-id="s1"]');mission.value='Mission mise à jour';
 const missionSave=Array.from(mission.closest('article').querySelectorAll('button')).find(b=>b.textContent==='Enregistrer la mission');missionSave.click();await tick();
 assert.equal(app.posts.at(-1).action,'set_mission');assert.equal(app.posts.at(-1).mission,'Mission mise à jour');
 get('chat-session').value='s1';get('chat-text').value='Quelle preuve manque ?';await app.dispatch('chat-form','submit');
 assert.equal(app.posts.at(-1).session_id,'s1');assert.match(get('chat-log').textContent,/Réponse du veilleur/);
 await app.dispatch('reset-chat');assert.equal(app.posts.at(-1).action,'reset_chat');assert.doesNotMatch(get('chat-log').textContent,/Réponse du veilleur/);
 get('chat-session').value='';get('chat-text').value='État global ?';await app.dispatch('chat-form','submit');assert.equal(Object.hasOwn(app.posts.at(-1),'session_id'),false);
 await app.dispatch('unlock-audio');
 app.snapshot.sessions[0].alerts.push({id:'new-error',severity:'error',reason:'Erreur nouvelle',evidence:'preuve',occurrences:1,disposition:'new'});
 await app.refresh();assert.equal(app.notifications.length,1);assert.equal(app.getAudioStarts(),1);
 await app.refresh();assert.equal(app.notifications.length,1,'same ID must not notify twice');assert.equal(app.getAudioStarts(),1);
 app.snapshot.sessions[0].alerts.push({id:'new-warning',severity:'warning',reason:'Avertissement',evidence:'preuve',occurrences:2,disposition:'new'});
 await app.refresh();assert.equal(app.notifications.length,1,'warning only affects badge');assert.equal(app.getAudioStarts(),1);
 const seen=Array.from(app.document.querySelectorAll('.alert')).find(n=>n.textContent.includes('Erreur nouvelle'));
 Array.from(seen.querySelectorAll('button')).find(b=>b.textContent==='Vu').click();await tick();
 assert.equal(app.posts.at(-1).disposition,'seen');assert.match(get('unread-count').textContent,/2 non lues/);
 const warning=Array.from(app.document.querySelectorAll('.alert')).find(n=>n.textContent.includes('Avertissement'));
 Array.from(warning.querySelectorAll('button')).find(b=>b.textContent==='Faux positif').click();await tick();assert.equal(app.posts.at(-1).disposition,'false_positive');
 const copiedAlert=app.document.querySelector('.alert'),postsBeforeCopy=app.posts.length;Array.from(copiedAlert.querySelectorAll('button')).find(b=>b.textContent.includes('Copier le constat')).click();await tick();assert.match(app.context.copied,/Constat de supervision à vérifier/);assert.equal(app.posts.length,postsBeforeCopy,'copy must not reinject into any agent');
 app.snapshot.sessions[0].alias='<img src=x onerror=alert(1)>';app.snapshot.sessions[0].state='source_missing';app.snapshot.sessions[0].context_truncated=true;
 app.snapshot.sessions[0].alerts[0].reason='<script>malicious()</script>';await app.refresh();
 assert.equal(app.document.querySelectorAll('#sessions img,#sessions script').length,0);assert.match(get('sessions').textContent,/<img src=x/);assert.match(get('sessions').textContent,/introuvable/);assert.match(get('sessions').textContent,/Contexte tronqué/);
 const exportButton=Array.from(app.document.querySelectorAll('#sessions button')).find(b=>b.textContent==='Actualiser note');exportButton.click();await tick();assert.equal(app.posts.at(-1).action,'export_note');assert.match(get('sessions').textContent,/C:\/notes\/session-one.md/);
 const preserved=get('sessions').textContent;app.setOffline(true);await app.refresh();assert.equal(get('sessions').textContent,preserved);assert.equal(get('connection-error').hidden,false);
}finally{app.cleanup();}

const denied=await environment({permission:'denied'});
try{
 assert.equal(denied.document.getElementById('sound-enabled').checked,false);
 await denied.dispatch('enable-notifications');assert.match(denied.document.getElementById('notification-hint').textContent,/Permission refusée/);
 await denied.refresh();assert.equal(denied.getPermissionRequests(),0,'denial must not trigger permission loop');assert.equal(denied.notifications.length,0);
}finally{denied.cleanup();}

assert.match(taskViewer, /href="\/ORCHESTRATOR_VIEWER\.html" target="_blank"/);
assert.doesNotMatch(taskViewer, /orchestrator-section|defaultOrchestrator/,'registry is no longer duplicated inside Task Viewer');
const orchWindow=parseHTML(orchestratorHtml).window,orchDocument=orchWindow.document;
const registry={success:true,entries:[
 {id:'T-TEST-A',date:'2026-11-02',type:'tache',priorite:'haute',agent_id:'CC01',sujet:'Mission active',statut:'en_cours',verdict:'Verdict actif <script>reste du texte</script>',decision:'Continuer',note:''},
 {id:'T-TEST-D',date:'2026-11-01',type:'review',priorite:'moyenne',agent_id:'AGY01',sujet:'Mission terminée',statut:'terminé',verdict:'Clôturée',decision:'Aucune action',note:''}
]};
let registryUrl='';
const orchScript=orchestratorHtml.match(/<script>([\s\S]*?)<\/script>/)[1];
const orchContext=vm.createContext({window:orchWindow,document:orchDocument,fetch:async url=>{registryUrl=url;return{ok:true,json:async()=>clone(registry)};}});
vm.runInContext(orchScript,orchContext);await tick();
assert.equal(registryUrl,'/api/orchestrator/json');assert.equal(orchDocument.querySelectorAll('.entry').length,1);
assert.match(orchDocument.getElementById('count').textContent,/1\/2/);
const entryHead=orchDocument.querySelector('.entry-head');entryHead.click();assert.equal(entryHead.getAttribute('aria-expanded'),'true');
assert.equal(orchDocument.querySelectorAll('.entry script').length,0,'registry values render as text');
orchDocument.querySelector('[data-filter="done"]').click();assert.equal(orchDocument.querySelectorAll('.entry').length,1);assert.match(orchDocument.querySelector('.entry-id').textContent,/T-TEST-D/);
orchDocument.querySelector('[data-filter="all"]').click();orchDocument.getElementById('search').value='AGY01';orchDocument.getElementById('search').dispatchEvent(new orchWindow.Event('input'));assert.equal(orchDocument.querySelectorAll('.entry').length,1);
const fallbackWindow=parseHTML(orchestratorHtml).window,fallbackDocument=fallbackWindow.document,fallbackCalls=[];
const fallbackYaml=fs.readFileSync('DOC/WFLOW/TASKS_ORCHESTRATOR.yaml','utf8');
const fallbackContext=vm.createContext({window:fallbackWindow,document:fallbackDocument,fetch:async url=>{fallbackCalls.push(url);return url.startsWith('/api/')?{ok:false,status:404,json:async()=>({})}:{ok:true,status:200,text:async()=>fallbackYaml};}});
vm.runInContext(orchScript,fallbackContext);await tick();
assert.equal(fallbackCalls.length,2);assert.ok(fallbackDocument.querySelectorAll('.entry').length>0);
fallbackDocument.querySelector('[data-filter="all"]').click();assert.equal(fallbackDocument.querySelectorAll('.entry').length,(fallbackYaml.match(/^-\s+id:/gm)||[]).length);
assert.ok(Array.from(fallbackDocument.querySelectorAll('.entry-id')).some(item=>item.textContent==='ORCHESTRATION-REPRISE-AGY01-20261028'));
console.log('Veilleur DOM smoke: mission, chat/reset, scope, ack/badges, note, notifications, XSS, source errors and cleanup passed.');
console.log('Orchestrator page: dedicated route, API load, filters, search, details and safe text rendering passed.');
