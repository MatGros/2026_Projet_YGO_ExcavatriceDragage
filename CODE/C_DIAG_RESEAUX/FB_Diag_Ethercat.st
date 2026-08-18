(* =======================================================================
   📊 FB_Diag_Ethercat — Diagnostic bus EtherCAT & Esclaves (M3, COD1, COD2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance bus EtherCAT master, variateur M3 et codeurs M1/M2
   🔌 Architecture : Publication ST_Diag_Device par esclave & E_Diag_State
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.0.md
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Diag_Ethercat
VAR_INPUT
    // === COMMANDES & CONTROLE ===
    Enable                      : BOOL;         // --> [CMD] Active la surveillance EtherCAT
    Reset                       : BOOL;         // --> [CMD] Front d'acquittement des defauts

    // === ETATS BRUTS MATERIEL & BYPASS VARIATEUR M3 ===
    DeviceVariateurStateRaw     : DEVICE_STATE; // --> [HW]  Valeur brute AC600_ECAT_Drive.GetDeviceState()
    DeviceVariateurSimBypass    : BOOL;         // --> [TST] TRUE = simulation active variateur M3

    // === ETATS BRUTS MATERIEL & BYPASS ENCODEUR M1 ===
    DeviceEncoderM1StateRaw     : DEVICE_STATE; // --> [HW]  Valeur brute COD1_CODEUR.GetDeviceState()
    DeviceEncoderM1SimBypass    : BOOL;         // --> [TST] TRUE = simulation active encodeur M1

    // === ETATS BRUTS MATERIEL & BYPASS ENCODEUR M2 ===
    DeviceEncoderM2StateRaw     : DEVICE_STATE; // --> [HW]  Valeur brute COD2_CODEUR.GetDeviceState()
    DeviceEncoderM2SimBypass    : BOOL;         // --> [TST] TRUE = simulation active encodeur M2

    // === BYPASS RESEAU IHM ===
    NetworkBypassActive         : BOOL;         // --> [TST] TRUE = bypass reseau global IHM
END_VAR
VAR_OUTPUT
    // === ETATS IEC & CONFORMITE ===
    Ready                       : BOOL;         // <-- [STAT] Logique de surveillance active
    Busy                        : BOOL;         // <-- [STAT] Non utilise (conformite interface)
    Done                        : BOOL;         // <-- [STAT] Non utilise
    State                       : E_Diag_State; // <-- [STAT] Phase courante du diagnostic global

    // === DIAGNOSTICS & ALARMES ===
    Error                       : BOOL;         // <-- [DIAG] Resume anomalie de communication bus
    ErrorId                     : WORD;         // <-- [DIAG] Code defaut global resume
    StateAtError                : E_Diag_State; // <-- [DIAG] Phase figee a l'apparition de l'erreur
    DeviceEthercatMaster        : ST_Diag_Device; // <-- [DIAG] Diagnostics bus EtherCAT
    DeviceVariateur             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave AC600
    DeviceEncoderM1             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave COD1
    DeviceEncoderM2             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave COD2

    // === MIROIRS BRUTS MATERIEL ===
    DeviceVariateurStateRawOut  : DEVICE_STATE; // <-- [DIAG] Miroir brut status variateur M3
    DeviceEncoderM1StateRawOut  : DEVICE_STATE; // <-- [DIAG] Miroir brut status encodeur M1
    DeviceEncoderM2StateRawOut  : DEVICE_STATE; // <-- [DIAG] Miroir brut status encodeur M2
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    ResetEdge                   : R_TRIG;       // * [INST] Detecteur front de reset

    // === CALCULS ET ETATS INTERNES ===
    VariateurOnlineReal         : BOOL;         // . [LOC]  GetDeviceState() = RUNNING, hors tout bypass
    EncoderM1OnlineReal         : BOOL;         // . [LOC]  GetDeviceState() = RUNNING, hors tout bypass
    EncoderM2OnlineReal         : BOOL;         // . [LOC]  GetDeviceState() = RUNNING, hors tout bypass
    VariateurBypass             : BOOL;         // . [LOC]  Simulation OU bypass reseau IHM variateur
    EncoderM1Bypass             : BOOL;         // . [LOC]  Simulation OU bypass reseau IHM encodeur M1
    EncoderM2Bypass             : BOOL;         // . [LOC]  Simulation OU bypass reseau IHM encodeur M2
    VariateurOnlineEff          : BOOL;         // . [LOC]  Online effectif (reel OU bypass)
    EncoderM1OnlineEff          : BOOL;         // . [LOC]  Online effectif (reel OU bypass)
    EncoderM2OnlineEff          : BOOL;         // . [LOC]  Online effectif (reel OU bypass)
END_VAR

{region "§1 Gate de desactivation"}
// 🛑 1. GATE : Désactivation si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_Diag_State.DISABLED;
    DeviceVariateur.State := E_Diag_State.DISABLED;
    DeviceEncoderM1.State := E_Diag_State.DISABLED;
    DeviceEncoderM2.State := E_Diag_State.DISABLED;
    DeviceVariateur.Online := FALSE;
    DeviceEncoderM1.Online := FALSE;
    DeviceEncoderM2.Online := FALSE;
    DeviceVariateur.Operational := FALSE;
    DeviceEncoderM1.Operational := FALSE;
    DeviceEncoderM2.Operational := FALSE;
    DeviceVariateur.Error := FALSE;
    DeviceEncoderM1.Error := FALSE;
    DeviceEncoderM2.Error := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    DeviceEthercatMaster.State := E_Diag_State.DISABLED;
    DeviceEthercatMaster.Online := FALSE;
    DeviceEthercatMaster.Operational := FALSE;
    DeviceVariateurStateRawOut := DeviceVariateurStateRaw;
    DeviceEncoderM1StateRawOut := DeviceEncoderM1StateRaw;
    DeviceEncoderM2StateRawOut := DeviceEncoderM2StateRaw;
    RETURN;
END_IF;

Ready := TRUE;

{endregion}

{region "§2 Interpretation etats bruts et bypass"}
// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES
VariateurOnlineReal := (DeviceVariateurStateRaw = DEVICE_STATE.RUNNING);
EncoderM1OnlineReal := (DeviceEncoderM1StateRaw = DEVICE_STATE.RUNNING);
EncoderM2OnlineReal := (DeviceEncoderM2StateRaw = DEVICE_STATE.RUNNING);

VariateurBypass := DeviceVariateurSimBypass OR NetworkBypassActive;
EncoderM1Bypass := DeviceEncoderM1SimBypass OR NetworkBypassActive;
EncoderM2Bypass := DeviceEncoderM2SimBypass OR NetworkBypassActive;

VariateurOnlineEff := VariateurOnlineReal OR VariateurBypass;
EncoderM1OnlineEff := EncoderM1OnlineReal OR EncoderM1Bypass;
EncoderM2OnlineEff := EncoderM2OnlineReal OR EncoderM2Bypass;

// 🔑 3. RESET FRONT
ResetEdge(CLK := Reset);

{endregion}

{region "§3 Diagnostic par equipement"}
// 🔍 4. DIAGNOSTIC VARIATEUR (AC600_ECAT_Drive / Translation M3)
DeviceVariateur.Online := VariateurOnlineEff;
DeviceVariateur.Operational := VariateurOnlineEff;

IF NOT DeviceVariateur.Online THEN
    DeviceVariateur.ErrorId := DeviceVariateur.ErrorId OR 16#0010;  (* Perte liaison physique variateur *)
ELSE
    DeviceVariateur.ErrorId := DeviceVariateur.ErrorId AND 16#FFEF; (* Effacement auto dès que RUNNING *)
END_IF;

// 🔍 5. DIAGNOSTIC ENCODEUR M1 (COD1_CODEUR / WinchM1)
DeviceEncoderM1.Online := EncoderM1OnlineEff;
DeviceEncoderM1.Operational := EncoderM1OnlineEff;

IF NOT DeviceEncoderM1.Online THEN
    DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId OR 16#0020;  (* Perte liaison encodeur M1 *)
ELSE
    DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId AND 16#FFDF; (* Effacement auto dès que RUNNING *)
END_IF;

// 🔍 6. DIAGNOSTIC ENCODEUR M2 (COD2_CODEUR / WinchM2)
DeviceEncoderM2.Online := EncoderM2OnlineEff;
DeviceEncoderM2.Operational := EncoderM2OnlineEff;

IF NOT DeviceEncoderM2.Online THEN
    DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId OR 16#0030;  (* Perte liaison encodeur M2 *)
ELSE
    DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId AND 16#FFCF; (* Effacement auto dès que RUNNING *)
END_IF;

{endregion}

{region "§4 Etats diagnostic par equipement"}
// 🚦 7. STATE MACHINES DE CHAQUE APPAREIL
IF DeviceVariateur.ErrorId <> 0 THEN
    DeviceVariateur.State := E_Diag_State.ERROR;
ELSIF NOT VariateurOnlineEff THEN
    DeviceVariateur.State := E_Diag_State.INIT;
ELSIF VariateurBypass AND NOT VariateurOnlineReal THEN
    DeviceVariateur.State := E_Diag_State.SIMULATED;
ELSE
    DeviceVariateur.State := E_Diag_State.READY;
END_IF;

IF DeviceEncoderM1.ErrorId <> 0 THEN
    DeviceEncoderM1.State := E_Diag_State.ERROR;
ELSIF NOT EncoderM1OnlineEff THEN
    DeviceEncoderM1.State := E_Diag_State.INIT;
ELSIF EncoderM1Bypass AND NOT EncoderM1OnlineReal THEN
    DeviceEncoderM1.State := E_Diag_State.SIMULATED;
ELSE
    DeviceEncoderM1.State := E_Diag_State.READY;
END_IF;

IF DeviceEncoderM2.ErrorId <> 0 THEN
    DeviceEncoderM2.State := E_Diag_State.ERROR;
ELSIF NOT EncoderM2OnlineEff THEN
    DeviceEncoderM2.State := E_Diag_State.INIT;
ELSIF EncoderM2Bypass AND NOT EncoderM2OnlineReal THEN
    DeviceEncoderM2.State := E_Diag_State.SIMULATED;
ELSE
    DeviceEncoderM2.State := E_Diag_State.READY;
END_IF;

// Fige la phase du diagnostic global sur le premier défaut
IF (DeviceVariateur.ErrorId <> 0 OR DeviceEncoderM1.ErrorId <> 0 OR DeviceEncoderM2.ErrorId <> 0) THEN
    IF StateAtError = E_Diag_State.DISABLED THEN
        StateAtError := State;
    END_IF;
END_IF;

{endregion}

{region "§5 Synthese EtherCAT et sorties"}
// 📤 8. RÉSUMÉ ET DÉFAUTS
DeviceVariateur.Error := (DeviceVariateur.ErrorId <> 0);
DeviceEncoderM1.Error := (DeviceEncoderM1.ErrorId <> 0);
DeviceEncoderM2.Error := (DeviceEncoderM2.ErrorId <> 0);

Error := (DeviceVariateur.Error OR DeviceEncoderM1.Error OR DeviceEncoderM2.Error);

ErrorId := 16#0000;
IF DeviceVariateur.Error THEN
    ErrorId := ErrorId OR 16#00F0;
END_IF;
IF DeviceEncoderM1.Error THEN
    ErrorId := ErrorId OR 16#0F00;
END_IF;
IF DeviceEncoderM2.Error THEN
    ErrorId := ErrorId OR 16#F000;
END_IF;

IF Error THEN
    State := E_Diag_State.ERROR;
ELSIF NOT (VariateurOnlineEff AND EncoderM1OnlineEff AND EncoderM2OnlineEff) THEN
    State := E_Diag_State.INIT;
ELSIF (VariateurBypass OR EncoderM1Bypass OR EncoderM2Bypass)
      AND NOT (VariateurOnlineReal AND EncoderM1OnlineReal AND EncoderM2OnlineReal) THEN
    State := E_Diag_State.SIMULATED;
ELSE
    State := E_Diag_State.READY;
END_IF;

DeviceEthercatMaster.Online := VariateurOnlineEff AND EncoderM1OnlineEff AND EncoderM2OnlineEff;
DeviceEthercatMaster.Operational := DeviceEthercatMaster.Online;

DeviceVariateurStateRawOut := DeviceVariateurStateRaw;
DeviceEncoderM1StateRawOut := DeviceEncoderM1StateRaw;
DeviceEncoderM2StateRawOut := DeviceEncoderM2StateRaw;

Busy := FALSE;
Done := FALSE;

{endregion}
