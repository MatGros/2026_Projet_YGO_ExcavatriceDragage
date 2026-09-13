(* ═══════════════════════════════════════════════════════════════
   🩺 ST_IOModuleDiag — Diagnostic carte des 5 modules E/S physiques
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §3bis
   🎨 Granularité MODULE (pas canal) : GetDeviceState() est un état de carte,
      pas un diagnostic par voie. Un module en défaut ne dit pas *quelle*
      TOR ment, seulement qu'aucune des TOR qu'il porte n'est fiable.
   🔗 Producteur : PRG_02_Acquisition (5 appels GetDeviceState()).
   🔌 Consommateurs : PRG_04 (SafeStop treuils), PRG_05 (SafeStop M3),
      PRG_07 (recopie IHM GVL_IHM.Network.InputModules + FB_TroubleshootingView).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_IOModuleDiag :
STRUCT
    LocalDigitalIoOk : BOOL;  // Module Local_Digital_IO OK (DI8/DO8)
    Vh0800EndOk      : BOOL;  // Module VH_0800END OK (DI8)
    Vh0808EtpOk      : BOOL;  // Module VH_0808ETP OK (DI8/DO8)
    Vh0008ErOk       : BOOL;  // Module VH_0008ER OK (DO8 Relais Freins/Kobold)
    Vh0008Er1Ok      : BOOL;  // Module VH_0008ER_1 OK (DO8 Relais AU/PowerKeepAlive)
    Fault            : BOOL;  // Défaut sur au moins un module E/S
END_STRUCT
END_TYPE
