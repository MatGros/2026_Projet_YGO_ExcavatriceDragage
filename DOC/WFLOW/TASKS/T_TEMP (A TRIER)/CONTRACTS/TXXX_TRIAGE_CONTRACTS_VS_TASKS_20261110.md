# CONTRACTS versus TASKS — identification et tri du 2026-11-10

**190 fichiers analysés**, tous sous `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/CONTRACTS/`. Révision `9b70dc6c665f3b3013e5b01ca3b338c3ac72fe31`. **Analyse uniquement : aucune suppression, aucun renommage, aucune correction de contrat ou du catalogue.**

Méthode : corpus intégral réparti entre trois agents DeepSeek v4.1 Flash (41/79/70 fichiers), index des 190 fichiers partagé ; quatrième avis ciblé sur remplacements et collisions. Route Ollama `deepseek-v4.1-flash:cloud` : traitement cloud. Lecture et arbitrage indépendants des propositions, contrôle structurel local et vérification HEAD.

## Décision proposée

| Décision | Nombre | Signification |
|---|---:|---|
| GARDER | 170 | Utilité actuelle ou valeur de preuve/référence conservée. |
| SUPPRIMER proposé | 4 | Remplacement explicite vérifié ; accord de suppression non demandé ni supposé. |
| GARDER — reprise préalable | 16 | Identité, contenu, preuve de reprise ou sauvegarde à clarifier avant réutilisation/retrait. |

## Ce qui a été identifié

- 122 YAML, 60 Markdown, 5 journaux TXT et 3 sauvegardes .bak_* ; parmi les YAML, 118 portent un nom TASK_CONTRACT_*.yaml et 4 ont un autre rôle.
- Rattachement nominal trouvé pour 190/190 fichiers : identifiant exact ou parent, avec les quatre documents TS_LOT1/TS_LOT5 reliés à T428. Cela ne prouve PAS un rattachement métier correct : six collisions d’objet sont détaillées ci-dessous.
- Répartition des fichiers selon le statut de leur rattachement nominal : 164 à faire, 13 terminés, 12 en cours, 1 rattaché à une tâche annulée/remplacée (T340). Ces nombres comptent des fichiers, pas des tâches distinctes.
- Aucun doublon binaire exact. Les couples Markdown/YAML ne sont pas supprimés par défaut : lecture humaine et critères structurés peuvent avoir des rôles complémentaires.
- 187 fichiers présents dans HEAD ; trois sauvegardes ignorées par *.bak_* et non suivies. Leur présence sur disque ne signifie pas qu’elles ont été incluses dans le checkpoint précédent.
- Contrat COMPLETED, tâche terminée et recette machine sont trois informations distinctes ; aucune validation machine n’est déduite du tri.

## Quatre retraits proposés

| Fichier | Pourquoi |
|---|---|
| `BRIEF_T224_ARMINGPERMIT_COHERENT.md` | Brief v1 explicitement déclaré faux/remplacé dans le début du brief v2 : trois affirmations fausses et un risque majeur ; la v2 demande de transmettre la version corrigée. Garder la v2 et le contrat, retirer la consigne périmée. Historique HEAD confirmé. |
| `BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST.md` | Brief v1 jamais transmis, réfuté avant transmission : sa borne interdisait le correctif requis. La v2 documente ce rejet ; T371 au catalogue reprend également la réserve et sa résolution. Garder v2, contrat, note et revue ; retirer la consigne fautive. Historique HEAD confirmé. |
| `BRIEF_T368_TEMPS_ECOULE_BANDEAU_AX13.md` | Brief consommé : le contrat T368 reprend le bandeau MMminSSs, tranche AX13 en temps RESTANT, impose réemploi des valeurs et preuves CI/G200. Conserver ce contrat et sa note. La clôture catalogue n’est pas supposée : le retrait vise le brief devenu redondant. |
| `TASK_CONTRACT_T383_MECAB_SOURCE_COMMANDE.yaml` | Fichier composé seulement de commentaires, explicitement DÉPRÉCIÉ et sans valeur contractuelle : T383 est déjà utilisé pour AX15D ; renvoi vers TASK_CONTRACT_T387_MECAB_SOURCE_COMMANDE.yaml, présent et conservé. Ne pas confondre avec le brief valide T383. |

## Six collisions d’objet à conserver et requalifier

| Fichier | Écart avec le catalogue |
|---|---|
| `TASK_CONTRACT_T262_LOCAL_IHM_BLOCKS.yaml` | Identifiant T262 réutilisé pour LocalIHM CtrlBlock/StatusBlock ; le catalogue T262 concerne seuil benne et continuité AX10→AX12. Conserver le besoin IHM et établir le bon rattachement avant réutilisation. |
| `TASK_CONTRACT_T263_IHM_IOHW_READONLY.yaml` | Identifiant T263 utilisé pour image IoHw lecture seule ; le catalogue T263 concerne inhibition synchro benne pendant 4 s. Garder le contenu, réconcilier son identité. |
| `TASK_CONTRACT_T264_HOMING_BOOT_GUARD.yaml` | Identifiant T264 utilisé pour garde boot/homing ; le catalogue T264 vise retrait des bypass AU à la livraison. Garder le contenu et confronter aux lots homing avant de le rattacher. |
| `BRIEF_T372_GENERATEUR_TEMPLATE_TRACE.md` | Brief de générateur .trace ; T372 au catalogue vise le harnais/registry CI et les rapports périmés. Besoin distinct : conserver et identifier son vrai suivi. |
| `BRIEF_T373_INREFERENCINGMODE_FENETRE_ETROITE.md` | Brief sur fenêtre InReferencingMode/homing ; T373 au catalogue vise visibilité du refus directionnel M3. Conserver et réconcilier le rattachement. |
| `TASK_CONTRACT_T375_MOT7_RESET_AC600.yaml` | Contrat sur mot 7 reset AC600 EtherCAT ; le catalogue T375 concerne les messages de blocages silencieux. Conserver sans l’exécuter sous un identifiant ambigu. |

## Contrôle structurel actuel

**118 contrats YAML contrôlés : 114 PASS, 4 FAIL.** Appel de la fonction `check(path, release=False)` du script existant `TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py`. Lecture seule, pas de contrôle PLC, pas de gate complet, pas de test machine.

| Fichier | Résultat | Interprétation |
|---|---|
| `TASK_CONTRACT_T273_WINCH_MAINTENANCE_DESCENTE_FREIN_REMONTEE_P1.yaml` | FAIL : T1: aucune section `contract:` — obligatoire a partir de C2. Gabarit : TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml | Conserver et remettre au format/compléter avant réutilisation. |
| `TASK_CONTRACT_T327_MANUAL_BUCKET_LIMITS_PHASE_JOG.yaml` | FAIL : T8: scope CODE/MAIN sans critere structurel explicite : nom de fichier = nom de POU; suffixe = langage genere dans le bundle | Conserver et remettre au format/compléter avant réutilisation. |
| `TASK_CONTRACT_T383_MECAB_SOURCE_COMMANDE.yaml` | FAIL : T1: aucune section `contract:` — obligatoire a partir de C2. Gabarit : TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml | Faux contrat explicitement déprécié, retrait proposé. |
| `TASK_CONTRACT_T391_M3_ANYFAULT.yaml` | FAIL : T8: scope CODE/MAIN sans critere structurel explicite : nom de fichier = nom de POU; suffixe = langage genere dans le bundle | Conserver et remettre au format/compléter avant réutilisation. |

Le fichier T273 est un ancien format à clés racine (`task_id`, `objectifs_testables`), pas une absence de besoin métier. Les 122 YAML se parsèment sans erreur syntaxique ; cela ne garantit ni leur identité, ni leur conformité sémantique. Les résultats détaillés figurent dans `TXXX_CONTROLE_STRUCTURE_CONTRACTS_20261110.json`.

## Arbitrages par rapport aux avis d’agents

- Les mentions ABSENTE pour T217, T270 et T400 sont réfutées par lecture directe du catalogue courant : ces trois tâches existent. Le tableau ci-dessous utilise le catalogue, pas les suppositions des agents.
- T383 existe bien pour le micro-step de décharge. Le fichier MecaB portant T383 est un pointeur erroné déprécié ; ce n’est pas le contrat de cette tâche.
- Le retrait du registre actions T262 n’est pas retenu : ses quatre mesures ne sont pas toutes prouvées soldées par l’argument fourni.
- Les anciens briefs T224/T371 sont proposés au retrait parce que leurs versions corrigées documentent explicitement leur remplacement et leurs erreurs ; l’ancien texte reste récupérable dans HEAD.
- Les trois .bak sont des versions antérieures différentes, pas des doublons binaires. Leur retrait reste subordonné à une décision sur leur sauvegarde ; aucun historique Git n’est supposé.
- Les quatre documents du lot historique T367 restent conservés conformément à T378 ; aucun marquage ou changement de statut effectué.
- Les réserves et assertions techniques des avis sont attribuées à leurs documents datés. Ni les commits mentionnés dans ces documents ni leurs tests historiques n’ont été rejoués pour valider le PLC actuel.

## Quatrième avis ciblé — arbitrage final

- Le challenger propose de conserver les v1 T224/T371 en raison de la mention « décision humaine » dans leurs v2. Ici, **on propose seulement** leur retrait : cette analyse ne lève pas un accord et ne supprime rien. Leurs erreurs et leur remplacement sont documentés par les v2 conservées, le catalogue et l’historique HEAD vérifié.
- Il conserve le brief T368 comme trace de mission tant que la recette est en attente. La proposition de retrait vise sa redondance avec le contrat conservé, pas une affirmation de recette achevée. La mention ancienne « non commité » n’est pas reprise comme état actuel : les fichiers sont présents dans HEAD.
- Il ne pouvait confirmer le remplaçant T387 car absent de son sous-corpus ; l’orchestrateur l’a lu directement dans le dossier et a vérifié son objectif MecaB. Ce manque local de contexte est levé.
- Il suggère le retrait des trois .bak après comparaison. Elles restent conservées dans notre liste tant que leur sauvegarde n’a pas été décidée : « non suivi » ne permet ni de garantir une restauration Git, ni d’affirmer qu’aucune copie historique n’existe ailleurs.
- Ses divergences de critères T224/T371 sont des points de cohérence documentaire à examiner avant réutilisation ; elles ne prouvent pas un défaut du code courant et n’ont déclenché aucune modification.

## Matrice exhaustive — 190 fichiers

Tous les chemins ci-dessous sont relatifs à CONTRACTS/. « Reprise préalable » signifie garder actuellement. La colonne catalogue décrit le rattachement nominal : consulter les collisions avant toute affectation.

### SUPPRIMER proposé

