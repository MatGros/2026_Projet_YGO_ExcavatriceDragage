(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_SyncHMI — Données d'échange IHM pour la synchronisation
   ───────────────────────────────────────────────────────────────
   🎨 Paramètres d'écart, écart réel et alarmes.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture) *)
    CfgSyncTolerance_M       : REAL := 0.25;     (* 📐 Tolérance max d'écart (m) — 🔧 REX 2026-07-08 (5) : 0.10→0.25, aligné _WinchSyncTolerance_M *)
    CfgInitialized           : BOOL := FALSE;    (* 🐛 FIX 2026-07-23 : flag restauration boot (défaut FALSE non ambigu) — PRG_09_Supervision.st §2/§3 *)

    (* 🚦 États (Lecture seule) *)
    DeltaPos_M            : REAL;             (* 📊 Écart de position réel mesuré (m) *)
    SyncActive          : BOOL;             (* ⚖️ Indicateur si surveillance active *)
    SyncWarn            : BOOL;             (* ⚠️ LED d'alarme écart hors tolérance *)
    Ready               : BOOL;             (* 🟢 Bloc de synchro prêt *)
    Error               : BOOL;             (* 🔴 Alarme synchro active *)
    ErrorId             : WORD;             (* ❌ Code défaut synchro *)
    State               : E_State;          (* 🤖 État de l'automate interne *)

    (* 🎮 Commandes / Bypasses *)
    SelSyncEnable   : BOOL := TRUE;      (* ☑️ 🔧 REX 2026-07-08 : coché = synchro voulue (MAINT_N1/N2), ex-OverrideSync inversé *)
    BypassGlobal    : BOOL := FALSE;      (* 🌐 Bypass GLOBAL synchro : ignore toute erreur de synchronisation *)
END_STRUCT
END_TYPE
