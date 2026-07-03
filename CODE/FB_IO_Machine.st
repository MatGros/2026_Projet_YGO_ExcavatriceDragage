(* ═══════════════════════════════════════════════════════════════
   🧰 FB_IO_Machine — Conditionnement I/O réel de TOUTE la machine (1 seule instance)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5, Plan FB_IO généralisé (final)
   🧭 Interface RÉDUITE (Partie3 §1bis) : compose FB_Input_Digital/FB_Output_Relay
      (_COMMON) pour TOUT le conditionnement I/O réel de la machine — Commun (AU/mou de
      câble/capteur haut), Winch M1, Winch M2, Chariot M3 — regroupés dans UN SEUL FB,
      1 SEULE instance dans PRG_MAIN. Interface volontairement longue (~28 voies) mais
      TOUT est au même endroit, classé par section métier ci-dessous — plus simple à
      relire/maintenir qu'éparpillé sur plusieurs FB ou dans PRG_MAIN directement.
   🔁 ⚠️ APPELÉE 2× PAR CYCLE dans PRG_MAIN (même instance, UNE SEULE fois pour toute la
      machine) :
      1er appel (tout en haut, AVANT Joystick/Homing/Safety/Winch/Chariot) : fournit
         TOUS les `*Raw` réels (entrées) → lit toutes les sorties `*Cond`.
      2e appel (tout en bas, APRÈS FB_Winch M1/M2 ET FB_Chariot) : refournit les mêmes
         `*Raw` (relecture sans effet, valeur figée pour tout le scan par le bus) +
         TOUTES les `*Cmd` (sorties des FB métier, disponibles seulement à ce point) →
         lit toutes les sorties `*Out` (→ I/O Mapping réel).
      Sans risque sur les timers internes (anti-rebond) : les 2 appels se suivent dans
      le même scan (écart de temps ≈0), TON ne "double-avance" pas.
   🔴 Portée limitée au conditionnement bas niveau (InvertLogic par voie, pour
      forcer/inverser en mise en service SANS toucher le câblage) : `UseFeedback` reste
      FALSE partout — la double-vérification contacteur (FB_Winch/FB_Chariot, écrite à
      la main) n'est PAS dupliquée/remplacée ici (choix d'architecture Partie6 §0 non
      tranché).
   🔴 Chariot M3 : seuls les signaux RÉELLEMENT câblés en I/O Mapping sont conditionnés
      ici (`PosFosse1/2/Maintenance/Tremie`, `M3_BrakeCmd`). `M3_RelayFwd/Rev/RelaySpeedGv`
      restent des STUB logiciels (`GVL_Chariot_M3_Stub`, pas de matériel réel encore) —
      les conditionner n'aurait pas de sens (pas de contact physique à inverser/filtrer).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_IO_Machine) ===

