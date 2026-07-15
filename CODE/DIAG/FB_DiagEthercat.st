(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagEthercat — Diagnostic de communication bus EtherCAT (3 esclaves)
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_DiagEthercat
VAR_INPUT
    Enable              : BOOL;        (* Active la surveillance EtherCAT *)
    Reset               : BOOL;        (* Front d'acquittement des défauts *)
    
    (* Variateur M3 (AC600_ECAT_Drive) *)
    VariateurWcState    : BOOL;        (* Working Counter variateur (FALSE = OK) *)
    VariateurSlaveState : WORD;        (* État esclave variateur (8 = OP) *)
    
    (* Encodeur M1 (COD1_CODEUR) *)
    EncoderM1WcState    : BOOL;        (* Working Counter M1 (FALSE = OK) *)
    EncoderM1SlaveState : WORD;        (* État esclave M1 (8 = OP) *)
    
    (* Encodeur M2 (COD2_CODEUR) *)
    EncoderM2WcState    : BOOL;        (* Working Counter M2 (FALSE = OK) *)
    EncoderM2SlaveState : WORD;        (* État esclave M2 (8 = OP) *)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;        (* Logique de surveillance active *)
    Busy                : BOOL;        (* Non utilisé (conformité) *)
    Done                : BOOL;        (* Non utilisé *)
    Error               : BOOL;        (* Résumé anomalie de communication bus *)
    ErrorId             : WORD;        (* Code défaut global résumé *)
    State               : E_DiagState; (* Phase courante du diagnostic global *)
    StateAtError        : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    BusEthercat         : ST_DeviceDiag;  (* Diagnostics bus EtherCAT *)
    Variateur           : ST_DeviceDiag;  (* Diagnostics esclave AC600 *)
    EncoderM1           : ST_DeviceDiag;  (* Diagnostics esclave COD1 *)
    EncoderM2           : ST_DeviceDiag;  (* Diagnostics esclave COD2 *)
END_VAR
VAR
    ResetEdge           : R_TRIG;      (* Détecteur front de reset *)
END_VAR

// 🛑 1. GATE : Désactivation si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_DiagState.DISABLED;
    Variateur.State := E_DiagState.DISABLED;
    EncoderM1.State := E_DiagState.DISABLED;
    EncoderM2.State := E_DiagState.DISABLED;
    Variateur.Online := FALSE;
    EncoderM1.Online := FALSE;
    EncoderM2.Online := FALSE;
    Variateur.Operational := FALSE;
    EncoderM1.Operational := FALSE;
    EncoderM2.Operational := FALSE;
    Variateur.Error := FALSE;
    EncoderM1.Error := FALSE;
    EncoderM2.Error := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC VARIATEUR (AC600_ECAT_Drive / Translation M3)
Variateur.Online := NOT VariateurWcState;
Variateur.Operational := Variateur.Online AND (VariateurSlaveState = 8);

IF NOT Variateur.Online THEN
    Variateur.ErrorId := 16#0010;  (* Perte liaison physique variateur *)
ELSE
    IF ResetEdge.Q THEN
        Variateur.ErrorId := Variateur.ErrorId AND 16#FFEF;
    END_IF;
END_IF;

IF NOT Variateur.Operational AND Variateur.Online THEN
    Variateur.ErrorId := Variateur.ErrorId OR 16#0011;  (* Variateur pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        Variateur.ErrorId := Variateur.ErrorId AND 16#FFEE;
    END_IF;
END_IF;

// 🔍 4. DIAGNOSTIC ENCODEUR M1 (COD1_CODEUR / WinchM1)
EncoderM1.Online := NOT EncoderM1WcState;
EncoderM1.Operational := EncoderM1.Online AND (EncoderM1SlaveState = 8);

IF NOT EncoderM1.Online THEN
    EncoderM1.ErrorId := 16#0020;  (* Perte liaison encodeur M1 *)
ELSE
    IF ResetEdge.Q THEN
        EncoderM1.ErrorId := EncoderM1.ErrorId AND 16#FFDF;
    END_IF;
END_IF;

IF NOT EncoderM1.Operational AND EncoderM1.Online THEN
    EncoderM1.ErrorId := EncoderM1.ErrorId OR 16#0021;  (* Encodeur M1 pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        EncoderM1.ErrorId := EncoderM1.ErrorId AND 16#FFDE;
    END_IF;
END_IF;

// 🔍 5. DIAGNOSTIC ENCODEUR M2 (COD2_CODEUR / WinchM2)
EncoderM2.Online := NOT EncoderM2WcState;
EncoderM2.Operational := EncoderM2.Online AND (EncoderM2SlaveState = 8);

IF NOT EncoderM2.Online THEN
    EncoderM2.ErrorId := 16#0030;  (* Perte liaison encodeur M2 *)
ELSE
    IF ResetEdge.Q THEN
        EncoderM2.ErrorId := EncoderM2.ErrorId AND 16#FFCF;
    END_IF;
END_IF;

IF NOT EncoderM2.Operational AND EncoderM2.Online THEN
    EncoderM2.ErrorId := EncoderM2.ErrorId OR 16#0031;  (* Encodeur M2 pré-opérationnel *)
ELSE
    IF ResetEdge.Q THEN
        EncoderM2.ErrorId := EncoderM2.ErrorId AND 16#FFCE;
    END_IF;
END_IF;

// 🚦 6. STATE MACHINES DE CHAQUE APPAREIL
IF Variateur.ErrorId <> 0 THEN
    Variateur.State := E_DiagState.ERROR;
ELSIF NOT Variateur.Online THEN
    Variateur.State := E_DiagState.INIT;
ELSIF Variateur.Operational THEN
    Variateur.State := E_DiagState.READY;
ELSE
    Variateur.State := E_DiagState.MONITORING;
END_IF;

IF EncoderM1.ErrorId <> 0 THEN
    EncoderM1.State := E_DiagState.ERROR;
ELSIF NOT EncoderM1.Online THEN
    EncoderM1.State := E_DiagState.INIT;
ELSIF EncoderM1.Operational THEN
    EncoderM1.State := E_DiagState.READY;
ELSE
    EncoderM1.State := E_DiagState.MONITORING;
END_IF;

IF EncoderM2.ErrorId <> 0 THEN
    EncoderM2.State := E_DiagState.ERROR;
ELSIF NOT EncoderM2.Online THEN
    EncoderM2.State := E_DiagState.INIT;
ELSIF EncoderM2.Operational THEN
    EncoderM2.State := E_DiagState.READY;
ELSE
    EncoderM2.State := E_DiagState.MONITORING;
END_IF;

// Fige la phase du diagnostic global sur le premier défaut
IF (Variateur.ErrorId <> 0 OR EncoderM1.ErrorId <> 0 OR EncoderM2.ErrorId <> 0) THEN
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
END_IF;

// 📤 7. RÉSUMÉ ET DÉFAUTS
Variateur.Error := (Variateur.ErrorId <> 0);
EncoderM1.Error := (EncoderM1.ErrorId <> 0);
EncoderM2.Error := (EncoderM2.ErrorId <> 0);

Error := (Variateur.Error OR EncoderM1.Error OR EncoderM2.Error);

ErrorId := 16#0000;
IF Variateur.Error THEN
    ErrorId := ErrorId OR 16#00F0;
END_IF;
IF EncoderM1.Error THEN
    ErrorId := ErrorId OR 16#0F00;
END_IF;
IF EncoderM2.Error THEN
    ErrorId := ErrorId OR 16#F000;
END_IF;

IF Error THEN
    State := E_DiagState.ERROR;
ELSIF NOT (Variateur.Operational AND EncoderM1.Operational AND EncoderM2.Operational) THEN
    State := E_DiagState.MONITORING;
ELSE
    State := E_DiagState.READY;
END_IF;

BusEthercat.Online := Variateur.Online AND EncoderM1.Online AND EncoderM2.Online;
BusEthercat.Operational := Variateur.Operational AND EncoderM1.Operational AND EncoderM2.Operational;

Busy := FALSE;
Done := FALSE;
