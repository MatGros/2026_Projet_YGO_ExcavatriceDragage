(* =======================================================================
   FB_MachineHomingCycle -- garde-fous de qualification machine (T185)
   Couverture contrat AC1..AC9 + defauts C-1 / C-2 / C-4.
   ======================================================================= *)

SETUP
VAR
    Fb : FB_MachineHomingCycle;
    Cfg : ST_fbMachineHomingCycle_Cfg;
    StatusHomed : ST_fbMachineHomingCycle_AxisHomingStatus;
    StatusNone  : ST_fbMachineHomingCycle_AxisHomingStatus;
    StatusBusy  : ST_fbMachineHomingCycle_AxisHomingStatus;
    StatusDone  : ST_fbMachineHomingCycle_AxisHomingStatus;
    StatusErr   : ST_fbMachineHomingCycle_AxisHomingStatus;
END_VAR
    StatusHomed.HomedAndReliable := TRUE;
    StatusBusy.HomingBusy := TRUE;
    StatusDone.HomedAndReliable := TRUE; StatusDone.HomingDone := TRUE;
    StatusErr.HomingError := TRUE;
END_SETUP


(* ---------- AC1 : SEMI_AUTO interdit sans datum ---------- *)
TEST 'TC-T185-001 : machine non qualifiee avec 2 codeurs seuls (offset benne absent)'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       TopPositionActive := FALSE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusHomed,
       BucketOffsetValid := FALSE);
    ASSERT_FALSE(Fb.MachineHomed, 'Deux codeurs seuls ne qualifient pas la machine');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.OFFSET_UNKNOWN, 'Guide : passer en MAINT_N2 pour la benne');
END_TEST


(* ---------- AC8 : causes distinctes M1 / M2 / offset ---------- *)
TEST 'TC-T185-010 : M1 non reference => M1_NOT_HOMED'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusHomed, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.M1_NOT_HOMED, 'Cause M1 isolee');
END_TEST

TEST 'TC-T185-011 : M2 non reference => M2_NOT_HOMED'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusNone, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.M2_NOT_HOMED, 'Cause M2 isolee');
END_TEST

TEST 'TC-T185-012 : les deux non references => BOTH_NOT_HOMED'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusNone, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.BOTH_NOT_HOMED, 'Cause conjointe');
END_TEST


(* ---------- AC7 : guide pas-a-pas jusqu'a la confirmation ---------- *)
TEST 'TC-T185-020 : codeurs OK, offset absent, N2 sans capteur haut => NEED_TOP_POSITION'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := FALSE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusHomed, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.NEED_TOP_POSITION, 'Guide : monter au capteur haut');
END_TEST

TEST 'TC-T185-021 : capteur haut atteint mais treuils non arretes => NEED_MECHANICAL_STOP'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := FALSE,
       M1Status := StatusHomed, M2Status := StatusHomed, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.NEED_MECHANICAL_STOP, 'Guide : attendre l arret');
END_TEST

TEST 'TC-T185-022 : fenetre sure => AWAIT_BUCKET_CONFIRM'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusHomed, BucketOffsetValid := FALSE);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.AWAIT_BUCKET_CONFIRM, 'Guide : confirmer la benne');
END_TEST


(* ---------- AC2 : confirmation admissible => homing conjoint + cible dynamique ---------- *)
TEST 'TC-T185-030 : confirmation refusee hors MAINT_N2'
    Cfg.CfgTopHomingTarget_M := 8.5;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusHomed,
       ConfirmOpenPosition := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'Homing conjoint refuse hors N2');
    ASSERT_FALSE(Fb.MachineHomingActive, 'Aucune transaction hors N2');
END_TEST

