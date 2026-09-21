# T372 — Format `.trace` CODESYS & Générateur de template

> **Phase 1 : INVESTIGATION + POC** — preuve par lecture réelle des fichiers, zéro
> affirmation non vérifiée. 81 fichiers `.trace` réels lus (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/**`).
> Hors périmètre PLC : aucun fichier `CODE/` touché.

---

## 🎯 Verdict d'approche (devoir de challenge)

| Approche | Verdict | Pourquoi |
|---|---|---|
| **Générateur XML from-scratch** | ❌ Rejeté | Doit reproduire tous les GUID d'archivage (`{f7aa3620-…}`, `{b6a18d24-…}`, …), la sérialisation des enums, les schémas d'axe, la section `Diagrams`, les flags de version… → sur-ingénierie et risque élevé. |
| **API / ScriptEngine CODESYS** | ❌ Non disponible | Le ScriptLib installé (`C:\Program Files\CODESYS 3.5.19.10\CODESYS\ScriptLib\Stubs\scriptengine\*.pyi`) n'expose **aucun objet Trace**. Le Trace est un outil de l'IDE, pas un modèle scriptable de ces stubs. |
| **Template modifié** (base = `.trace` réel) | ✅ **Retenu** | Un `.trace` réel est la garantie d'un fichier valide. On régénère **uniquement** la VariableList + les références + le RecordName ; **tout le reste** (schémas d'axe, GUID d'archivage, structuration) est conservé verbatim. |

→ Le générateur livré est donc un **transformateur de template**, pas un générateur from-scratch.

---

## 🗂️ Structure XML d'un `.trace` (prouvée sur fichiers réels)

Encodage : **UTF-16 LE + BOM** (octets `FF FE`), retours **CRLF**, racine `<Trace>`.

```
<Trace>
  <TraceConfiguration>
    <Single xml:space="preserve" Type="{f7aa3620-8073-4c91-b6ec-86ed9eb60303}" Method="IArchivable">
      <Dictionary Type="System.Collections.Hashtable" Name="TraceDataConfig" />
      <Dictionary Type="System.Collections.Hashtable" Name="TraceOutputConfig" />
      <Single Name="TraceSettings" Type="{8aaaee37-d2e1-4e99-b58f-acd4f8bf698f}" Method="IArchivable">
        AutoSave / AutoSaveFileName / RefreshDuration(500) / BufferPerVariable(10001) /
        HorizontalOrder / OverrideRTSBufferSize
      </Single>
      <Null Name="RecordList" />
      <Single Name="Record" Type="{988743cb-81f4-49a7-8a04-2490e2ab1c5e}" Method="IArchivable">
        <Dictionary Name="PlotLib" />
        <Single Name="VariableList" Type="{adcdd50b-433c-4999-986a-b4c67e7333be}" Method="IArchivable">
          <List Name="InnerList" Type="System.Collections.ArrayList">
            <Single Type="{b6a18d24-a045-4a81-a2ac-7044c6f553c0}" Method="IArchivable">   ← 1 bloc / variable
              VariableName / GraphColor / GraphType / Visible / Max-Warning / Min-Warning /
              YAxis / guid (System.Guid) / YAxisSettings {6ace1446-…} (Mode/Min/Max/Range/Font…) / Enabled
            </Single>
            ...
          </List>
        </Single>
        TriggerVariable(string) / TriggerEdge({33a32e6c-…}) / TriggerLevel(string) /
        TriggerPosition(byte) / TriggerFlags({7be0d640-…}) / TaskName / BufferEntries(uint) /
        EveryNCycles(uint) / guidPOU / Comment / Condition(string) / MicroSeconds / Autostart /
        GenerateVisuCode / Visible / Selected / RecordName(string) / PostTriggerSamples(uint) /
        Appearance{…} (tAxis, yAxisCommon, TimeAxis, Diagrams>Variables>List2>ReferencedVarGuid…)
      </Single>
    </Single>
  </TraceConfiguration>
  <TraceData Version="1.0.0.0">   ← données échantillons (optionnel pour un template)
    <TraceRecord>
      <TriggerState/> <StartTime/> <TriggerStartDate/> <TriggerTimeStamp/>
      <TraceVariable VarName="…" VariableIndex="0" Type="System.Double">
        <Values>…,0,1,…</Values>  <Timestamps>…</Timestamps>
      </TraceVariable> …
    </TraceRecord>
  </TraceData>
</Trace>
```

### Points clés prouvés

- **Chaque variable** = un bloc `<Single Type="{b6a18d24-…}">` portant un **`guid`** unique (System.Guid).
- **Section `Diagrams`** : la liste `<List2 Name="Variables">` contient **1 `ReferencedVarGuid` par variable** (compté 15/15 exactement), qui référence le `guid` de la variable.
- ⚠️ **L'ordre des `ReferencedVarGuid` n'est PAS aligné sur l'ordre de la VariableList** (démontré : `M3_ActualFrequencyHz` avant `M3_BrakeIsOpen_DI` dans Diagrams). → le générateur ne réordonne pas la liste par défaut.
- **Le type de variable** (`BOOL/INT/REAL/STRING`, ex. `System.Double`) n'apparaît **que dans `<TraceData>`**, pas dans la config — la config référence le nom symbolique uniquement.

---

## 🧩 Générateur livré

`TOOLS/PLC_CSV_SNAPSHOT/scripts/generate_trace_template.py` — transformateur de template.

### Couleurs par thème (auto)

Par défaut, chaque **nouvelle** variable reçoit une couleur **distincte**, assignée par thème
(groupe = chemin parent) : une **hue différente par groupe**, et des **teintes voisines
(luminosité variable) pour les variables du même groupe** — pour les distinguer sans perdre le
repère visuel de groupe. Déterministe (même liste ⇒ mêmes couleurs). Encodé en ARGB
`0xFFRRGGBB` (int signé), identique au `GraphColor` des fichiers réels.

Exemple (31 variables de debug cycle homing) :

| Thème | Couleurs |
|---|---|
| `GVL_IHM.CycleMachineHoming.State.*` | bleu (9 teintes croissantes) |
| `PRG_02_Acquisition.Data.EncoderM*.Measurement.*` | verts |
| `GVL_PERSISTENT._CalibM*.*` | jaunes/oranges |
| `PRG_04_Treuils_Benne.Data.BucketState.*` | rouges |
| `GVL_Troubleshooting.E_/F_HomingM*.` | magenta / violet |

Les variables **réutilisées** d'un modèle gardent leur couleur d'origine ; l'assignement de
couleur ne s'applique qu'aux blocs créés (pas de changement sur `--selftest` → identité byte-à-byte conservée).

### Usage

```powershell
# Exemple homing fourni
python TOOLS\PLC_CSV_SNAPSHOT\scripts\generate_trace_template.py `
  --template TOOLS\PLC_CSV_SNAPSHOT\RESULTS\trace\Suivi_Cycle_M3_20260906_49.trace `
  --var-file  TOOLS\PLC_CSV_SNAPSHOT\scripts\examples\homing_machine_variables.txt `
  --record-name Machine_Homing `
  --output     TOOLS\PLC_CSV_SNAPSHOT\scripts\examples\Example_Homing_Machine.trace

# Variables en ligne (ou liste séparée par virgules)
python TOOLS\PLC_CSV_SNAPSHOT\scripts\generate_trace_template.py `
  --template <model.trace> --variables GVL_A.B.C GVL_A.D.E --output t.trace

# Preuve d'identité byte-à-byte (régénère le modèle avec sa propre liste)
python TOOLS\PLC_CSV_SNAPSHOT\scripts\generate_trace_template.py --selftest --template <model.trace>
```

Options : `--task-name`, `--trigger-*`/`--condition` (best-effort, cf. § Non prouvé),
`--keep-data` (réutilise le TraceData du modèle, défaut : vide).

---

## ✅ Preuve de validité

1. **Identité byte-à-byte** (`--selftest`) : régénérer la `<TraceConfiguration>` d'un modèle avec
   son **exacte** liste de variables → config **byte-à-byte identique**. Verdict sur 2 types de modèles
   (`VISU_TASK` 15 var., `TrendRecordingTask` 20 var.) : **SELFTEST OK**.
2. **Identité structurelle sur l'exemple homing** : la config générée (14 var.) a le **même squelette**
   (balises + attributs) que le modèle ; l'unique écart = le **1 bloc variable retiré** (15→14), les
   valeurs feuilles qui changent étant les **noms de variables + guids + RecordName**.
3. **Création de blocs neufs** (cible > modèle : 15 → 25 var.) : XML bien formé, `ReferencedVarGuid`
   ⊆ guids (1:1) — vérifié.
4. **Fichier homing généré** : UTF-16+BOM, CRLF, XML bien formé, 14 variables `GVL_IHM.*`, RecordName
   `Machine_Homing`, `refs == guids`.

---

## ✅ Validation IMPORT RÉELLE (CODESYS) — 2026-09-21

L'utilisateur a **importé réellement** un fichier généré dans l'IDE CODESYS : **aucune erreur**,
~12 variables importées correctement. → l'**import d'un `<TraceData>` vide + config générée est
CONFIRMÉ fonctionnel** (levait la principale incertitude de validation).

## ⚠️ Reste NON PROUVÉ — à valider

- **Trigger actif** : aucun des 81 `.trace` du dépôt n'a de trigger configuré (`TriggerVariable`
  vide, `TriggerEdge=None`, `TriggerFlags=Undefined` partout). L'encodage d'un trigger
  (variable + condition + mode/single/continu, pré/post-trigger) **n'est donc pas prouvable sur
  les exemples existants**. Le générateur écrit un trigger en **best-effort** (`--trigger-*`) avec
  avertissement — à valider contre un `.trace` réel avec trigger.

> ⛔ Le cas **trigger actif** est le seul résidu à confirmer **dans CODESYS** avant industrialisation.

---

## 📁 Livrables

- `TOOLS/PLC_CSV_SNAPSHOT/scripts/generate_trace_template.py` — le générateur (transformateur de template, multicouleur par thème).
- `TOOLS/PLC_CSV_SNAPSHOT/scripts/examples/homing_machine_variables.txt` — liste type homing (14 variables).
- `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_cyclehoming_debug_v1.txt` — liste **debug cycle homing** (31 variables, mise en service).
- `TOOLS/PLC_CSV_SNAPSHOT/scripts/examples/Example_Homing_Machine.trace` — **exemple généré** (homing machine).
- `TOOLS/PLC_CSV_SNAPSHOT/scripts/examples/Example_CycleHoming_Debug.trace` — **exemple généré** (debug cycle homing, 31 var., multicouleur).
- Ce rapport + pointeur README de l'outil.

**Consolidation T372** — deux générateurs coexistèrent un temps :
- `scripts/generate_trace_template.py` (**retenu**) : refs `ReferencedVarGuid`↔guids **1:1 vérifié**, émet `<TraceData>`, multicouleur, selftest byte-à-byte.
- `_poc/generate_trace_template.py` (**laissé intact**, non retenu) : variante antérieure dont l'output avait **14 `ReferencedVarGuid` pour 12 variables sans aucun lien** avec les guids réels + **pas de `<TraceData>`** (`_poc/Suivi_HomingMachine_POC_generated.trace`). Gardé tel quel en `_poc/`, non effacé, pour référence — mais à ne **pas** importer tel quel.

*Chemin des variables issus de `ST_MachineHoming`, `ihm_variables.txt` (GVL_IHM) et la liste de mise en service — confirmés réels, non inventés.*
