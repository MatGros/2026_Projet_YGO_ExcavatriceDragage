# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — Treuil M2 : limites descente inopérantes

> 📌 **Emplacement obligatoire** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TreuilM2_LimiteDescente_20260901.md`.
> 📅 Date : 2026-09-01 · 🧊 Situation : [BANC SIMULATION] · 📄 Statut : [EN COURS — cause racine PROUVÉE par test CI, correction à valider]

> ## ⛔ Rectificatif — diagnostic précédent invalidé (2026-09-01)
>
> Les conclusions des sections 4 à 8 ne sont **pas validées** et ne doivent entraîner
> **aucune correction de code ni de configuration**. Elles reposaient sur une causalité
> déduite, non prouvée : le rapprochement entre `DescendPermitEffective = FALSE` et une
> sortie de descente active ne démontre pas que ce permis est le gate de cette sortie.
>
> En particulier, l'affirmation selon laquelle les seuils bas devraient être négatifs est
> **fausse** : le comportement confirmé par l'utilisateur est bien « position mesurée
> inférieure au seuil => voyant allumé », avec des seuils positifs. Le bypass simulation
> n'est pas une cause candidate tant que le symptôme est identique avec ou sans bypass.
>
> Statut : **diagnostic rouvert depuis le graphe réel de commande de la sortie M2**.

> ### Complément simulation — fait statique vérifié
>
> `GVL_Simulation.SimTopPositionActive` est un stimulus réel : il est transmis à
> `FB_SimBench` puis produit `HwSim.Winch.M1M2_TopPositionFree_DI := NOT SimTopPositionActive`.
> Le capteur haut n'est donc pas « ignoré » en simulation ; il est simulé de façon granulaire.
>
> À l'inverse, aucun stimulus `Sim…Slack…` n'existe : `FB_SimBench` force actuellement
> `HwSim.Winch.M2_TensionedCable_DI := TRUE`. Les indicateurs IHM
> `SimTopSensorBypassActive` / `SimSlackCableBypassActive` sont mis à TRUE dès que le domaine
> treuil est simulé, indépendamment de l'état des capteurs ; leur libellé « bypass » est inexact.
> Ce point est distinct du symptôme de limite basse et doit être corrigé par un contrat simulation
> explicite avant de conclure sur un essai impliquant le mou de câble.

> ### ✅ Réponse au rectificatif — preuve mécanique (2026-09-01)
>
> Le doute « causalité non prouvée (corrélation snapshot) » est levé par **test CI ad hoc** (§6bis) :
> `FB_Winch` réel compilé et exécuté, **variable isolée = `MinStepDown`**. Résultats :
> `DescendPermit=FALSE` + `MinStepDown=1` → `StepNumber=1` (**descente maintenue**) ;
> `DescendPermit=FALSE` + `MinStepDown=0` → **arrêt immédiat**. Le graphe réel de commande de la
> sortie est confirmé : le permis descente EST un gate de la sortie (`FB_Winch.st:163` → `:205`),
> mais le plancher `MinStepDown` (`:242`) s'exécute **après** la mise à 0 et relance le palier 1.
>
> Révisions suite aux retours utilisateur :
> 1. **Voyants NON fautifs** — ils reflètent correctement « position ≤ seuil » (confirmé utilisateur).
> 2. **Bypass éliminé** — `SimulationBypassActive=FALSE` → même symptôme (test utilisateur).
> 3. **Polarité requalifiée** — seuils (légal +5 / câble 0.0) saisis au hasard pour test : pas de
>    « mauvaise saisie » à corriger, et **aucune valeur de seuil ne pouvait arrêter la descente**
>    tant que le bug existe.
>
> Restent 2 notes de conception (§7), distinctes du bug : limite câble `0.0` ignorée par le garde
> `< 0.0` ; permis descente non affiché à l'IHM (existe côté PLC : `GVL_IHM.M2TreuilBenne.Safety.DescendPermit`).

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
- Utilisateur en mode treuils, **treuil M (M1) inhibé** → utilisation **uniquement du treuil M2**.
- Limite haute logicielle 7,50 m : **fonctionne** (arrêt OK en position haute).
- Limites basses configurées : **limite légale = 5 m**, **limite max = 0 m**.
- Voyants « limite légale » et « limite max » **allumés** sur l'IHM.
- **Aucun verrouillage de descente** : pas d'info « permission de descente », contacteur descente autorise → descente possible jusqu'à **-20 m**.

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Snapshot | `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260901_014859.csv` | 499/499 | 2026-09-01 01:48 |
| Mode | `ContexteMachineGlobal.Idx101_ModeActive` | MAINT_N2 | 01:48 |
| Simulation | `Idx102_SimulationEnabled` | TRUE (banc) | 01:48 |
| Treuil M1 inhibé | `TraceWinchM1.Inhibited` / `BlockReason` | TRUE / AXIS_DISABLED | 01:48 |
| Position M2 | `LevageUnitaireM2.Idx102_CablePos_M` | -7,26 m (en descente) | 01:48 |
| Position M1 | `LevageUnitaireM1.Idx102_CablePos_M` | +20 m (⚠️ incohérent, simu) | 01:48 |
| Limite basse active M2 | `LevageUnitaireM2.Idx414_BottomLimitActiveM` | **+5,0 m** (seuils au pif : légal +5 / câble 0.0) | 01:48 |
| Permis descente M2 | `LevageUnitaireM2.Idx309_DescendPermitEffective` | **FALSE** | 01:48 |
| Sortie descente M2 | `LevageUnitaireM2.Outputs_500.Idx502_CmdRelayDescent_DQ` | **TRUE** (contradiction — expliquée §6bis) | 01:48 |
| Palier M2 | `LevageUnitaireM2.Idx402_SpeedStepCalculated` / `MotionM2.RelayRevActive` | 1 / TRUE | 01:48 |
| Zone ralentissement basse | `LevageUnitaireM2.Idx413_InBottomSlowdownZone` | TRUE | 01:48 |
| Limite légale atteinte | `CycleSemiAuto.Idx305_LimitLegalReached` | TRUE | 01:48 |

## 2. 🎯 Symptôme

Avec treuil M inhibé (M2 seul), les limites logicielles basses M2 (légale 5 m / max 0 m) **n'interdisent pas la descente** : voyants allumés mais aucune permission de descente requise, contacteur descente fermé, descente jusqu'à -20 m. **Permanent** (reproductible). Limite haute 7,50 m fonctionne.

## 3. 🧩 Indices / historique

- Derniers changements : à confirmer (git récent : `FB_WinchOutputInterlock`, `PRG_04_Treuils_Benne`, `PRG_06_Outputs` modifiés — voir §10).
- Déjà essayé : rien de rapporté.
- Conditions d'apparition : **treuil M1 inhibé** + commande M2 seule. → suspect : la logique de limite basses n'est active qu'en mode synchro/levage couplé, ou calcule sur la position **M1** (inhibée → position invalide/gelée).
- Alarmes : non rapportées.

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Limites basses évaluées sur position M1 (inhibé → gelée) | `LimitLegalReached` (PRG_07:308) | OR des 2 positions | TRUE | ❌ éliminée (M2 lue aussi) |
| 2 | Verrou limite actif seulement en synchro M1+M2 | `TraceWinchM2.DescendPermitEffective` | TRUE si non atteinte | **FALSE** | ❌ éliminée — permis M2 calculé et FAUX (blocage détecté 🟢) |
| 3 | Bypass simu/MAINT_N2 neutralise le verrou (mou de câble) | test utilisateur `SimulationBypassActive=FALSE` | pareil | **pareil** | ❌ éliminée par test utilisateur (🟢) — le bug est indépendant du bypass |
| 4 | Voyants faux (franchissement non réel) | observation utilisateur | voyant = franchissement réel | allumés au bon moment | ❌ éliminée (🟡 confirmé utilisateur) — **les voyants fonctionnent** |
| 5 | Verrou inexistant / pas appliqué au contacteur | `StepNumber`/`RelayRev` avec permis FAUX | 0 / FALSE si permis FAUX | **StepNumber=1, RelayRev=TRUE** | ✅ **cause racine** : plancher `MinStepDown` (FB_Winch.st:242) relance le palier 1 **après** la mise à 0 par `EffectiveSafeStop` — **confirmé par test CI (§6bis)** |
| 6 | Régression diff non committé `FB_WinchOutputInterlock` | `Idx405_FinalInterlockState` | FAULT | READY, transmet | ❌ éliminée (barrière non fautive) |

**Pourquoi la limite HAUTE 7,50 m fonctionne** : le plancher `MinStepDown` ne s'applique qu'en **descente** (`Direction = -1`, FB_Winch.st:242). En montée, `EffectiveSafeStop` (via `AscentPermit`) met bien la cible à 0 et rien ne la relève → arrêt à 7,5 m. Asymétrie exacte du symptôme, **prouvée par test CI** (TROUBLESHOOT-03 vs 02).

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
Joystick Y = -100 % (descente demandée, StartStop=1, Dir=-1, StepTgt=1) ✅
 ├─ [CFG] Seuils saisis au pif (légal +5 / câble 0.0) — PAS une erreur de saisie : les voyants
 │   reflètent bien « pos ≤ seuil » (comportement confirmé par l'utilisateur) ℹ️
 │   └─ Note conception : garde FB_Safety_Winch.st:252 (CfgCableLimitDescentM < 0.0) → limite
 │      câble 0.0 jamais évaluée comme cause (à trancher si « interdit sous 0 m » doit exister)
 ├─ [SAFE] FB_Safety_Winch §3 : DescendPermit := NOT(... OR LimitLegalReached ...) = FALSE ✅ détecté
 ├─ [SAFE] EffectivePermitM2_Descend = FALSE (Idx309=FALSE, Idx502 trace=FALSE) ✅ propagé
 ├─ [LOGI] FB_Winch §3 : EffectiveSafeStop = TRUE (Dir=-1 ET NOT DescendPermit) ✅ calculé
 ├─ [LOGI] FB_Winch §5 : RampTargetStep := 0 → RequestedStep = 0 ✅… PUIS
 │   └─ [BUG] Plancher MinStepDown (st:242 : StartStop AND Dir=-1 AND MinStepDown>0,
 │            CommonMinStepDown = MAX(1, ·) ≥ 1 TOUJOURS, PRG_04:862)
 │            → RequestedStep := 1 — PAS de gate NOT EffectiveSafeStop ❌❌ CAUSE RACINE
 ├─ [ACT] StepShaper → StepNumber=1 → RelayRev=TRUE (Idx502_DQ=TRUE) ❌ descente continue (palier 1)
 │   └─ InBottomSlowdownZone TRUE (pos ≤ 5+1) → plafond 1 : descente au ralenti SANS arrêt
 └─ [ACT] Barrière finale : SafeStop=FALSE (causes directionnelles EXCLUES du SafeStop,
          FB_Safety_Winch:408) → la barrière TRANSMET la commande ❌ pas de défense en profondeur
```

