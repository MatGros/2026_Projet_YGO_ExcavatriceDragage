# Fiche PRG‑05 — Translation (v1.0)

> 🎯 Domaine M3 : décodage, interlocks, safety et requête finale variateur.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| `PRG_02.HwIn.Translation`, `PRG_03.Auth`, états `PRG_04`, `GVL_IHM` | Position logique, état, safety et requête M3 | Écrire la sortie variateur finale : responsabilité PRG‑06 |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 📍 Décodage M3 | Convertir les cinq capteurs en position logique et cohérence. | 🟢 `HwIn.Translation` | Capteurs translation qualifiés | Position M3 disponible avant toute décision. |
| 2. 🚧 Interlocks | Évaluer hauteur M1/M2, limites et verrous position. | 🟢 acquisition/Auth/état M1‑M2 | `PRG_02`, `PRG_03`, `PRG_04` | Enveloppe de déplacement M3. |
| 3. ↔️ Arbitrage | Sélectionner cible, sens et vitesse admissibles. | 🟢 position/interlocks/IHM | Résultats précédents et cycle | Consigne M3 unique. |
| 4. 🛡️ Safety/exécution | Déterminer SafeStop/PowerCutOff puis produire la requête. | 🟢 consigne ; 🟡 état local publié tardivement si relu | Consigne, feedbacks, diagnostics | Requête M3 bornée par safety. |
| 5. 📤 Publication | Publier position, état et diagnostic. | 🟢 exécution | Résultats du scan | Contrat unique PRG‑06/07. |

## ⚠️ État de migration

La responsabilité de décodage est attribuée ici. Le code actuel l'exécute encore dans PRG‑02 :
migration C3 à planifier sans double producteur, avec revue IHM et safety.

## 📚 Documents liés

- [AF‑02](../AF_Partie-02_Architecture_Programme_v3.2.md), [AF‑11](../AF_Partie-11_Fonction_Translation_v2.3.md).
- [FB Translation PositionDecoder](../AF_Partie-11_Fonction_Translation/FB_Translation_PositionDecoder_v1.1.md), Safety et OutputInterlock M3.
