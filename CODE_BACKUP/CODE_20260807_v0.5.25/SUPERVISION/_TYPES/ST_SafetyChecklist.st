(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_SafetyChecklist — Diagnostic chronologique réarmement chaîne de sécurité / AU
   ───────────────────────────────────────────────────────────────
   🎨 Permet d'identifier immédiatement pourquoi la puissance / AU ne réarme pas.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SafetyChecklist :
STRUCT
    (* 1. Intégrité matérielle & modules E/S *)
    Step1_InputModulesOk         : BOOL; (* TRUE = Les 3 cartes E/S physiques sont RUNNING ➔ En simu : GVL_Simulation.SimMachineActive=1 *)
    Step2_EmergencyBtnNotCut     : BOOL; (* TRUE = Pas d'appui AU ➔ Déverrouiller le BP coup-de-poing physique ou IHM : GVL_IHM.Modes.Cmd.BtnEmergencyCutOff *)
    Step3_EmergencyChainClosed   : BOOL; (* TRUE = Boucle physique AU fermée (EmergencyChainClosed_DI) *)

    (* 2. Conditions de réarmement *)
    Step4_ContactorRedundancyOk  : BOOL; (* TRUE = Test de redondance contacteurs OK ➔ Attendre la retombée complète des contacteurs *)
    Step5_ArmingAllowed          : BOOL; (* TRUE = Machine armable ➔ Appuyer sur BP Reset IHM : GVL_IHM.Modes.Cmd.BtnFaultReset *)

    (* 3. Séquence de réarmement *)
    ArmingPulseActive            : BOOL; (* TRUE = Impulsion d'armement 500ms en cours *)
    PowerContactorEngaged        : BOOL; (* TRUE = Contacteur principal sous tension (PowerContactorEngaged_DI) *)
    AllConditionsMet             : BOOL; (* TRUE = Chaîne de sécurité OK et puissance engagée *)

    (* 4. Erreurs *)
    SafetyError                  : BOOL; (* TRUE = Défaut sécurité actif ➔ Acquitter via : GVL_IHM.Modes.Cmd.BtnFaultReset *)
    RedundancyTestFailed         : BOOL; (* TRUE = Défaut test de redondance contacteurs *)
    ArmingFailed                 : BOOL; (* TRUE = Échec de la séquence d'armement *)
END_STRUCT
END_TYPE
