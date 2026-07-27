# 🧭 SÉQUENCE D'EXÉCUTION — Refonte Simulation (v1.0)

> 🎯 **Rôle** : document **opérationnel** de conduite du chantier. Lots numérotés, points d'arrêt,
> tests, critères GO/NO-GO, rollback. À suivre pendant l'implémentation, à cocher au fur et à mesure.
> 📅 2026-07-27 · **aucun `CODE/` modifié à ce jour**.
> 🔗 Plan de conception : [PLAN_Rationalisation_Simulation_v1.0](PLAN_Rationalisation_Simulation_v1.0.md) ·
> Phasage global : [PLAN_Allegement_Code §5](PLAN_Allegement_Code_v1.0.md)

---

## 0. 📏 Règles de conduite

| Règle | Détail |
|---|---|
| 🧱 **Chaque lot compile** | Aucun lot ne laisse le projet dans un état non compilable |
| 🛑 **Point d'arrêt = validation explicite** | Rien n'enchaîne sans ton GO |
| 📦 **1 lot = 1 commit** | Rollback = `git revert` d'un seul commit |
| 🖐️ **Application manuelle** | Chaque lot fournit sa **note d'application CODESYS** (objets, ordre d'import) |
| 🔒 **Structures IHM préservées** | **Aucun nom mappé dans la visu n'est renommé, déplacé ou supprimé.** Seuls les champs `.Test` (jamais mappés) partent, en L3. La perte des valeurs `PERSISTENT`/`RETAIN` au download est **acceptée (D10)** |
| ⛔ **Ordre d'import** | Toujours **consommateurs d'abord, objet supprimé ensuite** (sinon compilation cassée) |

### 🛑 Checkpoints de conscience — règle générale

> **Décision utilisateur 2026-07-27** : au-delà des points d'arrêt de fin de lot, certaines
> modifications méritent **un arrêt et une réflexion explicite avant d'être appliquées**, quel que
> soit l'exécutant (Claude, agent externe ou toi).

**Règle** — 🛑 arrêt obligatoire, avec justification écrite, dès qu'une modification touche :

| Critère | Pourquoi |
|---|---|
| 🔄 **une polarité** (inversion, `NOT`, `InvertLogic`, sens d'un retour) | C'est le mécanisme exact du bug C1 |
| 🛡️ **une condition de sécurité ou d'inhibition** (`SafeStop`, `Forbid*`, `PowerCutOff`, bit d'`ErrorId`, bypass) | Une condition retirée par erreur ne se voit pas : elle ne bloque plus |
| 💾 **une variable `RETAIN`/`PERSISTENT`** (valeur résiduelle possible) | Une valeur héritée peut activer une branche morte |
| 🗑️ **une suppression de ligne d'affectation** (plutôt qu'une mise à `FALSE`) | Supprimer ≠ neutraliser : la variable garde sa dernière valeur |
| ⏱️ **un décalage d'exécution** (ordre des PRG, lecture d'une valeur du scan N-1) | Des raisonnements validés en dépendent |

#### Checkpoints nommés (issus de l'analyse d'impact §6)

