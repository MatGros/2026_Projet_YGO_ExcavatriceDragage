(* =========================================================================
   FB_AutoResetTransientDiag — preuve isolee (T352, parent T278)
   =========================================================================
   Pourquoi ce fichier existe : T278 a livre le FB et son cablage SANS aucun
   test unitaire, et ses deux entrees d'autorisation StartupEnable /
   PowerRearmEnable ont ete cablees sur deux booleens d'une GVL de simulation
   valant FALSE par defaut et sans aucun ecrivain (PRG_02_Acquisition.st:225-226,
   GVL_Simulation.st:106-107). Consequence mesuree sur machine reelle : State
   reste bloque a 0, Phase ne passe jamais a 1 ni a 2, ResetPulse ne bouge
   jamais. Ces cas prouvent que la logique INTERNE du FB est saine des que les
   deux entrees valent TRUE — le defaut etait donc bien en amont du FB.

   Identifiants TC-T352-xxx : cas d'execution rattaches a la tache T352. Ils ne
   prennent AUCUN identifiant TC-P12 du catalogue AF-12 : ce catalogue s'arrete
   a TC-P12-050 et un TC-P12-060 a ete explicitement REFUSE par l'humain
   (AF_Partie-12_Fonction_Diagnostic_v1.4.md, ligne 348).

   Ce fichier prouve des comportements OBSERVABLES par les sorties publiques
   (ResetPulse, SequenceActive, Lockout, Cancelled, Phase, AttemptCount) :
   State et StartupStarted sont des VAR privees, non lisibles de l'exterieur.

   Gardes de securite couvertes, jamais affaiblies :
     FB_AutoResetTransientDiag.st:70  SafeCommon = EmergencyChainClosed AND
                                      NOT PowerCutOffActive AND NOT MotionActive
     FB_AutoResetTransientDiag.st:122 annulation immediate si SafeCommon tombe
   ========================================================================= *)

SETUP
VAR
    FB : FB_AutoResetTransientDiag;
END_VAR
END_SETUP

