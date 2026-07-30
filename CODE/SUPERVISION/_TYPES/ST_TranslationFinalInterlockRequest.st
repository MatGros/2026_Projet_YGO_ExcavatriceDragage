(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationFinalInterlockRequest — Demande brute vers PDO M3
   ───────────────────────────────────────────────────────────────
   📤 Producteur unique : PRG_07_TranslationControl (VAR_OUTPUT).
   📥 Consommateur unique : PRG_10_Outputs_LD, avant
      FB_TranslationOutputInterlock_LD.
   🔒 Ne contient jamais une commande PDO autorisée.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_TranslationFinalInterlockRequest :
STRUCT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL; // TRUE = contacteur/bobine desserrage confirmé
    RequestedDriveControlWord    : WORD; // 0=None, 1=Fwd, 2=Rev, 7=Reset AC600
    RequestedDriveFreqHz         : REAL;
END_STRUCT
END_TYPE
