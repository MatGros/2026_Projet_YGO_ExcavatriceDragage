(* ═══════════════════════════════════════════════════════════════
   📡 ST_NetworkDiagHMI — Données d'échange IHM pour les diagnostics réseau
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des diagnostics CANopen et EtherCAT.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_NetworkDiagHMI :
STRUCT
    BusCanOpen          : ST_Diag_Device;  (* 📡 Diagnostics bus CANopen *)
    Joystick            : ST_Diag_Device;  (* 🕹️ Diagnostics esclave Joystick *)
    CanError            : BOOL;           (* ⚠️ Voyant anomalie globale CANopen (IHM Visu) *)
    CanErrorId          : WORD;           (* ❌ Code anomalie CANopen *)

    BusEthercat         : ST_Diag_Device;  (* 📡 Diagnostics bus EtherCAT *)
    EncoderM1           : ST_Diag_Device;  (* 🧲 Diagnostics esclave COD1 *)
    EncoderM2           : ST_Diag_Device;  (* 🧲 Diagnostics esclave COD2 *)
    VariateurM3         : ST_Diag_Device;  (* ↔️ Diagnostics esclave AC600 *)
    EcatError           : BOOL;           (* ⚠️ Voyant anomalie globale EtherCAT (IHM Visu) *)
    EcatErrorId         : WORD;           (* ❌ Code anomalie EtherCAT *)

    InputModules        : ST_InputModuleDiagHMI; (* 🩺 Diagnostic carte des 5 modules d'E/S physiques *)

    (* 🌐 Bypass réseau global *)
    Bypass              : ST_BypassNetwork;
END_STRUCT
END_TYPE
