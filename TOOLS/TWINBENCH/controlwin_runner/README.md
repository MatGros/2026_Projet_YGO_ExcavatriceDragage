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
   complète de la copie source y est importée. Le device constructeur et ses
   modules E/S ne sont jamais modifiés ni copiés. Aucune connexion n'est ouverte.
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
- aucun stub E/S injecté automatiquement ; les erreurs sont restituées ;
- le déploiement est refusé si la copie a changé depuis la préparation.

## Limite du premier POC

Un projet construit pour le PLC réel peut ne plus compiler après remplacement
du device : les symboles créés par les modules E/S peuvent disparaître. Cette
erreur est un résultat attendu du diagnostic. Un éventuel shim `HW_SIM` fera
l'objet d'une décision séparée ; il ne sera jamais ajouté silencieusement.
