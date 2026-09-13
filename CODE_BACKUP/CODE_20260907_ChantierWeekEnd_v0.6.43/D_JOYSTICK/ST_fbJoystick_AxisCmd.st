(* =======================================================================
   🕹️ ST_fbJoystick_AxisCmd — Consigne d'axe normalisée (sortie FB_Joystick)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de consigne d'axe produite par FB_Joystick.
   📤 Champs : Enable, StartStop, SpeedTgt (%) + StepTgt (palier 1..5) + direction en bits
               (DirectionPositive/Negative, AtNeutral). SpeedTgt reste pour l'IHM, StepTgt pour la logique.
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md
   ======================================================================= *)

TYPE ST_fbJoystick_AxisCmd :
STRUCT
    // === CONSIGNES DE PILOTAGE AXE ===
    Enable      : BOOL;   // --> [CMD] Autorisation globale pipeline (FALSE=neutralisation, sorties coupees)
    StartStop   : BOOL;   // --> [CMD] Validation de mouvement (TRUE=acceleration, FALSE=deceleration/arret)
    SpeedTgt    : REAL;   // --> [CMD] Vitesse cible non signee (0...100 %, signe/sens donné par Direction) - IHM
    StepTgt     : INT;    // --> [CMD] Palier de vitesse (1..5, 0=arret) - logique/limitations (derive de SpeedTgt)
    DirectionNegative   : BOOL;   // --> [CMD] Direction joystick ou intension de gestuelle
    DirectionPositive   : BOOL;   // --> [CMD] Direction joystick ou intension de gestuelle
    AtNeutral   : BOOL;   // --> [CMD] TRUE si axes en zone morte (position centrale)

    // === MONITORING IHM (derive des bits ci-dessus, jamais lu en interlock) ===
    Direction   : INT;   // <-- [STAT] Sens -1=Rev / 0=Neutre / +1=Fwd (anim IHM fleche ; lu aussi logique treuils PRG_04)
    Deflection  : INT;   // <-- [STAT] Deflexion signee -100..+100 % (anim IHM jauge/barre)
END_STRUCT
END_TYPE
