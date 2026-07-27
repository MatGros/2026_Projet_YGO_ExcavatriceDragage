(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ GVL_Troubleshooting — GVL Globale de Recherche de Pannes (Fil de Signal)
   ───────────────────────────────────────────────────────────────
   ⚙️ Emplacement : CODE/MAIN/GVL_Troubleshooting.st
   🎨 Accessible en ligne sous CODESYS pour localiser instantanément tout blocage.
   💬 Commentaires : Valeurs nominales attendues en fonctionnement normal.
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    WinchM1       : ST_ChainWinch;       // 🪝 Fil de signal Treuil M1 (Retenue)
    WinchM2       : ST_ChainWinch;       // 🪝 Fil de signal Treuil M2 (Benne)
    TranslationM3 : ST_ChainTranslation; // ↔️ Fil de signal Translation M3 (Variateur AC600)
END_VAR