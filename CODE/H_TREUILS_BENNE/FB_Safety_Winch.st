(* =======================================================================
   🛡️ FB_Safety_Winch — Surveillance et sécurité d'un treuil (M1 / M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Protection machine, surveillance codeurs, dérives et interlocks
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔒 Sécurité : Gestion des autorisations SafeStop, PowerCutOff et permis
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Safety_Winch
VAR_INPUT
    // === COMMANDES ET ETATS GENERAL ===
    Enable                          : BOOL;                           // --> [CMD] Active la surveillance globale FB
    Reset                           : BOOL;                           // --> [CMD] Front acquittement defauts
    Mode                            : E_Mode;                         // --> [CMD] Mode d'exploitation actif
    SyncEnable                      : BOOL;                           // --> [CMD] Validation synchronisation treuils
    Direction                       : INT;                            // --> [CMD] Consigne active de direction (-1/0/+1)
    MovementCommanded               : BOOL;                           // --> [CMD] Au moins un contacteur de sens commande

    // === ETATS SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Chaine AU rearmee + puissance OK
    JoystickOnline                  : BOOL;                           // --> [HW] Statut bus CAN Joystick Online
    JoystickOperational             : BOOL;                           // --> [HW] Statut bus CAN Joystick Operational
    HeartbeatIhmOk                  : BOOL;                           // --> [HW] Communication IHM-PLC valide
    EncoderAvailable                : BOOL;                           // --> [HW] Codeur disponible pour ce treuil
    ThermalFeedback                 : BOOL;                           // --> [HW] Retour thermique moteur (NC)
    BrakeThermalFeedback            : BOOL;                           // --> [HW] Retour thermique frein (NC)
    SlackCableDetected              : BOOL;                           // --> [HW] Delecteur mou de cable (NC)
    PhaseRotationOk                 : BOOL;                           // --> [HW] Sens de rotation des phases OK
    TopPositionSensor               : BOOL;                           // --> [HW] Capteur fin de course haut (NC)
    FwdRevSpeedFeedbackOff          : BOOL;                           // --> [HW] Feedback retombe tous contacteurs
    BrakeFeedback                   : BOOL;                           // --> [HW] Feedback frein ouvert
    JoystickYNeutral                : BOOL;                           // --> [HW] Joystick au neutre
    BenneHoldStillActive            : BOOL;                           // --> [HW] Maintien fixe M1 actif pendant benne
    BenneBusy                       : BOOL;                           // --> [HW] Cycle benne actif sur l'autre treuil
    OtherWinchInhibited             : BOOL;                           // --> [HW] Autre treuil inhibe (maintenance)

    // === REGLAGES ET LIMITES SÉCURITÉ ===
    InReferencingMode               : BOOL;                           // --> [CFG] Treuil en cours de homing
    CablePosM                       : REAL;                           // --> [CFG] Position actuelle cable (m)
    CfgCableLimitDescentM           : REAL;                           // --> [CFG] Limite basse physique descente (m)
    LimitLegalReached               : BOOL;                           // --> [CFG] Limite legale de profondeur atteinte
    Homed                           : BOOL;                           // --> [CFG] Treuil reference
    HomingSuspect                   : BOOL;                           // --> [CFG] Referencement suspect
    TopLimitM                       : REAL;                           // --> [CFG] Position limite haute active (m)
    UncommandedSpeedThresholdMps    : REAL := 0.02;                   // --> [CFG] Seuil vitesse non commandee Meca A (m/s)
    UncommandedDriftToleranceM      : REAL := 2.0;                    // --> [CFG] Tolerance derive position Meca A (m)
    PostRampTimeout                 : TIME := T#3s;                   // --> [CFG] Delai attente retombee contacteurs/frein Meca B
    BenneSlipToleranceM             : REAL := 2.0;                    // --> [CFG] Tolerance glissement M1 pendant benne (m)
    ExpectedOtherWinchPosM          : REAL;                           // --> [CFG] Position attendue de l'autre treuil (m)
    CriticalSyncToleranceM          : REAL := 2.5;                    // --> [CFG] Tolerance ecart critique synchro (m)
    MovementSpeedThresholdMps       : REAL := 0.02;                   // --> [CFG] Seuil vitesse mesurable (m/s)
    MeasuredSpeedMps                : REAL;                           // --> [CFG] Mesure absolue vitesse (m/s)
    MeasuredSpeedSignedMps          : REAL;                           // --> [CFG] Mesure signee vitesse (m/s)
    MeasuredSpeedValid              : BOOL;                           // --> [CFG] Mesure vitesse valide
    OppositeDirectionTimeout        : TIME := T#500ms;                // --> [CFG] Delai confirmation sens oppose
    NoMovementTimeout               : TIME := T#3s;                   // --> [CFG] Delai confirmation absence mouvement

    // === BYPASSES ET SIMULATION ===
    EncoderFaultBypass              : BOOL;                           // --> [TST] Bypass defaut codeur
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Force ErrorId=0 global
    BypassSafety                    : BOOL := FALSE;                  // --> [TST] Bypass groupe PowerCutOff
    BypassProcess                   : BOOL := FALSE;                  // --> [TST] Bypass groupe SafeStop/Permit
    BypassTopLimitSwitch            : BOOL := FALSE;                  // --> [TST] Bypass individuel fin de course haut capteur
    BypassTopLimitSoftware          : BOOL := FALSE;                  // --> [TST] Bypass individuel fin de course haut logiciel
    BypassCableLimitSwitch          : BOOL := FALSE;                  // --> [TST] Bypass individuel limite basse cable
    BypassLimitLegal                : BOOL := FALSE;                  // --> [TST] Bypass individuel limite legale
    BypassOperatorComm              : BOOL := FALSE;                  // --> [TST] Bypass perte com operateur
    BypassPhaseRotation             : BOOL := FALSE;                  // --> [TST] Bypass defaut rotation phases
    BypassBrakeThermal              : BOOL := FALSE;                  // --> [TST] Bypass surchauffe frein
    BypassMotorThermal              : BOOL := FALSE;                  // --> [TST] Bypass surchauffe moteur
    BypassMecaA                     : BOOL := FALSE;                  // --> [TST] Bypass Meca A
    BypassMecaB                     : BOOL := FALSE;                  // --> [TST] Bypass Meca B
    BypassMecaC                     : BOOL := FALSE;                  // --> [TST] Bypass Meca C
    BypassMecaD                     : BOOL := FALSE;                  // --> [TST] Bypass Meca D
    BypassMecaE                     : BOOL := FALSE;                  // --> [TST] Bypass Meca E
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bitmask: bit0: "Perte comms opérateur" ; bit1: "Perte codeur" ; bit2: "Surchauffe moteur" ;
    // bit3: "Mou de câble" ; bit4: "Rotation phases" ; bit5: "Fin de course haut capteur" ;
    // bit6: "Limite max câble" ; bit7: "Méca A" ; bit8: "Méca B" ; bit9: "Méca C" ; bit10: "Thermique frein" ;
    // bit11: "Méca D" ; bit12/13: "Méca E écart synchro" ; bit14: "Sens opposé" ; bit15: "Absence mouvement".
    Status                         : ST_FbStatus;

    // === SORTIES DE SÉCURITÉ ET AUTORISATIONS ===
    SafeStop                        : BOOL;                           // <-- [SAFE] Arret rapide 2 sens (Enable maintenu)
    DescendPermit                   : BOOL;                           // <-- [SAFE] Permis de descente autorise
    AscentPermit                    : BOOL;                           // <-- [SAFE] Permis de montee autorise
    PowerCutOff                     : BOOL;                           // <-- [SAFE] Coupure puissance amont

    // === DIAGNOSTICS ET MESURES ===
    MecaADriftM                     : REAL;                           // <-- [DIAG] Derive mesuree Meca A (m)
    MecaCDriftM                     : REAL;                           // <-- [DIAG] Derive mesuree Meca C (m)
    MecaBElapsedTime                : TIME;                           // <-- [DIAG] Ecoule confirmation contacteurs/frein
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    DriftGuardA                     : FB_DriftGuard;                  // * [INST] Surveillance derive Meca A
    DriftGuardC                     : FB_DriftGuard;                  // * [INST] Surveillance derive Meca C

    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur
    TonMecaB                        : TON;                            // . [LOC] Tempo confirmation arret Meca B
    TonMecaD                        : TON;                            // . [LOC] Tempo arret fin de course haut Meca D
    TonMecaE                        : TON;                            // . [LOC] Tempo confirmation arret synchro Meca E
    TonOppositeDirection            : TON;                            // . [LOC] Tempo confirmation sens oppose
    TonNoMovement                   : TON;                            // . [LOC] Tempo confirmation absence mouvement
    TonStartupWarmup                : TON;                            // . [LOC] Tempo masquage transitoire au boot

    // === VARIABLES LOCALES INTERNES ===
    FirstScanDone                   : BOOL;                           // . [LOC] Premier cycle effectue
    MecaB_NoOperatorCmd             : BOOL;                           // . [LOC] Absence commande operateur
    LastInReferencingMode           : BOOL;                           // . [LOC] Memorisation etat homing precedent
    OppositeDirectionActive         : BOOL;                           // . [LOC] Sens oppose confirme actif
    EncoderAvailableEffective       : BOOL;                           // . [LOC] Codeur valide ou bypass effectif
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Ready := FALSE;
    Status.Busy := FALSE;
    Status.Done := FALSE;
    SafeStop := TRUE;
    DescendPermit := FALSE; // 🛡️ Fail-Safe : aucun mouvement permis si Safety désactivé
    AscentPermit := FALSE;  // 🛡️ Fail-Safe : aucun mouvement permis si Safety désactivé
    PowerCutOff := FALSE;
    Status.State := E_State.DISABLED;
    // 🛡️ ErrorId conservé : la cause du dernier défaut reste visible IHM.
    // Error en miroir de cette cause ; les sorties restent fail-safe (lignes ci-dessus).
    Status.Error := (Status.ErrorId <> 16#0000);
    // Force le réarmement (WasArmed→FALSE) via FB_DriftGuard.
    DriftGuardA(Arm := FALSE, PositionM := CablePosM, ToleranceM := UncommandedDriftToleranceM);
    DriftGuardC(Arm := FALSE, PositionM := CablePosM, ToleranceM := BenneSlipToleranceM);
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonMecaE(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonNoMovement(IN := FALSE);
    TonStartupWarmup(IN := FALSE);
    RETURN;
END_IF;

Ready := TRUE;
Status.State := E_State.READY;

{endregion}

{region "§2 Initialisation et bypass global"}
// Détecte la fin du référencement pour éviter le pic de vitesse au cycle de transition (offset appliqué)
IF LastInReferencingMode AND NOT InReferencingMode THEN
    DriftGuardA(Arm := FALSE, PositionM := CablePosM, ToleranceM := UncommandedDriftToleranceM);
END_IF;
LastInReferencingMode := InReferencingMode;

// Si le contacteur de puissance est ouvert (PowerContactorEngaged = FALSE), on force les sorties de sécurité
// mais on ne fait pas de RETURN pour permettre le diagnostic et l'acquittement (Reset) des défauts.
IF NOT PowerContactorEngaged THEN
    DriftGuardA(Arm := FALSE, PositionM := CablePosM, ToleranceM := UncommandedDriftToleranceM);
    DriftGuardC(Arm := FALSE, PositionM := CablePosM, ToleranceM := BenneSlipToleranceM);
END_IF;

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);

// 🧹 Initialisation au premier scan : évitement des alarmes transitoires au démarrage
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    Status.ErrorId := 16#0000;
    RETURN;
END_IF;

// 🌐 BYPASS GLOBAL : si TRUE, on force ErrorId = 0 ET on saute toute la logique de sécurité
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonMecaE(IN := FALSE);
END_IF;

{endregion}

{region "§3 Protections immediates position"}
// 🔍 3sexties. FIN DE COURSE HAUT / CAPTEUR DE POSITION HAUTE (anti-débordement) — bit5
// ⚠️ Convention NAMING_CONVENTION.md : TopPositionSensor TRUE = sain/non atteint (NF), FALSE =
// position haute réellement atteinte (contact ouvert). Si la position haute EST atteinte
// (TopPositionSensor=FALSE), qu'on n'est pas en phase de référencement (homing), ET qu'on
// commande un mouvement vers le haut (Direction > 0), alors on lève le défaut.
// SORTI du bloc "IF NOT BypassGlobal" ci-dessous — même doctrine que le blocage réel (§4) :
// BypassGlobal M1/M2 ne doit masquer NI le mouvement NI l'alarme IHM de ces 2 fins de course
// physiques. Seuls BypassProcess (groupé, conscient) ou BypassTopLimitSwitch (individuel)
// peuvent encore éteindre CETTE alarme — exactement comme tous les autres bypass individuels du
// fichier (une alarme ne s'éteint QUE si on a explicitement demandé à ignorer CETTE protection
// précise, jamais via le bypass global qui vise le reste du domaine : Méca A-E, thermique, phase,
// comm, sync, codeur).
IF NOT (BypassProcess OR BypassTopLimitSwitch) AND NOT TopPositionSensor AND NOT InReferencingMode AND (Direction > 0) THEN
    Status.ErrorId := Status.ErrorId OR 16#0020;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFDF;
END_IF;

// 🔍 3septies. LONGUEUR MAX DE CÂBLE (profondeur max autorisée) — bit6
// Sécurité active hors référencement. Si la position de câble descend sous la limite basse
// physique (CablePosM <= CfgCableLimitDescentM), alors on interdit uniquement la descente.
// SORTI du bloc "IF NOT BypassGlobal" — même doctrine que bit5 ci-dessus.
IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
    Status.ErrorId := Status.ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFBF;
END_IF;

{endregion}

{region "§4 Diagnostics et protections treuil"}
// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL (uniquement si bypass global désactivé)
IF NOT BypassGlobal THEN

    // ⏱️ Temporisation 3s de mise en route des bus de terrain au boot (CANopen / Modbus IHM)
    TonStartupWarmup(IN := Enable, PT := T#3s);

    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassOperatorComm) THEN
        IF (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk) THEN
            Status.ErrorId := Status.ErrorId OR 16#0001;       // Perte communication opérateur : joystick CAN ou heartbeat IHM absent
        ELSE
            Status.ErrorId := Status.ErrorId AND 16#FFFE;      // Effacement auto si la com repasse saine
        END_IF;
    ELSIF NOT TonStartupWarmup.Q THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFE;          // Inhibition pendant l'initialisation boot
    END_IF;
    IF ResetEdge.Q THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFE;
    END_IF;

// 🔍 3bis. PERTE CODEUR DE CE TREUIL
// Le fonctionnement sans codeur reste interdit par défaut.
// Le bypass est individuel, maintenu consciemment depuis l'IHM et strictement limité à MAINT_N2.
// Il ne masque aucun autre défaut du treuil et n'agit jamais sur l'autre instance.
EncoderAvailableEffective := EncoderAvailable
                             OR BypassGlobal
                             OR ((EncoderFaultBypass OR BypassProcess) AND (Mode = E_Mode.MAINT_N2));
IF NOT EncoderAvailableEffective THEN
    Status.ErrorId := Status.ErrorId OR 16#0002;
ELSE
    Status.ErrorId := Status.ErrorId AND 16#FFFD; (* Effacement auto si le codeur est dispo OU bypassé *)
END_IF;

// 🔍 3ter. SURCHAUFFE MOTEUR — bit2, participe au SafeStop total
// ET BypassMotorThermal — même doctrine que BypassBrakeThermal (§3sexies-ter),
// bypass dédié plutôt que de dépendre uniquement du bypass groupé BypassSafety.
IF NOT (BypassSafety OR BypassMotorThermal) AND ThermalFeedback THEN
    Status.ErrorId := Status.ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFB;
END_IF;

// 🔍 3quater. MOU DE CÂBLE (physiquement sur tambour M2, câblé sur les 2 instances Safety)
// Mode NORMAL (SyncEnable=TRUE) → SafeStop M1+M2 (bit3 inclus dans SafeStop)
// Mode RÉCUPÉRATION (SyncEnable=FALSE) → DescendPermit uniquement (descente interdite pour ne pas dérouler, montée OK pour retendre/fermer)
IF NOT BypassProcess AND SlackCableDetected THEN
    Status.ErrorId := Status.ErrorId OR 16#0008;
ELSIF ResetEdge.Q AND NOT SlackCableDetected THEN
    Status.ErrorId := Status.ErrorId AND 16#FFF7;
END_IF;

// 🔍 3quinquies. ROTATION DE PHASE —
// bit4, participe au SafeStop total (sens moteur potentiellement inversé, danger 2 sens).
IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
    Status.ErrorId := Status.ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFEF;
END_IF;

// 🔍 3octies. MÉCA A — MOUVEMENT NON COMMANDÉ GÉNÉRAL — bit7
// Armé quand tout est physiquement confirmé coupé (contacteurs + frein). Si dérive ou vitesse
// détectée pendant que c'est armé → roue libre / frein insuffisant.
// La chaîne codeur produit la mesure ; ce bloc safety la surveille seulement.
DriftGuardA(
    Arm        := MeasuredSpeedValid AND FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND NOT InReferencingMode,
    PositionM  := CablePosM,
    ToleranceM := UncommandedDriftToleranceM
);
MecaADriftM := DriftGuardA.DriftM;   // Diagnostic IHM

IF NOT (BypassSafety OR BypassMecaA) AND MeasuredSpeedValid AND (DriftGuardA.Violation OR (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND NOT InReferencingMode AND (MeasuredSpeedMps > UncommandedSpeedThresholdMps))) THEN
    Status.ErrorId := Status.ErrorId OR 16#0080;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FF7F;
END_IF;

// 🔍 3nonies. MÉCA B — PILOTAGE ACTIF SANS COMMANDE OPÉRATEUR — bit8
// Indépendant de FB_Winch (défense en profondeur). Perte CAN (bit0) OU joystick au neutre ;
// si les contacteurs OU LE FREIN ne confirment pas être retombés/serrés dans PostRampTimeout, défaut.
// Un frein qui ne confirme pas son engagement dans ce délai est tout aussi dangereux qu'un
// contacteur qui ne retombe pas (risque de mouvement/roue libre non détecté).
MecaB_NoOperatorCmd := (NOT JoystickOnline) OR (NOT JoystickOperational)
                       OR (NOT HeartbeatIhmOk) OR JoystickYNeutral;
TonMecaB(IN := NOT (BypassSafety OR BypassMecaB) AND MecaB_NoOperatorCmd AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback), PT := PostRampTimeout);
MecaBElapsedTime := TonMecaB.ET;   // Diagnostic IHM
IF TonMecaB.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#0100;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FEFF;
END_IF;

// 🔍 3decies. MÉCA C — GLISSEMENT M1 PENDANT BENNE, ESCALADE — bit9
// Armé UNIQUEMENT pour l'instance M1 (BenneHoldStillActive câblé sur instBucket.Busy côté M1
// seulement, toujours FALSE côté M2). Tolérance plus large que celle de FB_Bucket (1.0 m) —
// n'intervient que si la couche Benne (SafeStop M1 seul) n'a pas suffi.
// Dérive surveillée via FB_DriftGuard.
DriftGuardC(
    Arm        := NOT (BypassSafety OR BypassMecaC) AND BenneHoldStillActive,
    PositionM  := CablePosM,
    ToleranceM := BenneSlipToleranceM
);
MecaCDriftM := DriftGuardC.DriftM;   // Diagnostic IHM

IF DriftGuardC.Violation THEN
    Status.ErrorId := Status.ErrorId OR 16#0200;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FDFF;
END_IF;

// 🔍 3undecies. THERMIQUE FREIN COMMUN M1/M2/M3 — bit10
// Signal commun (1 seul fil, câblé identiquement sur les 3 instances Safety) : sa perte peut
// signifier qu'un frein colle instantanément (frein à manque de courant) → SafeStop ET
// PowerCutOff (voir bandeau en-tête).
IF NOT (BypassSafety OR BypassBrakeThermal) AND BrakeThermalFeedback THEN
    Status.ErrorId := Status.ErrorId OR 16#0400;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FBFF;
END_IF;

// 🔍 3duodecies. MÉCA D — ARRIVÉE CAPTEUR HAUT HORS RÉFÉRENCEMENT — bit11
// Complète le bit5 (AscentPermit immédiat) : arme la MÊME condition (capteur haut atteint, hors
// homing) mais avec un délai de confirmation, comme Méca B. Si les contacteurs ET le frein ne
// confirment pas être retombés/serrés dans PostRampTimeout après l'arrivée au capteur → défaut
// → SafeStop ET PowerCutOff (la coupure AscentPermit seule ne suffit pas à arrêter réellement
// le treuil : roue libre ou contacteur/frein défaillant).
TonMecaD(
    IN := NOT (BypassSafety OR BypassMecaD) AND ((((NOT TopPositionSensor AND NOT InReferencingMode) 
            OR (Homed AND NOT HomingSuspect AND (CablePosM >= (TopLimitM + 0.10))))
           AND (Direction >= 0)) // Neutralise la butée haute en descente (Direction = -1)
          AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)), 
    PT := PostRampTimeout
);
IF TonMecaD.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#0800;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#F7FF;
END_IF;

