# Extraction Joystick — code vs AF08 (v1.0)

> Sources : `CODE/JOYSTICK/*`, `PRG_01_Diagnostics`, `PRG_06/07/05/09`, DUT IHM.
> Statut : fiche de travail avant AF08 v2.0. Ne remplace pas l'AF.

## Alertes (devoir d'alerte)

| # | G | Sujet | Statut |
|---|---|---|---|
| A1 | P1 | AF v1.3 obsolète : mapping debug, `SafeStop` encore cité, pas d'homme-mort détaillé, `IsCentralPosition*` absent du code | Doc |
| A2 | P1 | `PreserveArmingAfterBucket` = exception safety homme-mort — câblée ExtractionSequence CLOSING only | Vérifié OK si inchangé |
| A3 | info | Désarmement benne / mode : effet au scan **N+1** (PRG_01 lit PRG_06/04) | Structurel, documenté |
| A4 | info | Miroirs `SpeedXPct`/`DirectionX`… redondants avec `AxisCmd*` | Surcharge légère maintenance OK |
| A5 | info | `Enable:=TRUE` fixe — gate modes en aval (PRG_06/07), pas dans le FB | Conforme profil non-mouvement |
| A6 | — | Neutre deadman sur `Scale*.OutPct` (pré-filtre/rampe) — voulu | Vérifié |

## Composition code

`FB_Joystick` → ScaleX/Y, FilterX/Y, RampX/Y, CycleTimeCalc  
Instance unique : `PRG_01_Diagnostics.instJoystick`  
DUT sortie : `ST_AxisCmd` (Enable, StartStop, SpeedRef signé, Direction)
