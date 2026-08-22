(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_SafetyTranslation — Diagnostics de sécurité pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des défauts de sécurité du translation.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SafetyTranslation :
STRUCT
    Error             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    ErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité *)
    ErrorOperatorComm : BOOL;    (* 🎮 Perte communication opérateur : joystick CAN ou heartbeat IHM (bit0) *)
    ErrorDriveComm    : BOOL;    (* 📡 Perte communication EtherCAT variateur (bit1) *)
    ErrorPhaseRotation: BOOL;    (* ⚡ Mauvaise rotation de phases électriques (bit2) *)
    ErrorBrakeThermal : BOOL;    (* 🌡️ Surchauffe thermique frein commun (bit3) *)
    ErrorMecaB        : BOOL;    (* 🛑 Absence confirmation arrêt (Méca B - bit4) *)
    ErrorMecaA        : BOOL;    (* 🔄 Mouvement non commandé (Méca A - bit5) *)
    ErrorLimitSwitch  : BOOL;    (* 🚧 Limite extrême Translation atteinte (bit6) *)
    ErrorSensorIncoherent : BOOL; (* 🧭 Mot capteurs M3 incohérent (bit7) *)
    SafeStop          : BOOL;    (* 🛡️ Décélération de sécurité demandée *)
    PowerCutOff       : BOOL;    (* 🧨 Coupure puissance demandée *)
END_STRUCT
END_TYPE
