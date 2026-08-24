---
name: troubleshooting
description: Recherche de blocage / diagnostic de panne dans le programme CODESYS. Déclencher dès que l'utilisateur demande de chercher un blocage, une panne, un bug, « pourquoi ça bloque », « pourquoi ça ne marche pas », un diagnostic, ou un troubleshooting. Crée une fiche de session dans DOC/WFLOW/TROUBLESHOOTING/ et applique la méthode d'arbre de décision + traçage inverse.
---

# 🕵️ Skill Troubleshooting — Recherche de Blocage (Excavatrice Dragage)

Méthode de diagnostic d'un blocage/bug dans le programme CODESYS, **sans exécuter le PLC** (lecture de variables de diagnostic + raisonnement par arbre de décision).

> 🧭 **Répartition des 3 fichiers (T150-A / T150-D)** — *une méthode, écrite une seule fois* :
>
> | Fichier | Rôle | Contenu |
> |---|---|---|
> | `.claude/skills/troubleshooting/SKILL.md` · `.dsh/skills/troubleshooting/SKILL.md` | **Déclencheurs** (stub court) | front-matter de détection + pointeur → ce fichier. Zéro méthode. |
> | `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md` (ce fichier) | **Source canonique** — procédure exécutable | bannière + étapes 0→8 + checklist |
> | `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` | **Méthode détaillée de référence** | algorithmes, tableaux de décision, cas limites (§1→§9) |

Le **garde-fou** `TOOLS/AGENT_WORKFLOW/scripts/check_skill_stubs.py` (gate G440) vérifie que les
stubs pointent bien vers ce canonique et qu'aucune copie complète n'est dupliquée.

