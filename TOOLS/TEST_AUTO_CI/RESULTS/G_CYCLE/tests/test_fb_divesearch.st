(* =======================================================================
   FB_DiveSearch -- assistance plongee et recherche du fond Kobold
   Tests alignes sur l'interface actuelle (bus structuré Inputs/Outputs).
   Couverture : TC-P03-001 (Enable) + TC-P04-010..016 (recherche fond).
   ======================================================================= *)

SETUP
VAR
    FB  : FB_DiveSearch;
    Inp : ST_fbDiveSearch_Inputs;
END_VAR
    (* Valeurs nominales par defaut du bus d'entree *)
    Inp.PowerContactorEngaged := TRUE;
    Inp.Mode                  := E_Mode.MAINT_N1;
    Inp.MotionRequestActive   := FALSE;
    Inp.MotionDirection       := 0;
    Inp.BucketIsOpen          := TRUE;
    Inp.KoboldImmersed        := FALSE;
    Inp.M1Position_M          := 20.0;
    Inp.M2Position_M          := 20.0;
    Inp.PositionsValid        := TRUE;
    Inp.CurrentSpeedStep      := 4;
    Inp.DiveStartMin_M        := 15.0;
    Inp.ImmersionUpper_M      := 10.0;
    Inp.ImmersionLower_M      := 5.0;
    Inp.CableLimitAscent_M    := 30.0;
    Inp.LimitLegalDepthMin_M  := -20.0;
    Inp.CfgDiveFloorStep      := 0;
    Inp.CycleTime             := T#10ms;
    Inp.BypassPreconditions   := FALSE;
END_SETUP


(* ---------- TC-P03-001 : dynamique Enable ---------- *)
TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* ⛔ Scan 0 : Enable=FALSE → neutralisé *)
    FB(Enable := FALSE, Reset := FALSE, Inputs := Inp);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Enable=FALSE -> Lifecycle.Busy=FALSE');

    ADVANCE_TIME(10000000);

    (* ✅ Scan 1 : Enable=TRUE → prêt *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* ⛔ Scan 2 : Enable=FALSE → re-neutralisé *)
    FB(Enable := FALSE, Reset := FALSE, Inputs := Inp);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST


(* ---------- TC-P04-010 : mise en service recherche de couche ---------- *)
TEST 'TC-P04-010 DiveSearch : mise en service recherche de couche'
    Inp.BypassPreconditions := TRUE;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Ready, 'Module DiveSearch pret');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.READY_TO_DESCEND, 'Pret a descendre');

    (* 🚀 Descente → SEARCHING_IMMERSION *)
    ADVANCE_TIME(10000000);
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_IMMERSION, 'Passe en recherche immersion');

    (* 👀 SEARCHING_IMMERSION : permis + Busy *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Outputs.DescendPermit, 'Permis descente actif en recherche immersion');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Recherche en cours -> Busy');
    ASSERT_TRUE(FB.Outputs.KoboldContactorCmd, 'Contacteur Kobold alimente a la volee');
END_TEST


(* ---------- TC-P04-011 : sequence complete Kobold 4 temps ---------- *)
TEST 'TC-P04-011 : Sequence complete Kobold 4 temps avec coupure contacteur sur contact fond'
    (* 🏁 Init → READY_TO_DESCEND *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Ready, 'Pret a descendre');

    (* 🚀 Descente → SEARCHING_IMMERSION *)
    Inp.M1Position_M := 12.0;
    Inp.M2Position_M := 12.0;
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Outputs.KoboldContactorCmd, 'Contacteur Kobold alimente');

    (* 🌊 Immersion (front 0→1) → SEARCHING_BOTTOM *)
    Inp.KoboldImmersed := TRUE;
    Inp.M1Position_M := 8.0;
    Inp.M2Position_M := 8.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_BOTTOM, 'Passe en recherche du fond');

    (* 🎯 Contact fond (front 1→0) → BOTTOM_CONFIRMED *)
    Inp.KoboldImmersed := FALSE;
    Inp.M1Position_M := -5.0;
    Inp.M2Position_M := -5.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.BOTTOM_CONFIRMED, 'Fond confirme');
    ASSERT_TRUE(FB.Outputs.BottomTouchConfirmed, 'Contact fond valide');
    ASSERT_FALSE(FB.Outputs.KoboldContactorCmd, 'Coupure contacteur Kobold pour eviter surchauffe');
