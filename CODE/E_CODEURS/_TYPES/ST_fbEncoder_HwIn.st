(* =======================================================================
   🔌 ST_fbEncoder_HwIn — Faits hardware d'entrée codeur (HwIn)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les SEULES entrées/faits hardware d'un codeur absolu
      EtherCAT consommés par FB_Encoder (lecture seule côté automate).
   🔒 Ownership : PRG_02_Acquisition câble ce bus depuis le device/simulé.
   🛡️ PresetStatusBit : bit du mot d'état codeur, réservé site futur —
      câblé à FALSE tant qu'aucun bit n'est identifié (aucun signal absent
      ne confirme implicitement le preset).
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

TYPE ST_fbEncoder_HwIn :
STRUCT
    // === ENTRÉES BUS ETHERCAT (faits d'entrée, lecture seule) ===
    RawPosIn           : UDINT; // --> [HW] Position brute codeur
    SpdValueIn         : DINT;  // --> [HW] Vitesse brute codeur (0x6031:01 en 0.1 RPM)
    AlarmsIn           : UINT;  // --> [HW] Alarmes brutes codeur
    WarningsIn         : UINT;  // --> [HW] Avertissements bruts codeur
    SlaveOperational   : BOOL;  // --> [HW] Esclave EtherCAT operationnel
    PresetStatusBit    : BOOL;  // --> [HW] Bit d'etat preset optionnel, FALSE si non cable
END_STRUCT
END_TYPE
