# 🧹 T144 — Assainir l'interface de PRG_06_Outputs (esprit bus T142)

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T144 — aligner `PRG_06_Outputs` sur
> l'encapsulation (bus `Data` + struct diag), assigner/supprimer les sorties mortes, déclarer les
> globals dans les `.st`, exposer la commande drive M3 via `Data`.
> Source : `PRG_06_Outputs.st`, `ST_OutputsInterPrg`, `ST_TranslationFinalInterlockRequest`.
> 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T144.

---

## 1. Constat (vérifié code — conforme à la revue sim M3)

| # | Fait vérifié | Lignes |
|---|---|---|
| ① | `M3_DriveControlWord` / `M3_DriveFreqRefWord` (VAR_OUTPUT) **jamais assignés** (morts, toujours 0) | L51-52 |
| ② | `M3_CommandWord` / `M3_SetpointFrequencyHz` **assignés** (L270-271) mais **non déclarés** dans le `.st` (globals Device/export uniquement) → source non auto-consistante | L270-271 |
| ③ | **Commande drive M3 absente du bus `Data`** (`ST_OutputsInterPrg` ne porte que `TranslationBrakeCmd`) | voir struct |
| ④ | **Diag plats en VAR_OUTPUT** (`M3BlockedBySafetyInfo`, `EmergencyState`, `EmergencyDiag`…) au lieu d'un struct/bus diag | L26-47 |

---

## 2. Plan d'assainissement (design — à valider)

### ① Sorties M3 mortes → remplacement
`M3_DriveControlWord` / `M3_DriveFreqRefWord` (jamais assignés) :
- **Supprimer** ces 2 VAR_OUTPUT morts, **ou** les réassigner depuis la vraie source
  (`instTranslationOutputInterlockM3.DriveControlWord` / `.DriveFreqRefWord`).
- → recommandation : **supprimer** (morts) et exposer la commande via `Data` (③).

### ② Globals non déclarés → déclarer dans le `.st`
`M3_CommandWord` / `M3_SetpointFrequencyHz` (assignés L270-271 mais non déclarés) :
- **Déclarer** comme `VAR_OUTPUT` (ou membre du bus) dans `PRG_06_Outputs.st`, ou remplacer par
  les vrais champs `DriveControlWord`/`DriveFreqRefWord` de l'interlock (noms cohérents).

### ③ Commande drive M3 dans le bus `Data`
Étendre `ST_OutputsInterPrg` (ou la struct d'ordre) avec la **commande drive M3 complète** :
`M3_DriveControlWord` + `M3_DriveFreqRef_Hz` (ou mots bruts), **producteur unique** — pour que
la source sim (`FB_SimBench`) et les consommateurs lisent un seul bus, pas des globals Device.

### ④ Diag plats → struct diag
Regrouper les diag plats (`M1/M2/M3BlockedBySafetyInfo`, `EmergencyState`, `EmergencyDiag`…)
dans un **struct `ST_OutputsDiag`** (ou réutiliser `ST_OutputsInterPrg` + un champ `Diag`),
au lieu de N `VAR_OUTPUT` à plat — conforme à l'esprit bus T142.

---

## 3. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Sorties mortes : **supprimer** (recommandé) ou réassigner ? |
| 2 | Extension de `ST_OutputsInterPrg` : champs drive M3 (mots bruts + Hz) — noms exacts à confirmer |
| 3 | Struct diag : nouveau `ST_OutputsDiag` ou champ dans l'existant ? |
| 4 | Impact **simulation** (`FB_SimBench` lit `PRG_05.Data.TranslationFinalInterlockRequest` déjà) — à vérifier si `PRG_06.Data` change de forme |
| 5 | Implémentation (code PRG_06 + structs) → **validation humaine** |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T144 |
| PRG_06 | `CODE/M_MAIN/PRG_06_Outputs.st` (L26-54, L264-271) |
| Bus | `ST_OutputsInterPrg` · `ST_TranslationFinalInterlockRequest` |
| Esprit bus | T142 (`DOC/WFLOW/TASKS.yaml`) · `DOC/STDS/CODE_QUALITY_STANDARDS.md §2` |
