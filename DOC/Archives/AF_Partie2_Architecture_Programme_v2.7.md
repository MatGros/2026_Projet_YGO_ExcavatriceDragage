# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (v2.7)

> **v2.7** — Renommage terminologique (demande utilisateur, 2026-07-02) : Bucket→Grappin
> (`FB_Grappin`, `ST_GrappinConfig`/`ST_GrappinState`), Translation→Chariot (`FB_Chariot`,
> `FB_Safety_Chariot`, `E_ChariotCommMode`, `ST_ChariotIO`) — préfixe I/O physique M3 inchangé.

> **Version 2.6** — Retour terrain 2026-07-02 (§6) : le câble mécanique « montée excessive » est
> **retiré de la chaîne AU matérielle** — seul le bouton coup-de-poing reste un AU purement
> câblé. Le capteur de position haute est désormais lu par l'automate, qui déclenche
> `PowerCutOff` si activé hors mode référencement (2ᵉ cause de `PowerCutOff`, en plus du
> contacteur collé) — voir aussi Partie 1 v1.4 et Partie 10.
>
> **Version 2.5** — Suite audit documentaire (voir `DOC/AUDIT_Coherence_Documentaire_v1.0.md`) :
> - **`CoupeEnable` supprimé** : cette variable n'a **jamais existé**, c'était une façon imprécise
>   de décrire le mécanisme d'arrêt. Remplacé par le couple **`SafeStop`/`StartStop`** (voir §0, §6).
> - **`SafeStop` par métier** : chaque bloc safety métier a sa **propre** sortie `SafeStop`
>   (pas de signal global unique), consommée par les FB de mouvement de son domaine.
> - **`SafetyOk` renommé `EmergencyStopOk`** (chaîne AU / retour contacteur puissance).
> - **`FB_Watchdog` supprimé** : la surveillance de périodicité des tâches est une **fonction
>   système CODESYS** (configuration tâche), pas un FB applicatif.
> - Interlock **`FB_WinchSync` suspendu** explicitement pendant la phase grappin (pas de mouvement M1).
>
> 🗂️ Historique : v2.3 (deux variantes) → v2.4 réconciliée → **v2.5** (présent audit, retrait
> définitif de `CoupeEnable`/`FB_Watchdog`, modèle `SafeStop`/`StartStop`). Versions périmées
> dans `DOC/Archives/` (gitignoré).

---

## 🧭 0. Principes directeurs

| # | Décision | Conséquence |
|---|----------|-------------|
| 1 | **Un seul `PLC_PRG_MAIN`** (MainTask) appelle séquentiellement diag + logique métier | Pas de PRG moniteur séparé, pas de sous-`PRG_*` |
| 2 | **Pas de `GVL_BusHealth`** | Chaque FB lit **directement** la sortie du FB producteur (appel séquentiel même cycle) |
| 3 | **Pas de `E_DegradationLevel`** | Dégradation = `FB_Modes` + interlocks `Enable`/`Ready` par FB |
| 4 | **Modèle d'arrêt à 3 niveaux** : `Enable` > `SafeStop` > `StartStop` | `Enable=FALSE` → FB neutralisé (sorties coupées) ; `SafeStop=TRUE` (émis par le bloc safety **du métier concerné**) → rampe décélération **rapide**, `Enable` maintenu ; `StartStop=FALSE` → rampe décélération **normale** (arrêt demandé). Voir §6. |
| 5 | **`SafeStop` = 1 par bloc safety métier**, pas de signal global | Chaque domaine (treuils, chariot, grappin…) a son diagnostic propre |
| 6 | **AU = chaîne matérielle indépendante** ; **`PowerCutOff`** = coupure puissance amont si contacteur collé | Voir §6. Automate **jamais coupé** ; `EmergencyStopOk` informe l'état AU. |
| 7 | **`FB_SpeedStep` en masque 4 bits**, table par treuil (`ST_SpeedStepTable`) | Paliers librement définis, données ≠ code |
| 8 | Conditionnement E/S mutualisé (`FB_Input_Digital` / `FB_Output_Relay`) | Interface **réduite** (types de données propres, pas de `StartStop`) — voir Partie 6 |
| 9 | **Pas de `FB_Watchdog` applicatif** | Périodicité des tâches surveillée par la **fonction système CODESYS** (config tâche) |

🔎 **Pourquoi quasi pas de GVL ?** Les GVL servent à partager entre FB de tâches/appels différents.
Ici tout est séquentiel dans `PLC_PRG_MAIN` → échange par entrées/sorties directes. Seule une GVL
**d'échange IHM** pourra être créée (à définir), pas pour l'état interne machine.

