# Note technique — Pause AX11, D18 et retours contacteurs M1/M2

> **Date :** 2026-09-23  
> **Contexte :** cycle semi-automatique, transition AX10/AX10B vers AX11  
> **Statut :** cause logicielle directe confirmée ; origine électrique ou mapping du DI à confirmer sur machine  
> **Impact constaté :** disparition simultanée des commandes de montée M1/M2 pendant environ 800 à 900 ms

## 1. Résumé exécutif

La pause AX11 n'est pas déclenchée par la baisse de vitesse de M2, par la position absolue de la
benne, ni directement par l'anticipation de fermeture de 1,2 m.

La cause directe observée est l'interlock de changement de sens **D18 de M1** :

```text
M1 arrêté pendant AX10
  → M1_ContactorsReleased_DI passe pourtant à FALSE lorsque M2 fonctionne seul
  → l'arrêt physique de M1 n'est plus crédité par l'interlock
  → AX11 demande la montée M1
  → D18 impose le délai complet de 800 ms
  → DirectionChangePending M1 = TRUE
  → la garde de départ couplé neutralise temporairement M1 et M2
  → reprise simultanée après expiration des 800 ms
```

Le comportement du retour contacteurs constitue donc l'anomalie prioritaire. Dans la trace réelle,
les états M1/M2 ressemblent à une permutation des deux retours, mais cette permutation n'est pas
encore prouvée au bornier ou dans le mapping CODESYS chargé.

## 2. Symptôme étudié

À l'entrée dans AX11 :

- `PRG_04_Treuils_Benne...InterlockM2.MotorRequest` tombe à `0` ;
- `PRG_06_Outputs...MotorRequest` tombe également à `0` ;
- les relais de montée M1 et M2 retombent ;
- le joystick et la demande opérateur restent actifs ;
- les deux commandes repartent ensemble après environ 800 ms ;
- le phénomène est présent sur machine, mais absent dans les essais de simulation étudiés.

## 3. Démarche d'investigation

### 3.1 Comparaison réel / simulation

Les traces suivantes ont été comparées :

- réel : `Suivi_83_BonEnSimu_Mais pas en reelAX10_11_ARRET_20260922.trace` ;
- simulation : `Suivi_83_AX10_11_ARRET_20260922.trace` ;
- réel détaillé : `Suivi_84_AX10_11_ARRET_20260922.trace`.

Les variables de décision ont été suivies depuis la demande de cycle jusqu'aux relais physiques :

```text
Cycle AX10/AX10B/AX11
  → demande montée
  → FB_WinchDirectionInterlock
  → DirectionChangePending
  → garde de départ couplé M1/M2
  → MotorRequest PRG_04
  → interlock final PRG_06
  → relais de montée
```

### 3.2 Traçage inverse du délai

Le délai de montée est configuré à `T#800ms` pour chaque treuil :

- `PRG_04_Treuils_Benne.st:1452` pour M1 ;
- `PRG_04_Treuils_Benne.st:1518` pour M2 ;
- valeur par défaut identique dans `ST_fbWinch_Cfg.st:19`.

Le code de `FB_WinchDirectionInterlock` :

1. accumule le temps d'arrêt réel dans `StoppedTimer` ;
2. capture ce temps au front d'une nouvelle demande ;
3. calcule `RemainingDelay := EffectiveDelay - CapturedStoppedTime` ;
4. interdit temporairement la nouvelle direction pendant le reliquat.

Le délai de 800 ms n'est donc pas censé provoquer une coupure systématique : un arrêt déjà confirmé
pendant au moins 800 ms doit donner un reliquat nul.

### 3.3 Analyse des retours contacteurs

Pour M1, l'accumulation du temps d'arrêt n'est autorisée que lorsque :

```text
StepNumber = 0
ET Sensors.ContactorsAllOff = TRUE
ET aucune demande active
```

`Sensors.ContactorsAllOff` est alimenté directement par
`PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI`.

Dans la trace réelle :

- M1 reste au neutre pendant AX10 ;
- le relais M1 reste à `0` et le frein M1 reste appliqué ;
- lorsque M2 démarre seul, `M1_ContactorsReleased_DI` passe de `1` à `0` ;
- ce niveau reste à `0` pendant environ 7,8 s avant AX11 ;
- le crédit d'arrêt M1 est donc nul au moment de la demande de montée.

Dans la simulation, pendant le mouvement M2 seul, les valeurs sont cohérentes :

```text
(M1_ContactorsReleased_DI, M2_ContactorsReleased_DI) = (1, 0)
```

