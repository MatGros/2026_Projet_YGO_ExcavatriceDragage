# T377 — Brouillon ST des diff (dossier de tâche — JAMAIS collé tel quel dans CODE/)

> v0.2 · 2026-11-16 · CC03. Brouillon de cadrage, base du brief d'implémentation.
> Aucune écriture CODE/ avant feu vert. **Décisions tranchées (GO exploitant 2026-11-16) :**
> **D1=C** — amendement AC3 : pas d'escalade PowerCutOff routée en MAINT_N2 ; le FB expose
> l'évènement (cause C8 non-latching + sortie dédiée + instruction IHM) ; dossier de risque
> résiduel = AU physique indépendant + butée + survol à mesurer en essai site.
> D2=A (dégagement sous joystick) · D3=renommages · contact = hybride sans FAIL (arbitrage
> A/B/C) · D5 = bande HX4 asymétrique +0,10/-0,10 · + garde d'écart M1/M2 en approche
> (challenge B). Arbitrages challenges indépendants intégrés (_REDMODEL_A/_B_20261116).

## 1. `G_CYCLE/_TYPES/E_MachineHomingTxState.st`

```iecst
// Renommés (valeurs 0..8 inchangées) + nouveau 9 en fin :
HX2_CLIMB_COUPLED        := 3,  (* Approche manuelle couplee M1+M2 palier 1, validation operateur *)
HX3_REFERENCE_RESTORE    := 4,  (* Prise de reference conjointe a l'arret, preset 8,50 m *)
HX4_REFERENCE_VERIFY     := 5,  (* Verification preset lu : bande asymetrique autour de 8,50 m *)
HX2A_CONTACT_CLEARANCE   := 9,  (* Capteur haut touche : degagement impose, aucune reference *)
```

## 2. `G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st`

- Supp : `CfgStabilizationMinM/MaxM` (7,50/9,50 — ne contrôle plus rien, commentaires déjà périmés).
- Ajout :
```iecst
CfgVerifyTolHighM : REAL := 0.10;  // HX4 : marge AU-DESSUS de la cible 8,50 m (m) — depassement vers capteur, critique
CfgVerifyTolLowM  : REAL := 0.10;  // HX4 : marge EN DESSOUS de la cible 8,50 m (m)
```
- Supp : `CfgTimeoutFlyingHoming` (Mode A supprimé). Gardes conservées : `CfgTimeoutClimb` (texte à reformuler), `CfgTimeoutHomeAxes`.

## 3. `G_CYCLE/FB_CycleMachineHoming.st` — le cœur du lot

### 3.1 Variables (VAR_OUTPUT + VAR)

```iecst
// VAR_OUTPUT — diagnostic
TopContactLatched            : BOOL;   // <-- [DIAG] Contact capteur haut latche jusqu'au degagement (T377)
LastValidationRefused        : BOOL;   // <-- [DIAG] Dernier BtnValidation refuse par les gardes HX2 (T377)

// VAR — nouveaux
TopContactLatchedLoc         : BOOL;   // . [LOC] Latch contact capteur (miroir VAR_OUTPUT)
ValidationGuardsOk           : BOOL;   // . [LOC] Les 5 gardes de validation HX2 vraies au meme scan
VerifyOk                     : BOOL;   // . [LOC] HX4 : verification reference conforme
ReEmitHomeReqDone            : BOOL;   // . [LOC] Re-emission unique HX4 deja faite
ValidationRefusCount         : UINT := 0; // . [LOC] Compteur de refus de validation (IHM)

// Suppressions (0 consommateur externe verifie : grep HomingModeBActive/FlyingHomingTimer/
// StandstillHomeReqDone = FB seul) :
//   HomingModeBActive, FlyingHomingTimer, StandstillHomeReqDone
//   + leurs RAZ (§1, §4, §7)

// CONSTANT
CST_CauseTopContact          : INT := 8; // Contact capteur haut pendant l'approche (NON latching)
```

### 3.2 §3/§4 — latch et purge

