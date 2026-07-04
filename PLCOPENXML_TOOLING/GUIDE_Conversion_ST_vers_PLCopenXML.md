# Guide — Conversion ST → PLCopenXML pour CODESYS 3.5

> ⚠️ **Ce dossier est hors périmètre du projet d'automatisme** (pas de la doc fonctionnelle,
> pas du code machine). C'est un **outil de travail** pour permettre un import sélectif d'un
> FB/PROGRAM/STRUCT/ENUM/GVL dans CODESYS sans réimporter tout le projet.
>
> **Statut : schéma quasi entièrement confirmé sur échantillons réels** (`samples_reference_codesys/`,
> exportés depuis **CODESYS V3.5 SP19 Patch 1**, projet `Programme MGS_v0.3.10_Simulation`) :
> `FB_Winch.xml` / `FB_Grappin.xml` / `FB_Cycle.xml` (FUNCTION_BLOCK), `PRG_MAIN.xml` (PROGRAM),
> `E_DiagState.xml` / `E_CycleStep.xml` (ENUM), `ST_WinchHMI.xml` / `ST_SpeedStepTable.xml` (STRUCT),
> `GVL_IHM.xml` / `GVL_PERSISTENT.xml` / `GVL_DEBUG.xml` (GVL, retain / retain+persistent / non-retain).
> Quelques points de **comportement à l'import** restent `🟡 TBD` (voir §7 — dépendance de
> type manquante, création auto du dossier cible, ré-import du même objet) : un POC de test
> est prêt dans `test_import_poc/` pour les vérifier directement dans CODESYS.

---

## 0. Pourquoi ce document existe

But : pouvoir écrire un FB/PROGRAM/STRUCT/ENUM/GVL en ST brut (comme dans `CODE/`), le
convertir en un fichier `.xml` au format **PLCopenXML**, et l'importer **sélectivement** dans
CODESYS via `Project → Import PLCopenXML` — sans passer par tout le projet, et sans reproduire
l'ancien pipeline `tools/inject.py`/`st2xml.py` (abandonné — celui-là patchait le format interne
propriétaire `Device.export` par GUID, pas du vrai PLCopenXML).

Trois choses confirmées par la doc officielle CODESYS (menus `Project → Import…` /
`Project → Export…`, sous-commande PLCopenXML) :
- L'import PLCopenXML matche les objets **par nom**, pas par GUID. En cas de conflit de nom,
  la boîte de dialogue d'import propose exactement 3 choix (termes officiels) :
  - **Replace** : l'objet existant du projet est écrasé par l'objet importé.
  - **Rename** : le nouvel objet est importé avec un nom modifié (`_<n>` ajouté en suffixe).
  - **Skip** : l'objet n'est pas importé.
- `Project → Export PLCopenXML` ouvre une boîte de dialogue qui **liste tous les objets de
  l'arbre du device exportables** en PLCopenXML — l'utilisateur coche un sous-ensemble précis.
  La doc officielle ne précise pas si les dépendances (types utilisés) sont cochées
  automatiquement : **à vérifier soi-même à l'export** (probablement non — à cocher à la main).
- **Aucune fidélité à 100 % garantie** (formulation officielle) : PLCopenXML ne couvre qu'un
  sous-ensemble des éléments CODESYS, contrairement au format natif `*.export` qui est
  "fully compatible with the CODESYS project format". Toujours vérifier visuellement après import.

👉 **Bonne pratique recommandée** (pas une exigence documentée par CODESYS, juste du bon sens
projet) : ce dépôt versionne déjà `PRJ_CODESYS/*.project` sous Git — commiter l'état courant
avant un import PLCopenXML permet de revenir en arrière si le résultat ne convient pas.

---

## 0bis. Qu'est-ce que PLCopenXML ? (norme vs extension CODESYS)

### Origine et objectif

