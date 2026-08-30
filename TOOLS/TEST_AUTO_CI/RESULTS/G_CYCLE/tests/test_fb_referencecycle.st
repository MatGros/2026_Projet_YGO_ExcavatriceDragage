(* =======================================================================
   FB_ReferenceCycle -- garde-fous de qualification machine (T184)
   ======================================================================= *)

SETUP
VAR
    Fb : FB_ReferenceCycle;
END_VAR
END_SETUP

TEST 'TC-T184-001 : semi-auto interdit sans offset benne confirme'
    Fb(Enable := TRUE, Mode := E_Mode.SEMI_AUTO,
       TopPositionActive := FALSE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := TRUE, M2HomedAndReliable := TRUE,
       BucketOffsetValid := FALSE);
    ASSERT_FALSE(Fb.MachineReferenceReady, 'Deux codeurs seuls ne qualifient pas la machine');
    ASSERT_EQ(Fb.ReferenceStep, 20, 'Le guide demande la maintenance N2 pour la benne');
END_TEST

TEST 'TC-T184-002 : confirmation benne refusee hors conditions N2 top arret'
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := TRUE, M2HomedAndReliable := TRUE,
       ConfirmOpenPosition := TRUE, CfgTopHomingTargetM := 8.5);
    ASSERT_FALSE(Fb.HomingRequestM1, 'Homing conjoint refuse hors N2');
    ASSERT_FALSE(Fb.ReferenceTransactionActive, 'Aucune transaction hors N2');
END_TEST

TEST 'TC-T184-003 : homing conjoint et commit atomique benne fermee'
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := FALSE, M2HomedAndReliable := FALSE,
       ConfirmClosePosition := FALSE, CfgTopHomingTargetM := 8.5,
       CfgOffsetCloseM := 3.0);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := FALSE, M2HomedAndReliable := FALSE,
       ConfirmClosePosition := TRUE, CfgTopHomingTargetM := 8.5,
       CfgOffsetCloseM := 3.0);
    ASSERT_TRUE(Fb.HomingRequestM1, 'M1 recoit le homing conjoint');
    ASSERT_TRUE(Fb.HomingRequestM2, 'M2 recoit le homing conjoint');
    ASSERT_TRUE(Fb.M2UseDynamicTarget, 'M2 utilise la cible geometrique');
    ASSERT_EQ(Fb.M2DynamicTargetM, 11.5, 'Cible M2 = top M1 configure + offset ferme');
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomingBusy := TRUE, M2HomingBusy := TRUE,
       CfgTopHomingTargetM := 8.5, CfgOffsetCloseM := 3.0);
    ASSERT_TRUE(Fb.ReferenceTransactionActive, 'Transaction conservee pendant les deux homings');
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := TRUE, M2HomedAndReliable := TRUE,
       M1HomingBusy := FALSE, M2HomingBusy := FALSE,
       M1HomingDone := TRUE, M2HomingDone := TRUE,
       CfgTopHomingTargetM := 8.5, CfgOffsetCloseM := 3.0);
    ASSERT_FALSE(Fb.ReferenceFailed, 'Succes homing ne doit pas abandonner la transaction');
    ASSERT_TRUE(Fb.MachineReferenceReady, 'Reference machine qualifiee apres commit atomique');
    ASSERT_EQ(Fb.ReferenceStep, 60, 'Etape succes publiee apres commit atomique');
    ASSERT_TRUE(Fb.CommitClosePosition, 'Commit ferme seulement apres les deux succes');
END_TEST

TEST 'TC-T184-004 : perte reference en mouvement demande SafeStop'
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1HomedAndReliable := TRUE, M2HomedAndReliable := TRUE,
       BucketOffsetValid := TRUE);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := FALSE,
       M1HomedAndReliable := FALSE, M2HomedAndReliable := TRUE,
       BucketOffsetValid := TRUE);
    ASSERT_TRUE(Fb.ReferenceLossSafeStop, 'Perte M1 en mouvement declenche arret controle');
END_TEST
