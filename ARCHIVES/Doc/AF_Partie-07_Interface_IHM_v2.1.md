# Analyse Fonctionnelle - Partie 7 : Interface IHM (v2.1)

> Role : definir le contrat structurel PLC ↔ IHM.
> Le detail des champs vit dans le code `CODE/SUPERVISION/_TYPES/`.

## 🧭 Sommaire

1. Principe
2. Frontiere `GVL_IHM`
3. Structures par domaine
4. Messages operateur
4bis. Bandeau d'alarme défilant
5. Troubleshooting
6. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P07-001</code></nobr> | IHM et PLC partagent les mêmes DUTs | Aucun miroir parallèle de variables | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P07-002</code></nobr> | Structures `Cmd/State/Cfg` par domaine | Convention respectée dans `GVL_IHM` | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P07-003</code></nobr> | IHM limitée aux variables de `GVL_IHM` | Zéro accès direct aux internes des FB | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P07-004</code></nobr> | Producteur unique par champ `State` | Un seul écrivain PLC par variable d'état | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P07-005</code></nobr> | Page Troubleshooting en lecture seule | Zéro écriture de commande/config/bypass | `💻 AUTO` | <small>§5</small> |
| <nobr><code>TC-P07-006</code></nobr> | Séparation messages action vs état | 2 familles distinctes, alarmes sur `ErrorId` | `⚡ SITE+AUTO` | <small>§4</small> |
| <nobr><code>TC-P07-007</code></nobr> | Warning auto-effaçable vs Fault sur Reset | Warning s'efface seul, Fault exige `Ack` | `⚡ SITE+AUTO` | <small>§4</small> |
| <nobr><code>TC-P07-008</code></nobr> | Carrousel d'alarmes un message à la fois, index n/N | `Banner.AlarmBanner.Index/Count` cohérents | `💻 AUTO` | <small>§4bis</small> |
| <nobr><code>TC-P07-009</code></nobr> | Aucun défaut actif → bandeau d'alarme vide | `HasAlarm=FALSE`, `Text=''`, `Index=0`, `Count=0` | `💻 AUTO` | <small>§4bis</small> |

---

## 🎯 1. Principe

L'IHM et le PLC partagent les **memes structures**.

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | `GVL_IHM` est le point d'echange IHM. |
| 🧩 Meme DUT | Producteur PLC et ecran utilisent la meme structure. |
| 🔒 Pas d'internes | L'IHM ne lit ni n'ecrit les variables internes des FB. |
| ✍️ Producteur unique | Chaque champ `State` a un seul ecrivain PLC. |
| 🎮 Commandes maintenues ou fronts | Les impulsions sont consommees sur front ; les maintenues gardent leur semantique. |

Pas de liste exhaustive de variables dans ce document.

---

## 🌐 2. Frontiere `GVL_IHM`

Domaines exposes a minima :

| Domaine | Structure |
|---|---|
| 🪝 Treuil M1 | `M1TreuilRetenue : ST_WinchHMI` |
| 🪝 Treuil M2 / Benne | `M2TreuilBenne : ST_WinchHMI` |
| ⚖️ Synchro | `M1M2Sync : ST_SyncHMI` |
| 🕹️ Joystick | `JOY1Joystick : ST_JoystickHMI` |
| 🎚️ Modes | `Modes : ST_ModesHMI` |
| ↔️ Translation | `TranslationM3 : ST_TranslationHMI` |
| 🔄 Cycle | `Cycle : ST_CycleHMI` |
| 🪨 Assistants | `DredgingAssist : ST_DredgingAssistHMI` |
| 📡 Reseau | `Network : ST_NetworkDiagHMI` |
| 🌐 Commun | `Commun : ST_CommunHMI` |

La reference des champs est le code actif des DUT.

---

## 🧱 3. Structures par domaine

Convention cible :

```text
Cmd    → IHM → PLC
State  → PLC → IHM
Cfg    → reglage borne / persiste
Bypass → maintenance consciente, si justifie
Test   → banc seulement, si justifie
Safety → diagnostics safety publies, si separes
```

| Sous-structure | Role |
|---|---|
| 🎮 `Cmd` | Demandes operateur. |
| 🚦 `State` | Etats, mesures, diagnostics produits par le domaine. |
| 🔧 `Cfg` | Reglages. Bornage PLC obligatoire. |
| 🛠️ `Bypass` | Degradations de maintenance visibles. |
| 🧪 `Test` | Stimuli de banc, jamais en production. |

