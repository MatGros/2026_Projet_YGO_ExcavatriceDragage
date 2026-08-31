(* ═══════════════════════════════════════════════════════════════
   ST_CommunCfg — Configuration des paramètres communs machine
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunCfg :
STRUCT
    // Blocage instantané à 0m : sans défaut explicite,
    // ce champ vaut 0.0 tant qu'il n'a pas été réglé côté IHM -- "CablePosM <= 0.0" se déclenche
    // dès la position de référence, avant tout réglage réel de la cote légale. Défaut -999.0
    // (jamais atteint en pratique) : LimitLegalEnabled=TRUE sans réglage ne bloque plus rien par
    // erreur -- il faut régler la vraie cote pour que la protection devienne active.
    LimitLegalDepthMinAllowed_M : REAL := -999.0; (* 📐 Cote min de dragage autorisée (m, négatif) *)
    LimitLegalEnabled           : BOOL; (* 🟢 Activation de la limite légale *)
    SelHomingApproachEnable     : BOOL; (* 🔌 Case IHM : autorise le dépassement butée haute pour homing (si MAINT_N2) *)
    WinchMaxStepDescent      : INT := 3;     (* 🛑 Limitation palier vitesse en descending (1..5), commun M1/M2 *)
    WinchMaxStepAscent          : INT := 5;     (* 🚀 Limitation palier vitesse en montée (1..5), commun M1/M2 *)
    WinchSlowdownDistance_M     : REAL := 1.0;  (* 📏 Distance avant limite pour enclencher le ralentissement (m), commun M1/M2 *)
    // : WinchSlowSpeed_Pct (%) retiré — un treuil ne connaît que des paliers (1..5),
    // pas une vitesse continue.
    WinchSlowdownMaxStep        : INT := 1;     (* : Plafond palier dans la zone de ralentissement (1..5), commun M1/M2 *)
    CfgCableLimitAscent_M       : REAL := 7.5;  (* 📐 Limite haute d'exploitation NORMALE (m), commun M1/M2 *)
    TglEnableKoboldAutoStopDescent : BOOL := FALSE; (* : Arrêt auto descente sur détection fond Kobold (pilotage normal) *)
    // Coupe-circuit d'urgence pour le séquencement auto benne.
    // Défaut FALSE = mouvement M1/M2 synchro jamais
    // gouverné par instBucket.Busy sauf action MANUELLE benne/DumpAtTremie/ExtractionAssist).
    TglEnableCoupledBucketSequencing : BOOL := FALSE;
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
