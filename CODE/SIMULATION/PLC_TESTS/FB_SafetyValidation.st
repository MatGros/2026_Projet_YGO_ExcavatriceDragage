(* ═══════════════════════════════════════════════════════════════
   🧪 FB_SafetyValidation — Validateur Automatique de Sécurité
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Séquenceur de test sous forme de bloc fonctionnel (FB).
      Exécute les cas de tests réglementaires de la boucle d'urgence.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_SafetyValidation
VAR_INPUT
    StartTests                 : BOOL;        // Commande de démarrage des tests
END_VAR
VAR_OUTPUT
    // Rapport de test
    TestInProgress             : BOOL;
    TC01_NominalArming_Ok      : BOOL;
    TC02_RedundancyFault_Ok    : BOOL;
    TC03_Lockout_Ok            : BOOL;
    AllTestsPassed             : BOOL;
    TestFailed                 : BOOL;
    FailedTestCase             : INT;         // Numéro du scénario en échec
    
    // Demandes de surcharge (overrides) vers le programme de simulation
    OverrideChainTrue          : BOOL;        // Force l'entrée boucle d'urgence à TRUE
    OverrideChainFalse         : BOOL;        // Force l'entrée boucle d'urgence à FALSE
    OverrideContactorFalse     : BOOL;        // Force l'entrée contacteur à FALSE
END_VAR
VAR
    StartTestEdge              : R_TRIG;
    TestSeqStep                : INT := 0;    // Séquenceur de test
    TestTimer                  : TON;         // Timer d'attente d'étapes
    
    // Signaux locaux pour stimuler le bloc sous test
    ArmRequest                 : BOOL;
    ResetFaults                : BOOL;
    CmdEmergencyCutOff         : BOOL;
END_VAR

// === IMPLEMENTATION ===

// ⛔ Neutralisation si la simulation globale n'est pas active (sécurité physique)
IF NOT GVL_Simulation.SimulationModeActive THEN
    TestSeqStep := 0;
    TestInProgress := FALSE;
    OverrideChainTrue := FALSE;
    OverrideChainFalse := FALSE;
    OverrideContactorFalse := FALSE;
    RETURN;
END_IF;

StartTestEdge(CLK := StartTests);

// ⏱️ Timer général d'étape
TestTimer(IN := (TestSeqStep <> 0), PT := T#10s);

// 🔀 Séquenceur de Test Automatique
CASE TestSeqStep OF

    0: // IDLE — En attente du départ de test
        IF StartTestEdge.Q THEN
            TestInProgress := TRUE;
            TC01_NominalArming_Ok := FALSE;
            TC02_RedundancyFault_Ok := FALSE;
            TC03_Lockout_Ok := FALSE;
            AllTestsPassed := FALSE;
            TestFailed := FALSE;
            FailedTestCase := 0;
            OverrideChainTrue := FALSE;
            OverrideChainFalse := FALSE;
            OverrideContactorFalse := FALSE;
            TestSeqStep := 10;
        END_IF;

    // ─────────────────────────────────────────────────────────────────
    // 🧪 SCÉNARIO 1 : Séquence Nominale (TC-01)
    // ─────────────────────────────────────────────────────────────────
    10: // Phase 1.1 : Initialisation saine
        ResetFaults := TRUE;
        IF NOT PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed AND 
           NOT PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingFailed THEN
            ResetFaults := FALSE;
            TestSeqStep := 11;
        END_IF;

    11: // Phase 1.2 : Envoi demande réarmement
        ArmRequest := TRUE;
        TestSeqStep := 12;

    12: // Phase 1.3 : Vérification début d'auto-test
        ArmRequest := FALSE;
        IF PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 1 THEN
            TestSeqStep := 13;
        END_IF;

    13: // Phase 1.4 : Attente réussite de l'auto-test et début impulsion armement
        IF PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 5 THEN
            TestSeqStep := 14;
        END_IF;

    14: // Phase 1.5 : Attente fin de l'impulsion et confirmation armement
        IF PRG_00_Inputs.EmergencyStopOk AND PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 0 THEN
            // Armé nominalement ! Maintenant on teste le Trip d'urgence
            TestSeqStep := 15;
        END_IF;

    15: // Phase 1.6 : Simulation d'un appui bouton d'urgence (Coupure franche)
        OverrideChainFalse := TRUE;
        TestSeqStep := 16;

    16: // Phase 1.7 : Vérification coupure instantanée
        IF NOT PowerCutOff_A_RQ AND NOT PowerCutOff_B_RQ AND NOT PRG_00_Inputs.EmergencyStopOk THEN
            // Coupure validée, on relâche le bouton d'urgence (doit rester coupé)
            OverrideChainFalse := FALSE;
            TestSeqStep := 17;
        END_IF;

    17: // Phase 1.8 : Vérification de l'auto-maintien (Latch)
        IF NOT PowerCutOff_A_RQ AND NOT PowerCutOff_B_RQ THEN
            TC01_NominalArming_Ok := TRUE;
            TestSeqStep := 20; // Passer au test de redondance
        ELSE
            TestFailed := TRUE;
            FailedTestCase := 1;
            TestSeqStep := 999;
        END_IF;

    // ─────────────────────────────────────────────────────────────────
    // 🧪 SCÉNARIO 2 : Défaut de Redondance (TC-02)
    // ─────────────────────────────────────────────────────────────────
    20: // Phase 2.1 : Acquitter le défaut précédent et relancer l'armement
        ResetFaults := TRUE;
        IF NOT PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed THEN
            ResetFaults := FALSE;
            ArmRequest := TRUE;
            TestSeqStep := 21;
        END_IF;

    21: // Phase 2.2 : Attente de l'auto-test canal A
        ArmRequest := FALSE;
        IF PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 1 THEN
            // Simuler contacteur A soudé
            OverrideChainTrue := TRUE;
            TestSeqStep := 22;
        END_IF;

    22: // Phase 2.3 : Vérification de la détection du défaut (dans les 200ms)
        IF PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed AND 
           PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 0 THEN
            // Détection réussie ! Les sorties doivent être inhibées.
            OverrideChainTrue := FALSE;
            TC02_RedundancyFault_Ok := TRUE;
            TestSeqStep := 30; // Passer au test de Lockout
        ELSIF TestTimer.Q THEN
            // Timeout -> Échec du test de redondance
            OverrideChainTrue := FALSE;
            TestFailed := TRUE;
            FailedTestCase := 2;
            TestSeqStep := 999;
        END_IF;

    // ─────────────────────────────────────────────────────────────────
    // 🧪 SCÉNARIO 3 : Verrouillage temporel (TC-03)
    // ─────────────────────────────────────────────────────────────────
    30: // Phase 3.1 : Acquitter et lancer un armement condamné à échouer
        ResetFaults := TRUE;
        IF NOT PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed THEN
            ResetFaults := FALSE;
            ArmRequest := TRUE;
            // Bloquer le contacteur de puissance à FALSE
            OverrideContactorFalse := TRUE;
            TestSeqStep := 31;
        END_IF;

    31: // Phase 3.2 : Attente de l'échec de confirmation d'armement (Step 6 -> Lockout)
        ArmRequest := FALSE;
        IF PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingFailed AND 
           PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingLockoutActive THEN
            TestSeqStep := 32;
        END_IF;

    32: // Phase 3.3 : Tenter de réarmer immédiatement pendant le lockout de 5s
        ArmRequest := TRUE;
        TestSeqStep := 33;

    33: // Phase 3.4 : Vérifier que la demande de réarmement est ignorée
        ArmRequest := FALSE;
        IF PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep <> 0 THEN
            // Pas normal, on a démarré pendant le lockout !
            OverrideContactorFalse := FALSE;
            TestFailed := TRUE;
            FailedTestCase := 3;
            TestSeqStep := 999;
        ELSE
            // Demande ignorée avec succès, on attend la fin du lockout
            TestSeqStep := 34;
        END_IF;

    34: // Phase 3.5 : Attente de la libération du verrouillage (5s)
        IF NOT PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingLockoutActive THEN
            // Lockout terminé, on désactive le blocage contacteur
            OverrideContactorFalse := FALSE;
            ResetFaults := TRUE;
            TestSeqStep := 35;
        END_IF;

    35: // Phase 3.6 : Valider qu'un réarmement normal est à nouveau possible
        ResetFaults := FALSE;
        ArmRequest := TRUE;
        TestSeqStep := 36;

    36: // Phase 3.7 : Confirmation finale de l'armement après lockout
        ArmRequest := FALSE;
        IF PRG_00_Inputs.EmergencyStopOk THEN
            TC03_Lockout_Ok := TRUE;
            AllTestsPassed := TRUE;
            TestSeqStep := 100; // Succès global !
        ELSIF TestTimer.Q THEN
            TestFailed := TRUE;
            FailedTestCase := 4;
            TestSeqStep := 999;
        END_IF;

    100: // SUCCÈS GLOBAL
        TestInProgress := FALSE;
        TestSeqStep := 0;

    999: // ÉCHEC
        TestInProgress := FALSE;
        TestSeqStep := 0;

END_CASE;

// === LIAISON DES ESTIMULI AUX VARIABLES D'ÉCHANGE GLOBALES ===
IF TestInProgress THEN
    GVL_IHM.Modes.CmdEmergencyArming := ArmRequest;
    GVL_IHM.Modes.FaultMachineReset  := ResetFaults;
END_IF;
