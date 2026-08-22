(* ═══════════════════════════════════════════════════════════════
   🪝 ST_WinchFinalInterlockRequest — Demande brute vers frontière Q M1/M2
   ───────────────────────────────────────────────────────────────
   📤 Producteur unique : PRG_TREUILS_CFC (VAR_OUTPUT).
   📥 Consommateur unique : PRG_10_Outputs_LD, avant FB_WinchOutputInterlock.
   🔒 Ne contient jamais une sortie Q autorisée : les C1..C4 restent les
      demandes exactes de FB_Winch / ST_SpeedStepTable.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_WinchFinalInterlockRequest :
STRUCT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    BrakeFeedback                 : BOOL; // (retrait FB_Brake) : retour PHYSIQUE brut du
                                          // contacteur/bobine frein (TRUE = ouvert/relâché) — remplace
                                          // BrakeReleaseRequest/BrakeCommandOpenConfirmed ; la barrière
                                          // finale calcule elle-même BrakeCmd := RelayFwd OR RelayRev.
    FwdRevSpeedFeedbackOff       : BOOL; // TRUE = relais sens + C1..C4 tous retombés
    RequestedRelayFwd            : BOOL;
    RequestedRelayRev            : BOOL;
    RequestedContactor1          : BOOL;
    RequestedContactor2          : BOOL;
    RequestedContactor3          : BOOL;
    RequestedContactor4          : BOOL;
    RequestedStep                : INT;
    PowerCutOff                  : BOOL; // : demande coupure puissance (FB_Safety_Winch), agrégée par PRG_06 (M5, A-04)
END_STRUCT
END_TYPE
