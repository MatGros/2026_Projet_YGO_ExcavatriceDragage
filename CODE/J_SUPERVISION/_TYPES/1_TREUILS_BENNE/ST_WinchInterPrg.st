(* ═══════════════════════════════════════════════════════════════
   🪝 ST_WinchInterPrg — Bus d'échange inter-PRG produit par PRG_04_Treuils_Benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les demandes finales M1/M2, les états publics
      WinchM1/M2State, les sécurités WinchM1/M2Safety, l'état synchro et
      l'état benne publiés par PRG_04_Treuils_Benne vers les consommateurs
      (PRG_02/03/06/07).
   📤 Producteur unique : PRG_04_Treuils_Benne (VAR_OUTPUT Data : ST_WinchInterPrg).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_WinchInterPrg :
STRUCT
    // === ⚡ Demandes finales M1/M2 (interlocks & consigne vitesse arbitrée) ===
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest; // 🪝 Demande finale et interlocks treuil M1
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest; // 🪝 Demande finale et interlocks treuil M2
    M1LogicRequestSpeedRef_Pct   : REAL; // 📈 Consigne vitesse M1 arbitree (%) — consommee par FB_SimBench (PRG_02)
    M2LogicRequestSpeedRef_Pct   : REAL; // 📈 Consigne vitesse M2 arbitree (%) — consommee par FB_SimBench (PRG_02)

    // === 📊 États publics des treuils ===
    WinchM1State                 : ST_WinchState; // 🚦 Etat public treuil Retenue M1
    WinchM2State                 : ST_WinchState; // 🚦 Etat public treuil Benne M2

    // === 🛡️ Sécurités des treuils ===
    WinchM1Safety                : ST_SafetyWinch; // 🛡️ Diagnostic et securites treuil M1
    WinchM2Safety                : ST_SafetyWinch; // 🛡️ Diagnostic et securites treuil M2

    // === 🔄 État synchronisation ===
    SyncState                    : ST_SyncState; // 🔄 Etat synchronisation treuils M1/M2

    // === 🏗️ État benne ===
    BucketState                  : ST_BucketHMIState; // 🏗️ Etat de fonctionnement benne
    Benne_IsRoughlyClosed        : BOOL;               // 🏗️ Benne consideree fermee (tolerance matiere)
END_STRUCT
END_TYPE
