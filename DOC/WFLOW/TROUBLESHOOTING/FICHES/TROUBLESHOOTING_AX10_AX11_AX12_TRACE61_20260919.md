# 🕵️ Session de Troubleshooting — Trace 61 AX10/AX11/AX12

> 📅 Date : 2026-09-19 · 🧪 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé

Trace utilisateur : `Suivi_61_SIMU_AX10_AX11_PASFLUIDE_ARRET AX12 avant FDC haut_20260919.trace`.
Conversion directe de la trace : 638 échantillons, 44 variables. Aucun code ni forçage modifié pendant ce diagnostic.

## 2. 🎯 Symptômes observés

1. La séquence passe de `AX10` à `AX11` sans échantillon `AX10B` visible.
2. Une coupure nette des commandes/relais apparaît à l'entrée d'AX11.
3. En AX12, l'arrêt intervient avant la position haute attendue ; la trace ne permet pas encore d'identifier quel FDC a déclenché l'arrêt.

## 3. 📊 Preuves de trace

| Événement | Temps | Valeurs observées |
|---|---:|---|
| Fin AX10 | 43103 ms | M2 avance ; M1 immobile ; relais M2=1 |
| Entrée AX11 | 43203 ms | étape 11 ; demandes M1/M2=0 ; relais M1/M2=0 |
| Trou de sortie | 43203–43910 ms | aucune montée, positions quasi constantes (~707 ms) |
| Reprise AX11 | 44012 ms | demandes/relais M1 et M2=1 simultanément |
| Entrée AX12 | 45823 ms | demandes/relais encore actifs |
| Fin trace | ~64121 ms | M1=7,357 m ; M2=21,572 m ; sorties à 0 |

**Fait fort 🟢** : le trou de sortie est réel et mesuré, pas seulement une impression opérateur.

## 4. 🌳 Hypothèses et verdicts

| # | Hypothèse | Variable/source | Verdict |
|---|---|---|---|
| H1 | La version exécutée ne contient pas réellement AX10B, ou l'étape est trop brève pour la trace | `CycleStep`, `E_AutoCycleStep` | 🔶 À confirmer : aucun échantillon 22 |
| H2 | La barrière de démarrage M1 impose ~700 ms de temps mort | `M1AscentStartReady`, `DeadTimeElapsed`, `RestartRequired` dans `PRG_06_Outputs` | 🟡 Très plausible : durée du trou ≈ 700 ms |
| H3 | Le maintien M2 P1 n'est pas propagé pendant AX10B | `Benne_CloseReached`, `ReqHoldAscentP1AfterClose`, `M2_SpeedStepApplied` | ❓ Non traçé dans la trace 61 |
| H4 | AX12 s'arrête sur M1 **ou** M2 | `FB_CycleSemiAuto.st:1338` | ✅ Confirmé par le code : `M1TopLimitReached OR M2TopLimitReached` |
| H5 | L'écart avant FDC vient d'une dynamique non compensée | `CableLimitAscentM1/M2`, positions, vitesse, seuil 7,5 m | ❓ Non prouvé ; la limite actuelle est un arrêt immédiat |

## 5. 🔍 Chaîne causale ciblée

```text
AX10 fermeture
  → Benne_CloseReached ?
  → AX10B attendu
      → maintien M2 P1
      → M1AscentStartReady (barrière 700 ms)
      → transfert simultané M1/M2 P1
  → AX11
  → sorties finales PRG06
```

Dans la trace, la commande AX11 devient active seulement après le trou. Il faut donc distinguer :

- AX10B réellement absent dans le runtime ;
- AX10B présent mais non capturé ;
- maintien M2 non autorisé par la barrière finale.

## 6. 🏁 Conclusion provisoire

- **Coupure AX10→AX11** : cause exacte non encore prouvée. La durée correspond fortement au temps mort de la barrière M1, mais l'absence d'AX10B est anormale au regard du code source actuel.
- **Arrêt AX12** : le code arrête le couple sur le premier FDC atteint (`M1 OR M2`). Cela ne correspond pas à la règle demandée par l'utilisateur (M1 comme référence du train), mais modifier ce comportement nécessite de préserver les barrières de sécurité individuelles.
- **Dynamique** : aucune compensation de dépassement n'est actuellement visible ; `CfgCableLimitAscent_M = 7,5 m` est documenté comme arrêt immédiat.

## 7. 🛠️ Prochaine vérification (sans modification de code)

Refaire une trace avec ces signaux internes :

`CycleStep`, `Benne_CloseReached`, `Benne_IsClosed`, `ReqHoldAscentP1AfterClose`, `M2_SpeedStepApplied`, `M1AscentStartReady`, `DeadTimeElapsed`, `RestartRequired`, `M1/M2 MotorRequest` PRG04 et PRG06, `M1/M2 CableLimitAscent`, positions M1/M2 et vitesses.

⚠️ Tant que ces valeurs ne sont pas tracées, ne pas conclure que la cause est uniquement AX10B ou uniquement l'interlock électrique.

## 8. ✅ Validation humaine requise

Aucune modification de `CODE/` effectuée. La correction éventuelle devra être validée avant implémentation :

1. sécuriser le transfert AX10B → AX11 sans trou de relais ;
2. décider formellement si M1 seul est la référence d'arrêt AX12 ;
3. définir une marge dynamique bornée sans neutraliser le FDC matériel.

## 9. 📝 Journal

- 2026-09-19 : lecture directe et conversion de la trace 61.
- 2026-09-19 : lecture inverse du code AX10/AX10B/AX11/AX12 et de la barrière `M1AscentStartReady`.
- 2026-09-19 : fiche créée, aucune modification applicative.
