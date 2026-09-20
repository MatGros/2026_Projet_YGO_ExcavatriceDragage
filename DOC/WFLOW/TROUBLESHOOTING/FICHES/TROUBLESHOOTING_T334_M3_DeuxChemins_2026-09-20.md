# 🕵️ Troubleshooting T334 — Translation M3 : deux chemins de commande (manuel/MAINT vs cycle auto) ?

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`
> 📅 Date : 2026-09-20 · 🧊 Situation : [SITE] constat opérateur (machine en service) + hypothèses vérifiables [SIMULATION BANC] · 📄 Statut : **EN COURS — analyse livrée, en attente de validation humaine du comparatif**
> 🎫 Tâche : `T334` (C3) · 🏷️ Acteur : **DSH07** (verrou posé `DOC/WFLOW/TASK_LOCKS.json`, tag vérifié 2026-09-20) · 🔒 Verrou orchestration : CC01
> 🚫 **Analyse read-only `CODE/`.** Aucun fichier `CODE/`, aucun test CI, aucun gate, aucun `CODE_XML/`, aucun `Device.export`, aucune IHM touchés. Aucun correctif proposé (§5 est « en principe »). Aucun commit.

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

---

## 9. 📊 Variables EXACTES à tracer à 10 ms (preuve de H1→H6)

> Base : `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T300_M3_SIMBENCH.md:9` (trace **tâche 10 ms** obligatoire : « une trace à 100 ms ne peut pas qualifier un délai de frein de 90 ms »), `:28-42` (étages de preuve), `:44-56` (variables minimales). Les ajouts **T334** sont les lignes marquées 🆕 — sans elles, aucune des 6 hypothèses n'est discriminable.
> ⚠️ Les chemins `instXxx.<interne>` sont des **internes de FB** : traçables par symbole CODESYS, mais **jamais** lus par du code (`CODE_QUALITY_STANDARDS.md:526-527`, « internes privés »). Si l'outil de trace ne les expose pas, la preuve doit passer par les équivalents publiés (`Data.*`, `TranslationState.*`) — signaler alors la variable manquante au diagnostic au lieu de conclure.

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
| A01 | **Contrat de tâche T334 inexistant** alors que `TASKS.yaml:38` le référence | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` (absent) | Tâche C3 sans contrat → cas d'arrêt du préambule ; à produire par l'orchestrateur |
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

---

## 11. 🏁 Conclusion

- **Cause racine : NON PRONONCÉE** (exigence `AC4` : hypothèse + preuve, pas d'inférence). Hypothèse principale **H1** (le cycle recrée sa demande de marche quand le jeton d'arrivée est effacé par un rebond/perte capteur, faute de verrou d'arrêt latché côté cycle = **H2**), aggravée par **H3/H4**, avec l'escalade **H6** comme conséquence observable (rapprochement direct avec `T287`).
- **Question de conception : TRANCHÉE** → **ANOMALIE partielle** (§7.1) : sources séparées = obligatoire et conforme ; **arrêt non possédé par l'axe** = anomalie modifiable.
- **Statut** : `[EN COURS]` — analyse livrée ; **arrêt en attente de validation humaine du comparatif** avant toute proposition de code (`TASKS.yaml:29`).

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

---

📖 Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` · Gabarit : `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`
🔗 Tâches liées : `T287` (défaut frein aux mêmes arrivées), `T300` (banc + perte capteur ~1 s), `T333` (estimateur — **non consommé** par les deux chaînes), `T319` (continuité AX2→AX3), `T204` (permits directionnels), `T327` (verrou descente benne).
