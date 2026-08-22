# Analyse Fonctionnelle — Partie 3 : Contrats Composants (v2.1)

> Role : definir les contrats publics des FB, des DUT internes et des pages CFC.
> La chaine electrique AU et le rearmement sont proprietaires de la Partie 01.

## 🧭 Sommaire rapide

1. Regles socle
2. Profils de composants
3. Cycle de vie, etats et defauts (3.1 Fiche FB_FbStatus)
4. Contrats DUT
5. Regles CFC

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P03-001</code></nobr> | Priorité `Enable > SafeStop > StartStop` | `SafeStop` impose la rampe rapide même si `StartStop=TRUE` | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-002</code></nobr> | Reset inconditionnel (Cause/Ack) | Front `Reset` efface l'affichage (interlock reste sur Cause) | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-003</code></nobr> | Pas de redémarrage auto après Ack | Retour READY, nouvel ordre explicite requis | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-004</code></nobr> | Pas de `SafeStop`/`StartStop` hors mouvement | Absents des briques E/S, joystick et diag | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P03-005</code></nobr> | Encapsulation stricte | Échanges via interfaces/DUTs publics uniquement | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P03-006</code></nobr> | Re-latch sur ré-apparition Cause | Nouveau front Cause ➔ `Ack=FALSE` | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-007</code></nobr> | Warning auto-effaçable vs Fault latché | Warning s'efface sans Reset, Fault exige Ack | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-008</code></nobr> | Cumul de plusieurs Fault latchés | 2 bits distincts apparus à des instants différents s'accumulent dans `ErrorId`, Reset les acquitte ensemble | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-009</code></nobr> | Sélection du texte IHM si Fault+Warning actifs ensemble | Texte IHM = première cause active (index le plus bas) par parcours de la liste `Causes` ; le warning reste dans `WarningIdTxt`, jamais dans `ErrorId` | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-010</code></nobr> | Bornes de la liste de causes `Causes[0..15]` | `Causes[0]` et `Causes[15]` correctement gérés, pas d'off-by-one | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-011</code></nobr> | `Reset` sans historique de défaut | Aucun effet parasite, `ResetRequested` reste `FALSE` | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-012</code></nobr> | `Reset` maintenu (niveau haut) pendant plusieurs scans | ⚠️ Faille identifiée (T148) : si la cause disparaît pendant que `Reset` reste haut sans nouveau front, l'acquittement se fait sans confirmation au moment réel — comportement actuel prouvé, pas validé comme cible | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-013</code></nobr> | Texte IHM pour un bit actif sans texte configuré | Chaîne vide, pas de plantage ni de texte résiduel d'un autre bit | `💻 AUTO` | <small>§3.1</small> |

---

## 🧱 1. Regles socle

| Regle | Exigence |
|---|---|
| 🧩 Responsabilite | Un composant produit les donnees dont il est proprietaire. Composition, pas heritage. |
| 🔒 Encapsulation | Les variables internes sont privees. Les echanges passent uniquement par interfaces et DUT publics. |
| ✍️ Producteur unique | Une commande ou donnee a un seul ecrivain. Un consommateur ne recalcule pas son producteur. |
| 📚 Bibliotheques | Une brique CODESYS existante est composee avant toute reimplementation. |
| 🔢 Robustesse | Bornage des sources externes, conversions explicites, temps nommes et absence de division non protegee. |
| 🖥️ IHM | L'IHM lit/ecrit ses structures dediees ; elle n'accede jamais aux internes des FB. |

## 🧩 2. Profils de composants

