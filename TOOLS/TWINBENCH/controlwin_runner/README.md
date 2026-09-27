# TwinBench Control Win Runner — POC T404

## But

Tester un projet CODESYS dans **CODESYS Control Win V3 x64** sans jamais
modifier le fichier choisi par l'utilisateur ni reconfigurer le PLC réel.

Le lanceur travaille dans un dossier local fixe :

```text
%LOCALAPPDATA%\TwinBenchControlWin\
├── Archives\
├── Current\TwinBench_ControlWin.project
├── Logs\
└── manifest.json
```

## Utilisation

Double-cliquer sur `Lancer_TwinBench_ControlWin.cmd`, puis utiliser le menu :

1. **Importer** : choisir un `.project` ou `.projectarchive`. L'original est
   contrôlé par SHA-256 avant/après et n'est jamais ouvert par CODESYS.
2. **Préparer** : un nouveau projet Control Win est créé et l'`Application`
   complète de la copie source y est importée. Un adaptateur `HW_SIM` remplace
   uniquement dans l'export dérivé les symboles produits par les modules E/S.
   Le device constructeur et le projet source ne sont jamais modifiés. Aucune
   connexion n'est ouverte.
3. **Déployer** : Control Win local est démarré, recherché par son identité
   exacte, puis la copie est téléchargée et lancée. Le PLC réel est exclu.
4. **Ouvrir la copie** : CODESYS ouvre exactement la copie déployée pour le
   monitoring, les Watch et les Traces.
5. **État** : affiche le manifeste et le dernier rapport.

## Garde-fous

- adresse réseau imposée à `127.0.0.1` lors de la préparation ;
- cible exigée au scan : `PC-Z-VICTUS` / `CODESYS Control Win V3 x64` ;
- Target ID exigé : type `4096`, ID `0000 0004`, version `3.5.19.10` ;
- aucun accès à `CODE/`, `PRJ_CODESYS/` ou au projet source après copie ;
- adaptateur E/S injecté uniquement dans la copie Control Win, avec types et
  valeurs initiales explicites dans le rapport de préparation ;
- joystick simulé initialisé au neutre (`5000`) ; autres entrées à l'état sûr ;
- appels d'état des modules remplacés uniquement sur la cible simulée ;
- toutes les erreurs et tous les avertissements de compilation sont restitués ;
- les fichiers `candidate_*` d'une tentative réussie ou échouée sont déplacés
  dans `Archives` ; aucun résidu n'est supprimé ;
- le déploiement est refusé si la copie a changé depuis la préparation.

## Limites

- L'adaptateur permet la compilation de l'Application sur Control Win ; il ne
  reproduit pas le comportement électrique des modules réels.
- La tâche `CAN` reste sans POU sur la cible simulée et génère un avertissement.
- La préparation ne déploie rien. Le déploiement reste une action séparée,
  explicite, et limitée au Control Win local.
