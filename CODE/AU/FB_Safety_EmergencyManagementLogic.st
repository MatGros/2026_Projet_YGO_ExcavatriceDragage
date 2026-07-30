(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyManagementLogic — Décision & Séquencement
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Gère la machine d'état d'auto-test et de réarmement de
      la boucle d'arrêt d'urgence. Produit les consignes logiques
      et les bus d'état/diagnostic.
   🏷️ Renommé PowerCutOff_X_Cmd → MaintainA/B_Cmd (polarité maintien).
      Ajout autotest démarrage (§5.4 AF01) + bus State/Diag.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md
              DOC/AF_Partie-03_Contrats_Composants_v2.0.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementLogic
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)
    EmergencyChainClosed      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    PowerContactorEngaged     : BOOL;        // Confirmation contacteur de puissance principal
    PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers
    BtnEmergencyCutOff  : BOOL;        // Commande d'ouverture d'urgence depuis l'IHM
END_VAR
VAR_OUTPUT
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: RedundancyTestFailed, bit1: EmergencyArmingFailed
    Cmd                 : ST_EmergencyManagementCmd; // Structure de commande logique produite

    ArmingSeqStep       : INT;         // Étape de diagnostic : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    RedundancyTestFailed: BOOL;        // Canal A ou B resté collé/shunté détecté à l'auto-test
    EmergencyArmingFailed: BOOL;       // Contacteur de puissance n'a pas confirmé l'armement
    EmergencyArmingLockoutActive : BOOL; // Verrouillage temporel de 5s entre les essais

    // 🆕 Bus State/Diag internes — repris par le composite pour les DUT publics
    Armable             : BOOL;        // 🟢 Réarmement possible maintenant
    ArmingBusy          : BOOL;        // ⏳ Séquence ou lockout en cours
    StartupFail         : BOOL;        // 🔴 Autotest démarche échoué
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ArmReqEdge          : R_TRIG;
    EnableRising        : R_TRIG;
    ForceTestA          : BOOL;
    ForceTestB          : BOOL;
    TonTestA            : TON;
    TonRestoreA         : TON;
    TonTestB            : TON;
    TonRestoreB         : TON;
    TonArmingPulse      : TON;
    TonArmingConfirm    : TON;
    TonArmingLockout    : TON;

    // 🆕 Autotest démarrage
    StartupCheckDone    : BOOL;        // TRUE = autotest passé, attente réarmement
    StartupCheckOK      : BOOL;        // Résultat autotest (latche le temps du front)
END_VAR

// === IMPLEMENTATION ===

// 🔄 Fronts
EnableRising(CLK := Enable);
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);

// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Error := FALSE;
    ErrorId := 16#0000;
    Cmd.MaintainA_Cmd := FALSE;
    Cmd.MaintainB_Cmd := FALSE;
    Cmd.ArmPulse_Cmd := FALSE;
    ArmingSeqStep := 0;
    RedundancyTestFailed := FALSE;
    EmergencyArmingFailed := FALSE;
    EmergencyArmingLockoutActive := FALSE;
    ForceTestA := FALSE;
    ForceTestB := FALSE;
    Armable := FALSE;
    ArmingBusy := FALSE;
    StartupFail := FALSE;
    StartupCheckDone := FALSE;
    StartupCheckOK := FALSE;
    TonTestA(IN := FALSE);
    TonRestoreA(IN := FALSE);
    TonTestB(IN := FALSE);
    TonRestoreB(IN := FALSE);
    TonArmingPulse(IN := FALSE);
    TonArmingConfirm(IN := FALSE);
    TonArmingLockout(IN := FALSE);
    RETURN;
END_IF;

// 🏁 2. AUTOTEST DÉMARRAGE (§5.4 AF01)
// Vérifications synchrones 1 cycle au premier passage Enable=TRUE
IF EnableRising.Q THEN
    StartupCheckDone := FALSE;
END_IF;

IF NOT StartupCheckDone THEN
    // Exécute les 4 contrôles en 1 cycle
    StartupCheckOK := EmergencyChainClosed          // 1. Boucle AU fermée
                      AND NOT PowerContactorEngaged // 2. Contacteur au repos
                      AND (ArmingSeqStep = 0);      // 4. Pas de séquence résiduelle
    // Le maintien A/B est vérifié via l'absence de RedundancyTestFailed
    // (si un canal est ouvert au démarrage, RedundancyTestFailed sera levé
    //  à la première tentative de réarmement — pas bloquant au boot)
    StartupCheckDone := TRUE;
    StartupFail := NOT StartupCheckOK;
    // Si échec : on reste en attente, ErrorId est positionné
    IF NOT StartupCheckOK THEN
        ErrorId := 16#0008; // bit3 = startup autotest fail
        Error := TRUE;
    END_IF;
    RETURN; // 1 cycle pour laisser le temps aux entrées de se stabiliser