// 🔍 3terdecies. MÉCA E — ÉCART SYNCHRO M1/M2 CRITIQUE — bits 12/13
// Couche INDÉPENDANTE de FB_WinchSync (écart mineur, 1er niveau) — défense en profondeur pour un
// écart VRAIMENT important. ExpectedOtherWinchPosM est DÉJÀ corrigé de l'offset benne actif par
// l'appelant : comparaison directe valable que le benne soit ouvert, fermé, ou absent du calcul.
// Suppression pendant BenneBusy (trajet actif = écart transitoire normal, pas un défaut),
// InReferencingMode (position pas fiable pendant homing) et OtherWinchInhibited (l'autre treuil
// en maintenance a une position figée, non comparable).
// Bit12 : détection → SafeStop immédiat. Bit13 : escalade si pas confirmé arrêté → PowerCutOff.
IF NOT (BypassProcess OR BypassMecaE) AND SyncEnable AND NOT BenneBusy AND NOT InReferencingMode AND NOT OtherWinchInhibited
   AND (ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM) THEN
    Status.ErrorId := Status.ErrorId OR 16#1000;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#EFFF;
END_IF;

TonMecaE(IN := NOT (BypassSafety OR BypassMecaE) AND (((Status.ErrorId AND 16#1000) <> 16#0000) AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)),
         PT := PostRampTimeout);
IF TonMecaE.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#2000;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#DFFF;
END_IF;

// 🔍 3quaterdecies — SENS RÉEL OPPOSÉ À LA COMMANDE (bit14)
// Le signe de la vitesse câble est comparé à la direction commandée uniquement pendant un
// mouvement effectivement demandé. La temporisation filtre bruit codeur et inversion transitoire.
OppositeDirectionActive := NOT BypassProcess AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
    AND (((Direction > 0) AND (MeasuredSpeedSignedMps < -MovementSpeedThresholdMps))
      OR ((Direction < 0) AND (MeasuredSpeedSignedMps > MovementSpeedThresholdMps))));
TonOppositeDirection(IN := OppositeDirectionActive, PT := OppositeDirectionTimeout);
IF TonOppositeDirection.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#4000;
ELSIF ResetEdge.Q AND NOT OppositeDirectionActive THEN
    Status.ErrorId := Status.ErrorId AND 16#BFFF;
END_IF;

// ⏱️ 3quindecies — ABSENCE DE MOUVEMENT MALGRÉ COMMANDE (bit15)
// Détecte charge coincée, contacteur inefficace ou chaîne mécanique non entraînée. SafeStop seul :
// aucun retour ne justifie une coupure puissance brutale immédiate ; l'escalade reste matérielle.
TonNoMovement(
    IN := NOT BypassProcess AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
          AND (ABS(MeasuredSpeedSignedMps) < MovementSpeedThresholdMps)),
    PT := NoMovementTimeout
);
IF TonNoMovement.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#8000;
ELSIF ResetEdge.Q AND (NOT MeasuredSpeedValid OR NOT MovementCommanded OR (ABS(MeasuredSpeedSignedMps) >= MovementSpeedThresholdMps)) THEN
    Status.ErrorId := Status.ErrorId AND 16#7FFF;
END_IF;

END_IF; // fin IF NOT BypassGlobal

{endregion}

{region "§5 Arbitrage sorties securite"}
// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Status.Error := (Status.ErrorId <> 16#0000);       // 🧭 Partie3 §4 : miroir de TOUT le domaine, y compris mou de câble (visible IHM)
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

// 🟧 SafeStop : bits 0/1/2/3/4 (joystick, codeur, thermique moteur, MOU CÂBLE, phases) + 7/8/9
// (Méca A/B/C) + 10 (thermique frein commun) + 11 (Méca D) + 12/13 (Méca E, écart synchro critique) ou si contacteur coupé
IF NOT PowerContactorEngaged THEN
    SafeStop := TRUE;
ELSIF NOT SyncEnable THEN
    SafeStop := (Status.ErrorId AND 16#FF97) <> 16#0000;   // bit3 exclu → SafeStop normal sans mou câble
ELSE
    SafeStop := (Status.ErrorId AND 16#FF9F) <> 16#0000;   // bit3 inclus → SafeStop complet avec mou câble
END_IF;

// ⬇️ DescendPermit : TRUE = descente autorisée (pas de limite basse, pas de mou câble en mode récup, contacteur engagé)
// Polarité positive Fail-Safe (TRUE = mouvement autorisé).
DescendPermit := NOT (
    (((Status.ErrorId AND 16#0040) <> 16#0000 OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
    OR (((CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode) AND NOT BypassCableLimitSwitch)
    OR (LimitLegalReached AND NOT (BypassProcess OR BypassLimitLegal))
    OR (((Status.ErrorId AND 16#0008) <> 16#0000 AND NOT SyncEnable) AND NOT (BypassProcess OR BypassGlobal))
);

// ⬆️ AscentPermit : TRUE = montée autorisée (pas de fin course haut, pas de dépassement position)
// Polarité positive Fail-Safe (TRUE = mouvement autorisé).
AscentPermit := NOT (
    (((Status.ErrorId AND 16#0020) <> 16#0000
    OR (NOT TopPositionSensor AND NOT InReferencingMode))
    AND NOT BypassTopLimitSwitch)
    OR ((Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM)) AND NOT BypassTopLimitSoftware)
);

// PowerCutOff — bits 7/8/9 (Méca A/B/C, voir bandeau en-tête).
// Coupure puissance amont : les contacteurs locaux sont déjà confirmés coupés/insuffisants,
// SafeStop seul ne sert à rien dans ces 3 cas précis.
// bit2 (surchauffe/perte thermique MOTEUR) et bit10 (surchauffe/perte thermique FREIN commun) :
// un frein à manque de courant peut coller instantanément sur perte de son retour thermique ;
// une rampe SafeStop seule ne protège pas la mécanique dans ce cas, coupure puissance immédiate
// nécessaire. Même raisonnement appliqué au thermique moteur par cohérence/défense en profondeur.
// bit11 (Méca D, capteur haut) : même raisonnement que Méca A/B — contacteurs/frein déjà censés
// être coupés (AscentPermit immédiat sur capteur), une confirmation manquante après délai signifie
// que la coupure locale n'a pas suffi.
// bit13 (Méca E escalade) : PAS bit12 seul (détection immédiate = SafeStop uniquement ;
// PowerCutOff seulement si l'arrêt n'est pas confirmé après délai).
PowerCutOff := (Status.ErrorId AND 16#2F84) <> 16#0000;

// Busy, Done non utilisés mais présents pour conformité (comme FB_Diag_CanOpen)
Status.Busy := FALSE;
Status.Done := FALSE;

{endregion}
