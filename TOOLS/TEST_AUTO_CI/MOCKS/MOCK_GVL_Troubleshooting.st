(* =======================================================================
   🧪 MOCK_GVL_Troubleshooting — Miroir TESTABLE de la GVL_Troubleshooting
   ───────────────────────────────────────────────────────────────
   🎯 Pourquoi ce fichier existe (T371) : voir le bandeau détaillé de
      `TOOLS/TEST_AUTO_CI/MOCKS/MOCK_GVL_IHM.st` (même cause, même patron).
      En résumé : STruCpp v0.6.2 ne supporte pas le namespace GVL CODESYS ;
      `GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk` (écrit 469 fois
      par `FB_TroubleshootingView.st`) n'est résoluble que si `GVL_Troubleshooting`
      existe comme VARIABLE GLOBALE d'un STRUCT miroir — patron prouvé par sonde
      compilateur le 2026-09-21.

   ⚠️ FICHIER DE TEST — JAMAIS compilé dans CODESYS, JAMAIS importé :
      référencé uniquement par l'entrée `FB_TroubleshootingView` du registry CI.
   ⚠️ DETTE DÉCLARÉE : dérive possible si `GVL_Troubleshooting.st` change ->
      erreur de compilation du harnais (bruit), jamais un faux résultat silencieux.
   📄 Source de vérité transcrite : CODE/J_SUPERVISION/GVL_Troubleshooting.st
      (bloc VAR_GLOBAL, membres dans l'ordre du fichier source)
   ======================================================================= *)

TYPE ST_MockGvlTroubleshooting :
STRUCT
    A_ContexteMachineGlobal  : ST_ChainContextGlobal;   (* 0.  Contexte Global Machine *)
    B_Inputs                 : ST_HardwareImage;        (* 1.  Image complète des entrées *)
    C_Safety                 : ST_SafetyChecklist;      (* 2.  Chaîne de sécurité & réarmement AU *)
    D_Joystick               : ST_JoystickChecklist;    (* 3.  Bus CANopen & homme-mort joystick *)
    E_HomingM1               : ST_HomingChecklist;      (* 4.  Homing M1 *)
    F_HomingM2               : ST_HomingChecklist;      (* 5.  Homing M2 *)
    G_CycleSemiAuto          : ST_ChainCycleSemiAuto;   (* 6.  Séquenceur de cycle semi-auto *)
    H_LevageSynchroniseM1M2  : ST_ChainWinchSync;       (* 7.  Levage synchronisé M1+M2 *)
    I_LevageUnitaireM1       : ST_ChainWinch;           (* 8.  Levage unitaire M1 *)
    J_LevageUnitaireM2       : ST_ChainWinch;           (* 9.  Levage unitaire M2 *)
    K_BenneOuvertureFermeture: ST_ChainBucket;          (* 10. Ouverture / fermeture benne *)
    L_TranslationPontM3      : ST_ChainTranslation;     (* 11. Translation pont M3 *)
    N_MotionM1               : ST_MotionChecklist;      (* 13. Diagnostic mouvement M1 *)
    O_MotionM2               : ST_MotionChecklist;      (* 14. Diagnostic mouvement M2 *)
    P_MotionM3               : ST_MotionChecklist;      (* 15. Diagnostic mouvement M3 *)
    Q_TraceWinchM1           : ST_TraceWinch;           (* 16. Trace blocage M1 *)
    R_TraceWinchM2           : ST_TraceWinch;           (* 17. Trace blocage M2 *)
    S_TraceTranslation       : ST_TraceTranslation;     (* 18. Trace blocage M3 *)
    T_Permits                : ST_PermitVisibilityHMI;  (* Vue unique des permis *)
END_STRUCT
END_TYPE

VAR_GLOBAL
    GVL_Troubleshooting : ST_MockGvlTroubleshooting;   // Miroir testable de la GVL de production
END_VAR