- §4 Purge sur `ResetEdge.Q` : ajouter `TopContactLatchedLoc := FALSE;` (Reset conscient en MAINT_N2) **et** `LastValidationRefused := FALSE;` (purge du latch de refus — challenge 2026-11-16 : purge aussi au changement de mode/init si constaté en test).
- v0.4 (arbitrage IN/OUT 2026-11-17) : purge identique des 2 latches dans le **gate §7** (Enable FALSE / coupure puissance) — état HX0 propre au retour sans latch fantôme.
- Note anti-blocage (challenge B inv 13) : HX2A n'a PAS de timeout par design — l'opérateur sort toujours par Reset conscient (§4 purge → HX0) ou par dégagement manuel ; aucun état du grafcet n'est sans sortie.
- Livrable traçabilité (challenge A Q3, challenge B files) : **matrice de mapping sortie→consommateur** dans la restitution (`file:line` pour CmdWinchM1/M2, CmdWinchSelect, HomeReq, preset, causes) — les fichiers preuves (PRG_03/PRG_04, FB_Safety_Winch) sont des **dépendances vérifiées**, pas des diffs.
- §4bis Forcage de step : `LIMIT(0, CfgForceStepTarget, 9)` + case `9: SeqStep := HX2A_CONTACT_CLEARANCE;`
- Cause 8 :
```iecst
instCauses[CST_CauseTopContact].Active   := TopContactLatchedLoc;
instCauses[CST_CauseTopContact].Latching := FALSE; // se vide des que la machine est degagee
instCauses[CST_CauseTopContact].Texte    := 'Capteur haut touche - descendre pour degager puis re-approcher';
```
⚠️ Point de vérification à l'implémentation : effets de bord de `Fault.Latched` (socle FB_FaultCore) pendant HX2A — la cause est non-latching et Active retombe au dégagement, mais la fenêtre pendant laquelle `Fault.Latched=TRUE` ne doit pas déclencher d'abandon extérieur non voulu. Test dédié au passage (scenario 3 SimBench).

### 3.3 §2 — conditions nommées

