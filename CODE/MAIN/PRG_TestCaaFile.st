(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_TestCaaFile — Test écriture CSV avec CAA File
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : sur front xStart, ouvre/écrit/ferme un fichier CSV
      (avec le pool async CAA File initialisé par PRG_PoolInit).
   📄 Docs : bibliothèque CAA File 3.5.19 (namespace FILE).
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_TestCaaFile

VAR
    fbOpen    : FILE.Open;
    fbWrite   : FILE.Write;
    fbClose   : FILE.Close;
    hFile     : CAA.HANDLE;
    sFileName : STRING(120) := 'test_snapshot.csv';
    sCsvLine  : STRING(255);
    xStart    : BOOL := FALSE;
    TestDone  : BOOL := FALSE;
    TestError : BOOL := FALSE;
    iStep     : INT := 0;
    iGood     : INT := 520;
    iBad      : INT := 41;
END_VAR

CASE iStep OF
    0:
        TestDone := FALSE;
        IF xStart THEN
            xStart := FALSE;
            sCsvLine := CONCAT('Pieces_OK;', TO_STRING(iGood));
            sCsvLine := CONCAT(sCsvLine, '$NPieces_NOK;');
            sCsvLine := CONCAT(sCsvLine, TO_STRING(iBad));
            sCsvLine := CONCAT(sCsvLine, '$N');
            iStep := 10;
        END_IF;

    10:  // Open
        fbOpen(xExecute := TRUE, sFileName := sFileName, eFileMode := FILE.MODE.MWRITE);
        IF fbOpen.xDone THEN
            hFile := fbOpen.hFile;
            fbOpen(xExecute := FALSE);
            iStep := 11;
        ELSIF fbOpen.xError THEN
            TestError := TRUE; iStep := 99;
        END_IF;

    11:  // Write
        fbWrite(xExecute := TRUE, hFile := hFile,
                pBuffer := ADR(sCsvLine), szSize := TO_UDINT(LEN(sCsvLine)));
        IF fbWrite.xDone THEN
            fbWrite(xExecute := FALSE); iStep := 12;
        ELSIF fbWrite.xError THEN
            TestError := TRUE; iStep := 99;
        END_IF;

    12:  // Close
        fbClose(xExecute := TRUE, hFile := hFile);
        IF fbClose.xDone THEN
            fbClose(xExecute := FALSE); TestDone := TRUE; iStep := 0;
        ELSIF fbClose.xError THEN
            TestError := TRUE; iStep := 99;
        END_IF;

    99:  // Erreur → reset
        fbOpen(xExecute := FALSE); fbWrite(xExecute := FALSE); fbClose(xExecute := FALSE);
        iStep := 0;
END_CASE;
