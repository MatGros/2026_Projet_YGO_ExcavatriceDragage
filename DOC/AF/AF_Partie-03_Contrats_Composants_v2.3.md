# Analyse Fonctionnelle — Partie 3 : Contrats Composants (v2.3)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🎯 Rôle et périmètre

- **Rôle** : définir les contrats publics des FB, des DUT internes et des pages CFC.
- **Périmètre** : profils de composants, cycle de vie/états/défauts (socle `FB_FbStatus`),
  contrats DUT, règles CFC/Ladder. Ne définit pas : la chaîne électrique AU et le réarmement
  (propriétaires de la Partie 01), l'architecture programme/ordonnancement (Partie 02).
- **Type de composant** : Fondations méta — pas de FB unique porteur. Le socle transverse
  `FB_FbStatus` (implémentation du contrat `standard`) a sa propre fiche détaillée depuis v2.3 :
  [`FB_FbStatus_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md).

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

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P03-001</code></nobr> | Cycle de vie et neutralisation `Enable` | `Enable=FALSE` neutralise commandes et statut (gate) ; `Enable=TRUE` autorise l'état Ready | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P03-002</code></nobr> | Reset inconditionnel (Cause/Ack) | Front `Reset` efface l'affichage (interlock reste sur Cause) | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P03-003</code></nobr> | Pas de redémarrage auto après Ack | Retour READY, nouvel ordre explicite requis | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P03-004</code></nobr> | Pas de `SafeStop`/`StartStop` hors mouvement | Absents des briques E/S, joystick et diag | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P03-005</code></nobr> | Encapsulation stricte | Échanges via interfaces/DUTs publics uniquement | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P03-006</code></nobr> | Re-latch sur ré-apparition Cause | Nouveau front Cause ➔ `Ack=FALSE` | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P03-007</code></nobr> | Warning auto-effaçable vs Fault latché | Warning s'efface sans Reset, Fault exige Ack | `💻 AUTO` | <small>§4</small> |

> Catalogue `TC-P03-008` à `TC-P03-013` (détail `FB_FbStatus` — cumul de défauts, sélection texte
> IHM, bornes de liste, faille T148...) **déplacé dans la fiche dédiée** depuis v2.3 — propriétaire
> unique, pas dupliqué ici (`GUIDE_EDITION_AF_v1.0.md` §4) :
> [`FB_FbStatus_v1.0.md` §2](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md#2--points-de-validation-détail).

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
`Reset : BOOL` (front d'acquittement). `VAR_OUTPUT` : `Ready : BOOL` + `Status : ST_FbStatus`
**seuls** — pas de champ `Error`/`ErrorId`/`Busy`/`Done` à plat en complément (rempli via le socle
`FB_FbStatus`, détail complet : [`FB_FbStatus_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md)).

> 🎯 **Le critère de classement est « remonte-t-il un défaut ? », pas « a-t-il une machine d'état ? ».**
> Un device qui remonte un défaut capteur/calibration/bus (ex. `FB_Joystick`) est `standard`, même
> sans machine d'état — `State`/`StateAtError` sont alors remplis par le socle (valeur `READY`).

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

**4. Tolérance transitoire T137** : les FB antérieurs exposent encore le défaut **à plat**
(`Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError` en `VAR_OUTPUT`, sans `Warning`, sans
textes) — accepté le temps de la migration, **uniquement** pour les FB existants. Tout FB
**nouveau** porte `Status : ST_FbStatus` rempli via `FB_FbStatus`. Ce n'est **pas** une seconde
forme de conformité permanente.

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
- Deux categories de defaut a distinguer des la conception d'un composant : **Warning** (auto-efface
  avec la cause, aucun acquittement) et **Fault** (necessite un acquittement explicite, meme si la
  cause a disparu ; reapparait si la cause revient apres acquittement). Pattern `Cause`/`Ack` et regle
  complete : `DOC/STDS/CODE_QUALITY_STANDARDS.md §9`.
