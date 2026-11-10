# Plan de tir — gel du sous-système treuil (T181)

> Livrable T181-00 (AC8). Ordre d'application manuelle CODESYS, points de rollback Git par phase,
> checklist essais site. **À relire avant le démarrage de Phase 0.**
> Date : 2026-08-29.

---

## 0 · Avertissements de mise en service (à lire à voix haute avant tout essai sous puissance)

| # | Avertissement |
|---|---|
| **SEC-1** | 🔴 **AUCUNE protection survitesse n'est active** tant que la table d'apprentissage n'est pas complète (T181-15/16, Phase B). Pendant toutes les Phases -1 → A → C et les **premiers essais site**, un emballement treuil **n'est pas détecté** par le logiciel. Les protections restantes : AU physique, `PowerCutOff`, Méca A/B (dérive à l'arrêt), FDC. Prévoir une **surveillance opérateur renforcée** et un accès AU immédiat. |
| **SEC-2** | La barrière finale `FB_WinchOutputInterlock` n'a **pas d'interlock de cadence** avant T181-01 (`StepDelay` TON mort). Le filet 2 niveaux est **créé** par T181-01, pas fiabilisé. |
| **SEC-3** | Le harnais d'intégration `WINCH_INTEG` a une **baseline volontairement rouge** — les oracles verts ne viennent qu'au fur et à mesure des lots T181. Ne jamais lire « WINCH_INTEG rouge » comme un régression. |

---

## 1 · Ordre d'application manuelle dans CODESYS (par lot / phase)

> Règle : les DUT partagés (`ST_WinchState`, `ST_SafetyWinch`, `ST_WinchInterPrg`, `ST_WinchFinalInterlockReq`,
> `ST_ContactorCheck`, `ST_fbWinch_*`) sont importés **avant** tout POU qui les consomme, et **dans la même
> passe d'import** que `PRG_04`, `PRG_06` **ET** `PRG_07` + `GVL_Troubleshooting` (sinon build cassé entre 2 imports).

### Passe type (Phase A — refonte interface)

1. **DUT / enum** — dans l'ordre : `CODE/H_TREUILS_BENNE/_TYPES/*` (`ST_fbWinch_DriveRequest`, `_Sensors`, `_Cfg`,
   `ST_WinchFinalInterlockReq`), puis `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/*` (`ST_WinchState`,
   `ST_SafetyWinch` incl. champ `ContactorStuck`, `ST_WinchInterPrg`), puis `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/*`
   (`ST_TranslationFinalInterlockReq` — symétrie M3).
2. **FB feuilles** — `FB_SpeedStep`, `FB_WinchDirectionInterlock`, `FB_WinchStepShaper` *(non — TON inline)*,
   `FB_WinchRateInterlock`, `FB_WinchSpeedLearning`.
3. **FB composites treuil** — `FB_Winch`, `FB_Safety_Winch`, `FB_WinchSync`, `FB_Winch_Symmetry`.
4. **FB cycle** — `FB_DiveSearch`, `FB_ExtractionSequence` (renommages).
5. **Programmes** — `PRG_03_Modes_Cycle`, puis `PRG_04_Treuils_Benne`, puis `PRG_06_Outputs`.
6. **Supervision & diagnostic** — `PRG_07_Supervision`, `GVL_Troubleshooting`, `FB_TroubleshootingView`,
   `ST_SafetyChecklist` (consomment les diags treuil renommés).
