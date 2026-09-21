(* =======================================================================
   🧪 test_fb_troubleshootingview.st — FB_TroubleshootingView (TC-P14-TSV-01..05)
   ───────────────────────────────────────────────────────────────
   Lot : écriture de tests CI — domaine AF-14 (troubleshooting).
   Fiche : DOC/AF/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.2.md §8.
   Conventions : 1 appel FB() = 1 scan. Le FB est lecture-pure : il recopie des faits
   déjà publiés vers GVL_Troubleshooting (aucune commande). Les scénarios assertent
   sur les valeurs d'init sûres de GVL_Troubleshooting.* et sur l'interface (Ready).
   Les TC de pure architecture (G200, gates) portent une assertion d'invariant
   structurel documenté + commentaire « (essai d'architecture — validation partielle
   boîte noire) ».
   ======================================================================= *)

SETUP
VAR
    FB : FB_TroubleshootingView;
END_VAR
END_SETUP

TEST 'TC-P14-TSV-01 Interface : seule sortie Ready, aucune commande (essai d architecture - validation partielle boite noire)'
    (* Enable=FALSE -> Ready=FALSE (neutralisation) *)
    FB(Enable := FALSE);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');

    (* Enable=TRUE -> Ready=TRUE *)
    FB(Enable := TRUE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE');

    (* (essai d architecture - validation partielle boite noire) : l interface VAR_OUTPUT de
       FB_TroubleshootingView = Ready uniquement (fiche §3) -- aucune sortie SafeStop/Enable/
       Cmd/Bypass/Config. Toute publication passe par GVL_Troubleshooting (lecture seule). *)
END_TEST

TEST 'TC-P14-TSV-02 Chaque champ GVL_Troubleshooting a un producteur documente : init sure (essai d architecture - validation partielle boite noire)'
    (* Appel nominal : tous les inputs par defaut (FALSE/0) -> le FB recopie les faits
       publies vers GVL_Troubleshooting. On verifie l initialisation sure des champs. *)
    FB(Enable := TRUE);
    ASSERT_EQ(GVL_Troubleshooting.A_ContexteMachineGlobal.Idx101_ModeActive, E_Mode.DISABLE,
              'Idx101_ModeActive = Auth.Mode (init DISABLE)');
    ASSERT_FALSE(GVL_Troubleshooting.A_ContexteMachineGlobal.Idx102_SimulationEnabled,
                 'Idx102_SimulationEnabled = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.A_ContexteMachineGlobal.Idx202_BypassNetworkGlobal,
                 'Idx202_BypassNetworkGlobal = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.A_ContexteMachineGlobal.Idx401_HmiHeartbeatOk,
                 'Idx401_HmiHeartbeatOk = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.H_LevageSynchroniseM1M2.Idx302_SyncFaultActive,
                 'Idx302_SyncFaultActive = FALSE (init)');
END_TEST

TEST 'TC-P14-TSV-03 Champs TBD publies a leur valeur d init (aucune mesure inventee)'
    (* Fiche §6/§7 : un champ sans producteur reel reste a sa valeur d initialisation,
       jamais recalculé. On verifie les 4 champs TBD documentes. *)
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.A_ContexteMachineGlobal.Idx203_BypassSensorsGlobal,
                 'Idx203_BypassSensorsGlobal = FALSE (TBD non cable)');
    ASSERT_FALSE(GVL_Troubleshooting.I_LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI,
                 'Idx307_SlackCablePhysical_DI = FALSE (TBD)');
    ASSERT_FALSE(GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx501_M2_CmdRev_DQ,
                 'Idx501_M2_CmdRev_DQ = FALSE (TBD)');
    ASSERT_EQ(GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz, 0,
             'Idx502_CmdDriveFreq_Hz = 0 (TBD)');
END_TEST

