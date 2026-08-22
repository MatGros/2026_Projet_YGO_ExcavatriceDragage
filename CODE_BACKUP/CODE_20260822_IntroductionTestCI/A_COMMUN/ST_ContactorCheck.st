(* =======================================================================
   🔌 ST_ContactorCheck — Double vérification commande/retour contacteur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de diagnostic pour vérification commande vs retour
   📊 Diagnostic : Détection des défauts contacteur (StuckClosed / StuckOpen)
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md §2
   ======================================================================= *)

TYPE ST_ContactorCheck :
STRUCT
    Command     : BOOL;   // Ordre envoyé au contacteur (TRUE = fermé/actif)
    Feedback    : BOOL;   // Retour d'état câblé (TRUE = effectivement fermé)
    StuckClosed : BOOL;   // Diag : commande OFF mais retour ON depuis trop longtemps → PowerCutOff
    StuckOpen   : BOOL;   // Diag : commande ON mais retour OFF depuis trop longtemps
END_STRUCT
END_TYPE
