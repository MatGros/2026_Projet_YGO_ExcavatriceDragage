# MISSION AGENT 3 — CONCEPTION ST DES OPTIONS T417-F (PAUSE AX14/AX15 & OUVERTURE ANTICIPÉE EN ZONE PV)

## Contexte Code (`FB_CycleSemiAuto.st` & `PRG_03_Modes_Cycle.st` & `FB_Modes.st`)
Dans `FB_CycleSemiAuto.st` :
- `AX14_TRANSLATE_DUMP` (lignes 1475-1501) : commande `TranslationCmd.PositionTgt := 1; TranslationCmd.ReqStart := TranslationTremiePermit;`. Quand `Translation_At_Tremie` est `TRUE` et `TranslationStopTimer.Q` (500 ms sous `0,5 Hz`), passe à `AX15A_DUMP_ARRIVE`.
- `AX15A_DUMP_ARRIVE` (lignes 1503-1534) : attend `SeenNeutralAfterArrival` puis `DeadmanArmed AND JoystickPush` pour passer à `AX15B_DUMP_OPEN`.
- `AX15B_DUMP_OPEN` (lignes 1536-1565) : `BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush;`. Quand `Benne_Done AND Benne_IsOpen`, passe à `AX18_DONE_SYNC`.

## Exigences Exploitant à Intégrer Simplement par Bits/Paramètres IHM
1. **Demande F1 (`CfgPauseBeforeDump_S : REAL := 0.0`) :**
   - Pause réglable IHM entre l'arrêt en `AX14` et l'ouverture benne (`AX15B`). Si `0.0 s` : transparent. Si `> 0.0 s` (ex. `0.5 s`) : impose ce délai supplémentaire à l'arrêt avant d'autoriser l'ouverture en `AX15A/B`.
2. **Demande F2 (`TglAllowDumpInPV : BOOL := FALSE`) :**
   - Quand `TglAllowDumpInPV = TRUE`, dès que le chariot est en zone PV (`Translation_PosPV = TRUE`) en `AX14` :
     - L'opérateur peut déjà ouvrir la benne (tout en continuant ou en finissant la translation vers Trémie),
     - Et dès que la benne est ouverte (`Benne_IsOpen = TRUE`), le cycle autorise le passage vers `AX18_DONE_SYNC` (et donc le retour vers `P1` en `AX2`) **même si le capteur `M3_PosTremie_DI` (`Translation_At_Tremie`) n'a pas été atteint** !
   - Vérifier aussi l'interaction avec `PRG_04_Treuils_Benne.st:1083` (`WinchDescentAuth_M3` exempte déjà `ReqProgram.ReqBucket.ReqOpen`) et `FB_Modes.st:372` (`M3AtTremie`).

## Objectif Évaluable
Proposer **2 variantes d'implémentation ST propres** (Variante A et Variante B) pour F1 et F2, avec le code ST exact et l'analyse des transitions joystick (Axe X translation vs Axe Y ouverture benne).
