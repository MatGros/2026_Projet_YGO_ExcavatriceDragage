(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_Joystick_AxisCmd — Consigne d'axe normalisée (sortie FB_Joystick)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-08_Fonction_Joystick_v2.0.md
                   DOC/AF_Partie-03_Contrats_Composants_v2.0.md
   🎯 4 champs exactement :
      - Enable    : Autorisation globale du pipeline
      - StartStop : RAMPE (TRUE = accélération, FALSE = décélération normale)
      - SpeedRef  : Consigne vitesse signée (-100.0 .. +100.0 %)
      - Direction : Sens d'axe (-1 = Rev, 0 = Neutre, +1 = Fwd)
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_Joystick_AxisCmd :
STRUCT
    Enable      : BOOL;   // Autorisation FB (FALSE = neutralisation, sorties coupées)
    StartStop   : BOOL;   // TRUE = rampe accélération, FALSE = rampe décélération normale
    SpeedRef    : REAL;   // Consigne vitesse SIGNÉE -100..+100 % (signe = sens, cohérent avec Direction)
    Direction   : INT;    // -1 = Rev, 0 = Neutre, +1 = Fwd
END_STRUCT
END_TYPE
