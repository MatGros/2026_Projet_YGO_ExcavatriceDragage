(* =======================================================================
   🧩 ST_Fault — Brique socle défaut (2 vues : live + latchée)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : porter l'état défaut d'un composant, applicable dans TOUS les cas
      (acquittable ou non), sans brique warning séparée.
        • Vue LIVE   (Error / ErrorId)     : suit la cause, retombe seule à 0.
        • Vue LATCHÉE (Latched / LatchedId): mémorisée au défaut, reste jusqu'au front Reset.
      Le choix acquittable / non-acquittable se fait PAR CAUSE
      (ST_FaultCause.Latching), jamais par bloc.
   🔒 Sécurité : interlock TOUJOURS sur la cause brute (Error / ErrorId), jamais
      sur l'acquittement. Reset TOUJOURS effectif, jamais conditionné (std §9).
   🧬 Composition : brique de base réutilisable — sortie de FB, struct métier, GVL.
      Texte IHM NON stocké ici : dérivé côté IHM depuis LatchedId / ErrorId.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

TYPE ST_Fault :
STRUCT
    Error     : BOOL;   (* <-- [DIAG] vue LIVE : au moins une cause présente maintenant *)
    ErrorId   : WORD;    (* <-- [DIAG] bitfield des causes présentes maintenant (0 si aucune) *)
    Latched   : BOOL;    (* <-- [DIAG] vue LATCHÉE : défaut non acquitté, reste jusqu'au front Reset *)
    LatchedId : WORD;    (* <-- [DIAG] ErrorId figé à l'apparition du défaut, effacé au Reset *)
END_STRUCT
END_TYPE
