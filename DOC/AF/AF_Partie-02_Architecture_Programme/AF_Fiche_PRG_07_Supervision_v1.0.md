# Fiche PRG‑07 — Supervision (v1.0)

> 🎯 IHM, persistance, bypass autorisés, diagnostics et vue de dépannage.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| États publics PRG‑02 à PRG‑06, `GVL_IHM`, `GVL_PERSISTENT`, `GVL_Simulation` | États IHM, persistance/bypass, reset global | Produire une commande métier depuis troubleshooting |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 🧰 Services | Produire horloge, heartbeat et reset sur front. | 🟢 IHM/états ; effet N+1 | `GVL_IHM.*.Cmd` | Reset global unique. |
| 2. 💾 Persistance/bypass | Restaurer boot et synchroniser configurations/bypass. | 🟢 IHM/persist/simulation ; effet N+1 | `GVL_IHM`, `GVL_PERSISTENT`, simulation | Configuration et bypass autorisés. |
| 3. 🖥️ Projection | Construire la vue IHM depuis contrats publics. | 🟢 états PRG‑02 à PRG‑06 | Bus publics | Vue opérateur cohérente. |
| 4. 🔎 Dépannage | Alimenter une vue passive traçable. | 🟢 états publics | Contrats publics | Aucune commande métier produite. |

## 📚 Documents liés

- [AF‑02](../AF_Partie-02_Architecture_Programme_v3.2.md), AF‑07 IHM, AF‑12 Diagnostic, AF‑14 Troubleshooting.
