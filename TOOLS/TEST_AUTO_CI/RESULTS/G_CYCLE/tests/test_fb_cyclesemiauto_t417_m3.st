(* T417 — confirmation minimale de la commande cycle AX14 -> AX15A.
   Baseline courante uniquement : aucune référence aux états AX15D absents. *)
SETUP
VAR
    FB : FB_CycleSemiAuto;
    SampleCount : INT := 0;
END_VAR
END_SETUP

TEST 'T417-CYCLE-010 AX14 retire M3 avant AX15A'
    (* Charger AX14 avec la translation encore en route. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       Translation_At_Tremie := FALSE, Translation_Busy := TRUE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickLeft := TRUE, JoystickRight := FALSE,
       SampleCount := SampleCount, StepForceTgt := 14);
    FB(StepForceTgt := -1, Translation_At_Tremie := FALSE, Translation_Busy := TRUE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX14_TRANSLATE_DUMP,
                'AX14 actif avant le capteur Tremie');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart,
                'AX14 maintient la demande translation avant arrivee');

    (* Arrivée : la demande tombe immédiatement, puis l état attend l arrêt confirmé. *)
    FB(Translation_At_Tremie := TRUE, Translation_Busy := TRUE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.TranslationCmd.ReqStart,
                 'Capteur Tremie : AX14 retire la demande avant confirmation arret');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX14_TRANSLATE_DUMP,
                'AX14 reste actif tant que Translation_Busy est vrai');

    (* Le TON est échantillonné avec Busy=FALSE avant que le temps simulé avance. *)
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickLeft := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(600000000);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE,
       SampleCount := SampleCount);
    (* Le changement de State est produit ci-dessus ; CycleStep est publié au scan AX15A suivant. *)
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'AX15A seulement apres arret confirme et tempo cycle');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart,
                 'AX15A conserve la demande translation a zero');
END_TEST
