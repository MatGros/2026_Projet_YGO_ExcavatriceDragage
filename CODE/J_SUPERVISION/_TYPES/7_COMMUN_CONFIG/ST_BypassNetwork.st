(* ═══════════════════════════════════════════════════════════════
   🌐 ST_BypassNetwork — Bypass général du diagnostic réseau
   ───────────────────────────────────────────────────────────────
   🔒 Permet de forcer les esclaves réseau (CAN, EtherCAT) à "online"
      pour le diagnostic, sans devoir toucher à chaque bit individuel.
      Jamais actif en production.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassNetwork :
STRUCT
    (* 📡 1. Bus maîtres & Modules d'E/S *)
    BusCanOpen  : BOOL; (* 📡 Bypass diagnostic bus CANopen maître *)
    BusEthercat : BOOL; (* 📡 Bypass diagnostic bus EtherCAT maître *)
    InputModules: BOOL; (* 🩺 Bypass diagnostic des 5 modules d'E/S physiques *)

    (* 🕹️ 2. Équipements esclaves *)
    Joystick    : BOOL; (* 🕹️ Bypass diagnostic esclave CANopen Joystick *)
    EncoderM1   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD1 (M1 codeur) *)
    EncoderM2   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD2 (M2 codeur) *)
    VariateurM3 : BOOL; (* ↔️ Bypass diagnostic esclave EtherCAT AC600 (M3 drive) *)
    IhmHeartbeat: BOOL := TRUE; (* 💓 Bypass du bit de vie IHM (défaut TRUE = sécurisé si pas d'IHM) *)

    (* 🛡️ 3. Hiérarchie & Restauration *)
    Global      : BOOL; (* 🌐 Bypass Global : tous les bus et esclaves réseau à la fois *)
    // Flag restauration boot dédié (défaut FALSE non ambigu, contrairement à une valeur métier)
    Initialized : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
END_STRUCT
END_TYPE
