(* ═══════════════════════════════════════════════════════════════
   🛑 FB_Brake — Séquence frein à manque de courant (temps physiques)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-10_Fonction_Winch_v2.0.md §3
                   (règles issues de DOC/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md §4)
   🛠️ Frein à manque de courant : colle au repos (sécurité positive).
   📥 MovementRequested : mouvement demandé par FB_Winch (sens+palier > 0)
   📤 BrakeCmd          : commande bobine frein — TRUE = relâché (alimenté)
   ⏱️ Séquence démarrage : attend fermeture contacteur + magnétisation
      moteur AVANT de relâcher (sinon charge retombe → à-coup).
   ⏱️ Séquence arrêt     : attend décélération/ouverture contacteur AVANT
      de coller (sinon usure/casse mécanique en plein mouvement).
   🔍 Double vérification retour contacteur bobine (ST_ContactorCheck) :
      incohérence commande/retour au-delà de FeedbackTimeout → ErrorId.
   🆕 REX 2026-08-03 (révocation 2026-07-26) : le retour câblé est l'image du CONTACTEUR DE COMMANDE
      (DI = 1 ⟺ frein ouvert). Plus d'inversion à la frontière : ce FB reçoit maintenant un
      signal dans le MÊME sens que `BrakeCmd` en marche saine (TRUE = relâché = ouvert) → le test d'incohérence est `<>`, pas `=`.
      ⚠️ Ce retour n'est PAS une mesure du frein : il détecte un contacteur/bobine défaillant, mais
      pas un frein usé ou qui patine. Le patinage reste couvert par Méca A (dérive codeur,
      FB_Safety_Winch bit7) — pas par ce bloc.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Brake) ===

FUNCTION_BLOCK PUBLIC FB_Brake
VAR_INPUT
    Enable              : BOOL;                     // Contexte général (comme tout FB) — FALSE = frein collé (sûr)
    Reset               : BOOL;                     // Acquittement défaut (front)
    MovementRequested   : BOOL;                      // TRUE = FB_Winch demande un mouvement (sens+palier actifs)
    ContactorFeedback   : BOOL;                      // Retour frein (PRG_01_Inputs_LD) : TRUE = frein OUVERT (desserré)
                                                       // 🆕 REX 2026-08-03 : même sens que BrakeCmd (TRUE = relâché)
                                                       // → en marche normale les deux sont ÉGAUX ; c'est leur
                                                       //   DIFFÉRENCE qui trahit un contacteur collé (voir §4).
    DelayContactClose   : TIME := T#100ms;            // Temps de fermeture contacteur de puissance
    DelayMagnetise      : TIME := T#300ms;            // Délai magnétisation moteur avant ouverture frein
    DelayMotorDecel     : TIME := T#500ms;            // Délai décélération/ouverture contacteur avant collage frein
    FeedbackTimeout     : TIME := T#1s;               // Délai max cohérence commande/retour frein
    BypassContactorCheck: BOOL;                       // 🧪 TRUE = désactive StuckClosed/StuckOpen (axe simulé,
                                                       // voir GVL_Simulation.SensorMxContactorFeedbackIsReal, passé
                                                       // par l'appelant FB_Winch/FB_Translation — TOUJOURS FALSE réel)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;          // bit0: "Défaut engagement frein" - incohérence commande/retour frein (collage ou non-relâche)
    State               : E_State;
    StateAtError        : E_State;
    BrakeCmd            : BOOL;          // Commande sortie bobine frein : TRUE = relâché
    BrakeCommandOpenConfirmed : BOOL;    // TRUE = frein ouvert = commande ouverture confirmée (même sens que ContactorFeedback)
    ContactorCheck      : ST_ContactorCheck;  // Diag détaillé (IHM / FB_Safety_Winch)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    BypassEdge          : R_TRIG;        // 🔑 REX 2026-07-24 : Front montant activation bypass pour réarmement immédiat
    TonMagnetise        : TON;           // Temporisation avant relâche
    TonDecel            : TON;           // Temporisation avant collage
    TonFeedback         : TON;           // Timeout cohérence commande/retour
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Brake) ===

// 🛑 1. GATE — pas d'Enable = frein collé (sécurité positive), aucune temporisation en cours
IF NOT Enable THEN
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    BrakeCmd := FALSE;
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);
BypassEdge(CLK := BypassContactorCheck);

// 🛠️ 3. SÉQUENCE TEMPORISÉE (démarrage vs arrêt)
IF MovementRequested THEN
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    TonMagnetise(IN := TRUE, PT := DelayMagnetise + DelayContactClose);
    IF TonMagnetise.Q THEN
        BrakeCmd := TRUE;              // ✅ Contacteur + magnétisation acquis → relâche
        State := E_State.DONE;
    ELSE
        BrakeCmd := FALSE;             // ⏳ Encore collé pendant la magnétisation
        State := E_State.BUSY;
    END_IF;
ELSE
    // 🆕 REX 2026-07-08 : Sécurité positive - fermeture immédiate du frein (collé) dès que les contacteurs de sens s'ouvrent
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := FALSE, PT := DelayMotorDecel);
    BrakeCmd := FALSE;                 // Fermeture immédiate
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY);
Done := (State = E_State.DONE);

// 🔍 4. DOUBLE VÉRIFICATION RETOUR CONTACTEUR (ST_ContactorCheck)
ContactorCheck.Command := BrakeCmd;
ContactorCheck.Feedback := ContactorFeedback;

// 🆕 REX 2026-08-03 (révocation 2026-07-26) : `ContactorFeedback` est maintenant dans le MÊME sens
// que `BrakeCmd` (TRUE = relâché = frein ouvert). En marche saine les deux sont ÉGAUX → c'est leur
// DIFFÉRENCE qui signale l'incohérence (contacteur collé).
// ⚠️ Le test repasse en `<>` (retour à la logique d'origine pré-2026-07-26).
TonFeedback(IN := (BrakeCmd <> ContactorFeedback), PT := FeedbackTimeout);
IF NOT BypassContactorCheck THEN
    IF TonFeedback.Q THEN
        ContactorCheck.StuckClosed := (BrakeCmd AND NOT ContactorFeedback);            // relâche commandée (BrakeCmd=TRUE), frein reste serré (ContactorFeedback=FALSE)
        ContactorCheck.StuckOpen   := (NOT BrakeCmd AND ContactorFeedback);             // serrage commandé (BrakeCmd=FALSE), frein reste ouvert (ContactorFeedback=TRUE)
        ErrorId := ErrorId OR 16#0001;
    ELSIF ResetEdge.Q THEN
        ContactorCheck.StuckClosed := FALSE;
        ContactorCheck.StuckOpen   := FALSE;
        ErrorId := ErrorId AND 16#FFFE;
    END_IF;
ELSE
    ContactorCheck.StuckClosed := FALSE;
    ContactorCheck.StuckOpen   := FALSE;
    ErrorId := ErrorId AND 16#FFFE;   // Bypass actif : efface/maintient à 0 le bit 0
    IF BypassEdge.Q THEN
        StateAtError := E_State.DISABLED; // Front activation bypass : débloque l'état figé
    END_IF;
END_IF;

// 🧾 5. ARBITRAGE ERROR / STATEATERROR (figé jusqu'à acquittement)
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🛡️ 6. SORTIE SÛRE SUR DÉFAUT
IF Error THEN
    BrakeCmd := FALSE;
END_IF;

// 📤 7. CONFIRMATION OUVERTURE FREIN (même sens que ContactorFeedback)
BrakeCommandOpenConfirmed := ContactorFeedback;  (* TRUE = frein ouvert = desserrage confirmé *)
