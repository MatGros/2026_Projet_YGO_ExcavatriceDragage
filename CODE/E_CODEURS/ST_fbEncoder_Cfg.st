(* =======================================================================
   ⚙️ ST_fbEncoder_Cfg — Réglages technologiques publics de FB_Encoder
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : porter le mode de confirmation preset commun aux codeurs.
   🔒 Ownership : GVL_IHM.Commun.EncoderCfg ↔ GVL_PERSISTENT._EncoderCfgPersist.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

TYPE ST_fbEncoder_Cfg :
STRUCT
    PresetConfirmMode : E_PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY; // Mode de confirmation preset, défaut relecture
    Initialized       : BOOL := FALSE;                        // 🚦 TRUE après restauration du pont persistant
END_STRUCT
END_TYPE
