# 📋 Analyse Fonctionnelle — Partie 4 : Cycle & Séquenceur (v1.4)

> 🔧 **WINCH-CORE-01 (2026-07-21)** — La fin de `ASCENDING_LOADED` utilise désormais
> `CableLimitM1AscentM` (8,0 m par défaut), identique à la limite haute d'exploitation de
> `FB_Winch`. La cible homing/capteur haut 8,5 m ne sert plus à dériver ce seuil.
>
> **v1.4 — Décisions client cycle semi-auto (2026-07-18)** : toute commande de mouvement reste
> conditionnée par l'homme-mort joystick ; le relâchement met le cycle en attente sur son étape,
> puis une sollicitation valide reprend cette étape. La descente de recherche utilise le retour
> dédié du détecteur de fond Kobold, commandé par un contacteur de puissance dédié. Le mapping
> exact de ces deux E/S est désormais défini : `KoboldContactFond_DI` (%IX0.5) et
> `KoboldContactor_DQ` (%QX0.6). Aucun capteur existant, notamment le mou de câble, ne doit être
> réutilisé comme équivalent Kobold.
>
> 🛡️ **T43 (2026-07-18)** : pendant `CTRL_ASCENDING`, `FB_Cycle` compare les vitesses
> linéaires mesurées M1/M2. Un écart supérieur à `SpeedMismatchThresholdMps`, maintenu pendant
> `SpeedMismatchTimeout`, pose le bit4 `ErrorId` et place le cycle en `ERROR_HOLD`. Les deux
> paramètres valent zéro par défaut tant que les seuils métier ne sont pas définis (T45).

> **Version 1.3** — Nettoyage documentaire (audit doc) : la note TBD sur le détail fin de la
> séquence INIT (§2) était une remarque organisationnelle (décision D22 reportée) — remplacée par
> un renvoi court vers `DOC/PLAN_TASK_v1.0.md` §3 (T1). Aucun changement fonctionnel.
> **Version 1.2** — Renommage terminologique (demande utilisateur, 2026-07-02) : Godet→Benne,
> Translation→Translation — y compris l'étape `E_CycleStep.TRANSLATION_MOVE` renommée
> **`TRANSLATION_MOVE`** (préfixe I/O physique M3 inchangé).
> **Version 1.1** — Suite audit documentaire : le passage à une étape **sans mouvement** se fait
> par **`StartStop := FALSE`** (décélération normale, `Enable` reste actif) — **plus** par retrait
> d'`Enable` (`CoupeEnable` n'a jamais existé, voir Partie 2 v2.7). `ERROR_HOLD` est déclenché par
> `SafeStop` (bloc safety **métier** concerné), pas un signal global. Interlock `FB_WinchSync`
> **suspendue** explicitement pendant la phase benne (§3bis).
> **Version 1.0** — Définition du séquenceur semi-automatique : `E_CycleStep`,
> séquence d'initialisation, synchronisation des treuils, séquence frein,
> translation, cinématique benne et stratégie de rampes.
>
> 🔗 Dépend de : Partie 2 v2.7 (architecture), Partie 3 v1.3 (contrat FB), Partie 5 (modes).

---

## 🎯 0. Principe & Doctrine d'Exploitation

Le cycle est un **séquenceur linéaire (Grafcet)** : chaque étape correspond à une sous-action de la machine (déplacement M3, descente, contact fond, prise matière, montée, vidage).
- **Le cycle auto n'est qu'une surcouche du manuel** : Il enchaîne de manière sécurisée les briques unitaires (`FB_DiveSearch`, `FB_ExtractionSequence`) préalablement qualifiées et validées en mode Maintenance N1.
- **Guidage IHM Pas-à-Pas** : Chaque étape (`E_CycleStep`) transmet à l'IHM un **message d'instruction clair pour l'opérateur** (indiquant l'état courant et l'action/mouvement attendu de sa part).
- **Validation Joystick (Homme-mort)** : Même en semi-automatique/automatique, la génération physique des mouvements exige le maintien et l'action du joystick par l'opérateur.
- **Sortie du Mode Auto & Reprise** : En cas d'abandon ou de sortie du mode automatique vers le mode maintenance, **aucune reprise en cours de cycle n'est autorisée**. L'opérateur doit impérativement ramener la machine en **position initiale de départ (au-dessus de la trémie)** pour pouvoir relancer un nouveau cycle automatique.

