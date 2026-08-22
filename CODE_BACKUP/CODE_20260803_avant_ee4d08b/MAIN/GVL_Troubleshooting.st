(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ GVL_Troubleshooting — GVL Globale de Recherche de Pannes (Orientée Fonctions & Contexte)
   ───────────────────────────────────────────────────────────────
   ⚙️ Emplacement : CODE/MAIN/GVL_Troubleshooting.st
   🎨 Structurée par CONTEXTE GLOBAL MACHINE + FONCTIONS MÉTIER (Utilisation Opérateur).
   💬 Permet de localiser en 3 secondes l'environnement et le blocage d'une action.
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    ContexteMachineGlobal : ST_ChainContextGlobal; // 🌐 0. Contexte Global Machine (Mode, Simu, Commande, Bypass)
    LevageSynchroniseM1M2 : ST_ChainWinchSync;     // 🛗 1. Levage Synchronisé M1+M2 (Mode Couplé Nominal)
    LevageUnitaireM1      : ST_ChainWinch;         // 🛗 2. Levage Unitaire M1 (Treuil Retenue)
    LevageUnitaireM2      : ST_ChainWinch;         // 🛗 3. Levage Unitaire M2 (Treuil Benne)
    BenneOuvertureFermeture: ST_ChainBucket;        // 🪣 4. Ouverture / Fermeture Benne
    TranslationPontM3     : ST_ChainTranslation;   // ↔️ 5. Translation Pont M3 (Variateur AC600)
END_VAR