(* ═══════════════════════════════════════════════════════════════
   🚦 ST_GrappinState — État mémorisé et diagnostic du grappin
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie12_Fonction_Grappin_v1.0.md §4.B
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_GrappinState :
STRUCT
    IsOpen          : BOOL;    (* TRUE = Grappin ouvert mémorisé *)
    IsClosed        : BOOL;    (* TRUE = Grappin fermé mémorisé *)
    LastPosM2Open   : REAL;    (* Dernière position M2 mémorisée ouvert *)
    LastPosM2Close  : REAL;    (* Dernière position M2 mémorisée fermé *)
    StateIncoherent : BOOL;    (* État non sûr (divergence boot/réel) *)
END_STRUCT
END_TYPE