7. **Simulation** — `FB_SimBench`, `FB_Sim_*` en dernier.
8. **Config persistante** — vérifier `GVL_PERSISTENT` : les nouveaux champs RETAIN (table apprentissage) sont
   ajoutés **en fin** de zone RETAIN (ne pas décaler les champs existants — CODESYS peut ré-initialiser toute
   la zone si l'ordre de déclaration change).
9. **Post-import** : régénérer le bundle PLCopenXML → `G200_check_linkage.py --report` → `run_all_gates.py --palier C`.
   Bandeau de restitution si tout est vert.

### Phases 0 / 0b (interface `FB_Winch` en réduction contrôlée)
Même principe, périmètre réduit : `FB_WinchOutputInterlock` + `FB_WinchRateInterlock` + `FB_Winch` (retrait `Mode`)
+ les 2 sites `PRG_04` + `PRG_06`. Toujours ré-importer `PRG_07` dans la même passe si un DUT diag bouge.

---

## 2 · Points de rollback Git par phase

| Étape | Tag avant | Commit de sortie | Rollback |
|---|---|---|---|
| Phase -1 (harnais) | `t181-pre` | `t181-phase-1-ok` | `git checkout t181-pre -- TOOLS/TEST_AUTO_CI/ TOOLS/AGENT_WORKFLOW/scripts/G48*` |
| Phase 0 (C4 rouges) | `t181-phase-1-ok` | `t181-phase0-ok` | `git revert` du commit de phase ; ré-import ST des POU concernés dans CODESYS |
| Phase 0b (sous-FB) | `t181-phase0-ok` | `t181-phase0b-ok` | idem |
| Phase A / T181-08a | `t181-phase0b-ok` | `t181-08a-ok` | shadow inactif = comportement iso ; revert commit + ré-import |
| Phase A / T181-08b (bascule clamp) | **`t181-08b-pre`** | `t181-08b-ok` | **table d'attendus** = référence ; revert + ré-import ; garder l'ancien calcul en shadow inactif 1 phase de plus |
| Phase A / T181-10 | `t181-08b-ok` | `t181-10-ok` | revert + ré-import PRG_04 |
| Phase C | `t181-10-ok` | `t181-phaseC-ok` | revert FB_Modes + PRG_04 |
| Phase B | `t181-phaseC-ok` | `t181-phaseB-ok` | revert FB_Safety_Winch + FB_WinchSpeedLearning ; **table RETAIN : ne pas la purger au rollback** (données de calibration) |
| Phase D | `t181-phaseB-ok` | `t181-ok` | — |

> ⚠️ « Rollback runtime » n'existe pas sur cette machine (application manuelle). Un rollback = **tag Git +
> ré-import ST manuel dans CODESYS** des POU du lot. Procédure documentée par lot dans le contrat correspondant.

---

## 3 · Non-régression du reste de la machine

À chaque fin de phase, en plus des gates treuil :
- `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` (21 gates, complet).
- `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb MAIN_EndToEnd` (chaîne machine globale — doit rester vert).
- Vérifier `PRG_02_Acquisition`, `PRG_05_Translation`, `PRG_07_Supervision` : aucun consommateur de diag treuil cassé.
- `WINCH_INTEG` : la baseline rouge est attendue ; noter le score (X/32) et vérifier qu'il **ne régresse pas**
  d'une phase à l'autre (les vecteurs virent au vert, jamais l'inverse).

---

## 4 · Checklist essais site (hors CI — signature sécurité)

> La CI ne délivre **pas** la qualification terrain. Les points suivants sont chronométrés / mesurés sur machine réelle,
> par phase, et **signés**.

### 4.1 Après Phase 0 (barrière + interlocks)
- [ ] Essai à vide **cadence paliers 1 → 5**, M1 seul puis M2 seul : chronométrer le temps d'accostage par cran.
      Vérifier que **la barrière finale ne mord pas** (`FinalInterlockGoverned` = FALSE relevé en ligne sur toute la montée).
- [ ] Forcer une cadence > seuil safety (essai contrôlé) : vérifier que l'instance `PRG_06` **coupe** (relais OFF) et
      que la trace `FinalInterlockGoverned = TRUE` est horodatée.
- [ ] Temps mort directionnel : arrêt puis inversion de sens immédiate → vérifier le délai appliqué (≥ 1 s).
- [ ] **Redémarrage à chaud** (D18) : Enable OFF puis ON avec la commande de sens maintenue → vérifier qu'un temps
      mort est appliqué (pas de réengagement instantané / inrush).
- [ ] Watchdog frein : simuler un retour frein incohérent → coupure après timeout.

### 4.2 Après Phase A (clamp)
- [ ] Régression M1 : benne en jog lent + M1 en demande palier 4 → **M1 reste au palier 4** (relevé en ligne).
- [ ] Déviation synchro provoquée (couplé) → plafond palier 1 **sur M1 ET M2** simultanément.
- [ ] Plongée Kobold : joystick effleuré → montée **temporisée** 0→1→2→3 (pas d'à-coup contacteur) ; relâche → 0 immédiat.
- [ ] Zone de ralentissement bordure haute : approche 7,5 m → plafond `SlowdownMaxStep`, **jamais** au-delà de 7,5 m.

### 4.3 Après Phase C (maintenance)
- [ ] En `MAINT_N1` : aucun bypass latché n'est effectif (grisé IHM).
- [ ] Override FDC N1 : bouton maintenu → dépassement autorisé jusqu'à **8,5 m** (capteur), jamais au-delà ;
      relâche → FDC 7,5 m re-actif immédiatement.
- [ ] `MAINT_N2` : bypass position latché → RETAIN vérifié après boot.
- [ ] Sortie de mode après usage override / bypass position → `HomingRequired` : SEMI_AUTO refusé jusqu'au homing complet.
- [ ] Bascule de mode refusée si treuil non à l'arrêt confirmé (contacteurs + frein).

### 4.4 Après Phase B (apprentissage + survitesse)
- [ ] Campagne d'apprentissage : parcourir tous les {sens × charge × palier 1-5} pour M1 et M2 →
      `TableComplete` passe TRUE, voyant IHM éteint.
- [ ] Vérifier les vitesses apprises : chaque cellule dans une enveloppe plausible (pas de valeur absurde).
- [ ] Survitesse ON (table complète) : provoquer un léger dépassement → `OverspeedSoftWarn` (diag, pas d'arrêt) ;
      dépassement franc → `OverspeedHardTrip` → `SafeStop`.
- [ ] Vérifier qu'un passage de palier normal (accélération transitoire) **ne déclenche pas** la survitesse.
- [ ] Coast-down après relâche lourd : **pas de faux `PowerCutOff`** ; Méca B arme bien à 3 s si dérive prolongée.

---

## 5 · État du harnais `WINCH_INTEG` (livraison T181-00)

| Élément | État |
|---|---|
| `FB_TestHarness_PRG_04.st` miroir de `PRG_04 §1-§8` | ✅ (gate G480 PASS — 4 expressions de clamp alignées) |
| `FB_Main_EndToEnd.st` v2 + modèle physique paire | ✅ compile ; entrées boutons/benne/plongée/injection + sorties diag |
| Modèle physique | `CablePosM += v_palier · 10 ms` par instance ; écart = déviation sync ; retours frein/contacteurs ; **aucune dynamique moteur** |
| Entrée registre `WINCH_INTEG` | ✅ |
| `test_winch_integ.st` — 32 vecteurs HARN-1x..8x | ✅ écrit, **compile + s'exécute** |
| Gate `G480` (anti-dérive stub↔PRG_04) | ✅ dans `run_all_gates --palier C` |
| Gate `G481` (compile + exécute, baseline rouge OK) | ✅ dans `run_all_gates --palier C` |
| **Calibration des vecteurs** | ⚠️ **à dérouiller** — les séquences de stimulus ne montent pas encore le treuil au palier cible dans les cas nominaux (homme-mort à armer, temps de rampe à laisser converger). Assertions actuelles partiellement triviales. Tâche de suivi : passe de calibration + retrait du marqueur `SUITE_CALIBREE` dans le `.st` (bascule G481 leak WARN→FAIL). |

---

## 6 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v0.1 | 2026-08-29 | Livraison T181-00 : ordre d'import, rollback par phase, checklist essais site, état harnais. Calibration des vecteurs = suivi. |
