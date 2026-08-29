# FB_WinchOutputInterlock — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §6.
> Rôle de **ce** document : barrière finale, watchdog frein, machine d'état, anti-redémarrage —
> et **catalogue unique** des `TC-P10-012`, `013`, `020`.
> Source code : `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` · instances dans `PRG_06_Outputs`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Machine d'état
4. Séquence hausse palier
5. Anti-redémarrage
6. Alertes et écarts
7. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P10-012/013/020/021/022`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 170px);">
    <col style="width: 90px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Intention / Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-012</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Watchdog frein barrière 500ms sans confirmation ➔ FAULT + Inhibit</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-013</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Anti-redémarrage : Cause + Reset + Neutre ➔ réautorisation</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-020</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Watchdog frein réel terrain (temps, contacteur/bobine)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>🟢 SITE</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-021</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Temps mort même sens : 1s après arrêt ➔ nouvelle demande</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-022</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Temps mort inversion : 1s après arrêt + inversion sens</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

Profil **barrière finale** (Partie3 §2) : reçoit la demande sortie typée (`ST_WinchFinalInterlockRequest`),
applique les interlocks ultimes, produit **seule** la commande physique autorisée (Q réelles).
2 instances : `instWinchOutputInterlockM1`, `instWinchOutputInterlockM2`, dans `PRG_06_Outputs`.

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
| Code | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` |
