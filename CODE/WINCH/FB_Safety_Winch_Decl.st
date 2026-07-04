(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Winch — Bloc safety MÉTIER du domaine Treuils (M1/M2)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.1.md,
                   DOC/AF_Partie10_Fonction_Encoder_Homing_v1.6.md §7
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
        ST_ContactorCheck de puissance câblé — FB_Output
        transverse hors périmètre de ce lot, voir Partie6).
   🆕 AJOUT (2026-07-02, retour terrain — nouvel export Device.export avec
      I/O réel `M1_ThermalFeedback`/`M2_ThermalFeedback` et
      `M1_M2_SlackCableSwitch`, demande utilisateur) — Partie9 §4ter :
      - ✅ `ThermalFeedback` (par instance, retour thermique CE moteur) :
        défaut → bit2 ErrorId → `SafeStop` (arrêt total, protection moteur,
        comme les autres défauts du domaine).
      - ✅ `SlackCableDetected` (COMMUN aux 2 treuils, même capteur — même
        principe que `M1_M2_TopPositionSensor`, câblé IDENTIQUEMENT sur
        les 2 instances) : mou de câble détecté (descente non arrêtée à
        temps) → bit3 ErrorId (visible IHM, reset front requis dès que la
        cause disparaît) → sortie **`ForbidDescent`** DÉDIÉE, DISTINCTE de
        `SafeStop` — bloque UNIQUEMENT la descente (`FB_Winch.RelayRev`),
        la remontée (`RelayFwd`) reste libre pour permettre à l'opérateur
        d'aller vérifier le câblage. Nouveau pattern (pas un simple
        `SafeStop`, qui aurait arrêté les 2 sens) — voir Partie9 §4ter
        pour la justification complète.
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
    ThermalFeedback     : BOOL;        // 🆕 Retour TOR thermique CE moteur (M1_ThermalFeedback/M2_ThermalFeedback, I/O réel) — TRUE = surchauffe
    SlackCableDetected  : BOOL;        // 🆕 Détecteur mou de câble COMMUN aux 2 treuils (M1_M2_SlackCableSwitch, I/O réel) — même valeur câblée sur les 2 instances
    PhaseRotationOk     : BOOL;        // 🆕 PRG_0_Inputs.PhaseRotationOk (commun, I/O réel) — TRUE = rotation phases élec. correcte
    TopPositionSensor   : BOOL;        // 🆕 Capteur de position haute commun (M1_M2_TopPositionSensor, I/O réel)
    InReferencingMode   : BOOL;        // 🆕 Indique si le treuil est en cours de homing (référencement)
    CablePosM           : REAL;        // 🆕 Position actuelle du câble en mètres (scaled)
    CableLimitDescentM  : REAL;        // 🆕 Limite basse physique de descente en mètres (négative)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : perte joystick/CAN ; bit1 : perte codeur de ce treuil ; bit2 : surchauffe moteur ; bit3 : mou de câble (commun) ; bit4 : mauvaise rotation de phase (commun) ; bit5 : fin de course haut atteint ; bit6 : longueur max câble atteinte (déroulement)
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Sortie maîtresse : rampe décélération RAPIDE (Enable maintenu) — bits 0/1/2/4 uniquement
    ForbidDescent       : BOOL;        // 🆕 Sortie dédiée : interdit UNIQUEMENT la descente (bit3, mou de câble)
    ForbidAscent        : BOOL;        // 🆕 Sortie dédiée : interdit UNIQUEMENT la montée (bit5, fin de course haut)
    PowerCutOff         : BOOL;        // 🧨 Sortie maîtresse : coupure puissance amont (FALSE, TBD ce lot)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR
