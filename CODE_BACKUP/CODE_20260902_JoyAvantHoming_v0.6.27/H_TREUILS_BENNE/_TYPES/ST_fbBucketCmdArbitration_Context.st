(* ═══════════════════════════════════════════════════════════════
   🧩 ST_fbBucketCmdArbitration_Context — Contexte de gating benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les faits de gating consommés par FB_BucketCmdArbitration
       pour le séquencement couplé benne (config, intention both, état benne).
       Le FB dérive les flags armés (WinchBothDiveBucketOpenArmed /
       WinchBothAscentBucketCloseArmed) et les commandes arbitrées.
   📤 Producteur : PRG_04_Treuils_Benne (câblage).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 État benne : 2 bits BOOL (BucketIsOpen/Closed) dérivés de _BucketState.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbBucketCmdArbitration_Context :
STRUCT
    TglEnableCoupledBucketSequencing : BOOL;  // --> [CFG] Activation séquencement couplé benne (Commun.Cfg)
    MotionActive                     : BOOL;  // --> [CMD] Intention mouvement both active (WinchBothMotionActive)
    ReqAscent                        : BOOL;  // --> [CMD] Intention both montée
    ReqDescend                       : BOOL;  // --> [CMD] Intention both descente
    BucketIsOpen                     : BOOL;  // --> [STAT] Benne ouverte (BucketState.IsOpen)
    BucketIsClosed                   : BOOL;  // --> [STAT] Benne fermée (BucketState.IsClosed)
END_STRUCT
END_TYPE