TEST 'TC-T185-031 : confirmation fermee admissible => homing M1+M2, cible M2 = top + offset ferme, commit atomique'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    (* settle *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    (* front confirmation fermee *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'M1 recoit le homing conjoint');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'M2 recoit le homing conjoint');
    ASSERT_TRUE(Fb.M2Demand.UseDynamicTarget, 'M2 cible geometrique');
    ASSERT_EQ(Fb.M2Demand.DynamicTarget_M, 11.5, 'Cible M2 = 8.5 + 3.0 (ferme)');
    ASSERT_TRUE(Fb.MachineHomingActive, 'Transaction active');
    ASSERT_TRUE(Fb.Lifecycle.Busy, 'Lifecycle.Busy pendant la transaction');
    (* les deux Busy *)
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusBusy, M2Status := StatusBusy,
       Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingActive, 'Transaction conservee pendant les deux homings');
    ASSERT_FALSE(Fb.BucketCommit.CommitClose, 'Pas de commit tant que les deux ne sont pas Done');
    (* les deux Done + fiables *)
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusDone, M2Status := StatusDone,
       Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingFailed, 'Succes homing ne doit pas abandonner');
    ASSERT_TRUE(Fb.BucketCommit.CommitClose, 'Commit ferme apres les deux succes');
    ASSERT_FALSE(Fb.BucketCommit.CommitOpen, 'Commit ouvert non arme');
    ASSERT_TRUE(Fb.MachineHomed, 'Machine qualifiee apres commit atomique');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.VALID, 'Etape succes');
    ASSERT_TRUE(Fb.Lifecycle.Done, 'Lifecycle.Done apres commit');
END_TEST


(* ---------- AC4 : quatre vecteurs d'abandon ---------- *)
TEST 'TC-T185-040 : abandon si capteur haut perdu pendant la transaction'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := TRUE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := FALSE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusBusy, M2Status := StatusBusy,
       Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingFailed, 'Perte capteur haut => abandon');
    ASSERT_FALSE(Fb.MachineHomingActive, 'Transaction close');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.FAILED, 'Guide : recommencer en N2');
END_TEST

TEST 'TC-T185-041 : abandon si erreur homing M1 pendant la transaction'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := TRUE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusErr, M2Status := StatusBusy,
       Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingFailed, 'Erreur homing M1 => abandon');
    ASSERT_TRUE(Fb.Fault.Latched, 'Cause erreur homing latchee');
END_TEST

TEST 'TC-T185-043 : HomingError present au scan exact du front de confirmation => abandon LE MEME SCAN, MachineHomed jamais TRUE'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    // Scan 1 : fenetre sure, pas de confirmation encore.
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       BucketOffsetValid := TRUE, ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    // Scan 2 : front de confirmation ET HomingError M1 au MEME scan.
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusErr, M2Status := StatusNone,
       BucketOffsetValid := TRUE, ConfirmClosePosition := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingFailed, 'Abandon des le scan d ouverture (pas de defer)');
    ASSERT_FALSE(Fb.MachineHomed, 'MachineHomed ne pulse jamais TRUE (gate SEMI_AUTO)');
    ASSERT_FALSE(Fb.MachineHomingActive, 'Pas de transaction active affichee');
END_TEST

TEST 'TC-T185-042 : abandon si mouvement pendant la transaction'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetOpen_M := 1.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmOpenPosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmOpenPosition := TRUE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := FALSE, M1Status := StatusBusy, M2Status := StatusBusy,
       Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingFailed, 'Mouvement pendant transaction => abandon');
END_TEST


(* ---------- C-2 : double confirmation meme scan = rejet total ---------- *)
TEST 'TC-T185-050 : Confirm ouverte ET fermee au meme scan => aucune transaction + cause latchee'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetOpen_M := 1.0; Cfg.CfgOffsetClose_M := 3.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusHomed, M2Status := StatusHomed,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE,
       Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusHomed, M2Status := StatusHomed,
       ConfirmOpenPosition := TRUE, ConfirmClosePosition := TRUE,
       Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'Double confirmation => aucun homing');
    ASSERT_FALSE(Fb.MachineHomingActive, 'Double confirmation => aucune transaction');
    ASSERT_TRUE(Fb.Fault.Latched, 'Cause double confirmation latchee');
END_TEST


(* ---------- C-4 : jamais de ref benne au vol par-dessus un homing d'axe ---------- *)
TEST 'TC-T185-060 : confirmation ignoree si un homing d axe est deja Busy'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusBusy, M2Status := StatusNone,
       ConfirmClosePosition := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingActive, 'Pas de transaction au vol sur homing d axe en cours');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.HOMING_IN_PROGRESS, 'Guide : homing d axe en cours');
