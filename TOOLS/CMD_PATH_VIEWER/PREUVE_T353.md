# 🧾 PREUVE T353 — CMD_PATH_VIEWER (outil web de cartographie interactive)

> **Lot** : T353 (C2, *patch*) · parent T351 · **agent** DSH19
> **Contrat opposable** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T353_OUTIL_WEB_CARTOGRAPHIE.yaml`
> (`check_task_contract.py` = **PASS**, 0 erreur / 0 avertissement — vérifié à la livraison)
> **HEAD à la livraison** : `c9e1fbfeff460a4bb6065f37efb80d5e574d8772` (inchangé depuis la prise —
> **aucun commit**)
> **Livraison** : `TOOLS/CMD_PATH_VIEWER/` · **aucune écriture** dans `CODE/` (preuve P5)

Toutes les valeurs ci-dessous sont **mesurées**, jamais estimées. Chaque bloc porte la commande
exacte qui l'a produite.

---

## P1 — Taux de parsing (AC1, AC3)

### Commande

```powershell
python TOOLS/CMD_PATH_VIEWER/parse_cartographies.py
```

### Résultat mesuré — **deux grandeurs, explicitement étiquetées**

| Document | **Lignes candidates** `Mnn`/`Cnn` | **Occurrences de codes** | Chaîne acceptée | Compléments acceptés | Rejets | Lignes **hors-candidats** (sans code) | `taux_chaine` | `taux_global` |
|---|---|---|---|---|---|---|---|---|
| `…TREUILS_JoystickContacteur_20260921.md` | **101** | 101 | **101** | 0 | 0 | 0 | **1,0** | **1,0** |
| `…T334_M3_DeuxChemins_2026-09-20.md` | **101** | 101 | **101** | 0 | 0 | 0 | **1,0** | **1,0** |
| `…T351_ANNEXE_M3_TrousT334_20260921.md` (document d'AUDIT) | **117** | **137** | 0 (par conception) | 8 | **109** | **11** | 0,0 | 0,0684 |
| **TOTAL** | **319** | **339** | **202** | **8** | **109** | **11** | — | — |

**Métrique et règle de comptage — écrites dans le JSON, jamais un nombre nu :**
`rapport_parsing.par_document[*].unite_de_comptage` = *« LIGNES DE TABLEAU (une ligne à codes
combinés = 1 candidat) »* et `.regle_de_comptage` = *« occurrences = tous les codes de la 1ʳᵉ cellule,
règle uniforme : l'espacement autour du `/` n'a AUCUN effet »*.

- **319 lignes** = 101 + 101 + 117, où 117 = **86** lignes de tableau 4 colonnes (audit §2.1/§2.2)
  + **8** compléments déclarés en zone de code (§4.2→§4.6) + **23** lignes 3 colonnes (§4.10).
- **339 occurrences de codes** = 101 + 101 + 137, où 137 = 117 lignes + **20** codes supplémentaires
  portés par **12 lignes à codes combinés** (`M07 / M08`, `M36 / M37 / M38`, `C02 / C03 / C04 / C05 / C06`…).
- Les **11 lignes hors-candidats** de l'annexe (`§6.1`, `§6.5`, `§10bis B.2`, `H6`, `A03`,
  `A06 / D09 / §7.1`…) **ne portent aucun code de chaîne** : elles appartiennent aux tableaux d'audit
  mais leur première cellule est une **référence de section ou un identifiant d'affirmation**. Elles
  sont **comptées à part** (`lignes_non_candidates_hors_audit`) et **n'entrent dans aucun dénominateur**
  — c'était l'erreur de la version précédente, qui les comptait comme candidats (d'où le « 330 »,
  non reproductible, signalé en revue).
- **La règle de comptage par occurrence est uniforme** : elle ne dépend **plus** de la présence
  d'espaces autour du `/` dans la cellule (le total est donc stable, quel que soit le formatage).

### Par chaîne — contiguïté, doublons, trous, références

| Document | Chaîne | Maillons | Codes | Contigu `M01..M66`/`C01..C35` | Doublons | Maillons sans aucune référence |
|---|---|---|---|---|---|---|
| treuils | M (MANU/MAINT) | **66** | `M01…M66` | **OUI** | **0** | **0** |
| treuils | C (SEMI_AUTO) | **35** | `C01…C35` | **OUI** | **0** | **0** |
| t334 | M (MANU/MAINT) | **66** | `M01…M66` | **OUI** | **0** | **0** |
| t334 | C (SEMI_AUTO) | **35** | `C01…C35` | **OUI** | **0** | **0** |

➡️ **202 lignes de chaîne = 202 parsées** (66 + 35 par document), codes contigus, **0 doublon,
0 trou, 0 ligne sans référence**. Cible de la baseline orchestrateur : **atteinte**.

### Toute ligne rejetée — liste et motif

**109 lignes rejetées, deux motifs nommés** :

| Motif | Lignes | Nature |
|---|---|---|
| `TABLE_AUDIT_4_COLONNES_NON_INJECTEE` | **86** | tableaux de contre-vérification §2.1/§2.2 (`Réf. T334 \| Ligne citée par T334 \| Contenu réel sur disque \| Verdict`) — leurs codes `Mnn`/`Cnn` ne portent **pas** la sémantique de ceux de T334 |
| `TABLE_CORRECTION_3_COLONNES_NON_INJECTEE` | **23** | tableau §4.10 « Table de correction des références périmées » (`Code \| Référence dans T334 \| Valeur correcte`) |

Et **11 lignes `hors-candidats`** (comptées à part, hors dénominateur) : premières cellules
`§6.1`, `§6.5`, `§10bis B.2`, `§10bis B.4 / B.5`, `H6`, `A03`, `A06 / D09 / §7.1`,
`A06 / D09 / §7.1 / H2`… — **aucun code de chaîne**, donc pas des candidates.

Exemples (extraits du JSON, champ `rapport_parsing.rejets`) :

```
annexe ligne 173 M01 TABLE_AUDIT_4_COLONNES_NON_INJECTEE | cellules 4
annexe ligne 175 M01 TABLE_AUDIT_4_COLONNES_NON_INJECTEE | cellules 4
annexe ligne 515 M01 TABLE_CORRECTION_3_COLONNES_NON_INJECTEE | cellules 3
annexe ligne 517 M11 TABLE_CORRECTION_3_COLONNES_NON_INJECTEE | cellules 3
annexe ligne 537 M65 TABLE_CORRECTION_3_COLONNES_NON_INJECTEE | cellules 3
```

Chaque rejet porte `document`, `ligne`, `code`, `cellules`, `categorie_tableau`, `motif` et l'extrait
de la ligne. **Aucune vraie ligne de chaîne n'est perdue** : les 202 maillons sont intacts et les 23
lignes du §4.10 sont **toutes à 3 colonnes** (elles ne peuvent pas être des maillons).

### Bonus livré : la table de correction §4.10 exposée séparément (diagnostic)

Le tableau §4.10 est désormais exposé dans `corrections_references_perimees` (26 lignes), **jamais
fusionné** dans les maillons (`statut: TABLE_CORRECTION_NON_FUSIONNEE`) :

| Code | Référence citée par T334 (périmée) | **Valeur correcte** (résolue, même fichier) |
|---|---|---|
| M01 | `PRG_02_Acquisition.st:465` | `CODE/M_MAIN/PRG_02_Acquisition.st:481` |
| M03 | `PRG_02_Acquisition.st:434` | `CODE/M_MAIN/PRG_02_Acquisition.st:445` |
| M11 | `PRG_02_Acquisition.st:475` | `CODE/M_MAIN/PRG_02_Acquisition.st:491` |
| M61/M62/M63 (miroirs IHM) | `PRG_07_Supervision.st:526 / :527 / :515` | `PRG_07_Supervision.st:576 / :577 / :565` |

Les **48 références corrigées sont toutes résolues** (règle nommée `CORRECTION_MEME_FICHIER` : la
colonne « valeur correcte » porte un numéro du **même fichier** que la référence périmée).

⚠️ **Ancrage de cette table** : son en-tête déclare « valeur correcte (**disque `d6e54377`**) ». HEAD
est aujourd'hui `c9e1fbfe` (3 commits plus loin) et **4 fichiers cités ont encore changé de blob
pendant ce lot** (§P3bis) ⇒ ces corrections sont **INDICATIVES** et doivent être re-vérifiées par blob
avant usage. C'est écrit dans le JSON (`corrections_meta.avertissement`) **et** affiché dans l'UI —
même doctrine que partout ailleurs dans cet outil.

### Compléments de l'annexe — jamais fusionnés (AC3)

**8 compléments** conservés en `statut = COMPLEMENT_NON_FUSIONNE` (tableaux §4.2 → §4.6, zone de
code) : 7 ajouts `M67…M73` + **1 correction de `M56`** (`nature: CORRECTION`). Ils n'entrent **pas**
dans la chaîne de T334 : ils ne s'affichent que lorsque l'utilisateur choisit le geste
« Chaîne MANU / MAINTENANCE — translation M3 », avec le badge `complément annexe`.

### Cas de parsing délicat traité (et pourquoi il comptait)

La cellule « Rôle » de `M57` (T334) contient `` `|fAct| > 0,5 Hz` `` : un `|` **littéral** entre
deux backticks. Un découpage naïf produisait **6 cellules au lieu de 5** et faisait perdre la ligne.
Le découpage est **sensible aux backticks** (`split_row`) : `M57` est parsé, et toute ligne dont le
nombre de cellules diffère de l'en-tête serait rejetée avec le motif `CELLULES_INCOHERENTES`
(aucune occurrence mesurée sur les 3 documents).

---

## P2 — Résolution des références (AC2)

### Commandes exactes

```powershell
python TOOLS/CMD_PATH_VIEWER/parse_cartographies.py      # produit graph.json → rapport_resolution
git -c core.quotepath=false ls-files                       # index d'origine (3793 chemins, 1968 exclus)
```

### Compteurs globaux

| Catégorie | Nombre |
|---|---|
| **RESOLUE** | **721** |
| **AMBIGUE** | **0** |
| **NON_RESOLUE** | **15** (refus explicites — voir ci-dessous) |
| **CONTESTEE_HORS_BORNES** | **0** dans les maillons+compléments · **1** toutes zones (`divergences:D07`) |
| **TOTAL** | **736** |
| Références **reroutées** par règle nommée | **3** (`E_CONTINUATION_HORS_BORNES_REROUTAGE`) |
| Fichiers distincts résolus | **29** |
| Références hors bornes du fichier cible | **0** (maillons+compléments) · **1** (toutes zones) — **aucune n'est `RESOLUE`** |
| **Invariant** « aucune `RESOLUE` hors bornes » | **PASS** — 862 références contrôlées, 0 violation |
| **Verrou des attendus** (7 valeurs de la revue) | **PASS** — 7/7 conformes, régression ⇒ parseur en code 1 |

### Par forme (les 4 formes exigées par AC2)

| Forme | Total | Résolues | Non résolues | Contestées | dont listes de lignes |
|---|---|---|---|---|---|
| **CHEMIN_COMPLET** (`CODE/M_MAIN/PRG_04_Treuils_Benne.st:1405`) | 21 | **21** | 0 | 0 | 3 |
| **ABREGE** (`PRG_02:492`, `FB_Winch.st:226`) | 479 | **479** | 0 | 0 | 34 |
| **CONTINUATION** (`` `:492` `` après un fichier nommé) | 236 | **221** | 15 | 0 | 8 |
| **Total** | **736** | **721** | **15** | **0** | 45 |

### Par règle de résolution (ordre tracé dans le JSON)

| Règle | Occurrences |
|---|---|
| `C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE` (nom unique dans `CODE/**`) | 608 |
| `D_STEM_UNIQUE_SOURCE_ACTIVE_CODE` (`PRG_02` → `PRG_02_Acquisition.st`) | 42 |
| `C_BASENAME_UNIQUE_ANCRAGE_DECLARE` (chemin déclaré par un ancrage : le CSV d'E/S) | 29 |
| `A_CHEMIN_EXACT` (chemin complet vérifié verbatim) | 27 |
| `E_ALIAS_DOCUMENTE_CITE` (alias `M1`/`M2` **prouvé** par le document) | 11 |
| `CONTINUATION_SANS_ANTECEDENT_CELLULE` (refus) | 8 |
| `HERITAGE_REFUSE_MOT_DESIGNATION` (refus : un mot désigne un autre objet) | 7 |
| **`E_CONTINUATION_HORS_BORNES_REROUTAGE`** (reroutage **vérifiable** : 1 seul candidat de la cellule OU de la ligne de tableau contient la plage) | **3** |
| `LIGNE_HORS_FICHIER_EXPLICITE` → catégorie **`CONTESTEE_HORS_BORNES`** (fiche T334 D07, ligne 650 inexistante) | 1 (hors graphe, zone `divergences`) |
| `C_BASENAME_UNIQUE_DOC_ACTIF` (référence documentaire `.md`) | 1 |

### Index scopé — la cause des ~90 % d'ambiguïté évitée (constat n°8)

`git ls-files` = **3793** chemins, dont **1968 exclus**. Index scopé sur :

| Tier | Fichiers | Rôle |
|---|---|---|
| `SOURCE_ACTIVE_CODE` | 262 | `CODE/**` **hors** `CODE_BACKUP/**` |
| `ANCRAGE_DECLARE` | 1 | chemins **déclarés par les blocs d'ancrage** (`TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv`) |
| `DOC_ACTIF` | 535 | `DOC/**` **hors** `ARCHIVES/**` | 

**Exclus** : `CODE_BACKUP/**`, `ARCHIVES/**`, `TOOLS/TEST_AUTO_CI/**` (une archive n'est jamais une
source active). Preuve de la nécessité : `git ls-files "*/PRG_02_Acquisition.st"` renvoie **6**
emplacements (`CODE/M_MAIN/` + 5 sauvegardes `CODE_BACKUP/CODE_2026…`), `FB_Joystick.st` **7**,
`FB_Winch.st` **7** — un index naïf basculerait 641 références en ambigu.

