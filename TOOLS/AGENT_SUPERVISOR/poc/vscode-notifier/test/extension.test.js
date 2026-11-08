'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { activate } = require('../extension');

function finding(id, disposition, severity, reason) {
  return { id, disposition, severity, reason, category: 'other', occurrences: 1, workflow_status: 'legacy' };
}

function baseSummary() {
  return {
    schema_version: 1, running: true,
    sessions: [
      { id: 'supervision-claude', platform: 'claude', native_id: 'same-native-id', alias: 'TEST Claude', state: 'active', analysis_state: 'alert', alerts: [
        finding('warning-1', 'new', 'warning', 'TEST — incohérence à vérifier.'),
        finding('alarm-1', 'seen', 'error', 'TEST — ancienne alarme toujours à suivre.')
      ] },
      { id: 'supervision-agy', platform: 'agy', native_id: 'same-native-id', alias: 'TEST Antigravity', state: 'paused', analysis_state: 'waiting', alerts: [] },
      { id: 'supervision-codex', platform: 'codex', native_id: 'same-native-id', alias: 'TEST Codex', state: 'active', analysis_state: 'waiting', alerts: [] },
      { id: 'supervision-dsh', platform: 'dsh', native_id: 'same-native-id', alias: 'TEST DSH', state: 'source_missing', analysis_state: 'unavailable', alerts: [] }
    ]
  };
}

function tooltipText(statusItem) {
  return typeof statusItem.tooltip === 'string' ? statusItem.tooltip : statusItem.tooltip.value;
}

function mockVscode(port) {
  const commands = new Map();
  const warnings = [];
  const errors = [];
  const external = [];
  const quickPickCalls = [];
  const quickPickResults = [];
  const warningResults = [];
  const errorResults = [];
  let statusItem;
  const vscode = {
    StatusBarAlignment: { Left: 1 },
    MarkdownString: class MarkdownString { constructor(value) { this.value = value; this.isTrusted = true; } },
    window: {
      createStatusBarItem() {
        statusItem = { text: '', tooltip: '', command: '', shown: false, show() { this.shown = true; }, dispose() {} };
        return statusItem;
      },
      showWarningMessage(message, ...actions) {
        warnings.push({ message, actions });
        return warningResults.length ? warningResults.shift() : Promise.resolve(undefined);
      },
      showErrorMessage(message, ...actions) { errors.push({ message, actions }); return errorResults.length ? errorResults.shift() : Promise.resolve(undefined); },
      showQuickPick(items, options) {
        quickPickCalls.push({ items, options });
        const choose = quickPickResults.shift();
        return Promise.resolve(choose ? choose(items) : undefined);
      }
    },
    workspace: {
      getConfiguration(section) {
        assert.equal(section, 'veilleur');
        return { get(key, fallback) { return ({ port, pollSeconds: 60, notifications: true })[key] ?? fallback; } };
      },
      onDidChangeConfiguration() { return { dispose() {} }; }
    },
    commands: { registerCommand(name, callback) { commands.set(name, callback); return { dispose() { commands.delete(name); } }; } },
    env: { openExternal(uri) { external.push(uri.toString()); return Promise.resolve(true); } },
    Uri: { parse(value) { return new URL(value); } }
  };
  return { vscode, commands, warnings, errors, external, quickPickCalls, quickPickResults, warningResults, errorResults, get statusItem() { return statusItem; } };
}

async function eventually(predicate, message) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  assert.fail(message);
}

