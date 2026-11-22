# T377 — Information à l'agent lot terrain (relais via exploitant)

→ RELAIS : agent du lot terrain M3 / Cycle Semi-Auto / MAINT_N2 inconditionnel
(transmis par l'exploitant — pas de contact direct session à session).

## 1. Décisions tranchées (GO exploitant 2026-11-16)

- **D1 = C** : amendement AC3 — pas d'escalade `PowerCutOff` routée en MAINT_N2.
  Le FB homing expose l'évènement contact capteur haut (cause non-latching C8 +
  sortie dédiée + instruction IHM). Dossier de risque résiduel : AU physique
  indépendant + butée mécanique + **survol réel à mesurer en essai site**.
  Rappel terrain : `PRG_04:1632/1653` masquent déjà `PowerCutOff` en MAINT_N2 et
  `PRG_06:355-356` bypasse le contacteur sync — l'AC3 amendé se borne à refléter
  ce que la chaîne applique réellement, avec compensation documentée.
- Contact capteur = hybride sans FAIL (latch + dégagement, retour HX2, zéro écriture).
- D5 = bande HX4 asymétrique +0,10 / -0,10 m ; garde d'écart M1/M2 ajoutée en HX2
  (vos SyncBlocks neutralisés en MAINT_N2 rendent cette cohérence nécessaire dans le FB).

## 2. Ton mini-lot 2 lignes : validé (réponses aux 4 questions déjà transmises)

1. Aucun lancement automatique du cycle (toutes entrées IHM-gated ; `BootReady`
   inutilisé = alerte ouverte, pas bloquant).
2. Homing unitaire MAINT_N2 sans cycle : aucun verrou bloquant (statuts dérivés,
   SEMI_AUTO gated par axe).
3. Aucune autre prise T377 en partiel recommandée.
4. Mini-lot 100 % compatible T377 et gates (consigne : geste « 3 appuis homme-mort »
   disparaît — validation devient bouton IHM, à répéter aux opérateurs).

## 3. Périmètre T377 (pour éviter les collisions avec ton lot non committé)

Ton lot : `PRG_03`, `PRG_04`, `PRG_05`, `PRG_06`, `FB_Modes`, `FB_CycleSemiAuto`,
`FB_Translation*`, `ST_CycleCmd`, `ST_TranslationFinalInterlockRequest`.
T377 : `E_MachineHomingTxState`, `ST_fbMachineHomingCycle_Cfg`, `FB_CycleMachineHoming`,
`PRG_02_Acquisition` (publication diagnostic — **ton mini-lot touche aussi PRG_02:609** :
un seul écrivain à la fois), `PRG_07`, `ST_HomingChecklist`, `FB_TroubleshootingView`,
`GVL_Troubleshooting`, `troubleshooting_variables.txt`.
Interdits T377 : `FB_Safety_Winch`, `FB_Encoder*`, `FB_WinchSync`, `Device.export`.

## 4. Obligation d'information (doctrine T427 — Signaler)

Tu peux challenger chaque point de ce rapport au besoin, à tout moment.
**Obligation corrélative** : tout constat qui touche T377 (collision fichier, effet de
bord d'une de tes neutralisations MAINT_N2 sur le homing, écart doctrine/code) doit
être signalé **dès apparition** — jamais en fin de lot, jamais silencieusement.
Canal : copie datée dans `DOC/WFLOW/TASKS/T377_HOMING_MANUEL_SANS_CONTACT_TOP/`
(journal ou fiche dédiée) + mention à l'exploitant. Échéance de signalement :
sans délai constaté. Un non-constat n'est pas un passage silencieux : une seule
ligne « rien à signaler au 2026-11-16 » au moment du merge suffit pour clore.

## 5. Ordonnancement convenu

1er test site M3 / MAINT_N2 en homing **unitaire** (hors cycle) → intégration T377
au bundle suivant → re-test homing seul. Précondition écrite : le 1er essai reste
possible sans le refactor T377 (vérifié : homing unitaire n'a pas de verrou cycle).