| Fichier | Catalogue courant | Rôle / preuve documentaire | Pourquoi / condition | Contrôle structurel |
|---|---|---|---|---|
| `BRIEF_T224_ARMINGPERMIT_COHERENT.md` | T224 ⬜ — ArmingPermit cohérent avec disponibilité réelle des actionneurs | Remplacement vérifié par lecture comparée ; fichier présent dans HEAD. | Brief v1 explicitement déclaré faux/remplacé dans le début du brief v2 : trois affirmations fausses et un risque majeur ; la v2 demande de transmettre la version corrigée. Garder la v2 et le contrat, retirer la consigne périmée. Historique HEAD confirmé. | Non applicable à ce contrôle |
| `BRIEF_T368_TEMPS_ECOULE_BANDEAU_AX13.md` | T368 ⬜ — Afficher le temps ecoule (min/s) a cote du bandeau mode et dans le texte AX13 egouttage | Remplacement vérifié par lecture comparée ; fichier présent dans HEAD. | Brief consommé : le contrat T368 reprend le bandeau MMminSSs, tranche AX13 en temps RESTANT, impose réemploi des valeurs et preuves CI/G200. Conserver ce contrat et sa note. La clôture catalogue n’est pas supposée : le retrait vise le brief devenu redondant. | Non applicable à ce contrôle |
| `BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST.md` | T371 ✅ — Faux vert du diagnostic mouvement (ST_MotionChecklist) - le technicien voit une barriere OK alors qu elle refuse | Remplacement vérifié par lecture comparée ; fichier présent dans HEAD. | Brief v1 jamais transmis, réfuté avant transmission : sa borne interdisait le correctif requis. La v2 documente ce rejet ; T371 au catalogue reprend également la réserve et sa résolution. Garder v2, contrat, note et revue ; retirer la consigne fautive. Historique HEAD confirmé. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T383_MECAB_SOURCE_COMMANDE.yaml` | T383 ⬜ — DECHARGE — MICRO-STEP de sequencage benne a la tremie (AX15D) + retrait du saut HORS GEL AX15B vers AX10 + amendement du GEL + garde-fou GEL<->code | Remplacement vérifié par lecture comparée ; fichier présent dans HEAD. | Fichier composé seulement de commentaires, explicitement DÉPRÉCIÉ et sans valeur contractuelle : T383 est déjà utilisé pour AX15D ; renvoi vers TASK_CONTRACT_T387_MECAB_SOURCE_COMMANDE.yaml, présent et conservé. Ne pas confondre avec le brief valide T383. | FAIL |
### GARDER — reprise préalable

| Fichier | Catalogue courant | Rôle / preuve documentaire | Pourquoi / condition | Contrôle structurel |
|---|---|---|---|---|
| `BRIEF_T372_GENERATEUR_TEMPLATE_TRACE.md` | T372 ⬜ — Harnais CI : entree registry incomplete (le test ne compile pas, personne ne le voit) + rapport .txt ecrit SEULEMENT en echec (artefact perime sur une entree qui passe) | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Brief de générateur .trace ; T372 au catalogue vise le harnais/registry CI et les rapports périmés. Besoin distinct : conserver et identifier son vrai suivi. | Non applicable à ce contrôle |
| `BRIEF_T373_INREFERENCINGMODE_FENETRE_ETROITE.md` | T373 ⬜ — Angle mort M3 : la barriere finale M3 ne publie aucun etat, donc le diagnostic de mouvement M3 ne voit pas son refus directionnel | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Brief sur fenêtre InReferencingMode/homing ; T373 au catalogue vise visibilité du refus directionnel M3. Conserver et réconcilier le rattachement. | Non applicable à ce contrôle |
| `BRIEF_T375_T365_MESSAGES_SILENCIEUX_v1.md.bak_v1` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Diff : v1→groupement T365/T375 ; ou renumérotation des AC5/6/7 vers AC9/10/11 selon la sauvegarde. | Ancienne version remplacée par le fichier courant (diff comparé), mais ignorée par .gitignore:8 (*.bak_*), absente de HEAD et non suivie. Retrait possible après décision explicite sur sa sauvegarde ; ne pas invoquer un historique Git non établi. | Non applicable à ce contrôle |
| `REGISTRE_ACTIONS_T262_AX10_STEP_CEILING_20260919.md` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Table de quatre risques : plafond AX10, proportionnalité maintenance, priorité safety, périmètre de micro-phase. | Avis de suppression non retenu : quatre mesures et statuts restent inscrits À implémenter/À vérifier. Il faut pointer pour chacune sa preuve ou sa reprise dans le contrat/plan avant retrait ; la seule existence de commits Phase B ne prouve pas ces quatre points. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml` | T229 ⬜ — FB_Cycle - une config treuil unique par etape (split X11, sequenceur au propre avant MES) | En-tête STUB rapide — à compléter ; questions ouvertes et anciennes références FB_Cycle/E_CycleStep. | Conserver le cadrage ; compléter les choix et réconcilier les anciennes étapes avec les références actives avant réutilisation. Le PASS structurel ne prouve pas que le contenu est prêt. | PASS |
| `TASK_CONTRACT_T262_LOCAL_IHM_BLOCKS.yaml` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Identifiant T262 réutilisé pour LocalIHM CtrlBlock/StatusBlock ; le catalogue T262 concerne seuil benne et continuité AX10→AX12. Conserver le besoin IHM et établir le bon rattachement avant réutilisation. | PASS |
| `TASK_CONTRACT_T263_IHM_IOHW_READONLY.yaml` | T263 ⬜ — Étendre à 4 s le maintien d'inhibition synchro après pilotage benne | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Identifiant T263 utilisé pour image IoHw lecture seule ; le catalogue T263 concerne inhibition synchro benne pendant 4 s. Garder le contenu, réconcilier son identité. | PASS |
| `TASK_CONTRACT_T264_HOMING_BOOT_GUARD.yaml` | T264 ⬜ — Retrait des bypass ingénierie AU (BypassAuPowerCutOff et RedundancyTestA) à la livraison machine | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Identifiant T264 utilisé pour garde boot/homing ; le catalogue T264 vise retrait des bypass AU à la livraison. Garder le contenu et confronter aux lots homing avant de le rattacher. | PASS |
| `TASK_CONTRACT_T270_AX12_LOADED_ASCENT_P5.yaml` | T270 ⬜ — Remontée en charge AX12 au palier 5 | Contrat C3, AC1-AC4, AX12 P5, `status: IN_PROGRESS`, aucune exécution ; le corps dit « modifier uniquement `CST_StepLoaded` ». | T270 existe bien au catalogue et reste à faire. Conserver le contrat ; vérifier le recouvrement allégué avec T291-B avant toute réutilisation ou clôture. Avis ABSENTE de l’agent corrigé. | PASS |
| `TASK_CONTRACT_T273_WINCH_MAINTENANCE_DESCENTE_FREIN_REMONTEE_P1.yaml` | T273 ⬜ — Révision cinématique treuils en maintenance (Descente frein, Remontée synchro/fermée P1 & Inhibition défauts) | Contrat C3 d’analyse, OBJ-01..04, matrice d’inhibition, aucune écriture. | Contrat actif d’architecture ; recoupe T386/T269 sur la safety. Condition : proposition technique validée. Contrôle structurel actuel FAIL : T1: aucune section `contract:` — obligatoire a partir de C2. Gabarit : TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml. Réparer le format/les critères avant une nouvelle utilisation, sans jeter le besoin. | FAIL |
| `TASK_CONTRACT_T325_D18_NEUTRE_ANALYSE_RISQUE.yaml` | T325 ⬜ — Analyse de risque - FB_WinchDirectionInterlock (D18) ne credite pas le temps reel deja passe au neutre | Contrat : « analyse pure -> pas de code cette tache » ; T355 : « correctif D18 EXISTE ET EST COMMITTE ». | L’analyse garde sa valeur, mais l’état du contrat est périmé. Condition : actualiser avant exécution, ne pas supprimer. | PASS |
| `TASK_CONTRACT_T327_MANUAL_BUCKET_LIMITS_PHASE_JOG.yaml` | T327 ⬜ — MAINT WinchSel=0 + benne auto - ManualBucketLimits (jog M2) fuit dans la phase JOG automatique (palier 1 force + trou permis/IsClosed) | Contrat de correction : « ManualBucketLimitsActive := TglManualBucketLimits AND NOT instBucket.Lifecycle.Busy » ; « validation: PENDING ». | Décision de correction et preuves, tâche non close. Condition : clôture après confirmation terrain ; « semble OK » n’est pas une validation. Contrôle structurel actuel FAIL : T8: scope CODE/MAIN sans critere structurel explicite : nom de fichier = nom de POU; suffixe = langage genere dans le bundle. Réparer le format/les critères avant une nouvelle utilisation, sans jeter le besoin. | FAIL |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_renum` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Diff : v1→groupement T365/T375 ; ou renumérotation des AC5/6/7 vers AC9/10/11 selon la sauvegarde. | Ancienne version remplacée par le fichier courant (diff comparé), mais ignorée par .gitignore:8 (*.bak_*), absente de HEAD et non suivie. Retrait possible après décision explicite sur sa sauvegarde ; ne pas invoquer un historique Git non établi. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_v1` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Diff : v1→groupement T365/T375 ; ou renumérotation des AC5/6/7 vers AC9/10/11 selon la sauvegarde. | Ancienne version remplacée par le fichier courant (diff comparé), mais ignorée par .gitignore:8 (*.bak_*), absente de HEAD et non suivie. Retrait possible après décision explicite sur sa sauvegarde ; ne pas invoquer un historique Git non établi. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T375_MOT7_RESET_AC600.yaml` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Objet du document comparé au titre/contexte du catalogue courant, pas au seul numéro. | Contrat sur mot 7 reset AC600 EtherCAT ; le catalogue T375 concerne les messages de blocages silencieux. Conserver sans l’exécuter sous un identifiant ambigu. | PASS |
| `TASK_CONTRACT_T391_M3_ANYFAULT.yaml` | T391 ⬜ — Remonter les defauts chariot M3 dans AnyFaultActive | Contrat C2, AC1-AC3, AnyFaultActive M3, `status: IN_PROGRESS`, `validation: APPROVED` (GO humain 2026-09-23). | Contrat actif ; demande humaine explicite. Aucune condition. Contrôle structurel actuel FAIL : T8: scope CODE/MAIN sans critere structurel explicite : nom de fichier = nom de POU; suffixe = langage genere dans le bundle. Réparer le format/les critères avant une nouvelle utilisation, sans jeter le besoin. | FAIL |
### GARDER

| Fichier | Catalogue courant | Rôle / preuve documentaire | Pourquoi / condition | Contrôle structurel |
|---|---|---|---|---|
| `BRIEF_T224_ARMINGPERMIT_COHERENT_v2_TRANSMISSION.md` | T224 ⬜ — ArmingPermit cohérent avec disponibilité réelle des actionneurs | Brief actif ; ADDENDUM 2026-09-21T12:30, 5 faits, Étape B après trace | Principal vecteur de transmission ; condition : trace 10 ms puis GO humain. | Non applicable à ce contrôle |
| `BRIEF_T262_SEUIL_FERMETURE_BENNE.md` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Brief ; mail GCAM 2026-09-15 ; champ mort jusqu’au 2026-09-21 ; remplacé par contrat Phase B | Consommé mais conserve le besoin d’origine ; remplacement prouvé par fichier 13 + commits 065591fb/c9e1fbfe ; recette machine restante. | Non applicable à ce contrôle |
| `BRIEF_T306_ROTATION_PHASE_v1_TRANSMISSION.md` | T306 ⬜ — Sécurité Machine — Vérifier en simulation le défaut de rotation de phase et l'interdiction totale de fonctionnement | Brief de transmission, 5 questions, phasage 0-3, AC1-AC8, chaîne vérifiée ; 2 erreurs de brief corrigées. | Brief actif ; phase 0 livrée, T386 dérive. Aucune condition. | Non applicable à ce contrôle |
| `BRIEF_T347_DUREE_CYCLE_MIN_SEC.md` | T347 ⬜ — Remplacer TIME par minutes/secondes (INT) pour les durees cycle affichees IHM (CurrentCycleElapsed, LastCycleDuration) — LOT LIVRE, NON COMMITE | Brief de transmission, chaîne complète, contraintes, non-régression chrono (§3-§8). | Brief actif du lot livré non commité. Aucune condition. | Non applicable à ce contrôle |
| `BRIEF_T351_CARTOGRAPHIE_JOYSTICK_TREUILS.md` | T351 ⬜ — Cartographie exhaustive joystick -> contacteur, MANU et AUTO, treuils M1/M2 ET translation M3 (besoin utilisateur recurrent) | Brief ; 2 chaînes M01-M66/C01-C35 ; read-only | Consommé ; remplacement = contrat T351 + fiche hors lot → incertitude. | Non applicable à ce contrôle |
| `BRIEF_T353_OUTIL_WEB_CARTOGRAPHIE_INTERACTIVE.md` | T353 ⬜ — PHASE 2 T351 — outil web interactif : choisir un geste joystick et voir le chemin exact parcouru dans le code (PRG, FB, variables), chronologiquement | Brief ; besoin « je suis un joystick » ; phase 2 T351 | Consommé ; remplacement = contrat T353 + commit 210cadb0 ; livrable final hors lot → incertitude limitée. | Non applicable à ce contrôle |
| `BRIEF_T354_ASYMETRIE_GARDE_M1_M2.md` | T354 ⬜ — Asymetrie de garde M1/M2 : NOT BucketBusy present au gate M1 et absent du gate M2 — M2 peut partir seul benne occupee | Brief ; 3 chemins M2, atteignabilité | Consommé ; remplacement = contrat T354 (dans le lot) + fiche hors lot → incertitude sur la fiche. | Non applicable à ce contrôle |
| `BRIEF_T358_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md` | T358 ⬜ — Forçage de step du cycle semi-auto : saut immédiat à une valeur, sans aucune garde de contexte ni confirmation | Brief ; décision exploitant « risque signalé et assumé », gardes retirées | Trace de la décision de risque ; remplacement prouvé par contrat + note ; recette machine restante. | Non applicable à ce contrôle |
| `BRIEF_T367_DIAGNOSTIC_DEFAUTS_BOOT.md` | T367 ⬜ — Voir s il est possible de ne pas avoir de defaut au demarrage, pour ne pas etre oblige de faire de recette ou d acquittement de defauts et donc de fait de pouvoir reamer la machine sans blocage, ce qui est logique parce que la plupart du temps ce sont juste des faux positifs et des blocages inutiles | T378 le liste parmi les 4 artefacts à marquer abandonnés, « AUCUNE SUPPRESSION ». | T378 demande explicitement de marquer l’abandon de l’ancien lot T367 SANS suppression. Préserver le document et distinguer ancien lot annulé de la demande T367 courante ; marquage non exécuté dans cet audit. | Non applicable à ce contrôle |
| `BRIEF_T370_C4_ACTIVATION_STUCKOPEN.md` | T370 ⬜ — Cartographie exhaustive des discordances contacteurs M1/M2 et choix de codage alarmes/messages | Brief activation StuckOpen ; diagnostic only, pas de PowerCutOff | Consommé ; remplacement = contrat T370_STUCKOPEN (dans le lot). | Non applicable à ce contrôle |
| `BRIEF_T370_DISCORDANCE_CONTACTEURS.md` | T370 ⬜ — Cartographie exhaustive des discordances contacteurs M1/M2 et choix de codage alarmes/messages | Brief investigation initiale ; trou M1=M2 | Remplacement = diagnostic TROUBLESHOOTING_T370 hors lot → incertitude ; conserver la question d’origine. | Non applicable à ce contrôle |
| `BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST_v2_TRANSMISSION.md` | T371 ✅ — Faux vert du diagnostic mouvement (ST_MotionChecklist) - le technicien voit une barriere OK alors qu elle refuse | Brief v2 transmis, préambule inline §0, 12 AC, 4 modes F1-F4, arrêt humain. | Trace de la mission réellement exécutée et des AC ; référence du contrat T371. Aucune condition. | Non applicable à ce contrôle |
| `BRIEF_T374_DSH_CONDITIONS_EXISTANTES.md` | T374 ⬜ — MAINT_N2 : restreindre la commande manuelle des treuils par boutons IHM a MAINT_N2 uniquement (inactive en MAINT_N1 + message op ; joystick inchange) | Brief de mission : « phase A en lecture seule », « Arrêt avant CODE/ », « status: PENDING ». | Cadre la mission read-only non exécutée. Condition : exécuter avant le plan de raccordement. | Non applicable à ce contrôle |
| `BRIEF_T375_T365_MESSAGES_SILENCIEUX_v1.md` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Brief commun v1.1 (nom de fichier v1), 4 voies silencieuses, AC1-AC8, contrainte FB_Safety_Winch interdit (§2-§6). | Brief actif du lot groupé ; groupement T365→T375 décidé. Aucune condition. | Non applicable à ce contrôle |
| `BRIEF_T383_MICROSTEP_DECHARGE_v1.md` | T383 ⬜ — DECHARGE — MICRO-STEP de sequencage benne a la tremie (AX15D) + retrait du saut HORS GEL AX15B vers AX10 + amendement du GEL + garde-fou GEL<->code | Brief : « v1 — PRÊT À TRANSMETTRE », « Aucun code … avant validation humaine de la PHASE 0 ». | Seul document de cadrage valide de T383. Condition : produire le contrat C4 avant code. | Non applicable à ce contrôle |
| `CONTRACT_T409_ANIMATION_REVIEW.md` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Contrat de challenge ; invariants capteurs/frein/UDP | Safety review unique ; conserver. | Non applicable à ce contrôle |
| `CORRECTION_CONSIGNE_T387_SECURITE_v1.md` | T387 ⬜ — FB_Safety_Winch : rendre la confirmation d'arret MecaB independante de la source de commande (JoystickYNeutral -> MovementCommanded) — faux ErrorID:09 en mode boutons MAINT_N2 | Correction de consigne ; blocage sécurité, 3 actions, remplace le point 4 | Safety C4 ; valeur propre ; ne pas fusionner avec T369. | Non applicable à ce contrôle |
| `DRAFT_T317_ARCHITECTURE_BLOCS_ST.md` | T317 ⬜ — SimBench — Modèle électrotechnique treuils M1/M2 (moteur rotor bobiné, gradins résistance rotorique, chute tension groupe électrogène) | Brouillon d’architecture ST, profils FB, questions ouvertes (« à challenger, PAS encore du code »). | Livrable de conception unique de T317 ; non remplacé. Condition : challenge avant toute implémentation. | Non applicable à ce contrôle |
| `FICHE_T400_MODELISATION_TRANSLATION_M3.md` | T400 ⬜ — Translation M3 — fiche récapitulative des données de modélisation | Fiche référence ; plaque, géométrie, hypothèses, à mesurer | Absence catalogue ≠ annulation (T384 réconciliation) ; données uniques. | Non applicable à ce contrôle |
| `IHM_FREEZE_T262_EXTRACTION_START_OPENING_20260915.md` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Gel IHM ; plage 0..20, effet à 9 %, mise à jour 2026-09-21 | Contrat d’interface unique ; non remplacé ; recette IHM à faire. | Non applicable à ce contrôle |
| `MESSAGE_AGENT_T387_BENNE_v1.md` | T387 ⬜ — FB_Safety_Winch : rendre la confirmation d'arret MecaB independante de la source de commande (JoystickYNeutral -> MovementCommanded) — faux ErrorID:09 en mode boutons MAINT_N2 | Message agent ; 3 défauts benne ; T388 absorbée | Trace de l’absorption T388 ; safety ; conserver. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T358_FORCESTEP_SANS_GARDE.md` | T358 ⬜ — Forçage de step du cycle semi-auto : saut immédiat à une valeur, sans aucune garde de contexte ni confirmation | Note ; 8 gardes tracées, 9 constats hors scope | Auditabilité sécurité ; unique. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T367_ACQ_AUTO_BOOT_ET_REARM.md` | T367 ⬜ — Voir s il est possible de ne pas avoir de defaut au demarrage, pour ne pas etre oblige de faire de recette ou d acquittement de defauts et donc de fait de pouvoir reamer la machine sans blocage, ce qui est logique parce que la plupart du temps ce sont juste des faux positifs et des blocages inutiles | Artefact T378 ; note d’application de l’ancien lot (écart de doctrine assumé, §2). | T378 demande explicitement de marquer l’abandon de l’ancien lot T367 SANS suppression. Préserver le document et distinguer ancien lot annulé de la demande T367 courante ; marquage non exécuté dans cet audit. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T371_FAUX_VERT_MOTIONCHECKLIST.md` | T371 ✅ — Faux vert du diagnostic mouvement (ST_MotionChecklist) - le technicien voit une barriere OK alors qu elle refuse | Note d’application : 2 incidents de revue corrigés, limite M3, résidus R1-R5 (§2.2, §2.5, §9). | Valeur propre : justification des décisions, réserves non recettées, preuve du raisonnement ; ne pas supprimer au motif que T371 est ✅. Aucune condition. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T387_FENETRE_BENNE.md` | T387 ⬜ — FB_Safety_Winch : rendre la confirmation d'arret MecaB independante de la source de commande (JoystickYNeutral -> MovementCommanded) — faux ErrorID:09 en mode boutons MAINT_N2 | Note ; fix MecaB, grant 4 verrous ; recette non faite | Preuve de conception safety ; unique. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T408_POC_UDP_NATIF_CONTROL_WIN.md` | T408 ⬜ — POC UDP natif — mesure 10 ms dans la copie Control Win | Note de recette : « Recette humaine — 2026-09-28 », « GO » flux rapide, « Reste … Enable := FALSE ». | Preuve partielle de recette, pas clôture. Condition : conserver jusqu’au stop/start. | Non applicable à ce contrôle |
| `NOTE_APPLICATION_T409_FMU_CONTROL_WIN.md` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Note ; corrections et 4 limites restantes | Preuve des limites ; unique. | Non applicable à ce contrôle |
| `PLAN_T262_TRANSFERT_AX10_AX11_20260915.md` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Plan C4 ; 9 fichiers, chronogrammes, repli ; cité `plan_reprise | Référence technique unique ; recette CODESYS/machine restante. | Non applicable à ce contrôle |
| `PLAN_T289_DECOMPTE_RESTANT_20260915.md` | T289 ⬜ — Égouttage AX13 — consigne IHM et décompte du temps restant en secondes (INT) | Delta temps restant ; validation machine | Unique ; T289 rouverte pour essai réel. | Non applicable à ce contrôle |
| `PLAN_T289_EGOUTTAGE_IHM_SECONDES_20260915.md` | T289 ⬜ — Égouttage AX13 — consigne IHM et décompte du temps restant en secondes (INT) | Plan phases A-D ; bornes 1..3600 s | Unique ; recette machine restante. | Non applicable à ce contrôle |
| `PLAN_T290_T291_LIMITES_TREUILS_20260915.md` | T290 ⬜ — Cycle auto extraction — autoriser palier 2 en remontee controle | Plan de reprise, addendum, revue indépendante BLOCK, limites et T290 (§1-§8). | Valeur de décision et de revue ; T290 ouverte, T291-B le référence. Aucune condition. | Non applicable à ce contrôle |
| `PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md` | T317 ⬜ — SimBench — Modèle électrotechnique treuils M1/M2 (moteur rotor bobiné, gradins résistance rotorique, chute tension groupe électrogène) | Plan P0, registre 5 questions, corrections obligatoires, verdict recherche. | Livrable actif ; conditionne R0. Condition : R0 humain. | Non applicable à ce contrôle |
| `PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` | T334 ⬜ — Translation M3 : pourquoi deux chemins de commande (manuel/MAINT vs cycle auto) ? Chaînes complètes, comparatif, et dépassement P1/Trémie en cycle | Plan Phase 3, arbitrage Q1→Q6, 7 invariants, lots L0-L4, décisions D1-D5 (§0-§9). | Livrable de conception actif de T334 ; référence des décisions Q1/Q3/Q4. Aucune condition. | Non applicable à ce contrôle |
| `PLAN_T346_BORNE_RECUL.md` | T346 ⬜ — Restaurer une borne de recul correcte sur FB_Bucket (frontiere PHYSIQUE, pas M2StartPosM), sans reproduire les coupures parasites du 2026-09-05 — LOT LIVRE, NON COMMITE | Plan ; 2 variantes, tests N1-N7, D6 | T346 lot livré non commité ; valeur de conception unique. | Non applicable à ce contrôle |
| `PLAN_T399_TWINBENCH_HYBRID_PLC_OPENMODELICA.md` | T399 ⬜ — TwinBench hybride — feuille de route CODESYS, OpenModelica et application Windows | Feuille de route P0-P6 ; jalons GO/NO-GO | Unique ; validation humaine P0.1 en attente. | Non applicable à ce contrôle |
| `PLAN_T406_TWINBENCH_CONTRAT_LIAISON.md` | T406 ⬜ — TwinBench M3 — contrat de signaux et surete de liaison PLC/plante | Plan : images atomiques, cadences, validation, états de liaison, GO/NO-GO. | Livrable actif ; conditionne les phases B/C/D. Condition : revue humaine. | Non applicable à ce contrôle |
| `PLAN_T408_POC_UDP_NATIF_CONTROL_WIN.md` | T408 ⬜ — POC UDP natif — mesure 10 ms dans la copie Control Win | Plan POC : « Critere de decision … 0 perte, p99 <= 50 ms ». | Cadre la recette et les limites. Condition : conserver. | Non applicable à ce contrôle |
| `PLAN_T409_FMU_CONTROL_WIN_INJECTION.md` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Plan ; gardes-fous, 6 étapes recette | Unique. | Non applicable à ce contrôle |
| `PLAN_T417_SIMBENCH_M3_ROUE_LIBRE.md` | T417 ⏳ — SimBench M3 - mecanique realiste et chaine automate-variateur-mouvement | Plan V2 ; roue libre abandonnée ; cible 25 Hz/s | Titre obsolète mais contenu V2 unique ; ne pas supprimer sur le titre. | Non applicable à ce contrôle |
| `PROCEDURE_CALIBRATION_ODOMETRIE_M3_T301.md` | T301 ⬜ — Translation M3 — Procédure et étalonnage terrain du ratio fréquence/déplacement et recalage des 5 capteurs | Procédure terrain : conventions, cotes 5 capteurs, formule de gain. | Livrable actif de T301. Condition : mesures terrain. | Non applicable à ce contrôle |
| `PROCEDURE_TRACE_T224_ARMINGPERMIT_10MS.md` | T224 ⬜ — ArmingPermit cohérent avec disponibilité réelle des actionneurs | Procédure 172 canaux, 6 scénarios, preuve C43-bis | Prérequis humain non joué ; valeur de preuve unique. | Non applicable à ce contrôle |
| `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` | T334 ⬜ — Translation M3 : pourquoi deux chemins de commande (manuel/MAINT vs cycle auto) ? Chaînes complètes, comparatif, et dépassement P1/Trémie en cycle | Procédure de trace 10 ms, scénarios A/B/C, canaux, matrice de décision (§4-§5). | Livrable opérationnel de T334 (run humain, recette) ; T348 s’y appuie. Aucune condition. | Non applicable à ce contrôle |
| `REFERENCE_T317_PROTOTYPE_PYTHON_FONCTIONS.md` | T317 ⬜ — SimBench — Modèle électrotechnique treuils M1/M2 (moteur rotor bobiné, gradins résistance rotorique, chute tension groupe électrogène) | Doc des calculs du prototype Python pour portage ST ; valeurs SYNTHÉTIQUES. | Référence technique unique ; le prototype source n’est pas dans le lot (incertitude sur son état). Condition : vérifier l’existence du prototype avant portage. | Non applicable à ce contrôle |
| `REGISTRE_ACTIONS_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | T288 ⬜ — Cohérence commande/retour contacteurs par axe et couverture absence de mouvement | Registre actions C4 ; 5 étapes ; attente utilisateur | Phase 2 non prête ; valeur de suivi safety. | Non applicable à ce contrôle |
| `REPONSE_T351_Q1_Q17.md` | T351 ⬜ — Cartographie exhaustive joystick -> contacteur, MANU et AUTO, treuils M1/M2 ET translation M3 (besoin utilisateur recurrent) | Réponse orchestrateur ; Q1-Q17 ; D18 corrigé/committé/non testé machine | Décisions humaines uniques ; conserver. | Non applicable à ce contrôle |
| `T262_VALIDATION_CODESYS_20260919.md` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Procédure de validation CODESYS humaine ; non faite | Preuve/recette non recettée ; valeur propre. | Non applicable à ce contrôle |
| `T401_M3_POC_SIGNAL_CATALOG.yaml` | T401 ⬜ — POC rapide M3 — fichier OpenModelica autonome ouvrable et simulable dans OMEdit | Catalogue des signaux publics du POC (rôles CMD/CFG/HW/DIAG). | Livrable référencé par le gate structurel ; non remplacé. Aucune condition. | Non applicable à ce contrôle |
| `T409_CONTROLWIN_TEST_RECIPE.md` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Recette CW-00/CW-01 ; verdicts PASS_MEMOIRE/FAIL | Recette humaine non faite ; preuve unique. | Non applicable à ce contrôle |
| `T409_FINAL_AUDIT.md` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Audit final ; prouvés/non prouvés ; verdict partiel | Ne pas transformer en validation ; conserver. | Non applicable à ce contrôle |
| `T409_T413_M3_VISUALISATION.yaml` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Contrat visualisation ; AC1-AC11 | Contrat unique ; validation Control Win requise. | Non applicable à ce contrôle |
| `T415_M3_LAUNCHER_RESTART.yaml` | T415 ⬜ — TwinBench — plateforme generale de simulation industrielle | Contrat C2, AC1-AC4, `status: COMPLETED`, `execution` CDX01, `validation: PENDING`. | Sous-lot du chantier T415 ; preuve de la relance propre sans kill. Condition : rattacher explicitement à T415. | Non applicable à ce contrôle |
| `T418_BUNDLE_GENERATION.txt` | T418 ✅ — Simulateur joystick - geste operateur complet depuis un bouton IHM | Log de génération, pas contrat : « PASS: CODE_XML/CODE_Bundle.xml is fresh », « Generated 264/264 object(s) … 0 error(s) ». | Preuve de build et de warnings, valeur de régression même T418 clos. Condition : archive de preuve, ne pas éditer. | Non applicable à ce contrôle |
| `T418_CI_BASELINE_METIER.txt` | T418 ✅ — Simulateur joystick - geste operateur complet depuis un bouton IHM | Baseline CI métier : « FAIL FB_Encoder (38/40) », « PASS FB_Bucket (41/41) », « PASS FB_CycleMachineHoming (15/15) ». | Montre échecs préexistants et succès, valeur comparative. Condition : ne pas lire comme validation de tous les FB. | Non applicable à ce contrôle |
| `T418_CI_SIMULATION.txt` | T418 ✅ — Simulateur joystick - geste operateur complet depuis un bouton IHM | Preuve CI simulation : « 12 FB testes, 12 PASS, 0 FAIL ». | Preuve de non-régression simulateur. Condition : conserver. | Non applicable à ce contrôle |
| `T418_G200_LIAISON.txt` | T418 ✅ — Simulateur joystick - geste operateur complet depuis un bouton IHM | Preuve de liaison : « Linkage check: PASS (0 erreur(s), 1727 avertissement(s), 2136 instance(s)) ». | Preuve mécanique de câblage, valeur propre. Condition : conserver comme archive, ne pas confondre PASS liaison et validation machine. | Non applicable à ce contrôle |
| `T418_GATES_COMPLETS.txt` | T418 ✅ — Simulateur joystick - geste operateur complet depuis un bouton IHM | Preuve palier C : « 6 gate(s) en echec sur 67 : G300/G100/G340/G430/G483/G519 ». | Documente les dettes et le delta de gates. Condition : ne pas présenter comme gates toutes vertes. | Non applicable à ce contrôle |
| `TASK_CONTEXT_T262_AX10_STEP_CEILING.yaml` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Mini-contexte micro-phase AX10 ; scope, 4 canaux de trace | Contexte historique utile ; faible coût ; ne pas supprimer sans vérifier le remplacement. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T213.yaml` | T213 ⬜ — Refactorer le troubleshooting — ajouter les variables de homing M2 (cible dynamique, offset benne) | Contrat ; `status: PENDING` ; AC1-AC7 | Référencé `contrat:` ; diagnostic homing M2. | PASS |
| `TASK_CONTRACT_T217_LIAISON_SORTIES_VARIATEUR_M3.yaml` | T217 ✅ — Mise en conformité PRG_06_Outputs §3bis — sorties variateur M3 ne doivent PAS être déclarées en VAR_OUTPUT homonyme d'un point matériel | Contrat C2, AC1-AC5, mapping AC600 M3, `status: IN_PROGRESS`, `validation: APPROVED` utilisateur. | T217 existe bien et est clôturée par l’exploitant au 2026-11-04. Conserver le contrat comme périmètre/preuve historique ; son IN_PROGRESS est périmé, pas une preuve de besoin actif. Avis ABSENTE de l’agent corrigé. | PASS |
| `TASK_CONTRACT_T218_BLOCAGE_MODE.yaml` | T218 ⬜ — Résoudre le blocage de mode (déverrouiller la bascule quand le retour contacteur n'est pas câblé) | Contrat C4, AC1-AC6, décision A/B/C requise avant implémentation. | Contrat actif ; blocage machine réel. Condition : décision de conception humaine. | PASS |
| `TASK_CONTRACT_T219_HISTORIQUE_ALARMES.yaml` | T219 ⬜ — Historique d'alarmes (buffer borné + horodatage), en complément du bandeau d'alarmes actives | Contrat buffer alarmes ; `PENDING` ; AC1-AC6 | Unique ; conserver. | PASS |
| `TASK_CONTRACT_T220_ENRICHIR_BANDEAU.yaml` | T220 ⬜ — Enrichir le bandeau IHM (maximum d'infos : défauts actifs, état AU, homing, blocage de mode) | Contrat : « Lot d’enrichissement (Phase 3) ». | Besoin opérateur et sécurité, non appliqué. Condition : validation utilisateur du contenu et de la priorité. | PASS |
| `TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` | T224 ⬜ — ArmingPermit cohérent avec disponibilité réelle des actionneurs | Contrat principal ; `design_decisions` l.66-68 (forme X, reprise B), `scope_conflict` G1/G2/G3, `status: PENDING | Référencé champ `contrat:` de T224 ; safety C4 ; ne pas clore sur statut vide. | PASS |
| `TASK_CONTRACT_T225_SYNCCONTACTOR_ESCALADE_PRG06.yaml` | T225 ⬜ — Concordance contacteurs M1/M2 graduee (SafeStop -> escalade PowerCutOff) en PRG_06 | Contrat safety ; `status: PENDING` ; 9 AC ; bypass | Référencé `contrat:` ; arbitrages humains ouverts. | PASS |
| `TASK_CONTRACT_T226_REFONTE_HOMING_SEMIAUTO.yaml` | T226 ⬜ — Refonte de la frontiere Referencement machine <-> SEMI_AUTO | Contrat C4, AC1-AC12, D1-D7, phases P0-P5. | Contrat actif ; incertitude : vérifier si T364/T377 n’ont pas absorbé son périmètre (le catalogue ne le dit pas). Condition : confirmer le périmètre. | PASS |
| `TASK_CONTRACT_T228_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml` | T228 ⬜ — ArmingPermit couvre les tempos idle de l interlock final (cloture du scope_conflict_flagged de T224) | Contrat C3, AC1-AC7, historique du revert 263fae18, blocages nommés. | Contrat actif ; valeur de leçon (3 contraintes de reprise). Condition : arbitrage T224. | PASS |
| `TASK_CONTRACT_T230_KOBOLD_PROTECTION_THERMIQUE.yaml` | T230 ⬜ — Protection thermique moteur / contacteur Kobold (temps maxi + repos impose + bypass) | Contrat C2 stub, AC1-AC7, Q1-Q5 ouvertes. | Stub à compléter, non remplacé ; risque de griller le moteur Kobold. Condition : trancher Q1-Q5. | PASS |
| `TASK_CONTRACT_T235_REFONTE_TRANSACTION_PRESET.yaml` | T235 ⬜ — Refonte transaction de vérification preset homing (suppression latence 500 ms) | Contrat C4 : « Validation humaine du plan obligatoire avant toute modification de CODE/ ». | Safety codeur, analyse non validée. Condition : GO humain. | PASS |
| `TASK_CONTRACT_T253_CALIB_BENNE_PERSISTANTE.yaml` | T253 ⬜ — Calibration géométrie benne réelle et fiabilisation persistance NVRAM | Contrat : « calibration … persistance NVRAM », PENDING. | Safety et mise en service. Condition : mesures site et validation. | PASS |
| `TASK_CONTRACT_T255_DYN_USER_MESSAGES_IHM.yaml` | T255 ⬜ — Guidage dynamique précis des messages opérateur et conditions IHM (Retours essais MES) | Contrat C2, AC1-AC5, `status: IN_PROGRESS`. | Contrat parent actif ; la livraison T255-D n’annule pas le reliquat. Aucune condition. | PASS |
| `TASK_CONTRACT_T258-A.yaml` | T258-A ⬜ — Etablir le socle de preuve STruC++ cycle et inter-PRG | Contrat C3, AC1-AC4, socle STruC++, `status: IN_PROGRESS`. | Contrat actif. Aucune condition. | PASS |
| `TASK_CONTRACT_T258-B.yaml` | T258-B ⬜ — Fiabiliser AX4 a AX8 diving et sequence Kobold | Contrat C3, AC1-AC5, `status: PENDING`, bloqué par T258-A. | Actif. Condition : T258-A. | PASS |
| `TASK_CONTRACT_T258-C.yaml` | T258-C ⬜ — Fiabiliser AX9 a AX12 pretension, fermeture et remontee | Contrat C3, AC1-AC5, `status: PENDING`, bloqué par A/B. | Actif. Condition : T258-A/B. | PASS |
| `TASK_CONTRACT_T258-D.yaml` | T258-D ⬜ — Ajouter mode essai controle et forçage transactionnel de step | Contrat C3, AC1-AC6, `status: PENDING`, bloqué par A. | Actif. Condition : T258-A. | PASS |
| `TASK_CONTRACT_T258-E.yaml` | T258-E ⬜ — Integrer, documenter et qualifier le lot cycle SAT J2 | Contrat C3, AC1-AC5, `status: PENDING`, bloqué par B/C/D. | Actif. Condition : B/C/D. | PASS |
| `TASK_CONTRACT_T258.yaml` | T258 ⬜ — Fiabiliser le cycle semi-auto pour SAT J2 | Contrat parent C3, AC1-AC3, `status: PENDING`. | Actif. Condition : contrats enfants. | PASS |
| `TASK_CONTRACT_T261.yaml` | T261 ⬜ — Bypass granulaire auto-test redondance AU par canal keepalive A / B | Contrat : « status: COMPLETED », « validation: PENDING ». | Preuves de modification safety et essais MES à faire. Condition : visa et essais A/B. | PASS |
| `TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Contrat principal référencé `contrat:` ; 18 AC ; `status: IN_PROGRESS | C4 safety ; recette machine non faite ; ne pas clore sur statut. | PASS |
| `TASK_CONTRACT_T262_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml` | T262 ⬜ — Seuil configurable benne et continuité AX10→AX11→AX12 | Contrat Phase B ; `status: COMPLETED` ; commits 065591fb/c9e1fbfe ; 15 AC | Remplacement prouvé du brief ; conserver comme preuve de la phase B. | PASS |
| `TASK_CONTRACT_T263_BUCKET_SYNC_HOLD_4S.yaml` | T263 ⬜ — Étendre à 4 s le maintien d'inhibition synchro après pilotage benne | Contrat : « PT = T#4s », « Validation humaine et essai sur machine requis ». | Contrat de patch ciblé, tâche ouverte. Condition : essai machine. | PASS |
| `TASK_CONTRACT_T264_RETRAIT_BYPASS_POWER_CUTOFF_LIVRAISON.yaml` | T264 ⬜ — Retrait des bypass ingénierie AU (BypassAuPowerCutOff et RedundancyTestA) à la livraison machine | Contrat C3, AC1-AC5, retrait des bypass AU à la livraison, `status: TODO` ; ISO 13849. | Vrai contrat T264 ; valeur de sécurité pour la livraison. Condition : exécution avant livraison client. | PASS |
| `TASK_CONTRACT_T269_MECAD_BUCKET_TOP.yaml` | T269 ⬜ — Empêcher le faux MecaD pendant ouverture benne au FdC haut | Contrat safety ; `IN_PROGRESS` ; AC1-AC4 ; MecaD | Safety ; conserver. | PASS |
| `TASK_CONTRACT_T272_M3_DESCENT_STATE_GATE.yaml` | T272 ⬜ — Verrou descente M3 basé sur State.AtMaintenance/AtP1 | Contrat ; `COMPLETED` ; AC1-AC6 ; `validation: PENDING | Écart statut fichier/catalogue à noter ; conserver. | PASS |
| `TASK_CONTRACT_T278_AU_ALARMS_FILTERING_AND_AUTO_RESET.yaml` | T278 ⬜ — Filtrage alarmes transitoires demarrage CPU et auto-reset post-rearmement | Contrat C3, AC1-AC7, `status: IN_PROGRESS` (exécution COMPLETED), `validation: PENDING` ; flags par défaut FALSE. | Contrat actif ; sûreté AU. Condition : essais CODESYS. | PASS |
| `TASK_CONTRACT_T280_TROUBLESHOOTING_WORKSPACE.yaml` | T280 ⬜ — Normaliser le workspace CI de troubleshooting par agent | Contrat workspace ; `validation: APPROVED | Tâche terminée mais contrat = convention durable ; ne pas supprimer. | PASS |
| `TASK_CONTRACT_T286_REFACTOR_CI_NON_REGRESSION_A_G.yaml` | T286 ⬜ — Refactor CI non-régression mise en service — domaines A à G | Contrat : « Phases 0 à 4 ». | Méthode de non-régression, encore ouverte. Condition : validation phase par phase. | PASS |
| `TASK_CONTRACT_T287_M3_BUTEES_ESCALADE_GRADUEE.yaml` | T287 ⬜ — Régression M3 sur butées — escalade graduée sans toucher FB_Brake | Contrat ; `IN_PROGRESS` ; 8 AC ; FB_Brake gelé | Safety ; preuve/trace manquante ; conserver. | PASS |
| `TASK_CONTRACT_T288_DISCORDANCE_CONTACTEURS_ABSENCE_MOUVEMENT.yaml` | T288 ⬜ — Cohérence commande/retour contacteurs par axe et couverture absence de mouvement | Contrat phase 1 ; `status: IMPLEMENTED/VALIDATED_SIMULATION` ; 5 AC | Safety ; ne pas clore sur statut catalogue ⬜. | PASS |
| `TASK_CONTRACT_T288_PHASE2_REGISTRE_ERREURS.yaml` | T288 ⬜ — Cohérence commande/retour contacteurs par axe et couverture absence de mouvement | Contrat phase 2 ; `status: REVIEWED_MAJOR_NOT_READY` ; 6 AC | Verdict MAJOR ; options A/B ; conserver. | PASS |
| `TASK_CONTRACT_T289_EGOUTTAGE_IHM_SECONDES.yaml` | T289 ⬜ — Égouttage AX13 — consigne IHM et décompte du temps restant en secondes (INT) | Contrat principal ; `status: PENDING` ; 9 AC | Référencé `contrat:` ; conserver. | PASS |
| `TASK_CONTRACT_T290_EXTRACTION_PALIER2_TEMPORISE.yaml` | T290 ⬜ — Cycle auto extraction — autoriser palier 2 en remontee controle | Contrat C3, AC1-AC7, `status: IN_PROGRESS`, simulation acquise, recette terrain à faire. | Contrat actif. Condition : recette terrain. | PASS |
| `TASK_CONTRACT_T294_TASK_MANAGER_PERFORMANCE.yaml` | T294 ⬜ — Task Manager & Viewer — Optimisation serveur (cache YAML/ETag 304) et IHM (zéro reflow DWM/GC) | Contrat performance ; `PENDING` ; AC1-AC6 | Unique ; conserver. | PASS |
| `TASK_CONTRACT_T295_AX15B_BUCKET_OPEN_TIMEOUT.yaml` | T295 ⬜ — AX15B — [BENNE] ErrorID:03 au timeout de la commande d’ouverture | Contrat du timeout benne : « SUSPENSION, PAS REMISE A ZERO » ; « contresignature humaine obtenue ». | Visa humain et preuves CI, valeur safety. Condition : ne pas clore sans recette machine AX3/AX15B. | PASS |
| `TASK_CONTRACT_T296_M3_FREQUENCES_PERSISTANTES.yaml` | T296 ⬜ — M3 — fréquences configurables et persistantes : 50 Hz standard / 15 Hz en zone PV | Contrat C3, AC1-AC7, 50/15 Hz persistants, `status: PENDING`. | Contrat actif ; cohérence avec T334/T417 à vérifier (15 Hz zone PV). Condition : confirmer la zone PV et la cohérence avec les rampes. | PASS |
| `TASK_CONTRACT_T297_CYCLE_IHM_FORCE_AX7.yaml` | T297 ⬜ — Cycle SEMI_AUTO — afficher CycleStep et préparer un saut de test vers AX7 (G7) | Contrat : « cadrage seulement ». | Décision IHM/safety, non implémentée. Condition : noms exacts des variables et GO. | PASS |
| `TASK_CONTRACT_T301_CALIBRATION_ODOMETRIE_M3.yaml` | T301 ⬜ — Translation M3 — Procédure et étalonnage terrain du ratio fréquence/déplacement et recalage des 5 capteurs | Contrat C2 V2 (2026-10-28), AC1-AC10, calculateur de position, `status: PENDING`. | Contrat actif ; V2 remplace la V1 jamais exécutée. Condition : campagne L0+L1 et GO. | PASS |
| `TASK_CONTRACT_T305_TREUILS_CONTRAINTES_ELECTROTHERMIQUES.yaml` | T305 ⬜ — Treuils — Tracer l'origine du plancher de commutation 400 ms, statuer sur l'asymétrie montée/descente et évaluer la marge thermique à la cadence nominale | Contrat C2 investigation/documentation, AC1-AC6, `status: PENDING`, zéro CODE. | Contrat actif ; documente le plancher 400 ms et le thermique. Condition : relevés MES. | PASS |
| `TASK_CONTRACT_T306_PHASE1_INJECTION_SIM.yaml` | T306 ⬜ — Sécurité Machine — Vérifier en simulation le défaut de rotation de phase et l'interdiction totale de fonctionnement | Contrat C2 phase 1, AC1-AC8, injection sim, `status: PENDING`. | Contrat actif ; la preuve ROUGE/VERT a été jugée quasi-tautologique par le challenge → à rejouer. Condition : compléter les tests d’intégration. | PASS |
| `TASK_CONTRACT_T306_VERIFICATION_DEFAUT_ROTATION_PHASE.yaml` | T306 ⬜ — Sécurité Machine — Vérifier en simulation le défaut de rotation de phase et l'interdiction totale de fonctionnement | Contrat C2 racine, AC1-AC6, scope `L_SIMULATION`/`TEST_AUTO_CI`. | Contrat racine de T306 ; la phase 1 est un amendement. Aucune condition. | PASS |
| `TASK_CONTRACT_T308_PCT_FERMETURE_BENNE_REMONTEE.yaml` | T308 ⬜ — % de fermeture benne avant remontée — cadrage de la logique cycle (variables IHM déjà prêtes) | Contrat : « seuil minimal de % de fermeture … », PENDING. | Logique cycle, non implémentée. Condition : simulation ; ne pas confondre avec T309/T262. | PASS |
| `TASK_CONTRACT_T310_TREUILS_VITESSE_CABLE_PALIER.yaml` | T310 ⬜ — Treuils — condition de vitesse câble avant passage à un palier supérieur (en complément des temporisations fixes) | Contrat : « condition de vitesse câble … », PENDING. | Safety treuils, non implémenté. Condition : simulation avant essai. | PASS |
| `TASK_CONTRACT_T311_CYCLE_HOMING_BUG.yaml` | T311 ⬜ — Cycle homing — reproduire le défaut signalé, corriger la séquence, valider simulation puis machine | Contrat ; `PENDING` ; AC1-AC4 | Unique ; reproduction non faite. | PASS |
| `TASK_CONTRACT_T312_EXPORT_MESSAGES_OPERATEUR.yaml` | T312 ⬜ — Export CSV/Excel des messages opérateur, alarmes et indications — finaliser les textes | Contrat : « finaliser l’outil d’export … », PENDING. | Traçabilité IHM, non finalisé. Condition : validation des textes. | PASS |
| `TASK_CONTRACT_T313_GVL_TROUBLESHOOTING_CHRONOLOGIQUE.yaml` | T313 ⬜ — GVL Troubleshooting — refactor présentation chronologique pour diagnostic rapide en maintenance | Contrat C2, AC1-AC3, refactor présentation chronologique, `status: PENDING`. | Contrat actif. Aucune condition. | PASS |
| `TASK_CONTRACT_T316_SIMBENCH_FIDELITE_TREUILS.yaml` | T316 ⬜ — SimBench — Fidelite dynamique treuils M1/M2 (retour vitesse et frein temporises) pour tester la fenetre AX10_WAIT_ASCENT_START | Contrat ; `COMPLETED` phase 1 ; phase 2 ouverte | Preuve de simulation ; conserver. | PASS |
| `TASK_CONTRACT_T317_SIMBENCH_TREUIL_ELECTRIQUE.yaml` | T317 ⬜ — SimBench — Modèle électrotechnique treuils M1/M2 (moteur rotor bobiné, gradins résistance rotorique, chute tension groupe électrogène) | Contrat C3, AC1-AC3, scope P0 only, R0 non validé. | Contrat actif bloqué sur R0 ; ne pas supprimer. Condition : R0. | PASS |
| `TASK_CONTRACT_T318_SIMBENCH_PROFIL_SIMPLE.yaml` | T318 ⬜ — SimBench - profil simple treuils et injection explicite cable | Contrat ; `IN_PROGRESS` ; AC1-AC6 | Unique ; conserver. | PASS |
| `TASK_CONTRACT_T322_MISE_EN_SERVICE_RECALAGE.yaml` | T322 ⬜ — Mise en service - campagne de recalage terrain des hypotheses du modele treuils (M1/M2) | Contrat campagne mesure ; `PENDING` ; 8 AC | Mesures terrain uniques ; conserver. | PASS |
| `TASK_CONTRACT_T323_BENNE_NON_REFERENCEE_DIAGNOSTIC.yaml` | T323 ⬜ — Benne — supprimer les faux défauts avant référencement et rafraîchir l'état après homing | Contrat : « correctif implémenté et 5 tests T323 PASS ; validation CODESYS humaine restante ». | Preuves de correction, tâche non close. Condition : validation CODESYS. | PASS |
| `TASK_CONTRACT_T331_AX15B_REPLI_TREUILS.yaml` | T331 ⬜ — Cycle SEMI_AUTO — famille "retour arrière contrôlé" : remise en posture AX1 (départ) ET repli AX15b (vidage, treuils bloqués) | Contrat C3 du repli AX15b, AC1-AC11 ; livré/non testé machine, régression AX15b→AX10 hors GEL. | Trace de la déviation et base de T383 ; T331 ouverte. Condition : T383 instruit la correction. | PASS |
| `TASK_CONTRACT_T331_AX1_POSTURE_DIAGNOSTIC_REMISE.yaml` | T331 ⬜ — Cycle SEMI_AUTO — famille "retour arrière contrôlé" : remise en posture AX1 (départ) ET repli AX15b (vidage, treuils bloqués) | Contrat C3 AX1, AC1-AC7, phases P1-P4, aucune écriture. | Sous-partie ouverte de T331. Aucune condition. | PASS |
| `TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` | T334 ⬜ — Translation M3 : pourquoi deux chemins de commande (manuel/MAINT vs cycle auto) ? Chaînes complètes, comparatif, et dépassement P1/Trémie en cycle | Contrat C3, faits 1-7, Q1-Q6 arbitrés, `PLAN_PHASE3`, AC1-AC16, `status: IN_PROGRESS`. | Contrat actif ; porte les faits et les décisions. Aucune condition. | PASS |
| `TASK_CONTRACT_T338_SIM_ENCODER_FLOOR.yaml` | T338 ⬜ — Position M2 (encodeur) figee malgre vitesse non nulle et contacteurs actifs — recurrent, cause non etablie | Contrat C2 ; `status: COMPLETED` ; AC1-AC8 ; CR1 | Safety mesure ; recette humaine + CR2 hors lot ; conserver. | PASS |
| `TASK_CONTRACT_T339_BENNE_TESTS_DOC_REALIGN.yaml` | T339 ⬜ — Réalignement tests & doc benne : 9 tests CI obsolètes + fiche FB_Bucket_v1.0.md + purge de l'argument nommé mort MotionRequestActive | Contrat : « status: DELIVERED », « validation: PENDING ». | Preuves CI et décisions, tâche non close. Condition : visa humain. | PASS |
| `TASK_CONTRACT_T340_HOMING_LOCKED_ASCENT.yaml` | T340 ❌ — T336 Phase 3 — REFONTE du homing : reference provisoire a la fermeture benne + palier 1 constant global + vrai Homed uniquement au FDC mecanique haut | Contrat C1, AC1-AC8, 3 revues indépendantes, abandon motivé de la position provisoire. | Tâche close/remplacée n’annule pas la valeur de sécurité et de REX (garde keyée, capteur inactif). Condition : archivage éventuel sur décision humaine. | PASS |
| `TASK_CONTRACT_T341_CFGT330_NORMALIZER_FB.yaml` | T341 ⬜ — T330 suite — extraire FB_CfgT330Normalizer en vrai FB + ecrire les 37 cas ST TC-P10-056-092 | Contrat C2, AC1-AC11, extraction FB, 21 TC, item G508, `status: COMPLETED`, `validation: PENDING`. | Contrat actif ; preuves de non-vacuité par mutation. Condition : visa. | PASS |
| `TASK_CONTRACT_T342_SIM_REINJECTION_SILENCIEUSE.yaml` | T342 ⬜ — T338 CR2 — reinjection silencieuse RawPosM2=0 -> 1 100 000 pts dans FB_SimBench.st:273-280 (cause directe du saut post-AU) | Contrat : « reinjection SUPPRIMEE », « validation: PENDING », « AUCUN COMMIT ». | Preuve de correction et garde-fou. Condition : recette banc. | PASS |
| `TASK_CONTRACT_T346_BORNE_RECUL.yaml` | T346 ⬜ — Restaurer une borne de recul correcte sur FB_Bucket (frontiere PHYSIQUE, pas M2StartPosM), sans reproduire les coupures parasites du 2026-09-05 — LOT LIVRE, NON COMMITE | Contrat principal ; `status: COMPLETED`, `validation: PENDING` ; 13 AC ; D6 safety | Référencé `contrat:` ; garantie de non-régression ; conserver. | PASS |
| `TASK_CONTRACT_T347_DUREE_CYCLE_MIN_SEC.yaml` | T347 ⬜ — Remplacer TIME par minutes/secondes (INT) pour les durees cycle affichees IHM (CurrentCycleElapsed, LastCycleDuration) — LOT LIVRE, NON COMMITE | Contrat C2, AC1-AC9, `status: COMPLETED`, `validation: PENDING` ; suffixe `_Min` à ratifier. | Contrat actif ; visa du suffixe hors NC-030 à trancher. Condition : ratification humaine du suffixe. | PASS |
| `TASK_CONTRACT_T349_AX15A_AFFICHAGE_GESTE.yaml` | T349 ⬜ — AX15A : afficher le geste reellement exige (homme-mort + appui Y-) au lieu d une deflection generique | Contrat ; `status: PENDING` ; 9 AC ; affichage seul | Unique ; verrou T347 signalé. | PASS |
| `TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` | T351 ⬜ — Cartographie exhaustive joystick -> contacteur, MANU et AUTO, treuils M1/M2 ET translation M3 (besoin utilisateur recurrent) | Contrat C2 ; 12 AC ; livrable 786 l | Référencé `contrat:` ; lecture humaine restante. | PASS |
| `TASK_CONTRACT_T353_OUTIL_WEB_CARTOGRAPHIE.yaml` | T353 ⬜ — PHASE 2 T351 — outil web interactif : choisir un geste joystick et voir le chemin exact parcouru dans le code (PRG, FB, variables), chronologiquement | Contrat principal ; 12 AC ; `status: DELIVERED/IN_PROGRESS` ; réserves R3/R4 | Référencé `contrat:` ; revue humaine et réserves non soldées. | PASS |
| `TASK_CONTRACT_T354_ASYMETRIE_GARDE_M1_M2.yaml` | T354 ⬜ — Asymetrie de garde M1/M2 : NOT BucketBusy present au gate M1 et absent du gate M2 — M2 peut partir seul benne occupee | Contrat principal ; 14 AC ; `status: COMPLETED` (analyse) | Référencé `contrat:` ; verdict atteignable ; options non implémentées. | PASS |
| `TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE.yaml` | T358 ⬜ — Forçage de step du cycle semi-auto : saut immédiat à une valeur, sans aucune garde de contexte ni confirmation | Contrat principal ; `status: COMPLETED` ; G517 ; commit unique | Référencé `contrat:` ; validation PENDING ; conserver. | PASS |
| `TASK_CONTRACT_T359_AUTORESET_NOOP.yaml` | T359 ⬜ — Auto-acquittement borne : le pulse ResetTransient est un NO-OP demontre, et la voie « front Online » est demontree impossible | Contrat C3, AC1-AC11, `status: COMPLETED`, `execution: ALERT_RAISED`, `validation: PENDING` ; O1 implémenté. | Contrat actif ; le pulse reste no-op documenté. Condition : recette CODESYS + visa. | PASS |
| `TASK_CONTRACT_T367_ACQ_AUTO_BOOT_ET_REARM.yaml` | T367 ⬜ — Voir s il est possible de ne pas avoir de defaut au demarrage, pour ne pas etre oblige de faire de recette ou d acquittement de defauts et donc de fait de pouvoir reamer la machine sans blocage, ce qui est logique parce que la plupart du temps ce sont juste des faux positifs et des blocages inutiles | Contrat de l’ancien lot, `status: COMPLETED`, `validation: PENDING` ; T378. | T378 demande explicitement de marquer l’abandon de l’ancien lot T367 SANS suppression. Préserver le document et distinguer ancien lot annulé de la demande T367 courante ; marquage non exécuté dans cet audit. | PASS |
| `TASK_CONTRACT_T367_REARMEMENT_ACQUITTEMENT.yaml` | T367 ⬜ — Voir s il est possible de ne pas avoir de defaut au demarrage, pour ne pas etre oblige de faire de recette ou d acquittement de defauts et donc de fait de pouvoir reamer la machine sans blocage, ce qui est logique parce que la plupart du temps ce sont juste des faux positifs et des blocages inutiles | Contrat V2 rejeté (`validation.status: REJECTED`, réduction de périmètre), T378. | T378 demande explicitement de marquer l’abandon de l’ancien lot T367 SANS suppression. Préserver le document et distinguer ancien lot annulé de la demande T367 courante ; marquage non exécuté dans cet audit. | PASS |
| `TASK_CONTRACT_T368_TEMPS_ECOULE_BANDEAU_AX13.yaml` | T368 ⬜ — Afficher le temps ecoule (min/s) a cote du bandeau mode et dans le texte AX13 egouttage | Contrat et suivi : « status: COMPLETED », « validation: PENDING ». | Preuves et AC, non commité. Condition : visa orchestrateur et commit distinct. | PASS |
| `TASK_CONTRACT_T370_CARTOGRAPHIE_DISCORDANCES.yaml` | T370 ⬜ — Cartographie exhaustive des discordances contacteurs M1/M2 et choix de codage alarmes/messages | Contrat C4 ; `status: PENDING` ; table vérité, comparatif bits | Référencé `contrat:` ; analyse non code. | PASS |
| `TASK_CONTRACT_T370_STUCKOPEN.yaml` | T370 ⬜ — Cartographie exhaustive des discordances contacteurs M1/M2 et choix de codage alarmes/messages | Contrat C4 activation ; `status: PENDING` ; AC1-AC9 | Safety diagnostic-only ; conserver. | PASS |
| `TASK_CONTRACT_T371_FAUX_VERT_MOTIONCHECKLIST.yaml` | T371 ✅ — Faux vert du diagnostic mouvement (ST_MotionChecklist) - le technicien voit une barriere OK alors qu elle refuse | Contrat C4, AC1-AC15, scope, `validation.notes` (revue finale MINOR, réserves R1-R5). | Contrat de référence et garanties de non-régression (FB_WinchOutputInterlock intouché, G522). Le visa PENDING est à régulariser, pas un motif de suppression. Condition : visa final humain. | PASS |
| `TASK_CONTRACT_T372_REGISTRE_CI_AUTO_COHERENT.yaml` | T372 ⬜ — Harnais CI : entree registry incomplete (le test ne compile pas, personne ne le voit) + rapport .txt ecrit SEULEMENT en echec (artefact perime sur une entree qui passe) | Contrat principal ; `status: PENDING/BLOCKED` ; AC1-AC7 ; WINCH_INTEG FAIL | Référencé `contrat:` ; dette CI réelle. | PASS |
| `TASK_CONTRACT_T374_DSH_CONDITIONS_EXISTANTES.yaml` | T374 ⬜ — MAINT_N2 : restreindre la commande manuelle des treuils par boutons IHM a MAINT_N2 uniquement (inactive en MAINT_N1 + message op ; joystick inchange) | Contrat d’analyse : « Analyse DSH read-only avant toute proposition de nouvelle garde » ; statut PENDING. | Contrat PENDING, non remplacé par l’audit Phase A. Condition : ne pas exécuter sans GO. | PASS |
| `TASK_CONTRACT_T374_MAINT_N2_AUDIT.yaml` | T374 ⬜ — MAINT_N2 : restreindre la commande manuelle des treuils par boutons IHM a MAINT_N2 uniquement (inactive en MAINT_N1 + message op ; joystick inchange) | Contrat/audit Phase A : « status: VALIDATED », « Phase A read-only : six boutons moteur sans consommateur de conduite ». | Preuve d’audit et de clôture Phase A. Condition : conserver comme preuve. | PASS |
| `TASK_CONTRACT_T374_MAINT_N2_BOUTONS_CODE.yaml` | T374 ⬜ — MAINT_N2 : restreindre la commande manuelle des treuils par boutons IHM a MAINT_N2 uniquement (inactive en MAINT_N1 + message op ; joystick inchange) | Contrat Phase B : « C4-safety : plan technique a valider humainement avant toute ligne de CODE/ » ; BC1..BC9. | Contrat de code à venir, décisions D1..D5. Condition : GO humain explicite. | PASS |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml` | T375 ⬜ — Defauts et refus SILENCIEUX : 3 voies de blocage sans message operateur (sequencement benne couple, causes latchees masquees par un temoin de validite, SafeStop de demande) + garde-fou anti-silence | Contrat C3 amendé, AC1-AC11, 4 voies, `groupement` 2026-09-22. | Contrat actif ; porte l’extension T365 et les garde-fous G524. Aucune condition. | PASS |
| `TASK_CONTRACT_T377_HOMING_MANUEL_SANS_CONTACT_TOP.yaml` | T377 ⬜ — HOMING N1 MANUEL SANS CONTACT TOP : approche prudente sans heurter le capteur haut TOP, validation visuelle operateur et securisation contact | Contrat : « doctrine hybride à valider », « ARRET DE VALIDATION ». | Safety et doctrine non validée. Condition : validation exploitant avant code. | PASS |
| `TASK_CONTRACT_T386_ROTATION_PHASE_POWERCUTOFF.yaml` | T386 ⬜ — T306 phase 2 - CORRECTIFS SECURITE (1 seul lot C4) : bypass PhaseRotation NON GATE MAINT_N2 sur 3 axes + masquage par BypassProcess [BLOCK], puis SafeStop INERTE a la barriere finale M3 [MAJOR] | Contrat C4 sécurité, AC1-AC8 ; PREG1 en attente schéma, PREG2 arbitrée, phases P0-P4. | Contrat de sécurité actif ; PREG1 ne peut être levé par un agent. Condition : confirmation schéma électrique (humain). | PASS |
| `TASK_CONTRACT_T387_FENETRE_BENNE.yaml` | T387 ⬜ — FB_Safety_Winch : rendre la confirmation d'arret MecaB independante de la source de commande (JoystickYNeutral -> MovementCommanded) — faux ErrorID:09 en mode boutons MAINT_N2 | Contrat C4 ; `status: PENDING` ; 10 AC ; MecaB AC10 | Contrat safety autonome ; ne pas supprimer ; rattacher explicitement à T387. | PASS |
| `TASK_CONTRACT_T387_MECAB_SOURCE_COMMANDE.yaml` | T387 ⬜ — FB_Safety_Winch : rendre la confirmation d'arret MecaB independante de la source de commande (JoystickYNeutral -> MovementCommanded) — faux ErrorID:09 en mode boutons MAINT_N2 | Contrat C4 MecaB ; `status: PENDING` ; 7 AC | Safety ; référencé dans le lot ; conserver. | PASS |
| `TASK_CONTRACT_T397_CALIBRATION_RESET_PULSE_DIAG.yaml` | T397 ⬜ — Calibration et prolongation de la durée d impulsion ResetPulse dans FB_AutoResetTransientDiag | Contrat C2, AC1-AC5, ResetPulse 500 ms-1 s, `status: PENDING`. | Contrat actif. Aucune condition. | PASS |
| `TASK_CONTRACT_T399_TWINBENCH_HYBRID_ROADMAP.yaml` | T399 ⬜ — TwinBench hybride — feuille de route CODESYS, OpenModelica et application Windows | Contrat ; `status: COMPLETED` ; AC1-AC6 | Principal ; `validation: PENDING`. | PASS |
| `TASK_CONTRACT_T400_FICHE_MODELISATION_M3.yaml` | T400 ⬜ — Translation M3 — fiche récapitulative des données de modélisation | Contrat ; `status: COMPLETED` ; AC1-AC6 | Même réserve ; conserver la fiche et le contrat. | PASS |
| `TASK_CONTRACT_T401_POC_OPENMODELICA_M3_MINIMAL.yaml` | T401 ⬜ — POC rapide M3 — fichier OpenModelica autonome ouvrable et simulable dans OMEdit | Contrat C2, AC0-AC13, `READY_FOR_HUMAN_REVIEW`, recette OMEdit à faire. | Contrat actif. Condition : recette visuelle humaine. | PASS |
| `TASK_CONTRACT_T402_POC_COMMUNICATION_CODESYS_SIM_M3.yaml` | T402 ⬜ — POC aller-retour M3 avec le simulateur intégré CODESYS | Contrat : « validation: APPROVED », mais « recette CODESYS encore requise ». | Méthode et preuves, tâche non clôturée. Condition : ne pas lire APPROVED comme recette. | PASS |
| `TASK_CONTRACT_T403_AIGUILLAGE_M3_OPENMODELICA.yaml` | T403 ⬜ — Aiguillage M3 SimBench entre modele ST et interface OpenModelica | Contrat ; `status: COMPLETED` ; AC1-AC6 | Principal ; `validation: PENDING`. | PASS |
| `TASK_CONTRACT_T405_POC_M3_LIVE_FMU_QML.yaml` | T405 ⬜ — POC M3 live — joystick PySide6/QML et FMU OpenModelica à pas de 10 ms | Contrat : « validation: PENDING … recette humaine de l interface live requise ». | Preuves et AC, recette non faite. Condition : recette visuelle. | PASS |
| `TASK_CONTRACT_T406_TWINBENCH_CONTRAT_LIAISON.yaml` | T406 ⬜ — TwinBench M3 — contrat de signaux et surete de liaison PLC/plante | Contrat C3, AC1-AC5, `status: COMPLETED`, `validation: PENDING`. | Contrat actif. Condition : GO humain. | PASS |
| `TASK_CONTRACT_T408_POC_UDP_NATIF_CONTROL_WIN.yaml` | T408 ⬜ — POC UDP natif — mesure 10 ms dans la copie Control Win | Contrat POC : « status: IN_PROGRESS », « validation: PENDING ». | Contrat d’outillage/sécurité, recette non finie. Condition : ne pas clore sans stop/start. | PASS |
| `TASK_CONTRACT_T409_FMU_CONTROL_WIN_INJECTION.yaml` | T409 ⬜ — POC FMU M3 fonctionnel avec injection reversible dans SimBench Control Win | Contrat principal ; `status: IN_PROGRESS` ; AC1-AC12 | Référencé `contrat:` ; recette Control Win restante. | PASS |
| `TASK_CONTRACT_T415-B_M3_LIEN_EXTERNE_SIMBENCH.yaml` | T415-B ⬜ — TwinBench — frontiere PLC, SimBench et simulateur externe | Contrat C3 L1, AC1-AC7 ; communication validée (~96 trames/s), réserves AC5/AC6. | Contrat actif ; trace de la communication et des réserves. Aucune condition. | PASS |
| `TASK_CONTRACT_T415-G_TWINBENCH_V2.yaml` | T415-G ⬜ — TwinBench v2 — lancer la simulation (projet unique Device + Device_CtrlWinSim) | Contrat C3, lots G0-G8, AC1-AC12, matrice de recette, attente Q1-Q7. | Contrat actif de la refonte TwinBench. Condition : décisions G0. | PASS |
| `TASK_CONTRACT_T415_TWINBENCH_PLATFORM_SIMULATOR.yaml` | T415 ⬜ — TwinBench — plateforme generale de simulation industrielle | Contrat mère C3, AC1-AC4, enfants A-G, `status: IN_PROGRESS`. | Contrat chapeau ; référence de l’arbre T415. Aucune condition. | PASS |
| `TASK_CONTRACT_T417_SIMBENCH_M3_FIDELITE_ROUE_LIBRE.yaml` | T417 ⏳ — SimBench M3 - mecanique realiste et chaine automate-variateur-mouvement | Contrat antérieur ; `status: IN_PROGRESS` ; bloc T420 annulée B1-B6 | Remplacé pour le corps par T417_SIMULATION_M3_REALISTE mais réserve unique T420 ; conserver. | PASS |
| `TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml` | T417 ⏳ — SimBench M3 - mecanique realiste et chaine automate-variateur-mouvement | Contrat le plus récent ; `status: COMPLETED` ; investigation 20261031 AWAITING_D | Principal ; recette non faite ; conserver. | PASS |
| `TASK_CONTRACT_T421_FIDELITE_DYNAMIQUE_TREUILS.yaml` | T421 ✅ — SimBench - Refonte dynamique glissement treuils M1/M2 et benne basee sur traces reelles | Contrat ; `status: validated` ; AC1-AC7 ; `SimWinchCoast_M` supprimé | Validation selon le fichier (banc CODESYS) ; preuve unique ; conserver. | PASS |
| `TASK_CONTRACT_T423_IHM_PACK1_CORRECTIFS.yaml` | T423 ✅ — IHM Pack 1 - Démasquage alarmes EtherCAT/codeurs et alignement carrousel cycle §5 | Contrat : « status: COMPLETED », « 27/27 cas ». | Preuve de clôture et de non-régression, valeur propre. Condition : conserver. | PASS |
| `TASK_CONTRACT_T424_BANC_AFFICHAGE_VOLET1.yaml` | T424 ✅ — Contre-audit T423 - fiabiliser le banc d affichage et le bandeau (volet 1) | Contrat C2, AC1-AC5, `status: COMPLETED`, `validation: COMPLETED`, G507 PASS. | Tâche ✅ ; le contrat conserve les AC et le garde-fou anti-récidive. Aucune condition. | PASS |
| `TASK_CONTRACT_T425_CI_SOURCE_DEFAUTS.yaml` | T425 ⬜ — Volet 2 source des defauts - baseline et remise au vert de la CI FB securite | Contrat C2, AC1-AC6, baseline CI, `status: PENDING`, étape 1 soumise au GO. | Contrat actif. Condition : feu vert étape 1. | PASS |
| `TASK_CONTRACT_T426.yaml` | T426 ⏳ — Fiabiliser le pilotage des tâches, délégations et contrôles sans gêner l'usage normal | Contrat principal ; `status: IN_PROGRESS` ; 43 tests ; tracking | Référencé `contrat:` ; étude non activée. | PASS |
| `TASK_CONTRACT_T427_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.yaml` | T427 ⏳ — Refonte Workflow Agents — Router de skills mince, contrat étendu, sas d'essais et note compagnon MD | Contrat : « status: IN_PROGRESS », « execution_plan M1..M3 ». | Contrat de méthode et jalons. Condition : valider les jalons. | PASS |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.md` | T428 ⏳ — Refactor troubleshooting : snapshot lisible comme un flux, par axe, pour mainteneur et agent | Plan détaillé ; jalons J0-J6 ; 0 cause/15 | Unique ; seuils non atteints publiés. | Non applicable à ce contrôle |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.yaml` | T428 ⏳ — Refactor troubleshooting : snapshot lisible comme un flux, par axe, pour mainteneur et agent | Contrat chapeau ; `status: IN_PROGRESS` ; AC1-AC6 | Principal ; conserver. | PASS |
| `TASK_CONTRACT_TS_LOT1_VALEURS_TROMPEUSES.md` | T428 ⏳ — sous-lot TS (rattachement par le contenu) | Résumé lisible du lot 1, tableau des corrections, périmètre, preuves. | Livrable humain de T428/J1 ; le `.yaml` est le contrat structuré. Aucune condition. | Non applicable à ce contrôle |
| `TASK_CONTRACT_TS_LOT1_VALEURS_TROMPEUSES.yaml` | T428 ⏳ — sous-lot TS (rattachement par le contenu) | Contrat C2 structuré, AC1-AC10, `execution: COMPLETED` (commit 8ac56593), `validation: APPROVED` 2026-11-08. | J1 validé exploitant ; rejeu AC9 à faire, aucun test machine. Condition : rejeu à l’aveugle avant clôture J1. | PASS |
| `TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.md` | T428 ⏳ — sous-lot TS (rattachement par le contenu) | Lecture humaine : « J5 — Guide de dépannage dans CODESYS ». | Document compagnon lisible, distinct du contrat. Condition : conserver. | Non applicable à ce contrôle |
| `TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.yaml` | T428 ⏳ — sous-lot TS (rattachement par le contenu) | Contrat machine : « status: IN_PROGRESS », « G531 PASS ». | Preuves et AC de J5. Condition : import CODESYS et recette. | PASS |
| `TASK_NOTE_T427_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.md` | T427 ⏳ — Refonte Workflow Agents — Router de skills mince, contrat étendu, sas d'essais et note compagnon MD | Note compagnon : « Note Technique & Schémas — Tâche T427 », `companion_doc`. | Requise par le contrat, valeur de documentation. Condition : conserver liée au contrat. | Non applicable à ce contrôle |
| `TEST_DESIGN_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | T288 ⬜ — Cohérence commande/retour contacteurs par axe et couverture absence de mouvement | Design essais TD-01..TD-12 | Preuve unique ; conserver. | Non applicable à ce contrôle |
| `TESTPLAN_T346_BORNE_RECUL.md` | T346 ⬜ — Restaurer une borne de recul correcte sur FB_Bucket (frontiere PHYSIQUE, pas M2StartPosM), sans reproduire les coupures parasites du 2026-09-05 — LOT LIVRE, NON COMMITE | Dossier de test ; blocs ST, mutations, matrice 36 tests | Preuve de non-vacuité unique ; conserver. | Non applicable à ce contrôle |

