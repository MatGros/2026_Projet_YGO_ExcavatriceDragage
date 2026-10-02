# 🧭 GRAFCET Séquenceur — Cycle Homing Machine

> **Source réelle** : `FB_CycleMachineHoming.st`  
> **Variable d'état** : `SeqStep` (`E_MachineHomingTxState`)  
> **Métriques** : **9** étapes · **17** transitions réelles extraites mécaniquement.  

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#1e293b',
    'primaryTextColor': '#ffffff',
    'primaryBorderColor': '#00e5ff',
    'lineColor': '#00e5ff',
    'secondaryColor': '#0f172a',
    'tertiaryColor': '#1e293b',
    'edgeLabelBackground': '#0b1329',
    'textColor': '#ffffff',
    'fontSize': '12px'
  }
}}%%
flowchart TD
    %% Style CEI 60848 standard haut contraste
    classDef stepClass fill:#1e293b,stroke:#00e5ff,stroke-width:2.5px,color:#ffffff,font-family:monospace;
    classDef initialStep fill:#0f172a,stroke:#38bdf8,stroke-width:4px,color:#38bdf8,font-family:monospace;
    classDef failStep fill:#450a0a,stroke:#ef4444,stroke-width:2.5px,color:#fca5a5,font-family:monospace;
    classDef completeStep fill:#064e3b,stroke:#10b981,stroke-width:2.5px,color:#6ee7b7,font-family:monospace;

    HX0_REPOS[["<b>HX0_REPOS</b><br/>(L412)"]]:::initialStep
    HX1_BUCKET_PREPARE["<b>HX1_BUCKET_PREPARE</b><br/>(L421)"]:::stepClass
    HX1A_COUPLING_INTERLOCK["<b>HX1A_COUPLING_INTERLOCK</b><br/>(L439)"]:::stepClass
    HX2_CLIMB_COUPLED["<b>HX2_CLIMB_COUPLED</b><br/>(L453)"]:::stepClass
    HX3_FLYING_REFERENCE["<b>HX3_FLYING_REFERENCE</b><br/>(L473)"]:::stepClass
    HX4_STABILIZATION_CHECK["<b>HX4_STABILIZATION_CHECK</b><br/>(L520)"]:::stepClass
    HX5_RELEASE_CLEARANCE["<b>HX5_RELEASE_CLEARANCE</b><br/>(L548)"]:::stepClass
    HX6_HOMED_SUCCESS["<b>HX6_HOMED_SUCCESS</b><br/>(L558)"]:::completeStep
    HX7_FAILED["<b>HX7_FAILED</b><br/>(L570)"]:::failStep

    %% Transitions réelles extraites du code
    HX0_REPOS -->|"L418: ((StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2)"| HX1_BUCKET_PREPARE
    HX1_BUCKET_PREPARE -->|"L431: (ModeLostDuringCycle OR MotionOutOfPhase)"| HX7_FAILED
    HX1_BUCKET_PREPARE -->|"L436: (HomingBucketConfirmEdge.Q AND NOT JoystickDeflected)"| HX1A_COUPLING_INTERLOCK
    HX1A_COUPLING_INTERLOCK -->|"L447: (ModeLostDuringCycle OR AxisHomingError)"| HX7_FAILED
    HX1A_COUPLING_INTERLOCK -->|"L450: ((JoystickWinchSelectArbitrated = 0)<br/>AND CouplingSettleTimer.Q<br/>AND WinchesMechanicallyStopped)"| HX2_CLIMB_COUPLED
    HX2_CLIMB_COUPLED -->|"L463: (TransactionAbort)"| HX7_FAILED
    HX2_CLIMB_COUPLED -->|"L470: (TopPositionSensor)"| HX3_FLYING_REFERENCE
    HX3_FLYING_REFERENCE -->|"L489: (NOT HomingModeBActive) AND (BothAxesHomed)"| HX4_STABILIZATION_CHECK
    HX3_FLYING_REFERENCE -->|"L510: (ELSE)<br/>AND (WinchesMechanicallyStopped)<br/>AND (BothAxesHomed)"| HX4_STABILIZATION_CHECK
    HX3_FLYING_REFERENCE -->|"L517: (TransactionAbort)"| HX7_FAILED
    HX4_STABILIZATION_CHECK -->|"L534: (ModeLostDuringCycle OR AxisHomingError)"| HX7_FAILED
    HX4_STABILIZATION_CHECK -->|"L536: (StabilizationOk)"| HX5_RELEASE_CLEARANCE
    HX4_STABILIZATION_CHECK -->|"L541: (StabilizationFailed) AND (RetryCount &gt;= 3)"| HX7_FAILED
    HX4_STABILIZATION_CHECK -->|"L544: (StabilizationFailed) AND (ELSE)"| HX1_BUCKET_PREPARE
    HX5_RELEASE_CLEARANCE -->|"L553: (ModeLostDuringCycle OR AxisHomingError)"| HX7_FAILED
    HX5_RELEASE_CLEARANCE -->|"L555: (NOT JoystickDeflected AND WinchesMechanicallyStopped)"| HX6_HOMED_SUCCESS
    HX6_HOMED_SUCCESS -->|"L567: (ELSE)"| HX0_REPOS
    linkStyle default stroke:#00e5ff,stroke-width:2.5px,color:#ffffff,fill:none;
