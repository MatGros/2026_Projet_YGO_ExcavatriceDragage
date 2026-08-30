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

    // === 🩺 Diagnostics modules E/S ===
    LocalDigitalIoOk             : BOOL; // 🟢 Module Local_Digital_IO OK (DI8/DO8)
    Vh0800EndOk                  : BOOL; // 🟢 Module VH_0800END OK (DI8)
    Vh0808EtpOk                  : BOOL; // 🟢 Module VH_0808ETP OK (DI8/DO8)
    Vh0008ErOk                   : BOOL; // 🟢 Module VH_0008ER OK (DO8 Relais Freins/Kobold)
    Vh0008Er1Ok                  : BOOL; // 🟢 Module VH_0008ER_1 OK (DO8 Relais AU/PowerKeepAlive)
    InputModuleFault             : BOOL; // ❌ Defaut sur au moins un module E/S

    // === 🧪 Simulation & variateur M3 filtré ===
    WinchInputSourceChanged       : BOOL; // 🔀 Impulsion 1 cycle si source Winch bascule (IHM)
    M3_StatusWord_Filtered        : UINT; // 📊 Mot d'etat variateur M3 filtre (consommé PRG_05)
    M3_ActualFrequencyHz_Filtered : UINT; // 📊 Frequence reelle M3 filtree (consommé PRG_05)
END_STRUCT
END_TYPE
