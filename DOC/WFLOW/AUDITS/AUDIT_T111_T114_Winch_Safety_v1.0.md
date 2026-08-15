# 🔎 Audit T111–T114 — Winch Safety, Synchro & Benne (v1.0)

> 📌 **Rapport read-only** : constats, écarts spec↔code, recommandations. Aucune modification de code.
> 📅 Audit réalisé le 2026-08-15 · Base : commits `5b729b6` (T111), `f69b0b2` (T113), `536a821` (T114), `00f2369` (T112), `2efdf8d` (fix gate T112), `5884575` (doc).
> 🎯 Périmètre : conformité aux specs `AF_Partie-10` §6.5/6.6/6.7, aux standards (`CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md`), non-régression et impacts hors périmètre.

---

## 🧭 Sommaire

1. Verdict global
2. Gates & preuves mécaniques
3. 🔴 Écarts spec ↔ code (bloquants)
4. 🟡 Écarts standards & documentation
5. ✅ Points conformes
6. 🎯 Recommandations & effort
7. Annexe — vérification par échantillonnage

---

## 1. Verdict global

| Tâche | Conformité spec | Conformité standards | Non-régression | Verdict |
|---|---|---|---|---|
| **T111** Mou de câble | ⚠️ Écart §6.5 | ✅ | ✅ | 🟠 **À corriger** |
| **T112** Polarité Permit | ✅ | ⚠️ Doc périmée | ✅ | 🟠 **Doc à mettre à jour** |
| **T113** Synchro étagée | ⚠️ Écart §6.7 | ✅ | ✅ | 🟠 **À corriger** |
| **T114** Benne obstruée | ⚠️ Écart §6.6 | ✅ | ✅ | 🟠 **À corriger** |

**Conclusion** : les 4 implémentations sont **logiquement saines et liées** (aucun bug de câblage, aucune régression fonctionnelle détectée), mais **3 écarts spec↔code** et **1 dette documentaire** restent à traiter avant de considérer les tâches closes.

---

## 2. Gates & preuves mécaniques

| Contrôle | Résultat |
|---|---|
| `run_all_gates.py` (TOUS) | ✅ **ALL PASSED** — 18 gates, 493 tests, 8 skipped |
| `G200_check_linkage.py --report` | ✅ PASS — 67 OK, 0 KO (L1-L7) · L10 : 936 OK |
| `G340_check_doc_links.py` | ✅ PASS |
| `G350_check_hw_name_collision.py` | ✅ PASS |
| `G110` Nommage IEC (NC-010..070) | ✅ PASS — 1 WARN hors baseline (`FB_Sim_Translation.SpeedRefPct`, préexistant, hors périmètre) |
| Bundle `CODE_XML/CODE_Bundle.xml` | ✅ Frais, cohérent avec le code ST (échantillonnage §7) |
| Compile headless CODESYS | ⚠️ **Non prouvé** — `G500_check_codesys_compile.py` valide un log exporté manuellement ; aucun log de build récent trouvé dans le dépôt. L'affirmation « 0 erreur headless » du rapport agent n'est pas vérifiable dans le dépôt |

---

## 3. 🔴 Écarts spec ↔ code (bloquants)

### 3.1 T111 — Bridage Palier 1 en montée mou de câble absent

**Spec** (`AF_Partie-10` §6.5) : en mode récupération (`SyncEnable=FALSE`), *« Autorisation d'ENROULER / MONTER (**Vitesse lente / Palier 1**) »*.

**Code** : la descente est bien bloquée (`DescendPermit=FALSE` via bit3 + `NOT SyncEnable`, `FB_Safety_Winch.st:587`) et la montée autorisée. **Mais aucun bridage de palier** : `MaxStepAscent` (`PRG_04_Treuils_Benne.st:842,881`) ne contient **aucun** terme mou de câble. L'opérateur peut monter à pleine vitesse (Palier 5) avec un câble mou → risque d'emmêlage tambour, exactement le risque que la spec visait.

**Preuve** : `grep MaxStepAscent` → conditions = `ForceMinSpeedStep OR ControlAscentActive OR SyncDegradedStep1 OR CoupledAscentBucketNotClosedSlowSpeed` — aucun `SlackCable`.

### 3.2 T113 — Seuils synchro non conformes à la spec §6.7

**Spec** : Zone 1 < 0.3 m · Zone 2 0.3–0.8 m · Zone 3 > 1.2 m.

**Code** :
- `CfgSyncToleranceM = 0.25` (`GVL_PERSISTENT.st:61`, `ST_SyncCfg.st:6`) → Zone 2 dès **0.25 m** (au lieu de 0.3).
- `CriticalSyncToleranceM = 2.0` (`FB_Safety_Winch.st:187`) → Zone 3 à **2.0 m** (au lieu de 1.2).

