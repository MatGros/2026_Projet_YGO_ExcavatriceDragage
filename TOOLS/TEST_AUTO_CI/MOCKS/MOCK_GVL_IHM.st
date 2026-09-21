(* =======================================================================
   🧪 MOCK_GVL_IHM — Miroir TESTABLE de la GVL_IHM (harnais CI uniquement)
   ───────────────────────────────────────────────────────────────
   🎯 Pourquoi ce fichier existe (T371) :
      STruCpp v0.6.2 ne supporte PAS le namespace GVL de CODESYS. Une GVL
      `VAR_GLOBAL` déclare ses membres comme des variables GLOBALES PLATES :
      `GVL_IHM.Modes.Cmd.X` n'est donc pas résoluble, alors que c'est
      exactement ce que fait le code de production (CODESYS, où le nom de la
      GVL EST un espace de noms).
      Sonde compilateur (2026-09-21) : `VAR_GLOBAL Foo:INT;` + `GVL_T.Foo`
      -> "error: Undeclared variable 'GVL_T'" ; accès direct `Foo` -> OK ;
      `GVL_T` déclaré comme VARIABLE d'un STRUCT miroir -> OK.

   🔧 Principe : `GVL_IHM` est déclarée ici comme une VARIABLE GLOBALE d'un
      STRUCT MIROIR dont les membres sont la TRANSCRIPTION EXACTE de la liste
      de membres de `CODE/J_SUPERVISION/GVL_IHM.st`. Le code de production
      (`GVL_IHM.<membre>`) devient alors résoluble à l'identique.

   ⚠️ FICHIER DE TEST — JAMAIS compilé dans CODESYS, JAMAIS importé :
      il n'est référencé que par l'entrée `FB_TroubleshootingView` de
      `TOOLS/TEST_AUTO_CI/scripts/config/registry.yaml`.
   ⚠️ DETTE DÉCLARÉE : ce miroir peut dériver si `GVL_IHM.st` change. Une
      dérive produit une ERREUR DE COMPILATION du harnais (bruit), jamais un
      faux résultat silencieux. Toute évolution de `GVL_IHM.st` doit être
      répercutée ici.
   📄 Source de vérité transcrite : CODE/J_SUPERVISION/GVL_IHM.st:8-24
   ======================================================================= *)

TYPE ST_MockGvlIHM :
STRUCT
    M1TreuilRetenue    : ST_WinchHMI;               (* GVL_IHM.st:8  *)
    M2TreuilBenne      : ST_WinchBenneHMI;          (* GVL_IHM.st:9  — porte Bucket *)
    M1M2Sync           : ST_SyncHMI;                (* GVL_IHM.st:10 *)
    JOY1Joystick       : ST_JoystickHMI;            (* GVL_IHM.st:11 *)
    Modes              : ST_ModesHMI;               (* GVL_IHM.st:12 *)
    Emergency          : ST_EmergencyHMI;           (* GVL_IHM.st:13 *)
    M3Translation      : ST_TranslationHMI;         (* GVL_IHM.st:14 *)
    CycleSemiAuto      : ST_CycleHMI;               (* GVL_IHM.st:15 *)
    CycleMachineHoming : ST_CycleMachineHomingHMI;  (* GVL_IHM.st:16 *)
    Banner             : ST_HmiBanner;              (* GVL_IHM.st:17 *)
    Network            : ST_NetworkDiagHMI;         (* GVL_IHM.st:18 *)
    Commun             : ST_CommunHMI;              (* GVL_IHM.st:19 *)
    LocalIHM           : ST_LocalIHM;               (* GVL_IHM.st:20 *)
    IoHw               : ST_IoHw;                   (* GVL_IHM.st:21 *)
    HmiInitDone        : BOOL;                      (* GVL_IHM.st:22 *)
    Permits            : ST_PermitVisibilityHMI;    (* GVL_IHM.st:23 *)
    MaintenanceN2      : ST_MaintenanceN2HMI;       (* GVL_IHM.st:24 *)
END_STRUCT
END_TYPE

VAR_GLOBAL
    GVL_IHM : ST_MockGvlIHM;   // Miroir testable de la GVL de production (voir bandeau)
END_VAR