**Résumé une ligne** : `[Joy=-100%] → [DescendPermit=0 ✅] → [EffectiveSafeStop=1 ✅] → [Plancher MinStepDown=1 ❌ BUG] → [StepNumber=1, RelayRev=1] → descente jusqu'à -20 m`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Snapshot 01:48 (499/499, 🟢) — **prise pendant le symptôme** : M1 inhibé (`TraceWinchM1.Inhibited=TRUE`, `AXIS_DISABLED`), M2 en descente active (`RelayRev=TRUE`, `StepNumber=1`, `AuthorizedStep=1`, pos **-7,26 m**).
- `Idx414_BottomLimitActiveM = REAL#5` 🟢 → `MAX(CfgCableLimitDescent_M, LimitLegal)` = MAX(≤5, **+5**) = +5 → preuve directe de la saisie positive de la limite légale.
- `Idx309_DescendPermitEffective = FALSE` 🟢 + `MotionM2.RelayRevActive = TRUE` 🟢 → **contradiction interne prouvée** : permis refusé + descente energisée.
- `Idx413_InBottomSlowdownZone = TRUE` 🟢 (pos -7,26 ≤ 5+1) → palier borné à 1 : descente lente continue, cohérent avec le rapport opérateur.
- Mode `MAINT_N2`, `SimulationEnabled=TRUE` (banc simu).
- Anomalie secondaire : M1 position **+20 m** (physiquement impossible, capteur haut 8,5 m) — simu/codeur M1 à vérifier séparément.