(* -------------------------------------------------------------------------
   Cas nominal : demarrage, stabilisation, impulsion unique, verrouillage.
   C'est exactement le scenario que l'observateur ne voyait jamais sur machine.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-001 Demarrage par defaut : Phase 1, impulsion apres stabilisation, verrouillage'
    (* Scan 0 : conditions nominales, contacteur au repos -> la sequence demarre *)
    FB(Enable := TRUE,
       StartupEnable := TRUE,
       PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE,
       PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE,
       MotionActive := FALSE,
       DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1,
       Cfg_StabilizationTime := T#1s,
       Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.SequenceActive, 'StartupEnable=TRUE -> sequence active des le 1er scan');
    ASSERT_EQ(FB.Phase, 1, 'Phase 1 = sequence de demarrage engagee');

    (* Scan 1 : aucune impulsion, la stabilisation est en cours *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Aucune impulsion avant Cfg_StabilizationTime');

    (* Scan 2 : 1 s ecoulee -> impulsion unique puis verrouillage (MaxAttempts=1) *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.ResetPulse, 'Apres 1 s de stabilisation -> ResetPulse=TRUE');
    ASSERT_EQ(FB.AttemptCount, 1, 'Une seule impulsion emise');
    ASSERT_TRUE(FB.Lockout, 'MaxAttempts=1 atteint -> Lockout=TRUE');
    ASSERT_EQ(FB.Phase, 3, 'Phase 3 = salve terminee, attente d''un nouvel evenement');

    (* Scan 3 : impulsion d'un seul scan, puis retour au repos verrouille *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'ResetPulse est impulsionnel : FALSE au scan suivant');
    ASSERT_TRUE(FB.Lockout, 'Lockout persiste apres la salve');
    ASSERT_FALSE(FB.SequenceActive, 'Sequence terminee');
END_TEST

(* -------------------------------------------------------------------------
   Le second chemin d'entree, inerte tant que PowerRearmEnable valait FALSE :
   phase 2 declenchee EXCLUSIVEMENT sur front du retour contacteur.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-002 Post-rearmement : Phase 2 sur front contacteur, impulsion puis verrouillage'
    (* Scan 0 : contacteur au repos, phase demarrage volontairement desactivee *)
    FB(Enable := TRUE,
       StartupEnable := FALSE,
       PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE,
       PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE,
       MotionActive := FALSE,
       DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1,
       Cfg_StabilizationTime := T#1s,
       Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.SequenceActive, 'Aucun evenement -> sequence au repos');

    (* Scan 1 : front montant du contacteur -> phase post-rearmement *)
    FB(Enable := TRUE, StartupEnable := FALSE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.SequenceActive, 'Front contacteur -> sequence post-rearmement engagee');
    ASSERT_EQ(FB.Phase, 2, 'Phase 2 = sequence post-rearmement');
    ASSERT_FALSE(FB.ResetPulse, 'Impulsion differee apres stabilisation');

    (* Scan 2 : stabilisation ecoulee -> impulsion puis verrouillage *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := FALSE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 1, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.ResetPulse, 'Apres stabilisation post-rearmement -> ResetPulse=TRUE');
    ASSERT_EQ(FB.AttemptCount, 1, 'Une impulsion emise');
    ASSERT_TRUE(FB.Lockout, 'Salve epuisee -> Lockout=TRUE');
END_TEST

(* -------------------------------------------------------------------------
   Gardes de securite : aucune impulsion ne doit sortir. Les trois composantes
   de SafeCommon sont testees separement, chacune suffit a interdire la salve.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-003 Gardes safety : chaine AU ouverte, coupure puissance, mouvement actif'
    (* Chaine AU ouverte : EmergencyChainClosed=FALSE *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.SequenceActive, 'Chaine AU ouverte -> aucune sequence');
    ASSERT_FALSE(FB.ResetPulse, 'Chaine AU ouverte -> aucune impulsion');

    (* Coupure puissance active : PowerCutOffActive=TRUE *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := TRUE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.SequenceActive, 'Coupure puissance active -> aucune sequence');

    (* Mouvement actif : MotionActive=TRUE *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := TRUE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.SequenceActive, 'Mouvement actif -> aucune sequence');

    (* Le temps qui passe ne force rien : meme apres 5 s, toujours aucune impulsion *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := TRUE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Garde safety invalide -> ResetPulse reste FALSE malgre le temps');
    ASSERT_EQ(FB.AttemptCount, 0, 'Aucune tentative consommee sous garde invalide');

    (* Diagnostics reseau instables : la stabilisation ne progresse pas *)
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := FALSE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_EQ(FB.Phase, 1, 'Sequence engagee mais bloquee en phase 1');
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := FALSE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Diagnostics instables -> aucune impulsion');
    ASSERT_EQ(FB.AttemptCount, 0, 'Aucune tentative consommee sans diagnostics stables');
END_TEST

(* -------------------------------------------------------------------------
   Annulation en cours de sequence : la garde retombe pendant la salve.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-004 Annulation : chute de la garde pendant la sequence -> Cancelled + Lockout'
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_EQ(FB.Phase, 1, 'Sequence engagee');

    (* L'AU s'ouvre pendant la salve -> annulation immediate *)
    ADVANCE_TIME(500000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.Cancelled, 'Garde tombee en cours de sequence -> Cancelled=TRUE');
    ASSERT_TRUE(FB.Lockout, 'Salve annulee -> Lockout=TRUE');
    ASSERT_FALSE(FB.ResetPulse, 'Annulation -> aucune impulsion');
    ASSERT_FALSE(FB.SequenceActive, 'Sequence interrompue');
    ASSERT_EQ(FB.Phase, 3, 'Phase 3 = verrouillage apres annulation');
END_TEST

(* -------------------------------------------------------------------------
   Borne haute : 3 impulsions espacees de Cfg_InterAttemptTime, puis lockout.
   Cadence reelle du FB : impulsion (etat 3) -> scan d'intervalle (retour etat 1)
   -> redemarrage de la stabilisation -> impulsion suivante.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-005 Borne haute : 3 impulsions espacees puis verrouillage definitif'
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_EQ(FB.Phase, 1, 'Sequence engagee');

    (* Impulsion 1 *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.ResetPulse, 'Impulsion 1 sur 3');
    ASSERT_EQ(FB.AttemptCount, 1, 'Compteur a 1');
    ASSERT_FALSE(FB.Lockout, 'Salve non epuisee -> aucun verrouillage');

    (* Intervalle : la tempo inter-impulsions ramene la sequence en phase 1 *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Intervalle inter-impulsions respecte');
    ASSERT_EQ(FB.AttemptCount, 1, 'Compteur inchange pendant l''intervalle');
    ASSERT_EQ(FB.Phase, 1, 'Retour en phase 1 pour la tentative suivante');

    (* Redemarrage de la stabilisation puis impulsion 2 *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Stabilisation redemarree : pas d''impulsion immediate');

    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.ResetPulse, 'Impulsion 2 sur 3');
    ASSERT_EQ(FB.AttemptCount, 2, 'Compteur a 2');
    ASSERT_FALSE(FB.Lockout, 'Salve non epuisee -> aucun verrouillage');

    (* Intervalle puis impulsion 3, qui sature la borne *)
    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Intervalle inter-impulsions respecte (2)');

    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Stabilisation redemarree : pas d''impulsion immediate (2)');

    ADVANCE_TIME(1000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.ResetPulse, 'Impulsion 3 sur 3');
    ASSERT_EQ(FB.AttemptCount, 3, 'Compteur a 3');
    ASSERT_TRUE(FB.Lockout, 'Borne haute atteinte -> verrouillage');
    ASSERT_EQ(FB.Phase, 3, 'Phase 3 apres salve complete');

    (* Le temps ne relance rien : seul un nouvel evenement rearme la salve *)
    ADVANCE_TIME(10000000000);
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.ResetPulse, 'Aucune 4e impulsion');
    ASSERT_EQ(FB.AttemptCount, 3, 'Compteur fige a la borne');
    ASSERT_TRUE(FB.Lockout, 'Verrouillage conserve');
END_TEST

(* -------------------------------------------------------------------------
   Neutralisation : Enable=FALSE remet le service au repos.
   ------------------------------------------------------------------------- *)
TEST 'TC-T352-006 Neutralisation : Enable=FALSE -> service remis au repos'
    FB(Enable := TRUE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_TRUE(FB.SequenceActive, 'Sequence engagee avant neutralisation');

    FB(Enable := FALSE, StartupEnable := TRUE, PowerRearmEnable := TRUE,
       EmergencyChainClosed := TRUE, PowerContactorEngaged := FALSE,
       PowerCutOffActive := FALSE, MotionActive := FALSE, DiagnosticsStable := TRUE,
       Cfg_MaxAttempts := 3, Cfg_StabilizationTime := T#1s, Cfg_InterAttemptTime := T#1s);
    ASSERT_FALSE(FB.SequenceActive, 'Enable=FALSE -> sequence neutralisee');
    ASSERT_FALSE(FB.Lockout, 'Enable=FALSE -> verrouillage efface');
    ASSERT_EQ(FB.Phase, 0, 'Enable=FALSE -> retour au repos');
    ASSERT_EQ(FB.AttemptCount, 0, 'Enable=FALSE -> compteur remis a zero');
    ASSERT_FALSE(FB.ResetPulse, 'Enable=FALSE -> aucune impulsion');
END_TEST
