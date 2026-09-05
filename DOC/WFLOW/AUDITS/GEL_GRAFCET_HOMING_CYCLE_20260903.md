# 🧊 GEL GRAFCET — Homing machine & Cycle SEMI_AUTO (cible refonte)

> **But** : figer **steps + actions + transitions** des deux séquenceurs AVANT toute ligne de code.
> Brouillon de travail — itéré avec l'utilisateur. Rien n'est codé tant que ce doc n'est pas validé.
>
> - **Date** : 2026-09-03 · **Branche** : `backup/mes-septembre-20260902`
> - **Baseline (état AVANT)** : [`BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md`](BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md)
> - **Contrats liés** : [T226](TASK_CONTRACT_T226_REFONTE_HOMING_SEMIAUTO.yaml) (homing) · [T229](TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml) (cycle) · [T232](TASK_CONTRACT_T232_MAJ_DOC_REFONTE_CYCLE.yaml) (doc)
> - **Statut** : 🟡 BROUILLON — questions ouvertes non tranchées (§4)

---

## 0️⃣ Principes GRAFCET communs (tranchés)

1. **Étape initiale = étape pure** : aucune action, aucune affectation dans le corps de l'étape.
   Les sorties retombent par **absence d'étape qui les commande** (remise à FALSE en tête de scan),
   pas par un `X := FALSE` écrit dans l'étape initiale.
2. **Coexistence** : le GRAFCET homing et le GRAFCET cycle SEMI_AUTO tournent **en parallèle**.
   Être en étape initiale de l'un pendant que l'autre bouge est un état **normal**. L'étape initiale
   n'interfère avec rien.
3. **On garde la machine à états `CASE`** (`E_MachineHomingTxState` créée en Zone F) : on
   l'**étend** en GRAFCET séquentiel, on ne la remplace pas.
4. **Permis mouvement** : tout ordre treuil émis par un séquenceur exige le permis opérateur
   maintenu (`manche défléchi + homme-mort armé`), même principe que `CycleMotionPermit`.
5. **Jamais de redémarrage auto après défaut** : sortie d'un état FAILED sur `Reset` conscient.
6. **Séparer DIRECTION et VALIDATION** — mécanismes homogènes sur **toute la machine**
   (cycle homing, cycle SEMI_AUTO, tout séquenceur opérateur). PAS de bit dédié par transition.

   | Concept | Définition | Rôle |
   |---|---|---|
   | **`StepDirection`** | déflexion joystick **dans le sens attendu par le step** + homme-mort armé. **Le step impose le sens** (tirer / pousser / gauche / droite). | commander le mouvement |
   | **`V_CONTINU`** | homme-mort armé **+** joystick maintenu défléchi (le sens = celui du step). | valider **sans confirm explicite** → continuité de mouvement (aucun à-coup entre steps) |
   | **`V_EXPLICITE`** | homme-mort armé **+** `BtnValidation` motif **3 appuis** (§5) — **bit unique partagé machine**. | valider un point qui exige un acte conscient (ex. « benne fermée ») |

   Chaque transition « opérateur » déclare **quelle variante** elle attend (`V_CONTINU` ou
   `V_EXPLICITE`). Le motif 3 appuis est défini **une seule fois** (§5) et réutilisé partout —
   jamais redéfini par transition.
7. **Sortie / annulation** : `Reset` (ou BP annulation générique), pas un bit par point de sortie.

---

## 1️⃣ GRAFCET Homing machine — `FB_CycleMachineHoming` (cible)

> Aujourd'hui : pas de GRAFCET (échelle de priorité §6 + transaction 3 états §4 déclenchée
> par le front de confirmation benne). Cible : vrai séquentiel `X0 → X4`.

### Séquence

> Variables = noms réels `FB_CycleMachineHoming`. Avancement = `StepValidate` (front) / `StepValidateJoy` (§0.6), pas de bit dédié.
> 🟦🟨🟩🟥 = **STEP** · ⬇️ transition · ⬆️ retour · 🚪 sortie.

