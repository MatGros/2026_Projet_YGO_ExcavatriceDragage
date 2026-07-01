(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Winch — Bloc safety MÉTIER du domaine Treuils (M1/M2)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
                   (contrat : DOC/AF_Partie3_Template_FB_Commun_v1.2.md §1/§7bis)
   🛡️ Interface STANDARD COMPLÈTE (Partie3 §1) : FB_Safety_<Metier> est
      un FB métier à part entière (pas une brique réduite).
   📤 Sortie maîtresse SafeStop_Winch : consommée en entrée par TOUT
      FB de mouvement du domaine treuil (FB_Winch M1, M2 plus tard).
   ⚠️ PÉRIMÈTRE MINIMAL DE CE LOT (créé pour tester la chaîne
      Joystick→Winch→Relais en Maintenance N1, sans dépendance codeur) :
      - ✅ Détecte la perte joystick/CAN (sans commande valide, un
        treuil ne doit pas pouvoir bouger).
      - 🔴 TBD (codeur non finalisé, PAS simulé) : perte codeur M1/M2,
        perte bus EtherCAT du treuil concerné. Zones clairement
        marquées ci-dessous — à câbler quand FB_Encoder_Abs/Safety et
        FB_DiagEthercat seront fiabilisés pour ce domaine.
      - `PowerCutOff` : FALSE pour ce lot (pas encore de
        ST_ContactorCheck de puissance câblé — FB_Output_Relay
        transverse hors périmètre de ce lot, voir Partie6).
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
    // 🔴 TBD (codeur non finalisé) : ajouter ici EncoderM1Available / EncoderM1EtherCatOk
    //     quand FB_Encoder_Abs/Safety M1 seront fiabilisés — ne PAS stubber en dur.
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : perte joystick/CAN (domaine treuil sans commande valide)
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Sortie maîtresse : rampe décélération RAPIDE (Enable maintenu)
    PowerCutOff         : BOOL;        // 🧨 Sortie maîtresse : coupure puissance amont (FALSE, TBD ce lot)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

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

// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL
IF NOT JoystickOnline OR NOT JoystickOperational THEN
    ErrorId := ErrorId OR 16#0001;       // Perte joystick/CAN : pas de commande opérateur valide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔴 TBD (codeur non finalisé) : bit1 réservé perte codeur/EtherCAT M1 — NON câblé dans ce lot.
// Ne jamais mettre un stub qui masquerait un vrai défaut : laisser le bit à 0 tant que la
// surveillance codeur n'est pas fiabilisée revient à accepter ce risque en Maintenance N1
// (cohérent avec le choix de test réduit validé avec l'utilisateur).

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SafeStop := Error;          // 🟧 Tout défaut du domaine → rampe décélération rapide (Enable maintenu)
PowerCutOff := FALSE;       // 🧨 TBD — pas de ST_ContactorCheck de puissance câblé dans ce lot

// Busy, Done non utilisés mais présents pour conformité (comme FB_DiagCanOpen)
Busy := FALSE;
Done := FALSE;
