# 🧭 Standards Qualité Code — Référentiel Universel

> 📌 **Propriétaire unique** des règles de déclaration, de liaison et de POO du projet.
> Tout autre document (skill CODESYS, `CODE_WRITING_POLICY`, prompts Pi) **renvoie ici**
> au lieu de reformuler — une règle écrite deux fois dérive toujours.
> Portée : tout agent (Claude, Codex, Gemini/antigravity), tout workflow, et l'humain.

**Répartition des rôles — ne pas chercher ailleurs :**

| <nobr>Sujet</nobr> | Document |
|---|---|
| <nobr>Comment on **nomme**</nobr> | `DOC/STDS/NAMING_CONVENTION.md` |
| <nobr>Comment on **déclare, encapsule, relie**</nobr> | **ce document** |
| <nobr>Comment on **édite une AF**</nobr> | **ce document §0** |
| <nobr>Comment on **teste/vérifie**</nobr> | `DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md` |
| <nobr>Contrats FB, DUT et CFC</nobr> | `DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md` |
| <nobr>Ce que fait la machine</nobr> | `DOC/` — voir `DOC/README.md` pour l'index complet |
| <nobr>Comment on exécute une modif</nobr> | `.claude/skills/codesys-workflow.md` |

---

## 0. Rédaction et Édition des Analyses Fonctionnelles (`DOC/AF/`)

1. **Emplacement & Versionnement** :
   - Toute spécification vit sous `DOC/AF/`.
   - Une modification d'exigence métier impose une nouvelle version (`_vX.Y.md`). L'ancienne version est déplacée dans `ARCHIVES/Doc/`.
2. **Structure d'une AF** :
   - 📌 Sommaire & Rôle Machine
   - 🧪 **Points de Validation (`TC-Pxx-nnn`)** (juste après le sommaire, obligatoire)
   - 🧱 Interfaces & DUTs
   - ⚙️ Chronogrammes & Logique métier
3. **Règle des Identifiants de Validation (`TC-Pxx-nnn`)** :
   - **Format** : `TC-P<Partie>-<Numéro>` (ex: `TC-P01-010`, `TC-P10-010`).
   - **Numérotation par pas de 10** (`010`, `020`, `030`) pour autoriser les insertions sans dénumérotation.
   - **Immuabilité stricte** : Un identifiant supprimé/obsolète n'est **jamais réattribué** à un nouveau test.
   - **Formulation synthétique** : Regrouper les sous-conditions logiques par grand test fonctionnel au lieu de multiplier les micro-variables.
4. **Formatage Ultra-Compact des Tableaux de Validation TC** :
   - **ID Mono-Ligne** : L'ID doit être encadré par `<nobr><code>TC-Pxx-nnn</code></nobr>` (pas de retour à la ligne sur les tirets).
   - **Intitulés Denses** : Colonnes compactes (`<nobr>ID Unique</nobr>`, `Groupe`, `Comportement Attendu`, `<nobr>Type</nobr>`, `<nobr>Réf FB</nobr>`).
   - **Réf FB Compacte** : Utiliser `<small>` avec découpage multi-lignes `<br>` (ex: `<small><code>FB_A</code><br><code>FB_B</code></small>`) pour réduire la largeur.
   - **Densité Texte** : Descriptions denses et directes (1 à 2 phrases max) pour supprimer les marges et la hauteur inutiles.
