# 🪣 CADRAGE T175-01 — Mouvement M2 pendant manœuvre de benne : commandé / glissé / écart géométrique / limite

> **Type** : Cadrage sécurité (lecture seule) · **Criticité** : C0 · **Stratégie** : patch
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T175-01_M2_SLIP_SAFETY.yaml`
> **Code ancré** : `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` · `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` · `CODE/M_MAIN/PRG_04_Treuils_Benne.st`
> **Tests lus** : `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st` · `test_fb_safety_winch.st`
> **Toutes références** : `fichier:ligne`. Aucune valeur (seuil, tolérance, PLr) inventée — toute valeur neuve exige un visa humain (contrat **AC5**).

---

## ⚡ TL;DR
- Le code détecte **bien le glissement de M1** (couche 1 `FB_Bucket.st:141`, couche 2 Méca C bit9).
- Il **ne détecte PAS un glissement de M2** (mouvement de M2 hors consigne) **pendant** une manœuvre benne commandée. **C’est le trou central de T175-01.**
- Mécanismes existants pour M2 **masqués** pendant benne : Méca A/B (exigent joystick au neutre), Méca E (masqué par `BenneBusy`). → aucune surveillance M2 pendant mouvement commandé.
- **Producteur unique recommandé** : `instSafetyWinchM2` (nouvelle Méca dédiée) — l’FB de sécurité du domaine est seul juge `SafeStop`/`PowerCutOff`.
- **Chaîne d’arrêt recommandée** : classe **PowerCutOff** (SafeStop + coupure AU), miroir Méca A/B — car un câble déjà libre n’est pas rattrapable par une rampe. Visa humain requis (AC5).
- **Patch minimale** : nouvelle Méca M2 dans `FB_Safety_Winch`, branchée sur la vitesse mesurée M2 + le statut de commande `M2LogicRequestStartStop`, armée aussi pendant `instBucket.Lifecycle.Busy`.

---

## 1. 🔎 Les 4 états — définitions (ancrées code)

### État 1 — Mouvement M2 **commandé** (intentionnel, par `FB_Bucket`)
| Attribut | Réf |
|---|---|
| `FB_Bucket` en `Lifecycle.Busy` (CloseReq/OpenReq verrouillés) | `FB_Bucket.st:242-252` |
| Commande M2 émise : `M2_StartStop:=TRUE`, `M2_Direction=+1/-1`, `M2_ForceSlowSpeed` | `FB_Bucket.st:53-55, 258-280` |
| Le treuil reçoit l’ordre : `M2LogicRequestStartStop := instBucket.M2_StartStop` si Busy | `PRG_04_Treuils_Benne.st:321-324` |
| Mouvement physique confirmé : `M2_Busy := (instWinchM2.StepNumber > 0)` | `PRG_04_Treuils_Benne.st:226` |

**Signaux discriminants** : `instBucket.Lifecycle.Busy` **ET** `instBucket.M2_StartStop` **ET** (mouvement M2 réel : `M2_Busy` ou `|Speed_Mps|>seuil`).
> Fermeture = M2 monte (`Direction=+1`) ; ouverture = M2 descend (`Direction=-1`) — effet de bord de la désynchronisation M1/M2 (`FB_Bucket_v1.0.md §1`).

### État 2 — Mouvement M2 **non commandé / glissement** (mouvement parasite hors consigne)
Mouvement **physique** de M2 alors que **aucune consigne** n’est émise : `NOT M2LogicRequestStartStop` (donc `instBucket.M2_StartStop=FALSE` à l’entrée du treuil, `PRG_04:321-324`).

⚠️ **Trou de couverture actuel** :
- La détection « glissement » existante surveille **M1**, pas M2 : `M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM)` — `FB_Bucket.st:141` ; `M1RefPosM` capturé à l’entrée Busy — `FB_Bucket.st:245`.
- Méca A (roue libre, bit7) armée **seulement** si `JoystickYNeutral AND NOT BenneHoldStillActive` — `FB_Safety_Winch.st:234-238`. Pendant une manœuvre commandée, le joystick de l’axe Y **n’est pas** au neutre (c’est lui qui pilote la benne via `MotionRequestActive`/`MotionDirection`) → **Méca A désarmée**.
- Méca B (bit8) même limitation — `FB_Safety_Winch.st:246-252`.
- `UncommandedSpeedThresholdMps:=0.02` est **déclaré mais non câblé** (`FB_Safety_Winch.st:45`) → aucune détection M2 réactive par vitesse existe aujourd’hui (mono-canal assumé, `FB_Safety_Winch_v1.0.md §3` / TC-P10-001).

➡️ **Aucun FB ne produit le fait « M2 bouge sans consigne » pendant la manœuvre.** C’est le cœur de T175-01.

### État 3 — Erreur géométrique M1/M2 (Méca E)
| Attribut | Réf |
|---|---|
| Armement : `SyncEnable AND NOT BenneBusy AND NOT InReferencingMode AND NOT OtherWinchInhibited` | `FB_Safety_Winch.st:291` |
| Déclenchement : `ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM` (2,5 m) | `FB_Safety_Winch.st:292` |
| `ExpectedOtherWinchPosM` M2 = `CablePosM1 + instBucket.ActiveOffsetM` | `PRG_04_Treuils_Benne.st:716` |
| bit12 → SafeStop seul ; bit13 (non-confirmé 3 s) → SafeStop+PowerCutOff | `FB_Safety_Winch.st:290-306` |

**Rôle** : désaccord **géométrique** entre les deux treuils (les deux sous commande), pas un mouvement parasite d’un seul treuil.
🚫 **Masqué pendant la benne** : `BenneBusy := instBucket.Lifecycle.Busy` (`PRG_04:717`) ⇒ **Méca E ne peut PAS servir de détection de glissement M2** (contrat **AC4** : la tolérance 2,5 m ne tient pas lieu de détection de glissement M2).

### État 4 — Arrêt mécanique / limite atteinte (fin de course, butée)
| Attribut | Réf |
|---|---|
| Limite haute LOGICIELLE M2 : `CableLimitAscentM2Reached` = Homed & non-suspect & hors homing & pos ≥ `CfgCableLimitAscent_M + M2_LimitShift` | `PRG_04:1016-1019` |
| **Butée haute M2 décalée** de `OffsetCloseM` quand fermé/en fermeture — `M2_LimitShift` | `PRG_04:547-550, 604-608` (TC-P10-033) |
| Limite haute physique (capteur) : `TopPositionSensor` (`M1M2_TopPositionFree_DI`) → `AscentPermit:=FALSE` | `FB_Safety_Winch.st:380-385, 642` |
| Fin de course non confirmé en 3 s → Méca D (bit11) SafeStop+PowerCutOff | `FB_Safety_Winch.st:278-288` |
| Ralentissement/arrêt : `FB_Winch` `TopLimitM`/`BottomLimitM` | `PRG_04:843-844` |

**Discriminant** : la position M2 atteint une **bornes connue** (`TopLimitM2_M`, capteur haut, limite câble) → permis coupé → arrêt en rampe ; le glissement, lui, bouge **hors borne**.

---

## 2. 🌳 Arbre de décision (signaux réels disponibles)

> Légende : 🟢 = discriminant exploitable aujourd’hui · 🔴 = **trou** à combler (nouvelle détection).

```
Manœuvre benne active ?   instBucket.Lifecycle.Busy   (PRG_04:655/712/717; FB_Bucket.st:242)
│
├── OUI ─────────────────────────────────────────────────────────────────
│   │
│   ├─ Consigne M2 émise ?   instBucket.M2_StartStop   (FB_Bucket.st:258-280; PRG_04:321-324)
│   │   ├─ TRUE ─► ÉTAT 1 M2 commandé (mouvement attendu)
│   │   │           + vérif M1 : M1SlipDetected (FB_Bucket.st:141) → État 2a (M1 slip)
│   │   │             → coupe M2 (FB_Bucket.st:221-230) + SafeStop M1 (PRG_04:491)
│   │   └─ FALSE ─► M2 bouge-t-il ?  (M2_Busy : PRG_04:226  OU  |Encoders.M2.Speed_Mps|>seuil)
│   │       ├─ OUI ─► ÉTAT 2 M2 NON COMMANDÉ (SLIP M2)  🔴 AUCUNE détection dédiée
│   │       └─ NON ─► benne au repos sans ordre + sans mouvement → nominal (rien)
│   │
│   └─ M2 bouge sans être en manœuvre active ? (M2_Busy OR vitesse)  🔴 (même trou)
│
└── NON (hors manœuvre) ─────────────────────────────────────────────────
    │
    ├─ Méca E armé (SyncEnable AND NOT BenneBusy …) :  (FB_Safety_Winch.st:291)
    │   ABS(M2pos - (M1pos+ActiveOffsetM)) > 2,5m      (FB_Safety_Winch.st:292; PRG_04:716)
    │   ├─ bit12 → SafeStop            → ÉTAT 3 (écart géométrique)
    │   └─ bit13 (3 s) → SafeStop+PowerCutOff → ÉTAT 3 escaladé
    │
    └─ Hors écart synchro :
        ├─ Joystick neutre ET dérive M2 > 2,0 m → Méca A bit7 (roue libre, PowerCutOff) → ÉTAT 2 (M2)
        │     (FB_Safety_Winch.st:234-238) — coars, arrêt confirmé coupé
        └─ Limite atteinte : CableLimitAscentM2Reached / capteur haut / limite câble / TopLimitM2_M
              → permits coupés → ÉTAT 4 (arrêt mécanique) (PRG_04:1016-1019, 604-608)
