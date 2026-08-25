(* =======================================================================
   📊 FB_Acquisition_Preflight — Verdict passif machine arrêtée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Verdict passif de qualification E/S machine arrêtée (16 contrôles)
   🔒 Polarité : Observateur pur (aucun SafeStop, PowerCutOff ou ordre machine)
   📄 Doc métier : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §6
   ======================================================================= *)
FUNCTION_BLOCK FB_Acquisition_Preflight
VAR_INPUT
    // === COMMANDES & ETATS MACHINE ===
    Execute                 : BOOL; // --> [CMD] Lancement du verdict (front montant)
    MachineIsStill          : BOOL; // --> [HW]  Machine a l'arret complet (vitesse nulle)

    // === ETATS FREINS & CONTACTEURS ===
    M1BrakeApplied          : BOOL; // --> [HW]  Frein M1 serre
    M2BrakeApplied          : BOOL; // --> [HW]  Frein M2 serre
    M3BrakeApplied          : BOOL; // --> [HW]  Frein M3 serre
    M1ContactorsReleased    : BOOL; // --> [HW]  Contacteurs M1 retombes
    M2ContactorsReleased    : BOOL; // --> [HW]  Contacteurs M2 retombes

    // === PROTECTION THERMIQUE & RESEAU ===
    M1ThermalOk             : BOOL; // --> [HW]  Thermique moteur M1 OK
    M2ThermalOk             : BOOL; // --> [HW]  Thermique moteur M2 OK
    BrakeThermalOk          : BOOL; // --> [HW]  Thermique freins OK
    PhaseRotationOk         : BOOL; // --> [HW]  Ordre des phases reseau OK

    // === CAPTEURS & CHAINE DE SECURITE ===
    SlackCableTensioned     : BOOL; // --> [HW]  Cable M2 tendu (anti-mou)
    M3SensorWordIncoherent  : BOOL; // --> [HW]  Incoherence mot capteurs M3
    EmergencyChainClosed    : BOOL; // --> [SAFE] Chaine d'arret d'urgence fermee
    PowerContactorEngaged   : BOOL; // --> [HW]  Contacteur de puissance enclenche

    // === CODEURS & HOMING ===
    EncoderM1Operational    : BOOL; // --> [HW]  Codeur M1 operationnel
    EncoderM2Operational    : BOOL; // --> [HW]  Codeur M2 operationnel
    HomedM1                 : BOOL; // --> [HW]  Homing M1 effectue
    HomedM2                 : BOOL; // --> [HW]  Homing M2 effectue
    M1PositionInBounds      : BOOL; // --> [HW]  Position M1 dans les bornes
    M2PositionInBounds      : BOOL; // --> [HW]  Position M2 dans les bornes
END_VAR
VAR_OUTPUT
    // === ETATS ET DIAGNOSTIC ===
    PreflightOk             : BOOL; // <-- [STAT] Verdict preflight OK (aucun defaut)
    PreflightDone           : BOOL; // <-- [STAT] Verdict preflight termine
    PreflightBusy           : BOOL; // <-- [STAT] Diagnostic preflight en cours
    PreflightErrorId        : WORD; // <-- [DIAG] Masque de defauts preflight (16 bits)
END_VAR
VAR
    // === TRIGGERS & ETATS INTERNES ===
    ExecuteEdge             : R_TRIG;       // . [LOC] Trigger front montant Execute
    BootPending             : BOOL := TRUE; // . [LOC] Demande preflight initiale au demarrage
    RequestPending          : BOOL;         // . [LOC] Demande de verdict en attente
END_VAR

{region "§1 Gate et demande"}
ExecuteEdge(CLK := Execute);
RequestPending := RequestPending OR ExecuteEdge.Q OR BootPending;
PreflightBusy := RequestPending AND NOT MachineIsStill;
IF NOT MachineIsStill THEN PreflightDone := FALSE; RETURN; END_IF;
IF NOT RequestPending THEN RETURN; END_IF;
{endregion}

{region "§2 Calcul verdict"}
PreflightErrorId := 0;
(* bit0..2 frein M1/M2/M3 serré; bit3..4 contacteurs M1/M2 retombés;
   bit5..6 thermique M1/M2 OK; bit7 thermique frein OK; bit8 phases OK;
   bit9 câble M2 tendu; bit10 mot M3 cohérent; bit11 contacteur sans chaîne;
   bit12..13 codeur M1/M2 opérationnel; bit14..15 homé et position bornée M1/M2. *)
IF NOT M1BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0001; END_IF;
IF NOT M2BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0002; END_IF;
IF NOT M3BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0004; END_IF;
IF NOT M1ContactorsReleased THEN PreflightErrorId := PreflightErrorId OR 16#0008; END_IF;
IF NOT M2ContactorsReleased THEN PreflightErrorId := PreflightErrorId OR 16#0010; END_IF;
IF NOT M1ThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0020; END_IF;
IF NOT M2ThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0040; END_IF;
IF NOT BrakeThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0080; END_IF;
IF NOT PhaseRotationOk THEN PreflightErrorId := PreflightErrorId OR 16#0100; END_IF;
IF NOT SlackCableTensioned THEN PreflightErrorId := PreflightErrorId OR 16#0200; END_IF;
IF M3SensorWordIncoherent THEN PreflightErrorId := PreflightErrorId OR 16#0400; END_IF;
IF PowerContactorEngaged AND NOT EmergencyChainClosed THEN PreflightErrorId := PreflightErrorId OR 16#0800; END_IF;
IF NOT EncoderM1Operational THEN PreflightErrorId := PreflightErrorId OR 16#1000; END_IF;
IF NOT EncoderM2Operational THEN PreflightErrorId := PreflightErrorId OR 16#2000; END_IF;
IF NOT HomedM1 OR NOT M1PositionInBounds THEN PreflightErrorId := PreflightErrorId OR 16#4000; END_IF;
IF NOT HomedM2 OR NOT M2PositionInBounds THEN PreflightErrorId := PreflightErrorId OR 16#8000; END_IF;
{endregion}

{region "§3 Sortie"}
PreflightOk := (PreflightErrorId = 0); PreflightDone := TRUE; BootPending := FALSE; RequestPending := FALSE;
{endregion}
