# 🧪 Audit framework tests PLC — v1.0

> **Statut :** diagnostic read-only, aucune modification CODE proposée ici.
>
> **Déclencheur :** la suite Modes démarrait à l'étape 10 alors que son préambule obligatoire d'armement Safety est l'étape 5. Le test pouvait donc échouer à l'étape 10 avec `EmergencyStopOk=FALSE`, sans indiquer que son environnement n'avait jamais été préparé.
>
> **Décision :** geler les patchs ponctuels de tests et traiter la fiabilité du framework comme un chantier dédié `TEST-FRAMEWORK-01`.

---

## 1. Conclusion

Le défaut n'est pas seulement dans TC-M1. Le projet a actuellement **deux modèles de banc de test actifs** :

| Modèle | État | Suites |
|---|---|---|
| `CASE Step OF` local : timers, états, rapports et cleanup propres à chaque suite | Legacy actif | `FB_ModesValidation`, `FB_EncoderValidation` |
| Tables déclaratives + `FB_TestSequencer` + sondes + stimuli + rapport uniforme | Cible Part.14 §7, partiellement déployée | Safety, Translation, Bucket, Heartbeat |

Les deux modèles n'ont pas le même contrat de démarrage, de précondition, d'abort, de timeout, de cleanup ni de reporting. Le manager doit donc connaître des conventions internes. Cela rend le banc fragile.

> 🎯 Un test automatique doit démarrer par **Suite + Cas**, jamais par une étape interne. Il doit préparer ou refuser explicitement ses préconditions avant toute assertion métier.

---

## 2. Fait observé : Suite Modes

### Chaîne attendue

```text
Préambule étape 5
→ CmdEmergencyArming
→ PRG_10 : EmergencyArming_RQ
→ scan suivant PRG_00 : FB_Sim_Safety / SimContactorOk
→ filtre entrée : EmergencyStopOk=TRUE
→ PRG_04 : FB_Modes autorise MAINT_N1
→ étape 10 : assertion métier Modes
```

### Défaut

`FB_PLC_Tests_Management` lance actuellement la suite Modes avec :

```st
FirstStepModes := 10;
```

alors que `FB_ModesValidation` définit :

```st
5: // préambule obligatoire
    GVL_IHM.Modes.CmdEmergencyArming := TRUE;
    IF PRG_00_Inputs.EmergencyStopOk THEN
        Step := 10;
    END_IF;
```

L'étape 10 est donc lancée sans armement simulé. `FB_Modes` reste correctement en `DISABLE` car `EmergencyStopOk=FALSE`, puis le test donne un timeout ambigu à l'étape 10.

### Cause architecture

Le manager connaît et manipule un détail d'implémentation (`FirstStepId`) au lieu de demander un **cas public**. Le setup n'est ni encapsulé ni vérifié.

---

## 3. Constats critiques 🔴

### C1 — Deux moteurs incompatibles

- **Fichiers :**
  - `CODE/SIMULATION/PLC_TESTS/FB_TestSequencer.st`
  - `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st`
  - `CODE/SIMULATION/PLC_TESTS/SUITE_ENCODER/FB_EncoderValidation.st`
- **Risque :** règles différentes selon la suite : validation de config, timeout, abort, cleanup, format rapport.
- **Décision :** ne pas créer un troisième style. Migrer les suites legacy vers le moteur unique après durcissement de celui-ci.

### C2 — Steps internes exposés au manager

Le manager construit directement `FirstStepSafety`, `FirstStepTranslation`, `FirstStepBucket`, `FirstStepEncoder`, `FirstStepModes`, `FirstStepHeartbeat`.

- **Risque :** saut setup / teardown, état non préparé, faux échec ou faux succès.
- **Règle cible :** le manager ne connaît que `SuiteId` et `CaseId`; chaque suite traduit `CaseId` vers son setup déclaré.

### C3 — Refus de gate silencieux

Le manager consomme une demande même si `SimulationModeActive` ou `SimGateOk` sont faux, sans toujours générer de résultat terminal explicite.

