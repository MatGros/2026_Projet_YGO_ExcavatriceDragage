(* =======================================================================
   ⚙️ E_MachineHomingTxState — Etats de la transaction de referencement conjoint
   ───────────────────────────────────────────────────────────────
   🎯 Role : Machine a etats de la transaction homing M1/M2 (FB_MachineHomingCycle §4/§5).
             Distincte de E_MachineHomingStep (echelle de priorite du guide operateur).
   📄 Doc metier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE E_MachineHomingTxState :
(
    IDLE          := 0,   (* Aucune transaction : attente d'un front de confirmation dans la fenetre sure *)
    ARMED         := 1,   (* Demande homing conjoint emise (HomeReq M1+M2) ; attente qu'un axe passe Busy *)
    BUSY_OBSERVED := 2    (* Au moins un axe a ete vu Busy ; attente des 2 succes -> commit atomique *)
);
END_TYPE