TEST 'TC-P14-TSV-04 Instance unique appelee dans PRG_07_Supervision (G200) (essai d architecture - validation partielle boite noire)'
    (* (essai d architecture - validation partielle boite noire) : la liaison G200 (instance
       unique, appelee dans PRG_07_Supervision seul) est verifiee par G200_check_linkage.py,
       pas par le harnais. Ce scenario verifie que le FB est fonctionnel en boite noire. *)
    FB(Enable := TRUE);
    ASSERT_TRUE(FB.Ready, 'FB_TroubleshootingView pret (lecture seule)');
END_TEST

TEST 'TC-P14-TSV-05 Aucune regression gates (essai d architecture - validation partielle boite noire)'
    (* (essai d architecture - validation partielle boite noire) : la non-regression des gates
       est verifiee par run_all_gates.py, pas par le harnais. Scenario logique minimal. *)
    FB(Enable := TRUE);
    ASSERT_TRUE(FB.Ready, 'FB_TroubleshootingView pret');
END_TEST

(* =======================================================================
   🛡️ T371 — FAUX VERT DU DIAGNOSTIC MOUVEMENT (Step8_OutputInterlockOk)
   ───────────────────────────────────────────────────────────────
   ⚠️ COMMENT CE FB EST ALIMENTE EN TEST : FB_TroubleshootingView est LECTURE-PURE. Il recopie des
   faits DEJA PUBLIES par d'autres (GVL_IHM / GVL_Troubleshooting) : les scenarios ci-dessous pilotent
   donc ses ENTREES (`FB.WinchM1`, `FB.WinchM2`, `FB.Translation`) avec les valeurs REELLES que la
   barriere finale produit — elles ne sont pas inventees, elles sont citees ligne a ligne ci-dessous.
   La barriere (FB_WinchOutputInterlock) n'est PAS dans la chaine de compilation de ce harnais : elle
   ne peut donc pas etre pilotee ici, et ces cas ne la pilotent pas.

   📌 LES 4 MODES DE REFUS A FAUX VERT (preuve statique, FB_WinchOutputInterlock.st) :
     F1 :357-363  RestartInhibit                       -> State FAULT,              Reason RESTART_INHIBITED
     F2 :364-373  ContactorStuckLatched                -> State FAULT,              Reason SENSE_DROP_TIMEOUT
     F3 :393-404  SafeStop OU PermitFinalBlocked       -> State READY (!),          Reason NONE (!)
     F4 :424-429  RestartRequired OU DeadTimePending   -> State WAIT_RESTART_DELAY, Reason NONE (!)
   Dans les 4 cas Fault.Error = FALSE (cause unique = ErrorId bit0, timeout frein, :516-519 -> :528-532) :
   l'ancien `Step8 := NOT FinalInterlockError` (:577/:609/:644) rendait donc TRUE = FAUX VERT.

   ⚠️ HONNETETE SUR CE QUI EST PROUVE ICI : seule la barriere est fautive sur `Step8`.
   `AllConditionsMet` etait DEJA FALSE dans les 4 modes, par `Step7_BrakeReleased` (= BrakeCmd AND
   BrakeCommandOpenConfirmed) : la barriere coupe BrakeCmd (= RelayFwd OR RelayRev) dans tous ces
   refus, donc Step7 tombe a FALSE et l'ET se propage. Ces cas n'assertent donc PAS AllConditionsMet
   (le faire serait vacue) : ils assertent le seul champ qui mentait, Step8.

   ⚠️ ETAT D'EXECUTION (2026-09-21, T371) : ces cas SONT EXECUTES (ROUGE mesure avant correctif, VERT apres).
   Les DEUX murs PREEXISTANTS a HEAD qui les rendaient non jouables ont ete leves par T371 :
     (1) 8 types manquants dans l'entree `FB_TroubleshootingView` de registry.yaml — CORRIGE (8 lignes) ;
     (2) STruCpp v0.6.2 ne supporte PAS le namespace GVL de CODESYS (`GVL_Troubleshooting.X`) :
         levee par 2 MOCKS miroirs (`TOOLS/TEST_AUTO_CI/MOCKS/MOCK_GVL_*.st`) qui declarent
         `GVL_Troubleshooting` / `GVL_IHM` comme VARIABLES globales de STRUCT miroirs.
   ⚠️ REALISME DES VALEURS PILOTEES (REX revue independante T371, verdict BLOCK du 2026-09-21) : dans un
   refus, la DEMANDE reste presente (FB_Winch demande toujours) et la barriere coupe SA SORTIE. Les cas
   ci-dessous pilotent donc `RelayFwd := TRUE` (demande, miroir de FB_Winch, projection :102-103) AVEC
   `BrakeCmd := FALSE` (SORTIE validee de la barriere, projection :108). Un cas qui mettrait
   `RelayFwd := FALSE` fabriquerait un etat IMPOSSIBLE en exploitation et validerait un temoin tautologique.
   ======================================================================= *)

