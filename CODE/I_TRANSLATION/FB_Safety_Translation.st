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
    Direction           : INT;         // --> [CMD] Direction commandée (-1: vers Maintenance, 0: Stop, 1: vers Trémie)
    LimitSwitchTremie   : BOOL;        // --> [HW] Fin de course extrême Trémie (ex-LimitSwitchFwd)
    LimitSwitchMaintenance : BOOL;     // --> [HW] Fin de course extrême Maintenance (ex-LimitSwitchRev)
    MaintenanceM3TargetEnable : BOOL;  // --> [CMD] Autorisation cible Maintenance (Auth.MaintenanceM3TargetEnable)
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
    Ready               : BOOL;   // <-- [STAT] FB prêt (sortie libre, hors ST_Status)
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault               : ST_Fault;
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
    TremiePermit        : BOOL;        // <-- [SAFE] Permis directionnel vers Trémie (TRUE = autorisé, fail-safe)
    MaintenancePermit   : BOOL;        // <-- [SAFE] Permis directionnel vers Maintenance (TRUE = autorisé, fail-safe)
END_VAR
VAR
    ResetEdge           : R_TRIG;   // . [LOC] Front Reset
    TonMecaB            : TON;         // . [LOC] Sécurité à l'arrêt (Méca B)
    TonMecaA            : TON;         // . [LOC] Sécurité mouvement non commandé (Méca A)
    TonLimitSwitchOverrun : TON;       // . [LOC] Surveillance poussée anormale / escalade fin de course
    OverrunCondition    : BOOL;   // . [LOC] Condition escalade fin de course
    PostRampTimeout     : TIME := T#3S;   // . [LOC] Délai Méca B
    UncommandedActiveB  : BOOL;   // . [LOC] Méca B active
    UncommandedActiveA  : BOOL;   // . [LOC] Méca A active
    FirstScanDone       : BOOL;   // . [LOC] Initialisation premier scan
    TonStartupWarmup    : TON;         // . [LOC] Inhibition 3s au boot + effacement auto coms

    // Latches défauts
    PhaseRotationFault  : BOOL;   // . [LOC] Latch rotation phase
    BrakeThermalFault   : BOOL;   // . [LOC] Latch thermique frein
    MecaBFault          : BOOL;   // . [LOC] Latch Méca B
    MecaAFault          : BOOL;   // . [LOC] Latch Méca A
    SensorIncoherentFault: BOOL;  // . [LOC] Latch mot capteurs incohérent

    // Socle défaut
    instFault           : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses          : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESET FRONT
ResetEdge(CLK := Reset);

IF ResetEdge.Q OR BypassGlobal THEN
    PhaseRotationFault    := FALSE;
    BrakeThermalFault     := FALSE;
    MecaBFault            := FALSE;
    MecaAFault            := FALSE;
    SensorIncoherentFault := FALSE;
END_IF;

IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    PhaseRotationFault    := FALSE;
    BrakeThermalFault     := FALSE;
    MecaBFault            := FALSE;
    MecaAFault            := FALSE;
    SensorIncoherentFault := FALSE;
END_IF;

