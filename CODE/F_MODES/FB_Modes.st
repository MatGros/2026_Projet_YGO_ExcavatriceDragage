(* =======================================================================
   ⚙️ FB_Modes — Arbitrage du mode machine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Source unique du mode arbitré et calcul du bus d'autorisations
   🔒 Sécurité : Refus du mode Semi-Auto en cas de défaut codeur
   🔌 Interface : Standard composant d'arbitrage applicatif
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.0.md
                   DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md
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
END_VAR
VAR_OUTPUT
    // === ETATS & DIAGNOSTICS IEC ===
    Ready                   : BOOL;   // <-- [STAT] FB pret a fonctionner
    Busy                    : BOOL;   // <-- [STAT] FB en traitement
    Done                    : BOOL;   // <-- [STAT] Traitement termine
    Error                   : BOOL;   // <-- [DIAG] Defaut present
    ErrorId                 : WORD;   // <-- [DIAG] Code erreur (bit0=Semi-Auto refuse)
    State                   : E_State;// <-- [STAT] Etat courant du FB
    StateAtError            : E_State;// <-- [DIAG] Etat au moment du dernier defaut

    // === BUS D'AUTORISATIONS ARBITREES ===
    Auth                    : ST_Modes_Autorisations; // <-- [STAT] Bus d'autorisations typees machine
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    ResetEdge               : R_TRIG; // * [INST] Detecteur front montant Reset
    ErrorEdge               : R_TRIG; // * [INST] Detecteur front montant Error

    // === VARIABLES LOCALES & MEMOIRES ===
    PrevInhibitM1           : BOOL;   // . [LOC] Memoire etat inhibition M1 (exclusion mutuelle)
    PrevInhibitM2           : BOOL;   // . [LOC] Memoire etat inhibition M2 (exclusion mutuelle)
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate neutralisation"}
// 1. GATE — neutralisation si désactivé ou AU non armé
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Auth.Mode := E_Mode.DISABLE;
    Auth.SyncEnable := TRUE;
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal par défaut
    Auth.MaintenanceM3TargetEnable := FALSE;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    PrevInhibitM1 := FALSE;
    PrevInhibitM2 := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

{endregion}

{region "§2 Reset et arbitrage mode"}
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

{endregion}

{region "§3 Calcul autorisations machine"}
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
// M1 seul ou M2 seul autorisé en MAINT_N1 et MAINT_N2. Forcé à Couplé (=0) sinon.
IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
    Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;  // Couplé nominal forcé
END_IF;

// 5quinquies. CIBLE TRANSLATION MAINTENANCE
// MAINT_N2 ou MAINT_N1 + bit IHM dédié (SelMaintenanceZoneAccess) exigé EN PLUS
Auth.MaintenanceM3TargetEnable := ((Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1)) AND SelMaintenanceZoneAccess;

// GATE — désactivation inhibitions/sync si mode change (sortie N1/N2)
IF (Auth.Mode <> E_Mode.MAINT_N2) AND (Auth.Mode <> E_Mode.MAINT_N1) THEN
    Auth.InhibitM1 := FALSE;
    Auth.InhibitM2 := FALSE;
    Auth.HomingApproachEnable := FALSE;
    Auth.MaintenanceM3TargetEnable := FALSE;
    Auth.JoystickWinchSelectArbitrated := 0;
END_IF;

{endregion}

{region "§4 Etats et defauts"}
// 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

Busy := FALSE;
Done := FALSE;

{endregion}

END_FUNCTION_BLOCK
