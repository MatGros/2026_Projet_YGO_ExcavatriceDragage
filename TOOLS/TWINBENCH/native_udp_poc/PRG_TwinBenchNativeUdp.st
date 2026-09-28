(* =======================================================================
   PRG_TwinBenchNativeUdp — POC transport UDP natif Control Win
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Mesurer un echo UDP loopback dans une tâche 10 ms isolée
   🔒 Polarité : Enable=FALSE ferme le socket ; aucun lien M3 ni sortie PLC
   🔌 Interface : SysSocket System, 127.0.0.1:29031/29032 uniquement
   ======================================================================= *)
PROGRAM PRG_TwinBenchNativeUdp
VAR
    // === COMMANDE POC ===
    Enable              : BOOL := FALSE;  // TRUE = mesure UDP locale active
    Stop                : BOOL := FALSE;  // TRUE = fermeture explicite socket

    // === ETAT PUBLIC ===
    SocketReady         : BOOL := FALSE;
    SentCount           : UDINT := 0;
    ReceivedCount       : UDINT := 0;
    SendErrorCount      : UDINT := 0;
    InvalidReplyCount   : UDINT := 0;
    LastResult          : SysTypes.RTS_IEC_RESULT := 0;
    LastBytesSent       : __XINT := 0;
    LastBytesReceived   : __XINT := 0;

    // === SOCKET PRIVE ===
    SocketHandle        : SysTypes.RTS_IEC_HANDLE := SysTypes.RTS_INVALID_HANDLE;
    NonBlocking         : DINT := 1;
    Reply               : UDP_REPLY;
    Tx                  : ARRAY [0..15] OF BYTE;
    Rx                  : ARRAY [0..15] OF BYTE;
    TxSequence          : UINT := 0;
END_VAR

// Le POC est inerte par défaut et ferme explicitement le port sous Control Win.
IF Stop OR NOT Enable THEN
    IF SocketHandle <> SysTypes.RTS_INVALID_HANDLE THEN
        SysSockCloseUdp(SocketHandle);
    END_IF;
    SocketHandle := SysTypes.RTS_INVALID_HANDLE;
    SocketReady := FALSE;
    RETURN;
END_IF;

// Un socket par programme, ports constants : destination 29031, retour 29032.
IF SocketHandle = SysTypes.RTS_INVALID_HANDLE THEN
    SocketHandle := SysSockCreateUdp(29031, 29032, ADR(LastResult));
    IF SocketHandle <> SysTypes.RTS_INVALID_HANDLE THEN
        LastResult := SysSockIoctl(SocketHandle, SOCKET_FIONBIO, ADR(NonBlocking));
        SocketReady := (LastResult = 0);
    END_IF;
    RETURN;
END_IF;

// Paquet fixe : "TB08", sequence UINT little-endian, reste reserve a zero.
Tx[0] := 16#54;
Tx[1] := 16#42;
Tx[2] := 16#30;
Tx[3] := 16#38;
Tx[4] := UINT_TO_BYTE(TxSequence AND 16#00FF);
Tx[5] := UINT_TO_BYTE(SHR(TxSequence, 8) AND 16#00FF);
Tx[6] := 0; Tx[7] := 0; Tx[8] := 0; Tx[9] := 0;
Tx[10] := 0; Tx[11] := 0; Tx[12] := 0; Tx[13] := 0;
Tx[14] := 0; Tx[15] := 0;

LastBytesSent := SysSockSendToUdp(SocketHandle, 29031, '127.0.0.1', ADR(Tx), SIZEOF(Tx), ADR(LastResult));
IF LastBytesSent = SIZEOF(Tx) THEN
    SentCount := SentCount + 1;
    TxSequence := TxSequence + 1;
ELSE
    SendErrorCount := SendErrorCount + 1;
END_IF;

// Non-bloquant : l'absence de réponse est normale au scan courant.
LastBytesReceived := SysSockRecvFromUdp(SocketHandle, ADR(Rx), SIZEOF(Rx), ADR(Reply), ADR(LastResult));
IF LastBytesReceived > 0 THEN
    IF (LastBytesReceived = SIZEOF(Rx))
       AND (Rx[0] = 16#54) AND (Rx[1] = 16#42)
       AND (Rx[2] = 16#30) AND (Rx[3] = 16#38) THEN
        ReceivedCount := ReceivedCount + 1;
    ELSE
        InvalidReplyCount := InvalidReplyCount + 1;
    END_IF;
END_IF;
