Audite ce diff de cablage homing D1-D7 (PRG_03/04/06, FB_Safety_Winch, FB_Bucket). Note : Meca D (PowerCutOff) est volontairement actif en N2 (retirer AND NOT MaintN2), SoftLimitsOff coupe uniquement SoftLimitsBypassed en HX1..HX3, ReqOpen/ReqClose=FALSE en homing car CommitClose est un commit codeur uniquement. Cherche tout vrai bug de securite, blocage ou scan IEC. Reponds concisement : bugs reels ou VERDICT CLEAN.

`diff
diff --git a/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st b/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
index 7091b5e5..0cac3ced 100644
--- a/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
+++ b/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
@@ -414,5 +414,5 @@ END_IF;
 //  - HomingSuspect n'est pose qu'apres le controle de coherence au demarrage (bus up) ->
 //    pas de faux positif pendant l'enum EtherCAT. Aucun redemarrage auto : re-confirmer.
-TonDatumUnreliable(IN := HomingSuspectM1 OR HomingSuspectM2, PT := T#2s);
+TonDatumUnreliable(IN := HomingSuspectM1 OR HomingSuspectM2 OR NOT HomedM1 OR NOT HomedM2, PT := T#2s);
 IF TonDatumUnreliable.Q THEN
     BucketState.BucketReferenced := FALSE;
@@ -470,13 +470,11 @@ IF SevereError THEN
     Lifecycle.Done := FALSE;
 ELSE
-    // ⚠️ SÉCURITÉ : abandon propre si une open/close est restée Busy HORS de tout contexte
-    // de pilotage benne (opérateur a quitté WinchSel=2 sans que le mouvement soit fini,
-    // hors cycle AUTO/SEMI_AUTO, hors homing machine). Sinon M2 continue de suivre la benne
-    // pendant un pilotage COUPLÉ WinchSel=0 -> désynchro des câbles (REX MES 2026-09-04).
-    IF Lifecycle.Busy
-       AND NOT WinchSelBucket
-       AND NOT ProgramBucketDriveActive
-       AND NOT MachineHomingActive
-       AND NOT (Mode = E_Mode.SEMI_AUTO) THEN
+    // Purge automatique pendant le homing machine (evite ErrorID:04/05 sur Busy residuel)
+    // ou hors contexte de pilotage benne.
+    IF MachineHomingActive
+       OR (Lifecycle.Busy
+           AND NOT WinchSelBucket
+           AND NOT ProgramBucketDriveActive
+           AND NOT (Mode = E_Mode.SEMI_AUTO)) THEN
         M2_RunRequest := FALSE;
         M2_ReqAscent := FALSE;
@@ -485,4 +483,5 @@ ELSE
         CloseReq := FALSE;
         OpenReq := FALSE;
+        CloseReached := FALSE;
         Lifecycle.Busy := FALSE;
         Lifecycle.Done := FALSE;
@@ -490,13 +489,15 @@ ELSE
 
     // Prise en compte des demandes IHM — anti-traversée (TC-P10-025) :
-    // demande benne refusée si un treuil agit (M1_Busy OR M2_Busy) à l'entrée READY.
-    IF CmdOpen_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
-        OpenReq := TRUE;
-        CloseReq := FALSE;
-        CloseReached := FALSE;
-    ELSIF CmdClose_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
-        CloseReq := TRUE;
-        OpenReq := FALSE;
-        CloseReached := FALSE;
+    // demande benne refusée si un treuil agit (M1_Busy OR M2_Busy) ou si homing actif.
+    IF NOT MachineHomingActive THEN
+        IF CmdOpen_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
+            OpenReq := TRUE;
+            CloseReq := FALSE;
+            CloseReached := FALSE;
+        ELSIF CmdClose_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
+            CloseReq := TRUE;
+            OpenReq := FALSE;
+            CloseReached := FALSE;
+        END_IF;
     END_IF;
 
diff --git a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
index eea649de..c474c900 100644
--- a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
+++ b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
@@ -38,5 +38,7 @@ VAR_INPUT
 
     // === REGLAGES ET LIMITES SÉCURITÉ ===
-    InReferencingMode               : BOOL;                           // --> [CFG] Treuil en cours de homing
+    InReferencingMode               : BOOL;                           // --> [CFG] Transaction preset SDO codeur active
+    SoftLimitsBypassed              : BOOL := FALSE;                  // --> [CFG] Inhibe uniquement les butees soft (HX1..HX3), jamais TOP ni Meca D
+    BrakeForceAllowed               : BOOL := FALSE;                  // --> [CFG] Desserrage frein volontaire N2 (inhibe faux Meca B)
     CablePosM                       : REAL;                           // --> [CFG] Position actuelle cable (m)
     CfgCableLimitDescentM           : REAL;                           // --> [CFG] Limite basse physique descente (m)
@@ -317,5 +319,5 @@ IF NOT BypassGlobal THEN
 
     // Cause 6 : Limite max câble descente (live)
-    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
+    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND Homed AND NOT HomingSuspect AND NOT SoftLimitsBypassed AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
         instCauses[6].Active := TRUE;
     ELSE
@@ -339,5 +341,5 @@ IF NOT BypassGlobal THEN
     // Cause 8 : Méca B absence confirmation arrêt (latched)
     IF NOT (BypassSafety OR BypassMecaB) THEN
-        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
+        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT BrakeForceAllowed AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
         IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;
@@ -377,4 +379,5 @@ IF NOT BypassGlobal THEN
         UncommandedActiveD := NOT (BenneBusy OR BenneHoldStillActive)
             AND NOT TopPositionSensor AND NOT InReferencingMode
+            AND NOT (ReqDescend AND NOT ReqAscent)
             AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaD(IN := UncommandedActiveD, PT := PostRampTimeout);
@@ -563,5 +566,5 @@ END_IF;
 DescendPermit := NOT (
     ((CauseCableLimitActive OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
-    OR ((CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode AND NOT BypassCableLimitSwitch)
+    OR (Homed AND NOT HomingSuspect AND NOT SoftLimitsBypassed AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode AND NOT BypassCableLimitSwitch)
     // La limite légale est une interdiction d'exploitation distincte du groupe
     // SafeStop/Permit. Le bypass banc BypassProcess ne doit jamais la lever :
@@ -579,5 +582,5 @@ AscentPermit := NOT (
     // logicielle reste active a la valeur relevee. Bypasser le logiciel releve la butee,
     // il ne la supprime pas ; le FDC haut materiel reste une barriere independante.
-    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
+    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND NOT SoftLimitsBypassed AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
 );
 
diff --git a/CODE/M_MAIN/PRG_03_Modes_Cycle.st b/CODE/M_MAIN/PRG_03_Modes_Cycle.st
index a83530c2..674653a8 100644
--- a/CODE/M_MAIN/PRG_03_Modes_Cycle.st
+++ b/CODE/M_MAIN/PRG_03_Modes_Cycle.st
@@ -75,9 +75,12 @@ CycleDrainTimeEffective := DINT_TO_TIME(INT_TO_DINT(CycleDrainTimeEffective_S) *
 // 1 = SEMI_AUTO ; 2, 5 = MAINT_N1 ; 3, 4, 6, 7, 8 = MAINT_N2)
 IF NOT ModeBootInitialized THEN
-    // Sécurité d'exploitation : après boot PLC, le mode demandé repart en
-    // SEMI_AUTO. La page affichée est mémorisée comme référence afin qu'une
-    // page IHM restaurée ne force pas MAINT_N1 au premier scan.
+    // Securite d'exploitation : au boot, MAINT_N1 si machine non referencee (evite faux refus SEMI_AUTO),
+    // sinon SEMI_AUTO. La page affichee est memorisee au premier scan.
     ModeBootInitialized := TRUE;
-    GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
+    IF PRG_02_Acquisition.Data.MachineHoming.Homed THEN
+        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
+    ELSE
+        GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1;
+    END_IF;
     PrevActualPage := GVL_IHM.LocalIHM.StatusBlock.StatusInt01_ActualPage;
 ELSIF GVL_IHM.LocalIHM.StatusBlock.StatusInt01_ActualPage <> PrevActualPage THEN
@@ -114,10 +117,12 @@ instModes(
     JoystickWinchSelectRequest := EffectiveWinchSelectRequest,
     SelMaintenanceZoneAccess := GVL_IHM.M3Translation.Cmd.TglMaintenanceZoneAccess,
-    // T248 — sequencement auto benne en couple (force temporairement le sel. a 2)
-    CoupledBucketSeqEnable  := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing,
-    // Stabiliser M3AtTremie via M3_AtTremieStable (et zone PV si ouverture anticipee active) pour maintenir la garde benne
-    M3AtTremie              := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
-                               OR PRG_05_Translation.Data.M3_AtTremieStable
-                               OR (GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV AND PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI),
+    // Sequencement auto benne en couple inhibe pendant homing machine
+    CoupledBucketSeqEnable  := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
+                               AND NOT PRG_02_Acquisition.Data.MachineHoming.Active,
+    // Stabiliser M3AtTremie via M3_AtTremieStable ; neutralise pendant homing machine (D7)
+    M3AtTremie              := (PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
+                                OR PRG_05_Translation.Data.M3_AtTremieStable
+                                OR (GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV AND PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI))
+                               AND NOT PRG_02_Acquisition.Data.MachineHoming.Active,
     AllowWinchMoveAtTremie  := GVL_IHM.M3Translation.Cmd.TglAllowWinchMoveAtTremie,
     JoystickPull            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive,
@@ -351,7 +356,7 @@ Data.ModesFault := instModes.Fault;
 
 // 1bis. Intention both continue opérateur (inconditionnelle, TOUS modes) — source unique
-Data.WinchBothIntent.Active    := WinchBothMotionActive;
-Data.WinchBothIntent.ReqAscent  := WinchBothMotionDirection > 0;
-Data.WinchBothIntent.ReqDescend := WinchBothMotionDirection < 0;
+Data.WinchBothIntent.Active     := WinchBothMotionActive;
+Data.WinchBothIntent.ReqAscent  := WinchBothMotionActive AND (WinchBothMotionDirection > 0);
+Data.WinchBothIntent.ReqDescend := WinchBothMotionActive AND (WinchBothMotionDirection < 0);
 
 // 2. Demandes programme et état public de séquence
@@ -454,5 +459,5 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     // maintenu (homme-mort + joystick) et ne commande qu'en HX2/HX3 ; PRG_04 conserve
     // ses interlocks maintenance. Copie struct entiere (ST_ProgramWinchRequest).
-    IF instModes.Auth.Mode = E_Mode.MAINT_N2
+    IF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
        AND PRG_02_Acquisition.Data.MachineHoming.Active THEN
         Data.ReqProgram.ReqWinchM1 := PRG_02_Acquisition.Data.MachineHoming.CmdWinchM1;
@@ -482,8 +487,8 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     // engage : evite le cumul ReqOpen+ReqClose si un assistant (DumpAtTremie / Extraction)
     // etait actif au meme instant. Hors cycle homing : demandes assistants inchangees.
-    IF instModes.Auth.Mode = E_Mode.MAINT_N2
+    IF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
        AND PRG_02_Acquisition.Data.MachineHoming.Active THEN
-        Data.ReqProgram.ReqBucket.ReqOpen  := PRG_02_Acquisition.Data.MachineHoming.CmdBucketOpen;
-        Data.ReqProgram.ReqBucket.ReqClose := PRG_02_Acquisition.Data.MachineHoming.CmdBucketClose;
+        Data.ReqProgram.ReqBucket.ReqOpen  := FALSE;
+        Data.ReqProgram.ReqBucket.ReqClose := FALSE;
     END_IF;
 
@@ -534,4 +539,5 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     Data.SequenceState.WinchDescentAuth_M3     :=
         (instModes.Auth.Mode = E_Mode.MAINT_N2)
+        OR PRG_02_Acquisition.Data.MachineHoming.Active
         OR NOT GVL_IHM.Commun.Cfg.TglEnableWinchDescentLock_M3
         OR GVL_IHM.M3Translation.State.AtP1
diff --git a/CODE/M_MAIN/PRG_04_Treuils_Benne.st b/CODE/M_MAIN/PRG_04_Treuils_Benne.st
index dcd9b0fd..522f52aa 100644
--- a/CODE/M_MAIN/PRG_04_Treuils_Benne.st
+++ b/CODE/M_MAIN/PRG_04_Treuils_Benne.st
@@ -271,4 +271,7 @@ VAR
     PositionLimitOverriddenM1 : BOOL;
     PositionLimitOverriddenM2 : BOOL;
+    BrakeForceAllowedM1       : BOOL;
+    BrakeForceAllowedM2       : BOOL;
+    HomingFreeMoveBlockedN1   : BOOL;
 
     // 🕵️ Trace de blocage terrain (§8bis) — publiée via Data.TraceM1/M2, consommée FB_TroubleshootingView
@@ -315,5 +318,6 @@ ArbBucketIHM.BtnOpen  := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen;
 ArbBucketIHM.BtnClose := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
 
-ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing;
+ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
+                                                    AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
 ArbBucketContext.MotionActive   := WinchBothMotionActive;
 ArbBucketContext.ReqAscent      := WinchBothReqAscent;
@@ -324,5 +328,5 @@ ArbBucketContext.CoupledPhaseLocked := PRG_03_Modes_Cycle.Data.Auth.CoupledBucke
 
 instArbBucket(
-    Enable    := TRUE,
+    Enable    := NOT PRG_02_Acquisition.Data.MachineHoming.Active,
     Auth      := PRG_03_Modes_Cycle.Data.Auth,
     ReqBucket := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket,
@@ -396,5 +400,7 @@ instBucket(
 // 📌 Note d'architecture (lag 1 scan) : M1/M2LogicRequestDirection est consommé ici avant son calcul arbitré
 // en §3 (lag d'un cycle automate nominal, toléré et homogène avec les arbitrages Translation/Modes).
-WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;
+WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed
+                                 AND NOT instBucket.Lifecycle.Busy
+                                 AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
 BucketNotClosedAscentCapStep1 := NOT ManualBucketJogActive
     AND (M1LogicReqAscent OR M2LogicReqAscent)
@@ -576,4 +582,30 @@ IF PRG_03_Modes_Cycle.Data.Auth.WinchSelTransitionHold THEN
     M2LogicRunRequest := FALSE; M2LogicReqAscent := FALSE; M2LogicReqDescend := FALSE; M2LogicRequestStepTgt := 0;
 END_IF;
+
+// D1/D3/D4/D6 : blocage mouvements libres MAINT_N1 en Step 0 (tant que NOT Homed) + gating directionnel homing
+HomingFreeMoveBlockedN1 := MaintN1
+                           AND NOT PRG_02_Acquisition.Data.MachineHoming.Homed
+                           AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
+IF HomingFreeMoveBlockedN1 THEN
+    M1LogicRunRequest := FALSE; M1LogicReqAscent := FALSE; M1LogicReqDescend := FALSE; M1LogicRequestStepTgt := 0;
+    M2LogicRunRequest := FALSE; M2LogicReqAscent := FALSE; M2LogicReqDescend := FALSE; M2LogicRequestStepTgt := 0;
+ELSIF PRG_02_Acquisition.Data.MachineHoming.Active THEN
+    IF PRG_02_Acquisition.Data.MachineHoming.CmdWinchSelect = 2 THEN
+        M1LogicRunRequest := FALSE; M1LogicReqAscent := FALSE; M1LogicReqDescend := FALSE; M1LogicRequestStepTgt := 0;
+        M2LogicReqAscent  := M2LogicReqAscent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        M2LogicReqDescend := M2LogicReqDescend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+        M2LogicRunRequest := M2LogicRunRequest AND (M2LogicReqAscent OR M2LogicReqDescend);
+    ELSIF PRG_02_Acquisition.Data.MachineHoming.CmdWinchSelect = 0 THEN
+        M1LogicReqAscent  := M1LogicReqAscent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        M1LogicReqDescend := M1LogicReqDescend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+        M1LogicRunRequest := M1LogicRunRequest AND (M1LogicReqAscent OR M1LogicReqDescend);
+        M2LogicReqAscent  := M2LogicReqAscent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        M2LogicReqDescend := M2LogicReqDescend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+        M2LogicRunRequest := M2LogicRunRequest AND (M2LogicReqAscent OR M2LogicReqDescend);
+    ELSE
+        M1LogicRunRequest := FALSE; M1LogicReqAscent := FALSE; M1LogicReqDescend := FALSE; M1LogicRequestStepTgt := 0;
+        M2LogicRunRequest := FALSE; M2LogicReqAscent := FALSE; M2LogicReqDescend := FALSE; M2LogicRequestStepTgt := 0;
+    END_IF;
+END_IF;
 // Diagnostic % (palier→%) pour IHM / simu — borne haute du palier arbitré.
 IF (M2LogicRequestStepTgt >= 1) AND (M2LogicRequestStepTgt <= 5) THEN
@@ -769,5 +801,9 @@ DescendPermitDiveBucketOpen := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.Desc
 ManualBucketLimitsActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits
     AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2)
-    AND NOT PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked;
+    AND NOT PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked
+    AND PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+    AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable
+    AND NOT (PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff
+             AND PRG_02_Acquisition.Data.MachineHoming.Active);
 
 ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
@@ -899,5 +935,7 @@ TopLimitM2_M := SEL(OverrideTopSoftwareN1M2 OR BypassM2TopLimitSoftwareEff,
 // (ManualBucketLimitsActive/anticipation, PRG_04 ~710-735). Le FdC haut MATERIEL
 // (TopPositionSensor, FB_Safety_Winch) reste une barriere INDEPENDANTE et non affectee.
-IF ManualBucketJogActive THEN
+IF ManualBucketJogActive
+   AND PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+   AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable THEN
     TopLimitM2_M := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM
                      + _BucketCfgPersist.Config.OffsetCloseM + 2.0;
@@ -926,4 +964,13 @@ PositionLimitOverriddenM2 := OverrideTopSoftwareN1M2 OR BypassM2TopLimitSwitchEf
 // Instancié avant instWinchM1/M2 : MovementCommanded lit RelayFwd/RelayRev du scan précédent
 // (même lag 1 scan accepté que M4/Translation, jamais sur Reset/SafeStop/PowerCutOff/sortie finale).
+BrakeForceAllowedM1 := MaintN2
+    AND PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI
+    AND PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
+    AND (GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease OR GVL_IHM.MaintenanceN2.Cmd.BtnM1BrakeRelease);
+BrakeForceAllowedM2 := MaintN2
+    AND PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI
+    AND PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
+    AND (GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease OR GVL_IHM.MaintenanceN2.Cmd.BtnM2BrakeRelease);
+
 instSafetyWinchM1(
     Enable                 := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
@@ -932,8 +979,4 @@ instSafetyWinchM1(
     Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
     SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
-    // Ecart critique croise M1/M2 (Meca E, FB_Safety_Winch:354) : gate canonique
-    // SyncOperationPermit (homing/benne -> OFF). N'affecte PAS le routage mou-de-cable
-    // (:508/:520) qui reste sur SyncEnable brut. Le mouvement couple par boutons-both
-    // (WinchBothMotionActive sans WinchSel=0) est un cas residuel -> voir T-tache.
     CrossCheckEnable       := SyncOperationPermit,
     JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
@@ -950,4 +993,7 @@ instSafetyWinchM1(
     TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
     InReferencingMode      := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy,
+    SoftLimitsBypassed     := PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff
+                              AND PRG_02_Acquisition.Data.MachineHoming.Active,
+    BrakeForceAllowed      := BrakeForceAllowedM1,
     CablePosM              := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
     CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
@@ -1019,4 +1065,7 @@ instSafetyWinchM2(
     TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
     InReferencingMode      := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy,
+    SoftLimitsBypassed     := PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff
+                              AND PRG_02_Acquisition.Data.MachineHoming.Active,
+    BrakeForceAllowed      := BrakeForceAllowedM2,
     CablePosM              := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
     CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
@@ -1130,4 +1179,29 @@ IF MaintN2 THEN
 END_IF;
 
+// Si un cycle homing machine est actif (en N1 ou N2), appliquer ses permis par etape
+IF HomingFreeMoveBlockedN1 THEN
+    EffectivePermitM1_Ascent  := FALSE;
+    EffectivePermitM1_Descend := FALSE;
+    EffectivePermitM2_Ascent  := FALSE;
+    EffectivePermitM2_Descend := FALSE;
+ELSIF PRG_02_Acquisition.Data.MachineHoming.Active THEN
+    IF PRG_02_Acquisition.Data.MachineHoming.CmdWinchSelect = 2 THEN
+        EffectivePermitM1_Ascent  := FALSE;
+        EffectivePermitM1_Descend := FALSE;
+        EffectivePermitM2_Ascent  := EffectivePermitM2_Ascent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        EffectivePermitM2_Descend := EffectivePermitM2_Descend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+    ELSIF PRG_02_Acquisition.Data.MachineHoming.CmdWinchSelect = 0 THEN
+        EffectivePermitM1_Ascent  := EffectivePermitM1_Ascent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        EffectivePermitM1_Descend := EffectivePermitM1_Descend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+        EffectivePermitM2_Ascent  := EffectivePermitM2_Ascent  AND PRG_02_Acquisition.Data.MachineHoming.AllowAscent;
+        EffectivePermitM2_Descend := EffectivePermitM2_Descend AND PRG_02_Acquisition.Data.MachineHoming.AllowDescend;
+    ELSE
+        EffectivePermitM1_Ascent  := FALSE;
+        EffectivePermitM1_Descend := FALSE;
+        EffectivePermitM2_Ascent  := FALSE;
+        EffectivePermitM2_Descend := FALSE;
+    END_IF;
+END_IF;
+
 // Permis canoniques benne : ouverture = M2 vers le bas, fermeture = M2 vers le haut.
 // Les fins de course benne restent des faits fonctionnels distincts des limites treuil.
@@ -1198,4 +1272,5 @@ ArmAnyAxisAvail := ArmM1AscentAvail OR ArmM1DescendAvail
 ArmBucketBusy := (instBucket.Lifecycle.Busy OR BenneBusyFallEdge.Q)
                  AND NOT MaintN2
+                 AND NOT PRG_02_Acquisition.Data.MachineHoming.Active
                  AND (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.SEMI_AUTO)
                  AND NOT PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen
@@ -1258,6 +1333,7 @@ MaintenanceMaxStepDescent := 1;
 // SyncDeviationWarn) sont eux-memes inactifs sans reference fiable. Debridage assume
 // plus tard sur capteur haut actif (position redevenue connue).
-IF NOT (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
-        AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable) THEN
+IF PRG_02_Acquisition.Data.MachineHoming.Active
+   OR NOT (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+           AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable) THEN
     CommonMaxStepAscent  := 1;
     CommonMaxStepDescent := 1;
@@ -1337,5 +1413,6 @@ END_IF;
 // si M1/M2 ne sont pas référencés, la position n'a pas de sens → repli palier 1 partout.
 IF ManualBucketJogActive THEN
-    IF NOT (PRG_02_Acquisition.Data.EncoderM1.Homed AND PRG_02_Acquisition.Data.EncoderM2.Homed) THEN
+    IF PRG_02_Acquisition.Data.MachineHoming.Active
+       OR NOT (PRG_02_Acquisition.Data.EncoderM1.Homed AND PRG_02_Acquisition.Data.EncoderM2.Homed) THEN
         M2MaxStepUp   := 1;
         M2MaxStepDown := 1;
@@ -1630,5 +1707,5 @@ WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
 WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
 WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;
-WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff AND NOT MaintN2;
+WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;
 WinchM1FinalInterlockRequest.AscentPermit := EffectivePermitM1_Ascent;
 WinchM1FinalInterlockRequest.DescendPermit := EffectivePermitM1_Descend;
@@ -1651,5 +1728,5 @@ WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
 WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
 WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;
-WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff AND NOT MaintN2;
+WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;
 WinchM2FinalInterlockRequest.AscentPermit := M2AscentPermitApplied;
 WinchM2FinalInterlockRequest.DescendPermit := M2DescendPermitApplied;
diff --git a/CODE/M_MAIN/PRG_06_Outputs.st b/CODE/M_MAIN/PRG_06_Outputs.st
index ae09da83..4e4b26a3 100644
--- a/CODE/M_MAIN/PRG_06_Outputs.st
+++ b/CODE/M_MAIN/PRG_06_Outputs.st
@@ -260,5 +260,7 @@ M2BrakeCmd        := M2RelayFwd OR M2RelayRev;
 WinchOutputCoupled := (PRG_04_Treuils_Benne.Data.SyncState.SyncActive
                        OR PRG_03_Modes_Cycle.Data.WinchBothIntent.Active)
-                      AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
+                      AND NOT (PRG_02_Acquisition.Data.MachineHoming.Active
+                               AND ((PRG_02_Acquisition.Data.MachineHoming.SeqStep = 1)
+                                    OR (PRG_02_Acquisition.Data.MachineHoming.SeqStep = 4)));
 
 // Frein = OR des relais de sens GATES (jamais desserre sans un sens valide).

`
