→ RELAIS ou NOUVEL AGENT : à décider par l'orchestrateur du catalogue (T377-CC03 a fait l'étude lecture seule ; l'exécution peut lui revenir ou à un agent neuf)

# Brief de cadrage — sous-tâche proposée de T377 : défauts au démarrage (verrou « perte codeur », autotest AU)

> **PROPOSITION, non créée au catalogue.** Seul l'orchestrateur désigné écrit dans `DOC/WFLOW/TASKS.yaml` (règle du task-planner). Rédigé par TORC-CC10 le 2026-11-17 à partir de la MES du jour. Criticité proposée : **C4** (fonction de sécurité). Aucun code n'a été modifié.

## OBJECTIF
- À chaque démarrage du PLC, l'IHM affiche `[M1]` et `[M2]` ErrorID:02 « perte codeur » et `[AU]` ErrorID:04 « échec autotest démarrage ». La machine fonctionne après un Reset : **faux positifs de démarrage** (étude `T377_ETUDE_BOOT_PERTE_CODEUR_20261117_v0.1.md`).
- Résultat attendu : plus de défaut fantôme au démarrage, **sans affaiblir** la détection d'une vraie perte codeur ni l'autotest AU, et sans acquittement automatique d'un défaut en exploitation.

## FAITS ÉTABLIS (vérifiés dans le code, fichier:ligne)
- `FB_Safety_Winch.st:277-281` : cause « perte codeur » verrouillée sans `Enable` ni warmup (le warmup 3 s ligne 268 ne sert qu'à la cause 0).
- `FB_Encoder_Abs.st:75,91` : `EncoderAvailable = NOT((AlarmsIn<>0) OR NOT SlaveOperational)` ; `PRG_02_Acquisition.st:642-645` : `Enable := TRUE` en dur.
- `FB_Safety_EmergencyManagement.st:172-183` : autotest AU évalué **une seule fois** au premier `Enable`, exige chaîne fermée ET contacteur au repos ET séquence au repos ; `PRG_06_Outputs.st:502-503` : `Enable := TRUE` inconditionnel ; `ArmingErrorId = 8` = `StartupFail` (`FB_FaultCore.st:49-57`).
- Snapshot post-redémarrage (17/11 10:34) : codeurs RUNNING, alarmes 0, `HomedAndReliable` TRUE, mais `Idx311_ErrorEncoder` TRUE (miroir du verrou).
- Historique (exploitant, **à confirmer sur `DOC/WFLOW/ELEC`**) : le Reset après AU existait parce que les codeurs étaient sur un 24 V coupé par l'AU ; ce n'est plus le cas au simple redémarrage du PLC.

## HYPOTHÈSES À CONFIRMER (ne pas les traiter comme acquises)
- Position réelle de la chaîne AU au démarrage du matin (ouverte jusqu'au réarmement matériel ?) ; temps réel de montée du bus EtherCAT (mesure sur site) ; affectation du 24 V des codeurs.

## PÉRIMÈTRE / INTERDITS
- Candidats (à confirmer par le contrat) : `FB_Safety_Winch.st`, `FB_Safety_EmergencyManagement.st`, câblage dans `PRG_02_Acquisition.st` / `PRG_04_Treuils_Benne.st` / `PRG_06_Outputs.st`, affichage `FB_Hmi_BannerFormatter.st` (option `[HISTO]`, non urgent).
- Interdits : acquittement automatique d'un défaut **en exploitation** ; toucher aux causes mécaniques, thermiques ou AU hors démarrage ; ajouter un `FB_Watchdog` ; bypass pour « faire passer » ; `Device.export` ; modifier `GVL_PERSISTENT` (aucune variable persistante à déplacer ; ajout en fin de liste seulement si un état doit survivre).
- Les interdits actuels de T377 sur `FB_Safety_Winch` / `FB_Encoder*` sont **levés explicitement et seulement** pour cette sous-tâche.

## VARIANTES (à challenger, recommandation de CC03 : B)
- **A** — acquittement unique au boot, borné aux causes bus/codeur, après X s de liaison saine. Plus faible côté ISO 13849 (auto-acquittement d'un verrou de sécurité).
- **B** — ne pas armer le verrou « perte codeur » tant que le bus n'a pas atteint OP au moins une fois depuis le boot, avec **délai maximal X s** (au-delà : verrou posé quand même). Ne dégrade pas le cas « AU puis réarmement » : le drapeau « OP atteint » est déjà vrai, toute perte ultérieure verrouille.
- **Autotest AU** : l'étude propose de rejouer l'évaluation après le réarmement, ou de la rendre dépendante de l'état d'armement. À instruire avec le persona `safety`.

## PHASES ET POINTS D'ARRÊT
1. Lire le contrat, `NAMING_CONVENTION`, `AF_Partie-01`/`-09`, le code réel et la note de CC03. Confirmer sur schéma électrique la chaîne AU et le 24 V codeurs.
2. **Mesure sur site** : durée entre le passage en RUN du PLC et `Operational` des codeurs (diagnostic IHM). Fixer X > cette durée.
3. Challenger le besoin (agent indépendant, lecture seule) et produire le plan.
4. **ARRÊT HUMAIN** : validation du plan par l'exploitant avant toute écriture dans `CODE/`.
5. Implémenter (un seul écrivain), puis relecture du diff par un agent indépendant (`BLOCK/MAJOR/MINOR/PASS`).
6. `generate_codesys_bundle.py`, diff bundle, `G200_check_linkage.py --report`, `run_all_gates.py --palier C`.
7. **Essai machine** (matrice ci-dessous) par l'exploitant ; aucun commit ni push sans accord.

## CRITÈRES TESTABLES (à reprendre dans `TASK_CONTRACT_<id>.yaml`, avec `verified_by`)
- AC1 — (a) redémarrage du PLC sous puissance, 24 V présent : aucun verrou « perte codeur » après initialisation du bus, `ErrorId = 0` sur M1/M2.
- AC2 — (b) mise sous tension complète après long arrêt : même résultat ; comportement de l'autotest AU **documenté ou corrigé** (chaîne AU ouverte avant réarmement).
- AC3 — (c) AU en cours de marche puis réarmement : perte codeur **verrouillée immédiatement** (comportement historique préservé).
- AC4 — codeur réellement absent au démarrage : verrou posé au plus tard après X s ; cause « communication codeur » (live) visible immédiatement.
- AC5 — perte du bus en exploitation : verrou immédiat, sans changement.
- AC6 — aucun acquittement automatique d'un défaut hors démarrage ; Reset opérateur inchangé (front, jamais conditionné).
- AC7 — bundle complet + diff bundle, `G200` PASS (0 erreur), gates palier C verts, scénarios SimBench des trois états du drapeau (OP jamais vu / vu une fois / perdu après avoir été vu).

## CHANTIERS CONCURRENTS (rubrique obligatoire)
- **T377** (CC03) : `PRG_02_Acquisition.st` — un seul écrivain à la fois ; lot homing complet « préparé, sans GO ».
- **T417-C** et ses sous-tâches (AGY02) : lot terrain de plusieurs fichiers, dont `PRG_04`/`PRG_06` modifiés le 16/11.
- **T386** (rotation de phase) et **T387** (benne) : touchent aussi `FB_Safety_Winch` → collision à arbitrer par l'orchestrateur avant tout verrou.
- **T395** (MAINT_N2) : modifie `PRG_03`/`PRG_04`/`PRG_06` ; ne pas défaire.

## PREUVES ATTENDUES
- Faits code (fichier:ligne), diff réel, sortie brute des gates et de `G200`, essais machine consignés avec heure lue par commande (`date`).

## RESPONSABILITÉ DU PRINCIPAL
- L'agent principal reste garant du code, du rapport et de la cohérence avec le besoin ; il vérifie les affirmations des sous-agents à la source. Hypothèse safety non tranchée = arrêt et remontée à l'orchestrateur.

## FORMAT DE RESTITUTION
- Verdict court · fichiers touchés · AC1 à AC7 un par un · tests/gates (sortie brute) · risques résiduels · hors scope constaté · bloc « Auto-vérification liaison ».
