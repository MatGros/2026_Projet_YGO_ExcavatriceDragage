(* =======================================================================
   🧩 ST_Lifecycle — Brique socle cycle d'exécution
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : porter l'avancement d'une action à cycle (organe, séquenceur).
      Optionnelle : un FB purement synchrone (conditionneur, filtre, joystick)
      ne la porte pas.
   🧬 Composition : brique de base réutilisable, composée avec ST_Fault.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies
   ======================================================================= *)

TYPE ST_Lifecycle :
STRUCT
    Busy : BOOL;   (* <-- [STAT] 1 = action en cours *)
    Done : BOOL;   (* <-- [STAT] 1 = action terminée avec succès *)
END_STRUCT
END_TYPE
