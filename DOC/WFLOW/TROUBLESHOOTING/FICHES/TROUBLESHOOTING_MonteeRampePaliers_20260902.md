# Session de Troubleshooting — montée : délai avant contacteurs de vitesse

> Date : 2026-09-02 · Situation : [SITE / banc non précisé] · Statut : RÉSOLUE — comportement nominal

## 1. Contexte figé

Snapshot : `Snapshot_Troubleshooting_20260902_160851.csv` (541/541 variables lues), pris en `MAINT_N2`, pendant une demande de montée joystick à 100 %.

| Élément | Variable | Valeur |
|---|---|---:|
| Demande montée M1/M2 | `Demandes_200.Idx209_ArbitratedDirection` | `INT#1` |
| Demande vitesse | `Demandes_200.Idx208_ArbitratedSpeed_Pct` | `REAL#100` |
| Palier courant M1/M2 | `Control_400.Idx402_SpeedStepCalculated` | `INT#1` |
| Palier final autorisé M1/M2 | `Control_400.Idx407_FinalAuthorizedStep` | `INT#1` |
| Contacteurs vitesse visibles | `Outputs_500.Idx503/Idx504` | `FALSE / FALSE` |

## 2. Conclusion

Le délai observé en montée est nominal. `FB_WinchStepShaper` passe immédiatement au palier 1 puis augmente d'un palier toutes les `T#1000ms` (`PRG_04_Treuils_Benne.st`, configuration M1 et M2). La table persistante affecte volontairement le palier 1 à aucun contacteur de vitesse (`P1R1..P1R4 = FALSE`) ; le premier contacteur apparaît au palier 2, environ une seconde après la demande maintenue.

Chaîne prouvée : `demande montée 100 %` → `StepNumber=1` → `P1={}` → `contacteurs vitesse=FALSE` → après 1 s, `StepNumber=2` → contacteur 1.

## 3. Action

Aucune modification ST ni forçage requis. Si le délai d'une seconde est jugé trop long en exploitation, il faut ouvrir une évolution C2/C3 avec exigence de sécurité et validation humaine ; ce n'est pas une anomalie de limite haute.

