(* =======================================================================
   ⚙️ E_MachineHomingStep — Etapes du guide de referencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Etat publie du guide de homing conjoint M1/M2/benne (IHM + interlocks)
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE E_MachineHomingStep :
(
    IDLE                 := 0,   (* Referencement indisponible (Enable=FALSE) *)
    LOSS_SAFESTOP        := 5,   (* Perte de datum en mouvement : arret controle en cours *)
    BOTH_NOT_HOMED       := 10,  (* Codeurs M1 et M2 non references : passer en MAINT_N2 *)
    M1_NOT_HOMED         := 11,  (* Codeur M1 non reference ou mesure douteuse : homer M1 *)
    M2_NOT_HOMED         := 12,  (* Codeur M2 non reference ou mesure douteuse : homer M2 *)
    OFFSET_UNKNOWN       := 20,  (* Offset benne inconnu : passer en MAINT_N2 *)
    NEED_TOP_POSITION    := 30,  (* Monter Both a vitesse lente jusqu au capteur haut *)
    NEED_MECHANICAL_STOP := 40,  (* Capteur haut atteint : relacher la commande et attendre l arret *)
    AWAIT_BUCKET_CONFIRM := 45,  (* Confirmer visuellement la benne : Fermee ou Ouverte *)
    HOMING_IN_PROGRESS   := 50,  (* Referencement conjoint M1/M2 en cours : ne pas manoeuvrer *)
    VALID                := 60,  (* Referencement machine valide : mode nominal disponible *)
    FAILED               := 70   (* Referencement incomplet : rester en N2 et recommencer *)
);
END_TYPE
