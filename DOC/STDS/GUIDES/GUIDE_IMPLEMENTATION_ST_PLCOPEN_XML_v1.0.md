# 📝 Guide d'Implémentation Structured Text (ST) en PLCopen XML (v1.0)

## 🎯 Raison d'être & Responsabilité Unique
- **Problème résolu** : le ST est un langage textuel, mais son enveloppe PLCopen XML
  (`<interface>` typée, `<body><ST><xhtml:p><![CDATA[...]]>`) a ses propres règles strictes de
  structuration — un fichier ST syntaxiquement correct mais mal enveloppé n'importe pas dans
  CODESYS.
- **Périmètre strict** : modélisation XML du langage **ST uniquement** — dataTypes, interface
  (toutes catégories de variables), POU (program/functionBlock/function), actions, structures de
  contrôle, `addData`. Ne couvre pas les sections `<configuration>`/`<resource>`/`<task>` de la
  norme (§7 de la spec source) — hors périmètre volontaire, voir le guide LD pour la même note.
- **Type de composant** : référence technique normative, source secondaire consommée par
  `TOOLS/CONVERTER_ST2XML_PLCopenXML/generator/` (parsing ST → XML) et par tout agent
  lisant/écrivant du ST en PLCopen XML.

> Origine : extraction agent de la spec officielle **PLCopen Technical Committee 6 — XML Formats
> for IEC 61131-3, v2.01** (document intégral en français-technique :
> [`tc6_xml_v201_technical_doc.md`](tc6_xml_v201_technical_doc.md)) — 2026-08-12.

---

## 🧭 Sommaire

| <nobr>§</nobr> | Contenu |
|---|---|
| <nobr>1</nobr> | Vue d'ensemble et principes de modélisation |
| <nobr>2</nobr> | Structure générale d'un fichier PLCopen XML pour du ST |
| <nobr>3</nobr> | Typage des données (`STRUCT`, `ENUM`, `ARRAY`) |
| <nobr>4</nobr> | Section déclarative (`interface`) — toutes catégories de variables |
| <nobr>5</nobr> | Structuration des POU (Programme, Bloc Fonctionnel, Fonction) |
| <nobr>6</nobr> | Actions, transitions et méthodes |
| <nobr>7</nobr> | Syntaxe des structures de contrôle ST |
| <nobr>8</nobr> | Données vendeur et métadonnées (`addData`) |
| <nobr>9</nobr> | Exemple complet importable |
| <nobr>10</nobr> | Tableau récapitulatif des balises et éléments |
| <nobr>11</nobr> | Documents liés |

---

## 1. Vue d'Ensemble et Principes de Modélisation du ST en PLCopen XML

À la différence des langages graphiques (Ladder/LD, FBD, SFC) qui s'appuient sur des coordonnées
cartésiennes et un réseau d'identifiants d'interconnexion (`localId`), le langage **Structured
Text (ST)** est un langage textuel impératif.

En PLCopen XML v2.01, le traitement du ST repose sur une séparation stricte entre :
1. **La section déclarative (`<interface>`)** : Structurée sous forme de nœuds XML typés
   (déclarations des variables d'entrée, de sortie, locales, globales, constantes, résonances de
   rétention, types dérivés, etc.).
2. **La section d'exécution (`<body> / <ST>`)** : Encapsule le code exécutable sous forme de
   texte formaté conforme à la spécification XHTML W3C, souvent encapsulé dans des sections
   `<xhtml:p>` ou des blocs `<![CDATA[ ... ]]>`.

---

## 2. Structure Générale d'un Fichier PLCopen XML pour du ST

