# T428 — Refactor troubleshooting : plan détaillé

> Contrat structuré : `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.yaml`.
> Ce fichier sert de référence aux agents : lire les sections 1 à 3 avant toute action.

## 1. Objectif

Trouver la source d'un blocage **à partir du seul snapshot**, rapidement et intuitivement, pour un mainteneur comme pour un agent, même sans le programme.

**Non-objectifs :** changer la logique machine, réduire le nombre de variables à tout prix, reprendre le homing (T377).

## 2. Validé ou non

| Sujet | État |
|---|---|
| Lecture en flux : entrées, traitement, sorties | ✅ Validé par l'exploitant |
| Une variable figée n'est pas retirée pour ce seul motif | ✅ Validé |
| Changer les lettres ne suffit pas, des variables doivent se déplacer | ✅ Validé |
| Trois niveaux : général, axe, fonctions mixtes | ✅ Validé |
| Sorties PLC et mot variateur dans les axes | ✅ Validé |
| Guide de dépannage souhaité dans le code | ✅ Besoin validé, 🟠 faisabilité à tester |
| Fiche d'axe en 10 étapes | 🟠 Proposé |
| Safety générale dans C, alarmes dans chaque axe | 🟠 Proposé |
| Renumérotation des blocs | 🟠 Proposé |
| Rangement des codeurs, capteurs bruts et traités dans les axes | 🟠 Proposé |
| Champs `M2Demand` | 🔴 À trancher |

## 3. Règles pour tout agent

- Aucune écriture dans `CODE/` sans contrat de lot et GO humain. Aucun commit ni push sans accord.
- Producteur unique par donnée, vue en lecture seule, aucun redémarrage automatique.
- Vérifier toute affirmation à la source (`fichier:ligne`). Séparer faits, inférences, inconnues.
- `Device.export` n'est jamais une référence. `ARCHIVES/` n'est pas une source active.
- Une simulation n'est pas une preuve terrain. Ne pas poser de question terrain : marquer inconnu.
- Un seuil non atteint se publie, il ne se modifie pas après coup.

## 4. Tâches rattachées

| Lien | Tâches |
|---|---|
| Entières sous T428 | T313, T213, T380, T373 |
| Preuve sous T428 | T372 |
| Une part passe dans T428 | T375 (témoins de la liste), T377 (champs AC4), T231 (compilation du test de la vue) |
| Restent dans leur tâche, renvoi depuis T428 | T225, T224, T324, T219 |

## 5. Protocole de test à l'aveugle

**Référence du 2026-11-06 :** 5 incidents, 3 modèles, 15 diagnostics, **0 cause trouvée** avec ou sans ordre par flux, symptôme ou carte. Maillon bien situé selon les passes : 1 à 6 sur 15.

**Protocole figé :**

| Élément | Règle |
|---|---|
| Incidents | Mêmes 5 snapshots ; ajout possible, jamais de retrait |
| Modèles | `deepseek-v4.1-flash`, `glm-5.3-flash`, `gpt-oss:120b` |
| Entrée | Snapshot et symptôme, sans la fiche d'incident |
| Note | Même notateur, température 0, deux passes, modèles anonymisés |
| Résultat | Score retenu = la plus faible des deux passes |

Les anciens snapshots ne contiennent pas les nouvelles variables : pour les jalons J3 et suivants, reproduire les incidents en simulation quand c'est possible, et signaler ceux qui ne le sont pas.

## 6. Jalons

Chaque jalon s'arrête sur une validation humaine. Pas de jalon suivant sans GO.

### J0 — Cadrage

| | |
|---|---|
| **Livrables** | T428, contrat, ce plan, rattachements |
| **Tests** | `check_task_contract.py` PASS ; catalogue relu ; moins de 60 lignes modifiées par rattachement |
| **Revue** | Exploitant |
| **Évaluation** | Plan validé ou corrigé |

### J1 — Lot 1, valeurs trompeuses

| | |
|---|---|
| **Livrables** | Corrections du contrat `TS_LOT1_VALEURS_TROMPEUSES` |
| **Tests** | Relecture du diff, bundle complet, diff bundle, G200, palier C, liste de variables identique, simulation : geste habituel inchangé. Pas de nouveau test CI exigé pour un lot diagnostic |
| **Revue** | A/B en aveugle : 1 agent natif Claude, 1 DeepSeek ; le reviewer lit le diff réel |
| **Évaluation** | 100 % des AC du lot PASS ; 0 faux bloquant ; rejeu à l'aveugle publié, sans seuil à ce stade |
| **Arrêt** | GO implémentation, puis GO commit, puis chargement par l'exploitant |

### J2 — Structure cible

