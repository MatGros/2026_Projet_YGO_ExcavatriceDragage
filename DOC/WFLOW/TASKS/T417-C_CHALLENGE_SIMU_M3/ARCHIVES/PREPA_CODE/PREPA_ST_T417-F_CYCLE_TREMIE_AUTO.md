# Préparation ST `T417-F` — Cycle Benne Trémie & Conditions Initiales Auto

> **Statut :** Audit réel effectué (`FB_Modes.st`, `PRG_03_Modes_Cycle.st`, `FB_CycleSemiAuto.st`) + brouillons prêts au GO C3 (aucune modification sur `CODE/`).

## 1. Audit ciblé des fichiers (`CODE/` en lecture seule)

### A. Ouverture benne au-dessus de la trémie
- **Constat 1 (`PRG_03_Modes_Cycle.st:111` vs `FB_Modes.st:372`) :**
  `PRG_03_Modes_Cycle.st:111` câble `M3AtTremie := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie`.
  Or si la came physique `M3_PosTremie_DI` décroche après dépassement (`Trace 27` : `1→0` en 115 ms), `LimitSwitchTremie` retombe alors que le chariot est au-dessus de la trémie, faisant basculer `FB_Modes` hors de la garde `WinchSel = 2` (si `AllowWinchMoveAtTremie = FALSE`).
- **Constat 2 (`FB_CycleSemiAuto.st:1503-1564`) :**
  En `SEMI_AUTO`, l'ouverture en `AX15A_DUMP_ARRIVE -> AX15B_DUMP_OPEN` exige `SeenNeutralAfterArrival` (un scan joystick au neutre) puis `DeadmanArmed AND JoystickPush` pour activer `BucketCmd.ReqOpen`. Les treuils sont déjà neutralisés (`RunRequest := FALSE`).

### B. Conditions initiales du mode Automatique (`SEMI_AUTO`)
- **Constat 1 (`FB_Modes.st:251-291`) :**
  La sélection `SEMI_AUTO` exige `MachineHomed` (sinon expulsion `MAINT_N1`) et `ModeChangeAllowed` (6 conditions : contacteurs M1/M2 retombés, freins serrés, vitesses < seuil).
- **Constat 2 (`PRG_03_Modes_Cycle.st:172-179` & `FB_CycleSemiAuto.st:925`) :**
  `AX1_INIT` vérifie `InitConditionsOk := HomedM1 AND HomedM2 AND NOT Fault.Latched AND InitPositionOk`.
  `CycleInitPositionOk` (`PRG_03_Modes_Cycle.st:179`) exige :
  1. `NOT PRG_05_Translation.Data.M3_AtMaintenanceStable`
  2. `(M1.CableLimitAscent OR M2.CableLimitAscent OR ABS(M1.CablePosM - CfgCableLimitAscent_M) <= CST_CycleInitWindowM)`
  3. `BucketState.MechState.IsClosed OR BucketState.MechState.IsOpen`
  → Si la benne est entre deux états mécaniques (entrouverte) ou juste sous la fenêtre `CST_CycleInitWindowM`, `AX1_INIT` bloque avec un message générique (`OperatorActionId := 16#0401`) sans distinguer quel sous-critère manque.

---

## 2. Brouillons ST prêts au GO (`T417-F`)

### 2.1 Ouverture benne sécurisée au-dessus de la trémie (`PRG_03_Modes_Cycle.st:111`)
- **Plan A :** Utiliser l'état stabilisé/mémorisé trémie (`M3_AtTremieStable`, déjà calculé dans `PRG_05_Translation.st:248` avec `GVL_PERSISTENT._TranslationAtTremiePersisted`) pour alimenter `M3AtTremie`, afin qu'une micro-perte de came n'annule pas l'autorisation/garde benne au-dessus de la trémie :
```iecst
// PRG_03_Modes_Cycle.st:111 (Plan A)
M3AtTremie := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
              OR PRG_05_Translation.Data.M3_AtTremieStable;
```
- **Décisions exploitant (2026-11-16) :**
  1. **Plancher vitesse PV à `20 Hz` maintenu** (pas de `5 Hz` : risque surchauffe moteur + vibrations).
  2. **Pause réglable avant `AX15B_DUMP_OPEN` :** `TON` paramétrable (`0 s` par défaut, testable à `0,3–0,5 s` sur site pour garantir le serrage frein avant ouverture).
  3. **Ouverture dès la zone PV :** autoriser l'ouverture benne dès la zone PV tout en poursuivant la translation vers Trémie pendant l'ouverture ; une fois ouverte, retour vers `P1` autorisé même si le capteur Trémie n'est pas encore atteint.
- **Option fluidité `AX15A` (`FB_CycleSemiAuto.st:1524-1534`) :** conserver `SeenNeutralAfterArrival` pour éviter l'ouverture involontaire en fin de translation, mais exposer un bit IHM/diag explicite `WaitingNeutralForDump` pour guider l'opérateur instantanément.

### 2.2 Simplification & test rapide conditions initiales Auto (`PRG_03_Modes_Cycle.st:172-179` + `FB_CycleSemiAuto.st:948-955`)
- **Plan A :**
  1. Assouplir la condition benne au démarrage `AX1_INIT` si la benne est en sécurité haute (ou permettre `NOT Fault.Latched` + diagnostic exact sur l'IHM : `M3_Maint`, `M1_Top`, `Benne_NonQualifiee`).
  2. Séparer les messages d'attente `ELSIF` dans `FB_CycleSemiAuto.st:948` pour afficher la cause exacte en < 1 s lors des essais :
```iecst
// Diagnostic granulaire AX1_INIT (brouillon FB_CycleSemiAuto.st)
// Exposer en VAR_INPUT ou diag PRG_03 : InitFailM3Maint, InitFailWinchTop, InitFailBucketState
IF NOT InitPositionOk THEN
    // Afficher precisement : "M3 en zone Maintenance", "Remonter M1/M2 au FDC haut", ou "Fermer/Ouvrir benne"
END_IF;
```
- **Plan B (secours essais terrain) :** si une condition mécanique capteur bloque les essais de cycle, basculer sur un forçage contrôlé `StepForceTgt` vers `AX2` ou autorisation explicite opérateur (jamais automatique).

## 3. Validation C3
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