test('activation, toast non bloquant, déduplication, alarme, panne/rétablissement et navigation ciblée', async (t) => {
  let summary = baseSummary();
  let online = true;
  const methods = [];
  const server = http.createServer((request, response) => {
    methods.push(`${request.method} ${request.url}`);
    if (request.method !== 'GET' || request.url !== '/api/supervision/summary') {
      response.writeHead(405).end();
      return;
    }
    if (!online) { response.writeHead(503).end('TEST offline'); return; }
    response.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(summary));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());

  const port = server.address().port;
  const ui = mockVscode(port);
  const state = new Map();
  const context = { subscriptions: [], globalState: {
    get(key) { return state.get(key); },
    async update(key, value) { state.set(key, value); }
  } };
  activate(context, ui.vscode);
  t.after(() => { for (const subscription of context.subscriptions) subscription.dispose?.(); });

  await eventually(() => ui.statusItem?.text.includes('2 à suivre'), 'activation lit le premier état local');
  assert.equal(ui.statusItem.shown, true);
  assert.match(ui.statusItem.text, /1 non lue/);
  assert.match(ui.statusItem.text, /Agent Supervisor/);
  assert.match(tooltipText(ui.statusItem), /Collecte active/);
  assert.ok(tooltipText(ui.statusItem).indexOf('Alarm 1') < tooltipText(ui.statusItem).indexOf('Collecte active'), 'les problèmes précèdent le statut technique vert');
  assert.match(tooltipText(ui.statusItem), /Compatibilit?/);
  assert.match(ui.statusItem.text, /\$\(error\)/);
  assert.match(tooltipText(ui.statusItem), /Sessions avec constats à suivre/);
  assert.match(tooltipText(ui.statusItem), /TEST Claude/);
  assert.match(tooltipText(ui.statusItem), /Non lues[\s\S]*marquées « Vu »/);
  assert.equal(ui.statusItem.tooltip.isTrusted, false, 'les données des sessions restent du texte non fiable dans MarkdownString');
  assert.equal(ui.warnings.length + ui.errors.length, 0, 'le premier snapshot établit la base sans rattrapage de toast');

  let resolveToast;
  ui.warningResults.push(new Promise((resolve) => { resolveToast = resolve; }));
  summary.sessions[0].alerts.push(finding('warning-2', 'new', 'warning', 'TEST — nouveau constat.'));
  await ui.commands.get('veilleur.refresh')();
  assert.equal(ui.warnings.length, 1, 'un nouveau constat déclenche un toast');
  assert.match(ui.warnings[0].message, /Nouveau/);
  assert.match(ui.statusItem.text, /3 à suivre/);
  await ui.commands.get('veilleur.refresh')();
  assert.equal(ui.warnings.length, 1, 'le refresh identique ne répète pas le toast');
  resolveToast('Ouvrir le constat');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ui.external.at(-1), `http://127.0.0.1:${port}/?session=supervision-claude&alert=warning-2`);

  ui.warningResults.push(Promise.resolve('Ouvrir le constat réel'));
  await ui.commands.get('veilleur.testNotification')();
  await new Promise((resolve) => setImmediate(resolve));
  assert.match(ui.warnings.at(-1).message, /TEST — Agent Supervisor/);
  assert.equal(ui.external.at(-1), `http://127.0.0.1:${port}/?session=supervision-claude&alert=warning-2`, 'le test de toast ouvre le constat réel sans modifier son état');

  summary.sessions[0].alerts[2].severity = 'error';
  summary.sessions[0].alerts[2].reason = 'TEST — requalification en alarme.';
  await ui.commands.get('veilleur.refresh')();
  assert.equal(ui.errors.length, 1, 'une requalification en alarme utilise le niveau rouge');
  assert.match(ui.errors[0].message, /Mis à jour/);

  ui.errorResults.push(Promise.resolve('Ouvrir l’alarme prioritaire'));
  summary.sessions[0].alerts.push(
    finding('warning-3', 'new', 'warning', 'TEST — nouvel avertissement groupé.'),
    finding('alarm-2', 'new', 'error', 'TEST — nouvelle alarme groupée.')
  );
  await ui.commands.get('veilleur.refresh')();
  assert.equal(ui.errors.length, 2, 'un lot mixte produit une seule notification de criticité maximale');
  assert.match(ui.errors[1].message, /2 constats/);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ui.external.at(-1), `http://127.0.0.1:${port}/?session=supervision-claude&alert=alarm-2`, 'le toast rouge ouvre l’alarme du lot');

  online = false;
  await ui.commands.get('veilleur.refresh')();
  assert.match(ui.statusItem.text, /5 à suivre · 4 non lues · périmé/);
  assert.doesNotMatch(ui.statusItem.text, /0 à suivre/);
  ui.quickPickResults.push((items) => items.find((item) => item.session?.id === 'supervision-claude'));
  ui.quickPickResults.push((items) => items.find((item) => item.alert?.id === 'warning-2'));
  await ui.commands.get('veilleur.open')();
  assert.match(ui.quickPickCalls.at(-2).options.placeHolder, /périmées/);
  assert.equal(ui.external.at(-1), `http://127.0.0.1:${port}/?session=supervision-claude&alert=warning-2`);

  online = true;
  await ui.commands.get('veilleur.refresh')();
  assert.match(ui.statusItem.text, /5 à suivre · 4 non lues/);
  assert.doesNotMatch(ui.statusItem.text, /périmé/);
  assert.ok(methods.every((entry) => entry === 'GET /api/supervision/summary'), 'l’extension ne fait que des GET sur le résumé dédié');
});

test('survol moderne reprend les comptes serveur et distingue résolution proposée de problème actif', async (t) => {
  const totals = { unread: 0, open: 2, deferred: 1, closed: 4, follow_up: 3, warnings: 0, alarms: 0, resolution_proposed: 2 };
  let summary = {
    schema_version: 1, running: true, counts: totals,
    sessions: [{ ...baseSummary().sessions[0], counts: totals, alerts: [{
      ...finding('resolution-1', 'seen', 'warning', 'Correction retrouvée ; décision utilisateur attendue.'),
      reference: 'T428-E17', business_state: 'open', version: 2, assessment: { status: 'resolution_proposed' }
    }] }]
  };
  const server = http.createServer((_req, res) => res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(summary)));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const ui = mockVscode(server.address().port);
  const state = new Map();
  const context = { subscriptions: [], globalState: { get: (key) => state.get(key), async update(key, value) { state.set(key, value); } } };
  activate(context, ui.vscode);
  t.after(() => context.subscriptions.forEach((item) => item.dispose?.()));
  await eventually(() => ui.statusItem?.text.includes('3 à suivre'), 'compteurs serveur reçus, pas recalculés depuis une carte');
  assert.match(tooltipText(ui.statusItem), /2 résolution\(s\) proposée\(s\)/);
  assert.doesNotMatch(tooltipText(ui.statusItem), /Compatibilité/);
  assert.match(ui.statusItem.text, /\$\(question\)/);
  assert.equal(ui.warnings.length + ui.errors.length, 0);
  summary.sessions[0].alerts[0].version += 1;
  summary.sessions[0].alerts[0].reason = 'Commentaire utilisateur pris en compte, même preuve.';
  await ui.commands.get('veilleur.refresh')();
  assert.equal(ui.warnings.length + ui.errors.length, 0, 'commentaire/résolution ne génèrent pas de nouvelle anomalie');
  ui.quickPickResults.push((items) => items[0]);
  ui.quickPickResults.push((items) => {
    assert.match(items[0].label, /Resolution proposed/);
    assert.match(items[0].description, /T428-E17/);
    return items[0];
  });
  await ui.commands.get('veilleur.open')();
  assert.match(ui.external.at(-1), /session=supervision-claude&alert=resolution-1$/);
});
