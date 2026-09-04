(* =======================================================================
   🔌 ST_fbMachineHomingCycle_HomingDemand — Demande de homing conjoint vers un axe
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Ordre de prise d'origine emis par FB_CycleMachineHoming vers
             une facade FB_Encoder. M1 : cible configuree. M2 : cible
             geometrique dynamique (top M1 configure +/- offset benne),
             jamais une position M1 live.
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
TYPE ST_fbMachineHomingCycle_HomingDemand :
STRUCT
    HomeReq          : BOOL;   (* Demande de prise d'origine pour cet axe (vocab reserve Homing) *)
    UseDynamicTarget : BOOL;   (* TRUE => cible = DynamicTarget_M (M2 uniquement) *)
    DynamicTarget_M  : REAL;   (* Cible geometrique benne (m) : CfgTopHomingTargetM + offset *)
END_STRUCT
END_TYPE