Un fichier complet contenant des POUs en ST (Programmes, Blocs Fonctionnels, Fonctions) doit
respecter la hiérarchie standard suivante :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.plcopen.org/xml/tc6_0200"
         xmlns:xhtml="http://www.w3.org/1999/xhtml"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200">
  
  <!-- En-tête du fichier -->
  <fileHeader companyName="MonEntreprise" 
              productName="STGenerator" 
              productVersion="1.0" 
              creationDateTime="2026-08-12T14:00:00"/>
  
  <!-- En-tête de contenu -->
  <contentHeader name="Projet_ST_Exhaustif"/>

  <!-- Section des types : Data Types personnalisés et POUs -->
  <types>
    <dataTypes>
      <!-- Types de données personnalisés (DUTs) : STRUCT, ENUM, ALIAS -->
    </dataTypes>
    <pous>
      <!-- Unités d'organisation de programme (Programmes, FB, Fonctions) -->
    </pous>
  </types>

  <!-- Section des instances (Configurations, Ressources, Tâches — hors périmètre, voir §🎯) -->
  <instances>
    <configurations/>
  </instances>
</project>
```

---

## 3. Typage des Données et Structures Personnalisées (`<dataTypes>`)

Avant de déclarer du code ST, les types de données personnalisés (Structures, Énumérations,
Sous-intervalles, Alias, Tableaux) doivent être définis sous la balise `<dataTypes>`.

### 3.1 Structure (`STRUCT`)
```xml
<dataType name="ST_CapteurMetrique">
  <baseType>
    <struct>
      <variable name="rValeur">
        <type><REAL/></type>
      </variable>
      <variable name="bValide">
        <type><BOOL/></type>
      </variable>
      <variable name="strUnite">
        <type><STRING length="10"/></type>
      </variable>
    </struct>
  </baseType>
</dataType>
```

### 3.2 Énumération (`ENUM`)
```xml
<dataType name="ET_EtatMachine">
  <baseType>
    <enum>
      <values>
        <value name="INIT"/>
        <value name="RUNNING"/>
        <value name="PAUSED"/>
        <value name="ERROR"/>
      </values>
    </enum>
  </baseType>
</dataType>
```

### 3.3 Tableau (`ARRAY`)
```xml
<dataType name="T_Array3D_Buffer">
  <baseType>
    <array>
      <dimension lower="0" upper="99"/>
      <baseType><DINT/></baseType>
    </array>
  </baseType>
</dataType>
```

---

## 4. Analyse Exhaustive de la Section Déclarative (`<interface>`)

La balise `<interface>` définit l'ensemble des variables manipulées par le POU ST. Chaque bloc de
variables peut supporter des attributs spécifiques de rétention, de persistance ou de constance.

### 4.1 Attributs des Blocks de Variables
- `constant="true|false"` : Définit si les variables sont en lecture seule.
- `retain="true|false"` : Conserve les valeurs après un arrêt/redémarrage normal du système.
- `nonretain="true|false"` : Empêche la rétention.
- `persistent="true|false"` : Conserve les valeurs même après un rechargement complet de
  l'application.

### 4.2 Catégories de Variables

#### 1. Variables Locales (`<localVars>`)
```xml
<localVars retain="false">
  <variable name="nCompteur"><type><INT/></type><initialValue><simpleValue value="0"/></initialValue></variable>
  <variable name="rMoyenne"><type><REAL/></type></variable>
</localVars>
```

#### 2. Variables d'Entrée (`<inputVars>`)
```xml
<inputVars>
  <variable name="bEnable"><type><BOOL/></type></variable>
  <variable name="rConsigne"><type><REAL/></type><initialValue><simpleValue value="50.0"/></initialValue></variable>
</inputVars>
```

#### 3. Variables de Sortie (`<outputVars>`)
```xml
<outputVars>
  <variable name="bDone"><type><BOOL/></type></variable>
  <variable name="nErrorCode"><type><WORD/></type></variable>
</outputVars>
```

#### 4. Variables d'Entrée-Sortie (`<inOutVars>`)
Transmises par référence (pointeurs implicites en ST).
```xml
<inOutVars>
  <variable name="stDonneesCapteur">
    <type><derived name="ST_CapteurMetrique"/></type>
  </variable>
