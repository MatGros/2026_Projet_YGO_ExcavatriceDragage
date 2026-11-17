🟡 **ADVISORY** — Design v0.3 globalement cohérent, mais 4 points doivent être corrigés avant implémentation (blocage silencieux HX1A, HX5 sans sémantique, persistance de latch à la coupure puissance, ambiguïté HomeReq HX3).
Impact : en l'état, un opérateur peut se retrouver bloqué sans message (HX1A, HX5) ou face à un preset accidentel (HX3 sur MachineHomed déjà TRUE).
Note de session : pas d'accès à `AGENTS.md`/`AGENT_OUTPUT_STANDARD.md` dans cet environnement — restitution calée sur le gabarit fourni ; je ne bloque que sur les points ci-dessous. Horodatage machine non disponible (pas d'horloge exposée) — simulation statique, aucune exécution.

---

## Niveau 1 — invariants vérifiés

1. `[✅ PASS]` Chaque état HX0→HX7 a au moins une condition d'entrée identifiée et au moins une sortie (sauf HX5 → voir anomalie).
2. `[✅ PASS]` Les chemins de faute globaux (ModeLost, MotionOutOfPhase, TransactionAbort, Enable FALSE, Reset conscient) convergent correctement vers HX7 ou HX0.
3. `[❌ FAIL]` Toutes les sorties ne sont pas couvertes : HX1A (arrêt mécanique non confirmé) et HX5 (neutre+arrêt) n'ont pas d'échappatoire/message → blocage silencieux possible.
4. `[❌ FAIL]` Politique de purge des latches (contact HX2A, refus HX2, C8) non définie à la coupure puissance / Enable FALSE → risque de latch résiduel bloquant après retour HX0.
5. `[❌ FAIL]` HX3 : sémantique « HomeReq = preset » vs « HomeReq = mouvement de homing » non tranchée → gating homme-mort/permis INDEFINI si mouvement.
6. `[❌ FAIL]` Preset accidentel : re-entrée HX0→...→HX3 alors que MachineHomed TRUE ré-applique 8,50 m sans vérifier la position réelle.
7. `[✅ PASS]` Latch contact HX2A et latch refus HX2 sont purgés sur Reset (conforme §4).
8. `[❌ FAIL]` ClimbTimer 300 s contournable : reset du budget au relâchement → montée infinie par tranches.
9. `[❌ FAIL]` Messages IHM de refus manquants sur gestes parasites (Start en MAINT_N1, manche non neutre, BtnValidation sur MachineHomed TRUE, montée tentée en HX2A, BtnHome unitaire pendant cycle).
10. `[❌ FAIL]` HX7 : sortie conditionnée à Reset **MAINT_N2** ; si mode retombe en N1, aucun échappatoire ni message → INDEFINI.

---

## Niveau 1 bis — Grille état → entrée → sorties → verdict (format bloc, pas de tableau)

**HX0_REPOS**
- Entrées : Reset (depuis tout état, purge §4), Enable FALSE (gate §7), HX6 (commit), HX7 (Reset). Sortie : (BtnStart OU BtnValidation) + MAINT_N2 + manche neutre → HX1 ; garde MachineHomed TRUE → BtnValidation n'relance pas, seul BtnStart.
- Verdict : 🟢 OP (logique), 🟡 messagerie incomplète.
- Anomalies : Start/Validation en MAINT_N1 refusé sans message ; manche non neutre refusé sans message ; BtnValidation sur MachineHomed TRUE = rien + aucun message ; **re-entrée avec MachineHomed TRUE ré-applique preset 8,50 (risque position)**.