END_TEST


(* ---------- TC-P04-012 : Palier 5 interdit sous Kobold ---------- *)
TEST 'TC-P04-012 : Tentative descente en Palier 5 sous Kobold declenche defaut bloquant'
    Inp.BypassPreconditions := TRUE;
    Inp.MotionRequestActive := FALSE;
    Inp.MotionDirection := 0;
    Inp.CurrentSpeedStep := 4;
    (* 🏁 Scan 1 → READY_TO_DESCEND *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    (* 🚀 Scan 2 → SEARCHING_IMMERSION *)
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    (* ⛔ Scan 3 : Palier 5 interdit → défaut *)
    Inp.CurrentSpeedStep := 5;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    (* 🔍 Scan 4 : évaluation défaut *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Fault.Error, 'Defaut Palier 5 interdit');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.Outputs.StepAtFault, E_DiveSearchState.SEARCHING_IMMERSION, 'StepAtFault memorise SEARCHING_IMMERSION');
    ASSERT_FALSE(FB.Outputs.KoboldContactorCmd, 'Contacteur coupe sur defaut');
END_TEST


(* ---------- TC-P04-013 : timeout recherche immersion ---------- *)
TEST 'TC-P04-013 : Depassement tempo recherche immersion Kobold -> ERROR_HOLD et capture StepAtFault'
    (* Course plancher (CableLimitAscent_M=0.15 -> MAX(1.0,..)=1.0m), timeout = 1.0/0.15*1.5 = 10s ;
       CycleTime=4s -> depassement au 3e scan d'accumulation. *)
    Inp.BypassPreconditions := TRUE;
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    Inp.DiveStartMin_M := 0.005;
    Inp.ImmersionUpper_M := 0.0;
    Inp.ImmersionLower_M := 0.0;
    Inp.CableLimitAscent_M := 0.15;
    Inp.CycleTime := T#4s;
    (* 🚀 WAIT→READY→SEARCHING_IMMERSION *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_IMMERSION, 'En recherche immersion');

    (* ⏱️ 5 scans × 4s = 20s > timeout 10s *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);

    ASSERT_TRUE(FB.Fault.Error, 'Defaut timeout immersion declenche');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.Outputs.StepAtFault, E_DiveSearchState.SEARCHING_IMMERSION, 'StepAtFault memorise SEARCHING_IMMERSION');
    ASSERT_FALSE(FB.Outputs.DescendPermit, 'Permis descente coupe');
    ASSERT_FALSE(FB.Outputs.KoboldContactorCmd, 'Contacteur Kobold coupe');
END_TEST


(* ---------- TC-P04-014 : timeout recherche fond ---------- *)
TEST 'TC-P04-014 : Depassement tempo recherche fond Kobold -> ERROR_HOLD et capture StepAtFault'
    (* Mise en condition SEARCHING_BOTTOM (immersion validee). Course fond plancher
       (ImmersionLower 5.0 - LimitLegalDepthMin 4.996 = 0.004 -> MAX(1.0,..)=1.0m), timeout = 10s ; CycleTime=4s. *)
    Inp.BypassPreconditions := FALSE;
    Inp.BucketIsOpen := TRUE;
    Inp.PositionsValid := TRUE;
    Inp.KoboldImmersed := FALSE;
    Inp.M1Position_M := 20.0;
    Inp.M2Position_M := 20.0;
    Inp.CurrentSpeedStep := 4;
    Inp.DiveStartMin_M := 15.0;
    Inp.ImmersionUpper_M := 10.0;
    Inp.ImmersionLower_M := 5.0;
    Inp.LimitLegalDepthMin_M := 4.996;
    Inp.CycleTime := T#4s;
    (* 🏁 Scan 1 → READY *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    (* 🚀 Scan 2 → SEARCHING_IMMERSION *)
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    Inp.M1Position_M := 12.0;
    Inp.M2Position_M := 12.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    (* 🌊 Scan 3 : immersion → SEARCHING_BOTTOM *)
    Inp.KoboldImmersed := TRUE;
    Inp.M1Position_M := 8.0;
    Inp.M2Position_M := 8.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_BOTTOM, 'Passe en recherche fond');

    (* ⏱️ 5 scans × 4s = 20s > timeout 10s *)
    Inp.M1Position_M := 7.0; Inp.M2Position_M := 7.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    Inp.M1Position_M := 6.5; Inp.M2Position_M := 6.5;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    Inp.M1Position_M := 6.0; Inp.M2Position_M := 6.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    Inp.M1Position_M := 5.5; Inp.M2Position_M := 5.5;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    Inp.M1Position_M := 5.2; Inp.M2Position_M := 5.2;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);

    ASSERT_TRUE(FB.Fault.Error, 'Defaut timeout fond declenche');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.Outputs.StepAtFault, E_DiveSearchState.SEARCHING_BOTTOM, 'StepAtFault memorise SEARCHING_BOTTOM');
    ASSERT_FALSE(FB.Outputs.DescendPermit, 'Permis descente coupe');
    ASSERT_FALSE(FB.Outputs.KoboldContactorCmd, 'Contacteur coupe anti-chauffe');
