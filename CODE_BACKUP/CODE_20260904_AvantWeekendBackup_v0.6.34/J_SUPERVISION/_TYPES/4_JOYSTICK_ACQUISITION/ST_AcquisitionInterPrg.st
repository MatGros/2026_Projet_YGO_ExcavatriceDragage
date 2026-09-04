(* ═══════════════════════════════════════════════════════════════
   🧲 ST_AcquisitionInterPrg — Bus d'échange inter-PRG produit par PRG_02_Acquisition
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les mesures câbles/vitesses, les états joystick qualifiés,
      les positions M3 et les diagnostics DI publiés par PRG_02_Acquisition vers
      les consommateurs (PRG_03/04/05/07, FB_TroubleshootingView).
   📤 Producteur unique : PRG_02_Acquisition (VAR_OUTPUT Data : ST_AcquisitionInterPrg).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AcquisitionInterPrg :
STRUCT
    // === 🛡️ Drapeau de vie & validité globale des données ===
    DataValid                    : BOOL; // 🟢 TRUE = PRG_02 a complété son scan et les données sont fraîches et qualifiées

    // === 📦 Structures qualifiées du bus ===
    Joystick                     : ST_AcquisitionJoystickQualified;    // 🕹️ Données et commandes joystick qualifiées
    Network                      : ST_AcquisitionNetworkDiagnostics;  // 🔌 Diagnostics réseaux CANopen et EtherCAT
    EncoderM1                    : ST_AcquisitionEncoderQualified;     // 🧲 Façade codeur qualifiée M1 (Retenue)
    EncoderM2                    : ST_AcquisitionEncoderQualified;     // 🧲 Façade codeur qualifiée M2 (Benne)
    MachineHoming                : ST_MachineHoming;                   // 🎯 État homing conjoint machine (M1/M2/benne)

    // === 🩺 Diagnostics modules E/S ===
    InputModules                 : ST_IOModuleDiag; // 🩺 Diagnostic carte des 5 modules E/S (AF06 §3bis)

    // === 🧪 Simulation & variateur M3 filtré ===
    InputSource                  : ST_InputSource; // 🔀 Flags de bascule de source (réel/simu) par domaine
    M3                           : ST_M3DriveFeedback; // ↔️ Retours variateur M3 filtrés (consommé PRG_05)
END_STRUCT
END_TYPE
