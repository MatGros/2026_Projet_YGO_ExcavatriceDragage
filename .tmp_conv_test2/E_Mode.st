(* =======================================================================
   ⚙️ E_Mode — Modes de marche de la machine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des modes d'exploitation et maintenance
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
   ======================================================================= *)
TYPE E_Mode :
    (DISABLE := 0, MAINT_N1 := 1, MAINT_N2 := 2, SEMI_AUTO := 3);
END_TYPE
