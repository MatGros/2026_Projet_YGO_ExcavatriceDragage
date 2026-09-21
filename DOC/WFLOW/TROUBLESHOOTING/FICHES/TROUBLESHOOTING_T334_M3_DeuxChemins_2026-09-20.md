# 🕵️ Troubleshooting T334 — Translation M3 : deux chemins de commande (manuel/MAINT vs cycle auto) ?

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`
> 📅 Date : 2026-09-20 · 🧊 Situation : [SITE] constat opérateur (machine en service) + hypothèses vérifiables [SIMULATION BANC] · 📄 Statut : **PHASE 1 ACCEPTÉE PAR CC01 — campagne de trace 10 ms prête à exécuter (run humain), contrat C3 créé, phase 2 (conception) en attente des traces**
> 🎫 Tâche : `T334` (C3) · 🏷️ Acteur : **DSH07** (verrou posé `DOC/WFLOW/TASK_LOCKS.json`, tag vérifié 2026-09-20) · 🔒 Verrou orchestration : CC01
> 🚫 **Analyse read-only `CODE/`.** Aucun fichier `CODE/`, aucun test CI, aucun gate, aucun `CODE_XML/`, aucun `Device.export`, aucune IHM touchés. Aucun correctif proposé (§5 est « en principe »). Aucun commit.
> 📦 **Livrables de la phase 2 préparatoire** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` (contrat C3, `check_task_contract.py` PASS) · `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` (mode opératoire de la trace).

---

## 0. 🧭 Réponse courte (à lire avant les tableaux)

**La question de fond est partiellement fausse, et c'est le résultat principal de cette fiche.**

| Affirmation de l'utilisateur | Verdict | Preuve |
|---|---|---|
| « L'axe M3 reçoit un ordre de marche selon deux voies » | ❌ **FAUX au niveau de l'axe** | L'axe a **un seul** contrat d'ordre : `FB_Translation` (`CODE/I_TRANSLATION/FB_Translation.st:18-50`) appelé **une seule fois** (`CODE/M_MAIN/PRG_05_Translation.st:537-572`), un **seul** arbitre (`CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st`, instancié `PRG_05_Translation.st:27`, appelé `:363-372`), une **seule** barrière finale (`CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st`, appelée `CODE/M_MAIN/PRG_06_Outputs.st:434-451`), un **seul** jeu de mots variateur (`PRG_06_Outputs.st:457-459`). Les deux demandeurs **convergent** avant l'axe. |
| « Il y a donc deux voies » | ✅ **VRAI au niveau du demandeur et de l'arrêt** | Les deux voies divergent **à l'intérieur du même arbitre** (`FB_TranslationCmdArbitrationM3.st:63-83` cycle / `:84-113` manuel) et surtout sur **la nature de l'arrêt** : en manuel l'arrêt est un **verrou latché** (`FB_Translation.st:179-204`) ; en cycle c'est le **retrait de la demande** (`FB_CycleSemiAuto.st:899` AX2, `:1386` AX14), donc **ré-armable** par un rebond capteur. |
| « Le cycle continue après P1/Trémie » | ⚠️ **Cohérent avec le code, non prouvé sans trace** | 3 mécanismes sourcés (§6), 1 discriminant expérimental (§7). Aucune trace 10 ms M3 n'existe aujourd'hui dans le dépôt → **hypothèse + plan de preuve**, pas de cause racine affirmée. |

**Verdict de conception (détaillé §5) : ANOMALIE — partiellement obligatoire, partiellement modifiable.**
La séparation des **sources** est obligatoire et conforme (`AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:179`, `AF_Partie-02_Architecture_Programme_v3.2.md:220`). La duplication de la **fonction d'arrêt** avec deux sémantiques différentes ne l'est pas : elle contredit `AF_Partie-02_Architecture_Programme_v3.2.md:502` (« une commande unique par mouvement, après arbitrage ») et `CODE_QUALITY_STANDARDS.md` §5 (« producteur unique »).

⚠️ **Devoir d'alerte immédiat** : le contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` référencé par `DOC/WFLOW/TASKS.yaml:38` **n'existe pas** (`glob DOC/WFLOW/CONTRACTS/*T334*` → 0 fichier). Tâche C3 sans contrat de tâche = cas d'arrêt du préambule sous-agent. Les critères AC1→AC5 du brief d'origine font office de contrat et sont traités tels quels ; **le fichier de contrat reste à produire par l'orchestrateur**.

