(* =========================================================================
   TEST CI AD HOC - Atomicite commande Both M1/M2 (T216, criticite C4)
   -------------------------------------------------------------------------
   Prouve les invariants de securite du depart couple des treuils M1/M2 :
     #1  Atomicite Both descente : BothDescendPermit=FALSE (un permit M2 absent)
         -> AUCUN des deux treuils ne demarre (StartStop M1=FALSE ET M2=FALSE).
     #2  Both nominal montee : les 2 permits agreges OK -> les DEUX demarrent.
     #3  Preservation unitaire : M1 seul / M2 seul / action benne M2 -> le gate
         Both*Permit est inactif, comportement inchange (aucun blocage croise).
     #4  Soft-stop : Both + ecart mineur -> jamais de demarrage unilateral (les 2
         bloques ensemble si le permit Both manque) ; hors Both (unitaire), l'ecart
         mineur bloque toujours le sens concerne (comportement preserve).
   Noms figes T216 intacts : EffectivePermitM1/2_Ascent/Descend non re-nommes.
   Chaque appel arb1(...)/arb2(...) = 1 scan de l'arbitre.
   (Le gate sync mineur de PRG_04 est coupe en Both en amont - voir le FB - ici on
   prouve que l'arbitre ne part JAMAIS seul, quelle que soit la polarite du flag.)
   ========================================================================= *)

SETUP
VAR
    arb1 : FB_WinchCmdArbitrationM1;
    arb2 : FB_WinchCmdArbitrationM2;
    joy  : ST_AcquisitionJoystickQualified;
    auth : ST_Modes_Autorisations;
    req  : ST_ProgramWinchRequest;
    both : ST_WinchBothIntent;
    ihm  : ST_fbWinchCmdArbitration_IHM;
    ctx  : ST_fbWinchCmdArbitration_Context;
    cfg1 : ST_fbWinchCmdArbitration_Cfg;
    cfg2 : ST_fbWinchCmdArbitration_Cfg;
END_VAR
END_SETUP

TEST 'T216 #1 Atomicite Both descente : BothDescendPermit=FALSE -> AUCUN treuil ne demarre'
    // Contexte : mode manuel boutons, intention both descente active.
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 0;
    both.Active := TRUE; both.Direction := -1;
    // Simule EffectivePermitM2_Descend=FALSE -> BothDescendPermit=FALSE (agregat PRG_04).
    ctx.BothDescendPermit := FALSE; ctx.BothAscentPermit := TRUE;
    ctx.BothBlock := TRUE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    ctx.SyncBlocksAscent := FALSE; ctx.SyncBlocksDescent := FALSE;
    ihm.BtnAscentM1 := FALSE; ihm.BtnDescentM1 := FALSE;
    ihm.BtnAscentM2 := FALSE; ihm.BtnDescentM2 := FALSE;
    cfg1.BtnStepTgt := 5; cfg2.BtnStepTgt := 5; cfg2.BucketOverrideStepTgt := 1;

    arb1(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg1);
    arb2(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg2);

    ASSERT_FALSE(arb1.StartStop, 'T216#1 Both descente : StartStop M1=FALSE (permit Both manquant)');
    ASSERT_FALSE(arb2.StartStop, 'T216#1 Both descente : StartStop M2=FALSE (permit Both manquant)');
    ASSERT_EQ(arb1.Direction, -1, 'T216#1 l intention descente est portee, seule la commande est coupee');
END_TEST

TEST 'T216 #2 Both nomiinal montee : permits OK -> les DEUX demarrent ensemble'
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 0;
    both.Active := TRUE; both.Direction := 1;
    ctx.BothDescendPermit := TRUE; ctx.BothAscentPermit := TRUE;
    ctx.BothBlock := FALSE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    ctx.SyncBlocksAscent := FALSE; ctx.SyncBlocksDescent := FALSE;
    ihm.BtnAscentM1 := FALSE; ihm.BtnDescentM1 := FALSE;
    ihm.BtnAscentM2 := FALSE; ihm.BtnDescentM2 := FALSE;
    cfg1.BtnStepTgt := 5; cfg2.BtnStepTgt := 5; cfg2.BucketOverrideStepTgt := 1;

    arb1(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg1);
    arb2(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg2);

    ASSERT_TRUE(arb1.StartStop, 'T216#2 Both montee : M1 demarre (permit OK)');
    ASSERT_TRUE(arb2.StartStop, 'T216#2 Both montee : M2 demarre (permit OK)');
    ASSERT_EQ(arb1.Direction, 1, 'T216#2 M1 sens montee');
    ASSERT_EQ(arb2.Direction, 1, 'T216#2 M2 sens montee');
END_TEST

