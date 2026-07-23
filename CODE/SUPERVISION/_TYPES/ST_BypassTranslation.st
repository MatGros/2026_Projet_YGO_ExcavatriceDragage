(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassTranslation — Bypass maintenance dédiés à Translation M3
   ───────────────────────────────────────────────────────────────
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassTranslation :
STRUCT
    (* 🔌 Bypass retour contacteur frein (existant) *)
    ContactorFeedback : BOOL;

    (* 🧭 Bypass mot capteurs M3 incohérent *)
    SensorIncoherent : BOOL;

    (* 🚧 Bypass butées extrêmes (LimitSwitchFwd / LimitSwitchRev) *)
    LimitSwitch : BOOL;

    (* 📡 Bypass perte communication opérateur (joystick CAN / heartbeat IHM) *)
    OperatorComm : BOOL;

    (* 📡 Bypass perte communication drive (EtherCAT) *)
    DriveComm : BOOL;

    (* ⚡ Bypass défaut rotation de phases *)
    PhaseRotation : BOOL;

    (* 🌡️ Bypass surchauffe frein *)
    BrakeThermal : BOOL;

    (* 🛑 Bypass Méca B (absence confirmation arrêt) *)
    MecaB : BOOL;

    (* 🔄 Bypass Méca A (mouvement non commandé) *)
    MecaA : BOOL;

    (* 🌐 Bypass GLOBAL : désactive TOUTES les surveillances Safety Translation M3
       ⚠️ Prioritaire sur les bypass individuels ci-dessus *)
    Global : BOOL;
END_STRUCT
END_TYPE