### Chronogramme (observé 🟡)
| <nobr>Événement</nobr> | <nobr>Position M2</nobr> | <nobr>DescendPermit</nobr> | <nobr>Voyant légal</nobr> | <nobr>RelayRev</nobr> |
|:---:|:---:|:---:|:---:|:---:|
| Départ (pos < +5 m) | < +5 m | FALSE | █ (allumé) | — |
| Descente commandée | ↓ décroît | FALSE | █ | █ (palier 1) |
| Passage -5 m | -5 m | FALSE | █ | █ continue |
| Arrêt observé | ≈ -20 m | FALSE | █ | (arrêt manuel/fin câble) |

### §6bis. 🔬 Test CI ad hoc — preuve mécanique (🟢, dossier jetable `_TROUBLESHOOTING/`)

`FB_Winch` réel (sources du repo, registry.yaml) compilé STruCpp + exécuté.
Runner : `RESULTS/_TROUBLESHOOTING/run_minstepdown_test.py` · Test : `tests/test_fb_winch_minstepdown.st`.
Scénario = snapshot 01:48 reproduit : `StartStop=TRUE, Direction=-1, SpeedStepReq=1`, permis basculé en cours de descente. **Variable isolée : `MinStepDown` uniquement.**

| Test | Entrées | Attendu correct | Obtenu | Verdict |
|---|---|---|---|---|
| TROUBLESHOOT-01 | `DescendPermit=TRUE`, `MinStepDown=1` | descente palier 1 (plongée nominale) | idem | ✅ PASS |
| **TROUBLESHOOT-02** | **`DescendPermit=FALSE`, `MinStepDown=1`** | **arrêt (`StepNumber=0`, `RelayRev=FALSE`)** | **`StepNumber=1` — descente maintenue** | ❌ **FAIL = bug confirmé** |
| TROUBLESHOOT-03 | `DescendPermit=FALSE`, `MinStepDown=0` | arrêt immédiat | idem | ✅ PASS |

