(* =======================================================================
   🔌 FB_Encoder_Abs — Acquisition codeur absolu (accès bus EtherCAT)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Accès bus EtherCAT, extraction positions brutes et séquence de Preset SDO
   🔒 Polarité : EncoderAvailable=TRUE si communication bus et esclave OK
   🔌 Architecture : Module d'acquisition codeur absolu
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Abs) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Abs
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable              : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset               : BOOL;        // --> [CMD] Acquittement defaut (front montant)
    PresetRequest       : BOOL;        // --> [CMD] Demande de preset (front montant)

    // === BUS ETHERCAT & CAPTEUR HW ===
    RawPosIn            : UDINT;       // --> [HW]  Position brute EtherCAT
    AlarmsIn            : UINT;        // --> [HW]  Codes alarmes bruts EtherCAT
    WarningsIn          : UINT;        // --> [HW]  Codes avertissements bruts EtherCAT
    SlaveOperational    : BOOL;        // --> [HW]  Statut esclave EtherCAT operationnel

    // === PARAMETRES & REGLAGES ===
    PointsPerRev        : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    PresetValue         : UDINT;       // --> [CFG] Valeur cible de preset
    PresetTimeout       : TIME := T#2s;// --> [CFG] Temporisation max attente preset
    PresetTolerancePts  : UDINT := 10; // --> [CFG] Tolerance relecture post-preset (pts)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready               : BOOL;        // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "Com", bit1: "Preset Timeout".
    Status              : ST_FbStatus;

    // === MESURES & DONNEES CODEUR ===
    RawPos              : UDINT;       // <-- [DIAG] Position brute gelee si non disponible
    EncoderAvailable    : BOOL;        // <-- [STAT] Codeur operationnel et disponible
    AngleRaw            : UINT;        // <-- [DIAG] Angle brut sur un tour (MOD PointsPerRev)
    TurnCount           : UDINT;       // <-- [DIAG] Nombre de tours bruts (RawPos / PointsPerRev)

    // === COMMANDES & ECHANGE BUS ETHERCAT ===
    PresetAck           : BOOL;        // <-- [STAT] Pulse confirmation preset reussi
    PresetNak           : BOOL;        // <-- [STAT] Pulse refus / timeout preset
    PresetTriggerCmd    : WORD;        // <-- [ACT]  Ordre declenchement preset vers PDO Rx
    CodeSeqTriggerCmd   : WORD;        // <-- [ACT]  Ordre sequence code vers PDO Rx
    PresetValueOut      : UDINT;       // <-- [ACT]  Valeur de preset transmise au PDO Rx
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge           : R_TRIG;      // . [LOC] Detecteur front montant Reset
    ErrorEdge           : R_TRIG;      // . [LOC] Detecteur front montant Error
    PresetReqEdge       : R_TRIG;      // . [LOC] Detecteur front montant PresetRequest

    // === TEMPORISATEURS INTERNES ===
    PresetTimer         : TON;         // . [LOC] Temporisateur timeout sequence preset
    PresetTimerVisual   : TON;         // . [LOC] Temporisateur maintien visuel impulsion (500ms)

    // === VARIABLES INTERNES DE CALCUL & ETAT ===
    PresetSeqStep       : INT;         // . [LOC] Etape sequence preset (0:IDLE, 1:PULSE/WAIT)
    RawDiff             : DINT;        // . [LOC] Ecart signe entre RawPos et PresetValueOut
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Abs) ===

