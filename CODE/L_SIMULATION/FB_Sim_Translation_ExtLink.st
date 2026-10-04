(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Translation_ExtLink — Lien UDP vers le simulateur externe M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Échange UDP loopback avec la passerelle FMU OpenModelica et publie l'image
      matérielle M3 (ST_HwTranslation) ; alternative externe à FB_Sim_Translation.
   🔒 Sécurité : Enable=FALSE ferme le socket et neutralise ; loopback 127.0.0.1 uniquement ;
      perte de liaison = dernière image valide gelée + LinkTimeout, jamais de saut de capteurs.
   🔌 Protocole : trames binaires M3B1 (commande 32 octets, réponse 39 octets), cadence tâche.
   🧩 Appelé par FB_SimBench (aiguillage M3_OpenModelicaActive) ; aucune lecture de GVL ici.
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Sim_Translation_ExtLink
VAR_INPUT
    // === CONTRAT LIGHT (Enable) ===
    Enable                  : BOOL;   // --> [CMD] Lien actif (simulation + domaine M3 + source externe)

    // === COMMANDES M3 ===
    ReqTremie               : BOOL;   // --> [CMD] Demande vers Trémie (sortie finale PRG_06)
    ReqMaintenance          : BOOL;   // --> [CMD] Demande vers Maintenance (sortie finale PRG_06)
    SetpointFrequencyHz     : WORD;   // --> [CMD] Consigne fréquence variateur, Hz x100
    BrakeReleaseCmd         : BOOL;   // --> [CMD] TRUE = desserrage frein commandé

    // === ECHO ETAT PLC (diagnostic simulateur) ===
    PlcEcho                 : ST_fbSim_Translation_ExtLink_Echo; // --> [TST] Etat decisionnel M3 copie dans la trame
END_VAR

VAR_OUTPUT
    // === CONTRAT LIGHT (Ready) ===
    Ready                   : BOOL;   // <-- [STAT] Socket ouvert, lien en cours d'échange

    // === IMAGE MATERIELLE M3 ===
    Translation             : ST_HwTranslation; // <-- [DIAG] Image retours M3 (initiale P1, puis FMU)

    // === ETAT DU LIEN ===
    LinkReady               : BOOL;   // <-- [STAT] Au moins une trame valide reçue et lien non expiré
    LinkTimeout             : BOOL;   // <-- [DIAG] Aucune trame valide depuis CST_LinkTimeout
    LinkInvalid             : BOOL;   // <-- [DIAG] Dernière trame rejetée, ou lien expiré
    LinkAge_Ms              : UDINT;  // <-- [DIAG] Durée sans trame valide, ms
    TxCount                 : UDINT;  // <-- [DIAG] Trames commande émises
    RxCount                 : UDINT;  // <-- [DIAG] Trames réponse acceptées
    RejectCount             : UDINT;  // <-- [DIAG] Trames rejetées ou émissions en échec
END_VAR

VAR
    // === SOUS-INSTANCES ===
    AgeTimer                : TON;    // * [INST] Durée sans trame valide

    // === SOCKET ===
    SocketHandle            : RTS_IEC_HANDLE := RTS_INVALID_HANDLE; // . [LOC] Socket UDP
    NonBlocking             : DINT := 1;                  // . [LOC] Option socket non bloquant
    SocketIsOpen            : BOOL := FALSE;              // . [LOC] Socket réellement ouvert (ni invalide, ni factice)
    LastResult              : RTS_IEC_RESULT := 0;        // . [LOC] Dernier code retour socket
    Reply                   : UDP_REPLY;                  // . [LOC] Adresse émettrice de la réponse
    Tx                      : ARRAY [0..31] OF BYTE;      // . [LOC] Trame commande
    Rx                      : ARRAY [0..63] OF BYTE;      // . [LOC] Trame réponse
    Bytes                   : __XINT := 0;                // . [LOC] Octets émis/reçus

    // === ETAT DU LIEN ===
    HasValidFrame           : BOOL := FALSE;              // . [LOC] Une trame valide a été acceptée
    FrameAccepted           : BOOL := FALSE;              // . [LOC] Au moins une trame acceptée ce scan
    FrameRejected           : BOOL := FALSE;              // . [LOC] Au moins une trame rejetée ce scan
    FrameIsAcceptedNow      : BOOL := FALSE;              // . [LOC] Trame en cours de lecture acceptée
    RxReads                 : UINT := 0;                  // . [LOC] Lectures UDP effectuées ce scan
    Sequence                : UDINT := 0;                 // . [LOC] Numéro de commande émise
    LastRxSequence          : UDINT := 0;                 // . [LOC] Dernier numéro de réponse accepté

    // === DECODAGE TRAME ===
    TxFrequency_x100        : UINT := 0;                  // . [LOC] Consigne bornée émise
    TxControlWord           : UINT := 0;                  // . [LOC] 0=arrêt, 1=Trémie, 2=Maintenance
    EchoFlagsA              : BYTE := 0;                  // . [LOC] Écho : autorisations, sécurité, fins de course
    EchoFlagsB              : BYTE := 0;                  // . [LOC] Écho : sens actif, jetons de position, lien
    EchoPos_Cm              : INT := 0;                   // . [LOC] Écho : position estimée, cm
    RxSequence              : UDINT := 0;                 // . [LOC] Numéro de la réponse
    RxCommandSequence       : UDINT := 0;                 // . [LOC] Commande acquittée par la réponse
    RxFrequency_x100        : UINT := 0;                  // . [LOC] Fréquence mesurée FMU
    RxBrakeIsOpen           : BOOL := FALSE;              // . [LOC] Frein ouvert (FMU)
    RxStatusWord            : WORD := 0;                  // . [LOC] Status word variateur simulé
    RxSensors               : ARRAY [0..4] OF BOOL;       // . [LOC] 0=Trémie 1=PV 2=P2 3=P1 4=Maintenance
    MagicIsValid            : BOOL := FALSE;              // . [LOC] En-tête M3B1 reconnu
    TypeIsValid             : BOOL := FALSE;              // . [LOC] Schéma 1 et type réponse
    FrameIsValid            : BOOL := FALSE;              // . [LOC] En-tête complet valide
    SequenceIsNewer         : BOOL := FALSE;              // . [LOC] Numéros strictement croissants
    SequenceHasWrapped      : BOOL := FALSE;              // . [LOC] Passage FFFFFFFF -> 0
    LinkIsRestarting        : BOOL := FALSE;              // . [LOC] Premier échange ou reprise après expiration
    SequenceIsAccepted      : BOOL := FALSE;              // . [LOC] Numéro acceptable
    BreakTremiePv           : BOOL := FALSE;              // . [LOC] Rupture de chaîne Trémie/PV
    BreakPvP2               : BOOL := FALSE;              // . [LOC] Rupture de chaîne PV/P2
    BreakP2P1               : BOOL := FALSE;              // . [LOC] Rupture de chaîne P2/P1
    BreakP1Maintenance      : BOOL := FALSE;              // . [LOC] Rupture de chaîne P1/Maintenance
    BreakNearTremie         : BOOL := FALSE;              // . [LOC] Rupture côté Trémie
    BreakNearMaintenance    : BOOL := FALSE;              // . [LOC] Rupture côté Maintenance
    SensorWordIsIncoherent  : BOOL := FALSE;              // . [LOC] Mot capteurs hors chaîne terrain

    // === IMAGE INITIALE ===
    // Zone P1 (00011) : AtPositionP1 n'est jamais forcé, le PLC attend un front capteur en mouvement.
    InitialImage            : ST_HwTranslation := (M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE, M3_ThermalOK_DI := TRUE, M3_StatusWord := 16#0080, AC600_DeviceState := DEVICE_STATE.RUNNING);
END_VAR

VAR CONSTANT
    CST_PortLocal           : UINT := 29061;              // Port UDP loopback commande (passerelle FMU)
    CST_PortRemote          : UINT := 29062;              // Port UDP loopback réponse
    CST_TxSize              : __XINT := 32;               // Taille trame commande
    CST_RxSize              : __XINT := 39;               // Taille trame réponse
    CST_LinkTimeout         : TIME := T#1s;               // Expiration du lien
    CST_MaxFrequency_x100   : UINT := 5000;               // 50,00 Hz
    CST_SequenceMax         : UDINT := 16#FFFFFFFF;       // Valeur avant rebouclage
    CST_ControlWordTremie   : UINT := 1;                  // Mot de commande vers Trémie
    CST_ControlWordMaint    : UINT := 2;                  // Mot de commande vers Maintenance
    CST_MaxRxPerScan        : UINT := 8;                  // Lectures UDP max par scan (vidage de file borné)
    CST_EchoVersion         : BYTE := 1;                  // Version de l'écho PLC (0 = absent)
    CST_EchoPosMin_M        : REAL := -300.0;             // Bornes de l'écho position (INT en cm)
    CST_EchoPosMax_M        : REAL := 300.0;
    CST_CmPerM              : REAL := 100.0;              // Conversion m -> cm
    CST_ResultOk            : RTS_IEC_RESULT := 0;        // Code retour socket OK (ERR_OK)
END_VAR

{region "§1 Gate neutralisation"}
// === ⚙️ §1 GATE NEUTRALISATION ===
IF NOT Enable THEN
    IF SocketHandle <> SysTypes.RTS_INVALID_HANDLE THEN
        SysSockCloseUdp(SocketHandle);
    END_IF;
    SocketHandle := SysTypes.RTS_INVALID_HANDLE;
    HasValidFrame := FALSE;
    FrameAccepted := FALSE;
    Sequence := 0;
    LastRxSequence := 0;
    AgeTimer(IN := FALSE, PT := CST_LinkTimeout);
    Ready := FALSE;
    LinkReady := FALSE;
    LinkTimeout := FALSE;
    LinkInvalid := FALSE;
    LinkAge_Ms := 0;
    Translation := InitialImage;
    RETURN;
END_IF;
{endregion}

{region "§2 Image initiale avant la premiere trame valide"}
// === 📥 §2 IMAGE INITIALE ===
IF NOT HasValidFrame THEN
    Translation := InitialImage;
END_IF;
{endregion}

{region "§3 Ouverture du socket"}
// === 🔌 §3 SOCKET ===
// Handle 0 = socket factice (simulateur intégré de l'IDE, sans réseau) : jamais considéré ouvert.
SocketIsOpen := (SocketHandle <> SysTypes.RTS_INVALID_HANDLE) AND (SocketHandle <> 0);
IF NOT SocketIsOpen THEN
    SocketHandle := SysSockCreateUdp(CST_PortLocal, CST_PortRemote, ADR(LastResult));
    SocketIsOpen := (SocketHandle <> SysTypes.RTS_INVALID_HANDLE) AND (SocketHandle <> 0);
    IF SocketIsOpen THEN
        LastResult := SysSockIoctl(SocketHandle, SOCKET_FIONBIO, ADR(NonBlocking));
        // 🔒 Socket non bloquant obligatoire : sinon la lecture gèlerait la tâche automate.
        IF LastResult <> CST_ResultOk THEN
            SysSockCloseUdp(SocketHandle);
            SocketHandle := RTS_INVALID_HANDLE;
            SocketIsOpen := FALSE;
        END_IF;
    END_IF;
    Ready := FALSE;
    RETURN;
END_IF;
Ready := TRUE;
{endregion}

{region "§4 Emission commande"}
// === 📤 §4 EMISSION COMMANDE ===
TxFrequency_x100 := MIN(WORD_TO_UINT(SetpointFrequencyHz), CST_MaxFrequency_x100);
IF ReqTremie AND NOT ReqMaintenance THEN
    TxControlWord := CST_ControlWordTremie;
ELSIF ReqMaintenance AND NOT ReqTremie THEN
    TxControlWord := CST_ControlWordMaint;
ELSE
    TxControlWord := 0;
END_IF;

// En-tête M3B1, schéma 1, type commande 1, numéro, Hz x100, mot de commande, frein.
Tx[0] := 16#4D; Tx[1] := 16#33; Tx[2] := 16#42; Tx[3] := 16#31;
Tx[4] := 1; Tx[5] := 1;
Tx[6] := UDINT_TO_BYTE(Sequence AND 16#FF);
Tx[7] := UDINT_TO_BYTE(SHR(Sequence, 8) AND 16#FF);
Tx[8] := UDINT_TO_BYTE(SHR(Sequence, 16) AND 16#FF);
Tx[9] := UDINT_TO_BYTE(SHR(Sequence, 24) AND 16#FF);
Tx[10] := UINT_TO_BYTE(TxFrequency_x100 AND 16#FF);
Tx[11] := UINT_TO_BYTE(SHR(TxFrequency_x100, 8));
Tx[12] := UINT_TO_BYTE(TxControlWord AND 16#FF);
Tx[13] := UINT_TO_BYTE(SHR(TxControlWord, 8));
Tx[14] := BOOL_TO_BYTE(BrakeReleaseCmd);

// 📊 Écho de l'état PLC dans les octets libres 23..31 (lecture seule côté simulateur).
EchoFlagsA := BOOL_TO_BYTE(PlcEcho.MaintenanceTargetEnable)
           OR SHL(BOOL_TO_BYTE(PlcEcho.MaintenanceZoneAccess), 1)
           OR SHL(BOOL_TO_BYTE(PlcEcho.SafeStop), 2)
           OR SHL(BOOL_TO_BYTE(PlcEcho.PowerCutOff), 3)
           OR SHL(BOOL_TO_BYTE(PlcEcho.LimitSwitchTremie), 4)
           OR SHL(BOOL_TO_BYTE(PlcEcho.LimitSwitchMaintenance), 5)
           OR SHL(BOOL_TO_BYTE(PlcEcho.PositionReached), 6)
           OR SHL(BOOL_TO_BYTE(PlcEcho.ActiveTremie), 7);
EchoFlagsB := BOOL_TO_BYTE(PlcEcho.ActiveMaintenance)
           OR SHL(BOOL_TO_BYTE(PlcEcho.AtTremie), 1)
           OR SHL(BOOL_TO_BYTE(PlcEcho.AtPV), 2)
           OR SHL(BOOL_TO_BYTE(PlcEcho.AtP2), 3)
           OR SHL(BOOL_TO_BYTE(PlcEcho.AtP1), 4)
           OR SHL(BOOL_TO_BYTE(PlcEcho.AtMaintenance), 5)
           OR SHL(BOOL_TO_BYTE(LinkReady), 6)
           OR SHL(BOOL_TO_BYTE(PlcEcho.SensorWordIncoherent), 7);
EchoPos_Cm := REAL_TO_INT(LIMIT(CST_EchoPosMin_M, PlcEcho.EstimatedPos_M, CST_EchoPosMax_M) * CST_CmPerM);
Tx[23] := CST_EchoVersion;
Tx[24] := INT_TO_BYTE(PlcEcho.Mode);
Tx[25] := INT_TO_BYTE(PlcEcho.FBState);
Tx[26] := INT_TO_BYTE(PlcEcho.AxisBlockReason);
Tx[27] := EchoFlagsA;
Tx[28] := EchoFlagsB;
Tx[29] := WORD_TO_BYTE(INT_TO_WORD(EchoPos_Cm) AND 16#FF);
Tx[30] := WORD_TO_BYTE(SHR(INT_TO_WORD(EchoPos_Cm), 8));
Tx[31] := WORD_TO_BYTE(PlcEcho.SafetyErrorId AND 16#FF);
// Adresse loopback écrite en littéral : une constante STRING déclarée est importée vide
// par le générateur PLCopenXML, et l'envoi partirait vers une adresse vide.
Bytes := SysSockSendToUdp(SocketHandle, CST_PortLocal, '127.0.0.1', ADR(Tx), SIZEOF(Tx), ADR(LastResult));
IF Bytes = CST_TxSize THEN
    TxCount := TxCount + 1;
    Sequence := Sequence + 1;
ELSE
    RejectCount := RejectCount + 1;
END_IF;
{endregion}

{region "§5 Reception et validation réponse"}
// === 📥 §5 RECEPTION ===
// File UDP vidée à chaque scan (bornée) : un retard ponctuel ne devient jamais permanent.
// Chaque trame acceptée met à jour l'image ; la dernière acceptée l'emporte.
FrameAccepted := FALSE;
FrameRejected := FALSE;
RxReads := 0;
REPEAT
Bytes := SysSockRecvFromUdp(SocketHandle, ADR(Rx), SIZEOF(Rx), ADR(Reply), ADR(LastResult));
RxReads := RxReads + 1;
FrameIsAcceptedNow := FALSE;
IF Bytes = CST_RxSize THEN
    MagicIsValid := (Rx[0] = 16#4D) AND (Rx[1] = 16#33) AND (Rx[2] = 16#42) AND (Rx[3] = 16#31);
    TypeIsValid := (Rx[4] = 1) AND (Rx[5] = 2);
    FrameIsValid := MagicIsValid AND TypeIsValid;

    IF FrameIsValid THEN
        RxSequence := BYTE_TO_UDINT(Rx[6]) OR SHL(BYTE_TO_UDINT(Rx[7]), 8)
                      OR SHL(BYTE_TO_UDINT(Rx[8]), 16) OR SHL(BYTE_TO_UDINT(Rx[9]), 24);
        RxCommandSequence := BYTE_TO_UDINT(Rx[10]) OR SHL(BYTE_TO_UDINT(Rx[11]), 8)
                             OR SHL(BYTE_TO_UDINT(Rx[12]), 16) OR SHL(BYTE_TO_UDINT(Rx[13]), 24);

        // Numéros strictement croissants, rebouclage FFFFFFFF -> 0 admis, redémarrage passerelle admis.
        SequenceIsNewer := (RxCommandSequence > LastRxSequence) AND (RxSequence > LastRxSequence);
        SequenceHasWrapped := (LastRxSequence = CST_SequenceMax) AND (RxCommandSequence = 0) AND (RxSequence = 0);
        LinkIsRestarting := AgeTimer.Q OR NOT HasValidFrame;
        SequenceIsAccepted := SequenceIsNewer OR SequenceHasWrapped OR LinkIsRestarting;

        RxFrequency_x100 := BYTE_TO_UINT(Rx[16]) OR SHL(BYTE_TO_UINT(Rx[17]), 8);
        RxBrakeIsOpen := Rx[20] <> 0;
        RxStatusWord := BYTE_TO_WORD(Rx[21]);
        RxSensors[0] := Rx[22] <> 0;
        RxSensors[1] := Rx[23] <> 0;
        RxSensors[2] := Rx[24] <> 0;
        RxSensors[3] := Rx[25] <> 0;
        RxSensors[4] := Rx[26] <> 0;

        // Chaîne terrain admissible : 11111 -> 01111 -> 00111 -> 00011 -> 00001 -> 00000.
        // Rupture = un capteur actif suivi d'un capteur inactif côté Maintenance (ex. 10111).
        BreakTremiePv := RxSensors[0] AND NOT RxSensors[1];
        BreakPvP2 := RxSensors[1] AND NOT RxSensors[2];
        BreakP2P1 := RxSensors[2] AND NOT RxSensors[3];
        BreakP1Maintenance := RxSensors[3] AND NOT RxSensors[4];
        BreakNearTremie := BreakTremiePv OR BreakPvP2;
        BreakNearMaintenance := BreakP2P1 OR BreakP1Maintenance;
        SensorWordIsIncoherent := BreakNearTremie OR BreakNearMaintenance;

        FrameIsAcceptedNow := SequenceIsAccepted AND NOT SensorWordIsIncoherent;
    END_IF;

    IF FrameIsAcceptedNow THEN
        Translation.M3_PosTremie_DI := RxSensors[0];
        Translation.M3_PosPV_DI := RxSensors[1];
        Translation.M3_PosPVP2_DI := RxSensors[2];
        Translation.M3_PosP1_DI := RxSensors[3];
        Translation.M3_PosMaintenance_DI := RxSensors[4];
        Translation.M3_BrakeIsOpen_DI := RxBrakeIsOpen;
        Translation.M3_ThermalOK_DI := TRUE;
        Translation.M3_StatusWord := RxStatusWord;
        Translation.M3_ActualFrequencyHz := RxFrequency_x100;
        Translation.AC600_DeviceState := DEVICE_STATE.RUNNING;
        LastRxSequence := RxSequence;
        HasValidFrame := TRUE;
        RxCount := RxCount + 1;
        FrameAccepted := TRUE;
    ELSE
        RejectCount := RejectCount + 1;
        FrameRejected := TRUE;
    END_IF;
ELSIF Bytes > 0 THEN
    // Datagramme de taille inattendue : rejeté.
    RejectCount := RejectCount + 1;
    FrameRejected := TRUE;
END_IF;
UNTIL (Bytes <= 0) OR (RxReads >= CST_MaxRxPerScan)
END_REPEAT;
{endregion}

{region "§6 Etat du lien"}
// === 📊 §6 ETAT DU LIEN ===
// Une trame rejetée ou absente laisse Translation inchangée (image gelée, pas de saut de capteurs).
AgeTimer(IN := NOT FrameAccepted, PT := CST_LinkTimeout);
LinkTimeout := AgeTimer.Q;
LinkReady := HasValidFrame AND NOT AgeTimer.Q;
LinkAge_Ms := TIME_TO_UDINT(AgeTimer.ET);

IF FrameAccepted THEN
    LinkInvalid := FALSE;
ELSIF FrameRejected THEN
    LinkInvalid := TRUE;
END_IF;
IF AgeTimer.Q THEN
    LinkInvalid := TRUE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
