# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (v2.4)

> **Version 2.4** — Réconciliation des deux lignes v2.3 :
> on **retire `GVL_BusHealth`, `ST_BusHealth` et `E_DegradationLevel`** (partage direct entre
> FB, dégradation gérée par `FB_Modes` + interlocks `Enable`/`Ready`), arrêt sûr logiciel par
> **retrait de l'`Enable`** (`CoupeEnable`) ; on **conserve** les apports v2.3 : mapping physique
> **M1/M2/M3**, `FB_SpeedStep` en **masque 4 bits** (`ST_SpeedStepTable`), et `FB_Safety` étendu à la
> **sécurité électrique** (`ST_ContactorCheck` + **`PowerCutOff`** = coupure puissance amont sur
> contacteur collé).
>
> 🗂️ Historique : v2.3 (deux variantes : diag-dans-main / CoupeEnable) → v2.4 réconciliée = référence.
> Versions périmées dans `DOC/Archives/` (gitignoré).

---

## 🧭 0. Principes directeurs

| # | Décision | Conséquence |
|---|----------|-------------|
| 1 | **Un seul `PLC_PRG_MAIN`** (MainTask) appelle séquentiellement diag + logique métier | Pas de PRG moniteur séparé |
| 2 | **Pas de `GVL_BusHealth`** | Chaque FB lit **directement** la sortie du FB producteur (appel séquentiel même cycle) |
| 3 | **Pas de `E_DegradationLevel`** | Dégradation = `FB_Modes` + interlocks `Enable`/`Ready` par FB |
| 4 | **`SafeStop` n'est pas un signal propagé** | `FB_Safety` lève **`CoupeEnable`** → `PLC_PRG_MAIN` fait `Enable := (ordre) AND NOT CoupeEnable` |
| 5 | **AU = chaîne matérielle indépendante** ; **`PowerCutOff`** = coupure puissance amont si contacteur collé | Voir §6 |
| 6 | **`FB_SpeedStep` en masque 4 bits**, table par treuil (`ST_SpeedStepTable`) | Paliers librement définis, données ≠ code |
| 7 | Conditionnement E/S mutualisé (`FB_Input_Digital` / `FB_Output_Relay`) | Voir Partie 6 |

🔎 **Pourquoi quasi pas de GVL ?** Les GVL servent à partager entre FB de tâches/appels différents.
Ici tout est séquentiel dans `PLC_PRG_MAIN` → échange par entrées/sorties directes. Seule une GVL
**d'échange IHM** pourra être créée (à définir), pas pour l'état interne machine.

---

## 🗺️ 1. Mapping physique (référence)

| Repère | FB / POU | Équipement physique | Bus |
|--------|----------|---------------------|-----|
| **M1** | `FB_Winch` (M1) + `FB_Encoder_Abs` **COD1** | Treuil levage 1 + codeur absolu tambour 1 | EtherCAT |
| **M2** | `FB_Winch` (M2) + `FB_Encoder_Abs` **COD2** | Treuil levage 2 + codeur absolu tambour 2 | EtherCAT |
| **M3** | `FB_Translation` | Variateur **AC600** axe transversal | EtherCAT |

🧭 `COD1`=codeur **M1**, `COD2`=codeur **M2**, `AC600`=variateur **M3**. Toute instance/variable respecte cette correspondance.

---

## ⏱️ 2. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | à définir¹ | **4 ms** | Rafraîchit images process EtherCAT : codeurs M1/M2 (COD1/COD2), variateur AC600 (M3). **Pas de PRG moniteur.** |
| 🔌 **CanTask** | à définir¹ | **20 ms** | Rafraîchit image process CANopen : joystick Hall. **Pas de PRG moniteur.** |
| 🧠 **MainTask** | à définir¹ | **10 ms** | `PLC_PRG_MAIN` : diagnostics bus (`FB_DiagCanOpen` + 3×`FB_DiagEthercat`) **puis** logique métier. |

