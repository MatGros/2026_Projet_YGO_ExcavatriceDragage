# 📋 FICHE DE TÂCHE — Lots L2 + L3 : retrait de `GVL_PLC_Tests` et des objets morts

> 🤖 **Destinataire** : agent d'implémentation externe · 📅 2026-07-27 · **v1.0**
> ⏱️ Lot d'ouverture du chantier simulation. Faible risque, périmètre strictement borné.
> ✅ **Ton travail sera relu et contrôlé** par l'agent pilote avant application sur l'automate.

---

## 1. 🏭 Contexte (tu n'as pas l'historique — lis ceci)

Automate **CODESYS 3.5**, machine spéciale : **excavatrice de dragage** en carrière noyée.
~10 000 lignes de **ST** dans `CODE/`. 3 axes : **M1** treuil de retenue, **M2** treuil de benne,
**M3** translation (variateur AC600 EtherCAT). Sécurité : chaîne AU câblée + `PowerCutOff`
logiciel redondant A/B, blocs `FB_Safety_*`.

Orchestration séquentielle, tâche 10 ms : `PRG_00_Inputs` → `PRG_01_Diagnostics` →
`PRG_02_Encoders` → `PRG_03_Safety` → `PRG_04_Modes` → `PRG_05_Cycle` → `PRG_06_WinchControl` →
`PRG_07_TranslationControl` → `PRG_08_AuxiliaryControl` → `PRG_09_Supervision` → `PRG_10_Outputs`.

⚠️ **Machine en cours de mise en service, livraison client imminente.** Prudence maximale.

⚠️ **L'utilisateur applique tout MANUELLEMENT** dans CODESYS (copier-coller du ST). Tu modifies les
fichiers du dépôt ; tu ne compiles pas, tu ne déploies pas.

### 📚 Lectures obligatoires avant de commencer

| Fichier | Pourquoi |
|---|---|
| `CLAUDE.md` | Règles projet, guardrails, workflow |
| `DOC/NAMING_CONVENTION.md` | PascalCase, pas de hongrois |
| `DOC/AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md` | Le pourquoi de ce chantier (§1, §2) |
| `DOC/AUDITS/PreLivraison/SEQUENCE_Execution_Simulation_v1.0.md` | Ta place dans la séquence + checkpoints |
| `DOC/AUDITS/PreLivraison/ANALYSE_Impact_Chaines_Actionneurs_v1.0.md` | §6 = les blocages connus |

### 🧠 Le contexte en une phrase

`GVL_PLC_Tests` est une GVL de **20 variables `Override*`** qui forçaient des entrées (et parfois des
**sorties déjà calculées**) pour un framework de tests automatiques **supprimé le 2026-07-26**.
Plus aucun automate ne les pilote. Elles sont toutes à `FALSE` au boot (non-RETAIN).
**On les retire.** Le forçage ponctuel se fera désormais par le **Force natif CODESYS**.

---

## 2. 🎯 Objectif et périmètre

### ✅ CE QUE TU DOIS FAIRE

**Lot L2 — retirer les lecteurs** (l'ordre compte : consommateurs d'abord, GVL ensuite)

| Fichier | Emplacement indicatif | Action |
|---|---|---|
| `CODE/MAIN/PRG_09_Supervision.st` | bloc « Commandes de test Translation », ~l. 61-74 | Supprimer le bloc `IF GVL_Simulation.SimulationModeActive THEN … OverrideM3* … END_IF` en entier |
| `CODE/MAIN/PRG_00_Inputs.st` | ~l. 129 | Retirer le terme `OR (GVL_Simulation.SimulationModeActive AND GVL_PLC_Tests.OverrideHmiCommandPurge)` — garder `IF NOT HmiCommandsInitialized THEN` |
| `CODE/MAIN/PRG_00_Inputs.st` | ~l. 173 | `BtnEmergencyStop := GVL_PLC_Tests.OverrideChainFalse` → `BtnEmergencyStop := FALSE` |
| `CODE/MAIN/PRG_00_Inputs.st` | ~l. 311-356 | Supprimer tout le bloc « Surcharges (overrides) » (chaîne AU, M3, retours M1/M2) |
| `CODE/MAIN/PRG_01_Diagnostics.st` | ~l. 42-45 | Retirer les 4 paramètres `TestOverride*` de l'appel `instSimJoystick(...)` |
| `CODE/MAIN/PRG_01_Diagnostics.st` | ~l. 91-95 | Simplifier le `SEL` heartbeat : retirer le `SEL` externe piloté par `OverrideIhmHeartbeatActive`, **conserver** le `SEL` interne (`SimulationModeActive AND NOT BusIhmHeartbeatIsReal`) |
| `CODE/SIMULATION/FB_Sim_Joystick.st` | à localiser | Retirer les `VAR_INPUT TestOverride*` et la logique qui les utilise |
| `CODE/MAIN/PRG_05_Cycle.st` | ~l. 39 | Supprimer `GVL_Simulation.SimKoboldContactFondValue := GVL_IHM.Cycle.Test.KoboldContactFond;` |

**Lot L3 — supprimer les objets devenus morts**

