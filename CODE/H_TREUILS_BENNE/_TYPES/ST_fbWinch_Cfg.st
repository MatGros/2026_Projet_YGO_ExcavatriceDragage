(* =======================================================================
   ðŸª ST_fbWinch_Cfg â€” Configuration statique d'un treuil
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   ðŸŽ¯ RÃ´le : RÃ©glages persistants propres Ã  l'instance treuil (statique)
   ðŸ“„ Doc mÃ©tier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ðŸ“¤ Producteur : configuration persistante
   ðŸ“¥ Consommateur : FB_Winch (statique uniquement)
   ðŸ”’ Structs cibles + champs conservÃ©s pour garder le dÃ©codage %â†’palier
      et les deux cadences de rampe DANS FB_Winch (comportement
      bit-identique). Le champ StepRampDelay est dÃ©clarÃ© mais non
      consommÃ© (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_Cfg :
STRUCT
    // === TABLE DES PALIERS ===
    SpeedStepTable                  : ST_SpeedStepTable;   // Table de seuils des paliers de vitesse

    // === INTERLOCK CHANGEMENT DE SENS ===
    DirectionInterlockDelayUp       : TIME := T#900ms;   // Delai interlock changement de sens montee
    DirectionInterlockDelayDown     : TIME := T#400ms;   // Delai interlock changement de sens descente

    // === CADENCE DE RAMPE PALIER ===
    StepRampDelay                   : TIME := T#1000ms;  // [cible] Tempo de rampe palier (usage aval)
    StepRampDelayAscent             : TIME := T#1000ms;  // [08a] Cadence palier montee (D10, dedie)
    StepRampDelayDescending         : TIME := T#500ms;   // [08a] Cadence palier descending (D10, dedie)

    // === RETOMBÃ‰E CONTACTEURS ===
    ContactorFeedbackTimeout        : TIME := T#500ms;   // Delai d'attente retombee des contacteurs

    // === RALENTISSEMENT BORDURE ===
    SlowdownDistance_M              : REAL := 1.0;   // Distance d'approche avant limite pour ralentir (m)
    SlowdownMaxStep                 : INT := 1;      // Plafond palier dans zone de ralentissement (1..5)

    // === DÃ‰CODAGE %â†’PALIER (conservÃ©) ===
    SpeedStepHystMargin             : REAL := 2.0;   // [08a] Marge d'hysteresis palier (%)
END_STRUCT
END_TYPE


