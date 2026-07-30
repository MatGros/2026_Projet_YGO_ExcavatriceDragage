(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_BucketConfig — Configuration des offsets du benne
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-11_Fonction_Benne_v2.0.md §4.A
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_BucketConfig :
STRUCT
    OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres benne ouvert *)
    OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres benne fermé *)
    CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)
END_STRUCT
END_TYPE
