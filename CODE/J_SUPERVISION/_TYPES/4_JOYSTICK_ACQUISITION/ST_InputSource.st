(* ═══════════════════════════════════════════════════════════════
   🔀 ST_InputSource — Flags de bascule de source (réel/simu) par domaine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les 4 impulsions 1 cycle signalant qu'une source
      d'entrée a basculé (réel ↔ simu) pour un domaine donné.
   📤 Producteur unique : PRG_02_Acquisition (Data.InputSource).
   📥 Consommateur : PRG_07_Supervision (Data.InputSource.* → GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_InputSource :
STRUCT
    WinchInputSourceChanged       : BOOL; // 🔀 Source Winch a basculé (réel/simu)
    TranslationInputSourceChanged: BOOL; // 🔀 Source Translation a basculé
    OperatorInputSourceChanged   : BOOL; // 🔀 Source Opérateur a basculé
    MachineInputSourceChanged    : BOOL; // 🔀 Source Machine a basculé
END_STRUCT
END_TYPE
