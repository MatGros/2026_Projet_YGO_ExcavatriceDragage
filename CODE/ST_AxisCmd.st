(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_AxisCmd — Consigne d'axe normalisée (sortie FB_Joystick)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie2_Architecture_Programme_v2.6.md §8
   ⚠️ MISE EN CONFORMITÉ (remplace la version actuelle du projet) :
      - Champ `Start` renommé `StartStop` (convention Partie3 §1bis :
        TRUE = rampe accélération, FALSE = rampe décélération normale)
      - Champ `SafetyOk` RETIRÉ : ce n'est pas une commande d'axe, c'est
        une info de contexte (`EmergencyStopOk`) consommée directement
        par le FB de mouvement (FB_Winch/FB_Translation), pas portée
        par la consigne d'axe elle-même.
   🧭 4 champs exactement, conforme Partie2 v2.5 §8.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AxisCmd :
STRUCT
    Enable      : BOOL;   // Autorisation FB (FALSE = neutralisation, sorties coupées)
    StartStop   : BOOL;   // TRUE = rampe accélération, FALSE = rampe décélération normale
    SpeedRef    : REAL;   // Consigne vitesse 0..100 %
    Direction   : INT;    // -1 = Rev, 0 = Neutre, +1 = Fwd
END_STRUCT
END_TYPE
