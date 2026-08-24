# 🛡️ T91 — ÉTUDE : Séquence frein/puissance asymétrique

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T91 — analyser la **séquence asymétrique**
> frein/puissance : **montée** = frein engagé d'abord (puis puissance) ; **descente** = puissance
> coupée immédiatement. Source : `FB_Brake.st`, `MES-006`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T91.

---

## 1. Constat — séquence actuelle `FB_Brake`

| Sens | Comportement actuel (`FB_Brake`) |
|---|---|
| **Montée / démarrage** (`MovementRequested=TRUE`) | `TonMagnetise` (DelayMagnetise + DelayContactClose, 300+100 ms) **avant** de relâcher le frein (`BrakeCmd=TRUE`) → puissance établie AVANT ouverture frein (L72-81) |
| **Descente / arrêt** (`MovementRequested=FALSE`) | `BrakeCmd := FALSE` (fermeture **immédiate**) — frein collé dès que les contacteurs s'ouvrent (L82-88) |

**Problème (MES-006)** : la séquence est **symétrique en timing** mais ne prend pas en compte le
**sens (montée vs descente)**. Or physiquement :
- **Montée** : si le frein se relâche avant que la puissance retienne la charge, la **charge peut
  redescendre** (frein = seul garde-fou) → il faut **frein d'abord** (collé) puis puissance, et
  relâcher le frein seulement quand la puissance est prête.
- **Descente** : couper la puissance **immédiatement** (le frein retient), pas d'attente de
  décélération en rampe.

---

## 2. Séquence asymétrique cible (design)

| Sens | Séquence proposée |
|---|---|
| **Montée** | ① frein **collé** (sécurité) → ② puissance établie (magnétisation) → ③ frein **relâché** une fois puissance OK |
| **Descente** | puissance coupée **immédiatement** → frein collé (pas d'attente de rampe) |

> ⚠️ **Polarité** (NC-100) : `BrakeCmd=TRUE` = frein relâché (ouvert). La séquence montée doit
> garantir `BrakeCmd=FALSE` (frein collé) tant que la puissance n'est pas établie.

**Implémentation proposée (design)** :
- `FB_Brake` reçoit un sens (`Direction`/`CommandedDirection`) en plus de `MovementRequested`.
- **Montée** : garder `TonMagnetise` avant relâchement (déjà OK) — vérifier que la puissance
  (contacteurs) est bien établie AVANT `BrakeCmd=TRUE`.
- **Descente** : `BrakeCmd := FALSE` **immédiatement** (déjà le cas), pas d'attente de `DelayMotorDecel`
  si celui-ci gêne l'arrêt — à clarifier (MES-006).

---

## 3. Points à trancher (avant implémentation)

| # | Question |
|---|---|
| 1 | `FB_Brake` reçoit-il le **sens** (montée/descente) ? (nouvelle entrée `Sens`/`Direction`) |
| 2 | La séquence descente actuelle (fermeture immédiate) est-elle conforme MES-006, ou faut-il une **rampe** ? |
| 3 | Confirmer la **polarité** et l'ordre exact (puissance avant frein en montée) |
| 4 | Implémentation (code) → **validation humaine** (C4 sécurité) |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T91 |
| FB | `CODE/A_COMMUN/FB_Brake.st` |
| MES | MES-006 (réf terrain) |
| Spec | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md §3` |
