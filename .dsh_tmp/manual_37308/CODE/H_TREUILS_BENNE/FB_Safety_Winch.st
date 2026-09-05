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
    SyncEnable                      : BOOL;                           // --> [CMD] Validation synchronisation treuils (routage mou-de-cable :508/:520)
    CrossCheckEnable                : BOOL := TRUE;                    // --> [CMD] Autorise le controle d'ecart critique croise M1/M2 (Meca E) : treuils reellement solidaires ET hors jog benne unitaire
    ReqAscent                       : BOOL;                           // --> [CMD] Commande active montée
    ReqDescend                      : BOOL;                           // --> [CMD] Commande active descente
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
    UncommandedDriftToleranceM      : REAL := 5.0;                    // --> [CFG] Tolerance derive position Meca A (m) - MES 2026-09-04 : 2.0 -> 5.0 (confirme operateur)
    PostRampTimeout                 : TIME := T#3s;                   // --> [CFG] Delai attente retombee contacteurs/frein Meca B
    BenneSlipToleranceM             : REAL := 2.0;                    // --> [CFG] Tolerance glissement M1 pendant benne (m)
    ExpectedOtherWinchPosM          : REAL;                           // --> [CFG] Position attendue de l'autre treuil (m)
    CriticalSyncToleranceM          : REAL := 2.5;                    // --> [CFG] Tolerance ecart critique synchro (m)
    MovementSpeedThresholdMps       : REAL := 0.10;                   // --> [CFG] Seuil vitesse mesurable (m/s)
    MeasuredSpeedMps                : REAL;                           // --> [CFG] Mesure absolue vitesse (m/s)
    MeasuredSpeedSignedMps          : REAL;                           // --> [CFG] Mesure signee vitesse (m/s)
    MeasuredSpeedValid              : BOOL;                           // --> [CFG] Mesure vitesse valide
    SpeedBandMaxMps                 : REAL;                           // --> [CFG] Seuil survitesse (max bande apprise , m/s)
    OppositeDirectionTimeout        : TIME := T#1s;                   // --> [CFG] Delai confirmation sens oppose
    NoMovementTimeout               : TIME := T#3s;                   // --> [CFG] Delai confirmation absence mouvement

    // === ESCALADE EXTERNE ===
    ExternalSyncEscalation          : BOOL := FALSE;                  // --> [SAFE] Discordance contacteurs M1/M2 persistante (FB_SyncContactor niveau 2) -> latch MecaE escalade (bit13 -> PowerCutOff), meme routing/Reset/bypass que MecaE

    // === BYPASSES ET SIMULATION ===
    EncoderFaultBypass              : BOOL;                           // --> [TST] Bypass defaut codeur
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Inhibe l'evaluation des causes + RAZ latches ; ne force pas ErrorId=0 (causes live deja posees restent visibles)
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
    OverspeedFault                  : BOOL;                           // <-- [DIAG] Survitesse latchée (acquittée au Reset)
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
    TonRefSettle                    : TON;                            // . [LOC] Garde de stabilisation apres referencement/benne (saut de position codeur)

    // === VARIABLES LOCALES CALCULÉES ===
    RefWindowActive                 : BOOL;                           // . [LOC] Fenetre de reference active : gardes derive/synchro re-basees (preset codeur = saut CablePosM)
    WinchStandstill                 : BOOL;                           // . [LOC] Treuil physiquement a l'arret : contacteurs retombes + frein serre + joystick neutre + aucun ordre + vitesse ~0 -> aucun emballement possible
    PosStepDetected                 : BOOL;                           // . [LOC] Saut de position non physique detecte ce scan (preset codeur, ce treuil ou l'autre)
    CablePosMPrev                   : REAL;                           // . [LOC] CablePosM scan precedent (detection de saut)
    ExpectedOtherWinchPosMPrev      : REAL;                           // . [LOC] ExpectedOtherWinchPosM scan precedent (detection de saut de l'autre treuil)
    UncommandedActiveB              : BOOL;                           // . [LOC] Condition active Meca B
    UncommandedActiveD              : BOOL;                           // . [LOC] Condition active Meca D
    OppositeDirectionActive         : BOOL;                           // . [LOC] Condition active sens oppose
    FirstScanDone                   : BOOL;                           // . [LOC] Initialisation premier scan

    // === MIROIRS LISIBLES DES CAUSES (bits ErrorId, source instCauses[i].Active) ===
    // Interlocks §3 : toujours sur la cause brute, jamais sur la vue Latched (AF03 §4).
    CauseOperatorCommActive         : BOOL;                           // . [LOC] bit0  Perte com operateur (live)
    CauseEncoderActive              : BOOL;                           // . [LOC] bit1  Perte codeur (latched)
    CauseMotorThermalActive         : BOOL;                           // . [LOC] bit2  Surchauffe moteur (latched)
    CauseSlackCableActive           : BOOL;                           // . [LOC] bit3  Mou de cable (live)
    CausePhaseRotationActive        : BOOL;                           // . [LOC] bit4  Rotation phases (latched)
    CauseTopLimitSwitchActive       : BOOL;                           // . [LOC] bit5  Fin de course haut capteur (live)
    CauseCableLimitActive           : BOOL;                           // . [LOC] bit6  Limite basse cable descente (live)
    CauseMecaAActive                : BOOL;                           // . [LOC] bit7  Derive non commandee (latched)
    CauseMecaBActive                : BOOL;                           // . [LOC] bit8  Absence confirmation arret (latched)
    CauseMecaCActive                : BOOL;                           // . [LOC] bit9  Glissement pendant benne (latched)
    CauseBrakeThermalActive         : BOOL;                           // . [LOC] bit10 Surchauffe frein (latched)
    CauseMecaDActive                : BOOL;                           // . [LOC] bit11 Escalade fin de course haut (latched)
    CauseMecaEActive                : BOOL;                           // . [LOC] bit12 Ecart critique synchro (latched)
    CauseMecaEEscaladeActive        : BOOL;                           // . [LOC] bit13 Escalade ecart synchro (latched)
    CauseOppositeDirActive          : BOOL;                           // . [LOC] bit14 Sens reel oppose (latched)
    CauseNoMovementActive           : BOOL;                           // . [LOC] bit15 Absence mouvement (latched)
    CausesSafeStopActive            : BOOL;                           // . [LOC] Causes non directionnelles -> SafeStop
    CausesPowerCutOffActive         : BOOL;                           // . [LOC] Causes critiques -> PowerCutOff

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
    OverspeedFaultLatched           : BOOL;                           // . [LOC] Latch survitesse (hors bitfield)

    // Socle défaut
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
    CauseIdx                        : INT;                            // . [LOC] Index de boucle — purge des causes vives sous BypassGlobal
