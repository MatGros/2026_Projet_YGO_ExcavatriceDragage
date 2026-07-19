---
name: codesys-change
description: Prépare et exécute une modification ciblée CODESYS en respectant les specs DOC, le scope, les gates et la validation humaine. Utiliser pour modifier CODE/ ou le programme automate.
---

# Modification CODESYS

1. Lire `TASK_CONTEXT`, `DOC_WRITING_POLICY.md` et les specs actives pertinentes.
2. Vérifier le scope avec `check_structure.py` et `check_code_style.py`.
3. Présenter un plan court si le besoin n'est pas déjà validé.
4. Modifier uniquement les fichiers autorisés.
5. Lancer les gates et signaler les limites.
6. Générer le bundle via `ST_PLCOPENXML_GENERATOR` si nécessaire.
7. Ne jamais committer sans validation utilisateur.

Pour safety/normes/redondance : Ponytail interdit, review read-only obligatoire.
