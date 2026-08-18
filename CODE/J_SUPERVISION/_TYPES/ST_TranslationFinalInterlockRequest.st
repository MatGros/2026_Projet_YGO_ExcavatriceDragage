(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationFinalInterlockRequest — Demande brute vers PDO M3
   ───────────────────────────────────────────────────────────────
   📤 Producteur unique : PRG_05_Translation (VAR_OUTPUT).
   📥 Consommateur unique : PRG_06_Outputs_LD, avant
      FB_TranslationOutputInterlock_LD.
   🔒 Ne contient jamais une commande PDO autorisée.
   PowerCutOff : demande safety M3 (FB_Safety_Translation).
      FIX : consommée par PRG_06_Outputs_LD comme SEULE cause de coupure
      d'Enable (barrière finale) — SafeStop n'y est plus lu, il reste géré en amont
      par FB_Translation (rampe rapide, Enable maintenu, AF06 §5).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_TranslationFinalInterlockRequest :
STRUCT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    PowerCutOff                  : BOOL; // 🧨 Demande coupure puissance (FB_Safety_Translation) — consommée par PRG_06_Outputs_LD (Enable)
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL; // TRUE = contacteur/bobine desserrage confirmé
    RequestedDriveControlWord    : WORD; // 0=None, 1=Fwd, 2=Rev, 7=Reset AC600
    RequestedDriveFreqHz         : REAL;
END_STRUCT
END_TYPE