| Profil | Role et contrat |
|---|---|
| 🎯 FB metier | Porte une responsabilite de domaine, un etat public et les diagnostics utiles a ses consommateurs. |
| 🛑 FB mouvement | Recoit `Enable`, `Reset`, `PowerContactorEngaged`, `Mode`, `StartStop`, `SafeStop` et son contrat de commande mouvement. |
| 🛡️ FB safety domaine | Surveille des faits qualifies, produit les interlocks de son domaine et expose ses causes. Il ne devient pas proprietaire des mesures surveillees. |
| 🔧 Brique technique | Contrat minimal propre a son role. Elle ne recoit pas artificiellement `Mode`, `State`, `StartStop` ou `SafeStop`. |
| ⚡ Barriere finale | Recoit la demande sortie typee, applique les interlocks ultimes et produit seule la commande physique autorisee. |
| 👁️ Programme CFC | Instancie et cable les composants par contrats. Il n'implemente aucune logique metier. |
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
`Reset : BOOL` (front d'acquittement). `VAR_OUTPUT` : `Ready : BOOL` + `Status : ST_FbStatus`
(rempli via le socle `FB_FbStatus`, cf. §3.1).

> 🎯 **Le critère de classement est « remonte-t-il un défaut ? », pas « a-t-il une machine d'état ? ».**
> Un device qui remonte un défaut capteur/calibration/bus (ex. `FB_Joystick`) est `standard`, même
> sans machine d'état — `State`/`StateAtError` sont alors remplis par le socle (valeur `READY`).

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

**4. Tolérance transitoire T137** : les FB antérieurs exposent encore le défaut **à plat**
(`Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError` en `VAR_OUTPUT`, sans `Warning`, sans
textes) — accepté le temps de la migration, **uniquement** pour les FB existants. Tout FB
**nouveau** porte `Status : ST_FbStatus` rempli via `FB_FbStatus`. Ce n'est **pas** une seconde
forme de conformité permanente.

## 🛑 3. Cycle de vie, etats et defauts

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
- Deux categories de defaut a distinguer des la conception d'un composant : **Warning** (auto-efface
  avec la cause, aucun acquittement) et **Fault** (necessite un acquittement explicite, meme si la
  cause a disparu ; reapparait si la cause revient apres acquittement). Pattern `Cause`/`Ack` et regle
  complete : `DOC/STDS/CODE_QUALITY_STANDARDS.md §9`.
- L'acquittement ne redemarre jamais un mouvement : une nouvelle demande explicite est requise.
- `ErrorId` est un bitfield cumulatif. Chaque bit a une cause, un proprietaire et un texte IHM documentes.
- `Error := (ErrorId <> 0)`.
- `State` decrit la phase ; `StateAtError` fige la phase lors du defaut jusqu'a l'acquittement effectif.

### 3.1 Fiche `FB_FbStatus` — socle transverse de statut (forme cible)

> 🧩 Implémentation concrète du pattern Cause/Ack décrit en §3. Un seul socle, réutilisé par
> tout FB `standard` qui doit remplir `Status : ST_FbStatus` — code écrit une fois, comportement
> identique partout (cf. §2 Profils de composants).

**But** : remplir de façon standardisée la sortie `Status : ST_FbStatus` d'un FB métier —
classification Fault (latché, à acquitter) vs Warning (auto-effacé), textes IHM prêts à
afficher, sans que chaque FB métier ré-implémente sa propre logique d'acquittement.

**Où il se place** : instancié **dans** le FB métier qui expose `Status : ST_FbStatus` (pas un
programme séparé) — le FB métier ne fait que fournir sa **liste de causes** (`Causes :
ARRAY[0..15] OF ST_FbCause`) et recopie `Status := instFbStatus.Status`. Consommateur actuel
confirmé (`grep CODE/`, 2026-08-22) : `FB_Joystick` (`instFbStatus`, `CODE/D_JOYSTICK/FB_Joystick.st`).
Forme cible destinée à se généraliser aux autres FB `standard` (cf. §2).

**Interfaces** :

| Sens | Nom | Type | Rôle |
|---|---|---|---|
| IN | `Enable` | `BOOL` | Autorisation générale — `FALSE` neutralise les sorties (`Ready=FALSE`) ; le latch des défauts est **conservé** (décision (b) ci-dessous) |
| IN | `Reset` | `BOOL` | Front d'acquittement, jamais conditionné par un état externe (§3) |
| IN | `Causes` | `ARRAY[0..15] OF ST_FbCause` | Liste des causes en **clair** (`Active`/`IsWarning`/`Texte`), fournies par le FB métier — remplace l'ancien couple bitfield `WORD` + tableaux de textes |
| OUT | `Ready` | `BOOL` | Recopie de `Enable` |
| OUT | `Status` | `ST_FbStatus` | Statut complet — mappé 1:1 sur la sortie `Status` du FB métier appelant |

**Type `ST_FbCause`** (nouveau — cause élémentaire en clair, sans bitfield ni masque) :

