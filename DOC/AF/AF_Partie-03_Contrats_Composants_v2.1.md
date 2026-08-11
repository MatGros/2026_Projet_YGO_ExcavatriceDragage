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
| TC-P03-001 | Priorité `Enable > SafeStop > StartStop` | `SafeStop` impose la rampe rapide même si `StartStop=TRUE` | `💻 AUTO` | §3 |
| TC-P03-002 | Reset inconditionnel (Cause/Ack) | Front `Reset` efface l'affichage (interlock reste sur Cause) | `💻 AUTO` | §3 |
| TC-P03-003 | Pas de redémarrage auto après Ack | Retour READY, nouvel ordre explicite requis | `💻 AUTO` | §3 |
| TC-P03-004 | Pas de `SafeStop`/`StartStop` hors mouvement | Absents des briques E/S, joystick et diag | `💻 AUTO` | §2 |
| TC-P03-005 | Encapsulation stricte | Échanges via interfaces/DUTs publics uniquement | `💻 AUTO` | §1 |
| TC-P03-006 | Re-latch sur ré-apparition Cause | Nouveau front Cause ➔ `Ack=FALSE` | `💻 AUTO` | §3 |
| TC-P03-007 | Warning auto-effaçable vs Fault latché | Warning s'efface sans Reset, Fault exige Ack | `💻 AUTO` | §3 |

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
| ✍️ Producteur unique | Une donnee, un ecrivain ; prouve par fiche contrat + `check_linkage.py`. |
| ✅ `Valid` | Seulement si le lecteur a un repli documente quand `FALSE` (souvent mesures / safety). |
| 🚫 Pas d'ID de connexion | Aucun `ProducerId`, signature ou jeton d'appairage dans les DUT internes. Surcharge et fausse securite en CFC local. |
| 📡 Bus terrain | Identite = adresse device + diag existant (`FB_Diag_Ethercat`, `FB_Diag_CanOpen`, OP/erreur). Pas de second ID applicatif. |
| ⚡ Fail-safe physique | Chaine AU / maintien A-B : absence de commande saine = coupure ; le logiciel ne remplace pas ce filet. |

## 👁️ 5. Regles CFC

- Le flux se lit de gauche a droite : faits qualifies, decision, mouvement, barriere, etat public.
- Les commandes ne se croisent pas : tout arbitrage est realise par un composant proprietaire, expose et nomme.
- Les sorties safety entrent par le haut ou une zone safety dediee, avec une polarite lisible.
- Une page reste limitee a un domaine ; une autre page est reliee par DUT, jamais par interne d'instance.
- Le numero d'ordre graphique ne prouve pas l'ordre scan. La configuration de tache CODESYS et `check_linkage.py` sont les preuves requises.
- Une GVL ne sert pas de bus de commande interne. `GVL_IHM`, persistance et simulation restent des frontieres justifiees.

### Production obligatoire d'une page CFC native

Un programme suffixe `_CFC` est une **source PLCopenXML native** :
`CODE/MAIN/PRG_XX_<Domaine>_CFC.xml`. Il n'est pas ecrit en ST et le generateur
ne le convertit pas depuis un `.st`. Le bundle decouvre et fusionne ce fichier
XML natif tel quel dans la sequence canonique de l'etape 6 ci-dessous.

**Reference de syntaxe reelle :**
`TOOLS/ST_PLCOPENXML_GENERATOR/samples_reference_codesys/PRG_CFC_3FB.xml`
(export CODESYS V3.5 SP19 Patch 1, trois FB). Ce sample est une reference de
**structure XML**, pas de geometrie : ses connecteurs en `(0,0)` ne doivent pas
etre recopies (regle de visibilite ci-dessous).

| Element PLCopenXML observe dans le sample | Role dans la page |
|---|---|
| `<interface><localVars>` | Declaration des instances de FB de la page. |
| `<body><ST><xhtml .../></ST><addData>...<CFC>` | Conteneur CODESYS du dessin CFC natif ; le ST reste vide. |
| `<inVariable localId>` + `<expression>` | Source nommee (variable ou champ DUT) placee a gauche. |
| `<connector localId>` | Relais graphique unique entre une source/sortie et son consommateur. |
| `<block localId executionOrderId typeName instanceName>` | Instance de FB ; `executionOrderId` materialise l'ordre graphique des blocs. |
| `<connection refLocalId>` | Liaison vers le `localId` de la source ou du connecteur. |
| Sortie de FB | Dans le sample, chaque `<variable>` de `<outputVariables>` porte un `<connectionPointOut>` et un `<relPosition>` ; aucun élément top-level `<outVariable>` n'est observe. |

Squelette minimal — balises et imbrication relevees dans le sample (les noms,
`localId`, `executionOrderId` et positions sont a definir pour la page reelle) :

```xml
<project xmlns="http://www.plcopen.org/xml/tc6_0200">
  <types><pous>
    <pou name="PRG_XX_Domaine_CFC" pouType="program">
      <interface><localVars>
        <variable name="instDomaine"><type><derived name="FB_Domaine" /></type></variable>
      </localVars></interface>
      <body>
        <ST><xhtml xmlns="http://www.w3.org/1999/xhtml" /></ST>
        <addData><data name="http://www.3s-software.com/plcopenxml/cfc" handleUnknown="implementation"><CFC>
          <inVariable localId="1"><position x="10" y="10" /><connectionPointOut><expression /></connectionPointOut><expression>Source</expression></inVariable>
          <connector localId="2" name=""><position x="20" y="10" /><connectionPointIn><connection refLocalId="1" /></connectionPointIn></connector>
          <block localId="3" executionOrderId="1" typeName="FB_Domaine" instanceName="instDomaine"><position x="40" y="10" /></block>
        </CFC></data></addData>
      </body>
    </pou>
  </pous></types>
</project>
```

Procedure par page :

1. Partir du sample et conserver son enveloppe `<project>`, `<pou>`, interface,
   `<body>` et extension CODESYS `<CFC>` ; ne pas inventer une balise alternative.
2. Declarer les instances dans `localVars`, puis creer les `inVariable`,
   `connector` et `block` avec des `localId` uniques.
3. Mettre les sources a gauche, les blocs au centre dans l'ordre
   `executionOrderId`, les sorties a droite. Une source ou sortie consommee
   passe par son propre `connector` avant le bloc consommateur.
4. Donner a chaque `connector`, `inVariable` et `block` une position non nulle ;
   les positions de connecteurs sont toutes distinctes. Pour une sortie de FB,
   conserver le pattern observe `<connectionPointOut><relPosition .../></connectionPointOut>`
   dans sa `variable` de `<outputVariables>` ; ne pas declarer de position
   top-level `<outVariable>`, absente du sample. Les coordonnees `(0,0)` du
   sample sont interdites par le REX CFC.
5. Conserver toute logique (`IF`, calcul, arbitrage, ecriture sortie) dans un FB
   proprietaire : la page ne fait que declarer et relier les contrats publics.
6. Generer le bundle, prouver sa liaison, puis executer tous les gates. Le
   runner inclut le controle `check_cfc_wiring.py` des pages CFC natives :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

7. Importer le PLCopenXML dans CODESYS 3.5 et confirmer humainement que les fils
   sont visibles avant de convertir la page suivante. Un XML bien forme ou un
   bundle vert ne remplace pas cette observation.

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
