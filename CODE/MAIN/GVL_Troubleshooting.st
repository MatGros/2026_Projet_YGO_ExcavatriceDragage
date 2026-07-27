(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ GVL_Troubleshooting — GVL Globale de Recherche de Pannes (Orientée Fonctions Machines)
   ───────────────────────────────────────────────────────────────
   ⚙️ Emplacement : CODE/MAIN/GVL_Troubleshooting.st
   🎨 Structurée par UTILISATION ET FONCTIONS MACHINE (pas uniquement par matériel).
   💬 Permet de localiser en 3 secondes le blocage d'une action utilisateur.
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    LevageSynchroniseM1M2 : ST_ChainWinchSync;    // 🛗 1. Levage Synchronisé M1+M2 (Mode Couplé Nominal)
    LevageUnitaireM1      : ST_ChainWinch;        // 🛗 2. Levage Unitaire M1 (Treuil Retenue)
    LevageUnitaireM2      : ST_ChainWinch;        // 🛗 3. Levage Unitaire M2 (Treuil Benne)
    BenneOuvertureFermeture: ST_ChainBucket;       // 🪣 4. Ouverture / Fermeture Benne
    TranslationPontM3     : ST_ChainTranslation;  // ↔️ 5. Translation Pont M3 (Variateur AC600)
END_VAR