- **Risque :** l'opérateur ne sait pas si le test a été refusé, n'a pas démarré, ou montre un rapport précédent.
- **À faire :** état terminal `PRECONDITION_FAILED`, code, message et snapshot des gates.

### C4 — Abort global incomplet

Dans le bloc d'abort/perte simulation du manager, Safety, Translation, Bucket et Heartbeat sont abortées, mais **Encoder et Modes ne le sont pas explicitement**.

- **Fichier :** `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_PLC_Tests_Management.st`
- **Risque :** stimuli actifs jusqu'au timeout local, rapport incohérent.
- **À faire :** abort unique et complet de la suite active; aucun cas particulier oublié.

### C5 — Suite Modes mélange unité et intégration

| Contenu actuel dans `FB_ModesValidation` | Nature réelle |
|---|---|
| Modes, homme-mort, DISABLE, cycle hors semi-auto | Intégration `PRG_00…PRG_10` |
| Bypass codeur, `ConfigError`, charge montée, seuil Cycle | Unitaire via instances locales |
| Purge RETAIN | Intégration boot / commandes IHM |

- **Risque :** setup lourd pour tests unitaires, rapport sans niveau clair, couplage global inutile.
- **Décision :** scinder cette suite lors de la migration.

---

## 4. Constats importants 🟠

### I1 — Les préconditions ne sont pas des objets testables

Le préambule Modes est une étape spéciale `5`; `CaseId := Step / 10` le classe même hors cas (`0`).

- **À faire :** chaque cas commence par un setup appartenant au cas, ou la suite utilise une fixture partagée qui publie `FixtureReady` / `FixtureFailed`.

### I2 — Rapport Modes : 12 TC annoncés, un seul cas publié

La fin de la suite publie :

```st
Report.Cases[1].Name := 'TC-M1..M12 Modes+WinchCore';
```

- **Impact :** impossible d'obtenir le diagnostic demandé : « quelle suite, quel TC, quelle étape, pourquoi ».
- **À faire :** un vrai cas par TC avec setup, teardown et résultat individuel.

### I3 — Nettoyage stimuli non uniforme

Chaque suite nettoie une liste différente d'overrides et de commandes IHM. Des commandes comme `ModeRequest`, `CmdEmergencyArming`, `FaultMachineReset`, `CmdStart`, homing, joystick, bypass, M3 ou Bucket peuvent conserver un état inattendu entre deux runs.

- **À faire :** ownership déclaré de chaque stimulus, état neutre complet, réaffectation complète par scan, cleanup structurel sur Done / Fail / Abort / watchdog / gate perdu / config error.

### I4 — `GVL_PLC_Tests` a trop de responsabilités

Elle mélange : commandes IHM, status, rapports, journal, stimuli Safety, joystick, M3, Bucket, retours frein/contacteurs, purge.

- **Conserver :** commande, status, rapports et stimuli amont nécessaires au raccordement simulation.
- **Retirer de la GVL :** tables, indices, timers, état de suite, instances et variables intermédiaires.
- **Ajouter :** producteur unique, consommateur, neutralité et suites autorisées pour chaque override.

### I5 — `OverrideEmergencyStopOkTrue` sans propriétaire démontré

- Déclaré dans `GVL_PLC_Tests`.
- Consommé dans `PRG_00_Inputs`.
- Pas de suite identifiée qui l'utilise et le nettoie.

**Décision requise :** retirer cette capacité, ou l'officialiser (suite propriétaire, scénario justifié, test de cleanup).

### I6 — Ordre de scan non formalisé

Les tests intégration dépendent de `PRG_00 → … → PRG_10 → scan suivant PRG_00`. Les délais de propagation doivent être modélisés par setup/stabilisation/check `WAIT_UNTIL`, pas absorbés par un timeout arbitraire de 3 s ou 5 s.

---

## 5. Dette documentaire 🟡

Partie 14 §7 décrit une cible déclarative : moteur unique, tables, setup/teardown, run case via setup et stimuli complets. Le code reste hybride.

À synchroniser :

- suites réellement migrées vs legacy;
- `RunAll` décrit déprécié mais logique `ChainMode` encore présente;
- anciennes mentions `CmdRunTests`;
- exemples `MaxSuites := 4` alors que le code gère 6 suites;
- nommage et catalogue des TC.

