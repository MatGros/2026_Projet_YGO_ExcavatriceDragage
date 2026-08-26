(* =======================================================================
   ⚙️ E_State — Phase opérationnelle d'un FB métier (valeurs EXCLUSIVES)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des phases opérationnelles d'un FB métier
   ⚙️ Machine d'état : Un seul état actif à la fois (orthogonal à Error)
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md §3
   ======================================================================= *)

TYPE E_State :
ENUM
    DISABLED := 0,   (* Enable faux, neutralisé *)
    INIT     := 1,   (* Démarrage / vérifs *)
    READY    := 2,   (* Prêt, attend ordre *)
    BUSY     := 3,   (* Action en cours *)
    DONE     := 4,   (* Action terminée *)
    STOPPING := 5    (* Décél rampe avant arrêt (StartStop=FALSE ou SafeStop=TRUE) *)
END_ENUM
END_TYPE
