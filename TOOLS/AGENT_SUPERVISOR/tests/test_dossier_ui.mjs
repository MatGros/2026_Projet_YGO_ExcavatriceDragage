import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';

// T429 R13/R14 (2026-11-14) : le dossier de lecture du juge est VISIBLE et DISTINGUE de
// tout acces direct au depot ; chaque constat declare la liste exacte des fichiers lus.
const require = createRequire(process.env.SUPERVISION_DOM_MODULES || path.join(os.tmpdir(), 'supervision-dom-tests', 'package.json'));
const {parseHTML} = require('linkedom');
const html = fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const {window, document} = parseHTML(html);window.HTMLElement.prototype.scrollIntoView=()=>{};
for (const select of document.querySelectorAll('select')) Object.defineProperty(select, 'value', {configurable:true, get(){return this._value ?? this.options?.[0]?.value ?? '';}, set(value){this._value=String(value);}});
const timers=[];
const snapshot = {running:true,token:'token',model:'local',allow_cloud:false,sessions:[{id:'s1',platform:'claude',native_id:'session-a',alias:'A',state:'active',analysis_state:'alert',mission:'Mission A',chat_messages:[],judge_request:null,
 memory_state:{fenetre:2,memoire_longue:5,journal:3,preuves_acquises:3,cadrage:1,ecartes:0,fenetre_tronquee:false,regles:12,dossier_lecture:{fichiers:['DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/CONTRAT.yaml','DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/PLAN.md'],illisibles:[{path:'DOC/inexistant.md',erreur:'FileNotFoundError'}],total_caracteres:900,budget:{max_fichiers:6,max_caracteres:12000}}},
 alerts:[{id:'a1',severity:'warning',reason:'Constat TEST',evidence:'Citation TEST',disposition:'new',workflow:{status:'legacy'},memory_usage:{fenetre:2,memoire_longue:5,journal:3,preuves_acquises:3,cadrage:1,fenetre_tronquee:false},lecture_declaree:{fichiers:['DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/CONTRAT.yaml'],illisibles:['DOC/inexistant.md']}}]},
 {id:'s2',platform:'claude',native_id:'session-mmx',alias:'T429-MMX01',state:'active',analysis_state:'no_alert',mission:'Mission MMX',chat_messages:[],judge_request:null,alerts:[]}],chat:{messages:[]}}
class FakeNotification{constructor(title,options){this.close=()=>{};}}FakeNotification.permission='granted';FakeNotification.requestPermission=async()=>'granted';window.Notification=FakeNotification;class FakeAudioContext{state='suspended';async resume(){this.state='running';}}window.AudioContext=FakeAudioContext;
const fetch = async () => ({ok:true,status:200,json:async()=>snapshot});
const sandbox={window,document,Notification:FakeNotification,navigator:{},localStorage:{getItem:()=>null,setItem:()=>{}},AbortController,URLSearchParams,fetch,console,Date,JSON,Set,Map,Promise,setTimeout:(f,ms)=>{timers.push({f,ms});return timers.length;},clearTimeout:()=>{}};
const ctx=vm.createContext(sandbox);
vm.runInContext(script,ctx);
await new Promise(resolve=>setImmediate(resolve));
sandbox.snapshot=snapshot;vm.runInContext('render(snapshot)',ctx);
const text=document.body.textContent;

assert.match(text,/📖 Dossier de lecture \(fourni au juge, lecture seule\)/,'R13 : le dossier de lecture est affiche avec son propre libelle');
assert.match(text,/Accès direct au dépôt : interdit en v1/,'R14 : le libelle depot-access interdit reste distinct');
assert.match(text,/DOC\/WFLOW\/TASKS\/T429_AGENT_SUPERVISOR\/CONTRAT\.yaml/,'les chemins du dossier sont affiches');
assert.match(text,/DOC\/inexistant\.md: FileNotFoundError/,'un fichier illisible est signale avec sa cause, jamais devine');
assert.match(text,/budget 6 fichiers \/ 12000 caractères/,'le budget affiche est le budget reel');
assert.match(text,/📖 Fichiers déclarés lus pour ce verdict/,'R13 : chaque constat declare sa lecture');
assert.match(text,/DOC\/inexistant\.md/,'la declaration du constat porte le fichier signale');
assert.match(text,/preuves 3 /,'la cle preuves_acquises est lue (le champ n affiche plus undefined)');
// R16 : la couleur porte l'etat (marqueur, fond discret, etiquette) — le texte du menu de gauche reste neutre ;
// l'identifiant d'agent est un badge colore selon le standard par acteur.
assert.match(html,/\.side-session\.has-alarm,[^}]*color:var\(--text\)/,'R16 : meme en alarme le bouton garde un texte neutre');
assert.match(html,/\.side-session\.status-alarm \.side-session-title\{color:var\(--text\);font-weight:650\}/,'R16 : le titre de session n est plus recolore par l etat');
assert.match(html,/\.side-session\.has-alarm \.session-marker\{background:#ff626d\}/,'R16 : l alarme vit sur le marqueur d etat');
const sideTitle=document.querySelector('.side-session .side-session-title');
assert.ok(sideTitle,'le titre de session latéral rendu');
const badge=document.querySelector('.side-session-content .model-tag');
assert.ok(badge,'R16 : badge identifiant d agent present dans le menu de gauche');
assert.equal(badge.textContent,'claude');
assert.ok(badge.classList.contains('model-claude'),'R16 : badge colore selon le standard d acteur');
const mmxBadge=Array.from(document.querySelectorAll('.side-session-content .model-tag')).find(item=>item.textContent==='MMX');
assert.ok(mmxBadge,'R16 : la famille d acteur MMX est detectee dans l alias T429-MMX01');
assert.ok(mmxBadge.classList.contains('model-mmx'),'R16 : MMX colore en jaune meme sous terminal claude');
assert.match(html,/\.model-tag\.model-mmx\{color:#ffdd57\}/,'standard acteur MMX declare');
assert.match(html,/\.model-tag\.model-agy\{color:#8ab4f8\}/,'standard par acteur : texte colore seul');
assert.doesNotMatch(html,/\.model-tag\{[^}]*background/,'remarque exploitant : plus de badge encadre, du texte colore');
assert.match(html,/\.side-session-meta-row\{display:flex/,'le badge et la meta partagent une ligne');
console.log('R13/R14 + R16 UI : 16 asserts PASS');
