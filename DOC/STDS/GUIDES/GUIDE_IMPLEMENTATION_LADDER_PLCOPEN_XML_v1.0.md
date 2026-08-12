# 🪜 Guide d'Implémentation Ladder Diagram (LD) en PLCopen XML (v1.0)

## 🎯 Raison d'être & Responsabilité Unique
- **Problème résolu** : générer du Ladder Diagram en PLCopen XML à la main (ou via un agent qui
  devine la structure) produit des fichiers non importables dans CODESYS — topologie graphique,
  chaînage `connectionPointIn`/`connectionPointOut` et ordre des `localId` sont des règles
  strictes, pas des conventions de style (voir REX `ld_builder.py`, `CODE_QUALITY_STANDARDS.md`).
- **Périmètre strict** : modélisation XML du langage **LD uniquement** — balises, attributs,
  topologie graphique, exemples. Ne couvre pas FBD, SFC, IL (non utilisés sur ce projet) ni les
  sections `<configuration>`/`<resource>`/`<task>`/`<pouInstance>` de la norme (§7 de la spec
  source) : le rattachement des POU aux tâches CODESYS reste câblé **manuellement** par
  l'utilisateur dans CODESYS 3.5, jamais généré par l'outillage — hors périmètre volontaire.
- **Type de composant** : référence technique normative, source secondaire consommée par
  `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py` et par tout agent lisant/écrivant du
  LD en PLCopen XML.

> Origine : extraction agent de la spec officielle **PLCopen Technical Committee 6 — XML Formats
> for IEC 61131-3, v2.01** (document intégral en français-technique :
> [`tc6_xml_v201_technical_doc.md`](tc6_xml_v201_technical_doc.md)) — 2026-08-12.

---

## 🧭 Sommaire

| <nobr>§</nobr> | Contenu |
|---|---|
| <nobr>1</nobr> | Structure générale d'un fichier PLCopen XML |
| <nobr>2</nobr> | Système de coordonnées et topologie réseau |
| <nobr>3</nobr> | Éléments du langage LD (rails, contacts, bobines, blocs, sauts, connecteurs) |
| <nobr>4</nobr> | Topologies avancées (OR, dérivation de fil) |
| <nobr>5</nobr> | Données vendeur et extensions (`addData`) |
| <nobr>6</nobr> | Exemple complet récapitulatif |
| <nobr>7</nobr> | Tableau récapitulatif des attributs et composants |
| <nobr>8</nobr> | Documents liés |

---

## 1. Structure Générale d'un Fichier PLCopen XML

Un fichier PLCopen XML respectant la norme TC6 v2.01 doit présenter une arborescence strictement
ordonnée. Les sections obligatoires définissent l'en-tête du fichier, l'en-tête de contenu
(comprenant la configuration des échelles graphiques), la déclaration des types et des POUs,
ainsi que les instances d'exécution.

### 1.1 Arborescence Racine et Espaces de Noms

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.plcopen.org/xml/tc6_0200"
         xmlns:xhtml="http://www.w3.org/1999/xhtml"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200">
  
  <!-- En-tête de fichier obligatoire -->
  <fileHeader companyName="NomEntreprise" 
              productName="ProductGen" 
              productVersion="1.0" 
              creationDateTime="2026-08-12T10:00:00"/>
  
  <!-- En-tête de contenu et configuration graphique -->
  <contentHeader name="Projet_Ladder_Exhaustif">
    <coordinateInfo>
      <ld>
        <scaling x="8" y="8"/>
      </ld>
    </coordinateInfo>
  </contentHeader>

  <!-- Section des types : Data Types et POUs -->
  <types>
    <dataTypes/>
    <pous>
      <pou name="POU_Main_LD" pouType="program">
        <interface>
          <!-- Déclarations des variables -->
          <localVars>
            <variable name="bStart"><type><BOOL/></type></variable>
            <variable name="bStop"><type><BOOL/></type></variable>
            <variable name="bCmdMoteur"><type><BOOL/></type></variable>
          </localVars>
        </interface>
        <body>
          <LD>
            <!-- Contenu graphique du réseau Ladder -->
          </LD>
        </body>
      </pou>
    </pous>
  </types>

  <!-- Section des instances (Configurations / Ressources / Tasks — hors périmètre, voir §🎯) -->
  <instances>
    <configurations/>
  </instances>
