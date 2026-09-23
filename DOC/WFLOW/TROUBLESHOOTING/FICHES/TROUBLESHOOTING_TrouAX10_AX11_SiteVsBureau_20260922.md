# 🕵️ Session de Troubleshooting — Trou AX10 → AX11 (site vs bureau)

> 📅 Date : 2026-09-22 · 🧊 Situation : **SITE MACHINE RÉELLE** (vs bureau = simulation) · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé (horodaté)

> À confirmer à la reprise. Ne PAS re-demander ensuite.

- Situation : SITE (le trou AX10→AX11 **absent au bureau/banc**, présent en site).
- Symptôme décrit : « trou AX10 AX11 » — probablement la **retombée à zéro des commandes treuils M1/M2 à la transition fermeture benne → montée contrôlée** (phénomène déjà documenté en banc dans `TRACE62`).
- Référencement treuils : à confirmer.
- Mode machine : à confirmer (SEMI_AUTO a priori).

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| (à lire en snapshot) | ... | ... | ... |

## 2. 🎯 Symptôme

Trou / saut dans les commandes treuils entre les étapes **AX10** (fermeture benne) et **AX11** (montée contrôlée) en site ; ce trou **n'apparaissait pas au bureau** (banc / simulation). Permanent ou intermittent : à confirmer.

## 3. 🧩 Indices / historique

