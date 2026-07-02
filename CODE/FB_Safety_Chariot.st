(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Chariot — Bloc safety MÉTIER du domaine Chariot (M3)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.2.md
                   (contrat : DOC/AF_Partie3_Template_FB_Commun_v1.2.md §1/§7bis)
   🔧 2026-07-02 : renommage métier Translation→Chariot (demande utilisateur).
      Préfixe I/O physique M3 inchangé (mapping matériel).
   🛡️ Interface STANDARD COMPLÈTE (Partie3 §1) : FB_Safety_<Metier> est
      un FB métier à part entière (pas une brique réduite).
   📤 Sortie maîtresse SafeStop_Chariot : consommée en entrée par
      FB_Chariot (M3).
   ⚠️ PÉRIMÈTRE MINIMAL DE CE LOT (même logique que FB_Safety_Winch,
      Partie9 §2 — premier lot testable) :
      - ✅ Détecte la perte joystick/CAN (sans commande valide, le
        chariot ne doit pas pouvoir bouger).
      - 🔴 TBD (non câblé, PAS simulé) : perte EtherCAT variateur AC600
        (VariateurAvailable de FB_DiagEthercat, non finalisé), défaut
        variateur détaillé (au-delà du simple DriveFaultFeedback TOR
        déjà géré dans FB_Chariot lui-même, bit3 ErrorId). Zone
        clairement marquée ci-dessous — à câbler quand FB_DiagEthercat
        AC600/M3 sera fiabilisé.
      - `PowerCutOff` : FALSE pour ce lot (pas encore de
        ST_ContactorCheck de puissance câblé — comme FB_Safety_Winch).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Safety_Chariot) ===

FUNCTION_BLOCK PUBLIC FB_Safety_Chariot
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    EmergencyStopOk     : BOOL;        // Chaîne AU réarmée + conditions globales OK (info de contexte)
    Mode                : E_Mode;      // Mode courant (autorisations)
    JoystickOnline      : BOOL;        // instDiagCanOpen.Joystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.Joystick.Operational
    // 🔴 TBD (EtherCAT AC600 non finalisé) : ajouter ici VariateurAvailable
    //     (FB_DiagEthercat AC600/M3) quand ce diag sera fiabilisé — ne PAS stubber en dur.
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : perte joystick/CAN (domaine chariot sans commande valide)
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Sortie maîtresse : rampe décélération RAPIDE (Enable maintenu)
    PowerCutOff         : BOOL;        // 🧨 Sortie maîtresse : coupure puissance amont (FALSE, TBD ce lot)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Chariot) ===

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

// 🔍 3. DIAGNOSTIC DU DOMAINE CHARIOT
IF NOT JoystickOnline OR NOT JoystickOperational THEN
    ErrorId := ErrorId OR 16#0001;       // Perte joystick/CAN : pas de commande opérateur valide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔴 TBD (EtherCAT AC600 non finalisé) : bit1 réservé perte EtherCAT variateur — NON câblé
// dans ce lot. Ne jamais mettre un stub qui masquerait un vrai défaut : laisser le bit à 0
// tant que la surveillance EtherCAT n'est pas fiabilisée revient à accepter ce risque, comme
// pour le codeur treuil (FB_Safety_Winch) — décision à revalider avec l'utilisateur avant
// mise en service réelle en mode ETHERCAT.

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SafeStop := Error;          // 🟧 Tout défaut du domaine → rampe décélération rapide (Enable maintenu)
PowerCutOff := FALSE;       // 🧨 TBD — pas de ST_ContactorCheck de puissance câblé dans ce lot

Busy := FALSE;
Done := FALSE;
