(* =======================================================================
   🧩 ST_FbCause — Cause élémentaire d'un FB standard (socle FB_FbStatus)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : une cause de défaut/warning exprimée en CLAIR (BOOL + libellé),
      sans bitfield ni masque. Le FB métier remplit une liste de causes
      (ARRAY[0..15] OF ST_FbCause) ; le socle gère latch/reset/textes.
   🧬 Contrat : remplacer l'ancien couple WORD bitfield + tableaux de textes
      indexés par bit par une liste lisible (maintenance, « avec une liste »).
   🔒 Sécurité : interlock TOUJOURS sur Active (cause brute), jamais sur
      l'acquittement. IsWarning distingue warning (auto) / fault (à acquitter).
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

TYPE ST_FbCause :
STRUCT
    Active     : BOOL;   (* 1 = cause présente (interlock sur la cause brute) *)
    IsWarning  : BOOL;   (* 1 = warning auto-effacé ; 0 = défaut à acquitter *)
    Texte      : STRING; (* libellé prêt IHM de la cause *)
END_STRUCT
END_TYPE
