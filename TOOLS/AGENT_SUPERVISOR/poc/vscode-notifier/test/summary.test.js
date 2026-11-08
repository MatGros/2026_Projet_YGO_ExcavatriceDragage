'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeSummary, counts, sessionIdentity, changedFindings } = require('../lib/summary');

function alert(id, disposition, severity = 'warning', reason = 'Raison de test', evidenceHash = 'evidence-a') {
  return { id, disposition, severity, reason, evidence_hash: evidenceHash, occurrences: 1 };
}

function session(platform, nativeId, id, alerts) {
  return { id, platform, native_id: nativeId, alias: platform.toUpperCase(), state: 'active', analysis_state: 'no_alert', alerts };
}

test('compte séparément non lues et à suivre selon les décisions locales', () => {
  const normalized = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'same-uuid', 's1', [
    alert('new-warning', 'new'), alert('seen-warning', 'seen'), alert('pending-alarm', 'pending', 'error'),
    alert('deferred', 'deferred'), alert('ignored', 'ignored'), alert('resolved', 'resolved'), alert('false-positive', 'false_positive')
  ])] });
  assert.deepEqual(counts(normalized), { sessions: 1, unread: 1, followUp: 4, open: 3, deferred: 1, closed: 3, warnings: 3, alarms: 1, resolutionProposed: 0, countsSource: 'legacy' });
});

test('isole deux UUID identiques rattachés à des plateformes différentes', () => {
  const claude = session('claude', 'same-uuid', 'supervision-1', []);
  const agy = session('agy', 'same-uuid', 'supervision-2', []);
  assert.notEqual(sessionIdentity(claude), sessionIdentity(agy));
});

test('premier snapshot sert de base sans toast puis les répétitions restent silencieuses', () => {
  const summary = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'id', 's1', [alert('a1', 'new')])] });
  const baseline = changedFindings(null, summary);
  assert.equal(baseline.events.length, 0);
  assert.equal(changedFindings(baseline.known, summary).events.length, 0);
  const later = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'id', 's1', [alert('a1', 'new'), alert('a2', 'new')])] });
  assert.equal(changedFindings(baseline.known, later).events.length, 1);
});

test('une requalification est signalée, un simple changement de compte ne relance pas le toast', () => {
  const before = normalizeSummary({ schema_version: 1, running: true, sessions: [session('agy', 'id', 's1', [alert('a1', 'new')])] });
  const baseline = changedFindings({}, before).known;
  const repeated = normalizeSummary({ schema_version: 1, running: true, sessions: [session('agy', 'id', 's1', [{ ...alert('a1', 'seen'), occurrences: 5 }])] });
  assert.equal(changedFindings(baseline, repeated).events.length, 0);
  const updated = normalizeSummary({ schema_version: 1, running: true, sessions: [session('agy', 'id', 's1', [alert('a1', 'seen', 'error', 'Nouvelle qualification')])] });
  const changes = changedFindings(baseline, updated);
  assert.equal(changes.events.length, 1);
  assert.equal(changes.events[0].kind, 'updated');
});

test('un changement de citation détecté par son empreinte déclenche une mise à jour sans exposer le texte', () => {
  const before = normalizeSummary({ schema_version: 1, running: true, sessions: [session('agy', 'id', 's1', [alert('a1', 'new')])] });
  const known = changedFindings(null, before).known;
  const after = normalizeSummary({ schema_version: 1, running: true, sessions: [session('agy', 'id', 's1', [alert('a1', 'new', 'warning', 'Raison de test', 'evidence-b')])] });
  const changes = changedFindings(known, after);
  assert.equal(changes.events.length, 1);
  assert.equal(changes.events[0].kind, 'updated');
  assert.equal(after.sessions[0].alerts[0].evidence_hash, 'evidence-b');
  assert.equal(Object.hasOwn(after.sessions[0].alerts[0], 'evidence'), false);
});

test('refuse les snapshots invalides au lieu de les transformer en compteurs nuls', () => {
  assert.throws(() => normalizeSummary({ sessions: [] }), /schéma 1/);
  assert.throws(() => normalizeSummary({ schema_version: 1, sessions: [{ id: 's', platform: 'claude' }] }), /Identité de session/);
});

test('ne notifie pas les constats déjà ignorés ou résolus au premier contact', () => {
  const summary = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'id', 's1', [
    alert('resolved', 'resolved'), alert('ignored', 'ignored')
  ])] });
  assert.deepEqual(changedFindings(null, summary).events, []);
});

test('un constat clos qui revient avec une nouvelle preuve est signalé à nouveau', () => {
  const closed = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'id', 's1', [alert('a1', 'resolved')])] });
  const known = changedFindings(null, closed).known;
  const reopened = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'id', 's1', [alert('a1', 'new', 'warning', 'Nouvelle preuve', 'evidence-b')])] });
  const changes = changedFindings(known, reopened);
  assert.equal(changes.events.length, 1);
  assert.equal(changes.events[0].kind, 'updated');
});


test('reprend les compteurs du service sans recalcul depuis une liste partielle', () => {
  const totals = { unread: 2, open: 7, deferred: 1, closed: 9, follow_up: 8, warnings: 4, alarms: 1, resolution_proposed: 3 };
  const normalized = normalizeSummary({ schema_version: 1, running: true, counts: totals, sessions: [
    { ...session('claude', 'uuid', 's1', []), counts: totals }
  ] });
  assert.equal(counts(normalized).followUp, 8);
  assert.equal(counts(normalized).alarms, 1);
  assert.equal(counts(normalized).resolutionProposed, 3);
  assert.equal(counts(normalized).countsSource, 'service');
  assert.throws(() => normalizeSummary({ schema_version: 1, running: true, counts: { ...totals, open: -1 }, sessions: [] }), /Compteurs/);
});

test('lecture commentaire et résolution proposée actualisent les données sans nouvelle alerte', () => {
  const snapshot = (item) => normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'uuid', 's1', [item])] });
  const original = { ...alert('a1', 'new'), version: 1, business_state: 'open', assessment: { status: 'active' } };
  const baseline = changedFindings(null, snapshot(original));
  const commented = { ...original, disposition: 'seen', version: 2, reason: 'Reformulation plus claire, même preuve.' };
  const afterComment = changedFindings(baseline.known, snapshot(commented));
  assert.equal(afterComment.events.length, 0);
  const resolved = { ...commented, version: 3, assessment: { status: 'resolution_proposed' } };
  const afterResolution = changedFindings(afterComment.known, snapshot(resolved));
  assert.equal(afterResolution.events.length, 0);
  const total = counts(snapshot(resolved));
  assert.equal(total.followUp, 1);
  assert.equal(total.resolutionProposed, 1);
  assert.equal(total.warnings, 0);
  assert.equal(changedFindings(afterResolution.known, snapshot({ ...resolved, assessment: { status: 'withdrawn' } })).events.length, 0);
});

test('plus de vingt constats restent disponibles et ne disparaissent pas des comptes legacy', () => {
  const items = Array.from({ length: 25 }, (_, i) => alert('a' + i, 'seen'));
  const normalized = normalizeSummary({ schema_version: 1, running: true, sessions: [session('claude', 'uuid', 's1', items)] });
  assert.equal(normalized.sessions[0].alerts.length, 25);
  assert.equal(counts(normalized).followUp, 25);
});
