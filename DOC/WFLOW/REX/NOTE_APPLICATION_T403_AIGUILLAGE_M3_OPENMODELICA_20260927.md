# Note d'application T403 — Aiguillage M3 SimBench / OpenModelica

Date : 2026-09-27  
Périmètre : `FB_SimBench`, `GVL_Simulation`, `PRG_02_Acquisition`  
Statut : implémenté côté ST, recette CODESYS/OM en attente

## 1. Architecture retenue

`FB_SimBench` reste l'enveloppe unique. `SimulationModeActive` reste le verrou maître.

```text
SimulationModeActive = FALSE → HwReal, aucun effet OM
SimulationModeActive = TRUE  + SimM3OpenModelicaActive = FALSE → modèle ST M3
SimulationModeActive = TRUE  + SimM3OpenModelicaActive = TRUE  → image OM M3
```

L'image OM respecte le contrat existant `ST_HwTranslation`. La logique métier PLC,
les commandes PLC, `HwReal`, `HwSim` et `HwIn` ne sont pas remplacés.

## 2. Tests exécutés et résultats

| Test | Résultat | Ce que cela prouve |
|---|---|---|
| POC Modelica `M3_POC.mo` — `checkModel` | PASS 54/54 | Le modèle M3 est compilable par OpenModelica. |
| POC Modelica — simulation DASSL 70 s | PASS | Le scénario et les signaux publics sont simulables par `omc.exe`. |
| CODESYS ScriptEngine — probe lecture seule | PASS | Les commandes et retours M3 sont lisibles depuis CODESYS. |
| CODESYS — précondition `SimulationModeActive=FALSE` | REFUS ATTENDU | L'écriture est bloquée hors simulation. |
| CODESYS — warning `callable()` | CORRIGÉ | Le script est compatible avec le moteur Python CODESYS utilisé. |
| CODESYS — pulse Maintenance asynchrone | CORRIGÉ | Une attente de propagation est nécessaire avant le readback. |
| CODESYS — `PASS T402 ROUNDTRIP` | PASS | Écriture, lecture et restauration du bit sans forçage. |
| Bundle PLCopenXML | PASS 262/262, 0 erreur | Les objets ST sont exportables pour import CODESYS. |
| G200 liaison | PASS, 0 erreur | Les instances et appels restent reliés. |
| Gates palier C | 12/14 PASS | Les échecs G300/G340/G430 sont préexistants, hors T403. |

## 3. Test d'aiguillage T403

Implémentation effectuée :

- `SimM3OpenModelicaActive` dans `GVL_Simulation` ;
- `SimM3OpenModelica : ST_HwTranslation` comme interface de retours OM ;
- sélection dans `FB_SimBench` ;
- raccordement depuis `PRG_02_Acquisition`.

La compilation/import et le test en ligne CODESYS restent à faire par l'utilisateur.

## 4. Ce qui n'est pas encore validé

- communication cyclique réelle entre `om.exe` et CODESYS ;
- transport réseau/local (OPC UA ou autre) ;
- synchronisation temporelle des échanges ;
- comportement dynamique M3 avec commandes PLC réelles ;
- validation visuelle OMEdit du POC.

Le script Python T402 exécuté dans `Tools > Scripting` est un test ponctuel de
ScriptEngine. Il ne constitue pas encore le pont temps réel `om.exe ↔ CODESYS`.

## 5. Prochaine étape

Utiliser `CODESYS Control Win V3` avec un canal de symboles/OPC UA, puis écrire
cycliquement l'image `GVL_Simulation.SimM3OpenModelica` depuis le pont Python/OM.

La logique PLC ne doit pas être dupliquée dans Python ou OpenModelica.