- L'acquittement ne redemarre jamais un mouvement : une nouvelle demande explicite est requise.
- `ErrorId` est un bitfield cumulatif. Chaque bit a une cause, un proprietaire et un texte IHM documentes.
- `Error := (ErrorId <> 0)`.
- `State` decrit la phase ; `StateAtError` fige la phase lors du defaut jusqu'a l'acquittement effectif.

### 4.1 Socle `FB_FbStatus` — pointeur (détail déplacé en fiche dédiée v2.3)

> 🧩 Implémentation concrète du pattern Cause/Ack décrit en §4. Un seul socle, réutilisé par
> tout FB `standard` qui doit remplir `Status : ST_FbStatus` — code écrit une fois, comportement
> identique partout (cf. §3 Profils de composants).

**But** : remplir de façon standardisée la sortie `Status : ST_FbStatus` d'un FB métier —
classification Fault (latché, à acquitter) vs Warning (auto-effacé), textes IHM prêts à
afficher, sans que chaque FB métier ré-implémente sa propre logique d'acquittement.

**Où il se place** : instancié **dans** le FB métier qui expose `Status : ST_FbStatus` (pas un
programme séparé). Consommateur actuel confirmé : `FB_Joystick` (`instFbStatus`,
`CODE/D_JOYSTICK/FB_Joystick.st`). Forme cible destinée à se généraliser aux autres FB `standard`
(cf. §3).

📄 **Interface complète (IN/OUT, type `ST_FbCause`), décisions (a)/(b)/(c), câblage minimal
copiable, limites T147/T148 et catalogue de tests** : voir
[`FB_FbStatus_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md) — ce chapô ne garde
que le résumé ci-dessus, le détail vit désormais uniquement dans la fiche dédiée
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
| v2.3 | 2026-08-26 | Décongestion du chapô : détail complet de `FB_FbStatus` (interfaces, type `ST_FbCause`, décisions a/b/c, câblage minimal, <nobr><code>TC-P03-008</code></nobr> à `013`) déplacé vers une fiche dédiée [`FB_FbStatus_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md), suivant le pattern chapô/sous-fiche déjà appliqué par AF10/`FB_Bucket`. §4.1 et §3 ne gardent qu'un résumé + pointeur. Précision ajoutée en §3 : le contrat `standard` porte `Ready`+`Status` **seuls**, sans mirror `Error`/`ErrorId` à plat en complément (écart constaté sur `FB_Joystick.st`, à corriger séparément). |
| v2.2 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lie, section `🎯 Rôle et périmètre` explicite, ajout Suivi historique et TBD, renumerotation complete des sections (chapô + réfs internes §N cascadées). Correctifs de fond (review sous-agent expert automatisme) : lien casse `AGENTS.md §1bis` corrige, exemple positif `FB_Winch` ajoute a cote du contre-exemple `FB_Joystick` (règle `PowerContactorEngaged`), limite du test automatique `light`/`standard` documentee (ne derive pas le critere semantique du corps du FB), cablage minimal `FB_FbStatus` ajoute (exemple ST copiable) |
| v2.1 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 9 · TBD

| # | Question | Impact |
|---|---|---|
| 1 | T148 — `Reset` maintenu (niveau haut) sans nouveau front pendant que la cause disparaît : acquittement silencieux, sans confirmation au moment réel (<nobr><code>TC-P03-012</code></nobr>) | Comportement actuel prouvé, pas validé comme cible — décision à trancher (exiger un nouveau front strict ?) |

## 📚 10 · Documents liés

- Partie 01 : AU, coupure puissance et rearmement.
- Partie 02 : pages CFC, programmes et flux inter-domaines.
- Parties 04 a 14 : contrats metier detailles et champs de leurs DUT.
- [`FB_FbStatus_v1.0.md`](AF_Partie-03_Contrats_Composants/FB_FbStatus_v1.0.md) : fiche détaillée
  du socle transverse `FB_FbStatus` (interfaces, décisions a/b/c, câblage, TC-008 à 013).
