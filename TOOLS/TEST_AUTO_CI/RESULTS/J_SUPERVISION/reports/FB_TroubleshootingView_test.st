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
    ASSERT_EQ(GVL_Troubleshooting.ContexteMachineGlobal.Idx101_ModeActive, E_Mode.DISABLE,
              'Idx101_ModeActive = Auth.Mode (init DISABLE)');
    ASSERT_FALSE(GVL_Troubleshooting.ContexteMachineGlobal.Idx102_SimulationEnabled,
                 'Idx102_SimulationEnabled = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.ContexteMachineGlobal.Idx202_BypassNetworkGlobal,
                 'Idx202_BypassNetworkGlobal = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.ContexteMachineGlobal.Idx401_HmiHeartbeatOk,
                 'Idx401_HmiHeartbeatOk = FALSE (init)');
    ASSERT_FALSE(GVL_Troubleshooting.LevageSynchroniseM1M2.Idx302_SyncFaultActive,
                 'Idx302_SyncFaultActive = FALSE (init)');
END_TEST

TEST 'TC-P14-TSV-03 Champs TBD publies a leur valeur d init (aucune mesure inventee)'
    (* Fiche §6/§7 : un champ sans producteur reel reste a sa valeur d initialisation,
       jamais recalculé. On verifie les 4 champs TBD documentes. *)
    FB(Enable := TRUE);
    ASSERT_FALSE(GVL_Troubleshooting.ContexteMachineGlobal.Idx203_BypassSensorsGlobal,
                 'Idx203_BypassSensorsGlobal = FALSE (TBD non cable)');
    ASSERT_FALSE(GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI,
                 'Idx307_SlackCablePhysical_DI = FALSE (TBD)');
    ASSERT_FALSE(GVL_Troubleshooting.BenneOuvertureFermeture.Idx501_M2_CmdRev_DQ,
                 'Idx501_M2_CmdRev_DQ = FALSE (TBD)');
    ASSERT_EQ(GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz, 0,
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
