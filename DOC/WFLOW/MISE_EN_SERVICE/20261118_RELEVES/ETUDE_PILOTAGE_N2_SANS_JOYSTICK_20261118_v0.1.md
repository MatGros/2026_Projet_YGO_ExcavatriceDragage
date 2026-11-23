# Étude — Pilotage MAINT_N2 sans joystick : état, options, recouvrement

TORC-CC10, exploitant oral 18/11. Lecture seule, pas de modification. Preuves `fichier:ligne`
vérifiées à l'instant (post-e75d1e08 + lot TOP non committé en cours).

## 1. Faits vérifiés

- **Le mode Boutons IHM est gâter par le sélecteur à 2 endroits** :
  `FB_WinchCmdArbitrationM1.st:68` (`IF NOT TglJoystickMaster THEN` → boutons,
  StepTgt = BtnStepTgt = palier max :74) et `PRG_03_Modes_Cycle.st:152-166`
  (WinchBothMotionActive : TglJoystickMaster TRUE → direction joystick ; FALSE →
  boutons BtnWinchBothAscent/Descent MIAU). `FB_WinchCmdArbitrationM2` homologue.
- **Le blocage N2 = réécriture inconditionnelle des permis** :
  `PRG_04_Treuils_Benne.st:1170-1182` — en MaintN2, SafeStop/permis M1/M2 sont
  ramenés à (PowerContactorEngaged_DI) et (TopPositionFree_DI + NOT TopHardStopLatched,
  :1178-1180 — déjà intégré par le lot TOP en cours). La cause 0 « perte com
  opérateur » (`FB_Safety_Winch.st:273-280`, alimente `CausesSafeStopActive` :535)
  n'est donc **pas bloquante en N2 pour M1/M2** → les essais d'aujourd'hui sans
  joystick sont cohérents avec le code.
