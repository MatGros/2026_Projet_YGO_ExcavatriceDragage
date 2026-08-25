# Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v2.1)

> Rôle : acquisition et conditionnement du geste opérateur (Hall CANopen → consignes d'axe).
> **Pas** un FB de mouvement : pas de `SafeStop` / pas de pilotage Q.
> Source code : `CODE/D_JOYSTICK/FB_Joystick.st` · instance `PRG_02_Acquisition.instJoystick`.

## 🧭 Sommaire

1. Rôle et périmètre
2. Pipeline et composition
3. Interface et contrats
4. Homme-mort
5. Calibration et défauts
6. Intégration programme
7. IHM
8. Alertes et écarts
8bis. Suivi historique
8ter. TBD — Filtre par défaut et double rampe Joystick↔FB de mouvement
9. Documents liés

## 🎯 1. Rôle et périmètre

Producteur d'**intention** de conduite (pas un actionneur) : 2 axes bruts 0..10000 + 1 bouton
(nœud CANopen ou sim amont) + `ArmingPermit` externe ➔ `ST_Joystick_AxisCmd` X/Y +
`DeadmanArmed` + `ArmingPermitDenied` + miroirs maintenance. Ne fait pas : arbitrage mode,
limites machine, frein, `PowerCutOff`, Q physiques — **ni** la décision de qui a le droit
d'armer (`ArmingPermit` est calculé par l'appelant).

Profil AF03 : contrat **`standard`** (remonte des défauts — calibration, capteur hors plage,
perte bus — via `Status : ST_FbStatus`, socle `FB_FbStatus`).

### 🎯 Table des fonctions

Convention : `DOC/WFLOW/AUDITS/PRG02_20260824/DESIGN_TABLE_FONCTIONS_AF_v0.2.md`. `Réalisée par`
peut être un `FB`, un `PRG` (câblage de collage) ou un `gate` (script de vérification) — pas
seulement un FB. `Statut` saisi à la main tant que l'outillage d'extraction n'existe pas (T153-C).

