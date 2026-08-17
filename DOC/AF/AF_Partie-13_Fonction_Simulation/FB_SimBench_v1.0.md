# FB_SimBench — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.3.md`](../AF_Partie-13_Fonction_Simulation_v2.3.md) §2/§4.
> Rôle de **ce** document : enveloppe unique de simulation banc — composition, câblage des
> décalages 1-scan, table des sous-modèles — et **catalogue unique** des `TC-P13-010...`.
> Source code : `CODE/L_SIMULATION/FB_SimBench.st` · instance `PRG_02_Acquisition.instSimBench`.

## 🧭 Sommaire

1. Rôle et profil
2. Composition (4 sous-modèles)
3. Interface — entrées bouclées avec décalage 1 scan
4. StatusWord AC600 simulé — polarité et REX Méca B
5. Alertes et écarts
6. Documents liés

## 🧪 Points de validation (`TC-P13-010...` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P13-010</code></nobr> | `Enable=FALSE` neutralise tout le banc en un seul `RETURN` (aucun sous-modèle actif) | `💻 AUTO` |
| <nobr><code>TC-P13-011</code></nobr> | 0 lecture de `GVL_*` en interne — toutes les entrées passées en paramètres par l'appelant (`PRG_02_Acquisition`) | `👁️ MANUEL` |
| <nobr><code>TC-P13-012</code></nobr> | `M1_BrakeIsOpen_DI := M1_BrakeCmd` (jamais de `NOT`) — polarité maintien (`P1 Lot L6`) | `💻 AUTO` |
| <nobr><code>TC-P13-013</code></nobr> | 🆕 `M3_StatusWordSim` bit0 retombe à l'arrêt (`Direction=0`) — ne déclenche plus `FB_Safety_Translation` Méca B en continu | `💻 AUTO` |

---

## 1. Rôle et profil

🎯 Enveloppe **unique** de simulation pour banc d'essai : compose les 4 blocs de modèle physique
existants et publie une image `ST_HardwareImage` complète (`Winch`, `Translation`, `Operator`,
`Machine`) équivalente à ce qu'un vrai jeu de PDO fournirait. Consommée exclusivement par
`PRG_02_Acquisition` (Partie 02 §4), jamais directement par un FB métier (doctrine §1 de la
Partie 13 : « aucun FB métier ne lit `GVL_Simulation` ni `HwSim` »).

🔒 **Brique réduite, 0 lecture de GVL interne** : toutes les entrées (commandes du scan
précédent, stimuli `GVL_Simulation.*`, `HwReal`) sont passées en paramètres par
`PRG_02_Acquisition.st:228-277`. Ce choix rend le FB testable isolément et rend visible, dans
un seul appel, **tous** les couplages temporels avec le reste du programme (voir §3).

