# Plan Consolidé — Refonte GRAFCET Homing (Audits 5 Agents + Avis T377)

- **Date :** 2026-11-18
- **Checkpoints Git :** `0771dd2d` (code propre pré-refonte) · `048a0cf0` (suivi constats)
- **Sources :** Audits lecture seule Code (`bbea8fdb`), Spec AF/T377 (`f1f08edf`), Effets de bord & CI (`1e57e6ce`), Ollama DeepSeek `safety` / `plc` / `challenger` / `T377` (`task-3023/3024/3025/3034`).
- **Statut :** Plan prêt pour validation des décisions §5 avant lancement Phase 1. **Aucune modif `CODE/` appliquée.**

---

## 1. Vérification : Constats exploitant vs Code réel

| Point vérifié | Statut code réel | Preuve `fichier:ligne` |
|---|---|---|
| Verrou anti-relance si déjà `MachineHomed` | ❌ **ABSENT** | `FB_CycleMachineHoming.st:416-420` (aucun `AND NOT MachineHomed`) |
| Mouvement libre bloqué en `MAINT_N1` si non ref | ❌ **ABSENT** | `PRG_04:1113-1116, 1223-1224` (`ArmingPermit=TRUE`, seul palier 1 bridé `:1260-1264`) |
| Entrée homing par maintien 5 s `JoyBtnRaw` neutre | ❌ **ABSENT** | `PRG_02:607-610`, `FB_CycleMachineHoming.st:416` (IHM `BtnStart`/`BtnValidate` en `N2` seul) |
| Benne « se souvient » d'être ref si M1/M2 non ref | 🐛 **BUG** | `FB_Bucket.st:416-419` (reset `BucketReferenced` sur `HomingSuspect` 2 s seul, pas `NOT Homed`) |
| Butées benne / câble actives sans référence | 🐛 **BUG** | `PRG_04:769-801` (`ManualBucketLimitsActive`), `FB_Safety_Winch.st:565` (sans `Homed`) |
| `ErrorID:05` seulement pendant appui | 🐛 **BUG** | `FB_Bucket.st:283-288` (`Latching:=FALSE`) + `PRG_03:354-355` (`WinchBothIntent` non gâté) |
| Step 1 ouv+ferm sans butées + garde temps `X` s | ❌ **ABSENT / BUG** | `FB_CycleMachineHoming.st:422-438` (`CmdBucketClose` seul, aucun timer continu) |
| `BtnValidate` IHM sans effet en `HX1` | 🐛 **BUG** | `FB_CycleMachineHoming.st:433` écoute `BtnConfirmHomingBucket` (`PRG_02:612`), pas `BtnValidate` |
| `BtnAbort` inopérant / alias de `Reset` | 🐛 **BUG** | `PRG_02:589` vs `PRG_03:243` (`CycleSemiAuto.Cmd.BtnAbort` séparé ; `BtnAbort` efface les latches) |
| `AnyFaultActive` incomplet (voyant reset éteint) | 🐛 **BUG** | `PRG_07:612-622` omet `MachineHoming.Failed`, `Safety.LatchedId`, `Encoder`, `State.Error`, etc. |
| Step 2 descente autorisée + `ErrorID:04` | 🐛 **BUG** | `FB_WinchCmdArbitrationM1/M2` ignore `ReqWinch` en maintenance ; `FB_Bucket.st:274, 476-480` |
| Capteur haut ne coupe pas + `Meca D` absent en `N2` | 🚨 **CRITIQUE** | `PRG_07:385-397` (`SimBypassRise` + `RETAIN`), `PRG_04:1632,1653` (`PowerCutOff AND NOT MaintN2`) |
| `M3` interdit si `NOT MachineHomed` | ⚠️ **PARTIEL** | `PRG_05:524-526` bloque seulement `CycleRunning`, pas Step 0 (`HX0`) |

---

## 2. Avis T377 & Justification des Écarts

