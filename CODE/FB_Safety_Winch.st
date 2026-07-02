(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Winch — Bloc safety MÉTIER du domaine Treuils (M1/M2)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md,
                   DOC/AF_Partie10_Fonction_Encoder_Homing_v1.3.md §7
                   (contrat : DOC/AF_Partie3_Template_FB_Commun_v1.2.md §1/§7bis)
   🛡️ Interface STANDARD COMPLÈTE (Partie3 §1) : FB_Safety_<Metier> est
      un FB métier à part entière (pas une brique réduite).
   📤 Sortie maîtresse SafeStop : consommée en entrée par le FB_Winch
      DU MÊME TREUIL (instSafetyWinchM1→instWinchM1, idem M2).
   ⚠️ ÉVOLUTION (lot Codeur, 2026-07-02) : `FB_Safety_Winch` reste UN
      SEUL type FB — le "split M1/M2" acté en Partie10 §7 s'obtient par
      DEUX INSTANCES (`instSafetyWinchM1`/`instSafetyWinchM2`), chacune
      câblée sur l'`EncoderAvailable` de SON treuil (pas deux FB
      distincts — composition, pas duplication de code).
      - ✅ Détecte la perte joystick/CAN (sans commande valide, un
        treuil ne doit pas pouvoir bouger).
      - ✅ Détecte la perte codeur DE CE TREUIL (`EncoderAvailable`,
        sortie `FB_Encoder_Abs` — désormais câblée, ErrorId bit1).
      - 🔴 TBD (non simulé) : perte bus EtherCAT spécifique (au-delà de
        ce que `EncoderAvailable` reflète déjà, si besoin d'un signal
        distinct plus tard).
      - `PowerCutOff` : FALSE pour ce lot (pas encore de
        ST_ContactorCheck de puissance câblé — FB_Output_Relay
        transverse hors périmètre de ce lot, voir Partie6).
   🔴 TBD — SURVEILLANCE DE COHÉRENCE MOUVEMENT (retour terrain 2026-07-02,
      idée capturée, NON conçue en détail, NON implémentée — détail complet
      dans DOC/AF_Partie9 §4bis). 4 cas DISTINCTS (1 bit ErrorId chacun,
      pas un bit générique) :
      - Cas A — Sens opposé : sens joystick BRUT (avant traitement) ≠ sens
        réel constaté (contacteur et/ou signe vitesse codeur), persistant.
        → câblage inversé / contacteur collé mauvais sens / codeur mal orienté.
      - Cas B — Mouvement non commandé (roue libre) : codeur bouge alors
        qu'AUCUN contacteur de sens n'est engagé. → charge qui tombe, frein
        qui ne tient pas. GRAVITÉ TRÈS ÉLEVÉE, priorité dès codeur dispo.
      - Cas C — Absence de mouvement malgré commande : sens+palier+frein
        relâché confirmés, mais codeur immobile après délai. → blocage
        mécanique / accouplement rompu / défaut invisible à ST_ContactorCheck.
      - Cas D — Fenêtre de tolérance (règle transverse, pas un défaut) :
        ne jamais déclencher pendant le temps normal de rampe+interlock.
      Sources manquantes aujourd'hui : sens joystick brut (RawX/RawY non
      remontés ici), vitesse/signe codeur (Partie10), RelayFwd/RelayRev/
      BrakeCmd de FB_Winch (existent en sortie, pas encore câblés ici).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Safety_Winch) ===

FUNCTION_BLOCK PUBLIC FB_Safety_Winch
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    EmergencyStopOk     : BOOL;        // Chaîne AU réarmée + conditions globales OK (info de contexte)
    Mode                : E_Mode;      // Mode courant (autorisations)
    JoystickOnline      : BOOL;        // instDiagCanOpen.Joystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.Joystick.Operational
    EncoderAvailable    : BOOL;        // Sortie FB_Encoder_Abs DU TREUIL concerné par cette instance
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : perte joystick/CAN ; bit1 : perte codeur de ce treuil
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Sortie maîtresse : rampe décélération RAPIDE (Enable maintenu)
    PowerCutOff         : BOOL;        // 🧨 Sortie maîtresse : coupure puissance amont (FALSE, TBD ce lot)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

// 🛑 1. GATE — sécurité par défaut : pas de surveillance active = arrêt forcé du domaine
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    SafeStop := TRUE;              // Fail-safe : tant que la surveillance n'est pas garantie, on arrête
    PowerCutOff := FALSE;
    State := E_State.DISABLED;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL
IF NOT JoystickOnline OR NOT JoystickOperational THEN
    ErrorId := ErrorId OR 16#0001;       // Perte joystick/CAN : pas de commande opérateur valide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔍 3bis. PERTE CODEUR DE CE TREUIL (câblé — lot Codeur 2026-07-02)
IF NOT EncoderAvailable THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SafeStop := Error;          // 🟧 Tout défaut du domaine → rampe décélération rapide (Enable maintenu)
PowerCutOff := FALSE;       // 🧨 TBD — pas de ST_ContactorCheck de puissance câblé dans ce lot

// Busy, Done non utilisés mais présents pour conformité (comme FB_DiagCanOpen)
Busy := FALSE;
Done := FALSE;
