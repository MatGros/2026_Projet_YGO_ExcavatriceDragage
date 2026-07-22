(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyManagementLogic — Décision & Séquencement
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Gère la machine d'état d'auto-test et de réarmement de
      la boucle d'arrêt d'urgence. Produit les consignes logiques.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md ; DOC/AF_Partie-03_Template_FB_Commun_v1.3.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementLogic
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)
    EmergencyChain      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    EmergencyStopOk     : BOOL;        // Confirmation contacteur de puissance principal
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
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ArmReqEdge          : R_TRIG;
    ForceTestA          : BOOL;
    ForceTestB          : BOOL;
    TonTestA            : TON;
    TonRestoreA         : TON;
    TonTestB            : TON;
    TonRestoreB         : TON;
    TonArmingPulse      : TON;
    TonArmingConfirm    : TON;
    TonArmingLockout    : TON;
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Error := FALSE;
    ErrorId := 16#0000;
    Cmd.PowerCutOff_A_Cmd := FALSE;
    Cmd.PowerCutOff_B_Cmd := FALSE;
    Cmd.EmergencyArming_Cmd := FALSE;
    ArmingSeqStep := 0;
    RedundancyTestFailed := FALSE;
    EmergencyArmingFailed := FALSE;
    EmergencyArmingLockoutActive := FALSE;
    ForceTestA := FALSE;
    ForceTestB := FALSE;
    TonTestA(IN := FALSE);
    TonRestoreA(IN := FALSE);
    TonTestB(IN := FALSE);
    TonRestoreB(IN := FALSE);
    TonArmingPulse(IN := FALSE);
    TonArmingConfirm(IN := FALSE);
    TonArmingLockout(IN := FALSE);
    RETURN;
END_IF;

ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);

// 🔍 2. ACQUITTEMENT DES DÉFAUTS
IF ResetEdge.Q THEN
    RedundancyTestFailed := FALSE;
    IF EmergencyStopOk THEN
        EmergencyArmingFailed := FALSE;
    END_IF;
END_IF;

// 🚦 3. DÉCLENCHEMENT DE LA SÉQUENCE DE SÉCURITÉ
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND EmergencyChain 
   AND NOT EmergencyArmingLockoutActive 
   AND NOT EmergencyStopOk THEN
    ArmingSeqStep := 1;
END_IF;

// ⏱️ Étape 1 : Coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := T#200ms);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF EmergencyChain THEN
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
    IF EmergencyChain THEN
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
        IF EmergencyChain THEN
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
    IF EmergencyChain THEN
        ArmingSeqStep := 5;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 5 : Les 2 canaux validés -> impulsion réarmement physique (1s)
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := T#1s);
Cmd.EmergencyArming_Cmd := (ArmingSeqStep = 5);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// ⏱️ Étape 6 : Attente confirmation contacteur principal (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := T#2s);
IF ArmingSeqStep = 6 THEN
    IF EmergencyStopOk THEN
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

// 📤 4. GÉNÉRATION DES CONSIGNES LOGIQUES
Cmd.PowerCutOff_A_Cmd := NOT PowerCutOffRequest AND NOT ForceTestA AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed;
Cmd.PowerCutOff_B_Cmd := NOT PowerCutOffRequest AND NOT ForceTestB AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed;

// 📤 5. SYNTHÈSE DES ERREURS
ErrorId := 16#0000;
IF RedundancyTestFailed THEN
    ErrorId := ErrorId OR 16#0001;
END_IF;
IF EmergencyArmingFailed THEN
    ErrorId := ErrorId OR 16#0002;
END_IF;

Error := (ErrorId <> 16#0000);
