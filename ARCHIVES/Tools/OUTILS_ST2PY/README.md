# OUTILS_ST2PY

Convertit un FB CODESYS (ST/PLCopen XML) en module Python simulable **hors PLC**, pour tester
la logique métier sans matériel. Prototype, pas un outil de production.

## Démarrage rapide

| Je veux... | Commande |
|---|---|
| Lister les POU d'un bundle | `python scripts/st_to_py.py --list --bundle ../../CODE_XML/CODE_Bundle.xml` |
| Générer un FB en Python | `python core/fb_gen.py --bundle ../../CODE_XML/CODE_Bundle.xml --pou <POU> --out RESULTS/<DOMAINE>/modules` |
| Régénérer malgré le cache | idem + `--force` |
| Générer les FB modifiés (git) | idem + `--changed --ref origin/main` |
| Lancer toute la suite pytest | `python -m pytest` |
| Vérifier le registre de tests | `python scripts/check_test_registry.py --report` |
| Générer les diagrammes UML/FSM | `python scripts/visualize_py_module.py` |

Toutes les commandes se lancent depuis `ARCHIVES/Tools/OUTILS_ST2PY/`.

## Architecture — 3 dossiers, 3 rôles

```
core/       bibliothèque importable (jamais lancée seule)      -> le moteur
scripts/    outils CLI autonomes (jamais importés)              -> les commandes
RESULTS/    tout ce que produit/teste l'outil, par DOMAINE     -> la preuve + la sortie
```

Depuis REX 2026-08 : plus de dossier `tests/` global séparé des résultats. Chaque domaine
machine (`AU`, `TRANSLATION`...) porte ses PROPRES tests, modules générés, rapports et
diagrammes au même endroit — un humain qui cherche "tout sur l'AU" trouve tout sous
`RESULTS/AU/`, sans devoir croiser deux arborescences paralleles.

```
core/
  fb_gen.py            générateur ST/PLCopenXML -> Python (cœur de l'outil, ~1600 lignes)
  canonicalize.py       hash stable d'un POU (détection de changement)
  changed_gen.py         POU à régénérer depuis `git diff`
  data_contracts.py     contrats d'échange (CONTRACT + validate_runtime_contract)
  simulation_bench.py   banc de simulation (scénarios multi-scan)
  test_tracer.py         trace scan-par-scan -> export HTML
  results_layout.py     POU -> domaine métier -> chemin RESULTS/ (source unique)

scripts/
  st_to_py.py              lister/générer un POU en ligne de commande
  check_test_registry.py  gate : TEST_REGISTRY.md <-> tests réels cohérents
  visualize_py_module.py  diagrammes UML (+FSM si détectée) depuis RESULTS/*/modules/*.py
  tools_compute_hash.py, position_decoder_demo.py   utilitaires ponctuels

RESULTS/<DOMAINE>/     un dossier PAR FONCTION MACHINE (miroir de CODE/ et de l'AF)
  tests/        tests pytest du comportement attendu (TC-P01, TC-P11...)
  modules/      *.py + *.meta.json générés
  reports/      *.safety_report.json, *.validation_report.json
  chronicles/   rapports HTML de test + diagrammes UML/FSM + exports CSV/JSON de banc
```

Domaines actuels : `AU` (TC-P01), `TRANSLATION` (TC-P11), `COMMUN` (briques partagées sans TC
dédié : `FB_Brake`, `FB_Ramp`, `FB_CycleTime`...), `_OUTIL` (tests unitaires du générateur
lui-même, pas liés à une fonction machine), `_ARCHIVE` (artefacts neutralisés).
Mapping POU → domaine : `core/results_layout.py` (un seul endroit à mettre à jour).
Tout `RESULTS/` est gitignoré sauf les `tests/*.py` (versionnés comme du code).

## Ce que fait réellement l'outil aujourd'hui

- Extrait l'interface d'un POU (entrées/sorties) depuis le bundle PLCopen XML.
- Génère un module Python + un test pytest minimal à partir de cette interface.
- Pour les FB complexes (machines d'état, sécurité), la logique du `step()` est **écrite à la
  main** par un humain/LLM dans un renderer dédié de `fb_gen.py` — l'extraction d'interface est
  automatique, la traduction de logique complexe ne l'est pas encore.
- Bloque par défaut la génération d'un POU contenant un token sécurité (voir plus bas) — il faut
  `--allow-safety` explicitement.
- Ne régénère pas un POU si son hash n'a pas changé (`.st2py_cache.json`), sauf `--force`.

**Ce qui n'existe pas encore** (ni en code, ni en projet actif) : traduction ST→Python générique
(seule l'interface est auto-extraite, pas le corps), génération de PRG complet, assemblage de
scénario, CI automatisée. Ne pas s'y référer comme si c'était livré.

## Garde-fou sécurité

`safety_tokens.json` liste les motifs qui bloquent la génération automatique par défaut
(`EmergencyStop`, `PowerCutOff`, `SafeStop`, `StartStop`, `CoupeEnable`, `FB_Watchdog`).
Un POU qui matche un de ces tokens exige `--allow-safety` explicite pour être généré — la
génération reste alors possible mais le rapport de sécurité (`*.safety_report.json`) trace le
contournement. Objectif : ne jamais laisser croire qu'une fonction critique a été validée
automatiquement.

## Traçabilité

`TEST_REGISTRY.md` = registre unique fonction ↔ cas de test (TC) ↔ test Python ↔ statut.
`scripts/check_test_registry.py --report` vérifie mécaniquement la cohérence (test référencé =
test qui existe réellement, et inversement) — à lancer avant toute clôture de lot touchant
`RESULTS/<DOMAINE>/tests/`.

## Limites connues

- Pas une preuve FAT/SAT : la simulation Python aide à valider la logique, les validations
  matérielles restent obligatoires.
- Traduction 1:1 impossible pour appels matériels, blocs natifs, pointeurs — stubés, adaptation
  manuelle nécessaire.
- Un seul FB composite peut être généré sans ses sous-FB internes (ex. `FB_Safety_
  EmergencyManagement` généré seul, sans `Logic`/`Output`) si la logique a été réécrite à la main
  dans un seul module — le diagramme UML reflète alors ce qui a été généré, pas toute la
  composition réelle du domaine.

## Historique

- 2026-07-28 : premiers FB générés et testés (translation : `FB_Translation`,
  `FB_Safety_Translation`, `FB_Translation_PositionDecoder`).
- 2026-08 : pattern Cause/Ack (AU), gates `check_test_registry.py` + `check_cfc_wiring.py`,
  registre de traçabilité créé, réorganisation `core/scripts/RESULTS` puis fusion des tests
  dans `RESULTS/<DOMAINE>/tests/` (plus de dossier `suites/` séparé).

Ce README doit rester synchronisé avec le code. Mettre à jour à chaque changement de design
(algo de hash, tokens safety, comportement CLI, arborescence).