Le contraste 02/03 (seule différence : `MinStepDown`) isole le plancher comme cause. L'échec 02 reproduit exactement la contradiction du snapshot 01:48 (`Idx309=FALSE` + `Idx502_DQ=TRUE`).

## 7. 🏁 Conclusion

- **Cause racine (code, C0 sécurité — PROUVÉE par test CI §6bis)** : le **plancher de palier `MinStepDown`** (`FB_Winch.st:242-249`) relance `RequestedStep` à ≥1 **après** que `EffectiveSafeStop` (permis descente FAUX) a mis la cible à 0. Comme `CommonMinStepDown := MAX(1, ·)` (`PRG_04:862`) est **toujours ≥ 1**, toute descente commandée (StartStop + Dir=-1) maintient le palier 1 **quoi que disent les permis** → limite légale, limite câble et mou de câble sont **inopérants en descente commandée**, quelles que soient les valeurs de seuils. Les causes directionnelles étant exclues du `SafeStop` (`FB_Safety_Winch.st:408-413`), la barrière finale ne compense pas.
- **Éliminé par tests (utilisateur + CI)** : bypass simu/MAINT_N2 (identique bypass off) · voyants fautifs (fonctionnent) · hypothèse « mauvaise saisie de seuils » (aucune valeur ne protège tant que le bug existe).
- **2 notes de conception (distinctes du bug, à trancher)** : (a) limite câble `0.0` silencieusement ignorée par le garde `(CfgCableLimitDescentM < 0.0)` — si « interdit sous 0 m » doit exister, ce réglage ne protège pas ; (b) permis descente non affiché à l'IHM alors qu'il existe côté PLC (`GVL_IHM.M2TreuilBenne.Safety.DescendPermit`, PRG_07:397 + ST_SafetyWinch).
- **Statut** : RÉSOLUE (cause prouvée) — correction à valider.

