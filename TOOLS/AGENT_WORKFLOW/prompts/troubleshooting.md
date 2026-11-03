# 🕵️ Méthode de Recherche de Blocage / Diagnostic (Excavatrice Dragage)

> Prompt réutilisable pour diagnostiquer un blocage/bug dans le programme CODESYS.
> Les accès au PLC dépendent de l'environnement et de l'autorisation de la mission. Ne pas supposer
> qu'un agent peut piloter ou lire le runtime. Une fiche est créée seulement si elle aide au suivi,
> à la reprise ou à la conservation de preuves.

> 🧭 **Répartition (T150-A / T150-D)** : ce fichier est la **méthode détaillée de référence**.
> Il est référencé par la source canonique `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md`
> (procédure exécutable) et par les stubs `.claude/.dsh/skills/troubleshooting/SKILL.md`
> (déclencheurs). **Une seule copie de la méthode** — ne pas dupliquer ce contenu ailleurs.
> Garde-fou : `TOOLS/AGENT_WORKFLOW/scripts/check_skill_stubs.py` (G440).

## 0. 🎯 Choisir la méthode selon les preuves

> ⛔ **Aucune méthode n'est obligatoire.** Le débogage se fait **par discussion avec l'utilisateur**, en fonction des **données disponibles** et de la **facilité**, dès le début. L'agent n'impose pas une voie lourde (ajout de variable à `GVL_Troubleshooting`, test CI...) sans que ce soit adapté au cas.

Commencer par les données déjà disponibles et l'analyse statique à faible coût. Choisir la mesure
qui départage les hypothèses ; ne demander une orientation que si plusieurs voies plausibles ont
des conséquences différentes pour l'utilisateur. Ne pas afficher le menu complet par défaut.

## 0bis-A. 📥 ACQUISITION DES VALEURS (canal)

> **Comment l'agent obtient les valeurs du PLC sans l'exécuter.**

- Si une acquisition live est nécessaire et autorisée, privilégier le snapshot CSV existant
  (`codesys_snapshot_troubleshooting.py`, `troubleshooting_variables.txt`) quand il couvre les
  variables utiles. Un autre canal existant peut convenir si le contrat le prévoit.
- **Règle de vérification avant demande** : pour chaque variable de décision, **vérifier d'abord** qu'elle est :
  1. implémentée dans `GVL_Troubleshooting` (grep `CODE/J_SUPERVISION/GVL_Troubleshooting.st` + types `_TYPES/ST_*.st` + câblage `FB_TroubleshootingView.st`) ;
  2. présente dans la liste du script `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt`.
- **Si présente** dans les deux → demander un snapshot uniquement si les valeurs changent le verdict.
- **Si manquante** → ne pas inventer de valeur ni de mesure ; signaler l'observabilité manquante et
  proposer l'ajout seulement si cette mesure est nécessaire à la décision.
- ⚠️ Si la cause exige > 2-3 structures → le troubleshooting est **mal conçu** OU il faut **créer une structure dédiée** à ce type de problématique. Le signaler.
- 🚫 **Ne JAMAIS se baser sur `Device.export`** (souvent périmé). Sources fiables : `CODE/*.st` + `GVL_Troubleshooting` (via snapshot).

## 0bis-B. 🔬 TEST CI AD HOC DE DÉPANNAGE (compiler un FB et vérifier une fonction)

