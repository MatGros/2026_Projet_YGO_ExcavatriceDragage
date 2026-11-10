# CADRAGE T181-11 — Matrice de maintenance N1/N2 (bypass, override FDC, re-homing)

> **Statut : proposé — ARRÊT VALIDATION HUMAINE.** Aucune écriture `CODE/`.
> Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-11_MATRICE_MAINT_N1_N2.yaml` (AC1-AC8).
> Alimente une section de `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md` (§4bis ci-dessous) + l'implémentation T181-14.
> Date : 2026-08-29. **Vérifié contre le code** (`FB_Safety_Winch.st`, `PRG_04_Treuils_Benne.st`, `FB_Modes.st`, DUT `ST_Bypass*`) le 2026-08-29.

---

## 0 · Constat de départ

**La doctrine existe déjà — le code ne l'applique pas.**

| Source | Ce qui est écrit | Réalité du code |
|---|---|---|
| `E_Mode.st` | `MAINT_N1` = *« pilotage unitaire avec **toutes sécurités actives** »* · `MAINT_N2` = *« pilotage dégradé (droits étendus + **bypasses autorisés**) »* | `PRG_04:601-627` passe `GVL_IHM.M1TreuilRetenue.Bypass.*` / `.Commun.Bypass.*` **bruts** à `FB_Safety_Winch`, **sans aucun filtre de mode** |
| `ST_BypassWinch.st` cartouche | *« Doctrine : actionnable **UNIQUEMENT en MAINT_N2**, RETAIN, jamais ne masque les autres défauts du même bloc »* | Aucune vérification `Mode = MAINT_N2` avant application |
| `ST_BypassBucket.st` / `ST_BypassCommun.st` | idem | idem |

⇒ **D15 = faire respecter par le code la doctrine déjà spécifiée**, + traiter les 2 cas non couverts : l'override FDC momentané N1 (décision Q8) et le re-homing.

---

## 1 · Inventaire exhaustif des bypass — périmètre treuil

### 1.1 Par axe — `ST_BypassWinch` (M1 = `GVL_IHM.M1TreuilRetenue.Bypass`, M2 = `GVL_IHM.M2TreuilBenne.Bypass`) — RETAIN

| # | Bypass | Entrée `FB_Safety_Winch` | Ce qu'il lève | Usage code (fichier:ligne) |
|---|---|---|---|---|
| 1 | `OperatorComm` | `BypassOperatorComm` | Perte com CANopen joystick / heartbeat IHM | `FB_Safety_Winch.st:174` |
| 2 | `EncoderFault` | `EncoderFaultBypass` | Défaut esclave EtherCAT codeur absolu | `:183` |
| 3 | `ContactorFeedback` | *(déclaré DUT, **non câblé** dans `PRG_04`)* | Feedbacks contacteurs puissance + frein | ⚠️ **gap de câblage** — voir §7-a |
| 4 | `PhaseRotation` | `BypassPhaseRotation` | Défaut rotation de phases (commun machine) | `:208` |
| 5 | `BrakeThermal` | `BypassBrakeThermal` | Surchauffe thermique frein | `:271` |
| 6 | `MotorThermal` | `BypassMotorThermal` | Surchauffe thermique moteur de CE treuil | `:191` |
| 7 | `TopLimitSwitch` | `BypassTopLimitSwitch` (OR `Commun`) | **FDC haut physique** (capteur `TopPositionSensor` ≈ 8,5 m) | `:216, :383` |
| 8 | `TopLimitSoftware` | `BypassTopLimitSoftware` (OR `Commun`) | **FDC haut logiciel** (`CablePosM >= TopLimitM` ≈ 7,5 m) | `:384` |
| 9 | `CableLimitSwitch` | `BypassCableLimitSwitch` (OR `Commun`) | Limite basse physique (longueur câble max) | `:225, :374-375` |
| 10 | `LimitLegal` | `BypassLimitLegal` (OR `Commun`) | Limite légale de profondeur | `:376` |
| 11 | `MecaA` | `BypassMecaA` | Méca A : mouvement non commandé à l'arrêt (DriftGuard dérive statique) | `:235` |
| 12 | `MecaB` | `BypassMecaB` | Méca B : absence de confirmation d'arrêt (frein/contacteurs), coast-down 3 s, ContactorStuck | `:246` |
| 13 | `MecaC` | `BypassMecaC` | Méca C : glissement de charge pendant maintien benne | `:260` |
| 14 | `MecaD` | `BypassMecaD` | Méca D : arrivée butée haute anormale | `:279-280` |
| 15 | `MecaE` | `BypassMecaE` | Méca E : désynchronisation critique des treuils | `:291, :300` |
| 16 | `Safety` | `BypassSafety` | **Groupé** : tous les bits provoquant un `PowerCutOff` | `:191, :235, :246, :260, :271, :279, :300` |
| 17 | `Process` | `BypassProcess` | **Groupé** : tous les bits provoquant un `SafeStop`/perte de permis | `:174, :183, :199, :208, :216, :225, :291, :309, :320, :376-377` |
| 18 | `Global` | `BypassGlobal` | **Groupé** : ignore **toutes** les sécurités de cet axe (force `ErrorId = 0`) | `:139, :170, :377` |
| — | `Initialized` | — | Flag RETAIN de restauration boot (pas un bypass) | — |

### 1.2 Communs — `ST_BypassCommun` (`GVL_IHM.Commun.Bypass`, capteur physique unique M1/M2) — RETAIN

| # | Bypass | Application |
|---|---|---|
| 19 | `Global` | Toutes sécurités communes M1 + M2 |
| 20 | `SlackCable` | Capteur mou de câble (unique M1/M2) — OR avec bypass individuel |
| 21 | `TopLimitSwitch` | OR sur les 2 treuils (pilotage « both ») |
| 22 | `TopLimitSoftware` | OR sur les 2 treuils |
| 23 | `CableLimitSwitch` | OR sur les 2 treuils |
| 24 | `LimitLegal` | OR sur les 2 treuils |

### 1.3 Benne — `ST_BypassBucket` (`GVL_IHM.M2TreuilBenne.Bucket.Bypass`) — RETAIN

| # | Bypass | Application |
|---|---|---|
| 25 | `Global` | Ignore toute la surveillance du mécanisme benne (M2) |

**Total : 25 bascules** (18 axe + 6 commun + 1 benne). Toutes RETAIN, toutes issues d'un toggle IHM brut, **aucune filtrée par mode aujourd'hui**.

---

## 2 · Matrice cible « mode × bypass »

**Règle générale (doctrine existante, à faire appliquer)** :
`bypass_effectif := bypass_IHM AND (Mode = MAINT_N2)` — pour **tous** les granulaires.
Un bypass IHM activé alors que `Mode ≠ MAINT_N2` est **ignoré** (pas d'erreur ; l'IHM le grise / l'affiche « inactif — passer en N2 »).

| Bypass | N1 | N2 | DISABLE / SEMI_AUTO | Latence | Décision |
|---|---|---|---|---|---|
| `OperatorComm`, `EncoderFault`, `ContactorFeedback`, `PhaseRotation`, `BrakeThermal`, `MotorThermal` | ❌ | ✅ latché | ❌ | N2 latché (RETAIN) | doctrine standard |
| `MecaA`, `MecaC`, `MecaD`, `MecaE` | ❌ | ✅ latché | ❌ | N2 latché | doctrine standard |
| `MecaB` | ❌ | ✅ **latché, avec avertissement fort** | ❌ | N2 latché | Méca B = confirmation d'arrêt + coast-down + ContactorStuck. Bypass = plus aucune détection qu'un treuil ne s'arrête pas. **Décision : autorisé en N2** (homogène, traçabilité RETAIN + journal) — bandeau d'avertissement fort. |
| `TopLimitSwitch` (capteur physique 8,5 m) | ❌ | ✅ latché | ❌ | N2 latché | dépasser le capteur physique = uniquement N2, acte assumé |
| **`TopLimitSoftware`** (logiciel 7,5 m) | ⚠️ **momentané** (bouton maintenu) | ✅ latché | ❌ | **N1 = tant que bouton tenu** ; N2 = latché | **décision Q8** — voir §3 |
| `CableLimitSwitch` (limite câble physique) | ❌ | ✅ latché | ❌ | N2 latché | limite basse = intégrité câble |
| `LimitLegal` (limite légale) | ❌ | ✅ latché | ❌ | N2 latché | **Décision : bypassable en N2** (homogène) — la traçabilité de l'action reste assurée par le RETAIN + le journal de bypass. |
| `SlackCable` (commun) | ❌ | ✅ latché | ❌ | N2 latché | doctrine standard |
| `Safety` (groupé) | ❌ | ✅ latché | ❌ | N2 latché | **conservé** — homogénéité projet (idem translation M3) |
| `Process` (groupé) | ❌ | ✅ latché | ❌ | N2 latché | **conservé** — homogénéité projet |
| `Global` axe (18) + `Global` commun (19) + `Global` benne (25) | ❌ | ✅ latché | ❌ | N2 latché | **conservé** — homogénéité projet ; effectif uniquement en MAINT_N2 (mode-gating) |

### Décision utilisateur : structure de bypass **inchangée / homogène projet**
- On garde la **hiérarchie existante** : groupés `Global` / `Process` / `Safety` **+** granulaire `MecaA..E`, limites, thermiques — identique à la translation M3.
- **Rien n'est retiré des DUT** `ST_BypassWinch` / `ST_BypassCommun` / `ST_BypassBucket` → **aucun impact IHM/SCADA**.
- **Seul changement T181-14** : `bypass_effectif := bypass_IHM AND (Mode = MAINT_N2)` pour **tous** (mode-gating de la doctrine déjà écrite mais non appliquée) + l'override FDC N1 momentané (§3) + le re-homing (§5).
- `MecaB`, `LimitLegal` : bypassables en N2 comme le reste (homogène). La traçabilité de l'action reste assurée par le RETAIN + le journal de bypass existant.

---

## 3 · Override FDC haut logiciel — décision Q8

**Rappel Q8** : *« capteur homing top toujours supérieur à FDC haut logiciel — actuellement 8,5 m / 7,5 m ; en fonctionnement normal on s'arrête à 7,5 m »* + *« en niveau [N1] il peut dépasser les fins de course logicielle si sur l'IHM il reste appuyé sur un bouton pour autoriser »*.

### 3.1 Comportement cible

| Contexte | `DriveRequest.TopLimitM` (calculé `PRG_04`) | Butée physique |
|---|---|---|
| Fonctionnement normal (SEMI_AUTO, N1 sans override, N2 sans override) | **7,5 m** (`_CommunCfgPersist.CfgCableLimitAscent_M`) | capteur `TopPositionSensor` ≈ 8,5 m (jamais atteint en nominal) |
| **N1 + bouton IHM « autoriser dépassement FDC » MAINTENU** | **8,5 m** (borne physique = valeur du capteur homing haut) | capteur `TopPositionSensor` — **jamais dépassé** (`BypassTopLimitSwitch` reste FALSE) |
| **N2 + bypass `TopLimitSoftware` latché** | 8,5 m | capteur `TopPositionSensor` (sauf si `TopLimitSwitch` aussi bypassé — acte N2 séparé) |

- **N1 momentané** : `OverrideTopSoftwareN1 := (Mode = MAINT_N1) AND GVL_IHM.<axe>.Cmd.BtnOverrideTopSoftware` (bouton, pas toggle). Relâche → `TopLimitM` **repasse à 7,5 m au cycle suivant**, le FDC logiciel redevient actif immédiatement.
- **La butée physique 8,5 m n'est jamais franchie en N1** : `BypassTopLimitSwitch` n'est **pas** ouvert par cet override. Si le capteur `TopPositionSensor` retombe (position atteinte), `AscentPermit` tombe (`FB_Safety_Winch.st:382-383`) → arrêt matériel.
- **N2 latché** : `TopLimitSoftware` classique (§2), RETAIN, débit assumé jusqu'à sortie de N2.

### 3.2 Nouveau champ / bouton IHM
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware : BOOL` (+ M2) — **bouton momentané** (préfixe `Btn`, NC-060). Pas dans `ST_BypassWinch` (ce n'est pas un bypass latché).
- `PRG_04` : `M1_TopLimitM := SEL(OverrideTopSoftwareN1 OR (BypassTopLimitSoftwareEff), CfgCableLimitAscent_M, CfgHomingSensorTop_M)` avec `CfgHomingSensorTop_M ≈ 8.5` (nouvelle constante persistante ou dérivée).

---

## 4 · Règle de bascule de mode

**Passage en / hors `MAINT_N1` ou `MAINT_N2` refusé tant que le treuil n'est pas à l'arrêt mécanique confirmé** — même composite que l'armement Méca B (`FB_Safety_Winch.st:247`) :

```
BasculeModeAutorisee := ContactorsAllOff AND NOT BrakeFeedback
                        (* = FwdRevSpeedFeedbackOff AND NOT BrakeIsOpen : contacteurs retombés + frein serré *)
                        AND (ABS(MeasuredSpeedMps) < MovementSpeedThresholdMps)   (* redondance mesure *)
```

- Tant que faux : `FB_Modes` maintient le mode courant, remonte `ModeChangePendingBlocked` à l'IHM (« arrêter le treuil avant de changer de mode »).
- S'applique aux **deux sens** (entrer et sortir de N1/N2).
- Décision et calcul dans **`FB_Modes`** (arbitrage de mode), pas dans `PRG_04`.

---

## 5 · Re-homing obligatoire

Après **toute** sortie d'un mode maintenance qui a **effectivement** utilisé :
- l'override FDC N1 momentané (`OverrideTopSoftwareN1` a été vrai au moins un cycle), **ou**
- un bypass de la famille position (`TopLimitSwitch`, `TopLimitSoftware`, `CableLimitSwitch`, `LimitLegal`, `MecaD`) latché en N2,

→ le treuil concerné est marqué `HomingRequired := TRUE` (drapeau persistant par axe).
- Tant que `HomingRequired` : SEMI_AUTO **interdit** pour cet axe (`FB_Modes` bloque l'arbitrage), N1 autorisé pour manœuvrer, `HomingSuspect` forcé côté diag.
- `HomingRequired` retombe uniquement sur **cycle de homing complet réussi** (`EncoderMx.HomingLifecycle.Done` + `Homed AND NOT HomingSuspect`).
- Raison : un dépassement des limites de position invalide la confiance dans la position calculée `CablePosM` — la re-référence est la seule remise à zéro sûre.

---

## 6 · Alignement T175 AC4 (confirm / ouvre benne en maintenance)

T175 AC4 : *« FB_Bucket confirme/ouvre sous MAINT_N1 ET N2 comme décrit (TC-P10-030), ou la fiche est corrigée MAINT_N2 seul — décision tracée »*.

**Proposition** : **MAINT_N1 ET MAINT_N2**.
- Rationale : ouvrir/fermer la benne est une **manœuvre de service courante** (dégagement, entretien du grappin) qui ne nécessite aucun bypass de sécurité — elle doit rester possible avec toutes sécurités actives (N1).
- N2 ajoute seulement la possibilité de la faire **avec** des bypass position/méca actifs (ex. benne bloquée en butée).
- ⇒ `FB_Bucket.ConfirmOpen` / `ConfirmClose` gatés sur `Mode IN {MAINT_N1, MAINT_N2}` (pas N2 seul). À implémenter en **T181-14** ; le TC-P10-030 est réécrit en conséquence.

---

## 7 · Gaps de câblage relevés en passant (devoir d'alerte)

- **7-a** — `ST_BypassWinch.ContactorFeedback` est **câblé**, mais vers `FB_Winch` (via `BypassContactorCheck`, `PRG_04:687,723`), **pas** vers `FB_Safety_Winch`. Il lève le timeout de retombée des contacteurs (`ContactorFeedbackTimeout`, `FB_Winch.st:293`). Ce n'est **pas** un bypass mort : il est **vivant** sur `FB_Winch` et doit figurer dans la matrice (N2 latché). Le `ContactorStuck` (propriétaire `FB_Safety_Winch`, D07) n'a, lui, **pas** de bypass dédié — couvert par `BypassSafety`/`BypassGlobal`.
- **7-b** — `GVL_IHM.Commun.Bypass.SlackCable` (n° 20) : **confirmé non consommé** comme bypass de sécurité. Il est **miré** vers le RETAIN `BypassSlackCable` (`PRG_07:241-242,259`) mais **aucun** `Bypass*` de `FB_Safety_Winch` ne le lit : le mou de câble (`SlackCableDetected`, cause 3) n'a que `BypassProcess` comme échappatoire. Le bypass commun `SlackCable` est donc **effectivement mort** (déclaré + miré, jamais appliqué).
- **7-c** — Le mou de câble (`SlackCableDetected`, `FB_Safety_Winch.st:199`) n'a **que** `BypassProcess` comme échappatoire (pas de bypass dédié individuel). `Process` groupé étant **conservé** (§2), le mou de câble reste bypassable en N2 via `Process` — mais le bypass commun `SlackCable` (7-b) étant mort, il n'y a **pas** de bypass granulaire dédié. À trancher en T181-14 : ajouter un `BypassSlackCable` individuel dans `ST_BypassWinch`, ou confirmer que le bypass granulaire n'est pas requis (le groupé `Process` suffit).

---

## 8 · Section pour `AF_Partie-05_Modes_Maintenance` (insérée en §4bis par T181-11)

### 4bis · Matrice de bypass maintenance — treuils M1/M2

**Principe** — Un bypass de sécurité n'est **effectif que si `Mode = MAINT_N2`** (doctrine `ST_BypassWinch` / `ST_BypassCommun` / `ST_BypassBucket`). Un bypass IHM activé hors N2 est ignoré (affiché « inactif »). Exception unique : l'**override FDC haut logiciel** est possible en `MAINT_N1` via un **bouton maintenu** (momentané), borné par le capteur physique haut (≈ 8,5 m), jamais franchi.

| Famille | Bypass | N1 | N2 | Latence |
|---|---|---|---|---|
| Communication & aux. | `OperatorComm`, `EncoderFault`, `PhaseRotation`, `BrakeThermal`, `MotorThermal`, `ContactorFeedback` | ❌ | ✅ | latché (RETAIN) |
| Limites position | `TopLimitSwitch`, `CableLimitSwitch`, `LimitLegal`, `SlackCable` | ❌ | ✅ | latché |
| Limites position | `TopLimitSoftware` | ⚠️ momentané (bouton tenu) | ✅ | N1 : tant que tenu · N2 : latché |
| Méca A-E | `MecaA`, `MecaC`, `MecaD`, `MecaE` | ❌ | ✅ | latché |
| Méca A-E | `MecaB` | ❌ | ✅ | latché + bandeau d'avertissement fort |
| Groupés | `Safety`, `Process`, `Global` (axe / commun / benne) | ❌ | ✅ | latché (RETAIN) — **conservés** (homogène projet, idem translation M3) |

**Bascule de mode** — entrer/sortir de N1/N2 refusé tant que : `contacteurs retombés ET frein serré ET |vitesse| < seuil`. Sinon `FB_Modes` maintient le mode courant + remonte « arrêter le treuil avant changement de mode ».

**Re-homing** — après usage effectif de l'override FDC N1 **ou** d'un bypass position latché N2 : `HomingRequired` par axe → SEMI_AUTO interdit pour cet axe jusqu'à cycle de homing complet réussi.

**Confirm/ouvre benne** — autorisé en `MAINT_N1` **et** `MAINT_N2` (manœuvre de service sans bypass requis). TC-P10-030 aligné.

---

## 9 · Livrables aval (T181-14, sur validation de ce cadrage)

- `FB_Modes` : calcul `BasculeModeAutorisee`, drapeau `HomingRequired` par axe, gate SEMI_AUTO.
- `PRG_04` : `bypass_effectif := bypass_IHM AND (Mode = MAINT_N2)` pour les 25 bascules ; `TopLimitM` (7,5 / 8,5) ; **aucun retrait** des groupés `Safety`/`Process`/`Global` (conservés, homogène projet — décision §2-3).
- DUT : **aucun retrait** de `ST_BypassWinch`/`ST_BypassCommun`/`ST_BypassBucket` (les 25 bascules restent, mode-gated) ; ajout `BtnOverrideTopSoftware` dans `ST_WinchHMI.Cmd` ; éventuel `BypassSlackCable` (§7-c).
- `FB_Bucket` : gate confirm/ouvre sur `Mode IN {MAINT_N1, MAINT_N2}`.
- Gate : `G4xx_check_bypass_matrix_mode_gated.py` — aucun `Bypass*` propagé sans `AND (Mode = MAINT_N2)` (sauf l'override FDC N1 explicitement listé).
- Migration variables IHM : `IHM_VARIABLES_MIGRATION.md` mis à jour pour les champs retirés/ajoutés.
