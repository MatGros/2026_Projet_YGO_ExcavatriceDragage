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

    // === VARIABLES LOCALES ===
    FaultCause      : WORD;    // . [LOC] bits Fault (cause brute)
    WarningCause    : WORD;    // . [LOC] bits Warning (cause brute)
    ErrorIdLatched  : WORD;    // . [LOC] code fault mémorisé (jusqu'au Reset)
    i               : INT;     // . [LOC] index de boucle (recherche du premier bit actif)
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
FaultEdge(CLK := (FaultCause <> 0));
IF FaultEdge.Q THEN
    ErrorIdLatched := ErrorIdLatched OR FaultCause;
END_IF;
// 5. Mémoire de l'état au défaut
IF (FaultCause <> 0) THEN
    Status.StateAtError := Status.State;
END_IF;
// 6. Sorties défaut : ErrorId = TOUS les bits (fault laté + warning auto-effacé).
//    WarningId reste le sous-ensemble warning (affichage IHM orange).
Status.ErrorId := ErrorIdLatched OR FaultCause OR WarningCause;
Status.Error := (Status.ErrorId <> 0);
Status.ResetRequested := (ErrorIdLatched <> 0);
{endregion}

{region "§4 Warning auto-effacé"}
Status.WarningId := WarningCause;
Status.Warning := (WarningCause <> 0);
{endregion}

{region "§5 Textes IHM"}
// 8. Sélection du texte : on affiche le texte du premier bit actif (le plus bas).
//    Parcours par boucle FOR + SHR (décalage) -> on lit le bit directement, aucun masque.
Status.ErrorIdTxt := '';
Status.WarningIdTxt := '';

// -- Texte ERROR : premier bit actif --
FOR i := 0 TO 15 DO
    IF (SHR(Status.ErrorId, i) AND 1) <> 0 THEN
        Status.ErrorIdTxt := ErrorTexts[i];
        EXIT;
    END_IF;
END_FOR;

// -- Texte WARNING : premier bit actif --
FOR i := 0 TO 15 DO
    IF (SHR(Status.WarningId, i) AND 1) <> 0 THEN
        Status.WarningIdTxt := WarningTexts[i];
        EXIT;
    END_IF;
END_FOR;
{endregion}

// Busy/Done : pilotés par le FB MÉTIER (cycle propre), pas par le socle.
// Le socle ne décide pas du cycle du FB métier — il gère Error/Warning/State/textes.
// Un conditionneur synchrone (ex. joystick) les laisse à FALSE ; un organe à cycle
// (treuil, séquenceur) les pilote lui-même après l'appel du socle.

END_FUNCTION_BLOCK