```

**Point clé** : la branche « M2 bouge pendant manœuvre **sans** consigne » (ÉTAT 2) n’a **aucun capteur logique** aujourd’hui. L’arbre la rend **détectable** uniquement si on ajoute la nouvelle Méca M2 (§3, §5, §7).

---

## 3. 🧑🔧 Producteur unique recommandé (règle « 1 FB = 1 responsabilité »)

| Fait | Producteur actuel/actuel | Producteur recommandé |
|---|---|---|
| Glissement **M1** pendant benne (couche 1, 1,0 m) | `FB_Bucket` bit4 (`FB_Bucket.st:141-148`) | **inchangé** (process) |
| Glissement **M1** couche 2 (2,0 m) | `instSafetyWinchM1` Méca C bit9 (`FB_Safety_Winch.st:259-268`) | **inchangé** (safety) |
| Écart géométrique M1/M2 (Méca E) | `instSafetyWinchM1/M2` bit12/13 | **inchangé** |
| **Glissement M2 non commandé** | **❌ aucun** | ➡️ **`instSafetyWinchM2`** (nouvelle Méca dédiée) |

**Justification** :
- `FB_Safety_Winch` est le **bloc safety du domaine** (Partie3 §2, profil FB safety), propriétaire des sorties `SafeStop`/`Permit`/`PowerCutOff` (`FB_Safety_Winch.st:77-93`).
- C’est lui qui a **déjà tous les entrants** nécessaires : `MeasuredSpeedMps/SignedMps/Valid`, `Direction`, `MovementCommanded` (`FB_Safety_Winch.st:16-18, 52-54`), câblés pour M2 (`PRG_04:707-721`).
- On garde « 1 donnée = 1 producteur » : le fait « M2 bouge hors consigne » est produit **une seule fois** (nouveau bit de `instSafetyWinchM2`), consommé par PRG_04 (arbitrage) et IHM. Aucun nouveau GVL-canal.
- **Non-doublon** : ce nouveau bit est distinct de Méca F/G (sens opposé/absence de mouvement, armés quand commande **présente**) et de Méca A (armé joystick neutre). Il couvre le cas « commande **absente** mais mouvement présent », **y compris pendant** `Lifecycle.Busy`.

---

## 4. 🛑 Chaîne d’arrêt recommandée (règles projet)

Règle : `Enable > SafeStop > StartStop` — « seul l’AU coupe brutalement » (AGENTS.md / AF01).

**Classe recommandée pour le glissement M2 : `PowerCutOff` (SafeStop + coupure AU)**, miroir Méca A et B :
- Méca A (roue libre) et Méca B (pilotage sans confirmation d’arrêt) déclenchent tous deux `SafeStop+PowerCutOff` — bits 7 & 8 dans le masque `16#2F84` (`FB_Safety_Winch.st:387`, `FB_Safety_Winch_v1.0.md §3`).
- **Physique** : un treuil qui **dévide librement** n’est pas rattrapable par une rampe (`SafeStop` supposerait le moteur capable de freiner). Seule la **coupure d’alimentation amont (AU)** stoppe le mouvement. → classe PowerCutOff justifiée.

