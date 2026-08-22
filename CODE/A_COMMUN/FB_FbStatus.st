(* =======================================================================
   🧩 FB_FbStatus — Socle de statut standard d'un FB métier
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : remplit de façon standardisée `Status : ST_FbStatus`
      à partir d'une LISTE de causes claires (ARRAY[0..15] OF ST_FbCause).
      Plus de bitfield WORD en entrée, plus de masque, plus de tableau de
      textes indexé par bit — le FB métier exprime ses défauts en clair.
   🧬 Contrat : tout FB `standard` expose `Status : ST_FbStatus`
      rempli via UNE instance de ce socle → même comportement partout.
   🔒 Sécurité :
      - interlock TOUJOURS sur `Causes[i].Active` (cause brute), jamais sur l'acquittement.
      - Reset TOUJOURS effectif (std §9), jamais conditionné.
      - IsWarning=1 → warning AUTO-EFFACÉ (ne lève jamais Error) ; IsWarning=0 → fault à acquitter (laté).
      - une cause fault réapparue se re-lathe automatiquement (ré-alarme).
      - une cause reclassée warning purge son latch résiduel (pas de défaut fantôme).
      - StateAtError : capture UNIQUE au premier défaut, gelé jusqu'au Reset.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

FUNCTION_BLOCK FB_FbStatus
VAR_INPUT
    // === PERMIS & ACQUITTEMENT ===
    Enable          : BOOL;    // --> [CMD] Autorisation générale FB
    Reset           : BOOL;    // --> [CMD] Front acquittement défaut (jamais conditionné, §9)

    // --- CAUSES (producteur = bloc métier, en clair) ---
    Causes          : ARRAY[0..15] OF ST_FbCause;  // --> [HW] Liste des causes (Active/IsWarning/Texte)
END_VAR
VAR_OUTPUT
    // --- ÉTAT & SYNOPTIQUE (forme cible) ---
    Ready           : BOOL;    // <-- [STAT] FB prêt (Enable)
    Status          : ST_FbStatus; // <-- [STAT] Statut complet (mappé 1:1 sur la sortie du bloc)
END_VAR
VAR
    // --- SOUS-INSTANCES & MEMOIRES ---
    ResetEdge         : R_TRIG;              // * [INST] Front Reset
    Latch             : ARRAY[0..15] OF BOOL;// . [LOC] Défaut laté par cause (jusqu'au Reset)
    StateAtErrorArmed : BOOL;                // . [LOC] Flag : StateAtError capturé UNE fois
    i                 : INT;                 // . [LOC] index de parcours de la liste
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — Enable = FALSE → statut neutre/sûr.
//    ⚠️ Les latches de défaut sont CONSERVÉS (décision utilisateur) : un défaut
//    non acquitté ne doit pas être effacé silencieusement par une bascule Enable
//    OFF→ON sans Reset (jamais de redémarrage auto après défaut). Au ré-enable,
//    §3 relatche naturellement toute cause encore active ; un défaut laté persistant
//    redevient visible jusqu'au Reset.
Ready := Enable;
IF NOT Enable THEN
    Status.Busy := FALSE; Status.Done := FALSE;
    Status.Error := FALSE; Status.ErrorId := 0;
    Status.Warning := FALSE; Status.WarningId := 0;
    Status.State := E_State.DISABLED; Status.StateAtError := E_State.DISABLED;
    Status.ResetRequested := FALSE;
    Status.ErrorIdTxt := ''; Status.WarningIdTxt := '';
    RETURN;
END_IF;
Status.State := E_State.READY;
{endregion}

{region "=== §2 Reset (front, toujours effectif) ==="}
// 2. Front Reset : TOUJOURS effectif, jamais conditionné (std §9).
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    FOR i := 0 TO 15 DO Latch[i] := FALSE; END_FOR;
    StateAtErrorArmed := FALSE;
END_IF;
{endregion}

{region "=== §3 Classification + latch par cause ==="}
// 3. Parcours de la LISTE (source de vérité = cause brute Active).
//    - IsWarning=TRUE  → warning : auto-effacé + purge d'un latch résiduel (reclassement, sans défaut fantôme).
//    - IsWarning=FALSE → fault : laté dès qu'Active ; conservé après disparition ; re-laté s'il revient.
FOR i := 0 TO 15 DO
    IF Causes[i].IsWarning THEN
        Latch[i] := FALSE;
    ELSE
        IF Causes[i].Active THEN Latch[i] := TRUE; END_IF;
    END_IF;
END_FOR;
{endregion}

{region "=== §4 StateAtError — capture au premier défaut ==="}
// 4. État mémorisé au moment de l'apparition du défaut (gelé jusqu'au Reset).
IF NOT StateAtErrorArmed THEN
    FOR i := 0 TO 15 DO
        IF Latch[i] OR (Causes[i].Active AND NOT Causes[i].IsWarning) THEN
            Status.StateAtError := Status.State;   // State déjà READY (§1)
            StateAtErrorArmed := TRUE;
            EXIT;
        END_IF;
    END_FOR;
END_IF;
{endregion}

{region "=== §5 Sorties Error / Warning / ResetRequested ==="}
// 5. Sorties : ErrorId réservé aux DÉFAUTS (à acquitter) ; les warnings sont
//    séparés dans WarningId. Un warning ne lève JAMAIS Error ni ne pollue ErrorId
//    (décision utilisateur : un IHM qui lit ErrorId ne voit pas de faux défaut).
Status.ErrorId := 0; Status.WarningId := 0;
Status.Error := FALSE; Status.Warning := FALSE; Status.ResetRequested := FALSE;
FOR i := 0 TO 15 DO
    // Défaut laté OU actif
    IF Latch[i] OR (Causes[i].Active AND NOT Causes[i].IsWarning) THEN
        Status.ErrorId := Status.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));
        Status.Error := TRUE;
        Status.ResetRequested := TRUE;
    END_IF;
    // Warning auto-effacé : uniquement dans WarningId (séparé de ErrorId)
    IF Causes[i].Active AND Causes[i].IsWarning THEN
        Status.WarningId := Status.WarningId OR SHL(WORD#1, INT_TO_DWORD(i));
        Status.Warning := TRUE;
    END_IF;
END_FOR;
{endregion}

{region "=== §6 Textes IHM — parcours de liste ==="}
// 6. Sélection du texte par parcours de la LISTE (première cause active, index le plus bas).
//    Plus de WHILE ni de masque. Hypothèse : `Causes[i].Texte` reste renseigné par l'appelant.
Status.ErrorIdTxt := ''; Status.WarningIdTxt := '';
FOR i := 0 TO 15 DO
    IF Latch[i] OR (Causes[i].Active AND NOT Causes[i].IsWarning) THEN
        Status.ErrorIdTxt := Causes[i].Texte; EXIT;
    END_IF;
END_FOR;
FOR i := 0 TO 15 DO
    IF Causes[i].Active AND Causes[i].IsWarning THEN
        Status.WarningIdTxt := Causes[i].Texte; EXIT;
    END_IF;
END_FOR;
{endregion}

// Busy/Done : pilotés par le FB MÉTIER (cycle propre), pas par le socle.
// Un conditionneur synchrone (joystick) les laisse à FALSE ; un organe à cycle les pilote lui-même.

END_FUNCTION_BLOCK
