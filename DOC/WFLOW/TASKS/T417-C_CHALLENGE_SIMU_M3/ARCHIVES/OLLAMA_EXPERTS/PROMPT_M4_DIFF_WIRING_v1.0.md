Tu es un expert senior automatisme industriel CODESYS 3.5 / IEC 61131-3 ST & securite machine ISO 13849.
Audite ce git diff reel de la refonte du GRAFCET Homing Machine 5 etapes (D1-D7, T417-C).
Verifie STRICTEMENT :
1. D1-D7 : HX0 repos N1 (BP joy relache puis 5s neutre) + N2 (BtnStart), verrou absolu si MachineHomed ; M3 verrouille des HX0 en N1/SEMI avec echappatoire N2 ; HX1 M2 sans soft limits 20s continu + neutre+BP ; HX2 couple 2s detente cable strict neutre + TOP coupe montee sans preset -> HX3 ; HX3 zero montee, 4s descente accumulee apres relachement TOP -> HX1 ; HX4 zero mouvement, NOT TOP, preset 8.5m M1 + (8.5+Offset) M2, attente HomingDone & NOT HomingBusy -> CommitClose -> HX0.
2. Aucun blocage silencieux, aucune variable non initialisee, aucun bug de scan IEC (TON, fronts, 1-scan glitch), conformite CODESYS V3.5 (chaines ASCII sans accents, types stricts).
Reponds de facon ultra-factuelle avec uniquement les bugs/risques reels (fichier:ligne + scenario causal) ou VERDICT CLEAN si aucun bug critique/majeur.

