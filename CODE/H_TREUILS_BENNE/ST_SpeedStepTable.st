(* =======================================================================
   🪜 ST_SpeedStepTable — Table des paliers de vitesse contacteurs
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de configuration des contacteurs et seuils par palier
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_SpeedStepTable :
STRUCT
    // === PALIER 1 (VITESSE MINIMALE) ===
    P1R1              : BOOL;                                         // Contacteur 1 pour Palier 1
    P1R2              : BOOL;                                         // Contacteur 2 pour Palier 1
    P1R3              : BOOL;                                         // Contacteur 3 pour Palier 1
    P1R4              : BOOL;                                         // Contacteur 4 pour Palier 1

    // === PALIER 2 ===
    P2R1              : BOOL;                                         // Contacteur 1 pour Palier 2
    P2R2              : BOOL;                                         // Contacteur 2 pour Palier 2
    P2R3              : BOOL;                                         // Contacteur 3 pour Palier 2
    P2R4              : BOOL;                                         // Contacteur 4 pour Palier 2

    // === PALIER 3 ===
    P3R1              : BOOL;                                         // Contacteur 1 pour Palier 3
    P3R2              : BOOL;                                         // Contacteur 2 pour Palier 3
    P3R3              : BOOL;                                         // Contacteur 3 pour Palier 3
    P3R4              : BOOL;                                         // Contacteur 4 pour Palier 3

    // === PALIER 4 ===
    P4R1              : BOOL;                                         // Contacteur 1 pour Palier 4
    P4R2              : BOOL;                                         // Contacteur 2 pour Palier 4
    P4R3              : BOOL;                                         // Contacteur 3 pour Palier 4
    P4R4              : BOOL;                                         // Contacteur 4 pour Palier 4

    // === PALIER 5 (VITESSE MAXIMALE) ===
    P5R1              : BOOL;                                         // Contacteur 1 pour Palier 5
    P5R2              : BOOL;                                         // Contacteur 2 pour Palier 5
    P5R3              : BOOL;                                         // Contacteur 3 pour Palier 5
    P5R4              : BOOL;                                         // Contacteur 4 pour Palier 5

    // === SEUILS DE TRANSITION (%) ===
    StepThreshold_Pct : ARRAY[1..5] OF REAL;                          // Seuils de changement de palier (0..100%)
END_STRUCT
END_TYPE
