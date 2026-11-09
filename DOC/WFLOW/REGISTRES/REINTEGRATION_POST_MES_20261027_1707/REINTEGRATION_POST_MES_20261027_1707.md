# 📦 REGISTRE DE RÉINTÉGRATION — code retiré pour revenir à l'état machine

| Champ | Valeur |
|---|---|
| 🕐 Créé le | `2026-10-27T17:07:51+01:00` |
| ✍️ Auteur | CC01 (Claude Code), sur instruction HUM |
| 🌿 Branche de travail | `work/base-machine-simu` (créée depuis `main` = `b305a130`) |
| 🏭 Référence machine | Commit `e38cc09a` (23/09 16:37 « checkpointMESSoir ») ≈ projet CODESYS `v0.7.25_…DernièreMES` |
| 🔐 Export machine de vérité | `PRJ_CODESYS/PROJ_Full_ImportExport/v0.7.25_CptHorraireGVLPerssistantePasImplémenté_DernièreMES_20260922.export` (exporté le 27/10 15:05, **non versionné** — gitignoré) · SHA256 `3ce77cd23627ff75fd350ab8d40f7592e2338e92ad6c80d606eb053ecec1d941` |
| 💾 Sauvegarde état complet avant retour | Branche `backup/etat-20261027`, commit `322b1fc6` (contient aussi le patch T255-B, NE PAS CHARGER) |

---

## 🎯 Pourquoi ce registre

`main` contenait du code **jamais chargé sur la machine** : une ligne de travail d'agents du **22/09** (pendant la MES) fusionnée dans `main` le **26/09** par le merge `420e2eea`, puis de la simulation (27/09 → 15/10).

Décision exploitant (27/10) : **code fonctionnel = identique à la mise en service**. Tout le reste est retiré de `CODE/` et listé ici, pour **décider plus tard, lot par lot**, de le réintégrer, le refaire autrement ou l'abandonner.

✅ Vérifié (revue indépendante, 27/10) : `CODE/` de la branche = `e38cc09a` à l'octet près ; les marqueurs des éléments retirés sont **absents** de l'export machine (`AX15D_DUMP_BUCKET_JOG`, `BucketCloseAscentGrant`, `ClosePermitDeniedWhileRequested`, `SimPhaseRotationOk`, `SimM3PlcEcho`, `M3_OpenModelicaActive`… = 0 occurrence).

---

## 📋 Tableau de suivi — À COCHER PAR L'EXPLOITANT

| Lot | Contenu | Commit(s) d'origine | Diff | Décision |
|---|---|---|---|---|
| **R1** | Étape **AX15D** : refermer/rouvrir benne sur place à la trémie | `0358c631` (T383, 22/09) | [`R1_AX15D_T383.diff`](R1_AX15D_T383.diff) | ⬜ réintégrer · ⬜ refaire · ⬜ abandonner |
| **R2** | **T387** benne/sécurité (8 changements, voir détail) | `dff0b535` (T387, 22/09) | [`R2_T387_BENNE_SECURITE.diff`](R2_T387_BENNE_SECURITE.diff) | Par sous-point, voir § R2 |
| **R3** | Textes bannière IHM liés à R1 et R2 | `0358c631` + `dff0b535` | [`R3_BANNIERE_T383_T387.diff`](R3_BANNIERE_T383_T387.diff) | Suit R1/R2 |
| **R4** | **Simulation** post-MES + écho/aiguillage `PRG_02` | voir § R4 | [`R4_SIMULATION_ET_PRG02.diff`](R4_SIMULATION_ET_PRG02.diff) | ✅ **Décidé : réintégrer SANS OpenModelica** (étape 2) |
| **R5** | Divers non fonctionnels | voir § R5 | [`R5_DIVERS_NON_A_REINTEGRER.diff`](R5_DIVERS_NON_A_REINTEGRER.diff) | ❌ Ne pas réintégrer |

> 📎 Les fichiers `.diff` vont de **l'état machine (`e38cc09a`) vers `main`** : ils montrent exactement ce qui serait ajouté en les réintégrant. Les commits d'origine restent consultables : `git show <commit>`.

### 🗓️ Décision exploitant 2026-11-09 — `main` avancé sur la base machine

`main` = `work/base-machine-simu` (`bb0f65c7`, fast-forward, accord « push A »). L'ancien `main`
(`b305a130`, contenant R1/R2/R3) est conservé sous le tag `backup/origin-main-avant-ff-20261109` ;
le mot « `main` » des `.diff` ci-dessus désigne désormais ce tag.

