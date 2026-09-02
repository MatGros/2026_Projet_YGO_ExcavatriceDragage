(* ═══════════════════════════════════════════════════════════════
   🎯 ST_HomingChecklist — Diagnostic chronologique de référencement (Dépannage)
   ───────────────────────────────────────────────────────────────
   🎨 Permet de localiser immédiatement l'étape qui bloque le Homing (M1/M2).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HomingChecklist :
STRUCT
    (* 1. Pré-requis de mode *)
    Step1_ModeAuthorized         : BOOL; (* TRUE = Mode MAINT_N1 ou MAINT_N2 actif ➔ Commutateur Mode IHM : GVL_IHM.Modes *)
    Step2_WinchSelected          : BOOL; (* TRUE = Treuil sélectionné en MAINT_N2 ➔ Bouton IHM : GVL_IHM.Modes.Cmd.TglJoystickMaster / Selection Treuil *)

    (* 2. Santé Matériel & Bus *)
    Step3_EncoderAvailable       : BOOL; (* TRUE = Codeur EtherCAT OK & E/S OK ➔ Si simu : GVL_Simulation.SimWinchActive=1 / SimSafetyActive=1 *)

    (* 2bis. Entrées physiques directes HwIn (vérité terrain) *)
    HwIn_ContactorsReleased_DI   : BOOL; (* Retours contacteurs retombés issus de HwIn.Winch *)
    HwIn_BrakeIsOpen_DI          : BOOL; (* Retour fin de course frein (1 = ouvert) issu de HwIn.Winch *)
    HwIn_TopPositionFree_DI      : BOOL; (* Capteur position haute commun libre (1 = libre) issu de HwIn.Winch *)

    (* 3. État Physique Machine *)
    Step4_ContactorsReleased     : BOOL; (* TRUE = Tous les contacteurs retombés (attendre l'arrêt complet) *)
    Step5_BrakeApplied           : BOOL; (* TRUE = Frein serré (attendre l'arrêt complet) *)
    TopPositionSensorActive      : BOOL; (* 📍 Fin de course haut physique (TRUE = au contact) *)
    BucketIsOpen                 : BOOL; (* 🪣 Benne Ouvert (TRUE = Ouvert) ➔ Pour forcer sans codeur : GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos *)

    (* 4. Séquence & Bilan *)
    AllConditionsMet             : BOOL; (* TRUE = Prêt pour le homing ! ➔ Déclencher : GVL_IHM.M1TreuilRetenue.Cmd.BtnHome (à 8m) ou BtnHomingAtZero (à 0m) *)
    HomingBusy                   : BOOL; (* TRUE = Séquence de calage en cours *)
    HomingDone                   : BOOL; (* TRUE = Calage réussi *)
    HomingHomed                  : BOOL; (* TRUE = Treuil actuellement référencé *)
    HomingSuspect                : BOOL; (* TRUE = Doute redémarrage ➔ Lever le doute via : GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence *)

    (* 5. Code de rejet exact *)
    RejectErrorMask              : WORD; (* Bitmask d'erreur FB_Encoder_Homing.ErrorId *)
END_STRUCT
END_TYPE
