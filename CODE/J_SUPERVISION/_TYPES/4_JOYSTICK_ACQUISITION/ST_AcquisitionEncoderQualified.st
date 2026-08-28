(* ═══════════════════════════════════════════════════════════════
   🧲 ST_AcquisitionEncoderQualified — Façade codeur qualifiée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les mesures métriques, statuts de référencement,
      défauts et signaux hardware produits par FB_Encoder dans PRG_02_Acquisition.
   📤 Producteur unique : PRG_02_Acquisition (Data.EncoderM1 / Data.EncoderM2).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AcquisitionEncoderQualified :
STRUCT
    Measurement              : ST_fbEncoder_Measurement; // 📊 Mesure métrique (CablePosM, SpeedMps, etc.)
    Ready                    : BOOL;                     // 🟢 Façade codeur prête
    Fault                    : ST_Fault;                 // ❌ Diagnostic défaut codeur
    Homed                    : BOOL;                     // 🎯 Codeur référencé
    HomingSuspect            : BOOL;                     // ⚠️ Référencement suspect
    EncoderFault             : BOOL;                     // ❌ Défaut fiabilité (indisponible ou incohérent)
    HomedAndReliable         : BOOL;                     // ✅ Référencé ET fiable (sans incohérence)
    PresetConfirmationFailed : BOOL;                     // ❌ Échec confirmation preset
    HwOut                    : ST_fbEncoder_HwOut;       // 📡 Commandes hardware de preset (lecture seule)
END_STRUCT
END_TYPE
