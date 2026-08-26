# Fiche PRG‑04 — Treuils & Benne (v1.0)

> 🎯 Domaine M1/M2/benne : arbitrage, synchronisation, safety et demandes finales.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| `PRG_02`, `PRG_03.Auth`, `GVL_IHM`, configuration persistante | États, safety et requêtes M1/M2 | Écrire Q/PDO finaux : responsabilité PRG‑06 |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 🧭 Intention | Qualifier maintenance et assistants de conduite. | 🟢 acquisition/Auth/IHM | Bus acquisition, droits et commandes IHM | Intention non ambiguë. |
| 2. 🪣 Benne | Évaluer état et séquences benne. | 🟢 mesures ; 🟡 états publiés si requis | Mesures M1/M2, intention | État benne utilisable pour les interdictions. |
| 3. 🪝 Arbitrage | Fusionner les sources en une demande par treuil. | 🟢 cycle, joystick, benne | Droits, cycle, `Data` acquisition | Consignes candidates uniques. |
| 4. 🛡️ Safety | Évaluer synchronisme, limites, permis et `PowerCutOff`. | 🟢 mesures/candidates | Consignes candidates et retours qualifiés | Permis effectifs déterminés. |
| 5. ⚙️ Exécution/publication | Produire requêtes M1/M2, états et diagnostics. | 🟢 décision du scan | Résultat safety | Contrat public pour PRG‑05/06/07. |

## 📚 Documents liés

- [AF‑02](../AF_Partie-02_Architecture_Programme_v3.2.md), AF‑10 Winch et ses fiches FB, AF‑03.
