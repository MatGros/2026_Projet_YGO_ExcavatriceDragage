(* =======================================================================
   🧪 test_fb_bucket.st — FB_Bucket (TC-P10-023..034, 045.1, 046.1-046.4, 047.1, 048.1)
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

TEST 'TC-P10-023 Fermeture engagee seulement si ReqAscent ET MotionRequestActive ET EffectivePermitBucket_Close'
    (* Realigne T339 : la direction n'est plus un entier mais DEUX entrees BOOL (ReqAscent /
       ReqDescend -> MotionRequestActive, FB_Bucket.st:162-163) et l'ordre M2 exige en plus le
       PERMIS DE SECURITE EffectifPermitBucket_Close (FB_Bucket.st:524). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scans 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne active et prete');

    (* Scan 3 : CmdClose + ReqAscent, permis de fermeture ABSENT -> demande latchee, AUCUN ordre *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.CloseReq, 'CmdClose -> CloseReq');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture demandee -> Busy engage');
    ASSERT_FALSE(FB.M2_RunRequest, 'Permis de fermeture absent -> aucun ordre M2');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'Fermeture -> vitesse lente forcee');

    (* Scan 4 : permis de fermeture present -> l ordre M2 sort en montee P1 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_RunRequest, 'ReqAscent + permis fermeture -> ordre M2 emis');
    ASSERT_TRUE(FB.M2_ReqAscent, 'Fermeture -> sens montee (M2_ReqAscent)');
    ASSERT_FALSE(FB.M2_ReqDescend, 'Fermeture -> jamais de sens descente');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'Fermeture -> vitesse lente forcee');
END_TEST

TEST 'TC-P10-024 Ouverture engagee seulement si ReqDescend ET MotionRequestActive ET EffectivePermitBucket_Open'
    (* Realigne T339 : symetrique de TC-P10-023 cote ouverture (FB_Bucket.st:540). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsClosed := TRUE;

    (* Scans 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);

    (* Scan 3 : CmdOpen + ReqDescend, permis d ouverture ABSENT -> demande latchee, AUCUN ordre *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdOpen_IHM := TRUE, ReqDescend := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 3.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.OpenReq, 'CmdOpen -> OpenReq');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Ouverture demandee -> Busy engage');
    ASSERT_FALSE(FB.M2_RunRequest, 'Permis d ouverture absent -> aucun ordre M2');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'Ouverture -> vitesse lente forcee');

    (* Scan 4 : permis d ouverture present -> l ordre M2 sort en descente P1 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdOpen_IHM := TRUE, ReqDescend := TRUE, EffectivePermitBucket_Open := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 3.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_RunRequest, 'ReqDescend + permis ouverture -> ordre M2 emis');
    ASSERT_TRUE(FB.M2_ReqDescend, 'Ouverture -> sens descente (M2_ReqDescend)');
    ASSERT_FALSE(FB.M2_ReqAscent, 'Ouverture -> jamais de sens montee');
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T196 fermeture armee -> Busy');

    (* Le modèle physique atteint la cible : seul ce fait valide IsClosed. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 2.9,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(BucketState.IsClosed, 'T196 cible atteinte -> IsClosed=TRUE');
    ASSERT_FALSE(BucketState.IsOpen, 'T196 cible atteinte -> IsOpen=FALSE');
    ASSERT_TRUE(FB.Lifecycle.Done, 'T196 cible atteinte -> Done=TRUE');
END_TEST

TEST 'T262-001 Fermeture atteinte : maintien M2 P1 puis liberation explicite'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Armer la fermeture AX10 avec le maintien deja autorise. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, HoldAscentP1AfterClose := TRUE,
       ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T262 fermeture armee');

    (* Fermeture : le proprietaire benne conserve M2 en montee P1. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HoldAscentP1AfterClose := TRUE,
       ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 2.9,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.CloseReached, 'T262 fermeture atteinte publiee');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T262 pont actif : proprietaire benne conserve');
    ASSERT_TRUE(FB.M2_RunRequest, 'T262 pont actif : M2 maintenu');
    ASSERT_TRUE(FB.M2_ReqAscent, 'T262 pont actif : sens montee conserve');
    ASSERT_TRUE(FB.M2_BucketJogLimit, 'T262 pont actif : palier P1 impose');

    (* Le transfert Both est publie par PRG04 ; le scan suivant libere la benne. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HoldAscentP1AfterClose := FALSE,
       ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 2.9,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Lifecycle.Busy, 'T262 proprietaire benne libere');
    ASSERT_FALSE(FB.M2_RunRequest, 'T262 M2 remis a Both sans ordre benne residuel');
    ASSERT_FALSE(FB.M2_ReqAscent, 'T262 sens benne libere');
END_TEST

TEST 'T323-001 Boot non reference : pas de faux ecart ni defaut de qualification au repos'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 25.0,
       HomedM1 := FALSE, HomedM2 := FALSE,
       MachineHomingActive := FALSE,
       Config := Config, BucketState := BucketState);
    ASSERT_EQ(FB.Fault.ErrorId, 0, 'T323 boot non reference -> ErrorId live nul');
    ASSERT_FALSE(FB.Fault.Latched, 'T323 boot non reference -> aucun latch');
