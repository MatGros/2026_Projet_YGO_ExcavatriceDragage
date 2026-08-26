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
    // === 🧲 Mesures codeurs M1/M2 (struct frontiere AF-06 §3ter) ===
    Encoders                : ST_EncoderMeasurements; // 📊 Mesures + statuts codeurs M1/M2 (sous-DUT)

    // === 🛡️ Gates fiabilite codeurs (sorties FB_Encoder, hors ST_EncoderMeasurement) ===
    M1_EncoderFault          : BOOL; // ❌ Gate fiabilite M1 (NOT Available OR Incoherent, sans Homed)
    M2_EncoderFault          : BOOL; // ❌ Gate fiabilite M2 (NOT Available OR Incoherent, sans Homed)
    M1_HomedAndReliable      : BOOL; // ✅ Gate strict M3 M1 : dispo ET reference ET pas incoherent
    M2_HomedAndReliable      : BOOL; // ✅ Gate strict M3 M2 : dispo ET reference ET pas incoherent

    // === 🕹️ États joystick qualifiés ===
    JoystickDeadmanArmed    : BOOL; // 🔒 Homme-mort joystick arme (1=Arme)
    JoystickYNeutral        : BOOL; // 🟢 Axe Y joystick au neutre
    JoystickDirectionX      : INT;  // 🎯 Sens X demande (-1:Gauche, 0:Neutre, 1:Droite)
    JoystickSpeedPctX       : REAL; // 📈 Magnitude deviation axe X en % (0..100)
    JoystickXNeutral        : BOOL; // 🟢 Axe X joystick au neutre

    // === 🩺 Diagnostics modules DI ===
    LocalDigitalIoOk         : BOOL; // 🟢 Module Local_Digital_IO OK
    Vh0800EndOk              : BOOL; // 🟢 Module VH_0800END OK
    Vh0808EtpOk              : BOOL; // 🟢 Module VH_0808ETP OK
    InputModuleFault         : BOOL; // ❌ Defaut sur au moins un module DI

    // === 🧪 Simulation & variateur M3 filtré ===
    WinchInputSourceChanged       : BOOL; // 🔀 Impulsion 1 cycle si source Winch bascule (IHM)
    M3_StatusWord_Filtered        : UINT; // 📊 Mot d'etat variateur M3 filtre (consommé PRG_05)
    M3_ActualFrequencyHz_Filtered : UINT; // 📊 Frequence reelle M3 filtree (consommé PRG_05)
END_STRUCT
END_TYPE
