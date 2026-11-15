# 📝 T377 — Contrat v1.1 CANDIDAT (issue du re-challenge A/B du 2026-11-14)

> ⚠️ **STATUT : CANDIDAT à validation exploitant.** Fichier `.md` volontairement
> (jamais ramassé par `check_task_contract.py` / `find_task_contract` qui globent `*.yaml`).
> Le contrat canonique reste `T_TEMP (A TRIER)/CONTRACTS/T377_CONTRAT_HOMING_MANUEL_SANS_CONTACT_TOP.yaml`
> jusqu'à pose explicite.
> **Cycle N+1** : table fermée sur les 9 écarts du cycle précédent. Arène : A (innovation) +
> B (Red Team) — `deepseek-v4.1-flash:cloud`, faits sources fournis inline (agents sans outils).
> Arbitrage et vérifications code : CC03 (lecture seule).

---

## 1. Table fermée — écarts vérifiés au code (preuve fichier:ligne)

| # | Écart vérifié | Preuve |
|---|---|---|
| C1 | AC1 falsifiable seulement par « site unique d'émission HomeReq / zéro commande directe de mouvement » — le diff HX2/HX3 exigé est vide par construction (le cycle ne commande pas la montée, il sélectionne l'axe et observe) | `FB_WinchCmdArbitrationM1.st:56-61` |
| C2 | Collision homme-mort/validation : `BtnValidation := JoyBtnRaw OR Cmd.BtnValidate` — la garde « homme-mort armé » peut être satisfaite par la validation elle-même | `PRG_02_Acquisition.st:609` ; front sur signal fusionné `FB_CycleMachineHoming.st:214` |
| C3 | Symbole mort `SafetyPermit_Ascent` dans AC3 ; réel = `AscentPermit` publié `M1SafetyAscentPermit`/`M2SafetyAscentPermit` | `FB_Safety_Winch.st:574` + `PRG_07_Supervision.st:875/884` |
| C4 | « PowerCutOff seulement si montée persiste » contredit le câblage : `PowerCutOff := CausesPowerCutOffActive` direct | `FB_Safety_Winch.st:523-525, 584` |
| C5 | « Dégagement en descente imposé » : `PowerCutOff` coupe le treuil sans direction → descente impossible tant que la coupure est active — D6 réel | idem C4 (périmètre fermé : consommateurs = FB_Safety_Winch seul) |
| C6 | AC4 « ≈23,5 m » non falsifiable → le devient : 23,50 = `CfgTopSensorPos_M` 8,50 + `OffsetCloseM` 15,0 | `GVL_PERSISTENT.st:67` |
| C7 | AC2 cite encore `BtnConfirmHomingBucket` (rôle HX1, à retirer selon revue §4/AC2) | contrat §AC2 vs `T377_REVUE_PLAN_20261114_v1.0.md` §4 |
| C8 | Ligne 134 : chemin « T_TEMP (A TRIIER) » typo — path inexistant | contrat:134 |
| C9 | Aucun `execution_plan` (gate T9) ; AC3–AC6 non rejouables (gate T10) | `check_task_contract.py` : 13 WARN, PASS |

## 2. Écarts RÉFUTÉS (vérifiés au code — ne plus les relancer)

- ❌ « Gates fantômes » : `G511`, `G496`, `G408`, `G110`, `G120` **existent** tous dans `TOOLS/AGENT_WORKFLOW/scripts/`
- ❌ **AC5 du contrat est CONFORME** : `ReadbackOk := ABS(CandidateCablePosM − TargetPositionM) ≤ CST_HomingVerifyToleranceM (0,010 m)` ; `PresetConfirmed := ReadbackOk [AND StatusBitOk]` ; `Calib.Homed := TRUE` écrit au site unique `FB_Encoder_Homing.st:249-261` — **l'écart E9/F11 est réfuté, il est retourné vers la revue** (voir §4)
- ❌ E6 (contrat vs `FB_Encoder_Homing`): le `scope.forbidden` couvre déjà le cas — reste un point d'alerte `alert_duty`
- ✅ `WinchesMechanicallyStopped` existe et est câblé (`FB_CycleMachineHoming.st:27, PRG_02:594 depuis MachineHomingMechanicalStopOk`)

## 3. AC révisés (version candidate — à faire valider)

### AC1 — falsifiable
```yaml
- id: AC1
  statement: >
    Aucun état de FB_CycleMachineHoming n'emette une commande directe de mouvement
    de treuil (ReqWinch, preset de vitesse, HomeReq hors site d'appel) ; HomeReq n'a
    qu'un seul site d'mission (bloc validation AC2) ; toute selection d'axe
    (CmdWinchSelect) ne declenche pas de montee automatique.
  verified_by: >
    Grep unique site HomeReq + grep ReqWinch/preset de vitesse dans HX0..HX6 (0 match) ;
    G511 en PASS avec preuve qu'il peut echouer (fixture negative ou revue nommee).
```

