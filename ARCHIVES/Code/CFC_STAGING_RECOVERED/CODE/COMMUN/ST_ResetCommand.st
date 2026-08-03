(* ═══════════════════════════════════════════════════════════════
   🔘 ST_ResetCommand — Commande Reset publique amont
   ───────────────────────────────────────────────────────────────
   🎯 Niveau continu issu de l'IHM. Chaque consommateur porte son
      propre détecteur de front : ce contrat ne mémorise aucun état.
   🛡️ Un Reset ne réarme jamais sans action consciente ultérieure.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ResetCommand :
STRUCT
    CmdReset : BOOL;  (* TRUE = au moins une demande Reset IHM présente *)
END_STRUCT
END_TYPE