> Méthode **complémentaire** au snapshot : quand le doute porte sur une **fonction d'un FB isolé**
> (simulation `FB_Sim_*`, logique interne, machine d'état), la **prouver par un test automatisé**
> plutôt que par un snapshot PLC. Utile quand la variable n'est pas dans `GVL_Troubleshooting`.

Dossier dédié : `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/` (le **underscore** = spécial/jetable, **hors registry principal** `registry.yaml`).

Démarche :
1. **Mettre à jour le script** `run_troubleshooting.py` : définir l'entrée ad hoc `FB_NAME` + `ENTRY["sources"]` (DUT/enum d'abord, FB en dernier) + `ENTRY["test"]`.
2. **Mettre à jour le test** `.st` (format `TEST '...'` + `ASSERT_*`, voir exemples dans `RESULTS/<domaine>/tests/`). Le test ne lit que les **sorties publiques** du FB (`VAR_INPUT`/`VAR_OUTPUT`/`VAR_IN_OUT`), jamais les internes.
3. **Compiler + exécuter** :
   ```bash
   python TOOLS/TEST_AUTO_CI/scripts/run_tests.py
   ```

   → rapport dans `RESULTS/_TROUBLESHOOTING/reports/` + affichage PASS/FAIL par test.
4. **Preuve** : PASS prouve le comportement attendu ; FAIL donne le message d'assertion exact (valeur attendue vs obtenue).

Règles :
- Les tests ad hoc et rapports sont des artefacts à tracer selon T279 ; aucun nettoyage ou retrait
  automatique. Déclarer clairement leur portée et ne pas les présenter comme une validation terrain.
- ⚠️ Dans le runner CI, **chaque appel `fb(...)` = 1 scan** (10ms) : `ADVANCE_TIME` avance le temps simulé mais ne fait **pas** tourner le FB — pour simuler N ms il faut **N/CycleTimeS appels** (ex. 1.6s @10ms = 160 appels), ou tester à l'échelle d'un scan.

## 1. 🧊 CONTEXTE FIGÉ (à remplir UNE fois selon la situation)

> ⚠️ **L'agent NE DOIT PAS re-demander ces infos.** Si un point manque → le marquer **inconnu**, poser une hypothèse explicite et poursuivre l'analyse ; ne le demander que s'il change la sécurité ou le verdict. Vérifier la **fraîcheur** : **re-figer si > 5 min** ou si un événement (redémarrage, changement de mode) est survenu depuis le dernier contexte.

**Situation :** `[SIMULATION BANC]` / `[SITE MACHINE RÉELLE]`

**État de départ** (redémarrage = valeurs par défaut) :
- `SimulationModeActive` : `TRUE` (banc) / `FALSE` (site)
- `SimulationBypassActive` : `TRUE` (banc) / `FALSE` (site)
- Référencement axes (homing) : fait / non fait
- Mode machine : `MAINT_N1` / `MAINT_N2` / `SEMI_AUTO` / `DISABLE`

**Acquis :** simulation active / matériel réel · référencement fait · 2 bits posés · toute autre valeur = défaut.

## 2. 🧩 Indices et historique

| # | Question | Pourquoi |
|---|---|---|
| 1 | Symptôme exact (quoi, où, depuis quand) ? | Cadre le périmètre |
| 2 | **Permanent ou intermittent** ? | Oriente l'arbre racine |
| 3 | Derniers changements (code, config, câblage, HMI) ? | Cause n°1 = régression → lire `VERSION_HISTORY`/git |
| 4 | Ce qui a déjà été essayé (et résultat) ? | Évite de re-tester |
| 5 | Conditions d'apparition (mode, charge, position) ? | Révèle le gating |
| 6 | Alarmes / historique d'alarmes ? | Cause souvent déjà nommée |

Utiliser les informations déjà fournies. Poser seulement les questions sans réponse qui changent
le périmètre ou le verdict ; ne pas rejouer une liste de questions complète.

**Force des preuves** : les valeurs/mesures directes sont plus fortes que les observations rapportées ;
une inférence seule ne confirme jamais une cause. Une observation rapportée reste un postulat
d'analyse valable : elle n'est pas contestée faute de mesure.

## 3. 🧭 PHASE 0 — Caractériser le symptôme (avant tout arbre)

| Type | Signature | Arbre racine probable |
|---|---|---|
| Sortie ne s'émet pas | Y reste FALSE | Chaîne enable/interlock (reverse) |
| Sortie ne se coupe pas | Y reste TRUE | Front, tempo, état, sortie collée |
| Valeur fausse | ≠ attendu | Scaling, type, config, producteur |
| État bloqué | machine à état figé | Condition de transition, front, mode |
| Intermittent | parfois OK | Timing, race, comm, mécanique |
| Aucune réaction | rien ne bouge | Tâche, mode, enable global, power |

