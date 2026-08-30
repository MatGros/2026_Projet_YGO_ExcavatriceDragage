# 📦 RAPPORT T181-13 — Palier plancher plongée Kobold (3-4) + montée lissée

> Rapport d'orchestration transmissible à l'agent orchestrateur.
> Date : 2026-08-30 · Criticité C3 · Stratégie patch · Worktree isolé `.mgs-worktrees/T181-13` (base = main + **diff T181-12 matérialisé** + baseline treuil live).

---

## 1. Verdict de revue (défi orchestrateur)

| Axe | Verdict | Preuve |
|---|---|---|
| dépendance T181-12 consommée | ✅ PASS | consomme `MinStepDown` end-to-end (`FB_DiveSearch` → `ReqBucket` → `CommonMinStepDown/M2MinStepDown` → `FB_Winch.MinStepDown`), **noms réels confirmés** |
| Injection sur la cible (AC4) | ✅ PASS | grep `StepNumber :=` : uniquement `StepShaper.ShapedStep` ; plancher agit sur `RequestedStep` uniquement |
| Plafond gagne (AC5) | ✅ PASS | clamp `if RequestedStep > ActiveMaxStep → RequestedStep := ActiveMaxStep` ; `ActiveMaxStep` = `MIN(plafond, CfgSlowdownMaxStep)/MIN(…, sync)` |
| Relâche → 0 immédiat (AC3) | ✅ PASS | bloc gated `StartStop=FALSE` → inactif → `RampTargetPct:=0` → `StepNumber=0` cycle suivant |
| Montée lissée (AC2) | ✅ PASS | plancher injecté sur cible AMONT du `FB_WinchStepShaper` (non réécrit) → cadence `StepNumber ≤ +1/cycle` |
| Non-régression gates | ⚠️ VERT sur lot | 21/25 PASS ; 4 FAIL **préexistants/hors scope** (G340, G430, G481, G484) — 0 introduit |
| Doc AF-04 (AC5) | ⚠️ à relocaliser option | section insérée dans `AF_Partie-04` (spec DiveSearch) — voir §6 |

**Verdict global : PASS (1 décision orchestrateur : localisation de la fiche plancher).**

---

## 2. Contenu livré (diff agent isolé)

**`CODE/H_TREUILS_BENNE/FB_Winch.st`** — port d'entrée + injection cible :
```st
+    MinStepDown : INT := 0;   // [CFG] Plancher palier en descente impose (0 = aucun) -- plongee Kobold
...
+IF StartStop AND (Direction = -1) AND (MinStepDown > 0) THEN
+    IF RequestedStep < MinStepDown THEN RequestedStep := MinStepDown; END_IF;
+    IF RequestedStep > ActiveMaxStep THEN RequestedStep := ActiveMaxStep; END_IF;
+END_IF;
```
Position : **après** le garde-fou vitesse, **avant** `FB_WinchStepShaper` → agit sur la cible, cadencé par le shaper.

**`CODE/M_MAIN/PRG_04_Treuils_Benne.st`** — câblage cible (seulement 2 lignes) :
```st
instWinchM1 : MinStepDown := CommonMinStepDown,
instWinchM2 : MinStepDown := M2MinStepDown,
```

**`DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`** — sous-section `Plancher de palier en plongée Kobold (F10.12 — T181-13)` : valeur `CfgDiveFloorStep=3`, flux, injection cible (AC4), plafond gagne (AC5), relâche arrêt franc (AC3), lissage shaper (AC2), limitation connue (perte dosage 0-40 %, décision figée).

---

## 3. Preuves mécaniques (G200 + gates)
- Bundle frais `CODE_Bundle.xml` XML-valid (208/208), régénéré.
- G200 : L1-L7 **96 OK / 0 KO** (câblage relié) ; seul KO = orphelin **préexistant** `FB_WinchSpeedLearning`.
- Gates palier C : 21/25 PASS ; 4 FAIL tous préexistants (G340 liens docs, G430 commentaires T181 préexistants — l'apport du lot a ramené de 10→5 violations, G481 crash tooling `run_tests.py`, G484 script absent). **Aucune non-régression introduite.**

---

## 4. Vérifications métier (confirmées par l'agent, recoupées au code)

- **AC4** : `grep StepNumber :=` → `StepNumber := StepShaper.ShapedStep` (2 sites gate + nominal). Plancher JAMAIS sur `StepNumber`.
- **AC3** : `StartStop=FALSE` → bloc inactif → arrêt franc préservé, pas de lissage résiduel.
- **AC5** exemple concret : bordure basse `ActiveMaxStep := MIN(CfgMaxStepDescente, CfgSlowdownMaxStep=1)=1` ; si `MinStepDown=3` → `RequestedStep:=3` puis `>1 → :=1`. **Résultat 1, plafond gagne.** Idem `SyncDeviationWarn` → `CommonMaxStepDown=1`.

---

## 5. Devoirs d'alerte tracés
1. `CfgDiveFloorStep=3` confirmé dans `FB_DiveSearch` (défaut, cohérent contrat/PLAN) — pas rendu réglable côté treuil (source existante respectée).
2. Harnais WINCH_INTEG (HARN-30/32/33, TC anti-à-coup) **non exécutables** : crash tooling G481 préexistant → à traiter avant validation terrain. Aucun TC ajouté (lot dédié).
3. Nom de champ T181-12 `MinStepDown` confirmé end-to-end — zéro ambiguïté.

---

## 6. ⚠️ Décision orchestrateur requise — localisation de la fiche AF
Le scope permettait `DOC/AF/AF_Partie-04_*`. L'agent a inséré la section plancher dans **`AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`** (où `FB_DiveSearch` est profilé, car **aucun `AF_Partie-04` treuil n'existe**). Alternative : relocaliser/synergier dans **`AF_Partie-10`** (spec winch). À trancher : conserver AF-04, ou dupliquer/référencer dans AF-10.

**Clôture : aucun commit effectué · diff prêt à validation orchestrateur + intégration CODESYS manuelle.**
