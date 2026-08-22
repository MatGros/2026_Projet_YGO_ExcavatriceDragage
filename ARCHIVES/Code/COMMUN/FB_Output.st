(* =======================================================================
   📤 FB_Output — Adaptateur de sortie physique TOR (inversion NO/NC)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Conditionnement et inversion optionnelle de la commande TOR
   🔌 Interface : Interface directe vers carte de sortie physique
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md §Câblage
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Output
VAR_INPUT
    // === COMMANDES ET CONFIGURATION ===
    Command                 : BOOL;               // --> [CMD] Ordre logique issu du FB metier appelant
    InvertLogic             : BOOL;               // --> [CFG] TRUE = cablage NC (inversion de la sortie)
END_VAR
VAR_OUTPUT
    // === SORTIES PHYSIQUES ===
    State                   : BOOL;               // <-- [ACT] Etat logique physique vers la carte de sortie
END_VAR

State := Command XOR InvertLogic;
