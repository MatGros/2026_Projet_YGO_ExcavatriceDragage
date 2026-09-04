(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_fbTranslationCmdArbitration_Cfg — Config translation M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Config statique de FB_TranslationCmdArbitrationM3.
       Porte la fréquence max (échelle FreqPct) — paramètre de config,
       pas un fait de gating (I5). Le Context ne garde que les faits
       de gating (HeightInterlockOk).
   📤 Producteur : PRG_05_Translation (câblage).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔌 Source : GVL_PERSISTENT._TranslationMaxFreq_Hz (source unique).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbTranslationCmdArbitration_Cfg :
STRUCT
    MaxFreq_Hz : REAL;  // --> [CFG] Fréquence max (échelle FreqPct, _TranslationMaxFreq_Hz)
END_STRUCT
END_TYPE