Sur la machine réelle, la trace donne au contraire :

```text
(M1_ContactorsReleased_DI, M2_ContactorsReleased_DI) = (0, 1)
```

Cette corrélation dure 78 échantillons. Elle est peu compatible avec un simple rebond de contact et
fortement compatible avec un croisement de signaux, de câblage ou de mapping.

## 4. À quoi sert D18 ?

**D18** est l'identifiant historique de la décision de conception concernant l'interlock de sens.
Ce n'est ni une entrée physique ni une durée de 18 ms.

Son rôle est d'empêcher une commande immédiate dans le sens opposé après une descente ou après une
retombée de contacteurs insuffisamment confirmée. Pour une demande vers la montée :

```text
Temps restant = 800 ms - temps d'arrêt physique déjà confirmé
```

Exemples :

| Arrêt physique crédité avant la montée | Attente restante |
|---:|---:|
| 900 ms | 0 ms |
| 500 ms | 300 ms |
| 0 ms | 800 ms |

Dans le cas étudié, M1 est mécaniquement arrêté, mais le DI reçu par le programme ne confirme pas
cet arrêt. D18 applique donc logiquement son délai complet.

## 5. Rôle d'AX10B

AX10B doit raccorder la fermeture de la benne à la montée couplée en maintenant M2 au palier 1.
Cette étape peut être très courte, éventuellement un seul cycle automate, lorsque ses conditions de
transfert sont déjà vraies.

La condition actuelle `M1FinalAscentStartReady` vérifie la disponibilité de la barrière finale de
sortie, mais ne prouve pas que le crédit d'arrêt D18 de `PRG_04` est acquis. AX10B peut donc autoriser
AX11 alors que M1 doit encore attendre.

Cette faiblesse explique pourquoi le délai devient visible à AX11, mais elle n'est pas la cause
initiale du reliquat complet. Même avec une AX10B plus longue, le compteur D18 resterait remis à zéro
tant que `M1_ContactorsReleased_DI = FALSE`.

## 6. Hypothèses écartées ou secondaires

### 6.1 Mesure de vitesse

La trace détaillée montre que la vitesse M2 commence à diminuer **après** la retombée du relais. La
baisse de vitesse est une conséquence de la coupure. De plus, `FB_WinchDirectionInterlock` ne reçoit
aucune mesure de vitesse.

**Verdict :** la mesure de vitesse ne déclenche pas le D18 observé.

### 6.2 Anticipation de fermeture de la benne

Le seuil de fermeture est atteint vers un écart relatif d'environ 13,8 m dans les traces réelle et
simulée. La position absolue de M2 est pourtant différente. L'anticipation de 1,2 m détermine le
moment du transfert, mais elle ne produit pas la temporisation de 800 ms.

**Verdict :** fonction à conserver ; elle n'est pas la cause directe de la pause.

### 6.3 Régression récente du code

La comparaison avec la base du matin `8ec1fa28` n'a pas identifié de différence pertinente dans la
chaîne AX10/AX10B/AX11, `FB_WinchDirectionInterlock`, `PRG_04` ou `PRG_06`. Les mécanismes D18 et AX10B
sont déjà présents dans cette base.

**Verdict :** aucune régression postérieure à cette base n'est prouvée pour ce symptôme.

## 7. Nature des DI et limite de preuve actuelle

En mode réel, le code copie directement les variables d'entrée dans `HwReal.Winch` :

```text
M1_ContactorsReleased_DI → HwReal.Winch.M1_ContactorsReleased_DI
M2_ContactorsReleased_DI → HwReal.Winch.M2_ContactorsReleased_DI
```

Puis `HwIn.Winch` sélectionne les entrées réelles ou simulées selon
`WinchInputSourceSimulated`. Les DI simulées sont calculées dans `FB_SimBench`; les DI réelles ne sont
pas recalculées par cette chaîne ST.

Le mapping de référence indique :

| Signal | Adresse prévue |
|---|---|
| `M1_ContactorsReleased_DI` | `%IX0.0`, Local Digital IO bit 0 |
| `M2_ContactorsReleased_DI` | `%IX0.2`, Local Digital IO bit 2 |

Ces adresses documentent l'intention du projet. Elles ne prouvent pas le mapping effectivement chargé
dans l'équipement. Conformément aux règles du projet, aucun ancien `Device.export` ne doit servir de
preuve ; un contrôle en ligne ou un export CODESYS frais est nécessaire.

Un signal numérique change naturellement de manière franche. En revanche, s'il change sans mouvement
du contacteur correspondant, les causes possibles sont :