---

## 6. Décision par composant

| Composant | Décision | Action |
|---|---|---|
| `FB_TestSequencer` | Conserver | Durcir validation et états terminaux |
| `FB_TestCheck` | Conserver | Tester ses modes et snapshots |
| `FB_Timeout` | Conserver | Brique transverse |
| `FB_TestStimulus` | Conserver | Conserver profils temporisés/analogiques |
| `FB_TestStopwatch` | Conserver | Mesure déterministe par cycles |
| `FB_TestEventOrder` / `FB_TestEdgeCounter` | Conserver | Vérifier ordre et fronts |
| `FB_PLC_Tests_Management` | Refactorer | Suite+Cas, gate explicite, abort complet |
| Safety / Translation / Bucket / Heartbeat | Conserver | Revue cleanup/gates/transitions |
| `FB_ModesValidation` | Scinder puis migrer | Intégration Modes / unités Winch / Boot RETAIN |
| `FB_EncoderValidation` | Migrer | Remplacer CASE local par moteur unique |
| `GVL_PLC_Tests` | Réduire/documenter | Ownership strict des stimuli |

---

## 7. Architecture cible

```text
CODE/SIMULATION/PLC_TESTS
├─ BRICKS/
│  ├─ FB_Timeout
│  ├─ FB_TestCheck
│  ├─ FB_TestStimulus
│  ├─ FB_TestStopwatch
│  ├─ FB_TestEventOrder
│  └─ FB_TestEdgeCounter
├─ FB_TestSequencer                 // moteur unique
├─ FB_TestFixtureIntegration        // Prepare → Ready → Cleanup
├─ UNIT/
│  ├─ FB_WinchCoreUnitValidation
│  ├─ FB_SafetyWinchUnitValidation
│  └─ FB_CycleUnitValidation
└─ INTEGRATION/
   ├─ FB_SafetyIntegrationValidation
   ├─ FB_ModesIntegrationValidation
   ├─ FB_EncoderIntegrationValidation
   ├─ FB_TranslationIntegrationValidation
   ├─ FB_BucketIntegrationValidation
   └─ FB_BootCommandsIntegrationValidation
```

### Tests unitaires

- instance locale du FB métier;
- aucune écriture `GVL_IHM`, `PRG_*` ou override global;
- stimulation uniquement via l'interface du FB;
- résultat rapide, déterministe, indépendant de l'ordre de tâche.

### Tests d'intégration

- cible : flux réel `PRG_00…PRG_10`;
- passage obligatoire par la fixture;
- gates `_IsReal` explicites;
- temps de propagation mesurés et documentés;
- stimulation uniquement en amont; sorties calculées observées en lecture seule.

---

## 8. Fixture d'intégration requise

Créer `FB_TestFixtureIntegration`.

### Responsabilité unique

```text
Prepare → VerifyReady → Cleanup
```

### Exigences

1. neutraliser les stimuli dont elle est propriétaire;
2. vérifier Simulation active et flags `_IsReal` incompatibles;
3. remettre les commandes au neutre;
4. armer la chaîne Safety simulée par le flux réel si requis;
5. attendre `EmergencyStopOk=TRUE` si requis;
6. attendre une stabilisation de cycles documentée;
7. publier `FixtureReady` ou `FixtureFailed` avec code/message;
8. nettoyer sur tous les chemins terminaux.

La suite Modes ne contiendra alors plus le préambule technique d'armement comme une pseudo-étape de cas métier.

---

## 9. Évolutions du moteur générique

`FB_TestSequencer` doit, avant migration des suites legacy, vérifier :

- `FirstStepId` = `CaseTable[CaseId].FirstStep` valide;
- step de départ avec `CaseId > 0`;
- cohérence `CaseTable.FirstStep ↔ StepTable.CaseId`;
- transitions valides, sans boucle sans sortie;
- chemins d'échec vers teardown;
- timeouts définis;
- cohérence des checks et indices de sondes;
- stimulus référencé et état neutre possible.

États terminaux à distinguer :