## Vérifications et limites

- Couverture automatique : 190 chemins uniques / 190 attendus, aucune omission, aucun fichier d’origine modifié pendant l’analyse.
- Les quatre fichiers proposés au retrait existent dans HEAD. Récupération possible : `git show 9b70dc6c665f3b3013e5b01ca3b338c3ac72fe31:<chemin actuel complet>`.
- Les références entrantes sont des mentions lexicales dans les textes actifs suivis, hors archives et hors Device.export ; elles ne sont pas toutes des dépendances exécutables. Aucun Device.export lu.
- Les contrats continuent souvent à citer leur ancien emplacement DOC/WFLOW/CONTRACTS/ après le déplacement humain : la réparation des références est un lot d’application, pas réalisée ici.
- Aucun changement de TASKS.yaml, contrat, CODE/, bundle, gate, hook, commit ou push pour cet audit. Les nouveaux rapports sont hors du corpus initial de 190 fichiers.

## Avis bruts (attribués, la consolidation ci-dessus prévaut)

- [Lot 1](TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT1_20261110.md)
- [Lot 2](TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT2_20261110.md)
- [Lot 3](TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT3_20261110.md)
- [Challenge ciblé](TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_CHALLENGE_20261110.md)

## Application du renommage — 2026-11-10

Après validation utilisateur : 4 suppressions précédemment exécutées ; puis 192 fichiers présents conservés et renommés selon TACHE_TYPE_DESIGNATION, T majuscule. Les 192 empreintes avant/après étaient identiques avant adaptation des liens. 5 liens Markdown internes effectivement adaptés. Aucun identifiant interne de contrat ni statut de tâche modifié ; les collisions de rattachement restent à résoudre. Les trois sauvegardes .bak restent conservées et ignorées par Git. Aucun nouveau rapport créé pour le renommage.

