# 🕵️ Session de Troubleshooting — AX10 → AX11 → AX12 — Trace 62

> 📅 Date : 2026-09-19 · 🧪 Situation : SIMULATION BANC · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé

Trace CODESYS fournie : `Suivi_62_SIMU_AX10_AX11_PASFLUIDE_ARRET AX12 avant FDC haut_20260919.trace`.
Conversion hors ligne : 44 variables, 693 échantillons, pas nominal ≈100 ms.

## 2. 🎯 Symptôme

À la transition fermeture benne → montée contrôle, les commandes de direction M1/M2 retombent à zéro pendant environ 0,8 s. En AX12, l'arrêt intervient encore avant le FDC haut logiciel attendu.

## 3. 🧩 Indices observés

- La trace passe de `CycleStep=10` à `CycleStep=11` ; aucun échantillon `CycleStep=22` (`AX10B_RACCORDEMENT_P1`).
- À 48 371 ms : AX10, M2 encore commandé en montée (`M2 MotorRequest=1`, relais M2=1), M1 arrêté.
- À 48 471 ms : AX11, demandes et relais M1/M2 tous à 0.
- À 49 276 ms : les deux demandes/relais remontent ensemble.
- Les défauts M1/M2 tracés restent à 0 pendant cette fenêtre.

## 4. 🌳 Hypothèses

| # | Hypothèse | Preuve disponible | Verdict |
|---|---|---|---|
| H1 | `AX10B` n'est pas exécuté dans le runtime testé | Aucun échantillon de valeur 22 | 🔴 À confirmer : binaire CODESYS différent ou condition AX10B non satisfaite |
| H2 | La barrière d'atomicité PRG04 neutralise les deux treuils tant que M1/M2 ne sont pas prêts | Les deux sorties sont simultanément nulles en AX11 puis reviennent ensemble | 🟢 Très probable |
| H3 | Temps mort/interlock M1 à l'origine de la non-préparation | Le code utilise `WinchBothMotionReady` et `DirectionChangePending` ; ces variables ne sont pas dans la trace | 🟡 Non prouvé |
| H4 | Défaut safety moteur | `ErrorMecaB=0`, `ErrorId=0` dans la trace | ⚪ Écarté pour les bits tracés |

## 5. 📊 Chronogramme observé

```text
AX10  48.371 s : M2 montée active, M1 arrêté
      ↓ transition
AX11  48.471..49.176 s : M1/M2 demandes = 0, relais = 0  ❌ trou ~0,8 s
AX11  49.276 s : M1/M2 demandes et relais = 1             ✅ reprise couplee
```

## 6. 🏁 Conclusion provisoire

Le problème n'est pas un simple défaut moteur : la trace montre une **neutralisation coordonnée des deux sorties par la chaîne d'arbitrage/interlock** au démarrage d'AX11. La trace ne prouve pas que la version avec `AX10B_RACCORDEMENT_P1` est celle réellement exécutée, car l'étape 22 n'apparaît jamais.

## 7. 🛠️ Proposition de correction / vérification

- **Avant tout nouveau patch** : refaire une trace en ajoutant `CycleStateStr`, `M1AscentStartReady`, `WinchBothMotionReady`, `DirectionChangePending` M1/M2, `RestartRequired` M1/M2 et `Reason` des deux `FB_WinchOutputInterlock`.
- Vérifier dans CODESYS que le bundle importé contient bien `E_AutoCycleStep.AX10B_RACCORDEMENT_P1` et que `CycleStep=22` est observable.
- Ne pas supprimer la barrière d'atomicité : elle protège contre le démarrage d'un seul treuil. La correction doit préparer la disponibilité M1 avant le transfert, puis faire le transfert sans neutraliser M2.

## 8. 📝 Journal

- 2026-09-19 : conversion et analyse hors ligne de la trace 62 ; aucun code modifié.
