(* ═══════════════════════════════════════════════════════════════
   🌐 GVL_Global — Variables globales d'utilité générale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les signaux et horloges système partagés qui
      ne sont pas spécifiques à la logique de simulation ni raccordés
      à des calibrations persistantes.
   BlinkClock alimenté via Util.BLINK
      (asymétrique, durées réglables GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff,
      câblage dans PRG_SUPERVISION_CFC §0). Le nom "1Hz" n'a plus de sens dès que
      le rythme n'est pas symétrique 500ms/500ms.
   💡 Besoin d'un AUTRE rythme pour un voyant particulier (pas celui-ci) ?
      Instancier son propre `BLINK` (lib Util) localement plutôt que de détourner
      ce bit partagé — voir Partie3 §0 (réutilisation obligatoire des libs).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md
*)
{attribute 'qualified_only'}
VAR_GLOBAL
    BlinkClock                 : BOOL;          // Horloge clignotement système (IHM/diag), rythme réglable GVL_PERSISTENT

    // ── [COMMANDES FINALES ET INTERLOCKS] ──────────────────────────
    // Permet la lecture publique globale par PRG_00_Inputs, PRG_SAFETY_CFC, PRG_SUPERVISION_CFC et PRG_TROUBLESHOOTING_CFC
    M1RelayFwd                    : BOOL;
    M1RelayRev                    : BOOL;
    M1SpeedContactor1             : BOOL;
    M1SpeedContactor2             : BOOL;
    M1SpeedContactor3             : BOOL;
    M1SpeedContactor4             : BOOL;
    M1BrakeCmd                    : BOOL;
    M2RelayFwd                    : BOOL;
    M2RelayRev                    : BOOL;
    M2SpeedContactor1             : BOOL;
    M2SpeedContactor2             : BOOL;
    M2SpeedContactor3             : BOOL;
    M2SpeedContactor4             : BOOL;
    M2BrakeCmd                    : BOOL;
    TranslationBrakeCmd           : BOOL;
    EmergencyArmingPulseActive   : BOOL;
    EmergencyArmingLockoutActive: BOOL;
    ArmingSeqStep                : INT;
END_VAR
