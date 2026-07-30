# FB_WinchOutputInterlock_LD — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.0.md`](AF_Partie-10_Fonction_Winch_v2.0.md) §6.
> Rôle de **ce** document : barrière finale, watchdog frein, machine d'état, anti-redémarrage —
> et **catalogue unique** des `TC-P10-012`, `013`, `020`.
> Source code : `CODE/TREUILS/FB_WinchOutputInterlock_LD.st` · instances dans `Outputs (Ladder)`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Winch_Extraction_Code_v1.0.md`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Machine d'état
4. Séquence hausse palier
5. Anti-redémarrage
6. Alertes et écarts
7. Documents liés

## 🧪 Points de validation (`TC-P10-012/013/020/021/022` — propriétaire unique)

| ID | Attendu | Type |
|---|---|---|
| TC-P10-012 | Watchdog frein barrière finale 500ms : sans confirmation ⇒ FAULT, RestartInhibit | AUTO_PLC |
| TC-P10-013 | Anti-redémarrage : cause disparue + Reset + neutre observé + nouvelle demande distincte | AUTO_PLC |
| TC-P10-020 | Watchdog frein réel terrain (temps, contacteur/bobine) | SITE |
| TC-P10-021 | Temps mort redémarrage même sens : 1s après arrêt → nouvelle demande même sens | AUTO |
| TC-P10-022 | Temps mort inversion sens : 1s après arrêt + inversion sens, > temps mort même sens | AUTO |

---

## 1. Rôle et profil

Profil **barrière finale** (Partie3 §2) : reçoit la demande sortie typée (`ST_WinchFinalInterlockRequest`),
applique les interlocks ultimes, produit **seule** la commande physique autorisée (Q réelles).
2 instances : `instWinchOutputInterlockM1_LD`, `instWinchOutputInterlockM2_LD`, dans `Outputs (Ladder)`.

`FB_Winch`/`ST_SpeedStepTable` restent propriétaires du **mapping** palier→contacteurs ; cette
barrière **autorise ou masque** la demande, ne la reconstruit jamais.

---

## 2. Interface

| Entrée | Sens |
|---|---|
| `Enable/Reset/PowerContactorEngaged` | Standard |
| `SafeStop` | Reçu de `FB_Winch` (déjà arbitré) |
| `BrakeReleaseRequest`/`BrakeCommandOpenConfirmed` | Demande + confirmation frein |
| `FwdRevSpeedFeedbackOff` | Confirmation arrêt réel |
| `RequestedRelayFwd/Rev`, `RequestedContactor1..4`, `RequestedStep` | Demande brute `ST_WinchFinalInterlockRequest` |

**Sorties** : `RelayFwd/Rev`, `Contactor1..4`, `BrakeCmd` (Q physiques), `State`, `Reason`
(`E_WinchFinalInterlockReason`), `AuthorizedStep`, `RestartInhibit`, `ErrorId`.

---

## 3. Machine d'état (`E_WinchFinalInterlockState`)

```text
DISABLED(0) → READY(1) → WAIT_BRAKE_COMMAND_CONFIRMATION(2) → WAIT_STEP_DELAY(3)
                                                              → WAIT_RESTART_DELAY(4)
                                                              → FAULT(5)
```

**Watchdog frein** : `T#500ms` fixe (câblé en dur) — armé si `BrakeReleaseRequest AND NOT
BrakeCommandOpenConfirmed AND NOT RestartInhibit`. Timeout ⇒ bit0 `ErrorId`, `RestartInhibit:=TRUE`,
`Reason:=BRAKE_COMMAND_NOT_CONFIRMED`, état FAULT.

**Gate final (double condition obligatoire)** : `RelayFwd/Rev`+`Contactor1..4` autorisés
**seulement si** `MovementRequested AND BrakeReleaseRequest AND BrakeCommandOpenConfirmed`.

---

## 5. Anti-redémarrage et temps mort de redémarrage

`RestartDelay` = **900ms** (paramétrable) après `FwdRevSpeedFeedbackOff` confirmé. 

**Nouveau : temps mort de redémarrage après arrêt** — distinct du redémarrage post-faute :
- **Redémarrage même sens** : temps mort paramétrable `DeadTimeSameDir` (défaut **1s**) après `MotorRequest=FALSE` → nouvelle demande.
- **Redémarrage inversion sens** : temps mort paramétrable `DeadTimeOppositeDir` (défaut **1s**, > temps mort même sens) — **en sus** du délai d'inversion 200ms FB_Winch.

Ces temps morts s'appliquent **dans la barrière finale** (cette FB), supérieurs aux délais internes FB_Winch (inversion 200ms + palier 1s250ms).

---

## 5. Séquence hausse palier

`StepDelay` = **1s250ms** — l'`AuthorizedStep` progresse un par un, invalidé si la cible change.

⚠️ **Écart vérifié** : ce délai (1s250ms, barrière finale) est **distinct** du délai métier
`BusinessStepDelay` = **1s500ms** dans `FB_Winch` — les deux se cumulent en cascade (~2.75s total
possible par montée de 2 paliers). Non documenté comme volontaire dans le code — voir AF10 §9bis.

---

## 5. Anti-redémarrage

`RestartDelay` = 900ms après `FwdRevSpeedFeedbackOff` confirmé. Réautorisation complète exige :
cause disparue + front Reset + demande neutre observée + nouvelle demande **distincte** avant de
réarmer `RestartInhibit`.

---

## 6. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P1 | Double délai palier (1s500 FB_Winch + 1s250 barrière) empilé, jamais clarifié voulu | Voir AF10 §9bis |
| 2 | P2 | **Temps mort redémarrage (même sens / inversion sens) absent des specs actuelles** | Ajouté §4, à valider terrain |

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF10 / FB_Winch | Producteur de la demande (`ST_WinchFinalInterlockRequest`) |
| AF03 | Profil barrière finale |
| Code | `CODE/TREUILS/FB_WinchOutputInterlock_LD.st` |
