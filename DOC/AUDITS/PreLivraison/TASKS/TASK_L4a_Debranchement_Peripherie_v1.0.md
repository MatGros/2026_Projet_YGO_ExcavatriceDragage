# 🔌 FICHE DE TÂCHE — Lot L4a : débranchement simulation, périphérie

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🟠 risque modéré
> ⏱️ **Prérequis : lot L2+L3 appliqué et validé.**
> 📖 **Contexte projet et règles de travail : lire les §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**
> (contexte machine, lectures obligatoires, devoir d'alerte — ils s'appliquent intégralement ici).

---

## 1. 🎯 Objectif

Retirer les références à `GVL_Simulation` dans les programmes **périphériques**
(`PRG_06`, `PRG_07`, `PRG_08`, `PRG_09`). Les programmes d'acquisition (`PRG_00`, `PRG_01`,
`PRG_02`) sont traités par d'autres lots — **n'y touche pas**.

**Prémisse de sûreté** : `GVL_Simulation.SimulationModeActive` vaut `FALSE` par défaut, donc chaque
terme retiré vaut déjà `FALSE` sur la machine réelle. Le comportement machine doit être
**strictement inchangé**. Si tu trouves un endroit où ce n'est pas vrai → **ALERTE, ne modifie pas**.

---

## 2. 🔧 Travail détaillé

*(numéros de ligne indicatifs — localise par recherche, pas par numéro)*

### `CODE/MAIN/PRG_06_WinchControl.st` (~l. 478 et 522)

```
AVANT : BypassContactorCheck := GVL_IHM.M1TreuilRetenue.Bypass.Global
                                OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal),
APRÈS : BypassContactorCheck := GVL_IHM.M1TreuilRetenue.Bypass.Global,
```
Idem pour M2 (`M2TreuilBenne`, `SensorM2ContactorFeedbackIsReal`).

🛑 **CK4** — le terme `Bypass.Global` est **conservé** : c'est le vrai bypass opérateur. Seul le
terme simulation part.

### `CODE/MAIN/PRG_07_TranslationControl.st` (~l. 161)

Même transformation pour `instTranslationM3` (`GVL_IHM.TranslationM3.Bypass.Global` conservé).

### `CODE/MAIN/PRG_08_AuxiliaryControl.st` (~l. 24)

```
AVANT : HydraulicFaultOk := ThermHydraulique_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorHydraulicThermalIsReal);
APRÈS : HydraulicFaultOk := ThermHydraulique_DI;
```

### `CODE/MAIN/PRG_09_Supervision.st` §4 (~l. 291-295)

Les **5 miroirs** `Bypass.ContactorFeedback` (M1/M2/M3), `Bypass.SlackCable`,
`Bypass.TopPositionSensor` doivent être **forcés à `FALSE`** :

```
APRÈS : GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := FALSE;
        GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := FALSE;
        GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := FALSE;
        GVL_IHM.Commun.Bypass.SlackCable                 := FALSE;
        GVL_IHM.Commun.Bypass.TopPositionSensor          := FALSE;
```

🛑 **CK3 — LE PIÈGE PRINCIPAL DE CE LOT.** **N'EFFACE PAS ces lignes.**
`GVL_IHM` est `VAR_GLOBAL RETAIN`. Si `TranslationM3.Bypass.ContactorFeedback` garde une valeur
résiduelle `TRUE`, `PRG_07:160` bascule sur une branche à **polarité inversée** ⇒ `FB_Brake`
`StuckClosed` après 1 s ⇒ `DriveControlWord := 0` ⇒ **M3 devient impilotable**.
Ces 5 lignes seront ré-alimentées depuis les 4 domaines de simulation au lot L6.

### `CODE/MAIN/PRG_09_Supervision.st` (~l. 509-510)

```
AVANT : GVL_IHM.TranslationM3.State.DriveCommReady  := PRG_00_Inputs.M3_StatusWord_Filtered.7 OR GVL_Simulation.SimulationModeActive;
APRÈS : GVL_IHM.TranslationM3.State.DriveCommReady  := PRG_00_Inputs.M3_StatusWord_Filtered.7;
```
Idem `DrivePowerReady` (bit `.0`). *(Affichage IHM uniquement, aucun consommateur métier — vérifié.)*

### ✅ À CONSERVER dans `PRG_09`

`GVL_IHM.TranslationM3.State.SimulationModeActive := GVL_Simulation.SimulationModeActive;`
(~l. 494) — publication d'état légitime vers l'IHM.

---

## 3. ⛔ Interdictions

- ❌ Ne touche pas à `PRG_00`, `PRG_01`, `PRG_02`, `PRG_03`, `PRG_04`, `PRG_05`, `PRG_10`
- ❌ Ne touche à aucun `FB_*` ni à `GVL_Simulation`
- ❌ **Ne supprime aucune ligne d'affectation** : mets à `FALSE` (voir CK3)
- ❌ Ne retire aucun terme `Bypass.Global` — jamais
- ❌ Aucun commit, aucun refactor opportuniste, aucun renommage

---

## 4. 🛑 Pièges de ce lot

| # | Piège |
|---|---|
| **CK3** | `PRG_09:291-295` → écrire `:= FALSE`, **jamais supprimer** (RETAIN résiduel ⇒ M3 impilotable) |
| **CK4** | `BypassContactorCheck` garde `Bypass.Global` — seul le terme simulation part |
| P3 | ⚠️ Effet **attendu** de ce lot : en simulation, les contrôles contacteur/frein redeviennent **actifs** (ils étaient désarmés). C'est voulu. S'ils déclenchent au prochain essai simulé, c'est un écart du **modèle de banc** — à signaler, jamais à masquer |
| P4 | `PRG_09` contient plusieurs blocs mentionnant `Bypass` : le §4 (miroirs simulation, **ta cible**) et la restauration RETAIN au boot (~l. 211-251, **à ne pas toucher**) |

---

## 5. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L4a_v1.0.md` :

- tableau **fichier · ligne · avant → après**
- confirmation : plus aucune occurrence de `GVL_Simulation.` dans `PRG_06`, `PRG_07`, `PRG_08`
  et dans le §4 de `PRG_09` (donne la commande et son résultat)
- confirmation explicite que les 5 lignes de `PRG_09` §4 sont **présentes et à `FALSE`**
- confirmation que les 3 `Bypass.Global` sont intacts
- note d'application CODESYS + tes alertes

### ✅ Critères de sortie

- [ ] `Bypass.Global` conservé sur M1, M2, M3
- [ ] Les 5 miroirs `PRG_09` §4 écrits `:= FALSE`, aucune ligne effacée
- [ ] `PRG_09:494` (`State.SimulationModeActive`) conservé
- [ ] Aucun fichier hors périmètre modifié
- [ ] Commentaires **français** + emoji conservés, en-têtes `(* … *)` intacts
