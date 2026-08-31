(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ GVL_Troubleshooting — GVL Globale de Recherche de Pannes (Orientée Fonctions & Contexte)
   ───────────────────────────────────────────────────────────────
   ⚙️ Emplacement : CODE/J_SUPERVISION/GVL_Troubleshooting.st
   🎨 Structurée par CONTEXTE GLOBAL MACHINE + FONCTIONS MÉTIER (Utilisation Opérateur).
   💬 Permet de localiser en 3 secondes l'environnement et le blocage d'une action.
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    ContexteMachineGlobal : ST_ChainContextGlobal; // 🌐 0. Contexte Global Machine (Mode, Simu, Commande, Bypass)
    Inputs                : ST_HardwareImage;     // 📥 1. Image complète des entrées réelles / qualifiées / simulées
    Safety                : ST_SafetyChecklist;   // 🛡️ 2. Diagnostic chronologique Chaîne de Sécurité & Réarmement AU
    Joystick              : ST_JoystickChecklist; // 🕹️ 3. Diagnostic chronologique Bus CANopen & Homme-Mort Joystick
    HomingM1              : ST_HomingChecklist;   // 🎯 4. Diagnostic chronologique Homing M1 (Treuil Retenue)
    HomingM2              : ST_HomingChecklist;   // 🎯 5. Diagnostic chronologique Homing M2 (Treuil Benne)
    CycleSemiAuto         : ST_ChainCycleSemiAuto;  // 🔄 6. Séquenceur de Cycle Semi-Automatique (X0 à X13)
    LevageSynchroniseM1M2 : ST_ChainWinchSync;     // 🛗 7. Levage Synchronisé M1+M2 (Mode Couplé Nominal)
    LevageUnitaireM1      : ST_ChainWinch;         // 🛗 8. Levage Unitaire M1 (Treuil Retenue)
    LevageUnitaireM2      : ST_ChainWinch;         // 🛗 9. Levage Unitaire M2 (Treuil Benne)
    BenneOuvertureFermeture: ST_ChainBucket;        // 🪣 10. Ouverture / Fermeture Benne
    TranslationPontM3     : ST_ChainTranslation;   // ↔️ 11. Translation Pont M3 (Variateur AC600)
    AssistanceDragage     : ST_ChainDredgingAssist; // 🌊 12. Assistance Plongée/Extraction/Vidage Trémie
    MotionM1              : ST_MotionChecklist;   // ⚙️ 13. Diagnostic chronologique Mouvement M1 (Treuil Retenue)
    MotionM2              : ST_MotionChecklist;   // ⚙️ 14. Diagnostic chronologique Mouvement M2 (Treuil Benne)
    MotionM3              : ST_MotionChecklist;   // ⚙️ 15. Diagnostic chronologique Mouvement M3 (Translation)

    // 🕵️ Trace de blocage terrain (cause priorisée + horodatage) — produite par PRG_04/05
    TraceWinchM1          : ST_TraceWinch;        // 🕵️ 16. Trace blocage treuil M1 (cause priorisée + horodatage)
    TraceWinchM2          : ST_TraceWinch;        // 🕵️ 17. Trace blocage treuil M2 (cause priorisée + horodatage)
    TraceTranslation      : ST_TraceTranslation;  // ↔️ 18. Trace blocage translation M3 (cause priorisée + horodatage)
END_VAR
