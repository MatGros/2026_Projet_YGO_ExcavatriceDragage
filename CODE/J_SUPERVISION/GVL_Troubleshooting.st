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
    LevageSynchroniseM1M2 : ST_ChainWinchSync;     // 🛗 1. Levage Synchronisé M1+M2 (Mode Couplé Nominal)
    LevageUnitaireM1      : ST_ChainWinch;         // 🛗 2. Levage Unitaire M1 (Treuil Retenue)
    LevageUnitaireM2      : ST_ChainWinch;         // 🛗 3. Levage Unitaire M2 (Treuil Benne)
    BenneOuvertureFermeture: ST_ChainBucket;        // 🪣 4. Ouverture / Fermeture Benne
    TranslationPontM3     : ST_ChainTranslation;   // ↔️ 5. Translation Pont M3 (Variateur AC600)
    AssistanceDragage     : ST_ChainDredgingAssist; // 🌊 5bis. Assistance Plongée/Extraction/Vidage Trémie
    CycleSemiAuto         : ST_ChainCycleSemiAuto;  // 🔄 6. Séquenceur de Cycle Semi-Automatique (X0 à X13)
    HomingM1              : ST_HomingChecklist;   (* 🎯 Diagnostic chronologique Homing M1 (Treuil Retenue) *)
    HomingM2              : ST_HomingChecklist;   (* 🎯 Diagnostic chronologique Homing M2 (Treuil Benne) *)
    Safety                : ST_SafetyChecklist;   (* 🛡️ Diagnostic chronologique Chaîne de Sécurité & Réarmement AU *)
    Joystick              : ST_JoystickChecklist; (* 🕹️ Diagnostic chronologique Bus CANopen & Homme-Mort Joystick *)
    MotionM1              : ST_MotionChecklist;   (* ⚙️ Diagnostic chronologique Mouvement M1 (Treuil Retenue) *)
    MotionM2              : ST_MotionChecklist;   (* ⚙️ Diagnostic chronologique Mouvement M2 (Treuil Benne) *)
    MotionM3              : ST_MotionChecklist;   (* ⚙️ Diagnostic chronologique Mouvement M3 (Translation) *)
    Inputs                : ST_HardwareImage;     (* 📥 Image complète des entrées réelles / qualifiées / simulées *)
END_VAR