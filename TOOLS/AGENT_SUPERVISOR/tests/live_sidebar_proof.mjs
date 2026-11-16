// R29 (2026-11-16) : PREUVE LIVE — le menu de gauche de la page RÉELLEMENT servie par
// 127.0.0.1:8082 affiche-t-il le titre complet (display_title) des sessions vivantes ?
// Usage : node TOOLS/AGENT_SUPERVISOR/tests/live_sidebar_proof.mjs
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';

const require = createRequire(process.env.SUPERVISION_DOM_MODULES || path.join(os.tmpdir(), 'supervision-dom-tests', 'package.json'));
const {parseHTML} = require('linkedom');

const base = 'http://127.0.0.1:8082';
const html = await (await fetch(base + '/')).text();
const snapshot = await (await fetch(base + '/api/supervision')).json();
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const {window, document} = parseHTML(html);
window.HTMLElement.prototype.scrollIntoView = () => {};
for (const select of document.querySelectorAll('select')) Object.defineProperty(select, 'value', {configurable: true, get(){return this._optionValue ?? '';}, set(v){this._optionValue = String(v);}});
class FakeNotification { constructor(){} close(){} } FakeNotification.permission = 'granted'; FakeNotification.requestPermission = async () => 'granted';
window.Notification = FakeNotification; window.AudioContext = class { async resume(){} };
const sandbox = {window, document, Notification: FakeNotification, navigator: {}, localStorage: {getItem: () => null, setItem: () => {}}, AbortController, URLSearchParams, fetch: async () => ({ok: true, status: 200, json: async () => snapshot}), console, Date, JSON, Set, Map, Promise, setTimeout: (f) => 0, clearTimeout: () => {}};
const ctx = vm.createContext(sandbox);
vm.runInContext(script, ctx);
await new Promise(resolve => setImmediate(resolve));
sandbox.snapshot = snapshot;
vm.runInContext('render(snapshot)', ctx);
const rows = [...document.querySelectorAll('.side-session')].map(row => ({title: row.querySelector('.side-session-title')?.textContent || '', full: row.textContent}));
console.log('PAGE SERVIE : ' + base + '/ (ui_build_id=' + (snapshot.ui_build_id || '?') + ')');
console.log('MEMU GAUCHE RENDU (titres des sessions vivantes) :');
for (const row of rows) console.log('  - ' + row.title);
const expected = (snapshot.sessions || []).map(s => s.display_title || s.alias || s.native_id);
const missing = expected.filter(title => !rows.some(row => row.title === title));
if (missing.length) { console.log('ECHEC : titres absents -> ' + JSON.stringify(missing)); process.exit(1); }
console.log('PREUVE OK : chaque session vivante affiche son titre complet dans le menu de gauche.');
