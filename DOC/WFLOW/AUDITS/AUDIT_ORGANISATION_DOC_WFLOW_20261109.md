# Audit organisation DOC/WFLOW — 2026-11-09

## Verdict et périmètre

Le problème de navigation et de cohérence est démontré. Un renommage massif ou une suppression
de fichiers ne sont pas justifiés par cet audit. Conserver les regroupements utiles, corriger
d'abord les règles et les points d'entrée, puis décider les déplacements sur pièces.

Audit demandé par l'utilisateur : retrouver les tâches de rangement, vérifier leur couverture
par des agents, comparer prescriptions et usages, challenger utilité, nommage et simplicité.
Révision observée : `fd8b18100b4fc98439952b3b6533391d56258b89`, avec modifications préexistantes.
Aucun document existant, code, catalogue, verrou ou registre modifié ; seul ce rapport est ajouté.
Aucun déplacement, suppression, commit, push ou accès machine. Aucun `Device.export` lu.

## Méthode et contrôles

- Catalogue YAML courant parsé : **228 tâches**. Recherche indépendante d'un agent dans titres,
  descriptions, objectifs, contrats, registre et snapshot historique, utilisé seulement pour la généalogie.
- Inventaire physique : **703 fichiers**, **14 sous-dossiers**, environ **20,3 Mo**.
  `git ls-files DOC/WFLOW` : **692 chemins suivis**. Les deux populations ne sont pas assimilées.
- Volumes physiques principaux : CONTRACTS 191, AUDITS 158, ETUDES 140, TROUBLESHOOTING 55,
  REVIEWS 49, REGISTRES 22, ORCHESTRATION_RAPPORTS 19. Le volume seul ne prouve pas le désordre.
- Chemins de navigation contrôlés avec résolution depuis le fichier appelant et `Path.exists()`.
- Empreintes SHA-256 comparées pour les fichiers accessibles, hors locks : un groupe de trois
  classeurs strictement identiques retrouvé, pas de preuve générale d'inutilité.
- G300 exécuté, avec `git status --short` avant/après : **FAIL, 3 erreurs** pour
  `TOOLS/AGENT_WORKFLOW/.tmp`, `.tmp_pytest_t417_unicode` et `prototypes`.
  `.tmp/<run>/` est pourtant autorisé par la table canonique. Les deux autres chemins restent
  à qualifier. Ce verdict ne valide ni n'invalide l'intérieur de WFLOW, que G300 ne parcourt pas.
- Aucun nouveau changement observé après le contrôle. Avertissement Git préexistant d'accès
  refusé à `.tmp_pytest_t417_unicode`. Pas de gates PLC : aucun lot PLC.

## Tâches retrouvées et vérification anti-oubli

Les états ci-dessous sont ceux du catalogue, pas une certification d'achèvement.

| Tâche | État | Portée et décision proposée |
|---|---|---|
| T279 | ✅ | Hygiène sorties agents/CI et routage ; ne couvre pas l'architecture complète de WFLOW. Ne pas rouvrir pour englober tout le rangement. |
| T280 | ⬜ | Workspace CI troubleshooting ; son contrat dit COMPLETED / APPROVED. Réconcilier avant toute relance. |
| T281 / T282 / T283 / T285 | ✅ | Unification runners, état local et scratchs CI ; travaux voisins, pas refonte documentaire. |
| T378 | ⬜ | Marquage d'abandon de quatre artefacts T367 et requalification du registre ; garder distinct. Les quatre chemins existent actuellement. |
| T384 | ⬜ | Réconciliation catalogue/contrats dans les deux sens ; réutiliser ce périmètre, après actualisation des chiffres et hypothèses. |
| T379 | ⬜ | Gouvernance des verrous et cohérence de criticité ; sujet voisin mais distinct. La skill actuelle décrit déjà C0 mineure / C4 safety : ne pas répéter le constat ancien sans revalidation. |
| T426 | ⏳ | Fiche unique et simplification du suivi ; à articuler avec l'index, sans second Task Manager. |
| T427 | ⏳ | Organisation des skills et contrat enrichi ; ne couvre pas tout WFLOW. |
| T415-A / T415-G | ✅ / ⬜ | Assainissement et restructuration TwinBench : périmètre spécialisé, à ne pas étendre à toute la documentation. |