**Question clé** : *permanent ou intermittent ?* → permanent = logique/config/câblage ; intermittent = timing/race/comm/mécanique.

## 4. 🌳 GABARIT STANDARDISÉ d'arbre des causes (6 catégories)

Chaque nœud = **variable de décision + où la lire + valeur attendue**.

```
SYMPTÔME
├─ 1. ENTRÉES / CAPTEURS      → signal absent / mal interprété / fieldbus
├─ 2. LOGIQUE / INTERLOCKS    → condition d'enable FALSE (lire CHAQUE conjonction) / logique erronée
├─ 3. MACHINE À ÉTAT          → état incorrect / transition jamais déclenchée / état invalide
├─ 4. CONFIGURATION / PARAMS  → seuil/temps mal réglé / constante mal initialisée
├─ 5. TIMING / ORDRE DE SCAN  → retard 1 scan / TON (ET, IN) / front manqué (M du R_TRIG)
└─ 6. SORTIES / ACTIONNEURS  → commandée sans action / non commandée (reverse)
```

**Règle d'or** : à chaque nœud, répondre *« quelle variable prouve/réfute cette branche, où la lire ? »*. Sinon branche **non testable** → le marquer et l'évaluer par déduction, avec l'étiquette **hypothèse**.

**💡 Exhaustivité & vitesse** : pour parcourir rapidement toutes les branches, déléguer l'exploration de branches **indépendantes** à des **sous-agents** (en parallèle), chacun remontant une branche jusqu'à sa source et rendant son verdict (cause confirmée / éliminée + preuve).
> ⚠️ **Délégation par CONTRAT clair** : objectif précis, **mesurable et évaluable** (ex. « éliminer ou confirmer la branche X, preuve = lecture de la variable Y »). **Analyse statique** (code `.st`) = déléguable. **Lecture live** (demander à l'utilisateur) = **non déléguable** (l'orchestrateur la fait). Si le contrat n'est pas mesurable → **faire soi-même**.

## 5. 🔄 TRACAGE INVERSE (reverse) — algorithme

```
TRACE_INVERSE(S):
  C = condition(s) qui commandent S
  pour chaque conjonction c_i de C:
    si c_i est FALSE:
      si c_i = ENTRÉE physique → cause EXTERNE (capteur/câblage/fieldbus) → STOP
      si c_i = PARAMÈTRE/config → cause CONFIG → STOP
      sinon → TRACE_INVERSE(c_i)          # récursion
  si toutes TRUE mais S reste FALSE → la LOGIQUE de S est erronée (vérifier le producteur)
```

**Vérification directe (forward)** : une fois la cause candidate trouvée, retracer en aval pour confirmer qu'elle explique S. **Règle producteur unique** : si S est écrit par plusieurs FB → bug suspect (aliasing).

## 6. 🛑 CRITÈRE D'ARRÊT (STOP quand)

1. **Nœud feuille** : entrée physique, paramètre, frontière matérielle.
2. **Cause prouvée** : variable FALSE alors qu'elle devrait être TRUE, et toutes ses entrées correctes → logique fausse.
3. **Frontière au-delà du PLC** : cause hors lecture → « voici quoi vérifier physiquement ».
4. **Étape suivante = modifier le code / forcer une variable** → **hand-off humain** (interdit sans validation).