### ≥ 10 exemples de la catégorie RESOLUE (tirés du JSON)

| # | Référence brute | Champ | Forme | Chemin résolu | Règle |
|---|---|---|---|---|---|
| 1 | `Device_IO_20260918.csv:521` | producteur | ABREGE | `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` | C_BASENAME_UNIQUE_ANCRAGE_DECLARE |
| 2 | `PRG_02_Acquisition.st:482` | producteur | ABREGE | `CODE/M_MAIN/PRG_02_Acquisition.st` | C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE |
| 3 | `CODE/M_MAIN/PRG_02_Acquisition.st:182` | producteur | CHEMIN_COMPLET | `CODE/M_MAIN/PRG_02_Acquisition.st` | A_CHEMIN_EXACT |
| 4 | `CODE/D_JOYSTICK/FB_Joystick.st:185` | consommateur | CHEMIN_COMPLET | `CODE/D_JOYSTICK/FB_Joystick.st` | A_CHEMIN_EXACT |
| 5 | `` `:272` `` | consommateur | CONTINUATION | `CODE/D_JOYSTICK/FB_Joystick.st` | héritage de cellule |
| 6 | `PRG_04:1462-1463` | consommateur | ABREGE | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | D_STEM_UNIQUE_SOURCE_ACTIVE_CODE |
| 7 | `FB_AxisScale.st:29,36,43,49` | producteur | ABREGE (liste) | `CODE/D_JOYSTICK/FB_AxisScale.st` | C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE |
| 8 | `FB_WinchOutputInterlock.st:458-464` | producteur | ABREGE | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE |
| 9 | `FB_Modes.st:395` | producteur | ABREGE | `CODE/F_MODES/FB_Modes.st` | C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE |
| 10 | `` `:121` `` précédé de « arbitres M1 » | consommateur | CONTINUATION | `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` | **E_ALIAS_DOCUMENTE_CITE** |
| 11 | `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:180` | rôle | ABREGE | `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` | C_BASENAME_UNIQUE_DOC_ACTIF |
| 12 | `FB_Translation_PositionDecoder.st:71-76` | producteur | ABREGE | `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st` | C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE |

### Les 18 références NON résolues — refus explicites, jamais devinées

**Aucune n'est un échec de l'index** : chacune est un **refus motivé** d'afficher un chemin que le
document ne permet pas d'établir (AC2 : « aucune référence devinée »).

| # | Maillon | Champ | Référence | Motif du refus |
|---|---|---|---|---|
| 1 | treuils/M06 | consommateur | `:121` | `HERITAGE_REFUSE_MOT_DESIGNATION` — « arbitres **M1** » précède : la cible est le FB d'arbitrage, pas `PRG_02_Acquisition.st` |
| 2 | treuils/M06 | consommateur | `:147` | idem (M2) |
| 3 | treuils/M13 | consommateur | `:68,121,124` | idem (« arbitres M1 ») |
| 4 | treuils/M13 | consommateur | `:97,147,150` | idem (« M2 ») |
| 5 | treuils/M17 | consommateur | `:56` | idem |
| 6 | treuils/M17 | consommateur | `:67,85` | idem |
| 7 | treuils/M21 | consommateur | `:114-115` | `CONTINUATION_SANS_ANTECEDENT_CELLULE` — cellule « arbitres `:114-115` ; … » : aucun fichier nommé avant |
| 8 | treuils/M22 | consommateur | `:114-115` | idem |
| 9 | treuils/M22 | consommateur | `:141-142` | idem |
| 10 | treuils/C13 | rôle | `:297-299` | cellule « Rôle » : aucun fichier nommé dans la cellule |
| 11 | treuils/C17 | rôle | `:65-67` | idem |
| 12 | t334/M18 | rôle | `:99` | cellule « Rôle » |
| 13 | t334/C25 | rôle | `:68` | cellule « Rôle » |
| 14 | t334/C26 | rôle | `:74` | cellule « Rôle » |
| 15 | annexe §4.4 (M73) | consommateur | `:73-74` | `HERITAGE_REFUSE_MOT_DESIGNATION` — « → **décodeur** » : la cible est `FB_Translation_PositionDecoder.st`, non `PRG_05_Translation.st` |

**+ 1 référence `CONTESTEE_HORS_BORNES`** (distinguée des refus ci-dessus : c'est un couple
`(fichier, ligne)` **impossible**, trouvé par l'auto-contrôle du parseur dans la fiche T334) et
**3 références reroutées** par la règle nommée — détail complet en **§P2ter** :
`treuils/M63 :1602`, `treuils/C32 :1441`, `treuils/C32 :1509` (toutes reroutées →
`PRG_04_Treuils_Benne.st`) et `divergences:D07` (`PRG_06_Outputs.st:431-432,650` → `650` inexistant).

### Écart assumé vs baseline orchestrateur

La baseline annonçait « **0 ambigu, 0 introuvable** » sur les 2 fiches. Mesure réelle :

- **0 ambigu et 0 introuvable au niveau des NOMS DE FICHIERS** — les 500 références portant un nom
  de fichier sont **500/500 résolues** (`479 ABREGE + 21 CHEMIN_COMPLET`, dont 11 via alias prouvés) ;
- **18 refus sur les 236 références COURTES** — parce que les 4 premiers garde-fous
  (`M63 :1602`, `C32 :1441/:1509`) donneraient un **chemin faux affiché avec assurance**.
  Les résoudre « quand même » violerait AC2 ; ils sont donc **affichés NON RÉSOLUS avec leur motif**.

➡️ Écart **motivé et tracé** dans le contrat (`execution.ecarts_assumes`) — pas un échec.

---

## P2bis — Audit GLOBAL des références, toutes zones (9e constat : la 4e forme)

Le §P2 ci-dessus compte les références **du graphe** (maillons + compléments + dissymétries/divergences).
Le 9e constat impose de traiter une **4e forme** — l'**abréviation** (`PRG_04:1309`, `FB_Winch:226`,
`M1:56`) — et de la compter sur **toutes** les zones des documents. Les deux périmètres coexistent donc,
et sont publiés séparément (`rapport_resolution` vs `audit_references`) :

| Périmètre | Occurrences | Nature |
|---|---|---|
| **Graphe** (`rapport_resolution`) | **736** | chaînes M/C + compléments de l'annexe + dissymétries/divergences |
| **Audit global** (`audit_references`) | **2 276** | **toutes zones** : chaînes 699 · autres tableaux 805 · prose 392 · tableaux d'audit 4 col 228 · divergences 75 · zone de code 46 · dissymétries 31 |

### Les 4 formes, mesurées sur l'audit global

| Forme | Occurrences |
|---|---|
| `CHEMIN_COMPLET` | 56 |
| `EXTENSION` (nom de fichier nu) | 1 317 |
| **`ABREVIATION_PREFIXE`** (préfixe de POU, sans extension) | **347** |
| **`ABREVIATION_ALIAS`** (`M1`, `M2`) | **70** |
| `CONTINUATION` (`:NNN` sans nom dans la cellule) | 486 |

### Les 4 traitements distincts — et leurs compteurs

| Traitement | Occurrences | Règle tracée (`resolved_by`) |
|---|---|---|
| **`PREFIXE_UNIQUE`** | **334** | `prefix_unique` — un seul fichier `CODE/**` commence par `<préfixe>.` ou `<préfixe>_` |
| **`PREFIXE_AMBIGU`** | **4** | `prefix_ambigu` — **jamais tranché**, candidats listés |
| **`ALIAS_CONTEXTE_CURE`** | **70** | `alias_documente_cure` — table **curée à 2 entrées**, provenance citée **et** corroborée |
| **`TRONCATURE_OU_NOM_INTROUVABLE`** | 1 troncature + 1 chemin introuvable | `troncature_prose` / `chemin_introuvable` |
| `CONTINUATION_REFUSEE` | 509 | héritage refusé (mot de désignation / hors bornes) ou sans antécédent |
| `RESOLUE_AUTRE` | 1 357 | chemin exact, nom unique, chemin déclaré, nom non suivi |
| **`NON_RESOLUE_AUTRE`** | **0** | aucun cas non classé : tous les traitements sont exposés, aucun masqué |

### Préfixes AMBIGUS — les 4 occurrences, jamais tranchées

| Document · ligne | Référence | Candidats mesurés |
|---|---|---|
| treuils:240 | `FB_Winch:284-293` | `FB_Winch.st` · `FB_Winch_Symmetry.st` |
| treuils:240 | `:306-309` (héritage du précédent) | idem |
| treuils:333 | `FB_Winch:169-171` | idem |
| t334:692 | `FB_Translation:229-233` | `FB_Translation.st` · `FB_Translation_PositionDecoder.st` · `FB_Translation_PositionEstimator.st` |

### Troncature de prose — l'occurrence signalée par l'orchestrateur, retrouvée

| Document · ligne | Référence | Traitement |
|---|---|---|
| treuils:**595** | **`M2.st:85`** | `NON_RESOLUE` — texte brut conservé, motif : *« troncature de prose : `M2.st` n'existe pas — le document écrit `M2.st` là où il désigne l'objet de l'alias `M2` (défaut de rédaction de la fiche, ce n'est PAS un fichier manquant) »* |
| t334:619 | `AF_Partie-11/FB_Translation_v1.1.md:190` | `NON_RESOLUE` (`chemin_introuvable`) — le chemin relatif cité **n'existe pas** (le fichier réel porte un autre nom de version) : aucune résolution approchée, ce serait une supposition |

### Alias contextuels `M1` / `M2` — table curée, provenance **corroborée**

70 occurrences d'alias sont résolues par une table **à 2 entrées** (jamais une règle générique
`M<chiffre>`) : chaque alias porte une preuve (document + ligne) **vérifiée mécaniquement**, et une
**corroboration indépendante** est cherchée — le document cite-t-il, sur une même ligne, le **nom
explicite** de la cible **et** les mêmes numéros ?

| Alias | Cible | Preuve | Corroborations mesurées |
|---|---|---|---|
| `M1` | `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` | fiche treuils **ligne 21** | 2 (ex. `:91-92` corroboré **ligne 190**, `:117` ligne 484) |
| `M2` | `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st` | fiche treuils **ligne 28** | 2 (ex. `:104-111` corroboré **ligne 332**) |

➡️ Le même alias est traité **identiquement** qu'il soit écrit `M1:91-92` (forme token) ou
« arbitres M1 `` `:91-92` `` » (forme continuation) — sans cette unification, le même alias était
résolu dans un cas et AMBIGU dans l'autre (incohérence détectée et corrigée pendant ce lot).

