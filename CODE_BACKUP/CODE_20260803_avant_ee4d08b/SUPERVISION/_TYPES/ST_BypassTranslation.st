(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassTranslation — Bypass maintenance dédiés à Translation M3
   ───────────────────────────────────────────────────────────────
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive)).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassTranslation :
STRUCT
    (* 📡 1. Communication & Systèmes auxiliaires *)
    OperatorComm      : BOOL; (* 📡 Bypass communication esclave CANopen Joystick / heartbeat IHM *)
    DriveComm         : BOOL; (* 📡 Bypass diagnostic esclave EtherCAT AC600 (variateur) *)
    ContactorFeedback : BOOL; (* 🔌 Bypass feedbacks contacteur de frein *)
    PhaseRotation     : BOOL; (* ⚡ Bypass défaut rotation de phases (commun machine) *)
    BrakeThermal      : BOOL; (* 🌡️ Bypass surchauffe thermique frein (commun machine) *)

    (* 🚧 2. Limites physiques et Positionnement *)
    LimitSwitch       : BOOL; (* 🚧 Bypass fins de course physiques avant/arrière *)
    SensorIncoherent  : BOOL; (* 🧭 Bypass incohérence mot capteurs de position *)

    (* ⚙️ 3. Sécurité Mécanique (Méca A-B) *)
    MecaA             : BOOL; (* 🔄 Bypass Méca A : mouvement non commandé à l'arrêt *)
    MecaB             : BOOL; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)

    (* 🛡️ 4. Hiérarchie & Restauration *)
    Safety            : BOOL; (* 🛡️ Bypass groupé : tous les bits qui provoquent un PowerCutOff *)
    Process           : BOOL; (* ⚙️ Bypass groupé : tous les bits qui provoquent un SafeStop *)
    Global            : BOOL; (* 🌐 Bypass Global : ignore toutes les sécurités de cet axe *)
    // 🐛 FIX persistance (voir DOC/AUDITS/ConfigPersistence/) : flag restauration boot dédié
    // (défaut FALSE non ambigu, contrairement à une valeur métier) — PRG_SUPERVISION_CFC.st
    Initialized       : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
END_STRUCT
END_TYPE
