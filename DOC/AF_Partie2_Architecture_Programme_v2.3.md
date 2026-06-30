# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (v2.3)

> **Version 2.3** — Suppression des PRG moniteurs (diag appelés dans `PLC_PRG_MAIN`), `FB_Safety` étendu à la sécurité électrique (contacteur collé → coupure puissance), `FB_SpeedStep` refondu en masque 4 bits/palier par treuil, mapping physique M1/M2/M3 explicite.
> Historique : v2.2 (diag distribué sans agrégateur), v2.1 (archive).

## ⏱️ 1. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | Haute (0) | Rapide (Bus) | Rafraîchissement images process EtherCAT (codeurs M1/M2, variateur M3). **Pas de PRG moniteur.** |
| 🔌 **CanTask** | Moyenne (1) | Moyenne (10ms) | Rafraîchissement image process CANopen (joystick). **Pas de PRG moniteur.** |
| 🧠 **MainTask** | Standard (10) | Cyclique (20ms) | `PLC_PRG_MAIN` : **diagnostics bus** (`FB_DiagCanOpen` + 3×`FB_DiagEthercat`) → `GVL_BusHealth`, puis logique métier (`FB_Safety`, joystick, treuils, codeurs, séquence). |

🧭 **Règle d'or (v2.3)** : les images process bus sont rafraîchies par les tâches bus ; **toute la logique applicative — diagnostics inclus — est centralisée dans `PLC_PRG_MAIN`** (MainTask).

⚠️ **Implication de cadence** : les `FB_Diag*` tournent désormais à **20ms** (MainTask) et non plus à la cadence bus. Acceptable car la détection de perte de bus reste largement sous le timeout des équipements ; si une réactivité bus < 20ms devenait nécessaire, réintroduire un moniteur dédié sur la tâche bus.

---

## 🌳 2. Arborescence Visuelle du Projet (CODESYS)

```text
Application (PLC_PRG → PLC_PRG_MAIN sur MainTask)
├── 📁 _COMMON (Briques génériques mutualisées)
│   ├── FB_FilterPT1         (Filtre premier ordre — sinon préférer Util si dispo)
│   └── FB_Brake             (Gestion de la logique levage & temporisation frein)
├── 📁 _TYPES (Structures & énumérations globales)
│   ├── 📄 ST_AxisCmd        (Structure de consigne générique)
│   ├── 📄 ST_BusHealth      (État santé CAN + EtherCAT par équipement)
│   ├── 📄 ST_WinchIO        (Structure d'état/commande Treuil)
│   ├── 📄 ST_TransIO        (Structure d'état/commande Translation)
│   ├── 📄 ST_EncoderData    (Structure de données traitées codeur)
│   ├── 📄 ST_SpeedStepTable (5 masques 4 bits — table de paliers d'UN treuil)
│   ├── 📄 ST_ContactorCheck (Commande + retour + diagnostic collage d'un contacteur)
│   ├── 📄 E_Mode            (Énumération des modes de marche)
│   ├── 📄 E_DegradationLevel (FULL / LEVEL1 / LEVEL2 / MAINTENANCE)
│   └── 📄 E_CycleStep       (Énumération des étapes du séquenceur)
├── 📁 _DIAG (Diagnostics bus communication)
│   ├── GVL_BusHealth        (Santé CAN + EtherCAT partagée, mise à jour par PLC_PRG_MAIN)
│   ├── FB_DiagCanOpen       (Moniteur CANopen bus + nœud Joystick)
│   └── FB_DiagEthercat      (Moniteur esclave EtherCAT unique)
├── 📁 JOYSTICK (Traitement commande opérateur)
│   └── FB_Joystick          (Traitement complet joystick : filtre, rampe, calibration)
├── 📁 WINCH (Gestion de la plongée/extraction)
│   ├── FB_Winch             (Directeur de treuil individuel — M1, M2)
│   └── FB_SpeedStep         (Décodeur de paliers → masque 4 bits/palier, table par treuil)
├── 📁 ENCODER (Traitement de la position câble)
│   ├── FB_Encoder_Abs       (Lecture + validation EtherCAT, latch défauts — COD1/COD2)
│   ├── FB_Encoder_Scale     (Mise à l'échelle en mètres via LIN_TRAFO)
│   └── FB_Encoder_Safety    (Vérifications cohérence position / limites)
├── 📁 TRANSLATION (Gestion déplacement pont)
│   └── FB_Translation       (Régulation vitesse/position sur variateur AC600 — M3)
├── 📁 BUCKET (Gestion cinématique godet)
│   └── FB_Bucket            (Calculateur de désynchronisation de position)
├── 📁 SAFETY (Surveillance & mise en sécurité)
│   ├── FB_Safety            (Superviseur défauts + cohérence contacteurs + coupure puissance)
│   └── FB_Watchdog          (Contrôle d'activité des tâches & bus)
└── 📁 SEQUENCE (Orchestration générale)
    ├── FB_Modes             (Arbitrage des sources de commande)
    └── FB_Cycle             (Séquenceur semi-automatique principal)
```