| Objet | Fichier |
|---|---|
| `GVL_PLC_Tests` (GVL entière) | `CODE/SIMULATION/GVL_PLC_Tests.st` |
| `FB_Sim_DigitalMirror` (orphelin confirmé, instancié nulle part) | `CODE/SIMULATION/FB_Sim_DigitalMirror.st` |
| `ST_TestTranslation` · `ST_TestCycle` | `CODE/SUPERVISION/_TYPES/` |
| champ `Test : ST_TestTranslation` | `ST_TranslationHMI.st` |
| champ `Test : ST_TestCycle` | `ST_CycleHMI.st` |
| `BypassRestoreDone` (déclaration `VAR RETAIN` **et** le bloc `IF NOT BypassRestoreDone THEN…`) | `CODE/MAIN/PRG_09_Supervision.st` |

### ⛔ CE QUE TU NE DOIS PAS FAIRE

- ❌ **Ne touche pas** à `GVL_Simulation` ni aux `FB_Sim_Encoder/Translation/Joystick/Safety`
  (hors le retrait des `TestOverride*` ci-dessus) — ils sont conservés pour un lot ultérieur
- ❌ **Ne retire aucune condition de simulation** de type `OR (SimulationModeActive AND NOT …IsReal)` — **ce n'est pas ce lot**
- ❌ Aucun renommage de variable
- ❌ Aucun refactor « au passage », aucune amélioration non demandée
- ❌ Aucun `git commit`, aucun `git push`
- ❌ Ne modifie aucun fichier hors de la liste ci-dessus

---

## 3. 🛑 Pièges connus — arrête-toi et réfléchis

| # | Piège | Règle |
|---|---|---|
| **P1** | **Supprimer une ligne ≠ neutraliser une variable.** Une variable non réaffectée **garde sa dernière valeur**, et en `RETAIN` elle survit au redémarrage | Si tu hésites entre supprimer une affectation et écrire `:= FALSE`, **écris `:= FALSE`** et signale-le |
| **P2** | `PRG_09` contient **deux** blocs distincts : les commandes de test M3 (~l. 61-74, **à supprimer**) et les miroirs `Bypass.*` (~l. 291-295, **à NE PAS toucher**, lot ultérieur) | Vérifie que tu es dans le bon bloc |
| **P3** | Les structs `ST_*HMI` sont dans `GVL_IHM`, déclarée `VAR_GLOBAL RETAIN`. Retirer un champ **invalide la zone RETAIN** au download | C'est **accepté** par l'utilisateur, mais **signale-le** dans ton rapport |
| **P4** | L'ordre de suppression : si tu supprimes `GVL_PLC_Tests` **avant** ses lecteurs, plus rien ne compile | Lecteurs (L2) d'abord, objets (L3) ensuite |
| **P5** | `PRG_01` heartbeat : il y a **deux `SEL` imbriqués**. Seul l'externe (Override) part | Relis la ligne complète avant d'éditer |

---

## 4. 🚨 Devoir d'alerte

**Tu dois t'arrêter et signaler — sans rien modifier — si tu constates :**

- une incohérence avec les spécifications `DOC/AF_Partie-*.md` ou `CLAUDE.md` ;
- une variable `Override*` qui aurait **un écrivain automate** (contredirait la prémisse du lot) ;
- une suppression qui changerait le comportement **machine réelle** (rappel : `SimulationModeActive`
  vaut `FALSE` par défaut, donc chaque branche supprimée doit se réduire à sa branche réelle —
  **si ce n'est pas le cas quelque part, ALERTE**) ;
- un écart aux standards d'automatisme (sécurité positive, reset sur front, état sûr en défaut) ;
- une ligne qui ne correspond pas à la description de ce document (numéros de ligne indicatifs :
  le code a pu évoluer — **vérifie par recherche, pas par numéro**) ;
- tout doute, même mineur, sur une chaîne de sécurité.

👉 **En cas de doute : n'invente pas, ne devine pas, ne comble pas. Signale et attends.**

---

## 5. 📤 Livrable attendu

1. **Les fichiers modifiés** dans `CODE/` (uniquement ceux listés en §2).
2. **Un rapport** `DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L2-L3_v1.0.md` contenant :
   - un tableau **fichier · ligne · avant → après** pour chaque modification ;
   - la confirmation que plus aucune référence à `GVL_PLC_Tests`, `FB_Sim_DigitalMirror`,
     `ST_TestTranslation`, `ST_TestCycle`, `BypassRestoreDone` ne subsiste dans `CODE/`
     (donne la commande de vérification et son résultat) ;
   - la **note d'application CODESYS** : quels objets remplacer, quels objets supprimer, **dans quel ordre** ;
   - tes **alertes** (§4), même si tu les juges mineures ;
   - ce que tu **n'as pas pu vérifier**.

### ✅ Critères de sortie

- [ ] Zéro occurrence des 5 objets supprimés dans `CODE/**/*.st`
- [ ] Aucun fichier modifié hors périmètre §2
- [ ] Aucune condition `OR (SimulationModeActive AND NOT …IsReal)` retirée
- [ ] Style ST du projet respecté : commentaires **français**, emoji conservés, en-têtes `(* … *)` intacts
- [ ] Rapport rédigé

⚠️ **Tu ne compiles pas et tu ne déploies pas.** La compilation CODESYS et l'essai machine sont
faits par l'utilisateur, après relecture par l'agent pilote.
