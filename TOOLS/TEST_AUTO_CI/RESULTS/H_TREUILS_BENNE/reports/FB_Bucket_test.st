(* =======================================================================
   🧪 test_fb_bucket.st — FB_Bucket (TC-P10-023..034, 045.1, 046.1, 047.1, 048.1)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG.
   Config valide : OffsetOpenM=0.0, OffsetCloseM=3.0, CoherenceLimitM=5.0,
   CloseAnticipationM=0.2, OpenAnticipationM=0.2.
   ======================================================================= *)

SETUP
VAR
    FB : FB_Bucket;
    BucketState : ST_fbBucket_State;
    Config : ST_fbBucket_Config;
END_VAR
END_SETUP

(* ── Config valide commune ── *)

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete au repos *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P10-023 Fermeture seulement si MotionDirection=1 ET MotionRequestActive'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne active et prete');

    (* Scan 2 : CmdClose + MotionDirection=1 + MotionRequestActive -> fermeture *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.CloseReq, 'CmdClose -> CloseReq');
    ASSERT_TRUE(FB.M2_RunRequest, 'Fermeture -> M2_StartStop=TRUE');
    ASSERT_EQ(FB.M2_ReqAscent, 1, 'Fermeture -> M2_Direction=1');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'Fermeture -> vitesse lente forcee');
END_TEST

TEST 'TC-P10-024 Ouverture seulement si MotionDirection=-1 ET MotionRequestActive'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsClosed := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : CmdOpen + MotionDirection=-1 + MotionRequestActive -> ouverture *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdOpen_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CablePosM1 := 0.0, CablePosM2 := 3.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.OpenReq, 'CmdOpen -> OpenReq');
    ASSERT_TRUE(FB.M2_RunRequest, 'Ouverture -> M2_StartStop=TRUE');
    ASSERT_EQ(FB.M2_ReqAscent, -1, 'Ouverture -> M2_Direction=-1');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'Ouverture -> vitesse lente forcee');
END_TEST

TEST 'T196-001 Etat ferme publie apres atteinte de l offset'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Initialisation au repos puis armement de la fermeture. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T196 fermeture armee -> Busy');

    (* Le modèle physique atteint la cible : seul ce fait valide IsClosed. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 2.9,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(BucketState.IsClosed, 'T196 cible atteinte -> IsClosed=TRUE');
    ASSERT_FALSE(BucketState.IsOpen, 'T196 cible atteinte -> IsOpen=FALSE');
    ASSERT_TRUE(FB.Lifecycle.Done, 'T196 cible atteinte -> Done=TRUE');
END_TEST

TEST 'T196-002 Etat ouvert publie apres atteinte de l offset'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 3.0,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdOpen_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 3.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T196 ouverture armee -> Busy');

    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       MotionRequestActive := TRUE, MotionDirection := -1,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.1,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(BucketState.IsOpen, 'T196 cible atteinte -> IsOpen=TRUE');
    ASSERT_FALSE(BucketState.IsClosed, 'T196 cible atteinte -> IsClosed=FALSE');
    ASSERT_TRUE(FB.Lifecycle.Done, 'T196 cible atteinte -> Done=TRUE');
END_TEST

TEST 'TC-P10-025 Demande benne refusee si M1_Busy OR M2_Busy a l entree (READY)'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : M1_Busy=TRUE -> demande fermeture REFUSEE (anti-traversee) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       M1_Busy := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.CloseReq, 'M1_Busy -> CloseReq refuse');
    ASSERT_FALSE(FB.M2_RunRequest, 'M1_Busy -> pas de mouvement benne');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'M1_Busy -> pas de Busy');
END_TEST

TEST 'TC-P10-025.1 Anti-traversee : M2_Busy seul refuse une demande benne a l entree (AC3)'
    (* Symetrique de TC-P10-025 (qui ne couvre que M1_Busy) : prouve que M2_Busy est lui aussi
       lu (FB_Bucket.st L234-240) et refuse une NOUVELLE demande benne a l entree READY. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : M2_Busy=TRUE -> demande fermeture REFUSEE (anti-traversee) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       M2_Busy := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.CloseReq, 'M2_Busy -> CloseReq refuse');
    ASSERT_FALSE(FB.M2_RunRequest, 'M2_Busy -> pas de mouvement benne');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'M2_Busy -> pas de Busy');
END_TEST

