SETUP
VAR
    harness   : FB_TestHarness_PRG_05;
    acqData   : ST_AcquisitionInterPrg;
    modesAuth : ST_Modes_Autorisations;
END_VAR
END_SETUP

TEST 'PRG_05_Translation : Commande Translation Fwd (Joystick X + Hauteur Treuils OK)'
    // 1. Contexte : Mode Manuel N1, Câbles treuils hauts (sécurité interlock hauteur validée)
    modesAuth.Mode := E_Mode.MAINT_N1;
    
    // 2. Stimulus issu du bus PRG_02 : Joystick armé vers la droite (+X)
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := 1;
    acqData.Joystick.AxisX.SpeedTgt := 75.0;
    
    // 3. Exécution PRG_05 (Position P2/P1/Maintenance = mot valide 00111, ni butée Trémie ni butée Maintenance)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ADVANCE_TIME(1000000000);
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );


    
    // 4. Vérification du bus sortant ST_TranslationInterPrg vers PRG_06
    ASSERT_TRUE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Demande desserrage frein M3 generee');
    ASSERT_FALSE(harness.Data.TranslationSafety.SafeStop, 'Aucun SafeStop actif sur translation');
    ASSERT_TRUE(harness.Data.TranslationState.ActiveTremie, 'Sens translation avant arbitre');
    ASSERT_GT(harness.Data.TranslationState.SpeedCmd_Pct, 0.0, 'Consigne vitesse M3 arbitree non nulle');
    ASSERT_NEQ(harness.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord, 16#0000, 'ControlWord variateur active pendant la commande');
END_TEST

TEST 'PRG_05_Translation : Commande Translation Rev (Joystick X negatif)'
    modesAuth.Mode := E_Mode.MAINT_N1;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := -1;
    acqData.Joystick.AxisX.SpeedTgt := 60.0;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := FALSE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ADVANCE_TIME(1000000000);
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := FALSE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := FALSE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ASSERT_TRUE(harness.Data.TranslationState.ActiveMaintenance, 'Sens translation arriere arbitre');
    ASSERT_TRUE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Frein M3 desserre en arriere');
    ASSERT_FALSE(harness.Data.TranslationSafety.SafeStop, 'Aucun SafeStop en commande arriere nominale');
END_TEST

TEST 'PRG_05_Translation : Interdiction Mouvement Translation si Treuils en Bas'
    // Stimulus : Treuil M1 descendu trop bas (< 2m)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 0.5,
        WinchM2CablePosM := 5.0,
        PowerContactorEngaged := TRUE
    );
    
    // Vérification : mouvement bloqué par l'interlock de hauteur
    ASSERT_FALSE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Frein reste serre');
    ASSERT_FALSE(harness.Data.TranslationState.ActiveTremie, 'Mouvement interdit');
    ASSERT_FALSE(harness.Data.TranslationState.ActiveMaintenance, 'Mouvement interdit');
END_TEST


TEST 'PRG_05_Translation : FdC Tremie LATCHE - un rebond capteur ne libere pas (guard REX MES 2026-09-04)'
    // REGRESSION : un rebond du capteur de butee Tremie (mot 11111 -> 01111 -> 11111)
    // ne doit JAMAIS liberer le bistable M3_LimitSwitchTremieStable ni reautoriser la
    // translation vers la Tremie. On ne perd la butee QU'EN commandant le sens inverse.
    modesAuth.Mode := E_Mode.MAINT_N1;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := 0;
    acqData.Joystick.AxisX.SpeedTgt := 0.0;

    // 1. Pont sur la butee Tremie : mot 11111 -> bistable latche
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(500000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Butee Tremie latchee sur mot 11111');

    // 2. REBOND capteur Tremie : DI tombe 2 scans (mot 01111), AUCUNE commande sens inverse
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Rebond capteur -> butee Tremie RESTE latchee (pas de flicker autorisation)');

    // 3. Capteur revient : toujours latche
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Capteur revenu -> toujours latchee');

    // 4. Commande SENS INVERSE (Maintenance, joystick X negatif) -> liberation legitime
    acqData.Joystick.AxisX.Direction := -1;
    acqData.Joystick.AxisX.SpeedTgt := 50.0;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_FALSE(harness.Data.TranslationState.LimitSwitchTremie, 'Commande sens inverse (Maintenance) -> butee Tremie liberee');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════════
   T345 lot L1 — PRG_05 : mémoire de cible et garde de mode des bypass M3.
   ═══════════════════════════════════════════════════════════════════════════ *)

TEST 'TC-P05-T345-01 (T345-L1) La perte de la demande n efface plus la cible deja qualifiee'
    modesAuth.Mode := E_Mode.MAINT_N1;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := -1;      // demande vers P1/Maintenance
    acqData.Joystick.AxisX.SpeedTgt := 50.0;

    // Scans 1-3 : commande arriere, capteur P1 atteint (mot 00011) -> jeton P1 -> cible qualifiee
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationDone, 'cible P1 qualifiee : debounce 100 ms ecoule');

    // Scan 4 : l operateur relache le joystick (perte de la demande) SANS quitter P1.
    // La cible doit rester portee : sans memoire de cible, la detection d arrivee en cours
    // etait effacee et le verrou d arret de l axe ne pouvait plus s armer.
    acqData.Joystick.AxisX.Direction := 0;
    acqData.Joystick.AxisX.SpeedTgt := 0.0;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationDone, 'demande retiree : la cible P1 reste qualifiee');

    // Scans 7-9 : le chariot repart vers la Tremie, le capteur P2 se re-arme (mot 00111) -> un
    // nouveau point est franchi, le jeton P1 retombe et la cible avec lui (elle n est pas collee).
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_FALSE(harness.Data.TranslationDone, 'nouveau point franchi : la cible P1 retombe d elle-meme');
END_TEST

TEST 'TC-P05-T345-02 (T345-L1) Bypass de fin de course M3 consomme uniquement en MAINT_N2'
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := 1;       // demande vers la Tremie
    acqData.Joystick.AxisX.SpeedTgt := 50.0;
    modesAuth.Mode := E_Mode.MAINT_N1;           // hors MAINT_N2 : la garde doit s opposer au bypass

    // Scans 1-4 (1 s chacun) : butee Tremie atteinte en demandant (mot 11111), bypass IHM a TRUE et
    // rotation reelle injectee. Hors MAINT_N2 le bypass n est PAS consomme : les deux voies de la
    // cause 6 (axe et safety) doivent s armer, la butee ne peut plus etre neutralisee.
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.Error, 'hors MAINT_N2 : cause 6 de l axe NON neutralisee par le bypass');
    ASSERT_TRUE(harness.Data.TranslationSafety.PowerCutOff, 'hors MAINT_N2 : cause 6 safety NON neutralisee -> PowerCutOff');

    // Scans 5-9 : retour en MAINT_N2, meme bypass et memes capteurs -> le bypass est consomme.
    modesAuth.Mode := E_Mode.MAINT_N2;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        BypassLimitSwitchIHM := TRUE, DriveActualFreqHzOverride := 5.0,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_FALSE(harness.Data.TranslationState.Error, 'en MAINT_N2 : bypass consomme -> cause 6 de l axe neutralisee');
    ASSERT_FALSE(harness.Data.TranslationSafety.PowerCutOff, 'en MAINT_N2 : bypass consomme -> pas de PowerCutOff');
END_TEST
