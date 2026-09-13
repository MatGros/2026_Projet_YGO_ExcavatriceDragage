(* =======================================================================
   ⚙️ E_State — Phase opérationnelle d'un FB métier (valeurs EXCLUSIVES)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des phases opérationnelles d'un FB métier
   ⚙️ Machine d'état : Un seul état actif à la fois (orthogonal à Error)
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md §3
   ======================================================================= *)

TYPE E_State :
    (DISABLED := 0, INIT := 1, READY := 2, BUSY := 3, DONE := 4, STOPPING := 5);
END_TYPE
