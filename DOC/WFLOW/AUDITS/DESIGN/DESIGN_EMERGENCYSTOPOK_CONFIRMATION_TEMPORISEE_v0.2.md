# 🛑 T11 — `EmergencyStopOk` : confirmation temporisée post-réarmement

> 📄 **ÉTUDE / DESIGN (zéro code)** · **v0.2** (corrigé après revue indépendante 2026-08-24) ·
> 📅 2026-08-24 · 🎯 T11 — analyser et concevoir la **confirmation temporisée** de l'état
> « arrêt d'urgence levé » après un réarmement AU.
> Source : `FB_Safety_EmergencyManagementLogic.st` (séquence réarmement), `AF_Partie-01`.
> 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T11. Réf constat : « AUDIT D93 » (externe, absent du dépôt).

> 🟠 **v0.2** : corrige le défaut rédhibitoire v0.1 (voir §3) — `EmergencyStopOk` ne doit **PAS**
> reposer sur `Armable` (qui exige `NOT PowerContactorEngaged`, donc FALSE après réarmement réussi).

---

## 1. Constat — l'état AU actuel

**`EmergencyStopOk` n'existe plus dans le code actuel** (grep = 0 hit). Il a existé comme signal
IHM (migré `GVL_IHM.Modes.State.EmergencyStopOk`, `IHM_VARIABLES_MIGRATION.md:120`) mais n'est
**pas câblé aujourd'hui**. ⚠️ **Historiquement c'était un VERROU DE MOUVEMENT**
(`SafeStop = Error OR NOT EmergencyStopOk`) — à ne pas recâbler aux FB de mouvement tant qu'on ne
l'a pas re-défini.

L'état AU est porté par `FB_Safety_EmergencyManagement` :

| Signal | Sens |
|---|---|
| `State.Armable` | Réarmement **possible maintenant** (chaîne OK, step=0, pas de lockout) |
| `State.Step` | Étape séquence (0=IDLE..6=Confirm) |
| `State.ArmingBusy` | Séquence ou lockout en cours |
| `State.ArmingFailed` | Échec réarmement (latch) |
| `State.LockoutActive` | Verrouillage 5 s anti-réessai |
| `State.EmergencyStopOk` | **absents** |

**Séquence de réarmement** (`FB_Safety_EmergencyManagementLogic` L166-256) :
```
0 IDLE → 1 TestA → 2 RestoreA → 3 TestB → 4 RestoreB → 5 Pulse (1s) → 6 Confirm (≤2s) → 0 IDLE
```
En `6 Confirm`, on attend `PowerContactorEngaged` (contacteur de puissance engagé) sous 2 s ; à
timeout → `EmergencyArmingFailed` + lockout 5 s.

---

## 2. Problème — pas de confirmation de stabilité post-réarmement

La séquence conclut par **`6 Confirm → 0 IDLE`** et la chaîne est refermée. Mais **aucun signal
positif n'atteste « l'AU est levé ET l'état est stable »** après le pulse : un contacteur qui
« re-colle » (rebond) ou un défaut AU non re-confirmé peut laisser croire que la machine est prête.

---

## 3. Conception — `EmergencyStopOk` (🔴 v0.1 corrigée)

> 🔴 **Erreur v0.1** : j'avais posé `EmergencyStopOk := Armable ∧ stabilité`. **FAUX** : `Armable`
> exige `NOT PowerContactorEngaged` (Logic L291), or après un réarmement réussi le contacteur est
> **engagé** → `Armable = FALSE` au moment où la machine est prête → `EmergencyStopOk` serait
> **toujours FALSE**. Verdict revue.

**Correction** : baser la confirmation sur **`PowerContactorEngaged`** (le fait d'engagement
contacteur, attesté au succès du step 6), **pas** sur `Armable`.

