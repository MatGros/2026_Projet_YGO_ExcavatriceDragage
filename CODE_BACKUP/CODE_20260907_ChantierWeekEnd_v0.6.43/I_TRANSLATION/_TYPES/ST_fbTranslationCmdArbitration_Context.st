(* ═══════════════════════════════════════════════════════════════
   🧩 ST_fbTranslationCmdArbitration_Context — Contexte de gating M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les faits de gating consommés par FB_TranslationCommandArbitration
       (interlock hauteur M1/M2).
       La fréquence max (config) vit dans ST_fbTranslationCmdArbitration_Cfg (I5).
   📤 Producteur : PRG_05_Translation (câblage).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbTranslationCmdArbitration_Context :
STRUCT
    HeightInterlockOk : BOOL;  // --> [SAFE] Hauteur mini M1/M2 OK (anti-collision translation)
END_STRUCT
END_TYPE