TEST 'T216 #3a M1 seul : gate Both inactif (pas de blocage croise)'
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 1;
    both.Active := FALSE; both.Direction := 0;
    // Meme si les permits Both sont faux, le pilotage unitaire M1 n'en depend pas.
    ctx.BothDescendPermit := FALSE; ctx.BothAscentPermit := FALSE;
    ctx.BothBlock := FALSE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    ctx.SyncBlocksAscent := FALSE; ctx.SyncBlocksDescent := FALSE;
    ihm.BtnAscentM1 := TRUE; ihm.BtnDescentM1 := FALSE;
    cfg1.BtnStepTgt := 5; cfg2.BtnStepTgt := 5; cfg2.BucketOverrideStepTgt := 1;

    arb1(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg1);

    ASSERT_TRUE(arb1.StartStop, 'T216#3a M1 seul : demarre (couplage Both inactif)');
    ASSERT_EQ(arb1.Direction, 1, 'T216#3a M1 sens montee');
END_TEST

TEST 'T216 #3b M2 seul : gate Both inactif (pas de blocage croise)'
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 2;
    both.Active := FALSE; both.Direction := 0;
    ctx.BothDescendPermit := FALSE; ctx.BothAscentPermit := FALSE;
    ctx.BothBlock := FALSE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    ctx.SyncBlocksAscent := FALSE; ctx.SyncBlocksDescent := FALSE;
    ihm.BtnAscentM2 := TRUE;

    arb2(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg2);

    ASSERT_TRUE(arb2.StartStop, 'T216#3b M2 seul : demarre (couplage Both inactif)');
    ASSERT_EQ(arb2.Direction, 1, 'T216#3b M2 sens montee');
END_TEST

TEST 'T216 #3c benne M2 : chemin override preserve (hors gate Both)'
    auth.Mode := E_Mode.MAINT_N1;
    both.Active := FALSE; both.Direction := 0;
    ctx.BothDescendPermit := FALSE; ctx.BothAscentPermit := FALSE;
    ctx.BothBlock := FALSE;
    // Action benne M2 active (chemin override FB_WinchCmdArbitrationM2).
    ctx.BucketBusy := TRUE; ctx.BucketM2StartStop := TRUE; ctx.BucketM2Open := TRUE;
    ctx.WinchBothMotionBlockedByBucket := FALSE;
    ctx.SyncBlocksAscent := FALSE; ctx.SyncBlocksDescent := FALSE;
    cfg2.BucketOverrideStepTgt := 1;

    arb2(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg2);

    ASSERT_TRUE(arb2.StartStop, 'T216#3c action benne M2 : demarre (override hors gate Both)');
    ASSERT_EQ(arb2.StepTgt, 1, 'T216#3c action benne M2 : palier lent override');
END_TEST

TEST 'T216 #4a Both + ecart mineur : JAMAIS de demarrage unilateral (les DEUX bloques)'
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 0;
    both.Active := TRUE; both.Direction := -1;
    ctx.BothDescendPermit := FALSE;   // un permit Both manquant (M2)
    ctx.BothAscentPermit := TRUE;
    ctx.BothBlock := TRUE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    // M1 bloque sur SyncBlocksAscent ; en descente M2 bloque sur SyncBlocksDescent.
    // Quelle que soit la polarite, le gate Both (permit manquant) bloque les DEUX.
    ctx.SyncBlocksAscent := TRUE; ctx.SyncBlocksDescent := TRUE;

    arb1(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg1);
    arb2(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg2);

    ASSERT_FALSE(arb1.StartStop, 'T216#4a Both + ecart : M1 bloque (pas de depart unilateral)');
    ASSERT_FALSE(arb2.StartStop, 'T216#4a Both + ecart : M2 bloque (pas de depart unilateral)');
END_TEST

TEST 'T216 #4b unite + ecart mineur : le sens concerne reste bloque (preservation)'
    auth.Mode := E_Mode.MAINT_N1;
    auth.JoystickWinchSelectArbitrated := 1;
    both.Active := FALSE; both.Direction := 0;
    ctx.BothDescendPermit := FALSE; ctx.BothAscentPermit := FALSE;
    ctx.BothBlock := FALSE;
    ctx.BucketBusy := FALSE; ctx.WinchBothMotionBlockedByBucket := FALSE;
    // Montee M1 bloquee par l'ecart mineur si SyncBlocksAscent (comportement d'origine
    // hors Both, preserve).
    ctx.SyncBlocksAscent := TRUE; ctx.SyncBlocksDescent := FALSE;
    ihm.BtnAscentM1 := TRUE;

    arb1(Enable := TRUE, Joystick := joy, Auth := auth, ReqWinch := req,
         BothIntent := both, IHM := ihm, TglJoystickMaster := FALSE,
         Context := ctx, Cfg := cfg1);

    ASSERT_FALSE(arb1.StartStop, 'T216#4b M1 seul + ecart mineur montee : bloque (comportement preserve hors Both)');
END_TEST
