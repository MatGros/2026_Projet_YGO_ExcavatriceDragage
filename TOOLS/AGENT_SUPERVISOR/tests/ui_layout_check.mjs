// T429 AC-F3.1/F3.4/F3.6/F3.7 — headless Chrome layout check on a synthetic snapshot (no live service).
// Usage (repo root): node TOOLS/AGENT_SUPERVISOR/tests/ui_layout_check.mjs [--shots <dir>]
// Exit 1 if, at any tested width, the page scrolls horizontally, an element overflows the viewport,
// the first finding is not in the first screen, or a long sentence is displayed twice in a finding card.
// Headless Chrome enforces a 500 px minimum window: narrow widths are rendered in an iframe of that width.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const chrome = process.env.VEILLEUR_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
if (!fs.existsSync(chrome)) { console.error('Chrome missing; set VEILLEUR_CHROME'); process.exit(2); }
const shotsArg = process.argv.indexOf('--shots'), shots = shotsArg > 0 ? process.argv[shotsArg + 1] : null;
const long = 'L’agent affirme que le guide a été « relu par un panel de 4 experts et un juge natif » et que « 39 corrections appliquées » avec « G531 et G200 PASS », présentant ces contrôles comme des validations acquises, sans preuve observable.';
const uuid = 'ebe3ca88-d30f-4113-a9eb-51df9de93f4d';
const alert = (id, severity, minutes, disposition) => ({id, severity, category: 'unsupported_success', reason: long + ' ' + id,
  evidence: '**Contrôles :** G531 PASS (324 chemins, mutation détectée), G200 PASS — C:\\Users\\ZEDVICTUS\\AppData\\Local\\ExcavatriceDragage\\supervision-exchanges\\' + uuid + '\\POINT_COURANT.md',
  disposition, business_state: 'open', version: 1, reference: 'A-' + id, created_at: `2026-11-09T01:${String(minutes).padStart(2, '0')}:00Z`,
  last_occurrence: `2026-11-09T01:${String(minutes).padStart(2, '0')}:00Z`, assessment: {status: 'active', reason: long + ' ' + id, evidence: 'x'},
  comments: [], history: [], workflow: {status: 'informational', delivery_status: 'not_sent'}, delivery_preview: '⚠️ Warning — Réussite sans preuve\n' + long});
