# 🕵️ Session de Troubleshooting — Temps mort > 800 ms à l'inversion plongée→extraction (AX8→AX9) — Treuils M1/M2

> 📌 Emplacement : DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_InversionTreuilM1M2_TempsMort_20260923.md
> 📅 Date : 2026-09-23 · 🧊 Situation : [SITE — mise en service] · 📄 Statut : [OUVERTE]

## 1. 🧊 Contexte figé (horodaté)

> Pas encore de snapshot/trace machine — la fiche s'ouvre sur **analyse statique du code source** (CODE/*.st).
> Toute valeur non listée = à vérifier (ne pas supposer).

### Texte de contexte

Machine réelle en mise en service, cycle **SEMI_AUTO** (Grafcet X0→X13, GEL 2026-09-03).
À l'inversion plongée (AX4..AX8, joystick poussé, descente) → extraction (AX9..AX12, joystick tiré, montée),
l'opérateur mesure un **arrêt des treuils > 800 ms**, ressenti anormal. Questions : où est la tempo, quelles
conditions, que peut-on couper/shunter pour l'essai ?

### Constantes relevées dans le code (🟢 preuve fichier:ligne)

| Élément | Source | Valeur |
|---|---|---|
| Delai interlock inversion vers montée (M1 & M2) | PRG_04_Treuils_Benne.st:1452 + :1518 | T#800ms (DirectionInterlockDelayAscent) |
| Delai interlock inversion vers descente | idem :1453 / :1519 | T#500ms |
| Stabilisation arrêt après contact fond (AX8) | FB_CycleSemiAuto.st:264 | CST_BottomTouchStabTime := T#500ms — ⚠️ commentaire :408 dit « 2s » : PÉRIMÉ |
| Seuil vitesse quasi nulle (arrêt confirmé) | FB_CycleSemiAuto.st:282 | 0.02 m/s |
| Délai mini AX9 (avant transition AX10) | FB_CycleSemiAuto.st:283 + :387-391 | CST_ExtractionStepDelay := T#1s |
| Décalage relâchement direction après vitesse | FB_WinchOutputInterlock.st:46 | ReleaseOrderDelay := T#50ms |
| Debounce confirmation retombée contacteurs | idem :42 | DropConfirmDelay := T#100ms |
| T_max maintien contacteur de sens (§3bis) | idem :43 | MaxSenseHoldTime := T#400ms |
| Plancher +1 cran barrière finale | idem :136 | CST_StepRampFloorDelay := T#400ms |
| Cadence rampe palier métier (montée) | ST_fbWinch_Cfg.st:24 | T#700ms/cran |
| Timer défaut divergence synchro M1/M2 | FB_SyncDeviation.st:95 | T#800ms puis latch |

### Variables & valeurs

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| À acquérir par trace CSV (§6) | — | — | — |

## 2. 🎯 Symptôme

À l'inversion descente→montée du cycle (AX8 fond confirmé → AX9 montée), arrêt mesuré **> 800 ms**
des deux treuils M1/M2 avant redémarrage ; systématique à chaque passe (à confirmer), démarrage ensuite normal.

## 3. 🧩 Indices / historique

- 🟡 **Incident 14/09/2026** (registre MES 15/09) : retour contacteur de direction resté inactif, sorties
  actives sans commutation, aucune alarme — reprise uniquement par coupure générale. → H1/H4.
- 🟡 **DIAG-SYNCHRO 31/08** : défaut synchro LATCHÉ (écart > seuil) bloque les deux treuils jusqu'à Reset. → H5.
- 🟡 **T262** (registre MES) : le client demande la continuité fermeture→remontée — l'arrêt franc AX10→AX11
  est un irritant connu, non codé (C4). Le ressenti « coupure entre les steps » recouvre AUSSI ce cas.
- 🟢 **T371** : la vue diagnostic a eu des modes de refus silencieux (Reason NONE) — le « vert » ne prouve rien ;
  lire Idx405/406 (état+raison barrière) et Idx417 (RestartInhibit).
