# 🧭 T415-A — Inventaire TwinBench

> État : **rangement implémenté, revue en cours** · 2026-10-02
> Portée : inventaire, rangement des outils et parcours utilisateur. Aucun contenu supprimé ; PLC et simulation non modifiés.

## Organisation mise en place

Un lanceur maître sépare maintenant la préparation d'une copie Control Win de la simulation
OpenModelica locale. Les prototypes de communication PLC restent en retrait et étiquetés.

| Usage humain | Point d'entrée à conserver | État réel | Décision proposée |
|---|---|---|---|
| Copier / ouvrir une application PLC isolée | `01_PROJECT/controlwin_runner/Start_ControlWin.cmd` | ✅ Recette humaine T404 documentée | **Runner Control Win** |
| Ouvrir le modèle M3 dans OMEdit | `02_SIM/modelica/Open_M3_Model.cmd` | 🟡 POC autonome, sans PLC | **Conserver : apprentissage/modèle** |
| Faire varier la plante FMU locale | `02_SIM/modelica/Start_M3_Live.cmd` | 🟡 POC local ; fidélité non qualifiée | **Conserver : développement physique** |
| Chaîne FMU ↔ copie Control Win | `90_PROTOTYPES/m3_link/Start_T409_M3_Integration.ps1` | 🔴 Instable/non qualifiée ; conflit de port déjà rencontré | **Prototype, hors parcours maître** |

## Carte des briques existantes

| ID / dossier | Responsabilité réelle | Preuve disponible | Classement proposé |
|---|---|---|---|
| T400 · fiche M3 | Faits, hypothèses, inconnues de modélisation | Fiche documentée | **Référence à conserver** |
| T401 · `02_SIM/modelica/M3_POC.mo` | POC OpenModelica autonome, capteurs et butées hypothétiques | README + validation `omc` déclarée | **Conserver, non fidèle terrain** |
| T402 · ScriptEngine | Probe / impulsion dans l'IDE CODESYS | Recette manuelle ancienne | **Historique, hors boucle cyclique** |
| T403 · aiguillage SimBench | Sélecteur image M3 interne / OM | Code et contrat existants | **Référence d'architecture à auditer sous T415-B** |
| T404 · `controlwin_runner/` | Copie isolée et déploiement local Control Win | Recette humaine documentée | **Socle à conserver** |
| T405 · `live_poc/` | FMU locale + interface QML | Tests locaux déclarés | **Conserver comme banc physique isolé** |
| T406 · contrat liaison | Images, cadence, validité, reprise | Contrat existant | **Entrée de T415-B : consolider, ne pas dupliquer** |
| T407 · UDP ScriptEngine | Connectivité loopback lente | Mesure ~217 ms/échange | **Archiver plus tard comme preuve d'exclusion performance** |
| T408 · UDP natif | Benchmark 10/50 ms, sans M3 | Mesures humaines rapportées | **Conserver comme banc de transport** |
| T409 · `90_PROTOTYPES/m3_link/` | POC FMU + pont SimBench Control Win | Tests locaux et incidents humains contradictoires | **Geler : audit/requalification obligatoire** |
| T414 · shadow CPU réel | Visualisation lecture seule future | Non démarré | **Hors urgence ; conserver séparé de la simulation** |

## Lanceurs : problème et règle cible

### Problème constaté

- Avant rangement, la racine `TOOLS/TWINBENCH/` exposait quatre lanceurs et outils sans séparation
  par usage (`Lancer_POC_M3`, `Lancer_POC_M3_Live`, `Lancer_M3_Live_PLC_Lecture`,
  `Start_M3_PLC_Demo`).
- T409 ajoute son propre lanceur d'intégration, son gateway et ses scripts de test.
- T407/T408 ajoutent encore leurs propres lanceurs. Aucun catalogue utilisateur ne dit clairement
  lequel est un test, une démo, ou une intégration PLC qualifiée.

### Règle appliquée

1. **Un seul point d'entrée par usage**, documenté dans un guide court.
2. Un lanceur utilisateur ne peut annoncer « Control Win » ou « PLC » que s'il indique : copie
   isolée, prérequis, données lues/écrites et état de qualification.
3. Les scripts `test_*`, `check_*`, `Start_T407_*`, `Start_T408_*`, gateway et démos restent
   internes à leur dossier ; jamais recommandés comme première action utilisateur.
4. Aucun prototype n'est supprimé ; tout archivage futur reste soumis à décision humaine.

## Arborescence implémentée