---

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Constat opérateur 2026-09-20 (machine en service depuis des semaines, `DOC/WFLOW/TASKS.yaml:28`) : **en manuel et en maintenance, M3 s'arrête correctement sur les fins de course** ; **en cycle automatique, à l'arrivée sur P1 ou Trémie, le chariot continue d'avancer**. Recadrage de fond de l'utilisateur (15:45) : en POO, l'axe devrait recevoir **un ordre de marche** (vers extrémité / Maintenance / P1) quel que soit le demandeur (joystick, cycle) ; passer par des voies différentes selon le mode est anormal.

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Situation | banc / site | **site** (constat) · banc non instrumenté pour ce cas | 2026-09-20 |
| Mode au moment du constat | `PRG_03_Modes_Cycle.Data.Auth.Mode` | `SEMI_AUTO` | 2026-09-20 |
| Trace 10 ms M3 disponible | — | ❌ **aucune** (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/` ne contient que `Suivi_TranslationM3bug_20260904_27` à **dt médian 100 ms**, cf. `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:40`) | 2026-09-20 |
| Trace voisine réutilisable | `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27.trace` | 352 échantillons, 15 variables, t ∈ [0,037 ; 35,137] s | 2026-09-04 |
| Capteur rebondissant aux arrivées | (rapport terrain T287) | commutations `0↔1` rapides pendant **≈ 1 s** aux arrivées Trémie **ET** P1 | 2026-09-15 (`TASKS.yaml:1249-1250`) |

> ⛔ **Aucune valeur live n'est demandée à ce stade** : la chaîne est établie par lecture statique du code (méthode `[3]`), et la preuve dynamique passe par une **trace 10 ms** (§7), pas par un snapshot §4bis de la skill troubleshooting.

---

## 2. 🎯 Symptôme

En `SEMI_AUTO`, à l'arrivée de M3 sur **P1** (étape AX2) et sur **Trémie** (étape AX14), le chariot **poursuit son avance** au lieu de s'arrêter au point d'arrêt, alors qu'en `MAINT_N1`/`MAINT_N2` (jog joystick / boutons IHM) l'arrêt sur les fins de course est jugé correct par l'opérateur. Symptôme **reproductible** (à chaque cycle), **non instrumenté** (aucune trace au pas de la tâche 10 ms).

---

## 3. 🧩 Indices / historique

- Derniers changements : `T319` (continuité AX2→AX3, clos ✅, `TASKS.yaml:308-328`) ; `T300` (banc M3, perte capteur ~1 s, `TASKS.yaml:768-818`) ; `T287` (défaut frein M3 aux arrivées Trémie **et** P1, `TASKS.yaml:1240-1273`) ; `T327` (exclusion `CoupledBucketPhaseLocked`, commit `cbd88966`).
- Déjà essayé / déjà su : `T287` documente la commutation capteur `0↔1` ≈ 1 s aux arrivées ; `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:76` note que la perte/reprise « ~1 s » **n'est pas** dans la trace du 04/09 → à recapturer au pas fin.
- Conditions d'apparition : arrivée **sur le point d'arrêt** (P1 en AX2, Trémie en AX14), joystick **maintenu** (c'est l'instruction IHM de l'étape : `FB_CycleSemiAuto.st:911` « Pousser gauche/droite : arrêt automatique sur P1 »).
- Alarmes : piste `State.ErrorId=64` (cause 6, « Limite extreme translation atteinte ») observée le 04/09 (`DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:55`), portée par `TranslationM3.**State**`.ErrorId et non `Safety` (`DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:66`, écart E4) ; `T287` signale une récidive du défaut **séquence/retour frein** aux mêmes arrivées.
- Indice fort : `FB_CycleSemiAuto.st:1534-1545` contient une **branche de récupération** dédiée à l'état « M3 au-delà de P1 » (`Translation_PosMaintenance AND NOT Translation_PosP1`, message `'AX2 - M3 au-dela de P1 : pousser vers la tremie (gauche) pour retrouver P1.'`) → le dépassement de P1 est **connu** du séquenceur, donc déjà rencontré.

---

## 4. 🔗 PARTIE 1 — CHAÎNE MANUELLE (de haut en bas, une ligne par variable)

Mode couvert : `MAINT_N1` / `MAINT_N2` (`FB_TranslationCmdArbitrationM3.st:84-113`).
Colonne « Consommateur » = consommateur **décisionnel** (celui qui décide de la suite) ; la vérification se fait par `grep` du nom exact.

| # | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle |
|---|---|---|---|---|
| M01 | `JoyXRaw_ANA1` (global E/S, `%IW114`) | mapping device `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv:504` ; recopie `CODE/M_MAIN/PRG_02_Acquisition.st:181` ; type `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_HwOperator.st:8` | `CODE/M_MAIN/PRG_02_Acquisition.st:465` | Valeur brute ADC axe X (translation), neutre 5000 |
| M02 | `JoyYRaw_ANA2`, `JoyBtnRaw` | `Device_IO_20260918.csv:521` et `:496` ; recopie `PRG_02_Acquisition.st:182-183` | `PRG_02_Acquisition.st:466-467` | Axe Y (treuils) et bouton homme-mort |
| M03 | `HwIn.Operator` (= réel **ou** simulé) | `PRG_02_Acquisition.st:434` (`SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator)`) ; sélection `:137` | `PRG_02_Acquisition.st:465-467` | Frontière réel/simulé de la manche |
| M04 | `ScaleX.OutPct` (axe X mis à l'échelle, −100..+100 %) | `CODE/D_JOYSTICK/FB_AxisScale.st:29,36,43,49` | `CODE/D_JOYSTICK/FB_Joystick.st:185,197,253` | Deadband + mise à l'échelle de l'axe X |
| M05 | `AtNeutralXY` | `FB_Joystick.st:185` | `FB_Joystick.st:211,248` ; `PRG_02_Acquisition.st:478` ; `CODE/M_MAIN/PRG_03_Modes_Cycle.st:196` | Les 2 axes au neutre **brut** (avant homme-mort) |
| M06 | `DeadmanArmed` | `FB_Joystick.st:232`, `:239` (désarmement si `ArmingPermit` retiré), `:249` (retour au neutre) | `FB_TranslationCmdArbitrationM3.st:102,104` ; `PRG_02_Acquisition.st:477` ; `PRG_03_Modes_Cycle.st:204` | Homme-mort **qualifié** — condition de COMMANDE (pas de possibilité) |
| M07 | `AxisCmdX.DirectionPositive` | `FB_Joystick.st:259` | `FB_TranslationCmdArbitrationM3.st:69,94` | Sens +1 = vers **Trémie** |
| M08 | `AxisCmdX.DirectionNegative` | `FB_Joystick.st:260` | `FB_TranslationCmdArbitrationM3.st:70,95` | Sens −1 = vers **Maintenance** |
| M09 | `AxisCmdX.SpeedTgt` (non signée, %) | `FB_Joystick.st:256`, `:262` (0 si neutre) | `FB_TranslationCmdArbitrationM3.st:113` | Magnitude du geste |
| M10 | `AxisCmdX.AtNeutral` | `FB_Joystick.st:261` | `FB_Joystick.st:265-267` (`Direction`) | Neutralité **qualifiée** axe X |
| M11 | `Data.Joystick.AxisX` | `PRG_02_Acquisition.st:475` | `PRG_05_Translation.st:365` (entrée `Joystick` de `instArbM3`) | Bus inter-PRG du geste X |
| M12 | `GVL_IHM.M3Translation.Cmd.BtnTremie` | IHM (hors `CODE/`) ; déclaration `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_TranslationCmd.st:12` | `PRG_05_Translation.st:354` → `FB_TranslationCmdArbitrationM3.st:89` | Bouton marche Trémie (MAINT) |
| M13 | `GVL_IHM.M3Translation.Cmd.BtnMaintenance` | IHM ; déclaration `ST_TranslationCmd.st:13` | `PRG_05_Translation.st:355` → `FB_TranslationCmdArbitrationM3.st:91` | Bouton marche Maintenance (MAINT) |
| M14 | `GVL_IHM.M3Translation.Cmd.SelPositioning` | IHM ; déclaration `ST_TranslationCmd.st:10` | `PRG_05_Translation.st:356` → `FB_TranslationCmdArbitrationM3.st:86` | Positionneur IHM → **`PositioningActive`** (jamais consommé, cf. §8 D04) |
| M15 | `GVL_IHM.M3Translation.Cmd.SetFreq_Hz` | IHM ; déclaration `ST_TranslationCmd.st:14` ; amorçage/recopie persistante `CODE/M_MAIN/PRG_07_Supervision.st:211,217` | `PRG_05_Translation.st:357` → `FB_TranslationCmdArbitrationM3.st:108-110` | Consigne **fréquence manuelle** (défaut 40 Hz, `CODE/GVL_PERSISTENT.st:98`) |
| M16 | `GVL_IHM.M3Translation.Cmd.InvertDirection` | IHM ; déclaration `ST_TranslationCmd.st:16` | `PRG_05_Translation.st:546` → `FB_Translation.st:292-295` | Inversion câblage Fwd/Rev (mise en service) |
| M17 | `GVL_IHM.Modes.Cmd.TglJoystickMaster` | IHM (`ST_ModesCmd`) | `PRG_05_Translation.st:369` → `FB_TranslationCmdArbitrationM3.st:89,91,93,101,104,111` | Switch machine : joystick maître ↔ boutons IHM |
| M18 | `ArbM3_IHM.BypassGlobal` | `PRG_05_Translation.st:358` ← `GVL_IHM.M3Translation.Bypass.Global` | `FB_TranslationCmdArbitrationM3.st:101` | Composante tautologique conservée (`:99` commentaire) |
| M19 | `ArbM3_Context.HeightInterlockOk` | `PRG_05_Translation.st:360` ← `M3_HeightInterlockOk` calculé `:134-138` | `FB_TranslationCmdArbitrationM3.st:72,105` | Anti-collision hauteur M1/M2 (seul `Bypass.MinHeight` le lève) |
| M20 | `ArbM3_Cfg.MaxFreq_Hz` | `PRG_05_Translation.st:361` ← `GVL_PERSISTENT._TranslationMaxFreq_Hz` | `FB_TranslationCmdArbitrationM3.st:110` | Échelle % → Hz de la consigne manuelle |
| M21 | `Data.Auth` (`ST_Modes_Autorisations`) | `CODE/F_MODES/FB_Modes.st` → `PRG_03_Modes_Cycle.st:278` | `PRG_05_Translation.st:366` → `FB_TranslationCmdArbitrationM3.st:63,84` | Mode + droits (dont `MaintenanceM3TargetEnable`, `FB_Modes.st:413`) |
| M22 | `instArbM3.RunRequest` | `FB_TranslationCmdArbitrationM3.st:100-105` | `PRG_05_Translation.st:375` | Demande de marche maintenue (homme-mort + inter-axes Y) |
| M23 | `instArbM3.ReqTremie` | `FB_TranslationCmdArbitrationM3.st:90,94` (neutralisée si conflit `:126-129`) | `PRG_05_Translation.st:376` | Demande explicite **vers Trémie** |
| M24 | `instArbM3.ReqMaintenance` | `FB_TranslationCmdArbitrationM3.st:92,95` (neutralisée si conflit `:126-129`) | `PRG_05_Translation.st:377` | Demande explicite **vers Maintenance** |
| M25 | `instArbM3.SpeedPct` | `FB_TranslationCmdArbitrationM3.st:108-113` + clamp `:132` | `PRG_05_Translation.st:379` | Consigne vitesse arbitrée 0..100 % |
| M26 | `instArbM3.SelTarget` | `FB_TranslationCmdArbitrationM3.st:87` (`SelTarget := 0` en MAINT) + garde `:135-137` | `PRG_05_Translation.st:374` → `:408` (`CASE SelTarget`) | En manuel : **toujours 0** → l'arrêt suit le SENS demandé |
| M27 | `instArbM3.PositioningActive` | `FB_TranslationCmdArbitrationM3.st:86` | `PRG_05_Translation.st:373` → **aucun consommateur** | Variable morte (§8 D04) |
| M28 | `M3_RunRequest_Active` | `PRG_05_Translation.st:375` | `PRG_05_Translation.st:455` (safety), `:542` (`FB_Translation`), `:391` (veto SEMI_AUTO) | Demande de marche retenue par PRG_05 |
| M29 | `M3_ReqTremie_Active` | `PRG_05_Translation.st:376` | `PRG_05_Translation.st:544` (FB), `:456` (safety), `:650` (`ReqTremieSemantic`), `:164,188` (latches FdC), `:579` (estimateur) | Sens Trémie retenu |
| M30 | `M3_ReqMaintenance_Active` | `PRG_05_Translation.st:377` | `PRG_05_Translation.st:545` (FB), `:457` (safety), `:164,188` (relâche des latches), `:580` (estimateur) | Sens Maintenance retenu |
| M31 | `M3_SpeedCmd_Active` | `PRG_05_Translation.st:379` | `PRG_05_Translation.st:547` (entrée `SpeedTgt_Pct`), `:693` (IHM) | Consigne % appliquée à la rampe |
| M32 | `SelTarget` (local PRG_05) | `PRG_05_Translation.st:374` | `PRG_05_Translation.st:408-429` | Sélection de la cible d'arrêt |
| M33 | `M3_HeightInterlockOk` | `PRG_05_Translation.st:134-138` | `PRG_05_Translation.st:360`, `:768`, `:779`, `:790` | Interlock hauteur (bloque la commande, pas le permis) |
| M34 | `M3_SafeStop_Aggregate` | `PRG_05_Translation.st:479-481` (`InputModuleFault` OR safety OR homing M3) | `PRG_05_Translation.st:510,514,543,642` | SafeStop réellement appliqué (rampe rapide) |
| M35 | `instPosDecoderM3.SensorsWord` | `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st:71-76` | `PRG_05_Translation.st:210-213`, `:226`, `:243-259`, `:292-297`, `:304-341` | Mot thermomètre 5 capteurs (bit4=Trémie, bit0=Maintenance, 6 mots valides) |
| M36 | `instPosDecoderM3.TranslationAtTremie` | `FB_Translation_PositionDecoder.st:113` (`EdgeUpTremie.Q` — **front montant uniquement**) | `PRG_05_Translation.st:265` | Front d'arrivée Trémie (1 cycle) |
| M37 | `instPosDecoderM3.TranslationAtP1` | `FB_Translation_PositionDecoder.st:116` (`EdgeUpP1.Q OR EdgeDnP1.Q` — **les 2 fronts**) | `PRG_05_Translation.st:271` | Front d'arrivée P1 (1 cycle) |
| M38 | `instPosDecoderM3.TranslationAtMaintenance` | `FB_Translation_PositionDecoder.st:117` (`EdgeDnMaintenance.Q` — **front descendant uniquement**) | `PRG_05_Translation.st:273` | Front d'arrivée Maintenance (1 cycle) |
| M39 | `M3_AtTremieStable` | `PRG_05_Translation.st:266` (front Trémie), `:245` (restauration boot), `:277` (RAZ mot capteurs) | `PRG_05_Translation.st:409,416,603,702`, `:819` (bus `Data`) | Jeton **latché** « au point Trémie » |
| M40 | `M3_AtP1Stable` | `PRG_05_Translation.st:272` (front P1), `:254` (restauration boot), `:277` (RAZ) | `PRG_05_Translation.st:411,424,608,705`, `:820` (bus) | Jeton **latché** « au point P1 » |
| M41 | `M3_AtMaintenanceStable` | `PRG_05_Translation.st:274`, `:257`, `:277` | `PRG_05_Translation.st:412,422,605,706`, `:821` (bus) | Jeton **latché** « au point Maintenance » |
| M42 | `M3_SensorsWordChanged` | `PRG_05_Translation.st:212` | `PRG_05_Translation.st:275-277` | **RAZ de TOUS les jetons** sur changement de mot sans front capteur |
| M43 | `M3_LimitSwitchTremieStable` | `PRG_05_Translation.st:163` (mot `11111`), relâché `:165` sur sens inverse | `PRG_05_Translation.st:458,561,713` | Verrou bistable FdC extrême Trémie |
| M44 | `M3_LimitSwitchMaintenanceStable` | `PRG_05_Translation.st:187` (`M3_LimitSwitchMaintenanceEffective`), relâché `:189` | `PRG_05_Translation.st:459,562,714` | Verrou bistable FdC extrême Maintenance / cran P1 |
| M45 | `M3_LimitSwitchMaintenanceEffective` | `PRG_05_Translation.st:152-154` (mot `00001` si Maintenance non autorisée) | `PRG_05_Translation.st:186` | Substituat de FdC dur pour P1 |
| M46 | `M3_PositionSensorTarget` | `PRG_05_Translation.st:408-429` (branche `ELSE` = sens demandé) | `PRG_05_Translation.st:548` → `FB_Translation.st:175` | **Capteur cible d'arrêt** |
| M47 | `TranslationCfg` | `PRG_05_Translation.st:529-535` (source unique `GVL_PERSISTENT`) | `PRG_05_Translation.st:568` → `FB_Translation.st:259,309-313,175` | Rampes + 3 vitesses d'approche (défaut 10 Hz, `ST_TranslationCfg.st:9-11`) |
| M48 | `instTranslationM3.CaptorDebounceTon.Q` → `TargetReached` | `FB_Translation.st:175-176` (debounce 100 ms, `ST_fbTranslation_Cfg.st:31`) | `FB_Translation.st:177` (`ArrivalEdge`) | Confirmation d'arrivée sur capteur cible |
| M49 | `instTranslationM3.ArrivalLock` | `FB_Translation.st:180` (front arrivée), `:192,196` (FdC), relâché `:202-204` (**sens inverse explicite requis**) | `FB_Translation.st:251` (§5 rampe) | **Verrou d'arrêt LATCHÉ — ne se relâche PAS sur perte capteur** |
| M50 | `instTranslationM3.ArrivalWasTremie` / `ArrivalWasMaintenance` | `FB_Translation.st:181-182`, `:193-198` | `FB_Translation.st:202` | Sens mémorisé de l'arrivée (condition de relâche) |
| M51 | `instTranslationM3.CommandedTremie` / `CommandedMaintenance` | `FB_Translation.st:215-216`, `:219-220`, `:230-231` | `FB_Translation.st:191,195` (FdC), `:290-303` (mot de commande) | Sens **réellement appliqué** |
| M52 | `instTranslationM3.RampTargetPct` | `FB_Translation.st:251-255` | `FB_Translation.st:258` | Cible de rampe (0 si `ArrivalLock`/`SafeStop`/pas de demande) |
| M53 | `instTranslationM3.EffectiveSafeStop` | `FB_Translation.st:244-247` (`SafeStop` OR sens non permis OR 2 sens) | `FB_Translation.st:251,260` | Gate de sens (permis directionnels) |
| M54 | `instTranslationM3.RequestedDriveControlWord` | `FB_Translation.st:297-303` | `PRG_05_Translation.st:648` → `PRG_06_Outputs.st:445-447` | Mot métier 0/1/2 (0 = **roue libre** côté variateur) |
| M55 | `instTranslationM3.RequestedDriveFreqHz` | `FB_Translation.st:305`, plafonnée par l'approche `:308-313` | `PRG_05_Translation.st:649` → `PRG_06_Outputs.st:448-450` | Consigne fréquence métier (Hz) |
| M56 | `instTranslationM3.BrakeReleaseRequest` | `FB_Translation.st:286` (issu de `FB_Brake`) | `PRG_05_Translation.st:646` → `PRG_06_Outputs.st:442-443` | Demande de desserrage frein |
| M57 | `instTranslationM3.OverrunLimitSwitch` | `FB_Translation.st:123-127` (dépassement **soutenu 1,5 s** ET `|fAct| > 0,5 Hz`) | `FB_Translation.st:127` → `instCauses[6]` | Cause 6 « Limite extreme translation atteinte » (non latched) |
| M58 | `TranslationFinalInterlockRequest` (champs `Enable`,`SafeStop`,`PowerCutOff`,`EffectivePermitM3_*`,`BrakeReleaseRequest`,`RequestedDriveControlWord`,`RequestedDriveFreqHz`,`ReqTremieSemantic`) | `PRG_05_Translation.st:639-651` (+ veto `:656-662` en SEMI_AUTO) | `PRG_06_Outputs.st:410-411,437-450` | Bus de la demande finale vers la barrière |
| M59 | `M3_TremieHardStopActive` | `PRG_06_Outputs.st:431-432` (DI **brut** `M3_PosTremie_DI` AND `ReqTremieSemantic`) | `PRG_06_Outputs.st:443,445,448` | Coupure directionnelle dure Trémie : mot 0 + frein fermé **au même scan** |
| M60 | `instTranslationOutputInterlockM3.DriveControlWord` / `.DriveFreqCmdWord` / `.BrakeCmd` | `FB_TranslationOutputInterlock.st:146-154` / `:154` / `:137` | `PRG_06_Outputs.st:458`, `:459`, `:457` | Barrière finale (watchdog frein 500 ms, anti-redémarrage) |
| M61 | `M3_CommandWord` (global, `%QW6`) | `PRG_06_Outputs.st:458` ; mapping `Device_IO_20260918.csv:190` | variateur AC600 (`%QW6`, registre `0x3101`) ; relecture banc `PRG_02_Acquisition.st:311-312` ; miroir IHM `PRG_07_Supervision.st:526` | **Mot de commande variateur** |
| M62 | `M3_SetpointFrequencyHz` (global, `%QW7`) | `PRG_06_Outputs.st:459` ; mapping `Device_IO_20260918.csv:207` | variateur AC600 (`%QW7`, registre `0x3100`) ; relecture banc `PRG_02_Acquisition.st:314` ; miroir IHM `PRG_07_Supervision.st:527` | **Consigne fréquence variateur** (×100) |
| M63 | `M3_BrakeRelease_RQ` (global, `%QX27.2`) | `PRG_06_Outputs.st:457` ; mapping `Device_IO_20260918.csv:480` | bobine frein M3 (`%QX27.2`, VH_0008ER) ; miroir IHM `PRG_07_Supervision.st:515` | **Ordre frein** (l'AU seul coupe brutalement) |
| M64 | `M3_BrakeIsOpen_DI` (retour frein) | mapping `Device_IO_20260918.csv:471` ; consommé `PRG_05_Translation.st:453,569,683` | `FB_Translation.st:278` (`ContactorFeedback`) | Retour physique frein → watchdog barrière |
| M65 | `M3_ActualFrequencyHz` (retour variateur ×100) | mapping `Device_IO_20260918.csv:241` ; recopie brute `PRG_02_Acquisition.st:177` ; projection `PRG_02_Acquisition.st:688` | `PRG_05_Translation.st:567` → `FB_Translation.st:260,125,210,272` | Vitesse réelle : arrêt confirmé, dépassement, rampe |
| M66 | `M3_StatusWord` | mapping `Device_IO_20260918.csv:224` | `PRG_05_Translation.st:566,728-729` ; `FB_Safety_Translation.st:200-201` | État variateur (bit 0 = marche, bit 7 = avertissement) |

**Chaîne manuelle en une ligne :**
`JoyXRaw_ANA1` → `FB_AxisScale.OutPct` → `FB_Joystick.AxisCmdX` → `Data.Joystick.AxisX` → `FB_TranslationCmdArbitrationM3` (branche `:84-113`, `SelTarget := 0`) → `M3_ReqTremie_Active`/`M3_ReqMaintenance_Active` → `M3_PositionSensorTarget` (**suit le sens**, `PRG_05:414-425`) → `FB_Translation` (`ArrivalLock` latché) → `FB_TranslationOutputInterlock` → `PRG_06_Outputs` → `M3_CommandWord`/`M3_SetpointFrequencyHz`/`M3_BrakeRelease_RQ`.

---

## 5. 🔗 PARTIE 2 — CHAÎNE CYCLE AUTO (même format, même profondeur)

Mode couvert : `SEMI_AUTO` (`FB_TranslationCmdArbitrationM3.st:63-83`). Étapes demandeuses de M3 : **AX2** (`E_AutoCycleStep.AX2_TRANSLATE_P1`) et **AX14** (`E_AutoCycleStep.AX14_TRANSLATE_DUMP`) — seules étapes autorisées, cf. `PRG_05_Translation.st:385-387`.

| # | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle |
|---|---|---|---|---|
| C01 | `GVL_IHM.CycleSemiAuto.Cmd.BtnStart` | IHM (hors `CODE/`) | `PRG_03_Modes_Cycle.st:206` → `FB_CycleSemiAuto.st:818,727,1510` | Départ/reprise **consciente** du cycle |
| C02 | `Data.Joystick.AxisX.DirectionNegative` | `PRG_02_Acquisition.st:475` | `PRG_03_Modes_Cycle.st:201` (`JoystickRight`) → `FB_CycleSemiAuto.st:716` (`TranslationP1Permit`) | Geste « vers P1 » (droite) |
| C03 | `Data.Joystick.AxisX.DirectionPositive` | `PRG_02_Acquisition.st:475` | `PRG_03_Modes_Cycle.st:203` (`JoystickLeft`) → `FB_CycleSemiAuto.st:717` (`TranslationTremiePermit`) | Geste « vers Trémie » (gauche) |
| C04 | `Data.Joystick.AtNeutralXY` | `PRG_02_Acquisition.st:478` | `PRG_03_Modes_Cycle.st:196` (`JoystickDeflected`) → `FB_CycleSemiAuto.st:715,1377,1388,1391` | Intention maintenue (principe `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:180`) |
| C05 | `Data.Joystick.DeadmanArmed` | `PRG_02_Acquisition.st:477` | `PRG_03_Modes_Cycle.st:204` → `FB_CycleSemiAuto.st:715-718` | Permis opérateur à chaque scan |
| C06 | `Data.Joystick.AxisY.DirectionNegative` / `.DirectionPositive` | `PRG_02_Acquisition.st:476` | `PRG_03_Modes_Cycle.st:197-198` (`JoystickPush`/`JoystickPull`) → `FB_CycleSemiAuto.st:718` (`JoystickPushOnly`) | Discrimination X seul / Y seul |
| C07 | `instModes.Auth` | `FB_Modes.st:413` (`MaintenanceM3TargetEnable`) → `PRG_03_Modes_Cycle.st:278` | `PRG_03_Modes_Cycle.st:191,195` → `FB_CycleSemiAuto.st:423,560` (mode) ; `PRG_05_Translation.st:152,188,421,560` | Autorisations : **`MaintenanceM3TargetEnable` est TOUJOURS faux en SEMI_AUTO** (`FB_Modes.st:413` exige `MAINT_N1/N2`) |
| C08 | `Data.M3_AtP1Stable` | `PRG_05_Translation.st:820` | `PRG_03_Modes_Cycle.st:234` (`Translation_At_P1`) → `FB_CycleSemiAuto.st:335,889` | Qualification P1 **consommée par le cycle** (jeton du manuel, pas un décodeur propre) |
| C09 | `Data.M3_AtTremieStable` | `PRG_05_Translation.st:819` | `PRG_03_Modes_Cycle.st:235` (`Translation_At_Tremie`) → `FB_CycleSemiAuto.st:336,1385` | Qualification Trémie consommée par le cycle |
| C10 | `Data.M3_AtMaintenanceStable` | `PRG_05_Translation.st:821` | `PRG_03_Modes_Cycle.st:236` ; `PRG_03_Modes_Cycle.st:168` (posture AX1) | Refus de départ si le chariot est à droite de P1 |
| C11 | `Data.TranslationBusy` | `PRG_05_Translation.st:817` (`|fAct| > 0,5 Hz`) | `PRG_03_Modes_Cycle.st:239` → `FB_CycleSemiAuto.st:337` | Arrêt **physique** confirmé (pas la consigne) |
| C12 | `HwIn.Translation.M3_PosP1_DI` (DI brut) | mapping `Device_IO_20260918.csv:454` | `PRG_03_Modes_Cycle.st:237` (`Translation_PosP1`) → `FB_CycleSemiAuto.st:1534` | Détection « au-delà de P1 » (branche de récupération) |
| C13 | `HwIn.Translation.M3_PosMaintenance_DI` (DI brut) | mapping `Device_IO_20260918.csv:455` | `PRG_03_Modes_Cycle.st:238` → `FB_CycleSemiAuto.st:1534` | Idem, seuil Maintenance |
| C14 | `FB_CycleSemiAuto.CycleMotionPermit` | `FB_CycleSemiAuto.st:715` | `FB_CycleSemiAuto.st:1558` | Repli homme-mort (§4 du FB) |
| C15 | `FB_CycleSemiAuto.TranslationP1Permit` | `FB_CycleSemiAuto.st:716` | `FB_CycleSemiAuto.st:913` | Permis « X droite, Y neutre, homme-mort » |
| C16 | `FB_CycleSemiAuto.TranslationTremiePermit` | `FB_CycleSemiAuto.st:717` | `FB_CycleSemiAuto.st:1383,1545` | Permis « X gauche, Y neutre, homme-mort » |
| C17 | `FB_CycleSemiAuto.TranslationStopTimer.Q` | `FB_CycleSemiAuto.st:334-338` (500 ms, `:246`) | `FB_CycleSemiAuto.st:896,901` (AX2), `:1391` (AX14) | Confirmation d'arrêt avant changement d'étape |
| C18 | `FB_CycleSemiAuto.TranslationCmd.ReqStart` (**AX2**) | `FB_CycleSemiAuto.st:899` (`FALSE` si `Translation_At_P1`), `:913` (`TRUE` sinon) | `FB_CycleSemiAuto.st:126` → `PRG_03_Modes_Cycle.st:314` → `Data.ReqProgram.ReqTranslation.ReqStart` → `PRG_05_Translation.st:367` → `FB_TranslationCmdArbitrationM3.st:72` | **Demande de marche** — ⚠️ **re-assertée dès que le jeton P1 retombe** |
| C19 | `FB_CycleSemiAuto.TranslationCmd.PositionTgt` (**AX2**) | `FB_CycleSemiAuto.st:887`, `:900`, `:912` (**toujours 3, même après l'arrivée**) | `FB_CycleSemiAuto.st:126` → `PRG_03_Modes_Cycle.st:314` → `PRG_05_Translation.st:367` → `FB_TranslationCmdArbitrationM3.st:65` | **Cible d'arrêt P1 figée** par l'étape |
| C20 | `FB_CycleSemiAuto.TranslationCmd.ReqStart` (**AX14**) | `FB_CycleSemiAuto.st:1383` (`= TranslationTremiePermit`), `:1386` (`FALSE` si `Translation_At_Tremie`) | idem C18 | Demande de marche — ⚠️ **re-assertée dès que le jeton Trémie retombe** |
| C21 | `FB_CycleSemiAuto.TranslationCmd.PositionTgt` (**AX14**) | `FB_CycleSemiAuto.st:1382` (`1`), `:1387` (**`0` à l'arrivée**) | idem C19 | Cible Trémie — ⚠️ **remise à 0 à l'arrivée, contrairement à AX2** |
| C22 | `Data.ReqProgram.ReqTranslation` | `PRG_03_Modes_Cycle.st:314` ; neutralisée hors SEMI_AUTO `:392-393`, `:483-484` ; type `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramTranslationRequest.st:9-10` | `PRG_05_Translation.st:367` | Bus demande cycle → translation |
| C23 | `instArbM3.RunRequest` (branche cycle) | `FB_TranslationCmdArbitrationM3.st:72` (`ReqStart AND HeightInterlockOk AND CycleJoystickAxisOk`) | `PRG_05_Translation.st:375` | Demande retenue en SEMI_AUTO |
| C24 | `instArbM3.SelTarget` (branche cycle) | `FB_TranslationCmdArbitrationM3.st:65` (`:= ReqTranslation.PositionTgt`) | `PRG_05_Translation.st:374` → `:408-429` | **Verdict de cible figé par l'étape** (3 en AX2, 1 en AX14, 0 sinon) |
| C25 | `CycleTargetDirectionOk` / `CycleJoystickAxisOk` | `FB_TranslationCmdArbitrationM3.st:68-71` | `FB_TranslationCmdArbitrationM3.st:72` | Le sens **ne filtre pas** la cible : en AX2, `SelTarget = 3` rend `CycleTargetDirectionOk` vrai **dans les deux sens** (`:68`) |
| C26 | `instArbM3.ReqTremie` / `ReqMaintenance` (cycle) | `FB_TranslationCmdArbitrationM3.st:75-80` | `PRG_05_Translation.st:376-377` | Sens déduit de `SelTarget` + joystick (100 % vitesse, `:74`) |
| C27 | `instArbM3.SpeedPct` (cycle) | `FB_TranslationCmdArbitrationM3.st:74` (**`100.0` fixe**) ou `:82` (`0.0`) | `PRG_05_Translation.st:379` → `:547` | ⚠️ Aucun plafond : `_TranslationAutoSpeedCap_Pct` (40 %) est **déclaré mais jamais consommé** (`GVL_PERSISTENT.st:97` → 0 lecteur) |
| C28 | `M3_CycleTranslationStepAuthorized` | `PRG_05_Translation.st:385-387` (étape ∈ {AX2, AX14}) | `PRG_05_Translation.st:390` (veto amont), `:657` (veto barrière) | **Veto SEMI_AUTO propre au cycle** : hors AX2/AX14, demande et vitesse forcées à 0 |
| C29 | `M3_RunRequest_Active` / `M3_ReqTremie_Active` / `M3_ReqMaintenance_Active` (veto) | `PRG_05_Translation.st:391-394` | `PRG_05_Translation.st:542-547` | Neutralisation amont hors étape de translation |
| C30 | `TranslationFinalInterlockRequest` (veto barrière) | `PRG_05_Translation.st:656-662` (frein, mot de commande, fréquence, sémantique) | `PRG_06_Outputs.st:442-450` | **2ᵉ barrière SEMI_AUTO** — n'existe pas côté manuel |
| C31 | `M3_PositionSensorTarget` (cycle) | `PRG_05_Translation.st:408-429` (`CASE SelTarget` : `1`→`AtTremieStable`, `3`→`AtP1Stable`) | `PRG_05_Translation.st:548` → `FB_Translation.st:175` | **Capteur cible = cible de l'ÉTAPE**, pas le sens du geste |
| C32 | `instCycleSemiAuto.SelTarget` (entrée du séquenceur) | `PRG_03_Modes_Cycle.st:209` ← `GVL_IHM.M3Translation.Cmd.SelTarget` | `FB_CycleSemiAuto.st:32` — **déclaré « RESERVE », câblé mais « non consomme »** | Entrée morte du séquenceur (le cycle part toujours de P1) |
| C33 | `Data.SequenceState.Step` | `PRG_03_Modes_Cycle.st:330` ← `FB_CycleSemiAuto.CycleStep` | `PRG_05_Translation.st:386-387` | Étape courante (base du veto C28) |
| C34 | `Data.M3_AtTremieStable` (drain benne) | `PRG_05_Translation.st:819` | `PRG_03_Modes_Cycle.st:398` (`DumpAtTremieBucketOpenArmed`) | Assistant vidage à la Trémie |
| C35 | Sorties variateur `M3_CommandWord` / `M3_SetpointFrequencyHz` / `M3_BrakeRelease_RQ` | `PRG_06_Outputs.st:457-459` | mapping `Device_IO_20260918.csv:190,207,480` | **Identiques à la chaîne manuelle** (mêmes mots, même barrière) |

**Chaîne cycle en une ligne :**
`instCycleSemiAuto` (AX2 `:873-914` / AX14 `:1370-1394`) → `TranslationCmd` (`ST_ProgramTranslationRequest.st:9-10`) → `PRG_03_Modes_Cycle.st:314` → `PRG_05_Translation.st:367` → `FB_TranslationCmdArbitrationM3` (branche `:63-83`, `SelTarget := ReqTranslation.PositionTgt`, `SpeedPct := 100`) → `M3_ReqTremie_Active`/`M3_ReqMaintenance_Active` → `M3_PositionSensorTarget` (**cible de l'étape**) → `FB_Translation` → `FB_TranslationOutputInterlock` → `PRG_06_Outputs` → **les mêmes** `M3_CommandWord`/`M3_SetpointFrequencyHz`/`M3_BrakeRelease_RQ`.

---

## 6. ⚖️ PARTIE 3 — COMPARATIF HIÉRARCHIQUE DES DEUX CHAÎNES

### 6.1 Où les deux chaînes **convergent** (le « bas » est déjà unifié)

| Étage | Preuve | Conséquence |
|---|---|---|
| Frontière d'acquisition (manche) | `PRG_02_Acquisition.st:434,447-483` | Le cycle consomme **le même** joystick qualifié (`PRG_03_Modes_Cycle.st:196-204`) |
| Décodage capteurs M3 | `FB_Translation_PositionDecoder`, appelé `PRG_05_Translation.st:112-118` | Un seul mot capteurs, un seul jeu de fronts |
| **Arbitre de commande** | `FB_TranslationCmdArbitrationM3`, appelé `PRG_05_Translation.st:363-372` | **Un seul point de sélection de source** (les deux branches sont dans le même FB) |
| FB de mouvement | `FB_Translation`, appelé `PRG_05_Translation.st:537-572` | **Un seul contrat d'ordre** : `RunRequest`, `ReqTremie`, `ReqMaintenance`, `SpeedTgt_Pct`, `PositionSensorTarget`, permis directionnels |
| Safety M3 | `FB_Safety_Translation`, appelé `PRG_05_Translation.st:439-472` | Un seul SafeStop/PowerCutOff |
| Barrière finale | `FB_TranslationOutputInterlock`, appelé `PRG_06_Outputs.st:434-451` | Un seul watchdog frein, un seul anti-redémarrage |
| Mots variateur | `PRG_06_Outputs.st:457-459` | **Un seul** jeu de mots physiques |

➡️ **Conclusion partielle : l'axe M3 ne reçoit PAS deux ordres.** Il reçoit un ordre produit par un arbitre unique, à partir de deux **règles** différentes selon le mode. La question de l'utilisateur est donc exacte sur le **symptôme** et inexacte sur l'**architecture**.

### 6.2 Où les deux chaînes **divergent** — avec le « pourquoi » sourcé

| # | Divergence | Manuel (`MAINT_N1/N2`) | Cycle (`SEMI_AUTO`) | Pourquoi / source |
|---|---|---|---|---|
| D01 | **Nature de l'arrêt** | `ArrivalLock` **latché** (`FB_Translation.st:180,192,196`), relâchable **uniquement** par une demande de sens inverse (`:202-204`) | **Retrait de la demande** (`FB_CycleSemiAuto.st:899` AX2, `:1386` AX14) → non latché, ré-armable | Intention de conception : `FB_CycleSemiAuto.st:879-884` (GEL SEMI_AUTO Q10 : le cycle n'émet AUCUNE commande M3 automatique, l'arrêt sur FDC P1 étant assuré par PRG_05/FB_Translation **comme en maintenance**). L'intention est l'équivalence ; l'implémentation ne l'atteint pas (D02/D03/D06) |
| D02 | **Cible d'arrêt** | `SelTarget := 0` (`FB_TranslationCmdArbitrationM3.st:87`) → `M3_PositionSensorTarget` **suit le sens** (`PRG_05_Translation.st:414-425`) | `SelTarget := ReqTranslation.PositionTgt` (`:65`) → cible **figée par l'étape** (3 en AX2, 1 en AX14) | Contradiction interne : `FB_CycleSemiAuto.st:905-906` et `PRG_05_Translation.st:404-407` affirment « la cible effective suit le sens du joystick » ; le code fait l'inverse. Source du « pourquoi » = commentaire, **non** une spec |
| D03 | **Continuité de la cible à l'arrivée** | `SelTarget` reste 0, la cible suit la demande tant qu'elle est tenue → le debounce 100 ms peut aboutir | AX2 **conserve** `PositionTgt := 3` (`:900`) → cible maintenue ; AX14 **remet `PositionTgt := 0`** (`:1387`) → cible perdue **10 ms après** le jeton | Aucune source : asymétrie AX2/AX14 = anomalie (voir §6.3, ligne « debounce ») |
| D04 | **Qui produit le sens** | Le geste/bouton opérateur, maintenu aussi longtemps qu'il veut | Le couple `SelTarget` + joystick (`FB_TranslationCmdArbitrationM3.st:75-80`) : en AX2 (`SelTarget = 3`) le sens dépend de `DirectionPositive` | `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:180-181` (intention maintenue requise) |
| D05 | **Vitesse demandée** | `SetFreq_Hz` mis à l'échelle (défaut 40 Hz, `GVL_PERSISTENT.st:98`) | **`SpeedPct := 100.0`** fixe (`FB_TranslationCmdArbitrationM3.st:74`) | `GVL_PERSISTENT.st:97` déclare `_TranslationAutoSpeedCap_Pct := 40.0` (« Plafond vitesse SEMI_AUTO ») et **aucun consommateur** n'existe → intention non implémentée |
| D06 | **Gates propres au cycle** | Aucune | Veto amont `M3_CycleTranslationStepAuthorized` (`PRG_05_Translation.st:385-395`) + veto barrière (`:656-662`) : hors AX2/AX14, mot de commande, fréquence, frein et sémantique forcés à 0 | Sécurité voulue (commentaire `PRG_05_Translation.st:381-384`, liée aux manœuvres benne AX3/AX10/AX15) |
| D07 | **Coupure dure Trémie** | Armée : `ReqTremieSemantic = M3_ReqTremie_Active` reste vrai tant que l'opérateur pousse (`PRG_06_Outputs.st:431-432,650`) | **Désarmée à l'arrivée** : le cycle retire la demande (`FB_CycleSemiAuto.st:1386`) donc `ReqTremieSemantic` tombe au même scan → la coupure dure ne s'arme pas sur le DI brut | Conséquence directe de D01 ; aucune protection dure équivalente n'existe pour **P1** (seul le substitut `M3_LimitSwitchMaintenanceEffective`, `PRG_05_Translation.st:152-154`) |
| D08 | **Escalade sécurité aux butées** | Voie `FB_Safety_Translation` cause 6 (`:200-203`, 1,5 s, `|fAct| > 0,5` ou `StatusWord.0`) puis `PowerCutOff` (masque `16#00F8`, `:268`) | Identique, **mais** dépend des mêmes latches de FdC que D07 pour s'armer | Spec `AF_Partie-11 v2.4:346-351` (escalade graduée 0 / ≥2,5 s / ≥5 s) : le code implémente **1,5 s** puis SafeStop+PowerCutOff — **écart spec/code** à signaler |
| D09 | **Bypass FdC** | Levée possible seulement si l'opérateur l'a posée | **Identique — et non filtré par le mode** : `PRG_05_Translation.st:571` lit `GVL_IHM.M3Translation.Bypass.LimitSwitch OR .Global` sans garde de mode, alors que la doctrine dit « actionnable UNIQUEMENT en MAINT_N2 » (`ST_BypassTranslation.st:4-5`) et que le bypass est **restauré au boot depuis le RETAIN** (`PRG_07_Supervision.st:230-235`) | Trou de conception : un bypass oublié **désactive le verrou d'arrivée en SEMI_AUTO** |
| D10 | **Arbitrage** | Branche `:84-113` | Branche `:63-83` | `AF_Partie-11 v2.4:270` décrit un arbitrage **par priorité** (« AU > Défaut > Cycle > Joystick > Boutons IHM MAINT ») ; le code implémente un **aiguillage exclusif par mode** (`:63` / `:84` / `:114`) → écart spec/code |