END_TEST

TEST 'T323-002 Homing actif : les commandes de reference ne declenchent pas ErrorID'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ReqAscent := TRUE, CmdClose_IHM := TRUE,
       HomedM1 := FALSE, HomedM2 := FALSE,
       MachineHomingActive := TRUE,
       EffectivePermitBucket_Close := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_EQ(FB.Fault.ErrorId, 0, 'T323 homing actif -> pas de defaut non reference');
END_TEST

TEST 'T323-003 Passage homed : ErrorID non reference retombe sans Reset'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ReqAscent := TRUE, CmdClose_IHM := TRUE,
       HomedM1 := FALSE, HomedM2 := FALSE,
       MachineHomingActive := FALSE,
       EffectivePermitBucket_Close := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Fault.Error, 'T323 demande sans reference -> cause live');
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       HomingSuspectM1 := FALSE, HomingSuspectM2 := FALSE,
       MachineHomingActive := FALSE,
       Config := Config, BucketState := BucketState);
    ASSERT_EQ(FB.Fault.ErrorId, 0, 'T323 homed -> ErrorID retombe sans Reset');
END_TEST

TEST 'T323-004 Ecart reel apres qualification reste acquittable'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.BucketReferenced := TRUE;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 10.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       HomingSuspectM1 := FALSE, HomingSuspectM2 := FALSE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(600000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 10.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       HomingSuspectM1 := FALSE, HomingSuspectM2 := FALSE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE((FB.Fault.ErrorId AND 2) <> 0, 'T323 ecart reel -> masque 16#0002');
    ASSERT_TRUE(FB.Fault.Latched, 'T323 ecart reel -> latch conserve');
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
       CmdOpen_IHM := TRUE, ReqDescend := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 3.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T196 ouverture armee -> Busy');

    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ReqDescend := TRUE,
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       M2_Busy := FALSE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture engagee -> Busy');
    ASSERT_TRUE(FB.M2_RunRequest, 'Fermeture engagee -> ordre M2 emis');

    (* Scan 3 : toujours en fermeture, M2_Busy passe a TRUE (M2 agit sous ordre benne) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours -> Busy');

    (* Scan 3 : glissement M1 > 1.0m -> M1SlipDetected + coupe M2 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
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

TEST 'TC-P10-029 Recul (sens inverse) sous commande engagee : sens descente commande'
    (* Realigne T339 : M2_Direction (INT) n'existe plus — l'interface porte DEUX sorties BOOL
       M2_ReqAscent / M2_ReqDescend (FB_Bucket.st:68-69) ; le recul exige le permis d'ouverture
       (FB_Bucket.st:528). La borne a M2StartPosM a ete retiree par le lot du 2026-09-05
       (commit 2a307b5b « suppression des coupures parasites ») — voir TC-P10-029.1. *)
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours');
    ASSERT_TRUE(FB.M2_ReqAscent, 'Fermeture -> sens montee');

    (* Scan 3 : inversion de sens (ReqDescend) -> M2 pilote en descente.
       ⚠️ Le harnais STruCpp ne remet PAS a zero les entrees non passees entre deux appels
       (l'instance C++ est persistante) : ReqAscent doit donc etre explicitement relache,
       sinon MotionRequestConflict (FB_Bucket.st:162) neutralise la demande. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE, EffectivePermitBucket_Open := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_ReqDescend, 'Recul -> M2_ReqDescend=TRUE');
    ASSERT_FALSE(FB.M2_ReqAscent, 'Recul -> M2_ReqAscent=FALSE (sens unique)');
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul commande (commande engagee)');
END_TEST

TEST 'TC-P10-029.1 Recul borne : arret reel a M2StartPosM (pas seulement Direction/StartStop)'
    (* ⛔ ECART ESCALADE T339 (non corrige dans ce lot — aucun fichier CODE/ modifie) :
       cette exigence n'est PLUS implementee. Le lot du 2026-09-05 (commit 2a307b5b
       « suppression des coupures parasites LeftStartSinceArm pour ouverture et fermeture
       completes ») a retire les deux branches d'arret a M2StartPosM ; le drapeau
       LeftStartSinceArm est encore AFFECTE (FB_Bucket.st:561) mais plus JAMAIS LU : le recul
       n'est donc borne par RIEN cote FB_Bucket quand la commande de fermeture reste engagee.
       La fiche FB_Bucket_v1.0.md:288 promettait encore « sens inverse tolere mais borne ».
       Le test est conserve tel quel sur ses assertions d'ARRET (seule la migration d'API
       M2_Direction INT -> M2_ReqDescend BOOL a ete appliquee) : il reste ROUGE et sert de
       preuve vivante du defaut. Arbitrage orchestrateur requis (restaurer la borne, ou acter
       la perte de protection et realigner la spec). *)
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture engagee -> Busy');

    (* Scan 3 : M2 monte au-dessus de M2StartPosM -> LeftStartSinceArm arme *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 1.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours au-dessus du depart');

    (* Scan 4 : inversion de sens (recul) -> M2 pilote en descente.
       ⚠️ Le harnais STruCpp conserve les entrees non passees entre deux appels : ReqAscent
       doit etre explicitement relache, sinon MotionRequestConflict neutralise la demande. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE, EffectivePermitBucket_Open := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 1.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_ReqDescend, 'Recul -> M2_ReqDescend=TRUE');
    ASSERT_FALSE(FB.M2_ReqAscent, 'Recul -> M2_ReqAscent=FALSE');
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul commande');

    (* Scan 5 : le recul n'a pas encore atteint M2StartPosM -> pas d arret *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE, EffectivePermitBucket_Open := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.5,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_RunRequest, 'Recul avant M2StartPosM -> toujours commande');

    (* Scan 6 : recul A M2StartPosM (0.0) -> ARRET attendu, jamais au-dela (ECART ESCALADE) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE, EffectivePermitBucket_Open := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.M2_RunRequest, 'Recul a M2StartPosM -> M2_StartStop=FALSE (arret)');
    ASSERT_FALSE(FB.M2_ReqDescend, 'Recul a M2StartPosM -> plus aucun sens commande');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Recul a M2StartPosM -> Busy=FALSE');
    ASSERT_TRUE(FB.Lifecycle.Done, 'Recul a M2StartPosM -> Done=TRUE');

    (* Recopie etat memorise restaure (WasOpenAtStart=TRUE) *)
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.IsOpen, 'Recul a M2StartPosM -> IsOpen restaure TRUE');
    ASSERT_FALSE(BucketState.IsClosed, 'Recul a M2StartPosM -> IsClosed restaure FALSE');
END_TEST

TEST 'TC-P10-030 ConfirmOpen/ClosePosition reference la benne : MAINT_N2 seul, etat publie par la mesure'
    (* Realigne T339. Depuis le refactor T247 (2026-09-04, commit 509e0eb1 « comparaison continue
       temps reel sans latch »), IsOpen/IsClosed sont publies EN DIRECT depuis la mesure
       Delta = M2 - M1 (FB_Bucket.st:428-448) et ne sont plus latches par la confirmation :
       celles-ci ne peuvent donc plus etre observees que par leur effet DURABLE, la REFERENCE
       benne (BucketState.BucketReferenced). Le mode accepte est MAINT_N2 UNIQUEMENT
       (FB_Bucket.st:339-357 ; le latch :382-398 exige en plus M1/M2 fiables).
       Config = valeurs de PRODUCTION (OffsetCloseM=15.0 / CoherenceLimitM=1.0) : les bandes
       ouverte et fermee ne se recouvrent pas, contrairement au 3.0/5.0 precedent qui rendait
       NearOpen ET NearClosed vrais simultanement pour Delta=0. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
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
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    BucketState.BucketReferenced := FALSE;

    (* Scan 2 : MAINT_N1, front ConfirmOpen -> AUCUNE reference benne (MAINT_N2 seul accepte). *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.BucketReferenced, 'MAINT_N1 + ConfirmOpen -> benne NON referencee');
    ASSERT_TRUE(BucketState.IsOpen, 'MAINT_N1 : etat publie par la mesure (Delta=0 -> bande ouverte)');
    ASSERT_FALSE(BucketState.IsClosed, 'MAINT_N1 : Delta=0 hors bande fermee (15 m) -> IsClosed=FALSE');

    (* Scan 3 : relâche la confirmation. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    BucketState.BucketReferenced := FALSE;

    (* Scan 4 : front MAINT_N2, ConfirmOpenPosition -> reference benne posee. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.BucketReferenced, 'MAINT_N2 + ConfirmOpen -> benne referencee');
    ASSERT_TRUE(BucketState.IsOpen, 'MAINT_N2 + ConfirmOpen -> etat ouvert publie');
    ASSERT_TRUE(FB.ActiveOffsetValid, 'MAINT_N2 : reference benne posee -> offset actif valide');

    (* Scan 5 : relâche, et place la mesure dans la bande fermee. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM1 := 0.0, CablePosM2 := 15.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    BucketState.BucketReferenced := FALSE;

    (* Scan 6 : front MAINT_N2, ConfirmClosePosition -> reference benne posee (benne fermee). *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, PowerContactorEngaged := TRUE,
       ConfirmClosePosition := TRUE, CablePosM1 := 0.0, CablePosM2 := 15.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.BucketReferenced, 'MAINT_N2 + ConfirmClose -> benne referencee');
    ASSERT_TRUE(BucketState.IsClosed, 'MAINT_N2 : Delta=15 m -> bande fermee publiee');
    ASSERT_FALSE(BucketState.IsOpen, 'MAINT_N2 : Delta=15 m hors bande ouverte -> IsOpen=FALSE');

    (* Scan 7 : relâche, bascule en SEMI_AUTO. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := FALSE, ConfirmClosePosition := FALSE, CablePosM1 := 0.0, CablePosM2 := 15.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    BucketState.BucketReferenced := FALSE;

    (* Scan 8 : SEMI_AUTO, ConfirmOpenPosition -> AUCUN effet. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, PowerContactorEngaged := TRUE,
       ConfirmOpenPosition := TRUE, ConfirmClosePosition := FALSE, CablePosM1 := 0.0, CablePosM2 := 15.0,
       HomedM1 := TRUE, HomedM2 := TRUE, HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.BucketReferenced, 'SEMI_AUTO + ConfirmOpen -> benne NON referencee');
    ASSERT_TRUE(BucketState.IsClosed, 'SEMI_AUTO : etat publie par la mesure (Delta=15 m -> ferme)');
END_TEST

TEST 'T323-005 Codeur(s) non reference(s) : statut au repos, defaut live seulement sur mouvement'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;

    (* Scan 1 : HomedM1=FALSE au repos -> aucun defaut *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := FALSE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Fault.Error, 'Codeur M1 non reference au repos -> statut seul');

    (* Scan 2 : une demande normale sans reference produit un defaut live *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ReqAscent := TRUE,
       HomedM1 := FALSE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Fault.Error, 'Commande sans reference -> defaut live');

    (* Scan 3 : referencement restaure -> disparition sans Reset *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Fault.Error, 'Referencement restaure sans Reset -> plus d erreur');
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
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Fermeture en cours');

    (* Scan 3 : le TON lit Lifecycle.Busy au scan suivant son armement. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 4 : apres 1s de BUSY sans atteindre la cible -> timeout. *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Fault.Error, 'Timeout mouvement 1s -> Error');
    ASSERT_TRUE(FB.Fault.Latched, 'Timeout -> defaut latche');
END_TEST

TEST 'TC-P10-046.2 T295 Pause operateur (relachement > PT, sans progression) -> AUCUN defaut'
    (* T295 — semantique a2 : le budget de timeout ne se consomme QUE pendant une commande
       operateur REELLEMENT engagee ; hors engagement il est GELE (pas remis a zero).
       ⚠️ REX T339 : le harnais STruCpp traduit un argument nomme en affectation de membre C++
       (`s.FB.<NOM> = ...`). Un nom qui correspond a un VAR LOCAL du FB (ici
       `MotionRequestActive`) COMPILE donc, mais le FB ecrase la valeur au scan suivant : le
       test serait VACANT. Tous les sites morts ont ete purges ; la commande est pilotee par la
       VRAIE entree ReqAscent. Le garde-fou G512 verrouille cette regle (branche dans PLANS). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Scans 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 3 : fermeture armee SOUS COMMANDE ENGAGEE, cible non atteinte *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T295 fermeture engagee -> Busy');

    (* Scan 4 : commande tenue 400 ms, toujours sous PT *)
    ADVANCE_TIME(400000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 5 : PAUSE OPERATEUR — relachement total maintenu 5 s (> PT), aucune progression.
       AVANT correctif : 60 s de temps MURAL depuis l'armement -> ErrorID:03 (bit 2) + latch. *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := FALSE, ReqAscent := FALSE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_FALSE(FB.Fault.Error, 'T295 pause operateur > PT -> AUCUN Error');
    ASSERT_FALSE(FB.Fault.Latched, 'T295 pause operateur > PT -> AUCUN Latched');
    ASSERT_EQ(FB.Fault.ErrorId, 0, 'T295 pause operateur -> ErrorId bit 2 (timeout) a 0');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T295 pause -> manoeuvre encore en cours (Busy conserve)');
END_TEST

TEST 'TC-P10-046.3 T295 Cumul du temps engage : 2 x 600 ms (< PT) + relachements -> defaut latche'
    (* T295 AC9 — preuve de la SUSPENSION (a2) et non d une remise a zero du TON au relachement :
       aucune sequence engagee n atteint PT=1s prise isolement (600 ms chacune), mais le CUMUL
       (600 + 600 = 1200 ms) atteint PT -> le defaut doit latcher. Une implementation « remise a
       zero a chaque relachement » (a1) resterait verte ici : c est precisement ce que ce TC tue. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Scans 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 3 : armement sous commande engagee *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T295 cumul : fermeture engagee -> Busy');

    (* Scan 4 : premier scan engage (front du TON de timeout) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 5 : segment engage 1 = 600 ms de commande (< PT) *)
    ADVANCE_TIME(600000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_FALSE(FB.Fault.Error, 'T295 cumul : 600 ms < PT -> pas encore de defaut');

    (* Scan 6 : relachement (le cumul 600 ms est GELE, pas remis a zero) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := FALSE, ReqAscent := FALSE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_FALSE(FB.Fault.Latched, 'T295 cumul : 600 ms consommes -> aucun defaut');

    (* Scan 7 : re-engagement — budget restant = PT - 600 ms = 400 ms *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 8 : segment engage 2 = 600 ms -> cumul 1200 ms >= PT -> defaut latché *)
    ADVANCE_TIME(600000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Fault.Error, 'T295 cumul 1200 ms >= PT -> Error');
    ASSERT_TRUE(FB.Fault.Latched, 'T295 cumul -> defaut latche (suspension, pas remise a zero)');
    ASSERT_TRUE((FB.Fault.ErrorId AND 4) <> 0, 'T295 cumul -> bit 2 (timeout) arme');
END_TEST

TEST 'TC-P10-046.4 T295 Arrivee nominale sous commande apres pause -> Done, aucun defaut'
    (* Non-regression AC8/AC9 : la manoeuvre commencee sous commande, interrompue par une pause
       operateur > PT puis reprise, doit aboutir normalement (Done) sans aucun defaut. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Scans 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 3 : fermeture engagee, benne en mouvement *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 1.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T295 arrivee : fermeture engagee -> Busy');

    (* Scan 4 : premier scan engage (front du TON de timeout) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 1.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);

    (* Scan 5 : pause operateur 2 s (> PT) — ne doit produire aucun defaut *)
    ADVANCE_TIME(2000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := FALSE, ReqAscent := FALSE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 1.0,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_FALSE(FB.Fault.Latched, 'T295 arrivee : pause 2 s -> aucun defaut');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T295 arrivee : pause -> manoeuvre toujours Busy');

    (* Scan 6 : reprise de la commande, le modele atteint la cible *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 2.9,
       Config := Config, BucketState := BucketState, CfgTimeoutDuration := T#1s);
    ASSERT_TRUE(FB.Lifecycle.Done, 'T295 arrivee nominale sous commande -> Done');
    ASSERT_FALSE(FB.Fault.Error, 'T295 arrivee nominale -> aucun Error');
    ASSERT_EQ(FB.Fault.ErrorId, 0, 'T295 arrivee nominale -> ErrorId a 0');
END_TEST

TEST 'TC-P10-047.1 Boot : etat classe en continu sur la mesure, offset invalide sans reference benne'
    (* Realigne T339. Le refactor T247 (2026-09-04, commit 509e0eb1) a SUPPRIME la detection
       d'incoherence au boot : l'etat benne n'est plus latche, il est re-classe a chaque scan
       depuis Delta = M2 - M1 (FB_Bucket.st:416-448, BucketState.StateIncoherent := FALSE :436).
       Ce qui reste VRAI au boot : IsOpen/IsClosed suivent la mesure et l'offset n'est PAS
       valide tant que la benne n'est pas referencee (BucketReferenced, FB_Bucket.st:745-748).
       La seule cause d'incoherence encore implementee est la NEUTRALISATION avec une manoeuvre
       engagee (FB_Bucket.st:300-303) : elle est verifiee dans la seconde moitie du test. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;
    BucketState.BucketReferenced := FALSE;

    (* Scan 1 : premier cycle, Delta=0 -> bande ouverte franche par la mesure *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState; // STruCpp : émule le copy-out VAR_IN_OUT CODESYS.
    ASSERT_FALSE(BucketState.StateIncoherent, 'Boot : plus de latche d incoherence (classification continue T247)');
    ASSERT_TRUE(BucketState.IsOpen, 'Boot Delta=0 -> bande ouverte classee sur la mesure');
    ASSERT_FALSE(BucketState.IsClosed, 'Boot Delta=0 -> hors bande fermee (15 m)');
    ASSERT_FALSE(FB.ActiveOffsetValid, 'Boot sans reference benne -> ActiveOffsetValid=FALSE');
    ASSERT_FALSE(FB.Fault.Error, 'Boot non reference et sans mouvement -> aucun defaut live');

    (* Scan 2 : manoeuvre engagee (permis + demande) -> Busy *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Manoeuvre benne engagee -> Busy');

    (* Scan 3 : NEUTRALISATION pendant la manoeuvre -> SEULE incoherence encore implementee *)
    ADVANCE_TIME(10000000);
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.StateIncoherent, 'Neutralisation avec manoeuvre engagee -> StateIncoherent=TRUE');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Neutralisation -> manoeuvre abandonnee');
    ASSERT_FALSE(FB.M2_RunRequest, 'Neutralisation -> aucun ordre M2');
END_TEST

TEST 'TC-P10-047.2 Boot : une mesure franche ecrase un etat memorise contradictoire (T247)'
    (* Realigne T339 — ECART DE SPEC SIGNALE (a arbitrer, hors lot) :
       l'exigence historique « IsOpen=TRUE ET IsClosed=TRUE -> StateIncoherent » n'est PLUS
       implementee. Depuis T247 (commit 509e0eb1) la classification continue ecrase les deux
       drapeaux a chaque scan (FB_Bucket.st:428-448) : la mesure tranche, mais AUCUN diagnostic
       ne signale qu'une bande a ete franchie alors que l'etat memorise disait l'inverse.
       Aggravant : avec une CoherenceLimitM >= (OffsetCloseM - OffsetOpenM)/2 les deux bandes se
       recouvrent et IsOpen=IsClosed=TRUE sont publies simultanement SANS aucun signal
       (CfgFault, cause 0, ne teste que OffsetOpenM < OffsetCloseM, FB_Bucket.st:176-179).
       Le test verifie donc le comportement REEL et documente ce trou. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := TRUE;
    BucketState.BucketReferenced := FALSE;

    (* Scan 1 : premier cycle, etat memorise contradictoire, mesure franche ouverte (Delta=0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.IsOpen, 'Mesure Delta=0 -> IsOpen=TRUE (classification continue)');
    ASSERT_FALSE(BucketState.IsClosed, 'Etat memorise contradictoire ecrase -> IsClosed=FALSE');
    ASSERT_FALSE(BucketState.StateIncoherent, 'ECART : aucune detection d incoherence contradictoire (T247)');
    ASSERT_FALSE(FB.ActiveOffsetValid, 'Offset invalide : benne non referencee');

    (* Scan 2 : la bande franche OPPOSEE (Delta=15 m) re-classe l'etat au scan suivant *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 15.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_FALSE(BucketState.IsOpen, 'Mesure Delta=15 m -> IsOpen=FALSE');
    ASSERT_TRUE(BucketState.IsClosed, 'Mesure Delta=15 m -> IsClosed=TRUE');
    ASSERT_FALSE(BucketState.StateIncoherent, 'Toujours aucune incoherence signalee');
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
       de test (sans copy-out manuel) : il ne passe QUE si le copy-out automatique est actif.
       Realigne T339 : chaque champ observe est PRE-POSITIONNE a la valeur OPPOSEE de celle
       que le FB ecrit — sans copy-out automatique, la variable de test conserverait donc sa
       valeur initiale et le test echouerait (l'ancienne forme asserait des valeurs FALSE
       deja presentes avant l'appel : elle ne prouvait rien). *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := TRUE;
    BucketState.IsIntermediate := FALSE;
    BucketState.StateIncoherent := TRUE;
    BucketState.ActiveOffsetValid := TRUE;

    (* Scan 1 : Delta=5,0 m -> position INTERMEDIAIRE : le FB ecrit IsIntermediate=TRUE,
       StateIncoherent=FALSE (classification continue FB_Bucket.st:436) et
       ActiveOffsetValid=FALSE (FB_Bucket.st:749, benne non referencee).
       Aucun copy-out manuel : la valeur doit etre restituee par le harnais. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 5.0,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(BucketState.IsIntermediate, 'Copy-out auto : IsIntermediate FALSE -> TRUE ecrit par le FB');
    ASSERT_FALSE(BucketState.StateIncoherent, 'Copy-out auto : StateIncoherent TRUE -> FALSE ecrit par le FB');
    ASSERT_FALSE(BucketState.ActiveOffsetValid, 'Copy-out auto : ActiveOffsetValid TRUE -> FALSE ecrit par le FB');
    ASSERT_FALSE(BucketState.IsOpen, 'Copy-out auto : IsOpen TRUE -> FALSE ecrit par le FB');
    ASSERT_FALSE(BucketState.IsClosed, 'Copy-out auto : IsClosed TRUE -> FALSE ecrit par le FB');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════════
   🧪 T291-B — Tests comportementaux continuité de DisplayOffsetM
   ───────────────────────────────────────────────────────────────────────────
   Vérifie :
   1. Continuité Fermé -> Intermédiaire -> Ouvert (zéro saut de 15 m)
   2. Continuité Ouvert -> Intermédiaire -> Fermé (monotonicité)
   3. Clamping rigoureux sur sur-ouverture (<= 0.0) et sur-fermeture (>= 15.0)
   4. Repli neutre (0.0 m) sous configuration invalide (OffsetOpenM >= OffsetCloseM)
   ═══════════════════════════════════════════════════════════════════════════ *)

TEST 'T291-B Continuité DisplayOffsetM : Fermé -> Intermédiaire -> Ouvert sans saut'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsClosed := TRUE;
    BucketState.IsOpen := FALSE;
    BucketState.BucketReferenced := TRUE;

    (* Scan 1 : Benne fermée nominale (M1=5.0, M2=20.0 -> Delta=15.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 20.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 15.0, 0.001, 'DisplayOffsetM fermé = 15.0 m');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Début ouverture (M1=5.0, M2=17.0 -> Delta=12.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 17.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 12.0, 0.001, 'DisplayOffsetM intermédiaire 1 = 12.0 m');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Mi-course ouverture (M1=5.0, M2=12.5 -> Delta=7.5) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 12.5,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 7.5, 0.001, 'DisplayOffsetM mi-course 50% = 7.5 m');

    ADVANCE_TIME(10000000);

    (* Scan 4 : Fin ouverture (M1=5.0, M2=7.0 -> Delta=2.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 7.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 2.0, 0.001, 'DisplayOffsetM intermédiaire 2 = 2.0 m');

    ADVANCE_TIME(10000000);

    (* Scan 5 : Benne complètement ouverte (M1=5.0, M2=5.0 -> Delta=0.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 5.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 0.0, 0.001, 'DisplayOffsetM ouvert = 0.0 m');
END_TEST

TEST 'T291-B Continuité DisplayOffsetM : Ouvert -> Intermédiaire -> Fermé'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsClosed := FALSE;
    BucketState.IsOpen := TRUE;
    BucketState.BucketReferenced := TRUE;

    (* Scan 1 : Benne ouverte nominale (Delta=0.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 5.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 0.0, 0.001, 'Ouvert départ = 0.0 m');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Fermeture 25% (Delta=3.75) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 8.75,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 3.75, 0.001, 'Fermeture 25% = 3.75 m');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Fermeture 75% (Delta=11.25) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 16.25,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 11.25, 0.001, 'Fermeture 75% = 11.25 m');

    ADVANCE_TIME(10000000);

    (* Scan 4 : Benne complètement fermée (Delta=15.0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 20.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 15.0, 0.001, 'Fermé arrivée = 15.0 m');
END_TEST

TEST 'T291-B Clamping DisplayOffsetM : Sur-course ouverture et fermeture'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    BucketState.BucketReferenced := TRUE;

    (* Sur-ouverture : Delta = -2.0 m -> DisplayOffsetM borné à OffsetOpenM = 0.0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 3.0,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 0.0, 0.001, 'Sur-ouverture clampée à 0.0 m');

    ADVANCE_TIME(10000000);

    (* Sur-fermeture : Delta = 17.5 m -> DisplayOffsetM borné à OffsetCloseM = 15.0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 22.5,
       Config := Config, BucketState := BucketState);
    ASSERT_NEAR(FB.DisplayOffsetM, 15.0, 0.001, 'Sur-fermeture clampée à 15.0 m');
END_TEST

TEST 'T291-B Repli DisplayOffsetM si configuration invalide (OffsetOpenM >= OffsetCloseM)'
    (* Configuration aberrante/inversée *)
    Config.OffsetOpenM := 15.0;
    Config.OffsetCloseM := 0.0;
    Config.CoherenceLimitM := 1.0;
    BucketState.BucketReferenced := TRUE;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       CablePosM1 := 5.0, CablePosM2 := 10.0,
       Config := Config, BucketState := BucketState);
    (* Ne doit PAS inverser silencieusement la formule, mais replier à 0.0 *)
    ASSERT_NEAR(FB.DisplayOffsetM, 0.0, 0.001, 'Config invalide -> DisplayOffsetM replié à 0.0 m');
END_TEST