IF NOT BypassGlobal THEN
    TonStartupWarmup(IN := Enable, PT := T#3s);

    // Cause 0 : Perte com opérateur (live)
    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassOperatorComm) THEN
        instCauses[0].Active := (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk);
    ELSE
        instCauses[0].Active := FALSE;
    END_IF;
    instCauses[0].Latching := FALSE;
    instCauses[0].Texte    := 'Perte communication operateur translation';

    // Cause 1 : Perte EtherCAT drive (live)
    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassDriveComm) THEN
        instCauses[1].Active := (NOT DriveOnline OR NOT DriveOperational);
    ELSE
        instCauses[1].Active := FALSE;
    END_IF;
    instCauses[1].Latching := FALSE;
    instCauses[1].Texte    := 'Perte communication EtherCAT variateur M3';

    // Cause 2 : Rotation de phase (latched)
    IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
        PhaseRotationFault := TRUE;
    END_IF;
    instCauses[2].Active   := PhaseRotationFault;
    instCauses[2].Latching := TRUE;
    instCauses[2].Texte    := 'Defaut rotation de phases';

    // Cause 3 : Thermique frein (latched)
    IF NOT (BypassSafety OR BypassBrakeThermal) AND BrakeThermalFeedback THEN
        BrakeThermalFault := TRUE;
    END_IF;
    instCauses[3].Active   := BrakeThermalFault;
    instCauses[3].Latching := TRUE;
    instCauses[3].Texte    := 'Surchauffe thermique frein translation';

    // Cause 4 : Méca B (latched)
    IF NOT (BypassSafety OR BypassMecaB) THEN
        IF NOT HeartbeatIhmOk THEN
            UncommandedActiveB := (ABS(DriveActualFreqHz) > 0.5) OR DriveStatusWord.0 OR BrakeFeedback;
        ELSIF (Direction = 0) AND NOT BrakeCmd THEN
            UncommandedActiveB := DriveStatusWord.0 OR BrakeFeedback;
        ELSE
            UncommandedActiveB := FALSE;
        END_IF;
        TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
        IF TonMecaB.Q THEN MecaBFault := TRUE; END_IF;
    ELSE
        TonMecaB(IN := FALSE);
    END_IF;
    instCauses[4].Active   := MecaBFault;
    instCauses[4].Latching := TRUE;
    instCauses[4].Texte    := 'Absence confirmation arret translation (Meca B)';

    // Cause 5 : Méca A (latched)
    IF NOT (BypassSafety OR BypassMecaA) THEN
        IF (Direction = 0) AND NOT BrakeCmd THEN
            UncommandedActiveA := ABS(DriveActualFreqHz) > 0.5;
        ELSE
            UncommandedActiveA := FALSE;
        END_IF;
        TonMecaA(IN := UncommandedActiveA, PT := T#1S);
        IF TonMecaA.Q THEN MecaAFault := TRUE; END_IF;
    ELSE
        TonMecaA(IN := FALSE);
    END_IF;
    instCauses[5].Active   := MecaAFault;
    instCauses[5].Latching := TRUE;
    instCauses[5].Texte    := 'Mouvement non commande translation (Meca A)';

    // Cause 6 : Limite extrême escalade (live)
    IF NOT (BypassSafety OR BypassLimitSwitch) THEN
        OverrunCondition := (LimitSwitchTremie AND (Direction = 1) AND (ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0))
                         OR (LimitSwitchMaintenance AND (Direction = -1) AND (ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0));
        TonLimitSwitchOverrun(IN := OverrunCondition, PT := T#1S500MS);
        instCauses[6].Active := TonLimitSwitchOverrun.Q;
    ELSE
        TonLimitSwitchOverrun(IN := FALSE);
        instCauses[6].Active := FALSE;
    END_IF;
    instCauses[6].Latching := FALSE;
    instCauses[6].Texte    := 'Depassement limite extreme translation';

    // Cause 7 : Mot capteurs incohérent (latched)
    IF NOT (BypassSafety OR BypassSensorIncoherent) AND SensorWordIncoherent THEN
        SensorIncoherentFault := TRUE;
    END_IF;
    instCauses[7].Active   := SensorIncoherentFault;
    instCauses[7].Latching := TRUE;
    instCauses[7].Texte    := 'Incoherence combinaison capteurs translation';

ELSE
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
    TonLimitSwitchOverrun(IN := FALSE);
END_IF;

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable THEN
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
    TremiePermit := FALSE;
    MaintenancePermit := FALSE;
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
    TonLimitSwitchOverrun(IN := FALSE);
    TonStartupWarmup(IN := FALSE);
    Ready := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Sorties sécurités et drapeaux IHM"}
// 📤 3. SORTIES SÉCURITÉ & DRAPEAUX
SafeStop := Fault.Error OR NOT PowerContactorEngaged;

// PowerCutOff actif si bits 3..7 actifs (causes physiques)
PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;

ErrorOperatorComm     := instCauses[0].Active;
ErrorDriveComm        := instCauses[1].Active;
ErrorPhaseRotation    := instCauses[2].Active;
ErrorBrakeThermal     := instCauses[3].Active;
ErrorMecaB            := instCauses[4].Active;
ErrorMecaA            := instCauses[5].Active;
ErrorLimitSwitch      := instCauses[6].Active;
ErrorSensorIncoherent := instCauses[7].Active;

// 🛡️ Permis directionnels M3 (polarité fail-safe : TRUE = autorisé)
// TremiePermit : autorisé vers Trémie tant que la fin de course Trémie n'est pas atteinte.
TremiePermit := NOT LimitSwitchTremie;
// MaintenancePermit : autorisé vers Maintenance uniquement si la cible Maintenance est
// autorisée (Auth.MaintenanceM3TargetEnable) ET la fin de course Maintenance non atteinte.
MaintenancePermit := MaintenanceM3TargetEnable AND NOT LimitSwitchMaintenance;
{endregion}

END_FUNCTION_BLOCK
