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
