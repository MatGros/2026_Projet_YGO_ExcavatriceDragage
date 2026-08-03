(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationRequestPublisher — Contrat M3 vers Outputs
   ───────────────────────────────────────────────────────────────
   📄 Migration M4 : encapsule l'assemblage de
      ST_TranslationFinalInterlockRequest hors de la page CFC native.
   🔒 Ne produit qu'une demande brute; PRG_06_Outputs_LD reste l'unique
      propriétaire des commandes physiques AC600 et du frein.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationRequestPublisher
VAR_INPUT
    Enable                      : BOOL;
    Reset                       : BOOL;
    PowerContactorEngaged       : BOOL;
    SafeStop                    : BOOL;
    BrakeReleaseRequest         : BOOL;
    BrakeCommandOpenConfirmed   : BOOL;
    RequestedDriveControlWord   : WORD;
    RequestedDriveFreqHz        : REAL;
END_VAR
VAR_OUTPUT
    Request                     : ST_TranslationFinalInterlockRequest;
END_VAR

Request.Enable := Enable;
Request.Reset := Reset;
Request.PowerContactorEngaged := PowerContactorEngaged;
Request.SafeStop := SafeStop;
Request.BrakeReleaseRequest := BrakeReleaseRequest;
Request.BrakeCommandOpenConfirmed := BrakeCommandOpenConfirmed;
Request.RequestedDriveControlWord := RequestedDriveControlWord;
Request.RequestedDriveFreqHz := RequestedDriveFreqHz;
