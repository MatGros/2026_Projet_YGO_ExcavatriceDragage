(* =======================================================================
   ⚙️ E_MachineHomingTxState — Steps du GRAFCET de referencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Role : Machine a etats sequentielle (GRAFCET) en 5 etapes du cycle
             de homing machine M1/M2/benne pilote par FB_CycleMachineHoming.
   📄 Doc : DOC/WFLOW/MISE_EN_SERVICE/PLAN_REFONTE_GRAFCET_HOMING_20261118_v1.0.md
            + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE E_MachineHomingTxState :
(
    HX0_REPOS          := 0,   (* Repos : N1 libre bloque si NOT Homed, M3 bloque N1/SEMI, attente 5s BP joy N1 ou BtnStart N2 *)
    HX1_BUCKET_PREPARE := 1,   (* M2 seul palier 1, ouv + ferm sans butees soft, garde continue 20s + decompte, BtnValidate neutre *)
    HX2_CLIMB_TO_TOP   := 2,   (* Couple M1+M2 palier 1 : montee lente + detente 2s max/geste, viser avant TOP sans toucher *)
    HX3_TOP_CLEARANCE  := 3,   (* Contact TOP = perdu/surcourse -> montee interdite, descente ~4s apres relachement TOP -> retour HX1 *)
    HX4_FINAL_CONFIRM  := 4,   (* Arret avant TOP + avertissement -> BtnValidate neutre -> preset 8.5m M1+M2 + CommitClose -> Homed *)
    HX7_FAILED         := 5    (* Echec / abandon : coupure mouvements, purge etats, attente Reset conscient *)
);
END_TYPE