END_VAR
VAR CONSTANT
    CST_RefPosStepM                 : REAL := 0.5;                    // Saut de position (m/scan) au-dela duquel la variation n'est pas physique (preset codeur) — la course reelle d'un treuil par scan 10ms reste sous ~0.01 m
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
    OverspeedFaultLatched         := FALSE;
END_IF;

IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    CablePosMPrev                 := CablePosM;
    ExpectedOtherWinchPosMPrev   := ExpectedOtherWinchPosM;
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
    OverspeedFaultLatched         := FALSE;
END_IF;

IF NOT BypassGlobal THEN
    TonStartupWarmup(IN := Enable, PT := T#3s);

    // 🛡️ Fenetre de reference : le preset SDO du codeur (homing, y compris reference benne fermee)
    // fait sauter CablePosM d'un bloc. Sans garde, DriftGuardA voit une derive non commandee (Meca A)
    // et l'ecart M1/M2 depasse la tolerance (Meca E). Le Busy homing seul est trop court (~500ms) :
    // il retombe avant l'application reelle du preset et la reconvergence M1/M2. On maintient donc
    // l'inhibition pendant homing + cycle benne + saut de position detecte + 2s de stabilisation,
    // et on RAZ les latches parasites poses dans le meme scan. Le saut sur ExpectedOtherWinchPosM
    // couvre le cas ou c'est l'AUTRE treuil qui est reference (ce treuil n'est pas en homing).
    // Les autres protections (limites, contacteurs, chaine) restent actives (AF_Partie-09 §13 :
    // le treuil ne passe pas en mode securite degrade, le homing exige l'arret confirme des treuils).
    PosStepDetected := (ABS(CablePosM - CablePosMPrev) > CST_RefPosStepM)
                    OR (ABS(ExpectedOtherWinchPosM - ExpectedOtherWinchPosMPrev) > CST_RefPosStepM);
    CablePosMPrev := CablePosM;
    ExpectedOtherWinchPosMPrev := ExpectedOtherWinchPosM;
    // NOT CrossCheckEnable : homing machine, manipulation benne, pilotage unitaire ->
    // l'ecart croise M1/M2 est volontairement grand ; la fenetre de reference reste
    // ouverte (RAZ continue des latch Meca A/E) tant que le controle croise est coupe.
    TonRefSettle(IN := NOT (InReferencingMode OR BenneBusy OR PosStepDetected OR NOT CrossCheckEnable), PT := T#2s);
    RefWindowActive := InReferencingMode OR BenneBusy OR PosStepDetected OR NOT TonRefSettle.Q
                       OR NOT CrossCheckEnable;
    IF RefWindowActive THEN
        MecaAFaultLatched         := FALSE;
        MecaEFaultLatched         := FALSE;
        MecaEEscaladeFaultLatched := FALSE;
    END_IF;

    // Treuil physiquement a l'arret : contacteurs retombes, frein serre, joystick neutre,
    // aucun ordre de sens, vitesse mesuree quasi nulle. Dans cet etat, l'ecart croise M1/M2
    // est une lecture geometrique statique (benne posee a un Delta quelconque), PAS un
    // emballement -> on n'ARME pas le latch Meca E (l'operateur doit pouvoir acquitter par
    // Reset sans que le defaut se re-pose au scan suivant). La protection redevient vive
    // des qu'un contacteur de sens est commande. Aucun redemarrage auto : latch deja pose
    // reste pose jusqu'au Reset explicite.
    WinchStandstill := FwdRevSpeedFeedbackOff AND NOT BrakeFeedback
                       AND JoystickYNeutral AND NOT MovementCommanded
                       AND (NOT MeasuredSpeedValid OR (ABS(MeasuredSpeedMps) < 0.05));

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
    IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
        instCauses[6].Active := TRUE;
    ELSE
        instCauses[6].Active := FALSE;
    END_IF;
    instCauses[6].Latching := FALSE;
    instCauses[6].Texte    := 'Limite basse cable atteinte';

    // Cause 7 : Méca A dérive à l'arrêt (latched)
    DriftGuardA(
        Arm        := NOT (BypassSafety OR BypassMecaA) AND FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND NOT BenneHoldStillActive AND NOT RefWindowActive,
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

    // Cause 12 & 13 : Méca E écart critique synchro & escalade (latched).
    // CrossCheckEnable (et non SyncEnable) : le controle d'ecart croise M1/M2 n'a de sens
    // que treuils solidaires ; en jog benne unitaire (M2-M1 varie de ~15 m volontairement)
    // il est inhibe. TonMecaE (:362) ne s'escalade que si MecaEFaultLatched est pose ici,
    // donc gater ce seul point suffit. Le mou-de-cable (:508/:520) reste sur SyncEnable.
    IF Enable AND NOT (BypassProcess OR BypassMecaE) AND CrossCheckEnable AND NOT RefWindowActive AND NOT OtherWinchInhibited
       AND NOT WinchStandstill
       AND (ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM) THEN
        MecaEFaultLatched := TRUE;
    END_IF;
    instCauses[12].Active   := MecaEFaultLatched;
    instCauses[12].Latching := TRUE;
    instCauses[12].Texte    := 'Ecart critique synchronisation treuil (Meca E)';

    TonMecaE(
        IN := NOT (BypassSafety OR BypassMecaE) AND NOT RefWindowActive AND MecaEFaultLatched AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback),
        PT := PostRampTimeout
    );
    IF TonMecaE.Q THEN MecaEEscaladeFaultLatched := TRUE; END_IF;
    // Escalade discordance contacteurs M1/M2 (deja debouncee + tempo escalade
    //   dans FB_SyncContactor, PRG_06) -> meme latch que MecaE escalade (bit13 -> PowerCutOff).
    //   Meme neutralisation que MecaE : BypassSafety / BypassMecaE. Efface par le meme Reset.
    IF ExternalSyncEscalation AND NOT (BypassSafety OR BypassMecaE) THEN
        MecaEEscaladeFaultLatched := TRUE;
    END_IF;
    instCauses[13].Active   := MecaEEscaladeFaultLatched;
    instCauses[13].Latching := TRUE;
    instCauses[13].Texte    := 'Escalade ecart synchronisation (Meca E)';

    // Cause 14 : Sens opposé (latched)
    // Convention de signe SignedSpeed_Mps confirmee machine reelle (MES 2026-09-05,
    // DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md) : + montee (enroulement cable),
    // - descente (deroulement cable).
    OppositeDirectionActive := NOT BypassProcess AND NOT RefWindowActive AND NOT BenneBusy AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
        AND ((ReqAscent AND (MeasuredSpeedSignedMps < -MovementSpeedThresholdMps))
          OR (ReqDescend AND (MeasuredSpeedSignedMps > MovementSpeedThresholdMps))));
    TonOppositeDirection(IN := OppositeDirectionActive, PT := OppositeDirectionTimeout);
    IF TonOppositeDirection.Q THEN OppositeDirectionFaultLatched := TRUE; END_IF;
    instCauses[14].Active   := OppositeDirectionFaultLatched;
    instCauses[14].Latching := TRUE;
    instCauses[14].Texte    := 'Sens reel oppose a la commande treuil';

    // Cause 15 : Absence mouvement (latched)
    TonNoMovement(
        IN := NOT BypassProcess AND NOT RefWindowActive AND NOT BenneBusy AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
              AND (ABS(MeasuredSpeedSignedMps) < MovementSpeedThresholdMps)),
        PT := NoMovementTimeout
    );
    IF TonNoMovement.Q THEN NoMovementFaultLatched := TRUE; END_IF;
    instCauses[15].Active   := NoMovementFaultLatched;
    instCauses[15].Latching := TRUE;
    instCauses[15].Texte    := 'Absence mouvement malgre commande treuil';

    // Survitesse (latch dédié hors bitfield —, alternative validée).
    // Seuil = max bande apprise  (SpeedBandMaxMps). Latché jusqu'au Reset.
    // ⚠️ N'alimente PAS PowerCutOff : couper la puissance en survitesse peut
    // provoquer une chute libre de la charge — décision à trancher (ISO 13849).
    IF NOT BypassProcess AND NOT RefWindowActive AND MeasuredSpeedValid AND (ABS(MeasuredSpeedMps) > SpeedBandMaxMps) THEN
        OverspeedFaultLatched := TRUE;
    END_IF;

