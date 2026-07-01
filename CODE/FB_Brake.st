(* ═══════════════════════════════════════════════════════════════
   🛑 FB_Brake — Séquence frein à manque de courant (temps physiques)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
                   (règles issues de DOC/AF_Partie4_Cycle_Sequenceur_v1.1.md §4)
   🛠️ Frein à manque de courant : colle au repos (sécurité positive).
   📥 MovementRequested : mouvement demandé par FB_Winch (sens+palier > 0)
   📤 BrakeCmd          : commande bobine frein — TRUE = relâché (alimenté)
   ⏱️ Séquence démarrage : attend fermeture contacteur + magnétisation
      moteur AVANT de relâcher (sinon charge retombe → à-coup).
   ⏱️ Séquence arrêt     : attend décélération/ouverture contacteur AVANT
      de coller (sinon usure/casse mécanique en plein mouvement).
   🔍 Double vérification retour contacteur bobine (ST_ContactorCheck) :
      incohérence commande/retour au-delà de FeedbackTimeout → ErrorId.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Brake) ===

FUNCTION_BLOCK PUBLIC FB_Brake
VAR_INPUT
    Enable              : BOOL;                     // Contexte général (comme tout FB) — FALSE = frein collé (sûr)
    Reset               : BOOL;                     // Acquittement défaut (front)
    MovementRequested   : BOOL;                      // TRUE = FB_Winch demande un mouvement (sens+palier actifs)
    ContactorFeedback   : BOOL;                      // Retour d'état câblé de la bobine/contacteur frein
    DelayContactClose   : TIME := T#100ms;            // Temps de fermeture contacteur de puissance
    DelayMagnetise      : TIME := T#300ms;            // Délai magnétisation moteur avant ouverture frein
    DelayMotorDecel     : TIME := T#500ms;            // Délai décélération/ouverture contacteur avant collage frein
    FeedbackTimeout     : TIME := T#1s;               // Délai max cohérence commande/retour frein
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;          // bit0 : incohérence commande/retour frein (collage ou non-relâche)
    State               : E_State;
    StateAtError        : E_State;
    BrakeCmd            : BOOL;          // Commande sortie bobine frein : TRUE = relâché
    ContactorCheck      : ST_ContactorCheck;  // Diag détaillé (IHM / FB_Safety_Winch)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
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
    TonMagnetise(IN := FALSE, PT := DelayMagnetise + DelayContactClose);
    TonDecel(IN := TRUE, PT := DelayMotorDecel);
    IF TonDecel.Q THEN
        BrakeCmd := FALSE;             // ✅ Décélération/ouverture contacteur acquise → collage
        State := E_State.READY;
    ELSE
        BrakeCmd := TRUE;              // ⏳ Encore relâché le temps que le moteur finisse de tourner
        State := E_State.BUSY;
    END_IF;
END_IF;

Busy := (State = E_State.BUSY);
Done := (State = E_State.DONE);

// 🔍 4. DOUBLE VÉRIFICATION RETOUR CONTACTEUR (ST_ContactorCheck)
ContactorCheck.Command := BrakeCmd;
ContactorCheck.Feedback := ContactorFeedback;

TonFeedback(IN := (BrakeCmd <> ContactorFeedback), PT := FeedbackTimeout);
IF TonFeedback.Q THEN
    ContactorCheck.StuckClosed := (NOT BrakeCmd AND ContactorFeedback);  // commandé collé mais retour "relâché"
    ContactorCheck.StuckOpen   := (BrakeCmd AND NOT ContactorFeedback);  // commandé relâché mais retour "collé"
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ContactorCheck.StuckClosed := FALSE;
    ContactorCheck.StuckOpen   := FALSE;
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🧾 5. ARBITRAGE ERROR / STATEATERROR (figé jusqu'à acquittement)
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;
