(* ═══════════════════════════════════════════════════════════════
   📏 ST_EncoderMeasurement — Mesures codeur qualifiées (1 sous-DUT par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 · Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md §2ter
   🎨 Facts de la chaîne de mesure pure : Abs → Scale → Safety → SpeedMeasure.
   🔗 Producteur : PRG_02_Acquisition_CFC (chaîne codeur du treuil concerné).
   ✅ Tout BOOL = TRUE état normalisé. Aucun brut EtherCAT (alarmes/warnings,
      DEVICE_STATE) : ils restent exposés via ST_EncoderHMI (Supervision).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EncoderMeasurement :
STRUCT
    RawPos           : UDINT; (* Position brute codeur — gelée si EncoderAvailable=FALSE *)
    EncoderAvailable : BOOL;  (* TRUE = bus/esclave opérationnel *)
    CablePosM        : REAL;  (* Position câble (m, signée, + enroulé) *)
    CablePosMSafe    : REAL;  (* Position câble bornée [-99;+99] m — gelée sur doute *)
    EncoderIncoherent: BOOL;  (* TRUE = incohérence redémarrage → refuse SEMI_AUTO *)
    Speed_Mps        : REAL;  (* Vitesse absolue (m/s) — 0.0 si SpeedValid=FALSE *)
    SignedSpeed_Mps  : REAL;  (* Vitesse signée (m/s, + montée) — 0.0 si SpeedValid=FALSE *)
    SpeedValid       : BOOL;  (* TRUE si ≥ 6 éch. couvrant 50 ms *)
END_STRUCT
END_TYPE
