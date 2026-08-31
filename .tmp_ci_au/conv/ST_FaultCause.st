(* =======================================================================
   🧩 ST_FaultCause — Cause élémentaire alimentant ST_Fault (socle FB_FaultCore)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : une cause exprimée EN CLAIR (BOOL + libellé), sans bitfield ni masque.
      Le FB métier remplit une liste (ARRAY[0..15] OF ST_FaultCause) ;
      le socle FB_FaultCore en déduit ST_Fault (vue live + vue latchée).
   🔒 Sécurité : interlock TOUJOURS sur Active (cause brute), jamais sur le latch.
      Latching = TRUE  → la cause ARME la vue latchée (défaut à acquitter).
      Latching = FALSE → la cause n'alimente que la vue live (retombe seule).
      Fail-safe : une cause laissée à Latching=FALSE reste visible en live —
      pour la rendre acquittable, il faut le déclarer explicitement.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

TYPE ST_FaultCause :
STRUCT
    Active   : BOOL;    (* 1 = cause présente maintenant (interlock sur cette valeur) *)
    Latching : BOOL;    (* 1 = cause à acquitter (arme Latched) ; 0 = live seulement *)
    Texte    : STRING;  (* libellé prêt IHM (non stocké dans ST_Fault, dérivé côté IHM) *)
END_STRUCT
END_TYPE