---

## 🗺️ 1. Mapping physique (référence)

| Repère | FB / POU | Équipement physique | Bus |
|--------|----------|---------------------|-----|
| **M1** | `FB_Winch` (M1) + `FB_Encoder_Abs` **COD1** | Treuil levage 1 + codeur absolu tambour 1 | EtherCAT |
| **M2** | `FB_Winch` (M2) + `FB_Encoder_Abs` **COD2** | Treuil levage 2 + codeur absolu tambour 2 | EtherCAT |
| **M3** | `FB_Chariot` | Variateur **AC600** axe transversal | EtherCAT |

🧭 `COD1`=codeur **M1**, `COD2`=codeur **M2**, `AC600`=variateur **M3**. Toute instance/variable respecte cette correspondance.

---

## ⏱️ 2. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | à définir¹ | **4 ms** | Rafraîchit images process EtherCAT : codeurs M1/M2 (COD1/COD2), variateur AC600 (M3). **Pas de PRG moniteur.** |
| 🔌 **CanTask** | à définir¹ | **20 ms** | Rafraîchit **uniquement** l'image process CANopen (joystick Hall). Le **traitement** (`FB_Joystick` : calibration/filtre/rampe) s'exécute dans `MainTask` (10 ms), pas ici. |
| 🧠 **MainTask** | à définir¹ | **10 ms** | `PLC_PRG_MAIN` : diagnostics bus (`FB_DiagCanOpen` + 3×`FB_DiagEthercat`) **puis** logique métier (dont `FB_Joystick`). |

> ¹ **Priorités à définir** en configuration CODESYS (TBD — voir `DOC/AUDIT_Coherence_Documentaire_v1.0.md` Q7). Critère : les tâches bus rafraîchissent
> l'image process **avant** que `MainTask` ne la consomme.

🧭 **Règle d'or** : images process rafraîchies par les tâches bus → `PLC_PRG_MAIN` consomme une image cohérente.
Les `FB_Diag*` tournent dans `MainTask` (10 ms) ; la détection de perte de bus reste sous le timeout des
équipements. Si une réactivité < 10 ms devenait nécessaire, réintroduire un moniteur sur la tâche bus.

⏲️ **Surveillance périodicité des tâches** : assurée par la **fonction système CODESYS**
(watchdog de tâche configuré dans les propriétés de tâche, seuil **200 ms**) — **pas de FB
applicatif dédié**. Un dépassement remonte comme défaut système ; le bloc safety concerné le
répercute en `SafeStop`.

---

## 🌳 3. Arborescence Visuelle du Projet (CODESYS)

```text
Application (PLC_PRG → PLC_PRG_MAIN sur MainTask 10 ms — orchestration séquentielle)
├── 📁 _COMMON (Briques génériques mutualisées)
│   ├── FB_FilterPT1         (Filtre 1er ordre — sinon lib Util si dispo)
│   ├── FB_Brake             (Séquence frein levage — voir Partie 4)
│   ├── FB_Input_Digital     (Conditionnement entrée TOR — interface réduite, voir Partie 6)
│   └── FB_Output_Relay      (Commande + feedback sortie — interface réduite, voir Partie 6)
├── 📁 _TYPES (Structures & énumérations globales)
│   ├── ST_AxisCmd           (Consigne générique Enable/StartStop/Sens/SpeedRef)
│   ├── ST_WinchIO           (État/commande treuil)
│   ├── ST_ChariotIO           (État/commande chariot)
│   ├── ST_EncoderData       (Données traitées codeur)
│   ├── ST_SpeedStepTable    (5 masques 4 bits — table de paliers d'UN treuil)
│   ├── ST_ContactorCheck    (Commande + retour + diag collage d'un contacteur)
│   ├── ST_LimitLegal        (Cote min dragage — voir Partie 5)
│   ├── ST_GrappinConfig      (Offsets désynchro M2 — RETAIN)
│   ├── ST_GrappinState       (État grappin mémorisé — RETAIN)
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
│   └── FB_WinchSync         (Surveillance + régulation écart M1↔M2 — actif hors phase grappin)
├── 📁 ENCODER (Chaîne de mesure position câble)
│   ├── FB_Encoder_Abs       (Lecture + validation EtherCAT, latch défauts — COD1/COD2)
│   ├── FB_Encoder_Scale     (Points → mètres via LIN_TRAFO, 2 déc.)
│   └── FB_Encoder_Safety    (Cohérence position / limites)
├── 📁 CHARIOT
│   └── FB_Chariot       (Variateur AC600 — M3, approche temporisée + arrêt capteur)
├── 📁 GRAPPIN
│   └── FB_Grappin            (Désynchro M2 ouvert/fermé, mémoire RETAIN + vérif boot)
├── 📁 SAFETY (Surveillance transverse — un bloc safety par métier)
│   └── FB_Safety_<Metier>   (Défauts du domaine → SafeStop propre au métier ; sécurité électrique → PowerCutOff)
└── 📁 SEQUENCE
    ├── FB_Modes             (Arbitrage sources + droits + overrides Maint N2 + limite légale)
    └── FB_Cycle             (Séquenceur semi-automatique — E_CycleStep, voir Partie 4)
```

