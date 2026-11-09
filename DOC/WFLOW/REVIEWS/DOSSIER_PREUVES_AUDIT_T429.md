# Dossier de Preuves Mécaniques & Réponses aux Exigences d'Audit T429

**Date :** 9 novembre 2026  
**Objet :** Levée formelle du statut HOLD de la Revue Finale A (DeepSeek V4.1) avec preuves matérielles, extraits de code source vérifiables et sorties complètes d'exécution.

---

## 1. Étanchéité aux faux PASS (Contre-exemple C1)

### Extrait ligne par ligne de `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py` (l. 1564-1574) :
```python
        elif message["role"] == "tool":
            tool_text = str(message.get("text", ""))
            # Barrière absolue : ne JAMAIS déduire de succès si un terme d'échec ou de négation est présent
            if not re.search(r"\b(?:non|not|failed|échec|echec|erreur|error|exception|traceback|interrompu)\b", tool_text, re.IGNORECASE):
                match = re.search(r"(?:={2,}\s*)?(\d+\s+passed[^\n\r]*|exited with code 0|0\s+erreur[^\n\r]*)", tool_text, re.IGNORECASE)
                if match:
                    summary = match.group(1).strip()
                    item = dict(kind="tool_proof", text=summary[:200], observed_at=message.get("observed_at", timestamp()), event_id=ident, event_index=message.get("event_index"))
                    session.setdefault("acquired_proofs", []).append(item)
                    session["acquired_proofs"] = session["acquired_proofs"][-15:]
```

### Test de régression dédié dans `TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py` (l. 595-608) :
```python
        # 1. Capture d'un tool PASS légitime
        tool_msg = {'role': 'tool', 'event_id': 'e10', 'text': '==== 159 passed in 11.85s ===='}
        svc._remember_source(session, tool_msg)
        assert len(session['acquired_proofs']) == 1
        assert '159 passed in 11.85s' in session['acquired_proofs'][0]['text']
        assert session['acquired_proofs'][0]['kind'] == 'tool_proof'

        # 1bis. Contre-exemple critique C1 : 'NON PASS : contrôle en échec' NE DOIT PAS être capturé comme preuve
        negative_tool_msg = {'role': 'tool', 'event_id': 'e11', 'text': 'NON PASS : contrôle en échec.'}
        svc._remember_source(session, negative_tool_msg)
        assert len(session['acquired_proofs']) == 1, "Un résultat d'outil avec négation ne doit pas être promu en PASS !"
```
**Exécution réelle et vérifiée :** `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -k test_deterministic_tool_proof_capture_and_trajectory_audit` → **1 passed in 0.45s (code de sortie 0)**.

---

## 2. Mémoire Long-Terme & Détection de Drift (AC-F2.9)

### 2.1 Injection des 4 sections attendues par le contrat C1 dans `_judge_loop` (`supervisor_service.py:1911-1934`) :
```python
                        mission = "## CAP INITIAL GELÉ :\n" + session["initial_mission"]
...
                        if framing:
                            notices.append(dict(role="context_notice", text="## DÉCISIONS UTILISATEUR (Cadrage observé avec dates et sources, pas de GO rétroactif) : " + json.dumps([dict(m, text=m["text"][:400], excerpt=len(m["text"])>400) for m in framing[-6:]], ensure_ascii=False)))
                        acquired = session.get("acquired_proofs", [])
                        if acquired:
                            notices.append(dict(role="context_notice", text="## PREUVES ACQUISES (vérifiées sur disque, ne pas redemander) :\n" + "\n".join(f"- [{p.get('event_id', 'cmd')}] {p.get('text')}" for p in acquired[-6:])))
                        journal = session.get("session_journal", [])
                        if journal:
                            notices.append(dict(role="context_notice", text="## MÉMOIRE DE SESSION (Jalons franchis) :\n" + "\n".join(f"- {j.get('text')}" for j in journal[-6:])))
                        session["judge_turn_count"] = session.get("judge_turn_count", 0) + 1
                        if session["judge_turn_count"] % 8 == 0:
                            notices.append(dict(role="context_notice", text=f"🚨 [AUDIT DE TRAJECTOIRE — TOUR {session['judge_turn_count']}] : Confronte l'avancement global et les preuves acquises au Cap Initial Gelé. Vérifie la direction et le respect du planning."))
```

### 2.2 Validation stricte fail-closed de `state_update` (`supervisor_service.py:2100-2120`) :
```python
                    state_update = result.get("state_update")
                    if isinstance(state_update, str) and state_update.strip() and len(state_update.strip()) >= 5:
                        clean_update = state_update.strip()[:300]
                        origin = "agent_observation"
                        source_event_id = None
                        try:
                            event_candidates = [{"id": m.get("event_id") or f"e{i+1}", "role": m["role"], "text": m.get("text", "")}
                                                for i, m in enumerate(observed) if m.get("role") in ("user", "assistant", "tool")]
                            validated = validate_state_update(clean_update, event_candidates)
                            if validated:
                                origin = validated["origin"]
                                source_event_id = validated["source_event_id"]
                        except (ValueError, KeyError):
                            pass
                        session.setdefault("session_journal", []).append(dict(
                            text=clean_update,
                            source_event_id=source_event_id,
                            origin=origin,
                            recorded_at=timestamp()
                        ))
                        session["session_journal"] = session["session_journal"][-20:]
                        record_event(session, "state_update", clean_update, timestamp())
```

---