| ID | Fonction | Description | Réalisée par | Criticité | TC couvrants | Statut |
|---|---|---|---|---|---|---|
| `F08.01` | Acquérir les axes bruts + bouton | Lit `RawX`/`RawY`/`RawButton` depuis le bus CANopen (ou l'image simulée) | `FB_Joystick` | C2 | — | ❌ |
| `F08.02` | Mettre à l'échelle proportionnellement | Convertit le compte brut ADC en % signé ±100, avec deadband centrée sur le neutre persistant | `FB_AxisScale` | C2 | <nobr><code>TC-P08-014</code></nobr> | ✅ |
| `F08.03` | Armer l'homme-mort par maintien | Appui continu `DeadmanArmHoldTime` (100ms) **et** `ArmingPermit=TRUE` au terme du maintien | `FB_Joystick` | **C4** | <nobr><code>TC-P08-002</code></nobr> | ✅ |
| `F08.04` | Désarmer sur neutre prolongé | Neutre tenu `NeutralHoldTime` (100ms), applicable seulement après `DeadmanArmGraceTime` (3s) écoulées depuis l'armement | `FB_Joystick` | **C4** | <nobr><code>TC-P08-004</code></nobr> | ✅ |
| `F08.05` | Désarmer sur perte de permission | `ArmingPermit=FALSE` ⇒ désarmement immédiat (niveau, pas front), axes à 0 | `FB_Joystick` | **C4** | <nobr><code>TC-P08-005</code></nobr>, <nobr><code>TC-P08-011</code></nobr>, <nobr><code>TC-P08-012</code></nobr> | ⚠️ *(logique FB testée ✅, mais producteur `ArmingPermit` câblé en dur `TRUE` en production — trou réel, voir §8 alerte 1 et Q1 `QUESTIONS_OUVERTES_PRG02_v0.1.md`)* |
| `F08.06` | Détecter un défaut capteur hors plage | `RawX`/`RawY` hors plage ⇒ arrêt (`SpeedRef=0`) + `ErrorId` bit1 (Warning) sur les 2 axes | `FB_Joystick` | C3 | <nobr><code>TC-P08-007</code></nobr> | ✅ |
| `F08.07` | Calibrer le neutre capteur | Bouton calibration mémorise le neutre si axes en zone [2000;8000], persistant au redémarrage, accessible depuis l'écran HMI | `FB_Joystick` | C2 | <nobr><code>TC-P08-006</code></nobr>, <nobr><code>TC-P08-009</code></nobr>, <nobr><code>TC-P08-010</code></nobr> | ⚠️ *(TC-P08-009/010 = type SITE, non exécutés automatiquement)* |
| `F08.08` | Interdire tout mouvement sans armement homme-mort | Gate combinant `AxisCmd*.StartStop AND DeadmanArmed` avant d'autoriser une commande treuil/translation | `PRG_04_Treuils_Benne` (**gate**, pas un FB) | **C4** | <nobr><code>TC-P08-008</code></nobr> | ✅ *(vérifié par `G375_check_deadman_arming_gate.py`, pas `TEST_AUTO_CI`)* |

---

## 🧪 Table des points de validation (Cas de Test — TC)

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P08-001</code></nobr> | Perte contacteur / CAN ➔ désarmer, annuler axes, et lever `Error` (`ErrorId` bit2, auto-effacé au retour) | `SpeedRef=0`, `DeadmanArmed=FALSE`, `Error=TRUE` | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P08-002</code></nobr> | Armement homme-mort par maintien `DeadmanArmHoldTime` (100ms) **ET** `ArmingPermit=TRUE` ; relâchement **avant** la fin du maintien annule la tentative (pas d'armement différé) | Tenu 100ms + permis ➔ armé / relâché avant ➔ `DeadmanArmed` reste `FALSE`, nouvel appui exigé | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-003</code></nobr> | ⛔ **RETIRÉ (v2.1)** — testait `DeadmanReconfEnable`/`DeadmanRearmTimeout` (reconfirmation périodique 10s), ports supprimés du FB. La sémantique « bouton relâché en mouvement » n'existe plus : le FB ne surveille plus le bouton après armement, seul le neutre prolongé désarme (§4). ID non réattribué (immutabilité `CODE_QUALITY_STANDARDS.md §0`). | — | — | <small>§4</small> |
| <nobr><code>TC-P08-004</code></nobr> | Neutre tenu `NeutralHoldTime` (100ms) après le délai de grâce `DeadmanArmGraceTime` (3s) désarme ; neutre bref ou pendant la grâce conserve l'armement | Armement conservé / perdu | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-005</code></nobr> | Retrait de `ArmingPermit` (niveau, pas front) désarme **immédiatement** — le FB ne connaît plus `Mode`/`BenneBusy` en interne, c'est l'appelant qui pilote `ArmingPermit` | `DeadmanArmed=FALSE` dès `ArmingPermit=FALSE` | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-006</code></nobr> | Calibration hors [2000;8000] ➔ alarme `ErrorId` bit0 (Fault, à acquitter) | Bit0 actif, `Reset` sur cause disparue | `💻 AUTO` | <small>§5</small> |
| <nobr><code>TC-P08-007</code></nobr> | `SpeedRef` signée [-100;+100] ; si `RawX`/`RawY` sort de la plage capteur (défaut/fil coupé) ⇒ arrêt (`SpeedRef=0`) + `ErrorId` bit1 (Warning), pas de commande à pleine vitesse (voir exemple §5bis) | `SpeedRef=0`, `ErrorId` bit1 actif | `💻 AUTO` | <small>§1, §2, §5bis</small> |
| <nobr><code>TC-P08-008</code></nobr> | Winch, Translation et Cycle exigent `DeadmanArmed` | ⚠️ gate câblé dans le PRG de collage, pas dans un FB — vérifié par `G375` (note ↓), pas par `test_fb_joystick.st` | `🔒 GATE` | <small>§6</small> |
| <nobr><code>TC-P08-011</code></nobr> | Retrait d'`ArmingPermit` (ex. fin de cycle benne) pendant un geste armé désarme **immédiatement**, sans attendre le neutre | `DeadmanArmed=FALSE` dès `ArmingPermit=FALSE`, même bouton relâché | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-012</code></nobr> | Maintien d'`ArmingPermit=TRUE` (ex. exception CLOSING Extraction) conserve l'armement même bouton relâché | `DeadmanArmed` reste `TRUE` tant que `ArmingPermit=TRUE` | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-013</code></nobr> | `ArmingPermitDenied` (sortie diagnostic) : `TRUE` pendant tout appui bouton alors que `ArmingPermit=FALSE`, `FALSE` sinon | `ArmingPermitDenied = RawButton AND NOT ArmingPermit` | `⬜ GAP` | <small>§4</small> |
| <nobr><code>TC-P08-014</code></nobr> | Mise à l'échelle **proportionnelle** sur valeurs intermédiaires (`RawX=9000`→80%, `RawY=300`→-94%), pas seulement correcte aux bornes 0/10000/neutre | `SpeedRef` exact ±0.01%, `Direction` cohérent | `💻 AUTO` | <small>§1, §2</small> |

> ⚠️ **TC-P08-008 — pourquoi ce n'est PAS un test de FB**
>
> Le gate qui interdit tout mouvement Winch tant que l'homme-mort du Joystick n'est pas armé
> n'est écrit **dans aucun `.st` de FB**. Il est câblé directement dans le PRG qui fait
> communiquer les deux : `PRG_04_Treuils_Benne.st`. Ni `FB_Joystick` (qui ignore l'existence de
> Winch, responsabilité unique), ni un futur `FB_Winch` (le gate n'est pas dans son interface) ne
> peuvent donc le prouver par un test qui les instancie isolément — `TEST_AUTO_CI` teste des FB,
> pas des PRG.
>
> | | Ce que ça vérifie | Comment | Où |
> |---|---|---|---|
> | <nobr><code>TC-P08-002/004/005</code></nobr> | `FB_Joystick` *produit* bien `DeadmanArmed` | Test dynamique (compile + instancie + assert) | `TEST_AUTO_CI`, `test_fb_joystick.st` |
> | <nobr><code>TC-P08-008</code></nobr> (ce point) | Le PRG *consulte* bien `DeadmanArmed` avant d'autoriser un mouvement | Recherche textuelle dans le vrai code de production | `G375_check_deadman_arming_gate.py` (`TOOLS/AGENT_WORKFLOW/scripts/`), lancé par `run_all_gates.py` |
>
> D'où le type `🔒 GATE` (ni `AUTO` ni `SITE`) : un mécanisme automatisé existe bien et tourne
> à chaque lot de code — ce n'est juste pas un test de `FB_Joystick`.

> ⚠️ **TC-P08-013 — `⬜ GAP`** : `ArmingPermitDenied` existe dans l'interface et est câblé
> (`ArmingPermitDenied := RawButton AND NOT ArmingPermit`), mais **aucun test** ne le vérifie
> dans `test_fb_joystick.st` — corrigé le 2026-08-25, cette ligne était précédemment marquée
> à tort `💻 AUTO`. À couvrir dans un prochain lot de tests.

---

## 2. Pipeline et composition

```text
Raw ─► FB_AxisScale ─► Homme-Mort (0 si non armé) ─► ST_Joystick_AxisCmd
         deadband raw
```

| Brique | Rôle |
|---|---|
| `FB_AxisScale` | Neutre + deadband (compte brut ADC) → % signé, borné ±100 |
| Homme-mort | Force la consigne à 0.0 si non armé (`DeadmanArmed = FALSE`) |

> 🔧 **`FB_Filter_PT1` retiré du pipeline** : le joystick est stable et ne doit **pas** être
> ralenti (aucun lissage). L'éventuel lissage de la consigne reste confié aux FB de mouvement
> aval si besoin. La fonction de filtrage PT1 est disponible en généraliste
> `CODE/A_COMMUN/FB_Filter` (réutilisable).

> 📌 **Architecture des rampes** : `FB_Ramp` n'est pas instancié dans `FB_Joystick`. La gestion
> des rampes d'accélération et de décélération est confiée exclusivement aux FB de mouvement aval
> (`FB_Winch`, `FB_Translation`) pour éviter le double-lissage et préserver la maîtrise directe du
> gradient de décélération lors des arrêts de sécurité (`SafeStop`).

`ST_Joystick_AxisCmd` :

| Champ | Sens |
|---|---|
| `Enable` | TRUE quand pipeline actif (`NOT RawOutOfRange AND ArmingPermit`) |
| `StartStop` | TRUE si `ABS(SpeedRef) > 0.1` |
| `SpeedRef` | % **signé** −100..+100 |
| `Direction` | −1 / 0 / +1 (seuil ±0,1) |

---

## 3. Interface publique (code réel, v2.1)

### Entrées (`VAR_INPUT`)

| Port | Rôle | Producteur actuel |
|---|---|---|
| `Enable` | Active la logique du bloc | `TRUE` fixe dans `PRG_02_Acquisition` |
| `Reset` | Acquittement défaut (front) | `FaultMachineReset_IHM` |
| `ArmingPermit` | **Seule** permission d'armement homme-mort — `FALSE` = armement bloqué **et** désarme immédiatement un geste déjà armé | `PRG_02_Acquisition.st:303` — ⚠️ **câblé en dur à `TRUE`** (« Câblage TEMPORAIRE », voir alerte §8) |
| `BusCanOpenOP` / `JoystickOP` | État présence nœud CAN / device esclave | `FB_Diag_CanOpen` |
| `RawX` / `RawY` | Valeur brute axe (0..10000) | `Acquisition.HwIn.Operator` |
| `RawButton` | État brut bouton homme-mort | `Acquisition.HwIn.Operator` |
| `BtnCalibrate` | Demande de recalage neutre | `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` |
| `DeadbandRaw` | Zone morte ADC brute (déf. 300) | `GVL_PERSISTENT` |
| `NeutralHoldTime` | Maintien continu au neutre avant désarmement (déf. `T#100MS`) | `PRG_02_Acquisition` (constante d'appel) |
| `DeadmanArmHoldTime` | Appui continu bouton requis pour armer (déf. `T#100MS`) | `PRG_02_Acquisition` (constante d'appel) |
| `DeadmanArmGraceTime` | Délai de grâce post-armement avant que le désarmement neutre puisse s'appliquer (déf. `T#3S`) | `PRG_02_Acquisition` (constante d'appel) |
| `RawOutOfRangeMargin` | Marge tolérance ADC autour des bornes [0..10000] avant défaut capteur (déf. 500) | `PRG_02_Acquisition` (constante d'appel) |
| `NeutralXMem` / `NeutralYMem` (`VAR_IN_OUT`) | Point neutre persistant | `GVL_PERSISTENT` |

🚫 **N'existent plus** (documentés en v2.0, retirés du code) : `Mode`, `BenneBusy`,
`PreserveArmingAfterBucket`, `DeadmanReconfEnable`, `DeadmanRearmTimeout`. Toute la logique de
« qui a le droit d'armer, et pourquoi » a été **extraite du FB** vers un port unique
(`ArmingPermit`) que l'appelant doit calculer.

### Sorties (`VAR_OUTPUT`)

| Port | Rôle |
|---|---|
| `AxisCmdX/Y` | Consignes normalisées |
| `Speed*Pct` / `Direction*` | Miroirs plats (maintenance) |
| `Button` | = `RawButton` (pas de filtre dédié) |
| `Neutral*Act` | Neutres actifs |
| `DeadmanArmed` | Geste armé |
| `AtNeutral` | TRUE si les 2 axes sont en zone morte |
| `ArmingPermitDenied` | 🆕 **Warning dédié** : `TRUE` pendant tout appui bouton alors que `ArmingPermit=FALSE` — visibilité opérateur d'une tentative d'armement refusée |
| `Ready/Busy/Done/Error/ErrorId` | État FB (miroirs de `Status`) |
| `Status : ST_FbStatus` | Statut standard complet (socle `FB_FbStatus`) |

**Gate** (`Enable` / bus CAN OP / device OP) : sorties axes à 0, `DeadmanArmed=FALSE`, timers
deadman reset, `RETURN` — reset complet, contrairement à `RawOutOfRange` (§5bis) qui neutralise
sans réinitialiser les timers d'armement.

La perte de `BusCanOpenOP.Operational` ou `JoystickOP.Operational` neutralise les sorties
(`Ready=FALSE`) et lève `ErrorId` bit2, auto-effacé dès le retour (catégorie Warning
`CODE_QUALITY_STANDARDS.md §9` — pas un Fault à acquitter).

---

## 4. Homme-mort

### Paramètres

| Paramètre | Défaut | Rôle |
|---|---|---|
| `DeadmanArmHoldTime` | `T#100MS` | Appui bouton maintenu avant armement |
| `DeadmanArmGraceTime` | `T#3S` | Délai après armement avant que le désarmement neutre (`NeutralHoldTime`) puisse s'appliquer |
| `NeutralHoldTime` | `T#100MS` | Neutre tenu avant désarmement (après la grâce) |

### Armement

Front bouton (`RawButton`) démarre un maintien `DeadmanArmHoldTime` (100 ms). À l'issue du
maintien — **et seulement si `ArmingPermit=TRUE`** à ce moment — le geste est armé,
**indépendamment** de la position des axes pendant ce délai. Relâché avant la fin du maintien =
tentative annulée, nouvel appui (front) exigé.

### Désarmement

| Cause | Condition |
|---|---|
| Gate | `NOT Enable OR BusLost` — reset complet, `RETURN` |
| `ArmingPermit` retiré | **Immédiat**, sur niveau (pas front) : `NOT ArmingPermit ⇒ DeadmanArmed := FALSE`. C'est l'**unique** mécanisme de désarmement externe — le FB ne sait plus *pourquoi* (mode, benne, etc.), seulement *que* la permission a disparu |
| Neutre tenu | `NeutralHoldTime` (100 ms) au neutre, applicable **seulement après `DeadmanArmGraceTime` (3s)** écoulées depuis l'armement (sans cette grâce, l'armement — typiquement fait au neutre — se désarmerait quasi immédiatement après lui-même) |

🚫 **N'existe plus** : le timeout de reconfirmation périodique (`DeadmanReconfEnable`/
`DeadmanRearmTimeout`, 10 s bouton relâché en mouvement) documenté en v2.0. Une fois armé, le FB
ne surveille **plus** le bouton — seul le retour au neutre prolongé (après grâce) désarme.

⚠️ Désarmement ⇒ cibles rampe à 0 ⇒ **décélération normale**, pas coupure puissance.

---

## 5. Calibration et défauts

| Règle | Détail |
|---|---|
| Front `BtnCalibrate` | Si `RawX`/`RawY` ∈ [2000 ; 8000] → écrit neutres mem |
| Sinon | `ErrorId` bit0 (Fault, à acquitter) |
| Reset | Front + Raw encore dans plage → clear bit0 |
| Neutres | Persistants (`NeutralXMem`/`NeutralYMem`) |

### 5bis. Surveillance capteur en fonctionnement (défaut hors plage ADC)

Distinct du §5 (calibration, front `BtnCalibrate` uniquement) : ici la surveillance est
**continue**, à chaque scan, pendant le fonctionnement normal.

| Règle | Détail |
|---|---|
| Détection | `RawX`/`RawY` hors `[0 - RawOutOfRangeMargin ; 10000 + RawOutOfRangeMargin]`, évalué en continu |
| Marge de tolérance | `RawOutOfRangeMargin := 500` — évite un faux défaut sur simple bruit ADC près des bornes nominales |
| Effet immédiat | `AxisCmdX/Y.SpeedRef := 0` sur **les 2 axes** (confiance perdue dans tout le geste, pas seulement l'axe en défaut) |
| Diagnostic | `ErrorId` bit1, Warning auto-effacé — cause brute évaluée en continu |

**Exemples** (`Neutral = 5000`) :

| `RawX` | Zone | `SpeedRef` attendu |
|---|---|---|
| `10000` | Plage nominale (max) | `100` |
| `11000` | Hors plage + marge | `0` |
| `-1000` | Hors plage + marge (sens inverse) | `0` |

### 5ter. Procédure calibration terrain (SITE)

| # | Étape | Attendu |
|---|---|---|
| 1 | Manche **relâché physiquement** (repos mécanique) | — |
| 2 | Front `BtnCalibrate` (IHM) | `NeutralXAct`/`NeutralYAct` ← `RawX`/`RawY` courants |
| 3 | Vérifier `NeutralXAct`/`NeutralYAct` proches de **5000** ±quelques centaines | Sinon jeu mécanique/capteur à investiguer |
| 4 | Débattement complet des 2 axes, les 4 directions | `SpeedRef` atteint ±100 % de façon symétrique |
| 5 | Redémarrage/download PLC | Neutre **conservé** (persistant) |

⚠️ **Point ouvert** : présence confirmée d'un bouton `BtnCalibrate` sur l'écran HMI **non
vérifiée** dans ce lot — non résolu depuis v2.0.

| TC | Attendu | Type |
|---|---|---|
| <nobr><code>TC-P08-009</code></nobr> | Neutre persiste après download/redémarrage PLC | SITE |
| <nobr><code>TC-P08-010</code></nobr> | Bouton calibration accessible et fonctionnel sur écran HMI réel | SITE |

---

## 6. Intégration programme

```text
Acquisition  HwIn.Operator (réel/sim)
Acquisition  Diag CAN + instJoystick          ← producteur unique consignes joy
Acquisition  ArmingPermit := TRUE (⚠️ câblage temporaire — voir alerte §8)
Treuils  Winch : joy + DeadmanArmed + sélecteur treuil
Translation  Translation : AxisCmdX + DeadmanArmed
Supervision  Mapping IHM JOY1Joystick.State
```

Consommateurs **doivent** combiner `AxisCmd*.StartStop` **et** `DeadmanArmed`
(déjà le cas Winch/Trans — TC-P08-008).

Cible archi AF02 : Joystick reste dans le domaine **Acquisition** (`PRG_02_Acquisition`).

---

## 7. IHM

| DUT | Contenu |
|---|---|
| `ST_JoystickCmd` | `BtnCalibrate` |
| `ST_JoystickState` | Raw, AxisCmd, neutres, DeadmanArmed, ArmingPermitDenied, Online/OP, Error |

Réglages deadband/timers : `GVL_PERSISTENT` (pas tous dans Cmd IHM — détail P07 / code).

---

## 8. Alertes et points ouverts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | 🔴 **sécurité** | `ArmingPermit` câblé en dur à `TRUE` dans `PRG_02_Acquisition.st:303` (« Câblage TEMPORAIRE ») — aucun désarmement automatique sur changement de mode/fin de cycle benne n'est actuellement en place. Trou de sécurité **non compensé ailleurs** (challenge indépendant, 2026-08-24/25). | À trancher par arbitrage humain — voir `DOC/WFLOW/AUDITS/PRG02_20260824/QUESTIONS_OUVERTES_PRG02_v0.1.md` Q1. Ne PAS refermer sans décision explicite. |
| 2 | info | v2.0 classait ce FB en contrat `light` (déjà inexact) | **Corrigé** par v2.1 (§1 : contrat `standard`) |
| 3 | info | Retard 1 scan potentiel entre calcul externe d'`ArmingPermit` et lecture par le FB | Accepté par construction (pattern producteur/consommateur standard) |
| 4 | mineur | Miroirs Speed/Direction dupliquent AxisCmd | Garder pour MES ; pas de 3ᵉ copie |
| 5 | site | Checklist MES joy | Exécution terrain, hors cette AF |

Pas de surcharge identifiée justifiant un refactor immédiat du FB : composition claire, une
instance, gate fail-safe.

---

## 📜 8bis. Suivi historique

- **v2.0 archivée** : `ARCHIVES/Doc/AF_Partie-08_Fonction_Joystick_v2.0.md`.
- **v2.1 (2026-08-25)** — resynchronisation avec le code réel : §3/§4 réécrits sur l'interface
  actuelle `ArmingPermit` (l'ancienne interface `Mode`/`BenneBusy`/`PreserveArmingAfterBucket`/
  `DeadmanReconfEnable`/`DeadmanRearmTimeout` documentée en v2.0 n'existe plus dans le FB).
- **Profil AF03 corrigé (v2.1)** : `standard`, pas `light` — la v2.0 classait ce FB en contrat
  `light`, ce qui était déjà inexact au moment de sa rédaction (le FB avait toujours un `Reset`
  et remontait des défauts).
- **TC-P08-011/012 corrigés (2026-08-25)** : marqués à tort « RETIRÉ » alors que des tests vivants
  existent (`test_fb_joystick.st:451,492`) ; TC-P08-013 reclassé `⬜ GAP` (non testé, faussement
  marqué `AUTO` auparavant).
- **Filtre PT1 supprimé** : `FB_Filter_PT1` retiré du pipeline Joystick (le joystick est stable et
  ne doit pas être ralenti) ; fonction généraliste toujours dispo dans `CODE/A_COMMUN/FB_Filter`.
- **Double rampe en cascade — constat périmé** : `FB_Joystick.st` actuel n'instancie **aucun**
  `FB_Ramp` (pipeline réel : `FB_AxisScale` → homme-mort, voir §2). Les paramètres de rampe
  historiques côté joystick n'existent plus dans le code — le TBD original décrivait un état
  antérieur du code.

## ❓ 8ter. TBD — Filtre par défaut et double rampe Joystick↔FB de mouvement

> ⛔ **Non tranché, pas d'autorisation de coder.** Risque d'interférence entre une éventuelle
> rampe côté Joystick et la rampe/tempo palier de `FB_Winch`/`FB_Translation` si une rampe est un
> jour réintroduite côté Joystick — devenir de la rampe `FB_Winch`/`FB_Translation` en cas de
> double-lissage, lié à AF10. Décision et code dans un lot dédié, contrat de tâche requis
> (C3/C4 — accélération/décélération treuil = sécurité machine).

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Acquisition / pas page joy autonome |
| AF03 | Profil `standard`, Reset front |
| AF06 | Raw Operator / sim |
| AF07 | `ST_JoystickHMI` |
| AF10 / AF11 | Consommateurs AxisCmd + DeadmanArmed (Treuils Benne incluse · Translation) |
| AF13 | `FB_Sim_Joystick` amont |
| Revue indépendante | `DOC/WFLOW/AUDITS/PRG02_20260824/REVUE_PRG02_ACQUISITION_v0.1.md` — trou `ArmingPermit` confirmé (Q1) |
| Code | `CODE/D_JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `ST_Joystick_AxisCmd.st` |
