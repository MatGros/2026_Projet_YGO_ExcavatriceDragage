// Synthetic browser fixture; standalone HTML, never contacts a running Veilleur.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
const chrome = process.env.VEILLEUR_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
if (!fs.existsSync(chrome)) throw Error('Chrome missing; set VEILLEUR_CHROME');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'veilleur-ui-browser-'));
let html=fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html','utf8');
// Block all HTTP calls and supply only invented data before the app script runs.
const mock=`<script>window.__fixture={running:true,model:'synthetic',allow_cloud:false,chat:{messages:[]},sessions:[{id:'synthetic-1',platform:'claude',native_id:'poc-01',alias:'POC session A',state:'active',mission:'Mission fictive pour la revue du rendu',alerts:[{id:'a1',severity:'warning',reason:'Alerte de demonstration',evidence:'Citation synthetique',disposition:'new'}],chat_messages:[{role:'user',text:'Question fictive'}],judge_request:{attempted_at:'2026-11-05T03:00:00Z',attempt:1,status:'analyse',payload:{model:'synthetic',system:'Consigne fictive',prompt:JSON.stringify([{role:'user',text:'Message fictif soumis au juge'}]),options:{}}}}]};window.fetch=async()=>({ok:true,status:200,json:async()=>window.__fixture});</script>`;
html=html.replace('<script>', mock+'<script>');
const populate=`<script>render(window.__fixture); document.querySelectorAll('#sessions details').forEach(x=>x.open=true); Array.from(document.querySelector('main').children).forEach(x=>{if(x.id!=='sessions')x.style.display='none'});</script>`;
html=html.replace('</body>',populate+'</body>');
const fixture=path.join(root,'fixture.html');fs.writeFileSync(fixture,html);
const screenshot=path.join(root,'screenshot.png');
const p=spawnSync(chrome,['--headless','--disable-gpu','--no-first-run','--disable-extensions',`--user-data-dir=${path.join(root,'profile')}`,'--window-size=1440,1800','--virtual-time-budget=1000',`--screenshot=${screenshot}`,pathToFileURL(fixture).href],{encoding:'utf8',timeout:45000});
console.log(JSON.stringify({fixture,screenshot,exit:p.status,error:p.error?.message??null,stdout:p.stdout,stderr:p.stderr},null,2));
if(p.status!==0||!fs.existsSync(screenshot)) process.exitCode=1;
