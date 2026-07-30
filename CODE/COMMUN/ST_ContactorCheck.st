(* ═══════════════════════════════════════════════════════════════
   🔌 ST_ContactorCheck — Double vérification commande/retour contacteur
   ───────────────────────────────────────────────────────────────
    📄 Doc métier : DOC/AF_Partie-02_Architecture_Programme_v3.0.md §3,
                    DOC/AF_Partie-03_Contrats_Composants_v2.0.md §2
   Utilisé par FB_Brake (frein) et FB_Winch (contacteurs de sens) pour
   détecter un collage / une absence de fermeture d'un contacteur de
   puissance, au-delà d'un délai de cohérence (FeedbackTimeout du FB
   appelant).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_ContactorCheck :
STRUCT
    Command     : BOOL;   // Ordre envoyé au contacteur (TRUE = fermé/actif)
    Feedback    : BOOL;   // Retour d'état câblé (TRUE = effectivement fermé)
    StuckClosed : BOOL;   // Diag : commande OFF mais retour ON depuis trop longtemps → PowerCutOff
    StuckOpen   : BOOL;   // Diag : commande ON mais retour OFF depuis trop longtemps
END_STRUCT
END_TYPE
