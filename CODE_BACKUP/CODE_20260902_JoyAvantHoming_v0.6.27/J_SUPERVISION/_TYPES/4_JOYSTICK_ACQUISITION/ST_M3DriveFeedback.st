(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_M3DriveFeedback — Retours variateur M3 filtrés
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les retours variateur M3 (mot d'état + fréquence réelle)
      conditionnés par PRG_02_Acquisition et consommés par PRG_05_Translation.
   📤 Producteur unique : PRG_02_Acquisition (Data.M3).
   📥 Consommateur : PRG_05_Translation (Data.M3.StatusWord / Data.M3.ActualFrequencyHz).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_M3DriveFeedback :
STRUCT
    StatusWord        : UINT; // 📊 Mot d'état variateur M3 filtré
    ActualFrequencyHz : UINT; // 📊 Fréquence réelle M3 filtrée
END_STRUCT
END_TYPE
