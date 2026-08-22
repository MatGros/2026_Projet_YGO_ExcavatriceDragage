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
| <nobr><code>TC-P03-009</code></nobr> | Priorité d'affichage texte IHM si Fault+Warning actifs ensemble | Texte du bit actif le plus bas affiché (comportement documenté, pas de priorité Fault>Warning à ce jour) | `💻 AUTO` | <small>§3.1</small> |
| <nobr><code>TC-P03-010</code></nobr> | Bornes du bitfield `ErrorId`/`WarningId` (16 bits) | `bit0` et `bit15` correctement gérés, pas d'off-by-one | `💻 AUTO` | <small>§3.1</small> |
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
programme séparé) — le FB métier ne fait que déclarer où vivent ses bits d'erreur
(`ErrorIdCause`, `WarningMask`) et recopie `Status := instFbStatus.Status`. Consommateur actuel
confirmé (`grep CODE/`, 2026-08-22) : `FB_Joystick` (`instFbStatus`, `CODE/D_JOYSTICK/FB_Joystick.st`).
Forme cible destinée à se généraliser aux autres FB `standard` (cf. §2).

**Interfaces** :

| Sens | Nom | Type | Rôle |
|---|---|---|---|
| IN | `Enable` | `BOOL` | Autorisation générale — `FALSE` neutralise le statut (façade), voir limite ci-dessous |
| IN | `Reset` | `BOOL` | Front d'acquittement, jamais conditionné par un état externe (§3) |
| IN | `ErrorIdCause` | `WORD` | Bits d'erreur **actifs** (cause brute), fournis par le FB métier |
| IN | `WarningMask` | `WORD` | `bit=1` → ce bit est Warning (auto-effacé) ; `bit=0` (défaut) → Fault (à acquitter) — fail-safe |
| IN | `ErrorTexts[0..15]` | `ARRAY OF STRING` | Textes IHM par bit, source pour `ErrorIdTxt` **quel que soit** Fault ou Warning |
| IN | `WarningTexts[0..15]` | `ARRAY OF STRING` | Textes IHM par bit, source pour `WarningIdTxt` uniquement |
| OUT | `Ready` | `BOOL` | Recopie de `Enable` |
| OUT | `Status` | `ST_FbStatus` | Statut complet — mappé 1:1 sur la sortie `Status` du FB métier appelant |

**Comportement clé** (détail Cause/Ack : §3 + `CODE_QUALITY_STANDARDS.md §9`) :
- Un bit est **exclusivement** Fault ou Warning (jamais les deux) selon `WarningMask`.
- `ErrorId` = union (`ErrorIdLatched OR FaultCause OR WarningCause`) : reste vrai tant que la
  cause brute est active, **même si** le latch vient d'être vidé (protection anti-acquittement
  prématuré, cf. `TC-P03-012` pour la limite connue de cette protection).
- Sélection du texte IHM : **premier bit actif le plus bas**, pas de priorité Fault > Warning
  (`TC-P03-009`) — à challenger côté spec si un cas réel de Fault+Warning simultanés apparaît.
- `State`/`StateAtError` : remplis par le socle à `READY` par défaut — un FB avec sa **propre**
  machine d'état (ex. séquenceur treuil) ne doit pas s'appuyer dessus (cf. `FB_Modes.st`, qui
  gère sa capture lui-même sans passer par ce socle).
- `Busy`/`Done` : **non gérés par le socle**, à la charge du FB métier appelant selon son cycle.

**⚠️ Limites connues, non résolues au 2026-08-22** (voir `DOC/WFLOW/PLAN_TASK.md` T147/T148,
décision de spec en attente d'implémentation) :
- **T147** : `Enable=FALSE` remet actuellement `ErrorIdLatched` à zéro — un défaut non acquitté
  disparaît silencieusement si le FB est désactivé puis réactivé sans `Reset`. Décision actée :
  ce comportement doit changer (le latch doit survivre à un cycle `Enable=FALSE`).
- **T148** : un `Reset` simplement **maintenu** (niveau haut, pas de nouveau front) pendant que
  la cause disparaît acquitte silencieusement le défaut, sans confirmation au moment réel de la
  disparition — prouvé par `TC-P03-012`.

**Tests** (`TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st`, 11 scénarios,
multi-scans) :

| ID | Scénario | Points clés vérifiés |
|---|---|---|
| <nobr><code>TC-P03-001</code></nobr> | Gate `Enable=FALSE` | Statut neutre, `Ready=FALSE` |
| — | Nominal sans cause | `Ready=TRUE`, aucun défaut ni warning |
| <nobr><code>TC-P03-007</code></nobr> | Warning auto-effacé | Apparition + texte IHM + disparition sans `Reset` |
| <nobr><code>TC-P03-002/003</code></nobr> | Fault latché | Mémorisé après disparition de la cause, acquitté seulement par `Reset` avec cause absente |
| <nobr><code>TC-P03-006</code></nobr> | `Reset` refusé si cause présente | Interlock sur la cause brute, jamais sur l'acquittement |
| <nobr><code>TC-P03-008</code></nobr> | Cumul multi-bits latchés | 2 faults apparus à des instants différents s'accumulent, acquittés ensemble |
| <nobr><code>TC-P03-009</code></nobr> | Fault + Warning simultanés | Texte affiché = bit le plus bas (comportement documenté) |
| <nobr><code>TC-P03-010</code></nobr> | Bornes bitfield | `bit0` et `bit15` |
| <nobr><code>TC-P03-011</code></nobr> | `Reset` à vide | Aucun effet parasite |
| <nobr><code>TC-P03-012</code></nobr> | `Reset` maintenu + cause qui disparaît | ⚠️ Faille T148 prouvée |
| <nobr><code>TC-P03-013</code></nobr> | Texte IHM non configuré | Chaîne vide, pas de plantage |

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