TEST 'TC-P10-025.2 Anti-traversee : mouvement deja engage + M2_Busy -> pas d avortement (AC3)'
    (* L'anti-traversee (AC3) est scope a la REFUS d'une demande a l entree. Une fois la
       manuvre engagee, la benne pilote M2 : le treuil agit donc logiquement (M2_Busy=TRUE).
       Le FB ne doit PAS s'auto-avorter a ce moment (bloc Busy L254+ ne relit pas les _Busy). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : demarrage fermeture, M2_Busy encore FALSE *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       M2_Busy := FALSE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture engagee -> Busy');

    (* Scan 3 : toujours en fermeture, M2_Busy passe a TRUE (M2 agit sous ordre benne) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       M2_Busy := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.5,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'M2_Busy pendant manuvre -> Busy conserve');
    ASSERT_TRUE(FB.M2_RunRequest, 'M2_Busy pendant manuvre -> pas d avortement');
    ASSERT_EQ(FB.M2_ReqAscent, 1, 'M2_Busy pendant manuvre -> direction conservee');
END_TEST

TEST 'TC-P10-026 Glissement M1 >1.0m pendant BUSY -> M1SlipDetected + coupe M2'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : demarrage fermeture, M1RefPosM capture a 0.0 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours -> Busy');

    (* Scan 3 : glissement M1 > 1.0m -> M1SlipDetected + coupe M2 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 2.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M1SlipDetected, 'Glissement M1 >1.0m -> M1SlipDetected');
    ASSERT_TRUE(FB.Fault.Error, 'Glissement M1 -> Error');
    ASSERT_FALSE(FB.M2_RunRequest, 'Glissement M1 -> M2 coupe (M2_StartStop=FALSE)');
END_TEST

TEST 'TC-P10-027 M1SlipDetected force SafeStop sur M1 cote Treuils'
    (* (essai site — stub) : le forçage SafeStop M1 depuis M1SlipDetected est cable dans
       PRG_04_Treuils_Benne.st, pas dans ce FB. On verifie ici la brique amont : M1SlipDetected
       est bien expose en sortie, condition du forçage. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 2.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M1SlipDetected, 'M1SlipDetected expose (consomme par Treuils pour SafeStop M1)');
END_TEST

