(* ═══════════════════════════════════════════════════════════════
   🚦 ST_BucketState — État mémorisé et diagnostic du benne
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md §4.B
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_BucketState :
STRUCT
    IsOpen          : BOOL;    (* TRUE = Benne ouvert mémorisé *)
    IsClosed        : BOOL;    (* TRUE = Benne fermé mémorisé *)
    LastPosM2Open   : REAL;    (* Dernière position M2 mémorisée ouvert *)
    LastPosM2Close  : REAL;    (* Dernière position M2 mémorisée fermé *)
    StateIncoherent : BOOL;    (* État non sûr (divergence boot/réel) *)
END_STRUCT
END_TYPE
