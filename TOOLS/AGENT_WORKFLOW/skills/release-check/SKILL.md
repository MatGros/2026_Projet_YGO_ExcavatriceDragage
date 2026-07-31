---
name: release-check
description: Vérifie la fin d'une tâche CODESYS avant intégration manuelle et prépare un rapport compact sans commit automatique.
---

# Release check

- Vérifier le diff et les fichiers générés.
- Exécuter les tests disponibles.
- Vérifier les liens DOC/CODE.
- Pour C3/C4 ou safety : `human_validation_required` reste la garantie (vérification manuelle CODESYS avant chargement). Si un test PLC automatique a été déclaré (`tests_automated_required: true`), exécuter `check_task_test_contract.py <TASK_CONTEXT> --release`; sans `implemented` + preuve d'exécution, rapporter « lot incomplet ».
- Si `CODE/` a changé : exécuter `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .`; échec = release bloquée.
- Ne jamais proposer un import POU par POU : communiquer uniquement le bundle frais.
- Lister validation CODESYS et essais terrain requis.
- Demander l'accord utilisateur avant tout commit.