Le mapping, la persistance et d'eventuels agregats restent **TBD**. Ils ne justifient pas automatiquement un programme CFC.

---

## 💬 4. Bandeau d'information et messages opérateur

Pour éviter toute ambiguïté de conduite et assister l'opérateur en temps réel (en exploitation comme en simulation/maintenance), l'IHM dispose d'un bandeau structuré en **4 champs de texte dédiés** à responsabilités disjointes :

```mermaid
flowchart LR
    subgraph SOURCES ["📊 Sources Métier Typées (POU Procédés)"]
        S1["⚙️ Modes & Contexte<br><i>Auth.Mode, SimActive</i>"]
        S2["🔄 Cycles & Séquences<br><i>FB_Cycle, FB_DiveSearch</i>"]
        S3["🛡️ Dérogations & Bypass<br><i>FB_Safety_*, Retain</i>"]
        S4["🎮 Arbitrage Consignes<br><i>ActionId, JoyNeutral</i>"]
    end

    subgraph FORMATTER ["🧠 PRG_07_Supervision"]
        BF["<b>FB_Hmi_BannerFormatter</b><br>• Concaténation normalisée<br>• Arbitrage des priorités<br>• Filtrage anti-clignotement"]
    end

    subgraph BANNER ["🖥️ IHM Opérateur (GVL_IHM.Banner)"]
        direction TB
        B1["<b>1. GlobalContextText</b> (STRING 80)<br><code>[RÉEL/SIMU] [MODE] [COUPLAGE]</code>"]
        B2["<b>2. SequenceProgressText</b> (STRING 120)<br><code>Macro: &lt;Cycle&gt; &gt; Sous-cycle: &lt;Étape&gt;</code>"]
        B3["<b>3. SpecialConditionText</b> (STRING 120)<br><code>ATTENTION: &lt;Dérogation / Bridage / Alerte&gt;</code>"]
        B4["<b>4. OperatorActionText</b> (STRING 120)<br><code>[ORGANE] &lt;Action physique&gt; &gt; &lt;Fin&gt;</code>"]
    end

    S1 --> BF
    S2 --> BF
    S3 --> BF
    S4 --> BF

    BF --> B1
    BF --> B2
    BF --> B3
    BF --> B4

    style BANNER fill:#f8fafc,stroke:#334155,stroke-width:2px
    style FORMATTER fill:#f0fdf4,stroke:#16a34a,stroke-width:2px
    style SOURCES fill:#f1f5f9,stroke:#64748b,stroke-width:1px
```

### 📋 4.1 Responsabilités des 4 champs