> 📌 `FB_SpeedStep` et `FB_Brake` sont **composés à l'intérieur** de `FB_Winch` (un jeu par treuil).
> Composition, pas appel global.
> 🗑️ **Supprimés** : `GVL_BusHealth`, `ST_BusHealth`, `E_DegradationLevel`, `PRG_CanMonitor`,
> `PRG_EthercatMonitor`, **`FB_Watchdog`** (surveillance = fonction système). Les `FB_Diag*` sont
> appelés directement dans `PLC_PRG_MAIN` et leurs **sorties sont lues directement** par les
> consommateurs (même cycle).
> ⚠️ Le découpage exact des blocs safety par métier (`FB_Safety_<Metier>` : combien d'instances,
> quel périmètre chacune) reste à préciser à la mise en œuvre — le principe (1 `SafeStop` par
> domaine) est acté (voir §6).
> 🧩 `FB_AxisScale`, `FB_FilterPT1`, `FB_Ramp`, `FB_CycleTime` (pipeline joystick, Partie 8 §2) sont
> des **instances composées à l'intérieur de `FB_Joystick`** — pas des FB de premier niveau
> supplémentaires dans le dossier `JOYSTICK` (composition, cf. objectif POO partielle).

---

## 🧱 4. Rôle de chaque bloc

### 📁 Diagnostics communication
* **`FB_DiagCanOpen`** — État bus CANopen + nœud joystick. Sorties (`CanHealthy`, `JoystickAvailable`) lues **directement** par `FB_Joystick`, blocs safety.
* **`FB_DiagEthercat`** (×3 : COD1/M1, COD2/M2, AC600/M3) — État esclave (WcState, SlaveState). Sorties lues directement par `FB_Encoder_Abs`, `FB_Chariot`, blocs safety.

### 📁 Conditionnement E/S (Partie 6)
* **`FB_Input_Digital`** — Inversion NO/NC, filtrage anti-rebond, diag. Déclaré en **tableau**. Interface réduite (types propres, pas `StartStop`/`Mode`).
* **`FB_Output_Relay`** — Commande relais + **contrôle feedback** (contacteur collé/ouvert), inversion, option blink 1 Hz. Déclaré en **tableau**. S'appuie sur `ST_ContactorCheck` pour les contacteurs de puissance. Interface réduite.

### 📁 Sécurité transverse (un bloc par métier)
* **`FB_Safety_<Metier>`** 🔌 — Centralise les détections **du domaine** (cohérence capteurs, limites, perte bus/codeur/joystick selon mode). **Sorties maîtresses** :
  - **`SafeStop`** (BOOL, **propre à ce métier**) : sur défaut process de son domaine, les FB de mouvement concernés passent en **rampe de décélération rapide** (`Enable` maintenu, freins gérés normalement en fin de rampe). Le bloc safety **n'arrête pas lui-même** les actionneurs, il **informe** ; chaque FB de mouvement réagit à son `SafeStop`.
  - **`PowerCutOff`** (BOOL) : **surveillance collage** — compare la commande de chaque contacteur de puissance à son **retour d'état câblé** (`ST_ContactorCheck`). Incohérence persistante (commande OFF mais retour ON) ⇒ contacteur **collé** ⇒ `PowerCutOff` ouvre le **contacteur général amont** et coupe **électriquement** la puissance (indépendant de l'automate, jamais coupé). C'est la sortie `AuTrigger` décrite en §6.
  - Expose `ErrorId` (bitfield) + `State` pour l'IHM.
  - Consomme `EmergencyStopOk` (chaîne AU réarmée / retour contacteur puissance — voir Partie 3 §1) en tant qu'information de contexte.

