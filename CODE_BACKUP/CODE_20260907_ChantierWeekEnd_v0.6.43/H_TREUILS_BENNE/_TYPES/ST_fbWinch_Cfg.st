(* =======================================================================
   🪝 ST_fbWinch_Cfg — Configuration statique d'un treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Réglages persistants propres à l'instance treuil (statique)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   📤 Producteur : configuration persistante
   📥 Consommateur : FB_Winch (statique uniquement)
   🔒 Structs cibles + champs conservés pour garder le décodage %→palier
      et les deux cadences de rampe DANS FB_Winch (comportement
      bit-identique). Le champ StepRampDelay est déclaré mais non
      consommé (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_Cfg :
STRUCT
    // === TABLE DES PALIERS ===
    SpeedStepTable                  : ST_SpeedStepTable;   // Table de seuils des paliers de vitesse

    // === INTERLOCK CHANGEMENT DE SENS ===
    DirectionInterlockDelayAscent       : TIME := T#800ms;   // Delai interlock inversion vers montee
    DirectionInterlockDelayDescent     : TIME := T#500ms;   // Delai interlock inversion vers descente

    // === CADENCE DE RAMPE PALIER ===
    StepRampDelay                   : TIME := T#700ms;   // [cible] Tempo de rampe palier (usage aval)
    StepRampDelayAscent             : TIME := T#700ms;   // [08a] Cadence palier montee (D10, dedie)
    StepRampDelayDescent         : TIME := T#500ms;   // [08a] Cadence palier descending (D10, dedie)

    // === RETOMBÉE CONTACTEURS ===
    ContactorFeedbackTimeout        : TIME := T#500ms;   // Delai d'attente retombee des contacteurs

    // === RALENTISSEMENT BORDURE ===
    SlowdownDistanceTop_M           : REAL := 0.5;   // Distance avant limite haute pour ralentir (m) : 0 = arrêt au seuil
    SlowdownDistanceBottom_M        : REAL := 1.0;   // Distance avant limite basse pour ralentir (m)
    SlowdownMaxStep                 : INT := 1;      // Plafond palier dans zone de ralentissement (1..5)

    // === DÉCODAGE %→PALIER (conservé) ===
    SpeedStepHystMargin             : REAL := 2.0;   // [08a] Marge d'hysteresis palier (%)
END_STRUCT
END_TYPE