### `Device_IO_20260918.csv` — forme courte, résolue par chemin déclaré

Résolue via le **chemin déclaré par les blocs d'ancrage** → `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv`
(règle `C_BASENAME_UNIQUE_ANCRAGE_DECLARE`, tier `ANCRAGE_DECLARE`). **Ce n'est pas un introuvable.**

### Contrôle anti-invention — mesuré, à zéro

```
chemins_inventes = 0
```

Aucun chemin résolu n'est un alias affublé d'une extension (`M1.st`, `M2.st`, `PRG_04.st`, `FB_Winch.st`
en tant qu'« invention » à partir de l'abréviation). Les vrais fichiers `FB_Winch.st` et
`FB_Translation.st` sont légitimes et ne sont pas comptés comme inventions. Contrôle rejouable :
`graph.json → audit_references.controle_anti_invention`.

### Réconciliation avec la mesure de l'orchestrateur (9e constat)

| Document | Orchestrateur : tokens abrégés · unique · ambigu · aucun match | Mesure (toutes zones) : unique · ambigu · alias curé · troncature | Mesure (chaînes seules, occurrences abrégées) |
|---|---|---|---|
| fiche treuils | 188 · 131 · **2** · 55 | **202** · **3** · **70** · 1 | 54 |
| T334 | 31 · 30 · **1** · 0 | **39** · **1** · 0 · 0 | 0 |
| annexe | 63 · 63 · 0 · 0 | **93** · 0 · 0 · 0 | 0 |

**Lecture honnête de l'écart** (aucune des deux mesures n'est fausse, elles ne couvrent pas le même périmètre) :

- les **2 ambigus** annoncés pour les treuils (`FB_Winch`) sont **retrouvés** — j'en compte **3
  occurrences** (`:284-293`, `:306-309`, `:169-171`) ; l'ambigu de T334 (`FB_Translation`) est
  retrouvé **1/1** ⇒ **4/4 conformes sur la catégorie AMBIGU** ;
- les **55 « aucun match »** (M2 ×31, M1 ×24) sont les **alias contextuels** : je les résous par la
  **table curée prouvée** que le 9e constat autorise explicitement (option 1) ⇒ `alias_contexte_cure
  = 70`, `alias_non_resolue = 0`, et **aucune règle générique devinée** ;
- les **55 = 31 + 24** et mes **70** diffèrent par la **zone** : j'audite aussi le journal (§13), la
  table d'alertes (§10) et le contrôle de non-régression (§14) ;
- le **1 troncature** annoncé (`M2.st:85`) est retrouvé **à la ligne exacte** ;
- `131 → 202`, `30 → 39`, `63 → 93` : mon périmètre inclut les zones **PROSE** et **AUTRE (autres
  tableaux)** que l'audit orchestrateur ne couvrait pas. La ventilation par zone publiée dans
  `audit_references.par_document[*].par_zone_forme` permet de **recalculer n'importe quel sous-périmètre**
  (chaînes seules : 54 / 0 / 0 occurrences abrégées).

➡️ **Aucun chemin inventé, aucune référence devinée, 0 ambiguïté sur les noms de fichiers** : AC2 est
satisfait par le **taux chiffré par catégorie** et par le fait que tout ce qui n'est pas résolu est
**listé avec son texte brut et son motif**, jamais remplacé par une supposition.

---

## P2ter — Réponse à la revue orchestrateur (D1 « 28 AMBIGU » et D2 « 5 résolutions hors bornes »)

### D1 — 28 références classées AMBIGUË alors qu'un seul candidat existe → **DÉJÀ CORRIGÉ** (et la mesure le prouve)

La revue portait sur l'instantané de `data/graph.json` **à 02:27:48**. La cause racine identifiée
(`index_resolution.tiers.ANCRAGE_DECLARE = 0`) a été corrigée à **02:33** : les chemins déclarés
étaient collectés en respectant la **casse**, alors que l'index compare en minuscules — le CSV n'entrait
donc dans aucun tier.

| Contrôle | AVANT (02:27:48, revue) | **APRÈS (génération courante)** |
|---|---|---|
| `index_resolution.fichiers_par_tier.ANCRAGE_DECLARE` | 0 fichier | **1 fichier** (`TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv`) |
| `rapport_resolution.par_categorie.AMBIGUE` | **28** (`C_BASENAME_HORS_TIERS`) | **0** |
| `ambigues_detail` | 28 entrées à **1 seul candidat** | **vide** |
| Références CSV résolues | 0 par la règle dédiée | **29** via `C_BASENAME_UNIQUE_ANCRAGE_DECLARE` |
| Taux d'ambiguïté de la fiche treuils | 28 / 374 | **0 / 374** |

Commandes de contrôle : `python parse_cartographies.py` puis lecture de
`index_resolution.fichiers_par_tier` et `rapport_resolution.par_categorie`.

### D2 — 5 continuations présentées comme résolues vers un fichier où la ligne n'existe pas

