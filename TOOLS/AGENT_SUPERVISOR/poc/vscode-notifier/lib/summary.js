'use strict';

const crypto = require('node:crypto');

function text(value, fallback = '') {
  return typeof value === 'string' ? value : fallback;
}

function normalizeSummary(value) {
  if (!value || typeof value !== 'object' || value.schema_version !== 1 || !Array.isArray(value.sessions)) {
    throw new Error('Résumé Agent Supervisor invalide (schéma 1 attendu).');
  }
  return {
    schema_version: 1,
    running: value.running === true,
    counts: normalizeCounts(value.counts),
    sessions: value.sessions.map((session) => {
      if (!session || typeof session !== 'object' || !text(session.id) || !text(session.platform) || !text(session.native_id)) {
        throw new Error('Identité de session invalide dans le résumé Agent Supervisor.');
      }
      const alerts = Array.isArray(session.alerts) ? session.alerts : [];
      return {
        id: text(session.id), platform: text(session.platform), native_id: text(session.native_id),
        alias: text(session.alias, session.platform), state: text(session.state, 'unknown'),
        analysis_state: text(session.analysis_state, 'unknown'),
        last_event: text(session.last_event), last_analysis: text(session.last_analysis),
        counts: normalizeCounts(session.counts),
        alerts: alerts.map((alert) => {
          if (!alert || typeof alert !== 'object' || !text(alert.id)) throw new Error('Constat invalide dans le résumé Agent Supervisor.');
          return {
            id: text(alert.id), reference: text(alert.reference || alert.event_ref || alert.short_id, text(alert.id).slice(0, 10)),
            version: Number.isInteger(alert.version) ? alert.version : 0,
            business_state: text(alert.business_state),
            assessment: alert.assessment && typeof alert.assessment === 'object' ? { status: text(alert.assessment.status, 'active') } : { status: 'active' },
            severity: text(alert.severity, 'warning'), reason: text(alert.reason, 'Point à vérifier.'),
            evidence_hash: text(alert.evidence_hash),
            category: text(alert.category), created_at: text(alert.created_at),
            last_occurrence: text(alert.last_occurrence), occurrences: Number.isFinite(alert.occurrences) ? alert.occurrences : 1,
            disposition: text(alert.disposition), acknowledged_at: text(alert.acknowledged_at),
            workflow_status: text(alert.workflow_status), delivery_status: text(alert.delivery_status)
          };
        })
      };
    })
  };
}

function normalizeCounts(value) {
  if (value === undefined || value === null) return null;
  const keys = ['unread', 'open', 'deferred', 'closed', 'follow_up', 'warnings', 'alarms', 'resolution_proposed'];
  if (!value || typeof value !== 'object' || keys.some((key) => !Number.isInteger(value[key]) || value[key] < 0)) {
    throw new Error('Compteurs Agent Supervisor invalides.');
  }
  return Object.fromEntries(keys.map((key) => [key, value[key]]));
}

function isUnread(alert) {
  return !alert.disposition || alert.disposition === 'new';
}

function businessState(alert) {
  if (['open', 'deferred', 'closed'].includes(alert.business_state)) return alert.business_state;
  if (['resolved', 'false_positive', 'ignored'].includes(alert.disposition)) return 'closed';
  return alert.disposition === 'deferred' ? 'deferred' : 'open';
}

function isFollowUp(alert) {
  return businessState(alert) !== 'closed';
}

function isProblem(alert) {
  return businessState(alert) === 'open' && (!alert.assessment || alert.assessment.status === 'active');
}

function projectedCounts(source, sessions) {
  if (source) return {
    sessions, unread: source.unread, followUp: source.follow_up, open: source.open,
    deferred: source.deferred, closed: source.closed, warnings: source.warnings,
    alarms: source.alarms, resolutionProposed: source.resolution_proposed, countsSource: 'service'
  };
  return null;
}

function sessionCounts(session) {
  const fromService = projectedCounts(session.counts, 1);
  if (fromService) return fromService;
  const result = { sessions: 1, unread: 0, followUp: 0, open: 0, deferred: 0, closed: 0,
    warnings: 0, alarms: 0, resolutionProposed: 0, countsSource: 'legacy' };
  for (const alert of session.alerts) {
    if (isUnread(alert)) result.unread += 1;
    result[businessState(alert)] += 1;
    if (!isFollowUp(alert)) continue;
    result.followUp += 1;
    if (alert.assessment?.status === 'resolution_proposed') result.resolutionProposed += 1;
    if (alert.assessment && alert.assessment.status !== 'active') continue;
    if (alert.severity === 'error' || alert.severity === 'alarm') result.alarms += 1;
    else result.warnings += 1;
  }
  return result;
}

function counts(summary) {
  const fromService = projectedCounts(summary.counts, summary.sessions.length);
  if (fromService) return fromService;
  const result = { sessions: summary.sessions.length, unread: 0, followUp: 0, open: 0, deferred: 0,
    closed: 0, warnings: 0, alarms: 0, resolutionProposed: 0, countsSource: 'service' };
  for (const session of summary.sessions) {
    const item = sessionCounts(session);
    for (const key of ['unread', 'followUp', 'open', 'deferred', 'closed', 'warnings', 'alarms', 'resolutionProposed']) result[key] += item[key];
    if (item.countsSource === 'legacy') result.countsSource = 'legacy';
  }
  return result;
}

function sessionIdentity(session) {
  return crypto.createHash('sha256')
    .update([session.id, session.platform, session.native_id].join('\0'))
    .digest('hex');
}

function alertIdentity(session, alert) {
  return crypto.createHash('sha256')
    .update([session.id, session.platform, session.native_id, alert.id].join('\0'))
    .digest('hex');
}

function alertSignature(alert) {
  return {
    problem: isProblem(alert), rank: alert.severity === 'error' || alert.severity === 'alarm' ? 2 : 1,
    evidence: text(alert.evidence_hash), version: alert.version || 0
  };
}

function changedFindings(previous, summary) {
  const isBaseline = previous === null;
  const known = new Map(Object.entries(previous || {}));
  const events = [];
  for (const session of summary.sessions) for (const alert of session.alerts) {
    const key = alertIdentity(session, alert);
    const next = alertSignature(alert);
    const before = known.get(key);
    // Text edits, comments, read status and resolution proposals are not new anomalies.
    const newEvidence = before && typeof before === 'object' && next.evidence && before.evidence !== next.evidence && next.rank >= before.rank;
    const escalated = before && typeof before === 'object' && next.rank > before.rank;
    if (next.problem && (!known.has(key) || escalated || newEvidence)) {
      events.push({ kind: known.has(key) ? 'updated' : 'new', session, alert });
    }
    known.set(key, next);
  }
  // Retain all known IDs: dropping an old entry would turn it into a new alert later.
  return { events: isBaseline ? [] : events, known: Object.fromEntries(known) };
}

function shortText(value, max = 120) {
  const clean = text(value).replace(/\s+/g, ' ').trim();
  return clean.length > max ? clean.slice(0, max - 1).trimEnd() + '…' : clean;
}

module.exports = { normalizeSummary, isUnread, isFollowUp, isProblem, businessState, sessionCounts, counts, sessionIdentity, alertIdentity, changedFindings, shortText };