> 🗑️ **Supprimés en v2.3** : `PRG_CanMonitor` et `PRG_EthercatMonitor`. Les instances `FB_DiagCanOpen` et `FB_DiagEthercat` (×3) sont déclarées et appelées directement dans `PLC_PRG_MAIN`.

---

## 🗺️ 3. Mapping physique (référence)

| Repère | FB / POU | Équipement physique | Bus / Adresse |
|--------|----------|---------------------|---------------|
| **M1** | `FB_Winch` (instance M1) + `FB_Encoder_Abs` **COD1** | Treuil levage 1 + codeur absolu tambour 1 | EtherCAT (esclave codeur M1) |
| **M2** | `FB_Winch` (instance M2) + `FB_Encoder_Abs` **COD2** | Treuil levage 2 + codeur absolu tambour 2 | EtherCAT (esclave codeur M2) |
| **M3** | `FB_Translation` | Variateur **AC600** axe transversal | EtherCAT (esclave variateur) |

🧭 `COD1`=codeur **M1**, `COD2`=codeur **M2**, `AC600`=variateur **M3**. Toute instance/variable doit respecter cette correspondance.

---

## 🧱 4. Liste Exhaustive des Fonctions

### 📁 Couche Diagnostics Bus

* **`FB_DiagCanOpen` (Moniteur CANopen)**
* *But* : Vérifier l'état du bus (online / operational) et du nœud joystick.
* *Outputs → GVL_BusHealth* : `CanHealthy`, `JoystickAvailable`
* *Appelée par* : **`PLC_PRG_MAIN`** (MainTask) — 1 instance.

* **`FB_DiagEthercat` (Moniteur esclave EtherCAT)**
* *But* : Vérifier l'intégrité de la communication avec un esclave (WcState, SlaveState).
* *Outputs → GVL_BusHealth* : `EncoderM1Available`, `EncoderM2Available`, `VariateurAvailable`
* *Appelée par* : **`PLC_PRG_MAIN`** (MainTask) — **3 instances** (COD1/M1, COD2/M2, Variateur/M3).
* *Interface standard AF_Partie3*.

### 📁 Couche Coordination & Séquencement

* **`FB_Cycle`** : Séquenceur principal du procédé (Descente, Synchro, Extraction, Égouttage, Déplacement, Vidage).
* **`FB_Modes`** : Commute et filtre l'origine des ordres selon le mode (`Manuel`, `Maint_N1`, `Maint_N2`, `Auto`).

### 📁 Couche Objets Métier

* **`FB_Winch` (Gestionnaire de Treuil)** — instances M1, M2
* *But* : Sélectionner le sens, commander les contacteurs de vitesse via `FB_SpeedStep`, séquencer le frein.
* *Inputs depuis GVL_BusHealth* : `EncoderM1Available` / `EncoderM2Available` selon l'instance.

