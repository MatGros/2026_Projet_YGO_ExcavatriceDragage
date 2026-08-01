(* ═══════════════════════════════════════════════════════════════
   🌐 ST_BypassNetwork — Bypass général du diagnostic réseau
   ───────────────────────────────────────────────────────────────
   🔒 Permet de forcer les esclaves réseau (CAN, EtherCAT) à "online"
      pour le diagnostic, sans devoir toucher à chaque bit individuel.
      Jamais actif en production.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassNetwork :
STRUCT
    (* 📡 1. Communication & Systèmes esclaves *)
    Joystick    : BOOL; (* 🕹️ Bypass diagnostic esclave CANopen Joystick *)
    EncoderM1   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD1 (M1 codeur) *)
    EncoderM2   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD2 (M2 codeur) *)
    VariateurM3 : BOOL; (* ↔️ Bypass diagnostic esclave EtherCAT AC600 (M3 drive) *)
    IhmHeartbeat: BOOL := TRUE; (* 💓 Bypass du bit de vie IHM (défaut TRUE = sécurisé si pas d'IHM) *)

    (* 🛡️ 2. Hiérarchie & Restauration *)
    Global      : BOOL; (* 🌐 Bypass Global : tous les esclaves réseau à la fois *)
    // 🐛 FIX persistance (voir DOC/AUDITS/ConfigPersistence/) : flag restauration boot dédié
    // (défaut FALSE non ambigu, contrairement à une valeur métier) — PRG_SUPERVISION_CFC.st
    Initialized : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
END_STRUCT
END_TYPE
