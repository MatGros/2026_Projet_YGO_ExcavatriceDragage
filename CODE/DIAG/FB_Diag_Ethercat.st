(* ═══════════════════════════════════════════════════════════════
   📡 FB_Diag_Ethercat — Diagnostic bus EtherCAT (3 esclaves)
   ───────────────────────────────────────────────────────────────
   📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v3.1.md
              DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §3
   🎯 Rôle : Décide Online/Operational pour variateur M3 + codeurs M1/M2.
      Publie ST_Diag_Device par device + state global.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Diag_Ethercat
VAR_INPUT
    Enable              : BOOL;        (* Active la surveillance EtherCAT *)
    Reset               : BOOL;        (* Front d'acquittement des défauts *)

    (* Variateur M3 (AC600_ECAT_Drive) *)
    DeviceVariateurStateRaw     : DEVICE_STATE; (* Valeur brute AC600_ECAT_Drive.GetDeviceState() *)
    DeviceVariateurSimBypass    : BOOL;         (* TRUE = simulation active *)

    (* Encodeur M1 (COD1_CODEUR) *)
    DeviceEncoderM1StateRaw     : DEVICE_STATE; (* Valeur brute COD1_CODEUR.GetDeviceState() *)
    DeviceEncoderM1SimBypass    : BOOL;         (* TRUE = simulation active *)

    (* Encodeur M2 (COD2_CODEUR) *)
    DeviceEncoderM2StateRaw     : DEVICE_STATE; (* Valeur brute COD2_CODEUR.GetDeviceState() *)
    DeviceEncoderM2SimBypass    : BOOL;         (* TRUE = simulation active *)

    NetworkBypassActive         : BOOL;         (* TRUE = bypass réseau global IHM *)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;        (* Logique de surveillance active *)
    Busy                : BOOL;        (* Non utilisé (conformité) *)
    Done                : BOOL;        (* Non utilisé *)
    Error               : BOOL;        (* Résumé anomalie de communication bus *)
    ErrorId             : WORD;        (* Code défaut global résumé *)
    State               : E_Diag_State; (* Phase courante du diagnostic global — voir en-tête *)
    StateAtError        : E_Diag_State; (* Phase figée à l'apparition de l'erreur *)
    DeviceEthercatMaster : ST_Diag_Device; (* Diagnostics bus EtherCAT *)
    DeviceVariateur     : ST_Diag_Device;  (* Diagnostics esclave AC600 *)
    DeviceEncoderM1     : ST_Diag_Device;  (* Diagnostics esclave COD1 *)
    DeviceEncoderM2     : ST_Diag_Device;  (* Diagnostics esclave COD2 *)
    (* Miroirs bruts lisibles directement sur l'instance *)
    DeviceVariateurStateRawOut : DEVICE_STATE;
    DeviceEncoderM1StateRawOut : DEVICE_STATE;
    DeviceEncoderM2StateRawOut : DEVICE_STATE;
END_VAR
VAR
    ResetEdge           : R_TRIG;      (* Détecteur front de reset *)
    VariateurOnlineReal  : BOOL; (* GetDeviceState() = RUNNING, hors tout bypass *)
    EncoderM1OnlineReal  : BOOL;
    EncoderM2OnlineReal  : BOOL;
    VariateurBypass      : BOOL; (* Simulation OU bypass réseau IHM, pour ce device *)
    EncoderM1Bypass      : BOOL;
    EncoderM2Bypass      : BOOL;
    VariateurOnlineEff   : BOOL; (* Online effectif (réel OU bypass) *)
    EncoderM1OnlineEff   : BOOL;
    EncoderM2OnlineEff   : BOOL;
END_VAR

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
