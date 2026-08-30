(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_fbWinchCmdArbitration_Cfg — Config treuil (partagé M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Config statique de FB_WinchCommandArbitrationM1/M2.
       Structure UNIQUE partagée : M2 consomme BucketOverrideSpeedPct (chemin benne),
       M1 l'ignore (pas de chemin benne).
   📤 Producteur : PRG_04_Treuils_Benne (câblage).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Remplace le littéral 15.0 (PRG_04 §3) par une constante nommée.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbWinchCmdArbitration_Cfg :
STRUCT
    BucketOverrideSpeedPct : REAL := 15.0;  // --> [CFG] Vitesse M2 pendant action benne (ex littéral 15.0)
END_STRUCT
END_TYPE