- **M3 : cause 0 LIVE identique** (`FB_Safety_Translation.st:122-129`) + **Meca B armé
  si Heartbeat IHM perdu** (`:165-172` : tout mouvement réel sans commande validée →
  PowerCutOff latched) → M3 sans joystick = SafeStop en N2 (constat d'essai confirmé).
- **Asymétrie clé (fond du point d)** : M3 DROP sa commande si heartbeat IHM perdu
  (`:166`) ; **les treuils M1/M2 n'ont AUCUN équivalent** — `HeartbeatIhmOk` n'est
  consommé nulle part dans la chaîne de commande treuils (grep : seul FB_Safety_Winch:275
  pour la cause 0, FB_CycleSemiAuto:504 pour le cycle). Bouton IHM maintenu + IHM figée
  = mouvement qui continue jusqu'à l'AU (ou la limite).
- Doctrine confirmée dans les faits : joystick maître par défaut ; sélecteur IHM = repli
  volontaire de l'opérateur ; l'IHM figée = pas de N2.

## 2. Options (difficulté / risque, preuves)

- **(a) Rien côté automate (bouton IHM + note collègue sur la page N2)** —
  Difficulté 0. Couvre treuils M1/M2 en N2 (vérifié ci-dessus). Risques : M3 reste
  bloqué sans joystick (repli : AU → réamener M3 physiquement, ou bypass explicite) ;
  erreur humaine « le bouton ne marche pas » tant que le sélecteur n'est pas sur la
  bonne page (mitigé par la note collègue IHM).
- **(b) Repli AUTOMATIQUE vers les boutons quand le joystick est perdu en N2** —
  2 sites, ~4 lignes (FB_WinchCmdArbitrationM1/M2:68 + PRG_03:152). **Déconseillé** :
  bascule silencieuse d'autorité de commande — contraire à la doctrine fail-safe
  « l'organe maître est toujours un choix conscient » ; un retour de joystick branché à
  chaud redeviendrait maître pendant un mouvement (à-coup). Si l'exploitant la veut
  malgré tout : exiger message IHM prioritaire + pas de retour automatique (latch du
  changement jusqu'à Reset).
- **(c) Cause 0 limitée au maître actif (M1/M2/M3)** — FB_Safety_Winch:275,
  FB_Safety_Translation:124 (condition → `(TglJoystickMaster AND (joy offline/opp))
  OR (NOT TglJoystickMaster AND NOT HeartbeatIhmOk)` + câblage d'une entrée
  `CommMasterIsIhm`), 3 fichiers, difficulté moyenne. Bénéfice : M3 récupère le
  pilotage en N2 sans joystick + supervision comm restée sur l'organe réel.
  Risque : perte de la double supervision comm (joystick + IHM) — cohérent avec la
  doctrine SI le champ maître est affiché et loggé ; à faire dans le cadre du
  re-design « maître de communication » (même famille que T377-B : ne pas surveiller
  ce qui n'est pas l'organe actif), pas en micro-patch.
- **(d) IHM gelée + commande maintenue (M1/M2)** — recommandé comme SEULE brique
  au-delà de (a) : `FB_WinchCmdArbitrationM1/M2:68-87` — requêtes boutons gâter
  `AND HeartbeatIhmOk` (+ TON tolérance ~1-2 s pour les lenteurs IHM, à caler sur
  la periode réelle du heartbeat de `FB_Diag_IhmHeartbeat.st:62-66`). Difficulté
  faible (2 sites + 1 tempo), risque faible : à la perte IHM les requêtes tombent →
  mouvement s'arrête (le frein glisse fait le reste ; Meca A/MecaE restent en filet).
  Pour M3, déjà couvert par `FB_Safety_Translation:166` (Meca B).

## 3. Recouvrement avec le lot contact TOP (non committé à 11:49)

- Fichiers partagés : `PRG_04_Treuils_Benne.st` (permits :1178-1180 déjà modifié par
  le lot TOP), `PRG_06_Outputs.st` (VAR RETAIN latch), `FB_Safety_Winch.st`
  (TonTopEscalate :556 déjà dans le working tree), `FB_Hmi_BannerFormatter.st`.
- **Aucun chevauchement de fonction** avec (d) (arb treuils) ni avec (c) sauf le
  :275 de FB_Safety_Winch (même fichier, lignes disjointes, mais 1 seul écrivain à la fois).
- **Ordre recommandé** : (1) le lot TOP est commité EN PREMIER (T417-C le termine) ;
  (2) (d) en micro-lot juste après (2 fichiers arb, sans chevauchement) ; (3) note
  collègue IHM pour le sélecteur sur la page N2 ; (4) (c) = étude de refonte
  « maître de communication » à cadrer avec l'exploitant (comme T377-B), PAS en patch.
- (b) : non recommandé (doctrine), à ne faire que sur consigne expresse + garde-fous
  décrits.

## 4. Decision attendue de l'exploitant

1. (a) accepté tel quel ? (le collègue IHM porte la note page N2)
2. GO de principe pour (d) en micro-lot posté-TOP ?
3. (c) à cadrer ou à écarter ? (ma reco : cadrer plus tard, avec T377-B en lot commun
   « supervision selon le maître actif »)

## 5. Décisions exploitant du 18/11 (après-relecture) — clôture de l'étude

- **(d) PARQUÉ.** Question exploitant sur le bit de vie : « qui demande ça ? » —
  personne n'a de besoin exprimé (le cas vient du point 6 de T417-C). La décision
  du 2026-09-14 (pas de bit de vie IHM : LUA trop lourd, joystick = pilotage
  principal, risque jugé faible) RESTE valable pour la philosophie ; noter que le
  heartbeat simple existe déjà (FB_Diag_IhmHeartbeat, consommé par M3
  FB_Safety_Translation:166 et le cycle FB_CycleSemiAuto:504) — seul le chemin
  boutons-treuils N2 ne l'embarque pas. À réouvrir UNIQUEMENT sur incident réel
  (IHM figée pendant une commande treuil tenue).
- **Clarification opérateur** : pas besoin d'une « benne auto » en N2 — l'écran N2
  porte 6 commandes et la bascule SYNC (couplé) / BENNE (unitaire) suffit à tout
  couvrir ; l'auto reste réservé au joystick. Seul reste à faire : afficher le
  sélecteur sur la page N2 (note collègue IHM, déjà transmise).
- **Verdict final** : (a) VALIDÉ — rien côté automate ; (b) écarté ; (c) parqué pour
  cadrage ultérieur avec T377-B ; (d) parqué (cf. ci-dessus). Rien à implémenter
  de cette étude.