```

---

## 📋 Tableau Récapitulatif des Étapes & Transitions Réelles

| # | Étape Source | Ligne ST | Cible | Ligne Transition | Réceptivité / Condition Réelle |
|---|---|---|---|---|---|
| 1 | `HX0_REPOS` | L412 | `HX1_BUCKET_PREPARE` | L418 | `((StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2)` |
| 2 | `HX1_BUCKET_PREPARE` | L421 | `HX7_FAILED` | L431 | `(ModeLostDuringCycle OR MotionOutOfPhase)` |
| 2 | `HX1_BUCKET_PREPARE` | L421 | `HX1A_COUPLING_INTERLOCK` | L436 | `(HomingBucketConfirmEdge.Q AND NOT JoystickDeflected)` |
| 3 | `HX1A_COUPLING_INTERLOCK` | L439 | `HX7_FAILED` | L447 | `(ModeLostDuringCycle OR AxisHomingError)` |
| 3 | `HX1A_COUPLING_INTERLOCK` | L439 | `HX2_CLIMB_COUPLED` | L450 | `((JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped)` |
| 4 | `HX2_CLIMB_COUPLED` | L453 | `HX7_FAILED` | L463 | `(TransactionAbort)` |
| 4 | `HX2_CLIMB_COUPLED` | L453 | `HX3_FLYING_REFERENCE` | L470 | `(TopPositionSensor)` |
| 5 | `HX3_FLYING_REFERENCE` | L473 | `HX4_STABILIZATION_CHECK` | L489 | `(NOT HomingModeBActive) AND (BothAxesHomed)` |
| 5 | `HX3_FLYING_REFERENCE` | L473 | `HX4_STABILIZATION_CHECK` | L510 | `(ELSE) AND (WinchesMechanicallyStopped) AND (BothAxesHomed)` |
| 5 | `HX3_FLYING_REFERENCE` | L473 | `HX7_FAILED` | L517 | `(TransactionAbort)` |
| 6 | `HX4_STABILIZATION_CHECK` | L520 | `HX7_FAILED` | L534 | `(ModeLostDuringCycle OR AxisHomingError)` |
| 6 | `HX4_STABILIZATION_CHECK` | L520 | `HX5_RELEASE_CLEARANCE` | L536 | `(StabilizationOk)` |
| 6 | `HX4_STABILIZATION_CHECK` | L520 | `HX7_FAILED` | L541 | `(StabilizationFailed) AND (RetryCount >= 3)` |
| 6 | `HX4_STABILIZATION_CHECK` | L520 | `HX1_BUCKET_PREPARE` | L544 | `(StabilizationFailed) AND (ELSE)` |
| 7 | `HX5_RELEASE_CLEARANCE` | L548 | `HX7_FAILED` | L553 | `(ModeLostDuringCycle OR AxisHomingError)` |
| 7 | `HX5_RELEASE_CLEARANCE` | L548 | `HX6_HOMED_SUCCESS` | L555 | `(NOT JoystickDeflected AND WinchesMechanicallyStopped)` |
| 8 | `HX6_HOMED_SUCCESS` | L558 | `HX0_REPOS` | L567 | `(ELSE)` |
| 9 | `HX7_FAILED` | L570 | *(Étape terminale)* | — | *(Aucune transition sortante)* |