**Conséquence** : la dégradation Palier 1 se déclenche ~2× plus tôt que spécifié, le SafeStop ~1.7× plus tard. Les valeurs 0.25/2.0 sont **préexistantes** (pas introduites par T113) — mais la spec §6.7 a été écrite avec 0.3/0.8/1.2 **sans trancher**. Incohérence doc/code à trancher (aligner la spec ou les valeurs persistantes).

### 3.3 T114 — Portée restreinte vs spec §6.6

**Spec** : *« Benne partiellement fermée / Obstruée (**NOT IsClosed** mais demande de montée) »* → montée rapide interdite, remontée Palier 1 autorisée.

**Code** : `CoupledAscentBucketNotClosedSlowSpeed` (`PRG_04_Treuils_Benne.st:368`) exige `CoupledAscentBucketCloseArmed` = `TglEnableCoupledBucketSequencing` (**défaut FALSE**, `ST_CommunCfg.st:27`) + `MaintenanceMotionRequestActive` + `MaintenanceMotionDirection = 1`.

**Conséquence** :
- En **pilotage unitaire M2** (Select=2) ou **boutons IHM individuels**, une benne obstruée monte à pleine vitesse — hors spec.
- Le blocage total `CoupledMotionBlockedByBucket` ne s'applique plus qu'à l'ouverture (Dive) : la montée couplée avec benne non fermée n'est **ni bloquée ni bridée** si le toggle est FALSE.

---

## 4. 🟡 Écarts standards & documentation

### 4.1 T112 — Documentation périmée (non-régression documentaire)

| Document | Écart |
|---|---|
| `AF_Partie-10_Fonction_Winch/FB_Safety_Winch_v1.0.md` | Interface `ForbidDescent`/`ForbidAscent` (l.62), masques (l.101-102), bit3 « ForbidAscent seul » (l.84) — **périmés** vs code `DescendPermit`/`AscentPermit` |
| `AF_Partie-10_Fonction_Winch/FB_Winch_v1.0.md` | l.52 `ForbidDescent`/`ForbidAscent` en entrée — périmé |
| `AF_Partie-10_Fonction_Winch_v2.0.md` (chapô) | l.195 `ForbidAscent`/`ForbidDescent`, l.295 `ForbidDescent` — périmés |
| `AF_Partie-09_Fonction_Encoder_v2.1.md` | l.152 `ForbidAscent` — périmé |
| `AF_Partie-14_Fonction_Troubleshooting_v1.2.md` | l.101-102 `ForbidAscentM1/M2_Raw` — périmé |
| `ST_ChainWinchSync.st` | `Idx303_M1_ForbidAscent`/`Idx304_M2_ForbidAscent` déclarés, **jamais assignés** |
| `ST_MotionChecklist.st` | Commentaire `ForbidAscent/ForbidDescent` — périmé |

### 4.2 T112 — Décision T109 non actée dans la convention

T109 (réflexion polarité `Forbid*` vs `Permit`) est **acté par T112 sans décision documentée** dans `NAMING_CONVENTION.md`. La convention n'a pas été mise à jour : la famille « sortie de commande » (§Polarité des booléens I/O) cite encore `ForbidDescent` comme exemple.

### 4.3 T112 — Code mort / variables non consommées

