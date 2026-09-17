# Standard TwinBench — convention de signaux v1.0

> Statut : **normatif** pour toute nouvelle interface OpenModelica, FMU, scénario, trace et IHM TwinBench.
> Complète — sans la contredire — [NAMING_CONVENTION.md](NAMING_CONVENTION.md), qui demeure la
> source unique des noms PLC. Ne renomme aucun objet PLC existant.

## 1. Décision

Une variable n'est jamais seulement un `Real`. Son affichage et son échange portent **six
dimensions distinctes** :

```text
Nom métier + causalité Modelica + classe de flux + nature + unité/référentiel + qualité/provenance
```

Exemple :

```text
M3CarriagePosAct_M
input/output: output       classe: HW       nature: Measurement
unité: m                   référentiel: RailTrémie         qualité: Valid
provenance: FMU / modèle+calibration versionnés
```

Le catalogue machine est la source de vérité de ces métadonnées. Une vue IHM ne les réinvente pas.

## 2. Trois plans à ne jamais confondre

| Plan | Rôle | Convention obligatoire |
|---|---|---|
| **Causalité modèle** | Qui lit ou écrit dans le modèle ? | Modelica `input`, `output`, `parameter`, `protected` |
| **Flux industriel** | À quel endroit de la chaîne circule le signal ? | Tags projet `[CMD]`, `[CFG]`, `[HW]`, `[SAFE]`, `[TST]`, `[STAT]`, `[ACT]`, `[DIAG]`, `[BUS]` |
| **Nature de donnée** | Comment l'IHM le présente ? | `Command`, `Configuration`, `Measurement`, `DiscreteFeedback`, `DeviceState`, `Diagnostic`, `Alarm`, `Scenario` |

`CMD` n'est donc pas un synonyme de `input`, et `STAT` n'est pas un synonyme de mesure : un
capteur simulé est typiquement `output + [HW] + DiscreteFeedback`.

## 3. Classes de flux — réutilisation stricte du projet

Les classes sont exactement celles de `NAMING_CONVENTION.md`, section « Tags de Rôle ».

| Classe | TwinBench : utilisation autorisée |
|---|---|
| `CMD` | commande finale `*Cmd` venant du PLC après les interlocks ; une `*Req` ou `*Tgt` ne traverse jamais la FMU |
| `CFG` | paramètre de modèle ou calibration ; `CFG_BUILD` (géométrie, masse, mouflage) impose une nouvelle version de modèle ; `CFG_RUN` n'est modifiable qu'à pause/point sûr et est tracé |
| `HW` | fait matériel réel ou **image capteur simulée** destinée à `HwSim` |
| `SAFE` | condition de sûreté lue par un composant ; la FMU ne la produit jamais pour le PLC |
| `TST` | stimulus de scénario/défaut, isolé de la plante nominale |
| `STAT` | état public de session, adaptateur ou exécution, sans autorité safety |
| `ACT` | sortie physique PLC uniquement ; **interdite en sortie FMU** |
| `DIAG` | diagnostic, incohérence, qualité ou santé de liaison ; non autorisant |
| `BUS` | enveloppe structurée d'échange, avec un seul producteur |

`DI` et `ALARM` ne sont **pas** de nouvelles classes de flux : `DI` appartient au nom de la
borne matérielle PLC (`*_DI`), tandis qu'une alarme est une nature `Alarm` publiée sous `[DIAG]`
avec sévérité, cause, latch et acquittement explicites.

## 4. Interface FMU obligatoire

```text
PLC Cmd final [CMD] ──► Adapter ──► FMU Plant
FMU faits physiques ──► Adapter ──► HwSim [HW] ──► PRG_02 ──► HwIn
Scénarios [TST] ───────────────────► frontière capteurs seulement
```

1. `Req → Tgt → Cmd → Act` reste la chaîne de nommage projet ; ne créer aucun niveau absent.
   La frontière PLC→FMU ne reçoit que le niveau final `Cmd`. Les noms historiques comportant
   `Req` sont mappés par l'adaptateur vers un nom canonique `*Cmd` ; ils ne sont pas propagés.
2. Une FMU reçoit seulement les `Cmd` finals ; elle ne publie ni `SAFE`, ni `ACT`, ni reset,
   ni permission de mouvement.
3. L'adaptateur est l'unique producteur de l'image `HwSim`. `PRG_02` reste le seul sélecteur
   `HwReal | HwSim → HwIn`.
4. Une valeur obsolète, invalide, de version incompatible ou de qualité inconnue rend le domaine
   simulation indisponible ; elle ne conserve jamais artificiellement le dernier état sain.

## 5. Métadonnées minimales par signal

