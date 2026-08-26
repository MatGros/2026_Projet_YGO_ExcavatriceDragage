(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_Translation — Bloc Safety pour le Translation M3 (EtherCAT)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   Rôle : Surveillance joystick, bus EtherCAT, rotation de phases,
      thermique frein commun, Méca A (vitesse non commandée à l'arrêt),
      Méca B (frein/variateur en mouvement à l'arrêt), et Fdc extrêmes.
   🎯 Invariant : les défauts de communication (bits 0/1/2) ne coupent
      jamais la puissance amont (SafeStop seul) ; seuls les défauts
      physiques (bits 3..7) déclenchent PowerCutOff.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Safety_Translation
VAR_INPUT
    Enable              : BOOL;        // --> [CMD] Active la surveillance
    Reset               : BOOL;        // --> [CMD] Front acquittement défauts
    PowerContactorEngaged     : BOOL;        // --> [SAFE] Chaîne AU réarmée + conditions globales OK
    Mode                : E_Mode;      // --> [CMD] Mode courant
    JoystickOnline      : BOOL;        // --> [HW] instDiagCanOpen.DeviceJoystick.Online
    JoystickOperational : BOOL;        // --> [HW] instDiagCanOpen.DeviceJoystick.Operational
    HeartbeatIhmOk      : BOOL;        // --> [HW] IHM↔PLC : TRUE après front post-boot, FALSE = perte communication opérateur
    PhaseRotationOk     : BOOL;        // --> [HW] PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI (TRUE = OK)
    BrakeThermalFeedback: BOOL;        // --> [HW] Thermique frein commun M1/M2/M3 (NC, TRUE = surchauffe/perte)

    // 🔌 Spécifique EtherCAT & Capteurs réels
    DriveOnline         : BOOL;        // --> [HW] Status diagnostic communication EtherCAT (Online)
    DriveOperational    : BOOL;        // --> [HW] Status diagnostic communication EtherCAT (Operational)
    DriveStatusWord     : WORD;        // --> [HW] Mot d'état variateur AC600
    DriveActualFreqHz   : REAL;        // --> [HW] Vitesse réelle variateur (Hz)
    BrakeFeedback       : BOOL;        // --> [HW] Retour d'état bobine frein (TRUE = ouvert/desserré)
    BrakeCmd            : BOOL;        // --> [HW] Commande frein
    Direction           : INT;         // --> [CMD] Direction commandée
    LimitSwitchFwd      : BOOL;        // --> [HW] Fin de course extrême avant
    LimitSwitchRev      : BOOL;        // --> [HW] Fin de course extrême arrière
    SensorWordIncoherent: BOOL;        // --> [HW] Mot des 5 capteurs position hors combinaisons valides (FB_Translation_PositionDecoder.Incoherent)

    // 🔧 Bypass des surveillances (GVL_IHM.TranslationM3.Bypass)
    BypassGlobal          : BOOL := FALSE;   // --> [TST] Bypass GLOBAL : ignore TOUTES les surveillances ci-dessous (prioritaire)
    BypassOperatorComm    : BOOL := FALSE;   // --> [TST] Bypass perte communication opérateur
    BypassDriveComm       : BOOL := FALSE;   // --> [TST] Bypass perte communication drive
    BypassPhaseRotation   : BOOL := FALSE;   // --> [TST] Bypass défaut rotation phases
    BypassBrakeThermal    : BOOL := FALSE;   // --> [TST] Bypass surchauffe frein
    BypassMecaB           : BOOL := FALSE;   // --> [TST] Bypass Méca B
    BypassMecaA           : BOOL := FALSE;   // --> [TST] Bypass Méca A
    BypassLimitSwitch     : BOOL := FALSE;   // --> [TST] Bypass butées extrêmes
    BypassSensorIncoherent: BOOL := FALSE;   // --> [TST] Bypass incohérence mot capteurs
    BypassSafety          : BOOL := FALSE;   // --> [TST] Bypass groupé PowerCutOff (BrakeThermal/MecaB/MecaA/LimitSwitch/SensorIncoherent)
    BypassProcess         : BOOL := FALSE;   // --> [TST] Bypass groupé SafeStop seul (OperatorComm/DriveComm/PhaseRotation/ContactorFeedback)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;   // <-- [STAT] FB prêt (sortie libre, hors ST_FbStatus)
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "Perte communication opérateur" - joystick CAN ou heartbeat IHM absent ; bit1: "Perte communication EtherCAT" - perte com EtherCAT ; bit2: "Défaut Rotation Phases" - rotation phases ; bit3: "Surchauffe Frein Translation" - thermique frein ; bit4: "Absence confirmation arrêt (Méca B)" - Méca B (incohérence arrêt) ; bit5: "Mouvement non commandé (Méca A)" - Méca A (mouvement non commandé) ; bit6: "Limite extrême Translation atteinte" - Fdc extrême atteint ; bit7: "Incohérence mot capteurs position" - combinaison des 5 capteurs Trémie/PV/P2/P1/Maintenance hors table valide
    Status              : ST_FbStatus;
    SafeStop            : BOOL;        // <-- [ACT] Décélération rapide (PLC)
    PowerCutOff         : BOOL;        // <-- [ACT] Coup de poing / coupure puissance amont
    ErrorOperatorComm   : BOOL;        // <-- [DIAG] Perte communication opérateur : joystick CAN ou heartbeat IHM (bit0)
    ErrorDriveComm      : BOOL;        // <-- [DIAG] Perte communication EtherCAT variateur (bit1)
    ErrorPhaseRotation  : BOOL;        // <-- [DIAG] Mauvaise rotation de phases (bit2)
    ErrorBrakeThermal   : BOOL;        // <-- [DIAG] Surchauffe thermique frein commun (bit3)
    ErrorMecaB          : BOOL;        // <-- [DIAG] Absence confirmation arrêt (Méca B - bit4)
    ErrorMecaA          : BOOL;        // <-- [DIAG] Mouvement non commandé (Méca A - bit5)
    ErrorLimitSwitch    : BOOL;        // <-- [DIAG] Limite extrême Translation atteinte (bit6)
    ErrorSensorIncoherent: BOOL;       // <-- [DIAG] Incohérence mot capteurs position (bit7)
END_VAR
VAR
    ResetEdge           : R_TRIG;   // . [LOC] Front Reset
    ErrorEdge           : R_TRIG;   // . [LOC] Front Erreur
    TonMecaB            : TON;         // . [LOC] Sécurité à l'arrêt (Méca B)
    TonMecaA            : TON;         // . [LOC] Sécurité mouvement non commandé (Méca A)
    TonLimitSwitchOverrun : TON;       // . [LOC] Surveillance poussée anormale / escalade fin de course
    OverrunCondition    : BOOL;   // . [LOC] Condition escalade fin de course
    PostRampTimeout     : TIME := T#3S;   // . [LOC] Délai Méca B
    UncommandedActiveB  : BOOL;   // . [LOC] Méca B active
    UncommandedActiveA  : BOOL;   // . [LOC] Méca A active
    FirstScanDone       : BOOL;   // . [LOC] Initialisation premier scan
    TonStartupWarmup    : TON;         // . [LOC] Inhibition 3s au boot + effacement auto coms
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    // 🛡️ Status.ErrorId conservé : la cause du dernier défaut reste visible IHM.
    // Status.Error en miroir de cette cause ; les sorties restent fail-safe (lignes ci-dessous).
    Status.Error := (Status.ErrorId <> 16#0000);
    SafeStop := FALSE;
    PowerCutOff := FALSE;
    ErrorOperatorComm := FALSE;
    ErrorDriveComm := FALSE;
    ErrorPhaseRotation := FALSE;
    ErrorBrakeThermal := FALSE;
    ErrorMecaB := FALSE;
    ErrorMecaA := FALSE;
    ErrorLimitSwitch := FALSE;
    ErrorSensorIncoherent := FALSE;
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
    TonLimitSwitchOverrun(IN := FALSE);
    TonStartupWarmup(IN := FALSE);
    Status.State := E_State.DISABLED;
    Status.Busy := FALSE; Status.Done := FALSE; Ready := FALSE;
    RETURN;
END_IF;

{endregion}

{region "§1bis Initialisation et bypass global"}
Ready := TRUE;
ResetEdge(CLK := Reset);

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    Status.ErrorId := 16#0000;
    RETURN;
END_IF;

// 🌐 BYPASS GLOBAL : si actif → force Status.ErrorId = 0 et saute toutes les vérifications
// (les bits d'erreur resteraient coincés si on ne les nettoie pas)
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
END_IF;

{endregion}

{region "§2 Diagnostics et protections translation"}
// ⚠️ ResetEdge doit être traité même si bypass actif, pour que le reset IHM fonctionne.
// On ne l'exécute que si on n'est PAS en bypass global (sinon ErrorId déjà à 0).
IF NOT BypassGlobal THEN
    // ⏱️ Temporisation 3s de mise en route des bus de terrain au boot (EtherCAT / CANopen / Modbus IHM)
    TonStartupWarmup(IN := Enable, PT := T#3s);

    // 🔍 2. PERTE COMMUNICATION OPÉRATEUR (bit0) — joystick CAN ou heartbeat IHM.
    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassOperatorComm) THEN
        IF (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk) THEN
            Status.ErrorId := Status.ErrorId OR 16#0001;
        ELSE
            Status.ErrorId := Status.ErrorId AND 16#FFFE; (* Effacement auto si la com repasse saine *)
        END_IF;
    ELSIF NOT TonStartupWarmup.Q THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFE; (* Inhibition pendant l'initialisation boot *)
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFFE; END_IF;

    // 🔍 2bis. PERTE ETHERCAT VARIATEUR M3 (bit1)
    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassDriveComm) THEN
        IF (NOT DriveOnline OR NOT DriveOperational) THEN
            Status.ErrorId := Status.ErrorId OR 16#0002;
        ELSE
            Status.ErrorId := Status.ErrorId AND 16#FFFD; (* Effacement auto si l'EtherCAT variateur M3 repasse sain *)
        END_IF;
    ELSIF NOT TonStartupWarmup.Q THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFD; (* Inhibition pendant l'initialisation boot *)
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFFD; END_IF;

    // 🔍 3. MAUVAISE ROTATION DE PHASE (bit2)
    IF NOT (BypassProcess OR BypassPhaseRotation) THEN
        IF NOT PhaseRotationOk THEN
            Status.ErrorId := Status.ErrorId OR 16#0004;
        END_IF;
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFFB; END_IF;

    // 🔍 3ter. THERMIQUE FREIN COMMUN M1/M2/M3 (bit3)
    IF NOT (BypassSafety OR BypassBrakeThermal) THEN
        IF BrakeThermalFeedback THEN
            Status.ErrorId := Status.ErrorId OR 16#0008;
        END_IF;
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFF7; END_IF;

    // 🔍 3quater. INCOHÉRENCE À L'ARRÊT (Méca B — bit4)
    IF NOT (BypassSafety OR BypassMecaB) THEN
        IF NOT HeartbeatIhmOk THEN
            UncommandedActiveB := (ABS(DriveActualFreqHz) > 0.5) OR DriveStatusWord.0 OR BrakeFeedback;
        ELSIF (Direction = 0) AND NOT BrakeCmd THEN
            UncommandedActiveB := DriveStatusWord.0 OR BrakeFeedback;
        ELSE
            UncommandedActiveB := FALSE;
        END_IF;
        TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
        IF TonMecaB.Q THEN Status.ErrorId := Status.ErrorId OR 16#0010; END_IF;
    ELSE
        TonMecaB(IN := FALSE);
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFEF; END_IF;

    // 🔍 3quinquies. MOUVEMENT NON COMMANDÉ (Méca A — bit5)
    IF NOT (BypassSafety OR BypassMecaA) THEN
        IF (Direction = 0) AND NOT BrakeCmd THEN
            UncommandedActiveA := ABS(DriveActualFreqHz) > 0.5;
        ELSE
            UncommandedActiveA := FALSE;
        END_IF;
        TonMecaA(IN := UncommandedActiveA, PT := T#1S);
        IF TonMecaA.Q THEN Status.ErrorId := Status.ErrorId OR 16#0020; END_IF;
    ELSE
        TonMecaA(IN := FALSE);
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FFDF; END_IF;

    // 🔍 3sexies. SURVEILLANCE ESCALADE FIN DE COURSE (bit6)
    IF (BypassSafety OR BypassLimitSwitch) THEN
        // Nettoie le bit 6 résiduel (posé avant activation du bypass)
        Status.ErrorId := Status.ErrorId AND 16#FFBF;
        TonLimitSwitchOverrun(IN := FALSE);
    ELSE
        // 🧱 L'erreur 64 (escalade / poussée anormale en butée) ne s'active QUE SI :
        // 1. On est sur le capteur Trémie (LimitSwitchFwd) ET qu'on continue d'insister en Marche Avant (Direction = 1) avec vitesse/commande variateur active.
        // 2. OU qu'on est sur le capteur Maintenance (LimitSwitchRev) ET qu'on continue d'insister en Marche Arrière (Direction = -1) avec vitesse/commande variateur active.
        OverrunCondition := (LimitSwitchFwd AND (Direction = 1) AND (ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0))
                         OR (LimitSwitchRev AND (Direction = -1) AND (ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0));

        TonLimitSwitchOverrun(IN := OverrunCondition, PT := T#1S500MS);

        IF TonLimitSwitchOverrun.Q THEN
            Status.ErrorId := Status.ErrorId OR 16#0040; // Défaut escalade confirmé (coupure puissance amont)
        ELSE
            // Si la poussée dans le mauvais sens cesse (ou si on repart en arrière), le défaut s'auto-efface
            Status.ErrorId := Status.ErrorId AND 16#FFBF;
        END_IF;
    END_IF;

    // 🔍 3septies. INCOHÉRENCE MOT CAPTEURS POSITION (bit7)
    IF (BypassSafety OR BypassSensorIncoherent) THEN
        // Nettoye le bit 7 résiduel
        Status.ErrorId := Status.ErrorId AND 16#FF7F;
    ELSE
        IF SensorWordIncoherent THEN
            Status.ErrorId := Status.ErrorId OR 16#0080;
        END_IF;
    END_IF;
    IF ResetEdge.Q THEN Status.ErrorId := Status.ErrorId AND 16#FF7F; END_IF;

END_IF; // fin IF NOT BypassGlobal

{endregion}

{region "§4 Arbitrage sorties et etat"}
// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

SafeStop := Status.Error OR NOT PowerContactorEngaged;

// PowerCutOff actif si thermique frein (bit3), incohérence arrêt (bit4),
// mouvement non commandé (bit5), dépassement de fin de course (bit6),
// ou incohérence mot capteurs position (bit7)
PowerCutOff := (Status.ErrorId AND 16#00F8) <> 16#0000;

// Décapsulage du bitfield Status.ErrorId pour l'IHM
ErrorOperatorComm   := (Status.ErrorId AND 16#0001) <> 16#0000;
ErrorDriveComm      := (Status.ErrorId AND 16#0002) <> 16#0000;
ErrorPhaseRotation  := (Status.ErrorId AND 16#0004) <> 16#0000;
ErrorBrakeThermal   := (Status.ErrorId AND 16#0008) <> 16#0000;
ErrorMecaB          := (Status.ErrorId AND 16#0010) <> 16#0000;
ErrorMecaA          := (Status.ErrorId AND 16#0020) <> 16#0000;
ErrorLimitSwitch    := (Status.ErrorId AND 16#0040) <> 16#0000;
ErrorSensorIncoherent := (Status.ErrorId AND 16#0080) <> 16#0000;

Status.Busy := FALSE;
Status.Done := FALSE;

// 🚦 5. STATE MACHINE (phase diagnostic)
Status.State := E_State.READY;


{endregion}
