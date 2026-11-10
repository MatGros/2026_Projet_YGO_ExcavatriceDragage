# Review indépendante — T429 lot 2 (lecture seule)

## Verdict borné au lot

**PASS partiel avec réserves.** Sur le DIFF réel fourni, les objectifs mesurables du lot sont couverts par des preuves exécutées pour le backend et l'UI (node 16/16, pytest 46/46). Les limites déclarées (modèle réel, Windows, hunks préexistants) bornent la portée mais ne changent pas le verdict du lot. **Ce verdict ne vaut pas validation Veilleur global.**

## Observation vs inférence (discriminant)

- **Observé (preuves fournies par le responsable, non ré-exécutables ici) :**
  - pytest 46/46 ; node 16/16.
  - HTTP `/review` : 80 constats sur ≤5 pages, max 27 951 octets, projection 1,073 ms max.
  - Hunks 1–3 `JUDGE_SETTINGS` / `audit_interval` : préexistants et hors lot (filtrage fait).
- **Observé dans le diff (ce que je peux vérifier textuellement) :**
  - `system_test` exclu du contexte juge dans `_collect_loop` (`if a.get("category") == "system_test": continue`) et dans le chat (`status["alerts"]` filtré, `referenced_alerts` filtré).
  - `_queue_agent_turn` refuse `system_test` → pas de envoi agent.
  - Expiration portée dans `snapshot`, `notification_snapshot`, `review_snapshot`, `_collect_loop` → l'expiration survit au redémarrage pendant arrêt (le test le confirme côté logique).
  - Extensions : `notifyFindings` émet un toast individuel pour `system_test` avec `openTarget(session, alert)`, puis les filtre du lot agrégé ; premier poll aussi notifié ; `notifications=false` **n'empêche pas** le toast `system_test`.
- **Inférence (non prouvée par les preuves fournies) :**
  - Le « vrai service/collecte » du test juge appelle un callable enregistrant le payload avec réponse synthétique — donc **la preuve d'exclusion est sur le payload envoyé**, pas sur le comportement du modèle réel. C'est exactement la limite annoncée, correctement bornée.
  - UI Windows non observée → comportement `showWarningMessage` et `openTarget` sous Windows : non prouvé.

## Bugs réels (max 3), triés par sévérité

### 1. Pagination `review_snapshot` par offset — **risque réel de doublon/omission**

`review_snapshot` filtre `business_state != "closed"`, mais l'expiration peut résoudre un `system_test` entre deux pages, et tout changement d'état (`acknowledge`, `comment`, nouvelle occurrence, nouveau constat) décale les indices. L'appelant qui pagine par `offset` peut :
- **omettre** un constat si un item avant l'offset devient `closed` entre pages (décalage vers la gauche) ;
- **dupliquer** un constat si un item précédent est ré-ouvert / nouvellement inséré.

Preuve par lecture du diff : rien ne fige un curseur ni un `snapshot_id`. Le champ `next_offset` est un simple index mutable. Non prouvé par test : le test HTTP fourni est **mono-thread et sans mutation concurrente** entre pages.

**Test discriminant** : exposer `review_snapshot(sid, offset)` puis, entre page 1 (`next_offset=k`) et page 2, fermer/expirer `opened[k-1]` ; vérifier côté client que la page 2 contient encore `opened[k-1]`. Attendu : **échec** aujourd'hui (omission).

**Correction minimale** : ajouter un curseur `after` stable dans `review_snapshot` — `(created_at, alert_id)` triés — et renvoyer `next_cursor` au lieu de `next_offset` ; paginer par `WHERE (created_at, id) > (cursor_at, cursor_id)` dans l'ordre. Coût : faible, pas de changement de pagination côté client autre que le nom du champ.

### 2. Toast `system_test` ignore `veilleur.notifications`

Le filtre devient : `system_test` **ou** (`notifications=on`). Conséquence : avec `notifications=false`, un `system_test` produit quand même un toast. C'est peut-être intentionnel (test explicite déclenché par l'utilisateur), mais **le diff ne le dit pas** et le test ne le prouve pas (il ne teste que le cas `notifications` par défaut).

**Test discriminant** : `notifications=false`, injecter `system_test`, assert `ui.warnings.length === 0` **ou** `=== 1` selon le choix contractuel — actuellement absent, donc la spécification est implicite.

