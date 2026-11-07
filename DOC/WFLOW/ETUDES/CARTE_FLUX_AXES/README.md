# Carte de flux des axes M1, M2, M3

**But :** savoir, pour chaque axe, quelles commandes, réglages et mesures agissent sur les actionneurs, par quels maillons, et lesquels se voient au snapshot.

**État :** étude du 2026-11-06, base `work/base-machine-simu` (`597a9571`). Aucune preuve sur automate. Aucune modification de `CODE/`.

## Fichiers

| Fichier | Contenu |
|---|---|
| `CARTE_M1.md`, `CARTE_M2.md`, `CARTE_M3.md`, `CARTE_AU.md` | Référentiel, maillons par étage, arbre par commande |
| `CARTE_M1.csv`, `CARTE_M2.csv`, `CARTE_M3.csv`, `CARTE_AU.csv` | Mêmes maillons, pour un agent ou un filtre |
| `donnees/` | Graphes bruts `cone_*.csv`, `edges_*.json`, commandes, inventaire snapshot |
| `generation/` | Scripts de génération. Les chemins sont ceux de la session d'origine : à adapter avant de relancer |

## Comment lire

1. Prendre le symptôme et la commande dans la section 3 de `CARTE_Mx.md`.
2. Suivre l'arbre de haut en bas, de la source à la sortie.
3. Au dernier maillon vrai, lire la colonne `Si dernier vrai` en section 2.
4. Le chemin affiché est le plus court. Les branches parallèles sont dans `donnees/edges_*.json`.

| Statut | Sens |
|---|---|
| `VISIBLE` | Dans le snapshot, ou copie directe d'une variable du snapshot |
| `LISIBLE?` | Variable existante, lecture directe à confirmer sur automate |
| `A CONTROLER` | Section de déclaration non déterminée par le parseur |

## Méthode

| Étape | Nature |
|---|---|
| Graphe : remontée depuis chaque sortie physique, affectations, conditions `IF`/`CASE`, entrées de FB, FB standards | Extraction mécanique |
| Frontières par axe : autre axe, cycles, modes, simulation | Choix de lecture |
| `fichier:ligne`, code cité, étage principal | Extraction et règles |
| Colonnes `Condition` et `Si dernier vrai` | Rédaction par modèle, à relire |

## Couverture mesurée

| Axe | Variables du graphe | Maillons annotés | Visibles | Points d'entrée reliés |
|---|---:|---:|---:|---:|
| M1 | 1 171 | 821 | 178 | 166 / 166 |
| M2 | 1 362 | 968 | 201 | 179 / 179 |
| M3 | 475 | 351 | 86 | 66 / 66 |
| AU et puissance | 122 | 82 | 32 | 24 / 24 |

- Aucun maillon de chemin n'est sans annotation.
- Dernière relecture par modèle, nouvel échantillon de 167 annotations sur les 4 cartes : 153 correctes, 12 trop vagues, 2 fausses. Les 2 fausses, vérifiées dans le code, sont corrigées, ainsi que leur famille de sorties M1 et M2. Cette relecture n'est pas une validation humaine.
- 469 maillons sont des frontières ou liaisons étiquetées par règle : leur texte renvoie à l'axe concerné.
- `Si dernier vrai` des frontières et des liaisons : renvoi mécanique vers les maillons aval du graphe.
- La carte AU part de `PowerKeepAlive_A_RQ`, `PowerKeepAlive_B_RQ` et `EmergencyArming_RQ`, avec les axes en frontière. Elle contient les bypass `GVL_BypassRetain.BypassAu*`, absents du snapshot. La relecture d'échantillon ne couvre pas cette carte.

## Commandes IHM sans chemin vers une sortie (18 sur 73)

Graphe sans frontière, sur 21 sorties physiques.

| Commandes | Constat dans le code |
|---|---|
| `MaintenanceN2.Cmd.BtnM1Ascent/Descend`, `BtnM2Ascent/Descend`, `BtnBothAscent/Descend`, `BtnM3Tremie/Maintenance`, `BtnM3BrakeRelease` | Lues seulement par `ActiveForcing` (`PRG_07_Supervision.st:770-781`). Les six boutons moteur sont déjà signalés au catalogue (`TASKS.yaml:1637`) |
| `M3Translation.Cmd.SelTarget` | Le cycle la déclare « Cable, non consomme » (`FB_CycleSemiAuto.st:32`) |
| `BtnLearnSpeed` M1 et M2 | Apprentissage, sans lien attendu avec une sortie |
| `CycleSemiAuto.Cmd.BtnResetSampleCount` | Compteur, sans lien attendu avec une sortie |
| `CycleSemiAuto.Cmd.BtnPause`, `TglCommissioning`, `TglCycleChecksInhibit`, `M3Translation.Cmd.SelPositioning`, `Modes.Cmd.BtnModeReset` | À vérifier : limite du graphe ou commande sans effet |

## Essais sur 5 incidents documentés

Mêmes 5 snapshots, 3 modèles, soit 15 diagnostics par essai. Note de la cause racine par rapport à la fiche, deux passes du même notateur. Aucun mainteneur réel. Plusieurs incidents viennent de la simulation.

| Essai | Cause trouvée | Maillon bien situé (passes 1 et 2) |
|---|---:|---:|
| Ordre actuel, sans symptôme | 0 / 15 | 6 et 2 |
| Ordre par flux, sans symptôme | 0 / 15 | 3 et 3 |
| Ordre par flux, avec symptôme | 0 / 15 | 4 et 3 |
| Ordre par flux, symptôme et carte | 0 / 15 | 4 et 1 |

Lecture : ni l'ordre seul ni la carte seule ne suffisent. L'écart sur le maillon reste dans le bruit de notation.

Deux cas relus :

- **AX12** : le diagnostic s'arrête sur `N_MotionM1.Step2_ModeAuthorized=FALSE`, valeur trompeuse hors MAINT. Le maillon utile `WinchBothFinalRequestsCoherent` est dans la carte, pas dans le snapshot.
- **WINCHSEL** : `ManualBucketJogActive` reste une hypothèse secondaire, car sa valeur n'est pas dans le snapshot. L'incident demande aussi de comparer deux snapshots.

Priorité déduite, à confirmer : corriger les valeurs trompeuses, puis ajouter les maillons manquants, avant de refaire cet essai.

## Limites

- Les maillons sont statiques : la carte dit quoi peut agir, pas ce qui a agi.
- Une entrée de FB partagée par plusieurs appels suit le premier appel trouvé.
- Quand une variable est écrite plusieurs fois, le code cite au plus deux affectations. La dernière exécutée dans le cycle fait foi, même si le texte de `Condition` dit « ou ».
- Une condition peut être fausse sur un cas non échantillonné : vérifier la ligne citée avant toute décision.
- `LISIBLE?` n'a pas été testé sur automate.
- Le découpage par mode de marche se lit dans les conditions, il n'est pas encore une racine par mode.
