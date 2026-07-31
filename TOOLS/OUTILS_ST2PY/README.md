# OUTILS_ST2PY — spécification et guide d'implémentation

But et périmètre
----------------
OUTILS_ST2PY est un prototype de pont ST/XML → Python destiné à produire des modules de test hors‑PLC à partir de POUs CODESYS.
À ce stade, l'implémentation livrée est centrée sur `core/fb_gen.py` :
- extraire l'interface d'un POU/FB depuis un bundle PLCopen XML,
- générer un module Python exécutable et un test pytest minimal à partir de ces entrées/sorties,
- valider avant génération la cohérence du contrat objet (classe encapsulée, méthodes `__init__`/`step`/mappings I/O, initialisation des variables d'interface),
- appliquer une génération sélective par hash/caching avec garde‑fou safety sur les POUs critiques.
Les étapes de traduction ST sémantique, de génération de PRG et d'assemblage de scénario sont toujours planifiées, pas encore implémentées.

Objectifs non fonctionnels
--------------------------
- sécurité : aucune exécution automatique sur le PLC ; tout se fait hors‑ligne en Python.
- idempotence : génération basée sur un fingerprint (SHA256) canonique ; pas de régénération inutile.
- traçabilité : chaque artefact généré inclut métadonnées (source, hash, date, template version).
- séparation claire des tests : tests/syntax (naming, style, bundle) vs tests/functional (FB Python).

Entrées et sources canonique
----------------------------
- Source canonique recommandée : bundle PLCopen XML exporté depuis CODESYS.
  Exemple dans ce workspace : [CODE_Bundle.xml](C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/CODE_Bundle.xml).
- Fallback : fichier `.st` individuel si le POU n'est pas présent proprement dans le bundle.

Principes de traduction
------------------------
- "XML-first" : utiliser le XML PLCopen comme représentation structurée (POU, VAR, instances) pour
  diminuer les heuristiques et les faux positifs liés au parsing brut de `.st`.
- Scope de conversion automatique : logique pure (assignations, IF/CASE, CASE, expressions arithmétiques,
  petites fonctions locales). Exclure automatiquement de la conversion : appels matériels, bibliothèques
  propriétaires, fonctionnalité safety critique (AU, PowerCutOff, SafeStop, homing) — ces cas déclenchent
  un blocage automatique et nécessitent une revue humaine (C4 sign‑off).
- Contrats de données explicites : les modules générés exposent désormais un `CONTRACT` et une fonction
  `validate_runtime_contract()` pour verrouiller les échanges d'entrée/sortie/état et éviter les agrégats
  de conditions ambiguës.
- Sortie : module Python avec une classe par FB, méthodes `__init__()` et `step()`, helpers `to_dict()` /
  `set_inputs_from_mask()`, et docstring lisible. Pour les FB de translation, la génération produit désormais
  un comportement de simulation minimal (machine d'état + temporisation simple) afin de rester proche du
  cycle PLC sans prétendre reproduire l'automate CODESYS à l'identique.

Architecture composants
-----------------------
- core/fb_gen.py
  - implémenté : extrait l'interface d'un POU depuis le bundle PLCopen XML, construit un module Python
    et un test pytest minimal à partir des entrées/sorties, puis applique le cache/hash et la garde‑fou safety.
- canonicalize.py
  - implémenté : fournit la représentation canonique utilisée pour calculer un hash stable d'un POU.
- changed_gen.py
  - implémenté : permet de déterminer les POUs à régénérer à partir des fichiers git modifiés.
- safety_tokens.json
  - implémenté : liste des tokens détectés comme sensibles et bloqués par défaut.
- prg_gen.py / assembler.py / ci_runner.py / templates/
  - planifiés : ils ne sont pas encore intégrés à la version courante du prototype.

Arborescence réelle (REX 2026-08, après réorganisation)
--------------------------------------------------------
TOOLS/OUTILS_ST2PY/
  ├─ core/                     # BIBLIOTHEQUE importable (jamais lancee directement) :
  │   ├─ fb_gen.py             #   generateur ST/PLCopenXML -> Python
  │   ├─ canonicalize.py, changed_gen.py, data_contracts.py
  │   ├─ simulation_bench.py   #   banc de simulation
  │   ├─ test_tracer.py        #   traceur d'execution -> chronicles/*.html
  │   └─ results_layout.py     #   POU -> domaine metier, chemins RESULTS/ (source unique)
  ├─ scripts/                  # OUTILS CLI autonomes (jamais importes) :
  │   ├─ check_test_registry.py    gate : registre <-> suites reelles
  │   ├─ visualize_py_module.py    diagrammes UML/FSM des modules generes
  │   ├─ st_to_py.py, tools_compute_hash.py, position_decoder_demo.py
  ├─ suites/                   # SUITE PYTEST de l'outil (pas les artefacts generes) :
  │   ├─ contracts/            #   comportement metier attendu (TC-*)
  │   ├─ generation/           #   le generateur fait-il son travail
  │   └─ simulation/           #   bancs de simulation
  ├─ functional_tests/         # catalogue CSV + runner translation M3
  ├─ TEST_REGISTRY.md          # tracabilite fonction <-> test critique (source unique)
  ├─ RESULTS/                  # ARTEFACTS GENERES (gitignore), un dossier par domaine
  │   ├─ AU/                   #   miroir de CODE/ et de l'analyse fonctionnelle
  │   │   ├─ modules/          #     *.py + *.meta.json generes
  │   │   ├─ reports/          #     *.safety_report.json, *.validation_report.json
  │   │   └─ chronicles/       #     TC-*.html + diagrammes UML/FSM + exports de banc
  │   ├─ TRANSLATION/          #   idem (modules/ reports/ chronicles/)
  │   ├─ COMMUN/               #   briques partagees (FB_Brake, FB_Ramp, FB_CycleTime)
  │   └─ _ARCHIVE/             #   artefacts neutralises, conserves pour historique
  └─ .st2py_cache.json

Trois noms, trois roles distincts, pour lever l'ambiguite historique (REX 2026-08) :
`suites/` = tests DE l'outil · `RESULTS/` = ce que l'outil PRODUIT · `functional_tests/` =
catalogue metier. Le mapping POU -> domaine est centralise dans `core/results_layout.py`
(un seul endroit a mettre a jour quand une fonction machine apparait).

Design détaillé : flux de génération
-----------------------------------
1. Détection des cibles
   - commande explicite `--pou <POU_NAME>` ou `--changed-from <git-ref>` pour détecter fichiers modifiés
     (ex: `git diff --name-only <ref>..HEAD`) et mapper aux POUs concernés.
2. Extraction POU
   - si `plcopen` disponible, parser le bundle et sérialiser le POU via xsdata (canonicalisé)
   - sinon, ouvrir le `.st` correspondant et normaliser (strip comments, collapse whitespace)
3. Hash canonicalisé
   - calculer SHA256 sur la représentation canonicalisée (XML rendu / normalized ST). Stocker dans cache.
4. Détection de staleness
   - comparer au cache : si identique => skip génération.
   - sinon => générer et mettre à jour cache.
   - détection transitive : si un POU B change et A appelle B => A marqué stale (re-générer) ou au moins
     émettre alerte (configurable : conservative regénération vs alerte humaine).
5. Génération module
   - produire classe Python minimaliste : inputs, outputs, step(); inclure docstring et mapping bitfields.
   - produire test pytest skeleton (table-driven) couvrant cas standards (valeur baselines) et invariants.
6. Sortie
   - écrire artefacts dans `RESULTS/<DOMAINE>/modules/` avec métadonnées `<POU>.meta.json` (source path, hash, template_version).

Cache et idempotence
--------------------
- `.st2py_cache.json` structure minimale:
  {
    "POU_NAME": {
      "hash": "...",
      "generated_at": "2026-07-28T...",
      "callers": ["CallerPOU1", ...]
    },
    ...
  }
- Règle : ne pas regénérer un module si hash inchangé, sauf `--force`.
- Transitive invalidation : on changement d'un POU, les callers peuvent être soit automatiquement regénérés,
  soit marqués dans le rapport PR pour revue — mode par défaut = conservative (regénérer callers simples),
  mode alternatif = report-only.

Sécurité / safety gate
----------------------
- Détection de tokens sensibles dans le POU source (exemples) : `PowerCutOff`, `AU`, `SafeStop`, `Homing`,
  `PowerCut`, `EmergencyStop`.
- Si tokens trouvés :
  - bloquer génération automatique,
  - produire rapport détaillé (ligne, motif),
  - exiger sign-off humain (C4) avant autorisation de génération (CLI `--override-safety-signoff` avec
    justificatif enregistré dans `.st2py_signoffs.json`).
- Justification : éviter toute fausse impression de validation automatique sur des fonctions critiques.

Tests et séparation (strategy)
------------------------------
- Deux familles de tests séparées et distinctes :
  1. `tests/syntax/` : linters, nommage, checks de conformité (existant : `check_code_style.py`).
     - Doit être exécuté sur tout PR touchant `CODE/`.
  2. `tests/functional/` : pytest pour modules Python générés (RESULTS/). Ces tests vérifient
     la logique métier isolée (unit + small integration via main_sim).
- CI pattern recommandé :
  - Step 1 (always): run tests/syntax; fail early on naming/style violations.
  - Step 2 (if generation requested in PR or RESULTS/ present): run generator for changed POUs,
    then run tests/functional; report pass/fail separately from syntax.
- Golden traces: store under `RESULTS/<DOMAINE>/golden/<POU>.json` and compare with tolerance. Use for regression detection.

PR / CI integration
-------------------
- Hook proposal : on PR create/update
  1. run `scripts/st_to_py.py changed --ref origin/main --out RESULTS/<DOMAINE>/modules/` to generate changed FBs (or report only if safety tokens present),
  2. run `ci_runner.py` which executes syntax tests and functional pytest for generated artifacts,
  3. post report in PR with:
     - list of generated modules,
     - hashes and diffs (if any),
     - test results (syntax vs functional),
     - safety warnings needing human signoff.
- Important : do NOT commit `RESULTS/` automatically into main branches; generated artifacts are for reviewer consumption and CI only.

CLI examples (chemins depuis la racine du depot)
------------
La bibliotheque vit dans `core/`, les outils CLI dans `scripts/`, la suite pytest dans
`suites/`, et les artefacts dans `RESULTS/<DOMAINE>/`.

- Lister POUs dans le bundle (requires plcopen):
  python TOOLS/OUTILS_ST2PY/scripts/st_to_py.py --list --bundle CODE/CODE_Bundle.xml

- Générer un FB unique (POU) — `--out` cible le domaine du POU :
  python TOOLS/OUTILS_ST2PY/core/fb_gen.py --bundle CODE/CODE_Bundle.xml \
      --pou FB_Translation_PositionDecoder \
      --out TOOLS/OUTILS_ST2PY/RESULTS/TRANSLATION/modules --allow-safety

- Tester rapidement le position decoder avec une entrée mask :
  python TOOLS/OUTILS_ST2PY/scripts/position_decoder_demo.py --mask 16

- Générer les FB modifiés depuis main (selective):
  python TOOLS/OUTILS_ST2PY/core/fb_gen.py --bundle CODE/CODE_Bundle.xml \
      --out TOOLS/OUTILS_ST2PY/RESULTS/TRANSLATION/modules --changed --ref origin/main

- Régénérer un POU malgré le cache :
  python TOOLS/OUTILS_ST2PY/core/fb_gen.py --bundle CODE/CODE_Bundle.xml \
      --pou FB_Translation --out TOOLS/OUTILS_ST2PY/RESULTS/TRANSLATION/modules --force --allow-safety

- Générer les diagrammes UML/FSM (ranges dans RESULTS/<DOMAINE>/chronicles/) :
  python TOOLS/OUTILS_ST2PY/scripts/visualize_py_module.py
  python TOOLS/OUTILS_ST2PY/scripts/visualize_py_module.py FB_Safety_EmergencyManagement

- Vérifier la cohérence du registre de traçabilité tests <-> TEST_REGISTRY.md :
  python TOOLS/OUTILS_ST2PY/scripts/check_test_registry.py --report

- Lancer la suite pytest complete :
  cd TOOLS/OUTILS_ST2PY && python -m pytest suites

Critères d'acceptation pour une génération (POU)
------------------------------------------------
- Le module Python exécute `step()` sans erreurs pour inputs bool/ints floats valides.
- Les tests unitaires générés (squelette) s'exécutent avec `pytest` et passent pour la base de cas
  (6 combinaisons valides + cas invalides pour PositionDecoder).
- Le hash du POU est enregistré dans `.st2py_cache.json` et empêche régénération inutile.
- S'il y a tokens safety, la génération échoue et demande sign-off explicite.

Limitations connues
-------------------
- Traduction 1:1 impossible pour appels matériels, blocs natifs et certaines constructions ST (pointeurs,
  instructions bas‑niveau). Ces éléments seront stubés et requièrent adaptation manuelle.
- Simulation Python est une aide de validation logique, pas une preuve FAT/SAT. Les validations matérielles
  restent obligatoires.

Extension et maintenance
------------------------
- Templates : améliorer templates Jinja2 pour produire code plus idiomatique / typing / docstrings.
- Parser ST : si besoin, améliorer fallback ST parser (simple AST) pour couvrir cas non exportés en XML.
- Ajouter Hypothesis-based property tests pour fonctions critiques.

Licence & contact
-----------------
- Prototype repris dans ce repo; réutiliser sous les règles du projet. Pour questions, contacter l'auteur de
  l'outil dans l'équipe (mettre ici le nom/mail du responsable).

---

Historique des actions récentes (extrait, 2026-07-28)
---------------------------------------------------
- Génération et tests : plusieurs POUs liés à la translation ont été générés et testés en prototype Python :
  - FB_Safety_Translation (safety) — détection tokens safety, blocage par défaut, génération possible avec --allow-safety.
  - FB_Translation — logique de pilotage translation (Enable / SafeStop / StartStop / DriveControlWord).
  - FB_Translation_PositionDecoder — décodage mot capteurs (5 positions) et détection incohérences.
  - Dépendances générées automatiquement (stubs/implémentations observables) : FB_Brake, FB_Ramp, FB_CycleTime, etc.
- Résultats : les tests générés ont été exécutés localement via `python -m pytest` et sont passés (séquences unitaires et petits tests d'intégration).
- Nettoyage de démonstration : l'artefact de preuve `FB_Test_Safety` a été neutralisé (placeholder) pour éviter toute confusion.

Comment reproduire localement (exemples rapides)
------------------------------------------------
- Générer un FB unique (forcé, permissif safety) :
  python TOOLS/OUTILS_ST2PY/core/fb_gen.py --bundle CODE/CODE_Bundle.xml --pou FB_Translation --out TOOLS/OUTILS_ST2PY/RESULTS/TRANSLATION/modules --force --allow-safety

- Générer les dépendances identifiées automatiquement :
  (lancer fb_gen pour chaque POU référencé ou utiliser --changed pour détection git)

- Exécuter toute la suite pytest de l'outil (contracts/generation/simulation) :
  cd TOOLS/OUTILS_ST2PY && python -m pytest suites

- Exécuter les tests generes a la volee (RESULTS/<DOMAINE>/modules/tests, ecrase a chaque run) :
  python -m pytest TOOLS/OUTILS_ST2PY/RESULTS/TRANSLATION/modules/tests

Notes opérationnelles supplémentaires
------------------------------------
- La génération crée des prototypes Python fondés sur la logique observable dans chaque POU ;
  quand des dépendances (instanciations FB externes) existent dans `CODE/`, le générateur peut créer
  automatiquement des stubs/modules pour ces dépendances afin d'autoriser des tests d'intégration locaux.
- Ces artefacts sont destinés à la revue et aux tests CI, pas à un déploiement automatique dans l'automate.

Prochaines étapes recommandées (court terme)
--------------------------------------------
1. Externaliser la liste des tokens safety dans `TOOLS/OUTILS_ST2PY/safety_tokens.json` pour pouvoir l'éditer sans modifier le code.
2. Implémenter un mécanisme de sign‑off (.st2py_signoffs.json + CLI `--sign-off`) afin d'autoriser formellement la génération d'un POU safety.
3. Ajouter `prg_gen` minimal pour composer FB_Safety_Translation + FB_Translation + PositionDecoder dans un scénario d'intégration et exécuter des séquences réalistes.

Fin de README : cette spécification doit rester synchronisée avec le code dans `TOOLS/OUTILS_ST2PY/`.
Mettre à jour cette page à chaque changement de design important (hash algo, safety tokens, comportement CLI).