> ¹ **Priorités à définir** en configuration CODESYS. Critère : les tâches bus rafraîchissent
> l'image process **avant** que `MainTask` ne la consomme.

🧭 **Règle d'or** : images process rafraîchies par les tâches bus → `PLC_PRG_MAIN` consomme une image cohérente.
Les `FB_Diag*` tournent dans `MainTask` (10 ms) ; la détection de perte de bus reste sous le timeout des
équipements. Si une réactivité < 10 ms devenait nécessaire, réintroduire un moniteur sur la tâche bus.

⏲️ **Watchdog** : `FB_Watchdog` surveille toutes les tâches, seuil unique **200 ms** → `ErrorId` → `FB_Safety` → `CoupeEnable`.

---

## 🌳 3. Arborescence Visuelle du Projet (CODESYS)

```text
Application (PLC_PRG → PLC_PRG_MAIN sur MainTask 10 ms — orchestration séquentielle)
├── 📁 _COMMON (Briques génériques mutualisées)
│   ├── FB_FilterPT1         (Filtre 1er ordre — sinon lib Util si dispo)
│   ├── FB_Brake             (Séquence frein levage — voir Partie 4)
│   ├── FB_Input_Digital     (Conditionnement entrée TOR — voir Partie 6)
│   └── FB_Output_Relay      (Commande + feedback sortie — voir Partie 6)
├── 📁 _TYPES (Structures & énumérations globales)
│   ├── ST_AxisCmd           (Consigne générique Enable/Sens/SpeedRef)
│   ├── ST_WinchIO           (État/commande treuil)
│   ├── ST_TransIO           (État/commande translation)
│   ├── ST_EncoderData       (Données traitées codeur)
│   ├── ST_SpeedStepTable    (5 masques 4 bits — table de paliers d'UN treuil)
│   ├── ST_ContactorCheck    (Commande + retour + diag collage d'un contacteur)
│   ├── ST_LimitLegal        (Cote min dragage — voir Partie 5)
│   ├── ST_BucketConfig      (Offsets désynchro M2 — RETAIN)
│   ├── ST_BucketState       (État godet mémorisé — RETAIN)
│   ├── E_Mode               (Manuel / Maint_N1 / Maint_N2 / SemiAuto)
│   ├── E_State              (DISABLED / INIT / READY / BUSY / DONE / STOPPING)
│   └── E_CycleStep          (Étapes du séquenceur — voir Partie 4)
├── 📁 _DIAG (Diagnostics communication — instances appelées dans PLC_PRG_MAIN)
│   ├── FB_DiagCanOpen       (État bus CANopen + nœud joystick)
│   └── FB_DiagEthercat      (État esclave EtherCAT unique)
├── 📁 JOYSTICK
│   └── FB_Joystick          (Filtre, zone morte, calibration zéro, consigne relative)
├── 📁 WINCH (Treuils — granularité unitaire)
│   ├── FB_Winch             (Directeur treuil individuel — M1, M2 ; pilotable seul)
│   ├── FB_SpeedStep         (Décodeur paliers → masque 4 bits, table par treuil)
│   └── FB_WinchSync         (Surveillance + régulation écart M1↔M2, permanente)
├── 📁 ENCODER (Chaîne de mesure position câble)
│   ├── FB_Encoder_Abs       (Lecture + validation EtherCAT, latch défauts — COD1/COD2)
│   ├── FB_Encoder_Scale     (Points → mètres via LIN_TRAFO, 2 déc.)
│   └── FB_Encoder_Safety    (Cohérence position / limites)
├── 📁 TRANSLATION
│   └── FB_Translation       (Variateur AC600 — M3, approche temporisée + arrêt capteur)
├── 📁 BUCKET
│   └── FB_Bucket            (Désynchro M2 ouvert/fermé, mémoire RETAIN + vérif boot)
├── 📁 SAFETY (Surveillance transverse)
│   ├── FB_Safety            (Défauts machine → CoupeEnable ; sécurité électrique → PowerCutOff)
│   └── FB_Watchdog          (Périodicité tâches, seuil 200 ms)
└── 📁 SEQUENCE
    ├── FB_Modes             (Arbitrage sources + droits + overrides Maint N2)
    └── FB_Cycle             (Séquenceur semi-automatique — E_CycleStep, voir Partie 4)
```