TEST 'TC-P14-TSV-06 M1/F1 : barriere FAULT + RESTART_INHIBITED, Fault.Error=FALSE -> Step8 PAS vert'
    (* Valeurs publiees par la barriere au site F1 (:357-363), projetees par FB_WinchStateProjection.st:112-115 *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;                                    // bit0 non pose
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.FAULT;          // :363
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.RESTART_INHIBITED; // :362
    FB.WinchM1.State.FinalMotorRequest    := TRUE;                                      // :118 projection (vue barriere)
    FB.WinchM1.State.RelayFwd             := TRUE;                                      // DEMANDE (miroir FB_Winch, :102)
    FB.WinchM1.State.RelayRev             := FALSE;
    FB.WinchM1.State.BrakeCmd             := FALSE;                                     // SORTIE validee coupee (:108 -> :487)
    FB(Enable := TRUE);
    ASSERT_EQ(GVL_Troubleshooting.N_MotionM1.Step8_InterlockState, E_WinchFinalInterlockState.FAULT, 'Step8_InterlockState = FAULT');
    ASSERT_EQ(GVL_Troubleshooting.N_MotionM1.Step8_InterlockReason, E_WinchFinalInterlockReason.RESTART_INHIBITED, 'Step8_InterlockReason = RESTART_INHIBITED');
    ASSERT_FALSE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                 'F1 RestartInhibit : la barriere refuse -> Step8 doit etre FALSE (faux vert avant T371)');
END_TEST

