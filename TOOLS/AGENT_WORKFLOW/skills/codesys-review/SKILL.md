---
name: codesys-review
description: Effectue une revue read-only ciblée de CODE, DOC et des résultats de tests CODESYS. Utiliser pour auditer une modification ou un diff.
---

# Revue

- Lire le diff et le scope uniquement.
- Vérifier les contrats DOC actifs et la cohérence DOC/CODE.
- Auditer l’encapsulation : une responsabilité par FB, producteur unique de chaque donnée,
  internes non écrits/lus par les appelants, échanges par interfaces publiques explicites.
- Auditer les flux : commandes arbitrées avant l’appel, aucun `OR` anarchique de sources,
  aucune duplication de calcul, aucune lecture GVL cachée, structures seulement si cohérentes.
- Vérifier les tests/gates disponibles.
- Classer les constats : bloquant, important, mineur.
- Ne modifier aucun fichier.
- Pour safety, vérifier aussi que les paramètres influençant la mesure/protection ne deviennent
  pas réglables depuis l’IHM ou l’extérieur sans exigence validée ; expliciter hypothèses,
  risques et preuves manquantes.
