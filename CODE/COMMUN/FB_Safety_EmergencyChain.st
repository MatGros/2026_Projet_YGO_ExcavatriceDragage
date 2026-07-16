(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyChain — Bloc de sécurité de la boucle d'urgence
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Séquence d'auto-test de redondance et réarmement de la 
      boucle d'arrêt d'urgence de la machine.
   ⚙️ Encapsule la double coupure A/B et le contrôle de collage contacteur.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyChain
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (CmdEmergencyArming)
    EmergencyChain      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    EmergencyStopOk     : BOOL;        // Confirmation contacteur de puissance principal
    PowerCutOffRequest  : BOOL;        // Requête de coupure des blocs safety métiers (M1/M2/M3)
    CmdEmergencyCutOff  : BOOL;        // Commande d'ouverture d'urgence depuis l'IHM
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: RedundancyTestFailed, bit1: EmergencyArmingFailed
    
    PowerCutOff_A_RQ    : BOOL;        // Sortie de pilotage canal A (maintenu à TRUE, fail-safe)
    PowerCutOff_B_RQ    : BOOL;        // Sortie de pilotage canal B (maintenu à TRUE, fail-safe)
    EmergencyArming_RQ  : BOOL;        // Impulsion réarmement physique (1s)
    
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
    PowerCutOff_A_RQ := FALSE;
    PowerCutOff_B_RQ := FALSE;
    EmergencyArming_RQ := FALSE;
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
    Busy := FALSE; Done := FALSE; Ready := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);

// 🔍 2. ACQUITTEMENT DES DÉFAUTS
IF ResetEdge.Q THEN
    RedundancyTestFailed := FALSE; // Défaut matériel : reset inconditionnel sur front
    IF EmergencyStopOk THEN
        EmergencyArmingFailed := FALSE; // Cause disparue (contacteur collé) + reset
    END_IF;
END_IF;

// 🚦 3. DÉCLENCHEMENT DE LA SÉQUENCE DE RÉARMEMENT
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND EmergencyChain 
   AND NOT EmergencyArmingLockoutActive 
   AND NOT EmergencyStopOk THEN // Ignoré si déjà armé
    ArmingSeqStep := 1;
END_IF;

// ⏱️ Étape 1 : Coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := T#200ms);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF EmergencyChain THEN
            // La boucle n'est pas tombée -> défaut de redondance
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
        ArmingSeqStep := 0; // Boucle non restaurée
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
EmergencyArming_RQ := (ArmingSeqStep = 5);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// ⏱️ Étape 6 : Attente confirmation contacteur principal (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := T#2s);
IF ArmingSeqStep = 6 THEN
    IF EmergencyStopOk THEN
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    ELSIF TonArmingConfirm.Q THEN
        EmergencyArmingFailed := TRUE;
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    END_IF;
END_IF;

// ⏱️ Séquence de verrouillage temporel (5s de sécurité après essai)
TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := T#5s);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

// 📤 4. GESTION DES COMMANDES DE COUPURE FAIL-SAFE
// Si défaut de redondance ou d'armement détecté -> on force l'ouverture en sécurité
PowerCutOff_A_RQ := NOT PowerCutOffRequest AND NOT ForceTestA AND NOT CmdEmergencyCutOff AND NOT RedundancyTestFailed;
PowerCutOff_B_RQ := NOT PowerCutOffRequest AND NOT ForceTestB AND NOT CmdEmergencyCutOff AND NOT RedundancyTestFailed;

// 📤 5. SYNTHÈSE DES ERREURS POUR LE CONTRAT FB
ErrorId := 16#0000;
IF RedundancyTestFailed THEN
    ErrorId := ErrorId OR 16#0001;
END_IF;
IF EmergencyArmingFailed THEN
    ErrorId := ErrorId OR 16#0002;
END_IF;

Error := (ErrorId <> 16#0000);
Busy  := (ArmingSeqStep <> 0);
Done  := EmergencyStopOk AND NOT Error;