> 📌 `FB_SpeedStep` et `FB_Brake` sont **composés à l'intérieur** de `FB_Winch` (un jeu par treuil).
> Composition, pas appel global.
> 🗑️ **Supprimés** : `GVL_BusHealth`, `ST_BusHealth`, `E_DegradationLevel`, `PRG_CanMonitor`,
> `PRG_EthercatMonitor`. Les `FB_Diag*` sont appelés directement dans `PLC_PRG_MAIN` et leurs
> **sorties sont lues directement** par les consommateurs (même cycle).

---

## 🧱 4. Rôle de chaque bloc

### 📁 Diagnostics communication
* **`FB_DiagCanOpen`** — État bus CANopen + nœud joystick. Sorties (`CanHealthy`, `JoystickAvailable`) lues **directement** par `FB_Joystick`, `FB_Safety`.
* **`FB_DiagEthercat`** (×3 : COD1/M1, COD2/M2, AC600/M3) — État esclave (WcState, SlaveState). Sorties lues directement par `FB_Encoder_Abs`, `FB_Translation`, `FB_Safety`.

### 📁 Conditionnement E/S (Partie 6)
* **`FB_Input_Digital`** — Inversion NO/NC, filtrage anti-rebond, diag. Déclaré en **tableau**.
* **`FB_Output_Relay`** — Commande relais + **contrôle feedback** (contacteur collé/ouvert), inversion, option blink 1 Hz. Déclaré en **tableau**. S'appuie sur `ST_ContactorCheck` pour les contacteurs de puissance.

### 📁 Sécurité transverse
* **`FB_Safety`** 🔌 — Centralise les détections (cohérence capteurs, limites, perte bus/codeur/joystick selon mode). **Deux sorties maîtresses** :
  - **`CoupeEnable`** (BOOL) : sur défaut process, `PLC_PRG_MAIN` retire les `Enable` → arrêt sûr **propre** (rampe non destructive, freins). N'arrête pas lui-même les actionneurs, il **informe**.
  - **`PowerCutOff`** (BOOL) : **surveillance collage** — compare la commande de chaque contacteur de puissance à son **retour d'état câblé** (`ST_ContactorCheck`). Incohérence persistante (commande OFF mais retour ON) ⇒ contacteur **collé** ⇒ `PowerCutOff` ouvre le **contacteur général amont** et coupe **électriquement** la puissance (indépendant de l'automate, jamais coupé). C'est la sortie `AuTrigger` décrite en §6.
  - Expose `ErrorId` (bitfield) + `State` pour l'IHM.
* **`FB_Watchdog`** — Périodicité tâches (200 ms) → contribue à `ErrorId`.

### 📁 Arbitrage modes & droits
* **`FB_Modes`** — Sélectionne la source légitime (joystick en Manuel/Maint, `FB_Cycle` en SemiAuto), calcule les **autorisations/interlocks** par bloc, porte les **overrides Maint N2**. Remplace fonctionnellement `E_DegradationLevel`. Voir Partie 5.

