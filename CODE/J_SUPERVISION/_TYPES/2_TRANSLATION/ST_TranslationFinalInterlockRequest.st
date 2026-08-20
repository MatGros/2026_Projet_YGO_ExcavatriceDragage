(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationFinalInterlockRequest — Demande brute vers PDO M3
   ───────────────────────────────────────────────────────────────
   📤 Producteur unique : PRG_05_Translation (VAR_OUTPUT).
   📥 Consommateur unique : PRG_06_Outputs, avant
      FB_TranslationOutputInterlock.
   🔒 Ne contient jamais une commande PDO autorisée.
   PowerCutOff : demande safety M3 (FB_Safety_Translation).
      Consommée par PRG_06_Outputs comme SEULE cause de coupure
      d'Enable (barrière finale). SafeStop est géré en amont
      par FB_Translation (rampe rapide, Enable maintenu, AF06 §5).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_TranslationFinalInterlockRequest :
STRUCT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    PowerCutOff                  : BOOL; // 🧨 Demande coupure puissance (FB_Safety_Translation) — consommée par PRG_06_Outputs (Enable)
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL; // TRUE = contacteur/bobine desserrage confirmé
    RequestedDriveControlWord    : WORD; // 0=None, 1=Fwd, 2=Rev, 7=Reset AC600
    RequestedDriveFreqHz         : REAL;
END_STRUCT
END_TYPE
