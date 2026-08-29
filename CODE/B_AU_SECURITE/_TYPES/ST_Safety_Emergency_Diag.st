(* =======================================================================
   📊 ST_Safety_Emergency_Diag — Diagnostic et erreurs de la chaîne AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de diagnostic et erreurs de la chaîne d'arrêt d'urgence
   🔌 Interface : Produit par FB_Safety_EmergencyManagement, consommé par Supervision/Troubleshooting
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_Diag :
STRUCT
    Error                : BOOL; // Synthese defaut active : (ErrorId <> 0)
    ErrorId              : WORD; // Bitfield erreurs : bit0=Redundancy, bit1=Arming, bit3=Startup
    RedundancyTestFailed : BOOL; // Canal A ou B reste colle/shunte detecte a l'auto-test (Reset requis)
    ArmFailed            : BOOL; // Impulsion envoyee mais contacteur puissance non confirme sous 2s (Reset requis)
    LockoutActive        : BOOL; // Verrouillage temporel de 5s entre tentatives de rearmement echouees
    LastAbortStep        : INT;  // Etape de la sequence AU lors du dernier abandon (0 a 6)
    LastAbortCause       : WORD; // Bitfield cause abandon : 16#0001=Cut IHM, 16#0002=Chute chaine pulse/confirm, 16#0004=Timeout A, 16#0008=Timeout B, 16#0010=PowerCutOff metier
END_STRUCT
END_TYPE
