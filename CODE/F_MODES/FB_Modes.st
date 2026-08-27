(* =======================================================================
   ⚙️ FB_Modes — Arbitrage du mode machine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Source unique du mode arbitré et calcul du bus d'autorisations
   🔒 Sécurité : Refus du mode Semi-Auto en cas de défaut codeur
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
END_VAR
VAR_OUTPUT
    // === ETATS & DIAGNOSTICS IEC ===
    Ready                   : BOOL;   // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                   : ST_Fault;

    // === BUS D'AUTORISATIONS ARBITREES ===
    Auth                    : ST_Modes_Autorisations; // <-- [STAT] Bus d'autorisations typees machine
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
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESET FRONT
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    SemiAutoRefusedFault := FALSE;
END_IF;

// Refus semi-auto si défaut codeur
IF (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    SemiAutoRefusedFault := TRUE;
END_IF;

instCauses[0].Active   := SemiAutoRefusedFault;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Mode Semi-Auto refuse car defaut codeur present';

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
    Ready := FALSE;
    PrevInhibitM1 := FALSE;
    PrevInhibitM2 := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Arbitrage du mode"}
// ⚙️ 3. ARBITRAGE DU MODE
IF (SelMode = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    Auth.Mode := E_Mode.MAINT_N1;
ELSE
    Auth.Mode := SelMode;
END_IF;
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
