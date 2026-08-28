# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION T165-CR : Revue indépendante basée sur le GIT DIFF RÉEL (T165-C1 / T165-C2)

## 1. Contexte factuel
Tu avais émis des doutes basés sur des noms hypothétiques. Voici le **git diff réel** des modifications apportées aux fichiers sources IEC 61131-3 de `CODE/M_MAIN/`.

## 2. Extraits réels du diff

### A. `PRG_03_Modes_Cycle.st` : encapsulation privée
```diff
 VAR_OUTPUT
     // === BUS D'AUTORISATIONS & DEMANDES DE CYCLE ===
-    Auth              : ST_fbModes_Autorisations;
-    instCycleSemiAuto : FB_Cycle;
+    Data              : ST_ModesCycleInterPrg;
 END_VAR

 VAR
     // === SOUS-INSTANCES FB INTERNES ===
     instModes         : FB_Modes;
+    instCycleSemiAuto : FB_Cycle; // Privé en VAR interne
 END_VAR
```

### B. `PRG_05_Translation.st` : remappage vers `PRG_03.Data`
```diff
 IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
     M3_PositioningActive  := TRUE;
-    SelTarget    := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Target;
-    M3_StartStop_Active  := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Start;
+    SelTarget    := PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt;
+    M3_StartStop_Active  := PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart;
```

### C. `PRG_04_Treuils_Benne.st` : remappage vers `PRG_03.Data`
```diff
 IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
-    M1LogicRequestDirection := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.Direction;
-    M1LogicRequestStartStop := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.StartStop;
-    M1LogicRequestSpeedCmd_Pct  := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.SpeedPct;
+    M1LogicRequestDirection := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDirection;
+    M1LogicRequestStartStop := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqStartStop;
+    M1LogicRequestSpeedCmd_Pct  := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.SpeedTgtPct;
```

### D. `PRG_07_Supervision.st` : remappage vers `PRG_03.Data`
```diff
-GVL_IHM.Cycle.State.Ready            := PRG_03_Modes_Cycle.instCycleSemiAuto.Ready;
-GVL_IHM.Cycle.State.Busy             := PRG_03_Modes_Cycle.instCycleSemiAuto.Lifecycle.Busy;
-GVL_IHM.Cycle.State.Error            := PRG_03_Modes_Cycle.instCycleSemiAuto.Fault.Error;
+GVL_IHM.Cycle.State.Ready            := PRG_03_Modes_Cycle.Data.SequenceState.Ready;
+GVL_IHM.Cycle.State.Busy             := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy;
+GVL_IHM.Cycle.State.Error            := PRG_03_Modes_Cycle.Data.SequenceState.Fault.Error;
```

## 3. Résultats mécaniques réels exécutés
- **G200 Linkage** : PASS (0 erreur, 1352 instances vérifiées)
- **Suite 22 Gates** : 22/22 PASS (dont G100, G200, G300, G310, G320, G330, G340, G430)
- **Tests CI M_MAIN** : 7 FB testés, 7 PASS, 0 FAIL (PRG_02, PRG_03, PRG_04, PRG_05, PRG_06, PRG_07, MAIN_GLOBAL)

## 4. Question pour ton verdict
À la lumière de ce diff réel (0 accès direct à `instCycleSemiAuto`, `ReqProgram` structuré en `ReqStartStop`/`ReqDirection`/`SpeedTgtPct`/`PositionTgt` sans safety), confirme ton verdict formel (**PASS / BLOCK**).
