(* =======================================================================
   ⚙️ FB_Modes — Arbitrage du mode machine
   ───────────────────────────────────────────────────────────────
    🎯 Rôle : Source unique du mode arbitré et calcul du bus d'autorisations
    🔒 Sécurité : Refus du mode Semi-Auto en cas de défaut codeur ou de re-homing requis ;
                  refus de toute bascule N1/N2/SEMI_AUTO tant que les treuils ne sont pas
                  à l'arrêt mécanique confirmé ; re-homing obligatoire après usage effectif
                  d'un override/bypass de position (AF-05 §4bis)
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
    ResetEdge               : R_TRIG; // * [INST] Detecteur front montant Reset

    // === GESTION DES DEFAUTS ===
    SemiAutoRefusedFault    : BOOL;   // . [LOC] Latch refus semi-auto
    instFault               : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées

    // === VARIABLES LOCALES & MEMOIRES ===
    PrevInhibitM1           : BOOL;   // . [LOC] Memoire etat inhibition M1 (exclusion mutuelle)
    PrevInhibitM2           : BOOL;   // . [LOC] Memoire etat inhibition M2 (exclusion mutuelle)

    // === MAINTENANCE : BASCULE DE MODE & RE-HOMING ===
    PrevArbitratedMode      : E_Mode; // . [LOC] Mode arbitré au scan précédent (maintien si bascule refusée)
    ModeChangeAllowed       : BOOL;   // . [LOC] Treuils à l'arrêt mécanique confirmé (condition de bascule)
    MaintHomingRequiredM1   : BOOL;   // . [LOC] M1 : re-homing obligatoire avant tout SEMI_AUTO
    MaintHomingRequiredM2   : BOOL;   // . [LOC] M2 : re-homing obligatoire avant tout SEMI_AUTO
    SemiAutoRefusedHoming   : BOOL;   // . [LOC] Latch refus semi-auto pour re-homing obligatoire
    SemiAutoRefusedMachineHoming : BOOL;   // . [LOC] Refus live : reference machine incomplete
    FirstScanDone           : BOOL;   // . [LOC] Initialisation premier scan (restauration PERSISTENT)
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESET FRONT
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    SemiAutoRefusedFault  := FALSE;
    SemiAutoRefusedHoming := FALSE;
END_IF;

// 🔑 1bis. RESTAURATION BOOT DES DRAPEAUX PERSISTANTS
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
//   1. pas de fenêtre d'un scan où SEMI_AUTO serait arbitré malgré un re-homing requis ;
//   2. pas de perte de l'obligation sur coupure / download pendant la maintenance
//      (la valeur est écrite dans le miroir PERSISTENT dès le scan courant, pas à la sortie).
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

// Refus semi-auto — une cause = un fait (AF03 §4) : défaut codeur et re-homing sont distincts.
IF (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    SemiAutoRefusedFault := TRUE;
END_IF;
IF (SelMode = E_Mode.SEMI_AUTO) AND (MaintHomingRequiredM1 OR MaintHomingRequiredM2) THEN
    SemiAutoRefusedHoming := TRUE;
END_IF;
SemiAutoRefusedMachineHoming := (SelMode = E_Mode.SEMI_AUTO) AND NOT MachineHomed;

instCauses[0].Active   := SemiAutoRefusedFault;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Mode Semi-Auto refuse car defaut codeur present';

instCauses[2].Active   := SemiAutoRefusedHoming;
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Mode Semi-Auto refuse car re-homing obligatoire (depassement de limite de position)';

instCauses[3].Active   := SemiAutoRefusedMachineHoming;
instCauses[3].Latching := FALSE;
instCauses[3].Texte    := 'Mode Semi-Auto refuse : referencement M1/M2/benne incomplet';

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
// 🛑 2. GATE — neutralisation si désactivé ou AU non armé
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Auth.Mode := E_Mode.DISABLE;
    Auth.SyncEnable := TRUE;
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal par défaut
    Auth.MaintenanceM3TargetEnable := FALSE;
    // Faits persistants : PUBLIÉS même neutralisé (l'IHM doit continuer à voir
    // qu'un re-homing est requis tant que la machine n'est pas réarmée). Aucune autorisation
    // n'est accordée ici : Auth.Mode := DISABLE verrouille tout le reste.
    Auth.ModeChangePendingBlocked := FALSE;
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

// 3.2 ARBITRAGE — priorité du refus de sécurité, puis du refus de bascule
IF (SelMode = E_Mode.SEMI_AUTO)
   AND (EncoderFaultPresent OR MaintHomingRequiredM1 OR MaintHomingRequiredM2 OR NOT MachineHomed) THEN
    // Défaut codeur ou re-homing obligatoire : SEMI_AUTO interdit, repli MAINT_N1.
    Auth.Mode := E_Mode.MAINT_N1;
    Auth.ModeChangePendingBlocked := FALSE;
ELSIF (SelMode <> PrevArbitratedMode)
      AND (SelMode <> E_Mode.DISABLE) AND (PrevArbitratedMode <> E_Mode.DISABLE)
      AND NOT ModeChangeAllowed THEN
    // Bascule N1/N2/SEMI_AUTO refusée : le mode courant est MAINTENU.
    // ⚠️ Exception de sécurité (contrat D2) : une transition vers ou depuis DISABLE n'est
    // JAMAIS bloquée — sortir d'un mode maintenance ne doit jamais dépendre d'un treuil à l'arrêt.
    Auth.Mode := PrevArbitratedMode;
    Auth.ModeChangePendingBlocked := TRUE;
ELSE
    Auth.Mode := SelMode;
    Auth.ModeChangePendingBlocked := FALSE;
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

// 4bis. EXCLUSION MUTUELLE INHIBITIONS + RESET SYNC ENABLE
IF InhibitM1Request AND NOT PrevInhibitM1 THEN
    IF PrevInhibitM2 THEN
        Auth.InhibitM1 := FALSE;
    ELSE
        Auth.InhibitM1 := TRUE;
        Auth.InhibitM2 := FALSE;
        SelSyncEnable := FALSE;
    END_IF;
ELSIF InhibitM2Request AND NOT PrevInhibitM2 THEN
    IF PrevInhibitM1 THEN
        Auth.InhibitM2 := FALSE;
    ELSE
        Auth.InhibitM2 := TRUE;
        Auth.InhibitM1 := FALSE;
        SelSyncEnable := FALSE;
    END_IF;
ELSE
    IF InhibitM1Request AND InhibitM2Request THEN
        Auth.InhibitM1 := FALSE;
        Auth.InhibitM2 := FALSE;
    END_IF;
END_IF;

PrevInhibitM1 := InhibitM1Request;
PrevInhibitM2 := InhibitM2Request;

Auth.InhibitM1 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM1;
Auth.InhibitM2 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM2;

// 4ter. AUTORISATION ARRÊT HAUT (HomingApproach)
Auth.HomingApproachEnable := (Auth.Mode = E_Mode.MAINT_N2) AND SelHomingApproachEnable;

// 4quater. SÉLECTEUR JOYSTICK TREUIL
IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
    Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal forcé
END_IF;

// 4quinquies. CIBLE TRANSLATION MAINTENANCE
Auth.MaintenanceM3TargetEnable := ((Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1)) AND SelMaintenanceZoneAccess;

// Re-vérification sécurité si sortie MAINT
IF (Auth.Mode <> E_Mode.MAINT_N2) AND (Auth.Mode <> E_Mode.MAINT_N1) THEN
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.MaintenanceM3TargetEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;
END_IF;
{endregion}

END_FUNCTION_BLOCK
