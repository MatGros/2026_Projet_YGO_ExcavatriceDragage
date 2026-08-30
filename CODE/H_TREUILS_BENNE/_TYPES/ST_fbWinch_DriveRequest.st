(* =======================================================================
   ðŸª ST_fbWinch_DriveRequest â€” RequÃªte d'axe treuil (producteur PRG_04)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   ðŸŽ¯ RÃ´le : Demande de mouvement, palier et bornes de clamp d'un treuil
   ðŸ“„ Doc mÃ©tier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ðŸ“¤ Producteur : PRG_04_Treuils_Benne (une par treuil M1/M2)
   ðŸ“¥ Consommateur : FB_Winch
   ðŸ”’ Structs cibles + champs conservÃ©s pour garder le dÃ©codage %â†’palier
      et le clamp DANS FB_Winch (comportement bit-identique). Les champs
      SpeedStepReq / MinStepUp sont dÃ©clarÃ©s mais non consommÃ©s (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_DriveRequest :
STRUCT
    // === ORDRE DE MOUVEMENT ===
    StartStop                       : BOOL;   // TRUE = mouvement demandÃ©
    Direction                       : INT;    // -1: Descending, 0: Stop, 1: Ascending
    SpeedStepReq                    : INT;    // [cible] Palier demandÃ© dÃ©codÃ© en amont (usage aval)
    SpeedTgt_Pct                    : REAL;   // [08a] Consigne vitesse % (0.0..100.0) â€” dÃ©codage conservÃ© dans FB_Winch

    // === BORNES DE CLAMP (agrÃ©gÃ©es PRG_04) ===
    MinStepUp                       : INT;    // [cible] Plancher palier montÃ©e (usage aval)
    MaxStepUp                       : INT := 5;    // Plafond palier montÃ©e (1..5)
    MinStepDown                     : INT := 0;    // Plancher palier descente (0 = aucun) -- plongee Kobold
    MaxStepDown                     : INT := 3;    // Plafond palier descente (1..5)

    // === LIMITES EFFECTIVES DU CYCLE ===
    TopLimitM                       : REAL := 8.5;   // Position limite haute active (m)
    BottomLimitM                    : REAL := -20.0; // Position limite basse active (m)

    // === DIAGNOSTIC (jamais lu par la logique FB_Winch) ===
    SyncCoupled                     : BOOL;   // [diag] Couplage synchro actif (garde de revue)

    // === CHAMPS CONSERVÃ‰S (clamp interne FB_Winch) ===
    HomingApproachActive            : BOOL;   // [08a] Vitesse limitÃ©e au palier 1 (approche homing)
END_STRUCT
END_TYPE