**Recommandation** : si intentionnel, écrire un test qui verrouille « toast `system_test` toujours émis, indépendant de `notifications` » ; sinon, filtrer aussi dans la branche premier poll et seconde branche.

### 3. Rejeu du toast `system_test` au second poll de la **même** occurrence après `resolved → new`

Non observé sur le diff, mais : `changedFindings(known, summary)` ne remonte un événement qu'au changement `disposition`. Un `system_test` qui redevient `new` (réémission via un nouveau `test_notification` avec le **même id** — impossible ici, uuid) ou après expiration puis relance… ce n'est pas un vrai scénario avec uuid frais. **Risque écarté** par lecture (uuid à chaque `test_notification`). À documenter comme « non-bug vérifié ».

> Je m'arrête à 3, dont un seul est un vrai risque backend (#1). #2 est une décision implicite, pas un bug prouvé. #3 écarté.

## Vérifications ciblées du DIFF (observé → conforme objectif)

| Objectif | Statut | Preuve |
|---|---|---|
| Pollution `system_test` dans juge exclue | ✅ observé (diff) + test passe avec callable | `_collect_loop` filtre `a` prior, `notices`, `referenced_alerts`, `status["alerts"]` |
| Persistance + expiration après restart (à l'arrêt) | ✅ observé (diff) + test `test_lot2_notification_expiry_survives_restart_while_stopped` | `_expire_test_notifications` dans `snapshot`/`notification_snapshot`/`_collect_loop` |
| Envoi agent `system_test` interdit | ✅ observé (diff) | `_queue_agent_turn` lève |
| Toast unique + clic ciblé | ✅ observé (diff) + node 16/16 | `openTarget(session.id, alert.id)`, pas de doublon au poll suivant |
| HTTP `<30 000 octets`, `<50 ms` | ✅ observé (preuve fournie) | 27 951 octets max, 1,073 ms max |
| Hunks `settings`/`audit_interval` hors lot | ✅ filtrés | Ne pas les citer dans le verdict du lot |

## Limites résiduelles (à retenir, pas à corriger dans ce lot)

- Modèle réel non exercé : exclusion juge prouvée **par payload**, pas par comportement modèle.
- UI Windows non observée : `showWarningMessage` et `openTarget` sous Windows non prouvés.
- Concurrence `review_snapshot` non testée : bug #1 non couvert par la suite actuelle.

## Décision recommandée

- **Lot 2 : accepté** sur le périmètre déclaré, avec la correction minimale #1 (curseur stable) ou un **ticket différé** explicite + test discriminant à ajouter. #2 à trancher contractuellement (documenter le choix, idéalement par un test).
- **Pas de commit ni de push** par cette review : je n'ai aucun outil et le diff n'est pas relu contre la branche réelle par mes soins. Codex responsable de l'intégration et du diff final.
- **Ne pas étendre ce verdict** au Veilleur global.

## Contre-revue apres correction, 2026-11-10

1. **Verdict correction seule : PASS** — la révision est calculée avant pagination et `offset>0` sans révision (ou révision périmée) lève `ValueError("Revue modifiee…")`, donc après fermeture en page 1 la page 2 échoue explicitement au lieu d’omettre silencieusement : correctif conforme à l’objectif.
2. **Preuve notifications=false** — `test_lot2_review_real_http_loaded_session` reste un test explicite (`test_notification` + assertion `counts['closed']==1`, `total==80`), pas un mock implicite ; conforme.
3. **Pagination stable** — `next_offset` pointe sur l’index dans `opened`, bornes `28000` respectées, test vérifie unicité (`len(seen)==len(set(seen))==80`) sans doublon ni omission.
4. **Budget/réseau** — `max(sizes)<30000`, `max(timings)<50`, `max(network_timings)<50` reflètent les mesures annoncées (27991 o, ≤0.848 ms, ≤42.623 ms) ; test cohérent avec le code.
5. **Effet de bord test** — la mutation `disposition='resolved'` puis restauration `'new'` puis `evidence` énorme est confinée au `TemporaryDirectory` et `svc.close()`; pas de fuite hors périmètre.
6. **Limites explicites** — aucun test modèle réel ni GUI Windows : hors périmètre de cette revue, ne remet pas en cause le correctif.
7. **Pas d’ajout d’exigences** — la revue se limite au défaut signalé (pagination offset instable après changement de révision) ; rien d’autre n’est requis.
8. **Verdict : correction acceptée.**
