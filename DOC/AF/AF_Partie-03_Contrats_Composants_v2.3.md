# Analyse Fonctionnelle — Partie 3 : Contrats Composants (v2.3)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🎯 Rôle et périmètre

- **Rôle** : définir les contrats publics des FB, des DUT internes et des pages CFC.
- **Périmètre** : profils de composants, cycle de vie/états/défauts (socle `FB_FaultCore`),
  contrats DUT, règles CFC/Ladder. Ne définit pas : la chaîne électrique AU et le réarmement
  (propriétaires de la Partie 01), l'architecture programme/ordonnancement (Partie 02).
- **Type de composant** : Fondations méta — pas de FB unique porteur. Le socle transverse
  `FB_FaultCore` (implémentation du contrat `standard`) a sa propre fiche détaillée :
  [`FB_FaultCore_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md).

## 📑 Sommaire

1. [🧪 Points de validation](#1--points-de-validation)
2. [🧱 Règles socle](#2--règles-socle)
3. [🧩 Profils de composants](#3--profils-de-composants)
4. [🛑 Cycle de vie, états et défauts](#4--cycle-de-vie-états-et-défauts)
5. [🚌 Contrats DUT internes](#5--contrats-dut-internes)
6. [👁️ Règles CFC](#6--règles-cfc)
7. [📐 Règles de génération Ladder](#7--règles-de-génération-ladder)
8. [📜 Suivi historique](#8--suivi-historique)
9. [❓ TBD](#9--tbd)
10. [📚 Documents liés](#10--documents-liés)

## 🧪 1 · Points de validation

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Intention | Preuve | Type | Réf | Etat |
|---|---|---|---|---|---|
| <nobr><code>TC-P03-001</code></nobr> | Cycle de vie et neutralisation `Enable` | `Enable=FALSE` neutralise commandes et statut (gate) ; `Enable=TRUE` autorise l'état Ready | `💻 AUTO` | <small>§4</small> | `NV-I` |
| <nobr><code>TC-P03-002</code></nobr> | Reset inconditionnel (Cause/Ack) | Front `Reset` efface l'affichage (interlock reste sur Cause) | `💻 AUTO` | <small>§4</small> | `NV-I` |
| <nobr><code>TC-P03-003</code></nobr> | Pas de redémarrage auto après Ack | Retour READY, nouvel ordre explicite requis | `💻 AUTO` | <small>§4</small> | `NV-I` |
| <nobr><code>TC-P03-004</code></nobr> | Pas de `SafeStop`/`StartStop` hors mouvement | Absents des briques E/S, joystick et diag | `💻 AUTO` | <small>§3</small> | `NV` |
| <nobr><code>TC-P03-005</code></nobr> | Encapsulation stricte | Échanges via interfaces/DUTs publics uniquement | `💻 AUTO` | <small>§2</small> | `NV` |
| <nobr><code>TC-P03-006</code></nobr> | Re-latch sur ré-apparition Cause | Nouveau front Cause ➔ `Ack=FALSE` | `💻 AUTO` | <small>§4</small> | `NV-I` |
| <nobr><code>TC-P03-007</code></nobr> | Warning auto-effaçable vs Fault latché | Warning s'efface sans Reset, Fault exige Ack | `💻 AUTO` | <small>§4</small> | `NV-I` |
| <nobr><code>TC-P03-014</code></nobr> | Bornage du `dt` de cycle (`FB_CycleTime`) | Hors plage nominale (`dt = 0` **ou** `dt > CST_MaxCycleDeltaMs`) ➔ `CycleTimeS = DefaultValueS` ; sinon `dt` réel ; secours non latché | `💻 AUTO` | <small><nobr>§3 →</nobr> <nobr>fiche</nobr></small> | `NV-I` |

> Catalogue `TC-P03-014.1` à `.3` (détail `FB_CycleTime` — plage nominale, borne basse, borne haute
> non latchée) **décliné dans la fiche dédiée**, pas dupliqué ici (`GUIDE_EDITION_AF_v1.0.md` §4) :
> [`FB_CycleTime_v1.0.md` §2](AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md#2--points-de-validation-détail).

> Catalogue `TC-P03-008` à `TC-P03-013` (détail `FB_FaultCore` — cumul de causes latchées, vue
> live vs vue latchée, bornes de liste, faille T148...) **déplacé dans la fiche dédiée** —
> propriétaire unique, pas dupliqué ici (`GUIDE_EDITION_AF_v1.0.md` §4) :
> [`FB_FaultCore_v1.0.md` §2](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md#2--points-de-validation-détail).

---

## 🧱 2 · Règles socle

| Regle | Exigence |
|---|---|
| 🧩 Responsabilite | Un composant produit les donnees dont il est proprietaire. Composition, pas heritage. |
| 🔒 Encapsulation | Les variables internes sont privees. Les echanges passent uniquement par interfaces et DUT publics. |
| ✍️ Producteur unique | Une commande ou donnee a un seul ecrivain. Un consommateur ne recalcule pas son producteur. |
| 📚 Bibliotheques | Une brique CODESYS existante est composee avant toute reimplementation. |
| 🔢 Robustesse | Bornage des sources externes, conversions explicites, temps nommes et absence de division non protegee. |
| 🖥️ IHM | L'IHM lit/ecrit ses structures dediees ; elle n'accede jamais aux internes des FB. |

## 🧩 3 · Profils de composants

| Profil | Role et contrat |
|---|---|
| 🎯 FB metier | Porte une responsabilite de domaine, un etat public et les diagnostics utiles a ses consommateurs. |
| 🛑 FB mouvement | Recoit `Enable`, `Reset`, `PowerContactorEngaged`, `Mode`, `StartStop`, `SafeStop` et son contrat de commande mouvement. |
| 🛡️ FB safety domaine | Surveille des faits qualifies, produit les interlocks de son domaine et expose ses causes. Il ne devient pas proprietaire des mesures surveillees. |
| 🔧 Brique technique | Contrat minimal propre a son role. Elle ne recoit pas artificiellement `Mode`, `State`, `StartStop` ou `SafeStop`. |
| ⚡ Barriere finale | Recoit la demande sortie typee, applique les interlocks ultimes et produit seule la commande physique autorisee. |
| 👁️ Programme d'orchestration (PRG) | Instancie et câble les composants par contrats. Il n'implémente aucune logique métier. |
| 🔄 Programme Cycle ST | Porte la machine d'etat de sequence et publie ses demandes automatiques par contrat public. |

### Contrats socle `light` / `standard`

Tout FB (`FB_*`) relève de l'un de ces deux contrats d'interface socle :

**1. Contrat `light`** (Calculateurs, filtres, utilitaires) — blocs **sans cycle de vie**, qui **ne
remontent aucun défaut**. `VAR_INPUT Enable : BOOL` + `VAR_OUTPUT Ready : BOOL`.
`Enable=FALSE` → sorties neutres/sûres + `Ready=FALSE`. Aucune machine d'état, aucun acquittement,
aucune sortie d'erreur. 🚫 Un bloc qui **remonte un défaut** (capteur, calibration, bus) n'est
**pas** `light` → c'est un `standard`.

**2. Contrat `standard`** (Composants métier, séquenceurs, organes, devices) — blocs qui **remontent
un défaut** OU **pilotent un organe**. `VAR_INPUT` socle fixe 2 champs : `Enable : BOOL` +
`Reset : BOOL` (front d'acquittement). `VAR_OUTPUT` socle :

- `Ready : BOOL`.
- `Fault : ST_Fault` — brique défaut (2 vues : live `Error`/`ErrorId` + latchée `Latched`/`LatchedId`),
  **remplie par une instance `FB_FaultCore`** alimentée par une liste de causes nommées
  `Causes : ARRAY[0..15] OF ST_FaultCause` (`Active` / `Latching` / `Texte`).
- `Lifecycle : ST_Lifecycle` (`Busy` / `Done`) **en plus, uniquement** si le FB porte une machine
  d'état à cycle (organe, séquenceur) — rempli par le FB lui-même, pas par `FB_FaultCore`. Un FB
  synchrone (conditionneur, joystick) ne porte pas `Lifecycle`.

Pas de champ `Error`/`ErrorId`/`Busy`/`Done` à plat en complément. Détail complet :
[`FB_FaultCore_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md).

