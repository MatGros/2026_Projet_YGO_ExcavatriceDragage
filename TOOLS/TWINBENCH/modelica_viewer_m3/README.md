# Modelica M3 Viewer — atelier expérimental

Viewer/éditeur local pour les modèles OpenModelica `.mo`, première cible : **axe de translation M3 seul**.

## Objectif

L'outil fournit un atelier léger autour d'OpenModelica :

- ouverture et sauvegarde d'un fichier `.mo` ;
- découverte des packages/classes/modèles ;
- vue blocs simplifiée à partir de la structure Modelica ;
- inspection des ports `input` / `output` / `parameter` ;
- édition textuelle du modèle ;
- `checkModel()` avant simulation ;
- simulation via `omc` avec sortie CSV ;
- lecture des résultats et tracé natif sans dépendance Python externe ;
- sélection d'une variable et affichage de sa valeur min/max/finale ;
- affichage du journal OpenModelica en cas d'erreur.

Le moteur physique reste **OpenModelica**. Le viewer ne recalcule pas la physique en Python.

## Lancement Windows

Depuis la racine du dépôt :

```bat
TOOLS\\TWINBENCH\\modelica_viewer_m3\\Lancer_M3Viewer.bat
```

Ou :

```powershell
python TOOLS/TWINBENCH/modelica_viewer_m3/modelica_viewer_m3.py
```

Le programme cherche `omc.exe` dans `OPENMODELICAHOME`, dans le PATH et dans `C:\\Program Files\\OpenModelica*`.

## Modèle de départ

Le bouton **Ouvrir Dredge M3** charge :

`TOOLS/TWINBENCH/modelica_atelier/Dredge.mo`

et sélectionne :

`Dredge.Examples.M3ContractCycle`

Ce modèle reprend le contrat actuel de la plante M3 :

`commandes finales -> plante physique -> mesures / retours TOR / état variateur / diagnostics`.

## Limites volontairement assumées

Cette V0 n'est pas un remplacement d'OMEdit et ne prétend pas éditer graphiquement toutes les annotations Modelica.

La vue graphique V0 est une **vue structurelle** générée depuis le texte Modelica. L'édition graphique des connexions sera ajoutée après validation du flux M3.

Aucune connexion PLC, aucune sortie physique, aucun pilotage machine réelle et aucune logique safety n'est implémentée.

## Évolution prévue

1. M3 : moteur électrique + variateur + frein + mécanique + rail + capteurs.
2. M3 : édition graphique des connexions.
3. M1/M2.
4. Benne et cinématique couplée.
5. Chaîne complète hors ligne.
6. éventuellement interface FMU/PLC virtuelle, uniquement avec un contrat séparé et les mêmes frontières de sûreté.
