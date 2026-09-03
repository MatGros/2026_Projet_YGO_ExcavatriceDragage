# ⚖️ DÉCISION DE CONCEPTION T146 — Arbitrage vitesse/position hors homing (ISO 13849)

> **Criticité : C4 — SÉCURITÉ machine réelle.** Cadre normatif : **ISO 13849-1/-2**
> (parties de commande relatives à la sécurité, PL) · **Directive Machine 2006/42/CE**
> (annexe I, §1.2.1 sécurité et fiabilité des systèmes de commande, §1.3.9 mouvements
> non commandés).
> Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T146.yaml` — critère **AC1**.
> Plan : `DOC/WFLOW/AUDITS/DESIGN/PLAN_T146homing_arbitrage_interlocks.md` (phase P0).
> Date rédaction : 2026-09-03 · Branche : `backup/mes-septembre-20260902`.

---

## 1 · 📍 Contexte — l'écart constaté

Tant que les codeurs M1 (retenue) **et** M2 (benne) ne sont pas `HomedAndReliable` :

- `CablePosM` est **potentiellement faux** (aucun référentiel fiable — cf. AF-09 §5).
- **Toutes les protections logicielles de position sont inertes** : fin de course haute
  logicielle (`CablePosM >= TopLimitM`), limite câble basse, limite légale de profondeur,
  ralentissements de bordure — toutes calculées sur une position non fiable.
- **Aucun bridage de vitesse n'était appliqué** : hors homing, le treuil pouvait monter
  **et** descendre jusqu'au **palier 5** (vitesse maximale).
- Seul reste actif le **capteur physique de fin de course haut** (TOP) — protection
  matérielle unique, non redondée par le logiciel dans cet état.

➡️ Situation non conforme à l'esprit ISO 13849 : un mouvement à pleine vitesse est
autorisé alors que la chaîne de commande **sait** qu'elle ne peut pas surveiller la
position. Mouvement potentiellement non maîtrisé au sens Directive Machine §1.3.9.

---

## 2 · 🔀 Les deux postures possibles

| # | Posture | Principe | Avantages | Inconvénients / dette |
|---|---|---|---|---|
| **A** | **Bridage logiciel — plafond palier = 1 hors homing** | Codeurs non `HomedAndReliable` (M1 **ET** M2) ⇒ plafond de palier de vitesse forcé à **1** (montée **et** descente) sur les deux treuils. Mouvement lent, maîtrisable à vue par l'opérateur. | Fail-safe immédiat, aucune hypothèse mécanique. Indépendant de l'état réel des capteurs. Réversible : plafond retombe dès `HomedAndReliable`. | Ergonomie dégradée pendant le référencement (montée lente au capteur). Ne protège pas *en soi* contre un dépassement de course — il réduit l'énergie et le temps de réaction. |
| **B** | **Repos capteur physique TOP haut assumé & documenté** | On assume que, hors homing, la machine est (ou doit être amenée) **au repos sur le capteur TOP haut**, seule référence physique fiable ; on documente cette exigence procédurale et on laisse la vitesse libre. | Aucune perte d'ergonomie. | Repose sur une **hypothèse de position** non vérifiée par le logiciel. Si l'opérateur n'est pas au TOP (datum perdu en exploitation, benne chargée au fond), la machine est à pleine vitesse sans aucune protection position. Contraire au principe de tolérance aux fautes ISO 13849. |

---

## 3 · ✅ Posture RETENUE

**POSTURE A — bridage logiciel plafond palier = 1 hors homing.**

- **Statut : IMPLÉMENTÉE** (interim fail-safe) sur `backup/mes-septembre-20260902` :
  `CODE/M_MAIN/PRG_04_Treuils_Benne.st` §5ter — codeurs non `HomedAndReliable`
  (M1 **ET** M2) ⇒ plafond palier de vitesse = **1**, montée **ET** descente, sur
  les deux treuils.
- **Motivation** : posture **interim fail-safe**. Elle ne fait aucune hypothèse sur
  la position mécanique réelle et se lève automatiquement dès que la position
  redevient fiable. C'est la seule des deux qui reste sûre quand l'hypothèse « au
  repos sur le TOP » est fausse.
- **Distinct de** : le non-bypass de `SyncDeviationWarn` tant que M1/M2 ne sont pas
  `HomedAndReliable` + état benne committé (AF-10 §5.2, note T184). Ce sont deux
  clauses indépendantes : l'une clampe le palier faute de position, l'autre interdit
  de lever la surveillance d'écart synchro faute d'offset benne qualifié.

### `decision:`

> **Le bridage hors homing est réalisé par un plafond de palier de vitesse forcé à 1
> (montée et descente, M1 et M2) tant que les codeurs M1 ET M2 ne sont pas
> `HomedAndReliable`. Posture interim fail-safe. Aucun repos capteur physique n'est
> assumé. Le plafond retombe automatiquement dès que M1 ET M2 sont
> `HomedAndReliable`.**
>
> Ce bridage-ci n'est **pas** fondé sur la vitesse *mesurée* : il ne dépend donc pas
> du garde-fou vitesse (`SpeedGuardEnable` / `FB_WinchRateInterlock` / table
> `SpeedBandMaxMps`), qui reste `FALSE` / dette S5 datée (contrat AC2/AC5). Tout
> bridage **futur** fondé sur la vitesse mesurée reste conditionné à ce garde-fou.

---

## 4 · 🔓 Règle de débridage — À IMPLÉMENTER

**Énoncé cible** : « **capteur haut (TOP) actif ⇒ position connue ⇒ levée du plafond
de palier hors homing** ».

- Intention : quand le capteur physique TOP haut est actif, la position est
  physiquement connue (machine en butée haute référencée) ⇒ le plafond de palier
  peut être levé même si `HomedAndReliable` n'est pas encore acquis.
- **Statut : À IMPLÉMENTER / À VALIDER.** Points à trancher avant code :
  - polarité et anti-rebond du signal TOP retenu (`TopPositionSensor` / `TopPositionActive`) ;
  - sens autorisés une fois le plafond levé (descente depuis le TOP = sortie du datum → à border) ;
  - articulation avec le GRAFCET homing (`FB_MachineHomingCycle`, HX2/HX2N) qui utilise
    déjà le TOP comme repère ;
  - **non-régression AC6** : la levée du plafond ne doit **jamais** assouplir l'interlock
    hauteur M3 strict (`M3_HeightInterlockOk` exige `HomedAndReliable` M1∧M2,
    `PRG_05_Translation`).
- En posture A pure (sans cette règle), le plafond de palier 1 tombe **uniquement**
  sur `HomedAndReliable = TRUE`.

---

## 5 · 📎 Volets liés (hors périmètre de cette décision, tracés)

| Volet | Statut |
|---|---|
| Interlock `TremieFull_OR_GateRaised_DI` consommé dans le permis M3→Trémie (AC3) | ⬜ à implémenter |
| Garde-fou vitesse `SpeedGuardEnable` / `FB_WinchRateInterlock` / table `SpeedBandMaxMps` (AC2/AC5) | ⬜ `FALSE` / dette S5 à dater et maintenir |
| Interlock hauteur M3 strict `HomedAndReliable` M1∧M2 (AC6) | ✅ conforme, **ne pas assouplir** |

---

## 6 · ⛔ VISA DE VALIDATION HUMAINE

**⛔ ARRÊT VALIDATION HUMAINE C4 — à contresigner par l'humain.**

Aucun agent n'attribue le statut `human-validated` ni n'équivaut le visa humain
ISO 13849 (`SAFETY_POLICY.md` : advisory-only tant qu'un automaticien n'a pas validé
explicitement). Le code du plafond palier hors homing est **implémenté en interim**
mais **non contresigné** : la posture A, la règle de débridage TOP et le périmètre
des fichiers CODE restent à valider par l'automaticien responsable.

```yaml
decision: >
  Bridage hors homing = plafond de palier de vitesse forcé à 1 (montée ET descente,
  M1 ET M2) tant que les codeurs M1 ET M2 ne sont pas HomedAndReliable. Posture
  interim fail-safe. Aucun repos capteur physique assumé. Plafond levé automatiquement
  sur HomedAndReliable ; règle de débridage "capteur TOP haut actif => position connue
  => levée du plafond" définie mais À IMPLÉMENTER/VALIDER. Bridage fondé sur la vitesse
  mesurée reste conditionné au garde-fou vitesse (SpeedGuardEnable=FALSE / dette S5).
validated_by: ""   # ⛔ ARRÊT VALIDATION HUMAINE C4 — à contresigner par l'humain
validated_at: ""
```