| Lot | Décision 2026-11-09 | Motif exploitant |
|---|---|---|
| R1 AX15D | ❌ **non récupéré** | Code fonctionnel identique à la machine, pour que la simulation porte le même code ; fonction à refaire proprement plus tard |
| R2-C levée FdC matériel haut M2 | ❌ **jamais** | On ne lève pas un FdC matériel |
| R2-E MecaB / faux `ErrorID:09` | ❌ **non récupéré** | La simulation doit expliquer la cause du défaut, pas le masquer |
| R2-H palier 1 au homing (et R2-F/G liés) | ❌ **non récupéré** | Contrainte nouvelle du 22/09, jamais chargée ; homing à refaire après M3 |
| R2-B, R2-D, R3 | ⬜ non tranchés individuellement | Absents de `main` ; R2-D et R3 suivent R1/R2 |

Les changements M3 hors simulation (gain odométrique T301, défauts positions 1,5/3,5/5/10 m,
compteurs horaires UDINT) sont **validés et conservés** : ils ne modifient pas le comportement fonctionnel.

---

## R1 — Étape AX15D (T383) · ⚠️ C4

- **But** : à la trémie, après vidage (AX15B), **tirer** le joystick → AX15D = fermer la benne **sur place** (treuils et translation à 0) ; pousser = rouvrir ; relâcher = retour AX15B ; benne ouverte + vidage fait = AX18.
- **Sur la machine aujourd'hui** : AX15B sort seulement vers AX15C (repositionnement) ou AX18. Tirer ne fait **rien** (le texte opérateur « Tirer : fermer et remonter » est **faux** — déjà sur machine, à corriger un jour). **Aucun saut AX15B → AX10** (retiré sur site le 23/09, commit `fe577ec2`).
- **Fichiers** : `FB_CycleSemiAuto.st` (étape + transitions + forçage borne 22→23 + exclusion sync), `E_AutoCycleStep.st` (`AX15D_DUMP_BUCKET_JOG := 23`), `FB_Joystick.st` (**commentaire seul**).
- **Dépendance forte** : sans R2-B/C/D, fermer la benne à la trémie bute sur le FdC haut (timeout `ErrorID:03`).
- **Exploitant (27/10)** : fonction **voulue**, à refaire plus tard proprement.

## R2 — T387 benne / sécurité · ⚠️ C4 (FB de sécurité)

Un seul commit, **8 changements de natures différentes** :

| # | Changement | Fichier | Lié à AX15D ? | Note exploitant / revue |
|---|---|---|---|---|
| R2-B | Butée **logicielle relative** M2/M1 étendue à la fermeture **auto** (existait déjà en jog manuel) | `PRG_04` | ✅ | Piste à garder (FdC **logiciel** calculé, position M2 corrigée) |
| R2-C | ⛔ **Levée du FdC MATÉRIEL haut M2** sous 4 verrous (`BucketCloseAscentGrant`) | `PRG_04`, `FB_Safety_Winch` | ✅ | **REFUSÉ par principe** : on ne lève jamais un FdC matériel. Contexte aggravant : FdC haut M1/M2 cassé et shunté par le client (registre 26/09) |
| R2-D | Timeout benne **gelé** + « en attente opérateur » quand un permis bloque la fermeture (`ClosePermitDeniedWhileRequested`, `WaitingForOperator`) | `FB_Bucket`, `PRG_04` | ✅ | Utile seulement avec AX15D |
| R2-E | **MecaB** : `JoystickYNeutral` → `NOT MovementCommanded` (faux `ErrorID:09` en MAINT_N2 **par boutons IHM**) | `FB_Safety_Winch` | ❌ | Indépendant. **Important** pour l'exploitant → lot séparé C4 |
| R2-F | Butées benne relatives appliquées **seulement si codeurs M1 et M2 référencés** | `PRG_04` | ❌ | Lot benne/homing |
| R2-G | Ralentissements d'approche jog benne seulement si `ManualBucketLimitsActive` | `PRG_04` | ❌ | Lot benne/homing |
| R2-H | **Homing machine : palier 1 max imposé** (montée et descente) pendant tout le cycle de homing | `PRG_04` | ❌ | Lot homing (lien T377) |
| R2-I | Message « Référencement en cours — codeurs non référencés (normal) » au lieu de `ErrorID:05` en MAINT/homing | Bannière (R3) | ❌ | Affichage |

Décision par sous-point : B ⬜ · C ❌ refusé · D ⬜ · E ⬜ · F ⬜ · G ⬜ · H ⬜ · I ⬜

