(* ═══════════════════════════════════════════════════════════════
   🧲 FB_Encoder_Abs — Acquisition codeur absolu (accès bus EtherCAT)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Encoder_v2.1.md §3/§6
                   DOC/AF_Partie-03_Contrats_Composants_v2.0.md
   🎯 Accès bus EtherCAT, statut esclave, extraction positions brutes
      et séquence de Preset SDO (PresetTriggerCmd := 2).
   🧊 Principe « geler sur doute » (§6) : RawPos/AngleRaw/TurnCount
      conservent leur dernière valeur valide si EncoderAvailable = FALSE.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Abs) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Abs
VAR_INPUT
    Enable              : BOOL;        // Standard
    Reset               : BOOL;        // Acquittement défaut (front)
    PowerContactorEngaged     : BOOL;        // Standard
    Mode                : E_Mode;      // Standard (contexte, pas encore exploité ce lot)
    RawPosIn            : UDINT;       // Brut EtherCAT (ex. COD1_PosValue, %ID)
    AlarmsIn            : UINT;        // Brut EtherCAT (ex. COD1_Alarms)
    WarningsIn          : UINT;        // Brut EtherCAT (ex. COD1_Warnings) — informatif seulement
    SlaveOperational    : BOOL;        // FB_DiagEthercat — esclave EtherCAT opérationnel
    PointsPerRev        : UDINT := 8192;  // Résolution codeur confirmée (Partie10 §3.3)
    PresetRequest       : BOOL;        // Front — piloté par FB_Encoder_Homing via PRG_02_Encoders
    PresetValue         : UDINT;       // Cible brute — piloté par FB_Encoder_Homing (stub 0 ce lot)
    PresetTimeout       : TIME := T#2s;
    PresetTolerancePts  : UDINT := 10; // Tolérance relecture post-preset
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Défaut communication codeur" - alarme/bus codeur ; bit1: "Erreur référencement (timeout)" - preset refusé/timeout
    State               : E_State;
    StateAtError        : E_State;
    RawPos              : UDINT;       // Position brute — GELÉE si EncoderAvailable=FALSE
    EncoderAvailable    : BOOL;
    AngleRaw            : UINT;        // Informatif maintenance : RawPos MOD PointsPerRev
    TurnCount           : UDINT;       // Informatif maintenance : RawPos / PointsPerRev
    PresetAck           : BOOL;        // Pulse 1 cycle — écriture confirmée
    PresetNak           : BOOL;        // Pulse 1 cycle — écriture refusée/timeout
    PresetTriggerCmd    : WORD;        // → à câbler sur COD_PresettTrigCmd (RxPDO)
    CodeSeqTriggerCmd   : WORD;        // → à câbler sur COD_CodeSeqTrigCmd (RxPDO)
    PresetValueOut      : UDINT;       // → à câbler sur COD_PresetValue (RxPDO)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    PresetReqEdge       : R_TRIG;
    PresetTimer         : TON;
    PresetSeqStep       : INT;         // 0=IDLE, 1=pulse CodeSeq, 2=pulse Trig, 3=attente confirmation
    RawDiff             : DINT;
    PresetTimerVisual   : TON;         // Timer pour laisser le temps de voir l'impulsion (1.5s)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Abs) ===

// 🛑 1. GATE
IF NOT Enable THEN
    EncoderAvailable := FALSE;
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    PresetTriggerCmd := 16#0000; CodeSeqTriggerCmd := 16#0000; PresetValueOut := 0;
    PresetSeqStep := 0;
    PresetTimer(IN := FALSE, PT := PresetTimeout);
    PresetTimerVisual(IN := FALSE, PT := T#500MS);
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC BUS / ALARME
IF (AlarmsIn <> 0) OR NOT SlaveOperational THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE; (* Auto-clearing dès que le bus et l'esclave sont OK *)
END_IF;
EncoderAvailable := (ErrorId AND 16#0001) = 0;

// 📥 4. LECTURE POSITION — GELER SUR DOUTE (Partie10 §6)
// Si EncoderAvailable=FALSE : RawPos/AngleRaw/TurnCount conservent leur dernière valeur (pas de RETURN
// global ici pour ne pas geler aussi la séquence preset/l'état — seule la lecture est gelée).
IF EncoderAvailable THEN
    RawPos := RawPosIn;   // 🔧 2026-07-03 : sens de comptage géré côté codeur (CoE 6000h bit0,
                          // startup parameter CODESYS) — voir Partie10 §3bis. Plus de calcul ici.
    AngleRaw := UDINT_TO_UINT(RawPos MOD PointsPerRev);
    TurnCount := RawPos / PointsPerRev;
END_IF;

// 🔧 5. SÉQUENCE PRESET (écriture bus)
// ✅ Confirmé terrain (2026-07-02) : PresettTrigCmd := 2 déclenche le référencement à
//    PresetValue (valeur de commande, pas un masque de bits — corrige l'hypothèse initiale).
// 🔴 CodeSeqTrigCmd : rôle NON identifié (même par l'utilisateur/terrain) — laissé à 0,
//    PAS piloté tant que sa fonction n'est pas confirmée (fiche technique ou essai dédié).
//    Ne jamais lui donner une valeur arbitraire "au cas où".
PresetReqEdge(CLK := PresetRequest);
PresetAck := FALSE; PresetNak := FALSE; // pulses 1 cycle uniquement
CodeSeqTriggerCmd := 16#0000;           // 🔴 non piloté — rôle inconnu, voir note ci-dessus
CASE PresetSeqStep OF
    0: // IDLE
        PresetTriggerCmd := 0;
        IF PresetReqEdge.Q AND EncoderAvailable THEN
            PresetValueOut := PresetValue;
            PresetSeqStep := 1;
            PresetTimer(IN := TRUE, PT := PresetTimeout);
        END_IF;
    1: // Déclenchement preset (laissé actif pendant 0.5s pour confort visuel en simulation/bus)
        PresetTriggerCmd := 2;   // ✅ Valeur confirmée terrain — référence le codeur à PresetValueOut
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
            ErrorId := ErrorId OR 16#0002;
            PresetSeqStep := 0;
            PresetTimer(IN := FALSE, PT := PresetTimeout);
            PresetTimerVisual(IN := FALSE, PT := T#500MS);
        END_IF;
END_CASE;
IF ResetEdge.Q AND (PresetSeqStep = 0) THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 🧾 6. ERROR / STATEATERROR
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

Busy := (PresetSeqStep <> 0);
Done := PresetAck;