END_TEST


(* ---------- AC / C-1 : perte de datum en mouvement ---------- *)
TEST 'TC-T185-070 : perte reference en mouvement => SafeStop, puis pas de requalification auto'
    (* datum valide *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusHomed, M2Status := StatusHomed,
       BucketOffsetValid := TRUE);
    ASSERT_TRUE(Fb.MachineHomed, 'Datum valide au depart');
    ADVANCE_TIME(10000000);
    (* perte M1 en mouvement *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := FALSE, M1Status := StatusNone, M2Status := StatusHomed,
       BucketOffsetValid := TRUE);
    ASSERT_TRUE(Fb.MachineHomingLossSafeStop, 'Perte M1 en mouvement => arret controle');
    ASSERT_FALSE(Fb.MachineHomed, 'Datum invalide');
    ADVANCE_TIME(10000000);
    (* treuils arretes + codeurs re-fiables : C-1 => MachineHomed reste FALSE sans Reset *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusHomed, M2Status := StatusHomed,
       BucketOffsetValid := TRUE);
    ASSERT_FALSE(Fb.MachineHomed, 'C-1 : pas de requalification automatique sans Reset conscient');
    ASSERT_FALSE(Fb.MachineHomingLossSafeStop, 'SafeStop leve apres arret mecanique');
    ADVANCE_TIME(10000000);
    (* Reset conscient => requalification possible *)
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusHomed, M2Status := StatusHomed,
       BucketOffsetValid := TRUE);
    ASSERT_TRUE(Fb.MachineHomed, 'Apres Reset conscient, datum re-qualifie');
    ASSERT_FALSE(Fb.Fault.Latched, 'Reset efface la cause latchee');
END_TEST


(* ---------- AC9 : ordre d action libre, meme etat final ---------- *)
TEST 'TC-T185-080 : Enable FALSE en pleine transaction => retour IDLE, sorties sures'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetClose_M := 3.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       ConfirmClosePosition := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingActive, 'Transaction armee');
    ADVANCE_TIME(10000000);
    Fb(Enable := FALSE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionActive := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StatusNone, M2Status := StatusNone,
       Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.IDLE, 'Enable FALSE => IDLE');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'Enable FALSE => demandes sures');
    ASSERT_FALSE(Fb.MachineHomed, 'Enable FALSE => non qualifie');
END_TEST

(* ---------- T132 absorbee : choix ferme par defaut IHM sans forçage PLC ---------- *)
TEST 'TC-T185-090 : aucune confirmation explicite => aucun commit benne'
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusHomed, M2Status := StatusHomed,
       BucketOffsetValid := FALSE, ConfirmOpenPosition := FALSE,
       ConfirmClosePosition := FALSE);
    ASSERT_FALSE(Fb.BucketCommit.CommitOpen, 'Presel. fermee IHM ne vaut pas confirmation');
    ASSERT_FALSE(Fb.BucketCommit.CommitClose, 'Aucun commit sans front operateur');
END_TEST

TEST 'TC-T185-091 : confirmation ouverte explicite => chemin ouvert exclusif'
    Cfg.CfgTopHomingTarget_M := 8.5; Cfg.CfgOffsetOpen_M := 1.0;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusNone,
       ConfirmOpenPosition := FALSE, Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusNone, M2Status := StatusNone,
       ConfirmOpenPosition := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'Confirmation ouverte declenche M1');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'Confirmation ouverte declenche M2');
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusBusy, M2Status := StatusBusy,
       Cfg := Cfg);
    ADVANCE_TIME(10000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionActive := TRUE, WinchesMechanicallyStopped := TRUE,
       M1Status := StatusDone, M2Status := StatusDone,
       Cfg := Cfg);
    ASSERT_TRUE(Fb.BucketCommit.CommitOpen, 'Commit ouvert apres deux succes');
    ASSERT_FALSE(Fb.BucketCommit.CommitClose, 'Commit ferme exclusif');
END_TEST