Snapshot hors dépôt : `C:\Users\ZEDVIC~1\AppData\Local\Temp\contracts_rename_snapshot_7b92i7rb`.

| Ancien nom | Nom appliqué |
|---|---|
| `BRIEF_T224_ARMINGPERMIT_COHERENT_v2_TRANSMISSION.md` | `T224_BRIEF_ARMINGPERMIT_COHERENT_V2_TRANSMISSION.md` |
| `BRIEF_T262_SEUIL_FERMETURE_BENNE.md` | `T262_BRIEF_SEUIL_FERMETURE_BENNE.md` |
| `BRIEF_T306_ROTATION_PHASE_v1_TRANSMISSION.md` | `T306_BRIEF_ROTATION_PHASE_V1_TRANSMISSION.md` |
| `BRIEF_T347_DUREE_CYCLE_MIN_SEC.md` | `T347_BRIEF_DUREE_CYCLE_MIN_SEC.md` |
| `BRIEF_T351_CARTOGRAPHIE_JOYSTICK_TREUILS.md` | `T351_BRIEF_CARTOGRAPHIE_JOYSTICK_TREUILS.md` |
| `BRIEF_T353_OUTIL_WEB_CARTOGRAPHIE_INTERACTIVE.md` | `T353_BRIEF_OUTIL_WEB_CARTOGRAPHIE_INTERACTIVE.md` |
| `BRIEF_T354_ASYMETRIE_GARDE_M1_M2.md` | `T354_BRIEF_ASYMETRIE_GARDE_M1_M2.md` |
| `BRIEF_T358_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md` | `T358_BRIEF_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md` |
| `BRIEF_T367_DIAGNOSTIC_DEFAUTS_BOOT.md` | `T367_BRIEF_DIAGNOSTIC_DEFAUTS_BOOT.md` |
| `BRIEF_T370_C4_ACTIVATION_STUCKOPEN.md` | `T370_BRIEF_C4_ACTIVATION_STUCKOPEN.md` |
| `BRIEF_T370_DISCORDANCE_CONTACTEURS.md` | `T370_BRIEF_DISCORDANCE_CONTACTEURS.md` |
| `BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST_v2_TRANSMISSION.md` | `T371_BRIEF_FAUX_VERT_MOTIONCHECKLIST_V2_TRANSMISSION.md` |
| `BRIEF_T372_GENERATEUR_TEMPLATE_TRACE.md` | `T372_BRIEF_GENERATEUR_TEMPLATE_TRACE.md` |
| `BRIEF_T373_INREFERENCINGMODE_FENETRE_ETROITE.md` | `T373_BRIEF_INREFERENCINGMODE_FENETRE_ETROITE.md` |
| `BRIEF_T374_DSH_CONDITIONS_EXISTANTES.md` | `T374_BRIEF_DSH_CONDITIONS_EXISTANTES.md` |
| `BRIEF_T375_T365_MESSAGES_SILENCIEUX_v1.md` | `T375_BRIEF_T365_MESSAGES_SILENCIEUX_V1.md` |
| `BRIEF_T375_T365_MESSAGES_SILENCIEUX_v1.md.bak_v1` | `T375_BRIEF_T365_MESSAGES_SILENCIEUX_V1.md.bak_v1` |
| `BRIEF_T383_MICROSTEP_DECHARGE_v1.md` | `T383_BRIEF_MICROSTEP_DECHARGE_V1.md` |
| `CONTRACT_T409_ANIMATION_REVIEW.md` | `T409_CONTRAT_ANIMATION_REVIEW.md` |
| `CORRECTION_CONSIGNE_T387_SECURITE_v1.md` | `T387_CORRECTION_CONSIGNE_SECURITE_V1.md` |
| `DRAFT_T317_ARCHITECTURE_BLOCS_ST.md` | `T317_BROUILLON_ARCHITECTURE_BLOCS_ST.md` |
| `FICHE_T400_MODELISATION_TRANSLATION_M3.md` | `T400_FICHE_MODELISATION_TRANSLATION_M3.md` |
| `IHM_FREEZE_T262_EXTRACTION_START_OPENING_20260915.md` | `T262_IHM_FREEZE_EXTRACTION_START_OPENING_20260915.md` |
| `MESSAGE_AGENT_T387_BENNE_v1.md` | `T387_MESSAGE_AGENT_BENNE_V1.md` |
| `NOTE_APPLICATION_T358_FORCESTEP_SANS_GARDE.md` | `T358_NOTE_APPLICATION_FORCESTEP_SANS_GARDE.md` |
| `NOTE_APPLICATION_T367_ACQ_AUTO_BOOT_ET_REARM.md` | `T367_NOTE_APPLICATION_ACQ_AUTO_BOOT_ET_REARM.md` |
| `NOTE_APPLICATION_T371_FAUX_VERT_MOTIONCHECKLIST.md` | `T371_NOTE_APPLICATION_FAUX_VERT_MOTIONCHECKLIST.md` |
| `NOTE_APPLICATION_T387_FENETRE_BENNE.md` | `T387_NOTE_APPLICATION_FENETRE_BENNE.md` |
| `NOTE_APPLICATION_T408_POC_UDP_NATIF_CONTROL_WIN.md` | `T408_NOTE_APPLICATION_POC_UDP_NATIF_CONTROL_WIN.md` |
| `NOTE_APPLICATION_T409_FMU_CONTROL_WIN.md` | `T409_NOTE_APPLICATION_FMU_CONTROL_WIN.md` |
| `PLAN_T262_TRANSFERT_AX10_AX11_20260915.md` | `T262_PLAN_TRANSFERT_AX10_AX11_20260915.md` |
| `PLAN_T289_DECOMPTE_RESTANT_20260915.md` | `T289_PLAN_DECOMPTE_RESTANT_20260915.md` |
| `PLAN_T289_EGOUTTAGE_IHM_SECONDES_20260915.md` | `T289_PLAN_EGOUTTAGE_IHM_SECONDES_20260915.md` |
| `PLAN_T290_T291_LIMITES_TREUILS_20260915.md` | `T290_PLAN_T291_LIMITES_TREUILS_20260915.md` |
| `PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md` | `T317_PLAN_SIMBENCH_TREUIL_ELECTRIQUE.md` |
| `PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` | `T334_PLAN_PHASE3_AUTORITE_ARRET_AXE.md` |
| `PLAN_T346_BORNE_RECUL.md` | `T346_PLAN_BORNE_RECUL.md` |
| `PLAN_T399_TWINBENCH_HYBRID_PLC_OPENMODELICA.md` | `T399_PLAN_TWINBENCH_HYBRID_PLC_OPENMODELICA.md` |
| `PLAN_T406_TWINBENCH_CONTRAT_LIAISON.md` | `T406_PLAN_TWINBENCH_CONTRAT_LIAISON.md` |
| `PLAN_T408_POC_UDP_NATIF_CONTROL_WIN.md` | `T408_PLAN_POC_UDP_NATIF_CONTROL_WIN.md` |
| `PLAN_T409_FMU_CONTROL_WIN_INJECTION.md` | `T409_PLAN_FMU_CONTROL_WIN_INJECTION.md` |
| `PLAN_T417_SIMBENCH_M3_ROUE_LIBRE.md` | `T417_PLAN_SIMBENCH_M3_ROUE_LIBRE.md` |
| `PROCEDURE_CALIBRATION_ODOMETRIE_M3_T301.md` | `T301_PROCEDURE_CALIBRATION_ODOMETRIE_M3.md` |
| `PROCEDURE_TRACE_T224_ARMINGPERMIT_10MS.md` | `T224_PROCEDURE_TRACE_ARMINGPERMIT_10MS.md` |
| `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` | `T334_PROCEDURE_TRACE_M3_DEUX_CHEMINS.md` |
| `REFERENCE_T317_PROTOTYPE_PYTHON_FONCTIONS.md` | `T317_REFERENCE_PROTOTYPE_PYTHON_FONCTIONS.md` |
| `REGISTRE_ACTIONS_T262_AX10_STEP_CEILING_20260919.md` | `T262_REGISTRE_ACTIONS_AX10_STEP_CEILING_20260919.md` |
| `REGISTRE_ACTIONS_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | `T288_REGISTRE_ACTIONS_PHASE2_REGISTRE_ERREURS_20260915.md` |
| `REPONSE_T351_Q1_Q17.md` | `T351_REPONSE_Q1_Q17.md` |
| `T262_VALIDATION_CODESYS_20260919.md` | `T262_VALIDATION_CODESYS_20260919.md` |
| `T401_M3_POC_SIGNAL_CATALOG.yaml` | `T401_CATALOGUE_SIGNAUX_M3_POC.yaml` |
| `T409_CONTROLWIN_TEST_RECIPE.md` | `T409_PROCEDURE_TEST_CONTROL_WIN.md` |
| `T409_FINAL_AUDIT.md` | `T409_AUDIT_FINAL.md` |
| `T409_T413_M3_VISUALISATION.yaml` | `T409_CONTRAT_T413_VISUALISATION_M3.yaml` |
| `T415_M3_LAUNCHER_RESTART.yaml` | `T415_CONTRAT_RELANCE_LANCEUR_M3.yaml` |
| `T418_BUNDLE_GENERATION.txt` | `T418_PREUVE_BUNDLE_GENERATION.txt` |
| `T418_CI_BASELINE_METIER.txt` | `T418_PREUVE_CI_BASELINE_METIER.txt` |
| `T418_CI_SIMULATION.txt` | `T418_PREUVE_CI_SIMULATION.txt` |
| `T418_G200_LIAISON.txt` | `T418_PREUVE_G200_LIAISON.txt` |
| `T418_GATES_COMPLETS.txt` | `T418_PREUVE_GATES_COMPLETS.txt` |
| `TASK_CONTEXT_T262_AX10_STEP_CEILING.yaml` | `T262_CONTEXTE_AX10_STEP_CEILING.yaml` |
| `TASK_CONTRACT_T213.yaml` | `T213_CONTRAT_DIAGNOSTIC_HOMING_M2.yaml` |
| `TASK_CONTRACT_T217_LIAISON_SORTIES_VARIATEUR_M3.yaml` | `T217_CONTRAT_LIAISON_SORTIES_VARIATEUR_M3.yaml` |
| `TASK_CONTRACT_T218_BLOCAGE_MODE.yaml` | `T218_CONTRAT_BLOCAGE_MODE.yaml` |
| `TASK_CONTRACT_T219_HISTORIQUE_ALARMES.yaml` | `T219_CONTRAT_HISTORIQUE_ALARMES.yaml` |
| `TASK_CONTRACT_T220_ENRICHIR_BANDEAU.yaml` | `T220_CONTRAT_ENRICHIR_BANDEAU.yaml` |
| `TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` | `T224_CONTRAT_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` |
| `TASK_CONTRACT_T225_SYNCCONTACTOR_ESCALADE_PRG06.yaml` | `T225_CONTRAT_SYNCCONTACTOR_ESCALADE_PRG06.yaml` |
| `TASK_CONTRACT_T226_REFONTE_HOMING_SEMIAUTO.yaml` | `T226_CONTRAT_REFONTE_HOMING_SEMIAUTO.yaml` |
| `TASK_CONTRACT_T228_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml` | `T228_CONTRAT_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml` |
| `TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml` | `T229_CONTRAT_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml` |
| `TASK_CONTRACT_T230_KOBOLD_PROTECTION_THERMIQUE.yaml` | `T230_CONTRAT_KOBOLD_PROTECTION_THERMIQUE.yaml` |
| `TASK_CONTRACT_T235_REFONTE_TRANSACTION_PRESET.yaml` | `T235_CONTRAT_REFONTE_TRANSACTION_PRESET.yaml` |
| `TASK_CONTRACT_T253_CALIB_BENNE_PERSISTANTE.yaml` | `T253_CONTRAT_CALIB_BENNE_PERSISTANTE.yaml` |
| `TASK_CONTRACT_T255_DYN_USER_MESSAGES_IHM.yaml` | `T255_CONTRAT_DYN_USER_MESSAGES_IHM.yaml` |
| `TASK_CONTRACT_T258-A.yaml` | `T258-A_CONTRAT_PREUVE_CYCLE_FRONTIERES_PRG03_PRG04.yaml` |
| `TASK_CONTRACT_T258-B.yaml` | `T258-B_CONTRAT_PLONGEE_KOBOLD_AX4_AX8.yaml` |
| `TASK_CONTRACT_T258-C.yaml` | `T258-C_CONTRAT_PRETENSION_FERMETURE_REMONTEE_AX9_AX12.yaml` |
| `TASK_CONTRACT_T258-D.yaml` | `T258-D_CONTRAT_MODE_ESSAI_FORCAGE_ETAPE.yaml` |
| `TASK_CONTRACT_T258-E.yaml` | `T258-E_CONTRAT_QUALIFICATION_AF_BUNDLE_SAT.yaml` |
| `TASK_CONTRACT_T258.yaml` | `T258_CONTRAT_CYCLE_SEMIAUTO_SAT_J2.yaml` |
| `TASK_CONTRACT_T261.yaml` | `T261_CONTRAT_BYPASS_AUTOTEST_CANAL_POWER_KEEP_ALIVE.yaml` |
| `TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml` | `T262_CONTRAT_AX10_CLOSE_BUCKET_THRESHOLD.yaml` |
| `TASK_CONTRACT_T262_LOCAL_IHM_BLOCKS.yaml` | `T262_CONTRAT_LOCAL_IHM_BLOCKS.yaml` |
| `TASK_CONTRACT_T262_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml` | `T262_CONTRAT_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml` |
| `TASK_CONTRACT_T263_BUCKET_SYNC_HOLD_4S.yaml` | `T263_CONTRAT_BUCKET_SYNC_HOLD_4S.yaml` |
| `TASK_CONTRACT_T263_IHM_IOHW_READONLY.yaml` | `T263_CONTRAT_IHM_IOHW_READONLY.yaml` |
| `TASK_CONTRACT_T264_HOMING_BOOT_GUARD.yaml` | `T264_CONTRAT_HOMING_BOOT_GUARD.yaml` |
| `TASK_CONTRACT_T264_RETRAIT_BYPASS_POWER_CUTOFF_LIVRAISON.yaml` | `T264_CONTRAT_RETRAIT_BYPASS_POWER_CUTOFF_LIVRAISON.yaml` |
| `TASK_CONTRACT_T269_MECAD_BUCKET_TOP.yaml` | `T269_CONTRAT_MECAD_BUCKET_TOP.yaml` |
| `TASK_CONTRACT_T270_AX12_LOADED_ASCENT_P5.yaml` | `T270_CONTRAT_AX12_LOADED_ASCENT_P5.yaml` |
| `TASK_CONTRACT_T272_M3_DESCENT_STATE_GATE.yaml` | `T272_CONTRAT_M3_DESCENT_STATE_GATE.yaml` |
| `TASK_CONTRACT_T273_WINCH_MAINTENANCE_DESCENTE_FREIN_REMONTEE_P1.yaml` | `T273_CONTRAT_WINCH_MAINTENANCE_DESCENTE_FREIN_REMONTEE_P1.yaml` |
| `TASK_CONTRACT_T278_AU_ALARMS_FILTERING_AND_AUTO_RESET.yaml` | `T278_CONTRAT_AU_ALARMS_FILTERING_AND_AUTO_RESET.yaml` |
| `TASK_CONTRACT_T280_TROUBLESHOOTING_WORKSPACE.yaml` | `T280_CONTRAT_TROUBLESHOOTING_WORKSPACE.yaml` |
| `TASK_CONTRACT_T286_REFACTOR_CI_NON_REGRESSION_A_G.yaml` | `T286_CONTRAT_REFACTOR_CI_NON_REGRESSION_A_G.yaml` |
| `TASK_CONTRACT_T287_M3_BUTEES_ESCALADE_GRADUEE.yaml` | `T287_CONTRAT_M3_BUTEES_ESCALADE_GRADUEE.yaml` |
| `TASK_CONTRACT_T288_DISCORDANCE_CONTACTEURS_ABSENCE_MOUVEMENT.yaml` | `T288_CONTRAT_DISCORDANCE_CONTACTEURS_ABSENCE_MOUVEMENT.yaml` |
| `TASK_CONTRACT_T288_PHASE2_REGISTRE_ERREURS.yaml` | `T288_CONTRAT_PHASE2_REGISTRE_ERREURS.yaml` |
| `TASK_CONTRACT_T289_EGOUTTAGE_IHM_SECONDES.yaml` | `T289_CONTRAT_EGOUTTAGE_IHM_SECONDES.yaml` |
| `TASK_CONTRACT_T290_EXTRACTION_PALIER2_TEMPORISE.yaml` | `T290_CONTRAT_EXTRACTION_PALIER2_TEMPORISE.yaml` |
| `TASK_CONTRACT_T294_TASK_MANAGER_PERFORMANCE.yaml` | `T294_CONTRAT_TASK_MANAGER_PERFORMANCE.yaml` |
| `TASK_CONTRACT_T295_AX15B_BUCKET_OPEN_TIMEOUT.yaml` | `T295_CONTRAT_AX15B_BUCKET_OPEN_TIMEOUT.yaml` |
| `TASK_CONTRACT_T296_M3_FREQUENCES_PERSISTANTES.yaml` | `T296_CONTRAT_M3_FREQUENCES_PERSISTANTES.yaml` |
| `TASK_CONTRACT_T297_CYCLE_IHM_FORCE_AX7.yaml` | `T297_CONTRAT_CYCLE_IHM_FORCE_AX7.yaml` |
| `TASK_CONTRACT_T301_CALIBRATION_ODOMETRIE_M3.yaml` | `T301_CONTRAT_CALIBRATION_ODOMETRIE_M3.yaml` |
| `TASK_CONTRACT_T305_TREUILS_CONTRAINTES_ELECTROTHERMIQUES.yaml` | `T305_CONTRAT_TREUILS_CONTRAINTES_ELECTROTHERMIQUES.yaml` |
| `TASK_CONTRACT_T306_PHASE1_INJECTION_SIM.yaml` | `T306_CONTRAT_PHASE1_INJECTION_SIM.yaml` |
| `TASK_CONTRACT_T306_VERIFICATION_DEFAUT_ROTATION_PHASE.yaml` | `T306_CONTRAT_VERIFICATION_DEFAUT_ROTATION_PHASE.yaml` |
| `TASK_CONTRACT_T308_PCT_FERMETURE_BENNE_REMONTEE.yaml` | `T308_CONTRAT_PCT_FERMETURE_BENNE_REMONTEE.yaml` |
| `TASK_CONTRACT_T310_TREUILS_VITESSE_CABLE_PALIER.yaml` | `T310_CONTRAT_TREUILS_VITESSE_CABLE_PALIER.yaml` |
| `TASK_CONTRACT_T311_CYCLE_HOMING_BUG.yaml` | `T311_CONTRAT_CYCLE_HOMING_BUG.yaml` |
| `TASK_CONTRACT_T312_EXPORT_MESSAGES_OPERATEUR.yaml` | `T312_CONTRAT_EXPORT_MESSAGES_OPERATEUR.yaml` |
| `TASK_CONTRACT_T313_GVL_TROUBLESHOOTING_CHRONOLOGIQUE.yaml` | `T313_CONTRAT_GVL_TROUBLESHOOTING_CHRONOLOGIQUE.yaml` |
| `TASK_CONTRACT_T316_SIMBENCH_FIDELITE_TREUILS.yaml` | `T316_CONTRAT_SIMBENCH_FIDELITE_TREUILS.yaml` |
| `TASK_CONTRACT_T317_SIMBENCH_TREUIL_ELECTRIQUE.yaml` | `T317_CONTRAT_SIMBENCH_TREUIL_ELECTRIQUE.yaml` |
| `TASK_CONTRACT_T318_SIMBENCH_PROFIL_SIMPLE.yaml` | `T318_CONTRAT_SIMBENCH_PROFIL_SIMPLE.yaml` |
| `TASK_CONTRACT_T322_MISE_EN_SERVICE_RECALAGE.yaml` | `T322_CONTRAT_MISE_EN_SERVICE_RECALAGE.yaml` |
| `TASK_CONTRACT_T323_BENNE_NON_REFERENCEE_DIAGNOSTIC.yaml` | `T323_CONTRAT_BENNE_NON_REFERENCEE_DIAGNOSTIC.yaml` |
| `TASK_CONTRACT_T325_D18_NEUTRE_ANALYSE_RISQUE.yaml` | `T325_CONTRAT_D18_NEUTRE_ANALYSE_RISQUE.yaml` |
| `TASK_CONTRACT_T327_MANUAL_BUCKET_LIMITS_PHASE_JOG.yaml` | `T327_CONTRAT_MANUAL_BUCKET_LIMITS_PHASE_JOG.yaml` |
| `TASK_CONTRACT_T331_AX15B_REPLI_TREUILS.yaml` | `T331_CONTRAT_AX15B_REPLI_TREUILS.yaml` |
| `TASK_CONTRACT_T331_AX1_POSTURE_DIAGNOSTIC_REMISE.yaml` | `T331_CONTRAT_AX1_POSTURE_DIAGNOSTIC_REMISE.yaml` |
| `TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` | `T334_CONTRAT_AUTO_CYCLE_M3_OVERSHOOT.yaml` |
| `TASK_CONTRACT_T338_SIM_ENCODER_FLOOR.yaml` | `T338_CONTRAT_SIM_ENCODER_FLOOR.yaml` |
| `TASK_CONTRACT_T339_BENNE_TESTS_DOC_REALIGN.yaml` | `T339_CONTRAT_BENNE_TESTS_DOC_REALIGN.yaml` |
| `TASK_CONTRACT_T340_HOMING_LOCKED_ASCENT.yaml` | `T340_CONTRAT_HOMING_LOCKED_ASCENT.yaml` |
| `TASK_CONTRACT_T341_CFGT330_NORMALIZER_FB.yaml` | `T341_CONTRAT_CFGT330_NORMALIZER_FB.yaml` |
| `TASK_CONTRACT_T342_SIM_REINJECTION_SILENCIEUSE.yaml` | `T342_CONTRAT_SIM_REINJECTION_SILENCIEUSE.yaml` |
| `TASK_CONTRACT_T346_BORNE_RECUL.yaml` | `T346_CONTRAT_BORNE_RECUL.yaml` |
| `TASK_CONTRACT_T347_DUREE_CYCLE_MIN_SEC.yaml` | `T347_CONTRAT_DUREE_CYCLE_MIN_SEC.yaml` |
| `TASK_CONTRACT_T349_AX15A_AFFICHAGE_GESTE.yaml` | `T349_CONTRAT_AX15A_AFFICHAGE_GESTE.yaml` |
| `TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` | `T351_CONTRAT_CARTOGRAPHIE_TREUILS.yaml` |
| `TASK_CONTRACT_T353_OUTIL_WEB_CARTOGRAPHIE.yaml` | `T353_CONTRAT_OUTIL_WEB_CARTOGRAPHIE.yaml` |
| `TASK_CONTRACT_T354_ASYMETRIE_GARDE_M1_M2.yaml` | `T354_CONTRAT_ASYMETRIE_GARDE_M1_M2.yaml` |
| `TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE.yaml` | `T358_CONTRAT_FORCESTEP_SANS_GARDE.yaml` |
| `TASK_CONTRACT_T359_AUTORESET_NOOP.yaml` | `T359_CONTRAT_AUTORESET_NOOP.yaml` |
| `TASK_CONTRACT_T367_ACQ_AUTO_BOOT_ET_REARM.yaml` | `T367_CONTRAT_ACQ_AUTO_BOOT_ET_REARM.yaml` |
| `TASK_CONTRACT_T367_REARMEMENT_ACQUITTEMENT.yaml` | `T367_CONTRAT_REARMEMENT_ACQUITTEMENT.yaml` |
| `TASK_CONTRACT_T368_TEMPS_ECOULE_BANDEAU_AX13.yaml` | `T368_CONTRAT_TEMPS_ECOULE_BANDEAU_AX13.yaml` |
| `TASK_CONTRACT_T370_CARTOGRAPHIE_DISCORDANCES.yaml` | `T370_CONTRAT_CARTOGRAPHIE_DISCORDANCES.yaml` |
| `TASK_CONTRACT_T370_STUCKOPEN.yaml` | `T370_CONTRAT_STUCKOPEN.yaml` |
| `TASK_CONTRACT_T371_FAUX_VERT_MOTIONCHECKLIST.yaml` | `T371_CONTRAT_FAUX_VERT_MOTIONCHECKLIST.yaml` |
| `TASK_CONTRACT_T372_REGISTRE_CI_AUTO_COHERENT.yaml` | `T372_CONTRAT_REGISTRE_CI_AUTO_COHERENT.yaml` |
| `TASK_CONTRACT_T374_DSH_CONDITIONS_EXISTANTES.yaml` | `T374_CONTRAT_DSH_CONDITIONS_EXISTANTES.yaml` |
| `TASK_CONTRACT_T374_MAINT_N2_AUDIT.yaml` | `T374_CONTRAT_MAINT_N2_AUDIT.yaml` |
| `TASK_CONTRACT_T374_MAINT_N2_BOUTONS_CODE.yaml` | `T374_CONTRAT_MAINT_N2_BOUTONS_CODE.yaml` |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml` | `T375_CONTRAT_MESSAGES_BLOCAGES_SILENCIEUX.yaml` |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_renum` | `T375_CONTRAT_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_renum` |
| `TASK_CONTRACT_T375_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_v1` | `T375_CONTRAT_MESSAGES_BLOCAGES_SILENCIEUX.yaml.bak_v1` |
| `TASK_CONTRACT_T375_MOT7_RESET_AC600.yaml` | `T375_CONTRAT_MOT7_RESET_AC600.yaml` |
| `TASK_CONTRACT_T377_HOMING_MANUEL_SANS_CONTACT_TOP.yaml` | `T377_CONTRAT_HOMING_MANUEL_SANS_CONTACT_TOP.yaml` |
| `TASK_CONTRACT_T386_ROTATION_PHASE_POWERCUTOFF.yaml` | `T386_CONTRAT_ROTATION_PHASE_POWERCUTOFF.yaml` |
| `TASK_CONTRACT_T387_FENETRE_BENNE.yaml` | `T387_CONTRAT_FENETRE_BENNE.yaml` |
| `TASK_CONTRACT_T387_MECAB_SOURCE_COMMANDE.yaml` | `T387_CONTRAT_MECAB_SOURCE_COMMANDE.yaml` |
| `TASK_CONTRACT_T391_M3_ANYFAULT.yaml` | `T391_CONTRAT_M3_ANYFAULT.yaml` |
| `TASK_CONTRACT_T397_CALIBRATION_RESET_PULSE_DIAG.yaml` | `T397_CONTRAT_CALIBRATION_RESET_PULSE_DIAG.yaml` |
| `TASK_CONTRACT_T399_TWINBENCH_HYBRID_ROADMAP.yaml` | `T399_CONTRAT_TWINBENCH_HYBRID_ROADMAP.yaml` |
| `TASK_CONTRACT_T400_FICHE_MODELISATION_M3.yaml` | `T400_CONTRAT_FICHE_MODELISATION_M3.yaml` |
| `TASK_CONTRACT_T401_POC_OPENMODELICA_M3_MINIMAL.yaml` | `T401_CONTRAT_POC_OPENMODELICA_M3_MINIMAL.yaml` |
| `TASK_CONTRACT_T402_POC_COMMUNICATION_CODESYS_SIM_M3.yaml` | `T402_CONTRAT_POC_COMMUNICATION_CODESYS_SIM_M3.yaml` |
| `TASK_CONTRACT_T403_AIGUILLAGE_M3_OPENMODELICA.yaml` | `T403_CONTRAT_AIGUILLAGE_M3_OPENMODELICA.yaml` |
| `TASK_CONTRACT_T405_POC_M3_LIVE_FMU_QML.yaml` | `T405_CONTRAT_POC_M3_LIVE_FMU_QML.yaml` |
| `TASK_CONTRACT_T406_TWINBENCH_CONTRAT_LIAISON.yaml` | `T406_CONTRAT_TWINBENCH_CONTRAT_LIAISON.yaml` |
| `TASK_CONTRACT_T408_POC_UDP_NATIF_CONTROL_WIN.yaml` | `T408_CONTRAT_POC_UDP_NATIF_CONTROL_WIN.yaml` |
| `TASK_CONTRACT_T409_FMU_CONTROL_WIN_INJECTION.yaml` | `T409_CONTRAT_FMU_CONTROL_WIN_INJECTION.yaml` |
| `TASK_CONTRACT_T415-B_M3_LIEN_EXTERNE_SIMBENCH.yaml` | `T415-B_CONTRAT_M3_LIEN_EXTERNE_SIMBENCH.yaml` |
| `TASK_CONTRACT_T415-G_TWINBENCH_V2.yaml` | `T415-G_CONTRAT_TWINBENCH_V2.yaml` |
| `TASK_CONTRACT_T415_TWINBENCH_PLATFORM_SIMULATOR.yaml` | `T415_CONTRAT_TWINBENCH_PLATFORM_SIMULATOR.yaml` |
| `TASK_CONTRACT_T417_SIMBENCH_M3_FIDELITE_ROUE_LIBRE.yaml` | `T417_CONTRAT_SIMBENCH_M3_FIDELITE_ROUE_LIBRE.yaml` |
| `TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml` | `T417_CONTRAT_SIMULATION_M3_REALISTE.yaml` |
| `TASK_CONTRACT_T421_FIDELITE_DYNAMIQUE_TREUILS.yaml` | `T421_CONTRAT_FIDELITE_DYNAMIQUE_TREUILS.yaml` |
| `TASK_CONTRACT_T423_IHM_PACK1_CORRECTIFS.yaml` | `T423_CONTRAT_IHM_PACK1_CORRECTIFS.yaml` |
| `TASK_CONTRACT_T424_BANC_AFFICHAGE_VOLET1.yaml` | `T424_CONTRAT_BANC_AFFICHAGE_VOLET1.yaml` |
| `TASK_CONTRACT_T425_CI_SOURCE_DEFAUTS.yaml` | `T425_CONTRAT_CI_SOURCE_DEFAUTS.yaml` |
| `TASK_CONTRACT_T426.yaml` | `T426_CONTRAT_PILOTAGE_TACHES_INVESTIGATIONS.yaml` |
| `TASK_CONTRACT_T427_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.yaml` | `T427_CONTRAT_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.yaml` |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.md` | `T428_CONTRAT_REFACTOR_TROUBLESHOOTING.md` |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.yaml` | `T428_CONTRAT_REFACTOR_TROUBLESHOOTING.yaml` |
| `TASK_CONTRACT_TS_LOT1_VALEURS_TROMPEUSES.md` | `T428_CONTRAT_LOT1_VALEURS_TROMPEUSES.md` |
| `TASK_CONTRACT_TS_LOT1_VALEURS_TROMPEUSES.yaml` | `T428_CONTRAT_LOT1_VALEURS_TROMPEUSES.yaml` |
| `TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.md` | `T428_CONTRAT_LOT5_GUIDE_DEPANNAGE.md` |
| `TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.yaml` | `T428_CONTRAT_LOT5_GUIDE_DEPANNAGE.yaml` |
| `TASK_NOTE_T427_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.md` | `T427_NOTE_WORKFLOW_SKILL_ET_CONTRAT_ETENDU.md` |
| `TEST_DESIGN_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | `T288_TEST_DESIGN_PHASE2_REGISTRE_ERREURS_20260915.md` |
| `TESTPLAN_T346_BORNE_RECUL.md` | `T346_PLAN_TEST_BORNE_RECUL.md` |
| `TXXX_CONTROLE_STRUCTURE_CONTRACTS_20261110.json` | `TXXX_CONTROLE_STRUCTURE_CONTRACTS_20261110.json` |
| `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_CHALLENGE_20261110.md` | `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_CHALLENGE_20261110.md` |
| `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT1_20261110.md` | `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT1_20261110.md` |
| `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT2_20261110.md` | `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT2_20261110.md` |
| `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT3_20261110.md` | `TXXX_REVUE_CONTRACTS_DEEPSEEK_V4_1_LOT3_20261110.md` |
| `TXXX_TRIAGE_CONTRACTS_VS_TASKS_20261110.md` | `TXXX_TRIAGE_CONTRACTS_VS_TASKS_20261110.md` |