5. **Représentation du Flux de Données & Séquencement FB (Cartes Compactes & Flèches Vectorielles SVG)** :
   - **Combinaison Zéro-Marge & Flèches Vectorielles** : Cartes HTML ultra-compactes (`padding: 6px 10px`) associées à de vraies flèches vectorielles SVG colorées (`<svg>`).
   - **Émoji collé directement à gauche** : Émoji sur la même ligne avec espace fixe devant le nom (`🛡️ &nbsp;<b>FB_Safety_Translation</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Rôle</span>`).
   - **Flèches Vectorielles & Contrats Explicites** : Éléments vectoriels `<svg>` colorés selon le domaine métier et étiquette explicite du signal transmis.
   - *(Référentiel d'édition complet : [`DOC/STDS/GUIDES/GUIDE_EDITION_AF_v1.0.md`](GUIDES/GUIDE_EDITION_AF_v1.0.md))*.
6. **Cartouche d'Entête des Fichiers Code ST (`CODE/*.st`) & Cohérence AF Stricte** :
   - **Concisions & Longueur Maximale (≤ 15 lignes)** : Le cartouche d'entête doit être **ultra-concis, direct et fonctionnel**. Il comporte au maximum 15 lignes de commentaires.
   - **Purge Absolue du Journal de Chantier / REX** : **Zéro historique REX, dates de correctifs terrain ou compte-rendus d'incidents** dans le cartouche d'entête du code ST (ex: ❌ *« REX 2026-07-01 bug corrigé... »*, ❌ *« ÉVOLUTION D72 suite retour terrain... »*). Tout l'historique vit exclusivement dans `DOC/VERSION_HISTORY.md`, `DOC/AF/` et Git.
   - **Structure Multi-Lignes & Liste Blanchie d'Emojis** : Tout fichier ST commence par un cartouche structuré utilisant **exclusivement** les émojis de la liste blanchie du projet, validée empiriquement dans l'éditeur et la visualisation CODESYS 3.5 (aucun carré vide) :
     ```pascal
     (* =======================================================================
        🛡️ FB_Safety_Translation — Anti-télescopage & Verrouillage M3
        ───────────────────────────────────────────────────────────────
        🎯 Rôle : Anti-télescopage Benne/Translation et verrous de sécurité M3
        🔒 Polarité : MaintainA/B_RQ en maintien (TRUE = voie saine)
        🔌 Architecture : Composition interne Logic/Output
        📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
        ======================================================================= *)
     ```
   - **Guide des Émojis Blanchis Autorisés (whitelist CODESYS projet)** :
     - `🎯` = Rôle principal du composant (recopié de l'AF).
     - `📄` = Référence exacte à la spec métier active dans `DOC/AF/`.
     - `🛡️` = Bloc ou fonction de Sécurité Machine.
     - `🔒` = Polarité, invariant de sécurité ou verrouillage / interlock.
     - `🔌` = Interface matérielle ou bus de données DUT.
     - `📥` = Section Entrées / Acquisition.
     - `📤` = Section Sorties / Ordres Actionneurs.
     - `⚙️` = Machine d'état / Calcul interne.
     - `📊` = Diagnostic / Mesures.
     - `💾` = Donnée Persistante (`GVL_PERSISTENT`).
     - `🧪` = Mode Test / Simulation.
     *(Whitelist validée en visualisation CODESYS du projet. Tout émoji qui s'afficherait en carré vide `` selon la police Windows CODESYS est proscrit et doit être retiré sur signalement terrain.)*
   - **Source Unique de Vérité (Zéro Dérive)** : Le titre et le rôle décrits dans le cartouche d'entête `.st` doivent être **recopiés à l'identique** depuis l'AF spécifiée (`DOC/AF/`). Le script d'audit valide automatiquement cette cohérence.

1. Le nom dit **le rôle**, jamais le type (`bFlag` ❌, `iCounter` ❌ — le type se lit en déclaration).
2. Le nom se lit **sans le commentaire d'à côté**. Si le commentaire répète le nom, le nom est mauvais.
3. Une notion = **un seul nom** dans tout le projet (jamais `BrakeIsOpenConfirmed` à côté de `BrakeCommandOpenConfirmed`).

Détail complet (préfixes, suffixes d'unité, polarité booléenne, construction instance→champ) :
`DOC/STDS/NAMING_CONVENTION.md`.

---

## 2. Déclaration — ce qu'un automaticien vérifie sans y penser

- **Ordre immuable des blocs de déclaration** :
  1. `VAR_INPUT` (Entrées)
  2. `VAR_OUTPUT` (Sorties)
  3. `VAR_IN_OUT` (Bus et structures partagées)
  4. `VAR` (Sous-instances FB puis variables locales internes)
  5. `VAR_STAT` / `VAR CONSTANT` (Si applicables)

- **Flèches ASCII de flux et Tags de rôle en visualisation CODESYS** :
  Pour maximiser la lisibilité en mode Watch / Visualisation CODESYS 3.5 et identifier immédiatement le flux de données :
  - **Entrées (`VAR_INPUT`)** : Flèche `-->` suivie du tag `[CMD]` (commande), `[CFG]` (réglage), `[HW]` (matériel/capteur), `[SAFE]` (sécurité/permis), ou `[TST]` (bypasses/tests).
  - **Sorties (`VAR_OUTPUT`)** : Flèche `<--` suivie du tag `[STAT]` (état/synoptique), `[ACT]` (ordre actionneur), ou `[DIAG]` (diagnostic/mesure).
  - **In/Out (`VAR_IN_OUT`)** : Flèche bidirectionnelle `<->` suivie du tag `[BUS]`.
  - **Instances FB (`VAR`)** : Étoile `*` suivie du tag `[INST]`.
  - **Variables Locales (`VAR`)** : Point `.` suivi du tag `[LOC]` (⚠️ **Ne JAMAIS utiliser `[INT]`** pour éviter la confusion avec le type de donnée `INT` / Integer IEC 61131-3 !).

- **Sous-groupage par Bannières ASCII** :
  À l'intérieur de chaque bloc (`VAR_INPUT`, `VAR_OUTPUT`, `VAR`), les variables sont regroupées par sous-domaines fonctionnels précédés d'une bannière ASCII `// === TITRE ===`.

- **Exemple de déclaration cible conforme** :
  ```pascal
  VAR_INPUT
      // === COMMANDES & CONSIGNES ===
      Enable                  : BOOL;   // --> [CMD] Autorisation generale FB (TRUE=Autorise)
      Direction               : INT;    // --> [CMD] Sens demande (-1: Descente, 0: Stop, 1: Montee)

      // === REGLAGES & CONFIGURATION ===
      CfgMaxStepDescente      : INT := 3; // --> [CFG] Plafond palier en descente
  END_VAR
  VAR_OUTPUT
      // === ETATS IEC & SYNOPTIQUE ===
      Ready                   : BOOL;   // <-- [STAT] FB pret a fonctionner

      // === ORDRES ACTIONNEURS (SORTIES TOR) ===
      RelayFwd                : BOOL;   // <-- [ACT]  Ordre contacteur sens montee
  END_VAR
  VAR
      // === SOUS-INSTANCES FB ===
      SpeedStep               : FB_SpeedStep; // * [INST] Decodage paliers vitesse

      // === DETECTEURS & TIMERS INTERNES ===
      ResetEdge               : R_TRIG;       // . [LOC]  Detecteur front montant Reset
      DirectionDelay          : TON;          // . [LOC]  Temporisation d'inversion
  END_VAR
  ```

- **Toute variable est initialisée explicitement** quand sa valeur par défaut n'est pas la valeur
  sûre. Cas vécu : un `BOOL` capteur de sécurité non initialisé démarre à `FALSE` = « défaut »
  permanent (REX `PhaseRotationOk`). Règle : famille sécurité → `:= TRUE` explicite.
- **Aucun nombre magique dans le corps.** Un seuil, une durée, un facteur se déclarent en
  `VAR CONSTANT` nommée (ou en paramètre de config), jamais en littéral au milieu du code.
  Exception admise : `0`, `1`, `TRUE`, `FALSE` et les indices de boucle.
- **Portée minimale.** Dans l'ordre de préférence : variable locale `VAR` → `VAR_INPUT`/`VAR_OUTPUT`
  → GVL. Une GVL ne se crée que pour une **frontière identifiée** (IHM, persistance, simulation,
  image process), jamais comme boîte à variables communes.
- **Une déclaration = un rôle documenté** : unité, plage et polarité en commentaire de fin de ligne
  quand elles ne sont pas évidentes dans le nom.
- **Littéraux STRING en ASCII strict** : un littéral STRING (`'...'`) ne contient **aucun caractère
  multi-octet** (emoji, tiret cadratin `—`, trait de cadre `═`). CODESYS n'interprète pas les STRING
  en UTF-8 par défaut → un caractère multi-octet casse la compilation (C0555 + erreurs en cascade,
  REX 2026-08-17 `FB_Hmi_BannerFormatter`). Les accents latins (é, è, à) sont tolérés ; les emojis
  restent autorisés dans les **commentaires**. Contrôle : `G405_check_st_string_ascii.py`.
- **`VAR_IN_OUT` est réservé** au partage intentionnel et documenté d'un objet. Il ne sert jamais
  à contourner une interface ni à autoriser un second écrivain.
- **`PERSISTENT`/`RETAIN`** : uniquement pour un réglage qui doit survivre à un redémarrage.
  Un paramètre influençant une fonction de sécurité n'est pas rendu réglable sans exigence
  métier validée, bornage et traçabilité.

---

## 2bis. 🧭 Convention des Régions `{region ...}` (Lisibilité Maintenance)

Les régions CODESYS (`{region "..."}` / `{endregion}`) structurent le corps ST en blocs
repliables. Elles **n'ont aucun effet sur la compilation ni la logique** (balises d'éditeur),
mais elles guident la lecture maintenance. Convention projet :

- **Format unique** : `{region "§N <Description concise>"}` — `N` = **numéro de section du corps**
  que le bloc contient (aligné sur les commentaires `// §N` du corps, eux-mêmes référencés par
  les fiches AF). L'ordre des régions suit l'ordre d'exécution du POU.
- **Sous-sections** : `§Nbis`, `§Nter`, `§Nquater` pour un sous-bloc rattaché à `§N`
  (ex. `§1bis Diagnostic modules DI`). Une région peut contenir plusieurs sous-sections du corps
  (ex. une région `§2` contenant `§2` et `§3`).
- **Description** : en français, **courte et TDAH-friendly**, sans REX, date, lot ni récit
  d'essai (même règle que les commentaires, §2ter). Elle nomme le **rôle fonctionnel** du bloc.
- **`{endregion}`** : inchangé, toujours présent pour fermer chaque région.
- **Cohérence globale** : la numérotation `§N` des régions est **alignée sur les sections du corps**
  dans chaque POU ; un POU ne mélange jamais style numéroté et style descriptif.

Exemple conforme :
```pascal
{region "§1 Gate neutralisation"}
...
{endregion}
{region "§2 Reset et arbitrage mode"}
...
{endregion}
{region "§3 Calcul autorisations machine"}
...
{endregion}
```

Contrôle : la numérotation des régions est vérifiée par revue (pas de gate dédié à ce jour).

---

## 2ter. 💬 Politique de Rédaction des Commentaires (Zéro « Journal Intime / REX » dans le Code)

1. **Le Code ST est un Livrable Industriel Client** :
   - Les commentaires dans `CODE/*.st` doivent décrire **exclusivement ce que fait le code**, les plages, unités, algorithmes et rôles physiques.
   - **Interdiction Formelle des Commentaires de type « Journal Intime / REX »** :
     - ❌ *« n'était protégé par AUCUN étage avant ce lot, contrairement à ce qu'affirmait AF... »*
     - ❌ *« suite demande client du 07/08... »*
     - ❌ *« correctif bug trouvé par audit M3... »*
2. **La Traçabilité Vit dans la Documentation** :
   - Tout l'historique des arbitrages, analyses de cause racine, REX, décisions de réunions et comparatifs avant/après est consigné dans `DOC/` (`DOC/VERSION_HISTORY.md`, `DOC/AF/`, `DOC/WFLOW/PLAN_TASK.md`, `ARCHIVES/Doc/AUDIT_*`).
3. **Style de Commentaire dans le Code** :
   - **Concis, direct, TDAH-friendly** avec repères visuels emojis (`🎯 Rôle`, `⚡ Front`, `🔀 Aiguillage`, `📏 Mesure`, `🛡️ Sécurité`).
   - L'explication porte sur le **« Pourquoi » métier / physique**, jamais sur les péripéties de développement passées.

---

## 2quater. Lisibilité des conditions booléennes (REX 2026-08-12)

> 🚨 Cas vécu (`PRG_04_Treuils_Benne.st`) : `M1_StartStop_Active` combine 7 termes
> (`AND`/`OR`/`NOT` imbriqués) sur une seule condition. Impossible en Watch CODESYS de voir
> lequel bloque sans recalculer la condition à la main.

**Règle** : une condition de plus de **3 termes** (comparaisons/`AND`/`OR`/`NOT` chaînés) est
**scindée** en variables `BOOL` intermédiaires nommées (≤3 termes chacune), recombinées ensuite.
Zéro changement fonctionnel — chaque variable intermédiaire devient observable seule en Watch.

**Comparaison brute jamais niée inline.** Une comparaison (`=`, `<>`, `>`, `<`, `>=`, `<=`,
notamment sur un `enum`) qui doit être combinée ou inversée dans une condition composée est
**nommée d'abord**, puis réutilisée — jamais écrite `NOT (Mode = E_Mode.MAINT_N1)` au milieu
d'une condition. Le lecteur lit un fait (`ModeIsMaint1`), il n'a pas à repasser par l'opérateur
de comparaison pour comprendre ce qui est testé.

```pascal
// ❌ 7 termes sur une ligne, comparaison niée inline, illisible en debug
M1_StartStop_Active := (M1_Direction_Active <> 0) AND NOT instBucket.Busy
                        AND NOT CoupledMotionBlockedByBucket
                        AND NOT ((SyncMinorDeviationBlocksUp AND (M1_Direction_Active = 1))
                             OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)))
                        AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.JoystickDeadmanArmed);

// ✅ décomposé, chaque comparaison nommée avant d'être combinée/niée
M1_DirectionRequested  := (M1_Direction_Active <> 0);
M1_BucketFree           := NOT instBucket.Busy AND NOT CoupledMotionBlockedByBucket;
M1_SyncBlocksDirection := (SyncMinorDeviationBlocksUp AND (M1_Direction_Active = 1))
                       OR (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1));
M1_JoystickAuthorized  := NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.JoystickDeadmanArmed;

M1_MotionAllowed    := M1_DirectionRequested AND M1_BucketFree AND NOT M1_SyncBlocksDirection;
M1_StartStop_Active := M1_MotionAllowed AND M1_JoystickAuthorized;
```

📌 **Portée** : s'applique aux **nouvelles écritures et aux refactors futurs**, pas de retouche
rétroactive du code existant à l'occasion de cette règle. Même logique pour la cohérence de
nommage `NAMING_CONVENTION.md` : l'écart déjà présent dans le code (noms longs plutôt
qu'abréviations anglaises courtes) n'est **pas** corrigé maintenant — mais toute variable créée
ou renommée à l'occasion d'un refactor ou d'une nouvelle fonctionnalité **doit** appliquer la
convention de façon cohérente avec le reste du projet, pas seulement localement.

---

## 2quinquies. 🔌 Interfaces Socle des Blocs Fonctionnels (Contrats Light & Standard)

Tout bloc fonctionnel (`FB_*`) relève de l'un des deux contrats d'interface socle formalisés à partir du code existant :

### 1. Contrat `light` (Calculateurs, filtres, utilitaires)
Destiné aux blocs **sans cycle de vie** (filtres, mises à l'échelle, convertisseurs, utilitaires purs)
et qui **ne remontent aucun défaut** — proche d'un FC de calcul.
- **`VAR_INPUT`** : `Enable : BOOL;` (en `BOOL` nu).
- **`VAR_OUTPUT`** : `Ready : BOOL;` (en `BOOL` nu).
- **Principe** : `Enable = FALSE` → sorties neutres/sûres + `Ready := FALSE`. Aucune machine d'état,
  aucun acquittement, aucune sortie d'erreur.
- 🚫 Un bloc qui doit **remonter un défaut** (capteur, calibration, bus) n'est **pas** `light` — c'est
  un `standard` (voir §2).

### 2. Contrat `standard` (Composants métier, séquenceurs, organes, devices)
Destiné aux blocs qui **remontent un défaut** (acquittable ou non) ou pilotent un organe.
- **`VAR_INPUT`** (socle fixe — 2 champs) :
  - `Enable : BOOL;` (en `BOOL` nu : autorisation générale).
  - `Reset : BOOL;` (en `BOOL` nu : acquittement sur front).
- **`VAR_OUTPUT`** :
  - `Ready : BOOL;` (en `BOOL` nu).
  - `Status : ST_FbStatus;` — **forme cible**, remplie via le socle `FB_FbStatus` (§3bis).

> 🎯 **Un device qui remonte un défaut est `standard`, même sans machine d'état.**
> Le critère de classement est **« remonte-t-il un défaut ? »**, pas « a-t-il une machine d'état ? ».
> Ex. `FB_Joystick` (device d'acquisition) remonte un défaut capteur/calibration/bus → il est
> `standard`. `State`/`StateAtError` sont alors remplis par le socle `FB_FbStatus` (valeur par
> défaut `READY`), sans exiger de machine d'état côté FB métier.

> ⚠️ **`PowerContactorEngaged` n'est PAS un champ du socle `standard`.** Ce n'est pas un troisième
> `VAR_INPUT` imposé par défaut — c'est une entrée **conditionnelle**, à ajouter **seulement** si
> le FB pilote lui-même un organe consommant de la puissance (contacteur, frein, moteur) et doit
> en conséquence interlocker sa propre action sur l'état de la chaîne de puissance. `Reset`/`Error`
> (gestion de défaut, ex. calibration, capteur hors plage) est une question totalement indépendante
> de `PowerContactorEngaged` (pilotage d'organe) — les deux ne se déduisent jamais l'un de l'autre.
> Un FB `standard` de pure acquisition/conditionnement qui gère un défaut capteur (donc `Reset`/`Error`
> légitimes) mais ne pilote **aucun** actionneur ne porte **jamais** `PowerContactorEngaged`.
> Ajouter ce champ par réflexe de conformité au tableau, sans vérifier que le FB pilote réellement
> un organe, est une erreur (constaté sur `FB_Joystick` : gate sur `PowerContactorEngaged` sans
> piloter aucun actionneur, forçait le reset du timer d'armement homme-mort pendant toute la
> séquence de réarmement AU). Décision au cas par cas, par FB — jamais par copie du tableau.

> ⏳ **Tolérance transitoire (levée à la clôture de T137)** — les FB antérieurs exposent encore
> l'état/le défaut **à plat** (`Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError` déclarés
> individuellement en `VAR_OUTPUT`, sans `Warning`, sans textes). Cette forme reste acceptée **le
> temps de la migration T137** et **uniquement** pour les FB existants : tout FB **nouveau** porte
> `Status : ST_FbStatus` (forme cible enrichie §3) rempli via `FB_FbStatus` (§3bis).
> Ce n'est pas une seconde forme de conformité permanente — arbitrage du 2026-08-19.
> Le guard `G315_check_fb_interface.py` reconnaît les deux formes et publie leur décompte, ce qui
> mesure l'avancement de T137.

### 3. Structure `ST_FbStatus` (Socle transverse de statut)
La structure `ST_FbStatus` regroupe l'état, le défaut **et** le warning d'un FB `standard`, avec les
**textes prêts pour l'IHM** (plus besoin de conditions complexes côté affichage). Évolution **additive**
par rapport à la forme historique (les 6 membres d'origine sont **conservés** pour ne rien casser) :
```pascal
TYPE ST_FbStatus :
STRUCT
    // ---- membres historiques (conservés, tolérance transitoire T137) ----
    Busy         : BOOL;         // 1 = Bloc en cours d'exécution
    Done         : BOOL;         // 1 = Action terminée avec succès
    Error        : BOOL;         // 1 = défaut à acquitter (laté jusqu'au Reset, ré-alarme si cause revient)
    ErrorId      : WORD;         // code défaut courant (bitfield)
    State        : E_State;      // état courant : DISABLED/INIT/READY/BUSY/DONE/STOPPING
    StateAtError : E_State;      // état mémorisé au moment du défaut
    // ---- membres ajoutés (forme cible enrichie, socle FB_FbStatus §3bis) ----
    Warning        : BOOL;       // 1 = warning actif (auto-effacé, aucun acquittement)
    WarningId      : WORD;       // code warning courant (bitfield)
    WarningIdTxt   : STRING;     // texte généré depuis WarningId (prêt IHM)
    ErrorIdTxt     : STRING;     // texte généré depuis ErrorId
    ResetRequested : BOOL;       // 1 = un Reset est nécessaire / en cours (défaut à acquitter)
END_STRUCT
END_TYPE
```
> 💡 Le mapping IHM lis `Status.ErrorIdTxt`/`Status.WarningIdTxt` directement (textes pré-calculés),
> et si **plusieurs** erreurs/warnings sont actifs, l'affichage **tourne toutes les 1 s** (rotation).

### 3bis. `FB_FbStatus` — socle de remplissage standardisé (forme cible)
Tout FB `standard` remplit son `Status : ST_FbStatus` **via** l'instance d'un socle unique `FB_FbStatus`
(code et comportement standardisés, écrits une seule fois, réutilisés partout). Le bloc métier déclare
**où vit chaque bit d'erreur** et le socle gère l'acquittement, la mémoire et la génération des textes.

```pascal
FB_FbStatus
  IN  Enable          : BOOL;    // autorisation générale
  IN  Reset           : BOOL;    // front acquittement (jamais conditionné, §9)
  IN  ErrorIdCause    : WORD;    // bits d'erreur ACTIFS (cause brute)
  IN  WarningMask     : WORD;    // bit=1 → cette erreur est WARNING (auto) ; bit=0 → FAULT (à acquitter)
  OUT Status          : ST_FbStatus;   // mappé 1:1 sur la sortie `Status` du bloc métier
  OUT Ready           : BOOL;    // en BOOL nu (contrat standard)
```

**Règles de catégorisation (fail-safe)** :
- `WarningMask = 0` (défaut) → **toutes** les erreurs sont des Fault à acquitter = **sécurité maximale**.
- On **lève un bit à 1** dans `WarningMask` pour déclarer cette erreur **Warning** (auto-effacée).
- Un bit est **exclusivement** warning **ou** fault — jamais les deux (un seul masque → pas d'incohérence possible).
- ⚠️ **Exigence de sécurité à tester nommément** (pas seulement en conséquence incidente d'un autre
  test) : `WarningMask` omis ou câblé à `0` doit classer **tout** bit d'`ErrorIdCause` en Fault, jamais
  en Warning. Le nom du test doit porter l'exigence elle-même (ex. `'WarningMask non fourni/à 0 :
  tout défaut classé Fault (fail-safe)'`), pas la déduire d'un test générique sur un autre sujet.

**Comportement** :
- `Warning` : s'affiche et s'efface **seul** avec la cause (`WarningIdCause`). Aucun `Reset` impliqué (§9).
- `Error` : **laté** — reste `TRUE` même si la cause disparaît, jusqu'au front `Reset` ; ré-alarme si la cause revient.
- `ErrorIdLatched` : code du défaut déclenchant **mémorisé** (ne disparaît pas avec la cause) → c'est la
  mémoire nécessaire à l'acquittement.
- `Reset` : **toujours effectif, jamais conditionné** (§9).
- `State`/`StateAtError` : remplis par le socle (valeur par défaut `READY`) — le FB métier n'a **pas**
  besoin de machine d'état pour être `standard` (cf. §2, device qui remonte un défaut). Conséquence :
  pour un FB **standard sans** machine d'état propre (ex. `FB_Joystick`), `StateAtError` vaut donc
  **toujours** `READY` — c'est correct et attendu, pas un défaut. Un FB métier qui possède **sa propre**
  machine d'état (ex. un séquenceur treuil) ne doit **pas** s'appuyer sur `StateAtError` du socle pour
  capturer son propre état au moment du défaut : il doit gérer cette capture lui-même (comme le fait
  déjà `FB_Modes.st`, qui ne passe pas par `FB_FbStatus`) — le socle écraserait sinon la valeur utile
  avec `READY`.
- `Busy`/`Done` : **non gérés par le socle** — `FB_FbStatus` ne pilote que Error/Warning/State/textes.
  Le FB métier appelant reste responsable de renseigner `Status.Busy`/`Status.Done` selon son propre
  cycle : un conditionneur synchrone (ex. `FB_Joystick`) les laisse à `FALSE` ; un organe à cycle
  (ex. un treuil/séquenceur) les pilote lui-même après l'appel du socle.
- Textes : `ErrorIdTxt`/`WarningIdTxt` générés à partir de **tableaux de chaînes** indexés par le code ;
  si **plusieurs** erreurs/warnings actifs, le texte affiché **tourne toutes les 1 s** (rotation).

---

## 3. Liaison — la vérification qui manquait (REX 2026-07-29)

> ⛔ **Un bundle généré, des tests Python verts ou un XML bien formé ne prouvent JAMAIS
> qu'une fonction est reliée au reste du programme.** Ce sont des preuves de forme.
> Le bug de la barrière finale Outputs a franchi tous ces contrôles.

Quatre faits doivent être **prouvés par recherche**, jamais déduits :

1. L'instance est **déclarée** dans le POU qui doit la porter (`Instance : FB_Xxx;` en `VAR`).
2. L'instance est **appelée** — `Instance(...)` — dans le corps du **même** POU, une fois par scan.
3. Elle n'existe **pas en double** ailleurs (déclaration accidentelle dans un autre POU).
4. Toute référence croisée `AutrePOU.instXxx.Champ` pointe une instance **réellement déclarée**
   dans `AutrePOU`, et un nouveau `PROGRAM` est **référencé dans la configuration de tâche**
   CODESYS sous son nom exact.

🤖 **Ce n'est plus à faire de tête** — c'est mécanique et obligatoire :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
```

Le résultat (bloc `Auto-vérification liaison`) est **collé dans la restitution du lot**.
Une restitution sans ce bloc est incomplète, quel que soit l'agent qui l'écrit.

---

## 3bis. Collision de nom avec une variable matérielle (REX 2026-08-05)

> 🚨 **Incident vécu** : `PRG_06_Outputs` déclarait `M3_BrakeRelease_RQ` (et l'équivalent
> M1/M2) en `VAR_OUTPUT` **avec le même nom exact** que la variable globale que CODESYS crée
> lors du mapping E/S physique du device. Un identificateur **local masque toujours un global
> homonyme** (IEC 61131-3) : toute écriture dans ce POU résolvait vers la sortie locale, jamais
> vers la globale réellement mappée au matériel. **Aucune erreur de compilation ni d'import ne
> signale ce piège** — le contacteur frein M3 ne s'est simplement jamais activé, plusieurs
> heures de diagnostic terrain avant identification. Le même schéma touchait aussi la
> **chaîne AU** (`PowerKeepAlive_A_RQ`/`PowerKeepAlive_B_RQ`/`EmergencyArming_RQ`, confirmé
> câblé réel par l'utilisateur) — corrigé dans le même lot. Détail complet et fix :
> `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py`.

**Règle** : un `PROGRAM` ne déclare **jamais** de variable (`VAR`/`VAR_INPUT`/`VAR_OUTPUT`)
portant le **nom exact** d'un point matériel du mapping E/S (`TOOLS/AGENT_WORKFLOW/config/
Device_IO_*.csv`, le plus récent, colonne `Mapped variable`) — sauf `PRG_02_Acquisition`, seul POU dont
le rôle architectural est de porter ces noms bruts en `VAR_INPUT` (AF_Partie-06 §1/§4).

Un `FUNCTION_BLOCK` n'est pas concerné : ses paramètres sont toujours référencés via une
instance (`instXxx.Param`), jamais par un nom nu — pas le même risque de collision de portée.

**Raccordement physique correct** : le mapping E/S CODESYS cible le **chemin qualifié**
(`PRG_06_Outputs.TranslationBrakeCmd`, `PRG_06_Outputs.M1RelayFwd`...), jamais un nom nu
qui recréerait la collision.

🤖 **Vérification automatique** :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G350_check_hw_name_collision.py .
```
Intégré à `run_all_gates.py` (GATE 2quinquies). Toute nouvelle collision est bloquante (`ERROR`).

---

## 4. Code et variables mortes (base MISRA)

- Toute variable déclarée est **lue au moins une fois** hors de son initialisation.
- Toute instance déclarée est **appelée** (§3) — jamais déclarée « pour plus tard ».
- Une branche inatteignable est **supprimée**, pas commentée.
- Un FB qui n'est plus appelé nulle part sort du programme actif ; s'il reste disponible
  comme POU, c'est documenté explicitement.

---

## 5. POO / encapsulation en IEC 61131-3

- **Une responsabilité par objet.** Le propriétaire d'une donnée est le FB qui l'acquiert, la
  calcule ou garantit sa cohérence. Un bloc safety surveille une mesure ; il n'en devient pas
  le producteur par commodité de câblage.
- **Producteur unique.** Une donnée/commande a **un seul** POU qui l'écrit. Les autres la lisent,
  ne la recalculent pas et ne créent pas de source parallèle.
- **Composition, pas héritage.** Un FB compose d'autres FB en instances privées `VAR`.
  Pas de méthode/propriété ajoutée sans décision d'architecture explicite.
- **Internes privés.** Aucun appelant ne lit ni n'écrit `Instance.VariableInterne`. Le contrat,
  ce sont les `VAR_INPUT`/`VAR_OUTPUT` — et eux seuls.
- **Couplage explicite.** Une GVL n'est jamais un canal de commande informel entre deux POU qui
  devraient se parler par interface typée.
- **Commandes arbitrées avant l'appel.** Une décision combinant plusieurs causes est calculée,
  nommée et documentée par son propriétaire fonctionnel :

```pascal
// ❌ sources fusionnées anonymement à l'interface
Start := HmiButton OR JoystickActive OR CycleRequest;

// ✅ l'arbitre propriétaire choisit, expose, puis appelle
StartArbitrated := ...;
Instance(Start := StartArbitrated);
```

Un `OR` reste légitime pour agréger des **états homogènes** documentés (`AnyError := ErrorM1 OR ErrorM2`).
Il ne doit jamais masquer un arbitrage de commandes ni une priorité safety.

- **Structure (`ST_*`) seulement si les données forment un contrat cohérent** (commande, mesure,
  état, diagnostic). Ni fourre-tout, ni structure pour deux scalaires sans bénéfice.
- **Un programme orchestre**, il ne réimplémente pas la responsabilité d'un FB. Les données
  destinées à d'autres programmes passent par ses `VAR_OUTPUT`, pas par accès direct à une instance interne.

---

## 6. Robustesse numérique

- **Division** : jamais sans garantir le dénominateur non nul (test explicite ou borne de config).
- **Conversion de type** : explicite (`TO_REAL`, `TO_INT`), jamais implicite ; vérifier la plage
  avant une conversion réductrice.
- **Bornage** : toute valeur issue d'un capteur, d'un bus ou de l'IHM est bornée avant usage
  (`LIMIT`), y compris quand la source est « censée » être valide.
- **Temps** : les durées se déclarent en `TIME` nommé, pas en compteurs de cycles implicites.

---

## 7. Organisation d'un POU

```text
En-tête (rôle, doc source, sécurité, dépendances)
Déclarations d'interface (VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT)
Déclarations internes (VAR, VAR CONSTANT)
Initialisation / gates (Enable, PowerContactorEngaged)
Reset sur front
Sécurité et défauts
Logique métier
États et sorties
Diagnostic / IHM
```

```mermaid
flowchart TD
    A["En-tête — rôle, doc source, sécurité, dépendances"] --> B["Déclarations d'interface — VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT"]
    B --> C["Déclarations internes — VAR, VAR CONSTANT"]
    C --> D["Initialisation / gates — Enable, PowerContactorEngaged"]
    D --> E["Reset sur front"]
    E --> F["Sécurité et défauts"]
    F --> G["Logique métier"]
    G --> H["États et sorties"]
    H --> I["Diagnostic / IHM"]
```

En-tête minimal obligatoire :

```pascal
(* ═══════════════════════════════════════════════════════════════
   🎯 Nom du POU — rôle métier
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-XX_...md §...
   🛡️ Sécurité : [règle ou domaine concerné]
   🧩 Dépendances : [FB/PRG principaux]
   ═══════════════════════════════════════════════════════════════ *)
```

Commentaires en français, orientés **rôle / raison / risque**. Détail obligatoire sur sécurité,
interlock, temporisation, polarité, ordre d'appel et correction de bug. Pas de commentaire sur
une affectation évidente.

---

### 7bis. Regions Pragma CODESYS — repli visuel

```st
{region "§1 Rôle fonctionnel"}
// === 📥 §1 RÔLE FONCTIONNEL ===
...
{endregion}
```

- Une Region est **purement visuelle** : elle ne porte aucune logique et ne modifie ni l'ordre d'exécution, ni l'interface du POU.
- L'utiliser dans un `PROGRAM` ou `FUNCTION_BLOCK` ST lorsqu'il regroupe plusieurs responsabilités top-level. Ce n'est pas une règle de longueur : un FB cohésif reste sans Region.
- Ouvrir/fermer uniquement entre deux structures complètes top-level ; ne jamais couper ou traverser `IF`, `CASE`, `FOR`, `WHILE` ou `REPEAT`. Pas de Regions imbriquées par défaut.
- Les `PROGRAM` utilisent `§N` et un rôle en français ; un `FUNCTION_BLOCK` utilise un rôle en français, avec `§N` seulement si son ordre est stable. Conserver le commentaire de section avec emoji.
- Interdit dans `*_LD.st`, `GVL_*`, `ST_*`, `E_*` et les déclarations `VAR_*` dans cette phase. Le convertisseur ST→LD ignore les pragmas par sécurité.
- Le garde-fou `TOOLS/AGENT_WORKFLOW/tests/test_region_pragmas.py` vérifie l'équilibrage, le périmètre autorisé et les POU sélectionnés.

## 8. Non-régression

- **Avant** modification : identifier ce qui consomme la fonction/variable touchée (appelants,
  IHM, diagnostics, tests).
- **Après** : vérifier que chaque consommateur identifié tient toujours (types, noms, signature).
- Un renommage ou un déplacement de responsabilité se fait **atomiquement** avec ses appelants.
- Un changement de comportement de sécurité (`SafeStop`, `Enable`, `Reset`, timeouts) est comparé
  explicitement au comportement documenté avant d'être accepté.

---

## 9. Alarmes et défauts — condition vs acquittement (REX 2026-08 AU)

> 🚩 Pattern absent depuis le début du projet, formalisé après incident `EmergencyArmingFailed`
> (Reset conditionné → blocage opérateur). Basé sur ISA-18.2 (gestion d'alarmes industrielles).

Deux catégories de défaut, **jamais mélangées dans la même variable** :

| <nobr>Catégorie</nobr> | Comportement | Exemple |
|---|---|---|
| <nobr>**Info / Warning**</nobr> | S'affiche et s'efface **seule** avec la cause. Jamais d'acquittement, aucun `Reset` impliqué. | <small><code>BypassOperatorComm actif</code></small> |
| <nobr>**Fault (à acquitter)**</nobr> | Nécessite un geste opérateur conscient (`Reset`) pour être effacée, **même si la cause a disparu**. Si la cause **revient après acquittement**, l'alarme réapparaît et redemande un acquittement. | <small><code>EmergencyArmingFailed</code><br><code>SlackCableDetected</code></small> |

### Le Reset n'est jamais conditionné

```pascal
// ❌ Reset conditionné par un état externe — bloque l'acquittement lui-même
IF ResetEdge.Q THEN
    IF PowerContactorEngaged THEN
        EmergencyArmingFailed := FALSE;
    END_IF;
END_IF;
```

```pascal
// ✅ Pattern Cause / Ack — Reset TOUJOURS effectif, jamais conditionné
CauseEdge(CLK := EmergencyArmingFailedCause);   // R_TRIG : nouvelle apparition de la cause
IF CauseEdge.Q THEN
    EmergencyArmingFailedAck := FALSE;          // nouvelle occurrence -> ack remis à zéro (ré-alarme)
END_IF;
IF ResetEdge.Q THEN
    EmergencyArmingFailedAck := TRUE;           // toujours effectif, sans condition externe
END_IF;

EmergencyArmingFailed := EmergencyArmingFailedCause OR NOT EmergencyArmingFailedAck;
```

- `<Nom>Cause` = condition brute (l'événement ou la mesure qui a déclenché).
- `<Nom>Ack` = accusé de réception opérateur, remis à `FALSE` automatiquement au prochain front de cause.
- Un interlock de sécurité (ex : interdiction de redémarrage) se base **toujours sur la cause brute**,
  jamais sur l'état d'acquittement — l'acquittement n'ouvre jamais un interlock de sécurité par lui-même.

### Temporisation d'affichage IHM (anti-clignotement, pas de délai sur l'action)

L'**action de sécurité** reste instantanée (coupure, interdiction de mouvement...). Seul
**l'affichage IHM** de la cause peut être retardé par un `TON` court (typiquement `T#0ms` à `T#500ms`,
valeur en `VAR CONSTANT` documentée) pour éviter qu'un opérateur qui acquitte pendant que la
cause est encore présente voie l'alarme reclignoter immédiatement — le délai laisse le temps de
constater visuellement que le problème revient plutôt qu'un affichage figé permanent.

```pascal
// Action de sécurité : instantanée sur la cause brute, jamais retardée
SafeStopRequest := EmergencyArmingFailedCause OR ...;

// Affichage IHM uniquement : lissage anti-clignotement
TonDisplayDebounce(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
EmergencyArmingFailedDisplayed := TonDisplayDebounce.Q OR NOT EmergencyArmingFailedAck;
```

## 10. Orchestration ST pur (`.st`) — REX 2026-08 (Remplace CFC XML)

> 📌 **Décision d'architecture (Urgence Projet)** : L'orchestration par diagrammes graphiques CFC (`.xml`) est remplacée par du **Texte Structuré ST pur (`.st`)** pour tous les programmes d'orchestration (`PRG_02_Acquisition`, `PRG_03_Modes_Cycle`, `PRG_04_Treuils_Benne`, `PRG_05_Translation`, `PRG_07_Supervision`).

Règles obligatoires pour tout programme d'orchestration ST :

1. **Sections structurées avec emojis** : Chaque programme ST d'orchestration doit obligatoirement découper son flux de haut en bas avec des bannières commentées explicites (ex: `// === 📥 §1 ACQUISITION ===`, `// === 🛡️ §2 SÉCURITÉ ===`, `// === 🔀 §3 ARBITRAGE ===`).
2. **Aucune logique métier inline** : Le POU ST ne contient aucun `IF` complexe ni calcul métier — uniquement des instanciations et des appels de FB avec liaison par structures DUT publiques (`ST_*`).
3. **Producteur unique par bus DUT** : Les échanges inter-programmes passent par des structures typées dédiées (`Auth`, `Qualified`, `Measurements`).
4. **Conservation du Ladder Diagram (`_LD.st`)** : La barrière finale des sorties physiques TOR
   (`PRG_06_Outputs.st`) reste exclusivement en Ladder Diagram (`<LD>`). `PRG_01_Inputs_LD`
   et `FB_Input` sont des composants historiques en retrait ; aucune nouvelle page Ladder d'entrée
   ne doit être créée.

## 11. Règles de génération Ladder (`_LD.st` → `<LD>`) — REX 2026-08

> 🚩 Trois bugs d'import CODESYS sur l'ancien `PRG_01_Inputs_LD` ont révélé que le générateur
> ST→LD (`TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py`) produisait du
> PLCopenXML invalide. Les règles ci-dessous restent obligatoires pour toute
> source `_LD.st` active, notamment `PRG_06_Outputs`, et sont vérifiées par `test_ld_import_guard.py`.

### Structure d'un rung LD complet

Un programme suffixe `_LD` est converti en `<LD>` dans le bundle PLCopenXML.
Chaque rung doit contenir la **chaîne complète** :

```text
leftPowerRail → contact → block(FB) → coil → rightPowerRail
```

CODESYS **rejette** les rungs incomplets (sans coil, sans rightPowerRail).

### Règles de câblage FB

| FB | Contact principal | Sortie → coil |
|---|---|---|
| `FB_Output` | `Command` (contact) | `.State` → coil |
| `FB_Input` historique | Aucun nouveau câblage | Retrait contrôlé, pas de nouveau rung |

- Le **contact principal** (`InputRaw` ou `Command`) est relié au
  `leftPowerRail` puis au `formalParameter` du block.
- La **coil** est reliée à la sortie `State` du block (`formalParameter="State"`).
- Les paramètres supplémentaires (`FilterTime`, `InvertLogic`)
  ne sont **pas** représentés en LD — seuls les paramètres BOOL sont câblés
  comme contacts ; les paramètres typés (TIME, INT…) restent des `inVariable`
  dans la section multi-paramètres du générateur.

### Expressions BOOL

| Expression | Rendu LD |
|---|---|
| `var` (BOOL connu) | contact `negated="false"` |
| `NOT var` (BOOL connu) | contact `negated="true"` |
| `var1 AND var2` (2 termes) | série de contacts |
| `var1 OR var2` (2 termes) | parallèle de contacts |
| Condition composée ≥3 termes nommés (post §2bis), ou toute condition passée en argument d'un appel (ex. `SEL(A AND B, ...)`) | bloc `AND`/`OR` — 1 broche par terme, résultat à droite. **Jamais** de chaîne série/parallèle au-delà de 2 termes, **jamais** de texte ST brut injecté dans un `<expression>` : illisible à l'import, invérifiable en Watch, et un texte brut défait l'intérêt même de compiler en LD |
| Expression typée non-BOOL | `inVariable` → `outVariable` (hors page BOOL pure) |

- **`NOT var` ne produit jamais d'`inVariable`/`outVariable`** pour un signal
  BOOL. Un `inVariable` en page LD BOOL pure est un bug d'import.
- Une page `_LD` de type BOOL pur (notamment `PRG_06_Outputs`) ne doit contenir
  **aucun** `inVariable` ni `outVariable` — uniquement des `contact`, `coil`,
  `block` et `comment`.

#### Structure confirmée du bloc opérateur `AND`/`OR` — REX 2026-08-15 (export/import CODESYS réel réussi)

> 📌 **Portée** : cette structure produit un bloc opérateur compact multi-entrées dans le réseau Ladder.
> Utilisé lorsque le code ST contient explicitement `Target := OR(A, B, C, ...)` ou `Target := AND(A, B, C, ...)`.

Structure exacte confirmée par export réel CODESYS V3.5 SP19 Patch 1 (`TOOLS/SAMPLES_CODESYS/PRG_OR_AND_BLOC.xml`) :

| Élément | Règle |
|---|---|
| `<block typeName="AND"\|"OR">` | `localId` **plus petit** que celui de toutes ses sources |
| `<addData>` CallType | `<CallType>operator</CallType>` (et non `function`) |
| Broche `EN` (Entrée 1) | `formalParameter="EN"`, reliée au rail gauche `<connection refLocalId="0"/>` |
| Broches d'entrée opérandes | `formalParameter="In2"`, `"In3"`, `"In4"`, ... — reliées aux `inVariable` d'entrée |
| Opérande `NOT x` | `negated="true"` sur la broche `Inn` |
| Broche `ENO` (Sortie 1) | `formalParameter="ENO"`, `<connectionPointOut/>` sans connexion |
| Broche de résultat (Sortie 2) | `formalParameter="Out2"`, `<connectionPointOut><expression>TargetVar</expression></connectionPointOut>` |
| Opérandes sources | `inVariable` déclarées en amont avec leur propre `localId` |

```xml
<block localId="3" typeName="OR">
  <position x="0" y="0"/>
  <inputVariables>
    <variable formalParameter="EN">
      <connectionPointIn><connection refLocalId="0"/></connectionPointIn>
    </variable>
    <variable formalParameter="In2">
      <connectionPointIn><connection refLocalId="4"/></connectionPointIn>
    </variable>
    <variable formalParameter="In3">
      <connectionPointIn><connection refLocalId="5"/></connectionPointIn>
    </variable>
  </inputVariables>
  <inOutVariables/>
  <outputVariables>
    <variable formalParameter="ENO"><connectionPointOut/></variable>
    <variable formalParameter="Out2">
      <connectionPointOut><expression>M1BlockedBySafetyInfo</expression></connectionPointOut>
    </variable>
  </outputVariables>
  <addData>
    <data name="http://www.3s-software.com/plcopenxml/fbdcalltype" handleUnknown="implementation">
      <CallType xmlns="">operator</CallType>
    </data>
  </addData>
</block>
```

### Structures conditionnelles (`IF/ELSE`) — REX 2026-08-13

> 🚩 `PRG_02_Acquisition_LD` importé le 2026-08-13 a révélé un `IF WinchInputSourceSimulated
> THEN HwIn.Winch := instSimBench.Winch; ELSE HwIn.Winch := HwReal.Winch; END_IF;`
> compacté sur une ligne : le générateur a fuité le texte brut `ELSE ... END_IF` dans un contact.

Sous-ensemble ST **obligatoire** pour tout `_LD.st` contenant une sélection conditionnelle :

- `IF` / `ELSIF` / `ELSE` / `END_IF` chacun sur **sa propre ligne** — le style compact
  (`IF x THEN a := b; ELSE a := c; END_IF;` sur une seule ligne) est **interdit**.
- **1 instruction par ligne** — jamais deux `:=` sur la même ligne.
- Commentaire de fin de ligne (`// ...`) **interdit** dans le corps exécutable d'un `_LD.st` —
  uniquement en ligne dédiée, précédant l'instruction qu'il documente.
- `CASE` est **hors périmètre `_LD.st`** : les machines à état restent en ST pur dans le corps
  d'un FB (§11bis), jamais directement en page LD.
- Toute construction hors de ce sous-ensemble doit être **refusée** par le générateur
  (erreur bloquante) — jamais approximée ou silencieusement corrompue en sortie.

### Extraction FC pour logique de sélection typée — REX 2026-08-13

Une logique de sélection/condition répétée sur des structs différents (ex. bascule
Sim/Réel par domaine machine) ne se duplique **jamais** inline dans le PRG appelant.

**Priorité 1 — `SEL(G, IN0, IN1)`** (brique IEC 61131-3 standard, générique `ANY`,
composée avant toute réimplémentation — AF_Partie-03 §1) : `SEL(cond, ValeurSiFalse,
ValeurSiTrue)` remplace directement le `IF/ELSE` à deux branches, y compris sur des
structs (à confirmer par compilation CODESYS réelle à chaque premier usage sur un type
sans précédent dans le projet — REX 2026-08-13, aucun antécédent `SEL` sur `STRUCT`
avant `PRG_02_Acquisition_LD`).

**Priorité 2 — `FC_<Domaine><Action>` dédié** (ex. `FC_SelectWinchSource`) : seulement
si `SEL` ne compile pas sur le type concerné, ou si la logique dépasse une sélection à
deux branches. Pas de FC générique paramétrable par type dans ce projet (pas de
generics en ST standard).

Dans les deux cas, le réseau LD du PRG appelant devient un simple bloc (`SEL` ou appel
FC) câblé à sa sortie, sans logique conditionnelle à traduire au niveau du PRG.

### Tests de régression

```powershell
python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_ld_import_guard.py -v
```

Les tests couvrent les rungs LD actifs, les contacts inversés, l'absence d'inVariable/outVariable
sur les pages BOOL et la coil reliée à `.State` pour chaque block actif. `FB_Input` historique ne
fait plus partie des nouveaux contrats LD.

## 11bis. Séquenceurs et machines à état (REX 2026-08-12)

> 📌 Écritures de machine à état non standardisées avant ce REX — origine du flou diagnostic
> terrain ("pourquoi ça bloque, sur quelle tempo"). Règles ci-dessous **normatives** ; squelettes
> de code, exemples et détail : [`DOC/STDS/GUIDES/GUIDE_SEQUENCEUR_v1.2.md`](GUIDES/GUIDE_SEQUENCEUR_v1.2.md).

| # | Règle |
|---|---|
| R1 | `CASE` obligatoire sur enum unique. SET/RESET par étape interdit. |
| R2 | Label runtime = `"Xn - texte métier"`, toujours le numéro et le texte ensemble. |
| R2bis | Gabarit `X0..Xn` autorisé en brouillon ; renommage sémantique ensuite, préfixe `Xn` conservé. |
| R3 | Graphe linéaire ; sous-graphes linéaires ; sauts autorisés seulement s'ils rejoignent le tronc. |
| R4 | Dernière étape = synchronisation finale nommée et documentée, jamais un simple bit `Done` isolé. |
| R5 | `TON` scaffold sur chaque bloc de transition, commenté `Xi→Xj : <ce qu'on teste>`. |
| R6 | Front partagé ≥2 consommateurs (entrée ou `GVL_IHM.*.Cmd`) → centralisé `PRG_02_Acquisition`, jamais `PRG_07_Supervision`. Front à consommateur unique → reste local. |
| R7 | `FB_Edge` (nouveau, sans lien avec `FB_Input` retiré §10-11) : une instance par entrée qualifiée dans `PRG_02_Acquisition`, sorties `.R`/`.F`, systématique, sans paramètre. |
| R8 | Porte d'initialisation en tête de FB (`NOT Enable OR NOT PowerContactorEngaged`) : sorties sûres, retour à la **première** étape (jamais intermédiaire), `RETURN` immédiat. |
| R9 | `<StateField>AtError` mémorise l'étape **spécifique** (pas `E_State` générique) au moment du défaut, capturée avant la bascule vers `ERROR_HOLD`. |

## 12. Checklist de restitution (bloquante)

```text
[ ] G200_check_linkage.py --report = PASS, bloc collé dans la restitution
[ ] G340_check_doc_links.py = PASS (aucun lien mort, aucune version périmée)
[ ] G350_check_hw_name_collision.py = PASS (aucune variable PRG_* homonyme d'un point Device_IO, §3bis)
[ ] Nommage conforme DOC/STDS/NAMING_CONVENTION.md
[ ] Aucune variable/instance déclarée non utilisée
[ ] Aucun nombre magique ; constantes nommées
[ ] Producteur unique par donnée ; aucune GVL de commande cachée
[ ] Contrat FB respecté (AF_Partie-03)
[ ] Non-régression : appelants/IHM/diagnostics identifiés et mis à jour
[ ] Défaut à acquitter : Reset jamais conditionné (§9) ; Warning auto-effaçable distingué du Fault
[ ] Orchestration ST pur (.st) : découpage par sections commentées avec emojis, zéro logique métier inline, contrats DUT raccordés (§10)
[ ] Séquenceur (§11bis) : CASE+enum unique (R1), label "Xn - texte" (R2), graphe linéaire (R3), synchronisation finale nommée (R4), TON scaffold par transition (R5), fronts centralisés si partagés (R6/R7), initialisation standard (R8), StateAtError spécifique (R9)
[ ] Devoir d'alerte : toute ambiguïté signalée AVANT d'écrire, pas après
```

---

## 📖 Comment ce document vit

- `AGENTS.md` (point d'entrée unique) y renvoie au même niveau que `NAMING_CONVENTION.md`.
- `.claude/skills/codesys-workflow.md` **applique** ce référentiel, ne le recopie pas.
- `TOOLS/AGENT_WORKFLOW/docs/CODE_WRITING_POLICY.md` renvoie ici pour §POO et §organisation.
- Les prompts de sous-agents Pi le citent via `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
- Toute règle ajoutée ici après un incident vient **avec son garde-fou** dans
  `TOOLS/AGENT_WORKFLOW/scripts/` (règle `fix:` + `guard:`, `docs/WORKFLOW.md`).

Sources : *Clean Code* (R. C. Martin), MISRA C:2012 (dead code / unused variables), principes
SOLID, conventions IEC 61131-3. Amendable par tout agent disposant d'une recherche externe réelle —
indiquer la source ajoutée.
