🟡 ADVISORY — Le modèle M3 ne peut pas produire le dépassement de butée  
Verdict : la simulation s’arrête structurellement à la butée électrique ; elle ne peut pas représenter un choc mécanique au-delà. Toute conclusion « pas de choc » est invalide en l’état.  
Horodatage : session courante — analyse statique lecture seule.

## 1. Invariants vérifiés

1. `[✅ PASS]` Formule discrète du modèle actuel reconstituée : `v[n] = 0.02 × f_e[n]`, avec `f_cmd[n] = max(0, f0 − 0.25n)`, `f_e[n] = 0.75 f_e[n−1] + 0.25 f_cmd[n]`, `dt = 0.01 s`, `α = 0.25`.
2. `[✅ PASS]` À 5 Hz, avec bobine coupée au début du scan et `PhysicalBrakeActive=TRUE`, distance d’arrêt exacte : `0.008000 m`.
3. `[✅ PASS]` À 10 Hz, mêmes hypothèses : distance d’arrêt exacte : `0.0216749 m`.
4. `[✅ PASS]` Ces distances sont très inférieures à `EndStopMargin = 0.5 m` : il reste respectivement `0.492 m` et `0.478 m` avant la butée électrique.
5. `[✅ PASS]` Même dans le cas le plus défavorable où la bobine reste alimentée jusqu’au seuil variateur `0.5 Hz`, la distance reste `0.012164 m` à 5 Hz et `0.044663 m` à 10 Hz.
6. `[✅ PASS]` Le modèle clipse explicitement la position à `EndStopTremie_M` / `EndStopMaintenance_M` et force `VelocityTrue_Mps := 0.0` : aucun dépassement de la butée électrique n’est représentable.
7. `[❌ FAIL]` Le modèle ne contient pas de butée mécanique distincte, ni compliance/penetration/contact : il ne peut donc pas reproduire le défaut terrain « dépassement puis choc mécanique ».

## 2. Argumentaire technique

Calcul exact en coupure bobine immédiate, `SpeedFactor=1`, `PhysicalBrakeActive=TRUE` :

```text
dt = 0.01 s
α = dt/(τ+dt) = 0.01/(0.03+0.01) = 0.25
f_cmd[n] = max(0, f0 − 0.25n)
f_e[n] = 0.75 f_e[n−1] + 0.25 f_cmd[n]
v[n] = 0.02 × f_e[n]
```

Le frein reste ouvert pendant 9 scans (`CloseDelay=0.09 s`), puis `v` décroît de `BrakeDecel × dt = 2.0 × 0.01 = 0.02 m/s` par scan.

```text
5 Hz :
  phase variateur n=1..8 : D_rampe = 0.00699505 m
  v8 = 0.07349831 m/s
  phase frein : D_frein = 0.00100495 m
  D_total = 0.00800000 m

10 Hz :
  phase variateur n=1..8 : D_rampe = 0.01499505 m
  v8 = 0.17349831 m/s
  phase frein : D_frein = 0.00667986 m
  D_total = 0.02167492 m
```

À 10 Hz, le chariot parcourt donc environ `2,17 cm` après la coupure. À 5 Hz, environ `0,8 cm`. Avec une marge de `0,5 m`, il s’arrête très loin de la butée électrique.

Mais le point bloquant est ailleurs : `FB_Sim_Translation.st:353-360` et `:400-410` écrivent :

```text
PositionTrue_M := EndStopTremie_M;
VelocityTrue_Mps := 0.0;
HardStopTremieActive := TRUE;
```

La position est projetée exactement sur la butée électrique, sans pénétration possible. Le recul autorisé ensuite `:368-393` est borné par `EndStopRecoilMax_M` et n’autorise le mouvement que dans le sens opposé à la butée touchée. Le modèle ne peut donc jamais aller au-delà de `EndStop..._M` vers un choc mécanique.

## 3. Pourquoi `ObsCartFree` ne déclenche pas le glissement attendu