ELSE
    StartupFail := FALSE;
END_IF;

// 🔍 3. ACQUITTEMENT DES DÉFAUTS
IF ResetEdge.Q THEN
    RedundancyTestFailed := FALSE;
    StartupFail := FALSE;
    IF PowerContactorEngaged THEN
        EmergencyArmingFailed := FALSE;
    END_IF;
    // Reset efface aussi bit3 d'ErrorId
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🚦 4. DÉCLENCHEMENT DE LA SÉQUENCE DE SÉCURITÉ
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND EmergencyChainClosed 
   AND NOT EmergencyArmingLockoutActive 
   AND NOT PowerContactorEngaged THEN
    ArmingSeqStep := 1;
END_IF;

// ⏱️ Étape 1 : Coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := T#200ms);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF EmergencyChainClosed THEN
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 2;
        END_IF;
    END_IF;
ELSE
    ForceTestA := FALSE;
END_IF;

// ⏱️ Étape 2 : Restaure A, attend le retour sain de la boucle amont
TonRestoreA(IN := (ArmingSeqStep = 2), PT := T#200ms);
IF (ArmingSeqStep = 2) AND TonRestoreA.Q THEN
    IF EmergencyChainClosed THEN
        ArmingSeqStep := 3;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 3 : Coupe canal B seul, vérifie que la boucle tombe
TonTestB(IN := (ArmingSeqStep = 3), PT := T#200ms);
IF ArmingSeqStep = 3 THEN
    ForceTestB := TRUE;
    IF TonTestB.Q THEN
        ForceTestB := FALSE;
        IF EmergencyChainClosed THEN
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 4;
        END_IF;
    END_IF;
ELSE
    ForceTestB := FALSE;
END_IF;

// ⏱️ Étape 4 : Restaure B, attend le retour sain de la boucle amont
TonRestoreB(IN := (ArmingSeqStep = 4), PT := T#200ms);
IF (ArmingSeqStep = 4) AND TonRestoreB.Q THEN
    IF EmergencyChainClosed THEN
        ArmingSeqStep := 5;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 5 : Les 2 canaux validés -> impulsion réarmement physique (1s)
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := T#1s);
Cmd.ArmPulse_Cmd := (ArmingSeqStep = 5);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// ⏱️ Étape 6 : Attente confirmation contacteur principal (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := T#2s);
IF ArmingSeqStep = 6 THEN
    IF PowerContactorEngaged THEN
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := FALSE;
    ELSIF TonArmingConfirm.Q THEN
        EmergencyArmingFailed := TRUE;
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    END_IF;
END_IF;

// ⏱️ Séquence de verrouillage temporel (5s)
TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := T#5s);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

// 📤 5. GÉNÉRATION DES CONSIGNES LOGIQUES
Cmd.MaintainA_Cmd := NOT PowerCutOffRequest AND NOT ForceTestA AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed;
Cmd.MaintainB_Cmd := NOT PowerCutOffRequest AND NOT ForceTestB AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed;
// ArmPulse_Cmd déjà positionné à l'étape 5 ci-dessus (garder FALSE hors étape 5)
IF ArmingSeqStep <> 5 THEN
    Cmd.ArmPulse_Cmd := FALSE;
END_IF;

// 🚦 6. ÉTATS PUBLICS (repris par le composite dans State/Diag)
Armable := EmergencyChainClosed
           AND (ArmingSeqStep = 0)
           AND NOT EmergencyArmingLockoutActive
           AND NOT RedundancyTestFailed
           AND NOT PowerContactorEngaged;

ArmingBusy := (ArmingSeqStep <> 0) OR EmergencyArmingLockoutActive;

// 📤 7. SYNTHÈSE DES ERREURS
ErrorId := 16#0000;
IF RedundancyTestFailed THEN
    ErrorId := ErrorId OR 16#0001;
END_IF;
IF EmergencyArmingFailed THEN
    ErrorId := ErrorId OR 16#0002;
END_IF;
// bit3 (16#0008) = StartupFail, positionné au §2 si autotest échoué
// — ne pas l'effacer ici (reset explicite requis)

Error := (ErrorId <> 16#0000);
