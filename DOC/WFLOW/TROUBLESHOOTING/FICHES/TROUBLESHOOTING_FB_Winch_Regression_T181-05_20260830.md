# 🕵️ Session de Troubleshooting — Régression CI FB_Winch après extraction T181-05

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_FB_Winch_Regression_T181-05_20260830.md`
> 📅 Date : 2026-08-30 · 🧊 Situation : [CI banc STATIC STruCpp] · 📄 Statut : [OUVERTE] — diagnostic terminé, correction « aucune régression à corriger en scope »

## 1. 🧊 Contexte figé

- Tâche : Agent 2 — T181-05 (extraction FB_WinchDirectionInterlock + FB_WinchStepShaper, retrait Mode/CycleTimeCalc).
- Source : `CODE/H_TREUILS_BENNE/FB_Winch.st`, `FB_WinchDirectionInterlock.st`, `FB_WinchStepShaper.st`, `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_winch.st`.
- Baseline figé par T181-00 : **FB_Winch 5/7** (contextes T181-02 : « 5/7 TC PASS, FAIL TC-P10-011, 018 »).
- État courant : `run_tests.py --fb FB_Winch` = **4/7** (FAIL TC-P10-011, 018, 052.1).

### Variables & valeurs (verdict CI — preuve par le harnais, pas par lecture live)
| Élément | Obj. | Niveau | Horodatage |
|---|---|---|---|
| run_tests.py --fb FB_Winch | n/a | **4/7** (compil. OK, 4 PASS) | 2026-08-30 |

## 2. 🎯 Symptôme

3 TC rouges en CI FB_Winch depuis l'extraction T181-05 : **TC-P10-011** (DirectionChangePending), **TC-P10-018** (Fault.Error StuckClosed), **TC-P10-052.1** (RequestedStep=5 au lieu de 1).

## 3. 🧩 Indices / historique

- Extraction T181-05 : interlock ⭢ `FB_WinchDirectionInterlock` (D18 : temps mort au front Enable), rampe palier ⭢ `FB_WinchStepShaper` (minimal, sans SpeedGuard), retrait Mode/CycleTimeCalc, **déplacement ContactorStuck → FB_Safety_Winch** (commentaire code « T181-08 », `instCauses[1].Active := FALSE`).
- Contract T181-02_03 (fusion) : c'est **T181-02_03 qui possède TC-P10-011 et le déplacement de TC-P10-018** (FB_Safety_Winch = propriétaire unique, scope interdit à T181-05).
- SpeedGuard limitant : retiré du chemin de cadence (AC3 StepShaper minimal) ; SpeedGuardLimit → T181-16 / **T177**.
- Déjà testé : aucune modif code faite ici tant que le verdict n'est pas validé.

## 4. 🌳 Arbre des causes & hypothèses (verdict par preuve)

| # | Hypothèse | Source attendu | Preuve | Verdict |
|---|---|---|---|---|
| 1 | TC-P10-011 : régression T181-05 | Contract T181-02_03 = propriétaire TC-011 ; TASKS.yaml:T181-02 « fix TC-P10-011 » | Interlock post-extraction **iso** à baseline (même suite neutre→sens immédiate après neutralisation CommandedDirection=0) ; TC-P10-011 **rouge baseline** (contexte T181-02 « FAIL TC-P10-011 ») | ❌ (pas une régression T181-05 → T181-02_03) |
| 2 | TC-P10-018 : régression T181-05 | Contract T181-02_03 : StuckClosed → FB_Safety_Winch propriétaire unique | `FB_Winch.st` `instCauses[1].Active := FALSE` + `ContactorsCheck.StuckClosed := FALSE` (migration volontaire, commentaire T181-08) ; mission : « respecter FB_Safety_Winch » | ❌ (transféré volontairement → T181-02_03 / FB_Safety_Winch) |
| 3 | TC-P10-052.1 : régression T181-05 | AC3 étape « step minimal », `SpeedGuardLimited := FALSE` ; feature SpeedGuard = **T177** | `FB_WinchStepShaper.st` ne contient PAS le garde-fou ; test forcé SpeedGuardEnable=TRUE sans consommateur → RequestedStep=5 ; mission : « ne pas implémenter T177 déguisé » | ❌ (red T177 ; ré-implémenter = T177 déguisé, interdit) |

## 5. 📊 Arbre vertical (flux — interlock & rampe)

```text
TC-P10-011 : Direction 1 →0 → -1  (passage par 0)
  CommandedDirection: 0 (neutralisé à l'arrêt) → neutre→sens immédiat
  DirectionChangePending = FALSE  ❌ expected TRUE
  → comportement == baseline (iso). Cause = absence de mémoire de sens = périmètre T181-02_03.

TC-P10-018 : FwdRevSpeedFeedbackOff=FALSE 500 ms
  instCauses[1].Active := FALSE (migration FB_Safety_Winch) → Fault.Error=FALSE
  → propriétaire unique déplacé. Cause = transfert volontaire (T181-02_03 / T181-08).

TC-P10-052.1 : SpeedTgt 90, SpeedGuardEnable=TRUE, SpeedGuardReady=FALSE
  SpeedGuard inerte (plus câblé) → RequestedStep=5  ❌ expected 1
  → garde-fou délégué à T177. Cause = délégué hors FB_Winch.
```

**Résumé une ligne** : `interlock iso` · `StuckClosed→Safety` · `SpeedGuard→T177` → aucun défaut de code FB_Winch introduit par T181-05.

## 6. 📊 Données / interactions

- `git diff d0000d1b..HEAD FB_Winch.st` : la partie interlock est logiquement équivalente à baseline ; D10 = paramètres dédiés (1000/500 ms = 900/400+100 ms) ; SpeedGuard et StuckClosed retirés.
- `git diff d0000d1b..HEAD test_fb_winch.st` : TC-P10-011/018/052.1 issus de la refonte du harnais (nouveaux IDs).
- Contrat T181-05 AC1/AC3 : « `run_tests.py --fb FB_WinchDirectionInterlock/StepShaper` » — ⚠️ **aucune entrée registry dédiée** : les 2 sous-FB sont testés via `FB_Winch`/`WINCH_INTEG`. (discrepancy contrat↔outillage, à remonter).

## 7. 🏁 Conclusion

- **Cause racine** : les 3 rouges de FB_Winch **ne sont pas introduits par T181-05**. T181-05 a réalisé une extraction **iso** sur les responsabilités conservées (interlock D18, rampe D10).
  - TC-P10-011 → périmètre **T181-02_03** (mémoire de sens lors d'une inversion passant par le neutre).
  - TC-P10-018 → transfert volontaire StuckClosed → **FB_Safety_Winch** (T181-02_03 / T181-08), respecter le propriétaire unique.
  - TC-P10-052.1 → garde-fou délégué → **T177** ; ne pas re-implémenter (déguisé) en T181-05.
- **Statut** : DIAGNOSTIC TERMINÉ — aucune modification de `FB_Winch*.st` à livrer (pas de régression T181-05 à corriger).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat)** : sans modification de código — acter que les 3 rouges appartiennent à d'autres tâches. Verdict TC-par-TC : 5/7 attendu une fois T181-02_03 (011, 018) et T177 (052.1) livrés.
- **Option 2 (définitif)** : pour lever l'ambiguïté AC7, réconcilier le harnais :
  - Déplacer/adapter TC-P10-018 vers la CI **FB_Safety_Winch** (déjà prescrit T181-02_03 AC5).
  - Annoter **TC-P10-052.1** « T177 en attente » (SpeedGuard hors FB_Winch) pour que la CI FB_Winch reflète sa responsabilité réelle. → hors scope périmètre interdit (ne pas dupliquer T181-02_03/T177).
- **⚠️ Validation requise** : [orchestrateur] — décision sur la réconciliation des TC 018/052.1 (toucher aux tests), et attribution de la régression verte→rouge de 052.1 (AC7).

## 9. ✅ Vérification de la correction / non-régression

- (sans correction code) : `run_tests.py --fb FB_Winch` = **4/7**, comportement iso sur interlock/rampe prouvé par lecture.
- À valider après T181-02_03 et T177 : passage 5/7 puis 6/7 puis 7/7.

## 11. 🛡️ Audit de challenge indépendant (retour sous-agent)

Verdict : **PASS (avec réserves)** — T181-05 n'introduit AUCUN défaut fonctionnel ; les 4 points du diagnostic initial sont **confirmés** (interlock iso hors D18, rampe = défauts 1000/500 ms, les 3 rouges = RED-baseline → T181-02_03 / T181-02_03+T181-08 / T177).

Réserves remontées (hors scope T181-05) :
- **MAJOR — Couverture StuckClosed dégradée** : 500 ms → 3 s (Méca B), et gated `JoystickYNeutral` (aveugle si un contacteur colle PENDANT commande), vide si `FB_Safety_Winch` désactivé. → exiger l'invariant runtime « FB_Safety_Winch toujours câblé/activé » + ré-alimenter `ContactorsCheck.StuckClosed` (T181-02_03 / T181-08).
- **MAJOR — Mémoire de sens absente** (TC-P10-011) : physiquement SÛR car la barrière PRG_06 impose un temps mort de 1 s (`FB_WinchOutputInterlock`).
- **MINOR** : câblage SpeedGuard mort dans PRG_04 (→ T177) ; iso rampe conditionnée aux configs interdélais par défaut (→ commissioning/AC5) ; `PowerContactorEngaged` entrée morte (→ T181-08).

## 10. 📝 Journal (chronologique)

- 2026-08-30 : diagnostic CI FB_Winch 4/7 ; preuve iso (diff baseline + lecture interlock/rampe) ; cause des 3 rouges attribuée aux autres tâches ; fiche ouverte.
- 2026-08-30 : audit de challenge sous-agent (PASS sous réserves) — confirme aucune régression T181-05 ; nouvelle alerte MAJOR couverture StuckClosed + invariant FB_Safety_Winch.
