(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_WinchBenneHMI — Données d'échange IHM pour le treuil Benne (M2 uniquement)
   ───────────────────────────────────────────────────────────────
   🎨 Composition dupliquée de ST_WinchHMI (Cmd/State/Cfg/Safety/Bypass) + Bucket.
   📄 IEC 61131-3 n'offre pas d'héritage de struct : cette duplication de la liste
      de champs est assumée pour garder M1TreuilRetenue (ST_WinchHMI, sans Bucket)
      strictement distinct de M2TreuilBenne (ce type, avec Bucket) — décision
      DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT_TROUBLESHOOTING_VIEW_ET_WINCHHMI.yaml AC5.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchBenneHMI :
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

    (* 🪣 Benne — pertinent uniquement pour M2 (M2TreuilBenne.Bucket) *)
    Bucket                  : ST_BucketHMI;
END_STRUCT
END_TYPE