### 6.3 Conditions d'arrêt : présentes d'un côté, absentes de l'autre

| Condition d'arrêt | Manuel | Cycle | Preuve |
|---|---|---|---|
| Capteur cible + **debounce 100 ms** → `ArrivalLock` | ✅ **aboutit** : l'opérateur tient le geste bien plus de 100 ms après le front capteur | ⚠️ **AX2 : aboutit** (`PositionTgt := 3` conservé, `FB_CycleSemiAuto.st:900`) — **AX14 : n'aboutit PAS** (`PositionTgt := 0`, `:1387` → `SelTarget = 0` → cible `FALSE` car `ReqTremie` déjà retombé, `PRG_05_Translation.st:427`) ⇒ le TON est remis à zéro après **1 seul scan (10 ms)** | `FB_Translation.st:175-177` ; `ST_fbTranslation_Cfg.st:31` ; `PRG_05_Translation.st:408-429` |
| Verrou bistable FdC extrême (`11111` / `00001`) → `ArrivalLock` | ✅ (`CommandedTremie` reste vrai) | ✅ si le **sens est encore commandé** au scan du latch (`FB_Translation.st:191,195`) — vrai au 1ᵉʳ scan de l'arrivée, faux ensuite | `PRG_05_Translation.st:163,187` ; `FB_Translation.st:190-200` |
| Coupure dure Trémie (DI brut + sémantique) | ✅ | ❌ **désarmée** dès que le cycle retire la demande (D07) | `PRG_06_Outputs.st:431-432` |
| Verrou de sens « ne pas redemander la même direction » | ✅ : `ArrivalLock` bloque la re-demande du même sens, **insensible au rebond capteur** | ❌ : le cycle **re-demande** (`FB_CycleSemiAuto.st:913` / `:1383`) dès que le jeton retombe | `FB_Translation.st:202-204` |
| Escalade SafeStop / PowerCutOff | ✅ | ✅ (mêmes FdC) | `FB_Safety_Translation.st:200-203,268` |
| Veto hors étape de translation | ➖ sans objet | ✅ (propre au cycle) | `PRG_05_Translation.st:389-395,656-662` |
| **Capteur perdu pendant ≈ 1 s** (cas T287 / T300) | ✅ **l'arrêt tient** : le verrou latché ne se relâche pas sur perte capteur ; l'opérateur voit le FDC et relâche | ❌ **l'arrêt est annulé** : le jeton est la *source* de la demande → perte du jeton = nouvelle demande de marche | `FB_Translation.st:202-204` vs `PRG_05_Translation.st:275-277` + `FB_CycleSemiAuto.st:913,1383` |

### 6.4 FB traversés en plus / en moins

| FB | Manuel | Cycle | Remarque |
|---|---|---|---|
| `FB_Joystick` | ✅ source de **commande** | ✅ source de **permis + sens** (jamais de la demande) | `PRG_02_Acquisition.st:447` ; `FB_CycleSemiAuto.st:716-718` |
| `FB_TranslationCmdArbitrationM3` | ✅ branche `:84-113` | ✅ branche `:63-83` | **Convergence** |
| `FB_CycleSemiAuto` | ➖ non traversé | ✅ **en plus** (`PRG_03_Modes_Cycle.st:190-269`) | Producteur du `ST_ProgramTranslationRequest` |
| `FB_Modes` | ✅ (via `Auth`) | ✅ (via `Auth`) | `MaintenanceM3TargetEnable` = **faux en SEMI_AUTO** |
| `FB_Translation_PositionDecoder` | ✅ | ✅ | **Convergence** (jetons partagés) |
| `FB_Translation_PositionEstimator` | ✅ appelé `PRG_05_Translation.st:575-594` | ✅ appelé (même scan) | ⚠️ **Aucun** consommateur de sûreté : publié `TranslationState.EstimatedPosM3_M` (`:710`) + persisté (`:596-597`). **Aucune des deux chaînes ne consomme l'estimateur** (réponse à la question de coordination T333) |
| `FB_Safety_Translation` | ✅ | ✅ | **Convergence** |
| `FB_Translation` | ✅ | ✅ | **Convergence — le seul FB qui commande l'axe** |
| `FB_Brake` (composé) | ✅ | ✅ | `FB_Translation.st:274-288` |
| `FB_TranslationOutputInterlock` | ✅ | ✅ | **Convergence** |

### 6.5 Qualification P1 / Trémie : qui utilise quoi

| Mécanisme | Producteur | Qui l'utilise (manuel) | Qui l'utilise (cycle) |
|---|---|---|---|
| Mot capteurs `SensorsWord` (6 mots valides) | `FB_Translation_PositionDecoder.st:71-84` | `PRG_05_Translation.st:243-259,292-297,304-341` | identique (même POU) |
| Jeton de franchissement `M3_AtTremieStable` / `M3_AtP1Stable` | `PRG_05_Translation.st:266,272` | `:409,411,416,424` | `PRG_03_Modes_Cycle.st:234-236` → `FB_CycleSemiAuto.st:889,1385` |
| Niveau cumulatif `TranslationPosXxx` (ralentissement) | `FB_Translation_PositionDecoder.st:94-98` | `PRG_05_Translation.st:549,555,559` | identique (même câblage) |
| Verrou bistable FdC extrême | `PRG_05_Translation.st:163,187` | `:458,459,561,562` | `:458,459,561,562` + `PRG_06_Outputs.st:431-432` |
| DI **bruts** (P1 / Maintenance) | mapping `Device_IO_20260918.csv:454-455` | ➖ | ✅ `PRG_03_Modes_Cycle.st:237-238` → `FB_CycleSemiAuto.st:1534` (état « au-delà de P1 ») |
| **Estimateur** `PositionEstimatedM` | `FB_Translation_PositionEstimator` (`PRG_05_Translation.st:575-594`) | ❌ aucun consommateur de conduite | ❌ aucun consommateur de conduite |
| **Décodeur / estimateur propre au cycle** | — | — | ❌ **n'existe pas** : le cycle consomme les jetons du manuel |

➡️ **Le cycle ne possède aucune qualification de position qui lui soit propre.** Il réutilise intégralement les jetons produits par `PRG_05`. Toute fragilité des jetons se propage donc **à l'identique** aux deux chaînes — mais avec des **conséquences opposées** : en manuel le jeton ne sert qu'à *arrêter* (verrou latché), en cycle il sert aussi à *démarrer*.

---

## 7. 🏁 PARTIE 4 — VERDICT ARGUMENTÉ

### 7.1 Verdict : **ANOMALIE** (avec une part obligatoire clairement délimitée)

