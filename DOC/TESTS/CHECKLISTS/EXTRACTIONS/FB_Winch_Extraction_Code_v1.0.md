# Extraction Treuils M1/M2 — code vs AF10 (v1.0)

> Sources : `CODE/TREUILS/*.st`, `CODE/COMMUN/FB_Brake.st`, `CODE/MAIN/PRG_04_Treuils_Benne.st`, `PRG_03_Safety.st`.
> Statut : fiche de travail avant AF10 v2.0. Renommage AU déjà à jour partout ici.

## Alertes (devoir d'alerte)

| # | G | Sujet | Statut |
|---|---|---|---|
| A1 | info | "5 mécanismes" annoncé — code+doc legacy en comptent **7 (A-G)** | Corrigé dans AF10 v2.0 |
| A2 | P1 | 2 temporisations hausse palier différentes en cascade : `FB_Winch` 1s500ms **puis** `FB_WinchOutputInterlock_LD` 1s250ms (cumul ~2.75s) | Non documenté comme voulu — à clarifier |
| A3 | P1 | T87/T91 : `DelayMotorDecel` **code mort** — TON armé `IN:=FALSE` dans `FB_Brake`, sans effet réel | Étude terrain non tranchée |
| A4 | P2 | T93 : rampe %/s peu pertinente pour paliers résistifs discrets | Proposition non faite |
| A5 | P1 | T94 : `SpeedGuardEnableM1/M2` = VAR **locales non-persistantes** de PRG_06 → perdues au download | Non résolu |
| A6 | P2 | T95 : bandes de vitesse `[0.4,0.8,1.2,1.6,2.0]` théoriques, jamais mesurées | Non résolu |
| A7 | info | Doc AF02 legacy décrit des noms CFC génériques (`PRG_TREUILS_CFC`) qui ne correspondent pas aux vrais PRG (`PRG_06_WinchControl`, ST) | Architecture cible ≠ code actuel, assumé |

## Composition code

`FB_Winch` (mouvement, compose `FB_SpeedStep`+`FB_Brake`+`FB_Ramp`) + `FB_Safety_Winch` (7 méca A-G) + `FB_WinchSync` (1 instance, synchro N1) + `FB_WinchOutputInterlock_LD` (barrière finale) + `FB_WinchLoadEstimator` (diagnostic).
Instances ×2 (M1/M2) sauf Sync (×1). Tout dans `PRG_06_WinchControl` (mouvement) / `PRG_03_Safety` (safety) / `PRG_10_Outputs_LD` (finale).
