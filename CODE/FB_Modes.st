(* ═══════════════════════════════════════════════════════════════
   🎚️ FB_Modes — Arbitrage du mode machine (MVP — diffusion, pas encore overrides complets)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.2.md §1/§2
   🔌 FB STANDARD (Partie3 §1bis) : pas un FB de mouvement, pas de StartStop/SafeStop.
   🎯 RÔLE CE LOT : sélectionner/arbitrer `Mode` (source unique diffusée à TOUS les FB
      métier) + garde-fous minimaux :
      - Refuse `SEMI_AUTO` si un défaut codeur est présent (`EncoderFaultPresent`,
        agrégat `FB_Encoder_Safety` M1/M2) → repli `MAINT_N1`, ErrorId bit0.
      - Refuse `MAINT_N2` sans mot de passe (`PasswordOk`, stub) → repli `MAINT_N1`,
        ErrorId bit1.
      - Sort `OverrideSync` (= Mode=MAINT_N2 AND OverrideSyncRequest) pour `FB_WinchSync.Enable`
        (Partie5 §2 "Logique d'override" : `FB_WinchSync.Enable := NOT OverrideSync`).
   🔴 HORS PÉRIMÈTRE CE LOT (Partie5 §2/§3, pas encore codé faute de FB_Cycle/FB_Grappin) :
      `OverrideGrappin`, `OverrideLimit`/limite légale de dragage. À ajouter quand
      `FB_Cycle`/`FB_Grappin` existeront — ne pas inventer un override sans consommateur.
   ⚠️ Dépendance croisée `EncoderFaultPresent` (FB_Encoder_Safety, appelé APRÈS ce FB dans
      PRG_MAIN car dépend de CablePosM/Homing) consommée avec 1 CYCLE DE RETARD — même
      principe déjà assumé pour HomingRefRaw (Partie10 §9bis).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Modes) ===

FUNCTION_BLOCK PUBLIC FB_Modes
VAR_INPUT
    Enable              : BOOL;        // Standard
    Reset               : BOOL;        // Acquittement défaut (front) — bits 0/1
    EmergencyStopOk     : BOOL;        // Standard
    ModeRequest         : E_Mode;      // 🖥️ GVL_Modes_Stub.ModeRequest_IHM — sélecteur forceable
    PasswordOk          : BOOL;        // 🖥️ GVL_Modes_Stub.PasswordOk_IHM — authentification MAINT_N2 (stub)
    OverrideSyncRequest : BOOL;        // 🖥️ GVL_Modes_Stub.OverrideSyncRequest_IHM — case à cocher N2
    EncoderFaultPresent : BOOL;        // Agrégat instEncoderSafetyM1/M2.EncoderIncoherent (OR), 1 cycle de retard
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : SEMI_AUTO refusé (défaut codeur) ; bit1 : MAINT_N2 refusé (mot de passe)
    State               : E_State;
    StateAtError        : E_State;
    Mode                : E_Mode;      // 🎯 Mode ARBITRÉ — diffusé à TOUS les FB métier (remplace E_Mode.MAINT_N1 codé en dur)
    OverrideSync        : BOOL;        // → FB_WinchSync.Enable := NOT OverrideSync (actif UNIQUEMENT si Mode=MAINT_N2)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Modes) ===

// 🛑 1. GATE — repli sur le mode le plus contraint/surveillé (MAINT_N1), jamais SEMI_AUTO/MANUEL
// par défaut si la surveillance elle-même n'est pas garantie
IF NOT Enable OR NOT EmergencyStopOk THEN
    Mode := E_Mode.MAINT_N1;
    OverrideSync := FALSE;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. GARDE-FOUS
// bit0 : SEMI_AUTO demandé mais défaut codeur présent → refusé, repli MAINT_N1
IF (ModeRequest = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// bit1 : MAINT_N2 demandé sans mot de passe → refusé, repli MAINT_N1
IF (ModeRequest = E_Mode.MAINT_N2) AND NOT PasswordOk THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 📤 4. ARBITRAGE DU MODE
IF (ModeRequest = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    Mode := E_Mode.MAINT_N1;
ELSIF (ModeRequest = E_Mode.MAINT_N2) AND NOT PasswordOk THEN
    Mode := E_Mode.MAINT_N1;
ELSE
    Mode := ModeRequest;
END_IF;

// 📤 5. OVERRIDE SYNC — actionnable UNIQUEMENT en MAINT_N2 (Partie5 §2)
OverrideSync := (Mode = E_Mode.MAINT_N2) AND OverrideSyncRequest;

// 📤 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

Busy := FALSE;
Done := FALSE;
