(* =======================================================================
   🔀 ST_SyncContactorDiag — Diagnostic discordance contacteurs M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : dire EN CLAIR quel contacteur diverge entre M1 et M2 et à quel
      niveau on est (aucun / mismatch confirmé / escalade). Consommé par le
      bandeau IHM et le troubleshooting pour répondre « pourquoi ça bloque ».
   🔒 Bits nommés (pas de masque hexa, AF03 §4). Plusieurs bits peuvent être
      TRUE simultanément (toutes les divergences détectées).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_SyncContactorDiag :
STRUCT
    RelayFwdMismatch : BOOL; // TRUE = relais montée M1 <> M2
    RelayRevMismatch : BOOL; // TRUE = relais descente M1 <> M2
    Step1Mismatch    : BOOL; // TRUE = contacteur palier 1 M1 <> M2
    Step2Mismatch    : BOOL; // TRUE = contacteur palier 2 M1 <> M2
    Step3Mismatch    : BOOL; // TRUE = contacteur palier 3 M1 <> M2
    Step4Mismatch    : BOOL; // TRUE = contacteur palier 4 M1 <> M2
    MismatchLevel    : INT;  // 0 = aucun · 1 = discordance confirmée (SafeStop) · 2 = escalade (PowerCutOff)
END_STRUCT
END_TYPE