```iecst
ValidationGuardsOk := ModeIsMaint2
                      AND WinchesMechanicallyStopped
                      AND NOT TopPositionSensor      // polarite homing : TRUE = contact
                      AND NOT JoystickDeflected
                      AND NOT TopContactLatchedLoc;
```
- `MotionOutOfPhase` : ajouter HX2A aux steps tolérés en fenêtre de grâce (`SettleGraceTimer` §2 : ajouter HX2A à la liste des steps d'arrêt/dégagement — déceler la déceleration de descente).

### 3.4 §8 — HX2 (approche manuelle)

```iecst
E_MachineHomingTxState.HX2_CLIMB_COUPLED:
    // T377 : approche MANUELLE. Le capteur TOP n'est plus declencheur.
    // Message IHM : "approche a vue — proche capteur haut".
    CmdWinchSelect := 0;

    // Garde d'ecart M1/M2 pendant l'approche (challenge B 2026-11-16) : SyncBlocks
    // neutralises en MAINT_N2 (PRG_04:501-514) => la cohesion est assuree ICI.
    ClimbSkewFault := (ABS(CablePosM1 - CablePosM2) > CoherenceLimitM);

    // Montee : permis operateur + couple + capteur libre + pas de contact latche
    // + coherence M1/M2 au preset courant
    IF ClimbPermit AND (JoystickWinchSelectArbitrated = 0)
       AND NOT TopPositionSensor AND NOT TopContactLatchedLoc
       AND NOT ClimbSkewFault THEN
        CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqAscent  := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
        CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqAscent  := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
    END_IF;

    IF TopPositionSensor AND NOT TopContactLatchedLoc THEN
        // Contact fortuit : AUCUN HomeReq. Stop (garde ci-dessus + AscentPermit
        // securite existant), latch, degagement impose. PAS de HX7 (arbitrage 2026-11-16).
        TopContactLatchedLoc := TRUE;
        SeqStep              := E_MachineHomingTxState.HX2A_CONTACT_CLEARANCE;
    ELSIF TransactionAbort THEN
        MachineHomingFailed := TRUE;
        SeqStep             := E_MachineHomingTxState.HX7_FAILED;
    ELSIF BtnValidationEdge.Q THEN
        IF ValidationGuardsOk THEN
            PendingClose := PendingClose;          // inchange
            HomeReqDone  := FALSE;                  // l'emission unique se fera en HX3, a l'arret
            SeqStep      := E_MachineHomingTxState.HX3_REFERENCE_RESTORE;
        ELSE
            // Refus explicite : aucun ecrit, aucun mouvement.
            // LATCH jusqu'au prochain appui de validation ou Reset (correction challenge 2026-11-16 :
            // TRUE/FALSE au meme scan serait rate par l'IHM). Le compteur cumule : 1 seul increment
            // par front BtnValidationEdge (pas de double comptage d'appui maintenu).
            LastValidationRefused := TRUE;
            ValidationRefusCount  := ValidationRefusCount + 1;
        END_IF;
    END_IF;
```

Entrée du cycle (§8 HX0) — garde anti-déclenchement accidentel (jeu joystick, constat
opérateur 2026-11-16) : lancer `StartEdge` **ou** `BtnValidationEdge` seulement si
`NOT JoystickDeflected` au front (le cycle démarre par la fermeture benne : un homme-mort
appuyé avec le manche défléchi est un geste de déplacement, pas un geste de lancement) :
```iecst
IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 AND NOT JoystickDeflected THEN
```

### 3.5 §8 — HX2A (nouveau)

```iecst
E_MachineHomingTxState.HX2A_CONTACT_CLEARANCE:
    // Degagement impose : AUCUN HomeReq, aucun preset. Montee interdite par le latch.
    CmdWinchSelect := 0;

    // Descente possible UNIQUEMENT sous joystick + homme-mort, palier 1 (D2=A)
    IF DescendPermit AND (JoystickWinchSelectArbitrated = 0) THEN
        CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqDescend := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
        CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqDescend := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
    END_IF;

    IF ModeLostDuringCycle OR AxisHomingError THEN
        MachineHomingFailed := TRUE;
        SeqStep             := E_MachineHomingTxState.HX7_FAILED;
    ELSIF NOT TopPositionSensor AND WinchesMechanicallyStopped AND NOT JoystickDeflected THEN
        // Degage et arrete : retour HX2 pour une NOUVELLE approche.
        // PAS de retour direct HX3 : position apres depassement != 8,50 m, un preset
        // ecrirait un datum biaise ("plus haut que d'habitude", exploitant 2026-11-16).
        TopContactLatchedLoc := FALSE;
        SeqStep              := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
    END_IF;
```

### 3.6 §8 — HX3 (reference à l'arrêt, une seule émission)

```iecst
E_MachineHomingTxState.HX3_REFERENCE_RESTORE:
    // La machine est deja a l'arret par construction (validation exige arret mecanique).
    // Mode A "au vol" supprime, repli Mode B supprime : UN SEUL HomeReq impulse a l'arret.
    CmdWinchSelect := 0;

    IF WinchesMechanicallyStopped AND NOT HomeReqDone THEN
        M1Demand.HomeReq := TRUE;
        M2Demand.HomeReq := TRUE;
        HomeReqDone      := TRUE;
    END_IF;

    IF TransactionAbort OR HomeAxesTimedOut THEN
        MachineHomingFailed := TRUE;
        SeqStep             := E_MachineHomingTxState.HX7_FAILED;
    ELSIF BothAxesHomed THEN
        SeqStep := E_MachineHomingTxState.HX4_REFERENCE_VERIFY;
    END_IF;
```

### 3.7 §8 — HX4 (vérification, bande asymétrique D5)

```iecst
E_MachineHomingTxState.HX4_REFERENCE_VERIFY:
    // La fenetre d'inertie [7,50..9,50] ne controle plus rien : preset impose 8,50 m.
    // Remplacée par la verification du preset LU + coherence + bande asymetrique.
    CmdWinchSelect := 0;
    SeenNeutral := NOT JoystickDeflected;

    VerifyOk := BothAxesHomed
                AND WinchesMechanicallyStopped AND SeenNeutral
                AND (ABS(CablePosM1 - CablePosM2) <= CoherenceLimitM)
                AND (CablePosM1 <= (Cfg.CfgTopHomingTarget_M + Cfg.CfgVerifyTolHighM))
                AND (CablePosM1 >= (Cfg.CfgTopHomingTarget_M - Cfg.CfgVerifyTolLowM))
                AND (CablePosM2 <= (Cfg.CfgTopHomingTarget_M + Cfg.CfgVerifyTolHighM))
                AND (CablePosM2 >= (Cfg.CfgTopHomingTarget_M - Cfg.CfgVerifyTolLowM));
    // NB : la reference ECRITE reste exactement CfgTopHomingTarget_M (preset).
    // La bande ne rejette qu'une validation faite au mauvais endroit.

    IF ModeLostDuringCycle OR AxisHomingError THEN
        MachineHomingFailed := TRUE;
        SeqStep             := E_MachineHomingTxState.HX7_FAILED;
    ELSIF VerifyOk THEN
        SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
    ELSIF WinchesMechanicallyStopped AND SeenNeutral AND NOT VerifyOk THEN
        IF NOT ReEmitHomeReqDone THEN
            // UNE SEULE re-emission a l'arret, puis echec (fini les 3 retries par HX1).
            M1Demand.HomeReq  := TRUE;
            M2Demand.HomeReq  := TRUE;
            ReEmitHomeReqDone := TRUE;
        ELSE
            MachineHomingFailed := TRUE;
            SeqStep             := E_MachineHomingTxState.HX7_FAILED;
        END_IF;
    END_IF;
```
- `RetryCount` : conservé mais inutilisé en HX4 (raisons C8/CST à re-libeller à l'impl).
- `ReEmitHomeReqDone` : raz en §4 (purge) et à l'entrée HX4.

### 3.8 §9 — sélection couplage + verrou M3

Ajouter `(SeqStep = HX2A_CONTACT_CLEARANCE)` à la liste `CmdWinchSelect := 0` (couplage
maintenu pendant tout le dégagement — cohérence M1/M2).

### 3.9 §10 — mapping IHM obligatoire (canal MachineHomingInstruction / bandeau)

```iecst
// HX2 — approche a vue (avant capteur)
'MHX2 - Approche a vue : tirer JOY palier 1 - VALIDER avant capteur haut'
// HX2A — degagement
'HX2A - Capteur haut touche : descendre JOY palier 1 pour degager'
// HX3
'HX3 - Reference conjointe a l'arret : attente preset 8,50 m'
// HX4
'HX4 - Verif reference : bande 8,50 m +0.10/-0.10'
```
- v0.4 (arbitrage IN/OUT 17/11) — messages d'inopérance ajoutés au mapping :
  `BtnValidation` ignoré si MachineHomed (« deja reference - utiliser Start ») ·
  `BtnHome` unitaire refusé si CycleRunning · garde skew KO HX2 (montée coupée sans
  raison = message) · WinchSel verrouillé par le cycle · contenu HX2A porte « DESCENTE SEULE ».
- v0.4 — sémantiques décidées : `ClimbTimedOut` = abort → HX7 + cause dédiée (budget =
  montée CONTINUE ; 300 s à 0,4 m/s = 120 m > course 58,5 m → expiration = anomalie) ·
  `HomeReq` HX3 = transaction preset SANS mouvement (câblage PRG_02) · purge latches
  identiques sur Enable FALSE (gate §7) · invariant purge : sorties mouvement déjà FALSE
  par la tête de scan avant toute réaction (§1 → §4 → §8) — « couper les permis d'abord »
  structurellement vrai, à écrire comme invariant testé.
- Priorité §10 : inserer HX2A avant la branche générique `Fault.Latched` (la cause 8
  est active pendant HX2A ; le libellé spécifique doit gagner).
- `ClimbTimedOut` : texte cause reformulé « Approche manuelle non validee dans le temps ».
- Longueurs : gate G408 (120 char max) à passer sur chaque nouveau libellé.

## 4. `M_MAIN/PRG_02_Acquisition.st`

- Publication diagnostic : brancher `TopContactLatched` (sortie FB) dans la structure
  de publication homing (côté `Data.MachineHoming.*`) — aucune modif de preset.
- Les blocs `CfgHomingTargetM` / `CfgTopSensorPosM` restent inchangés.

## 5. `J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st`

```iecst
TopContactLatched          : BOOL; (* Capteur haut touche latche — degager avant re-approche (T377) *)
LastValidationRefused      : BOOL; (* Dernier BtnValidation refuse par les gardes (T377) *)
```
- Remplissage dans `FB_TroubleshootingView.st` (E_HomingM1/F_HomingM2) et publication
  des refus dans `GVL_Troubleshooting.st` + `troubleshooting_variables.txt`.

## 6. Dossier benne / restants

- `ST_MachineHoming` (3e consommateur de l'enum) : mettre à jour les libellés/étapes
  renommés (D3) — à lire avant édition.
- Documentation : contrat T377 (corriger AC4 : 23,5 m = référence benne, pas homing ;
  chemin TASKS.yaml périmé) + `AF_Partie-09` F09.08 + `AF_Partie-14`.
- `TASKS.yaml` : via IHM Task Manager uniquement.

## 7. Non touchés (interdits sans accord)

`FB_Safety_Winch.st` (D1=A : aucune modif nécessaire tant que les gardes vivent dans le FB
homing) · `FB_Encoder_Homing.st` · `FB_Encoder.st` · `FB_WinchSync.st` · `Device.export`.

## 8. Tests SimBench à passer au moment du GO (rappel)

1. 4 refus de validation (manche défléchi / treuils non arrêtés / capteur atteint / hors MAINT_N2).
2. Validation nominale → HomeReq unique, M1/M2 = 8,50 m, Homed TRUE.
3. Contact fortuit → aucun HomeReq, HX2A, descente seule, retour HX2 après dégagement.
4. Hors bande HX4 → 1 re-émission puis HX7.
5. Preset non confirmé → Homed FALSE, aucun mouvement.
6. 13 TC `test_fb_cyclemachinehoming` adaptés aux états renommés.
7. Nouveau : entrée cycle refusée si manche défléchi (jeu joystick).
8. Ajouts challenge 2026-11-16 : contact volontaire basse vitesse avec **assert position NON modifiée** (avant/après · latch affiché) · barrière collée/shuntée (health-check entrée ; plus d'arrêt haut silencieux possible) · démarrage à froid manche non neutre → refus · relâche homme-mort en approche → arrêt, pas de FAIL · redémarrage mid-séquence (reinit propre, latches purgés, pas de preset sur glitch) · TC « inertie » : grafcet jamais entré → aucun ordre mouvement, zéro override WinchSel (`CmdWinchSelect = -1`) — précondition SimBench avant test terrain (remplace la garde xArmed proposée par le challenge A).
Gates : bundle · G200 --report · G496 · G511 · G408 · palier C + tous.

## 9. Alignement contrat complet (source lue le 2026-11-16, v0.2)

Source : `DOC/WFLOW/TASKS/T_TEMP (A TRIER)/CONTRACTS/T377_CONTRAT_HOMING_MANUEL_SANS_CONTACT_TOP.yaml`
(chemin TASKS.yaml périmé : `DOC/WFLOW/CONTRACTS/...` disparu — à corriger avec le lot doc).
Objectif complet : *« ... ne plus casser le capteur mecanique Top M1/M2 en allant le
heurter pour se referencer »* (REX MES 2026-09-23 + avarie capteur 2026-09-25).

| AC | Couvert par ce brouillon | Écart à traiter |
|---|---|---|
| AC1 | §3.4 HX2 approche manuelle | — |
| AC2 | §3.4 gardes de validation | Contrat = 4 gardes (MAINT_N1 **ou** N2, arrêt, capteur libre, homme-mort). Plan 11-14 (décisions exploitant) = 5 gardes (MAINT_N2 seul, + manche neutre, + non latché). **Contrat à amender** : prendre les 5 gardes, MAINT_N2 seul. |
| AC3 | §3.5 HX2A + cause 8 | **Arbitrage D1=C requalifié (challenge 2026-11-16)** : en MAINT_N2, l'arrêt au contact est un **retrait de permis** (`PRG_04:1126-1129` coupe `EffectivePermit*_Ascent`), PAS une coupure de puissance — `PowerCutOff` est masquée (`PRG_04:1632/1653 AND NOT MaintN2`) et le contacteur final bypassé (`PRG_06:355-356`). AC3 amendé : pas d'escalade automatique routée en MAINT_N2 ; le FB expose l'évènement (cause C8 + instruction IHM) ; l'overshoot au contact est borné par l'approche palier 1 + homme-mort. Le cycle ne tourne qu'en MAINT_N2 (`FB:414`), pas de second chemin MAINT_N1 (refuté challenge A). |
| AC4 | Hors homing : cible benne `BucketReferenceTargetM` (23,5 m) | AC4 à reformuler (23,5 m ≠ homing machine) — déjà identifié plan §2.3. |
| AC5 | §3.6/§3.7 : preset vérifié seule source de Homed | Conservation aussi : `CST_HomingVerifyToleranceM` (transaction preset, FB_Encoder_Homing) reste inchangé — le FB cycle ne l'altère pas ; la bande D5 est un contrôle CYCLE additionnel. |
| AC6 | Bundle frais : nom fichier/POU/langage | Standard, non spécifique. |
| AC7 | G110 + G120 sur champs nouveaux | Standard, non spécifique. |

Périmètre contrat — fichiers à AJOUTER à la liste §1-§5 du brouillon :
- `CODE/M_MAIN/PRG_07_Supervision.st` (publication diagnostic IHM des nouveaux champs)
- `CODE/J_SUPERVISION/FB_TroubleshootingView.st` (remplissage checklists)
- `DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md`, `AF_Partie-09 v2.4`

Forbidden contrat : `Device.export`, `FB_Encoder_Homing.st`, `FB_Encoder.st`,
`FB_WinchSync.st`, `ARCHIVES/**`. `FB_Safety_Winch.st` : pas dans la liste contractuelle
mais « interdit sans accord » selon plan §5 — rester sur D1=A (aucun contact).

Alert duty contrat : tout écart doctrine/code remonté immédiatement (jamais en fin de lot).

Deux typos du contrat à corriger au même passage : `T_TEMP (A TRIIER)` → une seule « I »,
et chemin de contrat dans `TASKS.yaml` périmé (migration T430 inachevée, plan §2.2).
