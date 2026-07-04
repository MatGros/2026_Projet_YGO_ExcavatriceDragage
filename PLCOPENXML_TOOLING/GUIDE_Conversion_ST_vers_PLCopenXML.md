# Guide — Conversion ST → PLCopenXML pour CODESYS 3.5

> ⚠️ **Ce dossier est hors périmètre du projet d'automatisme** (pas de la doc fonctionnelle,
> pas du code machine). C'est un **outil de travail** pour permettre un import sélectif d'un
> FB/PROGRAM/STRUCT/ENUM/GVL dans CODESYS sans réimporter tout le projet.
>
> **Statut : règles confirmées sur échantillons réels** (`samples_reference_codesys/`,
> exportés depuis **CODESYS V3.5 SP19 Patch 1**, projet `Programme MGS_v0.3.10_Simulation`) :
> `FB_Winch.xml` (FUNCTION_BLOCK), `PRG_MAIN.xml` (PROGRAM), `E_DiagState.xml` (ENUM),
> `ST_WinchHMI.xml` (STRUCT), `GVL_IHM.xml` / `GVL_PERSISTENT.xml` (GVL, retain / retain+persistent).
> Les points encore non couverts par un échantillon sont marqués `🟡 TBD`.

---

## 0. Pourquoi ce document existe

But : pouvoir écrire un FB/PROGRAM/STRUCT/ENUM/GVL en ST brut (comme dans `CODE/`), le
convertir en un fichier `.xml` au format **PLCopenXML**, et l'importer **sélectivement** dans
CODESYS via `Project → Import PLCopenXML` — sans passer par tout le projet, et sans reproduire
l'ancien pipeline `tools/inject.py`/`st2xml.py` (abandonné — celui-là patchait le format interne
propriétaire `Device.export` par GUID, pas du vrai PLCopenXML).

Deux choses confirmées par la doc officielle CODESYS :
- L'import PLCopenXML matche les objets **par nom**, pas par GUID. En cas de conflit de nom :
  remplacer l'existant / renommer le nouveau (`_<n>`) / ignorer.
- `Project → Export PLCopenXML` permet de sélectionner un sous-ensemble d'objets précis.

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
| `VAR_IN_OUT` / `VAR_TEMP` | 🟡 TBD — aucun FB échantillon n'en utilise. Par analogie avec `inputVars`/`outputVars`/`localVars`, attendre `<inOutVars>` / `<tempVars>` au même niveau, mais non vérifié.

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
| Valeur par défaut | `<initialValue><simpleValue value="..."/></initialValue>` (texte litéral, y compris préfixe `TIME#`) |

🟡 TBD (non couverts par les échantillons actuels) : `STRING(n)`, `ARRAY[..] OF`.

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

Confirmé sur `E_DiagState.xml` :

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
    <data name="http://www.3s-software.com/plcopenxml/objectid" handleUnknown="discard">
      <ObjectId>...</ObjectId>
    </data>
  </addData>
</dataType>
```

⚠️ **Correction importante par rapport à la 1ère version de ce guide** : `value` est un
**attribut** (`<value name="X" value="0" />`), pas un élément enfant imbriqué. Pas de
`<baseType>` séparé pour le type entier sous-jacent (contrairement à ce qui était supposé) —
non observé dans l'échantillon `E_DiagState` (5 valeurs, `INT` implicite).

---

## 5. Global Variable Lists (GVL) — extension propre à CODESYS, hors norme PLCopen de base

Confirmé sur `GVL_IHM.xml` (`retain="true"`) et `GVL_PERSISTENT.xml` (`retain="true"
persistent="true"`). **Une GVL n'apparaît PAS dans `<types>`** : c'est une extension
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
- 🟡 TBD : GVL **non-retain** (simple `VAR_GLOBAL`) — pas d'échantillon sans l'attribut
  `retain`, à vérifier (probablement `retain="false"` ou l'attribut simplement absent).
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
- Import = conflit résolu **par nom** (remplacer / renommer / ignorer) : pas besoin de faire
  correspondre un `ObjectId` existant pour mettre à jour un objet déjà présent.
- Le placement dans l'arbre (`<ProjectStructure><Folder Name="...">`) est piloté par le nom
  de dossier choisi dans le fichier généré — reproduire le nom du sous-dossier `CODE/` d'origine.

---

## 7. Ce qui reste à vérifier (🟡 TBD, pas d'échantillon disponible)

| Point | Pourquoi c'est encore incertain |
|---|---|
| `STRING(n)` | Aucune variable `STRING` dans les échantillons actuels. |
| `ARRAY[..] OF ...` | Idem. |
| `VAR_IN_OUT`, `VAR_TEMP` | Aucun FB échantillon n'en déclare. |
| GVL simple (non-retain) | Les 2 GVL échantillons sont `retain` (l'une aussi `persistent`). |
| `VAR_GLOBAL CONSTANT` | Non observé — juste la contrainte documentée officiellement (§6). |
| Comportement exact à l'import d'un `dataType` référencé par un FB mais absent du fichier (ex. importer `FB_Winch.xml` seul alors que `ST_SpeedStepTable`/`E_State` ne sont pas inclus) | Pas testé ; probablement un échec d'import ou une résolution différée — **à tester avant de généraliser un générateur qui n'exporterait qu'un seul objet à la fois sans ses dépendances**. |

Si tu recroises un de ces cas dans CODESYS, un export de plus dans
`samples_reference_codesys/` suffit à trancher.

---

## 📚 Sources

- Échantillons réels : `PLCOPENXML_TOOLING/samples_reference_codesys/*.xml` (CODESYS V3.5 SP19 Patch 1)
- [Command: Export PLCopenXML](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_cmd_export_plcopenxml.html)
- [Command: Import PLCopenXML](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_cmd_import_plcopenxml.html)
- [Exporting and Importing Projects (CODESYS)](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_project_export_import.html)