* **`FB_Translation` (Axe Transversal M3 — variateur AC600)**
* *But* : Mot de commande/état variateur, consigne vitesse %, rampes de décélération pour arrêt précis.
* *Inputs depuis GVL_BusHealth* : `VariateurAvailable`.

* **`FB_Bucket`** : Traduit un ordre ouverture/fermeture godet en désynchronisation de position entre M1 et M2.

### 📁 Couche Composants & Sous-Fonctions

* **`FB_SpeedStep` (Décodeur de Paliers — masque 4 bits)** 🪜 *(refondu v2.3)*
* *But* : Convertir une consigne de vitesse en un **masque de 4 bits** (4 contacteurs) selon le **palier courant**.
* *Principe* :
  - **5 paliers**, chaque palier ⇒ un masque 4 bits **librement défini** (plus de cumul implicite 1→2→3→4).
  - **Table de masques propre à chaque treuil** (M1 et M2 indépendants) — type `ST_SpeedStepTable`.
  - Sélection du palier à partir de la consigne via `HYSTERESIS` (anti-battement).
  - Sortie : 4 booléens de contacteurs (ou un `BYTE` masque) + n° de palier actif.
* *Note* : l'ordre d'actionnement des contacteurs est **données** (table), pas codé en dur.

* **`FB_Brake`** : Maintien de charge (attente magnétisation au démarrage, collage immédiat à l'arrêt).

* **`FB_Joystick`** : Filtre signal brut (0-10000 pts), calibre le zéro, zone morte, rampes. Lit `GVL_BusHealth.JoystickAvailable`.

### 📁 Couche Chaîne de Mesure (Codeurs)

* **`FB_Encoder_Abs`** (COD1→M1, COD2→M2) : Lecture EtherCAT, validation, défauts latching. Gate sur `EncoderM1/M2Available`.
* **`FB_Encoder_Scale`** : Points bruts → mètres (2 décimales) via `LIN_TRAFO`.
* **`FB_Encoder_Safety`** : Cohérence position et limites (fond, maintenance, fdc).

### 📁 Couche Sécurité Transverse

* **`FB_Safety` (Superviseur de Sécurité)** 🔌 *(étendu v2.3)*
* *But* : Valider la cohérence capteurs, interdire les consignes aberrantes, borner la limite légale, lever `SafeStop` — **et garantir la coupure physique de la puissance malgré un automate jamais coupé**.
* *Inputs depuis GVL_BusHealth* : `CanHealthy`, `EncoderM1Available`, `EncoderM2Available`, `VariateurAvailable`, `JoystickAvailable`.
* *Inputs sécurité électrique* : **retour d'état câblé de chaque contacteur de puissance** (`ST_ContactorCheck`).
* *Comportement* :
  - Calcule son propre `E_DegradationLevel` selon les équipements disponibles.
  - **Surveillance collage** : compare la **commande** envoyée à chaque contacteur avec son **retour d'état**. Incohérence persistante (API commande l'ouverture mais retour = fermé) ⇒ **contacteur collé**.
  - Sur collage détecté ⇒ lève la **sortie de coupure puissance** (`PowerCutOff`) qui ouvre le contacteur général amont et coupe **électriquement** la puissance.
  - Décide aussi le `SafeStop` global.

* **`FB_Watchdog`** : Chien de garde des tâches critiques et de l'état en ligne des bus.

---

## 🔗 5. Interactions & Flux Critiques

### 📈 Flux Montant (Mesures et Signaux)

**Dans `PLC_PRG_MAIN` (MainTask, en tête de cycle) — Diagnostics bus :**
1. `FB_DiagCanOpen()` lit l'image CANopen → `CanHealthy`, `JoystickAvailable` → `GVL_BusHealth`.
2. `FB_DiagEthercat()` ×3 (COD1/M1, COD2/M2, Variateur/M3) → `EncoderM1Available`, `EncoderM2Available`, `VariateurAvailable` → `GVL_BusHealth`.

