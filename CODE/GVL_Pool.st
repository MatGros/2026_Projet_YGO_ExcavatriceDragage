(* ═══════════════════════════════════════════════════════════════
   💾 GVL_Pool — Pool de ressources CAA File (RSU)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : instance globale du pool extender CAA File, pour traiter
      les jobs async d'écriture fichier (évite ASM_CREATEJOB_FAILED).
   📄 Docs : bibliothèque RSU (CAA Resource Management) + CAA File.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL
    myPoolExtender : RSU.PoolExtender;   // traite les jobs async CAA File
    PoolInitDone   : BOOL := FALSE;      // init exécutée une seule fois
END_VAR