| # | Lot | Point d'arrêt | Question à trancher AVANT d'écrire la ligne |
|---|---|---|---|
| **CK1** | L0 | `SimulationModeActive` sur l'automate **en service** | Est-il à `TRUE` ? Si oui, tout le raisonnement de neutralité tombe → dérouler d'abord les `*IsReal` un par un |
| **CK2** | L3 | Perte du RETAIN ⇒ **les bypass `Global` repartent à `FALSE`** | Un bypass actif masque-t-il aujourd'hui un blocage (capteur haut, PV, heartbeat) ? Si oui, il réapparaît au premier boot |
| **CK3** | L4a | `PRG_09:293` `Bypass.ContactorFeedback` M3 | **Écrire `:= FALSE`, NE PAS supprimer la ligne.** Valeur RETAIN résiduelle ⇒ `PRG_07:160` bascule sur une branche à polarité inversée ⇒ M3 impilotable |
| **CK4** | L4a | `BypassContactorCheck` (`PRG_06:478/522`, `PRG_07:161`) | Le terme `Bypass.Global` est-il bien conservé ? Seul le terme simulation part |
| **CK5** | L4b | `SlaveOperational` codeurs | Les devices EtherCAT sont-ils `Operational` sur la machine ? Sinon : plus d'`EncoderAvailable` → homing et mouvement bloqués |
| **CK6** | L4c | Heartbeat sans secours `BlinkClock` | La visu écrit-elle réellement `TglHeartbeatIhm` ? Sinon `SafeStop` 3 axes + `FB_Cycle` en `ERROR_HOLD` **non bypassable**. À trancher **avant** le download, pas après |
| **CK7** | L4d | Les 8 capteurs « forcés sains » → valeur réelle | Chacun est-il câblé **et** dans le bon sens ? Vérification physique à l'arrêt, capteur par capteur |
| **CK8** | L4d | Capteur haut `M1_M2_TopPositionSensor_DI` | Terme `ForbidAscent` **hors du bloc bypass interne** : si non câblé, montée M1 **et** M2 impossibles, seul `Bypass.Global` d'axe y remédie |
| **CK9** | L5 | Chaque signal redirigé vers `HwIn` | Le consommateur lit-il bien après remplissage ? Ordre §0 → §1 → `PRG_01` |
| **CK10** | L6 | Rebranchement du banc | `TstEncoderSpeedFactor` remis à `1.0` ? Polarité `PRG_07:160` corrigée ? |

### 🧪 Catalogue de tests (référencés par les lots)

| # | Test | Comment |
|---|---|---|
| **TC1** | Compilation | `0 erreur / 0 warning` |
| **TC2** | Config après download | Relire les valeurs restaurées (rampes, paliers, offsets, seuils, bypass) **avant tout mouvement** — constat, pas un critère bloquant (D10) |
| **TC3** | Comparaison watch-list | Les ~40 signaux de la liste de référence (L0) **identiques** à la baseline |
| **TC4** | M1 seul | Montée/descente joystick · rampes · paliers · arrêt · frein |
| **TC5** | M2 seul + benne | Ouverture/fermeture · offsets · vitesse lente |
| **TC6** | M1+M2 couplés | Synchro · `DeltaPosM` · arrêt simultané |
| **TC7** | M3 | Manuel Fwd/Rev · « aller à la position » · PV · Trémie |
| **TC8** | AU / réarmement | AU physique → coupure · réarmement + auto-test A/B |
| **TC9** | Cycle semi-auto | Séquence courte, homme-mort, pause/reprise |
| **TC10** | Bypass Global | M1/M2/M3 : purge contacteurs/frein toujours effective (MES-004) |
| **TC11** | Diagnostics bus | Aucun faux défaut CANopen/EtherCAT/heartbeat |
| **TC12** | Homing | M1 et M2, nominal 8,5 m + homing à 0 |
| **TC13** | Banc par domaine | `SimWinchActive` seul, puis Translation, Operator, Machine |
| **TC14** | Banc — injections | Méca E (écart synchro) · mot capteurs M3 valide **et** incohérent |
| **TC15** | Comparateur | Machine saine + `SimShadowCompare` → **`HwDelta` tout à FALSE** |
| **TC16** | Gates outillage | `run_all_gates.py` PASS + bundle régénéré |

---

## 1. 🗺️ Vue d'ensemble

