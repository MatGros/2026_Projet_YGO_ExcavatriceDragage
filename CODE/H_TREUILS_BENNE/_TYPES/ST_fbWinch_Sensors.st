(* =======================================================================
   ðŸª ST_fbWinch_Sensors â€” Mesures et feedbacks d'un treuil
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   ðŸŽ¯ RÃ´le : Retours physiques et mesures propres Ã  l'instance treuil
   ðŸ“„ Doc mÃ©tier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ðŸ“¤ Producteur : PRG_04_Treuils_Benne / acquisition
   ðŸ“¥ Consommateur : FB_Winch
   ðŸ”’ Structs cibles + champs conservÃ©s pour garder le garde-fou vitesse
      DANS FB_Winch (comportement bit-identique). Les champs
      MeasuredSpeedMps / MeasuredSpeedValid sont dÃ©clarÃ©s mais non
      consommÃ©s (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_Sensors :
STRUCT
    // === POSITION ET RÃ‰FÃ‰RENCEMENT ===
    CablePosM                       : REAL;   // Position actuelle du cable (m)
    Homed                           : BOOL;   // Statut treuil reference
    HomingSuspect                   : BOOL;   // Incertitude / doute sur le referencement

    // === RETOURS CONTACTEURS ===
    ContactorsAllOff                : BOOL;   // TRUE = relais sens + C1..C4 tous retombÃ©s (ex-FwdRevSpeedFeedbackOff)

    // === MESURE VITESSE ===
    MeasuredSpeedMps                : REAL;   // [cible] Mesure vitesse rÃ©elle (m/s) â€” usage aval
    MeasuredSpeedValid              : BOOL;   // [cible] Mesure exploitable â€” usage aval
    MeasuredSpeedBand               : INT := 0;   // [08a] Bande vitesse rÃ©elle validÃ©e (garde-fou conservÃ© dans FB_Winch)

    // === GARDE-FOU VITESSE (conservÃ©) ===
    SpeedGuardEnable                : BOOL := TRUE;   // [08a] Activation garde-fou changement de palier
    SpeedGuardReady                 : BOOL := FALSE;  // [08a] Conditions de stabilitÃ© validÃ©es
END_STRUCT
END_TYPE


