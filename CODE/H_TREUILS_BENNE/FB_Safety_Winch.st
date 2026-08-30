(* =======================================================================
   🛡️ FB_Safety_Winch — Surveillance et sécurité d'un treuil (M1 / M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Protection machine, surveillance codeurs, dérives et interlocks
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔒 Sécurité : Gestion des autorisations SafeStop, PowerCutOff et permis
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Safety_Winch
VAR_INPUT
    // === COMMANDES ET ETATS GENERAL ===
    Enable                          : BOOL;                           // --> [CMD] Active la surveillance globale FB
    Reset                           : BOOL;                           // --> [CMD] Front acquittement defauts
    Mode                            : E_Mode;                         // --> [CMD] Mode d'exploitation actif
    SyncEnable                      : BOOL;                           // --> [CMD] Validation synchronisation treuils
    Direction                       : INT;                            // --> [CMD] Consigne active de direction (-1/0/+1)
    MovementCommanded               : BOOL;                           // --> [CMD] Au moins un contacteur de sens commande

    // === ETATS SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Chaine AU rearmee + puissance OK
    JoystickOnline                  : BOOL;                           // --> [HW] Statut bus CAN Joystick Online
    JoystickOperational             : BOOL;                           // --> [HW] Statut bus CAN Joystick Operational
    HeartbeatIhmOk                  : BOOL;                           // --> [HW] Communication IHM-PLC valide
    EncoderAvailable                : BOOL;                           // --> [HW] Codeur disponible pour ce treuil
    ThermalFeedback                 : BOOL;                           // --> [HW] Retour thermique moteur (NC)
    BrakeThermalFeedback            : BOOL;                           // --> [HW] Retour thermique frein (NC)
    SlackCableDetected              : BOOL;                           // --> [HW] Delecteur mou de cable (NC)
    PhaseRotationOk                 : BOOL;                           // --> [HW] Sens de rotation des phases OK
    TopPositionSensor               : BOOL;                           // --> [HW] Capteur fin de course haut (NC)
    FwdRevSpeedFeedbackOff          : BOOL;                           // --> [HW] Feedback retombe tous contacteurs
    BrakeFeedback                   : BOOL;                           // --> [HW] Feedback frein ouvert
    JoystickYNeutral                : BOOL;                           // --> [HW] Joystick au neutre
    BenneHoldStillActive            : BOOL;                           // --> [HW] Maintien fixe M1 actif pendant benne
    BenneBusy                       : BOOL;                           // --> [HW] Cycle benne actif sur l'autre treuil
    OtherWinchInhibited             : BOOL;                           // --> [HW] Autre treuil inhibe (maintenance)

    // === REGLAGES ET LIMITES SÉCURITÉ ===
    InReferencingMode               : BOOL;                           // --> [CFG] Treuil en cours de homing
    CablePosM                       : REAL;                           // --> [CFG] Position actuelle cable (m)
    CfgCableLimitDescentM           : REAL;                           // --> [CFG] Limite basse physique descente (m)
    LimitLegalReached               : BOOL;                           // --> [CFG] Limite legale de profondeur atteinte
    Homed                           : BOOL;                           // --> [CFG] Treuil reference
    HomingSuspect                   : BOOL;                           // --> [CFG] Referencement suspect
    TopLimitM                       : REAL;                           // --> [CFG] Position limite haute active (m)
    UncommandedSpeedThresholdMps    : REAL := 0.02;                   // --> [CFG] Seuil vitesse non commandee Meca A (m/s)
    UncommandedDriftToleranceM      : REAL := 2.0;                    // --> [CFG] Tolerance derive position Meca A (m)
    PostRampTimeout                 : TIME := T#3s;                   // --> [CFG] Delai attente retombee contacteurs/frein Meca B
    BenneSlipToleranceM             : REAL := 2.0;                    // --> [CFG] Tolerance glissement M1 pendant benne (m)
    ExpectedOtherWinchPosM          : REAL;                           // --> [CFG] Position attendue de l'autre treuil (m)
    CriticalSyncToleranceM          : REAL := 2.5;                    // --> [CFG] Tolerance ecart critique synchro (m)
    MovementSpeedThresholdMps       : REAL := 0.02;                   // --> [CFG] Seuil vitesse mesurable (m/s)
    MeasuredSpeedMps                : REAL;                           // --> [CFG] Mesure absolue vitesse (m/s)
    MeasuredSpeedSignedMps          : REAL;                           // --> [CFG] Mesure signee vitesse (m/s)
    MeasuredSpeedValid              : BOOL;                           // --> [CFG] Mesure vitesse valide
    OppositeDirectionTimeout        : TIME := T#500ms;                // --> [CFG] Delai confirmation sens oppose
    NoMovementTimeout               : TIME := T#3s;                   // --> [CFG] Delai confirmation absence mouvement

    // === BYPASSES ET SIMULATION ===
    EncoderFaultBypass              : BOOL;                           // --> [TST] Bypass defaut codeur
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Force ErrorId=0 global
    BypassSafety                    : BOOL := FALSE;                  // --> [TST] Bypass groupe PowerCutOff
    BypassProcess                   : BOOL := FALSE;                  // --> [TST] Bypass groupe SafeStop/Permit
    BypassTopLimitSwitch            : BOOL := FALSE;                  // --> [TST] Bypass individuel fin de course haut capteur
    BypassTopLimitSoftware          : BOOL := FALSE;                  // --> [TST] Bypass individuel fin de course haut logiciel
    BypassCableLimitSwitch          : BOOL := FALSE;                  // --> [TST] Bypass individuel limite basse cable
    BypassLimitLegal                : BOOL := FALSE;                  // --> [TST] Bypass individuel limite legale
    BypassOperatorComm              : BOOL := FALSE;                  // --> [TST] Bypass perte com operateur
    BypassPhaseRotation             : BOOL := FALSE;                  // --> [TST] Bypass defaut rotation phases
    BypassBrakeThermal              : BOOL := FALSE;                  // --> [TST] Bypass surchauffe frein
    BypassMotorThermal              : BOOL := FALSE;                  // --> [TST] Bypass surchauffe moteur
    BypassMecaA                     : BOOL := FALSE;                  // --> [TST] Bypass Meca A
    BypassMecaB                     : BOOL := FALSE;                  // --> [TST] Bypass Meca B
    BypassMecaC                     : BOOL := FALSE;                  // --> [TST] Bypass Meca C
    BypassMecaD                     : BOOL := FALSE;                  // --> [TST] Bypass Meca D
    BypassMecaE                     : BOOL := FALSE;                  // --> [TST] Bypass Meca E
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                           : ST_Fault;

    // === SORTIES DE SÉCURITÉ ET AUTORISATIONS ===
    SafeStop                        : BOOL;                           // <-- [SAFE] Arret rapide 2 sens (Enable maintenu)
    DescendPermit                   : BOOL;                           // <-- [SAFE] Permis de descente autorise
    AscentPermit                    : BOOL;                           // <-- [SAFE] Permis de montee autorise
    PowerCutOff                     : BOOL;                           // <-- [SAFE] Coupure puissance amont

    // === DIAGNOSTICS ET MESURES ===
    MecaADriftM                     : REAL;                           // <-- [DIAG] Derive mesuree Meca A (m)
    MecaCDriftM                     : REAL;                           // <-- [DIAG] Derive mesuree Meca C (m)
    MecaBElapsedTime                : TIME;                           // <-- [DIAG] Ecoule confirmation contacteurs/frein
    ContactorStuck                  : BOOL;                           // <-- [DIAG] Contacteur colle (proprietaire unique, re-alimente IHM/Troubleshooting a la phase suivante)
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    DriftGuardA                     : FB_DriftGuard;                  // * [INST] Surveillance derive Meca A
    DriftGuardC                     : FB_DriftGuard;                  // * [INST] Surveillance derive Meca C
    ResetEdge                       : R_TRIG;                         // . [LOC] Front Reset

    // === TIMERS INTERNES ===
    TonMecaB                        : TON;                            // . [LOC] Delai confirmation arret contacteurs/frein
    TonMecaD                        : TON;                            // . [LOC] Delai confirmation arret fin de course haut
    TonMecaE                        : TON;                            // . [LOC] Delai confirmation arret ecart synchro
    TonOppositeDirection            : TON;                            // . [LOC] Delai confirmation sens oppose
    TonNoMovement                   : TON;                            // . [LOC] Delai confirmation absence mouvement
    TonStartupWarmup                : TON;                            // . [LOC] Inhibition transitoire boot (3s)

    // === VARIABLES LOCALES CALCULÉES ===
    UncommandedActiveB              : BOOL;                           // . [LOC] Condition active Meca B
    UncommandedActiveD              : BOOL;                           // . [LOC] Condition active Meca D
    OppositeDirectionActive         : BOOL;                           // . [LOC] Condition active sens oppose
    FirstScanDone                   : BOOL;                           // . [LOC] Initialisation premier scan

    // Latches défauts
    EncoderFaultLatched             : BOOL;
    MotorThermalFaultLatched        : BOOL;
    PhaseRotationFaultLatched       : BOOL;
    MecaAFaultLatched               : BOOL;
    MecaBFaultLatched               : BOOL;
    MecaCFaultLatched               : BOOL;
    BrakeThermalFaultLatched        : BOOL;
    MecaDFaultLatched               : BOOL;
    MecaEFaultLatched               : BOOL;
    MecaEEscaladeFaultLatched       : BOOL;
    OppositeDirectionFaultLatched   : BOOL;
    NoMovementFaultLatched          : BOOL;

    // Socle défaut
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS & REARMENT
ResetEdge(CLK := Reset);

IF ResetEdge.Q OR BypassGlobal THEN
    EncoderFaultLatched           := FALSE;
    MotorThermalFaultLatched      := FALSE;
    PhaseRotationFaultLatched     := FALSE;
    MecaAFaultLatched             := FALSE;
    MecaBFaultLatched             := FALSE;
    MecaCFaultLatched             := FALSE;
    BrakeThermalFaultLatched      := FALSE;
    MecaDFaultLatched             := FALSE;
    MecaEFaultLatched             := FALSE;
    MecaEEscaladeFaultLatched     := FALSE;
    OppositeDirectionFaultLatched := FALSE;
    NoMovementFaultLatched        := FALSE;
END_IF;

IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    EncoderFaultLatched           := FALSE;
    MotorThermalFaultLatched      := FALSE;
    PhaseRotationFaultLatched     := FALSE;
    MecaAFaultLatched             := FALSE;
    MecaBFaultLatched             := FALSE;
    MecaCFaultLatched             := FALSE;
    BrakeThermalFaultLatched      := FALSE;
    MecaDFaultLatched             := FALSE;
    MecaEFaultLatched             := FALSE;
    MecaEEscaladeFaultLatched     := FALSE;
    OppositeDirectionFaultLatched := FALSE;
    NoMovementFaultLatched        := FALSE;
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
    instCauses[0].Texte    := 'Perte communication operateur treuil';

    // Cause 1 : Perte codeur (latched)
    IF NOT (BypassProcess OR EncoderFaultBypass) AND NOT EncoderAvailable THEN
        EncoderFaultLatched := TRUE;
    END_IF;
    instCauses[1].Active   := EncoderFaultLatched;
    instCauses[1].Latching := TRUE;
    instCauses[1].Texte    := 'Perte ou defaut codeur treuil';

    // Cause 2 : Surchauffe thermique moteur (latched)
    IF NOT (BypassSafety OR BypassMotorThermal) AND ThermalFeedback THEN
        MotorThermalFaultLatched := TRUE;
    END_IF;
    instCauses[2].Active   := MotorThermalFaultLatched;
    instCauses[2].Latching := TRUE;
    instCauses[2].Texte    := 'Surchauffe thermique moteur treuil';

    // Cause 3 : Mou de câble (live / auto-effaçable)
    IF NOT BypassProcess AND SlackCableDetected THEN
        instCauses[3].Active := TRUE;
    ELSE
        instCauses[3].Active := FALSE;
    END_IF;
    instCauses[3].Latching := FALSE;
    instCauses[3].Texte    := 'Detection mou de cable treuil';

    // Cause 4 : Rotation phases (latched)
    IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
        PhaseRotationFaultLatched := TRUE;
    END_IF;
    instCauses[4].Active   := PhaseRotationFaultLatched;
    instCauses[4].Latching := TRUE;
    instCauses[4].Texte    := 'Defaut rotation de phases treuil';

    // Cause 5 : Fin de course haut capteur (live)
    IF NOT (BypassProcess OR BypassTopLimitSwitch) AND (NOT TopPositionSensor AND NOT InReferencingMode) THEN
        instCauses[5].Active := TRUE;
    ELSE
        instCauses[5].Active := FALSE;
    END_IF;
    instCauses[5].Latching := FALSE;
    instCauses[5].Texte    := 'Fin de course haut capteur atteint';

    // Cause 6 : Limite max câble descente (live)
    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND ((CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode) THEN
        instCauses[6].Active := TRUE;
    ELSE
        instCauses[6].Active := FALSE;
    END_IF;
    instCauses[6].Latching := FALSE;
    instCauses[6].Texte    := 'Limite basse cable atteinte';

    // Cause 7 : Méca A dérive à l'arrêt (latched)
    DriftGuardA(
        Arm        := NOT (BypassSafety OR BypassMecaA) AND JoystickYNeutral AND NOT BenneHoldStillActive,
        PositionM  := CablePosM,
        ToleranceM := UncommandedDriftToleranceM
    );
    MecaADriftM := DriftGuardA.DriftM;
    IF DriftGuardA.Violation THEN MecaAFaultLatched := TRUE; END_IF;
    instCauses[7].Active   := MecaAFaultLatched;
    instCauses[7].Latching := TRUE;
    instCauses[7].Texte    := 'Derive non commandee treuil (Meca A)';

    // Cause 8 : Méca B absence confirmation arrêt (latched)
    IF NOT (BypassSafety OR BypassMecaB) THEN
        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
        TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
        IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;
    ELSE
        TonMecaB(IN := FALSE);
    END_IF;
    MecaBElapsedTime := TonMecaB.ET;
    instCauses[8].Active   := MecaBFaultLatched;
    instCauses[8].Latching := TRUE;
    instCauses[8].Texte    := 'Absence confirmation arret contacteurs/frein (Meca B)';

    // Cause 9 : Méca C glissement benne (latched)
    DriftGuardC(
        Arm        := NOT (BypassSafety OR BypassMecaC) AND BenneHoldStillActive,
        PositionM  := CablePosM,
        ToleranceM := BenneSlipToleranceM
    );
    MecaCDriftM := DriftGuardC.DriftM;
    IF DriftGuardC.Violation THEN MecaCFaultLatched := TRUE; END_IF;
    instCauses[9].Active   := MecaCFaultLatched;
    instCauses[9].Latching := TRUE;
    instCauses[9].Texte    := 'Glissement treuil pendant cycle benne (Meca C)';

    // Cause 10 : Surchauffe thermique frein (latched)
    IF NOT (BypassSafety OR BypassBrakeThermal) AND BrakeThermalFeedback THEN
        BrakeThermalFaultLatched := TRUE;
    END_IF;
    instCauses[10].Active   := BrakeThermalFaultLatched;
    instCauses[10].Latching := TRUE;
    instCauses[10].Texte    := 'Surchauffe thermique frein treuil';

    // Cause 11 : Méca D escalade capteur haut (latched)
    IF NOT (BypassSafety OR BypassMecaD) THEN
        UncommandedActiveD := NOT TopPositionSensor AND NOT InReferencingMode AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
        TonMecaD(IN := UncommandedActiveD, PT := PostRampTimeout);
        IF TonMecaD.Q THEN MecaDFaultLatched := TRUE; END_IF;
    ELSE
        TonMecaD(IN := FALSE);
    END_IF;
    instCauses[11].Active   := MecaDFaultLatched;
    instCauses[11].Latching := TRUE;
    instCauses[11].Texte    := 'Escalade fin de course haut (Meca D)';

    // Cause 12 & 13 : Méca E écart critique synchro & escalade (latched)
    IF NOT (BypassProcess OR BypassMecaE) AND SyncEnable AND NOT BenneBusy AND NOT InReferencingMode AND NOT OtherWinchInhibited
       AND (ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM) THEN
        MecaEFaultLatched := TRUE;
    END_IF;
    instCauses[12].Active   := MecaEFaultLatched;
    instCauses[12].Latching := TRUE;
    instCauses[12].Texte    := 'Ecart critique synchronisation treuil (Meca E)';

    TonMecaE(
        IN := NOT (BypassSafety OR BypassMecaE) AND MecaEFaultLatched AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback),
        PT := PostRampTimeout
    );
    IF TonMecaE.Q THEN MecaEEscaladeFaultLatched := TRUE; END_IF;
    instCauses[13].Active   := MecaEEscaladeFaultLatched;
    instCauses[13].Latching := TRUE;
    instCauses[13].Texte    := 'Escalade ecart synchronisation (Meca E)';

    // Cause 14 : Sens opposé (latched)
    OppositeDirectionActive := NOT BypassProcess AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
        AND (((Direction > 0) AND (MeasuredSpeedSignedMps < -MovementSpeedThresholdMps))
          OR ((Direction < 0) AND (MeasuredSpeedSignedMps > MovementSpeedThresholdMps))));
    TonOppositeDirection(IN := OppositeDirectionActive, PT := OppositeDirectionTimeout);
    IF TonOppositeDirection.Q THEN OppositeDirectionFaultLatched := TRUE; END_IF;
    instCauses[14].Active   := OppositeDirectionFaultLatched;
    instCauses[14].Latching := TRUE;
    instCauses[14].Texte    := 'Sens reel oppose a la commande treuil';

    // Cause 15 : Absence mouvement (latched)
    TonNoMovement(
        IN := NOT BypassProcess AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
              AND (ABS(MeasuredSpeedSignedMps) < MovementSpeedThresholdMps)),
        PT := NoMovementTimeout
    );
    IF TonNoMovement.Q THEN NoMovementFaultLatched := TRUE; END_IF;
    instCauses[15].Active   := NoMovementFaultLatched;
    instCauses[15].Latching := TRUE;
    instCauses[15].Texte    := 'Absence mouvement malgre commande treuil';

