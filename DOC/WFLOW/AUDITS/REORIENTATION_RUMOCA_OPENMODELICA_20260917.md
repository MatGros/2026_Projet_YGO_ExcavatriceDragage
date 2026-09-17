# Décision de réorientation — Rumoca vers OpenModelica Windows

Date : 2026-09-17  
Décision : **OpenModelica/OMEdit/OMSimulator redevient le socle utilisateur**

## Pourquoi revenir en arrière

Le POC Rumoca a été utile pour explorer une piste Rust/VS Code, mais il ne répond
pas au besoin prioritaire de l'utilisateur : modifier facilement des simulations
Modelica sur Windows puis les exécuter et les animer avec un outil installé et
identifiable.

Constats vérifiés :

- le runtime Rumoca est séparé du serveur LSP et son installation portable n'est
  pas évidente pour un utilisateur Windows ;
- le POC de simulation a dû isoler les modèles de la Modelica Standard Library ;
- la compatibilité du modèle complet `Dredge.mo` et de ses animations n'est pas
  démontrée par Rumoca ;
- le viewer produit des rapports/HTML, mais ne remplace pas l'éditeur graphique
  et le flux de simulation OMEdit ;
- OpenModelica est déjà installé sur le poste et fournit l'exécutable Windows,
  OMEdit, la MSL, l'export FMU et OMSimulator.

## Décision technique

```text
OpenModelica + OMEdit + OMSimulator = référence de modélisation/exécution Windows
Rumoca + VS Code                         = piste R&D optionnelle, gelée
SimBench/CODESYS                         = référence PLC conservée
```

Le retour en arrière ne signifie pas que le POC Rumoca est supprimé. Ses
artefacts restent disponibles pour comparer ultérieurement l'édition Rust/3D,
mais ils ne doivent plus être nécessaires au lancement de l'atelier ni être
présentés comme moteur de référence.

## Tâches concernées

| Tâche | Décision | Motif |
|---|---|---|
| T304 — POC TwinBench/Rumoca | **Pause / réorientation** | POC exploratoire confirmé, mais installation et compatibilité insuffisantes pour un socle utilisateur Windows. |
| T314 — Atelier OpenModelica Windows | **Nouvelle tâche principale** | Reprend le besoin avec l'exécutable déjà installé : édition OMEdit, compilation, animation, conduite et traces live. |
| `OPENMODELICA_SIMULATION_MIGRATION` | **Conservée** | Contrat de migration et frontière de sûreté toujours valables ; aucun remplacement de SimBench sans preuves. |
| T307–T313 | **Conservées** | Ces tâches métier ne dépendent pas du choix Rumoca/OpenModelica et restent à traiter selon leur contrat. |

## Ce qui ne change pas

- `FB_SimBench`, CODESYS et la frontière `HwReal/HwSim/HwIn` restent la référence
  du PLC ;
- aucune simulation hors ligne ne commande une sortie physique ;
- les hypothèses mécaniques restent explicitement à calibrer ;
- aucune tâche n'est déclarée terminée par ce changement de moteur.

## Plan de reprise

1. Utiliser `Dredge.mo` comme source unique côté modèle.
2. Ouvrir et modifier les classes dans OMEdit.
3. Recompiler via OpenModelica/OMSimulator depuis l'atelier Windows.
4. Lire les mêmes sorties dans la vue 2D, la conduite interactive et les traces.
5. Rejouer les scénarios M3/M1/M2 avant toute comparaison au réel.