### AC2 — découpler la validation de l'homme-mort
```yaml
- id: AC2
  statement: >
    Le cycle n'emmet HomeReq que sur front montant d'une commande de validation
    DEDIEE (BtnValidate IHM, jamais JoyBtnRaw = homme-mort, PRG_02:609), si au meme
    scan : arret mecanique confirme (WinchesMechanicallyStopped), capteur top LIBRE
    (TopPositionSensor=FALSE, true=libre), mode homing actif (D7: MAINT_N2 seul ou
    MaintenanceActive - parametre ouvert a arbitage), et position brute d'arret dans
    la fenetre |RawPos - CfgTopSensorPos_M| <= 1,00 m (7,50-9,50 m const. reelles
    ST_fbMachineHomingCycle_Cfg:29-30) ; hors gardes : refus + message IHM, zero HomeReq ;
    boutons benne neutralises pendant le homing (exclusion mutuelle).
  verified_by: >
    Grep PRG_02:609 prouvant que JoyBtnRaw n'atteint pas le site HomeReq + grep site
    unique HomeReq + SimBench (Cmd.BtnValidate sans homme-mort / front joystick /
    capteur contact / mouvement non nul / mode hors homing) -> HomeReq=FALSE + G408 PASS.
```
> ⚠️ La garde de fenêtre brute est une **proposition** (garde de refus non circulare,
> ne tranche pas D4) — à faire valider par l'exploitant avant pose.

### AC3 — symboles réels + coupure existante non retardée
```yaml
- id: AC3
  statement: >
    Sur contact fortuit du capteur top : le cycle n'emmet ni HomeReq ni preset ;
    AscentPermit reste produit par FB_Safety_Winch (publie M1/M2SafetyAscentPermit,
    PRG_07:875/884) ; la coupure CauseMecaDActive -> CausesPowerCutOffActive ->
    PowerCutOff reste INTACTE (aucune condition a-posteriore ajoutée) ; la direction de
    degagement = D6 (hors AC, a trancher) ; FB_Safety_Winch.st et PRG_04 ne sont pas modifies.
  verified_by: >
    SimBench « contact fortuit pendant montee » : HomeReq=FALSE, preset non declenche,
    M1/M2SafetyAscentPermit=FALSE, PowerCutOff etat existant ; diff prouvant 0 modif de
    FB_Safety_Winch.st / PRG_04 ; G496 en PASS.
```

### AC4 — cible falsifiable
```yaml
- id: AC4
  statement: >
    BucketReferenceTargetM = CfgTopSensorPos_M (8,50) + OffsetCloseM (15,0) = 23,50 m,
    calcule uniquement si M1 HomedAndReliable et hors commande benne (exclusion mutuelle) ;
    aucun 23,5 hardcode ; publication RawPos d'arret + Calib.HomingRefRaw dans le snapshot.
  verified_by: >
    Grep GVL_Troubleshooting.F_HomingM2.* + G200 (valeur numerique 8,50+OffsetCloseM) +
    grep garde HomedAndReliable/exclusion benne + diff troubleshooting_variables.txt.
```

### AC5 — conforme (inchangé, ancré au code)
`ReadbackOk` = tolérance 10 mm (`FB_Encoder_Homing:249`), `PresetConfirmed` selon mode
(`:252-258`), `Calib.Homed` site unique (`:261`) — le contrat v1.0 reste correct ici.
Option de design (revue) : séparation `Homed` / `MachineHomed` dérivé — à arbitrer
par l'exploitant, pas une exigence du code actuel.

### AC7 — falsifiable
```yaml
- id: AC7
  statement: >
    Les champs ajoutes sont nommes en liste nominative dans le diff, conformes
    NAMING_CONVENTION, chacun avec producteur unique et consommateur declare ;
    aucun duplicata d'un fait deja publie dans le snapshot.
  verified_by: >
    G110+G120 en PASS avec preuve de capacite d'echec (fixture negative ou revue
    nominative des champs) ; G110/G120 seul en PASS n'est pas suffisant.
```

## 4. Corrections hors AC

- **C8** — ligne 134 : « T_TEMP (A TRIIER) » → « T_TEMP (A TRIER) ».
- **Execution plan (commandes existantes uniquement)** :
  1. `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .`
  2. `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report`
  3. `grep` site unique `HomeReq` + 0 `ReqWinch`/preset vitesse dans HX0..HX6
  4. `grep PRG_02:609` (JoyBtnRaw hors site HomeReq)
  5. `G511` + `G496` + `G408` + `G110` + `G120` (PASS + capacité d'échec démontrée pour G110/G120)
  6. `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <yaml revisé>`
  7. Scénarios SimBench nommés (AC2 gardes ×5, AC3 contact fortuit, AC5 preset échec)
- **Risque résiduel à trancher (documenté, pas un AC)** : référence = constante 8,50 m
  → plus aucune re-validation mécanique de la calibration (allongement câble / usure
  tambour invisibles). À accepter ou compenser (contrôle périodique) par l'exploitant.
- **D7** : garde de mode — MAINT_N2 seul (plan) vs MAINT_N1/N2 (`HomingPermit` câblé
  actuel = N1 OR N2, `PRG_02:652`) : à trancher.

## 5. Écart retourné vers la revue (à corriger dans `T377_REVUE_PLAN_20261114_v1.0.md`)

- **§4/AC5** affirme « ReadbackOk ne teste que l'absence de mouvement sur 50 ms » —
  **faux au code** (`FB_Encoder_Homing.st:249-256` : tolérance 10 mm + StatusBit,
  mode config). Le NO-GO global tient (bouton §2.1, arbitrage §2.2, HX4 tautologie,
  Mode B non lu) ; le classement AC5 et la « séparation Homed/MachineHomed »
  reposent sur ce fait à corriger.

## 6. Suite attendue

1. Arbitrage exploitant : **D4–D7** + garde de fenêtre brute (AC2) + risque résiduel.
2. Pose canonique du contrat v1.1 (.yaml) après accord — puis
   `check_task_contract.py` visé PASS sans nouvelle WARN T9/T10.
3. Correction du doc revue (§4/AC5) — cycle suivant, table fermée.
