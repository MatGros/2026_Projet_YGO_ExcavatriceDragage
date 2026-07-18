---
description: Lance une revue read-only via Herdr
argument-hint: "<scope>"
---

Utilise `herdr_delegate` pour faire relire en lecture seule le scope `$@`.
Contexte : projet CODESYS industriel.

Le rapport doit contenir uniquement :
- Bloquants
- Risques
- Écarts DOC/CODE
- Tests manquants
- Conclusion

Ne modifie aucun fichier et ne fais aucun commit. Pour safety/normes/redondance,
Ponytail est interdit et la validation humaine reste obligatoire.