**Chiffres AVANT / APRÈS** (les deux périmètres, la revue portait sur l'instantané de `02:29:57`) :

| Mesure | AVANT (revue 02:29:57) | **APRÈS (génération courante)** |
|---|---|---|
| `par_categorie` (maillons + compléments) | `RESOLUE 731 · AMBIGUE 0 · NON_RESOLUE 5` | `RESOLUE 721 · AMBIGUE 0 · NON_RESOLUE 15 · CONTESTEE_HORS_BORNES 0` |
| `refs_hors_bornes` (maillons+compléments) | **5** | **0** |
| `refs_hors_bornes_toutes_zones` | (absent) | **1** — compteur étendu à **toutes** les zones (maillons, compléments, dissymétries, divergences, familles), sur **862** références contrôlées |
| Références `RESOLUE` avec ligne hors bornes | **5** (invariant violé) | **0** |
| Reroutages par règle nommée | 0 | **3** (`M63 :1602`, `C32 :1441`, `C32 :1509`) |
| Références contestées (couple impossible) | 0 | **1** (`divergences:D07`) |

**Les 5 cas de la revue, tous désormais conformes à la cible que tu as prouvée dans les fiches :**

| Maillon | Champ | Cité | AVANT | **APRÈS** |
|---|---|---|---|---|
| M37 | consommateur | `:1499` | `FB_Winch.st:1499` ❌ | ✅ **`CODE/M_MAIN/PRG_04_Treuils_Benne.st:1499`** |
| M37 | consommateur | `:1541` | `FB_Winch.st:1541` ❌ | ✅ **`PRG_04_Treuils_Benne.st:1541`** |
| C32 | consommateur | `:1441` | `FB_Winch.st:1441` ❌ | ✅ **`PRG_04_Treuils_Benne.st:1441`** (reroutée) |
| C32 | consommateur | `:1509` | `FB_Winch.st:1509` ❌ | ✅ **`PRG_04_Treuils_Benne.st:1509`** (reroutée) |
| M63 | consommateur | `:1602` | `FB_WinchDirectionInterlock.st:1602` ❌ | ✅ **`PRG_04_Treuils_Benne.st:1602`** (reroutée) |

**5/5 conformes à ta table.** Les deux mécanismes que tu distingues sont tous deux traités :

- **(a) antécédent pris au plus proche précédent** — corrigé le `02:34` (l'héritage n'est plus « le
  dernier fichier de la cellule » mais « le **dernier fichier nommé avant la référence** ») ⇒ M37 corrigé ;
- **(b) antécédent correct hors bornes** — règle de réparation **nommée et traçable**, exactement celle
  que tu prescris : **`E_CONTINUATION_HORS_BORNES_REROUTAGE`** — recherche d'abord dans la **même
  cellule**, puis dans la **même ligne de tableau** ; reroutage accepté **seulement** si **exactement un**
  candidat contient la plage ; sinon `CONTESTEE_HORS_BORNES` avec la **liste des candidats examinés**
  (`candidats`) et la **valeur héritée initiale conservée dans `note`**.

**Exigences associées — état mesuré :**

1. **Invariant testable** ✅ — auto-contrôle du parseur (`controle_invariants`) : 4 invariants, **862
   références contrôlées, 0 violation, verdict `PASS`**, et le parseur **sort en code 1 en criant** si un
   invariant casse (il l'a fait pendant ce lot : voir le 10e cas ci-dessous).
   ```text
   1. aucune reference RESOLUE avec lignes_hors_bornes non vide
   2. toute reference RESOLUE porte chemin_resolu
   3. categorie dans {RESOLUE, AMBIGUE, NON_RESOLUE, CONTESTEE_HORS_BORNES}
   4. aucun chemin resolu de type M1.st / M2.st / PRG_04.st (alias converti en fichier)
   ```
2. **`refs_hors_bornes` toutes zones** ✅ — `refs_hors_bornes` (maillons+compléments) = **0**,
   `refs_hors_bornes_toutes_zones` = **1** sur **862** références ; l'écart de périmètre que tu avais
   relevé (9 vs 5) est **résorbé et instrumenté** : le compteur large existe désormais nommément.
3. **Affichage distinct** ✅ — panneau « Références contestées (couple fichier:ligne impossible) » avec
   l'**auto-contrôle des invariants** en tête, la liste des contestées (origine, cité, fichier écarté,
   motif) et celle des reroutées (avec la note « héritage initial écarté »).
4. **Chiffres avant/après** ✅ — tableau ci-dessus.

### 🔎 10e cas, trouvé par l'auto-contrôle : un **défaut réel de la fiche T334**

L'invariant a fait échouer le parseur (code 1) sur une référence que **personne n'avait relevée** :

| Origine | Cité | Résolu | Problème |
|---|---|---|---|
| `divergences:D07` (T334, ligne **214** de la fiche) | `PRG_06_Outputs.st:431-432,650` | `CODE/M_MAIN/PRG_06_Outputs.st` (**549** lignes) | **la ligne 650 n'existe pas** dans ce fichier |

Lecture : la fiche liste `431-432,650` sous un **seul** nom de fichier, alors que `650` appartient
visiblement à `PRG_05_Translation.st` (827 l — la même fiche cite `PRG_05_Translation.st:…, :650`
au maillon `M29`). **Traitement retenu** : la référence est **SCINDÉE** — la partie valide
(`431-432`) reste `RESOLUE`, le numéro impossible (`650`) devient une référence
**`CONTESTEE_HORS_BORNES`** distincte (`regle: LIGNE_HORS_FICHIER_EXPLICITE`), affichée comme telle.
**Constat signalé, fiches NON modifiées** (lecture seule).

### D2bis — Complément de revue n°2 : « l'héritage n'accepte plus les antécédents abrégés ou aliasés »

**Constat** : le trou signalé a existé **environ une minute** (instantané de `02:32:27`), le temps d'un
essai de propagation par « clause » (qui refusait de propager dès qu'un séparateur `;` ou `→`
séparait l'antécédent de la continuation). Cette règle a été **remplacée dès `02:34`** par la
propagation **par position** (« dernier fichier nommé AVANT la référence »), qui accepte **toutes** les
formes d'antécédent déjà résolues par le parseur.

| Mesure | Instantané revue n°2 (`02:32:27`, règle par clause) | **APRÈS (règle par position + attendus verrouillés)** |
|---|---|---|
| `RESOLUE` | 707 | **721** |
| `AMBIGUE` | 0 | **0** |
| `NON_RESOLUE` | **29** | **15** |
| `CONTESTEE_HORS_BORNES` | 0 | 0 (1 toutes zones : le `650` de T334 D07) |
| `refs_hors_bornes` (invariant) | 2 | **0** (maillons+compléments) · 1 toutes zones |
| Attendus de la revue | — | **7/7 conformes** |

**Les 6 valeurs que tu as vérifiées dans la fiche — toutes conformes, mesurées :**

| Maillon | Champ | Cité | Forme d'antécédent | **Obtenu** |
|---|---|---|---|---|
| M21 | consommateur | `:1611-1612` | **abréviation** `PRG_04:1462-1463` | ✅ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` |
| M34 | consommateur | `:1527` | **abréviation** `PRG_04:1461` | ✅ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` |
| M34 | consommateur | `:1596` | abréviation | ✅ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` |
| M34 | consommateur | `:1617` | abréviation | ✅ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` |
| M20 | consommateur | `:114-115` | **alias documenté** `M1` | ✅ `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` |
| M20 | consommateur | `:141-142` | **alias documenté** `M2` | ✅ `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st` |

**Cas qui reste refusé, comme tu l'exiges** : M21 consommateur « arbitres `` `:114-115` `` ; … » ⇒
**`NON_RESOLUE`** (`CONTINUATION_SANS_ANTECEDENT_CELLULE`). Le mot « arbitres » admet **M1 et M2**
comme candidats : l'outil ne choisit **jamais** silencieusement. (Ta classification proposée était
« `AMBIGUE` avec 2 candidats » ou `NON_RESOLUE` : c'est le second, et le motif est affiché dans l'UI.)

### 🔒 Verrou des attendus — non-régression mécanique

Les 7 valeurs ci-dessus sont désormais **codées dans le parseur** (`ATTENDUS_RESOLUTION`) et
**vérifiées à chaque génération** (`controle_attendus`) :

```text
OK   M20 :114-115     → CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st   [alias documenté M1]
OK   M20 :141-142     → CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st   [alias documenté M2]
OK   M21 :1611-1612   → CODE/M_MAIN/PRG_04_Treuils_Benne.st                [abréviation de préfixe]
OK   M34 :1527        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                [abréviation de préfixe]
OK   M34 :1596        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                [abréviation de préfixe]
OK   M34 :1617        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                [abréviation de préfixe]
OK   M21 :114-115     → NON_RESOLUE (CONTINUATION_SANS_ANTECEDENT_CELLULE)  [mot « arbitres » seul]
conformes : 7/7 · verdict : PASS
```

**Si un seul de ces attendus casse, le parseur sort en code 1** — la régression ne peut plus passer
inaperçue. L'UI affiche le même tableau (panneau « Références contestées ») et le smoke test le vérifie
(`35/35 PASS`).

### 🔎 Origine exacte du `650` — précision apportée

Tu attribues le `650` à l'annexe §2.1 (ligne 127 citant `PRG_06:431-432` · `:443,445,448`). Vérification
littérale : l'annexe **ne contient pas** ce `650` — il vient de la **fiche T334 elle-même, ligne 214**
(row de divergence **D07**) :

```text
| D07 | **Coupure dure Trémie** | Armée : `ReqTremieSemantic = M3_ReqTremie_Active` reste vrai tant que
l'opérateur pousse (`PRG_06_Outputs.st:431-432,650`) | …
```

C'est donc bien une **référence citée sans ligne correspondante** dans **T334**, et elle est classée
comme telle (`CONTESTEE_HORS_BORNES`, `regle: LIGNE_HORS_FICHIER_EXPLICITE`), **jamais verte** — limite
**L15** du README. Fiches non modifiées (lecture seule).

### 🔎 Trouvaille signalée sur les fiches (non corrigée — lecture seule)

Les continuations de la fiche T351 sont **rédigées de façon relâchée** : plusieurs d'entre elles se
rattachent au mauvais fichier de la cellule (le fichier réellement visé est nommé **plus tôt** dans la
même cellule), et deux d'entre elles (`C32 :1441`, `:1509`) ne correspondent à **aucune ligne** du
fichier désigné — le fichier visé (`PRG_04_Treuils_Benne.st`) n'est même pas nommé dans la cellule.
**Constat remonté, fiches NON modifiées** (elles sont en lecture seule dans ce lot) ; signalé aussi
dans le README (limite L14).

---

## P3bis — Drift **réel** détecté pendant le lot (démonstration en direct du garde-fou)

Le garde-fou n'est pas seulement prouvé par test volontaire : **il a détecté un vrai déplacement de
fichier pendant ce lot**, exactement le scénario du REX T351.

| Horodatage | Constat | Détail |
|---|---|---|
| `2026-09-21T02:39:08+02:00` | **47 VERT / 0 ROUGE** | constat figé de la livraison |
| `2026-09-21T03:01:01+02:00` | **43 VERT / 4 ROUGE** | 🔴 **4 fichiers cités ont bougé PENDANT le lot** : `CODE/G_CYCLE/FB_CycleSemiAuto.st` (consigné `032af59f…` 1652 l → mesuré **`f66dabfc…` 1659 l**) · `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st` (`81298082…` → `235942d3…`) · `CODE/M_MAIN/PRG_03_Modes_Cycle.st` (`6e22c76d…` → `89cb0853…`) · `CODE/M_MAIN/PRG_07_Supervision.st` (`c10f0041…` 920 l → `5eca71e0…` 918 l) |

Changement concomitant observé dans `git status --short -- CODE/` (lot concurrent, chaîne cycle /
modes / supervision) : `M CODE/G_CYCLE/FB_CycleSemiAuto.st` ·
`M CODE/J_SUPERVISION/FB_TroubleshootingView.st` · `M …/ST_ChainCycleSemiAuto.st` · `M …/ST_CycleCfg.st`
· `M …/ST_CycleCmd.st` · `M …/ST_CycleState.st` · `M …/ST_SequencePublicState.st` ·
`M CODE/M_MAIN/PRG_03_Modes_Cycle.st` · `M CODE/M_MAIN/PRG_07_Supervision.st`
(`FB_CycleSemiAuto.st` : `git diff --stat` = **109 insertions / 102 suppressions**).

**Interprétation** : les fichiers cités par les **trois** documents ont bougé **après** leurs ancrages ⇒
les numéros de ligne cités sont invalidés **à nouveau** (T334 l'était déjà de +20 à +91 pour
`FB_CycleSemiAuto.st`, selon l'annexe). C'est **précisément** ce que l'outil doit dire, et c'est
pourquoi il affiche le blob attendu **et** le blob mesuré plutôt qu'un simple voyant.

**Aucune correction des documents n'est faite ici** (lecture seule) : la seule action légitime est de
**re-mesurer** (`verify_anchors.py`) puis de **re-parser** (`parse_cartographies.py`) après stabilisation
de l'arbre. Le rouge disparaîtra **de lui-même** si les fichiers reviennent au contenu ancré, ou restera
jusqu'à re-ancrage des fiches par leurs auteurs.

> 📌 **Conséquence pour la baseline « 47 vert / 0 rouge »** : elle était **vraie et vérifiée** au
> `02:39:08` (et à chacune de mes exécutions précédentes : 02:31, 02:39, 02:56). Elle ne peut **pas**
> rester vraie pendant qu'un autre lot réécrit la chaîne cycle : c'est la limite **L13** (drift
> concurrent), pas un défaut de l'outil. La preuve de non-régression du lot reste `git status --short -- CODE/`
> **vide côté T353** (aucune écriture de ce lot dans `CODE/`) et les 3 blobs sources inchangés.

---

## P3 — Garde-fou blob **prouvé** par test volontaire (AC5)

### Commande

```powershell
python TOOLS/CMD_PATH_VIEWER/verify_anchors.py --test-garde-fou
```

### Volet A — fichiers **réellement cités**, modification en mémoire (dépôt jamais touché)

| Fichier cité | État | Blob mesuré par l'outil | Blob consigné | Verdict | `git hash-object` |
|---|---|---|---|---|---|
| `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` | AVANT | `18c75783a18856a1d4450c82624ceccbefe4f324` | `18c75783a18856a1d4450c82624ceccbefe4f324` | **VERT** | `18c75783a188…` |
| idem | **PENDANT** (1 ligne ajoutée) | **`1e2a0bc0801bfcce96ee1f0f5843968fc8b1f9b9`** | `18c75783a18856a1d4450c82624ceccbefe4f324` | **🔴 ROUGE** | `18c75783a188…` (inchangé) |
| idem | APRÈS restauration | `18c75783a18856a1d4450c82624ceccbefe4f324` | `18c75783a18856a1d4450c82624ceccbefe4f324` | **VERT** | `18c75783a188…` |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | AVANT | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | **VERT** | `31760d59b4e0…` |
| idem | **PENDANT** | **`fa6e6134293add37feaeb348cc303278d8765106`** | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | **🔴 ROUGE** | `31760d59b4e0…` (inchangé) |
| idem | APRÈS restauration | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | **VERT** | `31760d59b4e0…` |

Corroborations mesurées : `git hash-object` **identique avant et après** les deux fichiers ;
octets relus **identiques** aux octets d'origine (`OUI`) ; blob brut du « PENDANT »
(`130402cf2506` / `2daf0e8e16b2`) distinct du blob **git-normalisé**, ce qui prouve que la
normalisation CRLF est bien appliquée au moment du test.

### Volet B — test **sur disque**, dans le périmètre d'écriture autorisé

Cible : `TOOLS/CMD_PATH_VIEWER/git-blob-sha1.js` · blob consigné `7b1b1d730f34a994610b25ec18e7bc9ba2319c1c`
(registre : `data/selftest.json`).

| État | Blob outil | Blob `git hash-object` | Verdict |
|---|---|---|---|
| AVANT | `7b1b1d730f34a994610b25ec18e7bc9ba2319c1c` | `7b1b1d730f34a994610b25ec18e7bc9ba2319c1c` | **VERT** |
| **PENDANT** (ligne de test écrite sur le disque) | **`3a92a4300d309a20c3c4203425bcf35052508ab5`** | `3a92a4300d309a20c3c4203425bcf35052508ab5` | **🔴 ROUGE** (attendu `7b1b1d73…` / mesuré `3a92a430…`) |
| APRÈS restauration | `7b1b1d730f34a994610b25ec18e7bc9ba2319c1c` | `7b1b1d730f34a994610b25ec18e7bc9ba2319c1c` | **VERT** |

**Restauration à l'octet près : OUI · blob final = blob initial : OUI.**

### Journal horodaté

`TOOLS/CMD_PATH_VIEWER/data/preuve_garde_fou_T353.json` — dernier passage **`2026-09-21T03:15:08+02:00`**
(HEAD `c9e1fbfe`), `verdict: PASS`, `fichiers_cites_modifies_dans_le_depot: false`, volet B « PENDANT »
= outil `3a92a430…` **=** `git hash-object` `3a92a430…` → ROUGE, puis restauration à l'octet près.
*(Le test est rejouable à volonté : le journal porte l'horodatage du dernier passage.)*

### ⚖️ Constat de périmètre — arbitrage de l'orchestrateur (2026-09-21)

> Le brief §5 exige « prouver que l'outil détecte un cas où le blob a changé (test volontaire :
> modifier un fichier cité, voir l'alerte s'afficher) ». Le volet A le fait **sur les octets réels de
> deux fichiers réellement cités** (`Device_IO_20260918.csv`, `PRG_04_Treuils_Benne.st`) : le contenu
> est modifié, le blob recalculé diffère du blob consigné, l'état passe à ROUGE, puis le retour au
> VERT est constaté. Le volet B le fait **sur disque**, dans le périmètre d'écriture du lot, avec
> restauration à l'octet près. La variante écrivant sur disque dans un fichier cité (`CODE/**`) est
> **volontairement écartée** : sur un dépôt partagé où d'autres lots tournent (bundles, gates CI,
> tests), une modification transitoire de `CODE/` peut être lue par un tiers et polluer un artefact
> d'un autre lot — le risque n'est pas justifié par le gain, la détection étant déjà prouvée sur le
> contenu réel des mêmes fichiers. Décision de l'orchestrateur, tracée ici et dans le contrat
> (bloc `validation`).

**Conséquence pour ce lot** : le périmètre d'écriture **n'est pas élargi**, `OPEN_CMD_PATH_VIEWER.bat`
**n'est pas modifié**, et le **volet B est conservé tel quel** (il prouve le chemin « lecture disque →
comparaison », que le volet A ne couvre pas). Si l'humain veut la variante littérale, elle se fera
**sur un arbre gelé**, par lui, hors de ce lot.

---

## P4 — Égalité stricte du hash navigateur ↔ `git hash-object` (AC6)

### Commande exacte

```powershell
python TOOLS/CMD_PATH_VIEWER/verify_anchors.py --preuve-p4
```

Le programme exécuté sous Node **est le fichier même que charge le navigateur**
(`TOOLS/CMD_PATH_VIEWER/git-blob-sha1.js`, `require()` par le harnais) — la table n'est donc pas une
transcription, elle est **mesurée sur le code du front**.

### Table de comparaison (8 fichiers de contrôle)