📖 **Méthode complète** : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` (à lire en entier avant de commencer).

---

## ⛔ RÈGLE D'OR

**Ne jamais modifier le code ni forcer une variable sans validation humaine explicite.**
Cause racine **prouvée par lecture de variable**, jamais par inférence seule.
🚫 **Ne JAMAIS se baser sur `Device.export`** (souvent périmé, jamais une référence de contrôle).
Sources fiables : `CODE/*.st` + `GVL_Troubleshooting`.

---

## 🚦 Déclenchement

Déclencher sur : « cherche le blocage », « pourquoi ça bloque », « pourquoi ça ne marche pas », « diagnostic », « troubleshooting », « recherche de panne », « ça ne s'active pas », « ça ne se coupe pas ».

---

## 🚨 BANNIÈRE DE DÉCLENCHEMENT (OBLIGATOIRE)

Dès que la skill est déclenchée, **afficher immédiatement** ce texte clair en majuscules (dans le terminal / les échanges), avant toute autre action :

```
============================================================
🕵️ MODE DÉPANNAGE / TROUBLESHOOTING ACTIF
============================================================
```

Puis annoncer en 1 ligne le sujet du diagnostic (ex. « Diagnostic : DeadmanArmed tombe à 0 en commande descente »).

> 📛 Format standard : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (gabarit unique, 60 `=`).

## 🎯 ORIENTATION MÉTHODE (obligatoire au lancement — AUCUNE voie imposée)

> ⛔ **Le test CI ad hoc (§4ter) n'est PAS la voie obligatoire.** Il existe **plusieurs méthodes** de débogage, et le choix se fait **par discussion avec l'utilisateur**, en fonction des **données disponibles** et de la **facilité**, dès le début.

Afficher ensuite une **notice des méthodes possibles** pour que l'utilisateur voie les options et puisse orienter (et commenter ce qui a déjà été testé) :

```
🧭 Méthodes de débogage possibles :
  [1] Snapshot PLC (GVL_Troubleshooting) — lecture de variables en simu/site
  [2] Test CI ad hoc (_TROUBLESHOOTING/) — compiler un FB + vérifier une fonction
  [3] Analyse statique déléguée (sous-agent trace la chaîne dans le code)
  [4] Lecture trace CODESYS (variables internes d'un FB) par l'utilisateur
  [5] Autre / combinaison
```

Puis **poser la question d'orientation** (adaptée au symptôme) :
- Quelles **données sont déjà disponibles** (snapshot, trace, variables) ?
- Quelle méthode est la **plus facile / rapide** dans ce cas précis ?
- (option) Que voulez-vous que je **documente / que j'ai testé** jusqu'ici, pour vos commentaires ?

➡️ **L'agent suit l'orientation choisie** ; il peut combiner plusieurs méthodes. Il ne démarre **pas** une méthode lourde (ex. ajout de variable à `GVL_Troubleshooting` ou test CI) sans que ce soit adapté au cas. L'utilisateur voit **ce qui a été testé** (journal de la fiche) et peut commenter.

---

## 📋 Procédure

### Étape 0 — Créer la fiche de session
Créer `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_<Sujet>_<AAAAMMJJ>.md` depuis le gabarit `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`.

### Étape 1 — Remplir le contexte figé (§1 du prompt)
Lire la fiche existante si elle existe (contexte déjà figé). Sinon, demander UNE fois : situation (banc/site), mode, bits, référencement. **Ne pas re-demander ensuite.**

### Étape 2 — Collecter les indices (§2)
6 questions max (symptôme, permanent/intermittent, changements récents, déjà essayé, conditions, alarmes). Étiqueter la force des preuves (🟢/🟡/🔴).

### Étape 3 — Caractériser le symptôme (§3)
Type de symptôme (sortie ne s'émet pas / ne se coupe pas / valeur fausse / état bloqué / intermittent / aucune réaction).

### Étape 4 — Construire l'arbre des causes (§4)
Énumérer TOUTES les branches (6 catégories). Pour chaque nœud : variable de décision + où la lire + valeur attendue. **Pour l'exhaustivité & la vitesse** : déléguer l'exploration de branches **indépendantes** à des **sous-agents** (en parallèle), chacun remontant une branche jusqu'à sa source. ⚠️ **Délégation par CONTRAT clair** (objectif mesurable/évaluable) ; **analyse statique** = déléguable, **lecture live** = non déléguable (l'orchestrateur la fait). Si le contrat n'est pas mesurable → faire soi-même.

### Étape 4bis — Acquisition des valeurs (canal = **SNAPSHOT**, pas de lecture Watch)

> 🔑 **Règle nouvelle : ne demander AUCUN état de variable sans avoir vérifié qu'il est capturable.**
> Le canal unique d'acquisition est le **snapshot CSV** du script `codesys_snapshot_troubleshooting.py`
> (lecture de `troubleshooting_variables.txt`). **Ne jamais demander une lecture Watch variable par variable.**

Avant de demander quoi que ce soit à l'utilisateur, pour **chaque variable de décision** nécessaire :
1. ✅ **Vérifier qu'elle est implémentée dans `GVL_Troubleshooting`** — grep du chemin dans `CODE/J_SUPERVISION/GVL_Troubleshooting.st` + ses types `_2.._TYPES/ST_*.st` (et le câblage dans `FB_TroubleshootingView.st`).
2. ✅ **Vérifier qu'elle est dans la liste du script** — grep du chemin exact dans `TOOLS/PLC_LIVE_READER/variable_lists/troubleshooting_variables.txt`.

Selon le résultat :
- **Présente dans les deux** → demander **UN seul snapshot** : « Lance `Ctrl+W` (ou `execfile(codesys_snapshot_troubleshooting.py)`) et renvoie-moi le CSV ».
- **Manquante (dans GVL_Troubleshooting OU dans la liste)** → **NE PAS demander de valeurs live**. Proposer d'ajouter la variable dans `GVL_Troubleshooting` (structure + câblage `FB_TroubleshootingView`), régénérer la liste (`python .../generate_variable_list_from_code.py`), **valider avec l'humain**, puis compiler + snapshot.

Acquisition max = **UN snapshot**. Si la cause exige > 2-3 structures à lire → le troubleshooting est mal conçu OU il faut une structure dédiée → le signaler.

### Étape 4ter — Test CI ad hoc de dépannage (compiler un FB et vérifier une fonction)

> 🔬 **Méthode complémentaire** : quand le doute porte sur une **fonction d'un FB isolé** (simulation, logique interne, machine d'état), on peut la **prouver par un test automatisé** au lieu d'un snapshot PLC. Utile notamment quand la variable n'est pas dans `GVL_Troubleshooting` (cas `FB_Sim_*`, internes de FB).

Dossier dédié : `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/` (le **underscore** signale que c'est spécial/jetable, **hors registry principal**).

Démarche :
1. **Mettre à jour le script** `run_troubleshooting.py` : définir l'**entrée ad hoc** `FB_NAME` + `ENTRY["sources"]` (DUT/enum d'abord, FB en dernier) + `ENTRY["test"]`.
2. **Mettre à jour le test** `.st` (format `TEST '...'` + `ASSERT_*`, voir exemples dans `RESULTS/<domaine>/tests/`). Le test ne doit lire que les **sorties publiques** du FB (jamais les internes).
3. **Compiler + exécuter** :
   ```
   python TOOLS/TEST_AUTO_CI/scripts/run_tests.py
   ```
   → génère le rapport dans `RESULTS/_TROUBLESHOOTING/reports/` et affiche PASS/FAIL.
4. **Preuve** : un test PASS **prouve** le comportement attendu ; un FAIL donne le message d'assertion exact (différence valeur attendue/obtenue).

Règles :
- **⚠️ Dossier jetable** : nettoyer `RESULTS/_TROUBLESHOOTING/` après chaque dépannage (ne pas commiter les tests ad hoc).
- Le test n'accède **jamais** aux `VAR` internes du FB (seulement `VAR_INPUT`/`VAR_OUTPUT`/`VAR_IN_OUT`).
- ⚠️ Dans le runner CI, **chaque appel `fb(...)` = 1 scan** (10ms) : `ADVANCE_TIME` avance le temps simulé mais ne fait pas tourner le FB — pour simuler N ms il faut **N/CycleTimeS appels** (ex. 1.6s @10ms = 160 appels) ou tester à l'échelle d'un scan.

### Étape 5 — Tracage inverse + élimination par preuve (§5, §6)
Remonter du symptôme à la source. Lire les variables de décision dans le **snapshot CSV** (jamais Watch). Éliminer les branches par FAIT. S'arrêter au critère d'arrêt (§6).

### Étape 6 — Conclure + mettre à jour la fiche
Cause racine + correction proposée. Remplir la **section 8 (Proposition de correction)** : Option 1 (immédiat, sans code) + Option 2 (définitif) + validation requise. Mettre à jour la fiche (verdicts, journal, conclusion). **Ne pas modifier le code sans validation.**

### Étape 7 — Vérification / non-régression
Après correction (validée), remplir la **section 9** : le symptôme est-il résolu ? rien d'autre cassé ? (aligné `fix:` + `guard:`).

### Étape 8 — Clôturer la fiche : archiver les acquisitions PLC_LIVE_READER
Si des CSV ont été produits pendant la session (`TOOLS/PLC_LIVE_READER/RESULTS/snapshot/` et `RESULTS/acquisition/`) : les déplacer vers `ARCHIVES/Tools/PLC_LIVE_READER/RESULTS/<Sujet>_<AAAAMMJJ>/` (même `<Sujet>_<date>` que la fiche). But : éviter l'accumulation de CSV non triés dans `RESULTS/snapshot/`+`acquisition/`, qui sont trackés en Git. Ne déplacer que les CSV horodatés pendant la fenêtre de la session ; en cas d'ambiguïté (plusieurs fiches le même jour), demander avant de trier.

---

## 📚 Références

- Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`
- Gabarit : `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`
- **Bannière** : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (format 60 `=` unique)
- **Guide de remplissage** : `DOC/WFLOW/TROUBLESHOOTING/GUIDE_Troubleshooting.md`
- Exemple : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_DeadmanArmed_20260815.md`
- Carte de lecture : `GVL_Troubleshooting` — `ContexteMachineGlobal`, `LevageSynchroniseM1M2`, `LevageUnitaireM1/M2`, `BenneOuvertureFermeture`, `TranslationPontM3`, `AssistanceDragage`, `HomingM1/M2`, `Safety`, `Joystick`, `MotionM1/M2/M3`, `Inputs`
- Ordre d'exécution : `PRG_02 → PRG_03 → PRG_04/05 → PRG_06 → PRG_07`

## ✅ Checklist de restitution

- [ ] Fiche de session créée / mise à jour dans `DOC/WFLOW/TROUBLESHOOTING/FICHES/`
- [ ] Contexte figé rempli (pas de re-questions)
- [ ] Arbre des causes complet (6 catégories)
- [ ] **Variables de décision vérifiées dans `GVL_Troubleshooting` ET dans `troubleshooting_variables.txt` avant toute demande** (ajoutées + régénérées si manquantes, avec validation)
- [ ] Acquisition par **snapshot CSV unique** (pas de lecture Watch) **OU test CI ad hoc** (§4ter) selon le besoin
- [ ] Hypothèses éliminées par PREUVE (lecture), pas par inférence
- [ ] Cause racine + correction proposée
- [ ] Aucun code modifié / aucune variable forcée sans validation
- [ ] `_TROUBLESHOOTING/` nettoyé après usage (dossier jetable)
- [ ] CSV `PLC_LIVE_READER/RESULTS/` de la session archivés dans `ARCHIVES/Tools/PLC_LIVE_READER/RESULTS/<Sujet>_<date>/`