📎 Note d'application d'origine : `git show dff0b535:DOC/WFLOW/CONTRACTS/NOTE_APPLICATION_T387_FENETRE_BENNE.md` · tests CI d'origine : `test_fb_safety_winch.st` (T387-001, T387-FB-002), `test_fb_bucket.st` (T387-FB-003).

## R3 — Bannière IHM (`FB_Hmi_BannerFormatter`)

Textes AX15D (R1) + message référencement R2-I. Suit les décisions R1 et R2-I.

## R4 — Simulation · ✅ à réintégrer (étape 2) SANS OpenModelica

| Commit | Date | Contenu |
|---|---|---|
| `9253e516` (T306) | 22/09 (via merge) | Défaut rotation de phase **injectable en simu** : `FB_Sim_Safety`, `FB_SimBench`, `GVL_Simulation.SimPhaseRotationOk`, câblage `PRG_02` |
| `a5ed9a7c` | 27/09 | Aiguillage M3 vers OpenModelica (`M3_OpenModelicaActive`) — ❌ **à exclure** |
| `95c9ed5d` | 04/10 | Lien Modelica `FB_Sim_Translation_ExtLink` (**lib SysSocket**), écho `SimM3PlcEcho`, `SimM3Link*` — ❌ **à exclure** |
| `5d187eeb` | 13/10 | T417 M3 50 Hz |
| `9630ddb5`, `19abfcdf`, `f4db569d` | 15/10 | Joystick simulé, geste opérateur, `OperatorSourceActive` |
| `b305a130` | 15/10 | Roulis benne AX15B (`BucketOffsetOpen_M`, `BucketOpenAnticipation_M`, `BucketAx15bOpenActive`), `SimWinchCoast_M` 0,35 → 1,30 m |

⚠️ Dans `PRG_02` (main), retirer aussi la condition joystick **AX15D** (T383) lors de la réintégration.
⚠️ Décision exploitant (27/10) : **aucun risque sur site** → pas de lien OpenModelica / SysSocket dans le code machine (composant runtime VH601 non vérifié).
ℹ️ Rotation de phase : la protection réelle est **identique** machine/main ; le défaut constaté sur site (« mal géré ») est **non corrigé** → tâche **T386** (⬜), priorité à réévaluer.

## R5 — Divers · ❌ ne pas réintégrer

- `PRG_07_Supervision.st` : **doublon** de câblage `CycleElapsed_Min/S` (lignes 815-816 de main, commit `721939cb` T368) dans le même appel que les lignes 781-782 déjà présentes. L'affichage T368 **reste** (déjà sur machine via `d95904ae`). Le doublon est un bug de `main`.
- `ST_CycleCmd.st` : **commentaire seul** (`TglAutoDiveM2Step5Trial`, origine `708a0f44` qsave/T381).
- `FB_Joystick.st` : **commentaire seul** (mention AX15D) — inclus dans R1.diff.

---

## ✅ Ce qui RESTE dans la base (déjà dans `e38cc09a`)

- ⏱️ Compteurs horaires (`d95904ae`) — **non chargés sur machine** à cause des persistantes ; procédure : relever les persistantes → charger → réécrire.
- ⏱️ Chrono cycle incluant la pause + affichage temps écoulé (T368).
- 🔧 Réglages fin de MES : approche M3 20 Hz, marge T330 0,40 m, `BrakeFeedbackTimeout` M3 1000 ms, `ExtractionStartOpening_Pct` = 10 (voulu exploitant).

## ⚠️ Défauts terrain connus PRÉSENTS dans la base (non corrigés)

- 🛑 Arrêt M3 au-delà de P1/Trémie (roue libre, frein ouvert ~2 s sans commande) → **T334** (priorité 1).
- 🔌 Rotation de phase mal gérée → **T386**.
- 🔝 FdC haut M1/M2 cassé/shunté côté client (registre `REGISTRE_PrepaNextMES_20260926.md`).

## 🔁 Comment réintégrer un lot (procédure)

1. Partir de `work/base-machine-simu` (ou de la branche courante issue de celle-ci).
2. Lire le `.diff` du lot, ne garder que les sous-points validés (édition manuelle si partiel).
3. Contrat de tâche (C2+), tests CI, bundle, `G200_check_linkage.py --report`, gates.
4. Recomparer à l'export machine : seuls les écarts du lot doivent apparaître.
5. Cocher la décision dans ce registre + `TASKS.yaml`.
