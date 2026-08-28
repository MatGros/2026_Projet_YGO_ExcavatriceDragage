(* =======================================================================
   🎮 ST_OperatorCoupledIntent — Intention couplée continue de l'opérateur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Transmet l'intention de mouvement couplé (homme-mort / boutons)
      produite inconditionnellement par PRG_03 vers PRG_04 (tous modes).
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_OperatorCoupledIntent :
STRUCT
    Active    : BOOL; // Intention couplée active (JoyBtnRaw + Select=0 OU boutons BothUp/BothDown)
    Direction : INT;  // Sens d'intention (-1: Descente, 0: Neutre, +1: Montée)
END_STRUCT
END_TYPE
