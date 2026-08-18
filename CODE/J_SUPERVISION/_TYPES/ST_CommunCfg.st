(* ═══════════════════════════════════════════════════════════════
   ST_CommunCfg — Configuration des paramètres communs machine
   📄 : WinchMaxStepDescente/WinchMaxStepAscent/WinchSlowdownDistance_M/
   WinchSlowSpeed_Pct rapatriés depuis ST_WinchCfg (étaient partagés M1/M2 par réconciliation
   ad-hoc dans PRG_SUPERVISION_CFC.st, une seule instance ici l'élimine).
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
    WinchMaxStepDescente        : INT := 3;     (* 🛑 Limitation palier vitesse en descente (1..5), commun M1/M2 *)
    WinchMaxStepAscent          : INT := 5;     (* 🚀 Limitation palier vitesse en montée (1..5), commun M1/M2 *)
    WinchSlowdownDistance_M     : REAL := 1.0;  (* 📏 Distance avant limite pour enclencher le ralentissement (m), commun M1/M2 *)
    // : WinchSlowSpeed_Pct (%) retiré — un treuil ne connaît que des paliers (1..5),
    // pas une vitesse continue.
    WinchSlowdownMaxStep        : INT := 1;     (* : Plafond palier dans la zone de ralentissement (1..5), commun M1/M2 *)
    TglEnableKoboldAutoStopDescent : BOOL := FALSE; (* : Arrêt auto descente sur détection fond Kobold (pilotage normal) *)
    // (4) — coupe-circuit d'urgence pour le séquencement auto benne (Fiche 01).
    // Défaut FALSE = comportement IDENTIQUE à avant Fiche 01 (déplacement M1/M2 synchro jamais
    // gouverné par instBucket.Busy sauf action MANUELLE benne/DumpAtTremie/ExtractionSequence).
    TglEnableCoupledBucketSequencing : BOOL := FALSE;
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
