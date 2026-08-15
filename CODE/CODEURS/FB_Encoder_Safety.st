(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Encoder_Safety — Bornage physique & surveillance cohérence
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md §3.6/§3.7
   🎯 Rôle :
      - Surveillance bornage absolu [-99.00 ; +99.00] m
      - Relais de HomingSuspect (ErrorId bit1)
      - Expose EncoderIncoherent (= Error) et transmet CablePosMSafe
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Encoder_Safety
VAR_INPUT
    Enable                : BOOL;        // Active le bloc
    Reset                 : BOOL;        // Acquittement défaut (front)
    PowerContactorEngaged : BOOL;        // Ligne puissance enclenchée
    Mode                  : E_Mode;      // Mode d'exploitation
    CablePosM             : REAL;        // Position calculée (FB_Encoder_Scale)
    HomingSuspect         : BOOL;        // Alerte incohérence redémarrage (FB_Encoder_Homing)
    PositionMinM          : REAL := -99.0; // Bornage physique bas
    PositionMaxM          : REAL := 99.0;  // Bornage physique haut
    BypassGlobal          : BOOL := FALSE; // Mise en service : neutralise le défaut de bornage
END_VAR
VAR_OUTPUT
    Ready            : BOOL;
    Busy             : BOOL;
    Done             : BOOL;
    Error            : BOOL;
    ErrorId          : WORD;        // bit0: Position hors bornes [-99..+99]m ; bit1: Incohérence boot (HomingSuspect)
    State            : E_State;
    StateAtError     : E_State;
    CablePosMSafe    : REAL;        // Position câble instantanée (non figée)
    EncoderIncoherent: BOOL;        // = Error — consommé par FB_Modes et IHM
END_VAR
VAR
    ResetEdge             : R_TRIG;
    ErrorEdge             : R_TRIG;
END_VAR

// 🛑 1. GATE
IF NOT Enable THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    CablePosMSafe := CablePosM;
    EncoderIncoherent := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🌐 3. BYPASS GLOBAL
IF BypassGlobal THEN
    ErrorId := 16#0000;
END_IF;

// 🔍 4. SURVEILLANCE BORNAGE PHYSIQUE ABSOLU (bit0)
IF NOT BypassGlobal AND ((CablePosM < PositionMinM) OR (CablePosM > PositionMaxM)) THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE; (* Auto-clearing dès retour dans la plage *)
END_IF;

// 🔍 5. RELAIS INCOHÉRENCE REDÉMARRAGE (bit1)
IF NOT BypassGlobal THEN
    IF HomingSuspect THEN
        ErrorId := ErrorId OR 16#0002;
    ELSE
        ErrorId := ErrorId AND 16#FFFD;
    END_IF;
END_IF;

// 📏 6. TRANSMISSION DE LA MESURE (Toujours réelle, non figée)
CablePosMSafe := CablePosM;

// 📤 7. SORTIES ÉTAT & SÉCURITÉ
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

EncoderIncoherent := Error;
Busy := FALSE;
Done := FALSE;
