(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_Diag_Emergency — Diagnostic et erreurs de la chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Produit par FB_Safety_EmergencyManagement (sortie Diag).
      Consommé par PRG_09_Supervision et GVL_Troubleshooting.
   🎯 Champs lecture seule — producteur unique = FB composite.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md §8.2
*)

TYPE ST_Diag_Emergency :
STRUCT
    Error                    : BOOL;   // 🔴 Synthèse : (ErrorId <> 0)
    ErrorId                  : WORD;   // ❌ bit0 = RedundancyTestFailed (auto-test A/B), bit1 = EmergencyArmingFailed (timeout confirm contacteur)
    RedundancyTestFailed     : BOOL;   // 🔴 Canal A ou B resté collé/shunté détecté à l'auto-test — Reset requis (cause disparue)
    ArmFailed                : BOOL;   // 🔴 Impulsion envoyée mais contacteur puissance non confirmé sous 2 s — Reset + contacteur engagé requis
    LockoutActive            : BOOL;   // ⏳ Verrouillage temporel de 5 s entre tentatives de réarmement échouées
END_STRUCT
END_TYPE
