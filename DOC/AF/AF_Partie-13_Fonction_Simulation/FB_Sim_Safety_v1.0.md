# FB_Sim_Safety — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.4.md`](../AF_Partie-13_Fonction_Simulation_v2.4.md) §4.
> Rôle de **ce** document : modèle simulé de la chaîne AU/contacteur — et **catalogue unique** des `TC-P13-020...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Safety.st` · instance `FB_SimBench.instSimSafety`.
> ⚠️ Ce FB ne simule **que** les entrées de `FB_Safety_EmergencyManagement` (Partie 01, propriétaire
> de la vraie logique AU). Il ne redécide rien, il rejoue la chaîne sortie.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Modèle physique simulé
4. ⚠️ Piège opérateur — latches AU non liés à la simulation
5. Documents liés

## 🧪 Points de validation (`TC-P13-020...` — propriétaire unique)

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
      <th style="padding: 4px 1px; text-align: center;"><small>Etat</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-020</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SimChainOk := PowerCutOff_A AND PowerCutOff_B AND NOT BtnEmergencyStop</code> — un seul canal FALSE ouvre la boucle</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-021</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SimContactorOk</code> s'auto-maintient (latch) sur <code>EmergencyArming</code>, retombe immédiatement si <code>SimChainOk</code> repasse FALSE</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-022</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Enable=FALSE</code> neutralise tout (<code>SimChainOk</code>/<code>SimContactorOk</code>/<code>ContactorLatch</code> à FALSE)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-023</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">🆕 Un défaut AU réel latché (<code>RedundancyTestFailedCause</code>/<code>EmergencyArmingFailedCause</code> dans <code>FB_Safety_EmergencyManagementLogic</code>) <b>survit</b> à un cycle Reset/Restart de ce modèle simulé — voir §4</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>👁️ MANUEL</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

🧩 Brique réduite (`AF_Partie-03 §2`) : pas de contrat `Enable/Reset/Error` complet côté diagnostic —
juste un modèle physique fail-safe minimal du canal AU + contacteur, pour donner à
`FB_Safety_EmergencyManagement` (Partie 01) des entrées `EmergencyChainClosed_DI`/
`PowerContactorEngaged_DI` plausibles quand aucun matériel n'est branché.

Instance : `FB_SimBench.instSimSafety`, appelée uniquement si `FB_SimBench.Enable=TRUE`
(`GVL_Simulation.SimulationModeActive`). L'aiguillage réel/simulé de sa sortie vers `HwIn.Machine`
se fait **en amont**, dans `PRG_02_Acquisition.st` (`SEL` sur `SimulationModeActive AND
SimSafetyActive`) — ce FB ne sait pas lui-même s'il est réellement consommé.

⚠️ `Enable` est câblé en dur à `TRUE` dans `FB_SimBench.st` (contredit le commentaire d'en-tête de
`FB_Sim_Safety.st` qui documente `Enable = SimulationModeActive AND NOT
SensorEmergencyStopChainIsReal`) — sans conséquence observée à ce jour car l'aiguillage réel se
fait déjà correctement en amont via `HwIn.Machine`, mais incohérence documentaire à corriger un
jour (`T110`-adjacent, non prioritaire).

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Active la simulation |
| `PowerCutOff_A` | BOOL | Commande maintien canal A — **TRUE = OK/fermé** (miroir `PowerKeepAlive_A`, `FB_Safety_EmergencyManagement` scan N-1) |
| `PowerCutOff_B` | BOOL | Idem canal B |
| `EmergencyArming` | BOOL | Impulsion réarmement (`EmergencyArming_RQ`, OR avec `ArmingSeqStep=5` côté appelant pour sécuriser le transfert malgré le décalage scan) |
| `BtnEmergencyStop` | BOOL | Force l'ouverture de la boucle (TRUE = bouton IHM appuyé, `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff`) |

| Sortie | Type | Sens |
|---|---|---|
| `SimChainOk` | BOOL | Boucle AU simulée saine — alimente `Machine.EmergencyChainClosed_DI` |
| `SimContactorOk` | BOOL | Contacteur simulé engagé — alimente `Machine.PowerContactorEngaged_DI` |

---

## 3. Modèle physique simulé

```text
SimChainOk := PowerCutOff_A AND PowerCutOff_B AND NOT BtnEmergencyStop

IF NOT SimChainOk THEN
    ContactorLatch := FALSE
ELSIF EmergencyArming THEN
    ContactorLatch := TRUE
END_IF
SimContactorOk := ContactorLatch
```

Deux canaux redondants (A/B) : couper l'un ou l'autre ouvre la boucle — reproduit le test
croisé Méca A/B de `FB_Safety_EmergencyManagement` (Partie 01 §3.3bis) sans matériel. Le
contacteur simulé retombe **immédiatement** dès que la chaîne s'ouvre, priorité à la coupure sur
le maintien (comme une bobine réelle qui décolle sans alimentation).

---

## 4. ⚠️ Piège opérateur — latches AU non liés à la simulation

> 🚨 REX 2026-08-14 (troubleshooting AU full simu, plusieurs heures de diagnostic) : un bug de
> simulation (`FB_SimBench` §M3, voir `FB_SimBench_v1.0.md`) provoquait un faux `PowerCutOff`
> répété, qui a fini par faire échouer un test de redondance et **latcher**
> `RedundancyTestFailedCause` dans `FB_Safety_EmergencyManagementLogic` (Partie 01). Une fois le
> bug de simulation corrigé, l'armement restait **quand même** bloqué : le latch avait survécu,
> et sa condition de déblocage (`ArmReqEdge.Q AND EmergencyChainClosed=TRUE...`) ne peut jamais
> se réévaluer tant que la chaîne reste fermée par le latch lui-même — cercle vicieux
> auto-entretenu.

**Fait clé** : ce modèle simulé (`FB_Sim_Safety`) et ses stimuli (`GVL_Simulation.*`) sont
**indépendants** de l'état interne de `FB_Safety_EmergencyManagementLogic`
(`RedundancyTestFailedCause`, `EmergencyArmingFailedCause`, `StartupFail`). Ni le front descendant
de `SimulationModeActive` (Partie 13 §3 — ne remet à nominal que les *stimuli*), ni une correction
de bug côté simulation, ne réinitialisent ces latches.

**Seul déblocage possible** : un front `Reset` (`BtnFaultReset`) — le seul mécanisme qui efface
`Cause` sans condition (pattern Cause/Ack, `CODE_QUALITY_STANDARDS.md §9`).

**Règle opérateur à suivre systématiquement** : après tout échec d'armement en simulation (chaîne
qui ne réarme plus, `Step5_ArmingAllowed` qui reste FALSE), presser **Reset avant** de rejouer
l'essai — même si la cause suspectée est un bug de simulation déjà identifié. Ne jamais conclure
« la simulation est cassée » sans avoir d'abord vérifié `GVL_Troubleshooting.Safety.RedundancyTestFailed`
et `.ArmingFailed`.

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation, doctrine, garde-fous |
| AF01 / FB_Safety_EmergencyManagement | Consommateur réel de `SimChainOk`/`SimContactorOk` (via `HwIn.Machine`), propriétaire des latches `Cause`/`Ack` |
| AF13 / FB_SimBench | Câblage des entrées (`PowerCutOff_A/B`, `BtnEmergencyStop`, décalage 1 scan) |
| `CODE_QUALITY_STANDARDS.md §9` | Pattern Cause/Ack, Reset inconditionnel |
| Code | `CODE/L_SIMULATION/FB_Sim_Safety.st`, `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagementLogic.st` |