1. `DriveTorqueActive := (DirectionSign <> 0.0) OR (ElectricalFrequency_Hz > 0.5)` : si l’ordre de marche est maintenu, `DirectionSign` reste `±1`, donc `DriveTorqueActive` reste `TRUE` et `ObsCartFree` reste `FALSE`.
2. Si l’ordre est retiré, `DirectionSign=0`, mais `ElectricalFrequency_Hz > 0.5` maintient encore `DriveTorqueActive=TRUE` pendant la décélération.
3. Au seuil `0.5 Hz`, `FB_Sim_TranslationDrive.st:57-61` force `ElectricalFrequency_Hz := 0.0` et `ActualFrequency_Hz := 0.0`. Dans le même scan, `FB_Sim_Translation.st:294-297` et `:336-338` imposent `VelocityTarget_Mps = 0` puis `VelocityTrue_Mps := VelocityTarget_Mps = 0`. L’énergie cinétique est annulée avant toute intégration libre.
4. Avec `PhysicalBrakeActive=TRUE`, le frein se ferme `CloseDelay_S=0.09 s` après coupure bobine. Ensuite `BrakeMechanicallyOpen=FALSE`, donc `ObsCartFree=FALSE` et le mode libre ne peut plus s’activer.
5. Si la butée est atteinte avant, le clamp `:350-361` a déjà mis `VelocityTrue_Mps=0`. Le mode libre, même activé ensuite, repart de zéro et ne peut pas transporter un momentum vers la butée mécanique.

## 4. Registre des hypothèses physiques manquantes ou sur-idéalisées

1. **Impact très fort — butée électrique confondue avec butée mécanique.**  
   Le modèle clipse à `EndStopTremie_M` / `EndStopMaintenance_M` et ne possède pas de seconde limite mécanique avec compliance, pénétration, raideur ou amortissement. C’est la cause principale de l’absence de choc.

2. **Impact fort — maintien de l’ordre de marche et couple résiduel variateur.**  
   `DirectionSign` maintient `DriveTorqueActive=TRUE` ; à l’inverse, le modèle purge `TravelDirection` contre la butée et annule la vitesse. Un variateur réel peut continuer à pousser quelques centaines de ms, voire maintenir un couple dans l’obstacle.

3. **Impact fort — frein réel : retard, montée de couple, usure, température.**  
   `CloseDelay_S=0.09 s` et `BrakeDecel_Mps2=2.0` sont des constantes. Le modèle ne représente pas le temps de retombée réel, la montée progressive du couple, l’entrefre, l’usure, la température ni la dépendance à la vitesse.

4. **Impact moyen — inertie, glissement rail et frottement statique.**  
   En mode freiné/entraîné, la vitesse est imposée cinématiquement (`VelocityTrue_Mps := VelocityTarget_Mps`) : pas de masse, pas d’inertie, pas de glissement. Le frottement statique n’existe qu’en mode `ObsCartFree`, qui est précisément inhibé dans le scénario.

5. **Impact moyen — latence capteur/scan et logique PLC.**  
   `CycleTime_S=0.01 s` est parfait et synchrone. Le modèle ne représente pas la gigue de scan, le debounce du capteur de fin de course, la latence de l’ordre d’arrêt ni le délai de lecture de position. À `0.2 m/s`, `10 ms` valent déjà `2 mm`.

6. **Impact faible à moyen — pente et charge suspendue.**  
   La réaction de charge n’est intégrée sérieusement qu’en mode libre (`ObsCartFree`) et la pente n’apparaît que dans `FreeAccel_Mps2`. En mode entraîné/freiné, le couple de la charge suspendue et la pente ne sont pas couplés au freinage réel.

## 5. Plan d’action chirurgical recommandé

- **Localisation :** `FB_Sim_Translation.st:350-361` et `:400-410`.
- **Ancre :** `PositionCandidate_M < EndStopTremie_M` / `> EndStopMaintenance_M`.
- **Action exacte :** introduire une butée électrique et une butée mécanique distinctes. La butée électrique doit lever un flag, pas clipper la position. Seule la butée mécanique doit limiter la course, avec raideur/amortissement et pénétration bornée. Ajouter une décroissance de couple variateur et une montée de couple frein.
- **Outil déterministe associé :** rejeu Python des récurrences ci-dessus ; le test doit reproduire exactement `D(5 Hz)=0.00800000 m` et `D(10 Hz)=0.02167492 m` avant modification, puis vérifier qu’un cas avec maintien d’ordre/couple résiduel peut dépasser `EndStopMargin`.
- **Risque si ignoré :** validation fausse d’un scénario de sécurité ; la simulation conclura toujours « arrêt propre » alors que le défaut terrain reste possible.

Aucune modification effectuée — mission en lecture seule.