### 📁 Arbitrage modes & droits
* **`FB_Modes`** — Sélectionne la source légitime (joystick en Manuel/Maint, `FB_Cycle` en SemiAuto), calcule les **autorisations/interlocks** par bloc, porte les **overrides Maint N2**, et **applique la limite légale de dragage** (interdiction normale, hors sécurité — voir Partie 5). Remplace fonctionnellement `E_DegradationLevel`.

### 📁 Joystick
* **`FB_Joystick`** — Conditionne le signal Hall (0–10000 pts) : filtre, zone morte, calibration zéro. Produit une **consigne relative** (0–100 % de la vitesse max autorisée par l'étape/mode — voir Partie 4 §Rampes). Lit directement `FB_DiagCanOpen.JoystickAvailable`. Traitement exécuté dans `MainTask` (10 ms) ; la communication CAN (20 ms) ne fait que rafraîchir l'image process.

### 📁 Chaîne de mesure
* **`FB_Encoder_Abs`** (COD1→M1, COD2→M2) — Lecture points bruts EtherCAT + validation + défauts latching. Bloqué si esclave down.
* **`FB_Encoder_Scale`** — Points → mètres (`LIN_TRAFO`, 2 déc.).
* **`FB_Encoder_Safety`** — Cohérence position vs capteurs (fond, fdc, maintenance) et bornes.

### 📁 Treuils
* **`FB_Winch`** (M1, M2) — Directeur d'un treuil **individuel** : sens, commande des contacteurs de paliers via `FB_SpeedStep` (masque 4 bits), séquence frein via `FB_Brake`. Entrées `StartStop` (rampe accel/decel normale) et `SafeStop` (rampe decel rapide, propre au métier treuil). Pilotable **unitairement** (maintenance N1/N2, y compris sans codeur ni joystick selon droits). ⚠️ Treuils **sans variateur** : la vitesse résulte des contacteurs de paliers ; pas de mesure de courant (disjoncteurs seuls) → l'effort se **déduit** de Δposition/Δvitesse.
* **`FB_SpeedStep`** 🪜 — Convertit une consigne en **masque 4 bits** (4 contacteurs) selon le **palier courant** : 5 paliers, chaque palier = masque librement défini (plus de cumul implicite), **table propre à chaque treuil** (`ST_SpeedStepTable`), sélection du palier via `HYSTERESIS`. Sortie : 4 booléens (ou `BYTE` masque) + n° de palier. L'ordre des contacteurs est **donnée** (table), pas codé en dur.
* **`FB_WinchSync`** — Mesure `ΔPos = |PosM1 − PosM2|` (+ dérive vitesse) et régule l'axe rapide (ralentissement par paliers/rampe) **quand les deux treuils sont censés bouger ensemble**. ⚠️ **Suspendue pendant la phase grappin** (`SYNCHRO_ADJUST`, `DESCENDING_OPEN_DUMP`) : la désynchronisation y est **volontaire** (pas de mouvement M1), donc pas de conflit ni de faux défaut synchro. Voir Partie 4 §Synchro/§Grappin.

### 📁 Chariot
* **`FB_Chariot`** (M3) — Pilote le variateur **AC600** (mot cmd/état ; vitesse estimée + consigne fréquence disponibles, **pas** la mesure de courant). Entrées `StartStop`/`SafeStop` comme `FB_Winch`. Approche temporisée puis ralentissement et **arrêt sur capteur** (travail 1/2, vidage). Voir Partie 4 §Chariot.

### 📁 Grappin
* **`FB_Grappin`** — État **ouvert/fermé** via positions codeurs + **mémoire RETAIN**. Contrôle de cohérence au boot (état mémorisé vs position réelle > seuil → état **non sûr** → maintenance + vitesse réduite). Ouverture/fermeture = désynchro M2 (offsets `ST_GrappinConfig`, réglables Maint N2).

### 📁 Séquenceur
* **`FB_Cycle`** — Machine d'état `E_CycleStep` (pseudo-Grafcet). Émet `Enable`/`StartStop`/Sens/SpeedRef vers treuils & chariot ; passage à une étape **sans mouvement** = `StartStop := FALSE` → arrêt sur rampe de décélération **normale** (`Enable` reste actif). Voir Partie 4.

---

## 🔗 5. Flux de données (sans agrégateur)

### 📈 Flux montant (mesures)
```
EtherCAT 4ms : Codeurs COD1/COD2 ──► FB_Encoder_Abs ──► FB_Encoder_Scale ──► (mètres)
                Variateur AC600 ──► mot d'état ──► FB_Chariot
CANopen 20ms : Joystick Hall ──► (image process) ──► FB_Joystick (traité en MainTask 10ms) ──► consigne relative
TOR + retours contacteurs (Partie 6) ──► FB_Safety_<Metier>, FB_Cycle
FB_Diag* ──► (CanHealthy, JoystickAvailable, EncoderM1/M2Available, VariateurAvailable) lus DIRECTEMENT
```
Chaque consommateur lit la **sortie du FB producteur** (appel séquentiel), pas une GVL agrégée.

### 📉 Flux descendant (ordres)
```
FB_Modes (source légitime selon mode) ──► ST_AxisCmd (Enable, StartStop, SpeedRef, Direction)
   ├─► FB_Winch M1/M2 ──► FB_SpeedStep (masque 4 bits) ──► contacteurs ; FB_Brake ──► frein
   ├─► FB_WinchSync (corrige les consignes M1/M2 si dérive — hors phase grappin)
   ├─► FB_Chariot ──► variateur AC600
   └─► FB_Grappin (phase grappin : désynchro M2 ; FB_WinchSync suspendue durant cette phase)
```

### 🛡️ Flux sécurité (priorité absolue)
```
FB_Safety_<Metier> défaut process du domaine ──► SafeStop_<Metier> := TRUE
   → FB de mouvement du domaine : rampe de décélération RAPIDE (Enable inchangé)
   → freins se collent (FB_Brake) en fin de rampe
   → FB_Cycle se fige (ERROR_HOLD) si le défaut impacte le cycle en cours
FB_Safety_<Metier> contacteur collé ──► PowerCutOff := TRUE ──► coupure puissance amont (matériel)
```

### 🚦 Diagnostics → actions granulaires (via FB_Modes + interlocks)
| Défaut détecté | Signal (lecture directe FB_Diag) | Conséquence (FB_Modes / interlocks) |
|----------------|----------------------------------|--------------------------------------|
| CANopen / joystick down | `CanHealthy=0`, `JoystickAvailable=0` | Commande manuelle interdite, cycle en HOLD sûr (Ready=0) |
| Codeur M1 down | `EncoderM1Available=0` | Treuil M1 bloqué (Ready=0), M2 dégradé, auto interdit |
| Codeur M2 down | `EncoderM2Available=0` | Treuil M2 bloqué, M1 dégradé, auto interdit |
| Variateur M3 down | `VariateurAvailable=0` | Chariot interdite, treuils nominaux possibles |
| Contacteur collé | retour ≠ commande (`ST_ContactorCheck`) | `FB_Safety_<Metier>.PowerCutOff` → coupure puissance immédiate |

---

## 🚦 6. Arrêt d'urgence (AU) vs `SafeStop` vs `PowerCutOff`

| Couche | Élément | Nature | Action |
|--------|---------|--------|--------|
| Matérielle | Bouton coup-de-poing (opérateur) | Câblé | Coupe le **contacteur de puissance** → moteurs OFF + freins collés **brutalement**. Automate/CC **non coupés**, continue de surveiller. **Seul** AU purement matériel restant (2026-07-02). |
| Matérielle ⟵ Logiciel | Sortie **`PowerCutOff`** (= `AuTrigger`) | Cmd PLC → relais coupure | 2 causes possibles : (1) un **contacteur de puissance reste collé** (historique) ; (2) **capteur de position haute treuil activé hors mode référencement** (2026-07-02 — ancien câble mécanique « montée excessive », désormais lu par l'automate, voir Partie 1 §Sécurité électrique / Partie 10). Les deux ouvrent le **contacteur général amont**. |
| Logicielle | **`SafeStop`** (sortie d'un bloc safety **métier**, une par domaine) | Variable interne, propre au métier | Sur défaut process de son domaine : le(s) FB de mouvement concerné(s) passent en **rampe de décélération rapide** (**Enable maintenu**). **≠ AU** : c'est le **seul** mécanisme non-brutal ; **seul l'AU coupe brutalement** la puissance. |
| Logicielle | `EmergencyStopOk` (entrée FB, anciennement `SafetyOk`) | Info | Reflète « AU réarmé + conditions globales OK » — alimentée par la chaîne de sécurité AU ou le retour du contacteur de puissance (source exacte à définir par métier). |

🧭 L'AU physique reste la sécurité ultime **indépendante** et **la seule à couper brutalement**.
`PowerCutOff` gère le cas du contacteur collé (coupure électrique amont). `SafeStop` gère les
défauts process **par métier** (rampe rapide, non destructive). Réarmement AU = **physique**,
n'efface pas les alarmes (acquittement IHM séparé, reset front — voir Partie 3).

---

## 🚦 7. Chaîne logique d'exécution (1 cycle MainTask 10 ms)

```text
[0. DIAG]   ─► [1. IO IN]  ─► [2. SÉCURITÉ]           ─► [3. MODES] ─► [4. MÉTIER]        ─► [5. IO OUT]
 FB_DiagCan     FB_Input      FB_Safety_<Metier>×N       FB_Modes       FB_Winch M1/M2        FB_Output
 FB_DiagEcat×3  (TOR cond.)   (SafeStop par domaine,      (source+droits FB_SpeedStep/WinchSync (relais+feedback)
                retours contact PowerCutOff)                             +limite légale)FB_Chariot/Grappin
                                                                                          FB_Cycle
```

⚠️ **Priorité étape 2** : chaque `FB_Safety_<Metier>` lève son `SafeStop` propre → les FB de
mouvement du domaine concerné entrent en rampe de décélération rapide dès l'étape 4 (métier) ;
un contacteur collé déclenche `PowerCutOff` (coupure puissance amont, indépendante du cycle).

---

## 📌 8. Notes d'implémentation (types conservés / mis à jour)

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

### ST_AxisCmd (mis à jour v2.5)
```
STRUCT ST_AxisCmd
  Enable      : BOOL;   // autorisation FB (FALSE = neutralisation, sorties coupées)
  StartStop   : BOOL;   // TRUE = rampe accélération, FALSE = rampe décélération normale
  SpeedRef    : REAL;   // consigne vitesse %
  Direction   : INT;    // -1/0/+1
END_STRUCT
```

> 🗑️ **Retirés** : `E_DegradationLevel`, `ST_BusHealth`, `GVL_BusHealth`, **`CoupeEnable`**
> (n'a jamais été une variable). La dégradation est portée par `FB_Modes` + les `Enable`/`Ready`
> conditionnels de chaque FB. L'arrêt sûr est porté par `SafeStop` (par métier) + `StartStop`.

---

## 🔄 9. Hiérarchie des appels (chronologie 1 cycle)

```
EtherCatTask (4ms)  : rafraîchit images process EtherCAT (COD1/M1, COD2/M2, AC600/M3)
CanTask (20ms)      : rafraîchit image process CANopen (joystick) — pas de traitement ici

MainTask (10ms)
  └─ PLC_PRG_MAIN
     ├─ [DIAG] FB_DiagCanOpen() ; FB_DiagEthercat(COD1/M1, COD2/M2, AC600/M3)
     ├─ [IO IN]  Input[1..n]()                    // conditionnement TOR + retours contacteurs
     ├─ FB_Safety_<Metier>() ×N → SafeStop_<Metier>, PowerCutOff (lit sorties FB_Diag + ST_ContactorCheck)
     ├─ FB_Modes()    → source + droits + overrides + limite légale
     ├─ FB_Joystick()                              // traitement (calibration/filtre/rampe) ici, 10 ms
     ├─ FB_Encoder_Abs(COD1) → Scale → Safety ; FB_Encoder_Abs(COD2) → Scale → Safety
     ├─ FB_Winch(M1) / FB_Winch(M2)  → FB_SpeedStep (masque 4 bits) + FB_Brake ; FB_WinchSync() (hors phase grappin)
     ├─ FB_Chariot(M3)
     ├─ FB_Grappin()
     ├─ FB_Cycle()                                // machine d'état E_CycleStep
     └─ [IO OUT] Output[1..m]()                    // relais vitesse/sens pilotés par StartStop/SafeStop de chaque FB ; PowerCutOff
```

---

## 📚 Documents liés
- **Partie 1** — Présentation & équipements.
- **Partie 3** — Contrat FB commun : interface (`Enable/Reset/EmergencyStopOk/Mode`, `StartStop`), état, ErrorId, reset, AU/PowerCutOff.
- **Partie 4** — Cycle & séquenceur : `E_CycleStep`, INIT, synchro, frein, chariot, grappin, rampes.
- **Partie 5** — Modes & maintenance : Manuel/N1/N2/SemiAuto, AU/`SafeStop`/`PowerCutOff`, limite légale (`FB_Modes`).
- **Partie 6** — Conditionnement E/S : `FB_Input_Digital`, `FB_Output_Relay`, `ST_ContactorCheck`.
