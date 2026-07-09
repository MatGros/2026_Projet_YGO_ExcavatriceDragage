# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

Une ligne par jalon significatif — pas besoin de logguer chaque sous-version mineure.

| Version CODESYS | Date | Commentaire |
|---|---|---|
| `v0.4.5_IHM_MANU` | 2026-07-09 | Correctif : Lecture codeur réel forcée en mode Manu, même si la simulation générale est active. |
| `v0.4.4_IHM_MANU` | 2026-07-08 | Ajout de la structure d'échange IHM_MANU pour pilotage direct de secours (mise en service). |
| `v0.4.3_SimNoHardware-YGO_CablePre-Commissioning` | 2026-07-08 | Validation de pilotage sans blocage en simulation (recul, vitesses, butée dynamique M2, affichage HMI stable, bypass synchro) avant l'enroulage réel de demain. |
| `v0.4.2_SimNoHardware-SyncBypass` | 2026-07-08 | Butée haute de M2 dynamique (12m/14m). Offset de bargraphe stabilisé en mouvement. Bypass synchro en butées. |
| `v0.4.1_SimNoHardware-SyncUpdate` | 2026-07-08 | Méca E synchro critique ajoutée. Arrêt rampe normale sur écart mineur (vs SafeStop). Simulation stable, pas de mise en service matérielle. |
| `v0.4.0_SimNoHardware` | 2026-07-08 | Mouvements treuils M1/M2 + grappin stables en **simulation**. Aucune mise en service matérielle réelle. |

