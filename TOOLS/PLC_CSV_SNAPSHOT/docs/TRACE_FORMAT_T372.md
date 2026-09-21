# T372 — Format `.trace` CODESYS & générateur de template

> Phase **INVESTIGATION + POC** — preuve par lecture de 81 fichiers `.trace` réels et par
> **test d'import réel CODESYS**. Tout est outillage `TOOLS/`, **aucun fichier `CODE/` touché**.
> Date du cycle de test réel : **2026-09-21** (runtime SimBench v0.7.18).

---

## 1. 🎯 Verdict d'approche (devoir de challenge)

| Approche | Verdict | Pourquoi |
|---|---|---|
| Générateur XML **from-scratch** | ❌ Rejeté | Doit reproduire tous les GUID d'archivage (`{f7aa3620-…}`, `{b6a18d24-…}`…), les schémas d'axe, la section `Diagrams`, les flags de version → sur-ingénierie, risque élevé. |
| **API / ScriptEngine CODESYS** | ❌ Non disponible | Le ScriptLib installé (`...\ScriptLib\Stubs\scriptengine\*.pyi`) n'expose **aucun objet Trace**. Le Trace est un outil de l'IDE, pas un modèle scriptable de ces stubs. |
| **Template modifié** (base = `.trace` réel) | ✅ **Retenu** | Un `.trace` réel garantit la validité : on ne régénère **que** la VariableList + références + RecordName (+ couleurs) ; **tout le reste** est conservé verbatim. |

→ Le générateur est un **transformateur de template**, pas un générateur from-scratch.
⚠️ **Leçon clé** : le modèle doit venir de **du même runtime que la cible** (un `.trace` d'une
version plus ancienne peut être rejeté à l'application). Modèle par défaut = un `.trace` récent.

---

## 2. 🗂️ Structure XML d'un `.trace`

Encodage : **UTF-16 LE + BOM** (`FF FE`), retours **CRLF**, racine `<Trace>`.

```
<Trace>
  <TraceConfiguration>
    <Single xml:space="preserve" Type="{f7aa3620-…}" Method="IArchivable">
      <Dictionary Name="TraceDataConfig"/><Dictionary Name="TraceOutputConfig"/>
      <Single Name="TraceSettings" Type="{8aaaee37-…}">
        AutoSave / AutoSaveFileName / RefreshDuration / BufferPerVariable /
        HorizontalOrder / OverrideRTSBufferSize
      </Single>
      <Null Name="RecordList"/>
      <Single Name="Record" Type="{988743cb-…}">
        <Dictionary Name="PlotLib"/>
        <Single Name="VariableList" Type="{adcdd50b-…}">
          <List Name="InnerList" Type="System.Collections.ArrayList">
            <Single Type="{b6a18d24-…}" Method="IArchivable">   ← 1 bloc / variable
              VariableName / GraphColor / GraphType / Visible / Max/Min-Warning /
              YAxis / guid(System.Guid) / YAxisSettings{6ace1446-…} / Enabled
            </Single> …
          </List>
        </Single>
        TriggerVariable / TriggerEdge{33a32e6c-…} / TriggerLevel / TriggerPosition(byte) /
        TriggerFlags{7be0d640-…} / TaskName / BufferEntries / EveryNCycles / guidPOU /
        Comment / Condition / MicroSeconds / Autostart / GenerateVisuCode / Visible / Selected /
        RecordName / PostTriggerSamples / Appearance{…} (… Diagrams>Variables>List2>ReferencedVarGuid)
      </Single>
    </Single>
  </TraceConfiguration>
  <TraceData Version="1.0.0.0">   ← données échantillons (optionnel pour un template)
    <TraceRecord><TriggerState/><StartTime/><TriggerStartDate/><TriggerTimeStamp/>
      <TraceVariable VarName="…" VariableIndex="0" Type="System.Double">
        <Values>…</Values><Timestamps>…</Timestamps></TraceVariable> …
    </TraceRecord>
  </TraceData>
</Trace>
```

**Points prouvés par lecture :**
- Chaque variable = un bloc `<Single Type="{b6a18d24-…}">` portant un **`guid`** unique.
- Section Diagrams : **1 `ReferencedVarGuid` par variable** (compté 1:1 sur des fichiers réels).
- ⚠️ L'ordre des `ReferencedVarGuid` **n'est PAS** aligné sur l'ordre de la VariableList (`M3_ActualFrequencyHz`
  avant `M3_BrakeIsOpen_DI` dans Diagrams).
- Le **type de variable** n'apparaît **que dans `<TraceData>`** (ex. `System.Double`) ; la config ne porte
  que le **nom symbolique** (chemin complet).

---

## 3. 🧩 Le générateur

`TOOLS/PLC_CSV_SNAPSHOT/scripts/generate_trace_template.py`

### Usage (liste figée de debug cycle homing → trace fonctionnelle)

```powershell
python TOOLS\PLC_CSV_SNAPSHOT\scripts\generate_trace_template.py `
  --template TOOLS\PLC_CSV_SNAPSHOT\RESULTS\trace\Suivi_71_SIMU_M1M2_CycleMD_Bug_20260920.trace `
  --var-file  TOOLS\PLC_CSV_SNAPSHOT\variable_lists\trace_cyclehoming_debug_v1.txt `
  --record-name CycleHoming_Debug `
  --output    out.trace
```

