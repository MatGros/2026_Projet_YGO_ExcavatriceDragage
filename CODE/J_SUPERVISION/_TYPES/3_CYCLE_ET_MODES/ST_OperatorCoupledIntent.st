(* =======================================================================
   🎮 ST_WinchBothIntent — Intention both continue de l'opérateur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Transmet l'intention de mouvement both (2 treuils ensemble,
      homme-mort / boutons) produite inconditionnellement par PRG_03 vers
      PRG_04 et l'arbitrage (tous modes). Source UNIQUE de la décision both.
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_WinchBothIntent :
STRUCT
    Active    : BOOL; // Intention both active (homme-mort qualifié + Select=0 OU boutons BothUp/BothDown)
    Direction : INT;  // Sens d'intention (-1: Descending, 0: Neutre, +1: Ascending)
END_STRUCT
END_TYPE