</project>
```

---

## 2. Le Système de Coordonnées et de Topologie Réseau

La représentation du Ladder Diagram dans PLCopen XML s'appuie sur une modélisation graphique
explicite et interconnectée.

### 2.1 Repère et Ancrage Graphique
- **Origine `(0, 0)`** : Située au coin supérieur gauche de la feuille de travail. L'axe **X**
  s'étend positivement vers la droite, l'axe **Y** s'étend positivement vers le bas.
- **Point d'ancrage (`position`)** : Tout élément graphique possède un nœud enfant
  `<position x="..." y="..." />`. L'ancrage correspond au coin supérieur gauche de la boîte
  englobante de l'élément (hors étiquettes externes).
- **Dimensions (`height`, `width`)** : Définissent la largeur et la hauteur du rectangle de
  l'élément en unités de la grille.
- **Échelle (`scaling`)** : La balise `<coordinateInfo><ld><scaling x="8" y="8"/></ld></coordinateInfo>`
  fixe la taille d'une cellule de référence (en LD, cela correspond généralement aux dimensions
  minimales d'une bobine).

### 2.2 Chaînage des Connexions Graphiques (`connectionPointIn` / `connectionPointOut`)

La logique d'exécution et d'interconnexion en PLCopen XML est décrite de manière **rétrograde**
(du récepteur/consommateur de signal vers l'émetteur/producteur de signal, soit généralement de
droite à gauche) :

1. **`localId`** : Chaque élément du corps `<LD>` possède un identifiant numérique entier unique
   au sein de la POU.
2. **`connectionPointOut`** : Définit le point de sortie du signal logique (situé du côté droit
   de l'élément).
3. **`connectionPointIn`** : Contient un ou plusieurs enfants `<connection refLocalId="..." />`
   qui pointent vers le `localId` de l'élément source situé en amont.
4. **Tracé géométrique (`position` dans `connection`)** : La balise `<connection>` peut contenir
   une liste de points `<position x="..." y="..."/>` décrivant le tracé exact du segment
   filaire.

---

## 3. Analyse Exhaustive des Éléments du Langage Ladder (LD)

### 3.1 Barres d'Alimentation (Power Rails)

#### Left Power Rail (`<leftPowerRail>`)
Placée à la marge gauche du réseau, elle distribue le potentiel logique aux contacts.
```xml
<leftPowerRail localId="1" width="8" height="40">
  <position x="80" y="80"/>
  <!-- Une sortie par branche partant de la rail gauche -->
  <connectionPointOut globalId="100">
    <relPosition x="8" y="16"/>
  </connectionPointOut>
</leftPowerRail>
```

#### Right Power Rail (`<rightPowerRail>`)
Placée à la marge droite du réseau, elle collecte le potentiel après les bobines.
```xml
<rightPowerRail localId="99" width="8" height="40">
  <position x="800" y="80"/>
  <connectionPointIn>
    <connection refLocalId="10"/> <!-- Id de la dernière bobine -->
  </connectionPointIn>
</rightPowerRail>
```

---

### 3.2 Contacts (`<contact>`)

Un contact évalue l'état d'une variable booléenne ou d'une expression.

#### Attributs de la balise `<contact>`
- `localId` : Identifiant unique.
- `negated` : `"true"` (Normalement Fermé - NC) ou `"false"` (Normalement Ouvert - NO).
- `edge` : `"rising"` (Front montant - P), `"falling"` (Front descendant - N), ou `"none"`.
- `storage` : `"set"`, `"reset"`, ou `"none"`.

#### Exemple 1 : Contact NO (Normalement Ouvert)
```xml
<contact localId="2" negated="false" edge="none">
  <position x="160" y="88"/>
  <connectionPointIn>
    <connection refLocalId="1"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bStart</variable>
