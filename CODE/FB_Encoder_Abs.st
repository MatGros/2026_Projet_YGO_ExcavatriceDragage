(* ═══════════════════════════════════════════════════════════════
   🧲 FB_Encoder_Abs — Acquisition codeur absolu (accès bus, 1 responsabilité)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.5.md §3/§6
   ⚠️ RÉÉCRITURE COMPLÈTE (remplace la version legacy du projet, dossier
      CODEUR) : l'ancienne version utilisait `HomingTrigger` (recalage
      instantané par simple offset) + un mode `Teach` auto-calibré —
      **incompatibles** avec le design Partie10 (preset SDO avec
      accusé, formule `CableM_PerRev` fixe). Retirés : `HomingTrigger`,
      `WaterLevelOffset`, `TeachActive/StartRaw/EndRaw/RealDistance`.
   🧩 1 FB = 1 responsabilité : accès bus EtherCAT + séquence d'écriture
      preset. N'orchestre PAS le homing lui-même (ça sera le rôle de
      `FB_Encoder_Homing`, pas codé ce lot) — `PresetRequest`/`PresetValue`
      sont pilotés en dur (`FALSE`/`0`) dans `PRG_MAIN` pour l'instant.
   🧊 Principe « geler sur doute » (§6) : `RawPos`/`AngleRaw`/`TurnCount`
      ne sont PAS mis à jour si `EncoderAvailable = FALSE` — ils
      conservent leur dernière valeur plausible.
   ✅ SÉQUENCE PRESET (§5) — CONFIRMÉ TERRAIN 2026-07-02 : `PresetTriggerCmd := 2`
      (valeur de commande, pas un masque de bits) déclenche le
      référencement du codeur à `PresetValueOut`. `CodeSeqTriggerCmd`
      (canal réel `COD1_CodeSeqTrigCmd`) reste `0`, rôle **non identifié**
      (même par l'utilisateur/terrain) — ne jamais lui donner une valeur
      arbitraire tant que sa fonction n'est pas confirmée.
   🔴 PERTE DE FONCTION SIGNALÉE : l'ancienne version composait
      `FB_Encoder_Safety` en interne (survitesse via `In_SpdValue`).
      Ce n'est PAS repris ici (Partie10 ne le demande pas, hors
      périmètre du document) — `FB_Encoder_Safety` (overspeed) devient
      orphelin tant qu'un lot dédié ne décide pas de son sort (fusion
      avec le "saut incohérent" Partie10 §3.5, ou reprise telle quelle).
   🔧 CORRECTIF (2026-07-03, retour terrain) : `InvertDirection` **retiré**.
      Confirmé terrain : l'objet CoE `6000h` (bit0 : 4→5) inverse le sens
      de comptage **côté codeur** (F58x8 Kübler), configuré en **Startup
      Parameter** CODESYS (init automate) — pas un paramètre PLC. L'ancien
      calcul logiciel (`16#FFFFFFFF - RawPosIn`) était de toute façon
      **buggé** : il inversait sur toute la plage `UDINT` (32 bits) au
      lieu de la plage réelle du codeur (25 bits, `PointsPerRev ×
      MultiTurnRevsMax`), produisant des positions incohérentes après
      homing. Voir Partie10 §3bis.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Abs) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Abs
VAR_INPUT
    Enable              : BOOL;        // Standard
    Reset               : BOOL;        // Acquittement défaut (front)
    EmergencyStopOk     : BOOL;        // Standard
    Mode                : E_Mode;      // Standard (contexte, pas encore exploité ce lot)
    RawPosIn            : UDINT;       // Brut EtherCAT (ex. COD1_PosValue, %ID)
    AlarmsIn            : UINT;        // Brut EtherCAT (ex. COD1_Alarms)
    WarningsIn          : UINT;        // Brut EtherCAT (ex. COD1_Warnings) — informatif seulement
    SlaveOperational    : BOOL;        // FB_DiagEthercat — esclave EtherCAT opérationnel
    PointsPerRev        : UDINT := 8192;  // Résolution codeur confirmée (Partie10 §3.3)
    PresetRequest       : BOOL;        // Front — piloté par FB_Encoder_Homing (stub FALSE ce lot)
    PresetValue         : UDINT;       // Cible brute — piloté par FB_Encoder_Homing (stub 0 ce lot)
    PresetTimeout       : TIME := T#2s;
    PresetTolerancePts  : UDINT := 10; // Tolérance relecture post-preset
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : alarme/bus codeur ; bit1 : preset refusé/timeout
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
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Abs) ===

// 🛑 1. GATE
IF NOT Enable OR NOT EmergencyStopOk THEN
    EncoderAvailable := FALSE;
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    PresetTriggerCmd := 16#0000; CodeSeqTriggerCmd := 16#0000; PresetValueOut := 0;
    PresetSeqStep := 0;
    PresetTimer(IN := FALSE, PT := PresetTimeout);
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC BUS / ALARME
IF (AlarmsIn <> 0) OR NOT SlaveOperational THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
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
    1: // Déclenchement preset (1 cycle suffit normalement, laissé actif jusqu'à confirmation)
        PresetTriggerCmd := 2;   // ✅ Valeur confirmée terrain — référence le codeur à PresetValueOut
        RawDiff := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(PresetValueOut);
        IF ABS(RawDiff) <= UDINT_TO_DINT(PresetTolerancePts) THEN
            PresetTriggerCmd := 0;
            PresetAck := TRUE;
            PresetSeqStep := 0;
            PresetTimer(IN := FALSE, PT := PresetTimeout);
        ELSIF PresetTimer.Q THEN
            PresetTriggerCmd := 0;
            PresetNak := TRUE;
            ErrorId := ErrorId OR 16#0002;
            PresetSeqStep := 0;
            PresetTimer(IN := FALSE, PT := PresetTimeout);
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
