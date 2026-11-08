'use strict';

// Temporary loopback fixture for the VS Code Extension Development Host.
// Test-control POST routes are intentionally unavailable in the production Agent Supervisor service.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const port = Number(process.argv[2] || 18082);
const sharedNativeId = 'same-native-id-TEST-only';
let online = true;
let nextAlert = 1;

const sessions = [
  { id: 'test-claude', platform: 'claude', native_id: sharedNativeId, alias: 'TEST Claude', state: 'active', analysis_state: 'alert', alerts: [
    { id: 'test-warning-1', severity: 'warning', reason: 'TEST — incohérence à vérifier.', category: 'other', created_at: new Date().toISOString(), last_occurrence: new Date().toISOString(), occurrences: 1, disposition: 'new', workflow_status: 'legacy', delivery_status: 'not_sent' }
  ] },
  { id: 'test-agy', platform: 'agy', native_id: sharedNativeId, alias: 'TEST Antigravity', state: 'paused', analysis_state: 'no_alert', alerts: [
    { id: 'test-alarm-1', severity: 'error', reason: 'TEST — alarme déjà vue, toujours à suivre.', category: 'other', created_at: new Date().toISOString(), last_occurrence: new Date().toISOString(), occurrences: 2, disposition: 'seen', acknowledged_at: new Date().toISOString(), workflow_status: 'legacy', delivery_status: 'not_sent' }
  ] },
  { id: 'test-codex', platform: 'codex', native_id: sharedNativeId, alias: 'TEST Codex', state: 'active', analysis_state: 'waiting', alerts: [] },
  { id: 'test-dsh', platform: 'dsh', native_id: sharedNativeId, alias: 'TEST DSH', state: 'source_missing', analysis_state: 'unavailable', alerts: [] }
];

const server = http.createServer((request, response) => {
  if (request.socket.remoteAddress !== '127.0.0.1') {
    response.writeHead(403).end();
    return;
  }
  if (request.method === 'GET' && request.url === '/') {
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    response.end(fs.readFileSync(path.resolve(__dirname, '../../../ui/index.html')));
    return;
  }
  if (request.method === 'GET' && request.url === '/api/supervision') {
    if (!online) { response.writeHead(503, { 'Content-Type': 'text/plain' }).end('TEST offline'); return; }
    response.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    const publicSessions = sessions.map((session) => ({ ...session, mission: 'TEST — mission synthétique.', initial_mission: 'TEST — mission synthétique.',
      memory: [], context_truncated: false, source: null, error: null, last_event: null, last_analysis: null, analysis_error: null,
      exchange_path: null, exchange_error: null, exchange_saved_at: null, judge_request: null, judge_proposal: null,
      messages_observed: 0, chat_messages: [] }));
    response.end(JSON.stringify({ running: true, model: 'TEST — aucun modèle', allow_cloud: false, load_error: null, storage_error: null,
      chat: { state: 'paused', messages: [] }, poll_interval_seconds: 8, collector: { sessions_enabled: 4, messages_seen: 0, cycles: 0,
        sessions_unavailable: 0, last_cycle_at: null }, sessions: publicSessions,
      alerts: publicSessions.flatMap((session) => session.alerts.map((alert) => ({ ...alert, session_id: session.id, alias: session.alias }))),
      token: 'TEST-ONLY-NOT-A-SECRET', service_version: 2, build_id: 'fixture', update_available: false }));
    return;
  }
  if (request.method === 'GET' && request.url === '/api/supervision/summary') {
    if (!online) { response.writeHead(503, { 'Content-Type': 'text/plain' }).end('TEST offline'); return; }
    response.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    response.end(JSON.stringify({ schema_version: 1, running: true, sessions }));
    return;
  }
  if (request.method === 'POST' && request.url === '/__test/add-finding') {
    let body = '';
    request.on('data', (chunk) => { body += chunk; });
    request.on('end', () => {
      let input = {};
      try { input = JSON.parse(body || '{}'); } catch (_) {}
      const severity = input.severity === 'error' ? 'error' : 'warning';
      const id = `test-new-${nextAlert++}`;
      const now = new Date().toISOString();
      sessions[0].alerts.push({ id, severity, reason: input.reason || 'TEST — nouvel événement synthétique.', evidence: 'TEST — citation synthétique.', category: 'other', created_at: now, last_occurrence: now, occurrences: 1, disposition: 'new', acknowledged_at: null, workflow: { status: 'legacy', delivery_status: 'not_sent' }, workflow_status: 'legacy', delivery_status: 'not_sent' });
      response.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify({ ok: true, id }));
    });
    return;
  }
  if (request.method === 'POST' && request.url === '/__test/offline') {
    online = false;
    response.writeHead(200, { 'Content-Type': 'application/json' }).end('{"ok":true}');
    return;
  }
  if (request.method === 'POST' && request.url === '/__test/online') {
    online = true;
    response.writeHead(200, { 'Content-Type': 'application/json' }).end('{"ok":true}');
    return;
  }
  response.writeHead(404).end();
});

server.listen(port, '127.0.0.1', () => process.stdout.write(`TEST fixture Agent Supervisor : http://127.0.0.1:${port}\n`));
