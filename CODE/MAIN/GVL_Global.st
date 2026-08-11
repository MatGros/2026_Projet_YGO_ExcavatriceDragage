(* ═══════════════════════════════════════════════════════════════
   🌐 GVL_Global — Variables globales d'utilité générale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les signaux et horloges système partagés qui
      ne sont pas spécifiques à la logique de simulation ni raccordés
      à des calibrations persistantes.
   🔧 REX 2026-07-16 : BlinkClock1Hz renommé BlinkClock — alimenté via Util.BLINK
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

    // ── [COMMANDES FINALES ET INTERLOCKS RECOPIÉS DE PRG_10_Outputs_LD] ──────────────────────────
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
(* 🗑️ REX LOT_STRUCTURE_INTERLOCKS_LD (2026-08) : instWinchOutputInterlockM1_LD /
   M2_LD / instTranslationOutputInterlock_LD retirés d'ici — c'étaient des
   instances FB déclarées mais JAMAIS appelées (orphelines, check_linkage L13-FB).
   Les instances réelles vivent maintenant dans PRG_06_Outputs_LD (seul
   producteur), qui publie déjà leurs sorties utiles (M1RelayFwd...) recopiées
   ci-dessus. Une deuxième instance ici aurait dupliqué l'état sans jamais
   être appelée : source de confusion, pas de valeur ajoutée. *)