Instance : `PRG_02_Acquisition.instSimBench`, `Enable := GVL_Simulation.SimulationModeActive`
(bit maître seul — l'aiguillage par domaine se fait après, sur `HwIn`).

---

## 2. Composition (4 sous-modèles)

| Bloc | Instance | Rôle | Fiche |
|---|---|---|---|
| `FB_Sim_Encoder` ×2 | `instSimEncoderM1/M2` | Position codeur COD1/COD2, presets, écart synchro | `FB_Sim_Encoder_v1.0.md` |
| `FB_Sim_Translation` | `instSimTranslation` | Trajet continu M3, 5 capteurs par mot thermomètre | `FB_Sim_Translation_v1.0.md` |
| `FB_Sim_Joystick` | `instSimJoystick` | Valeurs Hall brutes + homme-mort forçables | `FB_Sim_Joystick_v1.0.md` |
| `FB_Sim_Safety` | `instSimSafety` | Chaîne AU, contacteur, réarmement | `FB_Sim_Safety_v1.0.md` |

Chaque sous-modèle reste indépendant (pas d'inter-dépendance directe) ; `FB_SimBench` se contente
de les appeler et d'assembler leurs sorties dans les 4 sous-images `ST_HardwareImage`.

---

## 3. Interface — entrées bouclées avec décalage 1 scan

Certaines entrées de `FB_SimBench` sont des **sorties du scan précédent** de `PRG_06_Outputs_LD`
(le programme sortie tourne **après** l'acquisition dans la `MainTask`, Partie 02 §4) : le banc
rejoue donc la vraie chaîne de commande, avec le même retard d'1 scan qu'un vrai automate aurait
entre une sortie et sa relecture. C'est **documenté et voulu** (Partie 01 §7 « Correctif L1 »),
pas un bug — mais c'est le point le plus piégeux de tout le FB, à connaître avant de diagnostiquer
un blocage simulation :

| Entrée `FB_SimBench` | Source | Décalage |
|---|---|---|
| `PowerKeepAlive_A` | `PRG_06_Outputs_LD.PowerKeepAliveACmd` | 1 scan (PRG_02 avant PRG_06) |
| `PowerKeepAlive_B` | `PRG_06_Outputs_LD.PowerKeepAliveBCmd` | 1 scan |
| `EmergencyArming_RQ` | `PRG_06_Outputs_LD.EmergencyArmingCmd OR (ArmingSeqStep=5)` | Le `OR` corrige le retard sur `EmergencyArmingCmd` seul ; `ArmingSeqStep` lui-même reste lu avec 1 scan de retard (non éliminé, sans conséquence connue vu la durée du pulse ≥ plusieurs scans) |
| `M1/M2_RelayFwd/Rev`, `M1/M2_SpeedContactor_1..4` | `GVL_Global.*` (recopie `PRG_06_Outputs_LD`) | 1 scan |
| `M1/M2_BrakeCmd`, `M3_BrakeCmd` | `GVL_Global.*` | 1 scan |

⚠️ Ce décalage est la première hypothèse à vérifier devant un comportement simulation qui
« devrait » être vrai d'après le calcul mais reste faux en régime transitoire (quelques scans,
quelques ms) — **mais ne peut pas expliquer un blocage stable sur plusieurs secondes**. Au-delà
de quelques scans, chercher ailleurs (latch AU réel — voir `FB_Sim_Safety_v1.0.md §4` — ou bug de
modèle comme au §4 ci-dessous).

---

## 4. StatusWord AC600 simulé — polarité et REX Méca B

```text
IF (M3_Direction <> 0) THEN
    M3_StatusWordSim := 16#0087;  // Power Ready + Comm Ready + Operating/Running
ELSE
    M3_StatusWordSim := 16#0080;  // Comm Ready seul — Power Ready retombé, arrêt confirmé
END_IF;
```

Bit0 = **Power Ready** (confirmé par `PRG_05_Translation.st:421`,
`TranslationStateHMI.DrivePowerReady`), bit7 = Comm Ready. Seul lecteur diagnostic de
`DrivePowerReady` : affichage IHM (`ST_TranslationState.st:34`) — aucun interlock ne le consomme,
donc aucune régression de mouvement possible en changeant sa valeur à l'arrêt.

> 🚨 **REX 2026-08-14** : avant ce lot, bit0 restait forcé à `1` en continu même à l'arrêt
> (`16#0081`). `FB_Safety_Translation.st:181` (Méca B, Partie 11) lit ce même bit comme indicateur
> de **mouvement non commandé** (`UncommandedActiveB := DriveStatusWord.0 OR BrakeFeedback`) —
> avec bit0 bloqué à 1, ce test se déclenchait en boucle après `PostRampTimeout` (3s), provoquant
> un `PowerCutOff` simulé permanent qui coupait `PowerKeepAlive_A/B` et bloquait
> `Step3_EmergencyChainClosed`. Jamais reproduit avec matériel réel connecté (non testé dans cette
> condition avant ce REX). **Écart potentiel plus large non tranché** : voir `PLAN_TASK.md T110`
> — le variateur AC600 réel garde-t-il "Power Ready" à 1 en continu à l'arrêt (comme la sémantique
> du nom le suggère), auquel cas `FB_Safety_Translation.st:181` aurait la même faille dormante côté
> réel, jamais déclenchée faute d'essai >3s d'arrêt stable avec les bonnes conditions ?

---

## 5. Alertes et écarts

| # | Gravité | Point | Détail |
|---|---|---|---|
| 1 | ✅ résolu (ce lot) | Bit0 `M3_StatusWordSim` forcé à l'arrêt, faux Méca B permanent | REX 2026-08-14, voir §4 |
| 2 | 🟡 ouvert | `T110` — sémantique réelle de `DriveStatusWord.0` sur AC600, à confirmer terrain/constructeur | `PLAN_TASK.md T110` |
| 3 | ℹ️ sans conséquence connue | `FB_Sim_Safety.Enable` câblé en dur `TRUE`, contredit son propre commentaire d'en-tête | Voir `FB_Sim_Safety_v1.0.md §1` |

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation, doctrine §1, garde-fous §6 |
| AF13 / FB_Sim_Safety | Piège latch AU §4 — lecture obligatoire avant tout diagnostic de blocage armement |
| AF11 / FB_Safety_Translation | Consommateur réel de `DriveStatusWord`, propriétaire Méca A/B |
| AF02 §4 | Ordre `MainTask`, base du décalage 1 scan |
| Code | `CODE/L_SIMULATION/FB_SimBench.st`, `CODE/M_MAIN/PRG_02_Acquisition.st:228-277` |