</inOutVars>
```

#### 5. Variables Temporaires (`<tempVars>`)
Réinitialisées à chaque cycle d'exécution de la POU.
```xml
<tempVars>
  <variable name="iLoopIndex"><type><INT/></type></variable>
</tempVars>
```

#### 6. Variables Externes (`<externalVars>`)
Invoque une variable déclarée dans la liste des variables globales (GVL).
```xml
<externalVars>
  <variable name="g_bUrgenceSysteme"><type><BOOL/></type></variable>
</externalVars>
```

---

## 5. Structuration des POUs en ST : Programmes, Blocs Fonctionnels et Fonctions

### 5.1 Programme (`pouType="program"`)
Un programme est une entité globale appelée par une tâche système.

```xml
<pou name="PRG_TraiterSignal" pouType="program">
  <interface>
    <localVars>
      <variable name="rEntree"><type><REAL/></type></variable>
      <variable name="rSortie"><type><REAL/></type></variable>
    </localVars>
  </interface>
  <body>
    <ST>
      <xhtml:p><![CDATA[
rSortie := rEntree * 1.5;
      ]]></xhtml:p>
    </ST>
  </body>
</pou>
```

### 5.2 Bloc Fonctionnel (`pouType="functionBlock"`)
Un bloc fonctionnel possède un état interne conservé d'un cycle à l'autre via une instance.

```xml
<pou name="FB_RégulateurPID" pouType="functionBlock">
  <interface>
    <inputVars>
      <variable name="rSetPoint"><type><REAL/></type></variable>
      <variable name="rActualValue"><type><REAL/></type></variable>
    </inputVars>
    <outputVars>
      <variable name="rOut"><type><REAL/></type></variable>
    </outputVars>
    <localVars>
      <variable name="rIntegralErr"><type><REAL/></type></variable>
    </localVars>
  </interface>
  <body>
    <ST>
      <xhtml:p><![CDATA[
rIntegralErr := rIntegralErr + (rSetPoint - rActualValue);
rOut := (rSetPoint - rActualValue) * 2.0 + rIntegralErr * 0.1;
      ]]></xhtml:p>
    </ST>
  </body>
</pou>
```

### 5.3 Fonction (`pouType="function"`)
Une fonction ne conserve aucun état d'un appel à l'autre et retourne directement une valeur via
`<returnType>`.

```xml
<pou name="FC_CalculerMoyenne" pouType="function">
  <interface>
    <returnType><REAL/></returnType>
    <inputVars>
      <variable name="rVal1"><type><REAL/></type></variable>
      <variable name="rVal2"><type><REAL/></type></variable>
    </inputVars>
  </interface>
  <body>
    <ST>
      <xhtml:p><![CDATA[
FC_CalculerMoyenne := (rVal1 + rVal2) / 2.0;
      ]]></xhtml:p>
    </ST>
  </body>
</pou>
```

---

## 6. Actions, Transitions et Méthodes en ST

PLCopen XML v2.01 permet de modulariser le code ST en lui rattachant des actions et des
transitions associées à un POU principal.

### 6.1 Actions Déclarées dans un POU (`<actions>`)
Une action est un sous-programme rattaché à une POU possédant son propre corps de code ST.

```xml
<pou name="PRG_Machine" pouType="program">
  <interface>...</interface>
  <actions>
    <action name="Act_Reinitialiser">
      <body>
        <ST>
          <xhtml:p><![CDATA[
nCompteur := 0;
bDone := FALSE;
          ]]></xhtml:p>
        </ST>
      </body>
    </action>
  </actions>
  <body>
    <ST>
      <xhtml:p><![CDATA[
IF bReset THEN
    Act_Reinitialiser();
END_IF;
      ]]></xhtml:p>
    </ST>
  </body>