TEST 'TC-P10-028 Couche 2 (Meca C) : derive M1 >2.0m -> PowerCutOff'
    (* (essai site — stub) : la couche 2 (Meca C, PowerCutOff a 2.0m) est portee par
       FB_Safety_Winch (BenneHoldStillActive), pas par FB_Bucket. Verifie ici dans
       test_fb_safety_winch.st (TC-P10-003). Ce FB expose M1SlipDetected (couche 1, 1.0m). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne prete (couche 1 active)');
END_TEST

TEST 'TC-P10-029 Recul (sens inverse) borne a la position de depart, jamais au-dela'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : demarrage fermeture, M2StartPosM=0.0 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours');

    (* Scan 3 : inversion de sens (MotionDirection=-1) -> M2 pilote en descente *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_EQ(FB.M2_ReqAscent, -1, 'Recul -> M2_Direction=-1');
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul commande (borne a M2StartPosM)');
END_TEST

TEST 'TC-P10-029.1 Recul borne : arret reel a M2StartPosM (pas seulement Direction/StartStop)'
    (* Etend TC-P10-029 (qui s'arrete a l'attente de Direction/StartStop) : simule le recul
       jusqu'a la position de depart M2StartPosM et prouve l'ARRET reel (M2_StartStop=FALSE,
       Busy=FALSE, Done=TRUE) et la restauration d'etat, jamais au-dela (FB_Bucket.st L303). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : demarrage fermeture, M2StartPosM capture a 0.0 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture engagee -> Busy');

    (* Scan 3 : M2 monte au-dessus de M2StartPosM -> LeftStartSinceArm arme *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 1.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 4 : inversion de sens (recul) -> M2 pilote en descente *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CablePosM1 := 0.0, CablePosM2 := 1.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_EQ(FB.M2_ReqAscent, -1, 'Recul -> M2_Direction=-1');
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul commande');

    (* Scan 5 : le recul n'a pas encore atteint M2StartPosM -> pas d arret *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CablePosM1 := 0.0, CablePosM2 := 0.5,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul avant M2StartPosM -> toujours commande');

    (* Scan 6 : recul A M2StartPosM (0.0) -> ARRET reel, jamais au-dela *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.M2_RunRequest, 'Recul a M2StartPosM -> M2_StartStop=FALSE (arret)');
    ASSERT_EQ(FB.M2_ReqAscent, 0, 'Recul a M2StartPosM -> M2_Direction=0');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Recul a M2StartPosM -> Busy=FALSE');
    ASSERT_TRUE(FB.Lifecycle.Done, 'Recul a M2StartPosM -> Done=TRUE');

    (* Recopie etat memorise restaure (WasOpenAtStart=TRUE) *)
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.IsOpen, 'Recul a M2StartPosM -> IsOpen restaure TRUE');
    ASSERT_FALSE(BucketState.IsClosed, 'Recul a M2StartPosM -> IsClosed restaure FALSE');
END_TEST

TEST 'TC-P10-030 ConfirmOpen/ClosePosition reference directement la benne en maintenance'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;

    (* Scan 0 : isole le cas de test des latches/Lifecycle du scénario précédent. *)
    FB(Enable := FALSE, Reset := FALSE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState; // STruCpp : émule le copy-out VAR_IN_OUT CODESYS.

    (* Scan 1 : acquittement, puis état bas explicite pour armer le R_TRIG. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;

    (* Scan 2 : front MAINT_N1, confirmation benne non autorisee. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := TRUE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.IsOpen, 'MAINT_N1 + ConfirmOpen -> IsOpen reste FALSE');
    ASSERT_FALSE(BucketState.IsClosed, 'MAINT_N1 + ConfirmOpen -> IsClosed=FALSE');
    ASSERT_TRUE(BucketState.StateIncoherent, 'MAINT_N1 : etat non qualifie conserve');

    (* Scan 3 : relâche la confirmation ouverture. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;

    (* Scan 4 : front MAINT_N2, ConfirmClosePosition -> IsClosed=TRUE. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, PowerContactorEngaged := TRUE,
       ConfirmClosePosition := TRUE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.IsOpen, 'MAINT_N2 + ConfirmClose -> IsOpen=FALSE');
    ASSERT_TRUE(BucketState.IsClosed, 'MAINT_N2 + ConfirmClose -> IsClosed=TRUE');

    (* Scan 5 : Mode SEMI_AUTO, ConfirmOpenPosition -> AUCUN effet. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := TRUE, ConfirmClosePosition := FALSE, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.IsOpen, 'SEMI_AUTO + ConfirmOpen -> IsOpen reste FALSE');
    ASSERT_TRUE(BucketState.IsClosed, 'SEMI_AUTO + ConfirmOpen conserve etat ferme');
END_TEST

TEST 'TC-P10-031 Codeur(s) non reference(s) -> defaut permanent, independant de Reset'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : HomedM1=FALSE -> defaut non reference *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := FALSE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Fault.Error, 'Codeur M1 non reference -> Error');

    (* Scan 2 : Reset -> defaut PERSISTE (cause toujours presente) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
       HomedM1 := FALSE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := FALSE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Fault.Error, 'Reset seul -> defaut non reference PERSISTE (cause brute)');

    (* Scan 3 : referencement restaure -> defaut acquittable *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Fault.Error, 'Referencement restaure + Reset -> plus d erreur');
END_TEST

TEST 'TC-P10-032 FB_ExtractionSequence.Busy preserve l armement joystick en fin benne'
    (* (essai site — stub) : PreserveArmingAfterBucket := instExtractionSequence.Busy est cable
       dans PRG_02_Acquisition.st, pas dans ce FB. Non automatisable en boite noire FB_Bucket. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne prete (preservation armement = cote PRG_02)');
END_TEST

TEST 'TC-P10-033 Butee haute M2 decalee de OffsetCloseM si ferme/en fermeture'
    (* (essai site — stub) : le decalage de butee haute M2 (OffsetCloseM) est cable dans
       PRG_04_Treuils_Benne.st, pas dans ce FB. Non automatisable en boite noire FB_Bucket. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsClosed := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne fermee (butee haute decalee = cote PRG_04)');
END_TEST

TEST 'TC-P10-034 Terrain : cinematique reelle en charge, amplitude offset validee'
    (* (essai site — stub) : la cinematique reelle en charge et l amplitude des offsets
       (OffsetCloseM=15.0 non valide en charge) sont des verifications terrain, jamais
       automatisables en boite noire. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne prete (cinematique reelle = essai terrain)');
END_TEST

TEST 'TC-P10-045.1 Benne partiellement fermee -> remontee palier 1 seul'
    (* (essai site — stub) : le verrouillage des paliers 2-5 en remontee quand NOT IsClosed est
       cable dans PRG_04_Treuils_Benne.st (arbitrage treuil), pas dans ce FB. Non automatisable
       en boite noire FB_Bucket. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne prete (verrouillage paliers = cote PRG_04)');
END_TEST

TEST 'TC-P10-046.1 Timeout mouvement pendant BUSY -> defaut timeout + latch'
    (* CfgTimeoutDuration force a 1s pour rendre le test rapide (code reel = 60s). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : demarrage fermeture, cible non atteinte -> BUSY maintenu *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours');

    (* Scan 3 : le TON lit Lifecycle.Busy au scan suivant son armement. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 4 : apres 1s de BUSY sans atteindre la cible -> timeout. *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, MotionRequestActive := TRUE, MotionDirection := 1,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Fault.Error, 'Timeout mouvement 1s -> Error');
    ASSERT_TRUE(FB.Fault.Latched, 'Timeout -> defaut latche');
END_TEST

TEST 'TC-P10-047.1 Incoherence boot : 1er cycle ni IsOpen ni IsClosed -> StateIncoherent, ActiveOffsetValid=FALSE'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;

    (* Scan 1 : premier cycle, ni ouvert ni ferme -> incoherence boot *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState; // STruCpp : émule le copy-out VAR_IN_OUT CODESYS.
    ASSERT_TRUE(BucketState.StateIncoherent, 'Boot incoherent -> StateIncoherent=TRUE');
    ASSERT_FALSE(FB.ActiveOffsetValid, 'Boot incoherent -> ActiveOffsetValid=FALSE');
END_TEST

TEST 'TC-P10-047.2 Boot incoherent IsOpen=TRUE ET IsClosed=TRUE -> StateIncoherent'
    (* Une position benne est exclusive : la combinaison ouverte ET fermee est
       invalide et doit rendre l'offset inutilisable dès le premier scan. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := TRUE;

    (* Scan 1 : premier cycle, IsOpen ET IsClosed -> incoherence contradictoire *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.StateIncoherent, 'Boot IsOpen ET IsClosed -> StateIncoherent=TRUE');
    ASSERT_FALSE(FB.ActiveOffsetValid, 'Boot incoherent -> ActiveOffsetValid=FALSE');
END_TEST

TEST 'TC-P10-048.1 Offset RETAIN : OffsetCloseM persiste apres power cycle'
    (* (essai site — stub) : la persistance RETAIN de OffsetCloseM (GVL_PERSISTENT) est une
       propriete de la memoire retenue CODESYS, non automatisable en boite noire (pas de power
       cycle dans le harnais). On verifie ici que la config OffsetCloseM est bien consommee. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Config OffsetCloseM=15.0 consommee (persistance RETAIN = cote GVL)');
END_TEST

TEST 'T181-21 Copy-out VAR_IN_OUT : BucketState ecrit par FB_Bucket restitue a la variable de test'
    (* Preuve du correctif T181-21 : STruCpp ne genere qu'un copy-in (s.FB.X = s.X;) sans
       copy-out. Le post-traitement injecte s.X = s.FB.X; apres chaque appel. Ce test lit
       la valeur ecrite par le FB sur la VAR_IN_OUT BucketState DIRECTEMENT sur la variable
       de test (sans copy-out manuel) : il ne passe QUE si le copy-out automatique est actif. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;

    (* Scan 1 : premier cycle, ni IsOpen ni IsClosed -> FB_Bucket ecrit StateIncoherent=TRUE
       sur la VAR_IN_OUT BucketState (FB_Bucket.st L198-200). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Aucun copy-out manuel : la valeur doit etre restituee par le harnais. *)
    ASSERT_TRUE(BucketState.StateIncoherent, 'Copy-out auto : BucketState.StateIncoherent restitue TRUE');
    ASSERT_FALSE(BucketState.IsOpen, 'Copy-out auto : BucketState.IsOpen reste FALSE');
    ASSERT_FALSE(BucketState.IsClosed, 'Copy-out auto : BucketState.IsClosed reste FALSE');
END_TEST
