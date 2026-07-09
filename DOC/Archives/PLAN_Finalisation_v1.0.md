# 📋 Plan de Finalisation du Projet (v1.0)

> **Objectif** : recenser tout ce qu'il reste à faire (code, doc, supervision) pour finaliser
> l'excavatrice de dragage, avec priorisation. Document de pilotage — pas une spec fonctionnelle
> (celles-ci restent dans la série `AF_PartieN`).
> **Portée** : constats établis par lecture croisée de `CODE/` (source de vérité) et `DOC/`
> (toutes dernières versions au 2026-07-04). Rien n'a été modifié dans `CODE/` pour produire ce plan.

---

## 🔴 1. Bloquants (empêchent la compilation)

| # | Fichier:ligne | Constat | Correctif suggéré |
|---|---|---|---|
| 1.1 | `CODE/CYCLE/PRG_5_Cycle.st:27`, `CODE/CONTROL/PRG_6_WinchControl.st:40,56`, `CODE/CONTROL/PRG_7_ChariotControl.st:25` | Testent `E_Mode.AUTO`, absent de `CODE/MODES/E_Mode.st` (seul `DISABLE/MAINT_N1/MAINT_N2/SEMI_AUTO`). Ne compile pas. | Aucun mode `AUTO` distinct n'existe nulle part dans la doc (Partie4/5 ne parlent que de `SEMI_AUTO`) → supprimer `OR ... = E_Mode.AUTO` dans les 4 occurrences, garder `SEMI_AUTO` seul. À confirmer avec l'utilisateur avant correction (pas fait dans ce document). |

---

## 🟠 2. Écarts fonctionnels vs spec validée

| # | Sujet | Constat |
|---|---|---|
| 2.A | Homme-mort joystick absent en semi-auto | `AF_Partie-04_Cycle_Sequenceur_v1.2.md` §0 exige un mouvement toujours conditionné à la tenue joystick, vitesse bornée par le plafond d'étape. `CODE/CYCLE/FB_Cycle.st` sort des `SpeedPct` fixes (50/20/70) sans lire de joystick ; `CODE/CONTROL/PRG_6_WinchControl.st:40-48,56-64` n'applique le homme-mort qu'en mode manuel (`ELSE`), jamais en SEMI_AUTO/AUTO. |
| 2.B | `ERROR_HOLD` ne reflète jamais un vrai `SafeStop` métier | `FB_Cycle` (`CODE/CYCLE/FB_Cycle.st`) n'a **aucune** entrée `SafeStop` (M1/M2/M3) ; confond Pause opérateur et défaut sécurité dans le même état `ERROR_HOLD` (l.130-137) ; `ResetEdge` (R_TRIG, l.75) est calculé mais **jamais utilisé** pour sortir d'un défaut. Contredit `AF_Partie-04_Cycle_Sequenceur_v1.2.md` §1 ("à tout instant, SafeStop → ERROR_HOLD… sortie par reset + nouvel ordre explicite"). |
| 2.C 🆕 | `PRG_8_AuxiliaryControl` entièrement stub, non raccordé | `CODE/CONTROL/PRG_8_AuxiliaryControl.st` force en dur `HydraulicPumpRunCmd/SifterRunCmd/GridOpenCmd/HelmetCloseCmd := FALSE` (l.26-29) et les `*FaultOk := TRUE` (l.31-32) — aucune logique réelle. **Et** `CODE/IO/PRG_10_Outputs.st` ne câble ces 4 commandes vers **aucune** sortie physique (`FB_Output`) : le programme existe mais n'a aucun effet, ni entrée, ni sortie physique. Fonction crible/hydraulique/grille/casque entièrement absente de la chaîne. |
| 2.D 🆕 | Aucune remontée IHM pour l'auxiliaire | `CODE/SUPERVISION/PRG_9_Supervision.st` mappe Winch M1/M2/Grappin/Sync/Chariot/Joystick/Modes/Network vers `GVL_IHM` — **rien** pour l'auxiliaire (pas de `GVL_IHM.Auxiliary`, pas de struct `ST_AuxiliaryHMI` dans `AF_Partie-07`). Cohérent avec 2.C : la fonction n'existe nulle part de bout en bout. |

---

## 🟡 3. Dette technique / vestiges à nettoyer