FUNCTION_BLOCK PUBLIC FB_IO_Machine
VAR_INPUT
    // 🛑 COMMUN — sécurité transverse + treuils (1er appel)
    EmergencyStopOkRaw       : BOOL;         // 📡 I/O Mapping réel — retour contacteur puissance/AU
    SlackCableSwitchRaw      : BOOL;         // 📡 I/O Mapping réel — mou de câble (commun M1/M2)
    TopPositionSensorRaw     : BOOL;         // 📡 I/O Mapping réel — capteur position haute (commun M1/M2)
    InvertEmergencyStopOk    : BOOL := FALSE; // ⚠️ TBD mise en service : TRUE si contact NC
    InvertSlackCableSwitch   : BOOL := FALSE;
    InvertTopPositionSensor  : BOOL := FALSE;

    // 🪝 WINCH M1 — entrées (1er appel)
    M1ContactorFeedbackFwdRaw : BOOL;        // 📡 I/O Mapping réel
    M1ContactorFeedbackRevRaw : BOOL;        // 📡 I/O Mapping réel
    M1ThermalFeedbackRaw      : BOOL;        // 📡 I/O Mapping réel
    InvertM1ContactorFwd      : BOOL := FALSE;
    InvertM1ContactorRev      : BOOL := FALSE;
    InvertM1Thermal           : BOOL := FALSE;

    // 🪝 WINCH M2 — entrées (1er appel)
    M2ContactorFeedbackFwdRaw : BOOL;        // 📡 I/O Mapping réel
    M2ContactorFeedbackRevRaw : BOOL;        // 📡 I/O Mapping réel
    M2ThermalFeedbackRaw      : BOOL;        // 📡 I/O Mapping réel
    InvertM2ContactorFwd      : BOOL := FALSE;
    InvertM2ContactorRev      : BOOL := FALSE;
    InvertM2Thermal           : BOOL := FALSE;

    // ↔️ CHARIOT M3 — entrées (1er appel) : 4 capteurs position réels
    ChariotPosFosse1Raw      : BOOL;         // 📡 I/O Mapping réel
    ChariotPosFosse2Raw      : BOOL;         // 📡 I/O Mapping réel
    ChariotPosMaintenanceRaw : BOOL;         // 📡 I/O Mapping réel
    ChariotPosTremieRaw      : BOOL;         // 📡 I/O Mapping réel
    InvertChariotPosFosse1      : BOOL := FALSE;
    InvertChariotPosFosse2      : BOOL := FALSE;
    InvertChariotPosMaintenance : BOOL := FALSE;
    InvertChariotPosTremie      : BOOL := FALSE;

    // 🪝 WINCH M1 — sorties (2e appel, Command = sortie DÉJÀ RAMPÉE de FB_Winch)
    M1RelayFwdCmd        : BOOL;
    M1RelayRevCmd        : BOOL;
    M1SpeedContactor1Cmd : BOOL;
    M1SpeedContactor2Cmd : BOOL;
    M1SpeedContactor3Cmd : BOOL;
    M1SpeedContactor4Cmd : BOOL;
    M1BrakeCmdCmd        : BOOL;
    InvertM1RelayFwd         : BOOL := FALSE;
    InvertM1RelayRev         : BOOL := FALSE;
    InvertM1SpeedContactor1  : BOOL := FALSE;
    InvertM1SpeedContactor2  : BOOL := FALSE;
    InvertM1SpeedContactor3  : BOOL := FALSE;
    InvertM1SpeedContactor4  : BOOL := FALSE;
    InvertM1BrakeCmd         : BOOL := FALSE;

    // 🪝 WINCH M2 — sorties (2e appel)
    M2RelayFwdCmd        : BOOL;
    M2RelayRevCmd        : BOOL;
    M2SpeedContactor1Cmd : BOOL;
    M2SpeedContactor2Cmd : BOOL;
    M2SpeedContactor3Cmd : BOOL;
    M2SpeedContactor4Cmd : BOOL;
    M2BrakeCmdCmd        : BOOL;
    InvertM2RelayFwd         : BOOL := FALSE;
    InvertM2RelayRev         : BOOL := FALSE;
    InvertM2SpeedContactor1  : BOOL := FALSE;
    InvertM2SpeedContactor2  : BOOL := FALSE;
    InvertM2SpeedContactor3  : BOOL := FALSE;
    InvertM2SpeedContactor4  : BOOL := FALSE;
    InvertM2BrakeCmd         : BOOL := FALSE;

    // ↔️ CHARIOT M3 — sorties (2e appel) : seul BrakeCmd est réel (RelayFwd/Rev/SpeedGv = STUB)
    ChariotBrakeCmdCmd       : BOOL;
    InvertChariotBrakeCmd    : BOOL := FALSE;
END_VAR
VAR_OUTPUT
    // 🛑 COMMUN
    EmergencyStopOkCond      : BOOL;
    SlackCableSwitchCond     : BOOL;
    TopPositionSensorCond    : BOOL;

    // 🪝 WINCH M1
    M1ContactorFeedbackFwdCond : BOOL;
    M1ContactorFeedbackRevCond : BOOL;
    M1ThermalFeedbackCond      : BOOL;
    M1RelayFwdOut         : BOOL;
    M1RelayRevOut         : BOOL;
    M1SpeedContactor1Out  : BOOL;
    M1SpeedContactor2Out  : BOOL;
    M1SpeedContactor3Out  : BOOL;
    M1SpeedContactor4Out  : BOOL;
    M1BrakeCmdOut         : BOOL;

    // 🪝 WINCH M2
    M2ContactorFeedbackFwdCond : BOOL;
    M2ContactorFeedbackRevCond : BOOL;
    M2ThermalFeedbackCond      : BOOL;
    M2RelayFwdOut         : BOOL;
    M2RelayRevOut         : BOOL;
    M2SpeedContactor1Out  : BOOL;
    M2SpeedContactor2Out  : BOOL;
    M2SpeedContactor3Out  : BOOL;
    M2SpeedContactor4Out  : BOOL;
    M2BrakeCmdOut         : BOOL;

    // ↔️ CHARIOT M3
    ChariotPosFosse1Cond      : BOOL;
    ChariotPosFosse2Cond      : BOOL;
    ChariotPosMaintenanceCond : BOOL;
    ChariotPosTremieCond      : BOOL;
    ChariotBrakeCmdOut        : BOOL;
