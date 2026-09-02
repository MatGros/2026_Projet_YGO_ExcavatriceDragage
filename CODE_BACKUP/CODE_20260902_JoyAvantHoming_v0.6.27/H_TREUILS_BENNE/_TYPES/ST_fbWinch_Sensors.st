(* =======================================================================
   🪝 ST_fbWinch_Sensors — Mesures et feedbacks d'un treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Retours physiques et mesures propres à l'instance treuil
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   📤 Producteur : PRG_04_Treuils_Benne / acquisition
   📥 Consommateur : FB_Winch
   🔒 Structs cibles + champs conservés pour garder le garde-fou vitesse
      DANS FB_Winch (comportement bit-identique). Les champs
      MeasuredSpeedMps / MeasuredSpeedValid sont déclarés mais non
      consommés (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_Sensors :
STRUCT
    // === POSITION ET RÉFÉRENCEMENT ===
    CablePosM                       : REAL;   // Position actuelle du cable (m)
    Homed                           : BOOL;   // Statut treuil reference
    HomingSuspect                   : BOOL;   // Incertitude / doute sur le referencement

    // === RETOURS CONTACTEURS ===
    ContactorsAllOff                : BOOL;   // TRUE = relais sens + C1..C4 tous retombés (ex-FwdRevSpeedFeedbackOff)

    // === MESURE VITESSE ===
    MeasuredSpeedMps                : REAL;   // [cible] Mesure vitesse réelle (m/s) — usage aval
    MeasuredSpeedValid              : BOOL;   // [cible] Mesure exploitable — usage aval
    MeasuredSpeedBand               : INT := 0;   // [08a] Bande vitesse réelle validée (garde-fou conservé dans FB_Winch)

    // === GARDE-FOU VITESSE (conservé) ===
    SpeedGuardEnable                : BOOL := TRUE;   // [08a] Activation garde-fou changement de palier
    SpeedGuardReady                 : BOOL := FALSE;  // [08a] Conditions de stabilité validées
END_STRUCT
END_TYPE