Sources : `TASKS.yaml:94,119,346,481,1228,1557,1587,6233,6285,8247` ;
`CONTRACTS/TASK_CONTRACT_T280_TROUBLESHOOTING_WORKSPACE.yaml:48-65`.

Précédents retrouvés : **T150-G**, décision de séparation gabarits projet/outillage, documentée
dans `TEMPLATE/README.md:3-16` et snapshot `ARCHIVES/TASKS_SNAPSHOT_20260915/TASKS_20260915_234600.yaml:1561-1575`.
T150, T150-E, T151 et T150-H complètent l'historique d'assainissement. Leur absence du catalogue
actuel ne prouve pas un oubli : le README du snapshot décrit explicitement un archivage de tâches.
Le registre porte aussi `ANALYSE-CLEAN-TASKS-YAML`, `TASKS_ORCHESTRATOR.yaml:1607-1632` ; son
livrable n'est pas désigné par un chemin durable.

Contrats déclarés mais absents actuellement, vérifiés directement par l'agent : T279, T281,
T282, T283, T285 et T415-A. C'est une absence dans ce checkout ; la cause n'est pas établie.
Le chiffre de **91 contrats orphelins** de T384 date du 22 septembre : il n'est pas reproduit.
Une extraction heuristique des IDs depuis les noms des **123 YAML TASK_CONTRACT actuels** ne
trouve aucun ID absent du catalogue. Ce contrôle ne remplace pas une jointure des identifiants
internes, des chemins déclarés et de l'historique : aucune conclusion de réconciliation achevée.

## Prescriptions contre réalité

| Constat vérifié | Source / conséquence |
|---|---|
| Règle de documentation à plat en décalage avec l'organisation reconnue | `STRUCTURE_AND_CLEANUP.md:7-20` contre `DOC/README.md` et `G300_check_structure.py:75-87`. Mettre à jour la règle, pas détruire les sous-dossiers pour s'y conformer. |
| Entrées de navigation absentes | `DOC/README.md:15,65,68,71,72` : REX_Nommage, PLAN_TASK.md, registres génériques et CHECKLISTS. Les registres datés existent ; aucune redirection ne les rend évidents. |
| README des audits périmé | `AUDITS/README.md:10,29,41,42,49` : anciens plans/registres/AF et chemin `../../ARCHIVES/Doc/AUDITS/`, résolu sous `DOC/ARCHIVES/Doc/AUDITS/` au lieu de l'archive racine. |
| Aucun point d'entrée propre à WFLOW | Absence de `DOC/WFLOW/README.md`. Les viewers et les catégories existent, mais leur usage n'est pas expliqué au même endroit. |
| Classements par type et par sujet mélangés | Notes d'application dans CONTRACTS et REX ; TEST_DESIGN dans CONTRACTS et TESTS ; revues dans REVIEWS, AUDITS/DESIGN et ETUDES/ANALYSES_T417. Aucune priorité explicite trouvée. Ce mélange n'est pas automatiquement une erreur. |
| Contrôle de structure incomplet pour ce besoin | G300 n'inspecte que les enfants immédiats de DOC, sans règles internes de destination pour WFLOW. |

Les fichiers de pilotage à la racine WFLOW ont des consommateurs logiciels : ne pas déplacer
viewers, TASKS.yaml, TASK_LOCKS.json, locks ou lanceurs par souci esthétique.

## Ce qui est utile et candidats à qualification

- `ETUDES/T428_J2_STRUCTURE/STRUCTURE_CIBLE.md:3-5` regroupe décisions, correspondance CSV et revue :
  conserver cette cohérence par sujet plutôt que disperser mécaniquement par extension/type.
- `REVIEWS/AGENT_CAPTURE_VALIDATION_20261102.json:3-20` conserve commande, sortie, empreintes et
  limites : preuve utile. JSON, logs et scripts dans les preuves ne sont pas des déchets par nature.
- La séparation `TEMPLATE/` projet et `TOOLS/AGENT_WORKFLOW/templates/` outillage est justifiée
  explicitement. Les fusionner recréerait une ambiguïté déjà traitée.