| Champ | Obligatoire | Exemple |
|---|---|---|
| `name` | oui | `M3CarriagePosAct_M` |
| `modelica_causality` | oui | `output` |
| `flow_class` | oui | `HW` |
| `kind` | oui | `Measurement` |
| `data_type` et `encoding` | oui | `Float64`, `IEEE754`; `Boolean`, `native` |
| `unit` et `reference_frame` | si grandeur physique | `m`, `RailTrémie` |
| `polarity` | tout TOR | `TRUE = frein physiquement ouvert` |
| `source_stage` | oui | `Cmd` ou `Act` |
| `access` | oui | `read`, `write`, `parameter` |
| `authority` | oui | `PLC`, `FMU`, `Adapter`, `Scenario` |
| `quality` | runtime | `Valid`, `Invalid`, `Stale`, `Uncertain` |
| `configuration_class` | si `CFG` | `CFG_BUILD` ou `CFG_RUN` |
| `calibration_status` | si `CFG` | `assumed`, `measured`, `validated`, `obsolete` |
| `model_hash`, `calibration_revision`, `timestamp`, `scan_index` | trace/rejeu | version et reproductibilité |

Les unités utilisent SI/UCUM à l'échange (`m`, `m/s`, `Hz`, `s`, `%`). Les suffixes PLC (`_M`,
`_Mps`, `_Hz`, …) restent requis par NC-030 ; le nom Modelica garde son idiome, mais le
catalogue fait le mapping explicite.

## 6. Booléens, états et paramètres

1. Tout nouveau signal logique interne Modelica est `Boolean`, pas un `Real` 0/1. Les mots
   protocolaires sont `Integer`/`UInt16`, jamais `Real`.
2. Une interface FMU/PLC temporairement numérique documente `encoding: NumericBoolean` ou
   `NumericUInt16`, sa plage et sa polarité ; elle est une dette de compatibilité, pas la convention cible.
3. Chaque retour discret porte aussi `true_means`, valeur nominale, délai/filtre et origine
   (`physical`, `simulated`, `injected`, `replayed`).
4. Un `parameter` est modifiable avant le run, versionné et marqué `assumed`, `measured` ou
   `calibrated`. Il n'est jamais éditable pendant une session live.
5. Un `DeviceState` est une énumération/code documenté ; un `StatusWord` impose un dictionnaire
   de bits/version variateur.

## 6bis. Alarmes et sécurité

Une alarme est une condition événementielle, pas un booléen process. Elle publie séparément
`active`, `latched`, `acknowledged`, `cleared`, `severity`, `cause` et horodatage. L'acquittement
ne supprime jamais la cause. Les signaux `[SAFE]`, `PowerCutOff`, reset safety, homme-mort qualifié
et toutes les sorties `[ACT]` restent autorité PLC/matériel et sont interdits en sortie de FMU.

## 7. Affichage IHM imposé

L'explorateur regroupe, dans cet ordre :

```text
Commandes finales | Configuration | Mesures | Retours TOR | Etats device | Diagnostics | Alarmes | Scénarios
```

Chaque ligne expose nom lisible, valeur, unité, qualité, source et âge. Les commandes affichent
aussi le niveau de chaîne (`Req/Tgt/Cmd`) ; les paramètres affichent leur statut de calibration.
Les signaux `[SAFE]` sont lecture seule et portent un bandeau « autorité PLC ».

## 8. Critères de conformité

- Aucun signal publié sans catalogue, classe de flux, nature, unité/polarité et autorité.
- Aucune catégorie TwinBench parallèle aux tags de `NAMING_CONVENTION.md`.
- Aucun `HW` simulé mélangé à un `HW` réel dans un même domaine.
- Aucun `ACT` ou `SAFE` produit par la FMU vers le PLC.
- Tout catalogue est validé par script contre les déclarations Modelica et sert aux traces/IHM.

## 9. Décisions issues de la revue

- Rejeté : une seule liste `CMD / CFG / STAT / DI / DIAG` ; elle confondait classe de flux et
  nature de donnée, et dupliquait `HW`/`DIAG` déjà normés côté PLC.
- Rejeté : utiliser les variables de résultat MAT comme source de métadonnées ; elles perdent la
  causalité et l'autorité d'écriture.
- Rejeté : laisser `reqTremie`, `Real 0/1` et `StatusWord: Real` devenir le contrat cible ; ce
  sont des compatibilités L1 explicitement à migrer par l'adaptateur.
- Retenu : catalogue versionné, consommable par Modex/IHM et futur adaptateur OPC UA ; Modelica
  porte la causalité, le catalogue porte le contrat industriel.
