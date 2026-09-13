(* =======================================================================
   ST_IoHw_Out — Image exhaustive des sorties hardware pour visualisation IHM
   -----------------------------------------------------------------------
   Producteur : PRG_07_Supervision (recopie de PRG_06/PRG_02).
   Rôle : observation PLC→IHM uniquement. Ces champs ne sont jamais des
   consignes écrites par l'IHM et ne constituent pas un retour électrique.
   ======================================================================= *)
TYPE ST_IoHw_Out :
STRUCT
    Logical : ST_OutputsInterPrg; // Commandes finales logiques effectivement produites

    // Local_Digital_IO — sorties relais direction M1/M2
    M1_RelayAscent_DQ        : BOOL;
    M1_RelayDescent_DQ       : BOOL;
    M2_RelayAscent_Close_DQ  : BOOL;
    M2_RelayDescent_Open_DQ  : BOOL;

    // VH_0808ETP — contacteurs de vitesse M1/M2
    M1_SpeedContactor_1_DQ : BOOL;
    M1_SpeedContactor_2_DQ : BOOL;
    M1_SpeedContactor_3_DQ : BOOL;
    M1_SpeedContactor_4_DQ : BOOL;
    M2_SpeedContactor_1_DQ : BOOL;
    M2_SpeedContactor_2_DQ : BOOL;
    M2_SpeedContactor_3_DQ : BOOL;
    M2_SpeedContactor_4_DQ : BOOL;

    // VH_0008ER — freins et mesure Kobold
    M1_BrakeRelease_RQ           : BOOL;
    M2_BrakeRelease_RQ           : BOOL;
    M3_BrakeRelease_RQ           : BOOL;
    M1_M2_KoboldMeasureEnable_DQ : BOOL;

    // VH_0008ER_1 — réarmement AU et maintien puissance
    EmergencyArming_RQ   : BOOL;
    PowerKeepAlive_A_RQ  : BOOL;
    PowerKeepAlive_B_RQ  : BOOL;

    // EtherCAT — PDO de sortie codeurs COD1/COD2
    COD1_PresettTrigCmd : WORD;
    COD1_CodeSeqTrigCmd : WORD;
    COD1_PresetValue    : UDINT;
    COD2_PresettTrigCmd : WORD;
    COD2_CodeSeqTrigCmd : WORD;
    COD2_PresetValue    : UDINT;

    // EtherCAT — PDO de sortie variateur AC600
    M3_CommandWord        : WORD;
    M3_SetpointFrequencyHz : WORD;
END_STRUCT
END_TYPE