{region "§1 Gate"}
// 🛑 1. GATE
IF NOT Enable THEN
    EncoderAvailable := FALSE;
    Status.State := E_State.DISABLED;
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    PresetTriggerCmd := 16#0000; CodeSeqTriggerCmd := 16#0000; PresetValueOut := 0;
    PresetSeqStep := 0;
    PresetTimer(IN := FALSE, PT := PresetTimeout);
    PresetTimerVisual(IN := FALSE, PT := T#500MS);
    RETURN;
END_IF;

Ready := TRUE;
Status.State := E_State.READY;
{endregion}

{region "§2 Reset front"}
// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);
{endregion}

{region "§3 Diagnostic bus et alarme"}
// 🔍 3. DIAGNOSTIC BUS / ALARME
IF (AlarmsIn <> 0) OR NOT SlaveOperational THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
ELSE
    Status.ErrorId := Status.ErrorId AND 16#FFFE; (* Auto-clearing dès que le bus et l'esclave sont OK *)
END_IF;
EncoderAvailable := (Status.ErrorId AND 16#0001) = 0;
{endregion}

{region "§4 Lecture position"}
// 📥 4. LECTURE POSITION — GELER SUR DOUTE (Partie10 §6)
// Si EncoderAvailable=FALSE : RawPos/AngleRaw/TurnCount conservent leur dernière valeur (pas de RETURN
// global ici pour ne pas geler aussi la séquence preset/l'état — seule la lecture est gelée).
IF EncoderAvailable THEN
    RawPos := RawPosIn;   // Sens de comptage géré côté codeur (CoE 6000h bit0, startup parameter CODESYS) — voir Partie10 §3bis. Plus de calcul ici.
    AngleRaw := UDINT_TO_UINT(RawPos MOD PointsPerRev);
    TurnCount := RawPos / PointsPerRev;
END_IF;
{endregion}

{region "§5 Séquence preset"}
// 🔧 5. SÉQUENCE PRESET (écriture bus)
// PresetTriggerCmd := 2 déclenche le référencement à PresetValue (valeur de commande, pas un
// masque de bits). CodeSeqTriggerCmd : rôle non identifié — laissé à 0, PAS piloté tant que sa
// fonction n'est pas confirmée. Ne jamais lui donner une valeur arbitraire.
PresetReqEdge(CLK := PresetRequest);
PresetAck := FALSE; PresetNak := FALSE; // pulses 1 cycle uniquement
CodeSeqTriggerCmd := 16#0000;           // non piloté — rôle inconnu, voir note ci-dessus
CASE PresetSeqStep OF
    0: // IDLE
        PresetTriggerCmd := 0;
        IF PresetReqEdge.Q AND EncoderAvailable THEN
            PresetValueOut := PresetValue;
            PresetSeqStep := 1;
            PresetTimer(IN := TRUE, PT := PresetTimeout);
        END_IF;
    1: // Déclenchement preset (laissé actif pendant 0.5s pour confort visuel en simulation/bus)
        PresetTriggerCmd := 2;   // Référence le codeur à PresetValueOut
        RawDiff := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(PresetValueOut);
        IF ABS(RawDiff) <= UDINT_TO_DINT(PresetTolerancePts) THEN
            PresetTimer(IN := FALSE, PT := PresetTimeout);
            PresetTimerVisual(IN := TRUE, PT := T#500MS);
            IF PresetTimerVisual.Q THEN
                PresetTriggerCmd := 0;
                PresetAck := TRUE;
                PresetSeqStep := 0;
                PresetTimerVisual(IN := FALSE, PT := T#500MS);
            END_IF;
        ELSIF PresetTimer.Q THEN
            PresetTriggerCmd := 0;
            PresetNak := TRUE;
            Status.ErrorId := Status.ErrorId OR 16#0002;
            PresetSeqStep := 0;
            PresetTimer(IN := FALSE, PT := PresetTimeout);
            PresetTimerVisual(IN := FALSE, PT := T#500MS);
        END_IF;
END_CASE;
IF ResetEdge.Q AND (PresetSeqStep = 0) THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFD;
END_IF;
{endregion}

{region "§6 Error et StateAtError"}
// 🧾 6. ERROR / STATEATERROR
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

Status.Busy := (PresetSeqStep <> 0);
Status.Done := PresetAck;
{endregion}
