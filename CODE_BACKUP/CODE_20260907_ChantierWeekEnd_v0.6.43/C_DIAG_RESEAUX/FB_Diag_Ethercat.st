(* =======================================================================
   📊 FB_Diag_Ethercat — Diagnostic bus EtherCAT & Esclaves (M3, COD1, COD2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance bus EtherCAT master, variateur M3 et codeurs M1/M2
   🔌 Architecture : Publication ST_Diag_Device par esclave & E_Diag_State
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.4.md
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

    // === BYPASS RESEAU IHM & GRANULAIRES ===
    NetworkBypassActive         : BOOL;         // --> [TST] TRUE = bypass reseau global IHM
    EcatBusBypassActive         : BOOL;         // --> [TST] TRUE = bypass specifique bus EtherCAT maître
    VariateurBypassActive       : BOOL;         // --> [TST] TRUE = bypass specifique esclave variateur M3
    EncoderM1BypassActive       : BOOL;         // --> [TST] TRUE = bypass specifique esclave codeur M1
    EncoderM2BypassActive       : BOOL;         // --> [TST] TRUE = bypass specifique esclave codeur M2
END_VAR
VAR_OUTPUT
    // === ETAT DU BLOC ===
    Ready                       : BOOL;         // <-- [STAT] Logique de surveillance active

    // === DIAGNOSTICS STRUCTURES PAR EQUIPEMENT ===
    DeviceEthercatMaster        : ST_Diag_Device; // <-- [DIAG] Diagnostics bus EtherCAT
    DeviceVariateur             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave AC600
    DeviceEncoderM1             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave COD1
    DeviceEncoderM2             : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave COD2
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
    DeviceEthercatMaster.State := E_Diag_State.DISABLED;
    DeviceEthercatMaster.Online := FALSE;
    DeviceEthercatMaster.Operational := FALSE;
    DeviceEthercatMaster.Error := FALSE;
    DeviceEthercatMaster.ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

{endregion}

{region "§2 Interpretation etats bruts et bypass"}
// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES
VariateurOnlineReal := (DeviceVariateurStateRaw = DEVICE_STATE.RUNNING);
EncoderM1OnlineReal := (DeviceEncoderM1StateRaw = DEVICE_STATE.RUNNING);
EncoderM2OnlineReal := (DeviceEncoderM2StateRaw = DEVICE_STATE.RUNNING);

VariateurBypass := DeviceVariateurSimBypass OR NetworkBypassActive OR VariateurBypassActive;
EncoderM1Bypass := DeviceEncoderM1SimBypass OR NetworkBypassActive OR EncoderM1BypassActive;
EncoderM2Bypass := DeviceEncoderM2SimBypass OR NetworkBypassActive OR EncoderM2BypassActive;

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

{endregion}

{region "§5 Synthese EtherCAT et sorties"}
// 📤 8. RÉSUMÉ ET DÉFAUTS
DeviceVariateur.Error := (DeviceVariateur.ErrorId <> 0);
DeviceEncoderM1.Error := (DeviceEncoderM1.ErrorId <> 0);
DeviceEncoderM2.Error := (DeviceEncoderM2.ErrorId <> 0);

DeviceEthercatMaster.Online := (VariateurOnlineEff AND EncoderM1OnlineEff AND EncoderM2OnlineEff) OR NetworkBypassActive OR EcatBusBypassActive;
DeviceEthercatMaster.Operational := DeviceEthercatMaster.Online;
DeviceEthercatMaster.Error := NOT DeviceEthercatMaster.Operational;

IF DeviceEthercatMaster.Error THEN
    DeviceEthercatMaster.ErrorId := 16#0001;
    DeviceEthercatMaster.State := E_Diag_State.ERROR;
ELSIF (VariateurBypass OR EncoderM1Bypass OR EncoderM2Bypass OR EcatBusBypassActive) THEN
    DeviceEthercatMaster.ErrorId := 16#0000;
    DeviceEthercatMaster.State := E_Diag_State.SIMULATED;
ELSE
    DeviceEthercatMaster.ErrorId := 16#0000;
    DeviceEthercatMaster.State := E_Diag_State.READY;
END_IF;
{endregion}
