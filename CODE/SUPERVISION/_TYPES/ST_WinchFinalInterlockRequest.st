(* ═══════════════════════════════════════════════════════════════
   🪝 ST_WinchFinalInterlockRequest — Demande brute vers frontière Q M1/M2
   ───────────────────────────────────────────────────────────────
   📤 Producteur unique : PRG_06_WinchControl (VAR_OUTPUT).
   📥 Consommateur unique : PRG_10_Outputs_LD, avant FB_WinchOutputInterlock_LD.
   🔒 Ne contient jamais une sortie Q autorisée : les C1..C4 restent les
      demandes exactes de FB_Winch / ST_SpeedStepTable.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_WinchFinalInterlockRequest :
STRUCT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL; // TRUE = contacteur/bobine desserrage confirmé
    FwdRevSpeedFeedbackOff       : BOOL; // TRUE = relais sens + C1..C4 tous retombés
    RequestedRelayFwd            : BOOL;
    RequestedRelayRev            : BOOL;
    RequestedContactor1          : BOOL;
    RequestedContactor2          : BOOL;
    RequestedContactor3          : BOOL;
    RequestedContactor4          : BOOL;
    RequestedStep                : INT;
END_STRUCT
END_TYPE