| Constituant de la divergence | Verdict | Fondement |
|---|---|---|
| Deux **sources** de commande (opérateur / cycle) | 🟢 **OBLIGATOIRE** — c'est l'architecture voulue | `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:179` (« Le cycle produit des demandes de mouvement, jamais des sorties physiques directes ») ; `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:180` (intention maintenue) ; `AF_Partie-02_Architecture_Programme_v3.2.md:220` (`PRG_03` = cerveau décisionnel unique, « Produit des demandes sur `Data` ; ne commande aucune sortie directe ») ; `AF_Partie-02_Architecture_Programme_v3.2.md:222` (`PRG_05` = « arbitrage final translation ») |
| Deux **règles** dans un arbitre unique, au lieu d'un arbitrage par priorité | 🟠 **ANOMALIE (écart spec/code)** | `AF_Partie-11 v2.4:270` prescrit une priorité (« AU > Défaut > Cycle > Joystick > Boutons IHM MAINT ») ; `FB_TranslationCmdArbitrationM3.st:63,84,114` implémente un aiguillage exclusif par mode |
| Deux **mécanismes d'arrêt** (verrou latché vs retrait de demande) | 🔴 **ANOMALIE de conception** — c'est la cause structurelle du symptôme | Contredit `AF_Partie-02_Architecture_Programme_v3.2.md:502` (« **Commande arbitrée** : une commande unique par mouvement, après arbitrage des sources et interlocks métier ») et `CODE_QUALITY_STANDARDS.md:522-523` (« Producteur unique. Une donnée/commande a **un seul** POU qui l'écrit ») : ici la **décision d'arrêt** a deux producteurs de nature différente (le verrou du FB en manuel, la disparition de la demande en cycle) |
| Contrat d'interface FB : demande vs commande finale unique | 🔴 **ANOMALIE (contrat AF-03)** | `AF_Partie-03_Contrats_Composants_v2.3.md:303` (« Demande : porte une intention brute sourcée ou une commande **déjà arbitrée**, jamais les deux sans distinction ») et `:305` (« Commande mouvement : porte la **commande finale unique du mouvement après arbitrage** ») : la commande finale unique existe bien (`FB_Translation`), **mais l'ordre d'arrêt ne l'est pas** ; `:341` (« Les commandes ne se croisent pas : tout arbitrage est réalisé par un composant propriétaire, exposé et nommé ») — en cycle, le séquenceur influence directement la **durée** de la commande via un jeton, ce qui croise les deux niveaux |
| Cible d'arrêt **figée par l'étape** au lieu du sens | 🔴 **ANOMALIE** (et contradiction avec ses propres commentaires) | `FB_CycleSemiAuto.st:905-906`, `PRG_05_Translation.st:404-407` vs `FB_TranslationCmdArbitrationM3.st:65` + `PRG_05_Translation.st:408-429` |
| Asymétrie AX2 (`PositionTgt` conservé) / AX14 (`PositionTgt := 0`) | 🔴 **ANOMALIE pure** (aucune source, aucun commentaire ne la justifie) | `FB_CycleSemiAuto.st:900` vs `:1387` |
| Plafond de vitesse SEMI_AUTO non appliqué | 🟠 **ANOMALIE** (config morte) | `GVL_PERSISTENT.st:97` (0 lecteur) vs `FB_TranslationCmdArbitrationM3.st:74` |
| Bypass FdC non filtré par le mode, restauré au boot | 🟠 **ANOMALIE** (contredit la doctrine du DUT) | `PRG_05_Translation.st:571` ; `ST_BypassTranslation.st:4-5` ; `PRG_07_Supervision.st:230-235` |
| Escalade butées 1,5 s au lieu de 2,5 / 5 s | 🟡 **ÉCART SPEC/CODE** (sûreté : le code est **plus** permissif en durée, mais déclenche un `PowerCutOff` là où la spec prévoit d'abord un `SafeStop` seul) | `AF_Partie-11 v2.4:346-351` vs `FB_Safety_Translation.st:200-203,268` ; `FB_Translation.st:123-129` |

**Réponse synthétique à l'utilisateur** : non, la séparation des demandeurs n'est pas une anomalie — c'est l'architecture. Oui, il y a une anomalie : **l'axe ne possède pas l'arrêt**. En manuel l'arrêt appartient à l'axe (verrou latché, insensible au rebond capteur) ; en cycle il appartient au séquenceur (retrait d'une demande, donc réversible par un rebond). C'est **modifiable sans casser l'architecture** : la cible du §5 de cette fiche.

### 7.2 Proposition d'unification — **en principe, pas en code**

> ⛔ Aucune de ces évolutions n'est implémentée ni prescrite ici : elles supposent un contrat C3, un plan validé et une validation humaine du présent comparatif (exigence explicite de `TASKS.yaml:29`).

1. **L'axe possède l'arrêt** (producteur unique) : `ArrivalLock` (ou son remplaçant) doit être **armé par la détection d'arrivée** — capteur cible **ou** FdC — **indépendamment de la présence d'une demande**. Le verrou est **latché** dans tous les modes, et son seul relâchement reste une demande **explicite** de sens inverse (`FB_Translation.st:202-204` conservé).
2. **La cible d'arrêt suit le sens commandé, pas l'étape** : `M3_PositionSensorTarget` doit être dérivé de la direction réellement appliquée (`CommandedTremie`/`CommandedMaintenance`), la cible d'étape (`PositionTgt`) ne servant qu'à **valider** (autoriser/interdire) et non à figer la cible. Corrige D02/D03 et rend AX2 ≡ AX14 ≡ manuel.
3. **Le demandeur ne fait que demander** : l'arbitre publie **un seul** contrat d'ordre (`RunRequest`, sens, `SpeedPct`, cible d'arrivée) ; les deux branches (manuel/cycle) remplissent **le même** contrat ; la décision d'arrêt reste dans l'axe. C'est exactement `AF_Partie-02_Architecture_Programme_v3.2.md:502` et `CODE_QUALITY_STANDARDS.md:530-540` (« Commandes arbitrées avant l'appel »).
4. **Retrait de demande ≠ arrêt** : quand le cycle n'a plus besoin de M3, il doit soit **attendre la confirmation d'arrêt** de l'axe (déjà disponible : `Data.TranslationDone`/`TranslationBusy`, `PRG_05_Translation.st:817-818`), soit laisser la barrière finale **commander** l'arrêt au lieu de mettre le mot de commande à 0 (le mot 0 = **roue libre** côté variateur, cf. §6.2 D01).
5. **Bypass gated par mode** : les bypass FdC consommés par l'axe doivent être neutralisés hors `MAINT_N1/N2` (ou non restaurés au passage en SEMI_AUTO), conformément à `ST_BypassTranslation.st:4-5`.
6. **Config morte à réactiver ou à supprimer** : `_TranslationAutoSpeedCap_Pct` (`GVL_PERSISTENT.st:97`), `M3_PositioningActive` (`PRG_05_Translation.st:45,373`), `TonM3ConfirmedMoving.Q` (`PRG_05_Translation.st:80,201`), `instCycleSemiAuto.SelTarget` (`FB_CycleSemiAuto.st:32`). En l'état : violation de `CODE_QUALITY_STANDARDS.md:507-513` (« code et variables mortes »).
7. **Un seul arbitrage par priorité** (ou une justification écrite de l'aiguillage par mode) : trancher l'écart avec `AF_Partie-11 v2.4:270` — soit le code, soit la spec.

### 7.3 Criticité de l'anomalie
**C3 confirmée.** L'arrêt d'un axe de translation de 30 m n'est pas garanti par une propriété latchée en mode automatique : une perte capteur au point d'arrêt peut rendre la main au mouvement. Aucune des protections dures existantes ne couvre **P1** (le substitut `M3_LimitSwitchMaintenanceEffective` n'est qu'un cran logique, `PRG_05_Translation.st:149-151`), et la coupure dure **Trémie** est désarmée par le cycle lui-même (D07).

---

## 8. 🌳 Arbre des causes — hypothèses de dépassement P1/Trémie en cycle

> ⚠️ **Aucune cause racine n'est affirmée** : aucune trace 10 ms M3 n'existe. Les 3 hypothèses ci-dessous sont **sourcées par le code** et **discriminables par la trace du §9**. Étiquetage des preuves : 🟢 prouvé par le code · 🟡 cohérent, à confirmer par trace.

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Verdict |
|---|---|---|---|---|
| **H1** 🟢 | **Le rebond/perte capteur à l'arrivée efface le jeton, et le cycle RECRÉE la demande de marche.** Trémie : le front **descendant** du capteur Trémie ne produit **aucun** `TranslationAtTremie` (`FB_Translation_PositionDecoder.st:113` = montant seul) → la chaîne `ELSIF` tombe sur `M3_SensorsWordChanged` → **RAZ de tous les jetons** (`PRG_05_Translation.st:275-277`) → `Translation_At_Tremie` retombe → AX14 **re-arme** `ReqStart := TranslationTremiePermit` (`FB_CycleSemiAuto.st:1383`) ⇒ **le chariot repart**, une fois par rebond, pendant toute la durée du rebond (≈1 s mesuré par T287). P1 : le jeton survit aux fronts P1 (`:116` = 2 fronts) mais est effacé par **exclusion mutuelle** dès qu'un **autre** capteur produit un front (`PRG_05_Translation.st:265-274` : chaque branche remet les 4 autres jetons à FALSE) → AX2 re-arme `ReqStart` (`FB_CycleSemiAuto.st:913`) ⇒ même effet | `Data.ReqProgram.ReqTranslation.ReqStart`, `Data.M3_AtTremieStable`, `Data.M3_AtP1Stable`, `instPosDecoderM3.SensorsWord`, `M3_SensorsWordChanged` | `ReqStart` doit rester **FALSE** tant que le chariot est au point d'arrêt et le geste maintenu ; le cycle ne doit pas recréer une demande sur perte de jeton (`AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md:179`) | 🟡 **à confirmer** — c'est l'hypothèse principale |
| **H2** 🟢 | **Aucun verrou d'arrêt n'est armé côté cycle à l'arrivée Trémie (AX14).** `PositionTgt := 0` (`FB_CycleSemiAuto.st:1387`) ⇒ `SelTarget = 0` ⇒ `M3_PositionSensorTarget := FALSE` car `M3_ReqTremie_Active` vient d'être retiré (`PRG_05_Translation.st:414-427`) ⇒ le `TON` de debounce (100 ms, `ST_fbTranslation_Cfg.st:31`) est remis à zéro après **1 scan** ⇒ pas d'`ArrivalEdge` ⇒ pas d'`ArrivalLock` par la voie capteur. Reste la voie **FdC** (`FB_Translation.st:190-200`), qui exige `NOT BypassLimitSwitch` : or `BypassLimitSwitch := GVL_IHM.M3Translation.Bypass.Global OR .LimitSwitch` (`PRG_05_Translation.st:571`), **non filtré par le mode** et **restauré au boot** (`PRG_07_Supervision.st:230-235`) ⇒ si un bypass traîne (session MAINT_N2 précédente), **il ne reste aucun verrou** | `instTranslationM3.ArrivalLock`, `.CaptorDebounceTon.ET/.Q`, `GVL_IHM.M3Translation.Bypass.LimitSwitch`, `.Bypass.Global` | `ArrivalLock = TRUE` dans les 150 ms suivant le front capteur, quel que soit le mode (source : `FB_Translation.st:175-204` — c'est le comportement obtenu en manuel) | 🟡 **à confirmer** — explique POURQUOI H1 a un effet au lieu d'être bloquée |
| **H3** 🟢 | **Vitesse d'arrivée plus élevée en cycle** (aggravant, pas causal seul) : `SpeedPct := 100.0` (`FB_TranslationCmdArbitrationM3.st:74`) et **aucun** plafond appliqué (`_TranslationAutoSpeedCap_Pct = 40 %`, `GVL_PERSISTENT.st:97`, 0 lecteur) vs `SetFreq_Hz = 40 Hz` en manuel (`GVL_PERSISTENT.st:98`, `PRG_07_Supervision.st:211`) ⇒ à échelle max (`_TranslationMaxFreq_Hz = 50 Hz`, `GVL_PERSISTENT.st:86`) la distance d'arrêt croît en v² : **≈ +56 %**. Les ralentissements d'approche **s'appliquent bien** en SEMI_AUTO (`SlowdownSensorP1`, `PRG_05_Translation.st:559-560`, car `MaintenanceM3TargetEnable` est **toujours faux** en SEMI_AUTO — `FB_Modes.st:413`) : H3 n'explique donc l'écart que si la zone de ralentissement est manquée ou si la config des 3 vitesses est modifiée | `PRG_05_Translation.st:547` (`SpeedTgt_Pct` = 100), `Data.TranslationState.SpeedCmd_Pct`, `M3_SetpointFrequencyHz` vs `ApproachSpeedP1Hz`/`ApproachSpeedTremieHz` (10 Hz), `instTranslationM3.SpeedRamp.Current` | `SpeedCmd_Pct = 100` en cycle ; `SetpointFrequencyHz ≤ 10 Hz` dès l'entrée dans la zone PV / P2→P1 (source : `FB_Translation.st:308-313`) | 🟡 **à confirmer** — aggravant quantifiable |
| **H4** 🟢 | **Le mot de commande tombe à 0 (roue libre) au lieu d'une consigne d'arrêt** : le cycle retire la demande → `FB_Translation.st:229-233` remet `CommandedTremie/Maintenance := FALSE` → `:297-303` ⇒ `RequestedDriveControlWord := 0`. Le variateur perd le sens : la rampe PLC n'est plus suivie, le chariot **décélère en roue libre** (trace 04/09 : 22,8 Hz/s, `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:96`) au lieu de 25 Hz/s par la rampe (50 %/s de 50 Hz, `GVL_PERSISTENT.st:95`). Écart faible en décélération, mais **disparition de la direction** ⇒ toute ré-assertion ultérieure relance immédiatement | `instTranslationM3.CommandedMaintenance`, `.RequestedDriveControlWord`, `M3_CommandWord`, `M3_ActualFrequencyHz` | mot de commande **1 ou 2 avec fréquence décroissante** pendant toute la décélération (comportement manuel), pas `0` dès le 1ᵉʳ scan | 🟡 **à confirmer** — mécanisme d'aggravation, cohérent avec T287 (frein) |
| H5 🟢 | **Faux départ / re-commande par l'étape suivante** : si `Translation_Busy` (`PRG_05_Translation.st:817`, seuil `|fAct| > 0,5 Hz`) passe à FALSE alors que le chariot bouge encore (retour PDO indisponible ou retard), `TranslationStopTimer` (`FB_CycleSemiAuto.st:334-338`) confirme en 500 ms et l'étape avance (AX3 / AX15A) ⇒ le veto `M3_CycleTranslationStepAuthorized` (`PRG_05_Translation.st:389-395`) neutralise M3 ⇒ roue libre au-delà du point | `Data.TranslationBusy`, `Data.SequenceState.Step`, `M3_CycleTranslationStepAuthorized`, `HwIn.Translation.M3_ActualFrequencyHz` | `Translation_Busy = TRUE` jusqu'à `fAct ≤ 0,5 Hz` ; l'étape ne change **jamais** avant l'arrêt physique | 🟡 **à confirmer** — branche indépendante de H1/H2 |
| H6 🟢 | **Défaut cause 6 prématuré côté Safety sur le substitut P1** : en SEMI_AUTO, `M3_LimitSwitchMaintenanceEffective` = mot `00001` = **tout dépassement de P1** (`PRG_05_Translation.st:152-154`) ; si le chariot reste commandé > 1,5 s au-delà (H1), `FB_Safety_Translation.st:200-203` lève la cause 6 ⇒ bit 6 `16#0040` inclus dans le masque `PowerCutOff` (`:268`) ⇒ **coupure générale** + frein fermé sur chariot en mouvement — c'est très exactement `T287` (« récidive du défaut séquence/retour frein M3 aux arrivées Trémie et P1 ») | `instSafetyTranslationM3.ErrorLimitSwitch`, `.PowerCutOff`, `.Fault.ErrorId`, `Data.TranslationState.FinalInterlockError` | aucun `ErrorLimitSwitch`/`PowerCutOff` sur une arrivée nominale (source : `AF_Partie-11 v2.4:349` — « 0 s à < 2,5 s : arrêt directionnel seul, pas d'alarme latched ») | 🟡 **à confirmer** — conséquence observable, pas cause |

**Résumé une ligne (chaîne causale la plus probable) :**
`[capteur 0↔1 au point d'arrivée] → [jeton AtXxx=FALSE : PRG_05:275-277 ou exclusion mutuelle :265-274] → [cycle RecStart=TRUE : FB_CycleSemiAuto:913/1383] → [Verrou d'arrêt absent : ArrivalLock=FALSE] → [chariot repart] → [dépassement P1] → [cause 6 + PowerCutOff + frein fermé en mouvement]`

### 🔗 Lien avec T287 — noté sur GO CC01 (2026-09-20)

**H1 rejoint potentiellement la cause de T287** (« Régression M3 sur butées — escalade graduée sans toucher `FB_Brake` », `DOC/WFLOW/TASKS.yaml:1247`, porteur CDX01) : T287 documente une **récidive du défaut séquence/retour frein M3 aux arrivées Trémie ET P1**, avec une trace réelle montrant des **commutations capteur `0↔1` rapides pendant environ 1 s** (`TASKS.yaml:1248-1250`) et une cause exacte « encore à prouver par la trace réelle » (`TASKS.yaml:1261`).

| Élément | T334 (H1) | T287 | Recouvrement |
|---|---|---|---|
| Lieu | arrivées P1 (AX2) et Trémie (AX14) | arrivées Trémie **et P1** | ✅ identique |
| Signal | jeton d'arrivée effacé par rebond capteur → demande recréée | commutations capteur `0↔1` ≈ 1 s | ✅ même signal d'entrée |
| Effet | dépassement + `CommandWord := 0` (roue libre) + frein fermé sur chariot en mouvement | défaut séquence / **retour frein** | ✅ la chaîne H1 → **H4/H6** produit exactement ce défaut |
| Statut | hypothèses H1-H6, **non prouvées** (aucune trace 10 ms) | cause exacte non prouvée (trace à 100 ms) | ⚠️ **même verrou de preuve** |

➡️ **Conséquence pratique** : la campagne du §9 (procédure `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md`) trace **explicitement** les canaux dont T287 a besoin — `instTranslationM3.Brake.BrakeCmd`, `M3_BrakeIsOpen_DI`, `PRG_06_Outputs.M3_TremieHardStopActive`, `instTranslationOutputInterlockM3.BrakeTimeoutElapsed`, `instTranslationM3.ArrivalLock`, plus les 5 DI et les fronts du décodeur. **Une seule campagne sert les deux tâches** ; le porteur read-only de T287 réutilise la trace telle quelle. Le scénario B (intermittence ≈ 1 s) est précisément le stimulus que T287 cherche à reproduire. **Aucune correction de T287 n'est faite dans ce lot** (devoir d'alerte, pas d'élargissement).

---

## 9. 📊 Variables EXACTES à tracer à 10 ms (preuve de H1→H6)

> Base : `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T300_M3_SIMBENCH.md:9` (trace **tâche 10 ms** obligatoire : « une trace à 100 ms ne peut pas qualifier un délai de frein de 90 ms »), `:28-42` (étages de preuve), `:44-56` (variables minimales). Les ajouts **T334** sont les lignes marquées 🆕 — sans elles, aucune des 6 hypothèses n'est discriminable.
> 🚀 **Campagne prête à exécuter (GO CC01 2026-09-20)** : `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` — liste des canaux à copier telle quelle (groupes A à G), réglage de la trace, les 3 scénarios A/B/C, la matrice de décision signature → hypothèse, et le post-traitement `trace_to_csv.py`. La présente section en est le **résumé décisionnel** ; la procédure est le mode opératoire.
> ✅ **Faisabilité des internes VÉRIFIÉE** (ne plus la supposer) : les traces existantes du dépôt enregistrent déjà des internes d'instance par chemin pointé, y compris imbriqués — `PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedTgt`, `PRG_02_Acquisition.instJoystick.ArmingPermit`, `PRG_04_Treuils_Benne.Data.WinchM1State.DirectionChangePending`, `PRG_02_Acquisition.instSimBench.instWinchElectricalM1.Slip_Ratio` (relevé dans `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_treuils_charge_v1.txt:25,29,84,105`). Les chemins `PRG_05_Translation.instTranslationM3.*` et `instArbM3.*` sont donc traçables. ⚠️ Ces internes restent **interdits à la lecture par du code** (`CODE_QUALITY_STANDARDS.md:526-527`) : ils ne servent qu'à la preuve de diagnostic.
> 📉 **Ce que les traces existantes ne peuvent PAS donner** (mesuré, pas supposé) : `Suivi_Cycle_M3_20260906_49.trace` = 15 canaux, 367 échantillons, **dt min 77 ms / médian 100 ms / max 128 ms** (39 valeurs distinctes), sans aucun jeton ni interne d'axe ; les 5 traces `Suivi_66..70_SIMU_MaintMANU_20260919.trace` = 54 à 58 canaux **exclusivement treuils + joystick Y**, **aucune variable M3**. Aucune des trois expériences du protocole n'existe donc dans le dépôt, et la comparaison manuel ↔ cycle n'a **jamais** été tracée.

### A. Ordre demandé et mode (discrimine H1)
| Variable | Rôle dans la preuve |
|---|---|
| `PRG_03_Modes_Cycle.Data.SequenceState.Step` | Étape courante — doit rester AX2 (ou AX14) pendant toute la séquence d'arrivée |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart` 🆕 | **LA variable décisive de H1** : toute transition 1→0→1 à l'arrivée = demande recréée |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt` 🆕 | Doit rester 3 en AX2 (D03) ; passe à 0 en AX14 à l'arrivée (H2) |
| `PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationStopTimer.Q` 🆕 | Confirmation d'arrêt (500 ms) avant changement d'étape (H5) |
| `PRG_03_Modes_Cycle.instCycleSemiAuto.CycleMotionPermit` 🆕 | Permis opérateur continu (repli §4 du FB) |
| `PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationP1Permit` / `.TranslationTremiePermit` 🆕 | Condition exacte de `ReqStart := TRUE` |
| `GVL_IHM.CycleSemiAuto.State.CycleStep` | Miroir IHM de l'étape (lisibilité de la trace) |

### B. Arbitrage M3 (discrimine H1/H2)
| Variable | Rôle |
|---|---|
| `PRG_05_Translation.SelTarget` 🆕 | 3 en AX2, 1 en AX14, 0 après retrait de cible → pilote la cible d'arrêt |
| `PRG_05_Translation.M3_RunRequest_Active` 🆕 | Demande effectivement appliquée à `FB_Translation` |
| `PRG_05_Translation.M3_ReqTremie_Active` / `.M3_ReqMaintenance_Active` 🆕 | Sens appliqué + condition d'armement du FdC et de la coupure dure |
| `PRG_05_Translation.M3_SpeedCmd_Active` 🆕 | 100 % en cycle vs 40 Hz équivalents en manuel (H3) |
| `PRG_05_Translation.M3_PositionSensorTarget` 🆕 | **Cible d'arrêt réellement présentée au FB** |
| `PRG_05_Translation.M3_CycleTranslationStepAuthorized` 🆕 | Veto SEMI_AUTO (H5) |
| `PRG_05_Translation.M3_PositioningActive` 🆕 | Preuve expérimentale de la variable morte (§7.2-6) |

### C. Capteurs et qualification de position (discrimine H1)
| Variable | Rôle |
|---|---|
| `PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI` | Front d'arrivée Trémie (DI qualifié) |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI` | Zone de ralentissement Trémie |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI` | Capteur **P2** (`DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:20-22`) |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI` | Front d'arrivée P1 + seuil du substitut FdC |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI` | Mot `00000` / zone Maintenance |
| `PRG_05_Translation.instPosDecoderM3.SensorsWord` | **Mot thermomètre** (frontière de toutes les qualifications) |
| `PRG_05_Translation.instPosDecoderM3.Incoherent` | Détection de mot invalide (rebond multi-capteurs) |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtTremie` / `.TranslationAtP1` / `.TranslationAtP2` / `.TranslationAtPV` / `.TranslationAtMaintenance` 🆕 | **Fronts** (1 scan) : prouve que la Trémie n'a **qu'un** front (H1) |
| `PRG_05_Translation.M3_SensorsWordChanged` 🆕 | **RAZ de tous les jetons** — la bascule exacte de H1 |
| `PRG_05_Translation.M3_AtTremieStable` / `.M3_AtP1Stable` / `.M3_AtPVStable` / `.M3_AtP2Stable` / `.M3_AtMaintenanceStable` 🆕 | Jetons latchés (exclusion mutuelle) |
| `PRG_05_Translation.M3_LimitSwitchTremieStable` / `.M3_LimitSwitchMaintenanceStable` 🆕 | Verrous FdC bistables |
| `PRG_05_Translation.M3_LimitSwitchMaintenanceEffective` 🆕 | Substitut FdC pour P1 (mot `00001`) |

### D. Le verrou d'arrêt — le cœur du diagnostic (discrimine H2/H4)
| Variable | Rôle |
|---|---|
| `PRG_05_Translation.instTranslationM3.CaptorDebounceTon.ET` / `.Q` 🆕 | **Le debounce atteint-il 100 ms ?** (H2 : non en AX14) |
| `PRG_05_Translation.instTranslationM3.TargetReached` 🆕 | Sortie du debounce |
| `PRG_05_Translation.instTranslationM3.ArrivalEdge.Q` 🆕 | Front d'arrivée — s'il ne se produit jamais, `ArrivalLock` ne s'arme pas |
| `PRG_05_Translation.instTranslationM3.ArrivalLock` 🆕 | **LA variable de preuve de H2** : 0 pendant l'avance = aucun verrou |
| `PRG_05_Translation.instTranslationM3.ArrivalWasTremie` / `.ArrivalWasMaintenance` 🆕 | Sens mémorisé (condition de relâche) |
| `PRG_05_Translation.instTranslationM3.CommandedTremie` / `.CommandedMaintenance` 🆕 | Sens réellement appliqué (H4 : tombe à 0 au retrait de demande) |
| `PRG_05_Translation.instTranslationM3.DirectionChangePending` 🆕 | Interlock de changement de sens (faux arrêts) |
| `PRG_05_Translation.instTranslationM3.RampTargetPct` / `.SpeedRamp.Current` 🆕 | Cible et sortie de rampe (100 % → 0) |
| `PRG_05_Translation.instTranslationM3.EffectiveSafeStop` 🆕 | Gate de sens (`SafeStop` OU sens non permis) |
| `PRG_05_Translation.instTranslationM3.MovementRequested` / `.Brake.BrakeCmd` 🆕 | Séquence frein interne (T287) |
| `PRG_05_Translation.instTranslationM3.OverrunLimitSwitch` / `.TonLimitSwitchOverrun.Q` 🆕 | Cause 6 locale du FB (1,5 s) |

### E. Barrière finale et mots variateur (preuve de l'effet physique)
| Variable | Rôle |
|---|---|
| `PRG_06_Outputs.M3_TremieHardStopActive` 🆕 | Coupure dure Trémie : **armée ou non** au moment du dépassement (D07) |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` 🆕 | Mot validé (0 = roue libre — H4) |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmdWord` 🆕 | Consigne validée (×100) |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCmd` 🆕 | Ordre frein validé |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.Reason` / `.Fault.Error` / `.Fault.ErrorId` 🆕 | Cause de blocage de la barrière (watchdog frein 500 ms) |
| `PRG_06_Outputs.M3_CommandWord` / `.M3_SetpointFrequencyHz` (ou `GVL_IHM.IoHw.Out.*`, `PRG_07_Supervision.st:526-527`) | Mots réellement écrits vers `%QW6` / `%QW7` |
| `PRG_06_Outputs.Data.TranslationBrakeCmd` | Demande frein arbitrée (bus inter-PRG) |
| `PRG_02_Acquisition.HwIn.Translation.M3_ActualFrequencyHz` | Vitesse réelle (×100) — seule preuve d'un chariot **en mouvement** |
| `PRG_02_Acquisition.HwIn.Translation.M3_StatusWord` | État variateur |
| `PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI` | Retour frein physique (distinct de la commande) |

### F. Sécurité, diagnostic et contexte de gating
| Variable | Rôle |
|---|---|
| `PRG_05_Translation.instSafetyTranslationM3.SafeStop` / `.PowerCutOff` / `.ErrorLimitSwitch` / `.Fault.ErrorId` + `.LatchedId` 🆕 | Escalade butées (H6) |
| `PRG_05_Translation.Data.TranslationState.Error` / `.ErrorId` | Défaut du FB de mouvement (cause 6 local, `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:66`) |
| `PRG_05_Translation.Data.TranslationState.FinalInterlockState` / `.FinalInterlockReason` / `.FinalInterlockError` 🆕 | État de la barrière |
| `PRG_05_Translation.Data.TranslationTrace.BlockReason` / `.BlockReasonTimestamp` 🆕 | Cause priorisée de blocage (lecture terrain) |
| `GVL_IHM.M3Translation.Bypass.LimitSwitch` / `.Global` / `.SensorIncoherent` 🆕 | **H2** : un bypass actif annule le verrou d'arrivée |
| `GVL_IHM.Modes.Cmd.TglJoystickMaster` | Source de commande (joystick maître vs boutons) |
| `GVL_IHM.M3Translation.Cmd.BtnTremie` / `.BtnMaintenance` / `.SetFreq_Hz` | Comparaison manuel/cycle à geste identique |
| `PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive` / `.DirectionNegative` / `.AtNeutral` / `PRG_02_Acquisition.Data.Joystick.DeadmanArmed` | Geste réellement tenu (réfute « l'opérateur a relâché ») |

### G. Pour la reproduction banc (si la trace terrain reste indisponible — dépendance T300)
| Variable | Rôle |
|---|---|
| `GVL_Simulation.SimM3SensorIntermittenceActive` / `.SimM3SensorStabilizationS` / `.SimM3SensorIntermittencePeriodS` / `.SimM3SensorHysteresis_M` / `.SimM3SensorScenarioSeed` | Injection déterministe de la perte capteur ≈1 s (`PROCEDURE_TRACE_T300_M3_SIMBENCH.md:15-21`) |
| `GVL_Simulation.SimulationModeActive` / `.SimTranslationActive` | Préconditions (activation par **front**, `:8`) |
| `GVL_Simulation.SimM3SensorsWordOverrideActive` | Doit rester **FALSE** (`:24`) |
| `PRG_02_Acquisition.instSimBench.instSimTranslation.PositionTrue_M` / `.LoadAngle_Rad` | Repère mécanique interne (jamais un oracle de sûreté, `:36`) |
| `GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget` / `GVL_IHM.CycleSemiAuto.Cmd.BtnForceStepApply` 🆕 | Forcer **AX2** / **AX14** de façon déterministe (rejouer le cas sans refaire tout le cycle) |

### H. Protocole de trace (à respecter pour que la preuve soit recevable)
1. **Tâche 10 ms** (MainTask), période réelle relevée et archivée avec la trace (`PROCEDURE_TRACE_T300_M3_SIMBENCH.md:9-10`).
2. **Déclenchement** : sur `Data.SequenceState.Step` entrant en AX2 (ou AX14) **et** sur le front du capteur d'arrivée ; capture ≥ 3 s avant / ≥ 3 s après l'arrivée.
3. **Scénario A (référence)** : arrivée nominale, capteur propre, geste maintenu. **Scénario B (défaut)** : même arrivée avec intermittence capteur ≈1 s (`§G`). **Scénario C (manuel)** : même arrivée en `MAINT_N1` au jog, pour la comparaison directe exigée par le constat utilisateur.
4. **Décision** (matrice) :
 - `ReqStart` 0→1 pendant l'avance + `AtXxx` 1→0 ⇒ **H1 confirmée** (cause du dépassement).
 - `ArrivalLock` jamais à 1 alors que `AtXxx` a été à 1 ⇒ **H2 confirmée** ; si `Bypass.LimitSwitch/Global` = 1 ⇒ **cause aggravante identifiée** (D09).
 - `CommandedMaintenance` 1→0 au même scan que `ReqStart` 1→0 et `M3_CommandWord` 2→0 ⇒ **H4 confirmée**.
 - `SpeedCmd_Pct` = 100 et `SetpointFrequencyHz` > vitesse d'approche **dans** la zone ⇒ **H3 confirmée**.
 - `ErrorLimitSwitch` ou `PowerCutOff` sans dépassement réel ⇒ **H6** (et rapprochement T287).
5. **Archi** : joindre révision Git, date, période effective, scénario, mode, réglages de simulation (`PROCEDURE_TRACE_T300_M3_SIMBENCH.md:10`).
6. **Si aucune trace terrain n'est possible** : la reproduction passe par le banc (dépendance **T300 P-A**, `TASKS.yaml:40`) — ⚠️ le banc actuel est **structurellement incapable** de reproduire le défaut frein/cause 6 (`DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:244`, C4) : un PASS banc ne vaudra pas non-régression du terrain.

---

## 10. 🚨 Devoir d'alerte — constats hors scope (signalés, **non corrigés**)

| # | Constat | Emplacement | Impact |
|---|---|---|---|
| A01 | **Contrat de tâche T334 inexistant** alors que `TASKS.yaml:38` le référençait | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` (absent en phase 1) | ✅ **CONSTAT LEVÉ le 2026-09-20 sur GO CC01** : contrat C3 créé par DSH07, `check_task_contract.py` → **PASS (0 erreur, 0 avertissement)**. La phase 1 avait été menée sur les critères AC1-AC5 du brief d'origine |
| A02 | `M3_PositioningActive` écrite, **jamais lue** | `PRG_05_Translation.st:45,373` | Variable morte (`CODE_QUALITY_STANDARDS.md:507-513`) |
| A03 | `TonM3ConfirmedMoving.Q` **jamais lu** : le « mouvement confirmé soutenu ≥ 1,5 s » **affirmé en commentaire** (`PRG_05_Translation.st:76-79,198-199`) n'est **pas implémenté** (seul le niveau instantané `:200` est utilisé) | `PRG_05_Translation.st:80,201` vs `:217,239,295,301` | Écart commentaire/implémentation sur une garde anti-rebond **revendiquée** |
| A04 | `_TranslationAutoSpeedCap_Pct = 40 %` (« Plafond vitesse SEMI_AUTO ») **jamais consommé** | `GVL_PERSISTENT.st:97` | Config morte ; le cycle tourne à 100 % (`FB_TranslationCmdArbitrationM3.st:74`) |
| A05 | `FB_CycleSemiAuto.SelTarget` déclaré « RESERVE », câblé mais « non consomme » | `FB_CycleSemiAuto.st:32` ; câblé `PRG_03_Modes_Cycle.st:209` | Entrée morte du séquenceur |
| A06 | Bypass FdC **non filtré par le mode** et **restauré au boot** depuis le RETAIN, alors que la doctrine du DUT dit « UNIQUEMENT en MAINT_N2 » | `PRG_05_Translation.st:571` ; `ST_BypassTranslation.st:4-5` ; `PRG_07_Supervision.st:230-235` | Un bypass oublié désactive le verrou d'arrivée **en SEMI_AUTO** (H2) |
| A07 | Escalade butées **1,5 s** + `PowerCutOff` immédiat par masque, alors que la spec prévoit 0 / ≥2,5 s (SafeStop) / ≥5 s (PowerCutOff) | `FB_Safety_Translation.st:200-203,268` ; `FB_Translation.st:123-129` vs `AF_Partie-11 v2.4:346-351` | Écart spec/code sur un seuil de sûreté |
| A08 | `FB_CycleSemiAuto` contient une branche de récupération « M3 au-delà de P1 » **déjà écrite** | `FB_CycleSemiAuto.st:1534-1545` | Confirme que le dépassement de P1 est un état **connu** du séquenceur : le présent diagnostic en propose les mécanismes |
| A09 | Aucune trace 10 ms M3 dans le dépôt ; la seule trace M3 disponible est à **dt médian 100 ms** | `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/` ; `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:40` | Toute conclusion sur des délais < 150 ms est impossible aujourd'hui (§9) |
| A10 | Course sur l'identité dans `DOC/WFLOW/TASK_LOCKS.json` : deux sessions ont visé « le premier tag libre » à ~2 s d'intervalle (T330 a pris **DSH06** à 15:54:05 ; T334 a pris **DSH07**) ; `DSH01` reste **contaminé** (≥6 sessions, note CC01) et des entrées `DSH01` subsistent dans `TASKS.yaml` / `TASKS_ORCHESTRATOR.yaml` | `DOC/WFLOW/TASK_LOCKS.json` ; `TASKS.yaml:46,86,164` ; `TASKS_ORCHESTRATOR.yaml` (nombreuses entrées `agent_id: "DSH01"`) | Traçabilité d'attribution non fiable ; **tri à faire par l'orchestrateur** (aucune réécriture automatique de ma part) |
| A11 | Horloges de session **désynchronisées** (des entrées du registre portent des horodatages 3-4 min en avance sur l'horloge locale de cette session) | `DOC/WFLOW/TASK_LOCKS.json` `updated_at` vs `Get-Date` local | Ordre chronologique du registre non fiable au-delà de la minute |
| A12 | `git status --short` contient des artefacts **hors T334** : `M CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st` (mtime 15:56:18 — périmètre **verrouillé T333/DSH02**, confirmé par le guard `TOOLS/AGENT_WORKFLOW/scripts/G488_check_estimator_sensor_edges.py` non suivi), `M CODE_XML/*`, `M TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` + `M TOOLS/TEST_AUTO_CI/scripts/config/registry.yaml` + `?? G506_check_anyfault_banner_labels.py` (T255-D/DSH05), `M TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_simbench.st` (T328/DSH03), scratchs racine (`.tmp_t255d_banner_backup.st`, `.tmp_t255d_proof.py`, `.tmp_t278_bundle.log`, `.tmp_t278_g200.log`, `.tmp_t330_orig.yaml`, `.tmp_trace63_ax10_ax11.csv`, `codex-session-*.md`) | arbre de travail | ⛔ **rien de DSH07 dans `CODE/`** : la seule modification `CODE/` appartient au chantier concurrent verrouillé T333. **Suppressions à signaler pour tri humain** (règle `AGENTS.md` : un agent ne supprime/déplace jamais un fichier qu'il n'a pas créé) : `D TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/DSH01_T255D_FDC_BAS/{README.md,tests/run.bat,tests/run.py,tests/test_t255d_fdc_bas_*.st}` (renommage du dossier jetable par son propriétaire T255-D vers `?? .../DSH05_T255D_FDC_BAS/`) et `D 2026-09-19-132035-help-me-fix-these-claude-code-settings-issues.txt`. Aucun de ces chemins n'est touché, restauré, déplacé ni indexé par cette session |

## 9bis. 🔬 Analyse des traces terrain 71/72/73 (Session 2026-09-20)

> 📅 Date d'analyse : 2026-09-20 · 🎯 Objectif : confrontation formelle des hypothèses H1→H6 contre les 3 traces réelles capturées en simulation CODESYS (`Suivi_71`, `Suivi_72`, `Suivi_73`).
> 📄 Matrice de référence : `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md §5`.
> 🚫 Analyse read-only : aucun fichier de `CODE/` modifié, aucun commit.

### A. Récapitulatif technique des fichiers de trace capturés

| Fichier | Objet principal | Échantillons | Période effective | Plage temporelle | Variables tracées |
|---|---|---|---|---|---|
| `Suivi_71_SIMU_M1M2_CycleMD_Bug_20260920.trace` | Treuils M1 / M2, synchro, benne, contacteurs, joystick Y | 10 000 | **10.5 ms** (dt ∈ [9 .. 16] ms, médiane 10 ms) | t ∈ [75 831 .. 181 353] ms (105,5 s) | 61 variables |
| `Suivi_72_SIMU_M3_CycleMD_Bug_20260920.trace` | Translation M3, capteurs Trémie/PV/P2/P1, consigne variateur, mot de commande | 10 000 | **10.5 ms** (dt ∈ [9 .. 16] ms, médiane 10 ms) | t ∈ [83 056 .. 188 566] ms (105,5 s) | 19 variables |
| `Suivi_73_SIMU_CYCLE_CycleMD_Bug_20260920.trace` | Chaîne AU, homing machine, position M1/M2 cycle | 10 000 | **10.5 ms** (dt ∈ [9 .. 16] ms, médiane 10 ms) | t ∈ [80 296 .. 185 813] ms (105,5 s) | 20 variables |

> ⏱️ **Synchronisation confirmée** : les trois traces partagent la même base temporelle de la `MainTask` (recouvrement complet de t ≈ 83 s à t ≈ 181 s).

---

### B. Confrontation formelle des hypothèses H1 à H6 (Matrice §5)

| Hypothèse | Signature attendue (§5) | Relevé factuel sur les traces (horodatage & canaux) | Verdict |
|---|---|---|---|
| **H1** (Recréation demande après perte de jeton) | `ReqTranslation.ReqStart` 0→1 après arrivée, corrélé à `AtXxxStable` 1→0 ou `M3_SensorsWordChanged` | • À la Trémie (t=84 864 ms) : `AtTremie` passe à 1 et reste à 1 stable (aucune intermittence injectée). `M3_CommandWord` tombe à 0 et reste à 0 jusqu'à t=131 920 ms.<br>• À P1 (t=139 546 ms) : `AtP1` passe à 1 et reste à 1 stable. `M3_CommandWord` tombe à 0 et reste à 0 jusqu'à t=188 566 ms.<br>• Canal `ReqStart` absent de la capture Suivi_72. | 🟡 **NON OBSERVABLE en dynamique dégradée** (aucun rebond capteur injecté au banc lors du test) / 🟢 **RÉFUTÉE en condition nominale stable** (aucun redémarrage intempestif sans perte de capteur). |
| **H2** (Verrou `ArrivalLock` absent / debounce avorté AX14) | `ArrivalLock` reste à 0 alors que `AtXxxStable` = 1 ; `CaptorDebounceTon.ET` ≤ 20 ms en AX14 | • Canaux internes de `FB_Translation` (`instTranslationM3.ArrivalLock`, `.CaptorDebounceTon.ET`) **absents** des 19 canaux enregistrés dans Suivi_72.<br>• Déduction mécanique : le retrait instantané de consigne à t=84 864 ms (H4) est cohérent avec l'effondrement amont de la demande. | 🟡 **NON OBSERVABLE directement** sur ces traces (canaux privés non capturés) ; reste **PROUVÉE STATIQUEMENT** par l'asymétrie de code (`PositionTgt := 0` en AX14, `:1387`). |
| **H3** (Vitesse d'arrivée excessive en cycle) | `SpeedCmd_Pct` = 100 et `SetpointFrequencyHz` > vitesse d'approche dans zone P2→P1 ou PV | • À l'approche Trémie (t=83 056..84 864 ms) : `M3_SetpointFrequencyHz` est stabilisé à **1000.0** (10,0 Hz = vitesse d'approche nominale `ApproachSpeedTremieHz`).<br>• En transit vers P1 (t=131 920..139 546 ms) : rampe jusqu'à 5000.0 (50 Hz). Au franchissement de P2 (t=137 340 ms, `PosPVP2_DI` = 1), la consigne chute immédiatement de 5000.0 à **1000.0** (10,0 Hz = `ApproachSpeedP1Hz`). L'approche se fait à 10 Hz pendant 2 206 ms avant l'arrêt. | 🔴 **RÉFUTÉE** : la réduction de vitesse d'approche est parfaitement active et appliquée dans les deux sens (10 Hz). Le chariot n'arrive pas à pleine vitesse. |
| **H4** (Mot de commande variateur 2→0 / 1→0 roue libre au scan d'arrivée) | `CommandedMaintenance`/`Tremie` 1→0 au scan d'arrivée et `M3_CommandWord` 2→0 (roue libre) au lieu d'une consigne d'arrêt avec rampe | • **Trémie** (t=84 864 ms, éch. 172) : à t=84 854 ms, `CmdWord = 1`, `SetFreq = 1000`. Au scan exact t=84 864 ms (`AtTremie = 1`), `M3_CommandWord` bascule instantanément de **1 à 0** et `M3_SetpointFrequencyHz` de **1000 à 0** en un seul scan (10 ms).<br>• **P1** (t=139 546 ms, éch. 5354) : à t=139 530 ms, `CmdWord = 2`, `SetFreq = 1000`. Au scan exact t=139 546 ms (`AtP1 = 1`), `M3_CommandWord` bascule instantanément de **2 à 0** et `M3_SetpointFrequencyHz` de **1000 à 0** en un seul scan (10 ms). | 🟢 **CONFIRMÉE** : le mot de commande variateur tombe instantanément à 0 (roue libre côté variateur AC600) dès la retombée de la demande cycle, au lieu d'exécuter une rampe de décélération pilotée avec mot de sens maintenu. |
| **H5** (Arrêt confirmé prématurément / saut d'étape) | `Data.TranslationBusy` = 0 alors que `fAct` > 0,5 Hz → étape suivante avance prématurément | • `M3_ActualFrequencyHz` = 0 constamment (simulation sans recopie dynamique).<br>• Aucune avance prématurée : M3 reste arrêté pendant **47,0 s** à la Trémie (jusqu'au départ AX2 à 131,9 s) et pendant plus de **49,0 s** à P1 sans aucun redémarrage intempestif. | 🔴 **RÉFUTÉE** sur ce profil : l'étape n'avance pas prématurément. |
| **H6** (Défaut cause 6 / escalade sécurité intempestive) | `ErrorLimitSwitch` ou `PowerCutOff` actif sur une arrivée nominale | • Sur les 10 000 échantillons de Suivi_72 (t ∈ [83 056 .. 188 566] ms) :<br>`M3Translation.Safety.Error` = 0<br>`M3Translation.Safety.ErrorId` = 0<br>`M3Translation.State.Error` = 0<br>`M3Translation.State.ErrorId` = 0 | 🔴 **RÉFUTÉE sur arrivée nominale** : aucune alarme ni arrêt d'urgence déclenché en l'absence de dépassement physique. |

---

### C. Point d'attention 1 : Caractérisation scan par scan du blocage AX12 (Remontée en charge) sur Suivi_71

#### 1. Constat dynamique
Dans `Suivi_71` :
- De t=75 831 ms à t=100 167 ms, `PRG_04_Treuils_Benne.Data.WinchM1State.CommandedAscent` et `WinchM2State.CommandedAscent` sont à **1**.
- Pourtant, `M1_RelayAscent_RQ` et `M2_RelayAscent_Close_RQ` restent à **0** constamment.
- De t=106 449 ms à t=110 417 ms (3 968 ms), l'opérateur tire vigoureusement sur le joystick Y en montée (`JOY1Joystick.State.RawY` atteint **10 000**, `DeadmanArmed = 1`), mais `CommandedAscent` reste à **0**, les contacteurs de vitesse restent à **0**, et aucun relais de montée ne s'enclenche.

#### 2. Cause racine établie (traçage inverse scan par scan)
1. **Position physique initiale** : Dès t=75 842 ms, la mesure encodeur de M1 est figée à `M1TreuilRetenue.State.Position_M = 7.8596 m` (et M2 à 22.801 m).
2. **Seuil de limite haute logicielle** : `_CommunCfgPersist.CfgCableLimitAscent_M` est configuré à **7.50 m** (`PRG_04_Treuils_Benne.st:867`).
3. **Activation du verrou de sûreté** :
   - `EncoderM1.Measurement.CablePosM (7.86 m) >= CfgCableLimitAscent_M (7.50 m)` entraîne `CableLimitAscentM1Reached := TRUE` (`FB_WinchStateProjection.st:220`).
   - `FB_Safety_Winch.st:581` coupe immédiatement le permis de montée : `AscentPermit := FALSE`.
   - Dans `FB_Winch.st:216`, l'absence de permis active `EffectiveSafeStop := TRUE` en montée, ce qui force `RampTargetStep := 0`, puis `StepNumber := 0`.
   - Dans `FB_Winch.st:284`, la commande des relais de sens impose `IF StepNumber > 0 AND CommandedAscent THEN RelayFwd := TRUE ELSE RelayFwd := FALSE`. Avec `StepNumber = 0`, `RelayFwd` est **strictement neutralisé**.
4. **Comportement dans le séquenceur AX12** :
   - Dans `PRG_03_Modes_Cycle.st:232`, `M1TopLimitReached := WinchM1Safety.CableLimitAscent` (= TRUE).
   - Dans `FB_CycleSemiAuto.st:1338` (AX12) :
     ```pascal
     IF M1TopLimitReached OR M2TopLimitReached THEN
         WinchM1Cmd.RunRequest := FALSE;
         WinchM2Cmd.RunRequest := FALSE;
         State := E_AutoCycleStep.AX13_DRAIN_PAUSE;
     END_IF;
     ```
   - Dès que le cycle tente d'entrer dans AX12, `M1TopLimitReached` est DÉJÀ vrai : `RunRequest` est annulé instantanément.
5. **Verdict** : Ce blocage n'est **pas une régression d'exécution des contacteurs**, mais la conséquence normale d'une précondition géométrique non satisfaite : **le tambour M1 se trouvait déjà au-dessus de sa limite haute d'exploitation (7.86 m ≥ 7.50 m)**, verrouillant physiquement et logiquement toute montée.

---

### D. Point d'attention 2 : Asymétrie de transition AX2 / AX14 vs AX3 sous joystick maintenu

L'examen comparé du code de transition dans `FB_CycleSemiAuto.st` met en évidence une **asymétrie structurelle majeure de conception ergonomique** :

| Étape | Geste opérateur en cours | Condition de transition vers l'étape suivante | Comportement sous geste maintenu |
|---|---|---|---|
| **AX14** (Translation vers Trémie) | Maintien joystick X à gauche (`JoystickLeft`, `JoystickDeflected = TRUE`) | `IF TranslationStopTimer.Q AND NOT JoystickDeflected THEN State := AX15A;` (`:1395`) | ⛔ **NE BASCULE PAS** : exige le **retour physique au neutre complet** du joystick (`NOT JoystickDeflected`). Message IHM explicite : `'AX14 - Tremie : relacher le joystick avant ouverture.'`. |
| **AX2** (Translation vers P1) | Maintien joystick X à droite (`JoystickRight`, `JoystickDeflected = TRUE`) | `IF TranslationStopTimer.Q AND DeadmanArmed AND JoystickPushOnly THEN State := AX3;` (`:901`) | ⛔ **NE BASCULE PAS** : `JoystickPushOnly` est défini par `JoystickPush AND NOT (JoystickLeft OR JoystickRight)` (`:718`). Tant que l'opérateur tient X à droite, `JoystickRight = TRUE`, donc `JoystickPushOnly = FALSE`. Le cycle reste figé à l'étape AX2 jusqu'au relâchement de X. |
| **AX3** (Ouverture benne) | Maintien joystick Y en poussant (`JoystickPush = TRUE`) | `IF Benne_IsOpen AND NOT Benne_Busy THEN State := AX3_WAIT_DIVE_START;` (`:943`) puis `IF DiveStartStopTimer.Q AND DeadmanArmed AND JoystickPush THEN State := AX4_DESCEND_DIVING;` (`:968`) | ✅ **ENCHAÎNEMENT AUTOMATIQUE CONTINU** : le cycle passe d'AX3 à AX3_WAIT puis à AX4 sous `JoystickPush` maintenu continu, **sans aucun retour au neutre**. |

➡️ **Conclusion sur l'asymétrie** : À AX14 et AX2, l'automatisme exige impérativement une rupture intentionnelle de geste (relâchement de l'axe X) pour sécuriser l'arrivée au point avant d'autoriser la manœuvre suivante. À AX3, la transition vers la plongée AX4 est fluide et continue sous maintien du même axe Y. Cette disparité est intentionnelle dans le code existant mais doit être documentée pour l'opérateur afin d'éviter la sensation d'un « automate bloqué » à l'arrivée P1/Trémie.

---

## 11. 🏁 Conclusion

- **Cause racine : NON PRONONCÉE** (exigence `AC4` : hypothèse + preuve, pas d'inférence). Hypothèse principale **H1** (le cycle recrée sa demande de marche quand le jeton d'arrivée est effacé par un rebond/perte capteur, faute de verrou d'arrêt latché côté cycle = **H2**), aggravée par **H3/H4**, avec l'escalade **H6** comme conséquence observable (rapprochement direct avec `T287`).
- **Question de conception : TRANCHÉE** → **ANOMALIE partielle** (§7.1) : sources séparées = obligatoire et conforme ; **arrêt non possédé par l'axe** = anomalie modifiable.
- **Statut** : `[PHASE 1 ACCEPTÉE]` — verdict validé par CC01 le 2026-09-20 sur 3 points durs ; contrat C3 créé (`check_task_contract.py` PASS) ; campagne de trace 10 ms prête (`PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md`). **Prochaine étape : le run de trace, qui est HUMAIN (CODESYS)** — l'agent ne peut pas exécuter une trace PLC. La phase 2 (conception du correctif) démarre au retour des traces **et** après arbitrage de Q1→Q6 ; aucune ligne de `CODE/` n'est écrite avant (`TASKS.yaml:29`).

## 12. 🛠️ Proposition de correction (au sens de la mission)

> ⛔ **Aucun correctif n'est prescrit ici** : le comparatif (§4-§7) doit d'abord être validé. Ce qui suit est le **cadre** d'un lot séparé.

- **Option 1 (immédiat, sans code)** : (a) relever et archiver une **trace 10 ms** selon §9 (scénarios A/B/C) ; (b) vérifier `GVL_IHM.M3Translation.Bypass.LimitSwitch`/`.Global` **avant** tout essai en SEMI_AUTO (A06) — un bypass actif suffit à expliquer l'absence de verrou ; (c) en exploitation, consigne opérateur transitoire : **relâcher le X** à l'arrivée en AX2/AX14 (le retrait de geste reste la seule protection fiable tant que H1/H2 ne sont pas corrigées). Risque : masque le défaut sans le traiter.
- **Option 2 (définitif, lot séparé sous contrat C3)** : appliquer §7.2 (1→7) dans l'ordre 1-2-3 (**arrêt possédé par l'axe**, cible suivant le sens, demande ≠ arrêt), puis 4 (retrait de demande ⇒ arrêt commandé), puis 5 (bypass gated par mode), puis 6 (configs mortes). Test CI cible : reproduction de la perte capteur à l'arrivée, échec avant / pass après ; `guard:` de non-régression sur l'armement de `ArrivalLock` en AX2 **et** AX14 ; `TASKS.yaml:36` exige « **jamais de franchissement toléré en auto** ».
- **⚠️ Validation requise** : **[humaine]** — ne pas modifier `CODE/`, ne pas forcer de variable, ne pas committer.

## 13. ✅ Vérification de la correction / non-régression *(à remplir après le lot de correction)*

- [ ] Trace 10 ms post-correctif en AX2 et AX14 : `ArrivalLock = TRUE` armé, `ReqStart` ne repart pas, aucun `ErrorLimitSwitch` sur arrivée nominale.
- [ ] Non-régression manuel : arrivée MAINT_N1 sur P1 / Maintenance / Trémie inchangée (mêmes temps d'arrêt).
- [ ] Non-régression sécurité : `FB_Safety_Translation` cause 6 (dépassement réel) toujours active ; `PowerCutOff` toujours atteignable.
- [ ] `G200_check_linkage.py --report` PASS + gates du palier applicable (à la charge du lot de correction, pas de cette fiche).

## 14. 📝 Journal (chronologique)

- 2026-09-20 (session T334, acteur **DSH07**) : briefing chargé (`subagent_preamble.md`, skill `troubleshooting` canonique + stub, skill `task-planner` canonique).
- 2026-09-20 : collision d'identité `DSH01` constatée (≥6 sessions). Vérification de `TASK_LOCKS.json` : `T330 → DSH06` pris par une autre session à 15:54:05, `DSH01..DSH06` indisponibles ⇒ **tag DSH07** retenu et inscrit explicitement (verrou T334 + 🚩 d'édition). `ConvertFrom-Json` : **JSON valide**.
- 2026-09-20 : relevé statique des deux chaînes (`PRG_02`/`FB_Joystick`, `FB_TranslationCmdArbitrationM3`, `PRG_05`, `FB_Translation`, `FB_Translation_PositionDecoder`, `FB_TranslationOutputInterlock`, `FB_Safety_Translation`, `PRG_03`, `FB_CycleSemiAuto`, `PRG_06`, `GVL_PERSISTENT`, `ST_*` de types, `Device_IO_20260918.csv`) — chaîne manuelle 66 lignes, chaîne cycle 35 lignes.
- 2026-09-20 : constat clé trouvé par lecture : **l'axe est déjà unifié** (arbitre + FB de mouvement + barrière + mots variateur uniques) ; la divergence réelle porte sur **la propriété de l'arrêt** et sur l'asymétrie AX2/AX14 (`FB_CycleSemiAuto.st:900` vs `:1387`).
- 2026-09-20 : 12 constats hors scope remontés (§10 A01-A12), dont 4 variables/configs mortes, un écart spec/code d'escalade de sûreté, un bypass non gated par mode, et la désynchronisation des horloges du registre.
- 2026-09-20 : fiche écrite ; `DOC/WFLOW/TASKS.yaml` mis à jour (T334) puis 🚩 d'édition retiré ; `git status --short` vérifié (aucun `CODE/`).
- 2026-09-20 (**GO CC01**) : verdict de la phase 1 **accepté**, vérifié sur 3 points durs (verrou d'arrêt de l'axe, asymétrie AX14, front montant seul du décodeur). Étapes autorisées : campagne de trace 10 ms selon le protocole A/B/C, et création du contrat C3 avant la phase 2. Hors scope transmis, non corrigé. Lien H1 ↔ T287 noté dans la fiche (§8).
- 2026-09-20 : **contrat C3 créé** — `TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml`, `check_task_contract.py` **PASS (0 erreur, 0 avertissement)**, 10 critères d'acceptation AC1→AC10 (dont les deux critères structurels exigés par le gate T8 pour toute écriture `CODE/M_MAIN/`), 6 questions Q1→Q6 à trancher avant le code, conservation et interdits des chantiers concurrents. Constat A01 levé.
- 2026-09-20 : **campagne de trace rendue turnkey** — `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` : liste des canaux à copier (groupes A à G, ~88 symboles), réglage de trace MainTask 10 ms avec repli en 3 sous-traces si buffer limité, 3 scénarios A/B/C au geste identique, matrice de décision signature → hypothèse, post-traitement `trace_to_csv.py`, interdits. **Le run reste humain (CODESYS)** : l'agent ne peut pas exécuter la trace.
- 2026-09-20 : 3 faits nouveaux **mesurés** intégrés à la fiche (et non supposés) — (1) les internes d'instance par chemin pointé, **imbriqués compris**, sont bel et bien traçables (relevé dans `trace_treuils_charge_v1.txt`) ⇒ la preuve de H2 est techniquement possible ; (2) `Suivi_Cycle_M3_20260906_49.trace` est à **dt médian 100 ms** (77-128 ms) avec 15 canaux sans jeton ni interne d'axe ; (3) les traces `SIMU_MaintMANU_20260919` ne contiennent **aucune** variable M3 ⇒ la comparaison manuel ↔ cycle n'existe pas dans le dépôt.
- 2026-09-20 : **arrêt de l'agent** — la phase 2 (conception) ne peut pas démarrer sans le retour des traces et l'arbitrage de Q1→Q6. Aucun `CODE/` écrit, aucun commit.
- 2026-09-20 18:41 (session **T334 bis**, tag **DSH10**, read-only, contexte frais) : **challenge indépendant livré en §10bis** — verdict **MAJOR**. Les 5 affirmations du brief ont été revérifiées **fichier:ligne** sans recopie ; 3 écarts de fond (H4 mal attribuée à la Trémie, lien H4→T287 trop fort, asymétrie AX2/AX14 en réalité **décidée** par T319/fiche 2026-09-05 avec garde mécanique à 6 faits), 2 configs mortes nouvelles (A13 délai de collage frein jamais appliqué, A14 timeout du modèle AX3 désactivé), 4 erreurs de citation (dont `PRG_07:230-235` → `:331-341`) et le décalage **+4** des références AX14 après l'édition concurrente T331/DSH09 de 18:13:32. **Aucun `CODE/` écrit, aucun test, aucun gate, aucun bundle, aucun commit.**

---

📖 Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` · Gabarit : `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`
🔗 Tâches liées : `T287` (défaut frein aux mêmes arrivées), `T300` (banc + perte capteur ~1 s), `T333` (estimateur — **non consommé** par les deux chaînes), `T319` (continuité AX2→AX3), `T204` (permits directionnels), `T327` (verrou descente benne).

---

## 10bis. 🔍 Challenge indépendant avant Phase 2 (T334 bis — revue read-only, contexte frais)

> 📅 2026-09-20 · 🏷️ Acteur : session **T334 bis**, tag **DSH10** (`TASK_LOCKS.json` vérifié : DSH07=T334, DSH08=T295, DSH09=T331 ⇒ DSH10 = premier libre). **Aucun verrou pris** : mission read-only, zéro écriture `CODE/`, zéro test, zéro gate, zéro bundle, zéro commit.
> 🎯 Objet : vérifier **fichier:ligne** les affirmations de la phase 1 (§1-§9bis) **sans rien recopier**, chercher ce que les analyses ont manqué, et proposer des options — **sans trancher à la place de l'orchestrateur**.
> 🔢 **Révision de travail** : `git rev-parse HEAD` = `fd12dc0` **+ arbre de travail modifié** (voir §A.0 : le fichier porteur de la preuve H2 a bougé **après** l'écriture de la fiche).

---

### A.0 ⚠️ Préalable bloquant pour la Phase 2 : la fiche a été écrite AVANT une édition concurrente du fichier qui porte la preuve H2

| Fait mesuré | Preuve |
|---|---|
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` est **modifié non commité** (`M`) | `git status --short` |
| Dernière écriture du fichier : **20/09/2026 18:13:32** — la fiche : **20/09/2026 18:07:20** | `LastWriteTime` des deux fichiers |
| Édition **+20 / −5** lignes : ajout `BucketCmd.ReqOpen := FALSE` en AX10 et **réécriture du repli AX15B → AX10** | `git diff CODE/G_CYCLE/FB_CycleSemiAuto.st` |
| Propriétaire identifié : **T331 / DSH09** (verrou d'écriture sur ce fichier depuis 17:57) | `TASK_LOCKS.json` clé `T331`, `TASKS.yaml:215` |

➡️ **Conséquence vérifiée** : toutes les références **postérieures à la ligne 1221** sont décalées de **+4**. Les citations AX14 de la fiche sont donc **périmées de 4 lignes** (`:1382→:1386`, `:1383→:1387`, `:1386→:1390`, `:1387→:1391`, `:1391→:1395`) ; les citations AX2 (avant 1221) restent exactes. Aucune conclusion n'est invalidée par ce décalage, mais **la Phase 2 doit figer une révision** avant de coder, sinon chaque `fichier:ligne` du contrat redevient faux à la prochaine édition concurrente.

---

### A.1 ✅ Vérification affirmation par affirmation (les 5 points du brief)

| # | Affirmation à challenger | Verdict | Preuve relue (références **courantes**) |
|---|---|---|---|
| 1 | H1/H2 non observables sur les traces mais **H2 prouvée statiquement** (`PositionTgt := 0` en AX14) | 🟢 **CONFIRMÉE** | `FB_CycleSemiAuto.st:1391` `TranslationCmd.PositionTgt := 0;` (cité `:1387` = +4) → `FB_TranslationCmdArbitrationM3.st:65` `SelTarget := ReqTranslation.PositionTgt` → `PRG_05_Translation.st:408-429` : `SelTarget=0` tombe en `ELSE` → `:414` `IF M3_ReqTremie_Active` — or la demande vient d'être retirée (`:1390` `ReqStart := FALSE` ⇒ arbitre `:48-50`, `:72-83` remettent `ReqTremie := FALSE`) ⇒ `:427` `M3_PositionSensorTarget := FALSE`. Debounce `FB_Translation.st:175-177`, `PT = Cfg.CaptorDebounce = T#100ms` (`ST_fbTranslation_Cfg.st:31`) ⇒ **le TON ne peut pas atteindre 100 ms** ⇒ `ArrivalEdge` ⇒ `ArrivalLock` jamais armé par la voie capteur en AX14. **Asymétrie confirmée** : en AX2 `:900` `PositionTgt := 3` est **conservé** ⇒ `SelTarget=3` ⇒ `PRG_05:411` `M3_PositionSensorTarget := M3_AtP1Stable` = **le jeton latché, indépendant de `ReqTremie`** ⇒ le debounce aboutit. |
| 2 | H3 / H5 / H6 **réfutées** ; H4 **confirmée** (coupure nette du mot de commande au lieu d'une rampe) | 🟡 **PARTIELLEMENT CONFIRMÉE — voir §B.2** | H3 : `FB_TranslationCmdArbitrationM3.st:74` `SpeedPct := 100.0` ✔ et `_TranslationAutoSpeedCap_Pct` (`GVL_PERSISTENT.st:97`) a **0 lecteur** (grep sur `CODE/` : la seule occurrence est la déclaration) ✔. H5 : `PRG_05:817` `TranslationBusy := (|fAct| > 0.5)` ✔. H6 : `FB_Safety_Translation.st:199-203` (1,5 s) + `:268` `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 0` ✔ ⇒ bit 6 ∈ `16#00F8` ⇒ H6 est **une conséquence atteignable**, pas une cause. **H4 est confirmée comme OBSERVATION, mais son mécanisme attribué est faux à la Trémie** (§B.2). |
| 3 | **AX12 « bloqué » = sécurité géométrique légitime, pas un bug** | 🟢 **CONFIRMÉE** (chaîne exacte, libellé d'un maillon à corriger) | `PRG_04_Treuils_Benne.st:867-876` `TopLimitM1_M := SEL(override, CfgCableLimitAscent_M, …)` ; valeur `7.5` en `GVL_PERSISTENT.st:145` et `ST_CommunCfg.st:21` ; fait public `FB_WinchStateProjection.st:219-222` `CableLimitAscentM1Reached := Homed AND NOT HomingSuspect AND NOT Busy AND (CablePosM >= CfgCableLimitAscent_M)` ⇒ à 7,86 m c'est `TRUE` ; sortie d'étape `FB_CycleSemiAuto.st:1342-1346` (cité `:1338` = +4) ⇒ AX12 → AX13 au premier scan ; permis de montée coupé en `FB_Safety_Winch.st:574-582` (le terme fautif est bien **`:581`**, mais l'affectation commence `:574`). ⚠️ Nuance : `:581` lit **`TopLimitM`**, pas `CfgCableLimitAscent_M` directement — la chaîne tient parce que `TopLimitM1_M = CfgCableLimitAscent_M` en nominal, mais les deux seuils sont distincts (relaxation 7,5 → 8,5 m documentée `:578-580`). |
| 4 | **Asymétrie** : AX2 (`:901`) et AX14 (`:1395`) exigent le retour au neutre ; AX3→AX4 enchaîne sans neutre | 🟢 **CONFIRMÉE sur le fait — 🔴 RÉFUTÉE sur la qualification « anomalie »** | Fait : `FB_CycleSemiAuto.st:901` `IF TranslationStopTimer.Q AND DeadmanArmed AND JoystickPushOnly` avec `:718` `JoystickPushOnly := JoystickPush AND NOT (JoystickLeft OR JoystickRight)` ; `:1395` `IF TranslationStopTimer.Q AND NOT JoystickDeflected` ; AX3 `:943` puis `:968` `IF DiveStartStopTimer.Q AND DeadmanArmed AND JoystickPush` ⇒ enchaînement sous le **même** geste Y, sans neutre, ✔. **Mais la « disparité non documentée » est fausse** → voir §B.1 (décision T319 + fiche 2026-09-05 **et** garde mécanique à 6 faits). |
| 5 | « Conflit AF-09 (T336) : la spec prévoit une cible dynamique M2 + variante benne ouverte, le code force cette cible à FALSE » | 🔴 **NON VÉRIFIABLE DANS CETTE FICHE + cadrage incomplet** | (a) **Le claim n'existe nulle part dans la fiche T334** : grep `AF-09\|AF_Partie-09\|T336\|cible` ⇒ **0 occurrence** (`M2` n'apparaît qu'en `M19`, `:465-508`). Il vit dans `DOC/WFLOW/TROUBLESHOOTING/TROUBLESHOOTING_T336_CycleHoming_Graphe7_2026-09-20.md:74,100,105`. ⇒ **mauvaise attribution** : ce point n'appartient pas au périmètre T334. (b) Le code **porte son propre REX** : `FB_CycleMachineHoming.st:418-420` `M1Demand.UseDynamicTarget := FALSE; M2Demand.UseDynamicTarget := FALSE;` précédé de `:412-417` — *« Cible dynamique (top + offset ~23 m) supprimée ici : elle créait un écart apparent M1/M2 de ~15 m au preset → FB_WinchSync SafeStop → Fault.Latched »*. ⇒ ce n'est **pas** un forçage arbitraire : c'est la séquelle documentée d'un incident de synchronisme. Réactiver la cible dynamique **exige de résoudre cet incident d'abord**. |

---

### B. 🔎 Ce que les analyses précédentes ont manqué (5 trouvailles sourcees)

#### B.1 🟢 La raison du neutre à AX2/AX14 **est écrite**, et AX3 n'est pas « plus permissif » : il a une garde différente

**Trois sources, jamais citées par la fiche :**

1. `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_ContinuiteJoystick_AX3_AX4_20260905.md` — analyse complète de la transition AX3→AX4 :
   - `:67` « **Cause de l'obligation de relâcher** : front `JoyDeflectedEdge.Q` explicitement exigé en AX3. »
   - `:68-70` « **Cause du risque lors de sa suppression** : aucune preuve d'arrêt mécanique M2 entre la manœuvre benne et le départ couplé ; le verrou aval `DirectionChangePending` ne couvre pas une reprise dans le même sens. »
   - `:76-82` recommandation : « **Conserver `DeadmanArmed` et la déflexion joystick sans demander de retour au neutre** » **+ insérer une phase explicite** (commandes à zéro, attente d'arrêt mécanique M1/M2 confirmé stable) **+ timeout de repli**.
2. Cette recommandation **est implémentée** : étape dédiée `AX3_WAIT_DIVE_START` (`FB_CycleSemiAuto.st:948-971`), garde à **6 faits physiques** `DiveStartStopped` (`:284-288` : vitesses valides, contacteurs retombés, freins appliqués, 2 vitesses < 0,02 m/s), TON `DiveStartStopTimer` (`:289`, `PT = T#300ms`, `:259`), transition sous **même geste** (`:968`). Le `JoyDeflectedEdge` n'est plus utilisé que pour AX18 (`:160`, `:279`).
3. **T319 est une tâche C3 CLOSE** (`TASKS.yaml:405-425`, `statut: ✅`, contrat `TASK_CONTRACT_T319_AX2_P1_CONTINUITY.yaml`) qui arbitre explicitement le sujet : *« AX2 enchaîne vers AX3 sous le même geste joystick maintenu »* **mais** son objectif `:420` borne la portée : *« **Hors P1 ou position non qualifiée**, AX2 **conserve la mise en position et ses autorisations actuelles** »*. ⇒ le relâchement à l'arrivée **en cours de jog** est **conservé par décision**, pas par oubli.
4. Cadre normatif : `AF_Partie-04 v2.3:180` (intention maintenue requise tant qu'un mouvement est commandé) et `:181` (« Relâchement manche ⇒ `StartStop=FALSE`, **étape conservée**, pas de reprise automatique ») ; doctrine de l'arrêt dans l'axe : `AF_Partie-11/FB_Translation_v1.1.md:190` (« un retour au neutre seul ne lève plus le verrou »).

**Et la raison technique, plus forte que l'ergonomie** : en cycle, la demande M3 **dérive du permis joystick** — `FB_CycleSemiAuto.st:716-717` (`TranslationP1Permit` / `TranslationTremiePermit` = `DeadmanArmed AND JoystickLeft/Right AND NOT Push/Pull`) → `:913` / `:1387` `TranslationCmd.ReqStart := <permis>`. **Relâcher X est aujourd'hui le seul geste qui retire réellement la demande M3 du séquenceur.** Le neutre n'est donc pas un confort opérateur : c'est **la protection qui empêche H1 de produire son effet**, et celle qui évite d'entrer dans l'étape suivante (où M3 est veté par `PRG_05:389-395` et où la barrière force frein + mots à 0 en `PRG_05:656-662`) avec une demande de translation encore vivante.

#### B.2 🔴 H4 est **mal attribuée à la Trémie** : la coupure en 1 scan est la **coupure dure**, pas le retrait de demande

Ordre d'exécution des tâches : `PRG_02 → PRG_03 → PRG_05 → PRG_06` (skill troubleshooting, « Ordre d'exécution »). Donc **le cycle lit les jetons de `PRG_05` avec un scan de retard**.

| Scan | Ce qui se passe réellement (Trémie, `SEMI_AUTO`) |
|---|---|
| **N** (le DI Trémie monte) | `PRG_03` lit le jeton **du scan précédent** (`FALSE`) ⇒ `:1387` `ReqStart := TRUE` ⇒ `PRG_05` : jeton `M3_AtTremieStable := TRUE` (`:266`), `M3_ReqTremie_Active := TRUE` ⇒ `FB_Translation` : mot **1**, fréquence ≈ **10 Hz** (approche `:308-313`) ⇒ **`PRG_06:431-432` `M3_TremieHardStopActive := M3_PosTremie_DI(1) AND ReqTremieSemantic(TRUE) = TRUE`** ⇒ `:442-450` **`BrakeReleaseRequest := FALSE`, mot `:= 0`, fréquence `:= 0.0` au MÊME scan** ⇒ `:457-459`. **C'est exactement la signature relevée en §9bis (CmdWord 1→0 ET SetFreq 1000→0 en un seul scan).** |
| **N+1** | Le cycle voit enfin `Translation_At_Tremie=TRUE` ⇒ `:1390-1391` `ReqStart := FALSE`, `PositionTgt := 0` ⇒ `ReqTremie := FALSE` ⇒ `ReqTremieSemantic := FALSE` ⇒ la coupure dure **se désarme** ; le mot reste à 0 par disparition de la demande. |
| **À P1** | `ReqTremieSemantic = FALSE` (sens = Maintenance) ⇒ la coupure dure **n'existe pas** ⇒ la bascule 2→0 vient bien du retrait de demande (`:899`, arbitre `:48-50`/`:83`, `FB_Translation.st:229-233`, `:297-303`). Et la **fréquence tombe en 1 scan** parce que la barrière dérive sa propre notion de mouvement **du mot de commande lui-même** : `FB_TranslationOutputInterlock.st:84` `MovementRequested := (W=1) OR (W=2)` puis `:133-151` n'affecte `DriveFreqCmd_Hz` que dans la branche `MovementRequested AND NOT PermitFinalBlocked` ⇒ mot 0 ⇒ fréquence 0 **au même scan** (`:154`). |

➡️ **Correction exigée** : H4 décrit correctement le **symptôme** (coupure nette au lieu d'une rampe) et le mécanisme **à P1**, mais **pas** à la Trémie, où la coupure dure — protection **voulue** (`PRG_06:428-430`) — agit **un scan avant** le cycle. La preuve §9bis « H4 CONFIRMÉE » à la Trémie ne discriminera donc **jamais** H4 de la coupure dure telle qu'elle est listée : la matrice §5 doit ajouter la ligne `M3_TremieHardStopActive` comme **signature concurrente** (le canal est d'ailleurs prévu §9-E, il suffit de l'exploiter).

#### B.3 🟠 H4 **ne ferme pas le frein** : l'implication « frein fermé sur chariot en mouvement » n'est pas produite par H4

- `FB_Translation.st:271-272` : `MovementRequested := (|SpeedRamp.Current| > 0.1) OR ((|fAct| > 0.5) AND NOT TonBrakeRealFreqTimeout.Q)` ⇒ **le frein reste desserré pendant la roue libre** tant que la vitesse réelle est mesurée > 0,5 Hz (fenêtre 2 s, `:266-269`). Le mot de commande à 0 (roue libre) **ne commande pas** le frein.
- Donc la ligne H4 de §8 (« frein fermé sur chariot en mouvement ») **n'est pas soutenue par le code**, et le rapprochement T287 qu'elle porte est **circulaire**. Voir §D.

#### B.4 🟠 Le défaut frein de T287 a un **mécanisme propre, documenté et déjà partiellement corrigé** — le challenge l'identifie

`FB_Brake.st` : `:100-105` fermeture **immédiate** dès que `MovementRequested` retombe ; `:114` `TonFeedback(IN := (BrakeCmd <> ContactorFeedback), PT := FeedbackTimeout)` ⇒ `:115-121` `StuckClosed`/`StuckOpen` ⇒ `:126-128` cause **latchée** ⇒ `:136-138` `BrakeCmd := FALSE` **définitif** jusqu'au `Reset`. **C'est le « latch définitif dans FB_Brake »** de T287.

Historique MES de ce mécanisme, **tous datés**, retrouvés dans le code :

| Source | Contenu |
|---|---|
| `FB_Translation.st:114-129` (REX MES 2026-09-04) | La cause 6 se déclenchait **à chaque arrivée nominale** → `§6` forçait `BrakeReleaseRequest := FALSE` « pendant que `FB_Brake` pense toujours commander l'ouverture (son `MovementRequested` reste vrai le temps du coast ~600 ms) → **incohérence commande/retour frein → latch définitif** ». Correctif : n'exiger la cause 6 que sur un **dépassement réel soutenu 1,5 s**. |
| `ST_fbTranslation_Cfg.st:35` | `BrakeFeedbackTimeout` **300 ms → 800 ms** : « 300ms trop court pour un **arrêt dur au FdC** (coast réel ~600 ms) → **latch spurieux** ». |
| `ST_fbTranslation_Cfg.st:34` | `BrakeDelayMotorDecel` **500 ms → 2 s** « confirmé opérateur » — **mais ce délai n'est jamais appliqué** (voir B.5). |

➡️ **Les producteurs vivants qui forcent `BrakeReleaseRequest := FALSE` EN AVAL de `FB_Brake`** (et reproduisent donc la faute déjà corrigée une fois) sont au nombre de deux, tous deux **aux arrivées** :
1. `PRG_06:442-443` `M3_TremieHardStopActive` (coupure dure Trémie, **voulue**) — armée dès que `M3_PosTremie_DI = 1` **et** la sémantique Trémie est présente, donc **pendant tout rebond haut** où le cycle recrée sa demande (H1) ;
2. `PRG_05:658` (veto SEMI_AUTO hors AX2/AX14) — se déclenche **au changement d'étape**, exactement là où T287 situe la récidive (P1 → AX3).

**Chaîne discriminante proposée (à prouver par la trace, pas affirmée)** : `H1 (jeton perdu → ReqStart recréé, geste maintenu) + H2 (ArrivalLock absent) → ReqTremie vrai alors que le FdC Trémie est haut → coupure dure armée ≥ 800 ms → BrakeCmd interne (TRUE, rampe encore non nulle) ≠ retour physique (FALSE) → latch FB_Brake` = **T287**. Elle exige **H1 ET H2** et un FdC **haut** pendant ≥ 800 ms.

#### B.5 🟠 Config morte **non signalée** : le délai de collage du frein n'est jamais appliqué

`FB_Brake.st:72,93,103` instancient `TonDecel(IN := …, PT := DelayMotorDecel)` et **`.Q` n'est jamais lu** (grep `TonDecel\.Q` sur `CODE/` : **0 résultat**) : en `:104`, `BrakeCmd := FALSE` **immédiatement**. La configuration `BrakeDelayMotorDecel = T#2s` (`ST_fbTranslation_Cfg.st:34`, alimentée en `FB_Translation.st:282`) est donc **sans effet** → le commentaire `FB_Brake.st:23` (« Délai deceleration avant collage frein ») et la valeur « confirmée opérateur » décrivent un comportement **absent**. C'est le **même défaut de forme que A03** (garde revendiquée en commentaire, non implémentée) sur la chaîne frein — donc **directement dans le périmètre de T287**, et **hors** de celui de T334.

#### B.6 🟠 La « cible figée à P1 en AX2 » a une raison documentée — et l'uniformiser **casse la reprise de dépassement**

- Le commentaire du code porte la raison, mot pour mot : `FB_CycleSemiAuto.st:905-906` — *« AX2 accepte les deux sens ; la cible effective suit le sens du joystick. **Si Maintenance=1 et P1=0, cela permet de se dégager d'un dépassement.** »* ⇒ l'intention invoquée est **la reprise après franchissement de P1**.
- La branche de récupération existe et la décrit : `FB_CycleSemiAuto.st:1549-1557` — *« chariot déjà au-delà de P1 … **Le retour gauche traverse P1 ; le front P1 réarme AtP1** et la branche précédente termine AX2 normalement. »* ⇒ le retour se fait **vers la Trémie** et l'arrêt est attendu **à P1**.
- Or `SelTarget = 3` force `M3_PositionSensorTarget := M3_AtP1Stable` (`PRG_05:411`), et `M3_AtP1Stable` est armé **sur les deux fronts de son propre capteur** (`FB_Translation_PositionDecoder.st:116`) ⇒ le retour gauche depuis 00001 arme le jeton dès la retombée de P1 et **stoppe le chariot à P1**, conformément au commentaire.
- ⚠️ **Risque caché de §7.2-2** (« la cible doit suivre le sens commandé ») : en AX2, un jog vers la Trémie rendrait la cible = `M3_AtTremieStable` ⇒ le chariot **ne s'arrêterait plus à P1** et partirait vers la Trémie **dans l'étape AX2**, alors que `:879-884` revendique un « jog bidirectionnel » et que la branche de reprise ci-dessus suppose l'arrêt à P1. **L'uniformisation proposée détruit un chemin de récupération existant**, sauf à rendre la cible dépendante de l'étape (ce que §7.2-2 cherche précisément à supprimer).
- Nuance de citation : la fiche appuie la « contradiction interne » de D02 sur `PRG_05_Translation.st:404-407` ; ce commentaire dit **« En mode manuel (SelTarget=0), n'importe quel des 3 points d'arrêt … »** — il décrit le **manuel**, pas le cycle. La contradiction n'existe donc qu'entre `FB_CycleSemiAuto.st:905-906` et l'arbitre, lequel porte **lui aussi son commentaire** (`FB_TranslationCmdArbitrationM3.st:66-67` : *« PositionTgt=3 (P1) en AX2 : jog bidirectionnel autorisé, **mais la cible d'arrêt reste P1 dans FB_Translation** »*). D02 reste une anomalie de cohérence de commentaires, **pas** un code non documenté.

---

### C. 🎯 Réponse à la question 2 — « uniformiser sur le modèle AX3 est-il sûr ? »

**Non, pas en l'état — et le risque n'est pas celui deviné.**

| Question posée | Réponse sourcée |
|---|---|
| Le neutre évite-t-il « une commande M3 non désirée pendant que l'opérateur redirige son attention » ? | 🟡 **En partie, mais le vrai contenu est plus fort** : le neutre est le **mécanisme de retrait de la demande M3** (§B.1-4). Sans lui, `ReqStart` reste vrai tant que X est défléchi, donc **toute** perte de jeton (rebond T287/T300, exclusion mutuelle `PRG_05:265-277`) recrée instantanément la demande — c'est **H1**, déjà décrit par la fiche. |
| Le modèle AX3 est-il « plus sûr » ou seulement plus fluide ? | 🔴 **Ni l'un ni l'autre : il est plus sûr *parce qu'il a une garde dédiée*.** AX3→AX4 ne demande pas le neutre **parce que** T319 a ajouté `AX3_WAIT_DIVE_START` + `DiveStartStopped` (6 faits mécaniques, `:284-288`) + `DiveStartStopTimer` 300 ms. M3 **n'a pas d'équivalent** : sa « confirmation d'arrêt » est `TranslationStopTimer` (`:334-338`) dont l'entrée est `NOT Translation_Busy` = `|fAct| ≤ 0,5 Hz` (`PRG_05:817`) — donc **une donnée variateur**, et **nulle au banc** (`M3_ActualFrequencyHz = 0` constamment dans Suivi_72, §9bis) ⇒ au banc la « preuve d'arrêt » est **vacuitaire**. |
| Uniformiser sans rien d'autre, que se passe-t-il ? | 🔴 Le geste X maintenu + changement d'étape ⇒ le veto `PRG_05:389-395` neutralise M3 et `:658` **force le frein fermé** ; combiné à `FB_Translation.st:271-272` (frein maintenu tant que `|fAct| > 0,5`) on entre dans la classe de faute de §B.4. **Et** l'opérateur perd le seul geste qui arrêtait le chariot. |
| Faut-il donc garder les deux modèles ? | ➖ **Décision d'orchestrateur, pas de challenger.** Ce qui est prouvé : les deux modèles **ne sont pas équivalents** (garde mécanique vs garde gestuelle) ; les rendre équivalents **exige d'abord** que l'axe possède l'arrêt (§7.2-1/2), donc l'option « uniformiser » **dépend** de l'option « l'axe possède l'arrêt » — elle ne peut pas être menée seule. |

---

### D. 🔗 Réponse à la question 3 — H4 et le défaut frein de T287 : **même mécanisme ou coïncidence de timing ?**

**Verdict : mécanismes DIFFÉRENTS, co-localisés — la fiche fait un raccourci.**

| | H4 (fiche) | Défaut frein T287 (reconstruit, §B.4) |
|---|---|---|
| Grandeur fautive | **mot de commande variateur** `M3_CommandWord` → 0 (« roue libre ») + fréquence en 1 scan | **`BrakeReleaseRequest` forcé à FALSE en aval de `FB_Brake`** ⇒ `BrakeCmd` interne ≠ retour physique |
| Producteur | retrait de la demande (`FB_CycleSemiAuto:1390`, arbitre `:83`, `FB_Translation:229-233/297-303`) **et** coupure dure à la Trémie | `PRG_06:442-443` (coupure dure) **et** `PRG_05:658` (veto d'étape) |
| Ferme-t-il le frein ? | **NON** — `FB_Translation.st:271-272` maintient le frein desserré tant que `|fAct| > 0,5` (fenêtre 2 s) | **OUI** — c'est sa définition |
| Seuil de latch | aucun (pas de latch : le mot revient dès une nouvelle demande) | **800 ms de désaccord continu** (`ST_fbTranslation_Cfg.st:35`) puis latch définitif `FB_Brake.st:126-138` |
| Statut | observation **prouvée** sur Suivi_72 | **non prouvé** : exige une trace avec les canaux frein **et** `≥ 800 ms` continus |

➡️ **Conclusion** : le lien affirmé « H1 → H4/H6 produit exactement le défaut T287 » (`§8`, tableau de rapprochement) est **trop fort**. Ce qui tient : (1) **même lieu** (arrivées Trémie et P1) ✔, (2) **même signal d'entrée** (rebond capteur ≈ 1 s) ✔, (3) **même verrou de preuve** (aucune trace 10 ms avec les canaux frein) ✔, (4) et un **producteur commun plausible** : la coupure dure Trémie + le veto d'étape, **activés par H1** (§B.4). En revanche **H4 n'est pas le vecteur du défaut frein** : il ne touche pas la commande de frein. Le rapprochement doit être **réécrit** sur cette base, sinon T287 risque de chercher sa cause au mauvais endroit (et de conclure à une coïncidence).

---

### E. 🛠️ Trois options pour la Phase 2 — risques et efforts (**aucune n'est tranchée ici**)

| | Option 1 — **Uniformiser sur le modèle AX3** (AX2/AX14 avancent sans neutre) | Option 2 — **Ne pas toucher au séquenceur ni à l'axe** : instrumenter et prouver d'abord | Option 3 — **Intermédiaire : corriger la cible AX14 + gater les bypass, laisser le neutre** |
|---|---|---|---|
| Contenu | Relaxer l'exigence de relâchement (`:901`, `:1395`) pour aligner sur AX3 ; M3 serait arrêté par la garde du cycle | Exécuter la campagne `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` (§9-A→G) **en y ajoutant les signatures concurrentes** (§B.2 : `M3_TremieHardStopActive` ; §B.4 : `BrakeCmd` interne vs `M3_BrakeIsOpen_DI`, `BrakeTimeoutElapsed`) et trancher Q1→Q6 | (a) AX14 : `:1391` `PositionTgt := 0` → conserver la cible comme AX2 conserve la sienne ⇒ le debounce 100 ms peut aboutir à la Trémie ; (b) `PRG_05:571` : neutraliser `Bypass.*` hors `MAINT_N1/N2` (doctrine `ST_BypassTranslation.st:4-5`) et/ou ne pas restaurer `Bypass.Global` au passage en SEMI_AUTO (`PRG_07:331-341`) |
| Ce que ça règle | La fluidité opérateur / la symétrie apparente | **Rien ne change** ; lève le verrou de preuve actuel (H1/H2 aujourd'hui « non observables », §9bis) | H2 (verrou d'arrêt réellement armable à la Trémie) et A06/D09 (bypass non gated) — les deux causes **les plus citées** du diagnostic |
| Risque | 🔴 **Élevé** : supprime la seule protection qui empêche H1 de relancer le chariot ; entre dans l'étape suivante avec une demande M3 vivante ⇒ veto `PRG_05:658` + frein ⇒ classe de faute T287 ; la garde de remplacement (arrêt mécanique prouvé) **n'existe pas pour M3** et est **vacuitaire au banc** (`fAct = 0`) | 🟢 **Faible** (read-only côté code) ; ⚠️ mais **le run est humain** (CODESYS) et **le banc est structurellement incapable** de reproduire le défaut frein (`AUDIT_T300_TRACE_20260904:244`) ⇒ un PASS banc ne vaut pas non-régression terrain | 🟡 **Moyen** : change la cible présentée à l'axe en AX14 ⇒ à tester (AC4) et à tracer ; le point (b) retire des capacités de mise en service (bypass) ⇒ **décision humaine**, et il ne corrige **pas** le retrait de demande (H1) |
| Ce que ça NE règle PAS | Tout le reste (H4 à P1, la propriété de l'arrêt, les bypass, le défaut frein) | Rien n'est corrigé — c'est un choix de méthode, pas un correctif | H1 (le cycle recrée encore sa demande sur perte de jeton) et la propriété de l'arrêt : **un rebond peut encore relancer le chariot** |
| Effort | **L** (interface + garde à concevoir pour M3 + tests + gates + AF-11) | **S** (procédure déjà écrite) + 1 run humain + analyse | **S/M** (2 fichiers : `FB_CycleSemiAuto.st` **verrouillé T331/DSH09** + `PRG_05_Translation.st`), + 1 test CI + gates palier C |
| Dépendance | ⛔ **Dépend de l'option « l'axe possède l'arrêt » (§7.2-1/2)** : ne peut pas être menée seule | Aucune | ⛔ `FB_CycleSemiAuto.st` est **sous verrou d'écriture T331/DSH09** ⇒ séquencer les lots |

**Ordre logique que le challenge met en évidence (à arbitrer)** : *prouver* (O2) → *l'axe possède l'arrêt* (§7.2-1/2, sur preuve) → *alors seulement* relâcher le neutre (O1). L'option 3 n'est pas un préalable à O1 : elle **réduit** le risque de H2 sans lever la dépendance.

---

### F. 🏁 Verdict sur le diagnostic existant

# **MAJOR**

Le socle est **solide et non recopié** : l'axe est bien unique, la divergence porte bien sur la **propriété de l'arrêt**, la preuve statique de **H2 est exacte** (`:1391` + `PRG_05:414-427`), l'AX12 est bien une **sécurité géométrique**, les réfutations H3/H5/H6 tiennent, et les constats A04 (config morte) et A06/D09 (bypass non gated) sont exacts. Aucune conclusion structurelle ne tombe.

**MAJOR** parce que trois affirmations **porteuses pour la Phase 2** sont fausses ou incomplètes et orienteraient le lot dans la mauvaise direction :

1. 🔴 **H4 mal attribuée à la Trémie** (§B.2) : la coupure en 1 scan y est produite par la **coupure dure** (`PRG_06:431-450`), **un scan avant** le retrait de demande. La matrice de décision §5 ne peut donc pas discriminer H4 de la coupure dure telle qu'elle est écrite.
2. 🔴 **H4 → T287 est un raccourci** (§D) : H4 **ne touche pas la commande de frein** (`FB_Translation.st:271-272`) ; le défaut frein a un mécanisme propre (latch commande/retour, seuil 800 ms) déjà corrigé **deux fois** en MES (`FB_Translation.st:114-129`, `ST_fbTranslation_Cfg.st:35`) — le rapprochement doit être réécrit.
3. 🔴 **L'asymétrie AX2/AX14 ⇄ AX3 n'est pas une disparité non documentée** (§B.1) et **l'uniformisation de la cible (§7.2-2) casse un chemin de récupération existant** (§B.6). En l'état, « uniformiser » supprime la seule protection active contre H1.

**Corrections exigées avant d'ouvrir la Phase 2 (conception)** :
- [ ] Re-référencer **toutes** les lignes de la fiche sur une **révision figée** (§A.0 : +4 après 1221 ; `FB_CycleSemiAuto.st` est sous verrou T331).
- [ ] Corriger `PRG_07_Supervision.st:230-235` → **`:331-341`** (restauration boot des bypass) : la référence actuelle pointe la logique **T330 TOP/FdC**, sans rapport. *(Substance de A06/D09 confirmée : `:336-341` restaure bien `Bypass.Global` depuis le RETAIN, et `PRG_05:571` le consomme sans garde de mode.)*
- [ ] Ajouter dans la matrice §5 la signature **coupure dure** (`PRG_06.M3_TremieHardStopActive`) comme concurrente de H4 (§B.2).
- [ ] Requalifier le lien T287 sur le mécanisme de §B.4 (frein), **pas** sur H4.
- [ ] Intégrer T319 (`TASKS.yaml:405-425`) et `TROUBLESHOOTING_ContinuiteJoystick_AX3_AX4_20260905.md:67-82` comme **sources** de §D (l'asymétrie) — la conclusion « à documenter pour l'opérateur » devient « **déjà décidée, à ne pas défaire sans garde équivalente** ».
- [ ] Vérifier la **faisabilité au banc** de tout critère d'acceptation fondé sur `Translation_Busy`/`|fAct|` (au banc `fAct = 0` constant ⇒ `Translation_Busy = FALSE` permanent).

---

### G. 🚨 Devoir d'alerte — constats hors périmètre T334 (signalés, **non corrigés**)

| # | Constat | Emplacement | Impact |
|---|---|---|---|
| A13 | **Le délai de collage du frein n'est jamais appliqué** : `TonDecel.Q` jamais lu (0 résultat au grep sur `CODE/`), `BrakeCmd := FALSE` immédiat, alors que `BrakeDelayMotorDecel = T#2s` est « confirmé opérateur » et commenté « Délai deceleration avant collage frein » | `FB_Brake.st:23,72,93,103-104` ; `ST_fbTranslation_Cfg.st:34` ; `FB_Translation.st:282` | Config **morte** sur la chaîne frein, **périmètre T287**, hors T334. Même classe que A03 |
| A14 | **Le timeout de repli du modèle AX3 est désactivé** : `DiveStartTimeoutTimer(IN := FALSE, …)` avec `CST_DiveStartStopTimeout = T#5s` déclaré — alors que la fiche 2026-09-05 §8 exigeait « un timeout de transition vers repli sûr, **jamais un départ au terme d'un timer seul** » | `FB_CycleSemiAuto.st:262,300` (commentaire `:298-300`) | Le modèle que la §D propose de généraliser porte **lui-même** une garde non armée ⇒ à vérifier avant d'en faire la référence |
| A15 | **Commentaire FAUX sur la libération des jetons** : `PRG_05:197-199` affirme que les jetons sont libérés « UNIQUEMENT sur mouvement CONFIRMÉ soutenu ≥1,5s — pas un rebond capteur » ; l'implémentation les RAZ sur **changement du mot capteurs** (`:275-277`) et `TonM3ConfirmedMoving.Q` n'est **jamais lu** | `PRG_05:197-201,275-277` | Prolonge A03 : c'est **exactement** la bascule de H1, et le commentaire laisse croire l'inverse ⇒ un lecteur futur conclurait à tort que H1 est impossible |
| A16 | **Conflit AF-09 / Graphe 7 mal cadré** : `TROUBLESHOOTING_T336_…:74,100,105` présente le `UseDynamicTarget := FALSE` comme un forçage à arbitrer, alors que le code **porte le REX de l'incident** (écart apparent M1/M2 ~15 m → `FB_WinchSync` SafeStop → `Fault.Latched`) | `FB_CycleMachineHoming.st:412-420` vs fiche T336 | La question n'est pas « quelle source est décisionnelle ? » mais « comment réactiver la cible dynamique **sans** réintroduire l'incident ». **Hors T334** (voir §A.1-5) |
| A17 | **Collision de tag à nouveau** : cette session a d'abord journalisé sous `DSH08` (**déjà pris par T295 depuis 18:02:24**) puis s'est re-taggée `DSH10`. Même motif que T330→DSH06 et T331→DSH09 : le registre s'attribue par « premier libre » **sans pose atomique** | `TASK_LOCKS.json` (`T295` DSH08, `T331` DSH09) ; `TOOLS/AGENT_WORKFLOW/status/T334bis.log` (18:41:28 **mis-taggé**, corrigé 18:41:34) | Traçabilité. **Aucune réécriture automatique** ; tri à l'orchestrateur |
| A18 | **Conflit de verrou à venir** : l'option 3 touche `CODE/G_CYCLE/FB_CycleSemiAuto.st`, **sous verrou d'écriture T331/DSH09** depuis 17:57, et `PRG_05_Translation.st` (libre) | `TASK_LOCKS.json` clé `T331` | Un lot T334 sur ce fichier **casserait** la règle « un seul agent écrit dans un même périmètre » ⇒ séquencement obligatoire |

---

### H. 📝 Journal de la session T334 bis (read-only)

- 2026-09-20 18:41 : briefing chargé (`subagent_preamble.md`, skill `troubleshooting` canonique). Tag **DSH10** (après correction d'un premier log mis-taggé `DSH08`, cf. A17). **Aucun verrou pris.**
- Relevé `git rev-parse HEAD` = `fd12dc0` **+ arbre modifié** ; détection du décalage **+4** sur `FB_CycleSemiAuto.st` (édition T331/DSH09 à **18:13:32**, postérieure à la fiche **18:07:20**).
- Vérification **fichier:ligne** des 5 affirmations ; relecture directe de `FB_CycleSemiAuto.st`, `PRG_05_Translation.st`, `FB_Translation.st`, `FB_TranslationCmdArbitrationM3.st`, `FB_TranslationOutputInterlock.st`, `FB_Translation_PositionDecoder.st`, `FB_Brake.st`, `FB_Safety_Translation.st`, `FB_Safety_Winch.st`, `FB_Winch.st`, `FB_WinchStateProjection.st`, `FB_CycleMachineHoming.st`, `FB_Modes.st`, `PRG_06_Outputs.st`, `PRG_07_Supervision.st`, `ST_*` de types, `GVL_PERSISTENT.st`, `TASK_LOCKS.json`, `TASKS.yaml`, `AF_Partie-04/11`.
- Trouvailles : 3 écarts de **fond** (§B.1, §B.2, §B.4/§B.6) + 2 configs mortes (§B.5, A13) + 4 erreurs/imprécisions de **citation** (§F) + 1 claim **hors fiche** (§A.1-5).
- **Aucun fichier de `CODE/` écrit, aucun test, aucun gate, aucun bundle, aucune IHM, aucun commit.** Seul livrable : la présente section.

---

## 11. 🧭 Suivi de l'arbitrage Phase 2 (DSH07, 2026-09-20 — ZÉRO code)

> 📌 Livrables : `DOC/WFLOW/CONTRACTS/PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` (arbitrage + modèle cible + lots séquencés) et le bloc `decisions` Q1→Q6 du contrat C3 — `check_task_contract.py` **PASS (0 erreur, 0 avertissement)**, y compris en `--release`.

| Question | Verdict retenu | Porté par |
|---|---|---|
| **Q1** autorité de l'arrêt | 🟢 **OUI** — l'axe arme son verrou sur la **seule** détection d'arrivée, **jamais** levé par la perte de la demande ; relâchement = demande de sens inverse seule (inchangé). **C'est la correction qui neutralise H1 à la racine** (`FB_Translation.st:251`) | L1 |
| **Q2** cible / sens | 🔴 **NON** — la cible d'étape reste la cible d'arrivée en SEMI_AUTO ; l'uniformiser en AX2 détruirait le chemin de récupération de dépassement (§B.6) | L1 (commentaires) |
| **Q3** retrait de la demande | 🟢 **OUI, option (a)** — demande et cible conservées jusqu'à `ArrivalLock` + arrêt confirmé ; « la barrière commande l'arrêt » **rejetée** (duplication du producteur) | L2 *(verrou T331)* |
| **Q4** bypass | 🟡 **OUI** — garde de mode au point de **consommation** (`PRG_05:468`, `:571`), doctrine MAINT_N2 ; `PRG_07` non touché | L1 |
| **Q5** escalade butées | ⛔ **HORS LOT** — `FB_Safety_Translation.st` interdit au contrat ; écart spec/code confirmé et chiffré | contrat dédié |
| **Q6** config morte | ⛔ **HORS LOT** — recommandation **supprimer** `_TranslationAutoSpeedCap_Pct` | contrat dédié |

**Ce que l'arbitrage ajoute au diagnostic :**
- 🆕 **Q7 (ouverte)** : à la Trémie, la **coupure dure** (`PRG_06:431-432` : `M3_PosTremie_DI AND ReqTremieSemantic`) arme frein fermé + mot 0 **au même scan** ⇒ conserver la demande jusqu'à l'arrêt (Q3) **prolonge** cette exposition (classe de faute frein T287, §B.4). À trancher **sur trace en L0** — décision humaine **D3**.
- Le levier exact de **H4 à P1** est nommé : `FB_Translation.st:229-233` + `:297-303` (mot 0 = **roue libre en mouvement**), neutralisé par Q3/§I2 (mot non nul pendant toute la décélération).

**Corrections exigées par §F — état :**

| Exigence §F | État |
|---|---|
| Re-référencer la fiche sur une **révision figée** | 🟡 **non levé** — `FB_CycleSemiAuto.st` toujours modifié non commité (T331) ; convention `WT`/`HEAD` documentée au **plan §0.1** ; à figer avant tout diff de `CODE/` |
| Corriger `PRG_07:230-235` → `:331-341` | ✅ **fait** — valeur exacte relevée directement : **`:336-346`** (bloc Translation `:341-346`) |
| Ajouter la signature **coupure dure** comme concurrente de H4 (§B.2) | 🟡 reporté en **L0** (enrichissement de la procédure de trace) |
| Requalifier le lien T287 sur le mécanisme de §B.4 (frein) | ✅ **intégré** — plan §6 (A13) et contrat (`lien_T287`) |
| Intégrer T319 + fiche 2026-09-05 comme **sources** de §D | ✅ **intégré** — c'est la base de la décision « le neutre reste en place » (invariant I4) |
| Vérifier la **faisabilité au banc** des AC fondés sur `Translation_Busy` | ✅ **intégré** — AC15 exige l'injection de `Translation_Busy := TRUE` (sinon l'assertion est vacuaire) |

- 2026-09-20 19:09 (DSH07) : arbitrage rédigé, **zéro `CODE/`**, aucun test, aucun gate, aucun bundle, aucun commit. Toutes les références du plan et du contrat ont été relues **directement dans les sources**.
