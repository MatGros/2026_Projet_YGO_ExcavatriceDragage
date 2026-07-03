(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_GrappinConfig — Configuration des offsets du grappin
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie12_Fonction_Grappin_v1.0.md §4.A
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_GrappinConfig :
STRUCT
    OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres grappin ouvert *)
    OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres grappin fermé *)
    CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)
END_STRUCT
END_TYPE