## 8. 🛠️ Proposition de correction

> ⚠️ **Devoir d'alerte** : défaut sécurité C0 — la machine (même en simu aujourd'hui) peut descendre sous les limites légale/câble au palier 1. Sur site réel avec charge : risque dépassement de cote légale / fin de câble.

- **Option 1 (immédiat, sans code)** : **aucune** — aucun réglage ne restaure le verrou tant que le bug existe (prouvé §6bis : l'arrêt ne survient qu'avec `MinStepDown=0`, jamais le cas en production).
- **Option 2 (définitif, code — validation humaine requise)** :
  1. `FB_Winch.st:242` — gater le plancher : `IF DriveRequest.StartStop AND (Direction=-1) AND (MinStepDown>0) AND NOT EffectiveSafeStop` (préserve l'intention plongée Kobold : permis TRUE pendant la plongée).
  2. À trancher : défense en profondeur — câbler les permis directionnels à la barrière finale OU réexaminer le `MAX(1, ·)` inconditionnel de `CommonMinStepDown`.
  3. IHM : afficher le permis descente (donnée déjà produite : `GVL_IHM.M2TreuilBenne.Safety.DescendPermit`).
  4. À trancher (conception) : limite câble `0.0` silencieusement ignorée (garde `< 0.0`).
- **Règle `fix:` + `guard:`** : test CI §6bis à promouvoir en test permanent du domaine H (`test_fb_winch.st`) après correction — TROUBLESHOOT-02 doit devenir PASS (`DescendPermit=FALSE` + `MinStepDown=1` → `StepNumber=0`).

## 9. ✅ Vérification de la correction / non-régression

> À remplir après correction validée : re-test descente M2 seule M1 inhibé → arrêt effectif à la limite ; limite haute 7,5 m toujours OK ; plongée Kobold (plancher) toujours fonctionnelle permis TRUE ; gates + G200.

## 10. 📝 Journal (chronologique)

- 2026-09-01 01:48 : Snapshot 499/499 pris pendant le symptôme (M1 inhibé, M2 descente active).
- 2026-09-01 : Analyse statique chaîne complète (PRG_07 → FB_Safety_Winch → PRG_04 §5/§5bis/§5ter/§6 → FB_Winch → FB_WinchOutputInterlock → PRG_06) croisée snapshot. Cause racine plancher MinStepDown + polarité config. Vérification croisée sous-agent en cours.
- 2026-09-01 : Diff non committé `FB_WinchOutputInterlock.st` (ordre de relâchement) examiné — **non impliqué** (State READY, pas en maintien).
- 2026-09-01 (rectificatif utilisateur) : voyants fonctionnent normalement (franchissements réels) ; `SimulationBypassActive=FALSE` → même symptôme → bypass éliminé ; seuils saisis au pif pour test. Diagnostic revu.
- 2026-09-01 02:26 : Snapshot 499/499 — machine retombée MAINT_N1 / AU ouverte / PowerCutOff / codeurs NOT_FOUND (état hors tension du banc, non exploitable pour le symptôme).
- 2026-09-01 : **Test CI ad hoc §6bis exécuté — 2 PASS / 1 FAIL attendu** : bug plancher `MinStepDown` confirmé mécaniquement (variable isolée, `FB_Winch` réel). Cause racine PROUVÉE, plus seulement corrélée.

---

📖 **Documentation complète** : `GUIDE_Troubleshooting.md` (même dossier).
