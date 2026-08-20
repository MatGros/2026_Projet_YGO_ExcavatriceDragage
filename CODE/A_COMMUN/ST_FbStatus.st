(* =======================================================================
   🧩 ST_FbStatus — Socle transverse de statut d'un FB métier (forme cible)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : regroupe exactement les six membres nécessaires au suivi
      synoptique et diagnostic d'un FB standard (contrat §2quinquies).
   🧬 Forme cible : les FB standard passent de la forme « à plat »
      (Busy/Done/Error/ErrorId/State/StateAtError en VAR_OUTPUT) vers
      `Status : ST_FbStatus`, migré par lot dédié, gradué (pilote d'abord).
   ⚠️ State/StateAtError : E_State (phases opérationnelles FB métier).
      Un FB dont l'état est un énum domaine (E_Diag_State, CycleStep,
      ST_Safety_Emergency_State…) garde sa sortie typée SÉPARÉE et ne
      migre pas vers ST_FbStatus (exception documentée).
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies
   ======================================================================= *)

TYPE ST_FbStatus :
STRUCT
    Busy         : BOOL;    (* 1 = Bloc en cours d'exécution *)
    Done         : BOOL;    (* 1 = Action terminée avec succès *)
    Error        : BOOL;    (* 1 = Défaut actif présent *)
    ErrorId      : WORD;    (* Code d'erreur bitfield / enum diagnostic *)
    State        : E_State; (* État courant de la machine d'état *)
    StateAtError : E_State; (* État mémorisé lors de l'apparition du défaut *)
END_STRUCT
END_TYPE
