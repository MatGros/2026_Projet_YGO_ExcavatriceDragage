(* ═══════════════════════════════════════════════════════════════
   🚦 ST_TranslationState — États et retours IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des retours et mesures de la translation M3.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationState :
STRUCT
    (* 🚦 États & diagnostics FB_Translation *)
    FBState                 : E_State; (* 🤖 État de l'automate interne (FB_Translation) *)
    AxisBlockReason         : E_TranslationTraceBlockReason; (* 🧩 Cause prioritaire de blocage (miroir de TranslationTrace.BlockReason) *)
    Ready                   : BOOL;    (* 🟢 Translation prêt à fonctionner *)
    Busy                    : BOOL;    (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;    (* ✅ Mouvement terminé avec succès *)
    Error                   : BOOL;    (* Translation en défaut *)
    ErrorId                 : WORD;    (* ❌ Code du défaut actif *)
    BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein (lecture seule, TRUE = desserré) *)
    BrakeFeedback           : BOOL;    (* 🔌 Retour physique direct : TRUE = frein OUVERT (desserré) *)
    PositionSensorTarget    : BOOL;    (* 🎯 Capteur de détection de la position cible atteint *)
    PositionReached         : BOOL;    (* ✅ Positionneur : cible sélectionnée atteinte (non mémorisé) *)
    DriveActualFreq_Hz      : REAL;    (* 📈 Fréquence de sortie réelle du variateur (Hz) *)
    DriveControlWord        : WORD;    (* ⚙️ Mot de commande AC600 réellement appliqué *)
    DriveFreqCmd_Hz         : REAL;    (* 🎯 Commande fréquence réellement appliquée *)
    ActiveTremie            : BOOL;    (* ↔️ Commande active vers Trémie *)
    ActiveMaintenance       : BOOL;    (* ↔️ Commande active vers Maintenance *)
    SpeedCmd_Pct            : REAL;    (* 📊 Commande active après arbitrage (0.0 à 100.0 %) *)
    FinalInterlockState     : E_State; (* 🛡️ État final lecture seule *)
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
    AtTremie                : BOOL;    (* jeton "dernier capteur franchi" (front + libération sur mouvement confirmé) — logique de positionnement *)
    AtPV                    : BOOL;
    AtP2                    : BOOL;
    AtP1                    : BOOL;
    AtMaintenance           : BOOL;
    (* T249-B : "at position" par PLAGE = capteur ON ET position estimée à ±0.5 m du point calibré.
       Fiable sans dépendance à la fréquence variateur (contrairement à AtXxx). Affichage IHM. *)
    AtBandTremie            : BOOL;
    AtBandPV                : BOOL;
    AtBandP2                : BOOL;
    AtBandP1                : BOOL;
    AtBandMaintenance       : BOOL;
    M3StatusText            : STRING(80);  (* Texte statut position M3 (INFO, lecture seule) — ex "M3 au capteur P1 -> Maintenance", "M3 entre P2 et P1" *)
    EstimatedPosM3_M        : REAL;    (* 📏 Position continue estimée en mètres (0.0 m Maint -> +X m Trémie) — persistante, survit reboot *)
    SensorsWord             : BYTE;    (* bit4=Trémie, bit3=PV, bit2=P2, bit1=P1, bit0=Maintenance *)
    SensorWordIncoherent    : BOOL;
    LimitSwitchTremie       : BOOL;    (* 🚧 Fin de course extrême Trémie (ex-LimitSwitchFwd) *)
    LimitSwitchMaintenance  : BOOL;    (* 🚧 Fin de course extrême Maintenance (ex-LimitSwitchRev) *)
    DriveThermalOk          : BOOL;    (* Retour disjoncteur thermique moteur/variateur AC600 — diagnostic seul, l'AC600 se protège lui-même *)
    MaintenanceTargetEnable : BOOL;    (* 🔓 TRUE = Autorise le déplacement vers la cible 4 (Maintenance) ; actif uniquement en mode MAINT_N2 *)
    SimulationModeActive    : BOOL;
    HeightInterlockBlocking : BOOL;    (* : TRUE = translation bloquée, M1 ou M2 sous la hauteur mini requise *)
END_STRUCT
END_TYPE