⚠️ Le passage à une étape **sans mouvement** met **`StartStop := FALSE`** → **rampe de décélération normale** (`Enable` reste actif).

---

## 🔢 1. Énumération `E_CycleStep`

```codesys
TYPE E_CycleStep :
ENUM
  INIT                 := 0;   (* Vérifs cohérence états + sécurités, mise en position init *)
  WORK_POS_SELECT      := 1;   (* Choix opérateur pos travail 1/2 + déplacement validé joystick *)
  DESCENDING_OPEN      := 2;   (* Plongée benne déjà ouvert, M1+M2 synchro, asserv si dérive *)
  BOTTOM_TOUCH_WAIT    := 3;   (* Attente info BOOL capteur "fond touché" *)
  SYNCHRO_ADJUST       := 4;   (* Désynchro M2 petite vitesse (offset X) → fermeture benne *)
  CTRL_ASCENDING       := 5;   (* Remontée lente de contrôle (risque relâchement si benne mal fermé) *)
  ASCENDING_LOADED     := 6;   (* Après X m param., remontée charge rampe + vitesse ∝ joystick *)
  DRAINING_PAUSE       := 7;   (* Égouttage temporisé (durée RETAIN) + message opérateur *)
  TRANSLATION_MOVE     := 8;   (* Déplacement pont vers vidage, validation + vitesse joystick *)
  DESCENDING_OPEN_DUMP := 9;   (* Descente arrêt position param. + demande user → ouverture benne (M2 inverse X) *)
  RETURN_WORK_POS      := 10;  (* Retour position travail, remontée treuils synchro *)
  READY                := 11;  (* Cycle terminé, prêt à reboucler *)
  ERROR_HOLD           := 12;  (* Arrêt sûr figé sur défaut (SafeStop du métier concerné) — sortie par reset + maintenance *)
END_ENUM
END_TYPE
```

