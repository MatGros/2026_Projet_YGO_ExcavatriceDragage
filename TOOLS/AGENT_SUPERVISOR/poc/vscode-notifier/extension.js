'use strict';

const { getSummary, validPort } = require('./lib/client');
const { normalizeSummary, counts, sessionCounts, isProblem, businessState, changedFindings, shortText } = require('./lib/summary');

const STATE_KEY = 'veilleur.known-findings.v2';
const BASE_URL = 'http://127.0.0.1';

function activate(context, vscodeApi) {
  const vscode = vscodeApi || require('vscode');
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 20);
  status.command = 'veilleur.open';
  status.text = '$(shield) Agent Supervisor · connexion…';
  status.tooltip = 'Lecture seule du résumé local d’Agent Supervisor. Aucun accès aux CLI.';
  status.show();
  context.subscriptions.push(status);

  let lastSummary = null;
  let lastSuccessAt = null;
  let serviceOnline = false;
  let inFlight = null;
  let timer = null;
  let disposed = false;
  let activePort = null;
  let known = null;

  function port() {
    return validPort(vscode.workspace.getConfiguration('veilleur').get('port', 8082));
  }

  function openTarget(sessionId, alertId) {
    const params = new URLSearchParams();
    if (sessionId) params.set('session', sessionId);
    if (alertId) params.set('alert', alertId);
    const query = params.toString();
    const url = `${BASE_URL}:${port()}/${query ? `?${query}` : ''}`;
    return vscode.env.openExternal(vscode.Uri.parse(url));
  }

  function markdownText(value, maxLength = 72) {
    return String(value || '').replace(/\s+/g, ' ').trim().slice(0, maxLength)
      .replace(/[\\`*_{}\[\]()#+.!|>~-]/g, '\\$&');
  }

  function buildTooltip(snapshot, online, error) {
    const lines = ['**🛡️ Agent Supervisor**'];
    if (snapshot) {
      const totals = counts(snapshot);
      const freshness = online ? '' : ' — DONNÉES PÉRIMÉES';
      lines.push(`**🔴 Alarm ${totals.alarms} · ⚠️ Warning ${totals.warnings}${freshness}**`);
      lines.push(`**${totals.followUp} à suivre** : ${totals.open} ouvert(s), ${totals.deferred} reporté(s). **${totals.unread} non lue(s).**`);
      lines.push(`**🟣 ${totals.resolutionProposed} résolution(s) proposée(s)** — avis du juge, clôture utilisateur distincte.`);
      if (totals.countsSource === 'legacy') lines.push('⚠️ Compatibilité : ancien service sans compteurs communs. Totaux calculés depuis les constats reçus ; mettre le service à jour.');
      const tracked = snapshot.sessions.map((session) => ({ session, counts: sessionCounts(session) }))
        .filter(({ counts: item }) => item.followUp > 0)
        .sort((a, b) => b.counts.alarms - a.counts.alarms || b.counts.warnings - a.counts.warnings || b.counts.followUp - a.counts.followUp);
      if (tracked.length) {
        lines.push('**Sessions avec constats à suivre**');
        for (const { session, counts: item } of tracked.slice(0, 5)) {
          const identity = `${markdownText(session.alias || session.platform, 48)} (${markdownText(session.platform, 20)})`;
          lines.push(`- **${identity}** — 🔴 ${item.alarms} Alarm · ⚠️ ${item.warnings} Warning · 🟣 ${item.resolutionProposed} résolution(s) proposée(s) · ${item.followUp} à suivre · ${markdownText(stateText(session), 80)}`);
          const finding = session.alerts.find(isProblem);
          if (finding) lines.push(`  Réf. **${markdownText(finding.reference, 24)}** — ${markdownText(shortText(finding.reason, 100), 100)}`);
        }
        if (tracked.length > 5) lines.push(`… et ${tracked.length - 5} autre(s) session(s) avec constats.`);
      } else if (online) lines.push('Aucun constat ouvert dans le dernier résumé reçu.');
      else lines.push('Le dernier résumé ne contenait aucun constat ouvert ; l’état actuel est inconnu.');
      lines.push('**À suivre** = ouverts + reportés, y compris résolution proposée en attente de décision. **Non lues** = pas encore marquées « Vu » ; lire ne clôture pas.');
    }
    lines.push('---');
    if (!online) {
      lines.push(`🔴 Service injoignable sur 127.0.0.1:${safePort()}. Les compteurs conservés sont périmés.`);
      if (error) lines.push(markdownText(error, 160));
    } else {
      lines.push(`${snapshot.running ? '🟢 Collecte active' : '⏸️ Collecte arrêtée'} · toutes les ${pollInterval()} s. Le vert décrit la collecte, pas l’absence de problème.`);
    }
    if (lastSuccessAt) lines.push(`${online ? 'Dernière lecture' : 'Dernières données reçues'} : ${lastSuccessAt.toLocaleTimeString('fr-FR')}.`);
    if (!snapshot) lines.push('Aucun état reçu. Vérifie que le service Agent Supervisor est démarré.');
    lines.push('Lecture seule : aucun accès aux CLI ni appel de modèle. Clique pour consulter une session ou un constat ; aucun statut n’est modifié.');
    const tooltip = new vscode.MarkdownString(lines.join('\n\n'));
    tooltip.isTrusted = false;
    return tooltip;
  }

  function stateText(session) {
    const collection = ({ active: 'lecture active', paused: 'en pause', waiting: 'en attente',
      source_missing: 'source absente', ambiguous: 'source ambiguë', error: 'erreur de lecture' })[session.state] || session.state;
    const analysis = ({ analyzing: 'analyse', queued: 'analyse en file', waiting: 'analyse en attente',
      no_alert: 'aucun nouveau constat', alert: 'constat récent', unavailable: 'analyse indisponible',
      uncertain: 'résultat incertain', context_required: 'mission requise', paused: 'analyse en pause' })[session.analysis_state] || session.analysis_state;
    return `${collection} · ${analysis}`;
  }

  function updateStatus(online, error) {
    serviceOnline = online;
    const snapshot = lastSummary;
    const totals = snapshot ? counts(snapshot) : { sessions: 0, unread: 0, followUp: 0, alarms: 0 };
    if (!online) {
      status.text = snapshot
        ? `$(warning) Agent Supervisor · ${totals.followUp} à suivre · ${totals.unread} non lues · périmé`
        : '$(warning) Agent Supervisor · indisponible';
      status.tooltip = buildTooltip(snapshot, false, error);
      return;
    }
    const icon = totals.alarms ? '$(error)' : totals.warnings ? '$(warning)' : totals.resolutionProposed ? '$(question)' : snapshot.running ? '$(shield)' : '$(debug-pause)';
    status.text = `${icon} Agent Supervisor · ${totals.followUp} à suivre · ${totals.unread} non lues`;
    status.accessibilityInformation = { label: `Agent Supervisor : ${totals.alarms} Alarm, ${totals.warnings} Warning, ${totals.resolutionProposed} résolutions proposées, ${totals.unread} non lues.` };
    status.tooltip = buildTooltip(snapshot, true);
  }

  function safePort() {
    try { return port(); } catch (_) { return 'invalide'; }
  }

  function pollInterval() {
    const configured = Number(vscode.workspace.getConfiguration('veilleur').get('pollSeconds', 8));
    return Number.isInteger(configured) ? Math.min(60, Math.max(5, configured)) : 8;
  }

  function notifyFindings(events) {
    if (!events.length) return;
    const alarmCount = events.filter(({ alert }) => alert.severity === 'error' || alert.severity === 'alarm').length;
    const severity = alarmCount ? 'alarm' : 'warning';
    const first = events[0];
    const target = events.find(({ alert }) => alert.severity === 'error' || alert.severity === 'alarm') || first;
    const change = events.some((event) => event.kind === 'new') ? 'Nouveau' : 'Mis à jour';
    const title = severity === 'alarm' ? 'Agent Supervisor · 🔴 Alarm' : 'Agent Supervisor · ⚠️ Warning';
    const description = events.length === 1
      ? `${change} · ${first.session.alias} — ${shortText(first.alert.reason, 130)}`
      : `${events.length} constats ${change.toLowerCase()} · ${alarmCount} alarme(s), ${events.length - alarmCount} avertissement(s). Ouvre Agent Supervisor pour les consulter.`;
    const message = `${title} · ${description}`;
    const action = events.length === 1 ? 'Ouvrir le constat' : alarmCount ? 'Ouvrir l’alarme prioritaire' : 'Ouvrir le premier constat';
    const notification = severity === 'alarm'
      ? vscode.window.showErrorMessage(message, action)
      : vscode.window.showWarningMessage(message, action);
    Promise.resolve(notification).then((choice) => {
      if (choice === action) return openTarget(target.session.id, target.alert.id);
      return undefined;
    }).catch(() => {});
  }

  async function refresh() {
    if (disposed) return false;
    if (inFlight) return inFlight;
    inFlight = (async () => {
      try {
        const servicePort = port();
        if (activePort !== servicePort) {
          const stored = context.globalState.get(`${STATE_KEY}.${servicePort}`);
          known = stored && typeof stored === 'object' && !Array.isArray(stored) ? stored : null;
          activePort = servicePort;
          lastSummary = null;
          lastSuccessAt = null;
        }
        const raw = await getSummary(servicePort);
        const summary = normalizeSummary(raw);
        lastSummary = summary;
        lastSuccessAt = new Date();
        updateStatus(true);
        if (known === null) {
          known = changedFindings({}, summary).known;
          await context.globalState.update(`${STATE_KEY}.${servicePort}`, known);
        } else {
          const changes = changedFindings(known, summary);
          known = changes.known;
          await context.globalState.update(`${STATE_KEY}.${servicePort}`, known);
          if (vscode.workspace.getConfiguration('veilleur').get('notifications', true)) {
            notifyFindings(changes.events);
          }
        }
        return true;
      } catch (error) {
        updateStatus(false, error.message);
        return false;
      } finally {
        inFlight = null;
      }
    })();
    return inFlight;
  }

  async function openSessions() {
    if (!lastSummary) {
      await refresh();
      if (!lastSummary) {
        await vscode.window.showWarningMessage(`Agent Supervisor indisponible sur 127.0.0.1:${safePort()}. Démarre le service puis actualise.`);
        return;
      }
    }
    const stale = !serviceOnline;
    const picks = lastSummary.sessions.map((session) => {
      const total = sessionCounts(session);
      return {
        label: `${session.alias} · ${session.platform}`,
        description: `${stateText(session)}${stale ? ' · DONNÉES PÉRIMÉES' : ''}`,
        detail: `🔴 ${total.alarms} Alarm · ⚠️ ${total.warnings} Warning · 🟣 ${total.resolutionProposed} résolutions proposées · ${total.followUp} à suivre · ${total.unread} non lue(s)`,
        session
      };
    });
    if (!picks.length) {
      const choice = await vscode.window.showQuickPick([{ label: 'Ouvrir Agent Supervisor', description: 'Aucune session affectée' }], { placeHolder: 'Aucune session suivie' });
      if (choice) await openTarget();
      return;
    }
    const placeholder = stale ? 'Dernier état connu — données périmées' : lastSummary.running ? 'Choisir une session suivie' : 'Collecte arrêtée — dernier état reçu';
    const selected = await vscode.window.showQuickPick(picks, { placeHolder: placeholder });
    if (!selected) return;
    const alerts = selected.session.alerts;
    if (!alerts.length) return openTarget(selected.session.id);
    const alertItems = alerts.slice().reverse().map((alert) => ({
      label: `${businessState(alert) === 'closed' ? '✅ Closed' : alert.assessment?.status === 'resolution_proposed' ? '🟣 Resolution proposed' : alert.assessment?.status === 'withdrawn' ? '⚪ Withdrawn' : alert.assessment?.status === 'uncertain' ? '❔ Uncertain' : alert.severity === 'error' || alert.severity === 'alarm' ? '🔴 Alarm' : '⚠️ Warning'} · ${shortText(alert.reason, 100)}`,
      description: `${alert.reference} · v${alert.version || 1} · ${alert.business_state || alert.disposition || 'new'} · ${alert.assessment?.status || 'active'}`,
      detail: 'Ouvre Agent Supervisor pour lire la citation et le contexte complets.',
      alert
    }));
    const alertChoice = await vscode.window.showQuickPick(alertItems, { placeHolder: `${selected.session.alias} · ouvrir le constat dans Agent Supervisor` });
    if (alertChoice) await openTarget(selected.session.id, alertChoice.alert.id);
  }

  const openCommand = vscode.commands.registerCommand('veilleur.open', openSessions);
  const refreshCommand = vscode.commands.registerCommand('veilleur.refresh', refresh);
  const settingsCommand = vscode.commands.registerCommand('veilleur.settings', () =>
    vscode.commands.executeCommand('workbench.action.openSettings', 'veilleur'));
  const testCommand = vscode.commands.registerCommand('veilleur.testNotification', async () => {
    if (!lastSummary) await refresh();
    const targetSession = lastSummary?.sessions.find((session) => session.alerts.length > 0);
    const targetAlert = targetSession?.alerts.at(-1);
    if (!targetSession || !targetAlert) {
      await vscode.window.showWarningMessage('TEST — notification Agent Supervisor. Aucun constat réel disponible pour tester le clic ; aucune donnée n’a été modifiée.');
      return;
    }
    const action = 'Ouvrir le constat réel';
    const title = targetAlert.severity === 'error' || targetAlert.severity === 'alarm'
      ? 'TEST — Agent Supervisor · 🔴 Alarm'
      : 'TEST — Agent Supervisor · ⚠️ Warning';
    const message = `${title} · ${markdownText(targetSession.alias, 48)} — ${shortText(targetAlert.reason, 120)}`;
    const notification = targetAlert.severity === 'error' || targetAlert.severity === 'alarm'
      ? vscode.window.showErrorMessage(message, action)
      : vscode.window.showWarningMessage(message, action);
    Promise.resolve(notification).then((choice) => {
      if (choice === action) return openTarget(targetSession.id, targetAlert.id);
      return undefined;
    }).catch(() => {});
  });
  context.subscriptions.push(openCommand, refreshCommand, settingsCommand, testCommand);

  function schedule() {
    if (timer) clearInterval(timer);
    const interval = pollInterval();
    timer = setInterval(() => { void refresh(); }, interval * 1000);
  }
  const configListener = vscode.workspace.onDidChangeConfiguration((event) => {
    if (event.affectsConfiguration('veilleur')) {
      schedule();
      void refresh();
    }
  });
  const pollDisposable = { dispose() { disposed = true; if (timer) clearInterval(timer); } };
  context.subscriptions.push(configListener, pollDisposable);
  schedule();
  void refresh();
}

function deactivate() {}

module.exports = { activate, deactivate };