**Puis logique métier (même cycle MainTask, consomme `GVL_BusHealth`) :**
3. `FB_Joystick` lit `JoystickAvailable`.
4. `FB_Encoder_Abs` (COD1/COD2) lit `EncoderM1/M2Available` et décide son `E_DegradationLevel`.
5. `FB_Encoder_Scale` calcule le déroulé en mètres → `FB_Winch` + `FB_Safety`.
6. Les capteurs TOR + **retours contacteurs** alimentent `FB_Safety` et `FB_Cycle`.

### 📉 Flux Descendant (Ordres et Procédés)

1. `FB_Modes` sélectionne la source (Joystick en manuel, `FB_Cycle` en auto) → `ST_AxisCmd`.
2. `FB_Winch` (M1, M2) reçoit la consigne, sollicite `FB_SpeedStep` (→ masque 4 bits du palier), pilote le frein via `FB_Brake`.
3. `FB_Translation` (M3) applique la décélération à l'approche cible, arrêt exact sur capteur.
4. En vidage, `FB_Bucket` désynchronise M1/M2 pour ouvrir le godet.

### 🛡️ Flux Transverse de Sécurité (Priorité Absolue)

**Adaptation locale** : chaque FB métier décide son `E_DegradationLevel` selon `GVL_BusHealth`.
- `FB_Safety` : MAINTENANCE si CAN down, LEVEL2 si M1+M2 down, LEVEL1 si M1 (ou M2) down, FULL sinon.
- `FB_Winch` : bloqué si son codeur down, nominal sinon.
- `FB_Encoder_Abs` : bloqué si EtherCAT down.