| État | Signification |
|---|---|
| `CONFIG_ERROR` | tables / code de suite invalides |
| `PRECONDITION_FAILED` | fixture/gate indisponible |
| `FAILED` | assertion métier échouée |
| `ABORTED` | opérateur ou gate perdu |
| `WATCHDOG_TIMEOUT` | timeout global |

---

## 10. Plan de migration `TEST-FRAMEWORK-01`

### M0 — Gel et inventaire

- aucune extension de suite sans contrat;
- classer chaque TC : unité / intégration / boot / simulation;
- pour chaque stimulus : producteur, consommateur, neutre, cleanup, suite autorisée;
- lister les sondes, gates et preuves d'exécution.

**Sortie :** matrice approuvée humainement.

### M1 — Manager robuste

- manager limité à Suite + Case;
- gate refusée avec rapport terminal;
- abort global complet;
- watchdog et perte simulation propres;
- cleanup vérifié;
- suppression réelle de `RunAll` mort, ou réactivation spécifiée et testée.

**Tests du manager :** start, gate absent, abort, watchdog, perte simulation, run après échec, cleanup.

### M2 — Fixture

- créer et tester `FB_TestFixtureIntegration`;
- armer Safety simulée par le vrai flux;
- prouver refus si E/S réelles incompatibles;
- prouver neutralisation après chaque terminal.

### M3 — Migration Modes et séparation

| Nouvelle suite | Contenu |
|---|---|
| `FB_ModesIntegrationValidation` | TC-M1…M7 |
| `FB_WinchCoreUnitValidation` | TC-M8…M11 |
| `FB_BootCommandsIntegrationValidation` | TC-M12 |

### M4 — Migration Encoder

- deux cas réels : interface puis homing;
- moteur déclaratif;
- fixture;
- teardown `CmdHome`;
- rapports individuels.

### M5 — Revue des suites déjà déclaratives

Safety, Translation, Bucket, Heartbeat : gates, ownership, cleanup, transitions échec→teardown, timing et `RunCase`.

### M6 — Retrait legacy et synchronisation DOC

- supprimer moteurs CASE legacy;
- supprimer les `FirstStep*` du manager;
- mettre Partie 14 et `VERSION_HISTORY.md` à jour;
- revue C4 de tout lot Safety / AU / contacteurs / PowerCutOff.

---

## 11. Critères d'acceptation finaux

### Démarrage

- [ ] Une suite démarre par `SuiteId + CaseId`, jamais par StepId.
- [ ] Un cas commence toujours par son setup.
- [ ] Précondition absente = état terminal explicite.

### Runtime

- [ ] Abort et perte simulation arrêtent toute suite active.
- [ ] Done / Fail / Abort / watchdog / config error nettoient les stimuli.
- [ ] Deux exécutions successives donnent le même résultat depuis le même environnement.

### Intégrité

- [ ] Aucun test ne force une sortie calculée (`SafeStop`, `PowerCutOff`, `_DQ`, etc.).
- [ ] Chaque stimulus est amont, documenté, propriétaire unique et neutre en sortie.

### Diagnostic

- [ ] Rapport : suite, TC, étape, check, valeur observée, durée et cause.
- [ ] Non-exécuté ≠ échoué.
- [ ] Résultat consultable jusqu'au run suivant / clear explicite.

### Preuves

- [ ] Tests des briques framework.
- [ ] Tests manager + fixture.
- [ ] Exécution CODESYS tracée pour chaque suite.
- [ ] Revue C4 obligatoire pour chaîne AU, contacteurs, PowerCutOff, SafeStop et safety.

---

## 12. Priorités

| Priorité | Lot |
|---|---|
| **P0** | M1 manager : abort, gates, terminal explicite, interfaces publiques |
| **P0** | M2 fixture intégration |
| **P1** | M3 scission/migration Modes |
| **P1** | M4 migration Encoder |
| **P2** | M5 revue suites déclaratives |
| **P2** | M6 retrait legacy + synchronisation documentaire |

> ✅ Le but n'est pas d'augmenter la modularité. Le but est d'avoir des frontières cohérentes : briques génériques réutilisables, mais lifecycle de test atomique et protégé.
