(* =======================================================================
   📊 ST_Safety_Emergency_Diag — Diagnostic et erreurs de la chaîne AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de diagnostic et erreurs de la chaîne d'arrêt d'urgence
   🔌 Interface : Produit par FB_Safety_EmergencyManagement, consommé par Supervision/Troubleshooting
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_Diag :
STRUCT
    Error                : BOOL; // Synthese defaut active : (ErrorId <> 0)
    ErrorId              : WORD; // Bitfield erreurs : bit0=Redundancy, bit1=Arming, bit3=Startup
    RedundancyTestFailed : BOOL; // Canal A ou B reste colle/shunte detecte a l'auto-test (Reset requis)
    ArmFailed            : BOOL; // Impulsion envoyee mais contacteur puissance non confirme sous 2s (Reset requis)
    LockoutActive        : BOOL; // Verrouillage temporel de 5s entre tentatives de rearmement echouees
END_STRUCT
END_TYPE
