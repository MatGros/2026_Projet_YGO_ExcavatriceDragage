# Analyse Fonctionnelle - Partie 4 : Mode Semi-Auto & Sequenceur (v2.0)

> Role : definir le mode semi-automatique, son sequenceur et les petits cycles reutilisables.
> Les sorties physiques restent hors de ce document.

## 🧭 Sommaire

1. Principes
2. Petits cycles reutilisables
3. Cycle semi-auto
4. Synchronisation pendant les mouvements
5. Messages et diagnostics
6. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P04-001</code></nobr> | Relâchement homme-mort stoppe sans perte d'étape | `StartStop=FALSE`, étape inchangée | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P04-002</code></nobr> | Cycle produit des demandes, zéro sortie physique | Aucune Q/PDO écrite par `FB_Cycle` | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P04-003</code></nobr> | SafeStop domaine ➔ fige l'étape (hold sur) | Étape figée, pas de reprise auto | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P04-004</code></nobr> | Reprise après hold : Cause + Reset + nouvel ordre | 3 conditions nécessaires | `💻 AUTO` | <small>§1</small> |
| <nobr><code>TC-P04-005</code></nobr> | Intention maintenue sur Diving/Extraction | Descente/montée bloquées sans joystick | `⚡ SITE+AUTO` | <small>§2</small> |
| <nobr><code>TC-P04-006</code></nobr> | Pas d'asservissement continu de vitesse en synchro | Même commande M1/M2, pas de boucle fermée | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P04-007</code></nobr> | Seuil synchro 1 ➔ arrêt mouvement principal | M1/M2 stoppés, rattrapage dédié | `⚡ SITE+AUTO` | <small>§4</small> |
| <nobr><code>TC-P04-008</code></nobr> | Écart persistant ➔ escalade safety | `SafeStop`/`PowerCutOff` selon contrat | `💻 AUTO` | <small>§4</small> |

---

## 🧱 1. Principes

| Regle | Exigence |
|---|---|
| 🔄 Programme ST | `FB_Cycle` reste un sequencer ST a machine d'etat. |
| ✍️ Demandes seulement | Le cycle produit des demandes de mouvement, jamais des sorties physiques. |
| 🕹️ Presence operateur | Tant qu'un mouvement est commande, l'intention maintenue et l'homme-mort restent requis. |
| 🛑 Relachement | Relachement joystick/homme-mort ⇒ `StartStop=FALSE`, etape conservee, pas de reprise automatique. |
| 🛡️ SafeStop | Un `SafeStop` du domaine concerne place le cycle en hold sur. |
| 🔑 Reprise | Cause disparue + Reset sur front + nouvel ordre explicite. |
| 🧩 Reutilisation | Diving et Extraction sont des briques ST reutilisees en maintenance et en semi-auto. |

`StartStop=TRUE` signifie permission maintenue de mouvement, pas un go-to position mémorisé.

---

## 🪨 2. Petits cycles reutilisables

Ces briques ne sont **pas** des modes machine.

### 🌊 `FB_DiveSearch` — Diving / plongée Kobold

- Descend avec intention opérateur maintenue.
- **Sémantique et Séquence de détection Kobold (`M1_M2_KoboldContactFond_DI`)** :
  1. **Prêt à plonger (Hors de l'eau, ex. $\ge +1,0$ m)** : Capteur = `0`.
  2. **Immersion (Contact surface de l'eau, fenêtre $[-0,5\text{ m} ; +0,5\text{ m}]$)** : Front montant $\rightarrow$ Capteur passe à **`1`**.
  3. **Plongée dans l'eau libre** : Capteur retombe à **`0`**.
  4. **Toucher Fond (Arrivée au fond)** : Front montant $\rightarrow$ Capteur passe à **`1`** (détection réelle du fond).
- **Règle de validation du fond** : Le fond est validé si et seulement si l'état `1` (fond) intervient **APRÈS** la confirmation de la séquence complète (départ hors eau `0` $\rightarrow$ immersion `1` $\rightarrow$ eau libre `0`). Un signal `1` direct sans immersion préalable est rejeté comme incohérent.
- **Activation de la mesure (`M1_M2_KoboldMeasureEnable_DQ`)** : Doit être alimentée pendant toute la séquence. Sans activation ou sans front d'immersion validé autour de $0,0$ m, la descente est bloquée en défaut (T82).
- Publie une confirmation de fond valide.
- En anomalie : arrêt sécurisé demandé + diagnostic.

### ⛏️ `FB_ExtractionSequence` — Extraction
- S'active apres confirmation de fond valide, ou attestation manuelle explicite en maintenance.
- Ferme la benne via le domaine Benne.
- Remonte en phase de controle puis en phase nominale.
- En anomalie : hold sur + diagnostic.

Les deux briques consomment une **intention deja arbitree**. Elles ne lisent pas directement plusieurs sources et ne fusionnent pas de commandes.

---

## 🔄 3. Cycle semi-auto

Le cycle enchaine les manoeuvres de production a partir des briques unitaires.

```text
INIT
 → selection / deplacement position travail
 → Diving
 → Extraction
 → montee charge / egouttage
 → translation vidage
 → ouverture / retour travail
 → pret a reboucler
```

| Etat | Sens |
|---|---|
| 🟢 Avancement | Conditions d'etape valides + intention operateur maintenue si mouvement. |
| ⏸️ Attente operateur | Intention absente : etape conservee, pas de progression cachee. |
| 🟥 Hold sur | `SafeStop` domaine, defaut cycle, ou condition d'etape invalide grave. |
| 🔑 Sortie hold | Cause disparue + Reset front + nouvel ordre. |

Pendant une desynchronisation volontaire de benne, la surveillance de synchro nominale est suspendue. Elle reprend des que le mouvement redevient synchronise.

### TBD cycle
- Detail exact de chaque etape et transition.
- Conditions completes d'INIT et de redemarrage apres abandon.
- Compteur de prelevements : retention, evenement d'incrementation, reset.
- Seuils Kobold eau/fond et distances de controle.
- Cibles de translation et parametres d'approche.

---

## ⚖️ 4. Synchronisation pendant les mouvements

Aucun asservissement continu de vitesse n'est prevu.

| Situation | Comportement |
|---|---|
| 🟢 Nominal | M1 et M2 recoivent la meme commande maintenue. |
| 🟠 Seuil 1 depasse | Arret du mouvement synchronise principal. |
| 🔧 Rattrapage | Phase dediee pour rattraper l'axe en retard. |
| 🟢 Ecart reaccepte | Reprise possible du mouvement synchronise. |
| 🔴 Ecart persistant / arret non confirme | Escalade safety. |

### TBD synchro
- Rattrapage manuel ou automatique sous conditions.
- Seuils, temporisations et axe prioritaire de rattrapage.

---

## 💬 5. Messages et diagnostics

| Famille | Role |
|---|---|
| 🧭 Etat | Etape courante, busy/ready/error, diagnostics. |
| 🎮 Action attendue | Ce que l'operateur doit faire maintenant. |
| 🚨 Alarme | Portee par `Error` / `ErrorId`, jamais confondue avec un simple etat. |

Le format exact des messages est porte par la Partie 07.

---

## 📚 Documents lies

- Partie 02 : architecture et place du sequenceur — `FB_Cycle` est instancie dans `PRG_03_Modes_Cycle_CFC` (rang 03), qui reunit modes, autorisations et sequences. Il produit des demandes ; il ne commande aucune sortie.
- Partie 03 : contrats FB et precedence des arrets.
- Partie 05 : modes et droits.
- Partie 10/11/12 : treuils, benne, translation.
- Partie 01 : AU et coupure puissance.
