# RAPPORT T181-14 — Matrice de bypass maintenance N1/N2 (mode-gating, override FDC, re-homing)

> **Tâche** : T181-14_MATRICE_BYPASS · **Criticité** : C3 · **Stratégie** : patch
> **Contrat de succès** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-14_MATRICE_BYPASS.yaml` (AC1..AC19, alertes A1..A9)
> **Doctrine** : `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md` §4bis · **Cadrage** : `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T181-11_MATRICE_MAINT.md`
> **Date** : 2026-08-30 · **Agent** : T181-14 (reprise) · **HEAD** : `cd0e6ece` · **Base** : `e11c3345`
> **Statut** : VÉRIFIÉ — matrice déjà implémentée et conforme, aucun écart corrigé (voir §5)

---

## 1 · Bandeau de conformité

```text
========================================
✅ BUNDLE EXPORTÉ : CODE_XML/CODE_Bundle.xml (frais)
========================================
✅ G483 — Matrice maintenance N1/N2 : PASS
   (bypass gatés MAINT_N2, origine Auth.Mode · override FDC borné + conditionné Homed ·
    bascule subordonnée à l'arrêt confirmé · re-homing immédiat publié · câblage inter-PRG complet)
========================================
⚠️ G200 — PASS pour T181-14 (0 NOUVELLE erreur) ; 1 erreur PRÉ-EXISTANTE hors scope :
   FB_WinchSpeedLearning orphelin (T181-15, traité par T181-16) — voir §4
⚠️ run_all_gates --palier C : 23/25 PASS ; G340 + G430 FAIL pré-existants hors scope — voir §4
========================================
```

---

## 2 · Matrice bypass N1 vs N2 — justification sécurité

**Règle générale (AF-05 §4bis)** : `bypass_effectif := bypass_IHM AND (Mode = MAINT_N2)` pour
**toutes** les bascules treuil. Un bypass IHM activé hors N2 est **ignoré** (l'IHM l'affiche
« inactif — passer en N2 »). Exception unique : l'**override FDC haut logiciel** en `MAINT_N1`
via bouton maintenu (momentané), borné par le capteur physique haut (≈ 8,5 m), jamais franchi.

### 2.1 Override FDC haut logiciel (décision Q8) — N1 momentané

| Bascule | Mode autorisé | Effet | Justification sécurité |
|---|---|---|---|
| `BtnOverrideTopSoftware` (M1/M2) | **N1** (bouton MAINTENU) | `TopLimitM` passe de 7,5 m (`CfgCableLimitAscent_M`) à 8,5 m (`CfgTopSensorPos_M`). Relâché → retour 7,5 m au cycle suivant. | Bouton, pas toggle : l'opérateur doit **maintenir** l'autorisation pour dépasser le FDC logiciel. Relâche → le FDC logiciel redevient actif immédiatement. **N'ouvre JAMAIS `BypassTopLimitSwitch`** : le capteur physique haut (8,5 m) reste la butée dure — si `TopPositionSensor` retombe, `AscentPermit` tombe → arrêt matériel. |
| Condition d'activation | N1 | `MaintN1 AND Homed AND NOT HomingSuspect AND BtnOverrideTopSoftware` | Sans référence de position fiable (`Homed` faux ou `HomingSuspect`), la butée logicielle ET la zone de ralentissement sont neutralisées : relever la limite ne laisserait QUE le capteur physique, approché à pleine vitesse. Refusé → seul reste le bypass N2 (acte conscient, tracé). |
| Plafond de sécurité | N1 | `TopLimitM := MIN(SEL(override, 7,5, 8,5), 7,5 + WinchSlowdownDistance_M)` | Le relèvement ne peut jamais excéder la bande de ralentissement (1,0 m). Au-delà, FB_Winch §3 n'engagerait plus le palier 1 avant le capteur : arrivée à pleine vitesse puis arrêt sec. Aujourd'hui 8,5 = 7,5 + 1,0 (MIN neutre) mais la protection est **structurelle** (invariant vérifié par G483 AC2b). |

### 2.2 Bypass position — N2 latché (RETAIN)

| Bascule | Mode autorisé | Effet | Justification sécurité |
|---|---|---|---|
| `TopLimitSwitch` (individuel OR commun) | **N2** latché | Lève le FDC haut **physique** (capteur `TopPositionSensor` ≈ 8,5 m) | Dépasser le capteur physique = acte assumé, uniquement en N2 (droits étendus), tracé par le RETAIN + journal. |
| `TopLimitSoftware` (individuel OR commun) | **N2** latché | Lève le FDC haut **logiciel** (7,5 m) → `TopLimitM` = 8,5 m | Dépassement logiciel assumé en N2. ⚠️ **A7 corrigé** : le bypass N2 relève la butée à 8,5 m mais **ne la supprime plus** (le terme `BypassTopLimitSoftware` a été retiré de la condition `AscentPermit` de `FB_Safety_Winch` par l'orchestrateur) — la butée logicielle reste active à la valeur relevée. |
| `CableLimitSwitch` (individuel OR commun) | **N2** latché | Lève la limite basse physique (longueur câble max) | Limite basse = intégrité câble : dépassement uniquement en N2, acte assumé. |
| `LimitLegal` (individuel OR commun) | **N2** latché | Lève la limite légale de profondeur | Bypassable en N2 (homogène projet) ; traçabilité assurée par le RETAIN + journal. |
| `MecaD` (individuel) | **N2** latché | Lève la détection d'arrivée butée haute anormale | Méca D = butée haute anormale : dépassement assumé en N2. |

### 2.3 Bypass benne / global — N2 latché

| Bascule | Mode autorisé | Effet | Justification sécurité |
|---|---|---|---|
| `BypassGlobal` benne (`ST_BypassBucket.Global`) | **N2** latché | Ignore toute la surveillance du mécanisme benne (M2) | Bypass groupé conservé (homogène projet, idem translation M3) ; effectif uniquement en N2. |
| `BypassGlobal` / `BypassSafety` / `BypassProcess` (axe) | **N2** latché | Groupés : ignore toutes / les PowerCutOff / les SafeStop de l'axe | Conservés (homogène projet) ; mode-gated N2. |
| `BypassContactorCheck` (FB_Winch) | **N2** latché | Lève le timeout de retombée des contacteurs | Bypass vivant sur FB_Winch (n°3 de la matrice) ; N2 latché. |
| `OperatorComm`, `EncoderFault`, `PhaseRotation`, `BrakeThermal`, `MotorThermal`, `MecaA`, `MecaB`, `MecaC`, `MecaE` | **N2** latché | Lèvent les défauts com/thermique/méca correspondants | Doctrine standard : N2 latché (RETAIN). `MecaB` = confirmation d'arrêt + coast-down + ContactorStuck → autorisé en N2 avec bandeau d'avertissement fort. |

### 2.4 Règle de bascule de mode + re-homing

| Règle | Détail | Justification sécurité |
|---|---|---|
| **Bascule de mode** | `ModeChangeAllowed := M1ContactorsReleased AND NOT M1BrakeIsOpen AND (ABS(M1Speed) < seuil) AND M2ContactorsReleased AND NOT M2BrakeIsOpen AND (ABS(M2Speed) < seuil)` | Entrer/sortir de N1/N2 refusé tant que les **deux** treuils ne sont pas à l'arrêt mécanique confirmé (contacteurs retombés + frein serré + |v| < seuil). Sinon `FB_Modes` maintient le mode courant + remonte `ModeChangePendingBlocked` (« arrêter les treuils avant de changer de mode »). |
| **Exemption DISABLE (D2)** | Transition vers/depuis `DISABLE` JAMAIS bloquée | Une sortie de maintenance ne doit jamais être retenue par un treuil en mouvement (exception de sécurité). |
| **Re-homing obligatoire** | `HomingRequiredMx` armé IMMÉDIATEMENT (§1ter, avant l'arbitrage de mode) dès qu'un override/bypass de position est **effectif** (`PositionLimitOverriddenMx` = override N1 OU bypass N2 position) | Un dépassement des limites de position invalide la confiance dans `CablePosM` — la re-référence est la seule remise à zéro sûre. Armement immédiat = pas de fenêtre d'un scan où SEMI_AUTO serait arbitré malgré un re-homing requis, pas de perte sur coupure/download (drapeau PERSISTENT). |
| **Levée du re-homing** | `HomingRequiredMx` retombe UNIQUEMENT sur cycle de homing complet réussi (`HomingLifecycle.Done` ET `Homed` ET NON `HomingSuspect`) | Seule une re-référence fiable lève l'obligation. |
| **Refus SEMI_AUTO** | `FB_Modes` refuse SEMI_AUTO si `HomingRequiredM1` OU `HomingRequiredM2` (bascule MAINT_N1) + cause nommée dans `Fault` | Tant que le re-homing est requis, SEMI_AUTO est interdit pour l'axe ; N1 reste autorisé pour manœuvrer. |

---

## 3 · Vérification contre les AC du contrat

| AC | Vérification | Statut |
|---|---|---|
| AC1 | Tous `Bypass*` transmis à `instSafetyWinchM1/M2`, `instWinchM1/M2`, `instBucket` gatés par `MaintN2` | ✅ G483 PASS |
| AC2 | `TopLimitM` = 7,5 m nominal / 8,5 m sous override ou bypass N2 | ✅ G483 PASS |
| AC3 | Override N1 n'ouvre JAMAIS `BypassTopLimitSwitch` | ✅ G483 PASS |
| AC4 | `FB_Modes` calcule `BasculeModeAutorisee` (contacteurs + frein + vitesse, M1 ET M2) | ✅ G483 PASS |
| AC5 | Transition vers/depuis DISABLE libre (D2) | ✅ G483 PASS |
| AC6 | `HomingRequired` armé immédiatement (§1ter, avant arbitrage) | ✅ G483 PASS |
| AC7 | `HomingRequired` retombe sur homing complet réussi | ✅ G483 PASS |
| AC8 | SEMI_AUTO refusé si `HomingRequired` + cause nommée | ✅ G483 PASS |
| AC9 | G200 : aucune instance orpheline, champs DUT déclarés/câblés | ⚠️ PASS T181-14 (1 orphelin pré-existant hors scope, §4) |
| AC10 | Aucun champ retiré de `ST_BypassWinch`/`ST_BypassCommun`/`ST_BypassBucket` (25 bascules) | ✅ Vérifié (18+6+1) |
| AC11 | Modifications non committées préexistantes préservées | ✅ Working tree CODE/ propre |
| AC12 | `BtnOverrideTopSoftware` dans `ST_WinchCmd`, absent de `ST_BypassWinch` | ✅ Vérifié |
| AC13 | Structure : nom fichier = nom POU | ✅ Vérifié |
| AC14 | Suffixe langage = ST pur (pas de `_CFC`/`_LD`) | ✅ Bundle `<ST>` |
| AC15 | Re-homing armé immédiatement + restauration boot PERSISTENT | ✅ G483 PASS |
| AC16 | Override N1 refusé si non `Homed` ou `HomingSuspect` (M1 ET M2) | ✅ G483 PASS |
| AC17 | `TopLimitM` borné par bande de ralentissement + invariant config | ✅ G483 PASS |
| AC18 | `FB_Modes.Fault` publié (PRG_03) + agrégé `AnyFaultActive` (PRG_07) | ✅ G483 PASS |
| AC19 | G483 vérifié par mutation (9/9) | ✅ (déjà exécuté 2026-08-30) |

**Aucun écart de la matrice contre les AC.** Le code est conforme.

---

## 4 · Résultats des gates

### 4.1 G200 — Auto-vérification liaison

```text
Auto-verification liaison (G200_check_linkage.py) — FAIL (1 erreur PRÉ-EXISTANTE hors scope)
  Linkage (L1-L7):    98 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 29 WARN
  L10 (Single prod):  1315 OK, 1187 WARN
  L11 (Polarity):     0 OK, 33 WARN
  L12 (Timing):       1 OK, 0 KO, 6 WARN
  L13 (Orphelins):    73 OK, 1 KO
  KO  [L13-FB] CODE/H_TREUILS_BENNE/FB_WinchSpeedLearning.st: FUNCTION_BLOCK `FB_WinchSpeedLearning`
      declare mais jamais instancie (aucun `: FB_WinchSpeedLearning` ailleurs dans CODE/) — orphelin
```

- **0 NOUVELLE erreur introduite par T181-14** : les L1-L7 (98 OK, 0 KO) confirment que tous les
  nouveaux champs DUT (`PositionLimitOverriddenM1/M2`, `ModesFault`, `HomingRequiredM1/M2`,
  `ModeChangePendingBlocked`, `BtnOverrideTopSoftware`) sont déclarés et câblés.
- **1 erreur PRÉ-EXISTANTE** : `FB_WinchSpeedLearning` orphelin (introduit par T181-15, présent dès
  le commit de base `e11c3345`, jamais instancié). **⚠️ ÉCART vs attente du contrat** : le contrat
  annonce que cet orphelin « reste en WARN », mais il n'est **pas** dans la liste
  `KNOWN_ORPHANS_PENDING_DECISION` de `G200_check_linkage.py` → il s'affiche en **ERROR**, pas en
  WARN. `G200_check_linkage.py` est **hors `scope.allowed`** → non modifié. **Traitement** : tâche
  T181-16 (`ORCHESTRATION_RAPPORTS/RAPPORT_T181-16_AUDIT_ORPHELINES.md`) — à ajouter à la liste
  d'exemption ou à instancier/supprimer.

### 4.2 run_all_gates --palier C

```text
RESUME — PALIER C (Temps total : 39.11s)
  FAIL  [10.84s]  G300 — Structure, documentation & sécurité (12/13)
  FAIL  [28.24s]  G400 — Bundle, qualité source & CI (11/12)
[FAIL] 2 gate(s) en echec sur 25 :
  - G340 — Liens documentaires
  - G430 — Commentaires REX (Zéro journal intime, §2ter)
```

- **23/25 PASS** (dont **G483 PASS**).
- **G340 FAIL** (111 erreurs) : liens morts dans `codex-session-*.md` (log de session) et fichiers
  `DOC/WFLOW/PROMPTS/*.md`, `DOC/WFLOW/REGISTRES/*.md`, `DOC/WFLOW/REX/*.md` — **tous hors
  `scope.allowed`**, pré-existants, non liés à T181-14.
- **G430 FAIL** (5 commentaires `[T181]`) : tous issus d'**autres tâches** (T181-02, T181-10,
  T181-15), pas de T181-14 :
  - `GVL_PERSISTENT.st:154` [T181-15] — commentaire T181-15 (concurrent)
  - `FB_WinchDirectionInterlock.st:29` [T181-02] — **hors scope**
  - `PRG_04_Treuils_Benne.st:134,455,771` [T181-10] — commentaires clamp de palier (T181-10)
  - Conformément à « Ne réécrire pas ce qui est déjà correct » et « Ne touche PAS aux fichiers
    hors scope.allowed », **non modifiés** (ce sont des commentaires d'autres lots décrivant du
    code correct).

---

## 5 · Écarts corrigés

**Aucun écart de la matrice corrigé** : le code de la matrice bypass N1/N2 (PRG_04 §5-0,
FB_Modes, PRG_03, PRG_07, GVL_PERSISTENT, DUT) est déjà implémenté et conforme aux AC1..AC19.
G483 passe. Aucun patch nécessaire.

---

## 6 · Alertes A1..A9 — statut

| Alerte | Sévérité | Statut |
|---|---|---|
| A1 | BLOCK_GEOMETRIE | **NON RÉSOLUE** — M2 benne fermée : limite relative à M1, override relève de 1,0 m alors que la marge native n'est que 0,5 m. Dépend de la géométrie réelle du capteur haut partagé (T1) et OffsetCloseM à reconfirmer (T2). |
| A2 | MAJOR | **NON RÉSOLUE** — `SlackCableAscentStep1` (PRG_04:266) lit `GVL_IHM.Commun.Bypass.SlackCable` en clair (hors N2). Préservé (D6 : sélecteur de récupération, pas un bypass de sécurité). |
| A3 | MAJOR | **NON RÉSOLUE** — `FB_Safety_Winch.Mode` déclaré et jamais utilisé. Arbitrage requis (déplacer la doctrine dans le FB ou retirer l'entrée morte). |
| A4 | MAJOR | **NON RÉSOLUE** — `M1M2Sync.Bypass.Global` force `ErrorId=0` sur désynchronisme critique. Hors périmètre treuils (D7), tâche à ouvrir (AF-05 §9). |
| A5 | MAJOR | **NON RÉSOLUE** — re-homing annulable en 1 clic (`BtnHome` presette position courante). Contre-mesure proposée : homing nominal capteur haut seul. |
| A6 | MAJOR | **NON RÉSOLUE** — « HomingSuspect forcé côté diag » non implémenté (producteur unique FB_Encoder). Décision documentaire, hors scope code. |
| A7 | MINOR | ✅ **RÉSOLUE par l'orchestrateur** — `FB_Safety_Winch.st` : le bypass N2 du FDC logiciel relève la butée à 8,5 m mais ne la supprime plus (`BypassTopLimitSoftware` retiré de `AscentPermit`). |
| A8 | MINOR | **NON RÉSOLUE** — `FB_Modes.Fault` remonté mais `FB_Hmi_BannerFormatter` sans texte dédié. Complément IHM à prévoir (F16). |
| A9 | MINOR | **NON RÉSOLUE** — agent concurrent dans le même arbre (FB_WinchSpeedLearning, T181-15). G200/G430 rouges sur LEURS apports (orphelin FB_WinchSpeedLearning, commentaires [T181]). Aucune de ces lignes n'a été touchée. |

---

## 7 · Fichiers modifiés

**Aucun fichier modifié** (matrice déjà implémentée et conforme). Seul livrable créé : ce rapport.

- `ORCHESTRATION_RAPPORTS/RAPPORT_T181-14_MATRICE_BYPASS.md` (créé)

---

## 8 · Validation humaine requise

- **A7** : valider la correction orchestrateur (butée logicielle relevée, non supprimée).
- **A1** : arbitrage géométrie M2 benne fermée (T1/T2) avant mise en service.
- **A9 / G200** : ajouter `FB_WinchSpeedLearning` à la liste d'exemption G200 (T181-16) ou
  l'instancier/supprimer.
- **G340 / G430** : traiter les liens morts et commentaires `[T181]` pré-existants (hors scope
  T181-14).
- Application manuelle dans CODESYS 3.5 (import PLCopenXML) par l'utilisateur.