> 📌 `ERROR_HOLD` n'est pas une étape « normale » : c'est l'état de repli atteint dès qu'**un**
> `SafeStop` (du bloc safety métier impliqué dans l'étape en cours) est actif. La reprise exige
> cause disparue + reset (front) + nouvel ordre explicite (`StartStop`) — jamais de redémarrage
> automatique (voir Partie 3 §Reset).

### Transitions nominales

```
INIT ──(états cohérents)──► WORK_POS_SELECT ──(position atteinte)──► [FB_DiveSearch] (DESCENDING_OPEN → BOTTOM_TOUCH_WAIT)
[FB_DiveSearch].Done ──(Fond Touché)──► [FB_ExtractionSequence] (SYNCHRO_ADJUST → CTRL_ASCENDING)
[FB_ExtractionSequence].Done ──► ASCENDING_LOADED ──(haut atteint)──► DRAINING_PAUSE
DRAINING_PAUSE ──(tempo + validation)──► TRANSLATION_MOVE ──(position vidage)──► DESCENDING_OPEN_DUMP
DESCENDING_OPEN_DUMP ──(benne ouvert)──► RETURN_WORK_POS ──(position travail)──► READY ──► (reboucle) DESCENDING_OPEN
[à tout instant] SafeStop (bloc safety métier concerné par l'étape en cours) ──► ERROR_HOLD
```

> 💡 **Non-Duplication du Code & Réutilisation** : Le Cycle Automatique ne réinvente pas la séquence de plongée et de prélèvement. Il appelle directement en cascade les deux sous-programmes **`FB_DiveSearch`** (étapes `DESCENDING_OPEN` à `BOTTOM_TOUCH_WAIT`) puis **`FB_ExtractionSequence`** (étapes `SYNCHRO_ADJUST` à `CTRL_ASCENDING`).

---

## 🧭 2. Séquence d'initialisation (INIT)

> 📌 Suivi : voir `DOC/PLAN_TASK_v1.0.md` §3 (T1) pour le détail fin restant à arrêter. Le squelette
> ci-dessous fixe les vérifications **sûres et vérifiées** attendues.

`INIT` doit garantir un état machine **cohérent et vérifié** avant d'autoriser le cycle.

```
INIT — sous-états :
  1. Vérifier Translation en position d'init
       → capteur BOOL dédié (pas besoin de codeur)
       → si absent : commande petite vitesse pour l'atteindre (validation joystick)
  2. Vérifier état benne : FB_Bucket retourne une info SÛRE et vérifiée (ouvert attendu)
       → si incohérent (mémoire RETAIN vs codeurs) : blocage + demande maintenance
  3. Vérifier position treuils M1/M2 (position haute attendue, benne ouvert)
       → info fournie par des FB qui CONTRÔLENT et VALIDENT (pas une lecture brute)
       → si non conforme : demande déplacement manuel petite vitesse pour atteindre l'état
  4. Demande de vérification VISUELLE opérateur sur IHM (confirmation humaine)
  5. Tous critères OK ──► WORK_POS_SELECT
```

🧭 Principe : chaque condition d'init s'appuie sur une **information sûre et vérifiée** émise
par les FB concernés (codeurs validés, capteurs filtrés), jamais sur une donnée brute volatile.
Une **confirmation visuelle IHM** est prévue (sécurité supplémentaire au démarrage).

---

## ↕️ 3. Synchronisation des treuils (`FB_WinchSync`)

Lorsqu'on **plonge ou remonte** sans bouger l'ouverture benne, les deux treuils doivent
**partir ensemble** et tenir **la même vitesse**. Les codeurs mesurent l'écart de position ;
en cas de dérive, on régule.

### Principe de régulation

```
À chaque cycle (FB_WinchSync, actif hors phase benne — voir §3bis) :
  ΔPos := |PosM1 − PosM2|            (* écart position via codeurs *)
  ΔVit := |VitEstM1 − VitEstM2|      (* dérive vitesse estimée — pas de mesure courant *)

  1. Démarrage : M1 et M2 reçoivent Enable + StartStop + même consigne vitesse (synchro).

  2. Si ΔPos AUGMENTE :
       → identifier l'axe trop rapide
       → le RALENTIR via ses contacteurs de paliers, selon une RAMPE définie
       → l'autre axe garde sa consigne
       (régulation par paliers : pas de variateur, on agit sur les relais de vitesse)

  3. Si ΔPos > SEUIL_ARRET (param. IHM) :
       → ARRÊT des deux treuils (StartStop := FALSE, rampe normale)
       → repositionnement en PETITE VITESSE jusqu'à ΔPos < tolérance
       → TANT QUE le joystick reste sollicité (homme-mort maintenu, présence opérateur) :
            reprise AUTONOME de la *rampe de vitesse* des deux treuils
            (⚠️ "autonome" = la régulation rétablit seule la vitesse ; ce n'est PAS un
             mouvement sans opérateur — relâcher le joystick arrête le mouvement)

  4. Estimation d'effort (déséquilibre charge) :
       → un benne mal ouvert/fermé répartit mal le poids sur les 2 treuils
       → FB_WinchSync surveille aussi la vitesse de déplacement par les codeurs
       → si un treuil "force" (Δ hors plage param.) : signalisation IHM,
         voire arrêt des mouvements + demande d'action MAINTENANCE
```

> 🔧 **Pas de mesure de courant** sur les treuils (contacteurs + disjoncteurs uniquement).
> Le « forçage » est **déduit** de Δposition / Δvitesse, pas mesuré directement.

### 3bis. Interlock benne ↔ synchro (v1.1)

⚠️ **`FB_WinchSync` est suspendue pendant la phase benne** (`SYNCHRO_ADJUST` en fermeture,
`DESCENDING_OPEN_DUMP` en ouverture) : ces étapes désynchronisent **volontairement** M2 (offset
`OffsetClose`/`OffsetOpen`, voir §6) et **M1 ne bouge pas**. Il n'y a donc **aucun conflit** entre
la désynchro benne et la surveillance synchro : pas de mouvement M1 pendant la phase benne = rien
à synchroniser, la suspension est **automatique et sans risque** (ce n'est pas un override N2, cf.
Partie 5, mais une conséquence directe de l'absence de mouvement M1 durant ces étapes).

`FB_Cycle` réactive `FB_WinchSync` dès la sortie de ces étapes (retour à un mouvement synchrone
M1+M2 : `CTRL_ASCENDING`, `RETURN_WORK_POS`, etc.).

### Seuils (paramètres IHM, valeurs par défaut dans le FB)
| Paramètre | Rôle | Défaut indicatif |
|-----------|------|------------------|
| `SyncWarn` | Écart d'alerte (signalisation) | 0.5 m |
| `SyncStop` | Écart d'arrêt + repositionnement | 1.5 m |
| `ForceImbalance` | Déséquilibre vitesse → « un treuil force » | ~10 % |

> `FB_WinchSync` est **actif** dès que M1 et M2 sont censés bouger ensemble (au minimum pour
> informer), **suspendu automatiquement** en phase benne (§3bis). En maintenance N2, son
> contrôle peut en outre être **désactivé volontairement** par l'opérateur (codeur mort, etc.) —
> voir Partie 5.

---

## 🪨 3ter. Briques Métier Autonomes Prélèvement (`FB_DiveSearch` & `FB_ExtractionSequence`)

> ℹ️ **Indépendance des FB & Découpage** : Les deux Function Blocks ci-dessous sont des **briques applicatives autonomes** (valables et utilisables aussi bien en **Maintenance N1/N2** qu'en **Cycle Automatique**). Elles sont documentées ici dans la Partie 4 car cette section centralise l'analyse fonctionnelle de toutes les cinématiques de prélèvement sous-marin.

```
┌────────────────────────────────────────────────────────┐
│ 1. FB_DiveSearch (Plongée / Recherche Fond Kobold)    │
│    - Immersion eau & contrôle benne ouverte            │
│    - Détection "Fond Touché" (perte signal Kobold)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Succès (Fond Touché = TRUE)
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. FB_ExtractionSequence (Extraction & Remontée)       │
│    - Fermeture benne (Désynchro M2 / Offset)           │
│    - Remontée de contrôle petite vitesse (Test effort) │
│    - Transition vers montée nominale pleine vitesse    │
└────────────────────────────────────────────────────────┘
```

---

### 🔒 Conditions Préalables de Démarrage & Interlocks (Verrouillage de Sécurité)

Afin d'éviter tout démarrage intempestif ou incohérent si l'opérateur active une option au milieu d'une mauvaise manœuvre manuelle, **chaque FB exige le respect strict de ses conditions initiales avant d'autoriser le démarrage du mouvement** :

1. **Conditions Préalables `FB_DiveSearch`** :
   - **Benne OUVERTE** (`FB_Bucket.IsOpen = TRUE`) : Interdiction absolue de démarrer la plongée si la benne est fermée.
   - **Position initiale valide** : Câble en zone haute / hors d'eau (ex: altitude > 4,0 m).
   - **Capteur Kobold au repos** (`FALSE`) avant immersion.
   - *Si une condition manque* : Le FB se verrouille (`Ready := FALSE`), interdit tout mouvement automatisé et affiche un message de blocage à l'IHM (*"Plongée impossible : benne non ouverte"*). **L'opérateur est alors contraint de décocher l'option pour repasser en Mode Manuel Pur et manœuvrer librement au joystick pour remettre la machine en position sûre**.

2. **Conditions Préalables `FB_ExtractionSequence`** :
   - **État "Fond Touché" Valide** (`BottomTouchConfirmed = TRUE`) : Délivré automatiquement par `FB_DiveSearch` à l'atteinte du fond.
   - **Exception Maintenance** : Si l'opérateur coche uniquement *Extraction Seule*, il doit explicitement valider un bouton IHM *"Benne au fond en position"* pour attester que la benne repose au sol.
   - **Benne non déjà fermée** : Vérification de l'état initial.
   - *Si une condition manque* : Le FB refuse d'exécuter la fermeture/remontée (*"Extraction impossible : benne non positionnée au fond"*). **L'opérateur doit décocher la brique pour repasser en Mode Manuel Pur s'il souhaite fermer ou remonter la benne manuellement à sa guise**.

---

### 🌊 Brique 1 : `FB_DiveSearch` (Recherche & Plongée Fond Kobold)
- **Rôle Métier** : Gère la plongée, la surveillance d'immersion eau et la détection du fond de carrière via le capteur Kobold (`KoboldContactFond_DI` %IX0.5, contacteur %QX0.6).
- **Conditions & Déroulement** :
  1. Exige impérativement les conditions préalables ci-dessus (Benne OUVERTE).
  2. Vérifie capteur ouvert (`FALSE`) au-dessus de l'eau (altitude > 4.0 m).
  3. Valide le passage à l'état immergé (`TRUE`) à la traversée de la surface d'eau.
  4. Détecte le **"Fond Touché"** au moment où la sonde se détend en touchant le sol ➔ le signal repasse à `FALSE`.
- **Issues de la brique** :
  - **`Done` / Succès** : Fond touché validé ➔ Émet l'autorisation d'extraction (`BottomTouchConfirmed = TRUE`).
  - **Limites / Arrêt** : Atteinte de la limite légale de profondeur (`LimitLegalDepthM`) avant le fond, ou anomalie capteur ➔ Interdiction de descente (`StartStop := FALSE`), alarme guidée IHM.

---

### ⛏️ Brique 2 : `FB_ExtractionSequence` (Fermeture Benne & Remontée Contrôlée)
- **Rôle Métier** : Séquence le fermage de la benne et la remontée sécurisée initiale.
- **Conditions & Déroulement** :
  1. **Condition d'activation** : Nécessite les conditions préalables ci-dessus (`BottomTouchConfirmed = TRUE`).
  2. **Fermeture Benne** : Pilotage du décalage treuil M2 (offset fermeture `SYNCHRO_ADJUST`).
  3. **Remontée de Contrôle Petite Vitesse (PV)** : Remontée initiale à 20 % de vitesse pour vérifier l'absence d'objets coincés, de sur-effort ou de déséquilibre critique entre codeurs M1/M2.
  4. **Montée Pleine Vitesse** : Une fois la stabilité confirmée sur la hauteur de contrôle (`CtrlAscentDistM`), bascule sur la montée chargée nominale.

---

### 🎛️ Architecture Maintenance (N1 / N2) & Mode Manuel Pur par Défaut

En mode Maintenance, le comportement des sous-programmes s'articules autour du mode manuel fondamental :

1. **Mode Manuel Pur (Aucune option sous-programme cochée)** :
   - Si les briques `FB_DiveSearch` et `FB_ExtractionSequence` sont décochées par l'opérateur, la machine fonctionne en **mode manuel pur**.
   - **Mouvements & Pilotage** : L'opérateur pilote librement et manuellement les descentes/remontées au joystick.
   - **Maintien Général des Sécurités** : Toutes les sécurités fonctionnelles et matérielles du système restent pleinement **actives et opérationnelles** (exemples non exhaustifs : longueur max de câble `MaxCableM`, butées d'arrêt haute, limite légale de profondeur `LimitLegalDepthM`, chaîne AU / `PowerCutOff`, surveillance thermique/freins, etc.), à moins qu'elles ne soient explicitement désactivées par un autre mécanisme ou un débrayage spécifique (ex: overrides N2).
   - **Fonctionnalités Désactivées** : Seules les briques logicielles d'assistance et d'automatisme (contrôle d'immersion Kobold, arrêt automatique au fond, séquence de fermeture automatique et remontée de contrôle automatisée) sont décochées et inhibées.

2. **Valeur par Défaut des Variables (`TRUE` par initialisation PLC)** :
   - **Initialisation déclarative** : Les variables de commande `EnableDiveSearch` et `EnableExtractionSequence` ont simplement leur valeur d'initialisation par défaut réglée à **`TRUE`** dans l'automate.
   - **Comportement** : Il n'y a pas d'écriture forcée cyclique à `TRUE` lors de la bascule en Maintenance N1. Les cases à cocher restent dans l'état où l'opérateur les a laissées sur l'IHM, tout en garantissant un démarrage initial sécurisé à `TRUE` à la mise sous tension.
   - **Objectif Opérateur** : Cela permet d'exécuter la fonction principale de prélèvement (descendre, chercher le fond, prélever, fermer et remonter en sécurité) **facilement et sans se prendre la tête**, tout en gardant la liberté de décocher l'une ou l'autre variable si besoin.

3. **Sélection des Options en Maintenance** :
   - **`EnableDiveSearch` (Activé par défaut)** : Gère la plongée sous eau avec arrêt automatique net au fond (`Fond Touché`).
   - **`EnableExtractionSequence` (Activé par défaut)** : Autorise la fermeture automatique/remontée de contrôle dès que le fond est touché. Si seule cette option est cochée, l'opérateur peut poser la benne manuellement puis lancer l'extraction.
### 🕹️ Conditionnement Joystick (Homme-Mort) & Guidage Textuel IHM

⚠️ **Règle Absolue de Sécurité** :
- **Aucun mouvement autonome sans opérateur** : Même lorsque `FB_DiveSearch` ou `FB_ExtractionSequence` sont activés (en Maintenance ou en Auto), la génération physique du mouvement exige impérativement la **sollicitation et le maintien du joystick par l'opérateur (Homme-Mort)**. Si l'opérateur relâche le joystick (`JoystickYNeutral = TRUE`), le mouvement s'arrête instantanément en rampe propre (`StartStop := FALSE`), et la séquence se met en attente sur l'étape courante.
- **Messages Guidés à l'IHM (`StepMessage`)** : À chaque sous-étape de `FB_DiveSearch` et `FB_ExtractionSequence`, l'automate émet un **message texte d'instruction clair et dynamique** sur l'écran IHM. L'opérateur sait exactement :
  1. Quel est l'état courant du système (ex: *"Séquence 1 : Recherche Fond Kobold en cours"*).
  2. Ce que l'automate attend de lui (ex: *"Maintenir le joystick vers le bas pour continuer la descente"* ou *"Fond touché ! Pousser le joystick vers le haut pour lancer l'extraction"*).
  3. L'anomalie éventuelle s'il y a un blocage (ex: *"Action stoppée : Benne fermée interdit la descente sous l'eau"*).

### 🚫 Gestion des Anomalies & Interdiction de Descente
Si à un moment quelconque de la séquence une incohérence est détectée (ex: benne fermée, absence du signal eau lors du passage sous la surface, signal perdus prématurément hors plage, ou capteur inactif au-dessus de l'eau) :
- **Interdiction immédiate de la descente** (`StartStop := FALSE` ➔ rampe de décélération propre).
- **Arrêt sécurisé de la machine** (verrouillage des contacteurs).
- **Émission d'un message d'alarme guidé à l'opérateur sur l'IHM** indiquant l'anomalie exacte (ex: *"Défaut Kobold : benne non ouverte"* ou *"Incohérence immersion eau Kobold"*).

---

### 3quater. Remontée de Sécurité & Stabilisation après fermeture
Après détection sûre du fond (perte du signal Kobold valide), M1 et M2 remontent ensemble à petite vitesse jusqu'à une position supérieure à `LimitLegalDepthM` avec une marge de 0,5 m. Si la limite légale est atteinte avant le contact Kobold, le cycle passe en `ERROR_HOLD`.

### 3quater. Stabilisation après fermeture de la benne (T36)

Après `SYNCHRO_ADJUST`, `CTRL_ASCENDING` constitue une étape de contrôle obligatoire :

- M1 et M2 remontent ensemble à petite vitesse (`20 %`) ;
- les deux positions absolues doivent dépasser `TouchPositionM + CtrlAscentDistM` ;
- l'écart entre codeurs doit rester inférieur ou égal à `CtrlAscentToleranceM` (`0,25 m` par défaut) ;
- `WinchSyncError` ou un écart supérieur à la tolérance provoque `ERROR_HOLD` ;
- un délai maximal `CtrlAscentTimeout` (`30 s` par défaut) évite toute attente infinie si un treuil,
  un câble ou la benne est bloqué ;
- la montée chargée (`ASCENDING_LOADED`) n'est autorisée qu'après validation simultanée des deux
  codeurs et maintien de l'homme-mort ;
- elle s'arrête à `M1_CablePosM >= CableLimitM1AscentM` (8,0 m par défaut), puis passe à
  `DRAINING_PAUSE`.

Le défaut de stabilisation est signalé par le bit 3 de `ErrorId`. Une reprise exige la disparition
de la cause, un acquittement et un nouvel ordre opérateur.

## 🛑 4. Séquence frein (`FB_Brake`)

Le frein est à **manque de courant** (colle au repos = maintien charge). Le séquencement
doit intégrer les **temps physiques** des contacteurs et du moteur, sinon : fermeture du
frein en plein mouvement (usure/casse) ou relâchement trop tôt (charge qui retombe → à-coup).

### Au démarrage (arrêt → mouvement)
```
1. Commande automate moteur (contacteur sens + palier), StartStop := TRUE
2. Attente : temps contacteur de puissance (fermeture) + magnétisation moteur
3. SEULEMENT ALORS : ouvrir le frein (relâche)
   → si on relâche trop tôt, la charge retombe par son poids → à-coup
```

### À l'arrêt (mouvement → arrêt)
```
1. Couper la commande de mouvement : StartStop := FALSE (arrêt demandé, rampe normale)
   ou SafeStop actif (défaut process du métier, rampe rapide) — Enable reste actif dans les 2 cas
2. Le moteur ne s'arrête PAS instantanément ; le contacteur met X ms à s'ouvrir
3. Attendre la décélération / ouverture contacteur AVANT de fermer le frein
   → si on ferme le frein en plein mouvement → usure/casse mécanique
4. Fermer le frein (collage)
```

### Double vérification (retour d'état contacteurs)
`FB_Brake` est **autonome** : il prend des informations d'autres FB, **mais** réalise une
**double vérification avec les retours d'état des contacteurs de puissance**. Incohérence
commande vs feedback (au-delà d'un timeout) → `ErrorId` (bit dédié) → état ERROR.

### Paramètres (RETAIN, réglage mise en service)
| Paramètre | Rôle |
|-----------|------|
| `DelayMagnetise` | Délai magnétisation moteur avant ouverture frein |
| `DelayContactClose` | Temps fermeture contacteur de puissance |
| `DelayMotorDecel` | Délai décélération/ouverture contacteur avant collage frein |
| `FeedbackTimeout` | Délai max cohérence feedback contacteur sinon défaut |

---

## ↔️ 5. Translation (`FB_Translation`)

Le pont se déplace vers une **position cible** (travail 1, travail 2, ou vidage) via le
variateur AC600. L'opérateur valide et dose la vitesse au joystick.

### Approche & arrêt
```
Exemple : opérateur a choisi "position 2" à l'IHM, puis avance au joystick.
  1. La translation passe la position 1 SANS ralentir (ce n'est pas la cible).
  2. À l'approche de la position 2 :
       → après un TEMPS ESTIMÉ de déplacement (paramètre réglable),
         le mouvement RALENTIT à petite vitesse (PV).
  3. Arrêt EXACT sur le CAPTEUR de position (dérive négligeable),
       même si le joystick reste actionné (StartStop := FALSE à l'arrivée).
  4. Message opérateur "en position" si : capteur présent
       ET frein à manque de courant fermé mécaniquement.
```

> Le variateur AC600 fournit mot de commande/état, vitesse estimée et consigne fréquence,
> mais **pas** la mesure de courant. Le défaut variateur est lu via son mot d'état.

### Paramètres (RETAIN)
| Paramètre | Rôle |
|-----------|------|
| `ApproachTime` | Temps estimé avant déclenchement du ralentissement |
| `ApproachSpeed` | Vitesse réduite d'approche (PV) |
| `CaptorDebounce` | Filtrage capteur de position d'arrêt |

---

## 🪣 6. Cinématique benne (`FB_Bucket`)

Le benne n'a **pas de moteur propre** : il s'ouvre/ferme par **désynchronisation de M2**
(décalage de position relatif à M1, **M1 immobile** — voir §3bis).

### Fonctionnement
```
Fermeture (SYNCHRO_ADJUST) : M2 se décale de OffsetClose (X m ou points) → mâchoires se ferment
Ouverture (DESCENDING_OPEN_DUMP) : M2 déplacement INVERSE de OffsetOpen → mâchoires s'ouvrent
```

Les offsets sont des **paramètres accessibles en Maintenance N2** (réglés à la mise en service).

### Disponibilité de la fonction benne
- **En cycle** : ouverture/fermeture aux étapes prévues.
- **En maintenance** : on peut demander une ouverture/fermeture à une position donnée
  **à condition** que la sécurité ne soit pas remise en cause (longueur câble max, positions
  extrêmes, limites codeur…). Si les conditions ne sont **pas** remplies, la seule possibilité
  est de passer en **Maintenance N2** pour commander les treuils indépendamment, avec
  possibilité de **désactiver les contrôles synchro et benne** (message IHM).

### Mémoire & contrôle au boot
```
RETAIN : ST_BucketState (IsOpen, LastPosM2_Open, LastPosM2_Close)

Au démarrage :
  comparer position M2 réelle vs mémoire
  si écart > seuil ET incohérence état (ex: "fermé" annoncé mais position d'ouvert) :
     → signaler "état benne non sûr / non correct"
     → forcer Maintenance N1 + vitesse réduite pour remettre en ordre
```

> ⚠️ Un état benne mal défini répartit mal le poids total sur les deux treuils.
> `FB_WinchSync` peut alors détecter qu'un treuil force (contrôle vitesse via codeurs)
> et signaler/arrêter (voir §3), **une fois la phase benne terminée et la synchro réactivée**.

---

## 🎚️ 7. Stratégie de rampes & vitesse joystick

Le joystick commande une vitesse **de l'arrêt (vitesse min) jusqu'à la vitesse max AUTORISÉE
par le mode/l'étape**. Appuyer à fond en mode « petite vitesse » ne donne que la petite vitesse.

### Changement de plafond de vitesse entre étapes
```
Étape A : vitesse max autorisée = PV (petite vitesse)
  → joystick à fond ⇒ axe rampe jusqu'à PV seulement.

Étape B : vitesse max autorisée = GV (grande vitesse)
  → pour éviter une accélération brutale "sans rien comprendre",
    on DEMANDE à l'opérateur de revenir à une position joystick cohérente
    avant d'autoriser la montée en GV.
```

### Rampes internes (anti à-coups / anti-pompage)
- Toute consigne passe par une **rampe** (montée/descente) pour éviter les à-coups mécaniques
  et les oscillations (pompage), en particulier sur la charge.
- **Arrêt demandé** (`StartStop := FALSE`, fin d'étape ou opérateur) : rampe de **décélération
  normale** (même profil que l'accélération).
- **Défaut process** (`SafeStop` du bloc safety métier concerné : perte codeur, bus, joystick…) :
  arrêt sur une **rampe plus rapide mais non destructive** (`Enable` reste actif le temps du
  ralentissement maîtrisé, pas de coupure brutale), puis collage des freins (voir §4) — voir
  aussi Partie 5 §Pertes/Défauts.

---

## 🖥️ 8. Interface IHM de test et d'exploitation

La source unique de commande et de diagnostic du cycle est `GVL_IHM.Cycle`.
Les commandes `CmdStart`, `CmdPause`, `CmdAbort` et `CmdReset` sont des impulsions
acquittées automatiquement par le PLC, même si la GVL est déclarée `RETAIN`.

La cible de travail reste portée par `GVL_IHM.TranslationM3.SelTarget` :
`2=P2` ou `3=P1`. Toute autre valeur au démarrage est refusée avec `ErrorId` bit 2.

Le mouvement du cycle est conditionné par `GVL_IHM.Cycle.MotionPermit`, issu de
l'homme-mort et du joystick Y. Au relâchement, les commandes treuil, translation,
benne et contacteur Kobold sont supprimées, tandis que l'étape est conservée.

Pour le banc de simulation, `GVL_IHM.Cycle.SimKoboldContactFond` pilote le retour
simulé ; en réel, le retour physique est `KoboldContactFond_DI` (%IX0.5) et la
commande contacteur est `KoboldContactor_DQ` (%QX0.6).

## 📚 Documents liés
- **Partie 2 v2.7** — Architecture (orchestration, `FB_WinchSync`, `SafeStop`/`StartStop`, IO).
- **Partie 3 v1.3** — Contrat FB (`E_State`, `ErrorId`, reset, `StartStop`/`SafeStop`).
- **Partie 5** — Modes & maintenance (overrides N2, limite légale `FB_Modes`, pertes/défauts).
- **Partie 6** — Conditionnement E/S.