- ❓ Derniers changements côté treuils : à confirmer par l'utilisateur.
- Déjà essayé : rien de tracé pour ce symptôme (pas de trace CSV sur l'inversion).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| H1 | **Crédit dead-time cassé** : ContactorsAllOff DI non confirmé pendant l'arrêt AX8 → StoppedTimer n'accumule pas → 800 ms pleins à AX9 | M1/M2_ContactorsReleased_DI pendant AX8 (FB_Winch.st:198 : Enable := (StepNumber=0) AND ContactorsAllOff) | TRUE pendant tout l'arrêt confirmé (FB_WinchDirectionInterlock.st:110-121) | — | ❓ |
| H2 | DiveStartStopped jamais TRUE (frein non confirmé, vitesse > 0.02 m/s, codeur invalide) → AX8 attend indéfiniment | DiveStartStopped + BottomTouchStabTimer.Q (FB_CycleSemiAuto.st:310-316, :409) | TRUE puis Q après 500 ms (CST :264) | — | ❓ |
| H3 | **Attente opérateur** : joystick relâché pendant AX8 → RunRequest := DeadmanArmed AND JoystickPull (:1284) attend le geste | Front JoystickPull vs entrée AX9 | requête présente dès l'entrée AX9 | — | ❓ |
| H4 | **Frein non confirmé → latch** RestartInhibit + ResetRequired (FB_WinchOutputInterlock.st:496-508) : blocage jusqu'à Reset conscient, les DEUX treuils figés (PRG_04:1407/:1499) | Idx417_RestartInhibit (GVL_Troubleshooting), ErrorId.0 | FALSE (sinon latch, pas une tempo) | — | ❓ |
| H5 | Divergence synchro M1/M2 pendant la décélération → DeviationFaultTimer 800 ms → latch → SafeStop process | instWinchSync.Fault, écart M1/M2 | FALSE pendant l'inversion (FB_SyncDeviation.st:95) | — | ❓ |
| H6 | **Atomicité couplée** : un treuil DirectionChangePending ou Fault.Latched fige l'autre (PRG_04:1405-1509) | DirectionChangePending M1 ET M2, WinchBothMotionReady | les deux prêts au même scan | — | ❓ |
| H7 | **Budget nominal** : le temps mort observé est la somme DESIGN (release 50 ms + retombée/frein + stab 500 ms + résiduel direction ≤ 300 ms + 1er cran) ≈ 0.8-1.2 s — pas un défaut | Trace CSV découpage (§6) | total ≈ 0.8-1.2 s, résiduel direction < 300 ms | — | ❓ |
| H8 | Refus silencieux barrière (F3 SafeStop/permis, Reason NONE — T371) | Idx405/406 pendant l'arrêt | READY, Reason NONE sans cause active | — | ❓ |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

    AX8 coupure instantanée (:1226-1227)
     └─ Barrière : ReleaseOrderActive → vitesse relâchée, direction tenue 50 ms → relâchée (§5 :340-344)
         └─ Retombée contacteurs (DI) + freins serrés (DI) + |v| < 0.02 m/s
             ├─ ❌ jamais TRUE → H2 (AX8 attend, blocage) / H4 (frein → latch RestartInhibit)
             └─ ✅ DiveStartStopped → BottomTouchStabTimer 500 ms
                 └─ AX9 entrée (:1232-1237)
                     ├─ ❓ opérateur tire le joystick ? → H3 (attente homme)
                     └─ Direction interlock D18 (FB_WinchDirectionInterlock)
                         ├─ Crédit StoppedTimer.ET ≥ 500 ms → restant ≈ 300 ms max → adoption ✅ (H7)
                         ├─ Crédit = 0 (ContactorsAllOff KO) → 800 ms pleins ❌ → H1
                         └─ Un seul treuil en attente → l'AUTRE est figé (PRG_04:1407/:1499) → H6
                             └─ Barrière finale : AuthorizedStep +1 cran (frein+sens) puis cascade 400 ms/cran

**Résumé une ligne** : [AX8 coupe] → [DI contacteurs+frein ?] → [stab 500ms] → [crédit ≥500ms ?] → [adoption] ❓

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais

- **Essai E1 (à faire)** : trace CSV CODESYS (export traces, validé MES 15/09) sur 1 cycle benne vide, basse hauteur.
  Variables : Step AX (Idx206), RunRequest/ReqAscent treuils, StepNumber M1/M2, DirectionChangePending +
  DirectionChangeDelayElapsed (ST_WinchState.st:68-69), M1/M2_ContactorsReleased_DI, freins, Idx417_RestartInhibit,
  Idx405/406, AuthorizedStep.
- **Découpage attendu** : t(coupure) → t(direction relâchée +50 ms) → t(DI confirmés) → +500 ms (stab) →
  t(AX9) → t(adoption sens) → t(1er cran). Chaque segment est comparé au budget design (§1).

### Chronogramme

| Événement | RunRequest | ContactorsAllOff | DirectionChangePending | AuthorizedStep |
|:---:|:---:|:---:|:---:|:---:|
| T1 AX8 coupure | 0 | ? | 0 | 0 |
| → +50 ms | 0 | ? | 0 | 0 |
| T2 arrêt confirmé | 0 | 1 ? | 0 | 0 |
| → +500 ms stab | 0 | 1 ? | 0 | 0 |
| T3 AX9 requête | 1 ? | 1 ? | 1 (crédit KO) / 0 | 0 |
| T4 adoption | 1 | 1 | 0 | 1 |

## 7. 🏁 Conclusion

- **Cause racine** : NON PROUVÉE — fiche ouverte. Leaders : **H7 (budget nominal ≈ 0.8-1.2 s, pas un défaut)**
  vs **H1 (crédit cassé → 800 ms pleins, cause DI contacteurs relâchés — cohérent avec l'incident 14/09)**.
- **Statut** : OUVERTE — mesure trace CSV requise avant toute conclusion.

## 8. 🛠️ Proposition de correction

> À remplir une fois la cause racine confirmée. Aucune modification sans validation humaine.

- **Option 1 (immédiat, sans code)** : si H1 → réparer/confirmer le retour contacteurs relâchés (chaîne DI),
  ne PAS bypasser : le crédit D18 en dépend structurellement (Enable := StepNumber=0 AND ContactorsAllOff).
- **Option 2 (réglage assumé)** : si le budget nominal est jugé trop long → tâche C2 sur les constantes
  (CST_BottomTouchStabTime, DirectionInterlockDelayAscent, CST_ExtractionStepDelay) avec contrat, gates et
  non-régression. **Jamais** de bypass de D18/AU/frein ; les bypass IHM existants (ST_BypassWinch :
  Global/Safety/Process/ContactorFeedback…) sont des outils MAINT_N2 bornés, qui n'accélèrent NI la stab
  500 ms NI le D18 et aveuglent la barrière finale (PRG_06_Outputs.st:351-359).
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression

- Après correction : rejouer E1 → résiduel direction < 300 ms, aucun latch Idx417, Idx405/406 sans refus
  résiduel, nominal 0/1/2 et Reset inchangés (git diff borné), G200 + gates verts.

## 10. 📝 Journal (chronologique)

- 2026-09-23 : fiche créée par DSH (orchestrateur). Investigation statique code : tempo 800 ms localisée
  (FB_WinchDirectionInterlock D18, config PRG_04:1452/:1518), crédit dead-time analysé, constante stab
  relevée à 500 ms (⚠️ commentaire :408 « 2s » périmé — à corriger dans un lot doc), carte des coupures et
  des bypass établie. Aucune variable machine lue. Essai E1 proposé à l'utilisateur.
