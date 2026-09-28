(* =======================================================================
   PRG_TwinBenchNativeUdpMulti — POC UDP multi-flux Control Win
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Mesurer flux rapide/cyclique/événementiel sans bloquer la tâche
   🔒 Polarité : Enable=FALSE ou Stop=TRUE ferme les trois sockets
   🔌 Interface : SysSocket System, 127.0.0.1 uniquement, aucun lien machine
   ======================================================================= *)
PROGRAM PRG_TwinBenchNativeUdpMulti
VAR
    // === COMMANDE POC ===
    Enable              : BOOL := FALSE;
    Stop                : BOOL := FALSE;
    EventTrigger        : BOOL := FALSE;

    // === ETAT PUBLIC ===
    SocketReady         : BOOL := FALSE;
    FastSentCount       : UDINT := 0;
    FastReceivedCount   : UDINT := 0;
    CyclicSentCount     : UDINT := 0;
    CyclicReceivedCount : UDINT := 0;
    EventSentCount      : UDINT := 0;
    EventReceivedCount  : UDINT := 0;
    SendErrorCount      : UDINT := 0;
    InvalidReplyCount   : UDINT := 0;
    LastResult          : SysTypes.RTS_IEC_RESULT := 0;

    // === SOCKETS PRIVES ===
    FastSocket          : SysTypes.RTS_IEC_HANDLE := SysTypes.RTS_INVALID_HANDLE;
    CyclicSocket        : SysTypes.RTS_IEC_HANDLE := SysTypes.RTS_INVALID_HANDLE;
    EventSocket         : SysTypes.RTS_IEC_HANDLE := SysTypes.RTS_INVALID_HANDLE;
    NonBlocking         : DINT := 1;
    FastReply           : UDP_REPLY;
    CyclicReply         : UDP_REPLY;
    EventReply          : UDP_REPLY;
    FastTx              : ARRAY [0..15] OF BYTE;
    FastRx              : ARRAY [0..15] OF BYTE;
    CyclicTx            : ARRAY [0..15] OF BYTE;
    CyclicRx            : ARRAY [0..15] OF BYTE;
    EventTx             : ARRAY [0..15] OF BYTE;
    EventRx             : ARRAY [0..15] OF BYTE;
    FastSequence        : UINT := 0;
    CyclicSequence      : UINT := 0;
    EventSequence       : UINT := 0;
    CycleDivider        : USINT := 0;
    EventPrevious       : BOOL := FALSE;
    Bytes               : __XINT := 0;
END_VAR

IF Stop OR NOT Enable THEN
    IF FastSocket <> SysTypes.RTS_INVALID_HANDLE THEN SysSockCloseUdp(FastSocket); END_IF;
    IF CyclicSocket <> SysTypes.RTS_INVALID_HANDLE THEN SysSockCloseUdp(CyclicSocket); END_IF;
    IF EventSocket <> SysTypes.RTS_INVALID_HANDLE THEN SysSockCloseUdp(EventSocket); END_IF;
    FastSocket := SysTypes.RTS_INVALID_HANDLE;
    CyclicSocket := SysTypes.RTS_INVALID_HANDLE;
    EventSocket := SysTypes.RTS_INVALID_HANDLE;
    SocketReady := FALSE;
    EventPrevious := EventTrigger;
    RETURN;
END_IF;

// Initialisation progressive : le scan ne poursuit qu une fois les trois sockets prets.
IF FastSocket = SysTypes.RTS_INVALID_HANDLE THEN
    FastSocket := SysSockCreateUdp(29031, 29032, ADR(LastResult));
    IF FastSocket <> SysTypes.RTS_INVALID_HANDLE THEN LastResult := SysSockIoctl(FastSocket, SOCKET_FIONBIO, ADR(NonBlocking)); END_IF;
    RETURN;
END_IF;
IF CyclicSocket = SysTypes.RTS_INVALID_HANDLE THEN
    CyclicSocket := SysSockCreateUdp(29041, 29042, ADR(LastResult));
    IF CyclicSocket <> SysTypes.RTS_INVALID_HANDLE THEN LastResult := SysSockIoctl(CyclicSocket, SOCKET_FIONBIO, ADR(NonBlocking)); END_IF;
    RETURN;
