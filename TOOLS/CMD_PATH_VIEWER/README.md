# 🔗 CMD_PATH_VIEWER — T353

> **Choisir une chaîne de commande (ou un geste curé) et voir le chemin exact parcouru dans le
> code — variable par variable, dans l'ordre, avec producteur et consommateur en `fichier:ligne` —
> en sachant à chaque instant si ces numéros de ligne sont encore valides.**
>
> Lot T353 (C2, stratégie *patch*), parent T351. **Aucun code PLC produit** : l'outil est un outil
> de **LECTURE**. `CODE/` et les 3 documents source sont en **lecture seule absolue**.

---

## 1. Pourquoi cet outil existe

Les cartographies de diagnostic T351/T334 (3 documents, ~2 200 lignes) s'ancrent par **blob SHA
git**, jamais par `HEAD` ni par numéro de ligne : pendant leur propre rédaction, 2 des 27 fichiers
cités ont changé de blob, invalidant silencieusement des centaines de références. Relire ces
documents à la main à chaque diagnostic est long **et** risqué.

`CMD_PATH_VIEWER` restitue le chemin, **et** dit à quel point on peut lui faire confiance :
chaque référence affichée porte l'état de fraîcheur du fichier qu'elle cite.

---

## 2. Structure

```text
TOOLS/CMD_PATH_VIEWER/
├─ README.md                     ← ce fichier (structure, 2 modes, LIMITES)
├─ index.html · app.js · style.css   ← front statique, vanilla JS, ZÉRO CDN, ZÉRO requête distante
├─ git-blob-sha1.js              ← calcul du blob git (navigateur + Node, même fichier)
├─ parse_cartographies.py        ← 3 documents → data/graph.json (+ data/graph.js)
├─ verify_anchors.py             ← blobs mesurés vs consignés → data/freshness.json (+ .js)
├─ smoke_test_ui.js              ← test de fumée du rendu (DOM simulé, sans navigateur) — 37/37
├─ check_lot_files.py            ← garde-fou de propreté (BOM, CRLF, URL distantes, livrables)
├─ OPEN_CMD_PATH_VIEWER.bat      ← MODE LIVE (serveur de FICHIERS statique)
├─ data/
│  ├─ graph.json · graph.js      ← format pivot (maillons, ancrage, gestes, limites, rapports)
│  ├─ freshness.json · freshness.js  ← constat figé et horodaté du garde-fou blob
│  ├─ selftest.json              ← cible du volet B de la preuve P3
│  ├─ preuve_garde_fou_T353.json ← journal du test volontaire du garde-fou (P3)
│  └─ .sortie_parseur.txt · .sortie_freshness.txt · .sortie_p3.txt · .sortie_p4.txt
│                                ← ⚠️ **CAPTURES BRUTES DES PREUVES** (sorties console verbatim collées
│                                  dans l'annexe A1→A9 de `PREUVE_T353.md`) — ce ne sont PAS des
│                                  scratchs : ce sont les pièces justificatives, conservées telles
│                                  quelles (règle « aucune suppression automatique »).
```

---

## 3. Les deux modes d'usage

| Mode | Lancement | Fraîcheur | Requête réseau |
|---|---|---|---|
| **STATIQUE** | double-clic sur `index.html` (`file://`) | **FIGÉE** et horodatée (bandeau orange explicite) | **aucune** — les données sont embarquées dans `data/graph.js` et `data/freshness.js` |
| **LIVE** | `OPEN_CMD_PATH_VIEWER.bat` → `http://127.0.0.1:8765/TOOLS/CMD_PATH_VIEWER/index.html` | **RECALCULÉE dans le navigateur** pour chaque fichier cité | lecture des fichiers cités du dépôt (serveur de fichiers statique, `python -m http.server`) |

### Pourquoi deux modes

Un navigateur ouvert en `file://` **ne peut pas** lire les fichiers du dépôt (politique CORS) :
les badges y sont donc **figés**. Afficher un vert « recalculé » dans ce cas serait un mensonge —
le bandeau le dit explicitement, et l'horodatage de la mesure est affiché.