TEST 'TC-P14-TSV-07 M1/F2 : barriere FAULT + SENSE_DROP_TIMEOUT, Fault.Error=FALSE -> Step8 PAS vert'
    (* Site F2 (:364-373) — latch T_max §3bis, sans aucun defaut frein *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.FAULT;              // :373
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.SENSE_DROP_TIMEOUT; // :372
    FB.WinchM1.State.FinalMotorRequest    := TRUE;
    FB.WinchM1.State.RelayFwd             := TRUE;    // demande toujours presente
    FB.WinchM1.State.RelayRev             := FALSE;
    FB.WinchM1.State.BrakeCmd             := FALSE;   // sortie validee coupee
    FB(Enable := TRUE);
    ASSERT_EQ(GVL_Troubleshooting.N_MotionM1.Step8_InterlockReason, E_WinchFinalInterlockReason.SENSE_DROP_TIMEOUT, 'Step8_InterlockReason = SENSE_DROP_TIMEOUT');
    ASSERT_FALSE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                 'F2 ContactorStuckLatched : la barriere refuse -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-08 M1/F3 : SafeStop/PermitFinalBlocked (State=READY, Reason=NONE) -> Step8 PAS vert'
    (* Site F3 (:393-404) — LE PLUS TROMPEUR : State laisse a READY et Reason a NONE alors que les
       6 ordres sont coupes (:402-403). Etat REEL en exploitation : la demande est TOUJOURS la
       (RelayFwd = TRUE, miroir de FB_Winch) et c'est la SORTIE VALIDEE qui est coupee (BrakeCmd = FALSE).
       Ce cas est celui qui a fait tomber la 1re version du correctif (temoin tautologique sur
       RelayFwd/RelayRev, cf. REX revue independante) : il ne doit JAMAIS etre adouci. *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.READY;   // :404 — piege
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;   // non ecrit
    FB.WinchM1.State.FinalMotorRequest    := TRUE;                              // demande vivante
    FB.WinchM1.State.RelayFwd             := TRUE;                              // DEMANDE presente
    FB.WinchM1.State.RelayRev             := FALSE;
    FB.WinchM1.State.BrakeCmd             := FALSE;                             // aucune sortie validee
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                 'F3 SafeStop/PermitFinalBlocked : sortie coupee -> Step8 doit etre FALSE malgre State=READY');
END_TEST

TEST 'TC-P14-TSV-09 M1/F4 : RestartRequired/DeadTimePending (WAIT_RESTART_DELAY) -> Step8 PAS vert'
    (* Site F4 (:424-429) — Reason reste NONE : un correctif lisant Reason SEUL raterait F3 et F4 *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.WAIT_RESTART_DELAY; // :429
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM1.State.FinalMotorRequest    := TRUE;
    FB.WinchM1.State.RelayFwd             := TRUE;    // demande presente
    FB.WinchM1.State.RelayRev             := FALSE;
    FB.WinchM1.State.BrakeCmd             := FALSE;   // sortie retenue par la tempo
    FB(Enable := TRUE);
    ASSERT_EQ(GVL_Troubleshooting.N_MotionM1.Step8_InterlockState, E_WinchFinalInterlockState.WAIT_RESTART_DELAY, 'Step8_InterlockState = WAIT_RESTART_DELAY');
    ASSERT_FALSE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                 'F4 tempos anti-court-cycle : demande retenue -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-10 M2/F3 : meme patron sur l axe M2 (State=READY, sortie coupee) -> Step8 PAS vert'
    (* Source M2 : FB_WinchStateProjection.st:179-182 + FB_WinchOutputInterlock.st:393-404.
       Meme realisme que M1 : demande presente, sortie validee coupee. *)
    FB.WinchM2.State.FinalInterlockError  := FALSE;
    FB.WinchM2.State.FinalInterlockState  := E_WinchFinalInterlockState.READY;
    FB.WinchM2.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM2.State.FinalMotorRequest    := TRUE;
    FB.WinchM2.State.RelayFwd             := TRUE;    // demande presente (miroir FB_Winch :175)
    FB.WinchM2.State.RelayRev             := FALSE;
    FB.WinchM2.State.BrakeCmd             := FALSE;   // sortie validee coupee (projection :175)
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.O_MotionM2.Step8_OutputInterlockOk,
                 'M2 F3 : sortie coupee -> Step8 doit etre FALSE malgre State=READY');
END_TEST

TEST 'TC-P14-TSV-11 M3 : etat et cause de la barriere M3 publies, defaut = PAS vert'
    (* M3 : la barriere publie Fault.Error (source unique) + Reason (memoire). Son ordre VALIDE existe
       bien ailleurs (PRG_06:458 -> PRG_07:576 `GVL_IHM.IoHw.Out.M3_CommandWord`) mais n'est PAS une
       entree de ce FB : l'atteindre exigerait d'ajouter `IoHw` en VAR_INPUT + un argument dans
       PRG_07_Supervision.st (hors perimetre T371). Limite declaree, remontee a l'orchestrateur. *)
    FB.Translation.State.FinalInterlockError  := TRUE;   // timeout confirmation frein M3
    FB.Translation.State.FinalInterlockState  := E_State.ERROR;
    FB.Translation.State.FinalInterlockReason := E_TranslationFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED;
    FB(Enable := TRUE);
    ASSERT_EQ(GVL_Troubleshooting.P_MotionM3.Step8_InterlockState, E_WinchFinalInterlockState.FAULT, 'Step8_InterlockState M3 = FAULT (projete depuis E_State.ERROR)');
    ASSERT_EQ(GVL_Troubleshooting.P_MotionM3.Step8_InterlockReason, E_WinchFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED, 'Step8_InterlockReason M3 = BRAKE_COMMAND_NOT_CONFIRMED');
    ASSERT_FALSE(GVL_Troubleshooting.P_MotionM3.Step8_OutputInterlockOk,
                 'M3 en defaut -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-12 NON-REGRESSION : barriere nominale au repos -> Step8 reste VERT (pas de faux rouge)'
    (* Garde-fou anti-sur-correction : au repos (State READY, aucune demande, aucun defaut) la
       conclusion doit rester VERTE. Verifie aussi les 2 etats NON bloquants ou l'etage de sortie est
       bien engage : WAIT_BRAKE_COMMAND_CONFIRMATION (ordre emis) et WAIT_SENSE_DROP_CONFIRM (§3bis). *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.READY;
    FB.WinchM1.State.FinalMotorRequest    := FALSE;   // aucune demande
    FB.WinchM1.State.RelayFwd             := FALSE;
    FB.WinchM1.State.RelayRev             := FALSE;
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk, 'Repos nominal -> Step8 = TRUE');

    FB.WinchM1.State.FinalInterlockState := E_WinchFinalInterlockState.WAIT_BRAKE_COMMAND_CONFIRMATION;
    FB.WinchM1.State.FinalMotorRequest   := TRUE;
    FB.WinchM1.State.RelayFwd            := TRUE;     // ordre de sens emis : etage de sortie engage
    FB.WinchM1.State.BrakeCmd            := TRUE;     // SORTIE validee presente -> pas un refus
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                'Attente confirmation frein (ordre emis) -> PAS un refus, Step8 = TRUE');

    FB.WinchM1.State.FinalInterlockState := E_WinchFinalInterlockState.WAIT_SENSE_DROP_CONFIRM;
    FB.WinchM1.State.FinalMotorRequest   := FALSE;    // §3bis : palier retombe, sens tenu
    FB.WinchM1.State.RelayFwd            := TRUE;
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                'Maintien §3bis du sens -> PAS un refus, Step8 = TRUE');
END_TEST

TEST 'TC-P14-TSV-13 M2/F1 : barriere FAULT + RESTART_INHIBITED (demande vivante) -> Step8 PAS vert'
    (* Complement de couverture exige par la revue independante : F1 n'etait teste que sur M1. *)
    FB.WinchM2.State.FinalInterlockError  := FALSE;
    FB.WinchM2.State.FinalInterlockState  := E_WinchFinalInterlockState.FAULT;              // :363
    FB.WinchM2.State.FinalInterlockReason := E_WinchFinalInterlockReason.RESTART_INHIBITED; // :362
    FB.WinchM2.State.FinalMotorRequest    := TRUE;
    FB.WinchM2.State.RelayFwd             := TRUE;    // demande presente
    FB.WinchM2.State.RelayRev             := FALSE;
    FB.WinchM2.State.BrakeCmd             := FALSE;   // sortie validee coupee
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.O_MotionM2.Step8_OutputInterlockOk,
                 'M2 F1 RestartInhibit : la barriere refuse -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-14 M2/F4 : tempos (WAIT_RESTART_DELAY), demande retenue -> Step8 PAS vert'
    (* Complement de couverture exige par la revue independante : F4 n'etait teste que sur M1. *)
    FB.WinchM2.State.FinalInterlockError  := FALSE;
    FB.WinchM2.State.FinalInterlockState  := E_WinchFinalInterlockState.WAIT_RESTART_DELAY; // :429
    FB.WinchM2.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM2.State.FinalMotorRequest    := TRUE;
    FB.WinchM2.State.RelayFwd             := TRUE;
    FB.WinchM2.State.RelayRev             := FALSE;
    FB.WinchM2.State.BrakeCmd             := FALSE;
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.O_MotionM2.Step8_OutputInterlockOk,
                 'M2 F4 tempos : demande retenue -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-15 Gate Enable/AU perdue (DISABLED) -> Step8 PAS vert'
    (* Le terme DISABLED est le SEUL qui bascule Step8 dans une situation SEMI-NOMINALE (tout est
       pret, seule la gate Enable/PowerContactorEngaged manque). Son oubli etait indetectable dans
       la v1 du garde-fou (REX revue independante T371). *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.DISABLED;  // :169
    FB.WinchM1.State.FinalMotorRequest    := FALSE;
    FB.WinchM1.State.BrakeCmd             := FALSE;
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                 'Gate Enable/AU perdue : etage de sortie neutralise -> Step8 doit etre FALSE');
END_TEST

TEST 'TC-P14-TSV-16 Cause MEMORISEE apres acquittement -> Step8 reste VERT (pas de faux rouge permanent)'
    (* Garde-fou de la decision A2 : `Reason` est MEMORISE et n'est pas remis a NONE quand le latch
       §3bis est acquitte (FB_WinchOutputInterlock.st:510-514). Le diagnostic doit rester VERT :
       l'injecter dans la decision produirait un faux ROUGE PERMANENT. Verifie que G522 l'interdit. *)
    FB.WinchM1.State.FinalInterlockError  := FALSE;
    FB.WinchM1.State.FinalInterlockState  := E_WinchFinalInterlockState.READY;                // latch acquitte
    FB.WinchM1.State.FinalInterlockReason := E_WinchFinalInterlockReason.SENSE_DROP_TIMEOUT;  // memoire qui reste
    FB.WinchM1.State.FinalMotorRequest    := TRUE;
    FB.WinchM1.State.RelayFwd             := TRUE;
    FB.WinchM1.State.RelayRev             := FALSE;
    FB.WinchM1.State.BrakeCmd             := TRUE;    // mouvement autorise de nouveau
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk,
                'Cause memorisee mais barriere de nouveau autorisante -> Step8 = TRUE');
    ASSERT_EQ(GVL_Troubleshooting.N_MotionM1.Step8_InterlockReason, E_WinchFinalInterlockReason.SENSE_DROP_TIMEOUT,
              'la cause memorisee reste LISIBLE (champ de lecture) sans etre DECISIONNELLE');
END_TEST

TEST 'TC-P14-TSV-17 Vert nominal M2 et M3 -> Step8 VERT (pas de faux rouge sur les autres axes)'
    (* Couverture manquante relevee par la revue : aucun cas vert n'existait pour M2 et M3. *)
    FB.WinchM2.State.FinalInterlockError  := FALSE;
    FB.WinchM2.State.FinalInterlockReason := E_WinchFinalInterlockReason.NONE;
    FB.WinchM2.State.FinalInterlockState  := E_WinchFinalInterlockState.READY;
    FB.WinchM2.State.FinalMotorRequest    := TRUE;
    FB.WinchM2.State.RelayFwd             := TRUE;
    FB.WinchM2.State.RelayRev             := FALSE;
    FB.WinchM2.State.BrakeCmd             := TRUE;
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.O_MotionM2.Step8_OutputInterlockOk,
                'M2 nominal en mouvement -> Step8 = TRUE');

    FB.Translation.State.FinalInterlockError  := FALSE;
    FB.Translation.State.FinalInterlockState  := E_State.READY;
    FB.Translation.State.FinalInterlockReason := E_TranslationFinalInterlockReason.NONE;
    FB(Enable := TRUE);
    ASSERT_TRUE(GVL_Troubleshooting.P_MotionM3.Step8_OutputInterlockOk,
                'M3 nominal (pas de defaut) -> Step8 = TRUE');
    ASSERT_EQ(GVL_Troubleshooting.P_MotionM3.Step8_InterlockState, E_WinchFinalInterlockState.READY,
              'M3 : E_State.READY projete sur le vocabulaire commun (READY)');
END_TEST
