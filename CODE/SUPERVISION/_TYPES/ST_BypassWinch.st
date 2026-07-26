(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassWinch — Bypass maintenance dédiés à UN treuil (M1 ou M2)
   ───────────────────────────────────────────────────────────────
   🎨 Regroupe les bypass "dégradé assumé" propres à un axe (codeur,
      contacteurs) — chaque treuil a son propre matériel, donc son
      propre struct (imbriqué M1Winch.Bypass / M2Winch.Bypass).
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive)).
   ⚠️ Les bypass de capteurs COMMUNS (SlackCable, TopPositionSensor — capteur
      physique unique partagé M1/M2) sont dans ST_CommunHMI.Bypass, PAS ici.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassWinch :
STRUCT
    (* 📡 1. Communication & Systèmes auxiliaires *)
    OperatorComm      : BOOL; (* 📡 Bypass communication esclave CANopen Joystick / heartbeat IHM *)
    EncoderFault      : BOOL; (* 🔌 Bypass diagnostic esclave EtherCAT COD (codeur absolu) *)
    ContactorFeedback : BOOL; (* 🔌 Bypass feedbacks contacteurs de puissance et frein *)
    PhaseRotation     : BOOL; (* ⚡ Bypass défaut rotation de phases (commun machine) *)
    BrakeThermal      : BOOL; (* 🌡️ Bypass surchauffe thermique frein (commun machine) *)

    (* 🚧 2. Limites physiques et Positionnement *)
    TopLimitSwitch    : BOOL; (* 🚧 Bypass fin de course physique haute *)
    CableLimitSwitch  : BOOL; (* 🚧 Bypass limite basse physique (longueur de câble max) *)

    (* ⚙️ 3. Sécurité Mécanique (Méca A-E) *)
    MecaA             : BOOL; (* 🔄 Bypass Méca A : mouvement non commandé à l'arrêt *)
    MecaB             : BOOL; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)
    MecaC             : BOOL; (* 🏋️ Bypass Méca C : glissement de charge (benne M1) *)
    MecaD             : BOOL; (* 🚧 Bypass Méca D : arrivée butée haute anormale *)
    MecaE             : BOOL; (* 🔄 Bypass Méca E : désynchronisation critique *)

    (* 🛡️ 4. Hiérarchie & Restauration *)
    Safety            : BOOL; (* 🛡️ Bypass groupé : tous les bits qui provoquent un PowerCutOff *)
    Process           : BOOL; (* ⚙️ Bypass groupé : tous les bits qui provoquent un SafeStop *)
    Global            : BOOL; (* 🌐 Bypass Global : ignore toutes les sécurités de cet axe *)
    // 🐛 FIX persistance (voir DOC/AUDITS/ConfigPersistence/) : flag restauration boot dédié
    // (défaut FALSE non ambigu, contrairement à une valeur métier) — PRG_09_Supervision.st
    Initialized       : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
END_STRUCT
END_TYPE