```
L0 ─ Baseline                    doc/relevé      🛑
L1 ─ Tableau de neutralité       doc             🛑 ◄── validation AVANT toute modif code
     ══════════ P1a — retrait des forçages ══════════
L2 ─ Retrait lecteurs Override   3 PRG           🛑 TC1
L3 ─ Suppression objets morts    3 objets        🛑 TC1 TC2
     ══════════ P1b — débranchement simulation ══════════
L4a─ Périphérie                  4 PRG           🛑 TC1
L4b─ Codeurs                     PRG_02          🛑 TC1 TC12
L4c─ Joystick & diag             PRG_01          🛑 TC1 TC11
L4d─ Entrées                     PRG_00          🛑 TC1 TC3 + ESSAI MACHINE COMPLET ⭐
     ══════════ P2 — frontière unique ══════════
L5 ─ Image matérielle (sans sim) structs + 8 PRG 🛑 TC1 TC3 + ESSAI MACHINE ⭐
L6 ─ FB_SimBench + aiguillage    SIMULATION      🛑 TC1 TC13 TC14
L7 ─ Comparateur HwDelta         PRG_00          🛑 TC15
     ══════════ P3 — verrou ══════════
L8 ─ Gate + spec                 TOOLS + DOC     🛑 TC16
```

⭐ = les deux seuls points d'arrêt exigeant un essai machine complet.

---

## 2. 📦 Lots détaillés

### L0 — Baseline 🏁 *(aucune modification)*

| | |
|---|---|
| **Actions** | Tag git `pre-simu-refactor` · export CODESYS (`Device.export`) · bundle PLCopenXML · relevé des bypass RETAIN actifs · relevé des valeurs `PERSISTENT` · **création de la watch-list de référence** |
| **🥇 GO/NO-GO — CK1** | **Relever sur l'automate EN SERVICE** : `GVL_Simulation.SimulationModeActive` **et** les 18 `*IsReal`. Toute la démonstration de neutralité de P1 suppose `SimulationModeActive = FALSE`. Cette variable est **non RETAIN** (donc `FALSE` à chaque download) **mais un forçage en ligne survit jusqu'au redémarrage**. Si elle est à `TRUE` : dérouler d'abord chaque `*IsReal := TRUE` un par un en vérifiant qu'aucun défaut n'apparaît, **avant** d'ouvrir L4 |
| **Relevé physique** | État à l'arrêt de chaque entrée TOR (câblée ? bon sens ?) — sert de base au CK7 et à la fiche de valeurs persistantes |
| **Watch-list** | Les ~40 sorties de `PRG_00_Inputs` + états devices + `HwIn` futurs, relevées **machine à l'arrêt** puis **en mouvement M1 lent**. C'est la référence de TC3 pour tout le chantier |
| **🛑 Point d'arrêt** | Baseline archivée · watch-list capturée · **CK1 tranché** |
| **Rollback** | — |

---

### L1 — Tableau de neutralité 📋 *(document seul)*

| | |
|---|---|
| **Livrable** | Les **46 points simulation + 31 lectures d'`Override`**, un par ligne : `fichier:ligne` · forme actuelle · valeur à `SimulationModeActive = FALSE` · verdict **neutre / à examiner** |
| **But** | Prouver, avant d'y toucher, que L2→L4 **ne peuvent pas** changer le comportement de la machine réelle |
| **🛑 Point d'arrêt** | ✋ **Ta validation ligne à ligne.** Tout point marqué « à examiner » est tranché ici, pas pendant l'implémentation |
| **Effort** | S |

---

### L2 — Retrait des lecteurs d'`Override` 🗑️

| | |
|---|---|
| **Fichiers** | `PRG_09_Supervision` (10 pts, l. 61-74) · `PRG_00_Inputs` (16 pts, l. 129, 173, 311-356) · `PRG_01_Diagnostics` (5 pts, l. 42-45, 91-95) · `FB_Sim_Joystick` (entrées `TestOverride*` retirées) |
| **Détail** | `PRG_09` : suppression du bloc « Commandes de test Translation » · `PRG_00` : suppression du bloc de surcharges + `BtnEmergencyStop := FALSE` · `PRG_01` : `SEL` heartbeat simplifié, 4 paramètres `TestOverride*` retirés de l'appel |
| **Ordre CODESYS** | `PRG_09` → `PRG_00` → `PRG_01` → `FB_Sim_Joystick`. **Ne pas encore supprimer `GVL_PLC_Tests`** |
| **Tests** | TC1 |
| **🛑 Point d'arrêt** | Compilation OK + relecture du diff |
| **Risque** | 🟢 très faible — tous ces points sont `FALSE` au boot (non-RETAIN) |
| **Effort** | S |

