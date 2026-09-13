(* ═══════════════════════════════════════════════════════════════
   🔌 ST_AcquisitionNetworkDiagnostics — Diagnostics réseaux qualifiés
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les états opérationnels et diagnostics des bus CANopen
      et EtherCAT produits par PRG_02_Acquisition.
   📤 Producteur unique : PRG_02_Acquisition (Data.Network).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AcquisitionNetworkDiagnostics :
STRUCT
    CanOpenMaster   : ST_Diag_Device; // 🔌 Diagnostic maître CANopen
    Joystick        : ST_Diag_Device; // 🕹️ Diagnostic esclave Joystick MCB560
    EthercatMaster  : ST_Diag_Device; // 🔌 Diagnostic maître EtherCAT
    EncoderM1       : ST_Diag_Device; // 🧲 Diagnostic esclave Codeur M1 (COD1)
    EncoderM2       : ST_Diag_Device; // 🧲 Diagnostic esclave Codeur M2 (COD2)
    DriveM3         : ST_Diag_Device; // ⚙️ Diagnostic esclave Variateur M3 (AC600)
END_STRUCT
END_TYPE
