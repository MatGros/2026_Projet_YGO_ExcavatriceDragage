(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_SyncHMI — Données d'échange IHM pour la synchronisation
   ───────────────────────────────────────────────────────────────
   🎨 Paramètres d'écart, écart réel et alarmes.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture) *)
    SyncToleranceM      : REAL := 0.10;     (* 📐 Tolérance max d'écart (m) *)

    (* 🚦 États (Lecture seule) *)
    DeltaPosM           : REAL;             (* 📊 Écart de position réel mesuré (m) *)
    SyncActive          : BOOL;             (* ⚖️ Indicateur si surveillance active *)
    SyncWarn            : BOOL;             (* ⚠️ LED d'alarme écart hors tolérance *)
    Ready               : BOOL;             (* 🟢 Bloc de synchro prêt *)
    Error               : BOOL;             (* 🔴 Alarme synchro active *)
    ErrorId             : WORD;             (* ❌ Code défaut synchro *)
    State               : E_State;          (* 🤖 État de l'automate interne *)

    (* 🎮 Commandes / Bypasses *)
    OverrideSync        : BOOL;             (* 🔓 Désactivation de la synchro (MAINT_N2) *)
END_STRUCT
END_TYPE