</contact>
```

#### Exemple 2 : Contact NC (Normalement Fermé)
```xml
<contact localId="3" negated="true" edge="none">
  <position x="280" y="88"/>
  <connectionPointIn>
    <connection refLocalId="2"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bStop</variable>
</contact>
```

#### Exemple 3 : Contact à Front Montant (Rising Edge - P)
```xml
<contact localId="4" negated="false" edge="rising">
  <position x="400" y="88"/>
  <connectionPointIn>
    <connection refLocalId="3"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bPoussoirP</variable>
</contact>
```

#### Exemple 4 : Contact à Front Descendant (Falling Edge - N)
```xml
<contact localId="5" negated="false" edge="falling">
  <position x="400" y="150"/>
  <connectionPointIn>
    <connection refLocalId="3"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bPoussoirN</variable>
</contact>
```

---

### 3.3 Bobines (`<coil>`)

Une bobine assigne le résultat de la combinaison logique à une variable.

#### Attributs de la balise `<coil>`
- `localId` : Identifiant unique.
- `negated` : `"false"` (Bobine directe `( )`) ou `"true"` (Bobine inversée `(/)`).
- `edge` : `"rising"` (Bobine à front montant), `"falling"` (Bobine à front descendant), ou
  `"none"`.
- `storage` : `"none"`, `"set"` (Bobine Set `(S)`), `"reset"` (Bobine Reset `(R)`).

#### Exemple 1 : Bobine Directe
```xml
<coil localId="10" negated="false" storage="none" edge="none">
  <position x="640" y="88"/>
  <connectionPointIn>
    <connection refLocalId="4"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bCmdMoteur</variable>
</coil>
```

#### Exemple 2 : Bobine Inversée
```xml
<coil localId="11" negated="true" storage="none" edge="none">
  <position x="640" y="150"/>
  <connectionPointIn>
    <connection refLocalId="4"/>
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bVoyantDefaut</variable>
</coil>
```

#### Exemple 3 : Bobines Set / Reset
```xml
<!-- Bobine SET -->
<coil localId="12" storage="set">
  <position x="640" y="210"/>
  <connectionPointIn><connection refLocalId="4"/></connectionPointIn>
  <connectionPointOut/>
  <variable>bMemoireMarche</variable>
</coil>

<!-- Bobine RESET -->
<coil localId="13" storage="reset">
  <position x="640" y="270"/>
  <connectionPointIn><connection refLocalId="5"/></connectionPointIn>
  <connectionPointOut/>
  <variable>bMemoireMarche</variable>
