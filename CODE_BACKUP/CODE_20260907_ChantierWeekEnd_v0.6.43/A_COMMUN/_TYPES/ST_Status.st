(* =======================================================================
   🧩 ST_Status — Socle transverse de statut d'un FB métier
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : regroupe l'état, le défaut et le warning d'un FB standard,
      avec les textes prêts pour l'IHM (plus de conditions complexes
      côté affichage). Évolution additive : les 6 membres d'origine sont conservés.
   🧬 Forme cible : les FB standard exposent `Status : ST_Status`
      rempli via le socle `FB_FbStatus` (même comportement partout).
   ⚠️ State/StateAtError : E_State (phases opérationnelles FB métier).
      Un FB dont l'état est un énum domaine (E_Diag_State, CycleStep,
      ST_Safety_Emergency_State…) garde sa sortie typée SÉPARÉE et ne
      migre pas vers ST_Status (exception documentée).
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies
   ======================================================================= *)

TYPE ST_Status :
STRUCT
    (* ---- membres historiques (conservés) ---- *)
    Busy         : BOOL;    (* 1 = Bloc en cours d'exécution *)
    Done         : BOOL;    (* 1 = Action terminée avec succès *)
    Error        : BOOL;    (* 1 = Défaut à acquitter (laté jusqu'au Reset) *)
    ErrorId      : WORD;    (* Code d'erreur bitfield / enum diagnostic *)
    State        : E_State; (* État courant de la machine d'état *)
    StateAtError : E_State; (* État mémorisé lors de l'apparition du défaut *)
    (* ---- membres ajoutés (forme cible enrichie) ---- *)
    Warning        : BOOL;  (* 1 = warning actif (auto-effacé, aucun acquittement) *)
    WarningId      : WORD;  (* Code warning courant (bitfield) *)
    WarningIdTxt   : STRING;(* Texte généré depuis WarningId (prêt IHM) *)
    ErrorIdTxt     : STRING;(* Texte généré depuis ErrorId *)
    ResetRequested : BOOL;  (* 1 = un Reset est nécessaire / en cours *)
END_STRUCT
END_TYPE
