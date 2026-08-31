# Fiche PRG‑06 — Outputs (v1.0)

> 🎯 Barrière matérielle finale : commandes actionneurs, AU et réarmement.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| Demandes/safety `PRG_04/05`, acquisition, IHM, reset `PRG_07` N‑1 | Q/PDO actionneurs, état AU, `PowerCutOff` agrégé | Produire une demande métier M1/M2/M3 |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 🔒 Barrières | Borner M1/M2/M3 par les interlocks finaux. | 🟢 PRG‑04/05 courant | Requêtes et safety procédés | Ordres autorisés ou neutralisés. |
| 2. ⚡ Actionneurs | Écrire les Q/PDO depuis les barrières seulement. | 🟢 interlocks | Ordres finaux | Sorties moteur/frein cohérentes. |
| 3. 🔧 Auxiliaires | Écrire les auxiliaires de leur demande propriétaire. | 🟢 demande courante | Demande Kobold | Sortie auxiliaire cohérente. |
| 4. 🛑 AU/réarmement | Agréger `PowerCutOff`, gérer AU et maintiens puissance. | 🟢 safety/acquisition/IHM ; 🟡 reset N‑1 | Demandes safety et reset | Chaîne puissance cohérente. |
| 5. 📤 Publication | Rendre les états sortie/AU publics. | 🟢 scan | Résultats précédents | Supervision courant ; banc N‑1. |

## 📚 Documents liés

- [AF‑02](../AF_Partie-02_Architecture_Programme_v3.2.md), AF‑01, AF‑06, AF‑10, AF‑11.