En mode LIVE, `python -m http.server` ne sert que des **octets** : **aucune logique métier côté
serveur**, aucune écriture possible (le protocole utilisé n'expose aucune écriture).

### Régénérer les données (après un changement de `CODE/`)

```powershell
python TOOLS/CMD_PATH_VIEWER/parse_cartographies.py     # relit les 3 documents → data/graph.*
python TOOLS/CMD_PATH_VIEWER/verify_anchors.py          # re-mesure les blobs → data/freshness.*
node TOOLS/CMD_PATH_VIEWER/smoke_test_ui.js             # rendu du front (DOM simulé) — 37/37
python TOOLS/CMD_PATH_VIEWER/check_lot_files.py         # propreté du lot : BOM, CRLF, URL distantes, livrables
```

> 🛡️ **`check_lot_files.py` — garde-fou de propreté (classe de bug du REX `2026-08-19`)** : pendant ce
> lot, un **BOM UTF-8** a été introduit par accident sur `smoke_test_ui.js`, rendant le script
> **inexécutable** (`SyntaxError` sur le shebang) — exactement le mode de défaillance décrit dans
> l'en-tête de `.gitattributes`. Le fichier a été réécrit sans BOM **et** ce garde-fou a été livré :
> il **échoue (code 1)** sur un BOM, une fin de ligne CRLF dans une source ou un JSON généré, une
> ressource distante, un shebang invalide ou un livrable manquant. *Place canonique souhaitable :
> `TOOLS/AGENT_WORKFLOW/scripts/` (hors périmètre d'écriture de ce lot — proposé à l'orchestrateur).*

---

## 4. Format pivot (`data/graph.json`)

```jsonc
{
  "meta":       { "genere_le": "...", "head_mesure": "...", "hash_exact": "SHA1(\"blob \" + taille + \"\\0\" + contenu)" },
  "documents":  [ { "id": "treuils|t334|annexe", "chaines": [...], "ancrage": {...} } ],
  "chaines":    [ { "id": "treuils/M", "mode": "MAINT_N1/N2 (branche ELSE)", "codes": [...],
                    "non_empruntee": { "chaine_id": "treuils/C", "motif": "...", "source": {...} } } ],
  "maillons":   [ { "document": "t334", "chaine": "M", "code": "M07", "ordre": 7,
                    "variable": "...", "producteur": "...", "consommateur": "...", "role": "...",
                    "refs": [ { "brut": "...", "forme": "CHEMIN_COMPLET|ABREGE|CONTINUATION",
                                "categorie": "RESOLUE|AMBIGUE|NON_RESOLUE", "chemin_resolu": "...",
                                "lignes": [...], "regle": "...", "propagation": true } ],
                    "refs_manquantes": [], "marqueurs": ["⚠️ASYM"] } ],
  "complements": [ { "code": "M67", "statut": "COMPLEMENT_NON_FUSIONNE", "nature": "AJOUT|CORRECTION" } ],
  "ancrage":    { "blobs": [ { "chemin": "...", "blob_consigne": "...", "sources": [...],
                               "ancrage_derive": true } ] },
  "gestes":     [ { "id": "G01_MANU_TREUILS", "statut": "CURE_SOURCE|NON_SEPARABLE",
                    "source": { "document": "treuils", "ligne": 160 }, "citation_verifiee": true } ],
  "limites":    [ { "id": "L1", "gravite": "BLOQUANT", "titre": "...", "detail": "...", "source": "..." } ],
  "rapport_parsing": {...}, "rapport_resolution": {...}, "index_resolution": {...}
}
```

**Règle de structure non négociable** : un code `Mnn`/`Cnn` **n'a de sens qu'avec son document**.
L'annexe réutilise `C02`/`C03` pour des objets de `PRG_03` alors que T334 définit `C02` comme
l'instance `instCycleSemiAuto` appelée `PRG_03:190`. Le format pivot porte donc `document` sur
**chaque** maillon, et l'outil ne compare jamais deux codes de documents différents.

---

## 5. Ce que le parseur accepte — et ce qu'il refuse

### Tableaux de chaîne (5 colonnes)

Seuls les tableaux dont l'en-tête est
`| # | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle |` alimentent le graphe.
Tout autre tableau est classé (`DIVERGENCES`, `ASYMETRIES`, `ANCRAGE_BLOBS`, `AUDIT_4COL`, `AUTRE`)
et **n'injecte aucun maillon**.

### Tableaux d'AUDIT et de CORRECTION — rejetés explicitement

Les tableaux à 4 colonnes de l'annexe (`Réf. T334 | Ligne citée par T334 | Contenu réel sur
disque | Verdict`) sont des lignes de **contre-vérification**, pas des chaînes ; le tableau §4.10 à
3 colonnes (`Code | Référence dans T334 | Valeur correcte`) est une table de **correction**. Leur
**120 lignes** sont **détectées et rejetées** avec un motif nommé
(`TABLE_AUDIT_4_COLONNES_NON_INJECTEE` = 97, `TABLE_CORRECTION_3_COLONNES_NON_INJECTEE` = 23) : les
injecter produirait 120 faux maillons.

Un **passage exhaustif** garantit qu'aucune ligne portant un code `Mnn`/`Cnn` n'échappe au rapport, et
**deux grandeurs sont publiées, explicitement étiquetées** (jamais un nombre nu) :

| Grandeur | Valeur | Règle |
|---|---|---|
| **Lignes candidates** `Mnn`/`Cnn` | **319** = 101 + 101 + 117 | **1 candidat par ligne** — une ligne à codes combinés (`M07 / M08`) compte **1** |
| **Occurrences de codes** | **339** = 101 + 101 + 137 | tous les codes de la 1ʳᵉ cellule, **règle uniforme** : l'espacement autour du `/` n'a **aucun** effet |

Les **11 lignes** dont la première cellule est une **référence de section** (`§6.1`, `H6`, `A03`…)
**ne portent aucun code** : elles sont comptées **à part** (`lignes_non_candidates_hors_audit`) et
n'entrent dans aucun dénominateur.

L'annexe sert donc à trois choses, **jamais fusionnées dans les chaînes** : source d'**ancrage blob**
(§1.3, étiqueté DÉRIVÉ), **compléments non fusionnés** (§4.2–§4.6 : 7 ajouts + 1 correction), et
**table de correction des références périmées** (§4.10 → `corrections_references_perimees`, affichée
dans l'UI avec l'avertissement que son ancrage `d6e54377` est **périmé**).

### Références : 4 formes traitées, aucune devinée

| Forme | Exemple | Traitement |
|---|---|---|
| **CHEMIN_COMPLET** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1405` | utilisé verbatim s'il existe dans l'index |
| **EXTENSION** (nom de fichier nu) | `PRG_02_Acquisition.st:492`, `Device_IO_20260918.csv:521` | résolu par basename **unique** dans l'index |
| **ABREVIATION** (préfixe de POU, **sans** extension) | `PRG_04:1309`, `FB_Winch:226`, `M1:56` | **préfixe unique** → résolu ; **préfixe ambigu** → AMBIGU ; **alias** → table curée ; sinon NON RÉSOLU |
| **CONTINUATION** | `` `:492` `` après un fichier nommé | hérite du **dernier fichier nommé avant elle dans la même cellule** |

Le modificateur `liste` s'applique aux quatre (`FB_AxisScale.st:29,36,43,49` → 4 numéros conservés).

**Les 4 traitements distincts de l'abréviation (jamais confondus) :**

| Cas | Exemple mesuré | Traitement | Trace JSON |
|---|---|---|---|
| préfixe **unique** | `PRG_04` → `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (un seul fichier `CODE/**` dont le nom commence par `<préfixe>.` ou `<préfixe>_`) | résolu | `resolved_by: "prefix_unique"` |
| préfixe **ambigu** | `FB_Winch` → `FB_Winch.st` **et** `FB_Winch_Symmetry.st` ; `FB_Translation` → 3 candidats | **AMBIGU** — jamais tranché silencieusement | `resolved_by: "prefix_ambigu"` + candidats listés |
| **alias contextuel** | `M1` / `M2` = `FB_WinchCmdArbitrationM1` / `M2` | **table CURÉE à 2 entrées**, chacune avec provenance citée **et vérifiée** ; toute autre forme d'alias reste NON RÉSOLUE — **aucune règle générique `M<chiffre>` n'est devinée** | `resolved_by: "alias_documente_cure"` + `alias_source` |
| **troncature de prose** | `M2.st:85` (fiche treuils, ligne 595) | **NON RÉSOLUE**, texte brut conservé — c'est un **défaut de rédaction**, pas un fichier manquant | `resolved_by: "troncature_prose"` |

`Device_IO_20260918.csv` (forme courte, très fréquente) se résout par le **chemin déclaré** dans les
blocs d'ancrage : `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv`. Ce n'est **pas** un introuvable.

### Index de résolution — scopé, jamais « premier match trouvé »

Un index naïf sur tout le dépôt rendrait **~90 % des références ambiguës** : `CODE_BACKUP/**`
contient 6 copies archivées de chaque POU. L'index est donc **scopé sur la source active** :

1. `A_CHEMIN_EXACT` — chemin complet fourni, présent dans l'index ;
2. `B_CHEMIN_DECLARE_ANC` — chemin **déclaré par un bloc d'ancrage** des documents ;
3. `C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE` — nom unique dans `CODE/**` ;
4. `C_BASENAME_UNIQUE_ANCRAGE_DECLARE` — nom unique parmi les chemins déclarés (ex. `Device_IO_20260918.csv`) ;
5. `C_BASENAME_UNIQUE_DOC_ACTIF` — nom unique dans `DOC/**` (références documentaires) ;
6. `D_STEM_UNIQUE_*` — **abréviation** (`PRG_02` → `PRG_02_Acquisition.st`) ;
7. `E_ALIAS_DOCUMENTE_CITE` — alias de contexte **prouvé par le document** (voir ci-dessous) ;
8. `E_CONTINUATION_HORS_BORNES_REROUTAGE` — **reroutage vérifiable** : l'héritage sortait du fichier et
   **un seul** candidat (même **cellule**, puis même **ligne de tableau**) contient la plage ; sinon la
   référence devient `CONTESTEE_HORS_BORNES`, jamais « résolue » ;
9. `C_BASENAME_UNIQUE_PRESENT_NON_SUIVI` — fichier **présent mais non suivi par Git** (les 3 documents
   source eux-mêmes, les livraisons d'autres lots) : résolu, mais dans un tier **tracé** ;
10. sinon **`AMBIGUE` ou `NON_RESOLUE` — jamais deviné**.

**Trois états de non-résolution, distingués exprès** (un diagnostic n'a pas la même valeur selon le cas) :

| État | Signification |
|---|---|
| `NON_RESOLUE` | l'index ne permet pas de conclure (cellule sans nom de fichier, alias non documenté, troncature de prose) |
| `CONTESTEE_HORS_BORNES` | le couple `(fichier, ligne)` est **impossible** : la ligne n'existe pas dans le fichier désigné — **trouvaille de diagnostic**, jamais affichée comme résolue |
| `AMBIGUE` | plusieurs candidats réels : jamais tranché silencieusement |

**Quatre tiers, ordre de priorité décroissant** (le plus prioritaire gagne, la trace est écrite) :

| Tier | Fichiers | Contenu |
|---|---|---|
| `SOURCE_ACTIVE_CODE` | 262 | `CODE/**` hors `CODE_BACKUP/**` |
| `ANCRAGE_DECLARE` | 1 | chemins déclarés par les blocs d'ancrage (`Device_IO_20260918.csv`) |
| `DOC_ACTIF` | 535 | `DOC/**` hors `ARCHIVES/**` |
| `PRESENT_NON_SUIVI` | 99 | `git ls-files --others --exclude-standard` (tier de plus basse priorité) |

**Exclus de l'index** : `CODE_BACKUP/**`, `ARCHIVES/**`, `TOOLS/TEST_AUTO_CI/**`
(une archive n'est jamais une source active — `AGENTS.md`).

### Les deux garde-fous de la propagation

Hériter mécaniquement du « dernier fichier nommé » peut produire un chemin **faux affiché avec
assurance**. Deux refus mécaniques l'empêchent :

- `HERITAGE_REFUSE_MOT_DESIGNATION` — un mot désignant un **autre** objet s'interpose
  (ex. `` arbitres M1 `:121` ``, `` → décodeur `:73-74` ``) ;
- `HERITAGE_REFUSE_HORS_BORNES` — la ligne héritée **sort du fichier** hérité
  (ex. `:1441` hérité de `FB_Winch.st`, long de 352 lignes).

Une référence héritée est en outre **marquée `propagation: true`** et affichée avec un badge
distinct (`pointillés`) : la ligne est une **interprétation** de la convention du document, pas une
citation explicite.

### Alias de contexte — prouvés, jamais supposés

`M1`/`M2`/`M3` ne sont **pas** des noms de fichiers. Deux alias sont utilisés **parce que le
document nomme lui-même leur cible**, avec une preuve vérifiée mécaniquement au parsing
(`citation_verifiee`) ; si la preuve échoue, l'alias est désactivé et l'écart est signalé :

| Alias | Cible | Preuve |
|---|---|---|
| `M1` (« arbitre M1 ») | `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` | fiche treuils, ligne 21 — **4 corroborations mesurées** (nom explicite **et** mêmes numéros sur une même ligne : `:91-92` corroboré ligne 190, `:104-111` ligne 332, `:117` ligne 484) |
| `M2` (« arbitre M2 ») | `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st` | fiche treuils, ligne 28 — corroborations mesurées |
| `M3` (« arbitre M3 ») | `CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st` | fiche T334, ligne 64 — citation **vérifiée mécaniquement** |

**Trois familles d'ambiguïté, toutes avec leurs candidats listés** (jamais de liste vide silencieuse) :

| Règle | Cas | Traitement |
|---|---|---|
| `DESIGNATION_PLURIELLE_AMBIGUE` | « arbitres `` `:114-115` `` » | **AMBIGUE** + les 2 cibles documentées, aucune choisie |
| `D_STEM_MULTIPLE_*` | `FB_Winch:169-171` → `FB_Winch.st` **et** `FB_Winch_Symmetry.st` | **AMBIGUE** + candidats |
| `ALIAS_CONTEXTE_CANDIDATS_DOCUMENTES_HORS_DOCUMENT` | alias non défini dans **ce** document | **AMBIGUE** + candidats documentés **avec leur provenance** |
| `ALIAS_NON_DETERMINABLE_SANS_SECTION` | alias défini par **aucun** document | refus **explicite** avec **motif nommé** (jamais une liste vide silencieuse) |

Tout alias non prouvé reste classé **AMBIGU** (`ALIAS_CONTEXTE_Mnn_Cnn`). L'alias est traité **de la
même façon** qu'il soit écrit `M1:91-92` ou « arbitres M1 `` `:91-92` `` ».

---

## 6. Le calcul du blob — et ses **deux** pièges mesurés

L'outil compare, pour chaque fichier cité, le blob consigné par les documents au blob mesuré.
La formule employée est :

```text
SHA1( "blob " + taille_octets_APRÈS_NORMALISATION + "\0" + contenu_normalisé_CRLF )
```

1. 🪤 **Sans l'en-tête `blob <taille>\0`**, on ne calcule pas un blob git (échec du critère AC6).
2. 🪤 **`core.autocrlf = true` sur ce dépôt** : `git hash-object <chemin>` convertit `CRLF → LF`
   **avant** de calculer le blob, et l'en-tête porte la taille **après** conversion. Sans cette
   normalisation, `PRG_04_Treuils_Benne.st` rendrait `a50024aa…` au lieu de `31760d59…` — et **les
   ~47 fichiers cités sortiraient en faux ROUGE**. Un rouge partout ne diagnostique plus rien :
   c'est le pire mode d'échec possible pour cet outil.
3. 🪤 **Corollaire** : `git hash-object --stdin` **n'applique pas** ce filtre (git le documente).
   La comparaison de référence doit **toujours** porter sur un **chemin de fichier**.

Le même fichier de fonction (`git-blob-sha1.js`) est utilisé par le navigateur **et** exécutable
sous Node — c'est ce qui rend la preuve P4 mesurable sans navigateur. Un **auto-test** de 4 vecteurs
vérifiés contre `git hash-object` s'exécute à chaque ouverture de la page et s'affiche dans l'UI.

---

## 7. ⚠️ LIMITES CONNUES DE L'OUTIL (à lire avant de s'y fier)

| # | Limite | Conséquence |
|---|---|---|
| **L1** | **T334 ne porte AUCUN bloc d'ancrage de révision** (trou n°1 relevé par l'annexe elle-même). La fraîcheur de ses références repose sur la table de blobs du **§1.3 de l'ANNEXE**, mesurée **après coup**. | Cet ancrage est étiqueté **DÉRIVÉ** dans le JSON et dans l'UI. Il n'est **jamais** présenté comme un ancrage de T334. Un lecteur qui suppose l'inverse se trompe de version. |
| **L2** | **Le « geste » n'existe pas dans les documents.** Ils livrent des chaînes **linéaires** par variable, pas un arbre de décision par geste/sens. | Le sélecteur de geste est une **surcouche curée** : 4 entrées = les 4 chaînes réelles, 4 entrées = les 4 familles de sources (§8 de la fiche treuils), 4 entrées déclarées **NON SÉPARABLE** avec leur raison. Aucun geste n'est inventé. |
| **L3** | **En `file://`, la fraîcheur n'est pas recalculable.** | Badges **figés** + horodatage + bandeau explicite. Jamais un vert trompeur. Le recalcul réel exige le mode LIVE. |
| **L4** | **Le hash dépend du filtre CRLF du dépôt** (`core.autocrlf=true`). | Si le filtre du dépôt change, la comparaison doit être revue (même règle des deux côtés : JS et Python). |
| **L5** | **Un code `Mnn`/`Cnn` n'est pas un espace de noms partagé.** | Toujours lire le **document** affiché avec le code. |
| **L6** | **18 références ne sont pas résolues** (sur 736) — et c'est volontaire : là où le document désigne un objet non nommé dans la cellule (`` arbitres M1 `:121` ``, `` → décodeur `:73-74` ``, référence courte dans la cellule « Rôle »), l'outil **refuse** d'afficher un chemin. | Une référence non résolue s'affiche **comme telle** (badge rouge) avec son motif. Elle n'est **jamais** remplacée par une supposition. |
| **L7** | **Ce que l'outil NE fait PAS** : il ne lit **pas** le contenu des lignes citées et ne vérifie donc **pas** que le motif annoncé est bien à la ligne citée (seule la **borne** du fichier est contrôlée) ; il ne corrige aucun document ; il ne produit aucun bundle ; il ne remplace pas la lecture du code réel avant une intervention machine. | Une référence au bon blob peut malgré tout porter un numéro de ligne périmé **si le fichier n'a pas changé** (le décalage viendrait alors d'une erreur de rédaction du document, non détectable par blob). |
| **L8** | **Les compléments de l'annexe (§4.2–§4.6) ne sont pas fusionnés** dans la chaîne de T334. | Ils sont affichés comme `COMPLÉMENT ANNEXE` (7 ajouts + 1 correction) uniquement quand on sélectionne le geste « M3 manuel ». Aucune écriture n'est faite dans T334 (périmètre interdit). |
| **L9** | **Le test volontaire du garde-fou (P3) n'écrit pas sur disque dans un fichier cité** (`CODE/**`). Décision d'arbitrage de l'orchestrateur (2026-09-21), transcrite telle quelle : « Le brief §5 exige “prouver que l'outil détecte un cas où le blob a changé (test volontaire : modifier un fichier cité, voir l'alerte s'afficher)”. Le volet A le fait **sur les octets réels de deux fichiers réellement cités** (`Device_IO_20260918.csv`, `PRG_04_Treuils_Benne.st`) : le contenu est modifié, le blob recalculé diffère du blob consigné, l'état passe à ROUGE, puis le retour au VERT est constaté. Le volet B le fait **sur disque**, dans le périmètre d'écriture du lot, avec restauration à l'octet près. La variante écrivant sur disque dans un fichier cité (`CODE/**`) est **volontairement écartée** : sur un dépôt partagé où d'autres lots tournent (bundles, gates CI, tests), une modification transitoire de `CODE/` peut être lue par un tiers et polluer un artefact d'un autre lot — le risque n'est pas justifié par le gain, la détection étant déjà prouvée sur le contenu réel des mêmes fichiers. Décision de l'orchestrateur, tracée ici et dans le contrat (bloc `validation`). » | Les deux volets sont livrés et rejouables (`verify_anchors.py --test-garde-fou`). Si la variante littérale est souhaitée, elle se fait **sur un arbre gelé**, par l'humain, hors de ce lot. |
| **L10** | **Deux périmètres de comptage coexistent** : le **graphe** (références des maillons + compléments + dissymétries/divergences = 736) et l'**audit global** (toutes zones des 3 documents = 2 276 occurrences, y compris la prose, le journal et les tableaux d'audit). | Les deux chiffres sont publiés côte à côte : `rapport_resolution` et `audit_references`. Comparer un chiffre de l'un avec un chiffre de l'autre n'a pas de sens. Détail : `PREUVE_T353.md` §P2bis. |
| **L11** | Les fichiers **présents non suivis** (tier `PRESENT_NON_SUIVI`) sont résolus — mais un fichier non suivi **n'a pas de blob de référence Git** pour la branche « sale/propre ». | Résolution oui, fraîcheur **non ancrable** (jamais verte). Les 3 documents source sont eux-mêmes dans ce tier. |
| **L12** | L'audit global compte **501 continuations refusées** : la plupart sont des **citations** de références de T334 dans les colonnes « Ligne citée par T334 » de l'annexe, qui ne nomment aucun fichier. | Ce n'est pas un défaut de résolution : c'est la nature du document (contre-vérification). Elles sont listées avec leur zone d'origine. |
| **L13** | **Le rouge peut apparaître à tout moment sans que rien ne soit cassé** : d'autres lots écrivent dans ce dépôt. Exemple **mesuré pendant ce lot** : `CODE/G_CYCLE/FB_CycleSemiAuto.st` est passé de 1652 à 1659 lignes (blob `032af59f…` → `f66dabfc…`) après les ancrages des documents → l'outil l'a affiché **ROUGE** (attendu vs mesuré). | Comportement **voulu** : un blob d'ancrage n'est valide que pour un contenu. Après stabilisation de l'arbre : relancer `verify_anchors.py` puis `parse_cartographies.py`. Le re-ancrage des fiches appartient à leurs auteurs (lecture seule ici). |
| **L14** | **Les continuations de la fiche T351 sont rédigées de façon relâchée** : plusieurs se rattachent au mauvais fichier de la cellule (le fichier réellement visé est nommé **plus tôt**, ou seulement dans une autre colonne de la même ligne). | L'outil les **reroute** par la règle **nommée** `E_CONTINUATION_HORS_BORNES_REROUTAGE` (3 cas mesurés : `M63 :1602`, `C32 :1441`, `C32 :1509`) — jamais par une heuristique silencieuse. **Trouvaille signalée, fiches NON corrigées** (lecture seule). |
| **L16** | **La table de correction §4.10 de l'annexe porte un ancrage PÉRIMÉ** : son en-tête dit « valeur correcte (disque `d6e54377`) » alors que HEAD est `c9e1fbfe` et que 4 fichiers cités ont encore changé de blob pendant ce lot. | Les 26 corrections sont **INDICATIVES** : elles sont affichées avec cet avertissement et doivent être **re-vérifiées par blob** avant usage. Elles ne sont **jamais** fusionnées dans les maillons. |
| **L15** | **Une fiche peut citer une ligne qui n'existe pas** : T334 (row `D07`) écrit `PRG_06_Outputs.st:431-432,650` alors que ce fichier a **549** lignes (le `650` appartient à `PRG_05_Translation.st`). | L'outil **scinde** la référence : la partie valide reste `RESOLUE`, le numéro impossible devient **`CONTESTEE_HORS_BORNES`** (`regle: LIGNE_HORS_FICHIER_EXPLICITE`) et s'affiche comme telle. Cas trouvé par l'**auto-contrôle du parseur**, qui **fait échouer** la génération si l'invariant casse. |

---

## 8. Preuves

Toutes les preuves chiffrées (P1→P6) sont dans **`PREUVE_T353.md`** :

| Preuve | Contenu |
|---|---|
| P1 | taux de parsing par document et par chaîne, + chaque ligne rejetée avec son motif |
| P2 | compteurs de résolution par catégorie et par forme, + exemples, + commande exacte |
| P3 | test volontaire du garde-fou blob : VERT → ROUGE → VERT, blobs avant/pendant/après, `git hash-object` |
| P4 | table « SHA-1 du JS (sous Node) » vs `git hash-object`, ≥ 5 fichiers, strictement égaux |
| P5 | `git status --short` avant/après et blobs des 3 sources inchangés |
| P6 | limites déclarées (reprises du §7 ci-dessus) |

---

## 9. Périmètre et garde-fous du lot

- **Aucune écriture** dans `CODE/**`, `CODE_XML/**`, `PRJ_CODESYS/**`, `TOOLS/TEST_AUTO_CI/**`,
  `TOOLS/AGENT_WORKFLOW/scripts/**`, `DOC/AF/**` — et **aucune** dans les 3 documents source.
- **Aucun bundle, aucun gate, aucun test CI** : le lot ne produit aucun code PLC.
- **Aucun commit, aucun push** : la validation est humaine.
- Les seules écritures du lot : `TOOLS/CMD_PATH_VIEWER/**` (+ `data/`), les heartbeats dans
  `TOOLS/AGENT_WORKFLOW/status/`, et l'entrée T353 des registres `DOC/WFLOW/`.