---

### L3 — Suppression des objets morts ☠️

| | |
|---|---|
| **Supprimés** | `GVL_PLC_Tests` (64 l., plus aucun lecteur après L2) · `FB_Sim_DigitalMirror` (46 l., orphelin) · `BypassRestoreDone` (`PRG_09`, orphelin déclaré dans le code lui-même) · **`ST_TestTranslation` / `ST_TestCycle` + les champs `.Test`** de `ST_TranslationHMI`/`ST_CycleHMI` · `PRG_05:39` |
| **RETAIN** | ⚠️ Le retrait des `.Test` **invalide la zone RETAIN** au download → restauration `PERSISTENT` + rejeu des bypass. **Accepté (D10)** : les valeurs persistantes n'ont pas de contenu à préserver à ce stade |
| **Structures IHM** | ✅ **Aucun nom mappé dans la visu n'est touché** — seuls des champs jamais mappés disparaissent |
| **Tests** | TC1 · TC2 (constat, plus un critère bloquant) |
| **🛑 Point d'arrêt** | Compilation + download + **relecture des valeurs de config restaurées** (rampes, paliers, offsets, seuils) avant tout mouvement |
| **Risque** | 🟢 |
| **Effort** | S |

---

### L4a — Débranchement périphérie 🔌

| | |
|---|---|
| **Fichiers** | `PRG_05` (1 pt, l. 39) · `PRG_06` (2 pts, l. 478/522) · `PRG_07` (1 pt, l. 161) · `PRG_08` (1 pt, l. 24) · `PRG_09` §4 (5 pts, l. 291-295) |
| **Détail** | `PRG_06/07` : `BypassContactorCheck` **garde `Bypass.Global`**, perd le terme simulation · `PRG_08` : `HydraulicFaultOk := ThermHydraulique_DI` · `PRG_09` §4 : les miroirs `Bypass.ContactorFeedback`/`SlackCable`/`TopPositionSensor` passent à `FALSE` (ré-alimentés en L6 depuis les 4 domaines) |
| **Tests** | TC1 |
| **🛑 Point d'arrêt** | Compilation + diff |
| **Risque** | 🟢 |
| **Effort** | S |

---

### L4b — Débranchement codeurs 🧲

| | |
|---|---|
| **Fichiers** | `PRG_02_Encoders` : 2 instances `FB_Sim_Encoder` retirées · `M1/M2_RawPosToUse := COD1/COD2_PosValue` en direct · `SEL(instSimEncoderMx.Enable, …)` sur `Alarms`/`Warnings`/`SlaveOperational` simplifiés |
| **⚠️ Vigilance** | `SlaveOperational := …Operational OR instSimEncoderM1.Enable` → devient `…Operational` seul. **Vérifier qu'aucun faux défaut codeur n'apparaît** sur machine câblée |
| **Tests** | TC1 · TC12 (homing M1/M2) |
| **🛑 Point d'arrêt** | Homing nominal réussi sur les deux treuils |
| **Risque** | 🟠 |
| **Effort** | S |

---

### L4c — Débranchement joystick & diagnostics 🕹️