> 🎯 **Le critère de classement est « remonte-t-il un défaut ? », pas « a-t-il une machine d'état ? ».**
> Un device qui remonte un défaut capteur/calibration/bus (ex. `FB_Joystick`) est `standard`, même
> sans machine d'état — il porte `Fault : ST_Fault` **sans** `Lifecycle`. Le socle `FB_FaultCore`
> ne produit ni `State`, ni `Warning`, ni texte (dérivés côté IHM depuis `LatchedId`/`ErrorId`).

⚠️ **Limite de la vérification automatique** : `test_fb_interface_guard.py` vérifie que
l'interface d'un FB **déjà classé** `light`/`standard` est complète pour son profil ; il ne
dérive pas lui-même le critère sémantique « remonte-t-il un défaut ? » à partir du corps du FB.
Un FB `light` dont le corps écrit malgré tout un `ErrorId`/champ de défaut passerait le guard sans
alerte. Revue humaine requise à la création d'un FB pour trancher `light` vs `standard` — ne pas
se reposer sur le seul test automatique pour ce choix.

**3. ⚠️ `PowerContactorEngaged` n'est PAS un champ du socle `standard`.** C'est une entrée
**conditionnelle**, à ajouter **seulement** si le FB pilote lui-même un organe consommant de la
puissance (contacteur, frein, moteur) et **interlocke son action** sur l'état de la chaîne de
puissance. `Reset`/`Error` (gestion de défaut, ex. calibration, capteur hors plage) est
**indépendant** de `PowerContactorEngaged` (pilotage d'organe) — les deux ne se déduisent jamais
l'un de l'autre. Un FB de pure acquisition/conditionnement qui gère un défaut capteur (donc
`Reset`/`Error` légitimes) mais ne pilote **aucun** actionneur ne porte **jamais**
`PowerContactorEngaged`. Ajouter ce champ par réflexe, sans vérifier que le FB pilote réellement un
organe, est une **erreur** (constaté sur `FB_Joystick` : gate sur `PowerContactorEngaged` sans
piloter d'actionneur, forçait le reset du timer d'armement homme-mort pendant la séquence de
réarmement AU). Décision **au cas par cas**, par FB.

✅ **Exemple légitime** : `FB_Winch` pilote directement le moteur/contacteur du treuil — il porte
`PowerContactorEngaged` et neutralise ses sorties si le contacteur n'est pas engagé
(`CODE/H_TREUILS_BENNE/FB_Winch.st` : `IF NOT Enable OR NOT PowerContactorEngaged THEN` avant
toute commande de mouvement). Comparer ce cas à `FB_Joystick` ci-dessus : la différence n'est pas
la présence d'un défaut à remonter, c'est **piloter ou non un actionneur physique**.

**4. Formes legacy tolérées (décomptées, jamais permanentes)** — deux tolérances, aucune n'est une
forme de conformité cible :

| Forme legacy | Portée | Sortie de tolérance |
|---|---|---|
| Défaut **à plat** (`Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError` en `VAR_OUTPUT`, sans textes) | FB antérieurs au socle | migration T137 |
| `Status : ST_Status` (struct de statut agrégé legacy) — **17 FB** encore concernés | FB déjà migrés vers l'ancien socle agrégé | migration **T164-5** |

Tout FB **nouveau** porte `Fault : ST_Fault` rempli via `FB_FaultCore` (+ `Lifecycle : ST_Lifecycle`
si machine d'état). Le guard `G315_check_fb_interface.py` reconnaît la forme cible et les formes
legacy et publie leur décompte (mesure de l'avancement des migrations).

### Briques techniques COMMUN (`CODE/A_COMMUN/`)

> Petites fonctions maison réutilisées par plusieurs domaines : un défaut dans l'une impacte
> toute la chaîne (ex. `FB_CycleTime` alimente rampes et intégrateurs). Liste d'inventaire +
> renvoi ; le détail vit dans la fiche dédiée ou dans la fiche du domaine consommateur.

| Brique | Rôle | Inst. | Comportement fail-safe notable | Détail |
|---|---|---|---|---|
| `FB_FaultCore` | Socle défaut → `Fault : ST_Fault` (vue live + latchée) | 18 | Latch / acquittement **par cause** (`ST_FaultCause.Latching`) | fiche [`FB_FaultCore_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md) (§4.1) |
| `FB_CycleTime` | Calcul du `dt` réel entre deux exécutions successives (s) | 5 | `dt` borné `0 < dt ≤ CST_MaxCycleDeltaMs`, sinon valeur de secours ; pas de redémarrage auto | fiche [`FB_CycleTime_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md) (<nobr><code>TC-P03-014</code></nobr>) |
| `FB_Brake` | Frein à manque de courant, temps physiques | 1 | Sécurité positive (`BrakeCmd = FALSE` = frein collé au repos) ; double vérif retour contacteur | résumé `AF_Partie-10_Fonction_Winch_v2.1.md` §3 |
| `FB_Ramp` | Rampe accel/décel asymétrique (%/s) | 1 | Distingue éloignement / retour à zéro | résumé `AF_Partie-11_Fonction_Translation_v2.3.md` §1 (<nobr><code>TC-P11-040</code></nobr>) |
| `FB_Acquisition_Preflight` | Verdict passif de qualification E/S machine arrêtée (16 contrôles) | 1 | Observateur pur (aucun `SafeStop` / `PowerCutOff` / ordre machine) | `AF_Partie-06_Acquisition_Qualification_IO_v2.4.md` §6 |
| `FB_Filter` | Filtre passe-bas PT1 discret | 0 | Pass-through si `T = 0` ou `CycleTimeS = 0` | *(non instancié — inventaire uniquement)* |

Règle : une brique avec un **comportement fail-safe non trivial** (bornage, latch, séquence
temporisée) a une fiche ou un paragraphe qui le spécifie et un `TC-Pxx` ; une brique de calcul
pur sans repli particulier se contente de la ligne d'inventaire ci-dessus.

## 🛑 4 · Cycle de vie, états et défauts

### Precedence mouvement

```text
Enable = FALSE  -> neutralisation des sorties
SafeStop = TRUE -> deceleration rapide, Enable maintenu
StartStop       -> acceleration ou deceleration normale
```

`StartStop` et `SafeStop` sont reserves aux FB de mouvement. Ils ne sont pas ajoutes aux briques

### Reset et diagnostic

- `Reset` est traite sur front interne, et n'est **jamais conditionne** par un etat externe
  (cause corrigee au REX 2026-08 AU, ex-regle erronee "efface seulement si la cause a disparu").
- Deux comportements de defaut a distinguer des la conception d'un composant, portes **par cause**
  via `ST_FaultCause.Latching` : `Latching=FALSE` → cause **live seulement** (visible dans
  `Fault.Error`/`ErrorId`, retombe seule, aucun acquittement) ; `Latching=TRUE` → cause **latchee**
  (arme `Fault.Latched`, necessite un front `Reset`, re-arme si la cause revient). Pattern
  `Cause`/`Ack` et regle complete : `DOC/STDS/CODE_QUALITY_STANDARDS.md §9`.
- ⚠️ **Changement de convention (T164-3)** : l'ancien socle classait en **Fault** toute cause sans
  `IsWarning=TRUE` (fail-safe par defaut = latche). Le nouveau socle laisse une cause sans
  `Latching=TRUE` en **live seulement** — elle reste visible (l'interlock se base sur la cause
  brute, la securite n'est pas affaiblie) mais son caractere **acquittable** est desormais un
  **choix explicite par cause**. Detail : [`FB_FaultCore_v1.0.md` §5](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md#5--changement-de-convention-fail-safe-ex-iswarning--latching).
- L'acquittement ne redemarre jamais un mouvement : une nouvelle demande explicite est requise.
- `ErrorId`/`LatchedId` sont des bitfields cumulatifs. Chaque bit a une cause, un proprietaire et
  un libelle IHM documentes. `Error := (ErrorId <> 0)`, `Latched := (LatchedId <> 0)`.
- Un FB porteur avec sa **propre** machine d'etat capture son etat au defaut lui-meme
  (`Lifecycle`/struct metier) — le socle `FB_FaultCore` ne produit pas de `State`/`StateAtError`.

### 4.1 Socle `FB_FaultCore` — pointeur (détail en fiche dédiée)

> 🧩 Implémentation concrète du pattern Cause/Ack décrit en §4. Un seul socle, réutilisé par
> tout FB `standard` qui doit remplir `Fault : ST_Fault` — code écrit une fois, comportement
> identique partout (cf. §3 Profils de composants).

**But** : remplir de façon standardisée la sortie `Fault : ST_Fault` d'un FB métier — vue live
(`Error`/`ErrorId`) + vue latchée (`Latched`/`LatchedId`), à partir d'une liste de causes en clair,
sans que chaque FB métier ré-implémente sa propre logique de latch/acquittement. Pas de `State`,
pas de `Warning`, pas de texte (dérivés côté IHM depuis `LatchedId`/`ErrorId`).

**Où il se place** : instancié **dans** le FB métier qui expose `Fault : ST_Fault` (pas un
programme séparé). Consommateur actuel confirmé : `FB_Joystick` (`instFault` + `instCauses`,
`CODE/D_JOYSTICK/FB_Joystick.st`). Forme cible destinée à se généraliser aux autres FB `standard`
(cf. §3).

📄 **Interface complète (IN `Enable`/`Reset`/`Causes[0..15]`, OUT `Ready`/`Fault`), vue live vs
latchée, changement de convention fail-safe, câblage minimal copiable, limites T147/T148 et
catalogue de tests** : voir
[`FB_FaultCore_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md) — ce chapô ne garde
que le résumé ci-dessus, le détail vit uniquement dans la fiche dédiée
(anti-duplication, `GUIDE_EDITION_AF_v1.0.md` §4).

## 🚌 5 · Contrats DUT internes

Un DUT de flux n'est ni une GVL, ni une copie de la structure IHM. Il est specifique a une frontiere.

| Regle | Exigence |
|---|---|
| 🧾 Fiche contrat | Proprietaire, ecrivain unique, lecteurs, champs, unites, polarites, cadence, invalidite et tests. |
| 🏗️ Acquisition | Porte des faits qualifies et leur disponibilite ; jamais une commande metier. |
| 🕹️ Demande | Porte une intention brute sourcee ou une commande deja arbitree, jamais les deux sans distinction. |
| 🛡️ Safety | Porte des interlocks et diagnostics de domaine ; il ne transporte pas des commandes IHM. |
| ⚙️ Commande mouvement | Porte la commande finale unique du mouvement apres arbitrage. |
| ⚡ Sortie | Porte la demande vers la barriere finale, sans ecriture Q/PDO par le domaine metier. |
| 👁️ Etat | Porte les faits, mesures et diagnostics publies ; aucun lecteur ne l'ecrit. |

`Valid` n'est ajoute que si son absence a une semantique documentee (mesure douteuse, fenetre
incomplete, device hors OP). `Enable` n'est pas un champ d'en-tete de bus : c'est une commande
de cycle de vie du FB.

### Projections de monitoring dans un DUT — bits = verite, INT/enum = vue derivee

Quand un DUT porte a la fois la **verite logique** (bits) et une **vue derivee** pour l'IHM ou le
monitoring, la regle est :

| Regle | Exigence |
|---|---|
| 🔩 Source unique | Les bits (`DirectionPositive`/`DirectionNegative`, `AtNeutral`…) sont la **verite** — toute logique d'interlock, de sens et de commande se base sur eux. |
| 📊 Vue derivee | Les champs `INT`/`ENUM` de synthese (`Direction : INT` -1/0/+1, `Deflection : INT` -100..+100) sont **produits par le FB proprietaire** a partir des bits, dans la meme passe. |
| 🚫 Pas de recalcul | Un consommateur **lit** la vue derivee ; il ne la recalcule **jamais** a partir des bits (sinon N formules paralleles a maintenir). |
| ➕ Non signe par defaut | Une consigne de vitesse (`SpeedTgt`) est **non signee** (`ABS`) ; le sens est porte par les bits + la vue `Direction`, jamais par le signe de la consigne. |

Reference appliquee : `ST_fbJoystick_AxisCmd` (`FB_Joystick`, 2026-08-27).

### Integrite des liaisons — rester simple

| Moyen | Usage |
|---|---|
| 🔗 Typage DUT | Premiere barriere : un bus `ST_Safety_*` ne se branche pas sur une entree `ST_Cmd_*`. |
| ✍️ Producteur unique | Une donnee, un ecrivain ; prouve par fiche contrat + `G200_check_linkage.py`. |
| ✅ `Valid` | Seulement si le lecteur a un repli documente quand `FALSE` (souvent mesures / safety). |
| 🚫 Pas d'ID de connexion | Aucun `ProducerId`, signature ou jeton d'appairage dans les DUT internes. Surcharge et fausse securite en CFC local. |
| 📡 Bus terrain | Identite = adresse device + diag existant (`FB_Diag_Ethercat`, `FB_Diag_CanOpen`, OP/erreur). Pas de second ID applicatif. |
| ⚡ Fail-safe physique | Chaine AU / maintien A-B : absence de commande saine = coupure ; le logiciel ne remplace pas ce filet. |

## 👁️ 6 · Règles CFC

- Le flux se lit de gauche a droite : faits qualifies, decision, mouvement, barriere, etat public.
- Les commandes ne se croisent pas : tout arbitrage est realise par un composant proprietaire, expose et nomme.
- Les sorties safety entrent par le haut ou une zone safety dediee, avec une polarite lisible.
- Une page reste limitee a un domaine ; une autre page est reliee par DUT, jamais par interne d'instance.
- Le numero d'ordre graphique ne prouve pas l'ordre scan. La configuration de tache CODESYS et `G200_check_linkage.py` sont les preuves requises.
- Une GVL ne sert pas de bus de commande interne. `GVL_IHM`, persistance et simulation restent des frontieres justifiees.

### Production de programmes — ST + PLCopenXML (CFC natif abandonné)

> 🚩 **Décision 2026-08-16** : la conversion CFC natif (lot M8) est **abandonnée**.
> Le code est écrit en **ST** (`CODE/MAIN/PRG_XX_*.st`) et converti en PLCopenXML par
> `TOOLS/CONVERTER_ST2XML_PLCopenXML`. Aucune page CFC native `.xml` n'est produite.

Les programmes sont des sources ST ; le générateur produit le bundle PLCopenXML
(`<ST>`, `<LD>`, `<FBD>` selon le suffixe). La renumérotation 7 POU (`PRG_02`→`PRG_07`)
est soldée. Historique de la migration : `ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`.

## 📐 7 · Règles de génération Ladder (`_LD.st` → `<LD>`)

> 🚩 Référentiel complet & règles de génération : voir [`DOC/STDS/CODE_QUALITY_STANDARDS.md §11`](../STDS/CODE_QUALITY_STANDARDS.md).

Un programme suffixé `_LD` est une **source ST** convertie en `<LD>` dans le bundle PLCopenXML par `TOOLS/CONVERTER_ST2XML_PLCopenXML/generator/ld_builder.py`.

### Câblage `FB_Output` et retrait de `FB_Input`

| FB | Statut migration | Règle |
|---|---|---|
| `FB_Output` | Actif | `Command` → barrières/interlocks → `.State`/sortie physique |
| `FB_Input` | Déprécié | Aucun nouveau rung, aucune nouvelle instance ; retrait après remappage acquisition |

Les entrées sont désormais observées et publiées par `PRG_02_Acquisition` en ST via `HwReal`,
`HwSim` et `HwIn`. La conversion automatique d'un `GetDeviceState()` en `BOOL` dans une page LD
est interdite : `GetDeviceState()` retourne un `DEVICE_STATE` et le diagnostic module reste
centralisé dans l'acquisition.

### Tests de régression

```powershell
python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_ld_import_guard.py -v
```

## 📜 8 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v2.5 | 2026-08-29 | **T088 — catalogue « Briques techniques COMMUN » en §3.** Table d'inventaire des briques maison `CODE/A_COMMUN/` (`FB_FaultCore`, `FB_CycleTime`, `FB_Brake`, `FB_Ramp`, `FB_Acquisition_Preflight`, `FB_Filter`) avec rôle, nombre d'instances, comportement fail-safe et renvoi (fiche dédiée ou fiche du domaine consommateur). Nouvelle sous-fiche [`FB_CycleTime_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md) (bornage du `dt` : plafond haut `CST_MaxCycleDeltaMs` ajouté par T088). TC racine <nobr><code>TC-P03-014</code></nobr> créé, décliné `.1`/`.2`/`.3` dans la sous-fiche. |
| v2.4 | 2026-08-27 | **T164-3 — socle défaut unifié.** Forme cible du contrat `standard` : `VAR_OUTPUT` = `Ready : BOOL` + `Fault : ST_Fault` (2 vues : live `Error`/`ErrorId` + latchée `Latched`/`LatchedId`), rempli par une instance `FB_FaultCore` alimentée par `Causes : ARRAY[0..15] OF ST_FaultCause` (`Active`/`Latching`/`Texte`), `+ Lifecycle : ST_Lifecycle` si machine d'état à cycle. Remplace `Status : ST_FbStatus` / socle `FB_FbStatus` / type `ST_FbCause` (supprimés du code au commit `51fccce6`). §2, §3, §4, §4.1 réécrits ; sous-fiche renommée `FB_FaultCore_v1.0.md`. **Changement de convention fail-safe assumé** : cause non classée passait en Fault (`IsWarning` absent) → passe désormais en live seulement (`Latching` absent) — l'interlock reste sur la cause brute, mais l'acquittabilité devient un choix explicite par cause. Forme `Status : ST_Status` (ex-`ST_FbStatus`) tolérée sur 17 FB jusqu'à T164-5. |
| v2.3 | 2026-08-26 | Décongestion du chapô : détail complet de `FB_FbStatus` (interfaces, type `ST_FbCause`, décisions a/b/c, câblage minimal, <nobr><code>TC-P03-008</code></nobr> à `013`) déplacé vers une fiche dédiée (aujourd'hui `FB_FaultCore_v1.0.md`, voir v2.4), suivant le pattern chapô/sous-fiche déjà appliqué par AF10/`FB_Bucket`. §4.1 et §3 ne gardent qu'un résumé + pointeur. Précision ajoutée en §3 : le contrat `standard` porte `Ready`+`Status` **seuls**, sans mirror `Error`/`ErrorId` à plat en complément (écart constaté sur `FB_Joystick.st`, à corriger séparément). |
| v2.2 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lie, section `🎯 Rôle et périmètre` explicite, ajout Suivi historique et TBD, renumerotation complete des sections (chapô + réfs internes §N cascadées). Correctifs de fond (review sous-agent expert automatisme) : lien casse `AGENTS.md §1bis` corrige, exemple positif `FB_Winch` ajoute a cote du contre-exemple `FB_Joystick` (règle `PowerContactorEngaged`), limite du test automatique `light`/`standard` documentee (ne derive pas le critere semantique du corps du FB), cablage minimal `FB_FbStatus` ajoute (exemple ST copiable) |
| v2.1 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 9 · TBD

| # | Question | Impact |
|---|---|---|
| 1 | T148 — `Reset` maintenu (niveau haut) sans nouveau front pendant que la cause disparaît : acquittement silencieux (<nobr><code>TC-P03-012</code></nobr>) | **Non applicable au socle `FB_FaultCore`** : le clear des latches n'agit que sur le front `R_TRIG` (`ResetEdge.Q`) ; une cause réapparue `Active AND Latching` ré-arme son bit. Reste à vérifier sur les FB legacy non encore migrés. |

## 📚 10 · Documents liés

- Partie 01 : AU, coupure puissance et rearmement.
- Partie 02 : pages CFC, programmes et flux inter-domaines.
- Parties 04 a 14 : contrats metier detailles et champs de leurs DUT.
- [`FB_FaultCore_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md) : fiche détaillée
  du socle transverse `FB_FaultCore` (interface `Enable`/`Reset`/`Causes[0..15]` → `Ready`/`Fault`,
  vue live vs latchée, changement de convention fail-safe, câblage, TC-008 à 013).
- [`FB_CycleTime_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md) : fiche détaillée
  de la brique `FB_CycleTime` (mesure du `dt` de tâche, double bornage du delta, consommateurs,
  <nobr><code>TC-P03-014</code></nobr>).
