SETUP
VAR
    FB : FB_Diag_Ethercat;
    (* Temoin de l'invariance T359 : meme sequence, SANS jamais activer ResetTransient.
       Toute difference entre FB et FBCtrl signerait un effet reel du pulse d'auto-acquittement. *)
    FBCtrl : FB_Diag_Ethercat;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.DISABLED, 'State=DISABLED');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic actif *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.READY, 'State=READY');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-010 EtherCAT : surveillance maitre et esclaves'
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'EtherCAT pret');
    ASSERT_FALSE(FB.DeviceEthercatMaster.Error, 'Pas d erreur bus');
    ASSERT_FALSE(FB.DeviceEncoderM1.Error, 'Pas d erreur encoder M1');
END_TEST

(* =========================================================================
   AF-12 — Diagnostic : TC-P12-030 (synthèse par device) & TC-P12-040 (bypass)
   ========================================================================= *)

TEST 'TC-P12-030 EtherCAT : State != RUNNING par device -> bits ErrorId + Error global'
    (* Variateur M3 hors RUNNING -> bit 4 (16#0010), M1/M2 sains *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceVariateur.Error, 'Variateur hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0010, 'Variateur -> ErrorId bit 4 (16#0010)');
    ASSERT_FALSE(FB.DeviceEncoderM1.Error, 'M1 sain -> pas d erreur');
    ASSERT_FALSE(FB.DeviceEncoderM2.Error, 'M2 sain -> pas d erreur');
    ASSERT_TRUE(FB.DeviceEthercatMaster.Error, 'Un device en defaut -> Error maitre=TRUE');

    (* M1 hors RUNNING -> bit 5 (16#0020), variateur/M2 sains *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.STOPPED, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceEncoderM1.Error, 'M1 hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceEncoderM1.ErrorId, 16#0020, 'M1 -> ErrorId bit 5 (16#0020)');
    ASSERT_FALSE(FB.DeviceVariateur.Error, 'Variateur sain -> pas d erreur');

    (* M2 hors RUNNING -> 16#0030 (bug T159 documente, pas 16#0040) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.STOPPED,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceEncoderM2.Error, 'M2 hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceEncoderM2.ErrorId, 16#0030, 'M2 -> ErrorId 16#0030 (bug T159 documente)');
END_TEST

TEST 'TC-P12-040 EtherCAT : bypass sim/reseau vs etat reel (READY/SIMULATED/DISABLED)'
    (* Reel RUNNING sans bypass -> READY *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.READY, 'Reel RUNNING sans bypass -> READY');

    (* Bypass sans device reel -> SIMULATED *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := TRUE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.SIMULATED, 'Bypass sans device reel -> SIMULATED');

    (* Ni l un ni l autre -> ERROR (fiche attend INIT, code produit ERROR -- ecart documente AF12 TBD) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.ERROR, 'Ni bypass ni reel -> ERROR (ecart fiche INIT)');

    (* Enable=FALSE prioritaire -> DISABLED *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.DISABLED, 'Enable=FALSE -> DISABLED');
END_TEST

(* =========================================================================
   T359 — PREUVE QUE L'AUTO-ACQUITTEMENT ResetTransient EST UN NO-OP
   =========================================================================
   OBJET DE LA PREUVE (aucun correctif ici, preuve AVANT correctif) : le service
   d'auto-acquittement borne (FB_AutoResetTransientDiag) produit bien une impulsion
   ResetTransient, mais cette impulsion n'a AUCUN effet observable sur les bits de
   diagnostic. Demonstration par trois faits :

   1. ORDRE DE SCAN (FB_Diag_Ethercat.st) : le bloc reset (lignes 103-119, dont
      ResetTransient en 106-112) s'execute AVANT le bloc « Diagnostic par equipement »
      (lignes 123-152) qui contient l'effacement automatique `AND 16#FFEF` (ligne 131),
      `16#FFDF` (141), `16#FFCF` (151). L'effet du pulse est donc ECRASE DANS LE MEME SCAN.

   2. L'effacement automatique est PREEXISTANT a T278 : le commit cb5ae5ea n'ajoute QUE
      la voie ResetTransient (git show cb5ae5ea -- CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st
      ne contient ni 131, ni 141, ni 151). La fonctionnalite etait inoperante a sa
      conception, independamment des flags d'activation corriges en T352.

   3. INVARIANCE : ErrorId de fin de scan = f(OnlineEff) SEUL.
      - OnlineEff = TRUE  -> l'effacement automatique passe, que le pulse ait agi ou non ;
      - OnlineEff = FALSE -> la garde du pulse (`IF VariateurOnlineEff`) est fausse, le bit
        est pose a nouveau juste apres par la ligne 129.
      => ResetTransient ne peut rien changer. C'est ce que mesurent ces 3 tests, en
      comparant FB (avec pulse) et FBCtrl (sans pulse) EGAL A EGAL.
   ========================================================================= *)

TEST 'TC-T359-001 Invariance : une perte de liaison puis retour, pulse actif vs temoin sans pulse'
    (* Scan 0 : tout est en ligne, aucune impulsion *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0000, 'Etat initial sain : ErrorId variateur nul');

    (* Scan 1 : PERTE DE LIAISON variateur -> le bit est pose *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0010, 'Perte liaison variateur -> bit 16#0010 pose');
    ASSERT_FALSE(FB.DeviceVariateur.Online, 'Variateur hors ligne pendant la perte');

    (* Scan 2 : RETOUR DE LIAISON, front ResetTransient sur FB seul (FBCtrl reste sans pulse) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := TRUE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);

    (* Aucun scan n'expose « en ligne ET bit pose » : l'effacement automatique a deja agi *)
    ASSERT_TRUE(FB.DeviceVariateur.Online, 'Variateur de nouveau en ligne');
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0000, 'Bit deja efface SANS le pulse (effacement auto ligne 131)');

    (* PREUVE D'INVARIANCE : le pulse ne change RIEN *)
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, FBCtrl.DeviceVariateur.ErrorId,
              'INVARIANCE : ErrorId identique avec et sans ResetTransient');
    ASSERT_EQ(FB.DeviceVariateur.Error, FBCtrl.DeviceVariateur.Error,
              'INVARIANCE : Error identique avec et sans ResetTransient');
    ASSERT_EQ(FB.DeviceEthercatMaster.ErrorId, FBCtrl.DeviceEthercatMaster.ErrorId,
              'INVARIANCE : aucun effet sur le diagnostic maitre non plus');
END_TEST

TEST 'TC-T359-002 Invariance au timing de production : pulse 1 s APRES le retour de liaison'
    (* Scan 0 : tout en ligne *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);

    (* Scan 1 : perte des DEUX codeurs *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.STOPPED, DeviceEncoderM2StateRaw := DEVICE_STATE.STOPPED,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.STOPPED, DeviceEncoderM2StateRaw := DEVICE_STATE.STOPPED,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_EQ(FB.DeviceEncoderM1.ErrorId, 16#0020, 'Perte liaison codeur M1 -> bit 16#0020');
    ASSERT_EQ(FB.DeviceEncoderM2.ErrorId, 16#0030, 'Perte liaison codeur M2 -> bit 16#0030');

    (* Scan 2 : retour de liaison, PAS encore de pulse (comme sur machine : la sequence attend
       Cfg_StabilizationTime = 1 s avant d'emetre son impulsion) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_EQ(FB.DeviceEncoderM1.ErrorId, 16#0000, 'Codeur M1 deja efface au retour de liaison');
    ASSERT_EQ(FB.DeviceEncoderM2.ErrorId, 16#0000, 'Codeur M2 deja efface au retour de liaison');

    (* Scan 3 : 1 s plus tard, l'impulsion d'auto-acquittement arrive enfin *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := TRUE);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_EQ(FB.DeviceEncoderM1.ErrorId, FBCtrl.DeviceEncoderM1.ErrorId,
              'INVARIANCE : pulse tardif sans effet sur codeur M1');
    ASSERT_EQ(FB.DeviceEncoderM2.ErrorId, FBCtrl.DeviceEncoderM2.ErrorId,
              'INVARIANCE : pulse tardif sans effet sur codeur M2');
    ASSERT_EQ(FB.DeviceEthercatMaster.ErrorId, FBCtrl.DeviceEthercatMaster.ErrorId,
              'INVARIANCE : pulse tardif sans effet sur le maitre');
END_TEST

TEST 'TC-T359-003 La voie alternative « front Online » ne peut pas davantage agir sur le bit'
    (* Cette sequence prouve que le bit de liaison n'est JAMAIS observable a TRUE alors que
       l'equipement est en ligne : il n'existe donc aucun instant ou un pulse, meme declenche
       au scan exact du front Online, aurait quelque chose a effacer. *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.STOPPED, DeviceEncoderM2StateRaw := DEVICE_STATE.STOPPED,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_FALSE(FB.DeviceVariateur.Online, 'Hors ligne : bit pose, aucun pulse possible (garde OnlineEff)');
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0010, 'Hors ligne : bit pose');

    (* Le scan EXACT du retour : Online passe a TRUE et le bit tombe dans le meme scan *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := FALSE);
    ASSERT_TRUE(FB.DeviceVariateur.Online, 'Scan du front Online : variateur en ligne');
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0000,
              'Scan du front Online : le bit est deja a 0 dans LE MEME scan — rien a effacer');

    (* Contre-epreuve du temoin : le pulse ACTIF sur ce meme scan ne peut pas faire mieux *)
    ADVANCE_TIME(10000000);
    FBCtrl(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE, EcatBusBypassActive := FALSE, ResetTransient := TRUE);
    ASSERT_EQ(FBCtrl.DeviceVariateur.ErrorId, 16#0000,
              'Contre-epreuve : pulse au scan du front Online -> toujours 0, aucune valeur ajoutee');
END_TEST