</coil>
```

---

### 3.4 Blocs Fonctionnels (`<block>`) dans le Réseau Ladder

Un bloc fonctionnel ou une fonction (ex: `TON`, `CTU`, `ADD`, `MUX`) s'insère directement dans la
chaîne du flux logique RLO (Result of Logic Operation).

#### Balises de Connexion d'Entrées/Sorties de Bloc
- **`inputVariables`** : Liste des entrées. Chaque entrée `<variable formalParameter="NAME">`
  possède son `<connectionPointIn>`.
- **`outputVariables`** : Liste des sorties. Chaque sortie `<variable formalParameter="NAME">`
  possède son `<connectionPointOut>`.
- **`inOutVariables`** : Déclare les variables transmises par référence (In/Out).

#### Exemple Complètement Intégré : Temporisateur `TON`
```xml
<block localId="20" typeName="TON" instanceName="fbTimerStart">
  <position x="400" y="80"/>
  <inputVariables>
    <!-- Entrée IN reliée au contact amont (flux RLO) -->
    <variable formalParameter="IN">
      <connectionPointIn>
        <connection refLocalId="3"/>
      </connectionPointIn>
    </variable>
    <!-- Entrée PT reliée à une variable ou constante -->
    <variable formalParameter="PT">
      <connectionPointIn>
        <connection refLocalId="21"/> <!-- Référence vers inVariable (T#5s) -->
      </connectionPointIn>
    </variable>
  </inputVariables>
  
  <inOutVariables/>

  <outputVariables>
    <!-- Sortie Q transmettant le flux logique à la bobine suivante -->
    <variable formalParameter="Q">
      <connectionPointOut/>
    </variable>
    <!-- Sortie ET (Temps écoulé) -->
    <variable formalParameter="ET">
      <connectionPointOut/>
    </variable>
  </outputVariables>
</block>

<!-- Variable d'entrée fournissant la valeur fixe du temporisateur -->
<inVariable localId="21">
  <position x="280" y="120"/>
  <connectionPointOut/>
  <expression>T#5s</expression>
</inVariable>
```

---

### 3.5 Variables d'Entrée / Sortie Graphiques (`inVariable`, `outVariable`, `inOutVariable`)

Ces éléments s'utilisent pour injecter ou extraire des valeurs numériques/analogiques ou
transférer des signaux en dehors du fil RLO principal.

#### Entrées Analogiques / Constantes (`<inVariable>`)
```xml
<inVariable localId="25" negated="false" edge="none">
  <position x="200" y="200"/>
  <connectionPointOut/>
  <expression>nConsigneTemperature</expression>
</inVariable>
```

#### Sorties sur Fonction / Affectation de Valeur (`<outVariable>`)
Utilisée lorsqu'une sortie de bloc fonctionnel doit écrire une valeur dans une variable :
```xml
<outVariable localId="26" negated="false">
  <position x="600" y="120"/>
  <connectionPointIn>
    <connection refLocalId="20" formalParameter="ET"/>
  </connectionPointIn>
  <expression>tTempsEcoule</expression>
</outVariable>
```

#### Variables In/Out (`<inOutVariable>`)
```xml
<inOutVariable localId="27" negatedIn="false" negatedOut="false">
  <position x="400" y="300"/>
  <connectionPointIn><connection refLocalId="25"/></connectionPointIn>
  <connectionPointOut/>
  <expression>stStructureAjustable.nValeur</expression>
</inOutVariable>
```

---

### 3.6 Sauts, Étiquettes, Retours et Connecteurs

#### Sauts (`<jump>`) et Étiquettes (`<label>`)
Permettent le déroutement du flux d'exécution réseau.
```xml
<!-- Étiquette cible -->
<label localId="30" label="LBL_DEFAUT">
  <position x="80" y="400"/>
</label>

<!-- Saut conditionnel déclenché par un contact amont -->
<jump localId="31" label="LBL_DEFAUT">
  <position x="500" y="400"/>
  <connectionPointIn>
    <connection refLocalId="3"/>
  </connectionPointIn>
</jump>
```

#### Instruction de Retour (`<return>`)
Force la sortie anticipée de la POU.
```xml
<return localId="35">
  <position x="500" y="480"/>
  <connectionPointIn>
    <connection refLocalId="3"/>
  </connectionPointIn>
</return>
```

#### Connecteurs et Continuations (`<connector>` / `<continuation>`)
S'utilisent pour scinder un fil complexe en deux sans encombrer le schéma graphique.
```xml
<!-- Source : Connecteur d'arrivée -->
<connector localId="40" name="LNK_SIG1">
  <position x="450" y="100"/>
  <connectionPointIn>
    <connection refLocalId="3"/>
  </connectionPointIn>
</connector>

<!-- Destination : Continuation de départ -->
<continuation localId="41" name="LNK_SIG1">
  <position x="80" y="250"/>
  <connectionPointOut/>
</continuation>
```

---

## 4. Topologies Avancées : Dérivation (OR) et Branched Connections

### 4.1 Implantation de Contacts en Parallèle (Logique OU / OR)
Pour implanter une structure en parallèle (par exemple `(bStart1 OR bStart2) AND bStop`),
plusieurs contacts amont doivent faire référence au même composant source et converger vers la
même entrée du composant aval.

```text
+--| bStart1 |--+--| bStop |--( bMoteur )
|               |
+--| bStart2 |--+
```

```xml
<!-- Left Rail -->
<leftPowerRail localId="1"><position x="80" y="80"/><connectionPointOut/></leftPowerRail>

<!-- Contact bStart1 (Branche Haute) -->
<contact localId="2" negated="false">
  <position x="160" y="80"/>
  <connectionPointIn><connection refLocalId="1"/></connectionPointIn>
  <connectionPointOut/>
  <variable>bStart1</variable>
</contact>

<!-- Contact bStart2 (Branche Basse en Parallèle) -->
<contact localId="3" negated="false">
  <position x="160" y="140"/>
  <connectionPointIn><connection refLocalId="1"/></connectionPointIn> <!-- Même point de départ -->
  <connectionPointOut/>
  <variable>bStart2</variable>
</contact>

<!-- Contact bStop en Série après la convergence -->
<contact localId="4" negated="true">
  <position x="320" y="80"/>
  <connectionPointIn>
    <connection refLocalId="2"/> <!-- Lien vers Branche Haute -->
    <connection refLocalId="3"/> <!-- Lien vers Branche Basse -->
  </connectionPointIn>
  <connectionPointOut/>
  <variable>bStop</variable>
</contact>
```

### 4.2 Dérivation de Fil (Forked Connections)
Lorsqu'une même sortie de contact ou de bloc alimente plusieurs éléments en aval (ex: deux
bobines en parallèle) :

```xml
<!-- Contact déclencheur -->
<contact localId="5"><position x="200" y="80"/><connectionPointOut/><variable>bCondition</variable></contact>

<!-- Bobine 1 -->
<coil localId="6"><position x="500" y="80"/><connectionPointIn><connection refLocalId="5"/></connectionPointIn><variable>bCmd1</variable></coil>

<!-- Bobine 2 (Forked) -->
<coil localId="7"><position x="500" y="140"/><connectionPointIn><connection refLocalId="5"/></connectionPointIn><variable>bCmd2</variable></coil>
```

---

## 5. Données Vendeur et Extensions (`<addData>`)

Le format PLCopen XML permet l'intégration de métadonnées spécifiques à **CODESYS** (ex:
commentaires de réseaux, coordonnées graphiques étendues, pragmas, désactivation
d'avertissements).

### Exemple d'Ajout de Commentaires sur un Réseau
```xml
<pou name="POU_Main_LD" pouType="program">
  <interface>...</interface>
  <body>
    <LD>
      <addData>
        <data name="http://www.3s-software.com/plcopenxml/networkcomment" handleUnknown="implementation">
          <NetworkComment>
            <xhtml:p>Réseau 1 : Commande et maintien du moteur principal</xhtml:p>
          </NetworkComment>
        </data>
      </addData>
      <!-- Eléments LD -->
    </LD>
  </body>
</pou>
```

---

## 6. Exemple Complet Récapitulatif

Voici un exemple complet d'une POU en Ladder Diagram comprenant :
- Un auto-maintien (Logique OU : `bStart` OR `bAutoMaintien`).
- Une sécurité NC (`bStop`).
- Un temporisateur `TON` sur le circuit d'activation.
- Une bobine principale `bMoteur` et une bobine d'état Set.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.plcopen.org/xml/tc6_0200"
         xmlns:xhtml="http://www.w3.org/1999/xhtml"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.plcopen.org/xml/tc6_0200 http://www.plcopen.org/xml/tc6_0200">
  
  <fileHeader companyName="AutomationStudio" productName="XMLGenerator" productVersion="1.0" creationDateTime="2026-08-12T12:00:00"/>
  
  <contentHeader name="Projet_Demo">
    <coordinateInfo>
      <ld><scaling x="8" y="8"/></ld>
    </coordinateInfo>
  </contentHeader>

  <types>
    <dataTypes/>
    <pous>
      <pou name="PRG_Moteur" pouType="program">
        <interface>
          <localVars>
            <variable name="bStart"><type><BOOL/></type></variable>
            <variable name="bStop"><type><BOOL/></type></variable>
            <variable name="bMoteur"><type><BOOL/></type></variable>
            <variable name="bFlagRunning"><type><BOOL/></type></variable>
            <variable name="fbTimer"><type><derived name="TON"/></type></variable>
          </localVars>
        </interface>
        <body>
          <LD>
            <!-- 1. Left Rail -->
            <leftPowerRail localId="1">
              <position x="80" y="80"/>
              <connectionPointOut><relPosition x="0" y="8"/></connectionPointOut>
            </leftPowerRail>

            <!-- 2. Contact NO bStart -->
            <contact localId="2" negated="false">
              <position x="160" y="80"/>
              <connectionPointIn><connection refLocalId="1"/></connectionPointIn>
              <connectionPointOut/>
              <variable>bStart</variable>
            </contact>

            <!-- 3. Contact NO Maintien bMoteur (Parallèle) -->
            <contact localId="3" negated="false">
              <position x="160" y="140"/>
              <connectionPointIn><connection refLocalId="1"/></connectionPointIn>
              <connectionPointOut/>
              <variable>bMoteur</variable>
            </contact>

            <!-- 4. Contact NC bStop -->
            <contact localId="4" negated="true">
              <position x="280" y="80"/>
              <connectionPointIn>
                <connection refLocalId="2"/>
                <connection refLocalId="3"/>
              </connectionPointIn>
              <connectionPointOut/>
              <variable>bStop</variable>
            </contact>

            <!-- 5. Temporisateur TON -->
            <block localId="5" typeName="TON" instanceName="fbTimer">
              <position x="400" y="80"/>
              <inputVariables>
                <variable formalParameter="IN">
                  <connectionPointIn><connection refLocalId="4"/></connectionPointIn>
                </variable>
                <variable formalParameter="PT">
                  <connectionPointIn><connection refLocalId="6"/></connectionPointIn>
                </variable>
              </inputVariables>
              <inOutVariables/>
              <outputVariables>
                <variable formalParameter="Q"><connectionPointOut/></variable>
                <variable formalParameter="ET"><connectionPointOut/></variable>
              </outputVariables>
            </block>

            <!-- 6. Valeur du Temps Preset (T#2s) -->
            <inVariable localId="6">
              <position x="320" y="120"/>
              <connectionPointOut/>
              <expression>T#2s</expression>
            </inVariable>

            <!-- 7. Bobine Moteur (Alimentée par la sortie Q du TON) -->
            <coil localId="7" negated="false" storage="none">
              <position x="600" y="80"/>
              <connectionPointIn>
                <connection refLocalId="5" formalParameter="Q"/>
              </connectionPointIn>
              <connectionPointOut/>
              <variable>bMoteur</variable>
            </coil>

            <!-- 8. Bobine SET Flag (Forked depuis le TON Q) -->
            <coil localId="8" storage="set">
              <position x="600" y="140"/>
              <connectionPointIn>
                <connection refLocalId="5" formalParameter="Q"/>
              </connectionPointIn>
              <connectionPointOut/>
              <variable>bFlagRunning</variable>
            </coil>

            <!-- 9. Right Rail -->
            <rightPowerRail localId="99">
              <position x="720" y="80"/>
              <connectionPointIn>
                <connection refLocalId="7"/>
                <connection refLocalId="8"/>
              </connectionPointIn>
            </rightPowerRail>
          </LD>
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

## 7. Tableau Récapitulatif des Attributs et Composants LD

| <nobr>Composant</nobr> | <nobr>Balise XML</nobr> | <small>Attributs majeurs</small> | <small>Sous-éléments importants</small> | <small>Description / Rôle</small> |
|---|---|---|---|---|
| <nobr>Rail Gauche</nobr> | <nobr><code>leftPowerRail</code></nobr> | <small><code>localId</code>, <code>width</code>, <code>height</code></small> | <small><code>position</code>, <code>connectionPointOut</code></small> | <small>Source du potentiel logique RLO.</small> |
| <nobr>Rail Droite</nobr> | <nobr><code>rightPowerRail</code></nobr> | <small><code>localId</code>, <code>width</code>, <code>height</code></small> | <small><code>position</code>, <code>connectionPointIn</code></small> | <small>Fin de réseau électrique / neutre.</small> |
| <nobr>Contact</nobr> | <nobr><code>contact</code></nobr> | <small><code>localId</code>, <code>negated</code>, <code>edge</code>, <code>storage</code></small> | <small><code>position</code>, <code>connectionPointIn</code>, <code>connectionPointOut</code>, <code>variable</code></small> | <small>Teste une variable booléenne (NO, NC, P, N).</small> |
| <nobr>Bobine</nobr> | <nobr><code>coil</code></nobr> | <small><code>localId</code>, <code>negated</code>, <code>edge</code>, <code>storage</code></small> | <small><code>position</code>, <code>connectionPointIn</code>, <code>connectionPointOut</code>, <code>variable</code></small> | <small>Assigne un état (Direct, Inversé, Set, Reset).</small> |
| <nobr>Bloc Fonction</nobr> | <nobr><code>block</code></nobr> | <small><code>localId</code>, <code>typeName</code>, <code>instanceName</code></small> | <small><code>position</code>, <code>inputVariables</code>, <code>outputVariables</code>, <code>inOutVariables</code></small> | <small>Incorpore Fonctions & FB (TON, CTU, ADD, etc.).</small> |
| <nobr>Entrée Valeur</nobr> | <nobr><code>inVariable</code></nobr> | <small><code>localId</code></small> | <small><code>position</code>, <code>connectionPointOut</code>, <code>expression</code></small> | <small>Injecte une constante ou variable analogique.</small> |
| <nobr>Sortie Valeur</nobr> | <nobr><code>outVariable</code></nobr> | <small><code>localId</code></small> | <small><code>position</code>, <code>connectionPointIn</code>, <code>expression</code></small> | <small>Reçoit une valeur numérique issue d'un bloc.</small> |
| <nobr>Saut</nobr> | <nobr><code>jump</code></nobr> | <small><code>localId</code>, <code>label</code></small> | <small><code>position</code>, <code>connectionPointIn</code></small> | <small>Déroute l'exécution vers une étiquette.</small> |
| <nobr>Étiquette</nobr> | <nobr><code>label</code></nobr> | <small><code>localId</code>, <code>label</code></small> | <small><code>position</code></small> | <small>Cible de destination d'un saut.</small> |
| <nobr>Retour</nobr> | <nobr><code>return</code></nobr> | <small><code>localId</code></small> | <small><code>position</code>, <code>connectionPointIn</code></small> | <small>Sortie anticipée du POU.</small> |
| <nobr>Connecteur</nobr> | <nobr><code>connector</code></nobr> | <small><code>localId</code>, <code>name</code></small> | <small><code>position</code>, <code>connectionPointIn</code></small> | <small>Point d'origine d'un renvoi de fil.</small> |
| <nobr>Continuation</nobr> | <nobr><code>continuation</code></nobr> | <small><code>localId</code>, <code>name</code></small> | <small><code>position</code>, <code>connectionPointOut</code></small> | <small>Point de destination d'un renvoi de fil.</small> |

---

## 8. Documents liés

- [`GUIDE_IMPLEMENTATION_ST_PLCOPEN_XML_v1.0.md`](GUIDE_IMPLEMENTATION_ST_PLCOPEN_XML_v1.0.md) — pendant ST de ce guide.
- [`tc6_xml_v201_technical_doc.md`](tc6_xml_v201_technical_doc.md) — spec source intégrale (PLCopen TC6 XML v2.01), y compris les sections hors périmètre ici (§7 configuration/resource/task).
- [`CODE_QUALITY_STANDARDS.md`](../CODE_QUALITY_STANDARDS.md) — pourquoi `G200_check_linkage.py` reste la seule preuve de câblage réel, y compris pour du LD généré.
- `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py` — implémentation Python consommant ces règles (REX 2026-08-04 : génération générique actuellement non fiable, contournée par un oracle dédié `PRG_06_Outputs_LD` — voir `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py`).
