(* ═══════════════════════════════════════════════════════════════
   🚦 ST_TranslationState — États et retours IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des retours et mesures de la translation M3.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationState :
STRUCT
    (* 🚦 États & diagnostics FB_Translation *)
    FBState                 : E_State; (* 🤖 État de l'automate interne (FB_Translation) *)
    Ready                   : BOOL;    (* 🟢 Translation prêt à fonctionner *)
    Busy                    : BOOL;    (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;    (* ✅ Mouvement terminé avec succès *)
    Error                   : BOOL;    (* Translation en défaut *)
    ErrorId                 : WORD;    (* ❌ Code du défaut actif *)
    BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein (lecture seule, TRUE = desserré) *)
    BrakeFeedback           : BOOL;    (* 🔌 Retour physique direct : TRUE = frein OUVERT (desserré) *)
    PositionSensorTarget    : BOOL;    (* 🎯 Capteur de détection de la position cible atteint *)
    PositionReached         : BOOL;    (* ✅ Positionneur : cible sélectionnée atteinte (non mémorisé) *)
    JoystickDeflection_Pct  : REAL;    (* 🕹️ Axe X fonctionnel -100..+100 %, 0 = neutre ; animation IHM M3 *)
    DriveActualFreq_Hz      : REAL;    (* 📈 Fréquence de sortie réelle du variateur (Hz) *)
    DriveControlWord        : WORD;    (* ⚙️ Mot de commande AC600 réellement appliqué *)
    DriveFreqRef_Hz         : REAL;    (* 🎯 Consigne fréquence réellement appliquée *)
    ActiveDirection         : INT;     (* ↔️ Sens arbitré : -1 / 0 / +1 *)
    ActiveSpeedRef_Pct      : REAL;    (* 📊 Consigne active après arbitrage *)
    FinalInterlockState     : E_State; (* 🛡️ État final _LD lecture seule *)
    FinalInterlockReason    : E_TranslationFinalInterlockReason; (* 🛡️ Cause finale mémorisée *)
    FinalInterlockError     : BOOL;    (* 🛡️ Défaut final mémorisé *)
    FinalInterlockErrorId   : WORD;    (* 🛡️ Bitfield final *)
    BrakeCommandOpenConfirmed : BOOL;  (* 🔌 Contacteur/bobine desserrage confirmé, pas frein mécanique *)
    FinalBrakeTimeoutElapsed : TIME;   (* ⏱️ Écoulé watchdog 500ms *)

    (* 🔌 Diagnostic variateur EtherCAT (décodé — pas de bit-masking côté IHM) *)
    DriveCommReady          : BOOL;    (* 📡 Variateur M3 : communication prête (StatusWord bit7) *)
    DrivePowerReady         : BOOL;    (* ⚡ Variateur M3 : puissance prête (StatusWord bit0) *)

    (* 📍 Mot capteurs et positions Translation M3 *)
    PositionTremie          : BOOL;
    PositionPV              : BOOL;
    PositionP2              : BOOL;
    PositionP1              : BOOL;
    PositionMaintenance     : BOOL;
    (* : mot EXACT — front franc arrivée/cible (voir PositionXxx ci-dessus = cumulatif zone, réservé ralentissement) *)
    AtTremie                : BOOL;
    AtPV                    : BOOL;
    AtP2                    : BOOL;
    AtP1                    : BOOL;
    AtMaintenance           : BOOL;
    EstimatedPosM3_M        : REAL;    (* 📏 Position continue estimée en mètres (0.0 m Maint -> +X m Trémie) — persistante, survit reboot *)
    SensorsWord             : BYTE;    (* bit4=Trémie, bit3=PV, bit2=P2, bit1=P1, bit0=Maintenance *)
    SensorWordIncoherent    : BOOL;
    LimitSwitchFwd          : BOOL;
    LimitSwitchRev          : BOOL;
    DriveThermalOk          : BOOL;    (* Retour disjoncteur thermique moteur/variateur AC600 — diagnostic seul, l'AC600 se protège lui-même *)
    MaintenanceTargetEnable : BOOL;    (* 🔓 TRUE = Autorise le déplacement vers la cible 4 (Maintenance) ; actif uniquement en mode MAINT_N2 *)
    SimulationModeActive    : BOOL;
    HeightInterlockBlocking : BOOL;    (* : TRUE = translation bloquée, M1 ou M2 sous la hauteur mini requise *)
END_STRUCT
END_TYPE
