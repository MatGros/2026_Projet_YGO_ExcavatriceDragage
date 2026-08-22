(* =======================================================================
   🛡️ FB_Brake — Séquence frein à manque de courant (temps physiques)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Gestion temporisée ouverture/fermeture frein à manque de courant
   🔒 Polarité : Sécurité positive (BrakeCmd=FALSE = frein collé au repos)
   🔌 Interface : Double vérification retour contacteur (ST_ContactorCheck)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md §3
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Brake
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                  : BOOL;               // --> [CMD]  Autorisation generale (FALSE = frein colle)
    Reset                   : BOOL;               // --> [CMD]  Acquittement defaut (front)
    MovementRequested       : BOOL;               // --> [CMD]  Demande de mouvement (sens+palier actifs)

    // === RETOURS MATERIELS & SIMULATION ===
    ContactorFeedback       : BOOL;               // --> [HW]   Retour contacteur frein (TRUE = relache/ouvert)
    BypassContactorCheck    : BOOL;               // --> [TST]  Bypass controle contacteur (simu)

    // === TEMPORISATIONS ET REGLAGES ===
    DelayContactClose       : TIME := T#100ms;    // --> [CFG]  Temps de fermeture contacteur de puissance
    DelayMagnetise          : TIME := T#300ms;    // --> [CFG]  Delai magnetisation moteur avant ouverture frein
    DelayMotorDecel         : TIME := T#500ms;    // --> [CFG]  Delai deceleration avant collage frein
    FeedbackTimeout         : TIME := T#1s;       // --> [CFG]  Delai max coherence commande/retour frein
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DERIVATION ===
    Ready                   : BOOL;               // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "incoherence retour contacteur".
    Status                  : ST_FbStatus;

    // === COMMANDES ET CONFIRMATIONS ===
    BrakeCmd                : BOOL;               // <-- [ACT]  Commande bobine frein (TRUE = relache/ouvert)
    BrakeCommandOpenConfirmed : BOOL;            // <-- [STAT] Confirmation ouverture frein pour verrous
    ContactorCheck          : ST_ContactorCheck;  // <-- [DIAG] Diagnostic detaille retour contacteur
END_VAR
VAR
    // === TRIGGERS ET DETECTION FRONTS ===
    ResetEdge               : R_TRIG;             // . [LOC]  Detecteur front acquittement
    ErrorEdge               : R_TRIG;             // . [LOC]  Detecteur front apparition defaut
    BypassEdge              : R_TRIG;             // . [LOC]  Detecteur front activation bypass

    // === TEMPORISATEURS INTERNES ===
    TonMagnetise            : TON;                // . [LOC]  Temporisation avant relachement frein
    TonDecel                : TON;                // . [LOC]  Temporisation avant collage frein
    TonFeedback             : TON;                // . [LOC]  Timeout de coherence commande/retour
END_VAR

{region "§1 Gate"}
// 🛑 1. GATE — pas d'Enable = frein collé (sécurité positive), aucune temporisation en cours
IF NOT Enable THEN
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    BrakeCmd := FALSE;
    Status.State := E_State.DISABLED;
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
{endregion}

{region "§2 Reset et fronts"}
// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);
BypassEdge(CLK := BypassContactorCheck);
{endregion}

{region "§3 Séquence temporisée"}
// 🛠️ 3. SÉQUENCE TEMPORISÉE (démarrage vs arrêt)
IF MovementRequested THEN
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    TonMagnetise(IN := TRUE, PT := DelayMagnetise + DelayContactClose);
    IF TonMagnetise.Q THEN
        BrakeCmd := TRUE;              // ✅ Contacteur + magnétisation acquis → relâche
        Status.State := E_State.DONE;
    ELSE
        BrakeCmd := FALSE;             // ⏳ Encore collé pendant la magnétisation
        Status.State := E_State.BUSY;
    END_IF;
ELSE
    // Sécurité positive : fermeture immédiate du frein (collé) dès que les contacteurs de sens s'ouvrent
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    BrakeCmd := FALSE;                 // Fermeture immédiate
    Status.State := E_State.READY;
END_IF;

Status.Busy := (Status.State = E_State.BUSY);
Status.Done := (Status.State = E_State.DONE);
{endregion}

{region "§4 Double vérification contacteur"}
// 🔍 4. DOUBLE VÉRIFICATION RETOUR CONTACTEUR (ST_ContactorCheck)
ContactorCheck.Command := BrakeCmd;
ContactorCheck.Feedback := ContactorFeedback;

// ContactorFeedback est dans le MÊME sens que BrakeCmd (TRUE = relâché = frein ouvert).
// En marche saine les deux sont ÉGAUX → c'est leur DIFFÉRENCE qui signale l'incohérence
// (contacteur collé). Le test compare donc `<>`.
TonFeedback(IN := (BrakeCmd <> ContactorFeedback), PT := FeedbackTimeout);
IF NOT BypassContactorCheck THEN
    IF TonFeedback.Q THEN
        ContactorCheck.StuckClosed := (BrakeCmd AND NOT ContactorFeedback);            // relâche commandée (BrakeCmd=TRUE), frein reste serré (ContactorFeedback=FALSE)
        ContactorCheck.StuckOpen   := (NOT BrakeCmd AND ContactorFeedback);             // serrage commandé (BrakeCmd=FALSE), frein reste ouvert (ContactorFeedback=TRUE)
        Status.ErrorId := Status.ErrorId OR 16#0001;
    ELSIF ResetEdge.Q THEN
        ContactorCheck.StuckClosed := FALSE;
        ContactorCheck.StuckOpen   := FALSE;
        Status.ErrorId := Status.ErrorId AND 16#FFFE;
    END_IF;
ELSE
    ContactorCheck.StuckClosed := FALSE;
    ContactorCheck.StuckOpen   := FALSE;
    Status.ErrorId := Status.ErrorId AND 16#FFFE;   // Bypass actif : efface/maintient à 0 le bit 0
    IF BypassEdge.Q THEN
        Status.StateAtError := E_State.DISABLED; // Front activation bypass : débloque l'état figé
    END_IF;
END_IF;

{endregion}

{region "§5 Arbitrage error"}
// 🧾 5. ARBITRAGE ERROR / STATEATERROR (figé jusqu'à acquittement)
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;
{endregion}

{region "§6 Sortie sûre"}
// 🛡️ 6. SORTIE SÛRE SUR DÉFAUT
IF Status.Error THEN
    BrakeCmd := FALSE;
END_IF;
{endregion}

{region "§7 Confirmation ouverture"}
// 📤 7. CONFIRMATION OUVERTURE FREIN (même sens que ContactorFeedback, ou image de BrakeCmd si BypassContactorCheck=TRUE)
IF BypassContactorCheck THEN
    BrakeCommandOpenConfirmed := BrakeCmd;
ELSE
    BrakeCommandOpenConfirmed := ContactorFeedback;  (* TRUE = frein ouvert = desserrage confirmé *)
END_IF;
{endregion}
