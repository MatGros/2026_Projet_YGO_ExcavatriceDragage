# Étude lecture seule — Acquitter « écart synchro M1/M2 » sans couper la synchro

Demande TORC-CC10, exploitant oral 18/11 ~08:55. Aucune écriture CODE/. Faits (fichier:ligne)
séparés des hypothèses. Snapshot de référence : `Snapshot_Troubleshooting_20261118_083602.csv`.

## 1. Quelle cause tient le défaut, et pourquoi le Reset ne purge pas

- Chaîne de mesure : `FB_SyncDeviation.st:75-101` — Warn si Delta > 3,0 m (seuils
  `:28-29` : Warn 3,0 / Critique 6,0), **latché** : purge uniquement `ResetEdge.Q AND NOT
  WarnActive` (:90) OU auto-purge si `SyncEnable=FALSE` (:86) — **c'est exactement le
  comportement observé : l'acquittement naturel passe par la synchro OFF**.
- Le Snapshot 08:36 : Delta -4,288 m (> 3,0) → Warn actif → cause 0 de
  `FB_WinchSync.st:171-173` → `Fault.Error` → `Idx302_SyncFaultActive`
  (`FB_TroubleshootingView.st:158`). Cause 2 (critique 6,0) NON atteinte (4,29 < 6,0).
- Pourquoi un Reset à l'arrêt ne purge pas : le Reset de `FB_FaultCore.st:41-43` efface
  les LATCHES, mais la cause 0 est **LIVE** (ré-mesurée chaque scan) — tant que
  Delta > 3,0 m, la cause se re-arme au scan suivant. Le message persiste par construction,
  pas par défaut.
