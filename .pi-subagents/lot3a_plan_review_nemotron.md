## Review Findings — LOT3A Plan Review (C4 Safety Final Interlock)

### Blockers (must resolve before implementation)

1. **FB_WinchOutputInterlock FB + enums missing** — `CODE/TREUILS/FB_WinchOutputInterlock.st`, `E_WinchOutputInterlockState.st`, `E_WinchOutputInterlockReason.st` do not exist. Plan requires this as the single final barrier in PRG_10 for M1/M2.

2. **FB_SpeedStep allows step jumping** — Lines 156-175 select `StepNumber` directly from hysteresis; 0→5 jump possible if `SpeedRefPct` high. Plan requires adjacent-step-only progression with ≥1.25s between increases.

3. **Brake/motor outputs run in parallel (no brake-first sequencing)** — `FB_Winch` calls `SpeedStep` + `Brake` + `SpeedRamp` same cycle; `RelayFwd/Rev/Contactor1-4` gated only by `EffectiveSafeStop`/`DirectionChangeDelay`. Plan: "Aucun relais sens ni contacteur vitesse n'est autorisé avant BrakeIsOpenConfirmed après commande de desserrage."

4. **No 900ms mandatory delay after contactors confirmed released** — `TonContactorsDropped` (line 185-190) used for StuckClosed detection (500ms), not restart delay. Plan: "Après coupure et confirmation FwdRevSpeedFeedbackOff, l'interlock impose T#900ms avant toute nouvelle marche."

5. **FB_Winch missing 1.5s step-hold and 1s restart delay params** — `VAR_INPUT` has ramp rates (50/150/400 %/s) but no `CfgStepHoldTime` (1.5s) or `CfgRestartDelay` (1s). Plan: "FB_Winch impose T#1s en nominal" for restart; "fonctionnement métier normal impose au moins T#1s500 entre paliers."

6. **15 FB_Output instances still in PRG_10** — Lines 45-60 (VAR) and 85-135 (calls). Plan: "Toutes les 15 instances FB_Output sont retirées : aucune instance FB_Output ne reste appelée."

7. **PRG_10 drives outputs directly from PRG_06 (no interlock layer)** — Lines 138-165 pass PRG_06 outputs to FB_Output. Plan: "La barrière finale est l'unique productrice des sorties relais vitesse M1/M2 dans PRG_10."

8. **No enums for HMI/PRG_11 exposure** — `E_WinchOutputInterlockState` / `E_WinchOutputInterlockReason` missing. Plan: "Les états/temporisations/reasons sont exposés IHM et en lecture seule dans PRG_11."

### Design Changes Required

9. **FB_Winch interface change** — Must output `RequestedStep`/`RequestedDirection`/`BrakeRequest` instead of `Contactor1-4`/`StepNumber`; new interlock owns contactor outputs and brake sequencing.

10. **FB_Brake becomes brake-sequence-only** — Output `BrakeIsOpenConfirmed` (feedback); motor contactors driven exclusively by new `FB_WinchOutputInterlock` AFTER brake confirmation.

### Residual Risks
- PRG_06_WinchControl drives PRG_10 VAR_INPUT directly (lines 840-870) — must redirect to new interlock inputs
- FB_WinchSync reads `instWinchM1.RelayFwd/Rev/Contactor1-4` — new interlock outputs must feed same signals
- BrakeFeedback polarity in PRG_00_Inputs must match `FB_Brake` expectation (TRUE = released)
- Single `FwdRevSpeedFeedbackOff` covers ALL contactors — interlock must use for 900ms drop confirmation
- Simulation bypass `BypassContactorCheck` must be respected consistently in new FB

---

**Verdict:** Plan NOT ready — 8 blockers + 2 design changes. Critical path: create `FB_WinchOutputInterlock` + enums, remove 15 `FB_Output` instances, refactor `FB_Winch`/`FB_SpeedStep`/`FB_Brake` interfaces per items 9-10.