END_TEST


(* ---------- TC-P04-015 : latch timeout survit au cycle Enable OFF/ON ---------- *)
TEST 'TC-P04-015 : Latch timeout survit au cycle Enable OFF/ON, acquitte seulement sur front Reset'
    (* ⏱️ Timeout immersion → latch armé *)
    Inp.BypassPreconditions := TRUE;
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    Inp.DiveStartMin_M := 0.005;
    Inp.ImmersionUpper_M := 0.0;
    Inp.ImmersionLower_M := 0.0;
    Inp.CableLimitAscent_M := 0.15;
    Inp.CycleTime := T#4s;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch timeout immersion arme');

    (* ⛔ Enable OFF : latch conservé *)
    FB(Enable := FALSE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch conserve sous Enable=FALSE (pas de redemarrage auto)');

    (* ⛔ Enable ON sans Reset : ERROR_HOLD *)
    Inp.BypassPreconditions := FALSE;
    Inp.MotionRequestActive := FALSE;
    Inp.MotionDirection := 0;
    Inp.BucketIsOpen := TRUE;
    Inp.PositionsValid := TRUE;
    Inp.KoboldImmersed := FALSE;
    Inp.M1Position_M := 20.0;
    Inp.M2Position_M := 20.0;
    Inp.DiveStartMin_M := 15.0;
    Inp.ImmersionUpper_M := 10.0;
    Inp.ImmersionLower_M := 5.0;
    Inp.CableLimitAscent_M := 30.0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch toujours actif sur retour Enable=TRUE sans acquittement');
    ASSERT_TRUE(FB.Fault.Error, 'Cause interne realimente Fault.Error au retour Enable');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.ERROR_HOLD, 'Verrouille ERROR_HOLD, aucun redemarrage vers READY_TO_DESCEND');
    ASSERT_FALSE(FB.Outputs.DescendPermit, 'Aucun permis descente au retour Enable sans reset');

    (* 🔄 Front Reset → acquittement *)
    FB(Enable := TRUE, Reset := TRUE, Inputs := Inp);
    ASSERT_FALSE(FB.Fault.Latched, 'Front Reset acquitte le latch timeout');
END_TEST


(* ---------- TC-P04-016 : contacteur Kobold coupe au relachement ---------- *)
TEST 'TC-P04-016 : Contacteur Kobold coupe des le relachement de la descente (anti-chauffe, H1)'
    Inp.BypassPreconditions := TRUE;
    Inp.MotionRequestActive := TRUE;
    Inp.MotionDirection := -1;
    Inp.CurrentSpeedStep := 4;
    (* 🚀 → SEARCHING_IMMERSION *)
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_IMMERSION, 'En recherche immersion');
    ASSERT_TRUE(FB.Outputs.KoboldContactorCmd, 'Contacteur alimente sous descente active');

    (* 🛑 Relâchement : contacteur + permis coupés *)
    Inp.MotionRequestActive := FALSE;
    Inp.MotionDirection := 0;
    FB(Enable := TRUE, Reset := FALSE, Inputs := Inp);
    ASSERT_FALSE(FB.Outputs.KoboldContactorCmd, 'Contacteur coupe des le relachement (anti-chauffe)');
    ASSERT_FALSE(FB.Outputs.DescendPermit, 'Permis descente coupe des le relachement');
    ASSERT_FALSE(FB.Fault.Error, 'Aucun defaut sur simple relachement');
    ASSERT_EQ(FB.Outputs.StepState, E_DiveSearchState.SEARCHING_IMMERSION, 'Reste en recherche (pas de bascule)');
END_TEST
