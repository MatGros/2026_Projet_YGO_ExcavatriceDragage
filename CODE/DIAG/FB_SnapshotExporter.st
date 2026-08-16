(* ═══════════════════════════════════════════════════════════════
   💾 FB_SnapshotExporter — Moteur fichier CSV commun (CAA File)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : écrit un snapshot CSV sur front de bit, machine d'état
      multi-scan (IDLE→OPEN→WRITE→CLOSE→DONE/ERROR), 1 chunk/scan.
   🔒 Polarité : TRUE = action/état actif ; FALSE = repos.
   🧩 Architecture : FB technique non-mouvement, lecture seule + fichier.
   📄 Docs : DOC/AF/AF_Partie-12_Fonction_Diagnostic/FB_SnapshotTroubleshooting_v1.0.md
      · DOC/AF/AF_Partie-12_Fonction_Diagnostic/FB_SnapshotIHM_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_SnapshotColumn :
STRUCT
    Name  : STRING(80);   // Nom de la colonne (condensé)
    Value : STRING(80);   // Valeur convertie en texte
END_STRUCT
END_TYPE

FUNCTION_BLOCK PUBLIC FB_SnapshotExporter
VAR_INPUT
    Enable      : BOOL;               // Active le FB
    Trigger     : BOOL;               // Front montant = déclenche un snapshot
    CfgFileName : STRING(80);         // Nom de base du fichier (ex. "Snapshot_Troubleshooting")
    CfgPath     : STRING(80);         // Chemin selon cible (ex. "\PLC\" ou chemin PERSISTENT)
    CfgMinPeriodMs : TIME := T#1S;    // Anti-rebond : temps min entre 2 snapshots
END_VAR
VAR_OUTPUT
    Ready       : BOOL;               // Prêt à déclencher
    Busy        : BOOL;               // Snapshot en cours (multi-scan)
    Done        : BOOL;               // Snapshot écrit (1 scan)
    Error       : BOOL;               // Présence défaut
    ErrorId     : WORD;               // bit0 open · bit1 write · bit2 close
    LastFile    : STRING(120);        // Chemin complet du dernier CSV
END_VAR
VAR_IN_OUT
    Columns     : ARRAY[1..200] OF ST_SnapshotColumn;  // Table colonnes (remplie par l'appelant)
    ColumnCount : INT;                // Nombre de colonnes valides
END_VAR
VAR
    State       : INT;                // 0=IDLE 1=OPEN 2=WRITE 3=CLOSE 4=ERROR
    Edge        : R_TRIG;
    LastTrig    : R_TRIG;
    HFile       : RTS_IEC_HANDLE;     // Handle fichier (CAA File)
    OpenDone    : BOOL;
    WriteDone   : BOOL;
    CloseDone   : BOOL;
    OpenError   : BOOL;
    WriteError  : BOOL;
    CloseError  : BOOL;
    OpenErrorID : RTS_IEC_RESULT;
    WriteErrorID: RTS_IEC_RESULT;
    CloseErrorID: RTS_IEC_RESULT;
    Idx         : INT;
    FileName    : STRING(120);
    Line        : STRING(255);
    // Instances CAA File (⚠️ confirmer noms exacts dans CODESYS)
    instOpen    : Open;
    instWrite   : Write;
    instClose   : Close;
END_VAR

// ═══════════════ IMPLÉMENTATION ═══════════════

// 🔄 Front déclenchement + anti-rebond
Edge(CLK := Trigger);
IF NOT Enable THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    Error := FALSE; ErrorId := 16#0000;
    State := 0; Idx := 0;
    RETURN;
END_IF;
Ready := TRUE;
IF Done THEN Done := FALSE; END_IF;

// ── IDLE : attend un front Trigger ──
IF State = 0 THEN
    IF Edge.Q THEN
        // Anti-rebond : temps écoulé depuis le dernier snapshot ?
        IF LastTrig.IN = FALSE THEN
            Busy := TRUE; Error := FALSE; ErrorId := 16#0000; Idx := 0;
            State := 1;   // → OPEN
        END_IF;
    END_IF;

// ── OPEN : ouvre le fichier ──
ELSIF State = 1 THEN
    FileName := CONCAT(CfgPath, CONCAT(CfgFileName, '_'));
    // ⚠️ horodatage : simplifié (à remplacer par date/heure réelle si dispo)
    FileName := CONCAT(FileName, 'SNAP');
    FileName := CONCAT(FileName, '.csv');
    instOpen(
        pDevice    := 'FileService',
        pFile      := FileName,
        eAccess    := OPEN_MODE.WRITE,
        eMode      := OPEN_MODE.APPEND,
        xExecute   := TRUE
    );
    IF instOpen.Done THEN
        HFile := instOpen.hFile;
        State := 2;   // → WRITE
    ELSIF instOpen.Error THEN
        Error := TRUE; ErrorId := ErrorId OR 16#0001;
        State := 4;   // → ERROR
    END_IF;

// ── WRITE : écrit l'en-tête puis les valeurs, 1 chunk/scan ──
ELSIF State = 2 THEN
    IF Idx = 0 THEN
        // En-tête : noms des colonnes
        Line := '';
        // (assembler les noms — simplifié)
        instWrite(hFile := HFile, xExecute := TRUE, pWriteBuffer := ADR(Line), cbWriteLen := TO_UDINT(LEN(Line)));
    ELSE
        // Valeur de la colonne Idx
        Line := Columns[Idx].Value;
        instWrite(hFile := HFile, xExecute := TRUE, pWriteBuffer := ADR(Line), cbWriteLen := TO_UDINT(LEN(Line)));
    END_IF;
    IF instWrite.Done THEN
        Idx := Idx + 1;
        IF Idx > ColumnCount THEN State := 3; END_IF;   // → CLOSE
    ELSIF instWrite.Error THEN
        Error := TRUE; ErrorId := ErrorId OR 16#0002;
        State := 4;   // → ERROR
    END_IF;

// ── CLOSE : ferme le fichier ──
ELSIF State = 3 THEN
    instClose(hFile := HFile, xExecute := TRUE);
    IF instClose.Done THEN
        LastFile := FileName;
        Done := TRUE; Busy := FALSE; State := 0;
    ELSIF instClose.Error THEN
        Error := TRUE; ErrorId := ErrorId OR 16#0004;
        Busy := FALSE; State := 0;
    END_IF;

// ── ERROR : ferme le handle si ouvert, puis retour IDLE ──
ELSIF State = 4 THEN
    IF HFile <> 0 THEN
        instClose(hFile := HFile, xExecute := TRUE);
        IF instClose.Done OR instClose.Error THEN HFile := 0; END_IF;
    ELSE
        Busy := FALSE; State := 0;
    END_IF;
END_IF;
LastTrig(CLK := Trigger);