| # | Fichier | Constat |
|---|---|---|
| 3.1 | `CODE/SYSTEM/GVL_BUS.st` | Vide, marqué obsolète en en-tête, non référencé nulle part → à supprimer. |
| 3.2 | `CODE/SYSTEM/GVL_Machine_Stub.st` | `MachineReset_IHM` orphelin, dupliqué avec `PRG_9_Supervision.MachineReset_IHM` (source réelle) → à supprimer. |
| 3.3 | `CODE/SYSTEM/PRG_IP.st` | Stub non référencé par aucun autre `.st` — statut dans la liste d'appel de tâche **TBD**, à vérifier avec l'utilisateur (config CODESYS non lisible depuis le code source seul). |
| 3.4 | `CODE/JOYSTICK/FB_Joystick.st:79-80` | Instancie `FB_Filter_PT1` (underscore) au lieu de `FB_FilterPT1` (sans underscore) — contredit une décision déjà actée dans `DOC/AUDIT_Coherence_Documentaire_v1.0.md`. Fichiers `FB_Filter_PT1.st`/`FB_FilterPT1.st`/`FB_AxisScale.st` absents de `CODE/` (probablement définis directement dans CODESYS, non exportés) — impossible de confirmer laquelle des deux formes existe réellement côté CODESYS depuis le seul code source. |

---

## 📄 4. Documentation à mettre à jour

| # | Fichier | Constat |
|---|---|---|
| 4.1 | Quasi tous les `AF_PartieN` | En-tête "Dépend de : Partie 2 vX.Y" obsolète — `Partie1_v1.4`→v2.5, `Partie3_v1.3`→v2.5, `Partie4_v1.2`→v2.7, `Partie5_v1.2`→**v2.5** (2 versions de retard), `Partie8_v1.2`→v2.5, `Partie9_v1.1`→v2.7, `Partie10_v1.6`→v2.7, `Partie11_v1.2`→v2.7. Seul `Partie6_v1.3` pointe déjà vers v2.8. → tout bumper vers v2.8 (nouvelle version de chaque fichier, ne pas écraser). |
| 4.2 | `DOC/AF_Partie-09_Fonction_Winch_v1.1.md` | Nom de fichier périmé : contenu interne déjà en "v1.3" (changelog D_SLACK_1/2/3, D_OVERRIDESYNC). Référence encore "câblage dans PRG_MAIN" (l.~) alors que c'est maintenant `CODE/CONTROL/PRG_6_WinchControl.st:153,181`. |
| 4.3 🆕 | `DOC/AF_Partie-05_Modes_Maintenance_v1.2.md:30` | Définit `E_Mode` avec un membre **`MANUEL := 0`** — mais le vrai `CODE/MODES/E_Mode.st` a `DISABLE := 0` (pas de `MANUEL`). La doc elle-même est incohérente avec le code sur l'énumération de base, indépendamment du bug 1.1 (`AUTO`). |
| 4.4 🆕 | `DOC/AF_Partie-07_Interface_IHM_v1.0.md` | Doc entière à réviser : §4 "Logique de Mapping" référence `PRG_MAIN.st` (n'existe plus, remplacé par `PRG_9_Supervision.st`+`PRG_0_Inputs.st`) ; §5 note d'application référence la création de fichiers `_TYPES`/`GVL_IHM.st`/`PRG_MAIN.st` avec des chemins `CODE/*.st` qui ne correspondent plus à l'arborescence actuelle (`CODE/SUPERVISION/`, etc.) ; structures documentées (`ST_ModesHMI`, etc.) n'incluent pas les champs réellement utilisés dans `PRG_9_Supervision.st` (`GVL_IHM.Chariot.SelectedTargetNum`, `LimitLegalDepthMinAllowed`, `LimitLegalEnabled`, `LimitLegalReached`, `TopPositionSensorActive`) ; aucune structure `ST_AuxiliaryHMI` (cf. 2.D). En-tête cite aussi "Partie 2 v2.7". |
| 4.5 | `CLAUDE.md` (racine projet) | Référence encore `AF_Partie-02_Architecture_Programme_v2.7.md` et décrit l'ancienne arborescence FB (`PLC_PRG_MAIN`+`_COMMON/_TYPES/_DIAG/JOYSTICK/WINCH/ENCODER/CHARIOT/GRAPPIN/SAFETY/SEQUENCE`) — à réécrire pour refléter `PRG_0_Inputs`→`PRG_10_Outputs`. Hors périmètre de ce document (fichier de contrôle racine, à traiter par l'utilisateur/Claude directement). |

---

## ❓ 5. Décisions TBD à trancher avec l'utilisateur

