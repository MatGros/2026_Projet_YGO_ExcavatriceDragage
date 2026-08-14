(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_JoystickChecklist — Diagnostic chronologique communication & prise en main Joystick
   ───────────────────────────────────────────────────────────────
   🎨 Permet de vérifier la chaîne Joystick (CANopen, Homme-mort, Neutre, Calibration).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickChecklist :
STRUCT
    (* 1. Bus & Matériel *)
    Step1_CanBusActive           : BOOL; (* TRUE = Bus CANopen en état ACTIVE *)
    Step2_JoystickOperational    : BOOL; (* TRUE = Esclave JOY1 en état RUNNING *)

    (* 1bis. Entrées physiques directes HwIn *)
    HwIn_JoyBtnRaw_DI            : BOOL; (* Bouton brut homme-mort issu de HwIn.Operator *)
    NeutralXAct                  : BOOL; (* TRUE = Axe X au neutre (PRG_02_Acquisition.JoystickXNeutral) *)
    NeutralYAct                  : BOOL; (* TRUE = Axe Y au neutre (PRG_02_Acquisition.JoystickYNeutral) *)

    (* 2. Prise en main & Sécurité *)
    Step3_DeadmanPressed         : BOOL; (* TRUE = Bouton Homme-Mort appuyé *)
    Step4_NeutralAcquired        : BOOL; (* TRUE = Repassé par le neutre (autorisation mouvement) *)

    (* 3. Éligibilité globale *)
    AllConditionsMet             : BOOL; (* TRUE = Joystick prêt pour piloter un axe *)
    JoystickSelected             : BOOL; (* TRUE = Joystick maître sélectionné IHM *)

    (* 4. Mesures brutes & Filtrées *)
    RawX                         : INT;  (* Valeur brute axe X (0..10000) *)
    RawY                         : INT;  (* Valeur brute axe Y (0..10000) *)
    DeflectionX_Pct              : REAL; (* Déflexion signée X (%) *)
    DeflectionY_Pct              : REAL; (* Déflexion signée Y (%) *)
END_STRUCT
END_TYPE