## Suite validée — REVIEWS et TESTS, 2026-11-10

Trois agents DeepSeek v4.1 ont analysé les 34 fichiers REVIEWS, les 11 fichiers TESTS et challengé les suppressions/attributions. Résultat consolidé : **45 fichiers conservés, zéro suppression supplémentaire**. Renommages appliqués, T majuscule et tâche en premier, à plat dans chaque dossier. Aucun nouveau rapport ajouté dans REVIEWS/TESTS : synthèse conservée ici.

Arbitrages indépendants :
- La campagne 20260922 cite son ancien emplacement DOC/WFLOW/TESTS, désormais absent : l’avis de suppression pour doublon probable est rejeté.
- Les captures du 20261102 et les mesures synthétiques ne sont pas requalifiées en recette T429 actuelle. Sans rattachement formel prouvé, TXXX est conservé.
- Les identifiants historiques T165/T199/T206 explicitement écrits sont conservés même s’ils ne figurent plus dans le catalogue courant. T291B est normalisé T291-B conformément au corps du document.
- Les noms proposés par les agents ajoutaient des V1 et des dates non présentes dans les noms initiaux : ces ajouts ne sont pas retenus. Les dates/versions existantes sont conservées.
- Les prompts restent conservés : ils portent les mandats et contextes, sans remplacement complet démontré par les revues. Les revues et plans d’essai conservent leurs réserves datées, pas une preuve du code courant.