```text
TOOLS/TWINBENCH/
├─ 00_START.cmd
├─ 10_PROJECT.cmd
├─ 20_SIM.cmd
├─ 01_PROJECT/controlwin_runner/
├─ 02_SIM/modelica/
├─ 03_TRANSPORT/udp_native/
└─ 90_PROTOTYPES/m3_link + m3_telemetry/
```

`00_START.cmd` est le menu maître. `10_PROJECT.cmd` appelle le runner Control Win existant.
`20_SIM.cmd` propose le modèle OMEdit ou la FMU locale. Les tests et sous-scripts restent dans le
dossier de leur brique. Le mode PLC lecture seule et le prototype T409 ne sont pas proposés dans
le parcours courant.

## Risques qui bloquent une présentation « simulation fiable »

| Risque | Fait observé | Traitement prévu |
|---|---|---|
| Démarrage ambigu | Plusieurs lanceurs et modes PLC | Décision de parcours avant refactor |
| T409 non stabilisé | Port occupé et comportement capteurs/position contesté | Audit de frontière et recette sous T415-B/D/E |
| Fidélité physique | Réducteur, frein, rampes et positions mécaniques incomplètement mesurés | Hypothèses marquées ; qualification terrain dans T415-E |
| CPU réel | Control Win n'est pas le CPU réel | T415-F lecture seule, aucun stimulus simulé |

## Recette finale

- **PASS** : `00_START.cmd` affiche les deux parcours, le retour du sous-menu simulation revient
  au menu maître, et les cibles de tous les lanceurs existent.
- **PASS** : le runner Control Win est contrôlé via son vrai point d'entrée, sans déploiement,
  par son auto-test `55/55`.
- **PASS** : FMU headless au départ P1 `20,000 m` avec mot capteurs `00011`; mouvement, arrêt,
  retour, auto-cycle local et priorité joystick sont vérifiés.
- **À faire par l'utilisateur** : ouvrir les menus dans une console interactive et confirmer
  l'ergonomie. Aucun lancement automatique de CODESYS, aucun déploiement et aucune écriture PLC
  n'ont été effectués pour cette recette.
- T407 est conservé comme preuve historique de latence ; son archivage peut être décidé plus tard.
- T409 reste gelé comme prototype, sans suppression ni déplacement hors `90_PROTOTYPES/`.

## Auto-vérification et revue externe

- **Revue CDX02 : MINOR** — les 58 fichiers suivis déplacés ont chacun une destination ; aucun
  fichier manquant. Les lanceurs parent/enfant sont cohérents à la lecture. Aucun fichier n'a été
  modifié par le reviewer.
- **PASS** : runner Control Win `55/55`, T405 live FMU, T407 garde-fou, T408 garde-fou, tests
  protocole/scénarios/reprise T409, contrat de tâche, parsing PowerShell et `git diff --check`.
- **Correction de cohérence T401** : `configuration.initialPosition_M`, déjà présente dans le
  modèle de base, est maintenant déclarée dans le catalogue. Le garde-fou T401 passe avec
  33 signaux catalogués.
- **Limite du verdict** : l'intégration Control Win et les menus `.cmd` restent à confirmer par
  lancement humain sur le poste ; les vérifications automatiques ne prouvent pas cette recette.

## Gates globales

`run_all_gates.py` a confirmé **G200 liaison : PASS**. La suite globale reste rouge pour des
dettes hors TwinBench déjà présentes : répertoires `TOOLS/AGENT_WORKFLOW` non attendus, liens
documentaires périmés (146 erreurs), et références de documentation de code hors lot. Son
exécution a régénéré `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/reports/WINCH_INTEG.html` et
`TOOLS/TEST_AUTO_CI/index.html` ; ces artefacts ne sont pas supprimés automatiquement.

## Preuves de l'inventaire

- `DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md` : `FB_SimBench` est la frontière unique ;
  la simulation produit une image matériel plausible, sans bypass de sécurité.
- `TOOLS/TWINBENCH/01_PROJECT/controlwin_runner/README.md` : T404 isole une copie et cible uniquement
  `CODESYS Control Win V3 x64` local.
- `TOOLS/TWINBENCH/02_SIM/modelica/README.md` et `live_poc/README.md` : T401/T405 sont hors PLC.
- `TOOLS/TWINBENCH/03_TRANSPORT/udp_native/README.md` : T408 est un benchmark de transport sans M3.
- `TOOLS/TWINBENCH/90_PROTOTYPES/m3_link/README_T409.md` : T409 est une intégration expérimentale,
  non une preuve de fidélité globale.
