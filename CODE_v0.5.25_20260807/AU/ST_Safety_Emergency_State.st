(* ═══════════════════════════════════════════════════════════════
   🚦 ST_Safety_Emergency_State — État public de la chaîne d'arrêt d'urgence
   ───────────────────────────────────────────────────────────────
   📄 Produit par FB_Safety_EmergencyManagement (sortie State).
      Consommé par PRG_SUPERVISION_CFC → GVL_IHM.Modes.State pour IHM,
      et par GVL_Troubleshooting pour diagnostic.
   🎯 Champs lecture seule — aucun lecteur n'est autorisé à l'écrire.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md §8.2
              DOC/AF_Partie-03_Contrats_Composants_v2.1.md
*)

TYPE ST_Safety_Emergency_State :
STRUCT
    ChainOk          : BOOL;   // 🔗 Boucle AU fermée (EmergencyChainClosed_DI = TRUE)
    ContactorOk      : BOOL;   // 🔌 Contacteur puissance confirmé engagé (PowerContactorEngaged_DI = TRUE)
    Step             : INT;    // 🔢 Étape séquence armement : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    Armable          : BOOL;   // 🟢 Réarmement possible maintenant : chain OK, step=0, pas de lockout, pas de redondance échouée, pas de contacteur déjà engagé
    ArmingBusy       : BOOL;   // ⏳ Séquence armement OU lockout en cours (nouvelle demande ignorée)
END_STRUCT
END_TYPE
