(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagEthercat — Diagnostic de communication bus EtherCAT (3 esclaves)
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v2.12.md
*)
FUNCTION_BLOCK PUBLIC FB_DiagEthercat
VAR_INPUT
    Enable              : BOOL;        (* Active la surveillance EtherCAT *)
    Reset               : BOOL;        (* Front d'acquittement des défauts *)
    
    (* Variateur M3 (AC600_ECAT_Drive) *)
    DeviceVariateurOnline : BOOL;      (* Variateur en ligne (TRUE = OK) *)
    DeviceVariateurState : WORD;       (* État esclave variateur (8 = OP) *)
    
    (* Encodeur M1 (COD1_CODEUR) *)
    DeviceEncoderM1Online : BOOL;      (* Encodeur M1 en ligne (TRUE = OK) *)
    DeviceEncoderM1State : WORD;       (* État esclave encodeur M1 (8 = OP) *)
    
    (* Encodeur M2 (COD2_CODEUR) *)
    DeviceEncoderM2Online : BOOL;      (* Encodeur M2 en ligne (TRUE = OK) *)
    DeviceEncoderM2State : WORD;       (* État esclave encodeur M2 (8 = OP) *)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;        (* Logique de surveillance active *)
    Busy                : BOOL;        (* Non utilisé (conformité) *)
    Done                : BOOL;        (* Non utilisé *)
    Error               : BOOL;        (* Résumé anomalie de communication bus *)
    ErrorId             : WORD;        (* Code défaut global résumé *)
    State               : E_DiagState; (* Phase courante du diagnostic global *)
    StateAtError        : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    DeviceEthercatMaster : ST_DiagDevice; (* Diagnostics bus EtherCAT *)
    DeviceVariateur     : ST_DiagDevice;  (* Diagnostics esclave AC600 *)
    DeviceEncoderM1     : ST_DiagDevice;  (* Diagnostics esclave COD1 *)
    DeviceEncoderM2     : ST_DiagDevice;  (* Diagnostics esclave COD2 *)
END_VAR
VAR
    ResetEdge           : R_TRIG;      (* Détecteur front de reset *)
END_VAR

// 🛑 1. GATE : Désactivation si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_DiagState.DISABLED;
    DeviceVariateur.State := E_DiagState.DISABLED;
    DeviceEncoderM1.State := E_DiagState.DISABLED;
    DeviceEncoderM2.State := E_DiagState.DISABLED;
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
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC VARIATEUR (AC600_ECAT_Drive / Translation M3)
DeviceVariateur.Online := DeviceVariateurOnline;
DeviceVariateur.Operational := DeviceVariateur.Online AND (DeviceVariateurState = 8);

IF NOT DeviceVariateur.Online THEN
    DeviceVariateur.ErrorId := 16#0010;  (* Perte liaison physique variateur *)
ELSE
    IF ResetEdge.Q THEN
        DeviceVariateur.ErrorId := DeviceVariateur.ErrorId AND 16#FFEF;
    END_IF;
END_IF;

IF NOT DeviceVariateur.Operational AND DeviceVariateur.Online THEN
    DeviceVariateur.ErrorId := DeviceVariateur.ErrorId OR 16#0011;  (* Variateur pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        DeviceVariateur.ErrorId := DeviceVariateur.ErrorId AND 16#FFEE;
    END_IF;
END_IF;

// 🔍 4. DIAGNOSTIC ENCODEUR M1 (COD1_CODEUR / WinchM1)
DeviceEncoderM1.Online := DeviceEncoderM1Online;
DeviceEncoderM1.Operational := DeviceEncoderM1.Online AND (DeviceEncoderM1State = 8);

IF NOT DeviceEncoderM1.Online THEN
    DeviceEncoderM1.ErrorId := 16#0020;  (* Perte liaison encodeur M1 *)
ELSE
    IF ResetEdge.Q THEN
        DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId AND 16#FFDF;
    END_IF;
END_IF;

IF NOT DeviceEncoderM1.Operational AND DeviceEncoderM1.Online THEN
    DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId OR 16#0021;  (* Encodeur M1 pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId AND 16#FFDE;
    END_IF;
END_IF;

// 🔍 5. DIAGNOSTIC ENCODEUR M2 (COD2_CODEUR / WinchM2)
DeviceEncoderM2.Online := DeviceEncoderM2Online;
DeviceEncoderM2.Operational := DeviceEncoderM2.Online AND (DeviceEncoderM2State = 8);

IF NOT DeviceEncoderM2.Online THEN
    DeviceEncoderM2.ErrorId := 16#0030;  (* Perte liaison encodeur M2 *)
ELSE
    IF ResetEdge.Q THEN
        DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId AND 16#FFCF;
    END_IF;
END_IF;

IF NOT DeviceEncoderM2.Operational AND DeviceEncoderM2.Online THEN
    DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId OR 16#0031;  (* Encodeur M2 pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId AND 16#FFCE;
    END_IF;
END_IF;

// 🚦 6. STATE MACHINES DE CHAQUE APPAREIL
IF DeviceVariateur.ErrorId <> 0 THEN
    DeviceVariateur.State := E_DiagState.ERROR;
ELSIF NOT DeviceVariateur.Online THEN
    DeviceVariateur.State := E_DiagState.INIT;
ELSIF DeviceVariateur.Operational THEN
    DeviceVariateur.State := E_DiagState.READY;
ELSE
    DeviceVariateur.State := E_DiagState.MONITORING;
END_IF;

IF DeviceEncoderM1.ErrorId <> 0 THEN
    DeviceEncoderM1.State := E_DiagState.ERROR;
ELSIF NOT DeviceEncoderM1.Online THEN
    DeviceEncoderM1.State := E_DiagState.INIT;
ELSIF DeviceEncoderM1.Operational THEN
    DeviceEncoderM1.State := E_DiagState.READY;
ELSE
    DeviceEncoderM1.State := E_DiagState.MONITORING;
END_IF;

IF DeviceEncoderM2.ErrorId <> 0 THEN
    DeviceEncoderM2.State := E_DiagState.ERROR;
ELSIF NOT DeviceEncoderM2.Online THEN
    DeviceEncoderM2.State := E_DiagState.INIT;
ELSIF DeviceEncoderM2.Operational THEN
    DeviceEncoderM2.State := E_DiagState.READY;
ELSE
    DeviceEncoderM2.State := E_DiagState.MONITORING;
END_IF;

// Fige la phase du diagnostic global sur le premier défaut
IF (DeviceVariateur.ErrorId <> 0 OR DeviceEncoderM1.ErrorId <> 0 OR DeviceEncoderM2.ErrorId <> 0) THEN
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
END_IF;

// 📤 7. RÉSUMÉ ET DÉFAUTS
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
    State := E_DiagState.ERROR;
ELSIF NOT (DeviceVariateur.Operational AND DeviceEncoderM1.Operational AND DeviceEncoderM2.Operational) THEN
    State := E_DiagState.MONITORING;
ELSE
    State := E_DiagState.READY;
END_IF;

DeviceEthercatMaster.Online := DeviceVariateur.Online AND DeviceEncoderM1.Online AND DeviceEncoderM2.Online;
DeviceEthercatMaster.Operational := DeviceVariateur.Operational AND DeviceEncoderM1.Operational AND DeviceEncoderM2.Operational;

Busy := FALSE;
Done := FALSE;
