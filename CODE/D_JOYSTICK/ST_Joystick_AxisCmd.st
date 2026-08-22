(* =======================================================================
   🕹️ ST_Joystick_AxisCmd — Consigne d'axe normalisée (sortie FB_Joystick)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de consigne d'axe produite par FB_Joystick.
   📤 Champs : Enable, StartStop, SpeedRef + direction en bits (DirectionPositive/Negative, AtNeutral).
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md
   ======================================================================= *)

TYPE ST_Joystick_AxisCmd :
STRUCT
    // === CONSIGNES DE PILOTAGE AXE ===
    Enable      : BOOL;   // --> [CMD] Autorisation globale pipeline (FALSE=neutralisation, sorties coupees)
    StartStop   : BOOL;   // --> [CMD] Validation de mouvement (TRUE=acceleration, FALSE=deceleration/arret)
    SpeedRef    : REAL;   // --> [CMD] Consigne vitesse non signee (0...100 %, signe/sens donné par Direction)
    DirectionNegative   : BOOL;   // --> [CMD] Direction joystick ou intension de gestuelle
    DirectionPositive   : BOOL;   // --> [CMD] Direction joystick ou intension de gestuelle
    AtNeutral   : BOOL;   // --> [CMD] TRUE si axes en zone morte (position centrale)
    // Remplacé par bit qui donne la direction Direction   : INT;  // --> [CMD] Sens de mouvement (-1=Arriere/Descente, 0=Neutre, +1=Avant/Montee)
END_STRUCT
END_TYPE
