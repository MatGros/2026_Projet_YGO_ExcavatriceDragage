(* ═══════════════════════════════════════════════════════════════
   📥 FB_InputsMachine — Conditionnement ENTRÉES réelles de toute la machine (1 instance)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5 (historique détaillé : AUDIT
      D52/D60/D61/D64)
   🧭 Interface RÉDUITE (Partie3 §1bis) : compose FB_Input (_COMMON) pour TOUTES les entrées
      TOR réelles (Commun/Winch M1/Winch M2/Chariot M3). Référence DIRECTEMENT les I/O réels
      globales en interne (pas de `*Raw`/`Invert*` câblés depuis `PRG_MAIN`) et écrit ses
      sorties DIRECTEMENT dans `GVL_IN.Xxx` (noms courts, sans suffixe) — appelé SANS
      PARAMÈTRE, rien à récupérer en retour. `InvertLogic`/`ChannelOk` de chaque sous-instance
      restent à leur défaut (FALSE/TRUE) — à FORCER DIRECTEMENT sur la sous-instance en vue
      CODESYS pour inverser NO/NC en mise en service, sans recompiler.
   ℹ️ Note utilisateur : prévu pour être implémenté en LANGAGE LD (Ladder) dans CODESYS pour
      faciliter la maintenance — code ci-dessous = référence ST. `FilterTime` : valeurs
      indicatives (`T#20MS`), à ajuster par voie selon le besoin réel (rebond capteur).
   🔴 NON CÂBLÉS ICI (pas de FB consommateur — FB_Grappin n'existe pas encore) :
      `ConveyorInfeedReady_DI`, `GridDwn_RQ`/`GridUp_RQ`, `HelmetClose_RQ`/`HelmetOpen_RQ`,
      `PosCasque_DI`, `PosGrille_DI`, `ThermHydraulique_DI`.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_InputsMachine) ===

FUNCTION_BLOCK PUBLIC FB_InputsMachine
VAR
    // 🛑 Commun
    instEmergencyStopOk   : FB_Input;
    instSlackCableSwitch  : FB_Input;
    instTopPositionSensor : FB_Input;
    instCtrlPhaseRotation : FB_Input;   // 🆕 2026-07-03sexdecies — contrôle rotation phases élec.

    // 🪝 Winch M1
    instM1ContactorFwd : FB_Input;
    instM1ContactorRev : FB_Input;
    instM1Thermal      : FB_Input;
    instM1BrakeFeedback: FB_Input;

    // 🪝 Winch M2
    instM2ContactorFwd : FB_Input;
    instM2ContactorRev : FB_Input;
    instM2Thermal      : FB_Input;
    instM2BrakeFeedback: FB_Input;

    // ↔️ Chariot M3
    instChariotPosFosse1      : FB_Input;
    instChariotPosFosse2      : FB_Input;
    instChariotPosMaintenance : FB_Input;
    instChariotPosTremie      : FB_Input;
    instM3BrakeFeedback       : FB_Input;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_InputsMachine) ===

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
// ⚠️ Bypass TEST banc (GVL_DEBUG) — TOUJOURS FALSE avant essai réel avec la chaîne AU câblée
instEmergencyStopOk(InputRaw := EmergencyStopOk_DI OR GVL_DEBUG.DBG_EmergencyStopOkBypass_TEST, FilterTime := T#20MS);
GVL_IN.EmergencyStopOk := instEmergencyStopOk.State;

// ⚠️ Bypass TEST banc (GVL_DEBUG, créé par l'utilisateur) — TOUJOURS FALSE avant essai réel
// avec le vrai capteur mou de câble câblé. Câblage sécurité : TRUE=OK (pas de mou) — le
// bypass force donc l'état OK, cohérent avec les autres bypass (OR sur le signal brut).
instSlackCableSwitch(InputRaw := M1_M2_SlackCableSwitch_DI OR GVL_DEBUG.DBG_SlackCableSwitch_TEST, FilterTime := T#20MS);
GVL_IN.SlackCableSwitch := instSlackCableSwitch.State;

// ⚠️ Bypass TEST banc (GVL_DEBUG) — TOUJOURS FALSE avant essai réel avec le capteur câblé
instTopPositionSensor(InputRaw := M1_M2_TopPositionSensor_DI OR GVL_DEBUG.DBG_TopPositionSensorBypass_TEST, FilterTime := T#20MS);
GVL_IN.TopPositionSensor := instTopPositionSensor.State;

// 🆕 Contrôle rotation phases électriques (2026-07-03sexdecies) — TRUE = rotation correcte.
// Câblé dans FB_Safety_Winch/FB_Safety_Chariot (D71), pas directement sur EmergencyStopOk.
// ⚠️ Bypass TEST banc (GVL_DEBUG, créé par l'utilisateur) — TOUJOURS FALSE avant essai réel
// avec le vrai contrôle de rotation câblé.
instCtrlPhaseRotation(InputRaw := CtrlPhaseRotation_DI OR GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST, FilterTime := T#20MS);
GVL_IN.PhaseRotationOk := instCtrlPhaseRotation.State;

// 🪝 ─── WINCH M1 ──────────────────────────────────────────────────────────
instM1ContactorFwd(InputRaw := M1_ContactorFeedbackFwd_DI, FilterTime := T#20MS);
GVL_IN.M1ContactorFeedbackFwd := instM1ContactorFwd.State;

instM1ContactorRev(InputRaw := M1_ContactorFeedbackRev_DI, FilterTime := T#20MS);
GVL_IN.M1ContactorFeedbackRev := instM1ContactorRev.State;

instM1Thermal(InputRaw := M1_ThermalFeedback_DI OR GVL_DEBUG.DBG_ThermalBypass_TEST, FilterTime := T#20MS);
GVL_IN.M1ThermalFeedback := instM1Thermal.State;

// 🆕 Retour frein M1 RÉEL (était miroir logiciel GVL_Winch_M1_Stub)
instM1BrakeFeedback(InputRaw := M1_BrakeContactorFeedback_DI, FilterTime := T#20MS);
GVL_IN.M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2ContactorFwd(InputRaw := M2_ContactorFeedbackFwd_DI, FilterTime := T#20MS);
GVL_IN.M2ContactorFeedbackFwd := instM2ContactorFwd.State;

instM2ContactorRev(InputRaw := M2_ContactorFeedbackRev_DI, FilterTime := T#20MS);
GVL_IN.M2ContactorFeedbackRev := instM2ContactorRev.State;

instM2Thermal(InputRaw := M2_ThermalFeedback_DI OR GVL_DEBUG.DBG_ThermalBypass_TEST, FilterTime := T#20MS);
GVL_IN.M2ThermalFeedback := instM2Thermal.State;

// 🆕 Retour frein M2 RÉEL (était miroir logiciel GVL_Winch_M2_Stub)
instM2BrakeFeedback(InputRaw := M2_BrakeContactorFeedback_DI, FilterTime := T#20MS);
GVL_IN.M2BrakeFeedback := instM2BrakeFeedback.State;

// ↔️ ─── CHARIOT M3 — 4 capteurs position réels ───────────────────────────
instChariotPosFosse1(InputRaw := PosFosse1_DI, FilterTime := T#20MS);
GVL_IN.ChariotPosFosse1 := instChariotPosFosse1.State;

instChariotPosFosse2(InputRaw := PosFosse2_DI, FilterTime := T#20MS);
GVL_IN.ChariotPosFosse2 := instChariotPosFosse2.State;

instChariotPosMaintenance(InputRaw := PosMaintenance_DI, FilterTime := T#20MS);
GVL_IN.ChariotPosMaintenance := instChariotPosMaintenance.State;

instChariotPosTremie(InputRaw := PosTremie_DI, FilterTime := T#20MS);
GVL_IN.ChariotPosTremie := instChariotPosTremie.State;

// 🆕 Retour frein M3 RÉEL (était miroir logiciel GVL_Chariot_M3_Stub)
instM3BrakeFeedback(InputRaw := M3_BrakeContactorFeedback_DI, FilterTime := T#20MS);
GVL_IN.M3BrakeFeedback := instM3BrakeFeedback.State;
