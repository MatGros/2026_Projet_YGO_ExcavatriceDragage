# Fiche `FB_Input` — v1.1 — composant en retrait contrôlé

> 📌 Statut : **déprécié pour la nouvelle architecture**, non supprimé dans cette phase documentaire.
> La cible fait de `PRG_02_Acquisition` l'unique producteur de `HwReal`, `HwSim`, `HwIn` et des
> diagnostics d'entrée. Aucun nouveau consommateur ne doit être ajouté à `FB_Input`.
>
> Source historique archivée : `ARCHIVES/Code/COMMUN/FB_Input.st` · ancien producteur : `PRG_01_Inputs_LD`.

## 1. Décision d'architecture

`FB_Input` n'est plus la brique cible de qualification des 22 TOR. La suppression effective est
conditionnée par :

1. l'inventaire CODESYS prouvant zéro instance et zéro consommateur restant ;
2. le remappage des anciens lecteurs vers `PRG_02_Acquisition.HwIn` ;
3. la preuve du filtrage matériel des entrées ou l'implémentation d'un filtrage équivalent dans
   `PRG_02_Acquisition` ;
4. la validation manuelle des polarités, AU, freins, thermiques, limites et simulation.

## 2. Ce qui ne doit pas être reconduit

- aucun `ChannelOk := GetDeviceState()` dans un programme Ladder ;
- aucun appel de méthode device dans `PRG_01_Inputs_LD` ;
- aucun double chemin `PRG_01_Inputs_LD` / `PRG_02_Acquisition` ;
- aucune valeur `ChannelOk := TRUE` présentée comme un diagnostic matériel ;
- aucune suppression du diagnostic module `Local_Digital_IO`, `VH_0800END`, `VH_0808ETP`.

## 3. Distinction des fonctions

| Fonction | Propriétaire cible |
|---|---|
| Acquisition matérielle | `PRG_02_Acquisition.HwReal` |
| Simulation | `PRG_02_Acquisition.HwSim` / `FB_SimBench` |
| Sélection réel/simulé | `PRG_02_Acquisition.HwIn` |
| Santé carte | `GetDeviceState()` + `InputModuleFault` |
| Filtrage signal | Filtre matériel prouvé ou `PRG_02_Acquisition` |
| Barrière finale sorties | `PRG_06_Outputs_LD` |

`GetDeviceState()` renseigne l'état d'une carte ou d'un device. Il ne constitue pas un filtre
anti-rebond et ne fournit pas un diagnostic individuel de canal.

## 4. Critère de retrait

```text
grep -RInE --exclude-dir=ARCHIVES --exclude=Device.export \
  'FB_Input|ChannelOk|PRG_01_Inputs_LD|ST_InputsQualified' CODE DOC TOOLS
```

Le retrait n'est autorisé qu'après analyse de chaque occurrence et preuve `check_linkage.py`.