ELSE
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonMecaE(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonNoMovement(IN := FALSE);
    TonRefSettle(IN := FALSE);
    RefWindowActive := FALSE;
    PosStepDetected := FALSE;
    CablePosMPrev := CablePosM;
    ExpectedOtherWinchPosMPrev := ExpectedOtherWinchPosM;

    // 🧪 BypassGlobal : l'évaluation des causes ci-dessus est sautée. Sans cette purge,
    // instCauses[i].Active resterait FIGÉ à sa dernière valeur (bug : PowerCutOff / SafeStop
    // gelés à TRUE, réarmement impossible malgré le bypass). Les latches sont déjà effacés
    // au § FRONTS & REARMENT (IF ResetEdge.Q OR BypassGlobal). Ici on force la vue LIVE à
    // « pas de cause » pour que CauseXxxActive / CausesPowerCutOffActive / CausesSafeStopActive
    // retombent et que la sortie PowerCutOff/SafeStop puisse se lever.
    FOR CauseIdx := 0 TO 15 DO
        instCauses[CauseIdx].Active := FALSE;
    END_FOR;
END_IF;

// ContactorStuck : proprietaire UNIQUE de la detection contacteur colle.
// Escalade : Meca B (bit8) -> SafeStop + PowerCutOff apres PostRampTimeout si le
// collage persiste. Le champ ContactorsCheck.StuckClosed de FB_Winch est force a
// FALSE (Phase 0) ; la re-alimentation IHM/Troubleshooting se fera depuis cette sortie.
ContactorStuck := MecaBFaultLatched;
OverspeedFault := OverspeedFaultLatched;

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

// Miroirs des causes : exactement les bits de la vue LIVE ErrorId (le socle pose
// ErrorId bit i = Causes[i].Active quand Enable). §2 fait RETURN si Enable=FALSE,
// ces miroirs ne servent qu'en aval, sous Enable.
CauseOperatorCommActive   := instCauses[0].Active;
CauseEncoderActive        := instCauses[1].Active;
CauseMotorThermalActive   := instCauses[2].Active;
CauseSlackCableActive     := instCauses[3].Active;
CausePhaseRotationActive  := instCauses[4].Active;
CauseTopLimitSwitchActive := instCauses[5].Active;
CauseCableLimitActive     := instCauses[6].Active;
CauseMecaAActive          := instCauses[7].Active;
CauseMecaBActive          := instCauses[8].Active;
CauseMecaCActive          := instCauses[9].Active;
CauseBrakeThermalActive   := instCauses[10].Active;
CauseMecaDActive          := instCauses[11].Active;
CauseMecaEActive          := instCauses[12].Active;
CauseMecaEEscaladeActive  := instCauses[13].Active;
CauseOppositeDirActive    := instCauses[14].Active;
CauseNoMovementActive     := instCauses[15].Active;

// Agregats safety (causes homogenes, AF03 §4 — jamais de masque hexa) :
// CausesSafeStop : toutes les causes sauf les 3 purement directionnelles
// (SlackCable bit3, TopLimitSwitch bit5, CableLimitDescent bit6), traitees
// par les permis de sens. CausesPowerCutOff : defauts a coupure immediate,
// SANS MecaE-ecart (bit12, laisse au SafeStop tant que non confirme).
CausesSafeStopActive := CauseOperatorCommActive OR CauseEncoderActive
    OR CauseMotorThermalActive OR CausePhaseRotationActive
    OR CauseMecaAActive OR CauseMecaBActive OR CauseMecaCActive
    OR CauseBrakeThermalActive OR CauseMecaDActive
    OR CauseMecaEActive OR CauseMecaEEscaladeActive
    OR CauseOppositeDirActive OR CauseNoMovementActive;

CausesPowerCutOffActive := CauseMotorThermalActive OR CauseMecaAActive
    OR CauseMecaBActive OR CauseMecaCActive OR CauseBrakeThermalActive
    OR CauseMecaDActive OR CauseMecaEEscaladeActive;
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
// Interlocks sur les miroirs de causes (bits ErrorId) — jamais de masque hexa.
IF NOT PowerContactorEngaged THEN
    SafeStop := TRUE;
ELSE
    // Causes non directionnelles + survitesse. Hors synchro (SyncEnable=FALSE),
    // le mou de cable (bit3) n'entraine pas SafeStop : il bloque la descente
    // seule via DescendPermit (retendre en montant reste possible).
    SafeStop := CausesSafeStopActive
                OR (SyncEnable AND CauseSlackCableActive)
                OR OverspeedFaultLatched;
END_IF;

DescendPermit := NOT (
    ((CauseCableLimitActive OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
    OR ((CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode AND NOT BypassCableLimitSwitch)
    // La limite légale est une interdiction d'exploitation distincte du groupe
    // SafeStop/Permit. Le bypass banc BypassProcess ne doit jamais la lever :
    // seul le bypass dédié BypassLimitLegal, déjà filtré par la matrice MAINT_N2
    // dans PRG_04, peut l'autoriser explicitement.
    OR (LimitLegalReached AND NOT BypassLimitLegal)
    OR ((CauseSlackCableActive AND NOT SyncEnable) AND NOT (BypassProcess OR BypassGlobal))
);

AscentPermit := NOT (
    ((CauseTopLimitSwitchActive
    OR (NOT TopPositionSensor AND NOT InReferencingMode))
    AND NOT BypassTopLimitSwitch)
    // TopLimitM porte la relaxation 7,5->8,5 m en override N1 / bypass N2 : la butee
    // logicielle reste active a la valeur relevee. Bypasser le logiciel releve la butee,
    // il ne la supprime pas ; le FDC haut materiel reste une barriere independante.
    OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM))
);

PowerCutOff := CausesPowerCutOffActive;
{endregion}

END_FUNCTION_BLOCK