- Les 3 sources de SafeStop affichées dans la trace (PRG_04:1947-1952, :1993-1999) :
  1. `SafeStopSourceSafety` = `instSafetyWinch*.SafeStop` — **TRUE au snapshot** ;
     cause réelle au snapshot : `Idx310_ErrorOperatorComm TRUE` (M1, snapshot :117) —
     **le joystick est démonté aujourd'hui** (changement de siège) → cause 0 « perte com
     opérateur » LIVE → SafeStop des deux treuils. Rien à voir avec la synchro.
  2. `SafeStopSourceSync` (PRG_04:1951-1952/:1997-1999) = discordance contacteurs (bit 1)
     OU `SyncActive AND SafeStopM2_Raw` (couplage croisé, PRG_04:1155-1158) — TRUE au
     snapshot par couplage (« dès qu'un treuil SafeStop, les 2 le sont »).
  3. `SafeStopSourceInput` FALSE au snapshot.
- Hypothèse à vérifier sur le levé d'aujourd'hui : **la valeur 4,288 m est suspecte**.
  Idx103_OffsetPos_M = 0 et benne ni ouverte ni fermée (snapshot :373-375, :384) →
  `ActiveOffsetM = 0` : si la référence benne est perdue (reset d'état au boot — le bug
  `FB_Bucket.st:416-419` listé au plan 6956366b §1), la synchro compare les positions
  BRUTES et 4,29 m = l'écart géométrique benne fermée d'origine → **faux positif
  structurel au boot sans offset benne restauré**. À confirmer : l'écart a-t-il suivi
  une glissade de frein réelle (historique positions) ?

## 2. Conception minimale — acquitter sans couper la synchro (chiffré)

- **O1 (recommandée, 0 ligne de code)** — procédure opérateur existante : restaurer
  l'offset benne (`ActiveOffsetM`) par le re-référencement benne IHM :
  la cause 0 est live → dès Delta ≤ 3,0 m le Warn retombe SEUL (:93 SyncDeviationWarn :=
  WarnActive OR WarnLatched ; la purge du latch attend le Reset, disponible car
  NOT WarnActive). À la synchro ON, sans couper. Vérifier simplement que le bouton
  re-référencement reste manœuvrable à l'arrêt malgré `SafeStopSourceSafety`
  (aujourd'hui bloqué par le joystick démonté — passer en MAINT_N2 si besoin).
- **O2 (1-2 lignes, si confirmation de faux positif au boot)** — gâter l'ENABLE de la
  surveillance par la validité de l'offset benne : au site d'appel `PRG_04:669-672`
  (Enable := SyncOperationPermit AND ActiveOffsetSettled AND ...) ajouter
  `AND (BucketIsOpen OR BucketIsClosed OU BucketReferenced)`. Effet : pas de Warn tant
  que la benne n'a pas d'état de référence, comme le fait déjà `ActiveOffsetSettled`.
  Faible risque : la synchro « ne voit » pas pendant la fenêtre non référencée —
  déjà le cas via ActiveOffsetSettled si celui-ci est FALSE ; à VÉRIFIER pourquoi il
  est TRUE avec Offset 0 (transitoire settle 2 s écoulé au boot?).
- **O3 (3-5 lignes, "acquittement à l'arrêt si écart statique")** — autoriser la purge du
  latch Warn à l'arrêt quand Delta stable > X s ET aucun mouvement : MODIFIER
  `FB_SyncDeviation.st:88-92` (clear latch si `WinchesMechanicallyStopped AND TON 5 s
  AND Delta inchangé ±0,1 m`). RISQUE : masque un vrai défaut physique (glissade
  lente) tant que la machine est à l'arrêt ; à accepter seulement avec ré-armement
  immédiat au moindre mouvement (WarnActive re-latche : déjà structurel, :88).
- **O4 (à écarter)** — acquitter même si l'écart dépasse le seuil critique (6,0) :
  jamais (anti-télescopage réel en SEMI_AUTO).

## 3. Effets de bord SEMI_AUTO

- La cause 0 (Warn) alimente : `SyncWarn` → LED IHM + `SyncMinorDeviation`
  (PRG_04:468) → soft-stop directionnel (:474-475) et `SyncFaultActive` checklist.
  L'écart critique (6,0) reste LE verrou dur des 2 treuils en cycle.
- Scénario à protéger : pendant SEMI_AUTO, un écart 3-6 m doit continuer à dégrader
  (clamp palier 1, soft-stop dirigeant) et alerter — **ne surtout pas auto-purger le Warn
  en mouvement** : O3 n'est acceptable qu'À L'ARRÊT + immobile (condition déjà dans le
  design : WinchBothMotionActive coupe les flags :474-475).
- `SyncOperationPermit` (gate source : PRG_04:669) coupe déjà la surveillance en homing/
  benne — un cycle SEMI_AUTO s'exécute synchro surveillée ; le changement O2/O3 n'ajoute
  aucun chemin de masquage en mouvement.

## 4. Conflits 6956366b / T377-B

- 6956366b ne touche ni FB_SyncDeviation ni FB_WinchSync (vérifié au --stat) ; il touche
  PRG_04 (zones distinctes : :1710/:1731 PowerCutOff, :967 BrakeForce) — AUCUN conflit
  de fichier avec O2/O3 ; seul l'ordre de commit importe (après le 6956366b pour éviter
  les rebases).
- T377-B : aucun chevauchement (FB_Encoder_Abs, FB_Safety_Winch cause 1, autotest AU) ;
  noter seulement que `PRG_04:673` Reset de la syncho est déjà `FaultMachineReset_IHM`
  (un seul canal de Reset, cohérent).
- Constat transversal pour T377-B : ce matin la synchro a « vu » 4,288 m avec offset 0 —
  le même famille de faux positif au boot que la « perte codeur » ; O2 est un parent
  logique du correctif B (tous deux = ne pas surveiller avec un datum non établi).

## 5. Proposition de mise en œuvre

1. Exploitant : confirmer la nature du 4,288 m (glissade réelle vs offset benne perdu)
   avec le relevé d'aujourd'hui avant de choisir O2 ou O3.
2. Si O2 : lot minimal PRG_04 (1 ligne) + test sim ; si O3 : FB_SyncDeviation (3-5 lignes)
   + test sim + gate équivalent. Implémentation prévue côté T417-C (AGY02) après ta
   validation, selon la consigne de phase.
