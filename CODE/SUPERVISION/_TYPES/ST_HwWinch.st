(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HwWinch — Image matérielle brute des entrées Treuils M1 / M2
   ───────────────────────────────────────────────────────────────
   📄 Lot L5 (Frontière unique HwIn)
   🎨 Regroupe les signaux physiques d'entrée bruts des treuils M1 et M2.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HwWinch :
STRUCT
    M1_ContactorsReleased_DI : BOOL; (* Retours contacteurs M1 retombés *)
    M1_ThermalOk_DI          : BOOL; (* Thermique moteur M1 OK *)
    M1_BrakeIsOpen_DI        : BOOL; (* Retour frein M1 (1 = ouvert) *)
    
    M2_ContactorsReleased_DI : BOOL; (* Retours contacteurs M2 retombés *)
    M2_ThermalOk_DI          : BOOL; (* Thermique moteur M2 OK *)
    M2_BrakeIsOpen_DI        : BOOL; (* Retour frein M2 (1 = ouvert) *)
    
    M1M2_TopPositionFree_DI  : BOOL; (* Capteur position haute commun M1/M2 libre *)
    M2_TensionedCable_DI     : BOOL; (* Capteur mou de câble M2 (câble tendu) *)
    
    COD1_PosValue            : UDINT;        (* Valeur brute position codeur COD1 (M1) *)
    COD1_Alarms              : UINT;         (* Alarmes brutes COD1 *)
    COD1_Warnings            : UINT;         (* Avertissements bruts COD1 *)
    COD1_DeviceState         : DEVICE_STATE; (* État device COD1 (GetDeviceState) *)
    
    COD2_PosValue            : UDINT;        (* Valeur brute position codeur COD2 (M2) *)
    COD2_Alarms              : UINT;         (* Alarmes brutes COD2 *)
    COD2_Warnings            : UINT;         (* Avertissements bruts COD2 *)
    COD2_DeviceState         : DEVICE_STATE; (* État device COD2 (GetDeviceState) *)
END_STRUCT
END_TYPE
