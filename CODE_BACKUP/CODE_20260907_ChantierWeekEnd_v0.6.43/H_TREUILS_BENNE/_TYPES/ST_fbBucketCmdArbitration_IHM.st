(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_fbBucketCmdArbitration_IHM — Entrées IHM de l'arbitrage benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes IHM consommées par FB_BucketCmdArbitration
       (boutons ouverture/fermeture benne, nommage hardware propagé).
   📤 Producteur : PRG_04_Treuils_Benne (câblage GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Nommage : BtnOpen/BtnClose = nommage hardware propagé (convention projet).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbBucketCmdArbitration_IHM :
STRUCT
    BtnOpen  : BOOL;  // --> [CMD] Bouton ouverture benne (M2TreuilBenne.Bucket.Cmd.BtnOpen)
    BtnClose : BOOL;  // --> [CMD] Bouton fermeture benne (M2TreuilBenne.Bucket.Cmd.BtnClose)
END_STRUCT
END_TYPE
