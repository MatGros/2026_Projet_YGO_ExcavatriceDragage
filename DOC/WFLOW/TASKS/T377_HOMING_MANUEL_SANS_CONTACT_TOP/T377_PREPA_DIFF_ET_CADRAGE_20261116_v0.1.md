# T377 — Préparation : diff futurs + cadrage (lecture seule)

> v0.1 · 2026-11-16 · CC03 — **aucune ligne de `CODE/` modifiée**, audit lecture seule.
> Sources : PLAN_TASK_v1.0.md · contrat 2026-11-02 · code constaté au 2026-11-16 (main).

## 1. Vérification du plan à la source (faits re-confirmés)

- Montée auto + HomeReq sur contact capteur : `FB_CycleMachineHoming.st:452-470` ✓
- Preset 8,50 m câblé M1/M2 : `PRG_02_Acquisition.st:661-663` / `:715-717` ✓
- Valeur persistante 8,5 : `CODE/GVL_PERSISTENT.st:41` et `:49` ✓
- Palier 1 max : `CST_StepSlow := 1` (FB_CycleMachineHoming.st:181) ✓
- Enum 0..8, valeur 9 libre : `E_MachineHomingTxState.st:11-23` ✓
- Consommateurs enum : exactement 3 fichiers (FB_CycleMachineHoming, ST_MachineHoming, type) ✓
- AC3 corrigé vérifié : détection MECA-D armée au contact (`FB_Safety_Winch.st:376-386`),
  escalation PowerCutOff incluse (`:523-525`), `AscentPermit` existe (`:574`) ✓
- Gates requis présentes : G496, G511, G408 ✓
- Briques de gardes déjà déclarées : `BtnValidationEdge` (:131), `ClimbPermit` (:233),
  `ClimbTimedOut` (:251), `JoystickDeflected` (:38) ✓

## 2. Constat nouveau (pas dans le plan)

- `InReferencingMode` inhibe la détection MECA-D (`FB_Safety_Winch.st:378`) et la garde
  capteur haut logicielle (`:310`) **tant que le cycle de homing tourne** → la détection
  existante ne peut donc PAS couvrir l'approche manuelle HX2. C'est l'argument
  décisif pour D1 option A (gardes dans FB_CycleMachineHoming, pas FB_Safety_Winch).
- Table causes `ARRAY[0..15]`, dernier id utilisé = 7 → `CST_CauseTopContact := 8`
  tient sans redimensionnement.

## 3. Diff prévus (7 lots)

1. `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` — + `HX2A_CONTACT_CLEARANCE := 9`
   en fin d'enum (aucune valeur 0..8 changée → aucun forçage/trace cassé).
2. `CODE/G_CYCLE/FB_CycleMachineHoming.st` — cœur du lot :
   - HX2 : montée sous `ClimbPermit` + neutre + capteur libre + `NOT TopContactLatched` ;
     contact → latch + bascule HX2A ; validation opérateur `BtnValidationEdge.Q`
     sous 5 gardes → `HomeReq` posé puis HX3.
   - HX2A (nouveau) : rien d'écrit, montée interdite, descente joystick palier 1,
     sortie vers HX7 cause 8 dégagée.
   - HX3 : suppression Mode A/B (`HomingModeBActive`, `FlyingHomingTimer`,
     `StandstillHomeReqDone`), `HomeReq` unique, sortie `BothAxesHomed` ou HX7.
   - HX4 : fenêtre d'inertie remplacée par vérification preset lu + cohérence M1/M2
     + distance à `CfgTopSensorPos_M` (`CST_HomingVerifyToleranceM`), 1 seule re-émission.
   - + cause `CST_CauseTopContact := 8` + guide opérateur §10.
3. `CODE/M_MAIN/PRG_02_Acquisition.st` — publication `TopContactLatched` si champ
   de diagnostic (aucune modif de preset prévue).
4. `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st` — 2 champs
   de diagnostic (contact latched, refus validation). Fichiers IHM_MANU non touchés.
5. `CODE/J_SUPERVISION/GVL_Troubleshooting.st` + liste CSV troubleshooting.
6. Docs : corrections contrat §2 (AC3 déjà corrigée, AC4, chemin) + `AF_Partie-09`
   (F09.08) + `AF_Partie-14`.
7. `TASKS.yaml` : statut/verrou/chemin contrat — **IHM Task Manager uniquement**.

Interdits respectés : `FB_Safety_Winch.st` (sauf accord), `FB_Encoder_Homing.st`,
`FB_Encoder.st`, `FB_WinchSync.st`, `Device.export`.

## 4. Décisions D1/D2/D3 à trancher

- **D1 — escalation montée persistante** :
  A) gardes dans FB_CycleMachineHoming (recommandé — InReferencingMode inhibe la
  sécurité existante pendant tout le cycle, cf. §2) ;
  B) étendre FB_Safety_Winch (changement C4, retest complet) ;
  C) amender AC3 (pas d'escalade auto).
- **D2 — dégagement HX2A** :
  A) descente sous joystick + homme-mort uniquement (recommandé) ;
  B) descente automatique palier 1 tant que contact.
- **D3 — renommages** HX3_FLYING_REFERENCE → HX3_REFERENCE_RESTORE,
  HX4_STABILIZATION_CHECK → HX4_REFERENCE_VERIFY : 3 fichiers consommateurs
  (coût faible) ou noms gardés + commentaires corrigés.

## 5. Tests prévus après GO

SimBench : 4 refus garde · validation nominale 8,50 m · contact fortuit → HX2A
sans `HomeReq` · preset non confirmé → aucun mouvement · 13 TC existants adaptés.
Gates : bundle · G200 --report · G496 · G511 · G408 · palier C + tous.