END_IF;
IF EventSocket = SysTypes.RTS_INVALID_HANDLE THEN
    EventSocket := SysSockCreateUdp(29051, 29052, ADR(LastResult));
    IF EventSocket <> SysTypes.RTS_INVALID_HANDLE THEN LastResult := SysSockIoctl(EventSocket, SOCKET_FIONBIO, ADR(NonBlocking)); END_IF;
    SocketReady := (LastResult = 0);
    RETURN;
END_IF;

// Entete commun TB08, classe de flux en octet 6, sequence UINT en octets 4/5.
FastTx[0] := 16#54; FastTx[1] := 16#42; FastTx[2] := 16#30; FastTx[3] := 16#38;
FastTx[4] := UINT_TO_BYTE(FastSequence AND 16#00FF); FastTx[5] := UINT_TO_BYTE(SHR(FastSequence, 8) AND 16#00FF); FastTx[6] := 1;
Bytes := SysSockSendToUdp(FastSocket, 29031, '127.0.0.1', ADR(FastTx), SIZEOF(FastTx), ADR(LastResult));
IF Bytes = SIZEOF(FastTx) THEN FastSentCount := FastSentCount + 1; FastSequence := FastSequence + 1; ELSE SendErrorCount := SendErrorCount + 1; END_IF;

// Receptions toutes non bloquantes, meme quand leur emission est moins frequente.
Bytes := SysSockRecvFromUdp(FastSocket, ADR(FastRx), SIZEOF(FastRx), ADR(FastReply), ADR(LastResult));
IF Bytes > 0 THEN
    IF (Bytes = SIZEOF(FastRx)) AND (FastRx[0] = 16#54) AND (FastRx[6] = 1) THEN FastReceivedCount := FastReceivedCount + 1; ELSE InvalidReplyCount := InvalidReplyCount + 1; END_IF;
END_IF;

CycleDivider := CycleDivider + 1;
IF CycleDivider >= 5 THEN
    CycleDivider := 0;
    CyclicTx[0] := 16#54; CyclicTx[1] := 16#42; CyclicTx[2] := 16#30; CyclicTx[3] := 16#38;
    CyclicTx[4] := UINT_TO_BYTE(CyclicSequence AND 16#00FF); CyclicTx[5] := UINT_TO_BYTE(SHR(CyclicSequence, 8) AND 16#00FF); CyclicTx[6] := 2;
    Bytes := SysSockSendToUdp(CyclicSocket, 29041, '127.0.0.1', ADR(CyclicTx), SIZEOF(CyclicTx), ADR(LastResult));
    IF Bytes = SIZEOF(CyclicTx) THEN CyclicSentCount := CyclicSentCount + 1; CyclicSequence := CyclicSequence + 1; ELSE SendErrorCount := SendErrorCount + 1; END_IF;
END_IF;
Bytes := SysSockRecvFromUdp(CyclicSocket, ADR(CyclicRx), SIZEOF(CyclicRx), ADR(CyclicReply), ADR(LastResult));
IF Bytes > 0 THEN
    IF (Bytes = SIZEOF(CyclicRx)) AND (CyclicRx[0] = 16#54) AND (CyclicRx[6] = 2) THEN CyclicReceivedCount := CyclicReceivedCount + 1; ELSE InvalidReplyCount := InvalidReplyCount + 1; END_IF;
END_IF;

IF EventTrigger AND NOT EventPrevious THEN
    EventTx[0] := 16#54; EventTx[1] := 16#42; EventTx[2] := 16#30; EventTx[3] := 16#38;
    EventTx[4] := UINT_TO_BYTE(EventSequence AND 16#00FF); EventTx[5] := UINT_TO_BYTE(SHR(EventSequence, 8) AND 16#00FF); EventTx[6] := 3;
    Bytes := SysSockSendToUdp(EventSocket, 29051, '127.0.0.1', ADR(EventTx), SIZEOF(EventTx), ADR(LastResult));
    IF Bytes = SIZEOF(EventTx) THEN EventSentCount := EventSentCount + 1; EventSequence := EventSequence + 1; ELSE SendErrorCount := SendErrorCount + 1; END_IF;
END_IF;
EventPrevious := EventTrigger;
Bytes := SysSockRecvFromUdp(EventSocket, ADR(EventRx), SIZEOF(EventRx), ADR(EventReply), ADR(LastResult));
IF Bytes > 0 THEN
    IF (Bytes = SIZEOF(EventRx)) AND (EventRx[0] = 16#54) AND (EventRx[6] = 3) THEN EventReceivedCount := EventReceivedCount + 1; ELSE InvalidReplyCount := InvalidReplyCount + 1; END_IF;
END_IF;
