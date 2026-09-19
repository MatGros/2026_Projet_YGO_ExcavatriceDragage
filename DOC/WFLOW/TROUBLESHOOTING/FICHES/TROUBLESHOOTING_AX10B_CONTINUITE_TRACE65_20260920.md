# Troubleshooting — AX10B et arrêt haut — trace 65

## Contexte

- Simulation, cycle semi-automatique complet.
- Source : `Suivi_65_SIMU_Raccord_AX10B_Interlock_20260919.trace`, échantillonnage proche de 100 ms.

## Résultats

### AX10 → AX10B → AX11

| Temps | Step | Faits |
|---:|---:|---|
| 36,889 s | AX10 (10) | M2 monte seul pour fermer la benne. |
| 48,758 s | AX10B (22) | M1 et M2 sont tous deux en montée, StepNumber 1/1. M2 ne perd pas son relais de sens. |
| 48,859 s | AX11 (11) | M1 et M2 restent commandés en montée, StepNumber 1/1. |

AX10B est visible pendant environ 101 ms (résolution de la trace). Aucun trou de relais de sens n'est visible entre AX10, AX10B et AX11. La continuité est validée pour cet essai précis.

### Arrêt haut

| Temps | Step | Position M1 | État |
|---:|---:|---:|---|
| 50,963 s | AX12 (12) | -13,49 m | Montée chargée M1+M2. |
| 73,183 s | AX13 (13) | 7,55 m | Relais et paliers M1/M2 retombés. |
| 78,211 s | AX14 (14) | 7,85 m | Position stabilisée après dynamique simulée. |

L'arrêt est déclenché autour de la limite logicielle M1 7,5 m, puis la dynamique simulée conduit à environ 7,85 m. Aucune preuve d'un arrêt piloté par la mesure M2 dans cette trace.

## Limite

Les traces réalisées en pilotage manuel de maintenance ne sont pas comparables à ce scénario : elles ne traversent pas AX10, AX10B et AX11. La trace 65 constitue donc la preuve pertinente pour juger ce raccordement du cycle. Les variables `DirectionChangePending`, `M1AscentStartReady`, `RestartRequired` et `DeadTimePending` ne sont toutefois pas présentes ; elles resteraient nécessaires pour analyser un éventuel futur échec dans le même scénario de cycle.

## Conclusion

- Continuité AX10→AX10B→AX11 : PASS sur la trace 65.
- Arrêt haut piloté autour de la limite M1 : PASS sur la trace 65.
- Les traces de maintenance sont hors comparaison pour la validation d'AX10B.
