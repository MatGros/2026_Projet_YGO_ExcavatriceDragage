(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Winch — Bloc safety MÉTIER du domaine Treuils (M1: moteur de retenue / M2: moteur Benne)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-10_Fonction_Winch_v2.0.md,
                   DOC/AF_Partie-09_Fonction_Encoder_v2.1.md §7
                    (contrat : DOC/AF_Partie-03_Contrats_Composants_v2.1.md §2/§3)
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
   🔴🔧 REX 2026-07-07 — IMPLÉMENTATION DU CAS B (roue libre) + 2 NOUVEAUX GARDE-FOUS
      (demande utilisateur, suite à la consolidation du feedback contacteur unique) :
      - **Bit7 — Méca A "mouvement non commandé général"** : arme une surveillance
        position/vitesse dès que `FwdRevSpeedFeedbackOff AND BrakeFeedback` (tout
        confirmé physiquement coupé). Si pendant que c'est armé, la vitesse mesurée
        codeur dépasse `UncommandedSpeedThresholdMps` (0.02 m/s, théorique — à
        ajuster sur site) OU la position dérive de plus de `UncommandedDriftToleranceM`
        (2.0 m) par rapport à la référence prise à l'armement → défaut → `SafeStop`
        ET `PowerCutOff` (les contacteurs sont déjà confirmés coupés, `SafeStop` seul
        ne suffit pas — c'est le rôle de `PowerCutOff`).
      - **Bit8 — Méca B "pilotage actif malgré absence de commande opérateur"** :
        indépendant de la logique interne FB_Winch (défense en profondeur — reste
        valable même si l'arbitrage FB_Winch est en défaut). Si (perte CAN joystick,
        bit0 déjà existant) OU (joystick au neutre, `JoystickYNeutral`) ET que
        `FwdRevSpeedFeedbackOff` ne repasse PAS à `TRUE` dans `PostRampTimeout` (3s,
        théorique) → défaut → `SafeStop` ET `PowerCutOff`.
      - **Bit9 — Méca C "glissement M1 pendant mouvement Benne" (escalade)** :
        armé UNIQUEMENT si `BenneHoldStillActive=TRUE` (câblé sur `instBucket.Busy`
        pour l'instance M1 SEULEMENT — toujours `FALSE` côté M2, qui doit bouger
        pendant le benne). Référence position prise à l'armement ; si dérive
        `BenneSlipToleranceM` (2.0 m, > à la tolérance 1.0 m déjà surveillée côté
        `FB_Bucket` lui-même) dépassée → la couche Benne (`SafeStop` M1 seul, 1m)
        n'a pas suffi → escalade `PowerCutOff` (dernier recours).
      - **Bit14** : sens codeur opposé au sens commandé, confirmé 500 ms → `SafeStop`.
      - **Bit15** : absence de vitesse malgré relais de sens commandé, confirmée 3 s → `SafeStop`.
   🆕 REX 2026-07-08 (demande utilisateur, retour terrain frein) :
      - `BrakeThermalFeedback` (COMMUN aux 3 freins M1/M2/M3, 1 seul fil, câblé IDENTIQUEMENT
        sur les 2 instances Winch + l'instance Translation — même principe que `SlackCableDetected`) :
        défaut/perte → bit10 ErrorId → `SafeStop` **ET `PowerCutOff`**. Justification : le frein
        est à manque de courant (colle au repos, voir FB_Brake) — la perte de ce retour peut
        signifier qu'un frein colle INSTANTANÉMENT alors que le moteur est encore sous couple/en
        mouvement ; une simple rampe de décélération (`SafeStop`) ne protège pas la mécanique
        dans ce cas précis, il faut couper la puissance immédiatement.
      - **Escalade PowerCutOff étendue à bit2 (surchauffe moteur, déjà existant)** : même
        raisonnement — la perte du retour thermique moteur M1/M2 est traitée à l'identique du
        thermique frein (défense en profondeur, demande explicite utilisateur), donc ajoutée au
        masque `PowerCutOff` en plus du masque `SafeStop` (déjà présente).
   🔧 REX 2026-07-08 (audit + demande utilisateur, factorisation/renforcement Méca A/B/C) :
      - **Méca A et Méca C factorisés** via la nouvelle brique réutilisable `FB_DriftGuard`
        (`CODE/WINCH/` — seul consommateur réel à ce jour, pas `COMMUN` : voir bandeau du FB) :
        les deux partageaient ~15 lignes identiques (armement + capture position référence +
        calcul dérive) — remplacé par 2 instances (`DriftGuardA`/`DriftGuardC`), comportement
        strictement inchangé. Méca A garde son propre check vitesse en plus (câblé en OR, hors
        périmètre de la brique). `MecaADriftM`/`MecaCDriftM`/`MecaBElapsedTime` exposés en sortie
        pour diagnostic/réglage tolérances côté IHM (voir §6 mapping).
      - **Méca B étendu au frein** : vérifiait uniquement `FwdRevSpeedFeedbackOff` (contacteurs)
        sous `PostRampTimeout` — `BrakeFeedback` (frein) ajouté à la même condition. Un frein qui
        ne confirme pas son engagement dans ce délai est tout aussi dangereux qu'un contacteur qui
        ne retombe pas (risque de mouvement/roue libre non détecté).
   🆕 REX 2026-07-08 (3) — MÉCA D (bit11), demande utilisateur (retour terrain test banc) :
      modèle à 3 couches en fonctionnement NORMAL (hors référencement) à l'approche du capteur
      haut : (1) ~arrêt rampé normal à `HomingTargetMx_M - WinchTopStopMarginM` (voir
       `PRG_TREUILS_CFC.st`, gardé par `HomingApproachEnable` désormais — REX 2026-07-08 (2)) ;
      (2) coupure immédiate `ForbidAscent` si le capteur physique est réellement atteint (bit5,
      déjà existant) ; (3) **Méca D** : si malgré la coupure (2), les contacteurs ET le frein ne
      confirment pas être retombés/serrés dans `PostRampTimeout` → `SafeStop` ET `PowerCutOff` —
      même motif exact que Méca B (`TonMecaD`, même vérification), juste une condition d'armement
      différente (capteur haut atteint hors référencement, au lieu de perte commande opérateur).
   🆕 REX 2026-07-08 (4) — MÉCA E (bits 12/13), écart synchro M1/M2 CRITIQUE, demande utilisateur
      (analyse redondance synchro) : `FB_WinchSync` (écart mineur, `WinchSyncTolerance_M`) reste
      le 1er niveau (arrêt rampe normale, `PRG_TREUILS_CFC.st`). Méca E est une couche
      SUPPLÉMENTAIRE et INDÉPENDANTE dans `FB_Safety_Winch` pour un écart VRAIMENT important
      (`CriticalSyncToleranceM`, théorique 2.0m) — défense en profondeur si le 1er niveau n'a pas
      suffi (ex. treuil qui continue malgré l'arrêt demandé). Nouvelles entrées `OtherWinchPosM`
      (position croisée : M2 côté instance M1, M1 côté instance M2) et `BenneBusy` (suppression
      pendant un cycle benne — l'écart M1/M2 y est volontaire, PAS un défaut ; 1 cycle de retard
      accepté, même principe que `BenneHoldStillActive`, négligeable vu l'amplitude en jeu).
      - **Bit12** : écart critique détecté (`SyncEnable AND NOT BenneBusy AND NOT
        InReferencingMode AND ABS(CablePosM - OtherWinchPosM) > CriticalSyncToleranceM`) →
        `SafeStop` immédiat (rampe rapide), PAS de `PowerCutOff` à ce stade.
      - **Bit13** : escalade — si l'arrêt (bit12) n'est PAS confirmé (contacteurs ET frein) dans
        `PostRampTimeout` → `SafeStop` ET `PowerCutOff` (dernier recours, même logique que Méca
        B/D : la rampe seule n'a visiblement pas suffi à arrêter réellement le treuil).
   🔴🔧 REX 2026-08-07 — BypassGlobal DÉSACTIVAIT LES FINS DE COURSE PHYSIQUES (demande client,
      audit confirmé à 100% par lecture directe du fichier) : `ForbidAscent`/`ForbidDescent`
      étaient calculés puis ANDés avec `NOT BypassGlobal` en toute fin de logique — même le check
      brut indépendant du capteur haut (déjà conçu pour "rester actif" selon son propre commentaire
      REX 2026-07-08) se retrouvait masqué. Concrètement : `Bypass.Global` sur M1/M2 empêchait
      l'arrêt réel sur fin de course haute/basse au joystick, aucun crash mécanique visible tant
      que l'opérateur ne relâchait pas. Corrigé : `BypassGlobal` retiré des deux formules finales
      (`ForbidAscent`/`ForbidDescent`) — seuls `BypassTopLimitSwitch`/`BypassCableLimitSwitch`
      (individuels, conscients) peuvent désormais lever CES deux protections précises. Le reste du
      domaine (Méca A-E, thermique, phase, comm, sync, codeur) reste masqué par `BypassGlobal`
      exactement comme avant — changement strictement limité aux 2 fins de course physiques.
      🔧 COMPLÉTÉ (même jour, demande client "intègre-le totalement côté IHM/troubleshooting") :
      les calculs bit5/bit6 (§3sexties/§3septies) sont EUX AUSSI sortis du bloc `IF NOT
      BypassGlobal` — `ErrorId`/`Error` (donc l'alarme IHM `WinchM1/M2SafetyHMI.Error`) reflètent
      désormais le vrai état des fins de course même sous `BypassGlobal`, cohérent avec le
      blocage réel déjà corrigé. Seuls `BypassProcess`/`BypassTopLimitSwitch`/
      `BypassCableLimitSwitch` (conscients, individuels/groupés) peuvent encore éteindre CETTE
      alarme précise — plus jamais `BypassGlobal` seul.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Safety_Winch) ===

FUNCTION_BLOCK PUBLIC FB_Safety_Winch
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    PowerContactorEngaged     : BOOL;        // Chaîne AU réarmée + conditions globales OK (info de contexte)
    Mode                : E_Mode;      // Mode courant (autorisations)
    SyncEnable          : BOOL;        // 🔧 REX 2026-07-08 : ex-OverrideSync inversé — FALSE (MAINT N1/N2) → désactive synchro ET lève SafeStop mou câble (récupération manuelle)
    JoystickOnline      : BOOL;        // instDiagCanOpen.DeviceJoystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.DeviceJoystick.Operational
    HeartbeatIhmOk      : BOOL;        // 💓 IHM↔PLC : TRUE après front post-boot, FALSE = perte communication opérateur
    EncoderAvailable    : BOOL;        // Sortie FB_Encoder_Abs DU TREUIL concerné par cette instance
    EncoderFaultBypass  : BOOL;        // 🔧 Autorisation maintenance sans codeur ; effective uniquement en MAINT_N2
    ThermalFeedback     : BOOL;        // Retour TOR thermique CE moteur (NC) — source normalisée par PRG_02_Acquisition.HwIn
    BrakeThermalFeedback: BOOL;        // 🆕 REX 2026-07-08 : retour TOR thermique frein commun — source normalisée par PRG_02_Acquisition.HwIn
    SlackCableDetected  : BOOL;        // Mou câble sur tambour M2 (NC, câblé sur les 2 instances) : TRUE=mou détecté → SafeStop sauf si NOT SyncEnable
    PhaseRotationOk     : BOOL;        // PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI — TRUE = rotation phases correcte
    TopPositionSensor   : BOOL;        // Capteur position haute (NC commun) — TRUE=libre, FALSE=butée atteinte
    InReferencingMode   : BOOL;        // TRUE si treuil en cours de homing (référencement)
    CablePosM           : REAL;        // Position actuelle câble en mètres (scalée)
    CfgCableLimitDescentM  : REAL;        // Limite basse physique descente en mètres (valeur négative)
    Direction           : INT;         // 🆕 REX 2026-07-08 : Consigne active de direction (-1/0/+1)
    MovementCommanded   : BOOL;        // TRUE si au moins un contacteur de sens est réellement commandé
    Homed               : BOOL;        // Indique si le treuil est référencé
    HomingSuspect       : BOOL;        // Indique si le référencement est suspect
    TopLimitM           : REAL;        // Position limite haute active (cible homing, m)

    // 🔧 REX 2026-07-07 — Méca A/B/C (voir bandeau en-tête)
    FwdRevSpeedFeedbackOff  : BOOL;         // Retour unique "tous contacteurs sens+vitesse retombés" CE treuil
    BrakeFeedback           : BOOL;         // Retour frein CE treuil (TRUE = ouvert/desserré — révocation 2026-08-03)
    JoystickYNeutral        : BOOL;         // TRUE = joystick axe Y au neutre (magnitude ~0), précalculé en amont
    BenneHoldStillActive  : BOOL;         // TRUE seulement pour l'instance M1 pendant que le benne bouge M2 seul (instBucket.Busy) — toujours FALSE côté M2
    UncommandedSpeedThresholdMps : REAL := 0.02; // 🔧 Méca A — théorique, à ajuster sur site
    UncommandedDriftToleranceM   : REAL := 2.0;  // 🔧 Méca A — théorique, à ajuster sur site
    PostRampTimeout              : TIME := T#3S; // 🔧 Méca B — théorique, à ajuster sur site
    BenneSlipToleranceM        : REAL := 2.0;  // 🔧 Méca C — escalade safety (> 1.0 m déjà surveillé côté FB_Bucket)

    // 🆕 REX 2026-07-08 (4) — Méca E (bits 12/13), écart synchro M1/M2 critique
    ExpectedOtherWinchPosM  : REAL;         // Position ATTENDUE de l'AUTRE treuil, DÉJÀ corrigée de
                                             // l'offset benne actif par l'appelant (PRG_SAFETY_CFC) —
                                             // ce FB ne fait qu'un ABS(CablePosM - ExpectedOtherWinchPosM)
    BenneBusy             : BOOL;         // instBucket.Busy (les 2 instances) — suppression pendant
                                             // le trajet actif (écart transitoire normal, pas un défaut)
    CriticalSyncToleranceM  : REAL := 2.0;  // 🔧 Méca E — théorique, à ajuster sur site
    // 🆕 REX 2026-07-08 (7) : retour terrain — InhibitM1 côté instance M1 (Enable global) ne suffit
    // pas : si c'est l'AUTRE treuil qui est inhibé (ex. M2 en maintenance), M1 continue de comparer
    // sa position à ExpectedOtherWinchPosM (calculé depuis la position figée de M2) — écart croît
    // sans borne pendant que M1 travaille seul normalement → faux Méca E. Croisé (M2 côté instance
    // M1, M1 côté instance M2), même principe que ExpectedOtherWinchPosM.
    OtherWinchInhibited     : BOOL;         // Inhibition de l'AUTRE treuil (mise en service N2)
    MovementSpeedThresholdMps : REAL := 0.02; // Seuil mouvement mesurable pour contrôles sens/absence
    MeasuredSpeedMps          : REAL; // Mesure absolue produite par PRG_02 chaîne codeur
    MeasuredSpeedSignedMps    : REAL; // Mesure signée produite par PRG_02 chaîne codeur
    MeasuredSpeedValid        : BOOL; // TRUE si la fenêtre horodatée codeur est complète et fiable
    OppositeDirectionTimeout  : TIME := T#500MS; // Confirmation sens réel opposé à la commande
    NoMovementTimeout         : TIME := T#3S;    // Confirmation absence de mouvement malgré commande
    // 🌐 Bypass Global : si TRUE, force ErrorId=0 et saute toutes les vérifications
    BypassGlobal              : BOOL := FALSE;
    BypassSafety          : BOOL := FALSE;   // 🛡️ Bypass groupé PowerCutOff (bits 2,7,8,9,10,11,13)
    BypassProcess         : BOOL := FALSE;   // ⚙️ Bypass groupé SafeStop/Forbid seul (bits 0,1,3,4,5,6,12,14,15)
    BypassTopLimitSwitch  : BOOL := FALSE;   // 🚧 Bypass individuel fin de course haute (bit5)
    BypassCableLimitSwitch: BOOL := FALSE;   // 🚧 Bypass individuel limite basse câble (bit6)
    BypassOperatorComm    : BOOL := FALSE;   // 📡 Bypass perte communication opérateur
    BypassPhaseRotation   : BOOL := FALSE;   // ⚡ Bypass défaut rotation phases
    BypassBrakeThermal    : BOOL := FALSE;   // 🌡️ Bypass surchauffe frein
    BypassMotorThermal    : BOOL := FALSE;   // 🆕 2026-08-07 : 🌡️ Bypass surchauffe moteur (bit2) —
                                              // manquait alors que BypassBrakeThermal existe déjà pour
                                              // le même niveau de sévérité (SafeStop+PowerCutOff)
    BypassMecaA           : BOOL := FALSE;   // 🔄 Bypass Méca A
    BypassMecaB           : BOOL := FALSE;   // 🛑 Bypass Méca B
    BypassMecaC           : BOOL := FALSE;   // 🏋️ Bypass Méca C
    BypassMecaD           : BOOL := FALSE;   // 🚧 Bypass Méca D
    BypassMecaE           : BOOL := FALSE;   // 🔄 Bypass Méca E
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bits0..13 : protections existantes ; bit14 : sens réel opposé ; bit15 : absence mouvement malgré commande
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Arrêt rapide 2 sens (Enable maintenu) — bits 0/1/2/3/4/7/8/9/10/11 (mou câble inclus SAUF si NOT SyncEnable)
    ForbidDescent       : BOOL;        // ⬇️ Interdit descente uniquement — bit6 (limite basse câble)
    ForbidAscent        : BOOL;        // ⬆️ Interdit montée uniquement — bit5 (fin course haut) OU bit3+(NOT SyncEnable) (récupération mou câble)
    PowerCutOff         : BOOL;        // 🧨 Coupure puissance amont réelle — bits 2/7/8/9/10/11 (voir bandeau en-tête)

    // 🆕 REX 2026-07-08 : diagnostic/réglage tolérances — miroirs des bricks internes, à consommer
    // par l'IHM pour la mise en service (voir PRG_SUPERVISION_CFC, GVL_IHM.M1Winch/M2Winch)
    MecaADriftM         : REAL;        // Dérive mesurée Méca A (m) — réglage UncommandedDriftToleranceM
    MecaCDriftM         : REAL;        // Dérive mesurée Méca C (m, benne M1) — réglage BenneSlipToleranceM
    MecaBElapsedTime    : TIME;        // Temps écoulé confirmation contacteurs/frein — réglage PostRampTimeout
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    FirstScanDone       : BOOL;

    // 🔧 Méca A (bit7) — la vitesse est désormais reçue de la chaîne codeur (T84/T85)
    DriftGuardA         : FB_DriftGuard;   // 🔧 REX 2026-07-08 : factorise Méca A (remplace MecaA_Armed/MecaA_RefPosM)

    // 🔧 REX 2026-07-07 — Méca B (bit8)
    MecaB_NoOperatorCmd : BOOL;         // (perte CAN joystick) OU (joystick au neutre)
    TonMecaB            : TON;

    // 🆕 REX 2026-07-08 (3) — Méca D (bit11) : arrivée capteur haut hors référencement
    TonMecaD            : TON;

    // 🔧 REX 2026-07-07 — Méca C (bit9, escalade)
    DriftGuardC         : FB_DriftGuard;   // 🔧 REX 2026-07-08 : factorise Méca C (remplace MecaC_Armed/MecaC_RefPosM)

    // Transition référencement
    LastInReferencingMode : BOOL;

    // 🆕 REX 2026-07-08 (4) — Méca E (bits 12/13)
    TonMecaE               : TON;   // Confirmation arrêt après détection écart critique (escalade PowerCutOff)
    TonOppositeDirection  : TON;
    TonNoMovement         : TON;
    OppositeDirectionActive : BOOL;
    EncoderAvailableEffective : BOOL;   // Codeur valide OU bypass individuel autorisé en MAINT_N2
    TonStartupWarmup      : TON;        // ⏱️ Inhibition 3s au boot + effacement auto coms
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    SafeStop := TRUE;
    ForbidDescent := TRUE;
    ForbidAscent := TRUE; // 🛡️ T86 : sortie safety déterministe pendant neutralisation
    PowerCutOff := FALSE;
    State := E_State.DISABLED;
    Error := FALSE;
    ErrorId := 16#0000;
    // 🔧 REX 2026-07-08 : force le réarmement (WasArmed→FALSE) via FB_DriftGuard, comportement
    // identique à l'ancien MecaA_Armed/MecaC_Armed := FALSE.
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
State := E_State.READY;

// Détecte la fin du référencement pour éviter le pic de vitesse au cycle de transition (offset appliqué)
IF LastInReferencingMode AND NOT InReferencingMode THEN
    DriftGuardA(Arm := FALSE, PositionM := CablePosM, ToleranceM := UncommandedDriftToleranceM); // 🔧 REX 2026-07-08
END_IF;
LastInReferencingMode := InReferencingMode;

// Si le contacteur de puissance est ouvert (PowerContactorEngaged = FALSE), on force les sorties de sécurité
// mais on ne fait pas de RETURN pour permettre le diagnostic et l'acquittement (Reset) des défauts.
IF NOT PowerContactorEngaged THEN
    DriftGuardA(Arm := FALSE, PositionM := CablePosM, ToleranceM := UncommandedDriftToleranceM); // 🔧 REX 2026-07-08
    DriftGuardC(Arm := FALSE, PositionM := CablePosM, ToleranceM := BenneSlipToleranceM);       // 🔧 REX 2026-07-08
END_IF;

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

// 🌐 BYPASS GLOBAL : si TRUE, on force ErrorId = 0 ET on saute toute la logique de sécurité
IF BypassGlobal THEN
    ErrorId := 16#0000;
    TonMecaB(IN := FALSE);
    TonMecaD(IN := FALSE);
    TonOppositeDirection(IN := FALSE);
    TonMecaE(IN := FALSE);
END_IF;

// 🔍 3sexties. FIN DE COURSE HAUT / CAPTEUR DE POSITION HAUTE (anti-débordement) — bit5
// ⚠️ Convention NAMING_CONVENTION.md : TopPositionSensor TRUE = sain/non atteint (NF), FALSE =
// position haute réellement atteinte (contact ouvert). Si la position haute EST atteinte
// (TopPositionSensor=FALSE), qu'on n'est pas en phase de référencement (homing), ET qu'on
// commande un mouvement vers le haut (Direction > 0), alors on lève le défaut.
// 🔧 REX 2026-08-07 (demande client, suite fix ForbidAscent/ForbidDescent) : SORTI du bloc
// "IF NOT BypassGlobal" ci-dessous — même doctrine que le blocage réel (§4) : BypassGlobal M1/M2
// ne doit masquer NI le mouvement NI l'alarme IHM de ces 2 fins de course physiques. Seuls
// BypassProcess (groupé, conscient) ou BypassTopLimitSwitch (individuel) peuvent encore éteindre
// CETTE alarme — exactement comme tous les autres bypass individuels du fichier (une alarme ne
// s'éteint QUE si on a explicitement demandé à ignorer CETTE protection précise, jamais via le
// bypass global qui vise le reste du domaine : Méca A-E, thermique, phase, comm, sync, codeur).
IF NOT (BypassProcess OR BypassTopLimitSwitch) AND NOT TopPositionSensor AND NOT InReferencingMode AND (Direction > 0) THEN
    ErrorId := ErrorId OR 16#0020;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFDF;
END_IF;

// 🔍 3septies. LONGUEUR MAX DE CÂBLE (profondeur max autorisée) — bit6
// Sécurité active hors référencement. Si la position de câble descend sous la limite basse
// physique (CablePosM <= CfgCableLimitDescentM), alors on interdit uniquement la descente.
// 🔧 REX 2026-08-07 : SORTI du bloc "IF NOT BypassGlobal" — même doctrine que bit5 ci-dessus.
IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode THEN
    ErrorId := ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFBF;
END_IF;

// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL (uniquement si bypass global désactivé)
IF NOT BypassGlobal THEN

    // ⏱️ Temporisation 3s de mise en route des bus de terrain au boot (CANopen / Modbus IHM)
    TonStartupWarmup(IN := Enable, PT := T#3s);

    IF TonStartupWarmup.Q AND NOT (BypassProcess OR BypassOperatorComm) THEN
        IF (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk) THEN
            ErrorId := ErrorId OR 16#0001;       // Perte communication opérateur : joystick CAN ou heartbeat IHM absent
        ELSE
            ErrorId := ErrorId AND 16#FFFE;      // Effacement auto si la com repasse saine
        END_IF;
    ELSIF NOT TonStartupWarmup.Q THEN
        ErrorId := ErrorId AND 16#FFFE;          // Inhibition pendant l'initialisation boot
    END_IF;
    IF ResetEdge.Q THEN
        ErrorId := ErrorId AND 16#FFFE;
    END_IF;

// 🔍 3bis. PERTE CODEUR DE CE TREUIL (câblé — lot Codeur 2026-07-02)
// 🔧 WINCH-CORE-01 : le fonctionnement sans codeur reste interdit par défaut.
// Le bypass est individuel, maintenu consciemment depuis l'IHM et strictement limité à MAINT_N2.
// Il ne masque aucun autre défaut du treuil et n'agit jamais sur l'autre instance.
EncoderAvailableEffective := EncoderAvailable
                             OR BypassGlobal
                             OR ((EncoderFaultBypass OR BypassProcess) AND (Mode = E_Mode.MAINT_N2));
IF NOT EncoderAvailableEffective THEN
    ErrorId := ErrorId OR 16#0002;
ELSE
    ErrorId := ErrorId AND 16#FFFD; (* Effacement auto si le codeur est dispo OU bypassé *)
END_IF;

// 🔍 3ter. SURCHAUFFE MOTEUR (câblé — I/O réel 2026-07-02) — bit2, participe au SafeStop total
// 🆕 2026-08-07 : ET BypassMotorThermal — même doctrine que BypassBrakeThermal (§3sexies-ter),
// bypass dédié plutôt que de dépendre uniquement du bypass groupé BypassSafety.
IF NOT (BypassSafety OR BypassMotorThermal) AND ThermalFeedback THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// 🔍 3quater. MOU DE CÂBLE (physiquement sur tambour M2, câblé sur les 2 instances Safety)
// Mode NORMAL (SyncEnable=TRUE) → SafeStop M1+M2 (bit3 inclus dans SafeStop)
// Mode RÉCUPÉRATION (SyncEnable=FALSE) → ForbidAscent uniquement (montée interdite, descente OK)
IF NOT BypassProcess AND SlackCableDetected THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q AND NOT SlackCableDetected THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🔍 3quinquies. ROTATION DE PHASE (câblé — I/O réel, commun M1/M2, 2026-07-03octodecies) —
// bit4, participe au SafeStop total (sens moteur potentiellement inversé, danger 2 sens).
IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
    ErrorId := ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFEF;
END_IF;

// 🔍 3octies. MÉCA A — MOUVEMENT NON COMMANDÉ GÉNÉRAL (REX 2026-07-07) — bit7
// Armé quand tout est physiquement confirmé coupé (contacteurs + frein). Si dérive ou vitesse
// détectée pendant que c'est armé → roue libre / frein insuffisant.
// 🔧 T84/T85 : la chaîne codeur produit la mesure ; ce bloc safety la surveille seulement.
DriftGuardA(
    Arm        := MeasuredSpeedValid AND FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND NOT InReferencingMode,
    PositionM  := CablePosM,
    ToleranceM := UncommandedDriftToleranceM
);
MecaADriftM := DriftGuardA.DriftM;   // 🆕 REX 2026-07-08 : diagnostic IHM

IF NOT (BypassSafety OR BypassMecaA) AND MeasuredSpeedValid AND (DriftGuardA.Violation OR (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND NOT InReferencingMode AND (MeasuredSpeedMps > UncommandedSpeedThresholdMps))) THEN
    ErrorId := ErrorId OR 16#0080;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FF7F;
END_IF;

// 🔍 3nonies. MÉCA B — PILOTAGE ACTIF SANS COMMANDE OPÉRATEUR (REX 2026-07-07) — bit8
// Indépendant de FB_Winch (défense en profondeur). Perte CAN (bit0) OU joystick au neutre ;
// si les contacteurs OU LE FREIN ne confirment pas être retombés/serrés dans PostRampTimeout, défaut.
// 🔧 REX 2026-07-08 (demande utilisateur) : BrakeFeedback ajouté — un frein qui ne confirme pas
// son engagement dans ce délai est tout aussi dangereux qu'un contacteur qui ne retombe pas
// (risque de mouvement/roue libre non détecté). Auparavant seul FwdRevSpeedFeedbackOff était vérifié.
MecaB_NoOperatorCmd := (NOT JoystickOnline) OR (NOT JoystickOperational)
                       OR (NOT HeartbeatIhmOk) OR JoystickYNeutral;
TonMecaB(IN := NOT (BypassSafety OR BypassMecaB) AND MecaB_NoOperatorCmd AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback), PT := PostRampTimeout);
MecaBElapsedTime := TonMecaB.ET;   // 🆕 REX 2026-07-08 : diagnostic IHM
IF TonMecaB.Q THEN
    ErrorId := ErrorId OR 16#0100;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FEFF;
END_IF;

// 🔍 3decies. MÉCA C — GLISSEMENT M1 PENDANT BENNE, ESCALADE (REX 2026-07-07) — bit9
// Armé UNIQUEMENT pour l'instance M1 (BenneHoldStillActive câblé sur instBucket.Busy côté M1
// seulement, toujours FALSE côté M2). Tolérance plus large que celle de FB_Bucket (1.0 m) —
// n'intervient que si la couche Benne (SafeStop M1 seul) n'a pas suffi.
// 🔧 REX 2026-07-08 : dérive factorisée via FB_DriftGuard (CODE/WINCH/) — comportement inchangé.
DriftGuardC(
    Arm        := NOT (BypassSafety OR BypassMecaC) AND BenneHoldStillActive,
    PositionM  := CablePosM,
    ToleranceM := BenneSlipToleranceM
);
MecaCDriftM := DriftGuardC.DriftM;   // 🆕 REX 2026-07-08 : diagnostic IHM

IF DriftGuardC.Violation THEN
    ErrorId := ErrorId OR 16#0200;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FDFF;
END_IF;

// 🔍 3undecies. THERMIQUE FREIN COMMUN M1/M2/M3 (REX 2026-07-08, demande utilisateur) — bit10
// Signal commun (1 seul fil, câblé identiquement sur les 3 instances Safety) : sa perte peut
// signifier qu'un frein colle instantanément (frein à manque de courant) → SafeStop ET
// PowerCutOff (voir bandeau en-tête).
IF NOT (BypassSafety OR BypassBrakeThermal) AND BrakeThermalFeedback THEN
    ErrorId := ErrorId OR 16#0400;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FBFF;
END_IF;

// 🔍 3duodecies. MÉCA D — ARRIVÉE CAPTEUR HAUT HORS RÉFÉRENCEMENT (REX 2026-07-08 (3),
// demande utilisateur) — bit11
// Complète le bit5 (ForbidAscent immédiat) : arme la MÊME condition (capteur haut atteint, hors
// homing) mais avec un délai de confirmation, comme Méca B. Si les contacteurs ET le frein ne
// confirment pas être retombés/serrés dans PostRampTimeout après l'arrivée au capteur → défaut
// → SafeStop ET PowerCutOff (la coupure ForbidAscent seule n'a visiblement pas suffi à arrêter
// réellement le treuil : roue libre ou contacteur/frein défaillant).
TonMecaD(
    IN := NOT (BypassSafety OR BypassMecaD) AND ((((NOT TopPositionSensor AND NOT InReferencingMode) 
            OR (Homed AND NOT HomingSuspect AND (CablePosM >= (TopLimitM + 0.10))))
           AND (Direction >= 0)) // 🆕 Neutralise la butée haute en descente (Direction = -1)
          AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)), 
    PT := PostRampTimeout
);
IF TonMecaD.Q THEN
    ErrorId := ErrorId OR 16#0800;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#F7FF;
END_IF;

// 🔍 3terdecies. MÉCA E — ÉCART SYNCHRO M1/M2 CRITIQUE (REX 2026-07-08 (4)) — bits 12/13
// Couche INDÉPENDANTE de FB_WinchSync (écart mineur, 1er niveau) — défense en profondeur pour un
// écart VRAIMENT important. ExpectedOtherWinchPosM est DÉJÀ corrigé de l'offset benne actif par
// l'appelant : comparaison directe valable que le benne soit ouvert, fermé, ou absent du calcul.
// Suppression pendant BenneBusy (trajet actif = écart transitoire normal, pas un défaut),
// InReferencingMode (position pas fiable pendant homing) et OtherWinchInhibited (🆕 REX
// 2026-07-08 (7) : l'autre treuil en maintenance a une position figée, non comparable).
// Bit12 : détection → SafeStop immédiat. Bit13 : escalade si pas confirmé arrêté → PowerCutOff.
IF NOT (BypassProcess OR BypassMecaE) AND SyncEnable AND NOT BenneBusy AND NOT InReferencingMode AND NOT OtherWinchInhibited
   AND (ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM) THEN
    ErrorId := ErrorId OR 16#1000;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#EFFF;
END_IF;

TonMecaE(IN := NOT (BypassSafety OR BypassMecaE) AND (((ErrorId AND 16#1000) <> 16#0000) AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)),
         PT := PostRampTimeout);
IF TonMecaE.Q THEN
    ErrorId := ErrorId OR 16#2000;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#DFFF;
END_IF;

// 🔍 3quaterdecies — SENS RÉEL OPPOSÉ À LA COMMANDE (bit14)
// Le signe de la vitesse câble est comparé à la direction commandée uniquement pendant un
// mouvement effectivement demandé. La temporisation filtre bruit codeur et inversion transitoire.
OppositeDirectionActive := NOT BypassProcess AND MeasuredSpeedValid AND (MovementCommanded AND NOT InReferencingMode
    AND (((Direction > 0) AND (MeasuredSpeedSignedMps < -MovementSpeedThresholdMps))
      OR ((Direction < 0) AND (MeasuredSpeedSignedMps > MovementSpeedThresholdMps))));
TonOppositeDirection(IN := OppositeDirectionActive, PT := OppositeDirectionTimeout);
IF TonOppositeDirection.Q THEN
    ErrorId := ErrorId OR 16#4000;
ELSIF ResetEdge.Q AND NOT OppositeDirectionActive THEN
    ErrorId := ErrorId AND 16#BFFF;
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
    ErrorId := ErrorId OR 16#8000;
ELSIF ResetEdge.Q AND (NOT MeasuredSpeedValid OR NOT MovementCommanded OR (ABS(MeasuredSpeedSignedMps) >= MovementSpeedThresholdMps)) THEN
    ErrorId := ErrorId AND 16#7FFF;
END_IF;

END_IF; // fin IF NOT BypassGlobal

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);       // 🧭 Partie3 §4 : miroir de TOUT le domaine, y compris mou de câble (visible IHM)
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🟧 SafeStop : bits 0/1/2/3/4 (joystick, codeur, thermique moteur, MOU CÂBLE, phases) + 7/8/9
// (Méca A/B/C) + 10 (thermique frein commun) + 11 (Méca D) + 12/13 (🆕 REX 2026-07-08 (4) :
// Méca E, écart synchro critique) ou si contacteur coupé
IF NOT PowerContactorEngaged THEN
    SafeStop := TRUE;
ELSIF NOT SyncEnable THEN
    SafeStop := (ErrorId AND 16#FF97) <> 16#0000;   // bit3 exclu → SafeStop normal sans mou câble
ELSE
    SafeStop := (ErrorId AND 16#FF9F) <> 16#0000;   // bit3 inclus → SafeStop complet avec mou câble
END_IF;

// ⬇️ ForbidDescent : bit6 uniquement (limite basse câble) ou si contacteur coupé (bypasser si BypassGlobal ou BypassCableLimitSwitch)
// 🆕 REX 2026-08-07 (demande client, audit confirmé) : terme INDÉPENDANT ajouté — check brut sur
// la limite basse physique (même condition que le calcul du bit6 ci-dessus §3septies, mais évalué
// HORS du bloc masqué par BypassGlobal), gardé UNIQUEMENT par BypassCableLimitSwitch. Même doctrine
// que le check brut ForbidAscent ci-dessous (déjà présent) : BypassGlobal M1/M2 continue de masquer
// Méca A-E/thermique/phase/comm/sync comme aujourd'hui, mais ne doit plus jamais désactiver l'arrêt
// physique sur fin de course haute/basse — sécurité positive, seul un bypass individuel conscient
// (BypassCableLimitSwitch) peut lever CETTE protection précise.
ForbidDescent := (((ErrorId AND 16#0040) <> 16#0000 OR NOT PowerContactorEngaged) AND NOT (BypassGlobal OR BypassCableLimitSwitch))
              OR (((CfgCableLimitDescentM < 0.0) AND (CablePosM <= CfgCableLimitDescentM) AND NOT InReferencingMode) AND NOT BypassCableLimitSwitch);

// ⬆️ ForbidAscent : bit5 (fin course haut) OU bit3+(NOT SyncEnable) (bypasser si BypassTopLimitSwitch)
// 🆕 REX 2026-07-08 : Sécurité positive maintenue si capteur haut physiquement activé hors référencement
// 🔧 REX 2026-08-07 (demande client, audit confirmé) : BypassGlobal RETIRÉ du ET final — la ligne
// "Sécurité positive maintenue" ci-dessus était contredite par l'ancien `AND NOT (BypassGlobal OR
// BypassTopLimitSwitch)` qui masquait quand même le check brut sous BypassGlobal M1/M2. Désormais
// seul BypassTopLimitSwitch (individuel, conscient) peut lever cette protection précise — le reste
// du domaine (Méca A-E/thermique/phase/comm/sync) reste masqué par BypassGlobal comme avant.
ForbidAscent := ((ErrorId AND 16#0020) <> 16#0000
             OR (NOT TopPositionSensor AND NOT InReferencingMode)
             OR ((ErrorId AND 16#0008) <> 16#0000 AND NOT SyncEnable))
             AND NOT BypassTopLimitSwitch;

// 🧨 REX 2026-07-07 : PowerCutOff enfin réel — bits 7/8/9 (Méca A/B/C, voir bandeau en-tête).
// Coupure puissance amont : les contacteurs locaux sont déjà confirmés coupés/insuffisants,
// SafeStop seul ne sert à rien dans ces 3 cas précis.
// 🆕 REX 2026-07-08 (demande utilisateur) : bit2 (surchauffe/perte thermique MOTEUR) et bit10
// (surchauffe/perte thermique FREIN commun) ajoutés — un frein à manque de courant peut coller
// instantanément sur perte de son retour thermique : une rampe SafeStop seule ne protège pas la
// mécanique dans ce cas, coupure puissance immédiate nécessaire. Même raisonnement appliqué au
// thermique moteur par cohérence/défense en profondeur (demande explicite).
// 🆕 REX 2026-07-08 (3) : bit11 (Méca D, capteur haut) ajouté — même raisonnement que Méca A/B :
// contacteurs/frein déjà censés être coupés (ForbidAscent immédiat sur capteur), une confirmation
// manquante après délai signifie que la coupure locale n'a pas suffi.
// 🆕 REX 2026-07-08 (4) : bit13 (Méca E escalade) ajouté — PAS bit12 seul (détection immédiate =
// SafeStop uniquement ; PowerCutOff seulement si l'arrêt n'est pas confirmé après délai).
PowerCutOff := (ErrorId AND 16#2F84) <> 16#0000;

// Busy, Done non utilisés mais présents pour conformité (comme FB_Diag_CanOpen)
Busy := FALSE;
Done := FALSE;