| Champ | Type | Rôle |
|---|---|---|
| `Active` | `BOOL` | Cause brute — `TRUE` = cause présente. **Interlock toujours sur `Active`** (cause brute), jamais sur l'acquittement |
| `IsWarning` | `BOOL` | `TRUE` = warning **auto-effacé** (ne lève jamais `Error`) ; `FALSE` = fault à acquitter (laté). Fail-safe : toute cause sans `IsWarning=TRUE` est classée Fault |
| `Texte` | `STRING` | Libellé IHM de la cause |

**Comportement clé** (détail Cause/Ack : §3 + `CODE_QUALITY_STANDARDS.md §2quinquies/§9`) :
- Une cause est classée Fault ou Warning par **`IsWarning`** (jamais les deux). `IsWarning=TRUE`
  → warning **auto-effacé** avec la cause (ne lève jamais `Error`) ; `IsWarning=FALSE` → défaut
  **laté** à acquitter, qui se re-lathe si la cause revient. Fail-safe : toute cause sans
  `IsWarning=TRUE` est classée Fault.
- **Décision (a)** : un warning n'est **jamais** écrit dans `ErrorId` — `ErrorId` est réservé aux
  **vrais défauts** (à acquitter). Un warning va dans `WarningId`/`WarningIdTxt`. `Error :=
  (ErrorId <> 0)` ne voit donc jamais de faux défaut.
- **Décision (b)** : le latch d'un défaut est **conservé** quand `Enable=FALSE` — un défaut non
  acquitté ne disparaît pas silencieusement ; seule un `Reset` l'efface. **Résout l'ancienne
  limite T147** (avant : le latch était remis à zéro au cycle `Enable=FALSE`).
- **Décision (c)** : `StateAtError` est capturé **au premier défaut** puis **gelé** jusqu'au
  `Reset` (`StateAtErrorArmed`) — jamais réécrit par une cause ultérieure.
- Sélection du texte IHM : **parcours de liste** (`FOR` sur `Causes[i].Active` → `Causes[i].Texte`),
  première cause active d'index le plus bas — **plus aucun `WHILE`, ni masque, ni `SHR`** pour la
  sélection. Un warning actif s'affiche via un second parcours (`WarningIdTxt`), séparé des défauts.
- `State`/`StateAtError` : remplis par le socle à `READY` par défaut — un FB avec sa **propre**
  machine d'état (ex. séquenceur treuil) ne doit pas s'appuyer dessus (cf. `FB_Modes.st`, qui
  gère sa capture lui-même sans passer par ce socle).
- `Busy`/`Done` : **non gérés par le socle**, à la charge du FB métier appelant selon son cycle.

**⚠️ Limites restantes** (voir `DOC/WFLOW/TASKS.yaml`) :
- **T147 — RÉSOLU** : le latch d'un défaut survit désormais à un cycle `Enable=FALSE` (décision (b)).
- **T148** : un `Reset` simplement **maintenu** (niveau haut, pas de nouveau front) pendant que
  la cause disparaît acquitte silencieusement le défaut, sans confirmation au moment réel de la
  disparition — prouvé par `TC-P03-012`.

**Tests** (`TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st`, 11 scénarios,
multi-scans) — les **11 scénarios testent désormais la liste de causes**
(`ARRAY[0..15] OF ST_FbCause`) : les causes sont injectées via `Causes[i].Active`/`IsWarning`/
`Texte`, plus aucune source bitfield `WORD` ni tableau de textes indexé par bit :