**HX1_BUCKET_PREPARE**
- Entrée : HX0 validé. Sorties : montée benne (manche tiré + homme-mort, palier 1) ; BtnConfirmHomingBucket + neutre → HX1A ; MotionOutOfPhase/ModeLost → HX7.
- Verdict : 🟢 OP.
- Anomalies : confirmation acceptée **sans vérifier capteur de position benne** (confirm à l'aveugle) ; pas de reprise explicite après relâchement homme-mort ; pas de timeout (acceptable manuel, mais à noter).

**HX1A_COUPLING_INTERLOCK**
- Entrée : HX1 confirmé. Sorties : WinchSel forcé 0, settle 300 ms, **arrêt mécanique requis**, neutre → HX2.
- Verdict : 🔴 BLOQUE-SANS-MSG (potentiel).
- Anomalie : si `WinchesMechanicallyStopped` jamais confirmé → aucun timeout, aucun message, aucun échappatoire. Changement sélecteur ignoré silencieusement.

**HX2_APPROCHE_MANUELLE**
- Entrée : HX1A. Sorties : montée couplée si 5 gardes ; CONTACT → latch + HX2A ; validation (front BtnValidation + 5 gardes) → HX3 ; refus → latch refus + compteur + message ; ClimbTimer 300 s → cause + message ; relâchement hm → arrêt propre.
- Verdict : 🟢 OP (gardes solides), 🟡 latch/timer.
- Anomalies : latch contact persiste-t-il à la coupure puissance (→ HX0) ? si oui, montée bloquée sans raison au retour ; ClimbTimer reset au relâchement = contournable ; martelage BtnValidation + purge « au prochain appui » = fenêtre d'acceptation accidentelle à surveiller.

**HX2A_DEGAGEMENT**
- Entrée : HX2 sur contact. Sorties : montée INTERDITE (latch), descente seule (hm + manche poussé, palier 1) ; capteur libre + arrêt + neutre → HX2 ; Reset conscient → HX0 (C8 latche, message persistant).
- Verdict : 🟢 OP avec 🟡 feedback.
- Anomalies : montée tentée = pas de mouvement mais **message « descente uniquement » non spécifié explicitement** ; C8 persiste-t-il à la coupure puissance ? ; pas de timeout de dégagement (voulu) mais aucune guidance après blocage prolongé.

**HX3_REFERENCE_RESTORE**
- Entrée : HX2 validé. Sorties : UN SEUL HomeReq M1+M2 à l'arrêt (preset 8,50 m) ; BothAxesHomed → HX4 ; timeout 60 s → HX7.
- Verdict : 🟡 INDEFINI (sémantique HomeReq).
- Anomalies : « HomeReq » = preset (aucun mouvement) ou homing (mouvement) ? si mouvement, gating homme-mort/permis absent → sécurité ; abort MotionOutOfPhase est cité en HX4 mais **pas explicitement en HX3** ; message timeout non spécifié.

**HX4_REFERENCE_VERIFY**
- Entrée : HX3. Sorties : BothAxesHomed + arrêt + neutre + cohérence 1,0 m + bande 8,50 ±0,10 → HX5 ; échec → UNE ré-émission HomeReq puis HX7 si re-échec ; mouvement hors phase → abort → HX7.
- Verdict : 🟢 OP.
- Anomalies : message de ré-émission/échec non spécifié ; pendant la grâce 3 s (mouvement hors phase) aucun message.

**HX5_DEGAGEMENT**
- Entrée : HX4. Sorties : neutre + arrêt requis → HX6. **Aucune action propre définie.**
- Verdict : 🔴 INDEFINI.
- Anomalie : état sans action ni message ; si neutre/arrêt non remplis → attente silencieuse indéfinie ; l'objet du « dégagement » est ambigu (résidu benne ?).

**HX6_COMMIT**
- Entrée : HX5. Sorties : commit benne atomique + MachineHomed := TRUE → HX0.
- Verdict : 🟢 OP, 🟡 robustesse.
- Anomalies : aucun chemin d'échec du commit (→ resterait bloqué en HX6) ; « atomique » non prouvé côté PLC (coupure en cours de commit = incohérence benne/MachineHomed à valider).

**HX7_ATTENTE_RESET**
- Entrée : timeout HX3, re-échec HX4, MotionOutOfPhase, ModeLost, TransactionAbort. Sortie : Reset conscient MAINT_N2 → HX0.
- Verdict : 🟢 OP, 🟡 échappatoire unique.
- Anomalie : si le mode retombe en MAINT_N1 pendant HX7 → impossible de Reset (exige N2), pas de message expliquant la condition.

**Transitions globales**
- Coupure puissance / Enable FALSE : pas logique → HX0 correct ; **mais latches résiduels = INDEFINI**.
- Sortie de mode pendant cycle → HX7 : 🟢 OP.
- Mouvement treuil hors phase (grâce 3 s) → TransactionAbort → HX7 : 🟢 OP (message de grâce manquant).
- BtnHome unitaire en cycle (interlock CycleRunning) : 🟢 refus prévu, 🟡 message non spécifié.

---

## Liste finale — cas d'entrée/sortie MANQUANTS

1. HX0 : sortie si Start/Validation en MAINT_N1 (refus + message).
2. HX0 : sortie si manche non neutre au Start (refus + message).
3. HX0 : comportement BtnValidation sur MachineHomed TRUE (message « déjà référencé, utiliser Start »).
4. HX0→HX3 : gate « ne pas ré-appliquer preset 8,50 si MachineHomed TRUE ».
5. HX1 : vérification capteur benne avant acceptation BtnConfirmHomingBucket ; reprise après relâchement hm.
6. HX1A : échappatoire + message si arrêt mécanique non confirmé (timeout).
7. HX2 : purge latch contact sur Enable FALSE / coupure puissance.
8. HX2 : politique anti-contournement ClimbTimer (compteur cumulatif, pas reset par relâchement).
9. HX2A : message explicite « montée interdite, descendre » sur tentative de montée.
10. HX2A : purge C8 à la coupure puissance ; guidance après blocage prolongé.
11. HX3 : tranché preset vs homing ; gating homme-mort si mouvement ; abort hors phase explicite ; message timeout.
12. HX5 : définition d'action/objet + message + timeout.
13. HX6 : chemin d'échec du commit + preuve d'atomicité.
14. HX7 : sortie si mode retombé en N1 + message de condition de Reset.
15. Global : message unifié pour refus BtnHome unitaire (interlock CycleRunning) dans tous les états cycle.

## Top 5 corrections (actionnables)

1. **Centraliser la messagerie de refus** : un canal unique couvrant Start en N1, manche non neutre, BtnValidation sur MachineHomed TRUE, montée en HX2A, BtnHome interlock, Reset HX7 exigeant N2. Sans cela = BLOQUE-SANS-MSG sur au moins 4 transitions.
2. **Corriger le preset accidentel** : conditionner HX3/HX4 à `MachineHomed = FALSE`, ou vérifier la position réelle avant d'écrire 8,50 m ; si MachineHomed TRUE, court-circuiter vers HX5/HX6.
3. **Définir la politique de latch** : contact (HX2A), refus (HX2) et C8 **purgés** sur Enable FALSE / coupure puissance (entrée HX0 par gate §7), en plus du Reset — sinon blocage résiduel invisible au retour.
4. **Rendre HX5 et HX1A non-pièges** : donner un objet/action à HX5 (ou le fusionner avec HX4/HX6), et ajouter timeout+message sur HX1A (arrêt mécanique) et HX5 (neutre+arrêt).
5. **Durcir HX3** : trancher HomeReq = preset (no-motion) ou homing (motion → homme-mort/permis requis), ajouter abort hors phase explicite, et ajouter le chemin d'échec de commit HX6 + vérifier l'atomicité côté PLC.

**Risques résiduels** : ClimbTimer contournable et martelage BtnValidation ne sont pas bloquants mais réduisent la garantie de sécurité — à traiter en même temps que la correction n°1 (compteur cumulatif + debounce).