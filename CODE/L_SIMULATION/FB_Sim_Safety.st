(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Safety — Simulation de la chaîne d'AU et du contacteur de puissance
   ───────────────────────────────────────────────────────────────
   📥 Enable            : activation de la simulation (SimulationModeActive AND NOT SensorEmergencyStopChainIsReal)
   📥 SimChainOkBit     : bit opérateur — TRUE = simuler la chaîne AU fermée ; FALSE = chaîne ouverte (non simulée)
   📥 PowerCutOff_A     : demande de coupure PLC canal A (TRUE = OK/fermé) — conservé pour interface, non utilisé par SimChainOk
   📥 PowerCutOff_B     : demande de coupure PLC canal B (TRUE = OK/fermé) — conservé pour interface, non utilisé par SimChainOk
   📥 PowerCutOffRequest: requête de coupure métier (PowerCutOffRequest du FB AU) — TRUE = arrêt d'urgence (chaîne ouverte)
   📥 EmergencyArming   : impulsion de réarmement (EmergencyArming_RQ)
   📥 BtnEmergencyStop   : appui coup-de-poing AU (TRUE = boucle ouverte)
   📥 TestCutActive     : test de redondance en cours (canal A ou B coupé par le FB AU)

   📤 SimChainOk        : simulation de la boucle AU (fermée si SimChainOkBit, ouverte sur coup-de-poing/test/coupure)
   📤 SimContactorOk    : simulation du contacteur engagé (PowerContactorEngaged)

   ⚙️ MÉCANISME GRANULAIRE (contrôle opérateur de la chaîne AU) :
      - `SimChainOkBit` pilote la chaîne : FALSE → chaîne OUVERTE (on ne peut pas armer) ;
        TRUE → chaîne FERMÉE (le bouton Armable s'active, on arme, la séquence teste les sorties).
      - Pendant le test de redondance (TestCutActive), la chaîne CLIGNOTE (s'ouvre pendant TEST_A/B,
        se referme pendant RESTORE_A/B) puis revient à 1 — comme en réel.
      - `PowerCutOffRequest` (coupure métier) ouvre la chaîne → ARRÊT D'URGENCE.
      - `BtnEmergencyStop` (coup-de-poing) ouvre la chaîne.
      - Le contacteur ne s'engage QUE pendant l'impulsion d'armement (EmergencyArming), avec une
        temporisation d'engagement (CST_ContactorEngageDelay), puis s'auto-maintient tant que la
        chaîne est saine ; il retombe (CST_ContactorDropDelay) dès que la chaîne s'ouvre.
      - À la ré-entrée en simulation (Enable FALSE→TRUE), SimChainOkBit = FALSE → chaîne OUVERTE et
        contacteur NON engagé (on n'a pas armé) — pas de faux « OK » immédiat.

   🔒 NON-RÉGRESSION ARMEMENT (dépendance circulaire) :
      - La chaîne n'est PAS fermée par défaut : elle est fermée UNIQUEMENT si l'opérateur pose
        `SimChainOkBit`. Elle ne dépend PAS de PowerCutOff_A/B (qui sont dans le cercle) : le
        réarmement après échec de test de redondance (RedundancyTestFailedCause laté → PowerCutOff_A=FALSE)
        reste possible car la chaîne est maintenue fermée par le bit opérateur, pas par le PLC.
      - L'ouverture « PLC coupe un canal » est représentée par TestCutActive (test redondance) et
        PowerCutOffRequest (coupure métier) — jamais par PowerCutOff_A/B seuls.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.4.md
*)
FUNCTION_BLOCK FB_Sim_Safety
VAR_INPUT
    Enable            : BOOL; // --> [CMD] Activation de la simulation
    SimChainOkBit     : BOOL; // --> [TST] Bit opérateur : TRUE = simuler chaîne AU fermée
    PowerCutOff_A     : BOOL; // --> [SAFE] Commande coupure canal A (TRUE = OK/fermé)
    PowerCutOff_B     : BOOL; // --> [SAFE] Commande coupure canal B (TRUE = OK/fermé)
    PowerCutOffRequest: BOOL; // --> [SAFE] Requête coupure métier (TRUE = arrêt d'urgence)
    EmergencyArming   : BOOL; // --> [CMD] Impulsion de réarmement (TRUE = pulse)
    BtnEmergencyStop   : BOOL; // --> [HW] Force l'ouverture de la boucle (TRUE = bouton appuyé/défaut)
    TestCutActive      : BOOL; // --> [SAFE] Test de redondance en cours (canal A ou B coupé par le FB AU)
END_VAR
VAR_OUTPUT
    SimChainOk      : BOOL; // <-- [STAT] Boucle AU simulée saine
    SimContactorOk  : BOOL; // <-- [STAT] Contacteur simulé engagé
END_VAR
VAR
    ContactorLatch  : BOOL; // . [LOC] Mémorisation de l'auto-maintien du contacteur
    ChainOpenReq    : BOOL; // . [LOC] Demande brute d'ouverture de la chaîne (bit off / coup-de-poing / test / coupure)
    ChainOpen       : BOOL; // . [LOC] État latche de la chaîne (TRUE = ouverte)
    ContactorEngageReq : BOOL; // . [LOC] Demande d'engagement du contacteur (pulse ET chaîne saine)
    TonChainOpen    : TON;  // . [LOC] Temporisation d'ouverture de la chaîne (retombée relais)
    TonChainClose   : TON;  // . [LOC] Temporisation de fermeture de la chaîne (retombée relais)
    TonContactorEngage : TON; // . [LOC] Temporisation d'engagement du contacteur (temps de collage bobine)
    TonContactorDrop   : TON; // . [LOC] Temporisation de retombée du contacteur (temps de décollage bobine)
END_VAR
VAR CONSTANT
    // === TEMPORISATIONS PHYSIQUES SIMULÉES (compatibles séquence FB AU) ===
    // ⚠️ Doivent rester < durées de la séquence FB AU (CST_TestDuration=200ms, CST_ArmingPulseDuration=1s,
    //    CST_ArmingConfirmTimeout=2s) pour que le test de redondance et la confirmation contacteur
    //    restent validés : ouverture/fermeture chaîne < 200ms, engagement contacteur < 1s.
    CST_ChainOpenDelay       : TIME := T#50ms;  // Temps de retombée relais AU (ouverture chaîne)
    CST_ChainCloseDelay      : TIME := T#50ms;  // Temps de retombée relais AU (fermeture chaîne)
    CST_ContactorEngageDelay : TIME := T#100ms; // Temps de collage bobine contacteur (engagement)
    CST_ContactorDropDelay   : TIME := T#50ms;  // Temps de décollage bobine contacteur (retombée)
END_VAR

// === IMPLEMENTATION ===
{region "§1 Gate"}
IF NOT Enable THEN
    SimChainOk     := FALSE;
    SimContactorOk := FALSE;
    ContactorLatch := FALSE;
    ChainOpen      := TRUE; // Chaîne ouverte par défaut à la ré-entrée (on n'a pas armé)
    ChainOpenReq   := FALSE;
    ContactorEngageReq := FALSE;
    TonChainOpen(IN := FALSE);
    TonChainClose(IN := FALSE);
    TonContactorEngage(IN := FALSE);
    TonContactorDrop(IN := FALSE);
    RETURN;
END_IF;
{endregion}

{region "§2 Chaîne AU (contrôle granulaire + dynamique)"}
// 1. La chaîne AU est saine si l'opérateur la simule fermée (SimChainOkBit = TRUE) ET si aucun
//    événement ne l'ouvre : coup-de-poing (BtnEmergencyStop), test de redondance (TestCutActive),
//    coupure métier (PowerCutOffRequest).
// 🔧 DEADLOCK SIMULATION (corrigé) : la chaîne n'est PAS fermée par défaut ni dépendante de
//    PowerCutOff_A/B (qui sont dans le cercle). Elle est fermée UNIQUEMENT par le bit opérateur
//    `SimChainOkBit`. Le réarmement après échec de test de redondance (RedundancyTestFailedCause laté
//    → PowerCutOff_A=FALSE) reste possible car la chaîne est maintenue fermée par le bit, pas par
//    le PLC. Hors simulation (Enable=FALSE), la chaîne reste pilotée par le matériel via le repli
//    HwReal (PRG_02 §1/§2) — aucune régression sécurité réelle.
// 🆕 DYNAMIQUE : l'ouverture/fermeture suit une temporisation (CST_ChainOpenDelay / CST_ChainCloseDelay)
//    qui simule le temps de retombée des relais AU, tout en restant < 200ms (CST_TestDuration) pour
//    ne pas fausser le test de redondance. Pendant le test, la chaîne clignote (s'ouvre en TEST_A/B,
//    se referme en RESTORE_A/B) puis revient à 1.
ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest;

// Temporisation d'ouverture : la chaîne s'ouvre après CST_ChainOpenDelay de demande soutenue
TonChainOpen(IN := ChainOpenReq, PT := CST_ChainOpenDelay);
// Temporisation de fermeture : la chaîne se ferme après CST_ChainCloseDelay d'absence de demande
TonChainClose(IN := NOT ChainOpenReq, PT := CST_ChainCloseDelay);

// Latch de la chaîne avec temporisations (défaut = ouverte à la ré-entrée)
IF ChainOpenReq THEN
    IF TonChainOpen.Q THEN
        ChainOpen := TRUE;
    END_IF;
ELSE
    IF TonChainClose.Q THEN
        ChainOpen := FALSE;
    END_IF;
END_IF;

SimChainOk := NOT ChainOpen;
{endregion}

{region "§3 Auto-maintien contacteur (dynamique réaliste)"}
// 2. Logique d'auto-maintien (latch) du contacteur avec priorité à la coupure.
// 🆕 DYNAMIQUE : le contacteur ne s'engage QUE pendant l'impulsion d'armement (EmergencyArming)
//    tant que la chaîne est saine, après CST_ContactorEngageDelay (temps de collage bobine), puis
//    s'auto-maintient. Il retombe après CST_ContactorDropDelay (temps de décollage bobine) dès que
//    la chaîne s'ouvre — comme une bobine réelle qui décolle sans alimentation. Ces temporisations
//    restent < CST_ArmingPulseDuration (1s) et CST_ArmingConfirmTimeout (2s) pour que la
//    confirmation contacteur reste validée. À la ré-entrée en simulation, le contacteur est NON
//    engagé (on n'a pas armé).
ContactorEngageReq := EmergencyArming AND SimChainOk;

// Temporisation d'engagement : le contacteur se colle après CST_ContactorEngageDelay de pulse soutenu
TonContactorEngage(IN := ContactorEngageReq, PT := CST_ContactorEngageDelay);
// Temporisation de retombée : le contacteur décolle après CST_ContactorDropDelay de chaîne ouverte
TonContactorDrop(IN := NOT SimChainOk, PT := CST_ContactorDropDelay);

// Latch du contacteur avec priorité à la coupure (retombée > engagement)
IF NOT SimChainOk THEN
    IF TonContactorDrop.Q THEN
        ContactorLatch := FALSE;
    END_IF;
ELSIF ContactorEngageReq THEN
    IF TonContactorEngage.Q THEN
        ContactorLatch := TRUE;
    END_IF;
END_IF;

// Recopie vers la sortie
SimContactorOk := ContactorLatch;
{endregion}