#### 🌳 Tronc commun — jusqu'au CHOIX

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **HX0** REPOS | 🟦 step initiale pure | *rien* — aucune action, aucune affectation |
| **HT0** | ⬇️ | `V_EXPLICITE` *(Q3 : ou auto)* **OU** (`MachineHomed` retombé) · **ET** `TxState = IDLE` · **ET** `Mode = E_Mode.MAINT_N2` |
| **HX1** ANNONCE + CHOIX | 🟨 step — 🚫 mvt | benne = **état inconnu** (quel que soit le capteur) · treuils manipulables couplés (both) · msg selon contexte : `NOT TopPositionActive` → `'machine non referencee - monter au capteur haut'` · `TopPositionActive` → `'sur capteur haut - valider pour referencer, ou quitter'` · aucun ordre `M1Demand`/`M2Demand`/benne |
| **HT1a** | 🚪 **sortie** | `R_TRIG(Reset).Q` (ou BP annulation) → abandon → **MAINT_N2 libre** (hors séquence, relance par HT0). Dégagement / décharge hors cycle. |
| **HT1b** | ⬇️ **→ Chemin A** | `NOT TopPositionActive` **ET** `V_EXPLICITE` *(Q7)* → **HX2** |
| **HT1c** | ⬇️ **→ Chemin B** | `TopPositionActive` **ET** `V_EXPLICITE` *(Q7)* → **HX2N** |

> HT1b / HT1c **quasi identiques** : seule diffère la polarité de `TopPositionActive`.
> ⚠️ **M3 translation INTERDITE** pendant tout le cycle (HX1→HX6) : joystick gauche/droite ignoré
> côté M3 (cf. §3 C4).

#### 🅰️ Chemin A — pas sur capteur (via HT1b)

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **HX2** MONTÉE AU CAPTEUR | 🟩 step — ⬆️ palier 1 | `MachineHomingInstruction := 'Tirer joystick - montee treuils M1 M2 Palier 1 - jusqu au capteur FDC haut'` · `M1Demand`/`M2Demand` = montée couplée palier 1 (permis opérateur maintenu, **joystick tiré**) *(Q2 : FB émet ou demande PRG_04)* |
| **HT2** | ⬇️ — 🔝 sur capteur | `TopPositionActive` → **HX2N** |

#### 🅱️ Chemin B — déjà sur capteur (via HT1c)

| Rep. | 🎬 | Contenu |
|---|---|---|
| — | — | HT1c va **directement à HX2N**. La montée (HX2) est sautée. Suite commune à partir de HX2N. |

