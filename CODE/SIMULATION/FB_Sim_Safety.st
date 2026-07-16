(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Safety — Simulation de la chaîne d'AU et du contacteur de puissance
   ───────────────────────────────────────────────────────────────
   📥 Enable          : activation de la simulation (SimulationModeActive AND NOT EmergencyStopChain_IsReal)
   📥 PowerCutOff_A   : demande de coupure PLC canal A (maintenu à TRUE en marche normale)
   📥 PowerCutOff_B   : demande de coupure PLC canal B (maintenu à TRUE en marche normale)
   📥 EmergencyArming : impulsion de réarmement (EmergencyArming_RQ)
   
   📤 SimChainOk      : simulation de la boucle AU (boutons relâchés et coupures PLC inactives)
   📤 SimContactorOk  : simulation du contacteur engagé (EmergencyStopOk)
   
   ⚙️ Logique physique :
      - La chaîne d'AU (SimChainOk) est saine si les deux relais PLC de coupure sont maintenus fermés (TRUE).
      - Le contacteur s'engage (SimContactorOk) lors d'une impulsion de réarmement (EmergencyArming) 
        et s'auto-maintient tant que la chaîne reste saine (SimChainOk).
      - Toute coupure de la chaîne (SimChainOk = FALSE) fait retomber immédiatement le contacteur.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_Sim_Safety
VAR_INPUT
    Enable          : BOOL; // Activation de la simulation
    PowerCutOff_A   : BOOL; // Commande coupure canal A (TRUE = OK/fermé)
    PowerCutOff_B   : BOOL; // Commande coupure canal B (TRUE = OK/fermé)
    EmergencyArming : BOOL; // Impulsion de réarmement (TRUE = pulse)
    BtnEmergencyStop : BOOL; // Force l'ouverture de la boucle (TRUE = bouton appuyé/défaut)
END_VAR
VAR_OUTPUT
    SimChainOk      : BOOL; // Boucle AU simulée saine
    SimContactorOk  : BOOL; // Contacteur simulé engagé
END_VAR
VAR
    ContactorLatch  : BOOL; // Mémorisation de l'auto-maintien du contacteur
END_VAR

// === IMPLEMENTATION ===
IF NOT Enable THEN
    SimChainOk     := FALSE;
    SimContactorOk := FALSE;
    ContactorLatch := FALSE;
    RETURN;
END_IF;

// 1. La chaîne AU est saine si le PLC maintient les deux relais de coupure de puissance
// AND if no emergency stop button is pressed (BtnEmergencyStop is FALSE)
SimChainOk := PowerCutOff_A AND PowerCutOff_B AND NOT BtnEmergencyStop;

// 2. Logique d'auto-maintien (latch) du contacteur avec priorité à la coupure
IF NOT SimChainOk THEN
    ContactorLatch := FALSE;
ELSIF EmergencyArming THEN
    ContactorLatch := TRUE;
END_IF;

// Recopie vers la sortie
SimContactorOk := ContactorLatch;
