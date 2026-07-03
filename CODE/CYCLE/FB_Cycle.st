(* ═══════════════════════════════════════════════════════════════
   🔄 FB_Cycle — Machine d'état séquentielle (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à piloter les cycles automatiques et semi-automatiques
      de l'Excavatrice (descente, dragage/godet, remontée, déversement).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_Cycle
VAR_INPUT
    Enable              : BOOL;         // Standard
    Reset               : BOOL;         // Acquittement défaut (front)
    EmergencyStopOk     : BOOL;         // Standard
    
    // Commandes opérateur
    StartCycle          : BOOL;         // Demande de lancement du cycle
    PauseCycle          : BOOL;         // Demande de mise en pause du cycle
    AbortCycle          : BOOL;         // Demande d'arrêt d'urgence/abandon cycle
    
    // Paramètres cycle (provenance GVL_PERSISTENT / GVL_IHM)
    TargetDepthM        : REAL;         // Profondeur de dragage cible (négative)
    TargetOffsetM       : REAL;         // Décalage grappin cible pour fermeture
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;
    
    // Commandes vers les actionneurs
    CmdWinchM1_StartStop : BOOL;
    CmdWinchM1_Direction : INT;
    CmdWinchM1_SpeedPct  : REAL;
    
    CmdWinchM2_StartStop : BOOL;
    CmdWinchM2_Direction : INT;
    CmdWinchM2_SpeedPct  : REAL;
    
    CmdChariotM3_Start   : BOOL;
    CmdChariotM3_Target  : INT;
    
    // État du cycle pour l'IHM
    CycleStep           : INT;          // Numéro de l'étape active
    CycleStateStr       : STRING(80);   // Description textuelle de l'état
END_VAR
VAR
    ResetEdge           : R_TRIG;
    StartEdge           : R_TRIG;
    
    // Machine d'état
    State               : INT := 0;     // 0 = Idle, 10 = Descente, 20 = Fermeture, 30 = Remontée, 40 = Vidange
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. GATE — Repli sécurisé
IF NOT Enable OR NOT EmergencyStopOk THEN
    CmdWinchM1_StartStop := FALSE;
    CmdWinchM1_Direction := 0;
    CmdWinchM1_SpeedPct  := 0.0;
    
    CmdWinchM2_StartStop := FALSE;
    CmdWinchM2_Direction := 0;
    CmdWinchM2_SpeedPct  := 0.0;
    
    CmdChariotM3_Start   := FALSE;
    
    State := 0;
    CycleStep := 0;
    CycleStateStr := "DÉSACTIVÉ / ARRET";
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);

// 🔁 2. LOGIQUE DU SÉQUENCEUR (Grafcet / Machine d'état)
CASE State OF
    0:  // IDLE / ATTENTE
        CycleStep := 0;
        CycleStateStr := "ATTENTE DÉMARRAGE";
        Busy := FALSE;
        Done := FALSE;
        
        IF StartEdge.Q THEN
            State := 10; // Lancement vers la première étape
        END_IF;
        
    10: // DESCENTE DU GRAPPIN OUVERT
        CycleStep := 10;
        CycleStateStr := "DESCENTE GRAPPIN OUVERT";
        Busy := TRUE;
        
        // Squelette de commande :
        // CmdWinchM1_StartStop := TRUE; CmdWinchM1_Direction := -1; CmdWinchM1_SpeedPct := 50.0;
        // CmdWinchM2_StartStop := TRUE; CmdWinchM2_Direction := -1; CmdWinchM2_SpeedPct := 50.0;
        
        // Condition de transition à définir (ex: position atteinte)
        
    20: // FERMETURE DU GODET (DÉBUT EXCAVATION)
        CycleStep := 20;
        CycleStateStr := "FERMETURE GODET / EXCAVATION";
        
        // Condition de transition
        
    30: // REMONTÉE DU GODET FERMÉ
        CycleStep := 30;
        CycleStateStr := "REMONTÉE DU GODET";
        
        // Condition de transition
        
    40: // DÉPLACEMENT CHARIOT & VIDANGE
        CycleStep := 40;
        CycleStateStr := "VIDANGE DU GODET";
        
        // Condition de transition
        
END_CASE;

IF AbortCycle THEN
    State := 0;
END_IF;
