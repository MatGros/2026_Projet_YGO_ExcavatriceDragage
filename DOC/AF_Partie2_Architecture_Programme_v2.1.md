# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (Détaillée)

## ⏱️ 1. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | Haute (0) | Rapide (Bus) | **PRG_EthercatMonitor** : appelle 3×`FB_DiagEthercat` (M1, M2, Variateur) → écrit dans `GVL_BusHealth`. |
| 🔌 **CanTask** | Moyenne (1) | Moyenne (10ms) | **PRG_CanMonitor** : appelle `FB_DiagCanOpen` (bus + joystick) → écrit dans `GVL_BusHealth`. |
| 🧠 **MainTask** | Standard (10) | Cyclique (20ms) | Logique métier : `FB_Safety`, `InstanceJoystick`, `FB_Winch`, `FB_Encoder_Abs` (lisent `GVL_BusHealth`), séquençage cycle. |

🧭 **Règle d'or** : Couche basse rafraîchit (Bus) → Couche haute consomme (`MainTask`).

---

## 🌳 2. Arborescence Visuelle du Projet (CODESYS)

```text
Application (PLC_PRG)
├── 📁 _COMMON (Briques génériques mutualisées)
│   ├── FB_FilterPT1         (Filtre premier ordre pour signaux analogiques)
│   └── FB_Brake             (Gestion de la logique levage & temporisation frein)
├── 📁 _TYPES (Structures & énumérations globales)
│   ├── 📄 ST_AxisCmd        (Structure de consigne générique)
│   ├── 📄 ST_BusHealth      (État santé CAN + EtherCAT par équipement)
│   ├── 📄 ST_WinchIO        (Structure d'état/commande Treuil)
│   ├── 📄 ST_TransIO        (Structure d'état/commande Translation)
│   ├── 📄 ST_EncoderData    (Structure de données traitées codeur)
│   ├── 📄 E_Mode            (Énumération des modes de marche)
│   ├── 📄 E_DegradationLevel (FULL / LEVEL1 / LEVEL2 / MAINTENANCE)
│   └── 📄 E_CycleStep       (Énumération des étapes du séquenceur)
├── 📁 _DIAG (Diagnostics bus communication)
│   ├── GVL_BusHealth        (Santé CAN + EtherCAT partagée, mise à jour par tâches basses)
│   ├── FB_DiagCanOpen       (Moniteur CANopen bus + nœud Joystick)
│   └── FB_DiagEthercat      (Moniteur esclave EtherCAT unique)
├── 📁 JOYSTICK (Traitement commande opérateur)
│   ├── FB_Joystick          (Traitement complet joystick : filtre, rampe, calibration)
│   └── PRG_CanMonitor       (Exécuté par CanTask : appelle FB_DiagCanOpen)
├── 📁 WINCH (Gestion de la plongée/extraction)
│   ├── FB_Winch             (Directeur de treuil individuel)
│   └── FB_SpeedStep         (Décodeur de paliers de vitesse pour contacteurs)
├── 📁 ENCODER (Traitement de la position câble)
│   ├── FB_Encoder_Abs       (Lecture + validation EtherCAT, latch défauts)
│   ├── FB_Encoder_Scale     (Mise à l'échelle en mètres via LIN_TRAFO)
│   ├── FB_Encoder_Safety    (Vérifications cohérence position / limites)
│   └── PRG_EthercatMonitor  (Exécuté par EthercatTask : appelle 3×FB_DiagEthercat pour M1/M2/Variateur)
├── 📁 TRANSLATION (Gestion déplacement pont)
│   └── FB_Translation       (Régulation vitesse/position sur variateur)
├── 📁 BUCKET (Gestion cinématique godet)
│   └── FB_Bucket            (Calculateur de désynchronisation de position)
├── 📁 SAFETY (Surveillance & mise en sécurité)
│   ├── FB_Safety            (Superviseur des défauts machine & limites)
│   └── FB_Watchdog          (Contrôle d'activité des tâches & bus)
└── 📁 SEQUENCE (Orchestration générale)
    ├── FB_Modes             (Arbitrage des sources de commande)
    └── FB_Cycle             (Séquenceur semi-automatique principal)

```

