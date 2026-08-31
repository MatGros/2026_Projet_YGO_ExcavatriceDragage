(* =======================================================================
   🧩 FB_FaultCore — Socle de remplissage de ST_Fault (vue live + vue latchée)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : à partir d'une LISTE de causes en clair (ARRAY[0..15] OF
      ST_FaultCause), produire la brique ST_Fault :
        • Error / ErrorId   : vue LIVE, suit les causes Active, retombe seule.
        • Latched / LatchedId: vue LATCHÉE, chaque bit figé à l'apparition d'une
          cause `Active AND Latching`, conservé jusqu'au front Reset.
   🔒 Sécurité :
      - interlock TOUJOURS sur `Causes[i].Active` (cause brute), jamais sur le latch.
      - Reset TOUJOURS effectif, jamais conditionné (std §9) — agit même Enable=FALSE.
      - Latching=FALSE → cause visible en LIVE seulement (fail-safe : reste visible).
      - un défaut laté non acquitté reste publié même FB désactivé (pas d'effacement
        silencieux sur bascule Enable OFF→ON sans Reset).
      - une cause à acquitter réapparue re-arme son bit (ré-alarme).
   🧬 Un seul socle, réutilisé par tout FB `standard` qui expose un ST_Fault.
      Pas de State, pas de Warning, pas de texte — hors périmètre de ce socle.
   📄 Doc : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies / §9
   ======================================================================= *)

FUNCTION_BLOCK FB_FaultCore
VAR_INPUT
    Enable  : BOOL;                          // --> [CMD] Autorisation générale du FB porteur
    Reset   : BOOL;                          // --> [CMD] Front d'acquittement (jamais conditionné, §9)
    Causes  : ARRAY[0..15] OF ST_FaultCause; // --> [CMD] Liste des causes en clair (Active / Latching / Texte)
END_VAR
VAR_OUTPUT
    Ready   : BOOL;                          // <-- [STAT] FB porteur autorisé (= Enable)
    Fault   : ST_Fault;                      // <-- [DIAG] Brique défaut (mappée 1:1 sur la sortie du FB porteur)
END_VAR
VAR
    ResetEdge : R_TRIG;                      // . [LOC] Front montant Reset
    Latch     : ARRAY[0..15] OF BOOL;        // . [LOC] Bit laté par cause, jusqu'au Reset
    i         : INT;                         // . [LOC] Index de parcours de la liste
END_VAR

{region "§1 Reset (front, toujours effectif)"}
// Front Reset : efface tous les latches. Jamais conditionné, agit même Enable=FALSE (§9).
Ready := Enable;
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    FOR i := 0 TO 15 DO Latch[i] := FALSE; END_FOR;
END_IF;
{endregion}

{region "§2 Vue LIVE — Error / ErrorId"}
// Bitfield des causes présentes MAINTENANT. Retombe seule à 0 quand les causes disparaissent.
// Non évaluée si Enable=FALSE (pas de lecture de cause hors autorisation).
Fault.ErrorId := 0;
IF Enable THEN
    FOR i := 0 TO 15 DO
        IF Causes[i].Active THEN
            Fault.ErrorId := Fault.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));
        END_IF;
    END_FOR;
END_IF;
Fault.Error := (Fault.ErrorId <> 0);
{endregion}

{region "§3 Armement des latches (causes à acquitter)"}
// Une cause Active ET Latching arme son bit ; le bit reste jusqu'au front Reset (§1),
// même si la cause disparaît. Réapparition => ré-armement (ré-alarme).
IF Enable THEN
    FOR i := 0 TO 15 DO
        IF Causes[i].Active AND Causes[i].Latching THEN
            Latch[i] := TRUE;
        END_IF;
    END_FOR;
END_IF;
{endregion}

{region "§4 Vue LATCHÉE — Latched / LatchedId"}
// Toujours publiée, y compris Enable=FALSE : un défaut non acquitté reste visible.
Fault.LatchedId := 0;
FOR i := 0 TO 15 DO
    IF Latch[i] THEN
        Fault.LatchedId := Fault.LatchedId OR SHL(WORD#1, INT_TO_DWORD(i));
    END_IF;
END_FOR;
Fault.Latched := (Fault.LatchedId <> 0);
{endregion}

END_FUNCTION_BLOCK
