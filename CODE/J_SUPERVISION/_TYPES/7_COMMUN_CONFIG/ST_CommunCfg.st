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
    WinchMaxStepDescent      : INT := 5;     (* 🚀 Plafond palier descente nominal (1..5), commun M1/M2 *)
    WinchMaxStepAscent          : INT := 5;     (* 🚀 Limitation palier vitesse en montée (1..5), commun M1/M2 *)
    WinchSlowdownDistanceTop_M     : REAL := 0.0;  (* 📏 Distance avant limite haute : 0 = arrêt au seuil (m), commun M1/M2 *)
    WinchSlowdownDistanceBottom_M  : REAL := 1.0;  (* 📏 Distance avant limite basse pour ralentir (m), commun M1/M2 *)
    // : WinchSlowSpeed_Pct (%) retiré — un treuil ne connaît que des paliers (1..5),
    // pas une vitesse continue.
    WinchSlowdownMaxStep        : INT := 1;     (* : Plafond palier dans la zone de ralentissement (1..5), commun M1/M2 *)
    CfgCableLimitAscent_M       : REAL := 7.5;  (* 📐 Limite haute d'exploitation NORMALE (m), commun M1/M2 *)
    TglEnableKoboldAutoStopDescent : BOOL := FALSE; (* : Arrêt auto descente sur détection fond Kobold (pilotage normal) *)
    // Séquencement auto benne en pilotage couplé (WinchSel=0, MAINT/MANUEL/AUTO) :
    // pousser le joystick benne pas ouverte -> ouvre d'abord puis descend couplé ;
    // tirer benne pas fermée -> ferme d'abord puis remonte couplé.
    // Défaut TRUE (activé) ; 1 bouton IHM pour désactiver -> comportement brut
    // (2 treuils sans condition). OFF = jamais gouverné par instBucket.Busy hors
    // action MANUELLE benne (WinchSel=2) / DumpAtTremie / ExtractionAssist.
    TglEnableCoupledBucketSequencing : BOOL := TRUE;
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