| Écart T377 vs Nouveau Plan | Comment T377 le justifiait | Verdict critique |
|---|---|---|
| **1 passe sans contact TOP** vs **2 passes (contact Passe 1 + arrêt avant TOP Passe 2)** | Après avarie du 25/09, T377 posait TOP = barrière de coupure seule (l'inertie fausse la cote si on écrit au contact). | **Réconciliable :** si Passe 1 prend une **ref provisoire** (ou `8.5 m` calibré) pour dégager et tester l'ouverture benne, l'arrêt **avant TOP** en Passe 2 évite de retaper le switch en fin de homing (voir Décision D5). |
| **IHM seul (`BtnStart`/`BtnValidate`)** vs **5 s `JoyBtnRaw` au neutre** | Mini-lot anti-démarrage `R3` (`PRG_02:609`) avait retiré `JoyBtnRaw` pour éviter un faux départ au simple armement. | **Insuffisant côté T377** (`FB:416` sans `NOT MachineHomed`). Le maintien **5 s neutre continu + anti-collage + `NOT MachineHomed`** (avec `ArmingPermit` découplé) répond aux deux craintes sans nouveau bouton. |
| **`MAINT_N2` seul** vs **`MAINT_N1` Step 0 verrouillé** | Doctrine historique T184 (`AF05 §4bis`). | **Contradiction interne T377 :** `MAINT_N2` shunte `SafetyWinch` et `PowerCutOff`. Passer le homing guidé en **`MAINT_N1`** (Option B) tout en bloquant les mouvements libres en Step 0 est nettement plus sûr. |
| **`Meca D` (`PowerCutOff`) masqué en `MAINT_N2`** | Périmètre T377 gelé (`D1=C`, interdiction de toucher `FB_Safety_Winch.st`). | **Trou réel à rejeter** (`PRG_04:1632,1653`) : un collage contacteur sur capteur haut doit couper la puissance (`Meca D`), sans casser `Meca B` lors du desserrage frein par gravité. |
| **`M3` libre en `HX0`** | Arbitrage T377 avait limité `M3Locked` à `CycleRunning`. | **Trou partiel** : bloquer `M3` en `N1`/`SEMI_AUTO` si `NOT MachineHomed`, tout en gardant un **échappatoire `N2` contrôlé** si chariot coincé hors `P1`/Trémie. |
| **Step 1 sans timeout `X` s** | Non justifié dans les docs T377 (`HX1` copié tel quel). | **Trou réel** : le timer continu `X` s + retour neutre obligatoire est requis. |

**Patrimoine T377 à conserver :** latch `TopContactLatched` + trace non-latching des contacts TOP, `HX2A` dégagement à montée interdite, `HomeReq` unique à l'arrêt (jamais en continu), garde de cohérence finale, zéro nouveau bouton matériel.

---

## 3. Top Effets de Bord Bloquants & Parades (Avant Codage)

1. **Deadlock maintien 5 s (`ArmingPermit = FALSE`)** — `FB_Joystick.st:225-244` bloque `DeadmanArmed` si aucun axe n'est dispo (`ArmingPermit`).
   - *Parade :* en Step 0, lire `HwIn.Operator.JoyBtnRaw` + `instJoystick.AtNeutralXY` directement dans `FB_CycleMachineHoming` (sans dépendre de `DeadmanArmed`), avec message prioritaire dans le bandeau.
2. **En `MAINT_N1`, `T248` & `M3AtTremie` cassent la montée couplée** — `FB_Modes.st:370-402` force `WinchSel := 2` si `BucketIsClosed = FALSE` ou si chariot à la Trémie (`CouplingInterlockFault` immédiat).
   - *Parade :* neutraliser `T248` dès `MachineHoming.Active = TRUE`, et vérifier la position M3 avant/pendant homing.
3. **Les arbitres `FB_WinchCmdArbitrationM1/M2` ignorent `ReqWinch` en maintenance** — donc les pas/paliers et sens de `HX2` ne sont pas appliqués, et après calibration Passe 1 le bridage palier 1 (`PRG_04:1260`) saute en Passe 2 !
   - *Parade :* router `ReqWinch` (ou gâter permis directionnels + `MaxStep := 1`) sur `MachineHoming.Active`.
4. **Ne JAMAIS étendre `InReferencingMode` à `MachineHoming.Active`** — sinon `FB_Safety_Winch` ignore `TopPositionSensor`, `Meca D` et remet `Meca A/E` à zéro en boucle !
   - *Parade :* garder `InReferencingMode` limité au preset `HomingLifecycle.Busy`, et utiliser un signal dédié (ou `NOT Homed`) pour les seules **butées logicielles** (`CfgCableLimitDescentM`, `ManualBucketLimitsActive`).
5. **Piège `Meca D` en descente de dégagement Step 3** — `Meca D` (`FB_Safety_Winch.st:377-379`) ne vérifie pas le sens : si le frein est ouvert > `3 s` en descendant pour quitter la came du capteur haut, `Meca D` coupe `PowerCutOff` !
   - *Parade :* exempter `Meca D` uniquement sur descente intentionnelle pure (aucune demande/contacteur montée, demande descente active).
6. **Démasquer `PowerCutOff` en `MAINT_N2` déclenche `Meca B` au desserrage frein** (`PRG_06:324-335`) — *Parade :* démasquer `Meca D` (hors bypass `Meca D`) en `N2` ou inhiber `Meca B` pendant `MaintenanceN2BrakeForce`.
7. **Faux boot fault `SEMI_AUTO` (`PRG_03:76-93` + `FB_Modes:251`)** — forcer `SelMode := SEMI_AUTO` au boot quand `NOT MachineHomed` lève `ModesFault.Error` et allume `AnyFaultActive` dès le démarrage. *Parade :* boot en `MAINT_N1` si `NOT MachineHomed`.
8. **Verrou `M3` dès Step 0 vs position chariot quelconque** — D7 impose de pouvoir lancer le homing **quelle que soit la position de `M3` (même entre deux capteurs)**, sans imposer de déplacement préalable du chariot ni bloquer sur `M3AtTremie`/`WinchDescentAuth_M3`. *Parade :* verrouiller `M3` dès Step 0 en `N1`/`SEMI`, lever les blocages treuils liés à `M3` pendant `MachineHoming.Active`, et conserver `MAINT_N2` comme échappatoire manuelle.
9. **Autres corrections conjointes :** `PRG_06:260-262` (garder `WinchOutputCoupled` actif sur les phases couplées en `N1`), `PRG_07:385-397` (ne pas persister `BypassTopLimitSwitch` en `RETAIN` hors sim), `FB_Bucket:274, 476-480` (purger `instBucket` à l'entrée Step 1 pour éviter `ErrorID:04`), `FB_Encoder_Homing.st:206-223` (empêcher `UnitaryHomingTrigger` d'écrire `8.5 m` hors capteur haut sur micro-rebond ou en `N1`), et mise à jour coordonnée des gates `G506`, `G511`, `G480`, `G483` + tests `TEST_AUTO_CI` (`test_fb_cyclemachinehoming.st`, `test_sim_operator_joystick.st`, `test_sim_manual_reference.st`, `test_prg_03/04/05.st`, `test_fb_bucket.st`, `test_fb_modes.st`).

---

## 4. Architecture Cible du Nouveau GRAFCET (Vue Step-by-Step — D1 à D7 verrouillés)

```text
  [Step 0 : H0_REPOS]  (NOT MachineHomed, N1 libre bloqué, M3 verrouillé N1/SEMI, M3 autorisé partout)
         │  Maintien 5 s JoyBtnRaw au neutre strict + anti-collage (ou BtnStart N2)
         │  [Verrou absolu : IMPOSSIBLE si MachineHomed = TRUE]
         ▼
  [Step 1 : H1_BUCKET_PREPARE]  (M2 seul, ouv + ferm, AUCUNE butée soft, TON max 20 s + décompte message)
         │  "Fermer visuellement la benne — DANGER aucune limite" + BtnValidate au neutre
         ▼
  [Step 2 : H2_CLIMB_TO_TOP]  (Couplé M1+M2, montée lente + max 2 s détente câble bornée)
         │  "Approcher le plus près du capteur haut SANS le toucher"
         ├──▶ Contact TOP (TopPositionSensor) = PERDU / SURCOURSE -> coupure montée immédiate
         │       ▼
         │   [Step 3 : H3_TOP_CLEARANCE]  (Montée interdite -> descente continue ~4 s après relâchement TOP, temporisée sans codeur)
         │       │  Temps dégagement écoulé + arrêt neutre -> retour [Step 1] (re-fermer/confirmer benne puis réessayer Step 2)
         ▼
  [Step 4 : H4_FINAL_CONFIRM]  (Arrêt visuel au plus près AVANT TOP -> avertissement + BtnValidate)
         │  Contrôle TOP=FALSE + écriture cote 8.5 m + ref benne -> "Homing fait"
         │  MachineHomed := TRUE, machine libérée -> retour Step 0 verrouillé
         ▼
  [HX7_FAILED]  (Timeout, collage contacteurs/frein / Meca D, discordance, perte mode -> Reset conscient en N1/N2)
```

---

## 5. Décisions actées (D1–D7 — Plan verrouillé)

### Actées par l'exploitant (2026-11-18)
- **D1 — Mode homing :** ✅ **Validé = `MAINT_N1` et `MAINT_N2`**. Cycle guidé complet faisable directement en `MAINT_N1` (direct depuis page d'accueil, mouvements libres bloqués en Step 0). Si problème mécanique, l'opérateur sort du cycle (`Abort`) et passe en `MAINT_N2` pour dégagement secours inconditionnel.
- **D2 — Entrée Step 0 :** ✅ **Validé = `JoyBtnRaw` 5 s au neutre strict + anti-collage en `MAINT_N1`** (+ décompte visible), et `BtnStart` IHM en `MAINT_N2`. Message `MAINT_N1` Step 0 rappelle aussi la possibilité de passer en `MAINT_N2` (secours).
- **D3 — Durée max continue Step 1 (`X` s) :** ✅ **Validé = `20 s` par défaut (paramétrable `Cfg`) avec décompte temps visible dans le champ message** + coupure nette et retour neutre/homme-mort si dépassé.
- **D4 — Step 2 descente détente câble :** ✅ **Validé = descente détente câble autorisée mais bornée à max `2 s` par geste** (coupure nette à 2 s + retour neutre obligatoire pour réarmer).
- **D5 — Contact TOP vs cote `8.5 m` :** ✅ **Validé = toucher `TopPositionSensor` est TOUJOURS PERDU / surcourse** (course inconnue derrière le contact, jamais de prise de `8.5 m` sur contact TOP). L'opérateur vise au plus près **avant** `TopPositionSensor` sans le toucher, puis valide avec avertissement → écriture `8.5 m` + référence benne → `"Homing fait"` (`MachineHomed := TRUE`).
- **D6 — Dégagement contact TOP (Step 3) :** ✅ **Validé = coupure immédiate de la montée**, passage en Step 3 exigeant une **descente continue temporisée (`~4 s` après relâchement du capteur TOP, indépendante des codeurs)**, puis **retour à Step 1** (vérification/fermeture benne puis nouvelle tentative Step 2 en s'arrêtant avant TOP).
- **D7 — `Meca D` & `M3` :** ✅ **Validé** :
  - **`Meca D` (`PowerCutOff`) reste ACTIF en `MAINT_N2`** (capteur de surcourse mécanique après fins de course logiciels ; jamais démasqué automatiquement en `N2` — un éventuel bypass explicite ne peut être que manuel).
  - **Position `M3` indifférente pour le homing** (y compris entre deux capteurs) : pas de prérequis de mouvement chariot, levée des blocages treuils liés à `M3` pendant `MachineHoming.Active`, verrouillage `M3` dès Step 0 en `N1`/`SEMI`, échappatoire manuelle préservée en `MAINT_N2`.

---

## 6. Roadmap Phasée (Jalons, Commits, Challenges & Tests)

> *Gouvernance Task Manager :* `T377` dans `DOC/WFLOW/TASKS.yaml` est actuellement verrouillée par `CC03`. Au GO, ouverture/usage d'un contrat dédié C4 (ou validation explicite exploitant sur `TASKS.yaml`) avant toute modification `CODE/`.

| Phase | Contenu | Livrables & Contrôles | Jalon Git / Validation |
|---|---|---|---|
| **Phase 0** | ✅ Spec + Audits + Avis T377 + Décisions D1–D7 verrouillées | `SUIVI_...` + `PLAN_...` | `commit` plan verrouillé + **GO utilisateur (et choix contrat C4)** |
| **Phase 1 — Contrat & Socle Sécurité/IHM** | Contrat C4 ; `Meca D` actif en `N2` (sans faux `Meca B` sur déblocage frein) ; `InReferencingMode` séparé des butées soft ; `BucketReferenced` invalidé sur `NOT Homed` ; `AnyFaultActive` + `G506` ; `BtnValidate`/`BtnAbort` unifiés ; boot `MAINT_N1` ; `WinchBothIntent` ; levée blocages `M3` pendant homing | `CODE/` hors GRAFCET + `G200` + `G506` + `G483` + challenge `safety` | `commit` jalon 1 + revue `safety`/`challenger` Ollama |
| **Phase 2 — Nouveau GRAFCET Homing + Arbitrage** | `FB_CycleMachineHoming` (Step 0 5 s neutre, Step 1 ouv/ferm + TON `20 s` décompte, Step 2 montée + détente `2 s`, Step 3 dégagement TOP `~4 s` → Step 1, Step 4 validation finale `8.5 m`) + routage `PRG_03`/`PRG_04`/`PRG_05`/`PRG_06` | `CODE/` + `G200 --report` + `G511` + `G480` + bundle XML + diff bundle | `commit` jalon 2 + revue `plc`/`safety` Ollama |
| **Phase 3 — Tests CI & Simulateur** | Réécriture `test_fb_cyclemachinehoming.st` + mise à jour tests `M_MAIN`/`F_MODES`/`L_SIMULATION` + scénarios `FB_SimBench` (contact TOP → dégagement ~4 s → Step 1, Step 1 timeout `20 s`, détente `2 s`, relance verrouillée, `AnyFaultActive`, `Meca D` en `N2`) | `pytest TOOLS/TEST_AUTO_CI` + `run_all_gates.py --palier C` (0 fail) | `commit` jalon 3 + **Livrable prêt pour TON test en simulation CODESYS** |
| **Phase 4 — Docs AF** | Mise à jour `AF_Partie-05/07/09/10/11` + archivage anciens brouillons T377 | `G340_check_doc_links.py --fix` + `run_all_gates.py` complet | `commit` final après ton verdict simu |