---

## 🧱 3. Liste Exhaustive des Fonctions

### 📁 Couche Coordination & Séquencement

* **`FB_Cycle` (Séquenceur Semi-Automatique)**
* *Désignation* : Séquenceur principal du procédé de dragage.
* *But* : Gérer la machine d'état du cycle (Descente, Synchro, Extraction, Égouttage, Déplacement, Vidage).


* **`FB_Modes` (Arbitrage des Modes)**
* *Désignation* : Gestionnaire des modes de marche et autorisations associées.
* *But* : Commuter et filtrer l'origine des ordres selon le mode actif (`Manuel`, `Maint_N1`, `Maint_N2`, `Auto`).



### 📁 Couche Objets Métier (Principaux)

* **`FB_Winch` (Gestionnaire de Treuil)**
* *Désignation* : Bloc de contrôle d'un enrouleur de câble de levage.
* *But* : Sélectionner le sens, commander exclusivement les contacteurs de vitesse et séquencer l'ouverture/fermeture du frein.


* **`FB_Translation` (Gestionnaire d'Axe Transversal)**
* *Désignation* : Bloc de contrôle du déplacement latéral du pont roulant.
* *But* : Communiquer avec le variateur via son mot de commande/état, gérer la consigne de vitesse en % et les rampes de décélération pour arrêt précis.


* **`FB_Bucket` (Calculateur Cinématique Godet)**
* *Désignation* : Coordinateur d'ouverture et fermeture du godet.
* *But* : Traduire un ordre d'ouverture/fermeture en désynchronisation de position physique entre le Treuil A et le Treuil B.



### 📁 Couche Composants & Sous-Fonctions

* **`FB_SpeedStep` (Sélecteur de Contacteurs de Vitesse)**
* *Désignation* : Décodeur logique de paliers discrets.
* *But* : Convertir une consigne de vitesse analogique ou en % en activations exclusives de 4 relais physiques avec gestion des transitions.


* **`FB_Brake` (Logique de Freinage Levage)**
* *Désignation* : Temporisateur de sécurité pour frein de maintien à manque de courant.
* *But* : Assurer le maintien de charge (attente magnétisation moteur au démarrage avant ouverture, collage immédiat à l'arrêt).


* **`FB_JoystickCAN` (Traitement Joystick)**
* *Désignation* : Conditionneur de signal pour organe de commande CANopen.
* *But* : Filtrer le signal brut (0-10000 pts), calibrer dynamiquement le zéro, appliquer la zone morte et injecter les rampes d'accélération.



### 📁 Couche Chaîne de Mesure (Codeurs)

* **`FB_EncoderRead` (Acquisition Codeur)**
* *Désignation* : Interface basse pour capteur angulaire absolu.
* *But* : Collecter les trames cycliques du réseau EtherCAT et valider l'intégrité de la communication.


* **`FB_EncoderScale` (Mise à l'échelle Câble)**
* *Désignation* : Convertisseur de grandeurs physiques.
* *But* : Transformer les points codeurs bruts en valeur de déroulé de câble en mètres avec 2 décimales via `LIN_TRAFO`.


* **`FB_EncoderHoming` (Référencement Plan d'Eau)**
* *Désignation* : Algorithme de calibration de niveau.
* *But* : Définir le point zéro réel au niveau du plan d'eau et sauvegarder l'offset en mémoire persistante (RETAIN).



### 📁 Couche Sécurité Transverse

* **`FB_Safety` (Superviseur de Sécurité)**
* *Désignation* : Gestionnaire centralisé des défauts machine.
* *But* : Valider la cohérence des capteurs, interdire les consignes aberrantes, borner la limite légale et lever le signal `SafeStop`.


* **`FB_Watchdog` (Surveillance Activité)**
* *Désignation* : Chien de garde logiciel des communications.
* *But* : Surveiller la bonne périodicité d'exécution des tâches critiques et l'état en ligne des bus de terrain.



---

## 🔗 4. Interactions & Flux Critiques (Données, Consignes & Procédés)

### 📈 Flux Montant (Mesures et Signaux)

**Tâche basse : Diagnostics bus (rafraîchit `GVL_BusHealth`)**
1. **CanTask** → `PRG_CanMonitor` appelle `FB_DiagCanOpen` (lit bus CANopen + nœud Joystick)
   - Outputs : `CanHealthy`, `JoystickAvailable` → `GVL_BusHealth`
2. **EthercatTask** → `PRG_EthercatMonitor` appelle 3×`FB_DiagEthercat` (M1, M2, Variateur)
   - Outputs : `EncoderM1Available`, `EncoderM2Available`, `VariateurAvailable` → `GVL_BusHealth`

**Tâche haute : Logique métier (consomme `GVL_BusHealth`)**
3. Le **Joystick physique** transmet ses positions brutes (CanTask) → `FB_Joystick` (MainTask) lit `GVL_BusHealth.JoystickAvailable`.
4. Les **Codeurs tambours** renvoient les points (EthercatTask) → `FB_Encoder_Abs` (MainTask) lit `GVL_BusHealth.EncoderM1/M2Available` et décide son propre `E_DegradationLevel`.
5. `FB_EncoderScale` calcule le déroulé en mètres et le distribue à `FB_Winch` + `FB_Safety`.
6. Les **Capteurs TOR** alimentent directement `FB_Safety` et `FB_Cycle`.

### 📉 Flux Descendant (Ordres et Procédés)

1. `FB_Modes` sélectionne la source légitime (Joystick en manuel, `FB_Cycle` en automatique) et transmet une structure `ST_AxisCmd` unifiée.
2. `FB_Winch` (A et B) reçoit la consigne, sollicite `FB_SpeedStep` pour positionner les contacteurs physiques et pilote le frein de levage via `FB_Brake`.
3. `FB_Translation` intercepte sa consigne de vitesse en %, applique la décélération à l'approche de la position cible et active l'arrêt exact sur capteur.
4. En phase de vidage, `FB_Bucket` applique une désynchronisation calculée aux treuils pour provoquer l'ouverture mécanique du godet.

### 🛡️ Flux Transverse de Sécurité (Priorité Absolue)

**Inputs granulaires vers FB_Safety**
- `FB_Safety` reçoit via `GVL_BusHealth` :
  - `CanHealthy` (CANopen bus + Joystick opérationnels?)
  - `EncoderM1Available`, `EncoderM2Available`, `VariateurAvailable` (quels équipements sont disponibles?)
  - `JoystickAvailable` (opérateur peut-il commander?)

**Adaptation locale de chaque FB**
- `FB_Safety` décide son propre `E_DegradationLevel` (FULL / LEVEL1 / LEVEL2 / MAINTENANCE) selon les inputs reçus.
- `FB_Winch` décide son propre niveau (ex: bloqué si M1 down, semi-opérationnel si M2 down).
- `FB_Encoder_Abs` décide son propre niveau (ex: bloqué si EtherCAT down, nominal sinon).

**Arrêt sûr**
1. Dès qu'un défaut critique est détecté par `FB_Safety`, le variable **`SafeStop` passe à `TRUE`**.
2. Ce bit `SafeStop` est propagé à l'entrée de tous les blocs opérationnels (`FB_Winch`, `FB_Translation`, `FB_Cycle`, `FB_Joystick`).
3. L'interaction est immédiate : coupure instantanée de toutes les sorties relais et collage des freins.

---

## 🚦 5. Chaîne Logique d'Exécution (1 Cycle Automate)

```text
[1. ENTRÉES] ──► [2. SÉCURITÉ] ──► [3. FILTRAGE] ──► [4. DÉCISION] ──► [5. ACTION] ──► [6. SORTIES]
 Joystick         FB_Safety         FB_Modes         FB_Cycle         FB_Winch         Contacteurs
 Codeurs          (SafeStop?)       (Autorise?)      (Étape en cours) FB_Translation   Freins
 Capteurs TOR                                                         FB_Bucket        Variateur

```

⚠️ **Priorité Étape 2** : Si `FB_Safety` lève un défaut, toute la logique interne des étapes suivantes est ignorée pour figer les actionneurs dans l'état de repli le plus sûr.