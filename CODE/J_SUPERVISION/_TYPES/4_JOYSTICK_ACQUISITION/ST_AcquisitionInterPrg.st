(* ═══════════════════════════════════════════════════════════════
   🧲 ST_AcquisitionInterPrg — Bus d'échange inter-PRG produit par PRG_02_Acquisition
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les mesures câbles/vitesses, les états joystick qualifiés,
      les positions M3 et les diagnostics DI publiés par PRG_02_Acquisition vers
      les consommateurs (PRG_03/04/05/07, FB_TroubleshootingView).
   📤 Producteur unique : PRG_02_Acquisition (VAR_OUTPUT Data : ST_AcquisitionInterPrg).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AcquisitionInterPrg :
STRUCT
    // === 🧲 Mesures câbles & vitesses treuils M1/M2 ===
    CablePosM1              : REAL; // 📏 Position cable M1 calibree (metres)
    CablePosM2              : REAL; // 📏 Position cable M2 calibree (metres)
    M1_Speed_Mps            : REAL; // 📏 Vitesse absolue M1 (m/s)
    M1_SignedSpeed_Mps      : REAL; // 📏 Vitesse signee M1 (+:Montee, -:Descente) (m/s)
    M1_SpeedValid           : BOOL; // 🟢 Validite mesure vitesse M1
    M2_Speed_Mps            : REAL; // 📏 Vitesse absolue M2 (m/s)
    M2_SignedSpeed_Mps      : REAL; // 📏 Vitesse signee M2 (+:Montee, -:Descente) (m/s)
    M2_SpeedValid           : BOOL; // 🟢 Validite mesure vitesse M2

    // === 🕹️ États joystick qualifiés ===
    JoystickDeadmanArmed    : BOOL; // 🔒 Homme-mort joystick arme (1=Arme)
    JoystickYNeutral        : BOOL; // 🟢 Axe Y joystick au neutre
    JoystickDirectionX      : INT;  // 🎯 Sens X demande (-1:Gauche, 0:Neutre, 1:Droite)
    JoystickSpeedPctX       : REAL; // 📈 Magnitude deviation axe X en % (0..100)
    JoystickXNeutral        : BOOL; // 🟢 Axe X joystick au neutre

    // === 🎯 Positions translation M3 (zones cumulatives + points exacts) ===
    TranslationPosTremie      : BOOL; // 📍 Zone Tremie (1=Present)
    TranslationPosPV          : BOOL; // 📍 Zone pre-ralentissement PV (1=Present)
    TranslationPosP2          : BOOL; // 📍 Zone P2 (1=Present)
    TranslationPosP1          : BOOL; // 📍 Zone P1 (1=Present)
    TranslationPosMaintenance : BOOL; // 📍 Zone Maintenance (1=Present)
    TranslationAtTremie       : BOOL; // 🎯 Position exacte Tremie (1=Atteint)
    TranslationAtPV           : BOOL; // 🎯 Position exacte PV (1=Atteint)
    TranslationAtP2           : BOOL; // 🎯 Position exacte P2 (1=Atteint)
    TranslationAtP1           : BOOL; // 🎯 Position exacte P1 (1=Atteint)
    TranslationAtMaintenance  : BOOL; // 🎯 Position exacte Maintenance (1=Atteint)
    M3_LimitSwitchFwd         : BOOL; // 🛡️ Fin de course avant M3 (1=Actionne)
    M3_LimitSwitchRev         : BOOL; // 🛡️ Fin de course arriere M3 (1=Actionne)
    M3_SensorWordIncoherent   : BOOL; // ❌ Incoherence detectee mot capteurs M3
    M3_SensorsWord             : BYTE; // 📊 Mot d'etat capteurs M3

    // === 🩺 Diagnostics modules DI & codeurs ===
    LocalDigitalIoOk         : BOOL; // 🟢 Module Local_Digital_IO OK
    Vh0800EndOk              : BOOL; // 🟢 Module VH_0800END OK
    Vh0808EtpOk              : BOOL; // 🟢 Module VH_0808ETP OK
    InputModuleFault         : BOOL; // ❌ Defaut sur au moins un module DI
    M1_EncoderIncoherent     : BOOL; // ❌ Mesure codeur M1 incoherente
    M2_EncoderIncoherent     : BOOL; // ❌ Mesure codeur M2 incoherente

    // === 🧪 Simulation & variateur M3 filtré ===
    WinchInputSourceChanged       : BOOL; // 🔀 Impulsion 1 cycle si source Winch bascule (IHM)
    M3_StatusWord_Filtered        : UINT; // 📊 Mot d'etat variateur M3 filtre (consommé PRG_05)
    M3_ActualFrequencyHz_Filtered : UINT; // 📊 Frequence reelle M3 filtree (consommé PRG_05)
END_STRUCT
END_TYPE
