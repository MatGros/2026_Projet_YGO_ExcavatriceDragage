(* =======================================================================
   🛡️ FB_Brake — Séquence frein à manque de courant (temps physiques)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Gestion temporisée ouverture/fermeture frein à manque de courant
   🔒 Polarité : Sécurité positive (BrakeCmd=FALSE = frein collé au repos)
   🔌 Interface : Double vérification retour contacteur (ST_ContactorCheck)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md §3
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
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                   : ST_Fault;

    // === COMMANDES ET CONFIRMATIONS ===
    BrakeCmd                : BOOL;               // <-- [ACT]  Commande bobine frein (TRUE = relache/ouvert)
    BrakeCommandOpenConfirmed : BOOL;            // <-- [STAT] Confirmation ouverture frein pour verrous
    ContactorCheck          : ST_ContactorCheck;  // <-- [DIAG] Diagnostic detaille retour contacteur
END_VAR
VAR
    // === TRIGGERS ET DETECTION FRONTS ===
    ResetEdge               : R_TRIG;             // . [LOC]  Detecteur front acquittement
    BypassEdge              : R_TRIG;             // . [LOC]  Detecteur front activation bypass

    // === TEMPORISATEURS INTERNES ===
    TonMagnetise            : TON;                // . [LOC]  Temporisation avant relachement frein
    TonDecel                : TON;                // . [LOC]  Temporisation avant collage frein
    TonFeedback             : TON;                // . [LOC]  Timeout de coherence commande/retour

    // === GESTION DES DEFAUTS ===
    ContactorIncoherentError: BOOL;               // . [LOC]  Défaut mémorisé incohérence contacteur
    instFault               : FB_FaultCore;       // * [INST] Socle de défaut
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Fronts"}
// 🔑 1. FRONTS
ResetEdge(CLK := Reset);
BypassEdge(CLK := BypassContactorCheck);

// Acquittement des drapeaux contacteur
IF ResetEdge.Q OR BypassContactorCheck THEN
    ContactorIncoherentError := FALSE;
    ContactorCheck.StuckClosed := FALSE;
    ContactorCheck.StuckOpen   := FALSE;
END_IF;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE — pas d'Enable = frein collé (sécurité positive), aucune temporisation en cours
IF NOT Enable THEN
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    TonFeedback(IN := FALSE, PT := FeedbackTimeout);
    BrakeCmd := FALSE;
    Ready := FALSE;
    ContactorCheck.Command := FALSE;          // 📊 Neutralisation : miroir de BrakeCmd := FALSE
    ContactorCheck.Feedback := ContactorFeedback; // 📊 Neutralisation : miroir entrée physique
    BrakeCommandOpenConfirmed := FALSE;       // 🛡️ Fail-Safe : frein commandé fermé hors Enable
    
    // Évaluation du socle de défaut sous neutralisation (permet acquittement Reset hors Enable)
    instCauses[0].Active   := FALSE;
    instCauses[0].Latching := TRUE;
    instCauses[0].Texte    := 'Incoherence retour contacteur frein';
    instFault(Enable := FALSE, Reset := Reset, Causes := instCauses);
    Fault := instFault.Fault;
    RETURN;
END_IF;
{endregion}

{region "§3 Séquence temporisée"}
// 🛠️ 3. SÉQUENCE TEMPORISÉE (démarrage vs arrêt)
IF MovementRequested THEN
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    TonMagnetise(IN := TRUE, PT := DelayMagnetise + DelayContactClose);
    IF TonMagnetise.Q THEN
        BrakeCmd := TRUE;              // ✅ Contacteur + magnétisation acquis → relâche
    ELSE
        BrakeCmd := FALSE;             // ⏳ Encore collé pendant la magnétisation
    END_IF;
ELSE
    // Sécurité positive : fermeture immédiate du frein (collé) dès que les contacteurs de sens s'ouvrent
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    BrakeCmd := FALSE;                 // Fermeture immédiate
END_IF;
{endregion}

{region "§4 Double vérification contacteur"}
// 🔍 4. DOUBLE VÉRIFICATION RETOUR CONTACTEUR (ST_ContactorCheck)
ContactorCheck.Command := BrakeCmd;
ContactorCheck.Feedback := ContactorFeedback;

// ContactorFeedback est dans le MÊME sens que BrakeCmd (TRUE = relâché = frein ouvert).
TonFeedback(IN := (BrakeCmd <> ContactorFeedback), PT := FeedbackTimeout);
IF NOT BypassContactorCheck THEN
    IF TonFeedback.Q THEN
        ContactorCheck.StuckClosed := (BrakeCmd AND NOT ContactorFeedback);
        ContactorCheck.StuckOpen   := (NOT BrakeCmd AND ContactorFeedback);
        ContactorIncoherentError   := TRUE;
    END_IF;
END_IF;
{endregion}

{region "§5 Causes & Socle Défaut"}
// 🚨 5. SOCLE DÉFAUT & SORTIE SÛRE
instCauses[0].Active   := NOT BypassContactorCheck AND (ContactorCheck.StuckClosed OR ContactorCheck.StuckOpen OR (TonFeedback.Q AND (BrakeCmd <> ContactorFeedback)));
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Incoherence retour contacteur frein';

instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

Ready := Enable AND NOT Fault.Latched;

// Sortie sûre immédiate
IF Fault.Error OR Fault.Latched THEN
    BrakeCmd := FALSE;
END_IF;
{endregion}

{region "§6 Confirmation ouverture"}
// 📤 6. CONFIRMATION OUVERTURE FREIN
IF BypassContactorCheck THEN
    BrakeCommandOpenConfirmed := BrakeCmd;
ELSE
    BrakeCommandOpenConfirmed := ContactorFeedback AND NOT Fault.Latched;  (* TRUE = frein ouvert = desserrage confirmé *)
END_IF;
{endregion}