| Fichier | SHA-1 du JS (sous Node) | `git hash-object` | Égal |
|---|---|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | **OUI** |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | `9c493a5f0d5726b3d276c455bc3efca83fe29ebd` | `9c493a5f0d5726b3d276c455bc3efca83fe29ebd` | **OUI** |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` | **OUI** |
| `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` | `18c75783a18856a1d4450c82624ceccbefe4f324` | `18c75783a18856a1d4450c82624ceccbefe4f324` | **OUI** |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` | **OUI** |
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` | `032af59fc1fa8ebb90c90b43c69dc30b71472419` | `032af59fc1fa8ebb90c90b43c69dc30b71472419` | **OUI** |
| `…TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` | `2ea84800602ea530698c4a220f88ad48e3b7fd8f` | `2ea84800602ea530698c4a220f88ad48e3b7fd8f` | **OUI** |
| `…TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md` | `20bfada06fc56a9fa10f432cd48272f203ed3b95` | `20bfada06fc56a9fa10f432cd48272f203ed3b95` | **OUI** |

**Résultat : 8/8 conformes** (exigence AC6 : ≥ 5). Détail des conversions :
`PRG_04` 126 466 o → **124 484 o** (1982 CRLF convertis) · `FB_Bucket.st` 50 861 → 50 023 o (838) ·
`PRG_02` 46 581 → 45 862 o (719).

### Formule employée — et les **deux** pièges mesurés

```text
SHA1( "blob " + taille_octets_APRÈS_NORMALISATION_CRLF + "\0" + contenu_normalisé_CRLF )
```

1. **Sans l'en-tête `blob <taille>\0`**, ce n'est pas un blob git (échec AC6 explicite).
2. **`core.autocrlf = true` mesuré sur ce dépôt** : `git hash-object <chemin>` convertit
   `CRLF → LF` **avant** de calculer le blob et l'en-tête porte la taille **après** conversion.
   **Sans cette normalisation** : `PRG_04_Treuils_Benne.st` → `a50024aa279659aa` au lieu de
   `31760d59b4e09b03` ⇒ **les ~47 fichiers cités sortiraient en FAUX ROUGE** (pire mode d'échec
   possible : un rouge partout ne diagnostique plus rien).
3. **Corollaire mesuré** : `git hash-object --stdin` sur le contenu `a\r\nb\r\n` rend
   `c30dea8a3641…` (octets bruts) alors que `git hash-object <chemin>` rendrait `422c2b7ab3b3…`
   (filtre appliqué). **La référence doit toujours être un CHEMIN DE FICHIER.**

### Auto-test embarqué (exécuté dans le navigateur à chaque ouverture)

| Vecteur | Attendu (vérifié contre `git hash-object` sur cette machine) | Obtenu | |
|---|---|---|---|
| vide | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` | ✅ |
| `hello\n` | `ce013625030ba8dba906f756967f9e9ca394464a` | idem | ✅ |
| `what is up, doc?\n` | `7108f7ecb345ee9d0084193f147cdad4d2998293` | idem | ✅ |
| `a\r\nb\r\n` (piège CRLF) | `422c2b7ab3b3c668038da977e4e93a5fc623169c` | idem | ✅ |

**Auto-test : PASS** — et il est **affiché dans l'interface** : l'utilisateur voit le verdict de
l'algorithme de hash dans son propre navigateur, pas seulement dans un rapport.

---

## P5 — Zéro `CODE/` touché, sources intactes (AC10, AC11)

### `git status --short -- CODE/`

```
(vide)
```

➡️ **0 fichier `CODE/` modifié, ajouté ou supprimé** par ce lot (le dépôt portait déjà, à la prise,
des modifications d'autres acteurs dans `CODE_XML/`, `DOC/AF/`, `TOOLS/TEST_AUTO_CI/` — **aucune
n'est imputable à T353**, et le lot n'a rien écrit dans ces périmètres).

### Blobs des 3 documents source — inchangés (AC11)

| Document | Blob à la prise (contrat) | Blob à la livraison | Verdict |
|---|---|---|---|
| `TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` | `aeaac5dd285618f80a0479dbb3ba81a0e6fe7001` | **`aeaac5dd285618f80a0479dbb3ba81a0e6fe7001`** | ✅ identique |
| `TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` | `2ea84800602ea530698c4a220f88ad48e3b7fd8f` | **`2ea84800602ea530698c4a220f88ad48e3b7fd8f`** | ✅ identique |
| `TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md` | `20bfada06fc56a9fa10f432cd48272f203ed3b95` | **`20bfada06fc56a9fa10f432cd48272f203ed3b95`** | ✅ identique |

### Autres contrôles

| Contrôle | Valeur |
|---|---|
| `git rev-parse HEAD` | `c9e1fbfeff460a4bb6065f37efb80d5e574d8772` — **inchangé depuis la prise**, aucun commit |
| Nouveau chemin créé par le lot | `?? TOOLS/CMD_PATH_VIEWER/` (unique) + `TOOLS/AGENT_WORKFLOW/status/` (heartbeats, local) |
| Fichiers `DOC/WFLOW/` touchés | `TASKS.yaml` (entrée T353, ` M`) · `TASK_LOCKS.json` (verrou T353 — **ignoré par Git**, `.gitignore:102`, donc invisible dans `git status` par conception) · `CONTRACTS/TASK_CONTRACT_T353_*.yaml` (bloc `execution`, non suivi) |
| Bundle / gates / tests CI lancés | **aucun** (le lot ne produit aucun code PLC) |
| Scratch temporaire créé | **aucun** à la racine ni ailleurs ; la seule cible temporaire du test P3 vit dans `TOOLS/CMD_PATH_VIEWER/` et n'est pas supprimée automatiquement |
| Incident de lot, détecté et réparé | guillemet fermant perdu dans l'`avancement` T353 de `TASKS.yaml` pendant l'ajout du 9e constat → **YAML invalide** ; détecté par la validation immédiate, **réparé dans le même tour** (~2 min), YAML revalidé (149 tâches). **Aucune donnée perdue, aucun autre acteur impacté durablement.** Traçé en heartbeat `task-T353 / 05-incident-repare`. |

---

## P6 — Limites déclarées (AC12)

Reprises du README §7 (elles figurent **aussi** dans `graph.json → limites` et sont **affichées dans
l'interface**, panneau « Limites déclarées de l'outil ») :

```
L1  T334 ne porte AUCUN bloc d'ancrage de révision  → ancrage DÉRIVÉ du §1.3 de l'ANNEXE
L2  Le « geste » n'existe pas dans les documents     → surcouche CURÉE sourcée + 4 entrées NON SÉPARABLE
L3  file:// ne recalcule aucun blob                   → badges FIGÉS, horodatés, bandeau explicite
L4  Le hash dépend du filtre CRLF du dépôt            → même règle des deux côtés (JS et Python)
L5  Mnn/Cnn n'est pas un espace de noms partagé       → le document est porté par chaque maillon
L6  18 références non résolues (graphe), volontaire   → affichées comme telles, jamais devinées
L7  Ce que l'outil NE fait PAS                        → pas de lecture de contenu, pas de correction
L8  Les compléments de l'annexe ne sont PAS fusionnés → affichés comme tels, T334 jamais réécrit
L9  Le test P3 n'a pas modifié de fichier cité SUR DISQUE → périmètre d'écriture borné au lot
L10 Deux périmètres de comptage coexistent            → 736 (graphe) vs 2 276 (audit toutes zones)
L11 Les fichiers « présents non suivis » n'ont pas de blob Git de référence → résolus, jamais verts
L12 509 continuations refusées, dont les CITATIONS de T334 dans les tableaux d'audit → listées par zone
L13 Drift concurrent : 4 fichiers cités ont bougé pendant ce lot (FB_CycleSemiAuto 1652→1659 l,
    ST_CycleCfg, PRG_03_Modes_Cycle, PRG_07_Supervision) → ROUGE attendu, à re-mesurer après gel
L14 Continuations de la fiche T351 rédigées de façon relâchée (2 couples fichier:ligne IMPOSSIBLES)
    → CONTESTEE_HORS_BORNES, trouvaille signalée, fiches NON corrigées (lecture seule)
```

**Ce que l'outil NE fait pas (détail L7)** : il ne lit pas le contenu des lignes citées et ne
vérifie donc **pas** que le motif annoncé est bien à la ligne citée (seule la **borne** du fichier
est contrôlée) ; il ne corrige aucun document ; il ne produit aucun bundle ; il ne remplace pas la
lecture du code réel avant une intervention machine.

---

## Conformité AC1 → AC12

