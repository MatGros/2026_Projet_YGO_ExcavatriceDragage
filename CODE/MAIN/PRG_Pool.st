(* ═══════════════════════════════════════════════════════════════
   💾 PRG_Pool — Traitement des jobs async CAA File
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : appelle le pool extender chaque cycle (dans la tâche
      'myPoolExtender') pour traiter les jobs async d'écriture fichier.
   📄 Docs : bibliothèque RSU + CAA File.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_Pool

GVL_Pool.myPoolExtender;   // traite les jobs async chaque cycle

END_PROGRAM
