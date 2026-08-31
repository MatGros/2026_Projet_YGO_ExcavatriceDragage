(* =======================================================================
   ⚙️ ST_Safety_Emergency_Cmd — Commandes de pilotage de la chaîne AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : DUT de commande du FB_Safety_EmergencyManagement fusionné.
      Regroupe les commandes physiques fail-safe de pilotage des canaux
      de maintien et de l'impulsion de réarmement.
   🔒 Polarité : MaintainA/B_Cmd en maintien (TRUE = voie saine).
      Fail-safe : Enable=FALSE → toutes commandes à FALSE.
   🔌 Interface : Produit par FB_Safety_EmergencyManagement.Cmd, consommé par
      PRG_06_Outputs uniquement.
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_Cmd :
STRUCT
    MaintainA_Cmd   : BOOL; // <-- [ACT]  Sortie pilotage canal A (TRUE = voie maintenue)
    MaintainB_Cmd   : BOOL; // <-- [ACT]  Sortie pilotage canal B (TRUE = voie maintenue)
    ArmPulse_Cmd    : BOOL; // <-- [ACT]  Impulsion rearmement physique (1s)
END_STRUCT
END_TYPE
