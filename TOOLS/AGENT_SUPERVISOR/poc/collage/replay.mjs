// Isolated DOM evaluation. No network, service, transcript or task catalogue access.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const require=createRequire(process.env.SUPERVISION_DOM_MODULES || path.join(os.tmpdir(),'supervision-dom-tests','package.json'));
const {parseHTML}=require('linkedom');
const html=fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html','utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const {window,document}=parseHTML(html);
for(const s of document.querySelectorAll('select'))Object.defineProperty(s,'value',{configurable:true,get(){return this._value??this.options?.[0]?.value??''},set(v){this._value=String(v)}});
const posts=[];
const snapshot={running:false,token:'synthetic',model:'synthetic',allow_cloud:false,sessions:[],chat:{messages:[]}};
const fetch=async(url,opts={})=>{if(opts.method==='POST')posts.push({url,body:JSON.parse(opts.body)});return {ok:true,status:200,json:async()=>snapshot}};
const ctx=vm.createContext({window,document,navigator:{},localStorage:{getItem:()=>null,setItem:()=>{}},AbortController,fetch,console,Date,JSON,Set,Map,Promise,setTimeout:()=>1,clearTimeout:()=>{}});
vm.runInContext(script,ctx);
const tick=async()=>{for(let i=0;i<5;i++)await new Promise(r=>setImmediate(r));};
await tick();
const id='11111111-1111-4111-8111-111111111111';
const legacy=`  VEILLEUR_ASSIGN_V1\n    platform: agy\n    native_id: ${id}\n    alias: AGY01\n    task: T999 — Cadrage du système de tâches\n    user_goal: Cadrer le travail et ses règles\n    current_step: Attente de validation\n    scope_and_permissions: Modification outillage autorisée dans le périmètre\n    indiqué ; code automate interdit\n    constraints: Respect des contrôles et style concis\n    acceptance_criteria: Critères vérifiables\n    evidence_observed: Contrôle rapporté PASS\n    hypotheses_and_unknowns: Modalité de validation inconnue\n    next_step: Attendre la décision humaine\n    END_VEILLEUR_ASSIGN_V1`;
const userExample=` VEILLEUR_ASSIGN_V1\n  platform: agy\n  native_id: ${id}\n  alias: AGY01\n  task: T427 — Refonte Workflow Agents — Router de skills mince, contrat étendu, sas d'essais et note compagnon MD\n  user_goal: Cadrer le système de tâches projet, sécuriser les retours d'essais sans code à chaud et rationaliser hooks et skills\n  current_step: Cadrage achevé, contrat T427 scellé et validé, attente du GO pour implémentation\n  scope_and_permissions: Modification outillage autorisée dans le scope strict du contrat T427 (templates, skills, contracts), code\n  automate interdit\n  constraints: Zéro écriture dans CODE/M_MAIN/, respect des gates (G530, check_task_contract, check_skill_stubs), style concis TDAH\n  acceptance_criteria: AC1 à AC5 validés mécaniquement par les scripts de vérification du projet\n  evidence_observed: G530 PASS (1265 chemins), check_task_contract PASS, check_tasks_yaml PASS, check_task_agent_naming PASS\n  hypotheses_and_unknowns: Choix de relaxation PostToolUse vs diff-bundle, modalité du gel d essais\n  next_step: Implémentation du routeur project-workflow et des extensions de gabarit sur validation humaine\n  END_VEILLEUR_ASSIGN_V1`;
const json=`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform:'agy',native_id:id,alias:'AGY01',task:'T999 — Cadrage',scope_and_permissions:'Lecture seule\nPérimètre explicitement borné'})}\nEND_VEILLEUR_ASSIGN_V1`;
const rawJson=JSON.stringify({platform:'agy',native_id:id,alias:'AGY01',task:'T999 — Cadrage'});
const cases=[
 {name:'legacy_indent_continuation',input:legacy,expected:'accepted',missionContains:'indiqué ; code automate interdit'},
 {name:'user_t427_block_with_synthetic_uuid',input:userExample,expected:'accepted',missionContains:'code automate interdit'},
 {name:'json_in_markers',input:json,expected:'accepted',missionContains:'Périmètre explicitement borné'},
 {name:'json_raw_no_markers',input:rawJson,expected:'error'},
 {name:'json_fenced_inside_markers',input:`VEILLEUR_ASSIGN_V1\n\`\`\`json\n${rawJson}\n\`\`\`\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'legacy_continuation_with_colon',input:`VEILLEUR_ASSIGN_V1\nplatform: agy\nnative_id: ${id}\ntask: T999\nscope_and_permissions: audit\n  code: interdit\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'json_unknown_field',input:`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform:'agy',native_id:id,task:'T999',extra:'X'})}\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'json_long_mission',input:`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform:'agy',native_id:id,task:'T999',user_goal:'x'.repeat(1500)})}\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'legacy_duplicate_field',input:`VEILLEUR_ASSIGN_V1\nplatform: agy\nplatform: codex\nnative_id: ${id}\ntask: T999\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'json_duplicate_identity',input:`VEILLEUR_ASSIGN_V1\n{"platform":"agy","native_id":"${id}","native_id":"22222222-2222-4222-8222-222222222222","task":"T999"}\nEND_VEILLEUR_ASSIGN_V1`,expected:'error'},
 {name:'json_wrapped_inside_id',input:'VEILLEUR_ASSIGN_V1\n{"platform":"agy","native_id":"11111111-1111-4111-\n  8111-111111111111","task":"T999"}\nEND_VEILLEUR_ASSIGN_V1',expected:'error'},
 {name:'new_id_without_alias',input:`VEILLEUR_ASSIGN_V1\n${JSON.stringify({platform:'agy',native_id:id,task:'T999'})}\nEND_VEILLEUR_ASSIGN_V1`,expected:'accepted',expectedAlias:''}
];
const results=[];
for(const c of cases){
 document.getElementById('platform').value='agy';document.getElementById('native-id').value='ancien-id';document.getElementById('alias').value='ANCIEN-ALIAS';document.getElementById('mission').value='ANCIENNE MISSION';document.getElementById('assignment-response').value=c.input;
 document.getElementById('apply-agent-response').dispatchEvent(new window.Event('click',{bubbles:true,cancelable:true}));await tick();
 const notice=document.getElementById('notice'),actual=notice.className==='error'?'error':'accepted';
 const values={platform:document.getElementById('platform').value,native_id:document.getElementById('native-id').value,alias:document.getElementById('alias').value,mission:document.getElementById('mission').value};
 const missionOk=!c.missionContains||values.mission.includes(c.missionContains);
 const aliasOk=c.expectedAlias===undefined||values.alias===c.expectedAlias;
 const pass=actual===c.expected&&missionOk&&aliasOk;
 results.push({case:c.name,expected:c.expected,actual,pass,missionOk,aliasOk,notice:notice.textContent,values,input:c.input});
}
assert.equal(posts.length,0,'prefill must not attach a session');
const report={synthetic:true,network:false,note:'Pre-fill UI only; no attachment or task catalog checked.',cases:results,pass:results.filter(x=>x.pass).length,total:results.length};
const suffix=new Date().toISOString().replace(/[:.]/g,'-');
const out=path.join(root,`results-${suffix}.json`);fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({pass:report.pass,total:report.total,cases:results.map(({case:n,expected,actual,pass,aliasOk,notice})=>({case:n,expected,actual,pass,aliasOk,notice})),result:out},null,2));
if(report.pass!==report.total)process.exitCode=1;