### 📁 Joystick
* **`FB_Joystick`** — Conditionne le signal Hall (0–10000 pts) : filtre, zone morte, calibration zéro. Produit une **consigne relative** (0–100 % de la vitesse max autorisée par l'étape/mode — voir Partie 4 §Rampes). Lit directement `FB_DiagCanOpen.JoystickAvailable`.

### 📁 Chaîne de mesure
* **`FB_Encoder_Abs`** (COD1→M1, COD2→M2) — Lecture points bruts EtherCAT + validation + défauts latching. Bloqué si esclave down.
* **`FB_Encoder_Scale`** — Points → mètres (`LIN_TRAFO`, 2 déc.).
* **`FB_Encoder_Safety`** — Cohérence position vs capteurs (fond, fdc, maintenance) et bornes.

### 📁 Treuils
* **`FB_Winch`** (M1, M2) — Directeur d'un treuil **individuel** : sens, commande des contacteurs de paliers via `FB_SpeedStep` (masque 4 bits), séquence frein via `FB_Brake`. Pilotable **unitairement** (maintenance N1/N2, y compris sans codeur ni joystick selon droits). ⚠️ Treuils **sans variateur** : la vitesse résulte des contacteurs de paliers ; pas de mesure de courant (disjoncteurs seuls) → l'effort se **déduit** de Δposition/Δvitesse.
* **`FB_SpeedStep`** 🪜 — Convertit une consigne en **masque 4 bits** (4 contacteurs) selon le **palier courant** : 5 paliers, chaque palier = masque librement défini (plus de cumul implicite), **table propre à chaque treuil** (`ST_SpeedStepTable`), sélection du palier via `HYSTERESIS`. Sortie : 4 booléens (ou `BYTE` masque) + n° de palier. L'ordre des contacteurs est **donnée** (table), pas codé en dur.
* **`FB_WinchSync`** — **Actif en permanence**. Mesure `ΔPos = |PosM1 − PosM2|` (+ dérive vitesse). Régule l'axe rapide (ralentissement par paliers/rampe), signale et, si écart hors plage, demande arrêt + repositionnement. Voir Partie 4 §Synchro.

### 📁 Translation
* **`FB_Translation`** (M3) — Pilote le variateur **AC600** (mot cmd/état ; vitesse estimée + consigne fréquence disponibles, **pas** la mesure de courant). Approche temporisée puis ralentissement et **arrêt sur capteur** (travail 1/2, vidage). Voir Partie 4 §Translation.

### 📁 Godet
* **`FB_Bucket`** — État **ouvert/fermé** via positions codeurs + **mémoire RETAIN**. Contrôle de cohérence au boot (état mémorisé vs position réelle > seuil → état **non sûr** → maintenance + vitesse réduite). Ouverture/fermeture = désynchro M2 (offsets `ST_BucketConfig`, réglables Maint N2).

### 📁 Séquenceur
* **`FB_Cycle`** — Machine d'état `E_CycleStep` (pseudo-Grafcet). Émet `Enable`/Sens/SpeedRef vers treuils & translation ; passage à une étape sans mouvement = retrait `Enable` → arrêt sur rampe. Voir Partie 4.

---

## 🔗 5. Flux de données (sans agrégateur)

### 📈 Flux montant (mesures)
```
EtherCAT 4ms : Codeurs COD1/COD2 ──► FB_Encoder_Abs ──► FB_Encoder_Scale ──► (mètres)
                Variateur AC600 ──► mot d'état ──► FB_Translation
CANopen 20ms : Joystick Hall ──► FB_Joystick ──► consigne relative
TOR + retours contacteurs (Partie 6) ──► FB_Safety, FB_Cycle
FB_Diag* ──► (CanHealthy, JoystickAvailable, EncoderM1/M2Available, VariateurAvailable) lus DIRECTEMENT
```
Chaque consommateur lit la **sortie du FB producteur** (appel séquentiel), pas une GVL agrégée.

### 📉 Flux descendant (ordres)
```
FB_Modes (source légitime selon mode) ──► ST_AxisCmd
   ├─► FB_Winch M1/M2 ──► FB_SpeedStep (masque 4 bits) ──► contacteurs ; FB_Brake ──► frein
   ├─► FB_WinchSync (corrige les consignes M1/M2 si dérive)
   ├─► FB_Translation ──► variateur AC600
   └─► FB_Bucket (phase godet : désynchro M2)
```

### 🛡️ Flux sécurité (priorité absolue)
```
FB_Safety défaut process ──► CoupeEnable := TRUE
   PLC_PRG_MAIN : Enable_X := (commande_X) AND NOT FB_Safety.CoupeEnable
   → treuils & translation perdent Enable ──► arrêt sur rampe (raide, non destructive)
   → freins se collent (FB_Brake)
   → FB_Cycle se fige (ERROR_HOLD)
FB_Safety contacteur collé ──► PowerCutOff := TRUE ──► coupure puissance amont (matériel)
```

### 🚦 Diagnostics → actions granulaires (via FB_Modes + interlocks, sans E_DegradationLevel)
| Défaut détecté | Signal (lecture directe FB_Diag) | Conséquence (FB_Modes / interlocks) |
|----------------|----------------------------------|--------------------------------------|
| CANopen / joystick down | `CanHealthy=0`, `JoystickAvailable=0` | Commande manuelle interdite, cycle en HOLD sûr (Ready=0) |
| Codeur M1 down | `EncoderM1Available=0` | Treuil M1 bloqué (Ready=0), M2 dégradé, auto interdit |
| Codeur M2 down | `EncoderM2Available=0` | Treuil M2 bloqué, M1 dégradé, auto interdit |
| Variateur M3 down | `VariateurAvailable=0` | Translation interdite, treuils nominaux possibles |
| Contacteur collé | retour ≠ commande (`ST_ContactorCheck`) | `FB_Safety.PowerCutOff` → coupure puissance immédiate |

---

## 🚦 6. Arrêt d'urgence (AU) vs `CoupeEnable` vs `PowerCutOff`

| Couche | Élément | Nature | Action |
|--------|---------|--------|--------|
| Matérielle | Bouton coup-de-poing **ou** câble mécanique « montée excessive » | Câblé | Coupe le **contacteur de puissance** → moteurs OFF + freins collés. Automate/CC **non coupés**. |
| Matérielle ⟵ Logiciel | Sortie **`PowerCutOff`** (= `AuTrigger`) | Cmd PLC → relais coupure | Si un **contacteur de puissance reste collé**, ouvre le **contacteur général amont** (organe distinct du contacteur collé). Seul moyen d'arrêter un treuil parti sans commande. |
| Logicielle | **`FB_Safety.CoupeEnable`** | Variable interne | Sur défaut process : retire les `Enable` → arrêt sûr propre. **≠ AU**. |
| Logicielle | `SafetyOk` (entrée FB) | Info | Reflète « AU réarmé + conditions globales OK ». |

🧭 L'AU physique reste la sécurité ultime **indépendante**. `PowerCutOff` gère le cas du contacteur collé
(coupure électrique amont). `CoupeEnable` gère les défauts process (arrêt propre). Réarmement AU = **physique**,
n'efface pas les alarmes (acquittement IHM séparé, reset front — voir Partie 3).

---

## 🚦 7. Chaîne logique d'exécution (1 cycle MainTask 10 ms)

```text
[0. DIAG]   ─► [1. IO IN]  ─► [2. SÉCURITÉ]        ─► [3. MODES] ─► [4. MÉTIER]        ─► [5. IO OUT]
 FB_DiagCan     FB_Input      FB_Safety              FB_Modes       FB_Winch M1/M2        FB_Output
 FB_DiagEcat×3  (TOR cond.)   (CoupeEnable)          (source+droits)FB_SpeedStep/WinchSync (relais+feedback)
                retours contact(PowerCutOff)                        FB_Translation/Bucket
                                FB_Watchdog                          FB_Cycle
```

⚠️ **Priorité étape 2** : si `FB_Safety` lève `CoupeEnable`, `PLC_PRG_MAIN` retire les `Enable` → les sorties
(étape 5) retombent en repli sûr ; un contacteur collé déclenche `PowerCutOff` (coupure puissance amont).

---

## 📌 8. Notes d'implémentation (types conservés de v2.3)

### ST_SpeedStepTable (paliers masque 4 bits, 1 par treuil)
```
STRUCT ST_SpeedStepTable
  // 5 paliers ; chaque palier = masque 4 bits (bit0..bit3 = contacteurs 1..4)
  StepMask          : ARRAY[1..5] OF BYTE;   // ex: StepMask[1] := 2#0001;
  StepThreshold_Pct : ARRAY[1..5] OF REAL;   // seuils de changement de palier (HYSTERESIS)
END_STRUCT
```

### ST_ContactorCheck (surveillance collage)
```
STRUCT ST_ContactorCheck
  Command     : BOOL;   // ordre envoyé au contacteur (TRUE = fermé/actif)
  Feedback    : BOOL;   // retour d'état câblé (TRUE = effectivement fermé)
  StuckClosed : BOOL;   // diag : commande OFF mais retour ON depuis trop longtemps → PowerCutOff
  StuckOpen   : BOOL;   // diag : commande ON mais retour OFF (option)
END_STRUCT
```

### ST_LimitLegal (interdiction normale, pas sécurité — voir Partie 5)
```
STRUCT ST_LimitLegal
  DepthMinAllowed : REAL;   // m ; cote min autorisée
  Enabled         : BOOL;   // actif en SEMI_AUTO, en descente
END_STRUCT
```

> 🗑️ **Retirés** : `E_DegradationLevel`, `ST_BusHealth`, `GVL_BusHealth`. La dégradation est portée
> par `FB_Modes` + les `Enable`/`Ready` conditionnels de chaque FB.

---

## 🔄 9. Hiérarchie des appels (chronologie 1 cycle)

```
EtherCatTask (4ms)  : rafraîchit images process EtherCAT (COD1/M1, COD2/M2, AC600/M3)
CanTask (20ms)      : rafraîchit image process CANopen (joystick)

MainTask (10ms)
  └─ PLC_PRG_MAIN
     ├─ [DIAG] FB_DiagCanOpen() ; FB_DiagEthercat(COD1/M1, COD2/M2, AC600/M3)
     ├─ [IO IN]  Input[1..n]()                    // conditionnement TOR + retours contacteurs
     ├─ FB_Safety()   → CoupeEnable, PowerCutOff  (lit sorties FB_Diag + ST_ContactorCheck)
     ├─ FB_Watchdog()
     ├─ FB_Modes()    → source + droits + overrides
     ├─ FB_Joystick()
     ├─ FB_Encoder_Abs(COD1) → Scale → Safety ; FB_Encoder_Abs(COD2) → Scale → Safety
     ├─ FB_Winch(M1) / FB_Winch(M2)  → FB_SpeedStep (masque 4 bits) + FB_Brake ; FB_WinchSync()
     ├─ FB_Translation(M3)
     ├─ FB_Bucket()
     ├─ FB_Cycle()                                // machine d'état E_CycleStep
     └─ [IO OUT] Output[1..m]()                   // Enable AND NOT CoupeEnable ; PowerCutOff
```

---

## 📚 Documents liés
- **Partie 1** — Présentation & équipements.
- **Partie 3** — Contrat FB commun : interface (`Enable/Reset/SafetyOk/Mode`), état, ErrorId, reset, AU/PowerCutOff.
- **Partie 4** — Cycle & séquenceur : `E_CycleStep`, INIT, synchro, frein, translation, godet, rampes.
- **Partie 5** — Modes & maintenance : Manuel/N1/N2/SemiAuto, AU/CoupeEnable/PowerCutOff, limite légale.
- **Partie 6** — Conditionnement E/S : `FB_Input_Digital`, `FB_Output_Relay`, `ST_ContactorCheck`.
</content>
