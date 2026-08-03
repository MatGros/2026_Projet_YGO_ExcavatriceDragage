(* ═══════════════════════════════════════════════════════════════
   🎚️ FB_Modes — Arbitrage du mode machine
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-05_Modes_Maintenance_v2.0.md
                   DOC/AF_Partie-03_Contrats_Composants_v2.0.md
   🔌 FB STANDARD : pas un FB de mouvement, pas de StartStop/SafeStop.
   🎯 Rôle : Source unique du mode arbitré + bus d'autorisations.
      - Arbitrage mode (DISABLE/N1/N2/SEMI_AUTO) + garde-fou codeur.
      - Calcul bus autorisations (SyncEnable, Inhibit, Sélection, Homing, Maintenance).
   🔒 Authentification : gérée côté IHM. FB_Modes accepte SelMode tel quel.
   ⚠️ EncoderFaultPresent consommé avec 1 cycle de retard (FB_Encoder_Safety appelé après).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION ===

FUNCTION_BLOCK PUBLIC FB_Modes
VAR_INPUT
    Enable              : BOOL;        // Active l'arbitrage
    Reset               : BOOL;        // Front acquittement défaut (bit0)
    PowerContactorEngaged : BOOL;      // Chaîne AU OK
    SelMode             : E_Mode;      // Sélecteur IHM (GVL_IHM.Modes.Cmd.SelMode)
    SelSyncEnable       : BOOL;        // Case IHM synchro (GVL_IHM.M1M2Sync.Cmd.SelSyncEnable)
    InhibitM1Request    : BOOL;        // Bouton IHM inhibition M1
    InhibitM2Request    : BOOL;        // Bouton IHM inhibition M2
    SelHomingApproachEnable : BOOL;    // Case IHM autorisant dépassement arrêt haut
    EncoderFaultPresent : BOOL;        // Défaut codeur (agrégat M1/M2, 1 cycle retard)
    JoystickWinchSelectRequest : INT;  // 1=M1, 2=M2, 3=Couplé (brut IHM)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Mode Semi-Auto refusé (Défaut Codeur)"
    State               : E_State;
    StateAtError        : E_State;
    Auth                : ST_Modes_Autorisations;  // Bus d'autorisations typé
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    PrevInhibitM1       : BOOL;  // Mémoire état inhibition M1 (exclusion mutuelle)
    PrevInhibitM2       : BOOL;  // Mémoire état inhibition M2 (exclusion mutuelle)
END_VAR

// === IMPLEMENTATION ===

// 1. GATE — neutralisation si désactivé ou AU non armé
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Auth.Mode := E_Mode.DISABLE;
    Auth.SyncEnable := TRUE;
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 3;  // Couplé par défaut
    Auth.MaintenanceM3TargetEnable := FALSE;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    PrevInhibitM1 := FALSE;
    PrevInhibitM2 := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 2. RESET FRONT (bit0 = défaut codeur)
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;  // Efface bit0 si front Reset
END_IF;

// 3. GARDE-FOU — refus SEMI_AUTO si défaut codeur
IF (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    ErrorId := ErrorId OR 16#0001;  // bit0 : défaut codeur
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 4. ARBITRAGE DU MODE
// MAINT_N2 accepté directement (authentification côté IHM).
IF (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    Auth.Mode := E_Mode.MAINT_N1;
ELSE
    Auth.Mode := SelMode;
END_IF;

// 5. SYNC ENABLE — actionnable en MAINT_N1 ou MAINT_N2
// FALSE (désactivé) seulement si en MAINT_N1/N2 ET case décochée ; TRUE partout ailleurs.
Auth.SyncEnable := NOT ((Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2) AND NOT SelSyncEnable);

// 5bis. EXCLUSION MUTUELLE INHIBITIONS + RESET SYNC ENABLE
// Inhibition M1/M2 mutuellement exclusives (soit l'un, soit l'autre, jamais les deux).
// Si les deux demandés simultanément : on garde celle déjà active, sinon on rejette les deux.
// Reset SelSyncEnable si une inhibition devient active (synchro incompatible avec inhibit).
// Mémorisation états précédents pour détection front montant.

// Détection fronts montants inhibitions
IF InhibitM1Request AND NOT PrevInhibitM1 THEN
    // Front montant M1
    IF PrevInhibitM2 THEN
        // M2 déjà actif → rejette M1
        Auth.InhibitM1 := FALSE;
    ELSE
        // M2 inactif → active M1, désactive M2
        Auth.InhibitM1 := TRUE;
        Auth.InhibitM2 := FALSE;
        // Synchro incompatible avec inhibition → reset case IHM
        SelSyncEnable := FALSE;
    END_IF;
ELSIF InhibitM2Request AND NOT PrevInhibitM2 THEN
    // Front montant M2
    IF PrevInhibitM1 THEN
        // M1 déjà actif → rejette M2
        Auth.InhibitM2 := FALSE;
    ELSE
        // M1 inactif → active M2, désactive M1
        Auth.InhibitM2 := TRUE;
        Auth.InhibitM1 := FALSE;
        SelSyncEnable := FALSE;
    END_IF;
ELSE
    // Pas de front montant → maintenir états actuels
    // Mais si les deux demandes sont TRUE sans front (cas synchrone sans transition)
    IF InhibitM1Request AND InhibitM2Request THEN
        // Les deux demandées simultanément sans transition : repli sécurité
        Auth.InhibitM1 := FALSE;
        Auth.InhibitM2 := FALSE;
    END_IF;
END_IF;

// Mise à jour mémoires pour prochaine détection front
PrevInhibitM1 := InhibitM1Request;
PrevInhibitM2 := InhibitM2Request;

// 5bis-bis. Sortie inhibitions effectives (calculées ci-dessus)
Auth.InhibitM1 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM1;
Auth.InhibitM2 := (Auth.Mode = E_Mode.MAINT_N2) AND Auth.InhibitM2;

// 5ter. AUTORISATION ARRÊT HAUT (HomingApproach)
// Uniquement actionnable en MAINT_N2.
Auth.HomingApproachEnable := (Auth.Mode = E_Mode.MAINT_N2) AND SelHomingApproachEnable;

// 5quater. SÉLECTEUR JOYSTICK TREUIL
// M1 seul ou M2 seul réservé au MAINT_N2. Forcé à Couplé (=3) sinon.
IF Auth.Mode = E_Mode.MAINT_N2 THEN
    Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSE
    Auth.JoystickWinchSelectArbitrated := 3;  // Couplé forcé
END_IF;

// 5quinquies. CIBLE TRANSLATION MAINTENANCE
// Autorisée uniquement en MAINT_N2. PRG_TRANSLATION_CFC consomme ce bit.
Auth.MaintenanceM3TargetEnable := (Auth.Mode = E_Mode.MAINT_N2);

// GATE — désactivation inhibitions/sync si mode change (sortie N2)
IF Auth.Mode <> E_Mode.MAINT_N2 THEN
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.MaintenanceM3TargetEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 3;
END_IF;

// 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

Busy := FALSE;
Done := FALSE;

END_FUNCTION_BLOCK