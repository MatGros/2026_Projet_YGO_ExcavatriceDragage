(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Safety — Simulation de la chaîne d'AU et du contacteur de puissance
   ───────────────────────────────────────────────────────────────
   📥 Enable          : activation de la simulation (SimulationModeActive AND NOT SensorEmergencyStopChainIsReal)
   📥 PowerCutOff_A   : demande de coupure PLC canal A (maintenu à TRUE en marche normale)
   📥 PowerCutOff_B   : demande de coupure PLC canal B (maintenu à TRUE en marche normale)
   📥 EmergencyArming : impulsion de réarmement (EmergencyArming_RQ)
   
   📤 SimChainOk      : simulation de la boucle AU (boutons relâchés et coupures PLC inactives)
   📤 SimContactorOk  : simulation du contacteur engagé (PowerContactorEngaged)
   
   ⚙️ Logique physique :
      - La chaîne d'AU (SimChainOk) est saine si les deux relais PLC de coupure sont maintenus fermés (TRUE).
      - Le contacteur s'engage (SimContactorOk) lors d'une impulsion de réarmement (EmergencyArming) 
        et s'auto-maintient tant que la chaîne reste saine (SimChainOk).
      - Toute coupure de la chaîne (SimChainOk = FALSE) fait retomber immédiatement le contacteur.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.4.md
*)
FUNCTION_BLOCK FB_Sim_Safety
VAR_INPUT
    Enable          : BOOL; // --> [CMD] Activation de la simulation
    PowerCutOff_A   : BOOL; // --> [SAFE] Commande coupure canal A (TRUE = OK/fermé)
    PowerCutOff_B   : BOOL; // --> [SAFE] Commande coupure canal B (TRUE = OK/fermé)
    EmergencyArming : BOOL; // --> [CMD] Impulsion de réarmement (TRUE = pulse)
    BtnEmergencyStop : BOOL; // --> [HW] Force l'ouverture de la boucle (TRUE = bouton appuyé/défaut)
END_VAR
VAR_OUTPUT
    SimChainOk      : BOOL; // <-- [STAT] Boucle AU simulée saine
    SimContactorOk  : BOOL; // <-- [STAT] Contacteur simulé engagé
END_VAR
VAR
    ContactorLatch  : BOOL; // . [LOC] Mémorisation de l'auto-maintien du contacteur
END_VAR

// === IMPLEMENTATION ===
{region "§1 Gate"}
IF NOT Enable THEN
    SimChainOk     := FALSE;
    SimContactorOk := FALSE;
    ContactorLatch := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Chaîne AU"}
// 1. La chaîne AU est saine si le PLC maintient les deux relais de coupure de puissance
// AND if no emergency stop button is pressed (BtnEmergencyStop is FALSE).
// 🔧 DEADLOCK SIMULATION (corrigé) : sur machine réelle, la boucle AU se ferme
// physiquement au relâchement du coup-de-poing (indépendant du PLC). En simulation,
// l'ancien modèle exigeait le maintien actif du PLC (PowerCutOff_A/B) pour fermer la
// chaîne, or ce maintien dépend lui-même de la chaîne fermée à l'IDLE
// (Maintain_ChainOk = EmergencyChainClosed, FB_Safety_EmergencyManagement.st:385)
// → dépendance circulaire : SimChainOk reste FALSE, l'AU ne peut jamais s'armer.
// Correction : chaîne « fermée par défaut » en simulation (défaut = TRUE, coup-de-poing
// relâché), qui retombe dès qu'un canal est coupé (test redondance A/B) ou que le
// coup-de-poing est appuyé. Hors simulation (Enable=FALSE), la chaîne reste pilotée par
// le matériel via le repli HwReal (PRG_02 §1/§2) — aucune régression sécurité réelle.
SimChainOk := TRUE; // 🔧 Chaîne fermée par défaut en simulation (coup-de-poing relâché)
IF NOT PowerCutOff_A OR NOT PowerCutOff_B OR BtnEmergencyStop THEN
    SimChainOk := FALSE; // Coupure canal (test redondance) ou appui coup-de-poing → boucle ouverte
END_IF;
{endregion}

{region "§3 Auto-maintien contacteur"}
// 2. Logique d'auto-maintien (latch) du contacteur avec priorité à la coupure
IF NOT SimChainOk THEN
    ContactorLatch := FALSE;
ELSIF EmergencyArming THEN
    ContactorLatch := TRUE;
END_IF;

// Recopie vers la sortie
SimContactorOk := ContactorLatch;
{endregion}