`diff
diff --git a/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st b/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
index 7091b5e5..0cac3ced 100644
--- a/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
+++ b/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
@@ -413,7 +413,7 @@ END_IF;
 //    chargement effacerait la ref a tort ; CfgFault bloque deja ActiveOffsetValid LIVE.
 //  - HomingSuspect n'est pose qu'apres le controle de coherence au demarrage (bus up) ->
 //    pas de faux positif pendant l'enum EtherCAT. Aucun redemarrage auto : re-confirmer.
-TonDatumUnreliable(IN := HomingSuspectM1 OR HomingSuspectM2, PT := T#2s);
+TonDatumUnreliable(IN := HomingSuspectM1 OR HomingSuspectM2 OR NOT HomedM1 OR NOT HomedM2, PT := T#2s);
 IF TonDatumUnreliable.Q THEN
     BucketState.BucketReferenced := FALSE;
 END_IF;
@@ -469,35 +469,36 @@ IF SevereError THEN
     Lifecycle.Busy := FALSE;
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
         M2_ReqDescend := FALSE;
         M2_BucketJogLimit := FALSE;
         CloseReq := FALSE;
         OpenReq := FALSE;
+        CloseReached := FALSE;
         Lifecycle.Busy := FALSE;
         Lifecycle.Done := FALSE;
     END_IF;
 
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
 
     // Armement de la manoeuvre : uniquement HORS manoeuvre deja engagee.
diff --git a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
index eea649de..c474c900 100644
--- a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
+++ b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
@@ -37,7 +37,9 @@ VAR_INPUT
     OtherWinchInhibited             : BOOL;                           // --> [HW] Autre treuil inhibe (maintenance)
 
     // === REGLAGES ET LIMITES SÉCURITÉ ===
-    InReferencingMode               : BOOL;                           // --> [CFG] Treuil en cours de homing
+    InReferencingMode               : BOOL;                           // --> [CFG] Transaction preset SDO codeur active
+    SoftLimitsBypassed              : BOOL := FALSE;                  // --> [CFG] Inhibe uniquement les butees soft (HX1..HX3), jamais TOP ni Meca D
+    BrakeForceAllowed               : BOOL := FALSE;                  // --> [CFG] Desserrage frein volontaire N2 (inhibe faux Meca B)
     CablePosM                       : REAL;                           // --> [CFG] Position actuelle cable (m)
     CfgCableLimitDescentM           : REAL;                           // --> [CFG] Limite basse physique descente (m)
     LimitLegalReached               : BOOL;                           // --> [CFG] Limite legale de profondeur atteinte
@@ -316,7 +318,7 @@ IF NOT BypassGlobal THEN
     instCauses[5].Texte    := 'Fin de course haut capteur atteint';
 
     // Cause 6 : Limite max câble descente (live)
-    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
+    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND Homed AND NOT HomingSuspect AND NOT SoftLimitsBypassed AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
         instCauses[6].Active := TRUE;
     ELSE
         instCauses[6].Active := FALSE;
@@ -338,7 +340,7 @@ IF NOT BypassGlobal THEN
 
     // Cause 8 : Méca B absence confirmation arrêt (latched)
     IF NOT (BypassSafety OR BypassMecaB) THEN
-        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
+        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT BrakeForceAllowed AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
         IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;
     ELSE
@@ -376,6 +378,7 @@ IF NOT BypassGlobal THEN
     IF NOT (BypassSafety OR BypassMecaD) THEN
         UncommandedActiveD := NOT (BenneBusy OR BenneHoldStillActive)
             AND NOT TopPositionSensor AND NOT InReferencingMode
+            AND NOT (ReqDescend AND NOT ReqAscent)
             AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaD(IN := UncommandedActiveD, PT := PostRampTimeout);
         IF TonMecaD.Q THEN MecaDFaultLatched := TRUE; END_IF;
@@ -562,7 +565,7 @@ END_IF;
 
 DescendPermit := NOT (
     ((CauseCableLimitActive OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
-    OR ((CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode AND NOT BypassCableLimitSwitch)
+    OR (Homed AND NOT HomingSuspect AND NOT SoftLimitsBypassed AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode AND NOT BypassCableLimitSwitch)
     // La limite légale est une interdiction d'exploitation distincte du groupe
     // SafeStop/Permit. Le bypass banc BypassProcess ne doit jamais la lever :
     // seul le bypass dédié BypassLimitLegal, déjà filtré par la matrice MAINT_N2
@@ -578,7 +581,7 @@ AscentPermit := NOT (
     // TopLimitM porte la relaxation 7,5->8,5 m en override N1 / bypass N2 : la butee
     // logicielle reste active a la valeur relevee. Bypasser le logiciel releve la butee,
     // il ne la supprime pas ; le FDC haut materiel reste une barriere independante.
-    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
+    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND NOT SoftLimitsBypassed AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
 );
 
 PowerCutOff := CausesPowerCutOffActive;
diff --git a/CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st b/CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
index c99a23af..2d93d65b 100644
--- a/CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
+++ b/CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
@@ -24,6 +24,12 @@ VAR_INPUT
     CycleChecksInhibited : BOOL;   // --> [TST] Mode essai cycle : controles procede inhibes
     MachineHomingStep        : INT;   // --> [HW] Étape guide homing machine (E_MachineHomingStep : 0..70, 60 = valide)
     MachineHomingInstruction : STRING(120);   // --> [HW] Consigne opérateur en clair produite par FB_CycleMachineHoming
+    MachineHomingFailed      : BOOL := FALSE; // --> [DIAG] Echec ou abandon cycle homing machine
+    WinchM1Error             : BOOL := FALSE; // --> [DIAG] Defaut commande/barriere treuil M1 (FB_Winch/Interlock)
+    WinchM2Error             : BOOL := FALSE; // --> [DIAG] Defaut commande/barriere treuil M2 (FB_Winch/Interlock)
+    EncoderM1Fault           : BOOL := FALSE; // --> [DIAG] Defaut codeur M1
+    EncoderM2Fault           : BOOL := FALSE; // --> [DIAG] Defaut codeur M2
+    JoystickLatchedFault     : BOOL := FALSE; // --> [DIAG] Defaut joystick latche
 
     // 🛡️ Dérogations & particularités
     BypassGlobalActive   : BOOL;   // --> [TST] Bypass global
@@ -1195,6 +1201,26 @@ IF ((CycleErrorId AND 16#0800) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) T
     AlarmArray[AlarmCount] := '[CYCLE] ErrorID:12 - consigne profondeur invalide'; AlarmCount := AlarmCount + 1;
 END_IF;
 
+// 5h-bis. Collecte — defauts homing / commande treuils / codeurs / joystick / AU global
+IF MachineHomingFailed AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[HOMING] Echec ou abandon referencement machine - Reset'; AlarmCount := AlarmCount + 1;
+END_IF;
+IF WinchM1Error AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[M1] Defaut commande ou barriere finale treuil'; AlarmCount := AlarmCount + 1;
+END_IF;
+IF WinchM2Error AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[M2] Defaut commande ou barriere finale treuil'; AlarmCount := AlarmCount + 1;
+END_IF;
+IF EncoderM1Fault AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[CODEUR] Defaut codeur treuil M1'; AlarmCount := AlarmCount + 1;
+END_IF;
+IF EncoderM2Fault AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[CODEUR] Defaut codeur treuil M2'; AlarmCount := AlarmCount + 1;
+END_IF;
+IF JoystickLatchedFault AND (AlarmCount < CST_NbMaxAlarmes) THEN
+    AlarmArray[AlarmCount] := '[JOYSTICK] Defaut joystick latche - Reset'; AlarmCount := AlarmCount + 1;
+END_IF;
+
 // 5i. Collecte [HISTO] — défauts latched passés (LatchedId AND NOT ErrorId)
 // 🕘 Marqueur [HISTO] (AF-07 §6, décision 2026-09-01) : un défaut laté dont la cause a
 //    disparu (bit LatchedId=1 ET bit ErrorId=0) reste affiché préfixé [HISTO] tant qu'il
diff --git a/CODE/L_SIMULATION/FB_SimBench.st b/CODE/L_SIMULATION/FB_SimBench.st
index 326c1d36..35c7c923 100644
--- a/CODE/L_SIMULATION/FB_SimBench.st
+++ b/CODE/L_SIMULATION/FB_SimBench.st
@@ -149,6 +149,7 @@ VAR_INPUT
     // ── Rattrapage mécanique M1/M2 (reprise de jeu en mouvement couplé) ──
     SimWinchCouplingModelActive : BOOL := TRUE;    (* --> [CFG] TRUE = rattrapage mécanique modélisé au banc *)
     SimBucketJamActive          : BOOL := FALSE;   (* --> [TST] TRUE = mâchoires bloquées (objet coincé) *)
+    WinchesHomed                : BOOL := TRUE;    (* --> [HW] TRUE = M1 et M2 references (butee meca benne inactive avant homing) *)
     M2_CablePos_M               : REAL := 0.0;     (* --> [HW] Position M2 recalée (m), issue de la même chaîne que le métier *)
     BucketOffsetCloseM          : REAL := 15.0;    (* --> [CFG] Butée mécanique benne FERMÉE (m, écart M2-M1) *)
     BucketCoherenceLimitM       : REAL := 1.0;     (* --> [CFG] Demi-largeur de la bande franc ouvert/fermé (m) *)
@@ -493,6 +494,7 @@ END_IF;
 // N'arrête M2 que s'il est commandé SEUL vers la butée (ouverture sous BucketOffsetOpen_M
 // ou fermeture au-dessus de BucketOffsetCloseM).
 M2_MechanicStopEngaged := SimWinchCouplingModelActive
+                          AND WinchesHomed
                           AND (((M2_CablePos_M - M1_CablePos_M) <= (BucketOffsetOpen_M - 0.40) AND M2_RelayRev AND NOT M1_RelayRev)
                                OR ((M2_CablePos_M - M1_CablePos_M) >= BucketOffsetCloseM AND M2_RelayFwd AND NOT M1_RelayFwd));
 
diff --git a/CODE/M_MAIN/PRG_02_Acquisition.st b/CODE/M_MAIN/PRG_02_Acquisition.st
index c1b23113..fd8afad6 100644
--- a/CODE/M_MAIN/PRG_02_Acquisition.st
+++ b/CODE/M_MAIN/PRG_02_Acquisition.st
@@ -353,6 +353,7 @@ instSimBench(
     // Rattrapage mecanique M1/M2 : reprise de jeu en montee couplee (banc uniquement).
     SimWinchCouplingModelActive := GVL_Simulation.SimWinchCouplingModelActive,
     SimBucketJamActive       := GVL_Simulation.SimBucketJamActive,
+    WinchesHomed             := Data.EncoderM1.Homed AND Data.EncoderM2.Homed,
     M2_CablePos_M            := Data.EncoderM2.Measurement.CablePosM,
     BucketOffsetCloseM       := _BucketCfgPersist.Config.OffsetCloseM,
     BucketCoherenceLimitM    := _BucketCfgPersist.Config.CoherenceLimitM,
@@ -599,18 +600,18 @@ instCycleMachineHoming(
     // simple coupure secteur si le datum absolu M1/M2 est intact.
     BucketOffsetValid          := PRG_04_Treuils_Benne.Data.BucketState.MechState.BucketReferenced,
     // Permis operateur maintenu (meme source que l'arbitrage joystick) : sens montee = manche
-    // tire (Y+), sens descente = manche pousse (Y-) ; ref. baseline continuite C1.
+    // tire (Y+), sens descente = manche pousse (Y-) ; BP brut transmis pour entree HX0 N1 (5 s).
     DeadmanArmed               := Data.Joystick.DeadmanArmed,
+    RawDeadmanButton           := HwIn.Operator.JoyBtnRaw,
     JoystickDeflected          := NOT Data.Joystick.AtNeutralXY,
     JoystickPull               := Data.Joystick.AxisY.DirectionPositive,
     JoystickPush               := Data.Joystick.AxisY.DirectionNegative,
-    // Lancer / valider le cycle : commande IHM dediee UNIQUEMENT (le BP homme-mort
-    // brut du joystick ne peut plus lancer/valider le cycle ; garde manche-neutre cote FB HX0).
+    // Lancer / valider le cycle : commande IHM dediee
     BtnValidation              := GVL_IHM.CycleMachineHoming.Cmd.BtnValidate,
     StartRequest               := GVL_IHM.CycleMachineHoming.Cmd.BtnStart,
-    // Confirmation visuelle benne fermee (nouveau bouton dedie IHM HX1)
+    // Confirmation visuelle benne (compat bouton historique)
     BtnConfirmHomingBucket     := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmHomingBucket,
-    // Interlock couplage E1 et mesures pour controle stabilisation HX4
+    // Interlock couplage E1 et mesures
     JoystickWinchSelectArbitrated := PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated,
     CablePosM1                 := Data.EncoderM1.Measurement.CablePosM,
     CablePosM2                 := Data.EncoderM2.Measurement.CablePosM,
@@ -635,6 +636,9 @@ Data.MachineHoming.CmdWinchM2       := instCycleMachineHoming.CmdWinchM2;
 Data.MachineHoming.CmdBucketOpen    := instCycleMachineHoming.CmdBucketOpen;
 Data.MachineHoming.CmdBucketClose   := instCycleMachineHoming.CmdBucketClose;
 Data.MachineHoming.CmdWinchSelect   := instCycleMachineHoming.CmdWinchSelect;
+Data.MachineHoming.AllowAscent      := instCycleMachineHoming.AllowAscent;
+Data.MachineHoming.AllowDescend     := instCycleMachineHoming.AllowDescend;
+Data.MachineHoming.SoftLimitsOff    := instCycleMachineHoming.SoftLimitsOff;
 HwInM1.RawPosIn          := HwIn.Winch.COD1_PosValue;
 HwInM1.SpdValueIn        := HwIn.Winch.COD1_SpdValue;
 HwInM1.AlarmsIn          := HwIn.Winch.COD1_Alarms;
@@ -644,14 +648,11 @@ HwInM1.PresetStatusBit    := FALSE;
 instEncoderM1(
     Enable                := TRUE,
     Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
-    // Homing unitaire M1 : autorise en MAINT_N1/N2 quel que soit WinchSel (0/1/2).
-    // L'ancien verrou croise WinchSel<>2 est retire (demande MES) : le homing est un
-    // appui bouton delibere ET conditionne a une position de reference (butee meca OK,
-    // ou capteur haut atteint pour BtnHome) -> la garde position suffit. Le cycle homing
-    // machine reste inconditionnel via M1Demand.HomeReq.
-    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
-                               AND (MachineHomingMechanicalStopOk OR (NOT GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero
-                                                                       AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
+    // Homing unitaire M1 : autorise en MAINT_N2 uniquement (BtnHomingAtZero a l'arret ou BtnHome au capteur haut).
+    // Le cycle machine (instCycleMachineHoming.M1Demand.HomeReq) reste autorise en N1/N2 via cible dynamique Step 4.
+    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
+                               AND ((GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero AND MachineHomingMechanicalStopOk)
+                                    OR (GVL_IHM.M1TreuilRetenue.Cmd.BtnHome AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
                               OR instCycleMachineHoming.M1Demand.HomeReq),
     HomingAtTargetM       := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome
                              OR GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero
@@ -661,8 +662,8 @@ instEncoderM1(
     CfgHomingTargetM      := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
                                  _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
     CfgTopSensorPosM      := _WinchM1CfgPersist.CfgTopSensorPos_M,
-    UseDynamicTarget      := FALSE,
-    DynamicHomingTargetM  := 0.0,
+    UseDynamicTarget      := instCycleMachineHoming.M1Demand.UseDynamicTarget,
+    DynamicHomingTargetM  := instCycleMachineHoming.M1Demand.DynamicTarget_M,
     TopPositionSensor     := NOT HwIn.Winch.M1M2_TopPositionFree_DI,
     HwIn                  := HwInM1,
     PointsPerRev          := ENCODER_POINTS_PER_REV,
@@ -699,12 +700,10 @@ HwInM2.PresetStatusBit    := FALSE;
 instEncoderM2(
     Enable                := TRUE,
     Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
-    // Homing unitaire M2 (benne) : autorise en MAINT_N1/N2 quel que soit WinchSel (0/1/2).
-    // L'ancien verrou croise WinchSel<>1 est retire (demande MES) : meme raisonnement que
-    // M1 ci-dessus. Permet notamment le homing benne en mode benne WinchSel=2.
-    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
-                               AND (MachineHomingMechanicalStopOk OR (NOT GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero
-                                                                       AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
+    // Homing unitaire M2 (benne) : autorise en MAINT_N2 uniquement (benne / zero / capteur haut).
+    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
+                               AND (((GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero OR BucketReferenceRequested) AND MachineHomingMechanicalStopOk)
+                                    OR (GVL_IHM.M2TreuilBenne.Cmd.BtnHome AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
                               OR instCycleMachineHoming.M2Demand.HomeReq),
     HomingAtTargetM       := GVL_IHM.M2TreuilBenne.Cmd.BtnHome
                              OR GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero
diff --git a/CODE/M_MAIN/PRG_03_Modes_Cycle.st b/CODE/M_MAIN/PRG_03_Modes_Cycle.st
index a83530c2..c8547a19 100644
--- a/CODE/M_MAIN/PRG_03_Modes_Cycle.st
+++ b/CODE/M_MAIN/PRG_03_Modes_Cycle.st
@@ -74,11 +74,14 @@ CycleDrainTimeEffective := DINT_TO_TIME(INT_TO_DINT(CycleDrainTimeEffective_S) *
 // 📄 Événement changement de page IHM : sélection automatique du mode (provisoire sans mdp :
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
     PrevActualPage := GVL_IHM.LocalIHM.StatusBlock.StatusInt01_ActualPage;
@@ -113,12 +116,14 @@ instModes(
     EncoderFaultPresent     := (PRG_02_Acquisition.HwIn.Winch.COD1_DeviceState <> DEVICE_STATE.RUNNING) OR (PRG_02_Acquisition.HwIn.Winch.COD2_DeviceState <> DEVICE_STATE.RUNNING),
     JoystickWinchSelectRequest := EffectiveWinchSelectRequest,
     SelMaintenanceZoneAccess := GVL_IHM.M3Translation.Cmd.TglMaintenanceZoneAccess,
-    // T248 — sequencement auto benne en couple (force temporairement le sel. a 2)
-    CoupledBucketSeqEnable  := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing,
-    // Stabiliser M3AtTremie via M3_AtTremieStable (et zone PV si ouverture anticipee active) pour maintenir la garde benne
-    M3AtTremie              := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
-                               OR PRG_05_Translation.Data.M3_AtTremieStable
-                               OR (GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV AND PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI),
+    // T248 — sequencement auto benne en couple inhibe pendant homing machine
+    CoupledBucketSeqEnable  := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
+                               AND NOT PRG_02_Acquisition.Data.MachineHoming.Active,
+    // Stabiliser M3AtTremie via M3_AtTremieStable ; neutralise pendant homing machine (D7)
+    M3AtTremie              := (PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
+                                OR PRG_05_Translation.Data.M3_AtTremieStable
+                                OR (GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV AND PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI))
+                               AND NOT PRG_02_Acquisition.Data.MachineHoming.Active,
     AllowWinchMoveAtTremie  := GVL_IHM.M3Translation.Cmd.TglAllowWinchMoveAtTremie,
     JoystickPull            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive,
     JoystickPush            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionNegative,
@@ -350,9 +355,9 @@ Data.Auth := instModes.Auth;
 Data.ModesFault := instModes.Fault;
 
 // 1bis. Intention both continue opérateur (inconditionnelle, TOUS modes) — source unique
-Data.WinchBothIntent.Active    := WinchBothMotionActive;
-Data.WinchBothIntent.ReqAscent  := WinchBothMotionDirection > 0;
-Data.WinchBothIntent.ReqDescend := WinchBothMotionDirection < 0;
+Data.WinchBothIntent.Active     := WinchBothMotionActive;
+Data.WinchBothIntent.ReqAscent  := WinchBothMotionActive AND (WinchBothMotionDirection > 0);
+Data.WinchBothIntent.ReqDescend := WinchBothMotionActive AND (WinchBothMotionDirection < 0);
 
 // 2. Demandes programme et état public de séquence
 IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
@@ -453,7 +458,7 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     // M1+M2 palier 1 (HX2 montee / HX3 descente). Le FB gate deja sur permis operateur
     // maintenu (homme-mort + joystick) et ne commande qu'en HX2/HX3 ; PRG_04 conserve
     // ses interlocks maintenance. Copie struct entiere (ST_ProgramWinchRequest).
-    IF instModes.Auth.Mode = E_Mode.MAINT_N2
+    IF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
        AND PRG_02_Acquisition.Data.MachineHoming.Active THEN
         Data.ReqProgram.ReqWinchM1 := PRG_02_Acquisition.Data.MachineHoming.CmdWinchM1;
         Data.ReqProgram.ReqWinchM2 := PRG_02_Acquisition.Data.MachineHoming.CmdWinchM2;
@@ -481,10 +486,10 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     // Mutuellement exclusifs cote FB. Route OVERRIDE (pas un OR) quand le cycle homing est
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
 
     // États de séquence — assistants FB_DiveSearch/FB_ExtractionAssist retires : neutre.
@@ -533,6 +538,7 @@ ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAI
     // Le mot capteurs reste une information de zone et n'autorise pas la descente.
     Data.SequenceState.WinchDescentAuth_M3     :=
         (instModes.Auth.Mode = E_Mode.MAINT_N2)
+        OR PRG_02_Acquisition.Data.MachineHoming.Active
         OR NOT GVL_IHM.Commun.Cfg.TglEnableWinchDescentLock_M3
         OR GVL_IHM.M3Translation.State.AtP1
         OR GVL_IHM.M3Translation.State.AtMaintenance
diff --git a/CODE/M_MAIN/PRG_04_Treuils_Benne.st b/CODE/M_MAIN/PRG_04_Treuils_Benne.st
index dcd9b0fd..790bf18c 100644
--- a/CODE/M_MAIN/PRG_04_Treuils_Benne.st
+++ b/CODE/M_MAIN/PRG_04_Treuils_Benne.st
@@ -270,6 +270,9 @@ VAR
     // Usage effectif d'un override/bypass de position -> arme le re-homing obligatoire (PRG_03).
     PositionLimitOverriddenM1 : BOOL;
     PositionLimitOverriddenM2 : BOOL;
+    BrakeForceAllowedM1       : BOOL;
+    BrakeForceAllowedM2       : BOOL;
+    HomingFreeMoveBlockedN1   : BOOL;
 
     // 🕵️ Trace de blocage terrain (§8bis) — publiée via Data.TraceM1/M2, consommée FB_TroubleshootingView
     TraceM1               : ST_TraceWinch;        // . [LOC] Trace blocage treuil M1
@@ -314,7 +317,8 @@ ManualBucketJogActive := (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitr
 ArbBucketIHM.BtnOpen  := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen;
 ArbBucketIHM.BtnClose := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
 
-ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing;
+ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
+                                                    AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
 ArbBucketContext.MotionActive   := WinchBothMotionActive;
 ArbBucketContext.ReqAscent      := WinchBothReqAscent;
 ArbBucketContext.ReqDescend     := WinchBothReqDescend;
@@ -323,7 +327,7 @@ ArbBucketContext.BucketIsClosed := _BucketState.IsClosed;
 ArbBucketContext.CoupledPhaseLocked := PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked;
 
 instArbBucket(
-    Enable    := TRUE,
+    Enable    := NOT PRG_02_Acquisition.Data.MachineHoming.Active,
     Auth      := PRG_03_Modes_Cycle.Data.Auth,
     ReqBucket := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket,
     IHM       := ArbBucketIHM,
@@ -395,7 +399,9 @@ instBucket(
 // protégeant ainsi la mécanique même en pilotage unitaire ou si l'auto-séquencement est désactivé.
 // 📌 Note d'architecture (lag 1 scan) : M1/M2LogicRequestDirection est consommé ici avant son calcul arbitré
 // en §3 (lag d'un cycle automate nominal, toléré et homogène avec les arbitrages Translation/Modes).
-WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;
+WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed
+                                 AND NOT instBucket.Lifecycle.Busy
+                                 AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
 BucketNotClosedAscentCapStep1 := NOT ManualBucketJogActive
     AND (M1LogicReqAscent OR M2LogicReqAscent)
     AND NOT instBucket.Lifecycle.Busy
@@ -575,6 +581,32 @@ IF PRG_03_Modes_Cycle.Data.Auth.WinchSelTransitionHold THEN
     M1LogicRunRequest := FALSE; M1LogicReqAscent := FALSE; M1LogicReqDescend := FALSE; M1LogicRequestStepTgt := 0;
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
     M2LogicRequestSpeedCmd_Pct := _WinchSpeedStepTable.StepThreshold_Pct[M2LogicRequestStepTgt];
@@ -768,7 +800,10 @@ DescendPermitDiveBucketOpen := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.Desc
 // instWinchM2 §6 plus bas).
 ManualBucketLimitsActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits
     AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2)
-    AND NOT PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked;
+    AND NOT PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked
+    AND PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+    AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable
+    AND NOT PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff;
 
 ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
 // Phase JOG du séquencement benne-auto couplé (CoupledBucketPhaseLocked ET Arbitrated=2) :
@@ -898,7 +933,9 @@ TopLimitM2_M := SEL(OverrideTopSoftwareN1M2 OR BypassM2TopLimitSoftwareEff,
 // a M1 courant (OffsetCloseM + marge) : c'est deja le vrai limiteur mecanique de la benne
 // (ManualBucketLimitsActive/anticipation, PRG_04 ~710-735). Le FdC haut MATERIEL
 // (TopPositionSensor, FB_Safety_Winch) reste une barriere INDEPENDANTE et non affectee.
-IF ManualBucketJogActive THEN
+IF ManualBucketJogActive
+   AND PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+   AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable THEN
     TopLimitM2_M := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM
                      + _BucketCfgPersist.Config.OffsetCloseM + 2.0;
 ELSIF WinchBothMotionActive AND NOT (OverrideTopSoftwareN1M2 OR BypassM2TopLimitSoftwareEff) THEN
@@ -925,16 +962,21 @@ PositionLimitOverriddenM2 := OverrideTopSoftwareN1M2 OR BypassM2TopLimitSwitchEf
 // FB_Safety_Winch M1/M2.
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
     Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
     PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
     Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
     SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
-    // Ecart critique croise M1/M2 (Meca E, FB_Safety_Winch:354) : gate canonique
-    // SyncOperationPermit (homing/benne -> OFF). N'affecte PAS le routage mou-de-cable
-    // (:508/:520) qui reste sur SyncEnable brut. Le mouvement couple par boutons-both
-    // (WinchBothMotionActive sans WinchSel=0) est un cas residuel -> voir T-tache.
     CrossCheckEnable       := SyncOperationPermit,
     JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
     JoystickOperational    := PRG_02_Acquisition.Data.Network.Joystick.Operational,
@@ -949,6 +991,8 @@ instSafetyWinchM1(
     // FALSE = FdC haut atteint ou rupture de chaîne ; le FB bloque alors la montée.
     TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
     InReferencingMode      := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy,
+    SoftLimitsBypassed     := PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff,
+    BrakeForceAllowed      := BrakeForceAllowedM1,
     CablePosM              := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
     CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
     LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
@@ -1018,6 +1062,8 @@ instSafetyWinchM2(
     // Même contact NC que M1 : TRUE = FdC haut libre, FALSE = FdC atteint/chaîne ouverte.
     TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
     InReferencingMode      := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy,
+    SoftLimitsBypassed     := PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff,
+    BrakeForceAllowed      := BrakeForceAllowedM2,
     CablePosM              := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
     CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
     LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
@@ -1129,6 +1175,31 @@ IF MaintN2 THEN
                                  AND (PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI OR BypassM2TopLimitSwitchEff);
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
 EffectivePermitBucket_Open := EffectivePermitM2_Descend
@@ -1197,6 +1268,7 @@ ArmAnyAxisAvail := ArmM1AscentAvail OR ArmM1DescendAvail
 // doit pouvoir armer l'homme-mort (DeadmanArmed) pour autoriser le mouvement benne !
 ArmBucketBusy := (instBucket.Lifecycle.Busy OR BenneBusyFallEdge.Q)
                  AND NOT MaintN2
+                 AND NOT PRG_02_Acquisition.Data.MachineHoming.Active
                  AND (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.SEMI_AUTO)
                  AND NOT PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen
                  AND NOT PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose;
@@ -1257,8 +1329,9 @@ MaintenanceMaxStepDescent := 1;
 // palier 5 accessible non reference : les caps de position (SlowdownMaxStep,
 // SyncDeviationWarn) sont eux-memes inactifs sans reference fiable. Debridage assume
 // plus tard sur capteur haut actif (position redevenue connue).
-IF NOT (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
-        AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable) THEN
+IF PRG_02_Acquisition.Data.MachineHoming.Active
+   OR NOT (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
+           AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable) THEN
     CommonMaxStepAscent  := 1;
     CommonMaxStepDescent := 1;
 END_IF;
@@ -1336,7 +1409,8 @@ END_IF;
 // = fermeture, descente M2 = ouverture. Les zones sont calculées sur la position :
 // si M1/M2 ne sont pas référencés, la position n'a pas de sens → repli palier 1 partout.
 IF ManualBucketJogActive THEN
-    IF NOT (PRG_02_Acquisition.Data.EncoderM1.Homed AND PRG_02_Acquisition.Data.EncoderM2.Homed) THEN
+    IF PRG_02_Acquisition.Data.MachineHoming.Active
+       OR NOT (PRG_02_Acquisition.Data.EncoderM1.Homed AND PRG_02_Acquisition.Data.EncoderM2.Homed) THEN
         M2MaxStepUp   := 1;
         M2MaxStepDown := 1;
     ELSE
@@ -1629,7 +1703,7 @@ WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
 WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
 WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
 WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;
-WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff AND NOT MaintN2;
+WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;
 WinchM1FinalInterlockRequest.AscentPermit := EffectivePermitM1_Ascent;
 WinchM1FinalInterlockRequest.DescendPermit := EffectivePermitM1_Descend;
 
@@ -1650,7 +1724,7 @@ WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
 WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
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
@@ -259,7 +259,9 @@ M2BrakeCmd        := M2RelayFwd OR M2RelayRev;
 // volontairement de ~15 m -> faux ContactorMismatch -> escalade MecaE bit13 / PowerCutOff).
 WinchOutputCoupled := (PRG_04_Treuils_Benne.Data.SyncState.SyncActive
                        OR PRG_03_Modes_Cycle.Data.WinchBothIntent.Active)
-                      AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;
+                      AND NOT (PRG_02_Acquisition.Data.MachineHoming.Active
+                               AND ((PRG_02_Acquisition.Data.MachineHoming.SeqStep = 1)
+                                    OR (PRG_02_Acquisition.Data.MachineHoming.SeqStep = 4)));
 
 // Frein = OR des relais de sens GATES (jamais desserre sans un sens valide).
 M1BrakeCmd := M1RelayFwd OR M1RelayRev;
diff --git a/CODE/M_MAIN/PRG_07_Supervision.st b/CODE/M_MAIN/PRG_07_Supervision.st
index f809ed73..1c661ef1 100644
--- a/CODE/M_MAIN/PRG_07_Supervision.st
+++ b/CODE/M_MAIN/PRG_07_Supervision.st
@@ -383,15 +383,9 @@ SimBypassRise(CLK := SimulationBypassEffective);
 SimBypassFall(CLK := SimulationBypassEffective);
 
 IF SimBypassRise.Q THEN
-    // 🧪 Bypass sim étendu aux tests Meca (Meca A-E via Safety ; NoMovement/
-    // OppositeDir via Process) pour travailler sans faux blocage en banc.
-    // Les trois limites banc demandées sont écrites depuis leur producteur unique.
-    // Elles restent strictement inertes hors SimulationBypassEffective.
-    GVL_IHM.M1TreuilRetenue.Bypass.Safety  := TRUE;
+    // Bypass sim banc limite a Process + FDC logiciel/bas ; TopLimitSwitch et Safety (Meca D) restent actifs.
     GVL_IHM.M1TreuilRetenue.Bypass.Process := TRUE;
-    GVL_IHM.M2TreuilBenne.Bypass.Safety    := TRUE;
     GVL_IHM.M2TreuilBenne.Bypass.Process   := TRUE;
-    GVL_IHM.Commun.Bypass.TopLimitSwitch   := TRUE;
     GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE;
     GVL_IHM.Commun.Bypass.CableLimitSwitch := TRUE;
 END_IF;
@@ -610,12 +604,29 @@ GVL_IHM.Emergency.State.OperatorMessage := PRG_06_Outputs.EmergencyOperatorMessa
 // OR avec les défauts d'arbitrage de mode (refus Semi-Auto, bascule de mode refusée) —
 // publiés par PRG_03 : sans eux ces refus restaient silencieux pour l'opérateur.
 GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs.EmergencyDiag.Error
+                                      OR PRG_06_Outputs.EmergencyFault.Error
+                                      OR PRG_06_Outputs.EmergencyFault.Latched
                                       OR PRG_02_Acquisition.Data.InputModules.Fault
+                                      OR PRG_02_Acquisition.Data.MachineHoming.Failed
+                                      OR PRG_02_Acquisition.Data.EncoderM1.Fault.Error
+                                      OR PRG_02_Acquisition.Data.EncoderM2.Fault.Error
+                                      OR PRG_02_Acquisition.Data.Joystick.Fault.Latched
                                       OR PRG_03_Modes_Cycle.Data.ModesFault.Error
                                       OR PRG_03_Modes_Cycle.Data.ModesFault.Latched
                                       OR GVL_IHM.M1TreuilRetenue.Safety.Error
+                                      OR GVL_IHM.M1TreuilRetenue.Safety.ErrorOverspeed
+                                      OR (GVL_IHM.M1TreuilRetenue.Safety.LatchedId <> 16#0000)
+                                      OR GVL_IHM.M1TreuilRetenue.State.Error
+                                      OR GVL_IHM.M1TreuilRetenue.State.FinalInterlockError
                                       OR GVL_IHM.M2TreuilBenne.Safety.Error
+                                      OR GVL_IHM.M2TreuilBenne.Safety.ErrorOverspeed
+                                      OR (GVL_IHM.M2TreuilBenne.Safety.LatchedId <> 16#0000)
+                                      OR GVL_IHM.M2TreuilBenne.State.Error
+                                      OR GVL_IHM.M2TreuilBenne.State.FinalInterlockError
                                       OR GVL_IHM.M3Translation.Safety.Error
+                                      OR (GVL_IHM.M3Translation.Safety.LatchedId <> 16#0000)
+                                      OR GVL_IHM.M3Translation.State.Error
+                                      OR GVL_IHM.M3Translation.State.FinalInterlockError
                                       OR GVL_IHM.M1M2Sync.State.Error
                                       OR GVL_IHM.M2TreuilBenne.Bucket.State.Error
                                       OR GVL_IHM.CycleSemiAuto.State.Error
@@ -797,6 +808,12 @@ instHmiBannerFormatter(
     CycleChecksInhibited  := PRG_03_Modes_Cycle.Data.SequenceState.CycleChecksInhibited,
     MachineHomingStep        := PRG_02_Acquisition.Data.MachineHoming.Step,
     MachineHomingInstruction := PRG_02_Acquisition.Data.MachineHoming.Instruction,
+    MachineHomingFailed      := PRG_02_Acquisition.Data.MachineHoming.Failed,
+    WinchM1Error             := GVL_IHM.M1TreuilRetenue.State.Error OR GVL_IHM.M1TreuilRetenue.State.FinalInterlockError,
+    WinchM2Error             := GVL_IHM.M2TreuilBenne.State.Error OR GVL_IHM.M2TreuilBenne.State.FinalInterlockError,
+    EncoderM1Fault           := PRG_02_Acquisition.Data.EncoderM1.Fault.Error,
+    EncoderM2Fault           := PRG_02_Acquisition.Data.EncoderM2.Fault.Error,
+    JoystickLatchedFault     := PRG_02_Acquisition.Data.Joystick.Fault.Latched,
     BypassGlobalActive    := GVL_IHM.Network.Bypass.Global,
     CfgCorrectedT330      := instCfgT330Normalizer.CorrectedHeld,
     BypassWinchM1Active   := GVL_IHM.M1TreuilRetenue.Bypass.Global,

`