</pou>
```

---

## 7. Syntaxe Intégrale des Structures de Contrôle ST dans le XML

Le bloc de code ST contenu dans `<ST><xhtml:p><![CDATA[ ... ]]></xhtml:p></ST>` doit contenir une
syntaxe ST strictement conforme à la norme IEC 61131-3. Voici l'inventaire exhaustif de tous les
cas d'instructions :

### 7.1 Affectations et Opérations
```pascal
// Affectation simple
nValeur := 100;

// Affectation de structure / tableau
stCapteur.rValeur := 23.5;
aBuffer[0] := nValeur;

// Appel de fonction
rMoyenne := FC_CalculerMoyenne(rVal1 := 10.0, rVal2 := 20.0);

// Appel de bloc fonctionnel
fbPID(rSetPoint := 50.0, rActualValue := rMesure, rOut => rCommande);
```

### 7.2 Instructions Conditionnelles

#### 1. `IF ... THEN ... ELSIF ... ELSE ... END_IF`
```pascal
IF rMesure > 100.0 THEN
    nStatut := 2;
    bAlerte := TRUE;
ELSIF rMesure > 80.0 THEN
    nStatut := 1;
    bAlerte := FALSE;
ELSE
    nStatut := 0;
    bAlerte := FALSE;
END_IF;
```

#### 2. `CASE ... OF ... END_CASE`
```pascal
CASE eEtatMachine OF
    ET_EtatMachine.INIT:
        bInitDone := FALSE;
        eEtatMachine := ET_EtatMachine.RUNNING;
        
    ET_EtatMachine.RUNNING:
        IF bDefaut THEN
            eEtatMachine := ET_EtatMachine.ERROR;
        END_IF;
        
    ET_EtatMachine.ERROR:
        bAlerte := TRUE;
        
ELSE
    eEtatMachine := ET_EtatMachine.INIT;
END_CASE;
```

### 7.3 Boucles d'Itération

#### 1. Boucle `FOR ... TO ... BY ... DO ... END_FOR`
```pascal
nSomme := 0;
FOR iIndex := 0 TO 99 BY 1 DO
    nSomme := nSomme + aBuffer[iIndex];
END_FOR;
```

#### 2. Boucle `WHILE ... DO ... END_WHILE`
```pascal
iIndex := 0;
WHILE iIndex < 100 AND NOT bStopSearch DO
    IF aBuffer[iIndex] = nCible THEN
        bFound := TRUE;
        bStopSearch := TRUE;
    END_IF;
    iIndex := iIndex + 1;
END_WHILE;
```

#### 3. Boucle `REPEAT ... UNTIL ... END_REPEAT`
```pascal
iIndex := 0;
REPEAT
    aBuffer[iIndex] := 0;
    iIndex := iIndex + 1;
UNTIL iIndex >= 100
END_REPEAT;
```

#### 4. Instructions d'Échappement (`EXIT`, `CONTINUE`, `RETURN`)
```pascal
FOR iIndex := 0 TO 99 DO
    IF aBuffer[iIndex] < 0 THEN
        CONTINUE; // Passe à l'itération suivante
    END_IF;
    IF aBuffer[iIndex] = 9999 THEN
        EXIT; // Sort immédiatement de la boucle
    END_IF;
END_FOR;

IF bUrgence THEN
    RETURN; // Quitte immédiatement la POU
END_IF;
```

---

## 8. Données Spécifiques CODESYS et Métadonnées (`<addData>`)

Pour préserver des pragmas d'optimisation, des attributs de visibilité, ou des commentaires
d'en-tête réseau au format spécifique à **CODESYS**, le bloc `<addData>` peut être intégré à
l'échelle du projet, du POU ou des variables.

### Exemple : Ajout de Pragmas et d'Attributs CODESYS
```xml
<pou name="FB_CommandeAvancee" pouType="functionBlock">
  <interface>
    <localVars>
      <variable name="nInternalCount">
        <type><DINT/></type>
        <addData>
          <data name="http://www.3s-software.com/plcopenxml/attributes" handleUnknown="implementation">
            <Attributes>
              <Attribute Name="hide" Value=""/>
            </Attributes>
          </data>
        </addData>
      </variable>
    </localVars>
  </interface>
  <body>
    <ST>
      <xhtml:p><![CDATA[
{attribute 'no_assign_warning'}
nInternalCount := nInternalCount + 1;
      ]]></xhtml:p>
    </ST>
  </body>
