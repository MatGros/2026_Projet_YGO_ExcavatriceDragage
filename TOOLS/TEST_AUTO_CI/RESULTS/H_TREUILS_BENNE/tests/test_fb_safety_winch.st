(* =======================================================================
   🧪 test_fb_safety_winch.st — FB_Safety_Winch (TC-P10-001..010, 018, 036.1, 037.1, 044.1, 051.1)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Safety_Winch_v1.0.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG ; hex décrit en décimal (bit 0 = 1, bit 15 = 32768).
   Masque PowerCutOff = 16#2F84 = bits 2,7,8,9,10,11,13 (décimal 12164).
   Masque SafeStop SyncEnable=TRUE  = 16#FF9F ; SyncEnable=FALSE = 16#FF97 (exclut bit3).
   ======================================================================= *)

SETUP
VAR
    fb : FB_Safety_Winch;
END_VAR
END_SETUP

(* ── Remise à zéro commune : pulse Enable+Reset, puis Reset retombé ── *)

TEST 'TC-P10-001 Meca A : derive >2.0m a l arret (joystick neutre) -> SafeStop + PowerCutOff'
    (* Scan 1 : Enable=TRUE, regime nominal, joystick neutre, contacteurs+frein confirmes coupes *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : regime etabli, Meca A arme (RefPosM capture a 0.0) *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.SafeStop, 'Nominal : pas de SafeStop');
    ASSERT_FALSE(fb.PowerCutOff, 'Nominal : pas de PowerCutOff');
    ASSERT_FALSE(fb.Fault.Error, 'Nominal : pas d erreur');
    (* Scan 3 : derive injectee > 2.0m (mono-canal position) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Derive >2.0m -> SafeStop');
    ASSERT_TRUE(fb.PowerCutOff, 'Derive >2.0m -> PowerCutOff (bit7 dans masque 16#2F84)');
    ASSERT_TRUE(fb.Fault.Error, 'Derive >2.0m -> Error');
    ASSERT_TRUE(fb.Fault.Latched, 'Meca A latchee (defaut a acquitter)');
END_TEST

TEST 'TC-P10-002 Meca B : non confirmation arret 3s -> SafeStop + PowerCutOff'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : joystick neutre mais contacteurs NON confirmes retombes (FwdRevSpeedFeedbackOff=FALSE) *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 3s : pas encore de PowerCutOff');
    (* Scan 3 : apres PostRampTimeout=3s -> Meca B latchee *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Non confirmation arret 3s -> SafeStop');
    ASSERT_TRUE(fb.PowerCutOff, 'Non confirmation arret 3s -> PowerCutOff (bit8 dans masque)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca B -> Error');
END_TEST

TEST 'TC-P10-018 ContactorStuck : contacteur colle -> ContactorStuck + SafeStop + PowerCutOff (action, pas seulement diagnostic)'
    (* (adapte depuis TC-P10-018 FB_Winch, T181-02/03 AC5) : FB_Safety_Winch est le producteur
       UNIQUE de ContactorStuck. Le TC prouve l'ACTION de securite (SafeStop + PowerCutOff),
       pas seulement l'etat diagnostic. *)
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : joystick neutre mais contacteurs NON retombes (FwdRevSpeedFeedbackOff=FALSE) *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.ContactorStuck, 'Avant 3s : pas encore de ContactorStuck');
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 3s : pas encore de PowerCutOff');
    (* Scan 3 : apres PostRampTimeout=3s -> ContactorStuck + SafeStop + PowerCutOff *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.ContactorStuck, 'Contacteur colle 3s -> ContactorStuck=TRUE');
    ASSERT_TRUE(fb.SafeStop, 'Contacteur colle -> SafeStop (action)');
    ASSERT_TRUE(fb.PowerCutOff, 'Contacteur colle -> PowerCutOff (action)');
    ASSERT_TRUE(fb.Fault.Error, 'Contacteur colle -> Error');
END_TEST

TEST 'TC-P10-003 Meca C : glissement M1 >2.0m pendant maintien benne -> SafeStop + PowerCutOff'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : BenneHoldStillActive=TRUE -> Meca C arme (RefPosM capture a 0.0) *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := TRUE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    (* Scan 3 : derive M1 > 2.0m pendant maintien *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := TRUE, InReferencingMode := FALSE,
       CablePosM := 3.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Glissement M1 >2.0m -> SafeStop');
    ASSERT_TRUE(fb.PowerCutOff, 'Glissement M1 >2.0m -> PowerCutOff (bit9 dans masque)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca C -> Error');
END_TEST

TEST 'TC-P10-004 Meca D : capteur haut sans arret 3s -> SafeStop (immediat) puis PowerCutOff (3s)'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : capteur haut atteint (TopPositionSensor=FALSE) + contacteurs non retombes.
       Cause 5 (fin de course haut) -> AscentPermit=FALSE (bit5 hors masque SafeStop 16#FF97) ;
       SafeStop/PowerCutOff viennent de Meca D (bit11) apres 3s. *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := FALSE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.AscentPermit, 'Capteur haut atteint -> AscentPermit=FALSE (cause 5)');
    ASSERT_FALSE(fb.SafeStop, 'Avant 3s : Meca D pas encore latchee -> pas de SafeStop');
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 3s : Meca D pas encore latchee -> pas de PowerCutOff');
    (* Scan 3 : apres PostRampTimeout=3s -> Meca D latchee -> SafeStop + PowerCutOff *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := FALSE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Capteur haut sans arret 3s -> SafeStop (Meca D bit11)');
    ASSERT_TRUE(fb.PowerCutOff, 'Capteur haut sans arret 3s -> PowerCutOff (bit11 dans masque)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca D -> Error');
END_TEST

TEST 'TC-P10-005 Meca E bit12 : ecart >2.5m -> SafeStop SEUL (pas PowerCutOff)'
    (* BypassMecaA=TRUE isole Meca E : l armement Meca A est desormais base sur le retour
       mecanique, pas sur JoystickYNeutral. Seul Meca E (bit12) doit se declencher. *)
    (* Scan 1 : regime nominal avec SyncEnable=TRUE *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := FALSE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE, BypassMecaA := TRUE,
       CablePosM := 0.0, ExpectedOtherWinchPosM := 0.0, CfgCableLimitDescentM := -20.0,
       Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : ecart M1/M2 > CriticalSyncToleranceM=2.5m *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := FALSE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE, BypassMecaA := TRUE,
       CablePosM := 3.0, ExpectedOtherWinchPosM := 0.0, CfgCableLimitDescentM := -20.0,
       Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Ecart critique -> SafeStop (bit12 dans masque SafeStop)');
    ASSERT_FALSE(fb.PowerCutOff, 'Ecart critique bit12 -> PAS de PowerCutOff (bit12 hors masque 16#2F84)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca E bit12 -> Error');
END_TEST

TEST 'TC-P10-006 Meca E bit13 : bit12 non confirme 3s -> escalade PowerCutOff'
    (* JoystickYNeutral=FALSE pour isoler Meca E (evite Meca A dans le masque PowerCutOff). *)
    (* Scan 1 : regime nominal avec SyncEnable=TRUE, ecart critique -> bit12 latche *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := FALSE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, ExpectedOtherWinchPosM := 0.0, CfgCableLimitDescentM := -20.0,
       Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : bit12 latche, contacteurs non retombes -> TonMecaE arme *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := FALSE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, ExpectedOtherWinchPosM := 0.0, CfgCableLimitDescentM := -20.0,
       Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 3s : bit12 seul -> pas de PowerCutOff');
    (* Scan 3 : apres PostRampTimeout=3s -> escalade bit13 -> PowerCutOff *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := FALSE,
       JoystickYNeutral := FALSE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, ExpectedOtherWinchPosM := 0.0, CfgCableLimitDescentM := -20.0,
       Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.PowerCutOff, 'Escalade bit13 -> PowerCutOff (bit13 dans masque 16#2F84)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca E escalade -> Error');
END_TEST

TEST 'TC-P10-007 Meca F : sens mesure oppose a la commande 500ms -> SafeStop SEUL'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : commande montee (Direction=1) mais vitesse mesuree negative *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := -0.1);
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 500ms : pas de PowerCutOff');
    (* Scan 3 : apres OppositeDirectionTimeout=500ms -> Meca F latchee *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := -0.1);
    ASSERT_TRUE(fb.SafeStop, 'Sens oppose 500ms -> SafeStop (bit14 dans masque)');
    ASSERT_FALSE(fb.PowerCutOff, 'Sens oppose -> PAS de PowerCutOff (bit14 hors masque 16#2F84)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca F -> Error');
END_TEST

TEST 'TC-P10-008 Meca G : vitesse nulle malgre commande 3s -> SafeStop SEUL'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : commande montee mais vitesse nulle *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := 0.0);
    ASSERT_FALSE(fb.PowerCutOff, 'Avant 3s : pas de PowerCutOff');
    (* Scan 3 : apres NoMovementTimeout=3s -> Meca G latchee *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := 0.0);
    ASSERT_TRUE(fb.SafeStop, 'Absence mouvement 3s -> SafeStop (bit15 dans masque)');
    ASSERT_FALSE(fb.PowerCutOff, 'Absence mouvement -> PAS de PowerCutOff (bit15 hors masque 16#2F84)');
    ASSERT_TRUE(fb.Fault.Error, 'Meca G -> Error');
END_TEST

TEST 'TC-P10-009 Masque PowerCutOff : bit2 (surchauffe moteur) coupe, bit14 (sens oppose) ne coupe pas'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : surchauffe moteur (ThermalFeedback=TRUE) -> bit2 dans masque PowerCutOff *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       ThermalFeedback := TRUE);
    ASSERT_TRUE(fb.PowerCutOff, 'Surchauffe moteur (bit2) -> PowerCutOff (bit2 dans masque 16#2F84)');
    ASSERT_TRUE(fb.SafeStop, 'Surchauffe moteur -> SafeStop');
    (* Scan 3 : Reset acquitte *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := TRUE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       ThermalFeedback := FALSE);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.Fault.Error, 'Reset acquitte la surchauffe');
    (* Scan 4 : sens oppose (bit14) -> SafeStop mais PAS PowerCutOff *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := -0.1);
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       Direction := 1, MovementCommanded := TRUE, MeasuredSpeedValid := TRUE,
       MeasuredSpeedSignedMps := -0.1);
    ASSERT_TRUE(fb.SafeStop, 'Sens oppose -> SafeStop');
    ASSERT_FALSE(fb.PowerCutOff, 'Sens oppose (bit14) -> PAS de PowerCutOff (hors masque 16#2F84)');
END_TEST

TEST 'TC-P10-010 SafeStop exclut bit3 (mou cable) si SyncEnable=FALSE'
    (* Scan 1 : regime nominal SyncEnable=FALSE *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : mou de cable (SlackCableDetected=TRUE), SyncEnable=FALSE -> bit3 exclu de SafeStop *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       SlackCableDetected := TRUE);
    ASSERT_FALSE(fb.SafeStop, 'Mou cable SyncEnable=FALSE -> PAS de SafeStop (bit3 exclu masque 16#FF97)');
    ASSERT_FALSE(fb.DescendPermit, 'Mou cable -> DescendPermit=FALSE (blocage descente)');
    ASSERT_TRUE(fb.AscentPermit, 'Mou cable -> AscentPermit reste TRUE');
    (* Scan 3 : cable retendu (SlackCableDetected=FALSE) -> blocage leve *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       SlackCableDetected := FALSE);
    ASSERT_TRUE(fb.DescendPermit, 'Cable retendu -> DescendPermit=TRUE (blocage leve)');
END_TEST

TEST 'TC-P10-036.1 Warmup 3s : perte com operateur ignoree pendant 3s puis SafeStop'
    (* Scan 1 : Enable=TRUE, perte com operateur (JoystickOnline=FALSE) -> warmup en cours *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := FALSE, JoystickOperational := FALSE,
       HeartbeatIhmOk := FALSE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.SafeStop, 'Pendant warmup (<3s) : perte com ignoree -> pas de SafeStop');
    (* Scan 2 : 1s ecoulee, toujours < 3s *)
    ADVANCE_TIME(1000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := FALSE, JoystickOperational := FALSE,
       HeartbeatIhmOk := FALSE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.SafeStop, '1s : toujours pas de SafeStop');
    (* Scan 3 : apres 3s -> cause 0 active -> SafeStop *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := FALSE, JoystickOperational := FALSE,
       HeartbeatIhmOk := FALSE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.SafeStop, 'Apres 3s : perte com -> SafeStop');
    ASSERT_TRUE(fb.Fault.Error, 'Perte com -> Error');
END_TEST

TEST 'TC-P10-037.1 Gate Enable=FALSE : sorties forcees FALSE, latches preserves, re-Enable exige Reset'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : declenche Meca A (derive >2.0m) *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.Fault.Error, 'Precondition : Meca A latchee');
    (* Scan 3 : Enable=FALSE -> sorties forcees FALSE, latch preserve *)
    ADVANCE_TIME(10000000);
    fb(Enable := FALSE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.SafeStop, 'Enable=FALSE -> SafeStop force FALSE');
    ASSERT_FALSE(fb.PowerCutOff, 'Enable=FALSE -> PowerCutOff force FALSE');
    ASSERT_FALSE(fb.Ready, 'Enable=FALSE -> Ready=FALSE');
    (* Scan 4 : re-Enable SANS Reset, cause disparue -> latch preserve (Ready=FALSE) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_FALSE(fb.Ready, 'Re-Enable sans Reset : latch preserve -> Ready=FALSE');
    ASSERT_TRUE(fb.Fault.Latched, 'Re-Enable sans Reset : defaut toujours latche');
    (* Scan 5 : front Reset -> acquitte *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := TRUE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.Ready, 'Reset front -> Ready=TRUE');
    ASSERT_FALSE(fb.Fault.Error, 'Reset front -> plus d erreur');
END_TEST

TEST 'TC-P10-044.1 Mou cable : SyncEnable=FALSE -> DescendPermit=FALSE, AscentPermit autorise, blocage leve au retension'
    (* Scan 1 : regime nominal SyncEnable=FALSE *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : mou de cable -> blocage descente, montee autorisee *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       SlackCableDetected := TRUE);
    ASSERT_FALSE(fb.DescendPermit, 'Mou cable -> DescendPermit=FALSE');
    ASSERT_TRUE(fb.AscentPermit, 'Mou cable -> AscentPermit=TRUE (montee autorisee)');
    ASSERT_FALSE(fb.SafeStop, 'Mou cable SyncEnable=FALSE -> pas de SafeStop (bit3 exclu)');
    (* Scan 3 : cable retendu (M2_TensionedCable_DI=TRUE) -> blocage leve *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       SlackCableDetected := FALSE);
    ASSERT_TRUE(fb.DescendPermit, 'Cable retendu -> DescendPermit=TRUE');
END_TEST

TEST 'TC-P10-051.1 Chaine PowerCutOff bout-en-bout : FB produit la coupure, chaine PRG_04->PRG_06->AU = essai site'
    (* (essai site — stub) : la preuve bout-en-bout (demande PRG_04 -> agregation PRG_06 -> coupure AU)
       n est pas automatisable en boite noire FB. On verifie ici la brique amont : le FB produit
       bien PowerCutOff sur une cause du masque 16#2F84, condition necessaire de la chaine. *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 3.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ASSERT_TRUE(fb.PowerCutOff, 'Cause masque 16#2F84 -> PowerCutOff produit (brique amont de la chaine)');
    ASSERT_TRUE(fb.SafeStop, 'Cause masque -> SafeStop');
END_TEST

TEST 'TC-P10-052 Limite legale : BypassProcess simu ne leve pas le verrou sous -15m'
    (* Regression T197 : SimulationBypassActive arme BypassProcess pour eviter les
       faux defauts mecaniques du banc. Ce bypass de groupe ne doit pas neutraliser
       la limite legale; seul BypassLimitLegal est habilite a le faire. *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := -15.1, CfgCableLimitDescentM := -20.0,
       LimitLegalReached := TRUE, Homed := TRUE, TopLimitM := 8.5,
       BypassProcess := TRUE, BypassLimitLegal := FALSE);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := -15.1, CfgCableLimitDescentM := -20.0,
       LimitLegalReached := TRUE, Homed := TRUE, TopLimitM := 8.5,
       BypassProcess := TRUE, BypassLimitLegal := FALSE);
    ASSERT_FALSE(fb.DescendPermit, 'BypassProcess seul ne doit pas autoriser la descente sous la limite legale');
END_TEST

TEST 'TC-P10-053 Limite legale : bypass dedie explicite autorise uniquement le test MAINT_N2'
    (* Le bypass legal dedie conserve le comportement de mise en service; il est
       gate par MAINT_N2 dans PRG_04 avant d arriver ici. *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := -15.1, CfgCableLimitDescentM := -20.0,
       LimitLegalReached := TRUE, Homed := TRUE, TopLimitM := 8.5,
       BypassProcess := TRUE, BypassLimitLegal := TRUE);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
       OtherWinchInhibited := FALSE, InReferencingMode := FALSE,
       CablePosM := -15.1, CfgCableLimitDescentM := -20.0,
       LimitLegalReached := TRUE, Homed := TRUE, TopLimitM := 8.5,
       BypassProcess := TRUE, BypassLimitLegal := TRUE);
    ASSERT_TRUE(fb.DescendPermit, 'BypassLimitLegal explicite autorise le test de descente');
END_TEST
