(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationHMI — Données d'échange IHM pour le Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des états, commandes et diagnostics du translation.
   📄 Structuration en Cmd / State / Safety / Bypass / Test (2026-07-22) —
      doc métier : ARCHIVES/Doc/AF_Partie-11_Fonction_Translation_v2.0.md
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationHMI :
STRUCT
    (* 🎮 Commandes opérateur (manuel / maintenance) *)
    Cmd                     : ST_TranslationCmd;

    (* 🚦 États & diagnostics *)
    State                   : ST_TranslationState;

    (* 🔧 Bypass maintenance *)
    Bypass                  : ST_BypassTranslation;

    (* 🛡️ Sécurité (FB_Safety_Translation) *)
    Safety                  : ST_SafetyTranslation;
END_STRUCT
END_TYPE