- `DIAGRAMS/` contient les GRAFCET métier, `DOC/DIA/` des PlantUML programme : frontière à écrire,
  pas doublon de dossiers démontré.
- Trois classeurs ELEC datés `20261006`, `20261007`, `20261008` ont les mêmes octets. Candidats à
  vérifier comme copies historiques ; ni suppression ni perte d'utilité prouvée.
- Six `.bak_*` physiques, non suivis Git : trois sous WFLOW/ARCHIVES, trois sous CONTRACTS.
  Vérifier propriétaire, raison de conservation et valeur historique avant décision humaine.
- L'existence de `WFLOW/ARCHIVES/` est documentée par le snapshot : ne pas l'assimiler sans analyse
  à une violation de l'archive racine. Écrire sa frontière avec `ARCHIVES/Doc/`.

## Revues et arbitrage du coordinateur

1. Agent indépendant « contre_recherche_taches » : 228 tâches examinées, précédents retrouvés,
   contradictions catalogue/contrats vérifiées ; pas de tâche actuelle couvrant explicitement toute
   l'architecture et l'utilisation de WFLOW.
2. Agent indépendant « audit_usage_dossiers » : confirme liens cassés, règles divergentes,
   catégories qui se chevauchent ; apporte les contre-exemples utiles T428 et preuve JSON.
3. **DeepSeek v4.1 via Ollama** (`deepseek-v4.1-flash:cloud`) : challenge sur dossier fourni,
   sans accès autonome aux fichiers. Réponse complète reçue au second appel. Confirme les priorités
   règles/index/statuts, refuse d'inférer le désordre du seul volume, recommande des lots ciblés
   plutôt qu'une grande tâche de rangement.
4. **GLM 5.3 via Ollama** (`glm-5.3-flash:cloud`) : premier appel vide ; second appel tronqué
   (`done_reason=length`), avec erreurs et raisonnement non finalisé. **Exclu du verdict.**
   Les premiers appels DeepSeek/GLM avaient chacun rendu une réponse vide ; ils ne sont pas comptés
   comme des revues. Les routes `:cloud` passent par Ollama mais ne sont pas des modèles locaux.

Arbitrages : ne pas reprendre l'idée DeepSeek d'une nouvelle tâche de réconciliation doublonnant
T384 ; ne pas transformer les règles documentaires en blocage général d'une investigation.
Ne pas exclure `.tmp*` en bloc : seul le scratch autorisé précis doit être admis ; les autres
chemins doivent rester visibles. Ne pas considérer toute absence au catalogue d'une tâche
archivée comme une perte démontrée. Ne pas conclure au caractère inutile des copies datées.

## Suite recommandée — proposition, non exécutée

1. **Lot ciblé navigation et règles DOC/WFLOW**, distinct des tâches existantes : une seule
   référence de structure à jour, point d'entrée WFLOW, réparation des liens d'entrée, destinations
   et priorité type/sujet, distinction actif/remplacé/abandonné/preuve historique.
2. **T384** : réconcilier sur mesures actuelles, incluant absences et contradiction T280.
   **T378** : traiter les documents T367 selon son contrat propre. Articuler T426/T427 ; ne pas
   fusionner automatiquement leurs responsabilités. T384 exclut expressément sa fusion avec
   T378/T379 (`TASKS.yaml:1258-1259`).
3. Inventaire de décision avant migration : chemin, rôle, tâche, état, consommateurs, destination,
   justification de conservation. L'absence de lien entrant ne suffit jamais à supprimer.
4. Déplacements éventuels par petits lots validés, table ancien → nouveau et contrôle des chemins
   consommés par liens, scripts, viewers et tests. Aucun renommage massif préalable.

Critères proposés pour le lot ciblé : zéro lien local absent dans les points d'entrée retenus ;
une règle de destination pour chaque catégorie avec exemples ; une tâche retrouvable sans
catalogue parallèle ; contrôles automatiques non destructifs couvrant les règles effectivement
décidées, avec cas d'erreur volontaires ; aucune régression de consommateurs lors des migrations.
La modification d'un gate suit son contrat et son point d'arrêt propres : non réalisée ici.

**Aucune tâche créée, fusionnée, clôturée ou réattribuée pendant cet audit.**
