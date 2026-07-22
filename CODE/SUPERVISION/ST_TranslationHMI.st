(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationHMI — Données d'échange IHM pour le Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des états, commandes et diagnostics du translation.
   📄 Migration des champs manuels ex-ST_IHM_MANU terminée (2026-07-19, suppression IHM_MANU) —
      doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.9.md
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationHMI :
STRUCT
    (* 🎮 Commandes opérateur (manuel / maintenance) *)
    PositioningSelect       : BOOL;    (* 🎯 TRUE = positionneur sur SelectedTargetNum ; FALSE = jog libre *)
    SelectedTargetNum       : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    ReqFwd                  : BOOL;    (* ↔️ Requête marche avant manuelle (bouton IHM, pas encore arbitrée) *)
    ReqRev                  : BOOL;    (* ↔️ Requête marche arrière manuelle (bouton IHM, pas encore arbitrée) *)
    FreqSetpointHz           : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], limitée par PRG_10_Outputs *)
    JoystickSelect          : BOOL;    (* 🕹️ TRUE = joystick, FALSE = boutons ReqFwd/ReqRev *)

    (* 🚦 États & diagnostics FB_Translation *)
    FBState                 : E_State; (* 🤖 État de l'automate interne (FB_Translation) *)
    Ready                   : BOOL;    (* 🟢 Translation prêt à fonctionner *)
    Busy                    : BOOL;    (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;    (* ✅ Mouvement terminé avec succès *)
    Error                   : BOOL;    (* 🔴 Translation en défaut *)
    ErrorId                 : WORD;    (* ❌ Code du défaut actif *)
    BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein (lecture seule, TRUE = desserré) *)
    BrakeFeedback           : BOOL;    (* 🔌 Retour physique de l'état du frein *)
    PositionSensorTarget    : BOOL;    (* 🎯 Capteur de détection de la position cible atteint *)
    PositionReached         : BOOL;    (* ✅ Positionneur : cible sélectionnée atteinte (non mémorisé) *)
    JoystickDeflectionPct   : REAL;    (* 🕹️ Axe X fonctionnel -100..+100 %, 0 = neutre ; animation IHM M3 *)
    DriveActualFreqHz        : REAL;    (* 📈 Fréquence de sortie réelle du variateur (Hz) *)
    DriveControlWord        : WORD;    (* ⚙️ Mot de commande AC600 réellement appliqué *)
    DriveFreqRefHz           : REAL;    (* 🎯 Consigne fréquence réellement appliquée *)
    ActiveDirection          : INT;     (* ↔️ Sens arbitré : -1 / 0 / +1 *)
    ActiveSpeedRefPct         : REAL;    (* 📊 Consigne active après arbitrage *)

    (* 🔌 Diagnostic variateur EtherCAT (décodé — pas de bit-masking côté IHM) *)
    DriveCommReady          : BOOL;    (* 📡 Variateur M3 : communication prête (StatusWord bit7) *)
    DrivePowerReady         : BOOL;    (* ⚡ Variateur M3 : puissance prête (StatusWord bit0) *)

    (* 🐞 Bypass diag (banc de test — auto-calculé depuis GVL_Simulation) *)
    BypassContactorFeedback : BOOL;    (* 🔌 Activation du bypass des retours contacteurs (sens + frein) *)

    (* 📍 Mot capteurs et positions Translation M3 *)
    PositionTremie          : BOOL;
    PositionPV              : BOOL;
    PositionP2              : BOOL;
    PositionP1              : BOOL;
    PositionMaintenance     : BOOL;
    SensorsWord              : BYTE;   (* bit4=Trémie, bit3=PV, bit2=P2, bit1=P1, bit0=Maintenance *)
    SensorWordIncoherent    : BOOL;
    LimitSwitchFwd          : BOOL;
    LimitSwitchRev          : BOOL;
    MaintenanceTargetEnable : BOOL;
    SimulationModeActive    : BOOL;

    (* 🧪 Commandes de test Translation, actives uniquement sur banc *)
    TestSensorsWordActive   : BOOL;
    TestSensorsWord         : BYTE;
    TestAtTremie             : BOOL;
    TestBrakeStuckOpen       : BOOL;
    TestPhantomFreq         : BOOL;

    (* 🛡️ Sécurité (FB_Safety_Translation) *)
    SafetyError             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité *)
    SafetyErrorOperatorComm : BOOL;    (* 🎮 Perte communication opérateur : joystick CAN ou heartbeat IHM (bit0) *)
    SafetyErrorDriveComm    : BOOL;    (* 📡 Perte communication EtherCAT variateur (bit1) *)
    SafetyErrorPhaseRotation: BOOL;    (* ⚡ Mauvaise rotation de phases électriques (bit2) *)
    SafetyErrorBrakeThermal : BOOL;    (* 🌡️ Surchauffe thermique frein commun (bit3) *)
    SafetyErrorMecaB        : BOOL;    (* 🛑 Absence confirmation arrêt (Méca B - bit4) *)
    SafetyErrorMecaA        : BOOL;    (* 🔄 Mouvement non commandé (Méca A - bit5) *)
    SafetyErrorLimitSwitch  : BOOL;    (* 🚧 Limite extrême Translation atteinte (bit6) *)
    SafetyErrorSensorIncoherent : BOOL; (* 🧭 Mot capteurs M3 incohérent (bit7) *)
    SafetySafeStop         : BOOL;    (* 🛡️ Décélération de sécurité demandée *)
    SafetyPowerCutOff      : BOOL;    (* 🧨 Coupure puissance demandée *)
END_STRUCT
END_TYPE
