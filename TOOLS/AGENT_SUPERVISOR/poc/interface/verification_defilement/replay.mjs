// Isolated fixture: the real UI, synthetic data, no service or user transcript.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const chrome=process.env.VEILLEUR_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
if(!fs.existsSync(chrome)) throw Error('Chrome absent; définir VEILLEUR_CHROME');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'veilleur-scroll-'));
const out=path.dirname(new URL(import.meta.url).pathname).replace(/^\/(\w:)/,'$1');
let html=fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html','utf8');
const fixture=`<script>window.__fixture={running:true,model:'synthetic',allow_cloud:false,chat:{messages:[]},sessions:[{id:'synthetic-1',platform:'claude',native_id:'poc-01',alias:'POC défilement',state:'active',mission:'Mission synthétique',alerts:[],chat_messages:[],judge_request:{attempted_at:'2026-11-05T03:00:00Z',attempt:1,status:'analyse',payload:{model:'synthetic',system:'Consigne fictive',prompt:JSON.stringify([{role:'user',text:Array.from({length:160},(_,i)=>'Ligne synthétique '+i+' : contenu de démonstration.').join('\\n')}]),options:{}}}}]};window.fetch=async()=>({ok:true,status:200,json:async()=>window.__fixture});</script>`;
html=html.replace('<script>',fixture+'<script>');
const measure=`<script>render(window.__fixture);const details=Array.from(document.querySelectorAll('#sessions details')).find(d=>d.querySelector('summary')?.textContent.includes('Ce que le juge a reçu'));details.open=true;Array.from(document.querySelector('main').children).forEach(x=>{if(x.id!=='sessions')x.style.display='none'});requestAnimationFrame(()=>requestAnimationFrame(()=>{const pre=details.querySelector('pre');const before=pre.scrollTop;pre.scrollTop=pre.scrollHeight;const v={clientHeight:pre.clientHeight,scrollHeight:pre.scrollHeight,scrollTopBefore:before,scrollTopAfter:pre.scrollTop,computedOverflowY:getComputedStyle(pre).overflowY,computedMaxHeight:getComputedStyle(pre).maxHeight};document.body.insertAdjacentHTML('beforeend','<output id="scroll-metrics">'+JSON.stringify(v)+'</output>');}));</script>`;
html=html.replace('</body>',measure+'</body>');
const file=path.join(root,'fixture.html');fs.writeFileSync(file,html);
const args=['--headless','--disable-gpu','--no-first-run','--disable-extensions','--window-size=1440,1400','--virtual-time-budget=2500'];
const dom=spawnSync(chrome,[...args,`--user-data-dir=${path.join(root,'profile-dom')}`,'--dump-dom',pathToFileURL(file).href],{encoding:'utf8',timeout:45000});
const match=dom.stdout?.match(/<output id="scroll-metrics">(\{[^<]+\})<\/output>/);
let metrics=null;try{metrics=JSON.parse(match?.[1]||'null');}catch{}
const runId=new Date().toISOString().replace(/[:.]/g,'-');
const screenshot=path.join(out,`capture-${runId}.png`);
const shot=spawnSync(chrome,[...args,`--user-data-dir=${path.join(root,'profile-shot')}`,`--screenshot=${screenshot}`,pathToFileURL(file).href],{encoding:'utf8',timeout:45000});
const report={fixture:file,dom_exit:dom.status,screenshot_exit:shot.status,metrics,success:!!metrics&&metrics.scrollHeight>metrics.clientHeight&&metrics.scrollTopBefore===0&&metrics.scrollTopAfter>0&&metrics.computedOverflowY==='auto',screenshot};
fs.writeFileSync(path.join(out,`results-${runId}.json`),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));if(!report.success||shot.status!==0)process.exitCode=1;