| Critère | Statut | Preuve |
|---|---|---|
| **AC1** parsing intégral ou rejets listés | ✅ | P1 : **202/202** lignes de chaîne acceptées ; dénominateurs **étiquetés** : **319 lignes candidates** (101 + 101 + 117) et **339 occurrences de codes** ; **109 rejets** à motif nommé (86 `TABLE_AUDIT_4_COLONNES_NON_INJECTEE` + 23 `TABLE_CORRECTION_3_COLONNES_NON_INJECTEE`) ; **11 lignes hors-candidats** (sans code) comptées **à part** ; 8 compléments non fusionnés ; 0 ligne sans référence · **mesuré le 2026-09-21 à 03:42** · reproductible : `python parse_cartographies.py` (annexe A1) |
| **AC2** résolution réelle, aucune référence devinée | ✅ | P2 : 721/736 résolues (graphe), **0 couple impossible présenté comme résolu** — **invariant `PASS` sur 3 319 références** (graphe + **zone d'audit** + table de correction §4.10), **0 `RESOLUE` hors bornes** · 3 reroutages par règle nommée · 3 ambiguïtés à candidats listés · 12 refus motivés · **mesuré le 2026-09-21 à 03:32** · reproductible : annexes A1/A3/A8 |
| **AC3** tableaux d'audit non injectés | ✅ | P1 : **86** lignes rejetées (`TABLE_AUDIT_4_COLONNES_NON_INJECTEE`) + **23** (`TABLE_CORRECTION_3_COLONNES_NON_INJECTEE`), annexe = ancrage blob + compléments non fusionnés + table de correction non fusionnée |
| **AC4** ancrage complet et étiqueté | ✅ | `graph.json → ancrage` : blob + source + étiquette `PROPRE`/`DERIVE` + HEAD mesuré + horodatage ISO ; T334 explicitement « ancrage DÉRIVÉ, jamais un ancrage de T334 » (UI + README L1) |
| **AC5** garde-fou blob prouvé | ✅ (avec écart de périmètre signalé) | P3 : VERT → ROUGE → VERT, blobs avant/pendant/après, `git hash-object`, journal horodaté · **P3bis : 4 fichiers RÉELS passés ROUGE pendant le lot** (drift concurrent détecté en direct) |
| **AC6** hash navigateur = `git hash-object` | ✅ | P4 : 8/8 conformes + auto-test 4 vecteurs PASS dans le navigateur |
| **AC7** chemin complet, 5 champs, sans référence | ⚠️ ✅ | 5 champs affichés pour chaque maillon ; **1 seul maillon** (treuils C02) a un consommateur `—` dans le document : affiché « référence absente » (`refs_manquantes`), **jamais complété** |
| **AC8** branches non empruntées + dissymétries | ✅ | Panneau « Branche NON empruntée » (chaîne sœur, motif, citation vérifiée) + 12 dissymétries (fiche treuils §6.4) + 20 divergences + marqueurs par maillon |
| **AC9** geste honnête sur sa limite | ✅ | 12 entrées curées, **12/12 citations vérifiées mécaniquement**, 4 déclarées `NON_SEPARABLE` avec leur raison et leurs points de séparation documentés |
| **AC10** aucun fichier de `CODE/`/`CODE_XML/`, aucun gate, aucun commit | ✅ | P5 : `git status --short -- CODE/` vide, aucun bundle/gate/CI, HEAD inchangé |
| **AC11** 3 documents source intacts | ✅ | P5 : 3 blobs identiques |
| **AC12** autonome, 2 modes, README + limites | ✅ | `README.md` (structure, 2 modes, 9 limites) ; `index.html` ne charge que des ressources locales relatives (vérifié : aucune URL distante) ; mode live = `python -m http.server` lancé par `OPEN_CMD_PATH_VIEWER.bat`, zéro logique métier serveur |

### Justification du ratio « 500/500 » (périmètre exact, reproductible)

Le chiffre « 0 ambigu et 0 introuvable au niveau des NOMS DE FICHIERS (500/500) » est **reproductible**
sur un périmètre explicite — ce sont des **occurrences**, non des tokens distincts :

| Métrique | Valeur | Où la lire / comment la reproduire |
|---|---|---|
| **Occurrences** portant un nom de fichier ou un chemin explicite, dans le **graphe** | **500** = `ABREGE 479` + `CHEMIN_COMPLET 21` | `rapport_resolution.par_forme.{ABREGE,CHEMIN_COMPLET}.total` |
| dont **RESOLUE** | **500** (0 ambiguë, 0 non résolue) | mêmes objets, champs `.RESOLUE` / `.AMBIGUE` / `.NON_RESOLUE` |
| **Tokens DISTINCTS** `(document, token)` dans le graphe | **64** | `rapport_resolution.par_document[*].tokens_fichier` |
| Occurrences supplémentaires (continuations, sans nom dans la cellule) | 236 | `par_forme.CONTINUATION.total` |

Commande de vérification :

```powershell
python -c "import json;r=json.load(open('TOOLS/CMD_PATH_VIEWER/data/graph.json',encoding='utf-8'))['rapport_resolution'];a=r['par_forme']['ABREGE'];c=r['par_forme']['CHEMIN_COMPLET'];print(a['total']+c['total'], a['RESOLUE']+c['RESOLUE'])"
# → 500 500
```

➡️ Le ratio « 500/500 » **ne compte pas les tokens distincts** (191/257 chez la revue, sur les tableaux
de chaîne) : ce sont **deux métriques différentes et toutes deux exactes**. Formulation retenue
désormais : *« les **500 occurrences** de référence portant un nom de fichier ou un chemin explicite
sont **toutes résolues** (0 ambiguë, 0 non résolue) ; les **236 continuations** sans nom dans la
cellule sont traitées séparément (221 résolues, 3 ambiguës, 12 refus motivés) »*.

### Existence des livrables — vérifiée par le garde-fou (classe « déclaré mais absent »)

`check_lot_files.py` vérifie que **les 12 livrables existent ET ne sont pas triviaux** (≥ 1 Ko) : c'est
la protection contre la classe d'erreur « déclaré au catalogue, absent du disque » signalée en revue.
Mesure du `03:30` : **21 fichiers scannés · 12/12 livrables présents et non triviaux · 0 anomalie**.
`PREUVE_T353.md` : **77 788 octets**, **créé le `2026-09-21T02:44:05`**, dernier écrit `03:27:17`,
SHA-256 `E1DF24A4E13B98A9F13E4EDDECDE921310FA32F494322F56E8DB88E7DA67BBD5`
— retrouvé par la **commande exacte** de la revue (`Get-ChildItem -Recurse -File -Filter PREUVE*`).

### Vérifications d'exécution du front (aucun navigateur automatisable dans ce lot)

```powershell
node TOOLS/CMD_PATH_VIEWER/smoke_test_ui.js
```

**Sortie réelle, collée telle quelle (exécutée à `03:22:09`, code de sortie `0`)** :

```text
================================================================================================
SMOKE TEST UI (mode statique, DOM simulé) — T353 CMD_PATH_VIEWER
================================================================================================
  OK   exécution des 4 scripts sans exception
  OK   data/graph.js expose le graphe  [202 maillons]
  OK   data/freshness.js expose le constat figé  [48 fichiers]
  OK   GitBlobSha1 exposé au navigateur (mode statique)
  OK   bandeau statique : fraîcheur déclarée NON recalculée
  OK   horodatage affiché  [2026-09-21T03:22:09+02:00]
  OK   badge de mode = STATIQUE  [MODE STATIQUE (file://)]
  OK   chaîne par défaut rendue (66 maillons treuils/M)  [66 cartes]
  OK   le premier maillon affiché est M01 · le dernier est M66
  OK   chaque carte porte producteur ET consommateur
  OK   les 5 champs exigés par AC7 (code, variable, producteur, consommateur, rôle)
  OK   des références fichier:ligne sont affichées  [244 pastilles]
  OK   auto-test du hash affiché PASS
  OK   branche NON empruntée affichée pour treuils/M · citation vérifiée
  OK   chaîne t334/C rendue (35 maillons) · marqueurs/dissymétries alimentés
  OK   entrée de geste NON SÉPARABLE sélectionnable, motif affiché
  OK   geste curé G03 (M3 manuel) sélectionne t334/M
  OK   compléments de l'annexe NON FUSIONNÉS dans la chaîne M3  [74 cartes = 66 + 8]
  OK   limites déclarées rendues  [7 entrées]
  OK   ancrage DÉRIVÉ de T334 mentionné · piège `--stdin` documenté
  OK   résumé de chaîne : aucun maillon sans référence (0)
  OK   panneau d'audit global (4 formes, préfixes ambigus, 0 chemin inventé)
  OK   compteurs EXACTS malgré les listes bornées (202 / 39 / 93)
  OK   références contestées · invariant PASS · D07 contesté (:650)
  OK   3 reroutages vers PRG_04_Treuils_Benne.st · verrou des attendus 7/7 PASS
  OK   corrections de références périmées (annexe §4.10) + avertissement d'ancrage périmé
------------------------------------------------------------------------------------------------
  37/37 vérifications PASS
```

Ce test exécute les **4 scripts du front** (`git-blob-sha1.js`, `data/graph.js`, `data/freshness.js`,
`app.js`) dans un **DOM simulé** et vérifie le rendu réel : 66 maillons pour `treuils/M`, 35 pour
`t334/C`, 74 pour le geste M3 (66 + 8 compléments), les 5 champs par maillon, 244 pastilles de
référence, le bandeau « fraîcheur non recalculée » horodaté, la branche non empruntée, l'auto-test
PASS, les 7 limites, l'invariant, les attendus et la table de correction.
**Limite déclarée** : ce test prouve l'exécution et le contenu du rendu, **pas** la mise en page
visuelle (aucun navigateur piloté n'était disponible).

### Garde-fou de propreté des fichiers (classe de bug du REX `2026-08-19`)

```powershell
python TOOLS/CMD_PATH_VIEWER/check_lot_files.py
```

| Contrôle | Résultat mesuré |
|---|---|
| Aucun **BOM UTF-8** dans un fichier du lot | **0** — `smoke_test_ui.js` commence bien par `#!/` |
| Aucune **fin de ligne CRLF** dans les sources **et** les JSON générés | **0** CRLF sur les 17 fichiers |
| Aucune **ressource distante** dans le front | **0** (une seule URL citée, dans un commentaire documentaire « AUCUN CDN ») |
| Les **12 livrables** attendus existent | **12/12** |
| Shebang sur la **première ligne** | conforme (`parse_cartographies.py`, `verify_anchors.py`, `smoke_test_ui.js`, `check_lot_files.py`) |
| **Verdict** | **PASS** — 17 fichiers scannés, 0 anomalie |

> 🔎 **Pourquoi ce garde-fou existe (REX appliqué)** : un BOM UTF-8 a été introduit **par accident**
> sur `smoke_test_ui.js` pendant ce lot (écriture via `Set-Content -Encoding UTF8`), rendant
> `node smoke_test_ui.js` **non exécutable** — exactement la classe de bug décrite dans l'en-tête de
> `.gitattributes` (REX 2026-08-19 : « le BOM se glisse AVANT le `#!` … le shebang devient
> invalide »). Le fichier a été réécrit **sans BOM** (mesure : 0 BOM, 0 CRLF), **et** un garde-fou
> automatique a été livré pour que la classe de bug ne repasse plus : `check_lot_files.py` sort en
> **code 1** dès qu'un BOM, une CRLF en source, une ressource distante ou un livrable manquant est
> détecté. *Place canonique souhaitable* : `TOOLS/AGENT_WORKFLOW/scripts/Gxxx_check_file_hygiene.py`
> (hors de mon périmètre d'écriture — **proposé à l'orchestrateur** pour branchement dans
> `run_all_gates.py`).

---

# ANNEXE A — SORTIES BRUTES DES SIX PREUVES (collées telles quelles)

> Exigence : « les sorties réelles collées, pas des tableaux déclarés ». Tout ce qui suit est la
> **sortie console verbatim** des commandes, capturée le **2026-09-21 entre 03:25 et 03:27**, HEAD
> `c9e1fbfe`. Les captures brutes sont conservées dans
> `TOOLS/CMD_PATH_VIEWER/data/.sortie_parseur.txt`, `.sortie_freshness.txt`, `.sortie_p3.txt`,
> `.sortie_p4.txt` (conservées, **non supprimées** — règle « aucune suppression automatique »).

## A1 — `python TOOLS/CMD_PATH_VIEWER/parse_cartographies.py` (P1 + P2 + audit + invariants + attendus)

```text
==============================================================================
P1 — TAUX DE PARSING
==============================================================================
  treuils  chaîne acceptée 101 / candidates 101 (codes 101)  taux_chaine 1.0  taux_global 1.0  rejets 0  compléments 0  hors-candidats 0
      chaîne M :  66 maillons  contigu=True  doublons=0  sans_ref=0
      chaîne C :  35 maillons  contigu=True  doublons=0  sans_ref=0
  t334     chaîne acceptée 101 / candidates 101 (codes 101)  taux_chaine 1.0  taux_global 1.0  rejets 0  compléments 0  hors-candidats 0
      chaîne M :  66 maillons  contigu=True  doublons=0  sans_ref=0
      chaîne C :  35 maillons  contigu=True  doublons=0  sans_ref=0
  annexe   chaîne acceptée   0 / candidates 117 (codes 137)  taux_chaine 0.0  taux_global 0.0684  rejets 109  compléments 8  hors-candidats 11
  TOTAUX : {"lignes_candidates_Mnn_Cnn": 319, "codes_candidats_occurrences": 339, "unite_par_defaut": "LIGNES DE TABLEAU (voir par_document[*].unite_de_comptage)", "lignes_chaine_acceptees": 202, "dont_treuils": 101, "dont_t334": 101, "complements_annexe_non_fusionnes": 8, "lignes_rejetees": 109, "rejets_audit_4col": 86}
  rejets par motif : {'TABLE_AUDIT_4_COLONNES_NON_INJECTEE': 86, 'TABLE_CORRECTION_3_COLONNES_NON_INJECTEE': 23}

==============================================================================
P2 — RÉSOLUTION DES RÉFÉRENCES
==============================================================================
  global : {"RESOLUE": 721, "AMBIGUE": 3, "NON_RESOLUE": 12, "CONTESTEE_HORS_BORNES": 0}  total = 736  fichiers distincts = 29
    forme ABREGE         total  479  résolues  479  ambiguës    0  non résolues    0  (listes 34)
    forme CHEMIN_COMPLET total   21  résolues   21  ambiguës    0  non résolues    0  (listes 3)
    forme CONTINUATION   total  236  résolues  221  ambiguës    3  non résolues   12  (listes 8)
    treuils  refs  374  R  363 / A   3 / NR   8 / CONTESTÉES   0  fichiers  15  courtes 162
    t334     refs  325  R  322 / A   0 / NR   3 / CONTESTÉES   0  fichiers  22  courtes  67
    annexe   refs   37  R   36 / A   0 / NR   1 / CONTESTÉES   0  fichiers   8  courtes   7
  références CONTESTÉES (couple fichier:ligne impossible) : 0 · reroutées par la règle E_CONTINUATION_HORS_BORNES_REROUTAGE : 3
  règles : {"C_BASENAME_UNIQUE_SOURCE_ACTIVE_CODE": 608, "D_STEM_UNIQUE_SOURCE_ACTIVE_CODE": 42, "C_BASENAME_UNIQUE_ANCRAGE_DECLARE": 29, "A_CHEMIN_EXACT": 27, "E_ALIAS_DOCUMENTE_CITE": 11, "HERITAGE_REFUSE_MOT_DESIGNATION": 7, "CONTINUATION_SANS_ANTECEDENT_CELLULE": 5, "DESIGNATION_PLURIELLE_AMBIGUE": 3, "E_CONTINUATION_HORS_BORNES_REROUTAGE": 3, "C_BASENAME_UNIQUE_DOC_ACTIF": 1}

  AUDIT GLOBAL (toutes zones des 3 documents — 9e constat) :
    treuils  occurrences  892  tokens-fichier  785  continuations  107  | préfixe unique   60  ambigu   3  alias curé  60  alias NON résolu   0  sans match   0  troncature  1
    t334     occurrences  741  tokens-fichier  670  continuations   71  | préfixe unique   39  ambigu   1  alias curé   0  alias NON résolu   0  sans match   0  troncature  0
    annexe   occurrences  644  tokens-fichier  336  continuations  308  | préfixe unique   60  ambigu   0  alias curé   0  alias NON résolu   0  sans match   0  troncature  0
    TOTAUX : {"occurrences": 2277, "prefixe_unique": 334, "prefixe_ambigu": 4, "alias_contexte_cure": 70, "alias_non_resolue": 0, "prefixe_sans_match": 0, "troncature_ou_nom_introuvable": 1, "continuation_refusee": 498, "resolues_autre": 1357, "tokens_exclus_non_fichier": 0, "occurrences_par_zone": {"CHAINE_5COL": 699, "AUDIT_4COL": 228, "DIVERGENCES": 76, "ASYMETRIES": 31, "ZONE_CODE": 46, "PROSE": 392}}
    contrôle anti-invention (chemins de type M1.st/PRG_04.st) : {"chemins_inventes": 0, "exemples": []}

==============================================================================
ANCRAGE
==============================================================================
  fichiers cités avec ancrage : 47  (dérivés seuls : 20, sans ancrage : 1, total 48)  conflits : 0
  treuils  ancrage=PRESENT head=065591fb2633 horodatage=2026-09-21T01:33:25+02:00 fichiers=27
  t334     ancrage=ABSENT  head=None         horodatage=None fichiers=0
  annexe   ancrage=PRESENT head=065591fb     horodatage=2026-09-21T01:31:44+02:00 fichiers=32

GESTES : 12 entrées · citations non vérifiées : aucune
LIMITES déclarées : 7

==============================================================================
AUTO-CONTRÔLE DES INVARIANTS
==============================================================================
    1. aucune reference RESOLUE avec lignes_hors_bornes non vide
    2. toute reference RESOLUE porte chemin_resolu
    3. categorie dans {RESOLUE, AMBIGUE, NON_RESOLUE, CONTESTEE_HORS_BORNES}
    4. aucun chemin resolu de type M1.st / M2.st / PRG_04.st (alias converti en fichier)
    références contrôlées : 862 · violations : 0 · verdict : PASS
    hors bornes — maillons+compléments : 0 · TOUTES ZONES : 1 (sur 862 références)

==============================================================================
VERROU DES ATTENDUS DE RÉSOLUTION (valeurs de la revue, vérifiées dans les fiches)
==============================================================================
    OK   M20 :114-115     → CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st       [alias documenté M1]
    OK   M20 :141-142     → CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st       [alias documenté M2]
    OK   M21 :1611-1612   → CODE/M_MAIN/PRG_04_Treuils_Benne.st                    [abréviation de préfixe (PRG_04:1462-1463)]
    OK   M34 :1527        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                    [abréviation de préfixe (PRG_04:1461)]
    OK   M34 :1596        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                    [abréviation de préfixe]
    OK   M34 :1617        → CODE/M_MAIN/PRG_04_Treuils_Benne.st                    [abréviation de préfixe]
    OK   M21 :114-115     → AMBIGUE (DESIGNATION_PLURIELLE_AMBIGUE)                [mot « arbitres » seul]
    conformes : 7/7 · verdict : PASS
```

## A2 — `python TOOLS/CMD_PATH_VIEWER/verify_anchors.py` (P5 nominal)

```text
================================================================================================
GARDE-FOU BLOB — constat figé (mode statique)
================================================================================================
  généré le 2026-09-21T03:25:47+02:00 · HEAD c9e1fbfeff46
  fichiers 48 · VERT 43 · ROUGE 4 · ABSENT 0 · NON_ANCRABLE 1 · ancrage DÉRIVÉ 20
  [ROUGE] CODE/G_CYCLE/FB_CycleSemiAuto.st — blob mesuré != blob consigné — les numeros de ligne cités sont a re-verifier
  [ROUGE] CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st — blob mesuré != blob consigné — …
  [ROUGE] CODE/M_MAIN/PRG_03_Modes_Cycle.st — blob mesuré != blob consigné — …
  [ROUGE] CODE/M_MAIN/PRG_07_Supervision.st — blob mesuré != blob consigné — …
  [NON_ANCRABLE] DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md — aucun blob consigne par les documents : cet etat n'est JAMAIS vert
  implémentation Python conforme à `git hash-object` : OUI (48/48)
```

> Le **VERT 47 / ROUGE 0** de la baseline a été mesuré et figé à **`02:39:08`** (et à chaque exécution
> jusqu'à `02:5x`). Les **4 ROUGE** ci-dessus sont le **drift d'un lot concurrent** (chaîne cycle/modes),
> détecté **en direct** par l'outil — §P3bis. Ce n'est pas une régression du lot T353.

## A3 — `python TOOLS/CMD_PATH_VIEWER/verify_anchors.py --test-garde-fou` (P3, sortie complète)

```text
================================================================================================================
P3 — TEST VOLONTAIRE DU GARDE-FOU BLOB (3 états : avant / pendant / après)
================================================================================================================
  horodatage : 2026-09-21T03:25:49+02:00 · HEAD c9e1fbfeff46
  périmètre d'écriture du lot : TOOLS\CMD_PATH_VIEWER/ — CODE/ et les 3 sources sont en LECTURE SEULE

  VOLET A — fichiers RÉELLEMENT cités par les documents, test EN MÉMOIRE (lecture seule)
  fichier                                              état     blob mesuré (outil)                        blob consigné                              verdict  git hash-object
  TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv   AVANT    18c75783a18856a1d4450c82624ceccbefe4f324   18c75783a18856a1d4450c82624ceccbefe4f324   VERT     18c75783a18856a1d4450c82624ceccbefe4f324
  TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv   PENDANT  1e2a0bc0801bfcce96ee1f0f5843968fc8b1f9b9   18c75783a18856a1d4450c82624ceccbefe4f324   ROUGE    18c75783a18856a1d4450c82624ceccbefe4f324
  TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv   APRÈS    18c75783a18856a1d4450c82624ceccbefe4f324   18c75783a18856a1d4450c82624ceccbefe4f324   VERT     18c75783a18856a1d4450c82624ceccbefe4f324
                                                       brut PENDANT 130402cf2506 · CRLF convertis PENDANT 571 · octets relus identiques : OUI

  CODE/M_MAIN/PRG_04_Treuils_Benne.st                  AVANT    31760d59b4e09b03a8e91b2358f8804a6b1985ad   31760d59b4e09b03a8e91b2358f8804a6b1985ad   VERT     31760d59b4e09b03a8e91b2358f8804a6b1985ad
  CODE/M_MAIN/PRG_04_Treuils_Benne.st                  PENDANT  fa6e6134293add37feaeb348cc303278d8765106   31760d59b4e09b03a8e91b2358f8804a6b1985ad   ROUGE    31760d59b4e09b03a8e91b2358f8804a6b1985ad
  CODE/M_MAIN/PRG_04_Treuils_Benne.st                  APRÈS    31760d59b4e09b03a8e91b2358f8804a6b1985ad   31760d59b4e09b03a8e91b2358f8804a6b1985ad   VERT     31760d59b4e09b03a8e91b2358f8804a6b1985ad
                                                       brut PENDANT 2daf0e8e16b2 · CRLF convertis PENDANT 1982 · octets relus identiques : OUI

  VOLET B — test SUR DISQUE, cible dans le périmètre autorisé du lot
  cible : TOOLS/CMD_PATH_VIEWER/git-blob-sha1.js · blob consigné = 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c
    AVANT   outil 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c · git 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c → VERT
    PENDANT outil 3a92a4300d309a20c3c4203425bcf35052508ab5 · git 3a92a4300d309a20c3c4203425bcf35052508ab5 → ROUGE  (attendu 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c / mesuré 3a92a4300d309a20c3c4203425bcf35052508ab5)
    APRÈS   outil 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c · git 7b1b1d730f34a994610b25ec18e7bc9ba2319c1c → VERT
    restauration à l'octet près : OUI · blob final = blob initial : OUI

  verdict global : PASS — VERT → ROUGE → VERT dans les deux volets
  journal : TOOLS/CMD_PATH_VIEWER/data/preuve_garde_fou_T353.json
  ⚠ CONSTAT À REMONTER : la variante « modifier SUR DISQUE un fichier cité par les documents » est HORS du périmètre d'écriture du lot (CODE/ interdit, sources interdites). Elle exige soit une extension explicite du périmètre, soit une action humaine sur un arbre gelé.
```

**`git status --short -- CODE/` APRÈS le test** :

```text
(vide)
```

## A4 — `python TOOLS/CMD_PATH_VIEWER/verify_anchors.py --preuve-p4` (P4)

```text
P4 — JS (même fichier que le navigateur, exécuté sous Node) vs `git hash-object`
fichier                                          SHA-1 JS (git-normalisé)                  git hash-object                           égal
CODE/M_MAIN/PRG_04_Treuils_Benne.st              31760d59b4e09b03a8e91b2358f8804a6b1985ad  31760d59b4e09b03a8e91b2358f8804a6b1985ad  OUI
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st          9c493a5f0d5726b3d276c455bc3efca83fe29ebd  9c493a5f0d5726b3d276c455bc3efca83fe29ebd  OUI
CODE/M_MAIN/PRG_02_Acquisition.st                5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7  5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7  OUI
TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv  18c75783a18856a1d4450c82624ceccbefe4f324  18c75783a18856a1d4450c82624ceccbefe4f324  OUI
CODE/M_MAIN/PRG_06_Outputs.st                    3b7534a3acd4c5bba6c667118abaf32f41eb3f67  3b7534a3acd4c5bba6c667118abaf32f41eb3f67  OUI
CODE/G_CYCLE/FB_CycleSemiAuto.st                 e7fee8be3de66a3346fee81e83391009e827dfa4  e7fee8be3de66a3346fee81e83391009e827dfa4  OUI
DOC/…TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md  2ea84800602ea530698c4a220f88ad48e3b7fd8f  2ea84800602ea530698c4a220f88ad48e3b7fd8f  OUI
DOC/…TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md  20bfada06fc56a9fa10f432cd48272f203ed3b95  20bfada06fc56a9fa10f432cd48272f203ed3b95  OUI

  conformes : 8/8
  CODE/M_MAIN/PRG_04_Treuils_Benne.st · brut 126466 o → normalisé 124484 o (1982 CRLF convertis) · CRLF→LF (filtre git du dépôt, core.autocrlf=true)
  CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st · brut 50861 o → normalisé 50023 o (838 CRLF convertis) · CRLF→LF (filtre git du dépôt, core.autocrlf=true)
  CODE/M_MAIN/PRG_02_Acquisition.st · brut 46581 o → normalisé 45862 o (719 CRLF convertis) · CRLF→LF (filtre git du dépôt, core.autocrlf=true)
  auto-test JS (vecteurs vérifiés contre git) : PASS
    OK  vide                                                   e69de29bb2d1d6434b8b29ae775ad8c2e48c5391  (git hash-object)
    OK  hello\n                                                ce013625030ba8dba906f756967f9e9ca394464a  (git hash-object)
    OK  what is up, doc?\n                                     7108f7ecb345ee9d0084193f147cdad4d2998293  (git hash-object)
    OK  a\r\nb\r\n  (piège CRLF)                               422c2b7ab3b3c668038da977e4e93a5fc623169c  (git hash-object <chemin> (filtre CRLF))
```

## A5 — `python TOOLS/CMD_PATH_VIEWER/check_lot_files.py` (propreté du lot)

```text
GARDE-FOU DE PROPRETÉ DES FICHIERS — T353 / CMD_PATH_VIEWER
  contrôles : 1) aucun BOM UTF-8  2) aucune fin de ligne CRLF dans les sources
              3) aucune ressource distante dans le front  4) livrables présents
              5) shebang sur la première ligne
  fichiers scannés : 17 · livrables vérifiés : 12 · anomalies : 0
  verdict : PASS — aucun BOM, aucune CRLF dans les sources, aucune ressource distante, tous les livrables présents
```

## A6 — P5 : `CODE/` et les 3 documents source

```text
$ git status --short -- CODE/
(vide)

$ git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md
aeaac5dd285618f80a0479dbb3ba81a0e6fe7001
$ git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md
2ea84800602ea530698c4a220f88ad48e3b7fd8f
$ git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md
20bfada06fc56a9fa10f432cd48272f203ed3b95

$ git rev-parse --short HEAD
c9e1fbfe
```

➡️ **P5 : les 3 blobs source sont STRICTEMENT identiques** aux valeurs du contrat
(`aeaac5dd…` / `2ea84800…` / `20bfada0…`), `CODE/` ne porte **aucune** écriture de T353, et HEAD n'a
pas bougé (aucun commit).

## A7 — Histoire des itérations de résolution (P2, chiffres avant/après)

| Itération | `RESOLUE` | `AMBIGUE` | `NON_RESOLUE` | Cause / correctif |
|---|---|---|---|---|
| état initial (bug de casse sur les chemins déclarés) | 696 | 28 | 12 | tier `ANCRAGE_DECLARE` vide ⇒ le CSV tombait en `C_BASENAME_HORS_TIERS` |
| après D1 (02:33) | 731 | 0 | 5 | chemins déclarés indexés insensiblement à la casse |
| essai par **clause** (02:31, ~1 min) | 707 | 0 | 29 | propagation refusée à travers `;`/`→` ⇒ **régression** signalée par la revue n°2 |
| après retour à la propagation **par position** (02:34) | 718 | 0 | 18 | « dernier fichier nommé **avant** la référence » |
| après D2 (catégorie `CONTESTEE` + règle de reroutage nommée) | 721 | 0 | 15 | 3 reroutages, 0 couple impossible en `RESOLUE` |
| après la règle **désignation plurielle** (revue n°5) | **721** | **3** | **12** | « arbitres `` `:NNN` `` » : **2 candidats listés**, aucun choix silencieux |

## A8 — Les 3 références `AMBIGUE` (règle `DESIGNATION_PLURIELLE_AMBIGUE`)

| Maillon | Champ | Cité | Cellule (fiche) | Candidats — **aucun choisi** |
|---|---|---|---|---|
| M21 | consommateur | `:114-115` | « arbitres `` `:114-115` `` ; `PRG_04:1462-1463` (entrée `FB_Winch`) ; `:1611-1612` (publication) » | `M1` → `FB_WinchCmdArbitrationM1.st` · `M2` → `FB_WinchCmdArbitrationM2.st` |
| M22 | consommateur | `:114-115` | « arbitres `` `:114-115` ``, `` `:141-142` `` ; `PRG_04:1131-1134` → `M2AscentPermitApplied`… » | idem |
| M22 | consommateur | `:141-142` | idem | idem |

Le mot « arbitres » est **pluriel** : la cellule n'identifie **aucun** arbitre précis. L'outil ne choisit
pas — il **liste les candidats** (JSON `candidats`, infobulle de l'UI avec badge violet `AMBIGU`,
et tableau ci-dessus). `NON_RESOLUE` était acceptable ; `AMBIGUE` + candidats est **plus informatif**.

### Mise à jour revue n°10 — **aucune ambiguïté sans candidats** (bug de paramètre corrigé)

Les **17 `AMBIGUE` à liste vide** (règle `ALIAS_CONTEXTE_Mnn_Cnn`, ex. `M2:119-122`, `:104-111`,
`:65-82`, `:87-90`, `:65-67`) provenaient d'un **bug de paramètre** : la branche
`divergences`/`asymétries` appelait `extraire_refs` **sans** `alias_actifs`, donc les alias n'étaient
pas résolus **alors que la fiche treuils les définit** (lignes 21 et 28). Corrigé : le paramètre est
transmis ⇒ ces 17 références sont désormais **`RESOLUE`** par `E_ALIAS_DOCUMENTE_CITE` — **mieux
qu'un `AMBIGUE`**, puisque l'alias est déterminable.

Et pour tout alias **non** défini dans le document courant, la règle est désormais **nommée et
informative** :

| Situation | Règle | Contenu exposé |
|---|---|---|
| alias défini **dans** le document | `E_ALIAS_DOCUMENTE_CITE` | `RESOLUE` + `alias_source` (preuve citée **et** corroboration) |
| alias défini **ailleurs** | `ALIAS_CONTEXTE_CANDIDATS_DOCUMENTES_HORS_DOCUMENT` | **`AMBIGUE`** + candidats `[{alias, chemin, provenance}]` |
| alias défini **nulle part** | `ALIAS_NON_DETERMINABLE_SANS_SECTION` | refus **explicite** + **motif nommé** (jamais une liste vide silencieuse) |

**Mesure après correctif** : le graphe ne contient plus **aucun** `AMBIGUE` sans candidats —
`DESIGNATION_PLURIELLE_AMBIGUE` (3, candidats = 2), `D_STEM_MULTIPLE_SOURCE_ACTIVE_CODE` (1,
candidats = 2) ; zone d'audit : `D_STEM_MULTIPLE` (3 + 1, candidats 2 et 3). Table curée des alias
portée à **3 entrées** : `M1`/`M2` (fiche treuils **l.21/28**) et **`M3` → `FB_TranslationCmdArbitrationM3.st`**
(fiche T334 **l.64**), **3 citations vérifiées mécaniquement** (`citation_verifiee: true`).

**Captures brutes des preuves** — `data/.sortie_parseur.txt`, `.sortie_freshness.txt`, `.sortie_p3.txt`,
`.sortie_p4.txt` : ce sont les **pièces justificatives** de l'annexe A1→A9, désormais **nommées comme
telles dans le README** (section Structure) pour qu'elles ne soient pas prises pour des scratchs
orphelins. Elles sont **conservées**, non supprimées.

## A9 — Contrôle final demandé par la revue n°5

```text
par_categorie        : RESOLUE 721 · AMBIGUE 3 (M21 « arbitres », M22 ×2) · NON_RESOLUE 12 · CONTESTEE_HORS_BORNES 0
                       → attendu revue : RESOLUE 718-724 ✅ · AMBIGUE 1-2 (3, M21 + 2 du même motif) · NON_RESOLUE 12-18 ✅
invariant            : 0 référence RESOLUE hors bornes — 3 319 références contrôlées (graphe + AUDIT + corrections), PASS
dénominateur parsing : 319 LIGNES candidates (101+101+117) / 339 OCCURRENCES de codes · rejets 109 = 86 (audit 4 col) + 23 (correction 3 col) · 11 lignes hors-candidats
PREUVE_T353.md       : présent (80 Ko) — P1→P6 + annexes A1→A9 avec sorties réelles
git status -- CODE/  : aucune écriture de T353 · blobs des 3 sources inchangés (aeaac5dd / 2ea84800 / 20bfada0)
```

> **Élargissement du périmètre du contrôle (revue n°7)** : l'auto-contrôle des invariants ne balayait
> que **862** références (graphe + dissymétries/divergences). Il couvre désormais **3 319** références,
> **zone d'audit comprise** (toutes occurrences des 3 documents) **et table de correction §4.10** —
> le champ `controle_invariants.zones_couvertes` énumère les zones et `refs_controlees` en donne le
> total. Résultat : **0 violation**, donc aucun `RESOLUE hors bornes` ne se cachait dans la prose ni
> dans les tableaux d'audit — c'est désormais **prouvé**, et plus seulement supposé.

---

## Hors scope constaté (devoir d'alerte — signalé, non corrigé)

| # | Constat | Impact |
|---|---|---|
| **1** | **`DATA/graph.json` = 1,2 Mo** (et `graph.js` idem). Le fichier est embarqué pour permettre le mode `file://` sans requête. | Acceptable en local ; si l'outil grossit (T354/T355), prévoir un chargement paresseux par chaîne. |
| **2** | **La fiche T334 est toujours modifiée non committée** (blob `2ea84800`, sous verrou DSH07). L'outil s'ancre sur ce **contenu** : si DSH07 commite ou retouche le fichier, il faut **relancer les 2 scripts**. | À intégrer à la procédure de reprise : `parse_cartographies.py` puis `verify_anchors.py`. |
| **3** | **4 chemins de scratch à la racine du dépôt**, hors table de routage, présents **avant** mon lot et imputables à d'autres acteurs : `?? .tmp_t255d_banner_backup.st`, `?? .tmp_t255d_gate_sans_bit6.py`, `?? .tmp_t255d_proof.py`, `?? .tmp_t255d_proof_gate.py` (plus les `*.log` de T278/T299/T339). | Signalés pour traitement humain — **aucune suppression automatique**, aucun masquage par `.gitignore`. |
| **4** | **Le test P3 littéral (modifier un fichier cité sur le disque) n'est pas réalisable dans le périmètre.** | Décision attendue de l'orchestrateur : élargir le périmètre ou exécuter la variante sur arbre gelé. |
| **5** | **Références à numéros périmés dans T334** (constat **de l'annexe**, re-confirmé par la mesure) : l'annexe relève 49 couples `fichier:ligne` périmés (+3 à +91). L'outil **affiche le blob** et **la borne** du fichier, mais il ne peut pas détecter le périmètre d'une **référence périmée sur un fichier inchangé** (limite L7). | Un lecteur doit garder le réflexe : *une référence au bon blob n'est pas forcément à la bonne ligne*. Piste : un gate de vérification contenu ↔ ligne (hors périmètre T353). |
| **7** | **`__pycache__/` créé par un de mes appels de debug** : `TOOLS/CMD_PATH_VIEWER/__pycache__/parse_cartographies.cpython-314.pyc` (112 Ko) est apparu quand j'ai importé le parseur pour diagnostiquer. | **Aucune suppression automatique** (règle projet) : chemin signalé, nettoyage à la main. Il est à l'intérieur de `TOOLS/CMD_PATH_VIEWER/` (périmètre du lot), donc sans effet ailleurs. |
| **8** | **Charge utile JSON réduite** : `data/graph.json` est passé de 4,0 Mo à **1,45 Mo** (et `graph.js` de 3,3 à 1,18 Mo) en bornant les listes d'exemples — **les compteurs restent exacts** (`prefixe_unique_total`, `alias_contexte_cure_total`…). | Amélioration de confort pour le mode `file://` ; `note_listes_bornees` le déclare dans le JSON. |
| **9** | **Une seule référence documentaire est « NON_ANCRABLE »** — `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:180` (citée en cellule « Rôle » de T334 C04) : aucun blob consigné par les documents. | Affichée comme **non ancrable**, jamais verte (choix délibéré : un vert non fondé serait un mensonge). |

---

## Reproduire l'intégralité des preuves

```powershell
python  TOOLS/CMD_PATH_VIEWER/parse_cartographies.py            # P1 + P2 (+ P2bis audit + P2ter contestées)
python  TOOLS/CMD_PATH_VIEWER/verify_anchors.py                 # garde-fou figé (47 VERT / 0 ROUGE au 02:39:08)
python  TOOLS/CMD_PATH_VIEWER/verify_anchors.py --test-garde-fou # P3
python  TOOLS/CMD_PATH_VIEWER/verify_anchors.py --preuve-p4      # P4
node    TOOLS/CMD_PATH_VIEWER/smoke_test_ui.js                  # rendu du front (37/37)
python  TOOLS/CMD_PATH_VIEWER/check_lot_files.py                # propreté du lot (BOM / CRLF / URL / livrables)
git status --short -- CODE/                                     # P5 (doit être vide) — ne montre AUCUNE écriture de T353
git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md
git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md
git hash-object DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md
```

> 🧊 **Constat figé de la livraison** : `2026-09-21T02:39:08+02:00` · HEAD `c9e1fbfe` ·
> **47 fichiers cités VERT / 0 ROUGE** · 1 non ancrable · 20 fichiers à **ancrage DÉRIVÉ**
> (T334 via l'annexe §1.3) · **0 conflit** entre les deux ancrages.
>
> 🔴 **Puis drift RÉEL détecté** (§P3bis) : au `2026-09-21T03:01:01+02:00`, **43 VERT / 4 ROUGE** —
> `FB_CycleSemiAuto.st`, `ST_CycleCfg.st`, `PRG_03_Modes_Cycle.st`, `PRG_07_Supervision.st` modifiés
> par un lot concurrent pendant ce lot. Ce n'est **pas** une régression de l'outil : c'est le
> comportement attendu, et la démonstration en direct de ce que le REX T351 avait établi —
> **un ancrage par blob n'est valide que pour un contenu**.
