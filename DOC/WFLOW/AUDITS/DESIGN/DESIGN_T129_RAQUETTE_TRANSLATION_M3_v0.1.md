# 🩺 T129 — Trou dans la raquette troubleshooting Translation M3

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T129 — combler le trou diagnostique qui
> empêche de comprendre l'**éjection SEMI_AUTO** de la Translation M3.
> Source : `FB_TroubleshootingView.st`, `GVL_Troubleshooting.st`, `PRG_05_Translation.st`,
> `ST_Chain_Translation_*.st`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T129.

---

## 1. Constat — le trou (vérifié code)

La raquette **TranslationPontM3** expose, côté Safety_300 (Idx309-316) et Control_400 :

| Exposé aujourd'hui | Source |
|---|---|
| `Idx309..316` — les **8 bits décapsulés** d'`ErrorId` (OperatorComm, DriveComm, PhaseRotation, BrakeThermal, MecaB, MecaA, LimitSwitch, SensorIncoherent) | `Translation.Safety.ErrorXxx` (PRG_05:434-441) |
| `Idx401_MotionAllowed`, `Idx402_SetpointFreq_Hz`, `Idx403_DriveControlWord`, ... | `Translation.State.*` |

**NON exposé** :
| Manquant | Pourquoi c'est bloquant |
|---|---|
| **`instSafetyTranslationM3.Status.ErrorId` brut** (WORD complet) | Les 8 bits décapsulés perdent le **masque exact** et surtout le **latch cause** : impossible de distinguer quelle combinaison / quel bit a réellement provoqué l'éjection SEMI_AUTO. Le `ErrorId` brut est la **seule source d'arbitrage** (`PowerCutOff := (ErrorId AND 16#00F8)`, `FB_Safety_Translation` L257). |
| **`M3_Direction_Active`** (INT, sens réel appliqué) | La direction demandée (`Direction` IN) n'est pas la direction réellement active. `M3_Direction_Active` (calculée PR_470, `PRG_05:156-176`) est le **sens sémantique réel** qui pilote les commandes variateur — absent → on ne peut pas diagnostiquer une inversion de sens ou un blocage directionnel à l'origine de l'éjection. |

---

## 2. Câblage proposé (design — à valider avant code)

Ajouter 2 champs dans les structs de la raquette Translation + le câblage dans
`FB_TroubleshootingView.st` :

| Struct | Champ | Source | Sens |
|---|---|---|---|
| `ST_Chain_Translation_Safety` | `Idx317_ErrorId` : WORD | `Translation.Safety.ErrorId` (= `instSafetyTranslationM3.Status.ErrorId`, `PRG_05:433`) | Masque brut complet |
| `ST_Chain_Translation_Control` | `Idx408_DirectionActive` : INT | `Translation.State.ActiveDirection` (= `SEL(..., M3_Direction_Active, 0)`, `PR_05:393`) | Sens réel appliqué |

Câblage `FB_TroubleshootingView` (région §5 TranslationPontM3) :
```
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx318_ErrorId := Translation.Safety.ErrorId;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx408_DirectionActive := Translation.State.ActiveDirection;
```

> 🛠️ **Cohérence producteur unique** : ces 2 sources sont déjà des producteurs uniques
> (`Translation.Safety.ErrorId`, `Translation.State.ActiveDirection`) — on ne recompose rien,
> on expose simplement un miroir (conforme esprit bus, cf. T142).

---

## 3. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Ajouter les 2 champs + le câblage ? (recommandé) |
| 2 | Faut-il aussi exposer `instSafetyTranslation3.M3_SafeStop_Aggregate` (agrégat SafeStop) ? |
| 3 | Implémentation (code `FB_TroubleshootingView` + structs) → **validation humaine** requise |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T129 |
| Câblage | `CODE/J_SUPERVISION/FB_TroubleshootingView.st` (région §5) · `PRG_05_Translation.st` (L472, L393) |
| Structs | `ST_Chain_Translation_Safety.st` · `ST_Chain_Translation_Control.st` |
| Spec raquette | `DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.2.md` |
