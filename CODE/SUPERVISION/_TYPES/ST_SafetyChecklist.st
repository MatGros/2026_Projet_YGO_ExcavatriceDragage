(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_SafetyChecklist — Diagnostic chronologique réarmement chaîne de sécurité / AU
   ───────────────────────────────────────────────────────────────
   🎨 Permet d'identifier immédiatement pourquoi la puissance / AU ne réarme pas.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SafetyChecklist :
STRUCT
    (* 0. Aiguillage source — dit QUELLE entree alimente les steps 1-3 ci-dessous.
       Absent jusqu'ici : diagnostiquer un blocage AU en full simu obligeait a rouvrir
       GVL_Simulation dans un Watch separe (REX 2026-08-14, banc sans HW). *)
    SimulationModeActive         : BOOL; (* TRUE = bit maitre simu actif (GVL_Simulation.SimulationModeActive) *)
    SimSafetyActive              : BOOL; (* TRUE = domaine Safety simule ➔ Step1-3 lisent FB_Sim_Safety, pas les DI/comm reelles *)

    (* 1. Intégrité matérielle & modules E/S *)
    Step1_InputModulesOk         : BOOL; (* TRUE = Les 3 cartes E/S physiques sont RUNNING ➔ En simu : GVL_Simulation.SimSafetyActive=1 *)
    Step2_EmergencyBtnNotCut     : BOOL; (* TRUE = Pas d'appui AU ➔ Déverrouiller le BP coup-de-poing physique ou IHM : GVL_IHM.Modes.Cmd.BtnEmergencyCutOff *)
    Step3_EmergencyChainClosed   : BOOL; (* TRUE = Boucle physique AU fermée (EmergencyChainClosed_DI) *)

    (* 2. Conditions de réarmement *)
    Step4_ContactorReleased      : BOOL; (* TRUE = Contacteur relâché ; précondition AF01 avant réarmement *)
    Step5_ArmingAllowed          : BOOL; (* TRUE = Armable ; acquitter si nécessaire puis générer un front BtnEmergencyArming *)

    (* 3. Séquence de réarmement *)
    ArmingStep                   : INT;  (* 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm *)
    ArmingPulseActive            : BOOL; (* TRUE = Impulsion d'armement en cours *)
    ArmingBusy                   : BOOL; (* TRUE = séquence de réarmement ou verrouillage en cours *)
    LockoutActive                : BOOL; (* TRUE = verrouillage temporel entre tentatives *)
    PowerContactorEngaged        : BOOL; (* TRUE = Contacteur principal sous tension (PowerContactorEngaged_DI) *)
    PowerCutOffActive            : BOOL; (* TRUE = demande de coupure safety active *)
    MaintainAActive              : BOOL; (* TRUE = maintien voie A demandé *)
    MaintainBActive              : BOOL; (* TRUE = maintien voie B demandé *)
    AllConditionsMet             : BOOL; (* TRUE = état final : chaîne OK et puissance engagée *)

    (* 4. Erreurs *)
    SafetyError                  : BOOL; (* TRUE = Défaut sécurité actif *)
    ArmingErrorId               : WORD; (* bit0 redondance ; bit1 échec confirmation contacteur *)
    RedundancyTestFailed         : BOOL; (* TRUE = Défaut test de redondance contacteurs *)
    ArmingFailed                 : BOOL; (* TRUE = Échec de la séquence d'armement *)
END_STRUCT
END_TYPE