| | |
|---|---|
| **Livrables** | Fiche d'axe définitive, table de correspondance variable par variable, cas des variables partagées |
| **Agents** | 3 parsing DeepSeek (M1, M2, M3) ; 2 concepteurs A/B en aveugle : GLM mainteneur, DeepSeek automaticien ; 1 avocat de la panne `gpt-oss` ; 1 juge natif Claude |
| **Tests** | Script : 100 % des variables classées ; 0 doublon sans raison ; même ordre sur les 3 axes |
| **Revue** | Le juge vérifie à la source tout ce que les agents affirment |
| **Évaluation** | 100 % de couverture ; 0 retrait sans panne vérifiée ; rejeu papier publié |
| **Arrêt** | L'exploitant valide la structure et les retraits |

### J3 — Maillons manquants sans PLC

| | |
|---|---|
| **Livrables** | Liste enrichie : `WinchBothFinalRequestsCoherent`, `ManualBucketJogActive`, `SyncOperationPermit`, textes de cycle, bypass AU, etc. |
| **Tests** | Lecture réelle des chemins en simulation, 0 KO ; durée lecture et écriture relevée en console ; essai `BATCH_SIZE` |
| **Revue** | 1 DeepSeek sur la liste ; orchestrateur sur les chemins |
| **Évaluation** | 0 KO ; durée mesurée avant et après ; maillon bien situé **au moins 8 sur 15** en rejeu quand l'incident est reproductible |
| **Arrêt** | Résultat publié, décision de poursuivre ou non J4 |

### J4 — Implémentation de la structure

| | |
|---|---|
| **Livrables** | Contrat de lot, nouveaux types, vue, publication si nécessaire, table ancien vers nouveau chemin, suivi migration IHM |
| **Agents** | 1 exécutant ; 2 reviewers A/B en aveugle : 1 natif Claude, 1 GLM ou DeepSeek ; validation finale orchestrateur sur `git diff` |
| **Tests** | Comme J1, plus couverture AC2 ; contrôle des consommateurs IHM et traces |
| **Évaluation** | Tous les gates PASS ; 0 changement d'ordre machine ; 0 chemin orphelin |
| **Arrêt** | GO humain avant écriture et avant commit |

### J5 — Guide de dépannage dans le code

| | |
|---|---|
| **Livrables** | Objet de commentaire : sommaire, cas par axe, chemins, branches. Garde-fou vérifiant que chaque variable citée existe |
| **Agents** | 3 rédacteurs DeepSeek (M1, M2, M3) ; 2 challengers : mainteneur GLM, automaticien `gpt-oss` ; 1 juge natif Claude |
| **Tests** | Import PLCopenXML réel ; garde-fou 0 erreur et sa mutation détectée ; rejeu avec le guide |
| **Évaluation** | Cause trouvée **au moins 9 sur 15** et maillon **au moins 12 sur 15**, sur la plus faible des deux passes |
| **Arrêt** | Si seuil manqué : publier, analyser, pas de modification du seuil |

### J6 — Validation humaine et clôture

| | |
|---|---|
| **Livrables** | Recette, AF-14 à jour, REX, table de correspondance publiée |
| **Tests** | Au moins 3 pannes injectées en simulation, retrouvées par une personne avec le guide seul |
| **Évaluation** | 3 sur 3 ; durée notée ; retours du mainteneur intégrés |
| **Arrêt** | Clôture par l'exploitant uniquement |

## 7. Agents par usage

| Besoin | Agent | Raison |
|---|---|---|
| Parsing, tri, rédaction de masse | DeepSeek `v4.1-flash` | Rapide, termine ses livrables |
| Regard mainteneur | GLM `5.3-flash` | Autre modèle ; `think: false`, contrôler la troncature |
| Challenge indépendant | `gpt-oss:120b` | Troisième avis |
| Juge, relecture finale | Agent natif Claude, peu nombreux | Coûteux, réservé aux décisions |
| Exécution d'un lot `CODE/` | 1 seul exécutant | Un seul écrivain par fichier |

Sortie de modèle = non vérifiée tant que l'orchestrateur ne l'a pas contrôlée à la source.

## 8. Risques

| Risque | Parade |
|---|---|
| Snapshot plus lourd | Mesure à J3, décision sur chiffres |
| Chemins cassés pour IHM ou traces | Table de correspondance et contrôle à J4 |
| Guide faux ou périmé | Garde-fou J5 |
| Fuite des réponses dans le test | Fiches d'incident jamais fournies aux diagnostiqueurs |
| Moment de capture | Limite connue, à traiter à part ; lien T219 |
| Seuils 8, 9 et 12 sur 15 arbitraires | Proposés, à valider à J0 |
