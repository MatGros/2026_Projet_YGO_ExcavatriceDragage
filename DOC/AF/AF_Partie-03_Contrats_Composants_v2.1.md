# Analyse Fonctionnelle — Partie 3 : Contrats Composants (v2.1)

> Role : definir les contrats publics des FB, des DUT internes et des pages CFC.
> La chaine electrique AU et le rearmement sont proprietaires de la Partie 01.

## 🧭 Sommaire rapide

1. Regles socle
2. Profils de composants
3. Cycle de vie, etats et defauts
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

> 🚩 REX 2026-08 : trois bugs d'import CODESYS sur `PRG_01_Inputs_LD` ont nécessité
> la formalisation des règles de génération LD. Référentiel complet :
> `DOC/STDS/CODE_QUALITY_STANDARDS.md §11`.

Un programme suffixe `_LD` est une **source ST** convertie en `<LD>` dans le
bundle PLCopenXML par `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py`.

### Rung complet obligatoire

Chaque rung doit contenir la chaîne complète :

```text
leftPowerRail → contact → block(FB) → coil → rightPowerRail
```

CODESYS rejette les rungs incomplets (sans coil ou sans rightPowerRail).

### Câblage `FB_Output` et retrait de `FB_Input`

| FB | Statut v2.1 | Règle |
|---|---|---|
| `FB_Output` | Actif | `Command` → barrières/interlocks → `.State`/sortie physique |
| `FB_Input` | Déprécié | Aucun nouveau rung, aucune nouvelle instance ; retrait après remappage acquisition |

Les entrées sont désormais observées et publiées par `PRG_02_Acquisition` en ST via `HwReal`,
`HwSim` et `HwIn`. La conversion automatique d'un `GetDeviceState()` en `BOOL` dans une page LD
est interdite : `GetDeviceState()` retourne un `DEVICE_STATE` et le diagnostic module reste
centralisé dans l'acquisition.

Les règles de rung ci-dessous restent applicables à `FB_Output` et aux éventuels anciens rungs
jusqu'à leur retrait contrôlé.

### Expressions BOOL — pas d'inVariable/outVariable

- `NOT var` → contact `negated="true"` (jamais d'`inVariable`).
- `var1 AND var2` → série de contacts.
- `var1 OR var2` → parallèle de contacts.
- Une page `_LD` BOOL pure ne contient **aucun** `inVariable`/`outVariable` —
  uniquement `contact`, `coil`, `block` et `comment`.
- Les `inVariable`/`outVariable` sont réservés aux expressions typées non-BOOL
  (TIME, INT, WORD, REAL) dans la section multi-paramètres du générateur.

### Tests de régression

```powershell
python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_ld_import_guard.py -v
```

## 📚 Documents lies

- Partie 01 : AU, coupure puissance et rearmement.
- Partie 02 : pages CFC, programmes et flux inter-domaines.
- Parties 04 a 14 : contrats metier detailles et champs de leurs DUT.
