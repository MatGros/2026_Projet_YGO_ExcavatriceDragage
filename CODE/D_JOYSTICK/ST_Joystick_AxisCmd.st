(* =======================================================================
   🕹️ ST_Joystick_AxisCmd — Consigne d'axe normalisée (sortie FB_Joystick)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de consigne d'axe 4 champs produite par FB_Joystick.
   📤 Champs : Enable, StartStop, SpeedRef, Direction.
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md
   ======================================================================= *)

TYPE ST_Joystick_AxisCmd :
STRUCT
    // === CONSIGNES DE PILOTAGE AXE ===
    Enable      : BOOL;   // --> [CMD] Autorisation globale pipeline (FALSE=neutralisation, sorties coupees)
    StartStop   : BOOL;   // --> [CMD] Validation de mouvement (TRUE=acceleration, FALSE=deceleration)
    SpeedRef    : REAL;   // --> [CMD] Consigne vitesse signee (-100.0..+100.0 %, signe coherent avec Direction)
    Direction   : INT;    // --> [CMD] Sens de mouvement (-1=Arriere/Descente, 0=Neutre, +1=Avant/Montee)
END_STRUCT
END_TYPE