| | |
|---|---|
| **Fichiers** | `PRG_01_Diagnostics` : instance `FB_Sim_Joystick` retirée · `RawX/RawY/RawButton` en direct · `SimBypassActive`/`DeviceXxxSimBypass` à `FALSE` · heartbeat sur `GVL_IHM.Commun.TglHeartbeatIhm` direct |
| **🔴 Correctif inclus** | `DeadmanRearmTimeout := T#10S` et `NeutralHoldTime := T#500MS` **en dur** (fin du `SEL` piloté par un flag de banc) |
| **⚠️ Vigilance** | Le heartbeat n'a plus de secours `BlinkClock` : **l'IHM doit toggler réellement**, sinon timeout. À vérifier avant download |
| **Tests** | TC1 · TC11 (aucun faux défaut bus) · homme-mort réel |
| **🛑 Point d'arrêt** | Diagnostics propres + homme-mort à 10 s confirmé |
| **Risque** | 🟠 |
| **Effort** | M |

---

### L4d — Débranchement entrées ⭐ *(fin de P1)*

| | |
|---|---|
| **Fichiers** | `PRG_00_Inputs` : instances `FB_Sim_Safety` et `FB_Sim_Translation` retirées · **8 `OR (SimActive AND NOT …)` supprimés** · `SEL` contacteurs/freins/position M3 supprimés · variables `*_Simulated` et `SimTopSensorTriggered` supprimées · bloc simulation variateur M3 (l. 295-309) réduit à la branche réelle |
| **Résultat** | `GVL_Simulation` n'a plus **aucun lecteur** → orpheline, **conservée** pour P2 |
| **Tests** | TC1 · **TC3** · **TC4 → TC12** (essai machine complet) |
| **🛑 Point d'arrêt ⭐** | **Essai machine réelle complet.** C'est le jalon qui valide « le code fonctionne sans simulation » et autorise P2 |
| **Risque** | 🟠 le plus large de P1 (20 points) |
| **Effort** | M |

> 🏁 **Fin de P1** : programme propre, aucun forçage, aucune simulation, RETAIN jamais perturbé.
> ⚠️ **À partir d'ici et jusqu'à L6, aucun banc de simulation n'est disponible.**

---

### L5 — Image matérielle, **sans simulation** ⭐

> 🧠 **Astuce de sécurité du chantier** : ce lot introduit la structure **sans** le banc.
> `HwIn := HwReal` inconditionnel ⇒ le comportement est **strictement identique** à L4d,
> seul le *chemin* de la donnée change. Le risque de la structure et le risque de la simulation
> sont ainsi testés **séparément**.

| | |
|---|---|
| **Créés** | `ST_HwWinch` · `ST_HwTranslation` · `ST_HwOperator` · `ST_HwMachine` · `ST_HardwareImage` |
| **Fichiers** | `PRG_00` §0 : recopie `HwReal` (~40 champs) + les 5 `GetDeviceState()` remontés de `PRG_01` + `HwIn := HwReal` · `PRG_00` §1, `PRG_01`, `PRG_02`, `PRG_07`, `PRG_08` : consommation de `HwIn.*` |
| **Tests** | TC1 · **TC3 (le test clé, signal à signal)** · TC4 · TC7 · TC8 · TC11 |
| **🛑 Point d'arrêt ⭐** | Comparaison watch-list **identique** à la baseline L0, puis essai machine |
| **Risque** | 🟠 **le plus technique du chantier** (~40 signaux redirigés) — mais entièrement couvert par TC3 |
| **Effort** | L |

---

### L6 — `FB_SimBench` + aiguillage 🏗️