**Ne PAS continuer** : hypothèse confirmée · prochaine étape **dangereuse** (actionnement d'organe) → recommander état sûr (MAINT, power cut).

## 7. 🧠 CAS LIMITES PLC/CODESYS (à ajouter à l'arbre)

| Cas | Signature | Variable de décision |
|---|---|---|
| Ordre de scan inter-PRG | valeur = scan précédent | ordre d'appel dans la tâche |
| RETAIN / persistance | mauvais état après coupure | valeur RETAIN, type de redémarrage |
| Front R_TRIG/F_TRIG | événement manqué | bit mémoire M du front |
| TON | sortie jamais TRUE | ET (accumule ?), IN (maintenu ?) |
| Portée inter-PRG | lue ≠ écrite | GVL vs VAR locale, collision |
| Gating par mode | fonction inerte hors mode | mode + condition de mode |
| Bypass / forçage | valeur figée anormale | variables forcées |
| Retard d'un scan | valeur décalée d'un cycle | ordre d'appel |
| Tâche arrêtée / watchdog | variables figées | statut tâche, temps de cycle |
| Multi-écrivains | valeur instable | producteur unique violé |
| Scaling analogique | seuil jamais atteint | brute vs échelle |
| Fieldbus / comm | entrée figée | statut I/O, validité image |

## 8. 📊 PRÉSENTATION — tableau d'hypothèses + journal

| # | Hypothèse | Variable de décision | Valeur attendue | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Capteur X HS | `GVL_Troubleshooting.X` | TRUE | FALSE | ❌ éliminée |
| 2 | Interlock Y bloque | `GVL_Troubleshooting.Y` | TRUE | FALSE | ✅ **cause** |

- Classer par *vraisemblance × coût de test*, **sécurité d'abord**.
- Étiqueter la force des preuves (🟢/🟡/🔴).
- **Journal auditable** : chaque hypothèse → preuve → verdict.
- **Ne jamais inventer un nom de variable** : vérifier l'existence contre le code/spec réel.

## 8bis. 🗺️ CARTE DE LECTURE — `GVL_Troubleshooting`

> Toutes les structures du GVL réel (`CODE/J_SUPERVISION/GVL_Troubleshooting.st`). Lire dans ces structures, jamais dans des internes de FB.

| Structure | Contenu |
|---|---|
| `ContexteMachineGlobal` | Mode, simulation, joystick maître, AU, power, heartbeat |
| `LevageSynchroniseM1M2` | Synchro M1+M2 (mode couplé) |
| `LevageUnitaireM1` / `LevageUnitaireM2` | Treuils M1 / M2 |
| `BenneOuvertureFermeture` | Benne (Busy, IsOpen, état, défauts) |
| `TranslationPontM3` | Translation M3 (variateur) |
| `AssistanceDragage` | Plongée / extraction / vidage trémie |
| `HomingM1` / `HomingM2` | Référencement M1 / M2 |
| `Safety` | Chaîne de sécurité & réarmement AU |
| `Joystick` | Bus CANopen & homme-mort |
| `MotionM1` / `MotionM2` / `MotionM3` | Mouvement M1 / M2 / M3 |
| `Inputs` | Image entrées réelles / qualifiées / simulées |

> 🛠️ **Ergonomie maintenance** : le dépanneur ouvre **une structure = tout sur une page**. Si une variable manque pour ce dépannage → **proposer son intégration**. Si une variable est présente mais inutile → **proposer son retrait**. Si une variable devrait être dans une autre structure pour l'ergonomie → **le signaler**.

## 9. ✅ RÈGLES DE L'AGENT
- Ne pas re-demander le contexte figé (§1).
- Distinguer **FAIT / HYPOTHÈSE / INCERTITUDE**.
- Lire dans `GVL_Troubleshooting` (lecture seule), **jamais forcer**.
- **Ne pas modifier le code, forcer une variable ou piloter un runtime** sans autorisation explicite.
- Une cause racine n'est dite **prouvée** que par lecture ; déduite, elle est dite **la plus probable** et l'analyse continue.
- 🚫 **Ne JAMAIS se baser sur `Device.export`** : cet export est mis à jour au bon vouloir humain,
  il est **souvent périmé** et induit des conclusions fausses. Sources fiables = `CODE/*.st`
  (sources versionnées) + `GVL_Troubleshooting` (diagnostic en direct).