**Chaîne bout-en-bout visée** (reprend la chaîne PowerCutOff existante, TC-P10-051.1) :
```
instSafetyWinchM2 <nouvelle Méca M2>
   → instSafetyWinchM2.PowerCutOff (bit dans masque 16#2F84)
   → PRG_04 §7 PowerCutOff := instSafetyWinchM2.PowerCutOff   (PRG_04:888)
   → Data.WinchM2FinalInterlockRequest → PRG_06 → coupure AU
et en parallèle :
   → instSafetyWinchM2.SafeStop → SafeStopM2_Active (PRG_04:744,768) → instWinchM2.SafeStop (PRG_04:818)
```
⚠️ **AC5** : l’ajout d’un nouveau bit **dans le masque PowerCutOff** est une décision de sécurité → **visa humain/site avant implémentation**. Pas de PLr, pas de seuil chiffré inventé ici : c’est une **recommandation de classe**, à valider.

---

## 5. 📡 Capteurs / signaux : dispo vs manquants pour discriminer le glissement M2

| Signal | Dispo code | Utile pour |
|---|---|---|
| Vitesse M2 mesurée (± & validité) : `Encoders.M2.Speed_Mps/SignedSpeed_Mps/SpeedValid` → entrées `FB_Safety_Winch` | ✅ `PRG_04:719-721` ; `FB_Safety_Winch.st:52-54` | détecter « M2 bouge » (base du slip) |
| Consigne de commande M2 : `M2LogicRequestStartStop/Direction` (= `instBucket.M2_StartStop` pendant Busy) | ✅ `PRG_04:321-324` | discriminer commandé vs non-commandé |
| `MovementCommanded` M2 (`instWinchM2.RelayFwd/Rev`) | ✅ `PRG_04:708` | savoir si le treuil a reçu un ordre |
| Retours contacteurs/frein M2 (`M2_ContactorsReleased_DI`, `M2_BrakeIsOpen_DI`) | ✅ `PRG_04:812-813, 836` | confirmer l’arrêt réel (Méca B) |
| Positions M1/M2 + Homed + homing | ✅ `PRG_02` → `PRG_04:221-224, 649-651` | géométrie Méca E, limites |
| `M1SlipDetected` (couche 1 M1) | ✅ `FB_Bucket.st:141` | glissement M1 (distinct du M2) |
| `UncommandedSpeedThresholdMps` (0,02 m/s) | ❗ `FB_Safety_Winch.st:45` — **déclaré, non câblé** | seuil vitesse non commandée (à réactiver pour la nouvelle Méca) |
| **Détection « M2 bouge sans consigne » (pendant & hors benne)** | 🔴 **ABSENT** | l’État 2 (le cœur T175-01) |
| Vitesse moteur/variateur indépendante du codeur câble | ❌ absent (seul le codeur de câble) | dérive tambour/câble invisible |
| Capteur d’effort/charge sur la benne M2 (libre vs commandé) | ❌ absent | discriminer physiquement la roue libre |
| Seuil de glissement M2 validé (valeur chiffrée) | ❌ à définir | AC5 — visa humain requis |