Autres :
- Variables en ligne : `--variables GVL_A.B.C GVL_A.D.E` (ou une liste séparée par virgules).
- **`--no-trace-data`** : omet totalement `<TraceData>` (format d'import le plus sûr).
- `--keep-data` : réutilise les échantillons du modèle (ne pas utiliser en production).
- `--selftest` : régénère le modèle avec sa **propre** liste et vérifie l'**identité byte-à-byte** de
  la `<TraceConfiguration>`.
- `--trigger-*` / `--condition` : **best-effort** (non prouvé, cf. § 8).

### 🎨 Couleurs par thème (auto)

Chaque **nouvelle** variable reçoit une couleur **distincte** par thème (groupe = chemin parent) :
une **hue différente par groupe**, des **teintes voisines (luminosité variable) dans un même groupe**
→ distinguables tout en gardant le repère visuel. Déterministe (même liste ⇒ mêmes couleurs), encodé
`0xFFRRGGBB` (int signé, comme le `GraphColor` des fichiers réels). Variables **réutilisées** gardent
leur couleur d'origine (le `--selftest` reste byte-à-byte identique).

---

## 4. 🧪 Règles de traçabilité — ÉTABLIES par test réel

Un **seul** symbole "non traçable" fait échouer **toute l'application** de la trace :
`Erreur de communication: Parameter (#0x00000002)` — sans indiquer lequel.

| Type de variable | Tracable ? | Exemple vécu |
|---|---|---|
| `BOOL` / `INT` / `REAL` / `WORD` / DUT | ✅ | `State.Homed`, `Encoder.Speed_Mps` |
| `ENUM` | ✅ (affiché **par nom**) | `instCycleMachineHoming.MachineHomingSeqStep` → `HX0..HX7` |
| `VAR_OUTPUT` de FB / champ publié / GVL / `PRG_xx.Data.*` | ✅ | `HomingModeBActive`, `instBucket.BucketState.*`, checklists `E/F_HomingM` |
| **`STRING(...)`** | ❌ | `GVL_IHM.CycleMachineHoming.State.Instruction` → tout échoue |
| `VAR` interne `[LOC]` (PRG ou FB, non exposée) | ❌ | `MachineHomingMechanicalStopOk`, `instCycleMachineHoming.TransactionAbort`… |

→ La liste **`trace_cyclehoming_debug_v1.txt`** contient **42 variables traçables** ; les symboles non
traçables y sont **commentés `#` avec la raison** (STRING / `[LOC]`).

---

## 5. ✅ Validation

1. **Identité byte-à-byte** (`--selftest`) : OK sur modèles `VISU_TASK` (15 var.) et `TrendRecordingTask` (20 var.).
2. **Import réel CODESYS (2026-09-21)** : après bisect des échecs, la trace **42 variables sans STRING ni
   locaux** s'importe sans erreur. Les fichiers de diag (tiny/1 var., moitiés, noSTRING) ont servi à isoler
   les coupables — non conservés.
3. `refs == guids` 1:1, XML bien formé, UTF-16+BOM, CRLF.

---

## 6. 🧭 Chemin des variables — leçon de l'audit

Un test « la feuille du chemin existe » est **insuffisant** : il laisse passer les erreurs de type structuré.
Exemple : `PRG_04_Treuils_Benne.Data.BucketState.*` est `ST_BucketHMIState`, l'état mécanique est sous
**`.MechState`**. Le chemin **retenu** vise l'état live du FB :
`PRG_04_Treuils_Benne.instBucket.BucketState.IsOpen/IsClosed/BucketReferenced`
(`instBucket : FB_Bucket` ; son `BucketState : ST_fbBucket_State` porte ces champs directement — pas de `MechState`,
qui ne concerne que le miroir HMI `Data.BucketState.MechState`).

→ La validation fiable doit **résoudre le chemin complet** (POU→instance→type→champ) contre les déclarations ST.

---

## 7. 🔀 Consolidation

Deux générateurs coexistèrent :
- `scripts/generate_trace_template.py` (**retenu**) — refs 1:1, multicouleur, `--no-trace-data`, selftest.
- `_poc/generate_trace_template.py` (**laissé intact**, non retenu) — output avec `ReferencedVarGuid`
  **sans lien** avec les guids réels + sans `<TraceData>` (`_poc/Suivi_HomingMachine_POC_generated.trace`).
  Gardé pour référence, à ne pas importer tel quel.

---

## 8. ⚠️ Résidu non prouvé

- **Trigger actif** : aucun des 81 `.trace` du dépôt n'a de trigger configuré (`TriggerVariable` vide,
  `TriggerEdge=None`, `TriggerFlags=Undefined` partout) → l'encodage d'un trigger (variable + condition +
  mode/single/continu, pré/post) **n'est pas prouvé**. Le générateur l'écrit en **best-effort**
  (`--trigger-*`) avec avertissement. À valider contre un `.trace` réel **avec** trigger.

---

## 9. 📁 Livrables finaux

| Fichier | Rôle |
|---|---|
| `scripts/generate_trace_template.py` | Le générateur (transformateur de template, multicouleur, `--no-trace-data`, `--selftest`) |
| `variable_lists/trace_cyclehoming_debug_v1.txt` | **Liste 42 variables traçables** (debug cycle homing) ; non-traçables en `#`+raison |
| `scripts/examples/Example_CycleHoming_Debug.trace` | **Trace fonctionnelle 42 var.** (import confirmé) — modèle `Suivi_71` |
| `scripts/examples/Example_Homing_Machine.trace` | Autre exemple (14 var. homing) |
| `scripts/examples/homing_machine_variables.txt` | Liste source de l'exemple homing |
| Ce rapport + section « Générateur .trace » du README de l'outil | Documentation |

**Aucun fichier `CODE/` modifié.** Fichiers non commités (untracked), hors `_poc/` laissé tel quel.