</pou>
```

---

## 9. Exemple Complet Importable dans CODESYS

Voici l'illustration d'un fichier complet intégrant un **Data Type énuméré**, un **Bloc
Fonctionnel** complet avec entrées/sorties et instructions conditionnelles en ST, ainsi qu'un
**Programme principal** d'appel :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.plcopen.org/xml/tc6_0200"
         xmlns:xhtml="http://www.w3.org/1999/xhtml"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200">
  
  <fileHeader companyName="AutomationStudio" productName="STGenerator" productVersion="1.0" creationDateTime="2026-08-12T15:00:00"/>
  <contentHeader name="Projet_ST_Complet"/>

  <types>
    <dataTypes>
      <!-- 1. Déclaration d'un ENUM -->
      <dataType name="ET_ModeOperation">
        <baseType>
          <enum>
            <values>
              <value name="MANUEL"/>
              <value name="AUTOMATIQUE"/>
              <value name="SECOURU"/>
            </values>
          </enum>
        </baseType>
      </dataType>
    </dataTypes>

    <pous>
      <!-- 2. Bloc Fonctionnel de Gestion de Pompe -->
      <pou name="FB_GestionPompe" pouType="functionBlock">
        <interface>
          <inputVars>
            <variable name="bCmdStart"><type><BOOL/></type></variable>
            <variable name="eMode"><type><derived name="ET_ModeOperation"/></type></variable>
            <variable name="rPression"><type><REAL/></type></variable>
          </inputVars>
          <outputVars>
            <variable name="bPompeActive"><type><BOOL/></type></variable>
            <variable name="bAlarmePression"><type><BOOL/></type></variable>
          </outputVars>
          <localVars>
            <variable name="nCycles"><type><UDINT/></type></variable>
          </localVars>
        </interface>
        <body>
          <ST>
            <xhtml:p><![CDATA[
// Surveillance Pression
IF rPression > 10.0 THEN
    bAlarmePression := TRUE;
    bPompeActive := FALSE;
    RETURN;
ELSE
    bAlarmePression := FALSE;
END_IF;

// Logique selon le mode
CASE eMode OF
    ET_ModeOperation.MANUEL:
        bPompeActive := bCmdStart;
        
    ET_ModeOperation.AUTOMATIQUE:
        IF rPression < 2.0 AND bCmdStart THEN
            bPompeActive := TRUE;
            nCycles := nCycles + 1;
        ELSIF rPression >= 8.0 THEN
            bPompeActive := FALSE;
        END_IF;
        
    ET_ModeOperation.SECOURU:
        bPompeActive := TRUE;
END_CASE;
            ]]></xhtml:p>
          </ST>
        </body>
      </pou>

      <!-- 3. Programme Principal -->
      <pou name="PLC_PRG" pouType="program">
        <interface>
          <localVars>
            <variable name="fbPompe1"><type><derived name="FB_GestionPompe"/></type></variable>
            <variable name="bStartLocal"><type><BOOL/></type></variable>
            <variable name="rPressionLigne"><type><REAL/></type></variable>
            <variable name="bStatePompe"><type><BOOL/></type></variable>
            <variable name="bAlarme"><type><BOOL/></type></variable>
          </localVars>
        </interface>
        <body>
          <ST>
            <xhtml:p><![CDATA[
// Appel du bloc fonctionnel
fbPompe1(
    bCmdStart := bStartLocal, 
    eMode := ET_ModeOperation.AUTOMATIQUE, 
    rPression := rPressionLigne, 
    bPompeActive => bStatePompe, 
    bAlarmePression => bAlarme
);
            ]]></xhtml:p>
          </ST>
        </body>
      </pou>
    </pous>
  </types>

  <instances>
    <configurations/>
  </instances>
</project>
```