| ID | Scénario | Points clés vérifiés |
|---|---|---|
| <nobr><code>TC-P03-001</code></nobr> | Gate `Enable=FALSE` | Statut neutre, `Ready=FALSE`, latch des défauts **conservé** (décision (b)) |
| — | Nominal sans cause | `Ready=TRUE`, aucun défaut ni warning |
| <nobr><code>TC-P03-007</code></nobr> | Warning auto-effacé (`IsWarning=TRUE`) | Apparition + texte IHM (parcours de liste) + disparition sans `Reset` ; `Error` et `ErrorId` **jamais** levés |
| <nobr><code>TC-P03-002/003</code></nobr> | Fault latché (`IsWarning=FALSE`) | Mémorisé après disparition de la cause, acquitté seulement par `Reset` avec cause absente |
| <nobr><code>TC-P03-006</code></nobr> | `Reset` refusé si cause présente | Interlock sur `Causes[i].Active` (cause brute), jamais sur l'acquittement |
| <nobr><code>TC-P03-008</code></nobr> | Cumul de plusieurs défauts latchés | 2 défauts (`Causes[i]` distincts) apparus à des instants différents s'accumulent dans `ErrorId`, acquittés ensemble |
| <nobr><code>TC-P03-009</code></nobr> | Fault + Warning simultanés | Texte IHM = **première cause active** (index le plus bas) par parcours de liste ; le warning reste dans `WarningIdTxt`, jamais dans `ErrorId` |
| <nobr><code>TC-P03-010</code></nobr> | Bornes de la liste de causes | `Causes[0]` et `Causes[15]` correctement gérés, pas d'off-by-one |
| <nobr><code>TC-P03-011</code></nobr> | `Reset` à vide | Aucun effet parasite |
| <nobr><code>TC-P03-012</code></nobr> | `Reset` maintenu + cause qui disparaît | ⚠️ Faille T148 prouvée |
| <nobr><code>TC-P03-013</code></nobr> | Texte IHM non configuré (`Texte=''`) | Chaîne vide, pas de plantage |

## 🚌 4. Contrats DUT internes

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

### Integrite des liaisons — rester simple

| Moyen | Usage |
|---|---|
| 🔗 Typage DUT | Premiere barriere : un bus `ST_Safety_*` ne se branche pas sur une entree `ST_Cmd_*`. |
| ✍️ Producteur unique | Une donnee, un ecrivain ; prouve par fiche contrat + `G200_check_linkage.py`. |
| ✅ `Valid` | Seulement si le lecteur a un repli documente quand `FALSE` (souvent mesures / safety). |
| 🚫 Pas d'ID de connexion | Aucun `ProducerId`, signature ou jeton d'appairage dans les DUT internes. Surcharge et fausse securite en CFC local. |
| 📡 Bus terrain | Identite = adresse device + diag existant (`FB_Diag_Ethercat`, `FB_Diag_CanOpen`, OP/erreur). Pas de second ID applicatif. |
| ⚡ Fail-safe physique | Chaine AU / maintien A-B : absence de commande saine = coupure ; le logiciel ne remplace pas ce filet. |

## 👁️ 5. Regles CFC

- Le flux se lit de gauche a droite : faits qualifies, decision, mouvement, barriere, etat public.
- Les commandes ne se croisent pas : tout arbitrage est realise par un composant proprietaire, expose et nomme.
- Les sorties safety entrent par le haut ou une zone safety dediee, avec une polarite lisible.
- Une page reste limitee a un domaine ; une autre page est reliee par DUT, jamais par interne d'instance.
- Le numero d'ordre graphique ne prouve pas l'ordre scan. La configuration de tache CODESYS et `G200_check_linkage.py` sont les preuves requises.
- Une GVL ne sert pas de bus de commande interne. `GVL_IHM`, persistance et simulation restent des frontieres justifiees.

### Production de programmes — ST + PLCopenXML (CFC natif abandonné)

> 🚩 **Décision 2026-08-16** : la conversion CFC natif (lot M8) est **abandonnée**.
> Le code est écrit en **ST** (`CODE/MAIN/PRG_XX_*.st`) et converti en PLCopenXML par
> `TOOLS/ST_PLCOPENXML_GENERATOR`. Aucune page CFC native `.xml` n'est produite.

Les programmes sont des sources ST ; le générateur produit le bundle PLCopenXML
(`<ST>`, `<LD>`, `<FBD>` selon le suffixe). La renumérotation 7 POU (`PRG_02`→`PRG_07`)
est soldée. Historique de la migration : `ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`.

## 📐 6. Règles de génération Ladder (`_LD.st` → `<LD>`)

> 🚩 Référentiel complet & règles de génération : voir [`DOC/STDS/CODE_QUALITY_STANDARDS.md §11`](../STDS/CODE_QUALITY_STANDARDS.md).

Un programme suffixé `_LD` est une **source ST** convertie en `<LD>` dans le bundle PLCopenXML par `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py`.

### Câblage `FB_Output` et retrait de `FB_Input`

| FB | Statut v2.1 | Règle |
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

## 📚 Documents lies

- Partie 01 : AU, coupure puissance et rearmement.
- Partie 02 : pages CFC, programmes et flux inter-domaines.
- Parties 04 a 14 : contrats metier detailles et champs de leurs DUT.
