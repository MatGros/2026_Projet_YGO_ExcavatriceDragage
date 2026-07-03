(* ═══════════════════════════════════════════════════════════════
   🚦 E_State — Phase opérationnelle d'un FB métier (valeurs EXCLUSIVES)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie3_Template_FB_Commun_v1.2.md §2
   ⚠️ Un seul état à la fois. Error / SafeStop / perte Enable sont
      ORTHOGONAUX à la phase (voir ErrorId, ne polluent pas State).
   🧩 Fondation manquante requise par le contrat FB (Partie3 §1).
   ═══════════════════════════════════════════════════════════════ *)

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
