(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_SafetyWinch — Diagnostics de sécurité pour un treuil
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des défauts de sécurité d'un treuil.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SafetyWinch :
STRUCT
    Error             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    ErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité (vue LIVE) *)
    LatchedId         : WORD;    (* 🕘 Vue LATCHÉE : ErrorId figé au défaut, effacé au Reset (marqueur [HISTO]) *)
    SafeStop          : BOOL;    (* 🟧 Arrêt rapide activé par la sécurité *)
    DescendPermit     : BOOL;    (* 🟢 Descending autorisée (TRUE = OK | FALSE = mou de câble / limite basse) *)
    AscentPermit      : BOOL;    (* 🟢 Ascending autorisée (TRUE = OK | FALSE = fin de course haut) *)
    SlackCable        : BOOL;    (* ⚠️ Mou de câble physiquement détecté *)
    ThermalFault      : BOOL;    (* 🔥 Surchauffe thermique moteur *)
    EncoderFault      : BOOL;    (* 🔌 Perte de liaison ou incohérence codeur *)
    BypassActive      : BOOL;    (* Bypass codeur effectivement accepté, uniquement MAINT_N2 *)
    CableLimitDescent : BOOL;    (* ⚠️ Longueur max de câble atteinte (limite basse physique) *)
    CableLimitAscent  : BOOL;    (* ⚠️ Limite haute d'exploitation normale atteinte *)
    MecaADrift_M      : REAL;    (* 📐 Dérive mesurée Méca A (m) *)
    MecaCDrift_M      : REAL;    (* 📐 Dérive mesurée Méca C (m) *)
    MecaBElapsedTime  : TIME;    (* ⏳ Temps écoulé confirmation contacteurs/frein *)
    PowerCutOff       : BOOL;    (* 🧨 Coupure puissance amont activée *)
    BlockedBySafety   : BOOL;    (* 🚫 Synthèse globale : actionneur bloqué par la sécurité (PowerCutOff OU SafeStop/Error) *)
    PowerCutOffSafety : BOOL;    (* 🧨 Synthèse sécurités critiques entraînant une coupure puissance *)
    SafeStopSafety    : BOOL;    (* 🛡️ Synthèse défauts entraînant un SafeStop / Rampe rapide *)
    (* 🔍 Décomposition individuelle des défauts de sécurité (bits ErrorId) *)
    ErrorOperatorComm : BOOL;    (* 🎮 Perte communication opérateur : joystick CAN ou heartbeat IHM (bit0) *)
    ErrorEncoder      : BOOL;    (* 🔌 Perte de liaison ou incohérence codeur (bit1) *)
    ErrorPhaseRotation: BOOL;    (* ⚡ Mauvaise rotation de phases électriques (bit4) *)
    ErrorBrakeThermal : BOOL;    (* 🌡️ Surchauffe thermique frein commun M1/M2/M3 (bit10) *)
    ErrorMecaA        : BOOL;    (* 🔄 Mouvement non commandé / roue libre (Méca A - bit7) *)
    ErrorMecaB        : BOOL;    (* 🛑 Absence confirmation arrêt sans commande (Méca B - bit8) *)
    ErrorMecaC        : BOOL;    (* 🏋️ Glissement M1 pendant cycle benne (Méca C - bit9) *)
    ErrorMecaD        : BOOL;    (* 🚧 Non-arrêt sur capteur haut (Méca D - bit11) *)
    ErrorMecaE        : BOOL;    (* 🔄 Écart de synchronisation critique M1/M2 (Méca E - bit12/13) *)
    ErrorOppositeDir  : BOOL;    (* 🧭 Sens réel opposé au sens commandé (bit14) *)
    ErrorNoMovement   : BOOL;    (* ⏱️ Absence de mouvement malgré commande (bit15) *)
    NoMovementContactorSuspect : BOOL;  (* 🔌 bit15 déclenché par le retour « tous contacteurs retombés » → contacteur de sens non engagé *)
END_STRUCT
END_TYPE
