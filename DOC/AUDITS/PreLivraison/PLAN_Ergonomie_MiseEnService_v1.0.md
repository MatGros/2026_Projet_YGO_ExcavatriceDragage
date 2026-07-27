# 🩺 PLAN — Ergonomie de mise en service & remontée d'informations (v1.0)

> 🎯 **Rôle** : rendre la machine **diagnosticable** par un technicien devant l'IHM, sans lecture de
> code ni décodage manuel de bitfields. Cible : livraison client + interventions futures.
> 📅 2026-07-26 · **Aucune modification code réalisée** — document de préparation.
> 🔗 [PLAN_Rationalisation_Simulation_v1.0](PLAN_Rationalisation_Simulation_v1.0.md) ·
> [PLAN_Allegement_Code_v1.0](PLAN_Allegement_Code_v1.0.md) ·
> Sources terrain : [REGISTRE_Suivi_MiseEnService_v1.0](../../REGISTRE_Suivi_MiseEnService_v1.0.md) · [PLAN_TASK §3](../../PLAN_TASK_v1.0.md)

---

## 1. 🔎 Ce qui manque aujourd'hui — vu depuis le terrain

| Question du technicien | Réponse disponible aujourd'hui | Verdict |
|---|---|---|
| « **Pourquoi ça ne bouge pas ?** » | Décoder à la main 8 blocs : `Modes`, `Safety_Winch`, `Winch`, `Homing`, `Sync`, `Bucket`, `Joystick`, `Cycle` | ❌ le trou n°1 |
| « **Qu'est-ce qui a coupé en premier ?** » | `AnyFaultActive` = OR géant + N `ErrorId` bitfields concurrents | ❌ impossible à trancher |
| « **Ce défaut veut dire quoi ?** » | Bit dans un `WORD`, libellé seulement dans le code ST | ❌ nécessite le source |
| « **Est-ce déréglé ou cassé ?** » | Aucune mesure conservée (distance d'arrêt, temps frein, écart max) | ❌ MES-006/008/009 bloqués |
| « **Quels bypass sont actifs ?** » | 1 bit par bypass, dispersés dans 6 structs, **RETAIN** | 🟠 dangereux à la livraison |
| « **Le câblage est-il dans le bon sens ?** » | Rien — découvert par accident (C1 polarité frein) | ❌ |

👉 Le programme **sait** tout cela. Il ne le **dit** pas. Tout ce plan consiste à publier de
l'information déjà calculée, pas à ajouter de la logique métier.

---

## 2. 🥇 A — `FB_MotionInhibit` : « pourquoi ça ne bouge pas »

**Le livrable à plus fort impact.** Un bloc par axe (M1, M2, M3) qui renvoie **la cause bloquante
prioritaire**, dans l'ordre où le programme l'applique.

```
FB_MotionInhibit          // 🧱 brique réduite (Partie 3 §1bis) — diagnostic pur, aucune commande
VAR_INPUT   : tous les gates déjà calculés (lecture seule)
VAR_OUTPUT
    MotionAllowed    : BOOL;            // ✅ rien ne bloque
    InhibitReason    : E_InhibitReason; // 🥇 cause prioritaire
    InhibitReasonUp  : E_InhibitReason; // ⬆️ cause bloquant la MONTÉE seule
    InhibitReasonDown: E_InhibitReason; // ⬇️ cause bloquant la DESCENTE seule
```

`E_InhibitReason` (ordre = priorité d'évaluation) :

```
NONE · EMERGENCY_STOP · POWER_CUTOFF · MODE_DISABLE · AXIS_INHIBITED · FB_ERROR ·
SAFE_STOP · BUS_FAULT · HEARTBEAT_LOST · NOT_HOMED · DEADMAN_NOT_ARMED · JOYSTICK_NEUTRAL ·
FORBID_ASCENT · FORBID_DESCENT · LIMIT_TOP · LIMIT_CABLE · LIMIT_LEGAL · SYNC_DEVIATION ·
BUCKET_BUSY · CYCLE_HOLD · SENSOR_INCOHERENT · SPEED_STEP_ZERO
```

🎯 **Séparer montée/descente est essentiel** : la moitié des blocages terrain sont directionnels
(mou de câble → descente interdite, capteur haut → montée interdite). Un seul code global ferait
dire « ça ne bouge pas » alors que l'autre sens fonctionne.

| Aspect | Évaluation |
|---|---|
| Poids | ~90 l. ST + 1 enum, 3 instances · **aucune variable RETAIN** |
| Risque | 🟢 très faible — lecture seule, aucune sortie physique |
| IHM | 1 champ `State.InhibitReason` par axe + libellé côté visu |
| Adresse | Le trou n°1, tous les essais terrain |

⚠️ **Piège d'ordonnancement** : à instancier dans `PRG_09_Supervision` (position 9), **après** tous les
producteurs — sinon 1 cycle de retard sur une partie des causes, et le code affiché peut désigner
une cause déjà disparue.

---

## 3. 🥈 B — `FB_FirstFault` : le premier défaut, gelé

Un défaut en cascade (ex. `PowerCutOff` → tous les axes en `Error`) rend l'origine indiscernable.

```
FB_FirstFault             // 🧱 brique réduite — Reset sur FRONT (doctrine projet)
VAR_OUTPUT
    FirstFaultActive : BOOL;
    FirstFaultSource : E_FaultSource;  // SAFETY_M1 · WINCH_M2 · TRANSLATION_M3 · CYCLE · BUS · …
    FirstFaultBit    : USINT;          // n° de bit dans l'ErrorId de la source
    FirstFaultAge    : TIME;           // ⏱️ depuis l'apparition
    FaultCountSince  : UINT;           // 🔁 nombre de défauts depuis le reset (défaut fugitif ?)
```

Gelé jusqu'à un **front** de `BtnFaultReset` — même doctrine que les blocs métier.

| Aspect | Évaluation |
|---|---|
| Poids | ~70 l. ST, 1 instance globale |
| Risque | 🟢 nul — diagnostic pur |
| IHM | Bandeau permanent « 1er défaut : Safety M1 / bit 7 / il y a 00:03 » |
| 🎁 Bonus | `FaultCountSince` révèle les défauts intermittents — invisibles autrement |

💡 **Ne pas mettre de `STRING` dans l'automate** : un code numérique + table de libellés côté IHM
coûte 0 octet PLC, se traduit, et se modifie sans recompiler. `CycleStateStr` (existant) est
l'exception historique, à ne pas généraliser.

---

## 4. 🥉 C — `FB_CommissioningMeter` : mesurer le déréglage

**Répond directement à 4 entrées MES ouvertes.** Un instrument de mesure permanent par axe.

| Mesure | Ce qu'elle révèle | Entrée MES adressée |
|---|---|---|
| `StopDistance_M` (dernière / max) | Distance parcourue entre coupure de commande et arrêt réel | **MES-009** (capteur 8 m / arrêt 7,5 m) |
| `BrakeApplyTime_Ms` / `BrakeReleaseTime_Ms` | Délai `BrakeCmd` → `BrakeFeedback` | **MES-006 / MES-008** (M1 vs M2, usure frein) |
| `StopTime_Ms` | Durée commande coupée → vitesse nulle | **MES-008** |
| `MaxSyncDeviation_M` (depuis reset) | Pire écart M1/M2 réellement atteint | Réglage `WinchSyncTolerance_M` |
| `MaxDriftMecaA_M` | Pire dérive à l'arrêt | **C5** — dimensionne le seuil 0,02 m/s |
| `TravelTime_S` M3 entre capteurs | Dérive mécanique translation | Suivi d'usure |
| `MovementCount` / `RunTime` par axe | Compteur d'usage | Maintenance préventive |

🎯 **Le comparatif M1 vs M2 devient lisible d'un coup d'œil** — c'est exactement l'objet de MES-008,
sans avoir à configurer une Trace.

| Aspect | Évaluation |
|---|---|
| Poids | ~110 l. ST, 3 instances · quelques `REAL`/`TIME` en `PERSISTENT` pour les max |
| Risque | 🟢 faible — mesure passive · ⚠️ ne **jamais** asservir une sécurité dessus |
| IHM | Page « Métrologie / mise en service » |

⚠️ Ces valeurs sont des **indicateurs de réglage**, pas des protections. Aucune ne doit devenir une
condition de mouvement sans passer par une spec `AF_PartieN` dédiée.

---

## 5. D — `FB_Preflight` : contrôle de cohérence machine à l'arrêt

Ce qui aurait détecté **C1** (polarité frein inversée) le premier jour.

Machine à l'arrêt, aucune commande active → **l'état attendu de chaque retour est connu** :

| Signal | Attendu à l'arrêt | Si faux |
|---|---|---|
| `M1/M2/M3BrakeFeedback` | `TRUE` (frein serré) | 🔴 polarité inversée ou frein collé |
| `Mx FwdRevSpeedFeedbackOff` | `TRUE` (contacteurs retombés) | 🔴 contacteur collé |
| Thermiques (NC) | `TRUE` | 🟠 fil coupé ou surchauffe |
| `PhaseRotationOk` | `TRUE` | 🔴 phases inversées |
| Mot 5 capteurs M3 | code valide (6 combinaisons) | 🔴 câblage/incohérence |
| `EmergencyChain` / `EmergencyStopOk` | cohérents entre eux | 🔴 câblage AU |
| Codeurs | `Operational`, position dans les bornes | 🟠 bus ou référencement |

Sorties : `PreflightOk : BOOL` + `PreflightErrorId : WORD` (bitfield, ≤ 16 défauts, doctrine projet)
+ `PreflightDone`. Exécuté **à la demande** (bouton IHM) et **au boot**, jamais pendant un mouvement.

| Aspect | Évaluation |
|---|---|
| Poids | ~80 l. ST, 1 instance |
| Risque | 🟠 **ne doit pas devenir bloquant** en v1 → informatif seul, sinon risque d'immobiliser la machine sur un faux positif |
| IHM | Bouton « Contrôle machine » + résultat détaillé |
| Adresse | MES-010 (polarité frein), MES-002, réception client |

👉 En complément direct de la fiche `BrakeFeedbackInvertLogic` : le préflight **dit** si la variable
est dans le bon sens, au lieu de laisser le technicien deviner.

---

## 6. E — Bypass : les rendre impossibles à oublier 🔴

**Risque livraison réel** : les bypass sont **RETAIN** (`GVL_BypassRetain`) et restaurés au boot.
Une machine peut partir chez le client avec un bypass MES resté actif — protection désactivée,
aucune alerte globale.

| Ajout | Effet |
|---|---|
| `BypassCountActive : UINT` (global) | Compte tous les bits `Bypass.*` actifs, tous domaines |
| `BypassWarningActive : BOOL` | Bandeau **permanent** non acquittable tant qu'un bypass est actif |
| `BypassListWord : WORD` par domaine | Quels bypass, sans ouvrir 6 pages IHM |
| 🔒 Refus `AUTO`/`SEMI_AUTO` si `BypassCountActive > 0` | À **trancher avec le client** — sécurise, mais peut gêner une exploitation dégradée assumée |
| `BtnBypassClearAll` | Remise à zéro d'un geste avant réception |

| Aspect | Évaluation |
|---|---|
| Poids | ~40 l. ST |
| Risque | 🟢 (bandeau) · 🟠 (refus de mode : **décision client requise**) |
| Adresse | MES-002 « vigilance », MES-004, réception |

---

## 7. F — Trace CODESYS livrée (T79) — coût automate nul

`MES-008` demande un enregistrement synchrone M1/M2. La Trace CODESYS le fait **sans une ligne de
code** : configuration à préparer, versionner et livrer.

Variables à échantillonner (10 ms, par axe) :
`RelayFwd` · `RelayRev` · `Contactor1..4` · `BrakeCmd` · `BrakeFeedback` ·
`FwdRevSpeedFeedbackOff` · `SpeedRamp.Current` · `CablePosM` · `MeasuredSpeedMps` ·
`DeltaPosM` · `SignedDeltaPosM`

📁 À stocker dans `TOOLS/` + procédure dans `DOC/CHECKLISTS/`.

| Aspect | Évaluation |
|---|---|
| Poids automate | **0** (la Trace ne consomme qu'à l'enregistrement) |
| Risque | 🟢 nul |
| Priorité | 🥇 **à faire en premier** — ratio valeur/effort imbattable, débloque MES-008 immédiatement |

---

## 8. G — Points de réglage exposés et lisibles

Constat transverse : plusieurs paramètres de réglage sont **invisibles ou trompeurs**.

| Point | État | Action |
|---|---|---|
| `DelayMotorDecel` (`FB_Brake`) | 🔴 **paramètre fantôme** — `TonDecel` armé à `IN := FALSE`, sans effet, mais réglable depuis `FB_Winch` | Supprimer **ou** implémenter — [audit C4](../RevueTechnique/AUDIT_Revue_Technique_v1.0.md) |
| `FB_Cycle.DrainingTime` | En dur `T#5s`, jamais câblé IHM/PERSISTENT | Exposer (T76) |
| `SpeedMismatchThreshold`/`Timeout` | À `0` = contrôle **inactif**, sans le dire à l'IHM | Afficher « surveillance inactive » (T43) |
| Plafond de palier réglé à `0` en essai | Rien ne signale la limitation | Afficher le plafond effectif (T64) |
| `BrakeFeedbackInvertLogic` | Variable clé, invisible IHM | Exposer en lecture + résultat préflight |
| Seuils Méca A/C/E | Annotés « théorique, à ajuster sur site » | Exposer avec la mesure max atteinte (§4) → réglage factuel |

🎯 **Règle** : tout paramètre qu'un technicien peut régler doit afficher **son effet réel** ou
indiquer qu'il est inactif. Un réglage sans effet est pire que pas de réglage.

---

## 9. 📊 Synthèse & priorisation

| # | Livrable | Valeur MES | Poids | Risque | Vague |
|---|---|---|---|---|---|
| F | Trace CODESYS livrée | 🔥🔥🔥 | 0 | 🟢 | **1 — immédiat** |
| A | `FB_MotionInhibit` ×3 | 🔥🔥🔥 | ~90 l. | 🟢 | **1** |
| B | `FB_FirstFault` | 🔥🔥🔥 | ~70 l. | 🟢 | **1** |
| E | Bandeau bypass | 🔥🔥 | ~40 l. | 🟢/🟠 | **1** |
| G | Paramètres fantômes | 🔥🔥 | −20 l. | 🟢 | **1** |
| C | `FB_CommissioningMeter` ×3 | 🔥🔥 | ~110 l. | 🟢 | **2** |
| D | `FB_Preflight` | 🔥🔥 | ~80 l. | 🟠 | **2** |

**Coût total ≈ +370 lignes ST (+3,7 %)**, à mettre en regard des **−210 lignes** du
[plan Simulation](PLAN_Rationalisation_Simulation_v1.0.md) → **bilan net ≈ +160 lignes (+1,6 %)**.

🎯 À assumer explicitement : **on n'allège pas, on rééquilibre.** On retire du code qui peut mentir
sur l'état de la machine, on ajoute du code qui l'explique. C'est le bon échange avant une livraison.

---

## 10. 🚦 Phasage & contraintes

### ⚠️ Contrainte RETAIN — structurante

Chaque livrable A/B/C/D/E ajoute des champs dans `ST_*HMI` (RETAIN) → **invalidation du RETAIN au
download**, restauration `PERSISTENT` (`ConfigRestoredFromPersistent`, ✅ en place) et **rejeu des
bypass RETAIN**.

👉 **Regrouper A + B + E + G et le lot 3 du plan Simulation en UNE livraison IHM unique.**
Une seule invalidation, un seul reparamétrage visu/SCADA, une seule vérification de config.
C + D peuvent constituer une 2ᵉ livraison IHM.

| Vague | Contenu | Prérequis | Livraison IHM |
|---|---|---|---|
| **0** | Trace CODESYS (F) | aucun | — |
| **1** | A + B + E + G ⊕ retrait `GVL_PLC_Tests` | Baseline | 🔄 **RETAIN #1** |
| **2** | C + D | Vague 1 validée | 🔄 **RETAIN #2** |
| **3** | Correctifs audit C2/C4/C5/C6 | — | — |

### 📋 À faire à chaque livraison IHM

1. Mettre à jour [AUDITS/IHM_VARIABLES_MIGRATION.md](../IHM_VARIABLES_MIGRATION.md) (ancien → nouveau chemin).
2. Régénérer le bundle PLCopenXML.
3. Relever et **vérifier** les bypass RETAIN après download.
4. Contrôler la config restaurée (`ConfigRestoredFromPersistent` → acquitter en conscience).
5. Consigner une entrée `MES-xxx` dans le registre.

---

## 11. 🧷 Limites & décisions à prendre

| Point | Décision attendue | Qui |
|---|---|---|
| Refuser `AUTO`/`SEMI_AUTO` si bypass actif | Sécurise / peut gêner l'exploitation dégradée | **Client** |
| `FB_Preflight` bloquant ou informatif | v1 informatif recommandé | Projet |
| Libellés défauts : PLC ou IHM | **IHM recommandé** (0 octet PLC, traduisible) | Projet + IHM |
| Historique d'alarmes | **Côté IHM** à partir de `FirstFault*` — un journal en PLC coûte cher pour peu | Projet + IHM |
| `DelayMotorDecel` | Supprimer ou implémenter | Projet / Sécurité |

- ⚠️ Aucun de ces blocs ne doit **modifier** une décision de sécurité existante. Ce sont des
  observateurs. Toute dérive vers « le diagnostic bloque le mouvement » doit repasser par une spec.
- ⚠️ Le décodage de `InhibitReason` doit rester **fidèle à l'ordre réel** d'évaluation du code.
  Une divergence entre l'ordre affiché et l'ordre appliqué serait pire que pas d'affichage.
- Aucun rejeu automatique depuis `v0.5.1` : validation par simulation manuelle + FAT/SAT.