END_VAR
VAR
    // 🛑 Commun
    instEmergencyStopOk  : FB_Input_Digital;
    instSlackCableSwitch : FB_Input_Digital;
    instTopPositionSensor : FB_Input_Digital;

    // 🪝 Winch M1
    instM1ContactorFwd : FB_Input_Digital;
    instM1ContactorRev : FB_Input_Digital;
    instM1Thermal      : FB_Input_Digital;
    instM1RelayFwd        : FB_Output_Relay;
    instM1RelayRev        : FB_Output_Relay;
    instM1SpeedContactor1 : FB_Output_Relay;
    instM1SpeedContactor2 : FB_Output_Relay;
    instM1SpeedContactor3 : FB_Output_Relay;
    instM1SpeedContactor4 : FB_Output_Relay;
    instM1BrakeCmd        : FB_Output_Relay;

    // 🪝 Winch M2
    instM2ContactorFwd : FB_Input_Digital;
    instM2ContactorRev : FB_Input_Digital;
    instM2Thermal      : FB_Input_Digital;
    instM2RelayFwd        : FB_Output_Relay;
    instM2RelayRev        : FB_Output_Relay;
    instM2SpeedContactor1 : FB_Output_Relay;
    instM2SpeedContactor2 : FB_Output_Relay;
    instM2SpeedContactor3 : FB_Output_Relay;
    instM2SpeedContactor4 : FB_Output_Relay;
    instM2BrakeCmd        : FB_Output_Relay;

    // ↔️ Chariot M3
    instChariotPosFosse1      : FB_Input_Digital;
    instChariotPosFosse2      : FB_Input_Digital;
    instChariotPosMaintenance : FB_Input_Digital;
    instChariotPosTremie      : FB_Input_Digital;
    instChariotBrakeCmd       : FB_Output_Relay;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_IO_Machine) ===

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
instEmergencyStopOk(InputRaw := EmergencyStopOkRaw, InvertLogic := InvertEmergencyStopOk, FilterTime := T#20MS);
EmergencyStopOkCond := instEmergencyStopOk.OutputClean;

instSlackCableSwitch(InputRaw := SlackCableSwitchRaw, InvertLogic := InvertSlackCableSwitch, FilterTime := T#20MS);
SlackCableSwitchCond := instSlackCableSwitch.OutputClean;

instTopPositionSensor(InputRaw := TopPositionSensorRaw, InvertLogic := InvertTopPositionSensor, FilterTime := T#20MS);
TopPositionSensorCond := instTopPositionSensor.OutputClean;

// 🪝 ─── WINCH M1 — entrées ────────────────────────────────────────────────
instM1ContactorFwd(InputRaw := M1ContactorFeedbackFwdRaw, InvertLogic := InvertM1ContactorFwd, FilterTime := T#20MS);
M1ContactorFeedbackFwdCond := instM1ContactorFwd.OutputClean;

instM1ContactorRev(InputRaw := M1ContactorFeedbackRevRaw, InvertLogic := InvertM1ContactorRev, FilterTime := T#20MS);
M1ContactorFeedbackRevCond := instM1ContactorRev.OutputClean;

instM1Thermal(InputRaw := M1ThermalFeedbackRaw, InvertLogic := InvertM1Thermal, FilterTime := T#20MS);
M1ThermalFeedbackCond := instM1Thermal.OutputClean;

// 🪝 ─── WINCH M1 — sorties ────────────────────────────────────────────────
instM1RelayFwd(Command := M1RelayFwdCmd, InvertLogic := InvertM1RelayFwd);
M1RelayFwdOut := instM1RelayFwd.OutputCmd;

instM1RelayRev(Command := M1RelayRevCmd, InvertLogic := InvertM1RelayRev);
M1RelayRevOut := instM1RelayRev.OutputCmd;

instM1SpeedContactor1(Command := M1SpeedContactor1Cmd, InvertLogic := InvertM1SpeedContactor1);
M1SpeedContactor1Out := instM1SpeedContactor1.OutputCmd;

instM1SpeedContactor2(Command := M1SpeedContactor2Cmd, InvertLogic := InvertM1SpeedContactor2);
M1SpeedContactor2Out := instM1SpeedContactor2.OutputCmd;

instM1SpeedContactor3(Command := M1SpeedContactor3Cmd, InvertLogic := InvertM1SpeedContactor3);
M1SpeedContactor3Out := instM1SpeedContactor3.OutputCmd;

instM1SpeedContactor4(Command := M1SpeedContactor4Cmd, InvertLogic := InvertM1SpeedContactor4);
M1SpeedContactor4Out := instM1SpeedContactor4.OutputCmd;

instM1BrakeCmd(Command := M1BrakeCmdCmd, InvertLogic := InvertM1BrakeCmd);
M1BrakeCmdOut := instM1BrakeCmd.OutputCmd;

// 🪝 ─── WINCH M2 — entrées ────────────────────────────────────────────────
instM2ContactorFwd(InputRaw := M2ContactorFeedbackFwdRaw, InvertLogic := InvertM2ContactorFwd, FilterTime := T#20MS);
M2ContactorFeedbackFwdCond := instM2ContactorFwd.OutputClean;

instM2ContactorRev(InputRaw := M2ContactorFeedbackRevRaw, InvertLogic := InvertM2ContactorRev, FilterTime := T#20MS);
M2ContactorFeedbackRevCond := instM2ContactorRev.OutputClean;

instM2Thermal(InputRaw := M2ThermalFeedbackRaw, InvertLogic := InvertM2Thermal, FilterTime := T#20MS);
M2ThermalFeedbackCond := instM2Thermal.OutputClean;

// 🪝 ─── WINCH M2 — sorties ────────────────────────────────────────────────
instM2RelayFwd(Command := M2RelayFwdCmd, InvertLogic := InvertM2RelayFwd);
M2RelayFwdOut := instM2RelayFwd.OutputCmd;

instM2RelayRev(Command := M2RelayRevCmd, InvertLogic := InvertM2RelayRev);
M2RelayRevOut := instM2RelayRev.OutputCmd;

instM2SpeedContactor1(Command := M2SpeedContactor1Cmd, InvertLogic := InvertM2SpeedContactor1);
M2SpeedContactor1Out := instM2SpeedContactor1.OutputCmd;

instM2SpeedContactor2(Command := M2SpeedContactor2Cmd, InvertLogic := InvertM2SpeedContactor2);
M2SpeedContactor2Out := instM2SpeedContactor2.OutputCmd;

instM2SpeedContactor3(Command := M2SpeedContactor3Cmd, InvertLogic := InvertM2SpeedContactor3);
M2SpeedContactor3Out := instM2SpeedContactor3.OutputCmd;

instM2SpeedContactor4(Command := M2SpeedContactor4Cmd, InvertLogic := InvertM2SpeedContactor4);
M2SpeedContactor4Out := instM2SpeedContactor4.OutputCmd;

instM2BrakeCmd(Command := M2BrakeCmdCmd, InvertLogic := InvertM2BrakeCmd);
M2BrakeCmdOut := instM2BrakeCmd.OutputCmd;

// ↔️ ─── CHARIOT M3 — entrées (4 capteurs position réels) ─────────────────
instChariotPosFosse1(InputRaw := ChariotPosFosse1Raw, InvertLogic := InvertChariotPosFosse1, FilterTime := T#20MS);
ChariotPosFosse1Cond := instChariotPosFosse1.OutputClean;

instChariotPosFosse2(InputRaw := ChariotPosFosse2Raw, InvertLogic := InvertChariotPosFosse2, FilterTime := T#20MS);
ChariotPosFosse2Cond := instChariotPosFosse2.OutputClean;

instChariotPosMaintenance(InputRaw := ChariotPosMaintenanceRaw, InvertLogic := InvertChariotPosMaintenance, FilterTime := T#20MS);
ChariotPosMaintenanceCond := instChariotPosMaintenance.OutputClean;

instChariotPosTremie(InputRaw := ChariotPosTremieRaw, InvertLogic := InvertChariotPosTremie, FilterTime := T#20MS);
ChariotPosTremieCond := instChariotPosTremie.OutputClean;

// ↔️ ─── CHARIOT M3 — sorties (seul BrakeCmd est réel) ─────────────────────
instChariotBrakeCmd(Command := ChariotBrakeCmdCmd, InvertLogic := InvertChariotBrakeCmd);
ChariotBrakeCmdOut := instChariotBrakeCmd.OutputCmd;
