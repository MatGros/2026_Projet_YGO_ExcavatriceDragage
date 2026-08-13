(* ═══════════════════════════════════════════════════════════════
   🩺 ST_InputModuleDiagHMI — Diagnostic carte des modules DI TOR réelles
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.2.md §3bis
   🎨 Granularité MODULE (pas canal) : GetDeviceState() est un état de carte,
      pas un diagnostic par voie. Un module en défaut ne dit pas *quelle*
      TOR ment, seulement qu'aucune des TOR qu'il porte n'est fiable.
   🔗 Producteur : PRG_02_Acquisition (3 appels GetDeviceState()).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_InputModuleDiagHMI :
STRUCT
    LocalDigitalIoOk : BOOL; (* TRUE = module Local_Digital_IO opérationnel (8 TOR Winch/Machine) *)
    Vh0800EndOk      : BOOL; (* TRUE = module VH_0800END opérationnel (7 TOR freins/thermiques/AU) *)
    Vh0808EtpOk      : BOOL; (* TRUE = module VH_0808ETP opérationnel (7 TOR positions M3/hydraulique/crible) *)
    Fault            : BOOL; (* TRUE = au moins un des 3 modules DI hors service *)
END_STRUCT
END_TYPE