- Base saine du matin : commit `8ec1fa28` (variante `AX11_A_MATIN`) ; variante `AX11_B_MECA_B_APRES_MIDI` puis `AX11_C_HOMING_INHIBE`.
- Fiche antérieure : `TROUBLESHOOTING_AX10_AX11_AX12_TRACE62_20260919.md` (banc) — hypothèse **H2 (barrière d'atomicité)** très probable, non tranchée faute de variables tracées.
- Déjà essayé : à confirmer par l'utilisateur.
- Conditions d'apparition : à confirmer.
- Alarmes : à confirmer.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Barrière d'atomicité neutralise M1+M2 tant qu'ils ne sont pas prêts simultanément | `WinchBothMotionReady` / `DirectionChangePending` | TRUE avant transfert (PRG_04) | — | à vérifier |
| 2 | Étape `AX10B_RACCORDEMENT_P1` non atteinte → bascule brute AX10→AX11 | `CycleStep` / `CycleStateStr` | 22 avant 11 (FB_CycleSemiAuto) | — | à vérifier |
| 3 | Retour fermeture benne (`CloseReached`) retardé/instable en site | `FB_Bucket.CloseReached` / `BucketCloseReached` | stable ≥300 ms | — | à vérifier |
| 4 | Surveillance écart vitesse M1/M2 (AX11) déclenche en conditions réelles | `SpeedMismatchActive` / `FB_SyncDeviation` | FALSE | — | à vérifier |
| 5 | Configuration site ≠ banc (`CtrlAscentMaxStep`, `CtrlAscentDistanceM`) | `CfgCtrlAscentMaxStep` / `CfgCtrlAscentDistanceM` | borné [1..2] | — | à vérifier |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
(à compléter après lecture snapshot / analyse branches)
```

**Résumé une ligne** : _(à compléter)_

## 6. 📊 Données / interactions & chronogramme (🟡)

_(à compléter)_

## 7. 🏁 Conclusion

- **Cause racine** : _(à déterminer)_

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : _(à compléter)_
- **Option 2 (définitif)** : _(à compléter)_
- **⚠️ Validation requise** : [humaine]

## 9. ✅ Vérification de la correction / non-régression

_(à compléter)_

## 10. 📝 Journal (chronologique)

- 2026-09-22 : ouverture fiche (site) ; lancement analyse statique parallèle des branches AX10→AX11 ; aucun code modifié.

---

## 11. Mise à jour terrain — pause AX11 de 800 ms (2026-09-22 soir)

### Faits mesurés

| Fait | Réel | Simulation | Verdict |
|---|---:|---:|---|
| Début AX11 | 57,294 s | 126,557 s | — |
| Coupure MotorRequest M2 PRG04/PRG06 | 0,901 s échantillonnée | aucune | confirmée site |
| D18 M1 `DirectionChangePending` | 800 ms, deux occurrences trace 84 | absent au transfert | cause directe |
| Delta M2-M1 au transfert | 13,872 m | 13,902 m | seuil fermeture similaire |
| Position absolue M2 | 4,850 m | -1,573 m | seuil 8,5 m éliminé |
| `M1_ContactorsReleased_DI` pendant M2 seul | tombe à 0 | reste à 1 | différence décisive |

Trace réelle `Suivi_83_BonEnSimu_Mais pas en reelAX10_11_ARRET_20260922.trace` :

- AX10 dure environ 23,5 s ; M1 reste à `StepNumber=0`, relais M1=0 et frein appliqué.
- À 49,494 s, au démarrage de M2, `M1_ContactorsReleased_DI` passe de 1 à 0 alors que M1 reste neutre.
- Le signal reste à 0 pendant les 7,8 s précédant AX11.
- À AX11, M1 attend D18 ; la garde d'atomicité neutralise les deux treuils ; reprise après 800 ms.

Trace 84 : `DirectionChangePending` M1 passe à 1, `DirectionChangeDelayElapsed` progresse jusqu'à
800 ms, puis les commandes et relais montée M1/M2 repartent ensemble. M2 ne porte pas le pending.

### Chaîne causale prouvée

```text
M2 démarre seul en AX10
  -> entrée physique M1_ContactorsReleased_DI tombe à 0 malgré M1 neutre
  -> M1 Sensors.ContactorsAllOff = 0
  -> StoppedTimer M1 est remis à 0
  -> AX11 demande la montée M1 avec CapturedStoppedTime = 0
  -> D18 M1 applique 800 ms complets
  -> DirectionChangePending M1 = 1
  -> garde d'atomicité neutralise aussi M2
  -> MotorRequest PRG04/PRG06 et relais M1/M2 = 0 pendant 800 ms
```

Références : `PRG_02_Acquisition.st:145`, `PRG_04_Treuils_Benne.st:1424`,
`FB_Winch.st:197-205`, `FB_WinchDirectionInterlock.st:73-120`,
`PRG_04_Treuils_Benne.st:1495-1501` et `:1658-1677`.

### Rôle de l'anticipation benne

`CloseAnticipationM=1,2 m` déclenche la fin de fermeture vers le delta relatif
`OffsetCloseM - CloseAnticipationM`, soit environ 13,8 m. Cette transition existe en réel et en
simulation. Elle détermine le moment où AX11 est demandé mais ne crée pas la temporisation.
`OpenAnticipationM=1,3 m` n'intervient pas dans cette fermeture.

### Conclusion et actions

- **Cause directe de la pause : confirmée** — D18 M1 800 ms + garde d'atomicité M1/M2.
- **Cause du D18 complet : confirmée** — perte du crédit d'arrêt par chute de
  `M1_ContactorsReleased_DI` pendant que seul M2 fonctionne.
- **Cause électrique exacte : croisement M1/M2 très probable, étage à confirmer au bornier / mapping.**
  En mouvement M2 seul, le réel donne `(M1DI,M2DI)=(0,1)` pendant 78 échantillons ; la simulation
  correcte donne `(1,0)`. Ce comportement est incompatible avec un simple retour commun et compatible
  avec une inversion des deux retours. La spécification prévoit M1 `%IX0.0`, M2 `%IX0.2`.
- **Correction prioritaire sans perte de fonction :** rendre le retour M1 indépendant du mouvement
  M2 conformément à la spécification. Les anticipations 1,2/1,3 m, AX10B et D18 restent conservés.
- **Correction logicielle éventuelle :** uniquement si le matériel confirme que le retour est
  volontairement commun ; elle devra être cadrée C3 et ne pourra pas considérer un contacteur
  retombé sur la seule absence de commande.

### Contre-vérification vitesse et AX10b

- Trace 84, événement 1 : M2 accélère de 0,460 à 0,513 m/s ; le relais tombe à 81,891 s alors que
  la vitesse vaut encore environ 0,480 m/s. La forte décélération commence ensuite.
- Événement 2 : M2 accélère de 0,547 à 0,653 m/s ; le relais tombe à 297,692 s, puis la vitesse
  décroît. La baisse de vitesse est donc une conséquence de la coupure.
- `FB_WinchDirectionInterlock` ne consomme aucune vitesse. `MeasuredSpeedBand` peut seulement
  plafonner un palier positif dans `FB_Winch`; il ne produit pas le pending D18 de 800 ms.
- Les traces 83 échantillonnées à environ 100 ms montrent AX10 puis AX11 sans échantillon AX10b.
  Une exécution AX10b très courte peut avoir été manquée, mais le fallback prévu après 2 s puis
  l'arrêt confirmé de 500 ms est exclu : il aurait été visible. AX10b ne peut donc pas expliquer
  le trou mesuré de 800 ms dans ces acquisitions.
- Limite de preuve : pour mesurer exactement AX10b sur le programme chargé, une nouvelle trace doit
  inclure `CycleStep`, `Ax10bFallbackStopActive`, `M1FinalAscentStartReady`,
  `DirectionChangePending M1` et les deux retours contacteurs.

- 2026-09-22 : analyse parallèle code/git/traces ; cause directe confirmée, aucune modification de `CODE/`.