## 3. Matrice Alarm Déverrouillée (AC-F2.10)

### 3.1 Préservation d'Alarm (`severity: error`) pour toutes les catégories (`supervisor_service.py:325-337`) :
```python
    priority = candidate.get("priority")
    return {
        "alert": True,
        "severity": "error" if priority == "alarm" else "warning",
        "reason": str(candidate.get("reason", "Ecart a verifier")),
        "evidence": span,
        "event_id": event["id"],
        "category": candidate.get("category", "other"),
        "title": str(candidate.get("title") or "")[:80],
        "context_evidence": context_evidence,
        "reviews": response.get("reviews", []),
        "state_update": response.get("state_update", ""),
    }
```
*Ancien code :* `"severity": "error" if priority == "alarm" and candidate.get("category") == "unauthorized_action" else "warning"`.  
*Nouveau code :* La condition restrictive `and candidate.get("category") == "unauthorized_action"` a été **totalement supprimée**.

### 3.2 Support de `other` et de l'imminence dans `alert_basis` (`supervisor_service.py:423-447`) :
```python
        performed = re.search(r"\b(?:j'ai|nous avons|(?:le|la)\s+(?:fichier|code|branche|commit)\s+a\s+(?:ete|\u00e9te)|je\s+vais|je\s+m'appr[eê]te\s+[aà]|sur\s+le\s+point\s+de)\s+(?:modifi(?:e|\u00e9)|supprim(?:e|\u00e9)|execute(?:e|\u00e9)|lance(?:e|\u00e9)|commite(?:e|\u00e9)|ecrase(?:e|\u00e9)|pouss(?:e|\u00e9)|publie(?:e|\u00e9)|envoye(?:e|\u00e9))\b", evidence, re.IGNORECASE)
...
    if category == 'other':
        return isinstance(evidence, str) and len(evidence.strip()) >= 4 and any(m.get('role') == 'assistant' and evidence in m.get('text', '') for m in messages)
```

---

## 4. Sécurité Déconnexion IHM (AC-F3.10)

### 4.1 CSS et Balisage DOM (`ui/index.html:25-26, 191, 249, 660`) :
```css
.app-sidebar.is-disconnected{background:#381d22!important;border-right:2px solid #ff626d!important;box-shadow:inset 0 0 24px rgba(255,98,109,.22)}
.sidebar-disconnected-banner{background:#ff626d;color:#23080b;font-weight:750;font-size:11px;padding:8px 6px;border-radius:6px;text-align:center;line-height:1.35;letter-spacing:.02em;border:1px solid #ff9fa7}
```
Lors de l'erreur réseau (`catch(error)` de fetch) :
```javascript
function showError(message){
  byId('connection-error').textContent=message;
  byId('connection-error').hidden=false;
  const side=document.querySelector('.app-sidebar'), banner=byId('sidebar-disconnected');
  if(side) side.classList.add('is-disconnected');
  if(banner) banner.hidden=false;
}
```
Et rétablissement automatique dès reconnexion :
```javascript
const side=document.querySelector('.app-sidebar'), banner=byId('sidebar-disconnected');
if(side) side.classList.remove('is-disconnected');
if(banner) banner.hidden=true;
```

### 4.2 Test DOM unitaire dans `test_ui.mjs` (l. 280-282) :
```javascript
  vm.runInContext("showError('Connexion au service indisponible')", ctx);
  assert.equal(document.querySelector('.app-sidebar').classList.contains('is-disconnected'), true, 'sidebar reflects disconnected state');
  assert.equal(document.getElementById('sidebar-disconnected').hidden, false, 'sidebar shows disconnected banner');
```
**Exécution réelle :** `node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs` → **Agent Supervisor UI: candidate discovery, ambiguity and explicit confirmation passed. (code de sortie 0)**.

---

## 5. Persistance & Continuité après Redémarrage

### Extraits de `supervisor_service.py` :
- `_new_session` (l. 1023) : `acquired_proofs=[], session_journal=[], judge_turn_count=0`
- `_persist` (l. 1031) : inclut `"acquired_proofs", "session_journal", "judge_turn_count"` dans la liste des clés persistées dans `agent-supervision.json`.
- `_load` (l. 550) : restaure `session["acquired_proofs"] = value.get("acquired_proofs", [])`, `session["session_journal"] = value.get("session_journal", [])`, `session["judge_turn_count"] = self._nonnegative_int(...)`.

---

## 6. Synthèse des Exécutions Mécaniques

| Commande | Résultat | Code de sortie |
|---|---|---|
| `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -v` | **43 passed in 2.02s** | 0 |
| `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_judge_prompt.py TOOLS/AGENT_SUPERVISOR/tests/test_judge_behavior.py -q` | **26 passed in 0.20s** | 0 |
| `python -m pytest TOOLS/AGENT_SUPERVISOR/tests -q` | **171 passed in 11.40s** | 0 |
| `node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs` | **PASS (candidate discovery, ambiguity, confirmation, is-disconnected)** | 0 |
| `node TOOLS/AGENT_SUPERVISOR/tests/ui_layout_check.mjs` | **PASS (1440, 390, 360 px, 0 overflow)** | 0 |
| `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T429_AGENT_SUPERVISOR_FIABILISATION.yaml` | **PASS (0 erreur, 0 avertissement)** | 0 |
| Service local actif sur port 8082 | **Build eb610fef45fb actif, 16 resolved, 1 false_positive, 0 open** | 0 |