ELSE
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonMecaE(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonNoMovement(IN := FALSE);
END_IF;

// ContactorStuck : proprietaire UNIQUE de la detection contacteur colle.
// Escalade : Meca B (bit8) -> SafeStop + PowerCutOff apres PostRampTimeout si le
// collage persiste. Le champ ContactorsCheck.StuckClosed de FB_Winch est force a
// FALSE (Phase 0) ; la re-alimentation IHM/Troubleshooting se fera depuis cette sortie.
ContactorStuck := MecaBFaultLatched;

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable THEN
    SafeStop := FALSE;
    DescendPermit := FALSE;
    AscentPermit := FALSE;
    PowerCutOff := FALSE;
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonMecaE(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonNoMovement(IN := FALSE);
    TonStartupWarmup(IN := FALSE);
    MecaBElapsedTime := T#0s;
    Ready := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Arbitrage sorties securite"}
// 📤 3. ARBITRAGE SÉCURITÉ
IF NOT PowerContactorEngaged THEN
    SafeStop := TRUE;
ELSIF NOT SyncEnable THEN
    SafeStop := (Fault.ErrorId AND 16#FF97) <> 16#0000;
ELSE
    SafeStop := (Fault.ErrorId AND 16#FF9F) <> 16#0000;
END_IF;

DescendPermit := NOT (
    (((Fault.ErrorId AND 16#0040) <> 16#0000 OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
    OR (((CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode) AND NOT BypassCableLimitSwitch)
    OR (LimitLegalReached AND NOT (BypassProcess OR BypassLimitLegal))
    OR (((Fault.ErrorId AND 16#0008) <> 16#0000 AND NOT SyncEnable) AND NOT (BypassProcess OR BypassGlobal))
);

AscentPermit := NOT (
    (((Fault.ErrorId AND 16#0020) <> 16#0000
    OR (NOT TopPositionSensor AND NOT InReferencingMode))
    AND NOT BypassTopLimitSwitch)
    // TopLimitM porte deja la relaxation 7,5->8,5 m (override N1 / bypass N2, bornee par la
    // bande de ralentissement, PRG_04 TopLimitM1_M/TopLimitM2_M) : la butee logicielle reste
    // active a la valeur relevee. Bypasser le logiciel releve la butee, il ne la supprime pas.
    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM))
);

PowerCutOff := (Fault.ErrorId AND 16#2F84) <> 16#0000;
{endregion}

END_FUNCTION_BLOCK
