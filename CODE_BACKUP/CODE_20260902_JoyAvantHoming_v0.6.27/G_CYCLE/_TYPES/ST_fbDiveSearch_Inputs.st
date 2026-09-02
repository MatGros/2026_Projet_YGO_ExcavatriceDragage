(* =======================================================================
   ST_fbDiveSearch_Inputs - Bus d'entree du cycle FB_DiveSearch
   ======================================================================= *)
TYPE ST_fbDiveSearch_Inputs :
STRUCT
    // === AUTORISATIONS & COMMANDE ===
    PowerContactorEngaged : BOOL;          // Chaine de puissance engagee
    Mode                  : E_Mode;        // Mode arbitre courant
    MotionRequestActive   : BOOL;          // Demande de mouvement couplee
    MotionDirection       : INT;           // Sens demande (-1 = descente)

    // === CAPTEURS & MESURES ===
    BucketIsOpen           : BOOL;          // Benne ouverte confirmee
    KoboldImmersed         : BOOL;          // Kobold immerge
    M1Position_M           : REAL;          // Position cable M1 (m)
    M2Position_M           : REAL;          // Position cable M2 (m)
    PositionsValid         : BOOL;          // Mesures M1/M2 valides
    CurrentSpeedStep       : INT;           // Palier reel courant (0..5)

    // === REGLAGES METIER ===
    DiveStartMin_M         : REAL;          // Position minimale avant descente (m)
    ImmersionUpper_M       : REAL;          // Borne haute fenetre immersion (m)
    ImmersionLower_M       : REAL;          // Borne basse fenetre immersion (m)
    CableLimitAscent_M     : REAL;          // Limite haute exploitation (m)
    LimitLegalDepthMin_M   : REAL;          // Limite basse legale (m)
    CfgDiveFloorStep       : INT;           // Plancher palier descente (0..5)
    CycleTime              : TIME;          // Periode d'execution du cycle
    BypassPreconditions     : BOOL;         // Bypass reserve au mode maintenance N2/test
    Config                 : ST_fbDiveSearch_Config; // Parametres timeout
END_STRUCT
END_TYPE
