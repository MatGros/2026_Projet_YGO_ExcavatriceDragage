(* =======================================================================
   ⚙️ FB_Encoder_Homing — Référencement codeur nominal ou unitaire
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Séquence de référencement nominal (capteur haut) ou unitaire (MAINT_N2)
   🔒 Polarité : Homed=TRUE dès qu'un référencement valide est enregistré
   🔌 Architecture : Expose ST_Encoder_Calib en VAR_IN_OUT
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Homing) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Homing
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                 : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                  : BOOL;        // --> [CMD] Acquittement defaut (front montant)
    Home                   : BOOL;        // --> [CMD] Demande de referencement (front)
    HomingPermit           : BOOL;        // --> [CMD] Autorisation de homer (calculee par le caller)
    BtnConfirmCoherence    : BOOL;        // --> [CMD] Levee de doute d'incoherence au boot (front)

    // === CIBLES & CONFIGURATION HOMING ===
    CfgHomingTargetM       : REAL;        // --> [CFG] Cible libre homing unitaire (m)
    UseDynamicTarget       : BOOL := FALSE; // --> [CFG] Activation cible dynamique
    DynamicHomingTargetM   : REAL := 0.0; // --> [CFG] Cible dynamique de referencement (m)
    CfgTopSensorPosM       : REAL := 8.5; // --> [CFG] Cible homing nominal capteur haut (m)

    // === RETOURS HW & CAPTEURS ===
    TopPositionSensor      : BOOL;        // --> [HW]  Capteur physique position haute unique
    // === MESURES & RETOURS FB CODEUR ABSOLU ===
    RawPos                 : UDINT;       // --> [HW]  Position brute codeur (sortie FB_Encoder_Abs)
    EncoderAvailable       : BOOL;        // --> [HW]  Codeur absolu disponible et valide
    PresetStatusBit        : BOOL;        // --> [HW]  Bit d'etat preset optionnel, FALSE si non cable

    // === REGLAGES TRANSACTION PRESET ===
    Cfg                    : ST_fbEncoder_Cfg; // --> [CFG] Mode de confirmation preset

    // === CARACTERISTIQUES MECANIQUES & BUS ===
    PointsPerRev           : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    MultiTurnRevsMax       : UDINT := 4096; // --> [CFG] Capacite multitour max codeur (tours)
    CableM_PerRev          : REAL := 2.0;   // --> [CFG] Perimetre tambour / developpement cable (m/tour)

    // === TESTS & BYPASS ===
    BypassGlobal           : BOOL := FALSE; // --> [TST] Neutralisation securites pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                  : BOOL;        // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                  : ST_Fault;
    // 🧩 Cycle de vie (forme cible ST_Lifecycle)
    Lifecycle              : ST_Lifecycle;

    // === COMMANDES VERS FB_ENCODER_ABS ===
    PresetRequest          : BOOL;        // <-- [ACT]  Pulse demande d'ecriture preset SDO
    PresetValue            : UDINT;       // <-- [ACT]  Valeur de cible brute pour preset SDO

    // === RESULTATS & MEMOIRE CALIBRATION ===
    Homed                  : BOOL;        // <-- [STAT] Codeur pagine et referencie
    HomingSuspect          : BOOL;        // <-- [DIAG] Incoherence redemarrage a lever
    HomingRefRaw           : UDINT;       // <-- [DIAG] Offset de reference brut calcule
    PresetConfirmationFailed : BOOL;      // <-- [DIAG] Latch derniere verification preset echouee
