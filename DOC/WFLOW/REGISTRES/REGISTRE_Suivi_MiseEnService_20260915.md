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
| 4 | **T290 — AX11 montée contrôlée P2** | En cycle semi-auto, maintenir la montée pendant AX11. | M1 et M2 atteignent P2 avec les interlocks existants ; manuel/maintenance inchangés. | 🟢 Confirmé en simulation par l'utilisateur le 15/09 ; recette réelle à faire. |

## ⛔ Ne pas tester comme une nouvelle fonction

| Sujet | Consigne | Pourquoi |
|---|---|---|
| **T288 — Phases 2/3** | Ne pas étendre les cas de discordance aujourd'hui. | Phase 1 seule validée. Les défauts complémentaires nécessitent mesures physiques des temps de retombée, politique d'alarme et injection de défaut simulation dédiée. |
| **T291-B — Approche haute M1/Both** | ⛔ Ne pas qualifier sur machine avant patch validé. | Snapshot AX12 : M1=P1 et M2=P5 vers 7,37 m ; la barrière Both neutralise les sorties sans alarme. La logique est commune au réel et à la simulation. |
| **T262 — Seuil benne + transition continue** | Ne pas supprimer directement AX10_WAIT_ASCENT_START. | Le transfert M2 seul → Both touche direction, contacteurs et freins ; chronogramme C4 à valider avant code. |

## 🧪 Hors machine / support de test

| Sujet | Disponible | À retenir |
|---|---|---|
| **T292 — Kobold simulation** | ✅ | Validé au banc CODESYS ; simulation uniquement. |
| **T293 — M2 couplé à M1 en simulation** | ✅ | Validé au banc CODESYS ; ne qualifie pas les treuils réels. |
| **Export traces CODESYS** | ✅ | Sélecteur de fichier dans `RESULTS/trace` ; CSV avec temps en lignes et variables en colonnes. |

## 🚨 REX AX12 — arrêt vers 7,37 m

- Snapshot : M1 `7,367 m`, M2 brut `21,641 m`, offset benne `15 m`, écart corrigé `0,726 m`.
- M1 entre dans la zone haute et demande **P1** ; M2 corrigé reste hors zone et demande **P5**.
- En Both, l'égalité finale refuse P1/P5 et neutralise les sorties physiques sans message.
- Les champs troubleshooting M2 `Idx323/324` sont trompeurs : ils comparent M2 brut à H sans offset.
- Décision : **M1 pilote le FDC logiciel nominal et le profil d'approche en M1/Both** ; M2 suit le même palier.
- M2 corrigé reste indépendant : **H+1 SafeStop**, **H+2 PowerCutOff** ; capteur TOP mécanique commun conservé.
- Suivi : **T291-B**, fiche `TROUBLESHOOTING_AX12_Arret_737m_20260915.md`.

## 🪣 Besoin client retrouvé — T262

- Seuil IHM d'ouverture benne : `0 %` par défaut = attente benne fermée comme aujourd'hui.
- Seuil `> 0 %` : entrée AX11 si ouverture réelle `< seuil` OU benne fermée.
- Objectif complémentaire : éviter l'arrêt franc AX10→AX11 et conserver la continuité AX11→AX12.
- Tant que la fermeture franche n'est pas confirmée, AX12 reste au palier lent.

## 🧠 Revue expert du phasage

- Verdict : **BLOCK avant nouveau code** ; ordre **T290 → T291-B → T262**.
- T290 : solder sans nouveau code, puis essai réel à faible hauteur.
- T291-B : B0 diagnostic/spec → B1 autorité M1 → B2 SafeStop H+1 → B3 PowerCutOff H+2/capteur.
- T262 : A paramètre seul → B transfert M2/Both P1 → C continuité AX11/AX12.
- Bloquant : `ActiveOffsetM` peut suivre `M2-M1` pendant la fermeture ; il ne constitue alors pas
  une mesure M2 indépendante pour H+1/H+2.
- T262 reste **C4** : transfert de propriété de commande sous charge et suppression d'un arrêt volontaire.

## 🧬 Audit Git indépendant — arrêt AX12

- Verdict : **RÉGRESSION IDENTIFIÉE — confiance 95 %**.
- `f36c4480` (05/09) : ajout de l'égalité finale stricte en Both et neutralisation si M1/M2 diffèrent.
- `92601d2c` (07/09) : AX12 passe de P4 à P5 ; le cas M1 ralenti P1 / M2 encore P5 devient possible.
- `196abd5c` T291-A : descente AX4..AX7 seulement, hors cause.
- `9a6aa738` / `885ad4b1` T292-T293 : simulation seulement ; elles ont révélé le défaut, pas modifié la commande réelle.
- ✅ Conclusion rassurante : **pas de régression de mesure/codeur**.
- Trou de test : aucun scénario Both avec positions corrigées différentes et ralentissement d'un seul axe.

## 📝 Journal terrain — à remplir pendant la séance

| Heure | Tâche / essai | OK / NOK | Observation courte | Décision |
|---|---|---|---|---|
|  | T291-A : AUTO M1 P4 / M2 P5 |  |  |  |
|  | T289 : égouttage AX13 |  |  |  |
|  | T288 phase 1 : discordance commande / retour |  |  |  |
|  | T290 : AX11 M1+M2 P2 |  |  |  |
|  | T291-B : approche haute pilotée par M1 | ⛔ | Ne pas tester avant patch validé |  |
|  |  |  |  |  |

## 📦 Preuves Git (repères seulement)

- `196abd5c` — T291-A, profil AUTO M1=P4 / M2=P5 ; CI partielle.
- `e56a429e` — checkpoint après validation utilisateur T289 ; garde `G499` incluse.
- `f837a24a` — checkpoint global : T288 phase 1 validée en simulation, tests TC-P10-054/055 et garde `G501`.
- `9a6aa738`, `885ad4b1` — T292/T293 simulation.
- `ddc2e39e` — outil de conversion de traces.

> 📌 Catalogue : `DOC/WFLOW/TASKS.yaml` · T291-A et T289 restent à clôturer formellement après décision humaine.
