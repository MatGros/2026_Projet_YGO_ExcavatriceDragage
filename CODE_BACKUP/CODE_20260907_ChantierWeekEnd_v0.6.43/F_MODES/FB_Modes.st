(* =======================================================================
   ⚙️ FB_Modes — Arbitrage du mode machine
   ───────────────────────────────────────────────────────────────
    🎯 Rôle : Source unique du mode arbitré et calcul du bus d'autorisations
    🔒 Sécurité : La sélection de mode est découplée de l'autorisation de mouvement :
                  le mode suit la sélection IHM même sous AU, arrêt d'urgence ou défaut ; le
                  mouvement est coupé en aval par la chaîne AU physique (PowerContactorEngaged)
                  et les interlocks (FB_CycleSemiAuto, FB_Safety_Winch, FB_Winch). Bascule N1/N2/SEMI_AUTO
                  soumise à l'arrêt mécanique confirmé des treuils ; re-homing obligatoire après
                  usage effectif d'un override/bypass de position (AF-05 §4bis) — publié à l'IHM,
                  ne bloque pas la sélection mais le cycle.
    🔌 Interface : Standard composant d'arbitrage applicatif
    📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
                    DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md
    ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Modes
VAR_INPUT
    // === GESTION FB & AUTORISATIONS ===
    Enable                  : BOOL;   // --> [CMD] Autorisation generale FB (TRUE = active)
    Reset                   : BOOL;   // --> [CMD] Front acquittement defauts
    PowerContactorEngaged   : BOOL;   // --> [SAFE] Chaine AU OK (TRUE = armee)

    // === SELECTIONS IHM & COMMANDES MODES ===
    SelMode                 : E_Mode; // --> [CMD] Selecteur de mode IHM
    SelSyncEnable           : BOOL;   // --> [CMD] Selection synchro treuils IHM
    InhibitM1Request        : BOOL;   // --> [CMD] Demande inhibition treuil M1
    InhibitM2Request        : BOOL;   // --> [CMD] Demande inhibition treuil M2
    SelHomingApproachEnable : BOOL;   // --> [CMD] Selection approche homing IHM
    JoystickWinchSelectRequest : INT; // --> [CMD] Selection treuils joystick (0=Couple, 1=M1, 2=M2)
    SelMaintenanceZoneAccess: BOOL;   // --> [CMD] Autorisation acces zone maintenance M3

    // === SEQUENCEMENT AUTO BENNE EN COUPLE (T248) ===
    // En sel. operateur COUPLE (0), le sequenceur force temporairement le sel. a 2
    // (jog benne) pour amener la benne dans l'etat requis par le sens joystick, puis
    // repasse a 0 pour le mouvement couple. Meme sel. joystick, un seul mecanisme.
    CoupledBucketSeqEnable  : BOOL;   // --> [CFG] Toggle "gestion bucket auto" (Commun.Cfg)
    M3AtTremie              : BOOL;   // --> [SAFE] Chariot M3 arrete stable a la Tremie (FdC latche) -> selecteur FORCE a 2 (benne seule), jamais couple (REX MES 2026-09-04 : M1 descendu a la Tremie via sequence T248)
    AllowWinchMoveAtTremie  : BOOL;   // --> [CFG] T249 : autorisation CONSCIENTE (bouton IHM) leve la garde M3AtTremie -> couple (0) re-autorise a la Tremie
    JoystickPull            : BOOL;   // --> [HW] Manche tire (Y+, montee demandee)
    JoystickPush            : BOOL;   // --> [HW] Manche pousse (Y-, descente demandee)
    BucketIsOpen            : BOOL;   // --> [STAT] Benne ouverte (comparaison temps reel Delta)
    BucketIsClosed          : BOOL;   // --> [STAT] Benne fermee (comparaison temps reel Delta)

    // === RETOURS CAPTEURS & DIAGNOSTICS ===
    EncoderFaultPresent     : BOOL;   // --> [HW] Defaut codeur agrege (1 cycle retard)

    // === ARRÊT MÉCANIQUE CONFIRMÉ DES TREUILS (bascule de mode, AF-05 §4bis) ===
    // Même composite que l'armement Méca B (FB_Safety_Winch.st:247) : contacteurs retombés
    // ET frein serré, redondés par la mesure de vitesse.
    M1ContactorsReleased      : BOOL; // --> [HW] M1 : feedback retombée contacteurs
    M1BrakeIsOpen             : BOOL; // --> [HW] M1 : feedback frein ouvert
    M1SpeedAbsMps             : REAL; // --> [HW] M1 : vitesse absolue mesurée (m/s)
    M2ContactorsReleased      : BOOL; // --> [HW] M2 : feedback retombée contacteurs
    M2BrakeIsOpen             : BOOL; // --> [HW] M2 : feedback frein ouvert
    M2SpeedAbsMps             : REAL; // --> [HW] M2 : vitesse absolue mesurée (m/s)
    MovementSpeedThresholdMps : REAL := 0.02; // --> [CFG] Seuil « vitesse quasi nulle » (m/s)

    // === ÉTATS HOMING & USAGE EFFECTIF D'UN OVERRIDE/BYPASS DE POSITION ===
    M1HomingDone              : BOOL; // --> [HW] M1 : cycle de homing terminé
    M1Homed                   : BOOL; // --> [HW] M1 : treuil référencé
    M1HomingSuspect           : BOOL; // --> [HW] M1 : référencement suspect
    M2HomingDone              : BOOL; // --> [HW] M2 : cycle de homing terminé
    M2Homed                   : BOOL; // --> [HW] M2 : treuil référencé
    M2HomingSuspect           : BOOL; // --> [HW] M2 : référencement suspect
    M1PositionLimitOverridden : BOOL; // --> [CMD] M1 : limite de position levée (override N1 ou bypass N2 effectif)
    M2PositionLimitOverridden : BOOL; // --> [CMD] M2 : limite de position levée (override N1 ou bypass N2 effectif)
    MachineHomed     : BOOL; // --> [STAT] M1/M2 fiables et offset benne valide

    // === RESTAURATION BOOT DES DRAPEAUX PERSISTANTS ===
    BootHomingRequiredM1      : BOOL; // --> [CFG] M1 : valeur PERSISTENT relue au premier scan
    BootHomingRequiredM2      : BOOL; // --> [CFG] M2 : valeur PERSISTENT relue au premier scan
END_VAR
VAR_OUTPUT
    // === ETATS & DIAGNOSTICS IEC ===
    Ready                   : BOOL;   // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                   : ST_Fault;

    // === BUS D'AUTORISATIONS ARBITREES ===
    Auth                    : ST_Modes_Autorisations; // <-- [STAT] Bus public d'autorisations machine (NC-110)
END_VAR
VAR
    // === SOUS-INSTANCES FB ===

    // === GESTION DES DEFAUTS ===
    instFault               : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées

    // === VARIABLES LOCALES & MEMOIRES ===
    PrevInhibitM1           : BOOL;   // . [LOC] Memoire front bouton inhibition M1 (détection front montant, toggle)
    PrevInhibitM2           : BOOL;   // . [LOC] Memoire front bouton inhibition M2 (détection front montant, toggle)

    // === MAINTENANCE : BASCULE DE MODE & RE-HOMING ===
    PrevArbitratedMode      : E_Mode; // . [LOC] Mode arbitré au scan précédent (maintien si bascule refusée)
    ModeChangeAllowed       : BOOL;   // . [LOC] Treuils à l'arrêt mécanique confirmé (condition de bascule)
    ModeChangeBlockReason   : STRING(40); // . [LOC] Motif du blocage de bascule (texte IHM court)
    MaintHomingRequiredM1   : BOOL;   // . [LOC] M1 : re-homing obligatoire avant tout SEMI_AUTO
    MaintHomingRequiredM2   : BOOL;   // . [LOC] M2 : re-homing obligatoire avant tout SEMI_AUTO
    SemiAutoCycleNotReadyFault        : BOOL;   // . [LOC] Diag live : SEMI_AUTO sélectionné mais défaut codeur (cycle non prêt)
    SemiAutoCycleNotReadyHoming       : BOOL;   // . [LOC] Diag live : SEMI_AUTO sélectionné mais re-homing requis (cycle non prêt)
    SemiAutoCycleNotReadyMachineHoming : BOOL;  // . [LOC] Diag live : SEMI_AUTO sélectionné mais référencement incomplet (cycle non prêt)
    FirstScanDone           : BOOL;   // . [LOC] Initialisation premier scan (restauration PERSISTENT)
    BucketSeqSatisfied      : BOOL;   // . [LOC] T248 : benne amenee dans l'etat requis pour ce maintien joystick -> VERROU de phase couple jusqu'au relachement confirme (la perte d'etat en mouvement ne relance rien)
    TonJoyNeutralT248       : TON;    // . [LOC] T248 : manche au neutre CONFIRME (>200 ms) avant d'effacer le verrou de phase (anti-blip)
    TonWinchSelSettle       : TON;    // . [LOC] T248 : arret CONFIRME des 2 treuils avant de lever le hold de transition
    WinchSelPrevT248        : INT;    // . [LOC] T248 : selecteur arbitre du scan precedent (detection de changement)
    WinchSelChangedT248     : BOOL;   // . [LOC] T248 : le selecteur arbitre a change ce scan -> relance la pause fixe
END_VAR
VAR CONSTANT
    CST_T248JoyNeutralConfirm : TIME := T#200ms;  // T248 : duree neutre pour relacher le verrou de phase
    // T248 : pause fixe apres bascule du selecteur jog<->couple. DOIT couvrir le
    // dead-time D18 du treuil qui vient de s'arreter (FB_WinchDirectionInterlock,
    // DirectionInterlockDelayAscent/Descent) + retombee/settle contacteurs, sinon
    // l'autre treuil (immobile depuis longtemps, dispo immediatement) part SEUL ->
    // decalage tambours (REX MES 2026-09-04 : M1 seul 63 cm, ecart final 50 cm).
    CST_T248TransitionSettle  : TIME := T#1s200ms; // MES 2026-09-04 : reduit de 2s (validation initiale) -> plancher = delai D18 montee (900ms) + marge ~300ms
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESTAURATION BOOT DES DRAPEAUX PERSISTANTS
// Non-RETAIN -> réinitialisé à chaque warm/cold reset ; relu depuis GVL_PERSISTENT (miroir
// réécrit chaque scan par PRG_03). Aucune perte du re-homing obligatoire sur coupure.
IF NOT FirstScanDone THEN
    FirstScanDone         := TRUE;
    MaintHomingRequiredM1 := BootHomingRequiredM1;
    MaintHomingRequiredM2 := BootHomingRequiredM2;
    PrevArbitratedMode    := E_Mode.DISABLE;
END_IF;

// 🔑 1ter. RE-HOMING OBLIGATOIRE — ARMEMENT IMMÉDIAT (AF-05 §4bis)
// Armé AVANT l'arbitrage de mode (§3) et non à la sortie du mode maintenance :
//   1. pas de fenêtre d'un scan où le re-homing serait perdu malgré un override effectif ;
//   2. pas de perte de l'obligation sur coupure / download pendant la maintenance
//      (la valeur est écrite dans le miroir PERSISTENT dès le scan courant, pas à la sortie).
// Le re-homing ne bloque PAS la sélection SEMI_AUTO : il est publié à l'IHM
// (Auth.HomingRequiredM1/M2) et le cycle ne progresse pas tant qu'il n'est pas levé.
IF M1PositionLimitOverridden THEN
    MaintHomingRequiredM1 := TRUE;
END_IF;
IF M2PositionLimitOverridden THEN
    MaintHomingRequiredM2 := TRUE;
END_IF;

// Levée : UNIQUEMENT sur cycle de homing complet réussi (Done + Homed + non suspect).
IF MaintHomingRequiredM1 AND M1HomingDone AND M1Homed AND NOT M1HomingSuspect THEN
    MaintHomingRequiredM1 := FALSE;
END_IF;
IF MaintHomingRequiredM2 AND M2HomingDone AND M2Homed AND NOT M2HomingSuspect THEN
    MaintHomingRequiredM2 := FALSE;
END_IF;

// Diagnostic « cycle non prêt » — le mode SEMI_AUTO reste sélectionnable mais le
// cycle ne tournera pas tant que ces conditions ne sont pas saines. Info NON-bloquante :
// la sélection n'est pas refusée, le mouvement est coupé en aval (FB_CycleSemiAuto/FB_Safety_Winch).
// Une cause = un fait (AF03 §4) : défaut codeur, re-homing et référencement sont distincts.
SemiAutoCycleNotReadyFault         := (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent;
SemiAutoCycleNotReadyHoming        := (SelMode = E_Mode.SEMI_AUTO) AND (MaintHomingRequiredM1 OR MaintHomingRequiredM2);
SemiAutoCycleNotReadyMachineHoming := (SelMode = E_Mode.SEMI_AUTO) AND NOT MachineHomed;

instCauses[0].Active   := SemiAutoCycleNotReadyFault;
instCauses[0].Latching := FALSE;
instCauses[0].Texte    := 'Mode Semi-Auto selectionne mais cycle non pret : defaut codeur present';

instCauses[2].Active   := SemiAutoCycleNotReadyHoming;
instCauses[2].Latching := FALSE;
instCauses[2].Texte    := 'Semi-Auto selectionne : re-homing obligatoire';

instCauses[3].Active   := SemiAutoCycleNotReadyMachineHoming;
instCauses[3].Latching := FALSE;
instCauses[3].Texte    := 'Semi-Auto selectionne : referencement incomplet';

// Cause 1 — changement de mode refusé : treuils non à l'arrêt mécanique confirmé.
// Non latchée (live) : l'information disparaît dès que la condition redevient vraie, sans
// acquittement — c'est une consigne d'action IHM (« arrêter les treuils »), pas un défaut machine.
// 📌 Lag 1 scan assumé : la cause est évaluée avant l'arbitrage §3 du cycle courant.
instCauses[1].Active   := Auth.ModeChangePendingBlocked;
instCauses[1].Latching := FALSE;
instCauses[1].Texte    := 'Changement de mode refuse : arreter les treuils avant de changer de mode';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE — neutralisation si désactivé (l'arbitrage de mode reste actif même AU non armé :
//    homing, réarmement défaut. Aucune autorisation de mouvement n'est accordée sans la chaîne
//    AU physique : chaque FB de mouvement garde son propre gate PowerContactorEngaged.)
IF NOT Enable THEN
    Auth.Mode := E_Mode.DISABLE;
    Auth.SyncEnable := TRUE;
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal par défaut
    Auth.CoupledBucketPhaseLocked := FALSE;
    Auth.WinchSelTransitionHold := FALSE;
    BucketSeqSatisfied := FALSE;
    Auth.MaintenanceM3TargetEnable := FALSE;
    // Faits persistants : PUBLIÉS même neutralisé (l'IHM doit continuer à voir
    // qu'un re-homing est requis tant que la machine n'est pas réarmée). Aucune autorisation
    // n'est accordée ici : Auth.Mode := DISABLE verrouille tout le reste.
    Auth.ModeChangePendingBlocked := FALSE;
    Auth.ModeChangeBlockReason := '';
    Auth.HomingRequiredM1 := MaintHomingRequiredM1;
    Auth.HomingRequiredM2 := MaintHomingRequiredM2;
    PrevArbitratedMode := Auth.Mode;
    Ready := FALSE;
    PrevInhibitM1 := FALSE;
    PrevInhibitM2 := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Arbitrage du mode"}
// ⚙️ 3. ARBITRAGE DU MODE

// 3.1 ARRÊT MÉCANIQUE CONFIRMÉ DES DEUX TREUILS (condition de bascule, AF-05 §4bis)
// Même composite que l'armement Méca B : contacteurs retombés + frein serré, redondé par
// la mesure absolue de vitesse. Vaut pour les DEUX treuils (M1 ET M2).
ModeChangeAllowed := M1ContactorsReleased AND NOT M1BrakeIsOpen
                     AND (ABS(M1SpeedAbsMps) < MovementSpeedThresholdMps)
                     AND M2ContactorsReleased AND NOT M2BrakeIsOpen
                     AND (ABS(M2SpeedAbsMps) < MovementSpeedThresholdMps);

// Détail des 6 sous-conditions (diagnostic IHM) — TRUE = condition satisfaite.
// Permet à l'opérateur de voir EXACTEMENT ce qui bloque la bascule de mode.
Auth.M1ContactorsReleased := M1ContactorsReleased;
Auth.M1BrakeApplied       := NOT M1BrakeIsOpen;
Auth.M1SpeedLow           := ABS(M1SpeedAbsMps) < MovementSpeedThresholdMps;
Auth.M2ContactorsReleased := M2ContactorsReleased;
Auth.M2BrakeApplied       := NOT M2BrakeIsOpen;
Auth.M2SpeedLow           := ABS(M2SpeedAbsMps) < MovementSpeedThresholdMps;

// 3.2 ARBITRAGE — le mode suit la sélection IHM (découplé de l'AU/défaut)
// La sélection de mode n'est JAMAIS bloquée par l'AU, l'arrêt d'urgence ou un défaut :
// le mode est un état de sélection, le mouvement est coupé en aval (FB_CycleSemiAuto, FB_Safety_Winch,
// FB_Winch) par PowerContactorEngaged et les interlocks. Seule la bascule N1/N2/SEMI_AUTO
// reste soumise à l'arrêt mécanique confirmé des treuils (ModeChangeAllowed).
// 3.2bis (AF-05 §4bis - referencement benne guide) : SEMI_AUTO est un mode "homed-only".
// Une selection SEMI_AUTO sans datum machine valide (MachineHomed) est REFUSEE et le mode
// est force vers MAINT_N1 (expulsion). Vaut aussi si MachineHomed retombe alors qu'on EST
// en SEMI_AUTO (perte de datum -> bascule MAINT_N1). Le SafeStop des treuils sur perte de
// datum en mouvement est assure en aval (PRG_04 via MachineHoming.HomingLoss). L'expulsion
// n'est jamais bloquee par l'arret mecanique (comme la sortie DISABLE, contrat D2).
IF (SelMode = E_Mode.SEMI_AUTO) AND NOT MachineHomed THEN
    Auth.Mode := E_Mode.MAINT_N1;
    Auth.ModeChangePendingBlocked := TRUE;
    // Motif distinct : perte de datum EN cours de SEMI_AUTO (arret controle assure en
    // aval par MachineHoming.HomingLoss si les treuils bougeaient) vs simple selection
    // refusee. Aucune coupure de puissance, aucun redemarrage automatique.
    IF PrevArbitratedMode = E_Mode.SEMI_AUTO THEN
        Auth.ModeChangeBlockReason := 'Datum machine perdu : arret controle';
    ELSE
        Auth.ModeChangeBlockReason := 'SEMI_AUTO refuse : datum machine absent';
    END_IF;
ELSIF (SelMode <> PrevArbitratedMode)
      AND (SelMode <> E_Mode.DISABLE) AND (PrevArbitratedMode <> E_Mode.DISABLE)
      AND NOT ModeChangeAllowed THEN
    // Bascule N1/N2/SEMI_AUTO refusée : le mode courant est MAINTENU.
    // ⚠️ Exception de sécurité (contrat D2) : une transition vers ou depuis DISABLE n'est
    // JAMAIS bloquée — sortir d'un mode maintenance ne doit jamais dépendre d'un treuil à l'arrêt.
    Auth.Mode := PrevArbitratedMode;
    Auth.ModeChangePendingBlocked := TRUE;
    // Motif du blocage (texte IHM court) — première condition échouée, ordre M1 puis M2.
    IF NOT M1ContactorsReleased THEN
        ModeChangeBlockReason := 'Chgt mode refuse : contacteur M1';
    ELSIF M1BrakeIsOpen THEN
        ModeChangeBlockReason := 'Chgt mode refuse : frein M1';
    ELSIF ABS(M1SpeedAbsMps) >= MovementSpeedThresholdMps THEN
        ModeChangeBlockReason := 'Chgt mode refuse : M1 en mvt';
    ELSIF NOT M2ContactorsReleased THEN
        ModeChangeBlockReason := 'Chgt mode refuse : contacteur M2';
    ELSIF M2BrakeIsOpen THEN
        ModeChangeBlockReason := 'Chgt mode refuse : frein M2';
    ELSIF ABS(M2SpeedAbsMps) >= MovementSpeedThresholdMps THEN
        ModeChangeBlockReason := 'Chgt mode refuse : M2 en mvt';
    ELSE
        ModeChangeBlockReason := '';
    END_IF;
    Auth.ModeChangeBlockReason := ModeChangeBlockReason;
ELSE
    Auth.Mode := SelMode;
    Auth.ModeChangePendingBlocked := FALSE;
    Auth.ModeChangeBlockReason := '';
END_IF;

PrevArbitratedMode := Auth.Mode;
{endregion}

{region "§3bis Publication du re-homing obligatoire"}
// 🧭 3bis. PUBLICATION DU RE-HOMING OBLIGATOIRE
// Armement et levée réalisés en §1ter, AVANT l'arbitrage de mode — voir le commentaire §1ter
// (pas de fenêtre d'un scan, pas de perte sur coupure en cours de maintenance).
Auth.HomingRequiredM1 := MaintHomingRequiredM1;
Auth.HomingRequiredM2 := MaintHomingRequiredM2;
{endregion}

{region "§4 Calcul autorisations machine"}
// 4. SYNC ENABLE — actionnable en MAINT_N1 ou MAINT_N2
// FALSE (désactivé) seulement si en MAINT_N1/N2 ET case décochée ; TRUE partout ailleurs.
Auth.SyncEnable := NOT ((Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2) AND NOT SelSyncEnable);

// 4bis. TOGGLE INHIBITIONS + EXCLUSION MUTUELLE + RESET SYNC ENABLE
// Chaque bouton est un TOGGLE (écran tactile simple, pas d'appui simultané possible) :
//   - front montant d'un bouton dont le treuil n'est PAS inhibé  -> pose l'inhibition
//     et lève l'autre (exclusion mutuelle), coupe la synchro.
//   - front montant d'un bouton dont le treuil EST déjà inhibé   -> lève l'inhibition
//     (retour à l'état normal), sans toucher à l'autre ni à la synchro.
IF InhibitM1Request AND NOT PrevInhibitM1 THEN
    IF Auth.InhibitM1 THEN
        // M1 déjà inhibé -> lever (toggle off)
        Auth.InhibitM1 := FALSE;
    ELSE
        // inhiber M1, lever M2 (exclusion mutuelle)
        Auth.InhibitM1 := TRUE;
        Auth.InhibitM2 := FALSE;
        SelSyncEnable := FALSE;
    END_IF;
ELSIF InhibitM2Request AND NOT PrevInhibitM2 THEN
    IF Auth.InhibitM2 THEN
        // M2 déjà inhibé -> lever (toggle off)
        Auth.InhibitM2 := FALSE;
    ELSE
        // inhiber M2, lever M1 (exclusion mutuelle)
        Auth.InhibitM2 := TRUE;
        Auth.InhibitM1 := FALSE;
        SelSyncEnable := FALSE;
    END_IF;
END_IF;

PrevInhibitM1 := InhibitM1Request;
PrevInhibitM2 := InhibitM2Request;

Auth.InhibitM1 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM1;
Auth.InhibitM2 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM2;

// 4ter. AUTORISATION ARRÊT HAUT (HomingApproach)
Auth.HomingApproachEnable := (Auth.Mode = E_Mode.MAINT_N2) AND SelHomingApproachEnable;

// 4quater. SÉLECTEUR JOYSTICK TREUIL
// T248 — Gestion bucket auto : en sél. opérateur COUPLÉ (0) + toggle actif, le sens
// joystick impose d'abord l'état benne requis en forçant le sél. à 2 (jog benne),
// puis retour à 0 pour le mouvement couplé. Un seul mécanisme = le sélecteur réel.
//   manche tiré (montée)  + benne pas fermée -> 2 (ferme), puis 0 (remonte couplé)
//   manche poussé (descente) + benne pas ouverte -> 2 (ouvre), puis 0 (descend couplé)
// BucketSeqSatisfied verrouille le retour à 0 jusqu'au relâchement joystick -> pas de
// va-et-vient du sélecteur au bord de la bande de détection.
// VERROU DE PHASE : n'est effacé que par un manche au neutre CONFIRMÉ (>200 ms) -> un
// passage bref par le neutre (ajustement de prise, dip sous deadzone) NE relance PAS la
// correction benne. Hors maintenance : effacement immédiat.
TonJoyNeutralT248(IN := NOT (JoystickPull OR JoystickPush), PT := CST_T248JoyNeutralConfirm);
IF TonJoyNeutralT248.Q THEN
    BucketSeqSatisfied := FALSE;
END_IF;

Auth.CoupledBucketPhaseLocked := FALSE;

IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
    // GARDE Tremie (MAINT uniquement -- ne doit PAS interferer avec SEMI_AUTO/cycle auto,
    // qui pilote la benne via ReqProgram.ReqBucket, pas ce selecteur) : a la Tremie, seul
    // le pilotage benne (WinchSel=2) est permis - le couple (0) ne doit JAMAIS s'y engager
    // manuellement, meme via T248 (BucketSeqSatisfied pouvait se lever a tort si la benne
    // etait deja ouverte d'une action precedente -> bascule 0 -> tentative descente couplee
    // -> M1 a bouge a la Tremie, REX MES 2026-09-04). Echappatoire consciente : bit IHM
    // AllowWinchMoveAtTremie (T249) leve la garde -> retour au comportement T248 normal.
    IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
        Auth.JoystickWinchSelectArbitrated := 2;
        BucketSeqSatisfied := FALSE;
    ELSIF CoupledBucketSeqEnable
       AND (JoystickWinchSelectRequest = 0)
       AND (JoystickPull XOR JoystickPush) THEN
        // TOUTE la séquence T248 (jog ET couplé) "possède" la benne : elle est pilotée
        // par le jog WinchSel=2, jamais par instBucket. -> on inhibe pour toute la durée
        // l'armement dive-open/ascent-close de FB_BucketCmdArbitration : plus de blip
        // instBucket.Lifecycle.Busy sur la bascule 2->0 -> plus de perte du deadman via
        // ArmBucketBusy (PRG_04), plus de blocage/correction sur l'état benne temps réel.
        Auth.CoupledBucketPhaseLocked := TRUE;
        // SET du verrou de phase dès que la benne est dans l'état requis par le sens.
        IF (JoystickPull AND BucketIsClosed) OR (JoystickPush AND BucketIsOpen) THEN
            BucketSeqSatisfied := TRUE;
        END_IF;
        IF BucketSeqSatisfied THEN
            Auth.JoystickWinchSelectArbitrated := 0;   // phase COUPLÉE : on ne recorrige
                                                       // plus la benne, perte d'état ignorée.
        ELSE
            Auth.JoystickWinchSelectArbitrated := 2;   // phase JOG : amener la benne dans l'état
        END_IF;
    ELSE
        Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
    END_IF;
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal forcé
    BucketSeqSatisfied := FALSE;
END_IF;

// HOLD DE TRANSITION : à chaque changement du sélecteur arbitré (jog<->couplé), on force
// l'arrêt des requêtes M1/M2 (PRG_04) pendant une PAUSE FIXE de 300 ms -> pas de hand-off
// en mouvement, redémarrage rampé. Dwell fixe (pas de condition vitesse) : auto-libéré,
// impossible à bloquer, aucun retour au neutre requis. Le verrou de phase empêche le
// sélecteur d'osciller, donc au plus une pause par changement franc.
WinchSelChangedT248 := (Auth.JoystickWinchSelectArbitrated <> WinchSelPrevT248);
WinchSelPrevT248 := Auth.JoystickWinchSelectArbitrated;
TonWinchSelSettle(IN := NOT WinchSelChangedT248, PT := CST_T248TransitionSettle);
Auth.WinchSelTransitionHold := NOT TonWinchSelSettle.Q;

// 4quinquies. CIBLE TRANSLATION MAINTENANCE
Auth.MaintenanceM3TargetEnable := ((Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1)) AND SelMaintenanceZoneAccess;

// Re-vérification sécurité si sortie MAINT
IF (Auth.Mode <> E_Mode.MAINT_N2) AND (Auth.Mode <> E_Mode.MAINT_N1) THEN
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.MaintenanceM3TargetEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;
    BucketSeqSatisfied := FALSE;
    Auth.CoupledBucketPhaseLocked := FALSE;
    Auth.WinchSelTransitionHold := FALSE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
