(* =======================================================================
   ⚙️ FB_Encoder_SpeedMeasure — Mesure de vitesse câble directe codeur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Conversion directe du mot de vitesse natif codeur EtherCAT (m/s)
   ⚙️ Source CoE : Objet 0x6031:01 en 0.1 RPM (dixième de tour/min)
   📐 Formule : V(m/s) = (SpdValue * 0.1 * CableM_PerRev) / 60.0
   🛡️ Sans bornage : zéro clamping artificiel, suppression délai filtre PT1
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMeasure
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable              : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset               : BOOL;        // --> [CMD] Purge immediate (front montant)

    // === MESURES EN ENTREE ===
    SpdValueIn          : DINT;        // --> [HW]  Mot de vitesse brut EtherCAT (0x6031:01 en 0.1 RPM)
    PositionValid       : BOOL;        // --> [SAFE] Validite de la chaine codeur
    CableM_PerRev       : REAL := 2.0; // --> [CFG] Developpement cable par tour tambour (m/tour)
END_VAR
VAR_OUTPUT
    // === VITESSE CÂBLE QUALIFIÉE (m/s) ===
    Speed_Mps           : REAL;        // <-- [DIAG] Vitesse absolue directe (m/s)
    SignedSpeed_Mps     : REAL;        // <-- [DIAG] Vitesse signee directe (+ montee, - descente) (m/s)
    Valid               : BOOL;        // <-- [STAT] Validite mesure (TRUE si codeur operationnel et autorise)
END_VAR
VAR
    // === MEMOIRES & DETECTEURS ===
    ResetEdge           : R_TRIG;      // . [LOC] Detecteur front montant Reset
END_VAR

{region "§1 Gate de neutralisation & Reset"}
ResetEdge(CLK := Reset);

// Purge immediate sur perte de confiance, desactivation ou Reset
IF NOT Enable OR ResetEdge.Q OR NOT PositionValid THEN
    Speed_Mps       := 0.0;
    SignedSpeed_Mps := 0.0;
    Valid           := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Conversion directe vitesse CoE (0.1 RPM -> m/s)"}
// Formule cinematique directe :
// N_RPM = SpdValueIn * 0.1
// V_mps = (N_RPM * CableM_PerRev) / 60.0 = (DINT_TO_REAL(SpdValueIn) * 0.1 * CableM_PerRev) / 60.0
SignedSpeed_Mps := (DINT_TO_REAL(SpdValueIn) * 0.1 * CableM_PerRev) / 60.0;
Speed_Mps       := ABS(SignedSpeed_Mps);
Valid           := TRUE;
{endregion}

END_FUNCTION_BLOCK
