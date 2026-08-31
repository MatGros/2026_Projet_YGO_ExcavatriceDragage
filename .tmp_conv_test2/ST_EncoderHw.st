(* ═══════════════════════════════════════════════════════════════
   🔌 ST_EncoderHw — Frontière hardware codeur (IN/OUT)
   ───────────────────────────────────────────────────────────────
   🎯 Regroupe les entrées/sorties hardware d'un codeur absolu EtherCAT
      pour exposer l'interface physique de FB_Encoder de façon testable.
   🔌 Producteur/consommateur : PRG_02_Acquisition câble ce bus vers le device.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EncoderHw :
STRUCT
    // === ENTREES BUS ETHERCAT (vers le codeur) ===
    RawPosIn            : UDINT;        // Position brute EtherCAT (in)
    AlarmsIn            : UINT;        // Codes alarmes bruts EtherCAT
    WarningsIn          : UINT;        // Codes avertissements bruts EtherCAT
    SlaveOperational    : BOOL;        // Esclave EtherCAT operationnel
    PresetAck           : BOOL;        // Pulse confirmation preset reussi
    PresetNak           : BOOL;        // Pulse echec / timeout preset

    // === SORTIES BUS (vers le codeur) ===
    PresetTriggerCmd    : WORD;        // Ordre declenchement preset vers PDO Rx
    CodeSeqTriggerCmd   : WORD;        // Ordre sequence code vers PDO Rx
    PresetValueOut      : UDINT;       // Valeur de preset transmise au PDO Rx
END_STRUCT
END_TYPE