---

## 10. Tableau Récapitulatif des Balises et Éléments ST

| <nobr>Élément / Structure</nobr> | <nobr>Balise XML / Conteneur</nobr> | <small>Emplacement</small> | <small>Fonction & Usage</small> |
|---|---|---|---|
| <nobr>Data Types Personnalisés</nobr> | <nobr><code>dataType</code></nobr> | <small><code>types/dataTypes</code></small> | <small>Définition des STRUCT, ENUM, ARRAY, ALIAS.</small> |
| <nobr>POU</nobr> | <nobr><code>pou name="..." pouType="..."</code></nobr> | <small><code>types/pous</code></small> | <small>Unité de programme (<code>program</code>, <code>functionBlock</code>, <code>function</code>).</small> |
| <nobr>Interface / Déclarations</nobr> | <nobr><code>interface</code></nobr> | <small>Enfant de <code>pou</code></small> | <small>Englobe toutes les déclarations de variables.</small> |
| <nobr>Variables d'Entrée</nobr> | <nobr><code>inputVars</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Paramètres transmis en entrée de la POU.</small> |
| <nobr>Variables de Sortie</nobr> | <nobr><code>outputVars</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Paramètres retournés par la POU.</small> |
| <nobr>Variables d'Entrée/Sortie</nobr> | <nobr><code>inOutVars</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Paramètres transmis par référence.</small> |
| <nobr>Variables Locales</nobr> | <nobr><code>localVars</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Variables internes persistantes ou normales.</small> |
| <nobr>Variables Temporaires</nobr> | <nobr><code>tempVars</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Variables réinitialisées à chaque cycle.</small> |
| <nobr>Type de Retour (FC)</nobr> | <nobr><code>returnType</code></nobr> | <small>Enfant de <code>interface</code></small> | <small>Type de la valeur renvoyée par une Fonction.</small> |
| <nobr>Code Exécutable ST</nobr> | <nobr><code>ST/xhtml:p/CDATA</code></nobr> | <small><code>body</code> ou <code>action/body</code></small> | <small>Conteneur du code impératif ST (IF, CASE, FOR, etc.).</small> |
| <nobr>Action secondaire</nobr> | <nobr><code>action name="..."</code></nobr> | <small><code>pou/actions</code></small> | <small>Méthode / Sous-programme rattaché à une POU.</small> |
| <nobr>Données Vendeur</nobr> | <nobr><code>addData</code></nobr> | <small>Multi-niveaux (Project, POU, Variable)</small> | <small>Métadonnées, Attributs/Pragmas spécifiques CODESYS.</small> |

---

## 11. Documents liés

- [`GUIDE_IMPLEMENTATION_LADDER_PLCOPEN_XML_v1.0.md`](GUIDE_IMPLEMENTATION_LADDER_PLCOPEN_XML_v1.0.md) — pendant LD de ce guide.
- [`tc6_xml_v201_technical_doc.md`](tc6_xml_v201_technical_doc.md) — spec source intégrale (PLCopen TC6 XML v2.01), y compris les sections hors périmètre ici (§7 configuration/resource/task).
- [`CODE_QUALITY_STANDARDS.md`](../CODE_QUALITY_STANDARDS.md) — référentiel universel de déclaration/liaison/nommage appliqué au-dessus de ce format XML.
- `TOOLS/CONVERTER_ST2XML_PLCopenXML/generator/` — implémentation Python consommant ces règles pour convertir `CODE/**/*.st` en PLCopen XML.