**Arrêt sûr (2 niveaux) :**
1. `SafeStop = TRUE` propagé à tous les blocs opérationnels ⇒ coupure des sorties relais + collage freins.
2. **Coupure puissance physique** : si un contacteur **reste collé** malgré l'ordre d'ouverture, `FB_Safety.PowerCutOff` ouvre le contacteur général amont ⇒ la puissance est **coupée électriquement** (indépendant de l'état de l'automate, qui n'est jamais coupé).

### 🚦 Diagnostics bus → actions granulaires

| Défaut détecté | Bit `GVL_BusHealth` | Conséquence (autorisations) |
|----------------|---------------------|------------------------------|
| CANopen / joystick down | `CanHealthy=0`, `JoystickAvailable=0` | `FB_Safety`→MAINTENANCE, commande manuelle interdite, cycle en HOLD sûr |
| Codeur M1 down | `EncoderM1Available=0` | Treuil M1 bloqué, M2 dégradé, auto interdit |
| Codeur M2 down | `EncoderM2Available=0` | Treuil M2 bloqué, M1 dégradé, auto interdit |
| Variateur M3 down | `VariateurAvailable=0` | Translation interdite, treuils nominaux possibles |
| Contacteur collé | retour ≠ commande (`ST_ContactorCheck`) | `FB_Safety.PowerCutOff` → coupure puissance immédiate |

---

## 🚦 6. Chaîne Logique d'Exécution (1 Cycle Automate)

```text
[0. DIAG BUS]   ──► [1. ENTRÉES]   ──► [2. SÉCURITÉ]    ──► [3. FILTRAGE]  ──► [4. DÉCISION] ──► [5. ACTION]   ──► [6. SORTIES]
 FB_DiagCanOpen      Joystick           FB_Safety            FB_Modes           FB_Cycle         FB_Winch         Contacteurs
 3×FB_DiagEthercat   Codeurs            (SafeStop)           (Autorise?)        (Étape)          FB_Translation   Freins
 → GVL_BusHealth     Capteurs TOR       (PowerCutOff)        (Mode)                              FB_Bucket        PowerCutOff
                     Retours contacteur (GVL_BusHealth)
```

⚠️ **Priorité Étape 2** : tout défaut levé par `FB_Safety` fige les actionneurs dans l'état de repli le plus sûr ; un contacteur collé déclenche la coupure puissance amont.

---

## 📌 7. Notes d'implémentation (types)

### E_DegradationLevel
```
ENUM E_DegradationLevel
  FULL        := 0;  // Tous équipements OK
  LEVEL1      := 1;  // Dégradation mineure (1 codeur ou variateur KO)
  LEVEL2      := 2;  // Dégradation significative (2 codeurs down)
  MAINTENANCE := 3;  // Immobilisation (CAN bus down, joystick KO, maintenance)
END_ENUM
```

### ST_BusHealth
```
STRUCT ST_BusHealth
  CanHealthy          : BOOL;  // CANopen opérationnel?
  JoystickAvailable   : BOOL;  // Nœud joystick en ligne et opérationnel?
  EncoderM1Available  : BOOL;  // Esclave COD1 (codeur M1) accessible?
  EncoderM2Available  : BOOL;  // Esclave COD2 (codeur M2) accessible?
  VariateurAvailable  : BOOL;  // Esclave variateur AC600 (M3) accessible?
  EthercatHealthy     : BOOL;  // (Optionnel) tous esclaves EtherCAT OK?
  GlobalHealthy       : BOOL;  // (Optionnel) CAN + EtherCAT tous OK?
END_STRUCT
```

### ST_SpeedStepTable (nouveau — paliers masque 4 bits, 1 par treuil)
```
STRUCT ST_SpeedStepTable
  // 5 paliers ; chaque palier = masque 4 bits (bit0..bit3 = contacteurs 1..4)
  StepMask     : ARRAY[1..5] OF BYTE;   // ex: StepMask[1] := 2#0001;
  // Seuils de consigne pour changer de palier (avec HYSTERESIS)
  StepThreshold_Pct : ARRAY[1..5] OF REAL;
END_STRUCT
```

### ST_ContactorCheck (nouveau — surveillance collage)
```
STRUCT ST_ContactorCheck
  Command       : BOOL;   // ordre envoyé au contacteur (TRUE = fermé/actif)
  Feedback      : BOOL;   // retour d'état câblé (TRUE = effectivement fermé)
  StuckClosed   : BOOL;   // diag : commande OFF mais retour ON depuis trop longtemps
  StuckOpen     : BOOL;   // diag : commande ON mais retour OFF (option)
END_STRUCT
```

### GVL_BusHealth
Déclarée dans `_DIAG`, exposée globalement. **Mise à jour par `PLC_PRG_MAIN`** (MainTask, en tête de cycle). Consommée par tous les FB métier (même cycle).

---

## 🔄 8. Hiérarchie des appels (chronologie 1 cycle)

```
EtherCatTask (rapide) : rafraîchit images process EtherCAT (COD1/M1, COD2/M2, AC600/M3)
CanTask (10ms)        : rafraîchit image process CANopen (joystick)

MainTask (20ms)
  └─ PLC_PRG_MAIN
     ├─ [DIAG] FB_DiagCanOpen()            → GVL_BusHealth.CanHealthy, .JoystickAvailable
     ├─ [DIAG] FB_DiagEthercat(COD1/M1)    → GVL_BusHealth.EncoderM1Available
     ├─ [DIAG] FB_DiagEthercat(COD2/M2)    → GVL_BusHealth.EncoderM2Available
     ├─ [DIAG] FB_DiagEthercat(AC600/M3)   → GVL_BusHealth.VariateurAvailable
     ├─ InstanceSafety()  (lit GVL_BusHealth + retours contacteurs) → SafeStop, PowerCutOff
     ├─ InstanceJoystick() (lit JoystickAvailable)
     ├─ EncoderM1 (FB_Encoder_Abs, COD1)  (lit EncoderM1Available)
     ├─ EncoderM2 (FB_Encoder_Abs, COD2)  (lit EncoderM2Available)
     ├─ FB_Winch(M1) / FB_Winch(M2)  → FB_SpeedStep (masque 4 bits) + FB_Brake
     ├─ FB_Translation(M3)
     └─ FB_Modes / FB_Cycle / FB_Bucket
```
