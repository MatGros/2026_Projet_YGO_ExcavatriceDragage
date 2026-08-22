(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_WinchHMI — Données d'échange IHM pour un treuil (M1: moteur de retenue / M2: moteur Benne)
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des bargraphes, LEDs, mesures et réglages.
   📄 Structuration en Cmd / State / Cfg / Safety / Bypass (2026-07-22)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchHMI :
STRUCT
    (* 🎮 Commandes opérateur *)
    Cmd                     : ST_WinchCmd;

    (* 🚦 États, retours et mesures *)
    State                   : ST_WinchState;

    (* 🔧 Configurations et limites *)
    Cfg                     : ST_WinchCfg;

    (* 🛡️ Sécurité (FB_Safety_Winch) *)
    Safety                  : ST_SafetyWinch;

    (* 🔧 Bypass maintenance *)
    Bypass                  : ST_BypassWinch;
END_STRUCT
END_TYPE