| Signal | Sémantique | Condition |
|---|---|---|
| `EmergencyStopOk` | AU levée **et confirmée stable** | `PowerContactorEngaged` **ET** stable pendant la fenêtre **ET** `NOT (ArmingFailed OR RedundancyFault OR StartupFault)` |

**Algorithme (design, à valider)** :
1. **Origine** : `PowerContactorEngaged` (retour physique, engagé au step 6 Confirm réussi).
2. **Fenêtre de stabilité** `TonStopOkStability` : `EmergencyStopOk` ne passe à `TRUE` que si
   l'état reste sain (contacteur engagé, pas de défaut AU) pendant toute la fenêtre.
3. **Retombée immédiate fail-safe** : `EmergencyStopOk := FALSE` dès que `PowerContactorEngaged`
   repasse à `FALSE`, ou un défaut AU (redundance/armement/startup) est actif — **jamais de
   réarmement automatique** (guardrail machine).
4. **Reset = front** : pas d'acquittement implicite.

> 🔔 **Alerte sécurité** : `EmergencyStopOk` était historiquement un **verrou de mouvement**
> (`SafeStop = Error OR NOT EmergencyStopOk`). Le re-définir « **diagnostic / état** » est OK
> **tant qu'on ne le recâble PAS aux FB de mouvement** sans décision explicite. Le blocage
> sécurité reste la responsabilité de `SafeStop`/`PowerCutOff` (Méca).

> 🟠 **Fenêtre 100–300 ms (v0.1) retirée** : revue — pas de rôle de sécurité (simple debounce
> d'affichage), redondante avec l'anti-rebond contacteur (20 ms), valeur non figée sans la spec
> D93. → soit la retirer, soit la cadrer explicitement avec la spec D93. Le présent doc **ne la
> fige pas**.

---

## 4. Points de validation proposés (renumetés, à confirmer)

| ID | Comportement attendu |
|---|---|
| TC-P01-011 | `EmergencyStopOk` reste `FALSE` tant que la séquence n'a pas atteint step 6 réussi |
| TC-P01-012 | Après step 6 réussi + `PowerContactorEngaged`, `EmergencyStopOk` passe à `TRUE` après stabilité |
| TC-P01-013 | `PowerContactorEngaged` retombe → `EmergencyStopOk` re-passe `FALSE` immédiatement |
| TC-P01-014 | Défaut AU actif (redundance/armement/startup) → `EmergencyStopOk` reste `FALSE` |

> ⚠️ Vérifier la numérotation vs AF_Partie-01 existante (TC-P01-001..) avant réservation.

---

## 5. Décision en attente (avant implémentation)

| # | Question | Recommandation |
|---|---|---|
| 1 | `EmergencyStopOk` **verrou de mouvement** historique → ré-câbler ou diag seulement ? | diag seulement (le blocage est à `SafeStop`/`PowerCutOff`) |
| 2 | Fenêtre de stabilité : la figer (combien ?) ou la **retirer** (debounce 20 ms suffit) ? | retirer, sauf spec D93 contraire |
| 3 | Où vit `EmergencyStopOk` ? | sortie `FB_Safety_EmergencyManagement` (composite → `ST_Safety_Emergency_State` → IHM) |
| 4 | Spec `AUDIT D93` (externe) | fournir pour confirmer fenêtre + cas limites |
| 5 | **Nommage** : suffixe `Ok` **muet** (NC-204) → considérer `*Allowed` (`EmergencyStopAllowed`) | `*Allowed` (cohérent T109) — à confirmer |

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T11 |
| FB AU | `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagementLogic.st` · `FB_Safety_EmergencyManagement.st` |
| Spec FB | `DOC/AF/AF_Partie-01_Analyse_Fonctionnelle/FB_Safety_EmergencyManagement_v1.2.md` |
| Bugs liés | `VERSION_HISTORY.md:398` (lockout step Trip) |
| Convention | `DOC/STDS/NAMING_CONVENTION.md` (polarité NC-100) |
