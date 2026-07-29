</think>Tool budget reached before the write could execute — returning the complete review findings here so the runtime can persist them.

## Review

- **Blocker** — `PRG_10_Outputs.st` currently has no `VAR_INPUT` for raw feedback signals (`BrakeFeedback` M1/M2, `FwdRevSpeedFeedbackOff` M1/M2). The plan requires the final interlock to gate on `BrakeIsOpenConfirmed` and the 900ms post-release delay directly at the output stage — these raw signals must be added as new PRG_10 inputs (sourced from PRG_00_Inputs/field I/O) before the interlock FB can consume them independently of FB_Winch.

- **Blocker** — PRG_10 today only receives decoded booleans (`RelayFwd/RelayRev`, `Contactor1..4`) from FB_Winch via PRG_06 (PRG_06_WinchControl.st:675-690), not a step number. The plan's "RequestedStep→AuthorizedStep+1 max" logic needs a numeric step (FB_Winch.StepNumber and CommandedDirection) piped through PRG_06→PRG_10 as new inputs; this wiring isn't in the current interface and must be added explicitly.

- **Note (design decision needed)** — For "perte autorisation coupe immédiatement" to be a genuine independent barrier, the interlock should read raw AU/SafeStop/Enable state directly (`PRG_00_Inputs.EmergencyStopOk`, `PRG_03_Safety.*` outputs) rather than trusting FB_Winch's already-gated `RelayFwd/RelayRev` (FB_Winch.st already zeroes these on Error/NOT Enable). If it only re-consumes FB_Winch's filtered outputs, it adds no defense-in-depth against a corrupted FB_Winch instance — clarify intended authorization source before coding.

- **Note** — FB_Winch's `SpeedRamp` + `FB_SpeedStep` hysteresis already make StepNumber change by at most 1 per scan under normal operation (ramped, monotonic). The "max +1 step" rule at the final interlock is therefore mostly redundant in nominal operation and only has value against BypassGlobal misuse or a corrupted/bugged ramp — confirm that's the intended failure mode being defended against.

- **Note (scope conflict risk)** — Adding a nominal 1.5s step-dwell timer and a 1s restart timer inside `FB_Winch` overlaps with the yaml's own `out_of_scope` entry: "T91/T93/T87 : stratégie détaillée frein/puissance et rampes métier." Verify this specific FB_Winch change isn't excluded by that line before implementing it under this ticket.

- **Note (ambiguity)** — "1s restart time" semantics are undefined: same-direction stop→restart, or only direction reversal? FB_Winch already has `DirectionInterlockDelay` (200ms, `DirectionChangeDelay` TON) strictly for Fwd↔Rev reversal. A new, separate restart timer must be scoped precisely (which transition it gates) to avoid two overlapping/conflicting timers producing inconsistent stop-to-restart behavior.

- **Note (missing signal)** — `FB_Brake.st` has no explicit "brake physically confirmed open" output today; `BrakeCmd` is a command and `ContactorFeedback` is inverted-polarity raw feedback (TRUE=serré). The acceptance criterion "aucun relais sens ni contacteur vitesse avant BrakeIsOpenConfirmed" needs a new derived signal (e.g. `BrakeCmd AND NOT ContactorFeedback`), not present in FB_Brake or FB_Winch outputs today.

- **Note (composition conflict)** — `FB_SpeedStep` already has an independent step limiter (`SpeedGuardEnable`/`SpeedGuardReady`/`MeasuredSpeedBand`, out-of-scope per yaml: "T94/T95 et activation du garde-fou vitesse T47"). A new final-interlock step-escalation timer must define precedence versus this existing guard to avoid contradictory or oscillating step limits.

- **Correct** — 15 `FB_Output` instance count in PRG_10 is accurate: 7 per winch (RelayFwd, RelayRev, Contactor1-4, BrakeCmd) × 2 (M1/M2) + 1 (TranslationBrakeCmd) = 15, matching the yaml acceptance criterion.

- **Correct** — FB_Winch's existing `Error`/`EffectiveSafeStop` paths already force `RelayFwd/RelayRev/Contactor1..4/BrakeCmd` to FALSE on fault, a reasonable base to compose with (not replace) — the new PRG_10-level interlock is additive defense-in-depth provided the two layers use distinct authorization sources (see blocker above).