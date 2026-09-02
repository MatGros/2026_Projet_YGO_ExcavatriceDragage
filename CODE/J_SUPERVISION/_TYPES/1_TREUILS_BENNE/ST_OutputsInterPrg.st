(* ═══════════════════════════════════════════════════════════════
   📤 ST_OutputsInterPrg — Bus d'échange inter-PRG produit par PRG_06_Outputs
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les ordres actionneurs finaux (M1/M2/M3, AU) produits
      par PRG_06_Outputs et rebouclés par FB_SimBench (instancié dans
      PRG_02_Acquisition) pour le banc de simulation intégré.
   📤 Producteur unique : PRG_06_Outputs (VAR_OUTPUT Data : ST_OutputsInterPrg).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §5
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_OutputsInterPrg :
STRUCT
    // === 🪝 Ordres actionneurs finaux treuil M1 ===
    M1RelayFwd            : BOOL; // 🛗 Ordre contacteur montee treuil M1
    M1RelayRev            : BOOL; // 🛗 Ordre contacteur descente treuil M1
    M1SpeedContactor1     : BOOL; // 🔌 Ordre contacteur palier 1 treuil M1
    M1SpeedContactor2     : BOOL; // 🔌 Ordre contacteur palier 2 treuil M1
    M1SpeedContactor3     : BOOL; // 🔌 Ordre contacteur palier 3 treuil M1
    M1SpeedContactor4     : BOOL; // 🔌 Ordre contacteur palier 4 treuil M1
    M1BrakeCmd            : BOOL; // 🔓 Ordre desserrage frein M1 (1=Desserrer)

    // === 🪝 Ordres actionneurs finaux treuil M2 ===
    M2RelayFwd            : BOOL; // 🛗 Ordre contacteur montee/fermeture treuil M2
    M2RelayRev            : BOOL; // 🛗 Ordre contacteur descente/ouverture treuil M2
    M2SpeedContactor1     : BOOL; // 🔌 Ordre contacteur palier 1 treuil M2
    M2SpeedContactor2     : BOOL; // 🔌 Ordre contacteur palier 2 treuil M2
    M2SpeedContactor3     : BOOL; // 🔌 Ordre contacteur palier 3 treuil M2
    M2SpeedContactor4     : BOOL; // 🔌 Ordre contacteur palier 4 treuil M2
    M2BrakeCmd            : BOOL; // 🔓 Ordre desserrage frein M2 (1=Desserrer)

    // === 🔀 Concordance contacteurs M1/M2 (instance FB_SyncContactor sur vecteurs finaux) ===
    ContactorMismatch          : BOOL;                  // Niveau 1 confirmé (debounce 500 ms) → SafeStop des 2 treuils (PRG_04, scan N-1)
    ContactorMismatchEscalated : BOOL;                  // Niveau 2 persistant → escalade PowerCutOff via latch MecaE (PRG_04)
    SyncContactorDiag          : ST_SyncContactorDiag;  // Détail : quel contacteur diverge + niveau atteint (IHM / troubleshooting)

    // === ↔️ Ordre actionneur final translation M3 ===
    TranslationBrakeCmd   : BOOL; // 🔓 Demande frein M3 arbitree

    // === 🚦 Disponibilite mouvement barriere finale ===
    // TRUE = une tempo idle / inhibition de l'interlock final interdit REELLEMENT de bouger maintenant
    // (FB non pret, anti-court-cycle, temps mort directionnel, contacteur colle). N'arrete rien.
    M1MovementInhibited   : BOOL; // 🚦 Treuil M1 — mouvement inhibe par tempo interlock final
    M2MovementInhibited   : BOOL; // 🚦 Treuil M2 — mouvement inhibe par tempo interlock final
    M3MovementInhibited   : BOOL; // 🚦 Translation M3 — mouvement inhibe par tempo interlock final

    // === 🚨 Chaîne réarmement puissance AU ===
    PowerKeepAliveACmd    : BOOL; // 🔒 Maintien puissance voie A (1=Maintenu)
    PowerKeepAliveBCmd    : BOOL; // 🔒 Maintien puissance voie B (1=Maintenu)
    EmergencyArmingCmd    : BOOL; // 🎯 Impulsion rearmement puissance AU
    TestCutActive         : BOOL; // 🧪 Test de redondance AU en cours (canal A ou B coupe) — consommé par FB_SimBench
    PowerCutOffRequest    : BOOL; // 🛑 Requête coupure métier (arrêt d'urgence) — consommé par FB_SimBench
END_STRUCT
END_TYPE
