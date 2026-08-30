# 🧊 Jumeau numérique — Étude de conception

> **Branche** : `WT4_TEST_AUTO_CI_TWIN` · **Périmètre** : `TOOLS/TEST_AUTO_CI/` uniquement.
> **Aucune modification de `CODE/` ni `DOC/AF/`** (agents concurrents sur `main`).
> Source de vérité = `WORKING_COPY/` (jamais `CODE/`).

## Objectif

Généraliser le banc interactif `anim_bench/` en un **jumeau numérique HTML** : une interface
« jolie » qui représente la machine, **sans savoir d'où viennent les données** qui l'animent
(binaire compilé, trace JSON, harnais CI, Grafcet). Le jumeau est un **pur rendu** : on lui envoie
des **frames** standardisées, il pilote la **cinématique** des actionneurs. Il est
**bidirectionnel** : joystick et boutons de la page **injectent** des bits vers la source
(remplaçant les stubs/mocks de joystick des tests CI).

## Documents

| Document | Contenu |
|---|---|
| [ETUDE_CONCEPTION_JUMEAU_NUMERIQUE.md](ETUDE_CONCEPTION_JUMEAU_NUMERIQUE.md) | Étude de conception principale (architecture, objet, provenance, cinématique, phases) |
| [SPEC_INTERFACE_FRAME.md](SPEC_INTERFACE_FRAME.md) | Schéma Frame (JSON) + protocoles `FrameAdapter`/`ControlSink` + transport |
| [SPEC_ADAPTATEURS_SOURCES.md](SPEC_ADAPTATEURS_SOURCES.md) | Adaptateurs binaire / trace / harnais CI |
| [CHALLENGE_EXPERT.md](CHALLENGE_EXPERT.md) | Challenge de la solution par un expert indépendant |

## Existant réutilisé

- `anim_bench/` — banc interactif (moteur, serveur, trace, garde-fou)
- `engine/cycle_engine.exe` — binaire compilé depuis `WORKING_COPY/FB_Cycle.st`
- `engine/cycle_bench.html` — page interactive actuelle
- `RESULTS/G_CYCLE/reports/trace_semi_auto_cycle.json` — trace scan-par-scan

## Statut

- [x] Étude de conception (v1.0)
- [x] Spec Frame + protocoles
- [x] Spec adaptateurs
- [x] Challenge expert (verdict : **Avec réserves**)
- [x] Intégration des retours du challenge (durcissement P0/P1 intégré)
