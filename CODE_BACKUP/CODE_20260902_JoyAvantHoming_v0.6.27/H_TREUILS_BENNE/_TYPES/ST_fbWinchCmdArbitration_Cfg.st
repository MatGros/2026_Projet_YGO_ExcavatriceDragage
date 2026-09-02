(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_fbWinchCmdArbitration_Cfg — Config treuil (partagé M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Config statique de FB_WinchCmdArbitrationM1/M2.
       Structure UNIQUE partagée : M1 consomme BtnStepTgt (boutons/both),
       M2 consomme BtnStepTgt (boutons/both) + BucketOverrideStepTgt (chemin benne).
   📤 Producteur : PRG_04_Treuils_Benne (câblage).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Remplace les paliers codés en dur (StepTgt := 5 / StepTgt := 1) par des constantes nommées.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbWinchCmdArbitration_Cfg :
STRUCT
    BtnStepTgt : INT := 5;  // --> [CFG] Palier boutons/both (100 % → palier max)
    BucketOverrideStepTgt : INT := 1;  // --> [CFG] Palier override benne (vitesse lente)
END_STRUCT
END_TYPE
