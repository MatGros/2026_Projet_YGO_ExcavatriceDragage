# Architecture V0 — Viewer Modelica M3

## Principe

Le viewer n'est pas le moteur physique.

```
                 ┌──────────────────────────────┐
                 │ modelica_viewer_m3.py        │
                 │                               │
 .mo ───────────►│ éditeur / parser léger       │
                 │ vue structurelle              │
                 │ sélection classe              │
                 └──────────────┬────────────────┘
                                │ script .mos
                                ▼
                 ┌──────────────────────────────┐
                 │ OpenModelica / omc.exe        │
                 │                               │
                 │ checkModel()                  │
                 │ simulate()                    │
                 │ outputFormat="csv"            │
                 └──────────────┬────────────────┘
                                │
                                ▼
                 ┌──────────────────────────────┐
                 │ résultats CSV                 │
                 │ time + variables              │
                 └──────────────┬────────────────┘
                                │
                                ▼
                 ┌──────────────────────────────┐
                 │ Viewer                       │
                 │ courbe + valeurs min/max     │
                 └──────────────────────────────┘
```

OpenModelica documente `simulate(..., outputFormat="csv")` et le filtre de variables ;
le viewer utilise cette interface plutôt que de reproduire un solveur local.

## Première abstraction M3

La V0 représente :

```
CMD
 ├─ cmdMoveToTremie
 ├─ cmdMoveToMaintenance
 ├─ cmdSpeed_Pct
 └─ cmdBrakeRelease
             │
             ▼
      TranslationM3Plant
             │
             ├─ positionAct_M
             ├─ velocityAct_Mps
             ├─ frequencyAct_Hz
             ├─ brakeIsOpen
             ├─ Tremie / PV / P2 / P1 / Maintenance
             ├─ driveStatusWord
             └─ diagnostics
```

La plante conserve la frontière définie dans le projet : elle reçoit les commandes finales et
publie des faits physiques/capteurs. Les permissions, AU, PowerCutOff et interlocks restent hors
du modèle.

## Ce qui sera ajouté ensuite

### V1 — vrai diagramme de composants

Parser :

- classes ;
- instances ;
- `connect(a,b)` ;
- annotations `Placement` ;
- ports ;
- paramètres.

Le viewer pourra alors reconstruire une représentation graphique proche d'OMEdit.

### V2 — édition graphique

Déplacer un composant ou créer une connexion devra produire une modification contrôlée du texte
Modelica, puis demander une validation `checkModel()`.

### V3 — bibliothèque physique

Bibliothèque dédiée M3 :

```
Commande électrique
  → variateur
  → moteur
  → réducteur
  → roue / rail
  → position chariot
  → capteurs
```

Les paramètres non mesurés seront marqués comme hypothèses.

### V4 — M1/M2 et benne

Seulement après validation du modèle M3 et de son contrat de signaux.

## Sécurité

Interdits :

- appel PLC ;
- accès aux sorties physiques ;
- bypass safety ;
- simulation servant de source directe à `HwIn` ;
- écriture dans `CODE/`, `CODE_XML/` ou `PRJ_CODESYS/`.

Le périmètre reste `TOOLS/TWINBENCH/modelica_viewer_m3/`.
