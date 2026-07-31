(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Encoder_Safety — Bornage physique + relais incohérence redémarrage (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Encoder_v2.0.md §3.6/§3.7
   🔌 FB STANDARD (Partie3 §1bis) : pas un FB de mouvement, pas de StartStop/SafeStop.
   🎯 PÉRIMÈTRE CE LOT (répond à l'incident CablePosM≈4096m après reset RETAIN) :
      - §3.6 Bornage absolu [-99.00 ; +99.00] m : `CablePosM` hors plage → valeur
        jugée IMPOSSIBLE, sortie `CablePosMSafe` GELÉE sur dernière valeur plausible
        (principe « geler sur doute », §6), ErrorId bit0.
      - §3.7 Relais de `HomingSuspect` (déjà détecté par `FB_Encoder_Homing`, jamais
        consommé nulle part avant ce lot) : ErrorId bit1.
      - `EncoderIncoherent` (= Error) → consommé par `FB_Modes` pour REFUSER
        `SEMI_AUTO` (reste possible de travailler en MAINT_N1/N2 pour re-référencer,
        voir échange utilisateur — PAS de SafeStop ici, ne bloque jamais le mouvement).
   🔴 HORS PÉRIMÈTRE CE LOT (Partie10 §3.5, reporté) : détection de saut EN COURS
      D'EXPLOITATION (plausibilité vitesse codeur, calcul sur cycles EtherCAT 4ms) —
      lot dédié à part entière, pas fait ici.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Safety) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Safety
VAR_INPUT
    Enable           : BOOL;        // Standard
    Reset            : BOOL;        // Acquittement défaut (front) — bit0 uniquement (bit1 suit HomingSuspect, voir §7bis)
    PowerContactorEngaged  : BOOL;        // Standard
    Mode             : E_Mode;      // Standard (contexte, pas encore exploité ce lot)
    CablePosM        : REAL;        // Sortie FB_Encoder_Scale DE CE TREUIL
    HomingSuspect    : BOOL;        // Sortie FB_Encoder_Homing DE CE TREUIL (§3.7, déjà calculé)
    PositionMinM     : REAL := -99.0;  // Bornage physique dur (Partie10 §3.6)
    PositionMaxM     : REAL := 99.0;
    BypassGlobal     : BOOL := FALSE;  // 🌐 Force ErrorId=0, ignore bornage (mise en service)
END_VAR
VAR_OUTPUT
    Ready            : BOOL;
    Busy             : BOOL;
    Done             : BOOL;
    Error            : BOOL;
    ErrorId          : WORD;        // bit0: "Position câble hors plage" - position hors plage physique ; bit1: "Incohérence position boot" - incohérence redémarrage (miroir HomingSuspect)
    State            : E_State;
    StateAtError     : E_State;
    CablePosMSafe    : REAL;        // CablePosM gelée sur dernière valeur plausible si hors plage
    EncoderIncoherent: BOOL;        // = Error — consommé par FB_Modes (refuse SEMI_AUTO)
END_VAR
VAR
    ResetEdge             : R_TRIG;
    ErrorEdge             : R_TRIG;
    LastPlausibleCablePosM: REAL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Safety) ===

// 🛑 1. GATE — expose la dernière valeur plausible connue même désactivé
IF NOT Enable THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    CablePosMSafe := LastPlausibleCablePosM;
    EncoderIncoherent := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🌐 BYPASS GLOBAL : force ErrorId = 0, ignore bornage et incohérence
IF BypassGlobal THEN
    ErrorId := 16#0000;
END_IF;

// 🔍 3. BORNAGE PHYSIQUE ABSOLU (§3.6) — bit0
IF NOT BypassGlobal AND ((CablePosM < PositionMinM) OR (CablePosM > PositionMaxM)) THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE; (* Auto-clearing dès que la position revient dans la plage valide *)
END_IF;

// 🔍 4. RELAIS INCOHÉRENCE REDÉMARRAGE (§3.7, calculée par FB_Encoder_Homing) — bit1
// Pas d'acquittement ici : la levée se fait via BtnConfirmCoherence/nouveau Home côté
// FB_Encoder_Homing (source), ce FB ne fait QUE relayer l'information pour FB_Modes.
IF NOT BypassGlobal THEN
    IF HomingSuspect THEN
        ErrorId := ErrorId OR 16#0002;
    ELSE
        ErrorId := ErrorId AND 16#FFFD;
    END_IF;
END_IF;

// 🧊 5. GELER SUR DOUTE (§6) — CablePosMSafe ne suit PAS CablePosM si hors plage
IF (ErrorId AND 16#0001) = 16#0000 THEN
    LastPlausibleCablePosM := CablePosM;
END_IF;
CablePosMSafe := LastPlausibleCablePosM;

// 📤 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

EncoderIncoherent := Error;
Busy := FALSE;
Done := FALSE;