**Lecture** : la **donnée** (vitesse M2, consigne, états) est déjà là ; c’est le **détecteur logique** « slip M2 » qui **manque**. Aucun nouveau capteur physique n’est strictement requis pour une première détection vitesse/consigne ; un **codeur moteur indépendant** lèverait néanmoins l’aveugle tambour/câble (option terrain, hors périmètre patch).

---

## 6. 🧪 Scénarios nominal et défaillants à tester (liste)

**Nominal (ne doit PAS déclencher — AC3)**
| # | Scénario | Attendu |
|---|---|---|
| S1 | Fermeture benne commandée (Direction=+1, M2_StartStop=TRUE), M1 stable | État 1, **pas de faux slip M2** |
| S2 | Ouverture benne commandée (Direction=-1), M2 bouge selon consigne | État 1, pas de faux défaut |
| S3 | M2 atteint la butée haute décalée (`OffsetCloseM`) en fin de fermeture | État 4, Done nominal (`FB_Bucket.st:293-302`) |
| S4 | Recul borné (inversion de sens) ramené à `M2StartPosM` | arrêt propre, pas de slip (`FB_Bucket.st:287,303-311` ; TC-P10-029.1) |

**Défaillants (doivent déclencher)**
| # | Scénario | Détection cible | Chaîne |
|---|---|---|---|
| S5 | M1 glisse >1,0 m pendant Busy (couche 1) | `M1SlipDetected` (`FB_Bucket.st:141`) | coupe M2 + SafeStop M1 (`PRG_04:491`) |
| S6 | M1 glisse >2,0 m en maintien (couche 2) | Méca C bit9 (`FB_Safety_Winch.st:259`) | SafeStop+PowerCutOff |
| S7 | **M2 bouge (vitesse ≠0) sans `M2_StartStop` pendant Busy** | 🔴 nouvelle Méca M2 | PowerCutOff (recommandé) |
| S8 | **M2 déride librement hors benne, joystick neutre** | Méca A bit7 (`FB_Safety_Winch.st:234`) | SafeStop+PowerCutOff |
| S9 | Écart M1/M2 >2,5 m hors benne (bit12, puis bit13) | Méca E (`FB_Safety_Winch.st:290-306`) | bit12 SafeStop ; bit13 +PowerCutOff |
| S10 | M2 atteint capteur haut sans arrêt 3 s | Méca D bit11 (`FB_Safety_Winch.st:278`) | SafeStop+PowerCutOff |
| S11 | Non‑déclenchement Méca E pendant manœuvre (BenneBusy) — vérif qu’aucun faux 2,5 m n’agit | `BenneBusy` masque (`PRG_04:717`) | pas de faux défaut |

