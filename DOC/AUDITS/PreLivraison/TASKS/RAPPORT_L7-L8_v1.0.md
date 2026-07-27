# 📋 Rapport L7–L8 — HwSim, verrou simulation, specs (v1.0)

> 📅 2026-07-27 · Source : `TASK_L7-L8_HwSim_Verrou_Specs_v2.0.md`  
> 🚫 Aucun comparateur `FB_HwCompare` / `HwDelta` développé. Aucun commit, compilation CODESYS ou déploiement.

## A. 🏗️ `HwSim` exposée

- Déclarée dans `CODE/MAIN/PRG_00_Inputs.st` en `VAR_OUTPUT` : `HwSim : ST_HardwareImage`.
- Alimentée immédiatement après `instSimBench(...)` depuis `Winch`, `Translation`, `Operator`, `Machine`.
- `HwIn` conserve seul l'aiguillage par domaine et l'alimentation du conditionnement.
- Recherche des occurrences : `HwSim` n'est lue par aucune logique métier; elle est un point
  d'observation en vue instance avec `HwReal` et `HwIn`.

## B. 🔧 Outillage

| Sujet | Résultat |
|---|---|
| B1 | `DOC/NAVBOARDS` autorisé par `check_structure.py`; `AUDITS/PreLivraison/TASKS` est accepté par récursion |
| B2 | chemins `GVL_IHM.*` exclus du contrôle VAR_OUTPUT : Bridge Pattern légitime; dette `PRG_09` obsolète retirée |
| B3 | référence exécutable à `GVL_Simulation` interdite hors `SIMULATION`, `PRG_00`, `PRG_09`, `PRG_11` |
| B4 | motif `OR (GVL_Simulation.<flag> AND ...)` interdit sans exception |
| B5 | `CODE/CODE/CODE_Bundle.xml` supprimé; `CODE/CODE_Bundle.xml` régénéré et frais |

### Gates avant / après

| Moment | Résultat |
|---|---|
| Avant | `run_all_gates.py --skip-codesys` : **FAIL Gate 1** — `DOC/NAVBOARDS` non autorisé (1 erreur, 2 warnings) |
| Après G1 | Structure : **PASS** (0 erreur, 2 warnings historiques) |
| Après G2 | Style : **PASS** (0 erreur, 54 warnings historiques); les 36 faux positifs C3 de `PRG_09` = **0** |
| Après G3/G4 | Persistance : **PASS** · bundle : **PASS frais** |
| Après G5 | **FAIL hors périmètre** : 2 golden tests générateur (`GVL_PERSISTENT`, `ST_WinchHMI`), 309 passés |

### 🧪 Test volontaire des nouvelles règles

Fichier temporaire injecté puis supprimé : `CODE/MAIN/L7L8_GateProbe.st`.

```text
py -3.13 TOOLS\AGENT_WORKFLOW\scripts\check_code_style.py CODE\MAIN\L7L8_GateProbe.st
Code style check: FAIL (3 error(s), 0 warning(s))
[ERROR] ...:8: GVL_Simulation reference outside allowed simulation boundary
[ERROR] ...:9: GVL_Simulation reference outside allowed simulation boundary
[ERROR] ...:9: forbidden hybrid simulation forcing OR (GVL_Simulation.<flag> AND ...)
```

La sonde a été retirée immédiatement après le test.

## C. 📄 Documentation

| Action | Fichier |
|---|---|
| Créé | `AF_Partie-13_Fonction_Simulation_v2.0.md` |
| Créé | `AF_Partie-06_IO_Conditioning_v1.7.md` |
| Archivé | `ARCHIVES/Doc/AF_Partie-13_Fonction_Simulation_v2.0.md` |
| Archivé | `ARCHIVES/Doc/AF_Partie-06_IO_Conditioning_v1.7.md` |
| Mis à jour | `NAMING_CONVENTION.md`, `AF_Partie-01_Analyse_Fonctionnelle_v1.6.md`, `VERSION_HISTORY.md`, `CLAUDE.md` |

Références actives mises à jour dans `CLAUDE.md`. Les anciens fichiers DOC restent présents pour
conserver les liens de commentaires ST, conformément à l'interdiction de modifier tout autre
fichier `CODE/**/*.st`.

## 🚨 Alertes

1. Le gate complet ne peut pas être déclaré PASS : G5 échoue sur deux tests golden indépendants
   du lot. Aucun correctif appliqué hors périmètre.
2. Les warnings de style restants (54) sont préexistants : dette DIAG, contrôles homme-mort et
   références DOC absentes. Ils ne sont pas liés à L7–L8.
3. Les références `GVL_Simulation` hors frontière relevées avant ajout du gate sont uniquement
   dans des commentaires; le gate analyse le code exécutable, afin de bloquer les dépendances
   réelles sans interdire le REX documentaire.
4. `git diff --check` signale trois lignes blanches avec espaces dans le bundle régénéré,
   provenant de l'en-tête préexistant de `FB_SimBench`; aucune correction appliquée hors périmètre.
