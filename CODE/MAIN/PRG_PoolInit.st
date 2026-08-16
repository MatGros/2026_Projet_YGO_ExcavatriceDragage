(* ═══════════════════════════════════════════════════════════════
   💾 PRG_PoolInit — Initialisation du pool de ressources CAA File
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : configure FILE.g_FileClass + pool extender (UNE fois, au boot).
   📄 Docs : CAA File 3.5.19 « Resource Management » · bibliothèque RSU.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_PoolInit

IF NOT GVL_Pool.PoolInitDone THEN
    GVL_Pool.myPoolExtender.Reset(RSU.g_AsyncProperty);
    FILE.g_FileClass.Reset(
        udiInitialPoolSize    := 40 * SIZEOF(__XWORD),
        udiNumExtensionBlocks := 20,
        itfPoolExtender       := GVL_Pool.myPoolExtender
    );
    GVL_Pool.PoolInitDone := TRUE;
END_IF

END_PROGRAM