**PLCopenXML** est un format d'échange XML défini par le comité technique **PLCopen TC6**,
pour permettre l'échange de programmes IEC 61131-3 (types de données, interfaces de POU, corps
de code FBD/LD/ST/SFC) entre différents environnements de développement industriels (EDI) —
CODESYS, Beremiz, TwinCAT, etc. Objectif affiché : interopérabilité, portabilité d'un
programme (ou d'un fragment) d'un outil à un autre.

### Historique

| Version | Année | Namespace | Remarque |
|---|---|---|---|
| v1.01 | 2005 | — | Première publication du schéma XSD par PLCopen. |
| **v2.0** | 2008 | **`tc6_0200`** | "Official Release". **C'est celle utilisée par CODESYS 3.5 SP19 Patch 1** (confirmé sur les 11 échantillons de `samples_reference_codesys/`). |
| v2.01 | 2009 | `tc6_0201` | Changements mineurs. Version documentée sur le site public PLCopen actuel — **mais pas celle que CODESYS 3.5 SP19 émet réellement** (voir §1). |
| IEC 61131-10 | 2019 | — | En 2014, PLCopen transfère la propriété intellectuelle du schéma à l'IEC ; le travail aboutit à la norme internationale **IEC 61131-10** ("PLCopen XML exchange format"), qui intègre officiellement le format dans la suite IEC 61131. |

### Ce qui est standard vs ce qui est extension propriétaire CODESYS/3S-Software

Le schéma TC6/IEC 61131-10 couvre le "cœur" du langage : types de données, interface de POU
(`VAR_INPUT`/`OUTPUT`/`IN_OUT`/local), corps de code. Il ne prévoit **pas** certaines notions
propres à un EDI donné (listes de variables globales, placement dans une arborescence de
projet, identifiant interne d'objet...). CODESYS comble ces manques via son propre mécanisme
d'extension `<addData><data name="http://www.3s-software.com/plcopenxml/...">`, déjà détaillé
empiriquement section par section dans ce guide :

| | Standard IEC 61131-10 / TC6 (`tc6_0200`) | Extension CODESYS (`3s-software.com`) |
|---|---|---|
| Types de données (STRUCT/ENUM) | ✅ `<types><dataTypes>` | — |
| Interface POU (FB/PROGRAM) | ✅ `<interface>` (`inputVars`/`outputVars`/`inOutVars`/`localVars`) | — |
| Corps de code | ✅ `<body><ST>` (texte brut échappé) | — |
| Listes de variables globales (GVL) | ❌ absent du schéma de base | ✅ `addData[.../globalvars]` (§5) |
| Placement dans l'arbre projet (dossier CODESYS) | ❌ absent du schéma de base | ✅ `addData[.../projectstructure]` (§1) |
| Identifiant interne d'objet | ❌ absent du schéma de base | ✅ `addData[.../objectid]` (GUID, `handleUnknown="discard"`) |
| Attributs enum (`qualified_only`/`strict`) | ❌ absent du schéma de base | ✅ `addData[.../attributes]` (§4) |
| Doc par valeur d'énum (commentaire `//` par valeur) | ❌ absent du schéma de base | ✅ `addData[.../enumvaluedocumentation]` (§4) |

### ⚠️ Conséquence pratique pour ce générateur

Un fichier produit par cet outil sera fidèle **à l'implémentation CODESYS 3.5 SP19 Patch 1**
(namespace `tc6_0200` + extensions `3s-software.com`), pas garanti portable tel quel vers un
autre EDI IEC 61131-3 : la norme garantit l'interopérabilité pour le cœur (types/POU/corps),
pas pour le placement dans l'arbre, les GVL, ni les autres extensions propriétaires
`3s-software.com` ci-dessus. Ce n'est pas un problème pour l'usage visé ici (aller-retour
CODESYS ↔ CODESYS), mais à garder en tête si le fichier généré devait un jour servir ailleurs.

**Sources** : [PLCopen — Technical Committees / XML](https://www.plcopen.org/technical-committees),
[IEC 61131-10:2019](https://webstore.iec.ch/publication/29056).

---

## 1. Structure générale d'un fichier PLCopenXML CODESYS

```xml
<?xml version="1.0" encoding="utf-8"?>
<project xmlns="http://www.plcopen.org/xml/tc6_0200">
  <fileHeader companyName="" productName="CODESYS" productVersion="CODESYS V3.5 SP19 Patch 1"
              creationDateTime="2026-07-04T07:56:09.9828169" />
  <contentHeader name="<Nom du projet>.project" modificationDateTime="...">
    <coordinateInfo>
      <fbd><scaling x="1" y="1" /></fbd>
      <ld><scaling x="1" y="1" /></ld>
      <sfc><scaling x="1" y="1" /></sfc>
    </coordinateInfo>
    <addData>
      <data name="http://www.3s-software.com/plcopenxml/projectinformation" handleUnknown="implementation">
        <ProjectInformation>
          <property name="Project" type="string"><Nom du projet></property>
        </ProjectInformation>
      </data>
    </addData>
  </contentHeader>
  <types>
    <dataTypes>  <!-- ou <dataTypes /> si aucune STRUCT/ENUM -->
      <dataType name="...">...</dataType>
    </dataTypes>
    <pous>       <!-- ou <pous /> si aucun FB/PROGRAM -->
      <pou name="..." pouType="functionBlock|program">...</pou>
    </pous>
  </types>
  <instances>
    <configurations />
  </instances>
  <addData>
    <!-- Uniquement si GVL exportée (voir §5) -->
    <data name="http://www.3s-software.com/plcopenxml/globalvars" handleUnknown="implementation">
      <globalVars name="GVL_X" retain="true">...</globalVars>
    </data>
    <!-- TOUJOURS présent : placement dans l'arborescence CODESYS -->
    <data name="http://www.3s-software.com/plcopenxml/projectstructure" handleUnknown="discard">
      <ProjectStructure>
        <Folder Name="NOM_DOSSIER_CODESYS">
          <Object Name="<Nom objet>" ObjectId="<GUID>" />
        </Folder>
      </ProjectStructure>
    </data>
  </addData>
</project>
```

Points confirmés (pas des suppositions) :
- **Namespace réel utilisé par CODESYS 3.5 SP19** : `http://www.plcopen.org/xml/tc6_0200`
  (pas `tc6_0201` comme documenté sur le site PLCopen public — CODESYS embarque une révision
  antérieure du schéma).
- `<types><dataTypes/>` et `<types><pous/>` sont **auto-fermants quand vides** (les 2 sont
  toujours présents même si l'un des deux ne contient rien).
- `<instances><configurations /></instances>` : boilerplate vide pour un export d'objet(s)
  isolé(s) (pas de config de tâche exportée).
- **Bloc `<addData name=".../projectstructure">` obligatoire** : c'est lui qui indique à
  CODESYS **dans quel dossier de l'arbre projet** ranger l'objet importé (`Folder Name=`
  correspond exactement au nom du sous-dossier `CODE/` d'origine : `WINCH`, `SYSTEM`,
  `SUPERVISION`, etc. — mapping direct et pratique pour un générateur).
- `ObjectId` (GUID) : présent partout mais avec `handleUnknown="discard"` → CODESYS peut
  l'ignorer sans erreur. Un GUID fraîchement généré (`uuid4`) pour un nouvel objet convient
  (confirme ce qu'indique la doc officielle : le matching à l'import se fait par **nom**, pas
  par cet ObjectId).

---

## 2. Function Block / Program (`<pou>`)

Confirmé sur `FB_Winch.xml` (functionBlock, ~30 VAR_INPUT/OUTPUT/VAR) et `PRG_MAIN.xml`
(program) :

```xml
<pou name="FB_MonFB" pouType="functionBlock">
  <interface>
    <inputVars>
      <variable name="Enable">
        <type><BOOL /></type>
      </variable>
      <variable name="MaxStepDescente">
        <type><INT /></type>
        <initialValue><simpleValue value="2" /></initialValue>
        <documentation>
          <xhtml xmlns="http://www.w3.org/1999/xhtml"> 🆕 Plafond palier en descente</xhtml>
        </documentation>
      </variable>
      <variable name="SpeedStepTable">
        <type><derived name="ST_SpeedStepTable" /></type>
      </variable>
    </inputVars>
    <outputVars>
      <variable name="ErrorId"><type><WORD /></type></variable>
    </outputVars>
    <localVars>
      <variable name="SpeedStep"><type><derived name="FB_SpeedStep" /></type></variable>
      <variable name="ResetEdge"><type><derived name="R_TRIG" /></type></variable>
    </localVars>
    <documentation>
      <xhtml xmlns="http://www.w3.org/1999/xhtml"> <!-- gros commentaire d'en-tête du FB, texte brut --> </xhtml>
    </documentation>
  </interface>
  <body>
    <ST>
      <xhtml xmlns="http://www.w3.org/1999/xhtml">
IF NOT Enable OR NOT EmergencyStopOk THEN
    RelayFwd := FALSE;
END_IF;
      </xhtml>
    </ST>
  </body>
  <addData>
    <data name="http://www.3s-software.com/plcopenxml/objectid" handleUnknown="discard">
      <ObjectId>fe1e6af7-da18-4559-8d7e-415a962a53ee</ObjectId>
    </data>
  </addData>
</pou>
```

### Points confirmés / corrigés par rapport aux hypothèses initiales

| Point | Confirmé sur échantillon |
|---|---|
| Corps ST | **Texte brut échappé XML** (`&lt;`, `&gt;`, `&amp;`), directement dans `<xhtml xmlns="http://www.w3.org/1999/xhtml">...</xhtml>` — **PAS de CDATA**, **PAS** de wrapper `<xhtml:p>`. Correction par rapport à la 1ère version de ce guide. |
| Documentation (commentaire d'en-tête du FB) | `<documentation><xhtml xmlns="...">texte brut</xhtml></documentation>` en dernier enfant de `<interface>`, après `localVars`. Même règle d'échappement que le corps. |
| Documentation par variable | Chaque `<variable>` peut avoir son propre `<documentation>` (utilisé pour le commentaire inline `//` de chaque VAR en ST). |
| Valeur par défaut | `<initialValue><simpleValue value="2" /></initialValue>` — confirmé, y compris pour `TIME` : `<simpleValue value="TIME#200ms" />` (texte litéral IEC, pas de conversion). |
| Type dérivé (FB interne, struct, enum) | `<derived name="XXX" />` — confirmé pour instances de FB (`FB_SpeedStep`, `TON`, `R_TRIG`), structures (`ST_SpeedStepTable`), énumérations (`E_Mode`). |
| GUID objet | `<addData><data name=".../objectid" handleUnknown="discard"><ObjectId>...</ObjectId></data></addData>` en dernier enfant du `<pou>`. Peut être un GUID neuf généré côté script. |
| `VAR_IN_OUT` | **Confirmé** sur `FB_Grappin.xml` (`GrappinState : ST_GrappinState`) : `<interface><inOutVars><variable name="GrappinState"><type><derived name="ST_GrappinState"/></type>...</variable></inOutVars></interface>` — même structure que `inputVars`/`outputVars`, positionné après `outputVars` et avant `localVars`. |
| `VAR_TEMP` | 🟡 non vérifié (aucun FB échantillon n'en déclare) — par analogie, `<tempVars>` au même niveau. |

### Mapping ST → PLCopenXML (confirmé)

| Bloc ST | Élément PLCopenXML |
|---|---|
| `FUNCTION_BLOCK <Nom>` | `<pou name="<Nom>" pouType="functionBlock">` |
| `PROGRAM <Nom>` | `<pou name="<Nom>" pouType="program">` |
| `VAR_INPUT ... END_VAR` | `<interface><inputVars>` |
| `VAR_OUTPUT ... END_VAR` | `<interface><outputVars>` |
| `VAR ... END_VAR` (interne) | `<interface><localVars>` |
| Commentaire d'en-tête `(* ... *)` | `<interface><documentation><xhtml>` |
| Commentaire inline `// ...` sur une variable | `<variable><documentation><xhtml>` |
| Corps ST (implémentation) | `<body><ST><xhtml xmlns="http://www.w3.org/1999/xhtml">texte échappé</xhtml></ST></body>` |

### Mapping des types de base IEC 61131-3 (confirmé)

| ST | PLCopenXML |
|---|---|
| `BOOL` | `<BOOL/>` |
| `INT` | `<INT/>` |
| `WORD` | `<WORD/>` |
| `REAL` | `<REAL/>` |
| `TIME` | `<TIME/>` |
| `TON`, `R_TRIG` (FB standard IEC) | `<derived name="TON"/>` |
| `E_Mode`, `FB_SpeedStep`, `ST_SpeedStepTable` (type/FB du projet) | `<derived name="..."/>` |
| `STRING(n)` | **Confirmé** sur `FB_Cycle.xml` (`CycleStateStr`) : `<string length="80" />` — attribut `length`, pas d'élément enfant. |
| `ARRAY[a..b] OF T` | **Confirmé** sur `ST_SpeedStepTable.xml` (`StepThreshold_Pct : ARRAY[1..5] OF REAL`) : `<array><dimension lower="1" upper="5" /><baseType><REAL /></baseType></array>` — une `<dimension>` par dimension (tableau multi-dim = plusieurs `<dimension>` successives, non vérifié mais cohérent avec le schéma TC6). |
| Valeur par défaut | `<initialValue><simpleValue value="..."/></initialValue>` (texte litéral, y compris préfixe `TIME#`) |

---

## 3. Structures (`TYPE ... STRUCT ... END_STRUCT END_TYPE`)

Confirmé sur `ST_WinchHMI.xml` (33 membres) :

```xml
<dataType name="ST_AxisCmd">
  <baseType>
    <struct>
      <variable name="StartStop">
        <type><BOOL /></type>
        <documentation><xhtml xmlns="http://www.w3.org/1999/xhtml"> commentaire </xhtml></documentation>
      </variable>
      <variable name="PositionM">
        <type><REAL /></type>
        <initialValue><simpleValue value="12.5" /></initialValue>
      </variable>
    </struct>
  </baseType>
  <addData>
    <data name="http://www.3s-software.com/plcopenxml/objectid" handleUnknown="discard">
      <ObjectId>818e37d8-0c03-4540-a2bb-61a33833a34f</ObjectId>
    </data>
  </addData>
  <documentation>
    <xhtml xmlns="http://www.w3.org/1999/xhtml"> commentaire d'en-tête de la structure </xhtml>
  </documentation>
</dataType>
```

Placé dans `<types><dataTypes>` (pas `<pous>`, qui reste `<pous />` vide dans ce cas).

---

## 4. Énumérations (`TYPE ... ENUM ... END_TYPE`)

Confirmé sur `E_DiagState.xml` (5 valeurs) et `E_CycleStep.xml` (13 valeurs, avec commentaire
par valeur) :

```xml
<dataType name="E_CycleStep">
  <baseType>
    <enum>
      <values>
        <value name="INIT" value="0" />
        <value name="WORK_POS_SELECT" value="1" />
        <value name="ERROR_HOLD" value="12" />
      </values>
    </enum>
  </baseType>
  <addData>
    <!-- Commentaire // inline par valeur d'énum (optionnel) -->
    <data name="http://www.3s-software.com/plcopenxml/enumvaluedocumentation" handleUnknown="implementation">
      <EnumValueDocumentation>
        <EnumValue>
          <Name>INIT</Name>
          <Documentation>
            <xhtml xmlns="http://www.w3.org/1999/xhtml"> Vérifs cohérence états + sécurités </xhtml>
          </Documentation>
        </EnumValue>
        <!-- une <EnumValue> par valeur documentée -->
      </EnumValueDocumentation>
    </data>
    <!-- Attributs enum "strict" (comportement par défaut de CODESYS pour un TYPE ENUM) -->
    <data name="http://www.3s-software.com/plcopenxml/attributes" handleUnknown="implementation">
      <Attributes>
        <Attribute Name="qualified_only" Value="" />
        <Attribute Name="strict" Value="" />
      </Attributes>
    </data>
    <data name="http://www.3s-software.com/plcopenxml/objectid" handleUnknown="discard">
      <ObjectId>...</ObjectId>
    </data>
  </addData>
</dataType>
```

⚠️ **Correction importante par rapport à la 1ère version de ce guide** : `value` est un
**attribut** (`<value name="X" value="0" />`), pas un élément enfant imbriqué. Pas de
`<baseType>` séparé pour le type entier sous-jacent — non observé (`INT` implicite).

Points additionnels confirmés sur `E_CycleStep.xml` :
- Le commentaire `//` placé après chaque valeur en ST (ex. `INIT := 0, (* ... *)`) devient un
  bloc `<EnumValueDocumentation>` **séparé**, dans `addData` du `dataType` — pas attaché au
  `<value>` lui-même (le schéma TC6 n'a pas prévu de documentation par valeur).
- `qualified_only` + `strict` : attributs CODESYS par défaut pour un `TYPE ... : (...) END_TYPE`
  moderne (accès uniquement via `E_CycleStep.INIT`, pas juste `INIT`) — à reproduire tel quel
  pour tout nouvel enum généré, sauf besoin explicite contraire.

---

## 5. Global Variable Lists (GVL) — extension propre à CODESYS, hors norme PLCopen de base

Confirmé sur `GVL_IHM.xml` (`retain="true"`), `GVL_PERSISTENT.xml` (`retain="true"
persistent="true"`) et `GVL_DEBUG.xml` (**aucun attribut** — GVL simple non-retain).
**Une GVL n'apparaît PAS dans `<types>`** : c'est une extension
CODESYS/3S-Software placée directement dans le **`<addData>` de niveau `<project>`** :

```xml
<addData>
  <data name="http://www.3s-software.com/plcopenxml/globalvars" handleUnknown="implementation">
    <globalVars name="GVL_IHM" retain="true">
      <variable name="WinchM1">
        <type><derived name="ST_WinchHMI" /></type>
        <documentation><xhtml xmlns="http://www.w3.org/1999/xhtml"> commentaire </xhtml></documentation>
      </variable>
      <!-- ... -->
      <addData>
        <data name="http://www.3s-software.com/plcopenxml/objectid" handleUnknown="discard">
          <ObjectId>da68fdec-ff0d-49e0-a78d-9c44c7a18922</ObjectId>
        </data>
      </addData>
      <documentation>
        <xhtml xmlns="http://www.w3.org/1999/xhtml"> commentaire d'en-tête de la GVL </xhtml>
      </documentation>
    </globalVars>
  </data>
  <data name="http://www.3s-software.com/plcopenxml/projectstructure" handleUnknown="discard">
    <ProjectStructure>
      <Folder Name="SUPERVISION">
        <Object Name="GVL_IHM" ObjectId="da68fdec-ff0d-49e0-a78d-9c44c7a18922" />
      </Folder>
    </ProjectStructure>
  </data>
</addData>
```

- `retain="true"` ↔ `VAR_GLOBAL RETAIN` en ST.
- `retain="true" persistent="true"` ↔ `VAR_GLOBAL PERSISTENT RETAIN` (`GVL_PERSISTENT`).
- **Confirmé** sur `GVL_DEBUG.xml` : GVL simple (`VAR_GLOBAL` sans qualificatif) → élément
  `<globalVars name="GVL_DEBUG">` **sans aucun attribut** `retain`/`persistent` (l'attribut est
  absent, pas mis à `"false"`).
- Variable-niveau `<addData name=".../attributes"><Attributes><Attribute Name="order_in_persistent_editor" Value="0" /></Attributes></addData>` :
  observé sur `GVL_PERSISTENT` (ordre d'affichage dans l'éditeur de persistance CODESYS) —
  **cosmétique, sûr à omettre** dans un fichier généré (pas de `handleUnknown="discard"`
  explicite mais purement lié à l'UI de l'éditeur, pas à la donnée elle-même).

---

## 6. Contraintes et limites connues

- **`VAR_GLOBAL` et `VAR_GLOBAL CONSTANT` ne peuvent pas cohabiter dans la même liste PLCopenXML**
  (doc officielle CODESYS) — à scinder en deux `globalVars` si une GVL mélange les deux.
- **Pas d'export de bibliothèque** via PLCopenXML.
- **Pas de garantie de fidélité à 100 %** (formulation officielle CODESYS) — toujours
  comparer visuellement le résultat après import avant de faire confiance à un lot généré.
- Import = conflit résolu **par nom**, 3 choix officiels **Replace / Rename / Skip** (voir §0)
  : pas besoin de faire correspondre un `ObjectId` existant pour mettre à jour un objet déjà
  présent — un GUID neuf convient même pour remplacer un objet existant du même nom.
- Le placement dans l'arbre (`<ProjectStructure><Folder Name="...">`) est piloté par le nom
  de dossier choisi dans le fichier généré — reproduire le nom du sous-dossier `CODE/` d'origine.

### 👉 Bonne pratique : import d'objets interdépendants

Tant que le point §7 (dépendance de type absente du fichier) n'est pas tranché par un test
réel, la pratique la plus sûre pour ce générateur est de **regrouper dans un seul fichier
`.xml`** (un seul `<project>`, plusieurs `<dataType>`/`<pou>` dans `<types>`) tous les objets
qui se référencent entre eux (ex. une STRUCT + le FB qui la consomme en `VAR_IN_OUT`, ou une
ENUM + les FB qui l'utilisent) — plutôt que de faire plusieurs imports séparés dans un ordre
supposé. Un seul import = une seule transaction CODESYS, donc pas de risque d'ordre.

---

## 7. Ce qui reste à vérifier (🟡 TBD)

Le schéma lui-même est maintenant couvert (FB/PROGRAM, STRUCT, ENUM, GVL retain/persistent/
simple, `VAR_IN_OUT`, `STRING(n)`, `ARRAY[..] OF`). Il reste des points **comportementaux**
(pas des points de syntaxe) qui ne se vérifient pas en lisant un export, mais en testant un
import — voir le POC `PLCOPENXML_TOOLING/test_import_poc/` conçu pour ça :

| Point | Pourquoi c'est encore incertain |
|---|---|
| Comportement exact à l'import d'un `dataType` référencé par un FB mais absent du fichier (ex. importer `FB_Winch.xml` seul alors que `ST_SpeedStepTable`/`E_State` ne sont pas inclus) | Pas testé ; probablement un échec d'import ou une résolution différée — **à tester avant de généraliser un générateur qui n'exporterait qu'un seul objet à la fois sans ses dépendances**. En attendant, voir la bonne pratique de regroupement en §6. |
| Le dossier `<Folder Name="...">` ciblé par `ProjectStructure` est-il créé automatiquement s'il n'existe pas encore dans l'arbre du projet, ou l'import échoue/range-t-il ailleurs ? | Non documenté officiellement. **Testable directement avec le POC `test_import_poc/`** (dossier `_POC_IMPORT_TEST` volontairement inexistant dans le vrai projet). |
| Comportement d'un ré-import du même fichier (même nom d'objet, même `ObjectId` inchangé) : le choix Replace/Rename/Skip est-il re-proposé à l'identique, ou CODESYS détecte-t-il "rien n'a changé" ? | Non documenté officiellement. **Testable avec le POC `test_import_poc/`** (réimporter deux fois de suite). |
| `VAR_GLOBAL CONSTANT` | Non observé dans un échantillon — seule la contrainte documentée officiellement (§6, incompatibilité avec `VAR_GLOBAL` simple dans la même liste) est connue. Faible priorité (peu utilisé dans `CODE/`). |
| `VAR_TEMP` | Non observé — par analogie avec `inOutVars`, `<tempVars>` attendu mais pas vérifié. Faible priorité (rarement utilisé dans le style de code du projet). |

Pour le point prioritaire (import avec dépendance manquante), il n'y a pas besoin d'un nouvel
export : c'est un **test direct dans CODESYS** (importer `FB_Winch.xml` seul dans un projet/
dossier qui n'a pas encore `ST_SpeedStepTable`/`E_State`, observer le résultat).

---

## 📚 Sources

- Échantillons réels : `PLCOPENXML_TOOLING/samples_reference_codesys/*.xml` (CODESYS V3.5 SP19 Patch 1)
- [Command: Export PLCopenXML](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_cmd_export_plcopenxml.html)
- [Command: Import PLCopenXML](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_cmd_import_plcopenxml.html)
- [Exporting and Importing Projects (CODESYS)](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_project_export_import.html)
- [PLCopen — Technical Committees (TC6, XML)](https://www.plcopen.org/technical-committees)
- [IEC 61131-10:2019 — PLCopen XML exchange format](https://webstore.iec.ch/publication/29056)