| # | Champ | Rôle / Responsabilité unique | Format / Grammaire | Exemples d'affichage |
|---|---|---|---|---|
| **1** | **`GlobalContextText`** *(Macro)* | Contexte d'exécution, mode de marche actif et sélection axes. | `[Contexte] [Mode] [Axes]` | • `[RÉEL] [SEMI-AUTO] [M1+M2 SYNCHRO]`<br>• `[SIMULATION] [MAINT_N2] [TREUIL M2 SEUL]` |
| **2** | **`SequenceProgressText`** *(Micro)* | Étape courante du cycle maître **ET** de la sous-séquence active (Kobold, arrachage, homing). | `Macro: <Étape> > Sous-cycle: <Sous-étape>` | • `Cycle: DESCENTE > Kobold: 02_IMMERSION_SURFACE`<br>• `Homing: M1_RECHERCHE_INDEX_HAUT` |
| **3** | **`SpecialConditionText`** *(Dérogations)* | Régimes dérogatoires de maintenance, sécurités neutralisées, bridages actifs (*vide si nominal*). | `ATTENTION: <Type> : <Détail>` ou `INFO: <Type> : <Détail>` | • `ATTENTION: DÉROGATION : Butées logicielles M2 inactives`<br>• `INFO: BRIDAGE : Palier 1 forcé (Désynchronisme 0.4m)` |
| **4** | **`OperatorActionText`** *(Action)* | Consigne d'action physique attendue immédiatement du conducteur. | `[Organe] <Verbe d'action> > <Condition de fin>` | • `[JOYSTICK] Pousser Y- (Descente) > Attendre contact fond`<br>• `[PUPITRE] Appuyer sur Bouton HOMING M2` |

### 🧩 4.2 Principes de génération & Typage fort
* **Pas de manipulation de texte dans les FB procédé** : Les FB métier (`FB_Cycle`, `FB_DiveSearch`, `FB_Safety_Winch`, etc.) publient exclusivement des états typés (`E_CycleStep`, `E_DiveSearchState`, `ActionId : WORD`, flags booléens de bypass).
* **Arbitre central dans `PRG_07_Supervision`** : Le POU `PRG_07_Supervision` instancie un formateur dédié (`FB_Hmi_BannerFormatter`) qui assemble les 4 champs selon les priorités machine et met à jour `GVL_IHM.Banner`.
* **Séparation stricte avec les alarmes** : Les alarmes et pannes restent publiées dans `Error`/`ErrorId` et traitées par le gestionnaire d'alarmes / journal de supervision IHM. Le bandeau d'information ne remplace pas le journal d'alarmes.

### 🧊 4.3 Stratégie anti-clignotement (décision 2026-08-17)

Le bandeau est recalculé à chaque scan (10 ms). Un signal qui oscille (ex. `SafeStopActive` qui
passe ON/OFF en boucle, warning transitoire) ferait **clignoter** le texte → illisible pour
l'opérateur. Stratégie **hybride** :

| Type de message | Traitement | Rythme |
|---|---|---|
| **Défaut** (latché + acquitté) | Affiché **immédiatement**, pas de délai | scan |
| **Warning / état** (peut disparaître) | **Maintien min** avant changement (TON ~500 ms) | anti-clignotement |

- **Champs concernés** : `OperatorActionText` et `SpecialConditionText` (les plus sujets à
  oscillation). `GlobalContextText`/`SequenceProgressText` changent moins souvent → pas de maintien.
- **Principe** : un message warning/état est **maintenu un temps minimum** (500 ms) avant de
  laisser le texte changer. Un signal qui oscille plus vite que 500 ms → texte stable. Un vrai
  changement → s'affiche après 500 ms max (acceptable pour un warning, jamais pour un défaut).
- **Défauts** : passent en direct (pas de maintien) — un défaut AU/puissance doit être visible
  immédiatement, sans latence.
- **Interlock `DirectionBlocked`** (décision revue 2026-08-17) : un mouvement **demandé** mais
  **bloqué** (permit absent) est traité comme un **défaut critique** → affiché **immédiatement**
  (pas de maintien). Justification : c'est une cause de **blocage de mouvement sécurité**, pas un
  simple état transitoire ; l'opérateur qui pousse un axe interdit doit comprendre tout de suite
  pourquoi la machine ne bouge pas. Le `DirectionBlocked` alimente donc `CriticalActionActive`
  au même titre que AU/puissance/SafeStop.
- **Implémentation** : le lissage est délégué au FB utilitaire **`FB_AntiFlickerText`** (un par
  champ anti-clignoté), qui prend `NewText` + `ForceInstant` (TRUE = direct) + `HoldTime`.
  `FB_Hmi_BannerFormatter` en instancie deux : `AntiFlickSpecial` (jamais critique) et
  `AntiFlickOperator` (`ForceInstant := CriticalActionActive`).
- **Seuil** : 500 ms par défaut (`CST_BannerHoldTime`), à calibrer sur site (REX terrain).

---

## 🔎 5. Troubleshooting

Le troubleshooting est une observation **lecture seule**.

| Regle | Exigence |
|---|---|
| 👁️ Observation | Affiche des structures publiques dans un ordre utile au debug. |
| 🚫 Ecriture | Aucune commande, config, bypass ou interlock. |
| 🧩 Source | Contrats publics des domaines, pas les internes FB. |

Type exact, programme eventuel et ordonnancement : **TBD**.

---

## ❓ 6. TBD

- Besoin ou non d'un programme ST de mapping/persistance.
- Contrat detaille des messages action/etat.
- Organisation finale troubleshooting.
- Eventuelle structure unique d'intention de conduite.

## 📚 Documents lies

- Partie 02 : frontieres IHM et troubleshooting.
- Partie 03 : contrats publics.
- Parties metier 04 a 14 : contenu semantique publie dans `State`/`Cmd`/`Cfg`.
- Code : `CODE/J_SUPERVISION/GVL_IHM.st` et `CODE/SUPERVISION/_TYPES/`.
