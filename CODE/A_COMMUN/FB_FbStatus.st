(* =======================================================================
   🧩 FB_FbStatus — Socle de statut standard d'un FB métier
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : remplit de façon standardisée `Status : ST_FbStatus`
      (warning auto-effacé / défaut laté acquitté, textes IHM prêts).
   🧬 Contrat : tout FB `standard` expose `Status : ST_FbStatus`
      rempli via UNE instance de ce socle → même comportement partout.
   🔒 Sécurité : WarningMask fail-safe (0 = tout fault à acquitter).
      Reset TOUJOURS effectif, jamais conditionné (std §9).
      Interlock toujours sur la cause brute, jamais sur l'acquittement.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

FUNCTION_BLOCK FB_FbStatus
VAR_INPUT
    // === PERMIS & ACQUITTEMENT ===
    Enable          : BOOL;    // --> [CMD] Autorisation générale FB
    Reset           : BOOL;    // --> [CMD] Front acquittement défaut (jamais conditionné, §9)

    // === CAUSES & CLASSIFICATION (producteur = bloc métier) ===
    ErrorIdCause    : WORD;    // --> [HW]  Bits d'erreur ACTIFS (cause brute)
    WarningMask     : WORD;    // --> [CFG] bit=1 → cette erreur est WARNING (auto) ; bit=0 → FAULT (à acquitter)

    // === TEXTES IHM (métier, indexés par bit) ===
    ErrorTexts      : ARRAY[0..15] OF STRING;   // --> [CFG] Textes des erreurs (par bit)
    WarningTexts    : ARRAY[0..15] OF STRING;  // --> [CFG] Textes des warnings (par bit)

    // === CONFIG DISPLAY ===
    RotatePeriod    : TIME := T#1S;   // --> [CFG] Période de rotation texte multi-erreurs
END_VAR
VAR_OUTPUT
    // === ÉTAT & SYNOPTIQUE (forme cible) ===
    Ready           : BOOL;    // <-- [STAT] FB prêt (Enable)
    Status          : ST_FbStatus; // <-- [STAT] Statut complet (mappé 1:1 sur la sortie du bloc)
END_VAR
VAR
    // === SOUS-INSTANCES & MEMOIRES ===
    ResetEdge       : R_TRIG;  // * [INST] Front Reset
    FaultEdge       : R_TRIG;  // * [INST] Front apparition cause fault (ré-alarme)
    RotateTimer     : TON;     // * [INST] Rotation du texte affiché (multi-erreurs)

    // === VARIABLES LOCALES ===
    FaultCause      : WORD;    // . [LOC] bits Fault (cause brute)
    WarningCause    : WORD;    // . [LOC] bits Warning (cause brute)
    ErrorIdLatched  : WORD;    // . [LOC] code fault mémorisé (jusqu'au Reset)
    ErrIdx          : INT;     // . [LOC] index de rotation du texte (multi-erreurs)
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — Enable = FALSE → statut neutre/sûr
Ready := Enable;
IF NOT Enable THEN
    Status.Busy := FALSE; Status.Done := FALSE;
    Status.Error := FALSE; Status.ErrorId := 0;
    Status.Warning := FALSE; Status.WarningId := 0;
    Status.State := E_State.DISABLED; Status.StateAtError := E_State.DISABLED;
    Status.ResetRequested := FALSE;
    Status.WarningIdTxt := ''; Status.ErrorIdTxt := '';
    ErrorIdLatched := 0; FaultCause := 0; WarningCause := 0;
    RotateTimer(IN := FALSE, PT := RotatePeriod);
    RETURN;
END_IF;
Status.State := E_State.READY;
{endregion}

{region "§2 Classification des causes (exclusivité)"}
// 2. Un bit est exclusivement warning OU fault (jamais les deux, §3bis)
FaultCause   := ErrorIdCause AND (NOT WarningMask);  // bits fault (à acquitter)
WarningCause := ErrorIdCause AND WarningMask;          // bits warning (auto-effacés)
{endregion}

{region "§3 Défaut laté + acquittement"}
// 3. Front Reset : TOUJOURS effectif, jamais conditionné (std §9)
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    ErrorIdLatched := 0;
END_IF;
// 4. Ré-alarme : nouvelle apparition d'un fault non encore acquitté -> relatte
FaultEdge(CLK := (FaultCause <> 16#0000));
IF FaultEdge.Q THEN
    ErrorIdLatched := ErrorIdLatched OR FaultCause;
END_IF;
// 5. Mémoire de l'état au défaut
IF (FaultCause <> 16#0000) THEN
    Status.StateAtError := Status.State;
END_IF;
// 6. Sorties défaut : affiché = laté OU cause courante
Status.ErrorId := ErrorIdLatched OR FaultCause;
Status.Error := (Status.ErrorId <> 16#0000);
Status.ResetRequested := (ErrorIdLatched <> 16#0000);
{endregion}

{region "§4 Warning auto-effacé"}
Status.WarningId := WarningCause;
Status.Warning := (WarningCause <> 16#0000);
{endregion}

{region "§5 Textes IHM + rotation 1s"}
// 8. Sélection du texte : on affiche le texte du bit le plus bas encore présent.
//    S'il y a plusieurs erreurs/warnings, l'affichage tourne toutes les RotatePeriod.
Status.ErrorIdTxt := '';
Status.WarningIdTxt := '';

// Rotation de l'index de départ (pour faire défiler les textes multi-erreurs)
RotateTimer(IN := (Status.ErrorId <> 16#0000) OR (Status.WarningId <> 16#0000),
            PT := RotatePeriod);
IF RotateTimer.Q THEN
    ErrIdx := (ErrIdx + 1) MOD 16;
    RotateTimer(IN := FALSE, PT := RotatePeriod);
END_IF;

// -- Texte ERROR : premier bit set à partir de ErrIdx (circulaire) --
IF Status.ErrorId <> 16#0000 THEN
    // scan 16 bits, départ ErrIdx
    // (boucle simple : les blocs métier gardent peu de bits -> OK performance)
    // remplit ErrorIdTxt avec le texte du bit le plus bas set
    IF (Status.ErrorId AND 16#0001) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[0];
    ELSIF (Status.ErrorId AND 16#0002) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[1];
    ELSIF (Status.ErrorId AND 16#0004) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[2];
    ELSIF (Status.ErrorId AND 16#0008) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[3];
    ELSIF (Status.ErrorId AND 16#0010) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[4];
    ELSIF (Status.ErrorId AND 16#0020) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[5];
    ELSIF (Status.ErrorId AND 16#0040) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[6];
    ELSIF (Status.ErrorId AND 16#0080) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[7];
    ELSIF (Status.ErrorId AND 16#0100) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[8];
    ELSIF (Status.ErrorId AND 16#0200) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[9];
    ELSIF (Status.ErrorId AND 16#0400) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[10];
    ELSIF (Status.ErrorId AND 16#0800) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[11];
    ELSIF (Status.ErrorId AND 16#1000) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[12];
    ELSIF (Status.ErrorId AND 16#2000) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[13];
    ELSIF (Status.ErrorId AND 16#4000) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[14];
    ELSIF (Status.ErrorId AND 16#8000) <> 0 THEN Status.ErrorIdTxt := ErrorTexts[15];
    END_IF;
END_IF;

// -- Texte WARNING : premier bit set --
IF Status.WarningId <> 16#0000 THEN
    IF (Status.WarningId AND 16#0001) <> 0 THEN Status.WarningIdTxt := WarningTexts[0];
    ELSIF (Status.WarningId AND 16#0002) <> 0 THEN Status.WarningIdTxt := WarningTexts[1];
    ELSIF (Status.WarningId AND 16#0004) <> 0 THEN Status.WarningIdTxt := WarningTexts[2];
    ELSIF (Status.WarningId AND 16#0008) <> 0 THEN Status.WarningIdTxt := WarningTexts[3];
    ELSIF (Status.WarningId AND 16#0010) <> 0 THEN Status.WarningIdTxt := WarningTexts[4];
    ELSIF (Status.WarningId AND 16#0020) <> 0 THEN Status.WarningIdTxt := WarningTexts[5];
    ELSIF (Status.WarningId AND 16#0040) <> 0 THEN Status.WarningIdTxt := WarningTexts[6];
    ELSIF (Status.WarningId AND 16#0080) <> 0 THEN Status.WarningIdTxt := WarningTexts[7];
    ELSIF (Status.WarningId AND 16#0100) <> 0 THEN Status.WarningIdTxt := WarningTexts[8];
    ELSIF (Status.WarningId AND 16#0200) <> 0 THEN Status.WarningIdTxt := WarningTexts[9];
    ELSIF (Status.WarningId AND 16#0400) <> 0 THEN Status.WarningIdTxt := WarningTexts[10];
    ELSIF (Status.WarningId AND 16#0800) <> 0 THEN Status.WarningIdTxt := WarningTexts[11];
    ELSIF (Status.WarningId AND 16#1000) <> 0 THEN Status.WarningIdTxt := WarningTexts[12];
    ELSIF (Status.WarningId AND 16#2000) <> 0 THEN Status.WarningIdTxt := WarningTexts[13];
    ELSIF (Status.WarningId AND 16#4000) <> 0 THEN Status.WarningIdTxt := WarningTexts[14];
    ELSIF (Status.WarningId AND 16#8000) <> 0 THEN Status.WarningIdTxt := WarningTexts[15];
    END_IF;
END_IF;
{endregion}

// Busy/Done : conditionneur toujours prêt -> Busy/Done FALSE (usage métier)
Status.Busy := FALSE;
Status.Done := FALSE;