| | |
|---|---|
| **Créés** | `FB_SimBench` (composition `FB_Sim_Encoder` ×2, `_Translation`, `_Joystick`, `_Safety`) · `GVL_Simulation` refondue (**5 flags + stimuli**, polarité positive, `SimEncoderSpeedFactor := 1.0`) |
| **Fichiers** | `PRG_00` §0 : appel du banc + **les 4 `IF` d'aiguillage** · `PRG_09` §4 : miroirs IHM ré-alimentés depuis les 4 domaines |
| **Tests** | TC1 · sim OFF ⇒ **identique à L5** · **TC13** (chaque domaine seul) · **TC14** (Méca E, mot M3 incohérent) · TC10 |
| **⚠️ Attendu nouveau** | Le contrôle contacteur/frein est désormais **actif en simulation**. S'il déclenche, c'est un **écart du modèle** à corriger dans le banc — jamais à masquer |
| **🛑 Point d'arrêt** | Banc fonctionnel domaine par domaine |
| **Risque** | 🟠 |
| **Effort** | L |

---

### L7 — Comparateur `HwDelta` 🔍

| | |
|---|---|
| **Créés** | `HwSim` exposé · `HwDelta` · `HwMismatchCount` · `SimShadowCompare : BOOL := FALSE` |
| **Détail** | Comparaison **des grandeurs logiques uniquement** (TOR, états devices, mots d'état). Les continues (position codeur, fréquence M3) sont affichées côte à côte, **sans verdict** |
| **Tests** | **TC15** : machine saine + shadow ON ⇒ `HwDelta` tout à `FALSE` |
| **🛑 Point d'arrêt** | Comparateur silencieux sur machine saine (sinon : écart réel à instruire 🎯) |
| **Risque** | 🟢 (observateur pur, n'écrit jamais dans `HwIn`) |
| **Effort** | M |

---

### L8 — Verrou & spec 🔒

| | |
|---|---|
| **Fichiers** | `check_code_style.py` : **C3 corrigé d'abord** (36 faux positifs), puis règle « `GVL_Simulation.` interdit hors `CODE/SIMULATION/`, `PRG_00` §0 et `PRG_09` » · `AF_Partie-13 v2.0` · `VERSION_HISTORY` · bundle régénéré |
| **Tests** | TC16 |
| **🛑 Point d'arrêt** | Gates PASS · doc à jour |
| **Risque** | 🟢 |
| **Effort** | M |

---

## 3. 🔙 Rollback

| Niveau | Moyen |
|---|---|
| Un lot | `git revert <commit>` + réimport de l'objet précédent dans CODESYS |
| Tout P2 | Retour au tag posé en fin de L4d — état P1 propre et déjà validé machine |
| Tout le chantier | Retour au tag `pre-simu-refactor` (L0) + réimport de l'export CODESYS de baseline |

👉 Poser un **tag intermédiaire en fin de L4d** : c'est le point de repli le plus utile du chantier
(programme propre, validé machine, sans simulation).

---

## 4. ⚠️ Points de vigilance transverses

| # | Sujet | Traitement |
|---|---|---|
| 1 | **Pas de banc entre L4d et L6** | Enchaîner sans pause si un essai simulé est nécessaire |
| 2 | **Heartbeat sans secours** (L4c) | L'IHM doit toggler réellement — vérifier avant download |
| 3 | **`SlaveOperational` codeurs** (L4b) | Ne plus être forcé par la simulation : surveiller les faux défauts |
| 4 | **Contrôle contacteur actif en sim** (L6) | Comportement voulu, à instruire s'il déclenche |
| 5 | **Perte des valeurs persistantes** (L3) | Acceptée (D10). Le relevé L0 permet de **reconstituer un réglage** s'il s'avérait utile (rampes MES-007, plafond palier MES-003, offset benne MES-010) |
| 6 | **Application manuelle CODESYS** | Chaque lot fournit sa note d'objets et son ordre d'import |
| 7 | **Bundle** | Régénéré à chaque lot committé |
| 8 | **Registre MES** | 1 entrée `MES-xxx` aux deux jalons ⭐ (L4d et L5) |

---

## 5. 📌 Prochaine action

**L0 (baseline) puis L1 (tableau de neutralité)** — les deux sans toucher à `CODE/`.
Le premier lot modifiant du code est **L2**, et il n'est ouvert qu'après ta validation de L1.
