(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleDumpAtTremieCmd — Sélections IHM cycle vidage trémie (legacy)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDumpAtTremieCmd :
STRUCT
    TglEnableDumpAtTremie : BOOL := FALSE; (* Mode vidage à la trémie — RESTREINT des mouvements dès le boot *)
END_STRUCT
END_TYPE