const counts = {unread: 1, open: 3, deferred: 0, closed: 0, follow_up: 3, warnings: 2, alarms: 1, resolution_proposed: 0};
const fixture = {running: true, model: 'synthetic', allow_cloud: false, token: 't', service_version: 2, build_id: 'test', ui_build_id: 'test', update_available: false,
  chat: {messages: []}, counts, collector: {},
  sessions: [
    {id: 's-ok', platform: 'claude', native_id: '11111111-1111-1111-1111-111111111111', alias: 'session-calme', state: 'active', enabled: true, mission: 'Mission', alerts: [],
     counts: {unread: 0, open: 0, deferred: 0, closed: 0, follow_up: 0, warnings: 0, alarms: 0, resolution_proposed: 0}, events: [], framing: [], recovery: {status: 'none'}, chat_messages: []},
    {id: 's-t', platform: 'claude', native_id: uuid, alias: 't428-refactor-troubleshooting-avec-un-alias-long', state: 'paused', enabled: false,
     mission: 'Mission longue ' + long, source: 'C:\\Users\\ZEDVICTUS\\.claude\\projects\\C---MGS-DEV-2026-Projet-YGO-ExcavatriceDragage\\' + uuid + '.jsonl',
     exchange_path: 'C:\\Users\\ZEDVICTUS\\AppData\\Local\\ExcavatriceDragage\\supervision-exchanges\\' + uuid + '\\POINT_COURANT.md',
     alerts: [alert('a-old', 'warning', 1, 'seen'), alert('a-alarm', 'error', 2, 'seen'), alert('a-new', 'warning', 9, 'new')], counts,
     events: [], framing: [], recovery: {status: 'unverified', reason: 'checkpoint_absent'}, chat_messages: []}]};

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'veilleur-layout-'));
const probe = `<script>
window.fetch=async(url)=>({ok:true,status:200,json:async()=>url.includes('/history')?{messages:[]}:url.includes('candidates')?{candidates:[]}:window.__fixture});
window.__fixture=${JSON.stringify(fixture)};
setTimeout(()=>{const vw=document.documentElement.clientWidth,vh=window.innerHeight;
 const over=[...document.querySelectorAll('body *')].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.right>vw+1&&getComputedStyle(e).position!=='fixed'&&!e.closest('[hidden],details:not([open])>*:not(summary)');})
  .slice(0,12).map(e=>(e.tagName+'.'+(e.className||'')+'#'+(e.id||'')).slice(0,80)+' right='+Math.round(e.getBoundingClientRect().right));
 const first=document.querySelector('.finding-card');const firstTop=first?Math.round(first.getBoundingClientRect().top+window.scrollY):-1;
 const firstId=first?first.dataset.alertId:null;
 const dup=[...document.querySelectorAll('.finding-card[open]')].map(card=>{const seen=new Map();let d=0;for(const n of card.querySelectorAll('p,blockquote,span,li')){if(n.children.length)continue;const t=n.textContent.trim();if(t.length<40)continue;const k=t.slice(0,120);seen.set(k,(seen.get(k)||0)+1);if(seen.get(k)===2)d++;}return d;}).reduce((a,b)=>a+b,0);
 const out={vw,vh,scrollWidth:document.documentElement.scrollWidth,overflowing:over,firstFindingTop:firstTop,firstFindingId:firstId,duplicateLongTexts:dup,
  visibleActionsFirstCard:first?[...first.querySelectorAll(':scope > .alert-history-body > .finding-actions > button, :scope > .alert-history-body > .finding-actions > details > summary')].map(x=>x.textContent.trim()):[]};
 const pre=document.createElement('pre');pre.id='layout-result';pre.textContent=JSON.stringify(out);document.body.append(pre);if(window.parent!==window)window.parent.postMessage(JSON.stringify(out),'*');},1500);
</script>`;
let html = fs.readFileSync('TOOLS/AGENT_SUPERVISOR/ui/index.html', 'utf8');
html = html.replace('<script>', probe + '<script>');
const page = path.join(root, 'page.html');
fs.writeFileSync(page, html);
const pageUrl = pathToFileURL(page).href + '?session=s-t';
const results = [];
for (const [w, h] of [[1440, 900], [390, 844], [360, 740]]) {
  let url = pageUrl, win = `${w},${h}`;
  if (w < 500) {
    const frame = path.join(root, `frame_${w}.html`);
    fs.writeFileSync(frame, `<!doctype html><body style="margin:0"><iframe id="f" src="${pageUrl}" style="width:${w}px;height:${h}px;border:0"></iframe><script>addEventListener('message',e=>{const p=document.createElement('pre');p.id='layout-result';p.textContent=e.data;document.body.append(p);});</script></body>`);
    url = pathToFileURL(frame).href; win = `600,${h + 40}`;
  }
  const args = ['--headless', '--disable-gpu', '--no-first-run', '--disable-extensions', '--allow-file-access-from-files', `--user-data-dir=${path.join(root, 'p' + w)}`,
    `--window-size=${win}`, '--virtual-time-budget=5000'];
  const dom = spawnSync(chrome, [...args, '--dump-dom', url], {encoding: 'utf8', timeout: 60000, maxBuffer: 64 << 20});
  const match = /<pre id="layout-result">([\s\S]*?)<\/pre>/.exec(dom.stdout || '');
  const data = match ? JSON.parse(match[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')) : {error: 'no result', stderr: (dom.stderr || '').slice(-300)};
  if (shots) { fs.mkdirSync(shots, {recursive: true}); spawnSync(chrome, [...args, `--screenshot=${path.join(shots, `layout_${w}.png`)}`, url], {timeout: 60000}); }
  const checks = data.error ? {result: false} : {
    no_horizontal_scroll: data.scrollWidth <= data.vw,
    no_overflowing_element: data.overflowing.length === 0,
    first_finding_in_first_screen: data.firstFindingTop >= 0 && data.firstFindingTop < h,
    open_alarm_first: data.firstFindingId === 'a-alarm',
    no_duplicate_long_text: data.duplicateLongTexts === 0,
    at_most_3_primary_actions: data.visibleActionsFirstCard.length <= 3};
  results.push({width: w, height: h, ...data, checks});
}
const failed = results.flatMap(r => Object.entries(r.checks).filter(([, ok]) => !ok).map(([k]) => r.width + ':' + k));
console.log(JSON.stringify({results, failed}, null, 2));
process.exitCode = failed.length ? 1 : 0;
