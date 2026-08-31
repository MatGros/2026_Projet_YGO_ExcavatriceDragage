(* ═══════════════════════════════════════════════════════════════
   🧩 ST_fbWinchCmdArbitration_Context — Contexte de gating treuil (partagé M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les faits de gating consommés par FB_WinchCommandArbitrationM1/M2
       (benne, synchro, blocage both). Structure UNIQUE partagée par les 2 axes,
       identifiée par l'instance : M1 ignore le chemin benne, M2 le consomme.
   📤 Producteur : PRG_04_Treuils_Benne (câblage).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Action benne : 2 bits BOOL (BucketM2Open/Close) dérivés de instBucket.M2_Direction.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbWinchCmdArbitration_Context :
STRUCT
    BucketBusy                     : BOOL;  // --> [STAT] Action benne en cours (instBucket.Lifecycle.Busy)
    BucketM2StartStop              : BOOL;  // --> [CMD] Commande M2 par la benne active (instBucket.M2_StartStop)
    BucketM2Open                   : BOOL;  // --> [CMD] Ouverture benne (instBucket.M2_Direction = 1)
    BucketM2Close                  : BOOL;  // --> [CMD] Fermeture benne (instBucket.M2_Direction = -1)
    WinchBothMotionBlockedByBucket : BOOL;  // --> [STAT] Mouvement both bloqué par benne (ex CoupledMotionBlockedByBucket)
    SyncBlocksAscent                   : BOOL;  // --> [STAT] Synchro bloque la montée (SyncMinorDeviationBlocksUp)
    SyncBlocksDescent                 : BOOL;  // --> [STAT] Synchro bloque la descente (SyncMinorDeviationBlocksDown)
END_STRUCT
END_TYPE