#### 🔻 Tronc HX2N → HX6 (commun aux 2 chemins)

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **HX2N** ARRÊT (+ inversion si besoin) | 🟩 step — 🛑 mvt nul | treuils 0 (`M1Demand`/`M2Demand` = 0) · `MachineHomingInstruction := 'joystick au neutre, attendre l arret, puis pousser joystick pour descendre'` · latch `SeenNeutral := TRUE` dès `NOT JoystickDeflected` (satisfait d'emblée si on arrive déjà centré — Chemin B) · **état sans mouvement obligatoire** |
| **HT2N** | ⬇️ — descente armée | `WinchesMechanicallyStopped` **ET** `SeenNeutral` **ET** `StepDirection` = joystick **poussé** (sens imposé par HX3 = descente) + homme-mort armé → **HX3**. Validation = `V_CONTINU` (le joystick maintenu EST le go, continuité de mouvement). *(Chemin A : `SeenNeutral` force le retour au neutre après la montée. Chemin B : `SeenNeutral` déjà vrai, pas d'inversion.)* |

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **HX3** RÉF. AXES M1 M2 (au vol) — **pas la benne** | 🟩 step — ⚓⬇️ | descente couplée M1+M2 **palier 1** (permis opérateur maintenu) · réf. **axes seulement** (M1 + M2) déclenchée sur **`F_TRIG(TopPositionActive).Q`** (front descendant = sortie du capteur, basse vitesse → **répétable**) : `M1Demand.HomeReq` + `M2Demand.HomeReq` à ce front · l'**état benne** (ouverte/fermée) n'est **pas** traité ici → HX4/HX5 · **échec** (`M1Status.HomingError OR M2Status.HomingError`, ou axes non `HomedAndReliable` après le front + timeout *(Q4)*) ⇒ **HXF** |
| **HT3** | ⬇️ — 🔓 homé, hors capteur | `NOT TopPositionActive` **ET** `M1Status.HomedAndReliable` **ET** `M2Status.HomedAndReliable` (on peut quitter le FDC soft haut : on est homé) |
| **HX3N** ARRÊT avant benne | 🟩 step — 🛑 mvt nul | treuils 0 · benne 0 · latch `SeenNeutral := TRUE` dès `NOT JoystickDeflected` · `MachineHomingInstruction := 'joystick au neutre, puis tirer pour fermer la benne (2 sens autorises pour ajuster)'` — évite que le joystick resté poussé (descente HX3) commande la benne dès l'entrée en HX4 |
| **HT3N** | ⬇️ — pause franchie | `WinchesMechanicallyStopped` **ET** `SeenNeutral` → **HX4** |
| **HX4** AJUSTEMENT BENNE | 🟩 step — 🪣 palier 1 sans FDC soft | `MachineHomingInstruction := 'ouvrir / fermer la benne pour la mettre en position fermee'` · benne palier 1 **sans FDC soft**, **2 sens autorisés** (réglage à l'œil) · treuils 0 |
| **HT4** | ⬇️ — ✅ « benne fermée » | `V_EXPLICITE` (joystick centré + `WinchesMechanicallyStopped`) ⇒ `PendingClose := TRUE` |
| **HX5** COMMIT BENNE FERMÉE | 🟩 step — 🪣⚓ | axes déjà homés (HX3) → HX5 = **commit d'état benne** seul : `BucketCommit.CommitClose := PendingClose` (atomique, 1 scan) · pas de re-homing d'axe *(Q10 : l'offset `CfgOffsetClose_M` sert-il encore, ou l'état benne suffit ?)* |
| **HT5** | ⬇️ — 🎯 | `CommitPublished` **ET** 2× `HomedAndReliable` |
| **HX6** MACHINE RÉFÉRENCÉE | 🟩 step fugace | `MachineHomed := TRUE` = `AxisHomed AND CommitOrOffsetValid AND NOT MachineHomingFailed AND NOT ReHomingAckRequired AND NOT Fault.Latched` |
| **HT6** | ⬇️ — 🔁 | inconditionnelle (1 scan) → **HX0** |

#### 🟥 Défaut & transverses

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **HXF** FAILED | 🟥 step | `MachineHomingFailed := TRUE` · `MachineHomingInstruction := 'referencement incomplet - rester N2 et recommencer'` |
| **HTF** | ⬆️ abort (HX2→HX5) | `NOT TopPositionActive` (hors phase descente volontaire) **OU** `NOT WinchesMechanicallyStopped` (hors phase mvt) **OU** `M1Status.HomingError OR M2Status.HomingError` **OU** timeout *(Q4)* → **HXF** |
| **HTR** | ⬆️ (HXF → HX0) | front `Reset` (cause disparue) |
| **HT⊥** | ⬆️ transverse | `NOT Enable` → sorties sûres, `MachineHomed := FALSE` → **HX0** |
| **HT⊘** | ⬆️ transverse | perte datum **en mouvement** ⇒ `MachineHomingLossSafeStop := HomingLossLatched` (latch jusqu'à arrêt méca + `Reset`) |

### Mapping vers la machine `CASE` existante
- `E_MachineHomingTxState` passe de 3 valeurs à ~6 (HX0..HX4 + HXF).
- Le §6 (échelle de priorité, libellés diagnostic) **reste** en `IF/ELSIF` — il devient le
  **producteur du message opérateur** de l'étape courante, pas un dispatch d'état.
- Angle mort connu (baseline) : ajouter une branche `Fault.Latched` au §6.

---

## 2️⃣ GRAFCET Cycle SEMI_AUTO — `FB_Cycle` (cible)

> Aujourd'hui : `X0_PREPARATION` fait du housekeeping (treuils/translation/benne = 0,
> `WaitingForOperator`, `SampleCountDone := FALSE`) → **ce n'est pas** une étape initiale pure.

### Ajout : étape initiale pure en amont

| Step | Nature | Actions |
|---|---|---|
| **CX_INIT** *(nom + valeur à trancher — « X10 » déjà pris par `X10_TRANSLATE_DUMP`)* | initiale pure | *aucune* |
| **X0_PREPARATION** | active | housekeeping actuel (inchangé) — devient l'étape **1** de préparation |
| X1…X13, STABILIZING | — | inchangés (refonte T229 déjà committée : X1 gutté, split X11a/b/c, translation P1, garde-fous) |

### Transition ajoutée

| # | De → Vers | Réceptivité |
|---|---|---|
| **CT_INIT** | CX_INIT → X0_PREPARATION | condition à définir : `Enable (= Mode SEMI_AUTO)` ? front d'entrée mode ? *(Q6)* |

### Impact consommateurs enum `E_CycleStep`
`FB_Hmi_BannerFormatter`, `FB_TroubleshootingView`, `PRG_03`, `PRG_07`, tests — tous à couvrir
pour la nouvelle valeur. Choix « valeur négative / 99 / renumérotation » à figer ici.

---

## 3️⃣ Contraintes non négociables reprises de la baseline

- **C1** continuité joystick : `CycleMotionPermit` ne retombe jamais entre étapes ; pas de creux
  `RunRequest := FALSE` aux frontières (hors arrêt réellement voulu).
- **C1e** X6 → X7 sans temps mort (M1 lancé même scan que sortie X6).
- **C2** homing au boot si non référencé ; perte `MachineHomed` en SEMI_AUTO → SafeStop treuils
  **puis** MAINT_N1 (T226 AC1/AC2, committé).
- **C3 / C3.1** translation M3 = jamais de déplacement autonome ; départ toujours P1.
- **C4** *(nouveau)* **M3 INTERDIT pendant tout le cycle de homing machine** (HX1→HX6) : le joystick
  gauche/droite ne doit **pas** commander la translation. Verrou côté arbitrage M3 tant que le
  GRAFCET homing n'est pas en HX0. Idem : passage montée→descente (HX2→HX3) **impose** un état
  treuils nuls (HX2N) — pas d'inversion de sens sans arrêt.

---

## 4️⃣ ❓ Questions ouvertes (à trancher pour passer 🟡→🟢)

| Q | Sujet | Options |
|---|---|---|
| **Q1** | ✅ ~tranché | Réf. **axes M1+M2 au vol** sur `F_TRIG(TopPositionActive)` (front descendant, basse vitesse = répétable). État benne commit séparé en HX5. Confirmer. |
| **Q2** | Montée au capteur (HX2, Chemin A) | FB émet l'ordre treuil **ou** demande vers PRG_04 ? |
| **Q3** | Entrée HT0 | bouton IHM dédié · **ou** automatique en MAINT_N2 non-homed (condition d'état, « pas de bouton HomingRequest » = D6) |
| **Q4** | Timeouts | HX2 (montée), HX3 (descente jusqu'au front), HX4 (attente validation benne) : valeurs ? configurables `Cfg` ? |
| **Q5** | ✅ tranché | **M3 interdit tout le cycle** (HX1→HX6, cf. C4). Reste : où poser le verrou — arbitrage M3 (`FB_TranslationCmdArbitrationM3`) ou `PRG_05` ? |
| **Q6** | `CX_INIT` | nom + valeur enum · réceptivité `CT_INIT` · stratégie renumérotation vs valeur hors-plage |
| **Q7** | Validation HT1b (HX1→HX2) | mêmes moyens que HT4 (IHM / motif 3 appuis) ? ou simple BP suffit (pas encore de mouvement engagé) ? |
| **Q8** | Décharge en HX1 | matière dans la benne au moment du homing (datum perdu en exploitation) ? largage volontaire autorisé (⇒ sortie HT1a en N2) ? |
| **Q9** | Motif 3 appuis (§5) | durées exactes : appui pris `> 300 ms`, fenêtre max entre appuis, timeout global ? Même motif HT1b / HT4 ? |
| **Q10** | Offset `CfgOffsetClose_M` | encore utile en HX5 (les axes sont homés en HX3) ou l'**état benne** committé suffit ? |

---

## 5️⃣ `V_EXPLICITE` — motif `BtnValidation` « 3 appuis successifs »

**Bit unique partagé sur toute la machine** (homing, SEMI_AUTO, tout séquenceur). Défini ici une
seule fois, jamais redéfini par transition. `V_EXPLICITE` = *homme-mort armé* **+** ce motif validé.

**Pré-conditions permanentes** (sinon le compteur se réinitialise) :
- joystick **centré** (aucune déflexion sur tous les axes)
- **aucun mouvement** en cours (treuils + translation à l'arrêt)
- reste dans le step concerné

**Séquence** (exemple, valeurs à figer — Q9) :
1. appui BP joystick **maintenu ≥ 300 ms** → 1ᵉʳ appui pris en compte
2. **front descendant** (relâchement) → arme l'attente du 2ᵉ
3. 2ᵉ appui ≥ 300 ms → relâchement
4. 3ᵉ appui ≥ 300 ms → relâchement → **validation acquise**

- Fenêtre max entre deux appuis : *à définir* (ex. 2 s) — dépassée ⇒ reset compteur.
- Toute déflexion joystick / tout mouvement pendant la séquence ⇒ reset compteur (repart de 0).
- Un `R_TRIG` / `F_TRIG` + `TON` par appui ; compteur `0→3`.

---

_Brouillon 2026-09-03. Ne pas coder tant que §4 n'est pas résolu et le doc validé._