- `AscentPermitExtractionBottomConfirmed` (`PRG_04_Treuils_Benne.st:107,807`) : calculé, **jamais lu** (commentaire l.805 « n'est plus appliqué ») — violation `CODE_QUALITY_STANDARDS.md §4`.
- `Idx303_M1_ForbidAscent`/`Idx304_M2_ForbidAscent` (`ST_ChainWinchSync.st:13-14`) : déclarés, jamais assignés.
- Commentaires d'en-tête `FB_Safety_Winch.st` (l.36, 95, 116, 122, 137...) : références `Forbid*` résiduelles — cosmétique mais trompeur.

### 4.4 T112 — Bug gate `IF NOT Enable` (corrigé)

Le commit `00f2369` laissait `ForbidDescent := TRUE; ForbidAscent := TRUE;` dans le gate de neutralisation (`FB_Safety_Winch.st`) → **erreur de compilation** (variables renommées). Corrigé par `2efdf8d` (HEAD) : `DescendPermit := FALSE; AscentPermit := FALSE;` — **fail-safe correct** (aucun mouvement permis si Safety désactivé). ✅ Le rapport de l'agent ne mentionne pas ce fix intermédiaire.

---

## 5. ✅ Points conformes (vérifiés)

- **T112** : inversion `NOT Forbid` → `Permit` **logiquement exacte** partout (`FB_Safety_Winch`, `FB_Winch`, `PRG_04`, `FB_TroubleshootingView` SEL bien orienté, `ST_SafetyWinch`, `GVL_IHM`). Défauts `:= TRUE` sur les entrées `FB_Winch` = fail-safe.
- **T113** : `SyncDegradedStep1` câblé M1+M2 (montée ET descente), exposé IHM (`SyncState` → `GVL_IHM.M1M2Sync.State`), gate `Enable`/`BypassGlobal` correct, `ELSE` de remise à FALSE présent. Pas de régression sur M1 (le plafond descente n'existait pas avant).
- **T114** : `CoupledMotionBlockedByBucket` scindé proprement (Dive bloqué / Ascent dégradé), `_BucketState.IsClosed` est le bon signal (RETAIN, état mécanique).
- **Nommage** : `SyncDegradedStep1`, `CoupledAscentBucketNotClosedSlowSpeed`, `DescendPermit`/`AscentPermit` conformes PascalCase/polarité.
- **Liaison** : G200 PASS, aucun double producteur sur les nouveaux signaux.
- **Bundle XML ↔ code ST cohérent** (échantillonnage §7).

---

## 6. 🎯 Recommandations & effort

| # | Priorité | Action |
|---|---|---|
| 1 | 🔴 | **T111** : ajouter le bridage Palier 1 en montée mou de câble (mode récupération) — terme `SlackCableDetected AND NOT SyncEnable` dans `MaxStepAscent` M1/M2 |
| 2 | 🔴 | **T113** : trancher les seuils (0.3/0.8/1.2 spec vs 0.25/2.0 code) — aligner la spec **ou** les valeurs persistantes |
| 3 | 🔴 | **T114** : étendre le bridage à toute demande de montée benne non fermée (pas seulement l'auto-séquencement), **ou** documenter explicitement la restriction |
| 4 | 🟡 | **T112** : mettre à jour `FB_Safety_Winch_v1.0.md`, `FB_Winch_v1.0.md`, chapô AF10, AF09/AF14, `NAMING_CONVENTION.md` (acte T109) ; supprimer ou câbler `AscentPermitExtractionBottomConfirmed` et `Idx303/304` |
| 5 | 🟡 | Produire un log de build CODESYS réel pour prouver la compilation (G500) |

**Effort estimé** : 1 jour (corrections ciblées) à 2 jours (avec mise à jour doc + gates).

---

## 7. Annexe — vérification par échantillonnage

Cohérence bundle XML ↔ code ST sur les points sensibles :

| Signal | Code ST | Bundle XML |
|---|---|---|
| `SyncDegradedStep1` (déclaration + assignations) | `FB_WinchSync.st:80,101,165,188` | `FB_WinchSync.xml:387,492,556,579` ✅ |
| Gate `DescendPermit/AscentPermit := FALSE` | `FB_Safety_Winch.st:278-279` | `FB_Safety_Winch.xml:1056-1057` ✅ |
| `CoupledAscentBucketNotClosedSlowSpeed` | `PRG_04_Treuils_Benne.st:368` | `PRG_04_Treuils_Benne.xml:2552` ✅ |
| `CfgMaxStepDescente`/`MaxStepAscent` M1/M2 | `PRG_04_Treuils_Benne.st:841-842,880-881` | `PRG_04_Treuils_Benne.xml:3025-3026,3064-3065` ✅ |
| `SyncState.SyncDegradedStep1` (IHM) | `PRG_04_Treuils_Benne.st:1109` | `PRG_04_Treuils_Benne.xml:3293` · `GVL_IHM.xml:2325` · `ST_SyncHMI.xml:196` ✅ |
| `CfgSyncToleranceM` (persist) | `GVL_PERSISTENT.st:61` = 0.25 | `PRG_04_Treuils_Benne.xml:2714` ✅ |

---

## 📎 Documents liés

| Doc | Lien |
|---|---|
| Spec | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md` §6.5/6.6/6.7 |
| Fiches FB | `DOC/AF/AF_Partie-10_Fonction_Winch/FB_Safety_Winch_v1.0.md` · `FB_Winch_v1.0.md` · `FB_WinchSync_v1.0.md` |
| Standards | `DOC/STDS/CODE_QUALITY_STANDARDS.md` · `DOC/STDS/NAMING_CONVENTION.md` |
| Pilotage | `DOC/WFLOW/PLAN_TASK.md` T111–T114 |
| Code | `CODE/TREUILS/FB_Safety_Winch.st` · `FB_WinchSync.st` · `CODE/MAIN/PRG_04_Treuils_Benne.st` |