| # | Sujet | Détail |
|---|---|---|
| 5.1 | Séquence `INIT` (`E_CycleStep.INIT`) | `AF_Partie-04_Cycle_Sequenceur_v1.2.md` §2 marque explicitement TBD les sous-vérifications (position chariot, cohérence grappin, position treuils, confirmation visuelle IHM) — décision D22 reportée. **Ne pas coder sans validation explicite du détail.** |
| 5.2 | Correctif du bug 1.1 (`E_Mode.AUTO`) | Semble être un résidu (aucune doc ne mentionne de mode `AUTO` distinct de `SEMI_AUTO`), mais la correction (suppression pure vs ajout réel d'un mode manquant) doit être confirmée par l'utilisateur avant modification de `CODE/`. |
| 5.3 | Statut de `PRG_IP.st` (3.3) | Présence/priorité dans la liste d'appel de tâche CODESYS — non vérifiable depuis le code source seul. |
| 5.4 | `FB_Filter_PT1` vs `FB_FilterPT1` (3.4) | Quel nom existe réellement côté CODESYS (fichier non exporté dans `CODE/`) — à vérifier au prochain export utilisateur avant de trancher. |
| 5.5 🆕 | Périmètre réel de `PRG_8_AuxiliaryControl` | Avant de coder le crible/hydraulique (2.C), il faut une spec fonctionnelle minimale (aucune `AF_PartieN` ne couvre ce métier aujourd'hui) — E/S réelles, sécurités associées, contrat FB (Enable/Reset/ErrorId) à définir. |

---

## 🖥️ 6. Supervision / IHM (analyse complémentaire)

- **Chaîne de sécurité → IHM** : pour M1/M2 (Winch) et M3 (Chariot), `PRG_9_Supervision.st` remonte `Error`/`ErrorId`/`SafeStopActive`/`ForbidDescentActive`/`ForbidAscentActive` correctement vers `GVL_IHM`. Pour le Grappin et la Synchro également. **Trou identifié** : rien pour l'auxiliaire (2.D) — cohérent avec le fait que la fonction n'existe pas encore.
- **Contrat Partie3 (Reset=front, ErrorId bitfield, Enable>SafeStop>StartStop)** : respecté dans les FB métier examinés cette session (`FB_Safety_Winch`, `FB_Safety_Chariot`, `FB_Winch` via `PRG_6_WinchControl`) — sauf `FB_Cycle` qui **calcule** un front (`ResetEdge`) mais ne l'utilise pas (2.B), et qui n'a pas de vrai `Error`/`ErrorId` actif (jamais posés dans le corps du FB malgré leur déclaration en `VAR_OUTPUT`).
- **`AF_Partie-07_Interface_IHM_v1.0.md` est le document le plus en retard** de toute la série (4.4) — c'est aussi celui qui décrit le contrat de données IHM, donc son obsolescence a un impact direct sur la fiabilité de la supervision si un intégrateur s'y fie tel quel aujourd'hui.
- **Pas de checklist de mise en service** trouvée dans `DOC/` (recherche "mise en service"/"plan de test"/"recette" infructueuse). Un projet de simulation CODESYS existe et a été compilé/exécuté récemment (`PRJ_CODESYS/Programme MGS_v0.3.10_Simulation.project`, horodatage 2026-07-04) — l'outil de test existe, mais aucune checklist formalisée (quels scénarios rejouer en simulation avant mise en service réelle : cycle complet, chaque SafeStop déclenché individuellement, overrides N1/N2, PowerCutOff redondant). **Recommandation** : créer une checklist de mise en service une fois les bloquants et écarts fonctionnels (sections 1-2) traités — prématuré avant.

---

## ✅ 7. Recommandation de séquencement

1. **1.1 (bloquant `E_Mode.AUTO`)** en premier — rien ne compile tant que ce n'est pas réglé, tout le reste est bloqué derrière.
2. **2.C/2.D (Auxiliaire)** vs **2.A/2.B (FB_Cycle)** : à arbitrer selon priorité métier de l'utilisateur — 2.A/2.B touchent la sécurité du cycle de dragage déjà en service (plus critique) ; 2.C/2.D est une fonction encore non spécifiée (5.5 doit être tranché avant de coder quoi que ce soit ici).
3. **3.x (dette technique)** : rapide à traiter (suppressions de fichiers vestiges), peut se faire en parallèle à tout moment, faible risque.
4. **4.x (doc)** : bump de version en dernier, une fois le code stabilisé sur les points 1-3 — sinon la doc devra être rebumpée deux fois (une fois maintenant, une fois après les correctifs fonctionnels).
5. **5.x (TBD)** : à trancher **avant** de coder les items associés (5.1 bloque tout codage d'INIT, 5.5 bloque tout codage de l'auxiliaire) — pas de work-around, conforme à la règle d'or du projet ("jamais d'approximation").
6. **6. (checklist mise en service)** : dernier, une fois 1-2 stabilisés — une checklist écrite contre un code encore incomplet serait obsolète avant d'être utilisée.