1. retour M1 et retour M2 croisés dans le mapping CODESYS ;
2. fils ou contacts auxiliaires croisés au bornier ;
3. mauvais contact auxiliaire intégré dans la chaîne de retour ;
4. variable forcée ou source de simulation sélectionnée ;
5. plus rarement, défaut électrique ou instabilité de l'entrée.

## 8. Contrôle terrain décisif

### 8.1 Variables à surveiller

```text
WinchInputSourceSimulated
M1_ContactorsReleased_DI
M2_ContactorsReleased_DI
HwReal.Winch.M1_ContactorsReleased_DI
HwReal.Winch.M2_ContactorsReleased_DI
HwIn.Winch.M1_ContactorsReleased_DI
HwIn.Winch.M2_ContactorsReleased_DI
M1_RelayAscent_RQ / M1_RelayDescend_RQ
M2_RelayAscent_Close_RQ / M2_RelayDescend_Open_RQ
```

`WinchInputSourceSimulated` doit être `FALSE` pendant ce contrôle.

### 8.2 Matrice d'essai attendue

Après mise en sécurité et selon la procédure d'essai machine autorisée :

| État physique | M1 Released attendu | M2 Released attendu |
|---|---:|---:|
| Tous les contacteurs retombés | 1 | 1 |
| M1 seul actif | 0 | 1 |
| M2 seul actif | 1 | 0 |
| M1 et M2 actifs | 0 | 0 |

Comparer pour chaque essai :

1. l'état mécanique du contacteur ;
2. la LED du canal d'entrée ;
3. la variable d'entrée CODESYS brute ;
4. `HwReal.Winch` puis `HwIn.Winch`.

### 8.3 Interprétation

| Observation | Localisation probable |
|---|---|
| LED physique correcte, variable CODESYS incorrecte | mapping appareil CODESYS |
| LED du mauvais canal suit le contacteur | câblage ou contact auxiliaire |
| variable brute correcte, `HwReal` incorrect | copie ou programme chargé incohérent |
| `HwReal` correct, `HwIn` incorrect | sélection réel/simulation |
| tous les niveaux corrects mais D18 complet | reprendre la trace de `StoppedTimer.ET`, `CapturedStoppedTime` et `RemainingDelay` |

## 9. Conclusions et ordre de correction

### Conclusion confirmée

La pause observée est la combinaison suivante :

```text
D18 M1 attend 800 ms
  + garde de départ atomique M1/M2
  = disparition simultanée des commandes M1 et M2 à AX11
```

Le délai complet est demandé parce que le retour `M1_ContactorsReleased_DI` empêche le crédit d'arrêt
de M1 pendant que M2 travaille seul.

### Conclusion très probable, à confirmer sur machine

Les deux retours contacteurs M1/M2 sont possiblement permutés entre le matériel et les variables
automate. La trace apporte une forte présomption, mais seule la matrice d'essai terrain peut localiser
et confirmer le croisement.

### Correction qui conserve le maximum de fonctions

1. **Corriger d'abord le DI ou son mapping** afin que chaque retour corresponde réellement à son axe.
2. **Conserver D18 à ce stade** : avec un retour correct, les 800 ms sont créditées pendant l'arrêt et
   ne doivent plus créer une pause supplémentaire à AX11.
3. **Conserver les anticipations de benne** de 1,2/1,3 m, qui ne déclenchent pas le délai.
4. Après correction du DI, refaire plusieurs cycles réels et vérifier que
   `CapturedStoppedTime ≥ 800 ms`, `RemainingDelay = 0 ms` et qu'aucun trou n'apparaît.
5. Traiter ensuite séparément la robustesse d'AX10B : elle devrait vérifier explicitement la
   disponibilité de l'interlock amont avant AX11. Cette évolution est un changement de sécurité à
   cadrer et valider avant modification du code.

## 10. Niveau de confiance

| Point | Niveau |
|---|---|
| D18 M1 produit les 800 ms | **Confirmé par trace** |
| La garde couplée coupe aussi M2 | **Confirmé par trace et code** |
| La chute de vitesse déclenche la pause | **Écarté** |
| L'anticipation de 1,2 m déclenche D18 | **Écarté** |
| Le DI M1 empêche le crédit d'arrêt | **Confirmé par trace et code** |
| Retours M1/M2 physiquement ou logiquement permutés | **Très probable, contrôle terrain requis** |
| AX10B doit être renforcée | **Faiblesse secondaire identifiée** |

---

**Aucune modification du code automate n'a été réalisée dans cette investigation.**
