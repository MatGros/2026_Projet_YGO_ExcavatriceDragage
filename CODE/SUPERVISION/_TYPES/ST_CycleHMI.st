(* ═══════════════════════════════════════════════════════════════
   🔄 ST_CycleHMI — Données d'échange IHM du cycle semi-automatique
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Test (2026-07-24), homogène avec ST_WinchHMI.
   🐛 T66 : Cfg protégé par persistance GVL_PERSISTENT (voir PRG_09_Supervision.st §2/§3) —
   avant ce lot, SetDepth_M/SetOffset_M n'avaient AUCUN backing persistant (juste un défaut
   compilé dans le DUT), contrairement à tous les autres domaines déjà traités.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleHMI :
STRUCT
    Cmd   : ST_CycleCmd;
    State : ST_CycleState;
    Cfg   : ST_CycleCfg;
END_STRUCT
END_TYPE
