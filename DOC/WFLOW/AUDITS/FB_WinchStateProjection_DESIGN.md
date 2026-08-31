# FB_WinchStateProjection — Design (Phase 6 / T195)

## 🎯 Objectif
Décharger PRG_04 de la §8 « Publication états IHM » (~250 lignes d'assignations pures) en un FB de **projection lecture seule**. PRG_04 appelle le FB, qui remplit `WinchM1State`/`WinchM2State`/`WinchM1Safety`/`WinchM2Safety`/`CableLimitAscent`.

## 🧬 Responsabilité (1 FB = 1 responsabilité)
- **Projection pure** : recopie de sources → structs d'état publics. Aucune logique de commande, aucun calcul de sécurité.
- **Producteur unique** : les structs d'état restent produits par PRG_04 (via ce FB), consommés par PRG_07/IHM.

## 📥 Entrées (sources)
| Groupe | Sources |
|---|---|
| Encoders | `PRG_02_Acquisition.Data.EncoderM1/M2.Measurement` (Speed_Mps, CablePosM, RawPos, AbsFault, HomingLifecycle, HomingFault, HomingRefRaw), `.Homed`, `.HomingSuspect`, `.HwOut`, `HwReal.Winch.COD1/2_Alarms/Warnings`, `Data.Network.EncoderM1/M2.Operational` |
| Treuils | `instWinchM1/M2` (StepNumber, Fault, Ready, RelayFwd/Rev, Contactor1..4, RequestedStep, ContactorsCheck, InTop/BottomSlowdownZone, CommandedDirection, DirectionChangePending/DelayElapsed) |
| Interlocks | `PRG_06_Outputs.instWinchOutputInterlockM1/M2` (BrakeCmd, State, Reason, Fault, RestartInhibit, BrakeTimeoutElapsed, RestartDelayElapsed, StepDelayElapsed) |
| Safety | `instSafetyWinchM1/M2` (PowerCutOff, Fault), `SafeStopM1/M2_Active`, `EffectivePermitM1/M2_Ascent/Descend`, `BottomLimitM1/M2_Active` |
| Modes | `PRG_03_Modes_Cycle.Data.Auth.InhibitM1/M2` |
| Config | `_CommunCfgPersist.CfgCableLimitAscent_M`, `_WinchM1/M2CfgPersist.CfgCableLimitDescent_M`, `M2_LimitShift` |
| Locaux | `M1/M2_PrevSpeed_Mps` (delta vitesse), `M1/M2LogicRequestSpeedCmd_Pct` |

## 📤 Sorties (structs remplis)
- `WinchM1State`, `WinchM2State` : `ST_WinchState`
- `WinchM1Safety`, `WinchM2Safety` : `ST_SafetyWinch`
- `CableLimitAscentM1Reached`, `CableLimitAscentM2Reached` : BOOL

## 🔒 Non-régression
- **Bit-identique** : chaque assignation de la §8 est déplacée telle quelle dans le FB. Aucune logique modifiée.
- **Ordre** : le FB est appelé en §8 de PRG_04, après §6 (exécution treuils) et §5bis (sécurité) — mêmes sources disponibles.
- **G200** : les structs d'état restent produits par PRG_04 (via le FB) → liaison préservée.

## 📐 NC-110
`ST_WinchState`/`ST_SafetyWinch` sont des DUT de domaine public (multi-consommateurs) → pas de préfixe `ST_fb*`. Le FB `FB_WinchStateProjection` est propriétaire de la projection.

## 🗂️ Fichiers
- `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st` (nouveau)
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§8 → appel FB)

## ✅ Critères d'acceptation
1. Bundle 237/237, G200 PASS (0 erreur).
2. §8 de PRG_04 réduite à l'appel FB (~10 lignes au lieu de ~250).
3. Bit-identique (aucune assignation perdue).
