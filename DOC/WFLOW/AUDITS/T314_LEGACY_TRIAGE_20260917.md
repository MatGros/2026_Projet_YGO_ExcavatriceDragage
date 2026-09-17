# T314 — Triage du legacy TwinBench / Modelica

Date : 2026-09-17  
Décision humaine : repartir propre sur OpenModelica Windows ; le legacy peut être archivé ou supprimé.

## Cible active après assainissement

Après challenge utilisateur, la phase active est recentrée strictement sur OMEdit. Le dossier
`TOOLS/TWINBENCH/modelica_atelier/` ne porte plus que :

- `Dredge.mo` : source Modelica éditable, scénarios, chronogrammes et animations OMEdit ;
- `README.md` : parcours minimal.

Le seul point d'entrée est `TOOLS/TWINBENCH/Lancer_TwinBench.bat`, hors du dossier modèle.

## Classement

| Élément antérieur | Décision | Motif |
|---|---|---|
| `Dredge.mo` | Conserver actif | Source unique ouverte et exécutée dans OMEdit |
| catalogues de signaux/parité | Déplacer vers `DOC/WFLOW/CONTRACTS/` | Preuves actives sans encombrer l'atelier utilisateur |
| viewer interactif situé sous `rumoca_poc/` | Archiver | L'utilisateur a demandé de rester dans OMEdit ; aucune IHM web active |
| `Atelier.mo`, ancien `runtime.py`, ancienne IHM AxisLab | Archiver | Modèle pédagogique concurrent de `Dredge.mo`, source de confusion |
| pont Claude et documents API/design du premier POC | Archiver | Documents datés, non contractuels pour T314 |
| scripts, modèles, rapports HTML et binaire Rumoca | Archiver | Preuve R&D utile, mais aucune dépendance active autorisée |
| branche web/FMU Python T314 | Archiver | Travail intermédiaire stoppé dès le recentrage explicite sur OpenModelica/OMEdit |
| `__pycache__/` | Archiver avec la branche abandonnée | Aucun cache Python dans le dossier actif |

## Emplacement d'archive

`ARCHIVES/Tools/TWINBENCH/modelica_atelier_pre_T314_20260917/`

Cette archive est une preuve historique seulement. Elle n'est pas une source active, ne doit pas
être lancée par le point d'entrée TwinBench et ne doit pas être utilisée pour contourner OMEdit,
OpenModelica ou OMSimulator.

## Invariants de sécurité

- aucune modification de `CODE/`, `CODE_XML/` ou `PRJ_CODESYS/` ;
- aucune liaison à une sortie physique ;
- les permissions, interlocks, AU, `PowerCutOff` et réarmements restent propriétaires du PLC ;
- toute perte d'homme-mort ou de heartbeat neutralise les commandes du banc hors ligne.
