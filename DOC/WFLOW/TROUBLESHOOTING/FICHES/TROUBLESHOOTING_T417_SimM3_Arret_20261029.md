# 🕵️ Session de Troubleshooting — T417 · Arrêt M3 simulé (Auto) ≠ réel

> 📅 Date : 2026-10-29 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]
> Tâche liée : T417 (SimBench M3, criticité C2) · Contrat : `CONTRACTS/TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml`

## 1. 🧊 Contexte figé (2026-10-29)

### Texte de contexte
Objectif : simulateur M3 (translation) qui reproduit l'arrêt réel. Constat exploitant :
- **Manuel** : arrêt propre ≈ **10 cm** après le capteur Trémie / P1.
- **Automatique** : automate affiche 0.0 m (Trémie) et 5.0 m (P1) ; le simulateur dérive jusqu'à **-0.45 m** (Trémie) et **+5.38 m** (P1), fausses alarmes fin de course (ErrorId 64).
- Oscilloscope exploitant : `TranslationFinalInterlockRequest.BrakeReleaseRequest` → 0 instantanément au capteur ; `M3_BrakeIsOpen_DI` retombe après un délai mécanique ; `TranslationState.BrakeCmd` retombe ~1 s plus tard.

### Modifications courantes (non committées, `git status`)
| Élément | Valeur dans le code | Source |
|---|---|---|
| `SimM3RollingFriction_Mps2` | 0.30 (était 0.10) | `GVL_Simulation.st:86` |
| `StaticFriction_Mps2` | 0.35 (nouveau) | `FB_Sim_Translation.st` |
| `SimM3CartFreeActive` | **TRUE** (défaut FB = FALSE) | `GVL_Simulation.st:84` |
| `SimM3BrakePhysicalActive` | TRUE | `GVL_Simulation.st:79` |
| `SimM3BrakeDecel_Mps2` | 2.0 | `GVL_Simulation.st:80` |
| `DecelRate_HzPerS` (drive) | 20.0 (contrat AC1 dit 25) | `FB_Sim_TranslationDrive.st` |
| `TimeConstant_S` (drive) | 0.03 | `FB_Sim_TranslationDrive.st` |
| `BrakeOpenDelayS` / `BrakeCloseDelayS` | 0.10 / 0.09 (contrat AC2 dit 200 ms d'ouverture) | `FB_Sim_Translation.st` |

## 2. 🎯 Symptôme
En cycle **Automatique**, la position simulée dépasse le capteur d'arrêt de **0.45 m** (Trémie) et **5.38 m** (P1) alors que l'automate reste à 0.0 / 5.0 m. En **Manuel**, arrêt ≈ 10 cm. Permanent, reproductible.

## 3. 🧩 Indices / historique
- Déjà attribué (rapport agent T417, **non vérifié**) : frottement sous-estimé (0.10 → 0.30), décélération variateur (25 → 20 Hz/s), double filtre PT1 supprimé.
- Essai utilisateur des corrections : **non réalisé** (rapport d'agent : « essai CODESYS utilisateur » listé comme prochaine étape).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Attendu (source) | Verdict |
|---|---|---|---|---|
| H1 | Le frottement 0.10→0.30 explique le dépassement | distance d'arrêt sur chemin frein serré | dépend du frottement seulement en mode **chariot libre** (frein ouvert ET variateur sans couple) — `FB_Sim_Translation.st` | ❌ **non démontré** : réplique, arrêt nominal 20 Hz = -0.069 m, identique à friction 0.10 et 0.30 |
| H2 | Décélération variateur (25→20 Hz/s) explique le dépassement | distance d'arrêt | `TimeConstant` et `DecelRate` n'agissent que sur la fréquence avant coupure frein (0.09 s) | ❌ **peu d'impact** sur le chemin nominal (réplique) |
| H3 | Arrêt nominal à 40 Hz (approche rapide) | distance d'arrêt | — | ⚠️ réplique : -0.211 m. **À confirmer** : vitesse d'approche réelle en Auto non relevée |
| H4 | Auto : le frein est **re-relâché** après l'arrêt Trémie, chariot libre (`CartFree`) pousse la benne (pendule) | `M3_BrakeCmd`, `DirectionSign`, `ObsCartFree`, `SimM3ObsCartFree` | dérive possible si angle ≠ 0 et frein ouvert sans couple | ❓ **non testé** (réplique sans balancier) |
| H5 | Auto : **requête de direction** maintenue/réémise malgré le capteur (PLC, `ReqTremieSemantic`) | `M3_RelayFwd`, `M3_TremieHardStopActive` | arrêt dur = fréquence 0 + frein relâché à FALSE | ❓ **non vérifié** |
| H6 | Came capteur (`SimM3SensorCamDropoutActive := TRUE`) fait perdre puis retrouver le capteur Trémie, relâchant l'arrêt dur | `M3_PosTremie_DI` (fenêtre 0.02–0.06 m) | capteur perdu = arrêt dur levé | ❓ **non testé** — cause plausible d'un re-pilotage vers Trémie |
| H7 | Incohérence contrat ↔ code (AC1 25 Hz/s, AC2 200 ms) | valeurs | contrat T417 | ⚠️ **à arbitrer** (pas une cause de dérive, mais le contrat ne correspond plus au code) |

### Lecture du code (vérifiée)
- PRG_06 (`PRG_06` ~l.443) : `M3_TremieHardStopActive` → `BrakeReleaseRequest AND NOT M3_TremieHardStopActive` et `RequestedDriveFreqHz := SEL(..., 0.0)` ✅ présent.
- PRG_05 : bloc `IF SEMI_AUTO AND NOT M3_CycleTranslationStepAuthorized` force `BrakeReleaseRequest := FALSE` ✅ présent. **Numéro de ligne 717 du rapport : non vérifié.**
- Frottement : utilisé **uniquement** quand `ObsCartFree` (frein ouvert ET `NOT DriveTorqueActive`). Donc sans frein ouvert, le frottement n'agit pas sur l'arrêt frein serré.

### 4bis. 🧮 Barème d'évaluation (PROPOSITION — non validée, voir challenge)

**Plausibilité** (vérifiée, jamais supposée)
| Statut | Critère |
|---|---|
| 🟢 Prouvée | Lecture code (`fichier:ligne`) ou trace qui confirme |
| 🟡 Plausible | Cohérente avec le code, pas encore testée |
| 🔴 Réfutée | Contredite par le code, une trace ou une réplique |
| ⚪ Non évaluable | Donnée manquante (ex. trace Auto absente) |

**Impact** (4 dimensions, toutes renseignées, sinon ⚪ non chiffré)
| Dimension | Mesure | Seuils PROVISOIRES (à valider) |
|---|---|---|
| Marge restante | cm avant butée ou capteur voisin, sur le chemin du symptôme | 🔴 < 0 cm (franchi) · 🟠 0–5 cm · ⚪ > 5 cm |
| État capteur / alarme | changement vu/perdu d'un capteur ou ErrorId | 🔴 ErrorId ou capteur d'arrêt perdu · 🟠 capteur changé d'état sans alarme |
| Délai frein | s entre coupure demande et retombée contact | 🟠 ≥ 0,3 s · ⚪ < 0,3 s |
| Fréquence | rare / fréquent (occurrence en cycle) | rare = 🟠 minimum si impact 🔴 |

Impact global = la dimension la plus haute.

**Exception sécurité** : toute branche touchant le maintien du frein, `PowerCutOff` ou `SafeStop` n'est jamais ⚪, quelle que soit la marge.

**Chemin du symptôme** : l'impact est mesuré sur le chemin où le symptôme apparaît (Auto, chariot libre si applicable), jamais sur un chemin voisin.

**Priorité** = plausibilité × impact
- 🟢 × 🔴/🟠 → traiter en premier
- 🟡 × 🔴/🟠 → **investigation seulement**, jamais présentée comme cause
- 🔴 réfutée, ou impact ⚪ sur le chemin du symptôme → écartée, raison écrite
- Impact non chiffré → chiffrer d'abord, ne pas prioriser

**Notation** : par un agent qui n'a pas écrit la conclusion, à partir des lignes citées. Jamais par l'auteur de l'hypothèse.

**Critère d'arrêt** : une cause n'est retenue que si elle reproduit l'ordre de grandeur observé (−0,45 m Trémie, +5,38 m P1, délai frein à la transition AX14→AX15). Tolérance ±5 cm à confirmer.

**Application à H1** : friction 0,10 → 0,30 sur l'arrêt Trémie nominal = 0 cm de changement (réplique, chemin frein serré). Non écartée pour le chemin Auto/chariot libre (H4) tant que la trace n'existe pas. Limite de la réplique : pas de balancier.

## 5. 📊 Arbre vertical (flux)
```text
Capteur Trémie (pos <= 0)
  → PLC : BrakeReleaseRequest=FALSE + FreqCmd=0            (instantané)
    → Sim variateur : Elec 20 Hz -> 0.5 Hz en ~1 s          (rampe 20 Hz/s)
    → Sim frein : coil OFF -> contact ouvert -> fermé +0.09 s
      → chariot : vitesse suit variateur pendant 0.09 s, puis décel 2 m/s²
        → arrêt ≈ -0.07 m  (réplique, 20 Hz)   ✅ ordre de grandeur = manuel (10 cm)
Auto -0.45 m  : NON expliqué par ce chemin  ❓ (H4/H5/H6 à tester sur trace)
```

## 6. 📊 Données / essais

### Réplique minimale (scratchpad, non committée)
Script : `C:\Users\ZEDVIC~1\AppData\Local\Temp\claude\C---MGS-DEV-2026-Projet-YGO-ExcavatriceDragage\98182986-a492-4e29-8941-ad6c63def8f2\scratchpad\replica_t417_stop.py`
Hypothèses de la réplique : pas de balancier (angle=0), pas de came/jitter capteur, droop=0, capteur à seuil 0 + hystérésis 0.02. **Ce n'est pas le ST** : elle sert à éliminer des hypothèses, pas à valider le code.

| Essai | Résultat |
|---|---|
| A. Arrêt Trémie 20 Hz, friction 0.30 | pos finale -0.069 m, frein fermé |
| A'. Idem, friction 0.10 | -0.069 m (identique) |
| B. Idem 40 Hz, friction 0.30 | -0.211 m |
| C. Frein relâché 3 s après arrêt, consigne nulle, angle=0 | -0.069 m (pas de dérive : sans balancier, pas de poussée) |

**Conclusion provisoire** : sur le chemin d'arrêt nominal, le frottement n'a **aucun effet** et l'arrêt est bien ≈ 7 cm à 20 Hz. Le -0.45 m en Auto vient donc d'un **autre enchaînement** (H4/H5/H6), pas du réglage de frottement.

## 7. 🏁 Conclusion
- **Cause racine** : **non établie**. Le rapport d'agent (friction = cause) est **infirmé pour le chemin nominal** par la réplique.
- **Statut** : à valider — il manque la trace Auto.

## 8. 🛠️ Proposition de correction
- **Option 1 (sans code)** : relever une trace **Auto** (CSV snapshot `codesys_snapshot_troubleshooting.py`) couvrant l'arrêt Trémie : `M3_PosTremie_DI`, `BrakeReleaseRequest`, `M3_BrakeCmd`, `M3_RelayFwd/Rev`, `M3_SpeedCmd_Pct`, `M3_BrakeIsOpen_DI`, `SimM3ObsCartFree`, `SimM3ObsPositionTrue_M`, `SimM3ObsEndStopHitCount`, `SimM3SensorCamDropoutActive` (si exposé). Objectif : savoir si le frein est re-relâché (H4) ou si la requête de direction reste active (H5).
- **Option 2 (définitif)** : après cause prouvée, corriger le modèle (pas l'automate) ; aligner le contrat T417 (AC1, AC2) sur le code ou l'inverse, avec arbitrage humain.
- **⚠️ Validation requise** : humaine. Aucun code modifié dans cette session.

## 9. ✅ Vérification / non-régression
- À faire après correction validée : arrêt Manuel ≈ 10 cm inchangé ; arrêt Auto Trémie et P1 cohérent avec l'automate (0.0 / 5.0 m) ; `G200_check_linkage.py --report` PASS.

## 10. 📝 Journal
- 2026-10-29 : Lecture du code T417 (`FB_Sim_Translation`, `FB_Sim_TranslationDrive`, `FB_Sim_TranslationBrake`, `GVL_Simulation`, PRG_05/06). Rapport d'agent partiellement vérifié.
- 2026-10-29 : Réplique minimale (scratchpad) : arrêt nominal ≈ -0.07 m, frottement sans effet sur ce chemin. Dépassement Auto non reproduit → trace Auto requise.
- 2026-10-29 : Incohérence contrat AC1 (25 Hz/s) / AC2 (200 ms) vs code (20 Hz/s, 100 ms) relevée.
- 2026-10-29 : Non vérifié : numéros de ligne du rapport, bundles/G200 PASS revendiqués (non relancés).
- 2026-10-29 : Vérif lecture seule : PRG_05:717 (BrakeReleaseRequest:=FALSE, bloc SEMI_AUTO/step non autorisé) ✅ ; PRG_05:739 (TranslationState.BrakeCmd) ✅ ; PRG_06:443 ✅ ; GVL_PERSISTENT:107 (P1 = 5.0 m) ✅ ; FB_Translation:312-318 (timeout 2 s, seuil 0,5 Hz) ✅ ; FICHE_T400 pas de « 90 ms » trouvé dans le fichier cité (source à retrouver) ❌.
- 2026-10-29 : Ajout barème d'évaluation (§4bis) : plausibilité × impact chiffré, exception sécurité frein.
