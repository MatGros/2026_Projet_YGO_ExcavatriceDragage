# 💓 M3-A04 — Conception tests Heartbeat IHM↔PLC

> **Statut :** 🟡 Spec de lot validée pour reconstruction du test.  
> **Source de vérité implémentation :** `TASK_CONTEXT_M3-A04.yaml` + ce document.  
> **Références de contrat :** P3 reset/front & Safety par métier · P4 Cycle `ERROR_HOLD` · P9 Méca B treuil · P11 Méca B M3 · P14 §7 tables + stimuli amont.

## 1. Règles non négociables

- 🧪 Simulation uniquement ; gate = `SimulationModeActive=TRUE` + aucun retour stimulé déclaré réel.
- ⚡ Stimuli seulement amont : toggle IHM, retours contacteurs/frein/variateur simulés, commandes IHM de test.
- 🚫 Jamais écrire `SafeStop`, `PowerCutOff`, `Error`, `ErrorId` ou une sortie calculée.
- 📋 Suite **table-driven** : `FB_TestSequencer`, tables Step/Check/Case/Invariant, banques `Probe*`, `CASE ActiveStimulusId` état-complet.
- 🔁 Chaque TC a Setup + Teardown. Tout échec passe par Teardown ; les overrides sont relâchés structurellement.
- 🛑 Reconnexion Heartbeat ne doit jamais être confondue avec un Reset ou un ordre mouvement.

## 2. Stimuli amont requis

| Id | Stimulus | Injection / justification |
|---|---|---|
| S0 | Neutre | Tous overrides FALSE ; aucun reset ni commande mouvement. |
| S1 | Liaison IHM saine | Override test actif ; toggle IHM à 500 ms. |
| S2 | Perte IHM | Override test actif ; toggle figé. |
| S3 | Reset conscient | S1 + front `FaultMachineReset` et `Cycle.CmdReset`; jamais automatique. |
| S4 | M1 arrêt non confirmé | S2 + **nouvel override amont dédié** des retours M1 `FwdRevSpeedFeedbackOff`/`BrakeFeedback`; ne pas réutiliser `OverrideContactorFalse` (il force `EmergencyStopOk`). |
| S5 | M2 arrêt non confirmé | Même principe M2. |
| S6 | M3 arrêt non confirmé | S2 + `OverrideM3BrakeStuckOpen=TRUE` (retour frein amont). |

## 3. Matrice traçable

| TC | Critère source | Setup / stimulus | Checks PLC attendus | Temps |
|---|---|---|---|---|
| `TC-HEARTBEAT-01_SAFETY_BOOT` | Boot sans IHM bloque la machine jusqu’au front post-boot | S2 au lancement | `HeartbeatIhmOk=FALSE`; bit0 M1/M2/M3 ; `SafeStop` M1/M2/M3 ; aucun `PowerCutOff` sans indice arrêt non confirmé | ≥2 s |
| `TC-HEARTBEAT-02_SAFETY_HEALTHY` | Toggle IHM 500 ms, diagnostic sain | S1 après reset explicite S3 | `HeartbeatIhmOk=TRUE`; timeout FALSE; bit0 Heartbeat absent. Les défauts hors périmètre ne sont pas des préconditions du TC. | front + ≤2 s |
| `TC-HEARTBEAT-03_SAFETY_TIMEOUT_CYCLE` | Perte 2 s : SafeStop métiers + cycle repli sûr | S1, demander `SEMI_AUTO` **sans `CmdStart`, sans homme-mort**, puis S2 | bit0 M1/M2/M3 ; `SafeStop` 3 métiers ; Cycle bit5 + `ERROR_HOLD` | timeout 2 s ± 1 MainTask |
| `TC-HEARTBEAT-04_SAFETY_CONFIRMED_STOP` | Pas de PowerCutOff si arrêt confirmé | S2, retours arrêt sains | Pas de `PowerCutOff` pendant fenêtre Méca B ; bit0/SafeStop restent présents | 3 s + marge task |
| `TC-HEARTBEAT-05_SAFETY_MECA_B_M1_M2` | P9 Méca B : contacteurs **et** frein doivent confirmer arrêt ; sinon escalade | S4 puis S5, runs séparés | Méca B bit8 du treuil concerné + `PowerCutOff` global ; autre treuil observé sans attribution erronée | 3 s + marge task |
| `TC-HEARTBEAT-06_SAFETY_MECA_B_M3` | P11 Méca B : frein desserré / variateur Operation après perte IHM → escalade | S6 | M3 bit4 + `PowerCutOff` global | 3 s + marge task |
| `TC-HEARTBEAT-07_COMPLIANCE_RECONNECT` | Reconnexion : reset manuel + nouvel ordre obligatoire | Après TC-03, S1 sans S3 | `HeartbeatIhmOk=TRUE`, mais bit0 et Cycle bit5 restent ; aucun mouvement/ordre généré | après premier front |
| `TC-HEARTBEAT-08_COMPLIANCE_RESET` | Cause disparue + Reset front seulement | Après TC-07, S3 | bits Heartbeat effacés et Cycle bit5 effacé ; test ne génère aucun ordre mouvement | après Reset |

## 4. Décisions de conception du test

- Les TC 01→04/07→08 sont dans une suite Heartbeat dédiée.
- TC 05 M1/M2 et TC 06 M3 peuvent être des cas ciblés de cette même suite, mais chaque cas est exécutable individuellement via `RunCase`.
- Les cas qui déclenchent `PowerCutOff` se terminent par Teardown neutre, puis exigent la procédure simulation existante de réarmement ; ils ne chaînent jamais vers un autre TC.
- La suite ne vérifie que les bits/signaux attribuables au Heartbeat. Un défaut homing/capteur hors périmètre est rapporté par un invariant de précondition, jamais interprété comme un échec Heartbeat.

## 5. Critère de sortie avant ST test

- [x] Matrice critère → stimulus → check → temps validée.
- [ ] Nouveau plan ST détaillé (interfaces/overrides/steps/checks) validé.
- [ ] Ancien `FB_HeartbeatValidation` ad-hoc retiré/remplacé : il ne satisfait pas P14 §7.
