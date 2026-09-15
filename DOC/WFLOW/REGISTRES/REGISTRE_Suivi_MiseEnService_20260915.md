# 🧾 MES — Feuille d’essais du 15/09/2026

> 🎯 **But ce matin** : savoir immédiatement quoi essayer sur la vraie machine.
> ⚠️ Un commit sauvegarde du code ; il ne prouve pas un essai machine.

## 🚨 Pourquoi cette intervention

- 📞 **Incident client du 14/09** : sorties automate actives, mais contacteurs de **direction** et de **vitesse** ne commutaient pas.
- 🔎 **Constat** : le retour du contacteur de direction est resté inactif ; aucun message d'alarme ne permettait d'identifier cette discordance.
- 🔌 **Seule reprise obtenue** : coupure générale de tension de l'installation, puis redémarrage.
- 👷 **Objet de l'intervention du 15/09** : qualifier ce défaut avec le collègue, avancer les essais utiles (T291-A, T289) et disposer d'une alarme de discordance exploitable pour éviter un blocage silencieux.
- 🛡️ **T288 phase 1 validée en simulation** : sous commande sans mouvement, avec retour collectif « tous contacteurs au repos », une alarme unique `ErrorID:16` est levée puis le **SafeStop** agit après 3 s. Aucun PowerCutOff ajouté.

## 🚦 À tester sur machine — priorité

| Prio | Essai | Action opérateur attendue | Résultat attendu | Statut |
|---|---|---|---|---|
| 1 | **T291-A — Plongée AUTO M1 P4 / M2 P5** | Cycle semi-auto uniquement : lancer une descente. Laisser `GVL_IHM.Commun.Cfg.WinchMaxStepDescent = 4`. | M1 reste au **palier 4** ; M2 atteint **palier 5**. Manuel et maintenance N1/N2 inchangés. | 🟡 Déjà confirmé au banc par l'utilisateur ; recette machine C4 à faire. |
| 2 | **T289 — Égouttage AX13 IHM** | Modifier la consigne en secondes pendant AX13, puis observer le compteur. | Tempo effective conforme à la consigne ; temps écoulé en secondes, croissant et lisible. | 🟢 Déjà confirmé par l'utilisateur ; à rejouer machine si souhaité. |
| 3 | **T288 — Discordance commande / retour** | En simulation uniquement : figer le mouvement et injecter un retour collectif « tous repos » pendant une commande. | Après 3 s : `ErrorID:16`, message de discordance et SafeStop ; pas de PowerCutOff. Reprise seulement après disparition de la cause et Reset conscient. | 🟢 Phase 1 confirmée en simulation par l'utilisateur. Essai machine réel à cadrer. |

## ⛔ Ne pas tester comme une nouvelle fonction

| Sujet | Consigne | Pourquoi |
|---|---|---|
| **T288 — Phases 2/3** | Ne pas étendre les cas de discordance aujourd'hui. | Phase 1 seule validée. Les défauts complémentaires nécessitent mesures physiques des temps de retombée, politique d'alarme et injection de défaut simulation dédiée. |
| **T290 — Remontée extraction P2** | Ne pas attendre de changement. | Cadrée seulement ; aucun code implanté. |

## 🧪 Hors machine / support de test

| Sujet | Disponible | À retenir |
|---|---|---|
| **T292 — Kobold simulation** | ✅ | Validé au banc CODESYS ; simulation uniquement. |
| **T293 — M2 couplé à M1 en simulation** | ✅ | Validé au banc CODESYS ; ne qualifie pas les treuils réels. |
| **Export traces CODESYS** | ✅ | Sélecteur de fichier dans `RESULTS/trace` ; CSV avec temps en lignes et variables en colonnes. |

## 📝 Journal terrain — à remplir pendant la séance

| Heure | Tâche / essai | OK / NOK | Observation courte | Décision |
|---|---|---|---|---|
|  | T291-A : AUTO M1 P4 / M2 P5 |  |  |  |
|  | T289 : égouttage AX13 |  |  |  |
|  | T288 phase 1 : discordance commande / retour |  |  |  |
|  |  |  |  |  |

## 📦 Preuves Git (repères seulement)

- `196abd5c` — T291-A, profil AUTO M1=P4 / M2=P5 ; CI partielle.
- `e56a429e` — checkpoint après validation utilisateur T289 ; garde `G499` incluse.
- `f837a24a` — checkpoint global : T288 phase 1 validée en simulation, tests TC-P10-054/055 et garde `G501`.
- `9a6aa738`, `885ad4b1` — T292/T293 simulation.
- `ddc2e39e` — outil de conversion de traces.

> 📌 Catalogue : `DOC/WFLOW/TASKS.yaml` · T291-A et T289 restent à clôturer formellement après décision humaine.