**Tests automatisables** (boîte noire, à ajouter) : S1, S2, S7, S8, S9 dans `test_fb_safety_winch.st` (injection vitesse/consigne) ; S5 dans `test_fb_bucket.st` (TC-P10-026/027 existants). S6, S10, S11 couverts/à compléter. **S7 nécessite un nouveau bit + le câblage du statut consigne M2 dans le harnais d’injection** (AC2 « TC d’injection »).

---

## 7. 🩹 Patch minimale (description — aucune implémentation ici)

1. **Nouvelle Méca M2 dans `instSafetyWinchM2`** (dans `FB_Safety_Winch`) : détection « mouvement M2 mesuré alors qu’aucune consigne n’est émise ».
   - Entrant : `MeasuredSpeedMps/SignedMps/Valid` (déjà câblé, `PRG_04:719-721`) + un nouveau signal `MovementCommanded` **valide pendant la benne** = `instBucket.M2_StartStop` (ou `M2LogicRequestStartStop`).
   - Armement : **ne pas** exiger le joystick neutre (contrairement à Méca A) et **ne pas** masquer sur `BenneBusy` (contrairement à Méca E) → couvre le glissement pendant la manœuvre.
   - Déclenchement : `MeasuredSpeedValid AND NOT MovementCommanded AND |SignedSpeedMps| > <seuil>` confirmé sur un délai court (pattern Méca F, `FB_Safety_Winch.st:312`).
   - Sortie : nouveau bit → `SafeStop` + `PowerCutOff` (miroir Méca A/B).
2. **Réactiver `UncommandedSpeedThresholdMps`** (déclaré `FB_Safety_Winch.st:45`, non branché) comme seuil vitesse de base — valeur à viser humainement (**AC5**), aucune inventée ici.
3. **Câbler le nouveau bit dans le masque PowerCutOff** (`FB_Safety_Winch.st:387`) et le publier via `PRG_04:888` — **décision à visa** (AC5).
4. **Aucune modification** de la détection M1 (couche 1 & 2), ni de Méca E, ni des permis — la nouvelle Méca est **parallèle**.
5. **TC** : ajouter S7 (et confirmer S1/S2 = zéro faux positif) dans `test_fb_safety_winch.st` + un TC d’injection de chaîne (AC2).

**Périmètre interdit** : `TASKS.yaml`, `Device.export`, aucun bypass existant (conservation contrat T175 §conservation).

---

## 8. 🧾 Mapping contrat T175-01 (AC1–AC7)

| AC | Verdict vis-à-vis de ce cadrage |
|---|---|
| AC1 Classer chaque scénario | ✅ Table §1 + arbre §2 (4 états) |
| AC2 M2 non commandé → producteur unique + SafeStop/PowerCutOff | 🟡 Recommandé §3 + §4 ; **état 2 non détecté aujourd’hui**, nouveau producteur proposé = `instSafetyWinchM2` |
| AC3 M2 commandé sans faux défaut | ✅ S1/S2 §6 ; à verrouiller par TC |
| AC4 Meca C vs Meca E distincts, pas de faux usage 2,5 m | ✅ §1 État 3 / §2 ; Méca E masqué benne (`PRG_04:717`) |
| AC5 aucune valeur inventée | ✅ Aucun seuil/PLr produit ici ; visa requis (§4, §7 item 2/3) |
| AC6 & AC7 nom de fichier = POU, ST pur | ✅ `PRG_04_Treuils_Benne.st` non modifié (0 édition) |

---

## 9. 🚩 Devoir d’alerte & ouvertures
- **Décision sécurité à viser** : classe `PowerCutOff` pour le glissement M2 (miroir Méca A/B) — ne pas implémenter sans visa (AC5, `TASK_CONTRACT …:60-62`).
- **Seuil de vitesse/délai** de la nouvelle Méca → valeur humaine (AC5). Aucune valeur proposée dans ce cadrage.
- **Limite connue** : la détection vitesse/consigne ne voit pas un **dérapage tambour/câble** (codeur du côté câble uniquement). Un **codeur moteur indépendant** est l’option terrain si ce mode est dans le REX.
- **Aucun bypass** n’est touché ; matrice maintenance N1/N2 inchangée (`PRG_04:554-620`).

---

*Fin du cadrage. Aucun fichier `CODE/`, `DOC/WFLOW/TASKS.yaml` ni contrat modifié ; aucun commit/push.*
