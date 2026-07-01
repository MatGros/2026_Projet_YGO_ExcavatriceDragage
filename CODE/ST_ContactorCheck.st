(* ═══════════════════════════════════════════════════════════════
   🔌 ST_ContactorCheck — Double vérification commande/retour contacteur
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie2_Architecture_Programme_v2.5.md §8,
                   DOC/AF_Partie3_Template_FB_Commun_v1.2.md §7bis
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