| Dossier | Ancien nom | Nom appliqué | Décision et motif |
|---|---|---|---|
| REVIEWS | `AGENT_CAPTURE_AGY_20261102.json` | `TXXX_PREUVE_CAPTURE_AGY_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_CLAUDE_20261102.json` | `TXXX_PREUVE_CAPTURE_CLAUDE_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_CLAUDE_AUTH_20261102.json` | `TXXX_PREUVE_CAPTURE_CLAUDE_AUTH_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_CODEX_20261102.json` | `TXXX_PREUVE_CAPTURE_CODEX_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_LIVE_AGY_20261102.json` | `TXXX_PREUVE_CAPTURE_LIVE_AGY_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_LIVE_CLAUDE_20261102.json` | `TXXX_PREUVE_CAPTURE_LIVE_CLAUDE_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_LIVE_CODEX_20261102.json` | `TXXX_PREUVE_CAPTURE_LIVE_CODEX_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_SOURCE_ASSOCIATIONS_20261102.json` | `TXXX_PREUVE_CAPTURE_SOURCE_ASSOCIATIONS_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_TUI_AGY_20261102.json` | `TXXX_PREUVE_CAPTURE_TUI_AGY_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_TUI_CLAUDE_20261102.json` | `TXXX_PREUVE_CAPTURE_TUI_CLAUDE_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_TUI_CODEX_20261102.json` | `TXXX_PREUVE_CAPTURE_TUI_CODEX_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_CAPTURE_VALIDATION_20261102.json` | `TXXX_PREUVE_CAPTURE_VALIDATION_20261102.json` | GARDER : Capture historique du POC ; succès, échecs et limites distincts. TXXX : pas de rattachement formel prouvé, pas une recette T429 actuelle. |
| REVIEWS | `AGENT_SUPERVISION_DEEPSEEK_V41_SMOKE_20261102.json` | `TXXX_PREUVE_SUPERVISION_DEEPSEEK_V41_SMOKE_20261102.json` | GARDER : Mesure datée du juge/service, parfois synthétique ; conserver ses limites, sans la qualifier de preuve machine ou de recette T429 actuelle. |
| REVIEWS | `AGENT_SUPERVISION_OLLAMA_SMOKE_20261102.json` | `TXXX_PREUVE_SUPERVISION_OLLAMA_SMOKE_20261102.json` | GARDER : Mesure datée du juge/service, parfois synthétique ; conserver ses limites, sans la qualifier de preuve machine ou de recette T429 actuelle. |
| REVIEWS | `AGENT_SUPERVISION_OLLAMA_WARM_20261102.json` | `TXXX_PREUVE_SUPERVISION_OLLAMA_WARM_20261102.json` | GARDER : Mesure datée du juge/service, parfois synthétique ; conserver ses limites, sans la qualifier de preuve machine ou de recette T429 actuelle. |
| REVIEWS | `AGENT_SUPERVISION_SERVICE_FINAL_SMOKE_20261102.json` | `TXXX_PREUVE_SUPERVISION_SERVICE_FINAL_SMOKE_20261102.json` | GARDER : Mesure datée du juge/service, parfois synthétique ; conserver ses limites, sans la qualifier de preuve machine ou de recette T429 actuelle. |
| REVIEWS | `AGENT_SUPERVISION_SERVICE_REAL_JUDGE_20261102.json` | `TXXX_PREUVE_SUPERVISION_SERVICE_REAL_JUDGE_20261102.json` | GARDER : Mesure datée du juge/service, parfois synthétique ; conserver ses limites, sans la qualifier de preuve machine ou de recette T429 actuelle. |
| REVIEWS | `PROMPT_AUDIT_REVIEW_SESSION.md` | `T429_PROMPT_AUDIT_REVIEW_SESSION.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_CHALLENGE_AGENT_A_CONTRAT_C1.md` | `TXXX_PROMPT_CHALLENGE_AGENT_A_CONTRAT_C1.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1.md` | `TXXX_PROMPT_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_CHALLENGE_ISOLATION_PERIMETRES_COLLABORATIFS.md` | `TXXX_PROMPT_CHALLENGE_ISOLATION_PERIMETRES_COLLABORATIFS.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md` | `T429_PROMPT_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_CHALLENGE_SUPERVISOR_PROMPTS_ET_DRIFT.md` | `T429_PROMPT_CHALLENGE_SUPERVISOR_PROMPTS_ET_DRIFT.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_REVIEW_AGENT_B_CONTRAT_C1.md` | `TXXX_PROMPT_REVIEW_AGENT_B_CONTRAT_C1.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `PROMPT_REVIEW_B_AVEC_PREUVES.md` | `T429_PROMPT_REVIEW_B_AVEC_PREUVES.md` | GARDER : Mandat et contexte d’une revue, contenu non intégralement repris dans le résultat. Conserver sans supposer qu’un prompt consommé est inutile. |
| REVIEWS | `REVIEW_AGENT_SESSION_SUPERVISION_T417_20261102.md` | `T417_REVUE_AGENT_SESSION_SUPERVISION_20261102.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_ARBITRAGE_AGENT_B_CONTRAT_C1.md` | `TXXX_REVUE_ARBITRAGE_AGENT_B_CONTRAT_C1.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_CHALLENGE_AGENT_A_CONTRAT_C1.md` | `TXXX_REVUE_CHALLENGE_AGENT_A_CONTRAT_C1.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1.md` | `TXXX_REVUE_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_CHALLENGE_ISOLATION_PERIMETRES.md` | `TXXX_REVUE_CHALLENGE_ISOLATION_PERIMETRES.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md` | `T429_REVUE_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_SUPERVISOR_PROMPTS_ET_DRIFT.md` | `T429_REVUE_SUPERVISOR_PROMPTS_ET_DRIFT.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | `T288_REVUE_PHASE2_REGISTRE_ERREURS_20260915.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| REVIEWS | `REVIEW_T291B_GIT_HISTORY_AX12_20260915.md` | `T291-B_REVUE_HISTORIQUE_GIT_AX12_20260915.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `BILAN_TC_COVERAGE_v1.0.md` | `TXXX_BILAN_TC_COVERAGE_V1_0.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `CAMPAGNE_20260922_CYCLE_SANS_BLOCAGE.md` | `TXXX_CAMPAGNE_CYCLE_SANS_BLOCAGE_20260922.md` | GARDER : Campagne multi-tâches T295/T331/T345 ; ancien chemin canonique absent après déplacement, donc aucun doublon prouvé. Garder sous TXXX plutôt que choisir arbitrairement une tâche. |
| TESTS | `GUIDE_TEST_RAPIDE_20260922.md` | `TXXX_GUIDE_TEST_RAPIDE_20260922.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `PLAN_TEST_T306_ROTATION_PHASE_SIM.md` | `T306_PLAN_TEST_ROTATION_PHASE_SIM.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `PLAN_TEST_T383_AX15D_MODULE_BENNE_SIM.md` | `T383_PLAN_TEST_AX15D_MODULE_BENNE_SIM.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `TEST_DESIGN_LOT_C4_AU_TROUBLESHOOTING.md` | `TXXX_DESIGN_TEST_LOT_C4_AU_TROUBLESHOOTING.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `TEST_DESIGN_T165_FLUX_PRG02_PRG03.md` | `T165_DESIGN_TEST_FLUX_PRG02_PRG03.md` | GARDER : Identifiant historique explicitement écrit dans le nom/titre conservé ; son absence du catalogue actuel ne justifie ni retrait ni remplacement par TXXX. |
| TESTS | `TEST_DESIGN_T199_CASE_AU.md` | `T199_DESIGN_TEST_CASE_AU.md` | GARDER : Identifiant historique explicitement écrit dans le nom/titre conservé ; son absence du catalogue actuel ne justifie ni retrait ni remplacement par TXXX. |
| TESTS | `TEST_DESIGN_T206_STARTUPFAIL_LOCKOUT.md` | `T206_DESIGN_TEST_STARTUPFAIL_LOCKOUT.md` | GARDER : Identifiant historique explicitement écrit dans le nom/titre conservé ; son absence du catalogue actuel ne justifie ni retrait ni remplacement par TXXX. |
| TESTS | `TEST_DESIGN_T262_AX10_STEP_CEILING.md` | `T262_DESIGN_TEST_AX10_STEP_CEILING.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |
| TESTS | `TEST_DESIGN_T318_SIMBENCH_PROFIL_SIMPLE.md` | `T318_DESIGN_TEST_SIMBENCH_PROFIL_SIMPLE.md` | GARDER : Conserver les résultats/restrictions ou scénarios propres ; aucun remplacement complet démontré. |

Contrôles : empreintes des 45 fichiers identiques avant/après renommage avant réparation des liens ; 0 lien supplémentaire modifié (4 liens déjà à jour vérifiés) ; zéro collision dans chaque dossier. Snapshot : `C:\Users\ZEDVIC~1\AppData\Local\Temp\reviews_tests_rename_snapshot_43sz_gu6`. Les autres références historiques dans le texte, les contrats et les consommateurs externes ne sont pas toutes réparées ; aucun CODE/, gate, hook ou catalogue modifié dans ce lot.
