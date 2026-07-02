(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Chariot — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.2.md
   🔧 2026-07-02 : renommage métier Translation→Chariot (demande utilisateur —
      l'axe transversal est un objet métier, "le chariot qui se déplace").
      Préfixe I/O physique M3 inchangé (mapping matériel).
   🔌 FB DE MOUVEMENT (Partie3 §1bis) : porte StartStop + SafeStop en
      plus de l'interface standard. Précédence Enable > SafeStop > StartStop.
   🔀 CommMode (E_ChariotCommMode) — sélection MANUELLE, verrouillée
      pendant un mouvement (CommModeLocked, correctif v1.1 F5 — voir §2bis) :
        - ETHERCAT    : mot de commande/état + consigne fréquence (proportionnelle)
        - DEGRADED_IO : RelayFwd/RelayRev + RelaySpeedGv (2 paliers PV/GV),
                        vitesse et rampes réglées LOCALEMENT sur le variateur
   🧩 Compose FB_Brake (réutilisé TEL QUEL depuis _COMMON, nouvelle instance
      + nouveaux réglages RETAIN propres à M3 — pas de FB_Brake spécifique,
      voir Partie11 §3).
   🧱 Réutilisation lib Util (Partie3 §0) : HYSTERESIS pour la sélection
      PV/GV en DEGRADED_IO (préféré à FB_SpeedStep — table 5 paliers/4
      relais disproportionnée pour un choix à 2 états, voir Partie11 §3).

   🔧 CORRECTIFS retour terrain — revue automatisme/mise en service 2026-07-02
      (Partie11 passe v1.0 → v1.1, voir doc pour le détail complet) :
      1. [F1 — BLOQUANT corrigé] En DEGRADED_IO, RelayFwd/RelayRev restaient
         commandés tant que la rampe LOGICIELLE SpeedRamp.Current ne repassait
         pas sous 0.1 % — or cette rampe n'a AUCUN lien avec la vitesse physique
         réelle en DEGRADED_IO (vitesse en tout-ou-rien PV/GV, fixée sur le
         variateur). Résultat : jusqu'à ~2,5 s de roulage à pleine vitesse
         PV/GV après passage sur le capteur cible (risque de choc en bout de
         course). Corrigé : nouvelle variable DegradedMoveAuthorized, calculée
         directement depuis StartStop/SafeStop/ArrivalLock (immédiate, aucune
         dépendance à la rampe) — voir §4quater et §5bis.
      2. [F5 — corrigé] Ajout d'une garde logicielle CommModeLocked (§2bis) :
         le changement de CommMode n'est plus pris en compte tant qu'un
         mouvement est en cours (Busy de l'état précédent), en complément de
         la consigne procédurale (bascule manuelle hors mouvement).
      3. [F7 — clarifié] Les paramètres de rampe (RampAccelRate/RampDecelNormalRate/
         RampDecelFastRate) ne pilotent une vitesse physique réelle qu'en
         ETHERCAT. En DEGRADED_IO ils ne servent plus qu'à SpeedRamp pour
         l'affichage State/StateAtError — le nouveau DegradedStopSettleTime
         remplace la rampe comme confirmation d'arrêt physique pour l'interlock
         de sens (§5, IsStoppedConfirmed).
   🔴 SQUELETTE — sections encore marquées TBD, volontairement non comblées
      (Ne JAMAIS approximer, Partie3 §0/CLAUDE.md) :
        - Layout exact des bits DriveControlWord/DriveStatusWord AC600
          (non disponible à la rédaction — voir doc constructeur variateur).
        - Interface exacte LIN_TRAFO (Util) : NON vérifiée ici. Le
          projet a déjà eu une mauvaise supposition d'interface sur
          HYSTERESIS (correctif FB_SpeedStep 2026-07-01) — pour ne pas
          répéter l'erreur, la mise à l'échelle %→Hz ci-dessous est un
          calcul linéaire explicite en attendant confirmation ; à
          remplacer par LIN_TRAFO si son interface réelle est vérifiée.
        - Comportement "arrêt exact sur capteur, même direction verrouillée
          jusqu'à inversion joystick" (§9bis) : logique PROPOSÉE, absente
          de toute doc existante — à valider avec l'utilisateur avant
          application (pas un simple report du contrat FB standard).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Chariot) ===

FUNCTION_BLOCK PUBLIC FB_Chariot
VAR_INPUT
    Enable                      : BOOL;        // Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                       : BOOL;        // Acquittement défaut (front)
    EmergencyStopOk             : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                        : E_Mode;      // Mode courant (contexte — droits arbitrés en amont par l'appelant)
    StartStop                   : BOOL;        // TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                    : BOOL;        // Sortie FB_Safety_Chariot : TRUE = rampe décélération RAPIDE (Enable maintenu)
    CommMode                    : E_ChariotCommMode; // Sélection MANUELLE (maintenance) — verrouillée pendant un mouvement, voir §2bis
    Direction                   : INT;         // -1 = Rev, 0 = Neutre, +1 = Fwd (ex. AxisCmdX.Direction) — source d'autorité du sens (interlock §5)
    SpeedRefPct                 : REAL;        // 🔧 2026-07-02 : AxisCmdX.SpeedRef est désormais SIGNÉ (-100..+100 %) —
                                                 // seule la MAGNITUDE est utilisée ici (ABS() en §4 et §5bis), Direction
                                                 // ci-dessus reste la source d'autorité du sens/interlock (inchangé)
    PositionSensorTarget        : BOOL;        // Capteur position cible courante (sélection de la cible = hors périmètre, en amont — IHM/FB_Cycle)

    // 🔌 Spécifique ETHERCAT (image process EtherCAT, rafraîchie par EtherCatTask 4ms)
    DriveStatusWord              : WORD;       // 🔴 TBD bit layout exact — mot d'état AC600 lu depuis l'image d'entrée EtherCAT
    DriveActualFreqHz            : REAL;       // Fréquence réelle mesurée (retour variateur) — pas de mesure de courant (Partie4 §5)

    // 🔌 Spécifique DEGRADED_IO (retours câblés TOR)
    ContactorFeedbackFwd         : BOOL;       // Retour d'état câblé contacteur sens avant
    ContactorFeedbackRev         : BOOL;       // Retour d'état câblé contacteur sens arrière
    DriveFaultFeedback           : BOOL;       // Retour TOR défaut variateur, SI câblé sur une sortie relais dédiée du variateur (sinon laisser à FALSE côté appelant — ne pas stubber un "pas de défaut" arbitraire)

    // 🔌 Frein (indépendant du mode — circuit propre, comme le treuil)
    BrakeFeedback                : BOOL;       // Retour d'état câblé bobine frein chariot

    // Réglages rampe (RETAIN) — pilotent une vitesse PHYSIQUE réelle en ETHERCAT uniquement (correctif v1.1 F7)
    RampAccelRate                : REAL := 20.0;    // %/s — accélération
    RampDecelNormalRate          : REAL := 40.0;    // %/s — décélération normale (StartStop=FALSE)
    RampDecelFastRate            : REAL := 100.0;   // %/s — décélération RAPIDE (SafeStop=TRUE)
    DirectionInterlockDelay      : TIME := T#200ms; // Délai avant d'autoriser un changement de sens à l'arrêt (interlock, identique principe FB_Winch)

    // Réglages ETHERCAT uniquement (RETAIN)
    ApproachTime                 : TIME := T#5s;    // Temps estimé avant déclenchement du ralentissement auto (Partie4 §5)
    ApproachSpeedPct             : REAL := 20.0;    // Vitesse réduite d'approche (PV) une fois ApproachTime écoulé
    DriveFreqScaleMaxHz          : REAL := 50.0;    // Échelle 0..100 % → 0..DriveFreqScaleMaxHz Hz (calcul linéaire, voir 🔴 TBD LIN_TRAFO en tête de fichier)

    // Réglages DEGRADED_IO uniquement (RETAIN)
    DegradedGvThresholdHighPct   : REAL := 60.0;    // Seuil bascule PV→GV (HYSTERESIS HIGH)
    DegradedGvThresholdLowPct    : REAL := 40.0;    // Seuil bascule GV→PV (HYSTERESIS LOW)
    ContactorFeedbackTimeout     : TIME := T#500ms; // Timeout cohérence commande/retour contacteurs de sens (DEGRADED_IO)
    DegradedStopSettleTime       : TIME := T#1s;    // 🆕 v1.1 (F1) — délai physique estimé d'arrêt réel après coupure relais (à régler selon la décélération interne réelle configurée sur le variateur en PV/GV) ; remplace SpeedRamp comme confirmation d'arrêt pour l'interlock de sens en DEGRADED_IO

    // Réglages communs
    CaptorDebounce                : TIME := T#100ms; // Filtrage capteur de position cible
    BrakeDelayContactClose        : TIME := T#100ms; // Voir FB_Brake
    BrakeDelayMagnetise           : TIME := T#300ms; // Voir FB_Brake
    BrakeDelayMotorDecel          : TIME := T#500ms; // Voir FB_Brake
    BrakeFeedbackTimeout          : TIME := T#1s;    // Voir FB_Brake
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: Brake.Error ; bit1: contacteur sens Fwd (DEGRADED_IO) ; bit2: contacteur sens Rev (DEGRADED_IO) ; bit3: défaut variateur (DriveFaultFeedback, si câblé)
    State               : E_State;
    StateAtError        : E_State;
    TargetReached        : BOOL;       // Capteur position cible confirmé (debounce) — voir §9bis

    // 🔌 Sorties ETHERCAT — à mapper sur l'image de sortie EtherCAT du variateur (SI CommModeLocked=ETHERCAT, sinon inertes)
    DriveControlWord     : WORD;       // 🔴 TBD — mot de commande AC600, layout non câblé (voir tête de fichier)
    DriveFreqRefHz        : REAL;      // Consigne fréquence écrite au variateur

    // 🔌 Sorties DEGRADED_IO — à mapper en I/O Mapping CODESYS (SI CommModeLocked=DEGRADED_IO, sinon forcées FALSE)
    RelayFwd              : BOOL;      // 🔌 Contacteur sens avant
    RelayRev               : BOOL;     // 🔌 Contacteur sens arrière
    RelaySpeedGv           : BOOL;     // 🔌 FALSE = PV (défaut), TRUE = GV — câblé sur entrée présélection vitesse AC600

    // 🔌 Frein (indépendant du mode)
    BrakeCmd                : BOOL;    // Commande bobine frein — TRUE = relâché

    // Diag
    FwdContactorCheck    : ST_ContactorCheck;  // Diag contacteur sens avant (pertinent en DEGRADED_IO)
    RevContactorCheck    : ST_ContactorCheck;  // Diag contacteur sens arrière (pertinent en DEGRADED_IO)
    BrakeContactorCheck  : ST_ContactorCheck;  // Diag contacteur frein (miroir de FB_Brake)
END_VAR
VAR
    Brake                : FB_Brake;       // 🧩 Composé — séquence frein (réutilisé tel quel, Partie11 §3)
    CycleTimeCalc        : FB_CycleTime;
    SpeedRamp             : FB_Ramp;       // Rampe interne — vitesse physique réelle en ETHERCAT ; affichage State uniquement en DEGRADED_IO (v1.1)
    ResetEdge            : R_TRIG;
    ErrorEdge            : R_TRIG;
    DirectionChangeDelay : TON;            // Interlock changement de sens (identique principe FB_Winch)
    CommandedDirection   : INT;            // Sens réellement appliqué (figé pendant le mouvement)
    TonFwdFeedback       : TON;
    TonRevFeedback       : TON;
    RampTargetPct        : REAL;
    ApproachTimer         : TON;           // ETHERCAT uniquement — déclenche le ralentissement auto
    CaptorDebounceTon     : TON;
    HystGv                : HYSTERESIS;    // 🧱 Lib Util — sélection PV/GV (DEGRADED_IO)
    SpeedRefInt            : INT;          // Consigne convertie en INT (interface HYSTERESIS)
    ArrivalEdge            : R_TRIG;       // §9bis — détecte l'arrivée sur capteur cible
    DirectionAtArrival     : INT;          // §9bis — sens verrouillé au moment de l'arrivée
    ArrivalLock             : BOOL;        // §9bis — TRUE tant que le capteur cible bloque le sens d'arrivée
    MovementRequested      : BOOL;         // Commun aux 2 modes — pilote FB_Brake
    CommModeLocked          : E_ChariotCommMode; // 🆕 v1.1 (F5) — CommMode figé pendant un mouvement (Busy)
    DegradedMoveAuthorized  : BOOL;        // 🆕 v1.1 (F1) — DEGRADED_IO : autorisation IMMÉDIATE du relais (StartStop/SafeStop/ArrivalLock, sans rampe)
    DegradedStopSettleTon   : TON;         // 🆕 v1.1 (F1) — confirmation d'arrêt physique DEGRADED_IO (remplace SpeedRamp pour l'interlock)
    IsStoppedConfirmed      : BOOL;        // 🆕 v1.1 — "vitesse confirmée nulle" par mode : rampe (ETHERCAT) ou temporisation (DEGRADED_IO)
END_VAR

// === IMPLEMENTATION (SQUELETTE — corps à compléter/vérifier avant collage, voir TBD en tête de fichier) ===

// 🛑 1. GATE (Enable / EmergencyStopOk) — neutralisation totale, sorties sûres
IF NOT Enable OR NOT EmergencyStopOk THEN
    RelayFwd := FALSE; RelayRev := FALSE; RelaySpeedGv := FALSE;
    DriveControlWord := 0; DriveFreqRefHz := 0.0;

    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeCmd := Brake.BrakeCmd;
    BrakeContactorCheck := Brake.ContactorCheck;

    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ApproachTimer(IN := FALSE, PT := ApproachTime);
    SpeedRamp(Target := 0.0, AccelRate := RampAccelRate, DecelRate := RampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

    ArrivalLock := FALSE;
    DegradedMoveAuthorized := FALSE;
    DegradedStopSettleTon(IN := FALSE, PT := DegradedStopSettleTime);
    CommModeLocked := CommMode;   // Neutralisé = libre de choisir le mode (pas de mouvement en cours)

    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);   // MainTask = 10 ms (valeur de secours si delta temps invalide)

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔒 2bis. GARDE CommMode — 🆕 v1.1 (F5) : pas de changement de mode de communication en cours
// de mouvement. Utilise Busy du cycle PRÉCÉDENT (pas encore recalculé ce cycle, §9) : tant que
// l'axe était en mouvement au dernier scan, CommMode externe est ignoré.
IF NOT Busy THEN
    CommModeLocked := CommMode;
END_IF;

// 📡 3. CAPTEUR POSITION CIBLE (debounce commun aux 2 modes)
CaptorDebounceTon(IN := PositionSensorTarget, PT := CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;

// ⚙️ 4. CORE — arbitrage rampe : Enable > SafeStop > StartStop
RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop THEN
    RampTargetPct := ABS(SpeedRefPct);  // 🔧 2026-07-02 : SpeedRefPct peut arriver signé (AxisCmdX.SpeedRef) — ABS() ici
END_IF;

// ⏱️ 4bis. RALENTISSEMENT AUTO À L'APPROCHE — ETHERCAT uniquement (Partie4 §5)
// DEGRADED_IO : pas d'automatisme, le choix PV/GV reste manuel (joystick) — voir §5bis
IF CommModeLocked = E_ChariotCommMode.ETHERCAT THEN
    ApproachTimer(IN := (StartStop AND NOT SafeStop), PT := ApproachTime);
    IF ApproachTimer.Q THEN
        RampTargetPct := LIMIT(0.0, RampTargetPct, ApproachSpeedPct);
    END_IF;
ELSE
    ApproachTimer(IN := FALSE, PT := ApproachTime);
END_IF;

// 🎯 4ter. ARRÊT EXACT SUR CAPTEUR — §9bis (commun aux 2 modes, comportement PROPOSÉ à valider)
// Verrouille (ArrivalLock) tant que le capteur cible reste actif ET que le sens commandé est
// le MÊME que celui qui a mené à l'arrivée (permet de repartir immédiatement en sens inverse,
// contrairement à un blocage total qui empêcherait de quitter la position).
ArrivalEdge(CLK := TargetReached);
IF ArrivalEdge.Q THEN
    DirectionAtArrival := CommandedDirection;
END_IF;
ArrivalLock := TargetReached AND (Direction = DirectionAtArrival) AND (DirectionAtArrival <> 0);
IF ArrivalLock THEN
    RampTargetPct := 0.0;   // Pertinent en ETHERCAT (consigne proportionnelle) ; sans effet direct en DEGRADED_IO, voir §5bis/DegradedMoveAuthorized
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := RampAccelRate,
          DecelRate := SEL(SafeStop, RampDecelNormalRate, RampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

// ⏱️ 4quater. CONFIRMATION D'ARRÊT PHYSIQUE — 🆕 v1.1 (F1)
// DEGRADED_IO : basée sur un délai RÉEL depuis la coupure du relais (RelayFwd/RelayRev tiennent
// encore la valeur du cycle précédent à ce stade — pas encore recalculés, voir §5bis), PAS sur
// la rampe logicielle SpeedRamp (sans lien physique en DEGRADED_IO, cf. correctif F1 en tête de fichier).
DegradedStopSettleTon(IN := NOT (RelayFwd OR RelayRev), PT := DegradedStopSettleTime);
IsStoppedConfirmed := SEL(CommModeLocked = E_ChariotCommMode.DEGRADED_IO,
                          (ABS(SpeedRamp.Current) < 0.1),   // ETHERCAT : rampe = consigne réelle
                          DegradedStopSettleTon.Q);          // DEGRADED_IO : délai physique réel

// 🔒 5. INTERLOCK CHANGEMENT DE SENS — jamais Fwd+Rev simultanés (même principe que FB_Winch §3bis)
IF Direction <> CommandedDirection THEN
    IF CommandedDirection = 0 AND Direction <> 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ELSIF IsStoppedConfirmed THEN
        DirectionChangeDelay(IN := TRUE, PT := DirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
END_IF;

// 🆕 v1.1 (F1) — Autorisation de mouvement DEGRADED_IO : IMMÉDIATE, découplée de la rampe logicielle
DegradedMoveAuthorized := StartStop AND NOT SafeStop AND NOT ArrivalLock;

MovementRequested := SEL(CommModeLocked = E_ChariotCommMode.DEGRADED_IO,
                          (CommandedDirection <> 0) AND (ABS(SpeedRamp.Current) > 0.1),  // ETHERCAT : lié à la rampe réelle (pilote le frein en douceur)
                          (CommandedDirection <> 0) AND DegradedMoveAuthorized);          // DEGRADED_IO : immédiat

// 🔀 5bis. SORTIE PHYSIQUE SELON CommModeLocked
IF CommModeLocked = E_ChariotCommMode.ETHERCAT THEN
    RelayFwd := FALSE; RelayRev := FALSE; RelaySpeedGv := FALSE;

    // 🔴 TBD — mise à l'échelle %→Hz : calcul linéaire explicite (LIN_TRAFO NON vérifié, voir tête de fichier)
    DriveFreqRefHz := (ABS(SpeedRamp.Current) / 100.0) * DriveFreqScaleMaxHz;
    // 🔴 TBD — DriveControlWord : layout de bits non disponible à la rédaction (Run/Stop/Enable/Reset
    // variateur selon protocole AC600 — À CONFIRMER avant tout collage, ne pas déduire de bits ici).
    DriveControlWord := 0;

    HystGv(IN := 0, HIGH := 0, LOW := 0);   // Inerte en ETHERCAT — instance maintenue pour cohérence cyclique
ELSE // DEGRADED_IO
    DriveFreqRefHz := 0.0;
    DriveControlWord := 0;

    // 🪜 Sélection PV/GV par HYSTERESIS (lib Util, Partie3 §0) — anti-battement, PAS de FB_SpeedStep
    // (table 5 paliers disproportionnée pour un choix à 2 états)
    // 🔧 2026-07-02 : ABS() — SpeedRefPct signé, les seuils Threshold sont des seuils de MAGNITUDE
    // (60%/40%) ; sans ABS() une consigne négative (sens arrière) ne dépasserait jamais HIGH et
    // resterait bloquée en PV quelle que soit la vitesse réelle demandée en marche arrière.
    SpeedRefInt := REAL_TO_INT(ABS(SpeedRefPct));
    HystGv(IN := SpeedRefInt, HIGH := REAL_TO_INT(DegradedGvThresholdHighPct), LOW := REAL_TO_INT(DegradedGvThresholdLowPct));
    RelaySpeedGv := NOT HystGv.OUT;   // Convention FB_SpeedStep : OUT=TRUE en régime bas → NOT OUT = seuil haut franchi (GV)

    // 🆕 v1.1 (F1) — coupure IMMÉDIATE sur DegradedMoveAuthorized=FALSE (StartStop=FALSE, SafeStop,
    // ou ArrivalLock) : ne dépend plus du temps de décroissance de la rampe logicielle.
    RelayFwd := (CommandedDirection = 1) AND DegradedMoveAuthorized;
    RelayRev := (CommandedDirection = -1) AND DegradedMoveAuthorized;
END_IF;

// 🛑 6. FREIN (composé, réutilisé tel quel) — indépendant du mode
Brake(Enable := TRUE, Reset := Reset, MovementRequested := MovementRequested,
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

// 🔍 7. DOUBLE VÉRIFICATION CONTACTEURS DE SENS — pertinent en DEGRADED_IO uniquement
// (en ETHERCAT, RelayFwd/RelayRev restent FALSE ci-dessus, donc pas de fausse incohérence
// tant que les retours câblés lisent bien FALSE au repos)
FwdContactorCheck.Command := RelayFwd;
FwdContactorCheck.Feedback := ContactorFeedbackFwd;
TonFwdFeedback(IN := (RelayFwd <> ContactorFeedbackFwd), PT := ContactorFeedbackTimeout);
IF TonFwdFeedback.Q THEN
    FwdContactorCheck.StuckClosed := (NOT RelayFwd AND ContactorFeedbackFwd);
    FwdContactorCheck.StuckOpen   := (RelayFwd AND NOT ContactorFeedbackFwd);
ELSIF ResetEdge.Q THEN
    FwdContactorCheck.StuckClosed := FALSE; FwdContactorCheck.StuckOpen := FALSE;
END_IF;

RevContactorCheck.Command := RelayRev;
RevContactorCheck.Feedback := ContactorFeedbackRev;
TonRevFeedback(IN := (RelayRev <> ContactorFeedbackRev), PT := ContactorFeedbackTimeout);
IF TonRevFeedback.Q THEN
    RevContactorCheck.StuckClosed := (NOT RelayRev AND ContactorFeedbackRev);
    RevContactorCheck.StuckOpen   := (RelayRev AND NOT ContactorFeedbackRev);
ELSIF ResetEdge.Q THEN
    RevContactorCheck.StuckClosed := FALSE; RevContactorCheck.StuckOpen := FALSE;
END_IF;

// 🧾 8. ERRORID (bitfield, cumul — effacé bit à bit si cause disparue + reset front)
IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

IF FwdContactorCheck.StuckClosed OR FwdContactorCheck.StuckOpen THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

IF RevContactorCheck.StuckClosed OR RevContactorCheck.StuckOpen THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// 🔴 TBD — bit3 défaut variateur : uniquement basé sur DriveFaultFeedback TOR SI câblé (ne
// jamais stubber ce bit si le retour n'existe pas encore — cf. principe codeur TBD FB_Safety_Winch)
IF DriveFaultFeedback THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🚦 9. STATE MACHINE (phase — orthogonale à Error, Partie3 §2)
// ⚠️ En DEGRADED_IO, cet indicateur reste basé sur SpeedRamp.Current (valeur logicielle sans lien
// physique direct, cf. F7) : usage diagnostic/IHM uniquement, PAS utilisé pour une décision de
// sécurité (celles-ci utilisent DegradedMoveAuthorized/IsStoppedConfirmed, calculés séparément).
IF (NOT StartStop OR SafeStop) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING) OR RelayFwd OR RelayRev;

Done := FALSE;   // Pas de notion de "terminé" ponctuel sans FB_Cycle — présent pour conformité

// 🛡️ 10. SORTIE SÛRE SUR DÉFAUT (Partie3 §9 étape 7)
IF Error THEN
    RelayFwd := FALSE; RelayRev := FALSE; RelaySpeedGv := FALSE;
    DriveControlWord := 0; DriveFreqRefHz := 0.0;
    BrakeCmd := FALSE;
END_IF;