END_VAR
VAR_IN_OUT
    // === STRUCTURE DE CALIBRATION PERSISTANTE ===
    Calib                  : ST_Encoder_Calib; // <-> [BUS] Structure de calibration RETAIN
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge              : R_TRIG;      // . [LOC] Detecteur front montant Reset
    HomeEdge               : R_TRIG;      // . [LOC] Detecteur front montant Home
    ConfirmCoherenceEdge   : R_TRIG;      // . [LOC] Detecteur front montant BtnConfirmCoherence
    TopSensorEdge          : R_TRIG;      // . [LOC] Detecteur front montant TopPositionSensor
    DynamicTargetEdge      : R_TRIG;      // . [LOC] Detecteur front montant UseDynamicTarget

    // === ETATS & DRAPEAUX INTERNES ===
    InitDone               : BOOL;        // . [LOC] Controle incoherence boot effectue
    HomingModeOk           : BOOL;        // . [LOC] Mode de fonctionnement valide pour homing
    NominalHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing nominal
    UnitaryHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing unitaire
    DynamicHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing dynamique
    HomingTrigger          : BOOL;        // . [LOC] Synthese declenchement homing
    PresetVerificationActive : BOOL;      // . [LOC] Verification preset en attente
    PresetConfirmed        : BOOL;        // . [LOC] Resultat du mode de confirmation selectionne

    // === DRAPEAUX DEFAUTS INTERNES ===
    HomingModeError        : BOOL;        // . [LOC] Latch erreur mode
    TargetOutOfRangeError  : BOOL;        // . [LOC] Latch cible hors limites
    PresetFailError        : BOOL;        // . [LOC] Latch échec preset
    BootIncoherentError    : BOOL;        // . [LOC] Latch incohérence boot

    // === VARIABLES DE CALCUL ===
    TargetPoints           : DINT;        // . [LOC] Ecart cible converti en points
    TargetPositionM        : REAL;        // . [LOC] Cible retenue en metres
    RawDiffRestart         : DINT;        // . [LOC] Ecart brut de position au redemarrage
    PendingHomingRefRaw    : UDINT;       // . [LOC] Reference candidate, non publiee avant succes
    CandidateRawDiff       : DINT;        // . [LOC] Ecart brut de la mesure candidate
    CandidateCablePosM     : REAL;        // . [LOC] Position candidate calculee avant commit
    ReadbackOk             : BOOL;        // . [LOC] Mesure candidate dans la tolerance
    StatusBitOk            : BOOL;        // . [LOC] Etat du bit optionnel de confirmation
    PresetVerifyTimer      : TON;         // . [LOC] Temporisation historique de verification 500ms

    // === SOCLE DEFAUT (FB_FaultCore) ===
    instFault              : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses             : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

VAR CONSTANT
    // === TOLERANCE & TEMPORISATION TRANSACTION ===
    CST_HomingVerifyToleranceM : REAL := 0.010; // Tolerance mesure cible (m)
    CST_PresetVerifyTime        : TIME := T#500MS; // Latence historique avant relecture
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Homing) ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS
ResetEdge(CLK := Reset);
HomeEdge(CLK := Home);
ConfirmCoherenceEdge(CLK := BtnConfirmCoherence);

// Effacement des latches d'erreur sur Reset conscient
IF ResetEdge.Q THEN
    PresetConfirmationFailed := FALSE;
    HomingModeError := FALSE;
    TargetOutOfRangeError := FALSE;
    PresetFailError := FALSE;
END_IF;

// Levée de doute incohérence boot (BtnConfirmCoherence)
IF ConfirmCoherenceEdge.Q AND HomingPermit THEN
    Calib.HomingSuspect := FALSE;
    BootIncoherentError := FALSE;
END_IF;

// Configuration des causes nommées
instCauses[0].Active   := HomingModeError;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Homing non autorise dans ce mode';

instCauses[1].Active   := TargetOutOfRangeError;
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Cible de homing hors plage';

instCauses[2].Active   := PresetFailError;
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Echec confirmation transaction preset';

instCauses[3].Active   := BootIncoherentError;
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Incoherence position codeur au demarrage';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE — neutralisation ; on continue toutefois d'exposer le dernier état RETAIN connu
// (FB_Encoder_Scale a besoin de HomingRefRaw même si ce FB est désactivé)
IF NOT Enable THEN
    PresetRequest := FALSE;
    PresetValue := 0;
    Ready := FALSE;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    InitDone := FALSE;   // Force un nouveau contrôle à la prochaine activation
    PresetVerificationActive := FALSE;
    PresetVerifyTimer(IN := FALSE, PT := CST_PresetVerifyTime);
    Homed := Calib.Homed;
    HomingSuspect := Calib.HomingSuspect;
    HomingRefRaw := Calib.HomingRefRaw;
    // PresetConfirmationFailed est un diagnostic latch : il est gelé hors Enable
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Cohérence au redémarrage"}
// 🔍 3. COHÉRENCE AU REDÉMARRAGE — une fois par session Enable, dès que le codeur répond
IF NOT InitDone THEN
    IF EncoderAvailable THEN
        RawDiffRestart := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(Calib.LastKnownRawPos);
        IF Calib.Homed AND (ABS(RawDiffRestart) > UDINT_TO_DINT(Calib.RestartCoherenceTolerancePts)) THEN
            Calib.HomingSuspect := TRUE;
            BootIncoherentError := TRUE;
        END_IF;
        InitDone := TRUE;
    END_IF;
END_IF;
{endregion}

{region "§4 Demande et déclenchement homing"}
// ⚙️ 4. DEMANDE & DÉCLENCHEMENT HOMING
PresetRequest := FALSE;
PresetValue := 0;
TopSensorEdge(CLK := TopPositionSensor);
DynamicTargetEdge(CLK := UseDynamicTarget);

HomingModeOk := HomingPermit;

IF HomeEdge.Q AND NOT HomingModeOk THEN
    HomingModeError := TRUE;
END_IF;

NominalHomingTrigger := HomingModeOk AND NOT UseDynamicTarget
                         AND ((Home AND TopSensorEdge.Q) OR (HomeEdge.Q AND TopPositionSensor));

UnitaryHomingTrigger := HomingModeOk AND NOT UseDynamicTarget AND HomeEdge.Q;

DynamicHomingTrigger := HomingModeOk AND (DynamicTargetEdge.Q OR (UseDynamicTarget AND HomeEdge.Q));

HomingTrigger := (NominalHomingTrigger OR UnitaryHomingTrigger OR DynamicHomingTrigger)
                 AND NOT PresetVerificationActive;

IF HomingTrigger THEN
    IF UseDynamicTarget THEN
        TargetPositionM := DynamicHomingTargetM;
    ELSIF NominalHomingTrigger THEN
        TargetPositionM := CfgTopSensorPosM;
    ELSE
        TargetPositionM := CfgHomingTargetM;
    END_IF;

    // Bornage obligatoire avant écriture (CODE_QUALITY_STANDARDS §6) [-99;+99] m
    IF (TargetPositionM < -99.0) OR (TargetPositionM > 99.0) THEN
        TargetOutOfRangeError := TRUE;
    ELSE
        TargetPoints := REAL_TO_DINT(TargetPositionM * UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
        PendingHomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - TargetPoints);
        PresetValue := RawPos;
        PresetRequest := TRUE;
        PresetVerificationActive := TRUE;
        Lifecycle.Done := FALSE;
    END_IF;
END_IF;
{endregion}

{region "§5 Suivi de transaction preset"}
// ⏳ 5. SUIVI DE LA TRANSACTION PRESET
PresetVerifyTimer(IN := PresetVerificationActive, PT := CST_PresetVerifyTime);
IF PresetVerificationActive AND PresetVerifyTimer.Q THEN
    CandidateRawDiff := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(PendingHomingRefRaw);
    IF PointsPerRev <> 0 THEN
        CandidateCablePosM := DINT_TO_REAL(CandidateRawDiff) * CableM_PerRev / UDINT_TO_REAL(PointsPerRev);
    ELSE
        CandidateCablePosM := 0.0;
    END_IF;
    ReadbackOk := ABS(CandidateCablePosM - TargetPositionM) <= CST_HomingVerifyToleranceM;
    StatusBitOk := PresetStatusBit;

    CASE Cfg.PresetConfirmMode OF
        E_PresetConfirmMode.READBACK_ONLY:
            PresetConfirmed := ReadbackOk;
        E_PresetConfirmMode.READBACK_AND_STATUSBIT:
            PresetConfirmed := ReadbackOk AND StatusBitOk;
        E_PresetConfirmMode.STATUSBIT_ONLY:
            PresetConfirmed := StatusBitOk;
        ELSE
            PresetConfirmed := FALSE;
    END_CASE;

    IF PresetConfirmed THEN
        Calib.HomingRefRaw := PendingHomingRefRaw;
        Calib.Homed := TRUE;
        Calib.HomingSuspect := FALSE;
        Calib.LastKnownRawPos := RawPos;
        PresetConfirmationFailed := FALSE;
        PresetFailError := FALSE;
        Lifecycle.Done := TRUE;
    ELSE
        Calib.HomingSuspect := TRUE;
        PresetConfirmationFailed := TRUE;
        PresetFailError := TRUE;
        Lifecycle.Done := FALSE;
    END_IF;

    PresetVerificationActive := FALSE;
    PresetVerifyTimer(IN := FALSE, PT := CST_PresetVerifyTime);
END_IF;
{endregion}

{region "§6 Sorties état & calibration"}
// 📤 6. SORTIES ÉTAT & CALIBRATION
IF EncoderAvailable AND NOT PresetVerificationActive THEN
    Calib.LastKnownRawPos := RawPos;
END_IF;

Lifecycle.Busy := PresetVerificationActive;
Homed := Calib.Homed AND NOT Calib.HomingSuspect;
HomingSuspect := Calib.HomingSuspect;
HomingRefRaw := Calib.HomingRefRaw;
{endregion}
