(* ═══════════════════════════════════════════════════════════════
   🚦 ST_SyncState — États et diagnostics de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncState :
STRUCT
    DeltaPos_M : REAL;    (* 📊 Écart de position réel mesuré (m) *)
    SyncActive : BOOL;    (* ⚖️ Indicateur si surveillance active *)
    SyncWarn   : BOOL;    (* ⚠️ LED d'alarme écart hors tolérance *)
    SyncDegradedStep1 : BOOL; (* 🐢 Écart modéré actif : limitation forcée au Palier 1 *)
    Ready      : BOOL;    (* 🟢 Bloc de synchro prêt *)
    Error      : BOOL;    (* Alarme synchro active *)
    ErrorId    : WORD;    (* ❌ Code défaut synchro *)
    FBState    : E_State; (* 🤖 État de l'automate interne (FB_WinchSync) *)
END_STRUCT
END_TYPE
