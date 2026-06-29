# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (Détaillée)

## ⏱️ 1. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | Haute (0) | Rapide (Bus) | Lecture synchrone codeurs, communication variateur, blocs `diagETHERCAT`. |
| 🔌 **CanTask** | Moyenne (1) | Moyenne (10ms) | Lecture trames PDO du joystick Hall, blocs `diagCAN`. |
| 🧠 **MainTask** | Standard (10) | Cyclique (20ms) | Logique métier complète, exécution du cycle, arbitrages des modes, `FB_Safety`. |

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
│   ├── 📄 ST_WinchIO        (Structure d'état/commande Treuil)
│   ├── 📄 ST_TransIO        (Structure d'état/commande Translation)
│   ├── 📄 ST_EncoderData    (Structure de données traitées codeur)
│   ├── 📄 E_Mode            (Énumération des modes de marche)
│   └── 📄 E_CycleStep       (Énumération des étapes du séquenceur)
├── 📁 JOYSTICK (Traitement commande opérateur)
│   ├── FB_JoystickCAN       (Traitement complet de l'axe physique)
│   └── PRG_JOY1             (Programme d'acquisition sur CanTask)
├── 📁 WINCH (Gestion de la plongée/extraction)
│   ├── FB_Winch             (Directeur de treuil individuel)
│   └── FB_SpeedStep         (Décodeur de paliers de vitesse pour contacteurs)
├── 📁 ENCODER (Traitement de la position câble)
│   ├── FB_EncoderRead       (Lecture physique brute EtherCAT)
│   ├── FB_EncoderScale      (Mise à l'échelle en mètres via LIN_TRAFO)
│   └── FB_EncoderHoming     (Mise à zéro et gestion offset plan d'eau)
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

1. Le **Joystick physique** transmet ses positions brutes sur la `CanTask` au bloc `FB_JoystickCAN`.
2. Les **Codeurs tambours** renvoient les points de rotation sur l' `EtherCatTask` vers `FB_EncoderScale`.
3. `FB_EncoderScale` calcule le déroulé en mètres (`CablePosM`) et le distribue instantanément à `FB_Winch` (pour les arrêts de position) et à `FB_Safety` (pour le contrôle de la cote légale).
4. Les **Capteurs TOR de position** (fond touché, maintenance, fdc) alimentent directement `FB_Safety` et le séquenceur `FB_Cycle`.

### 📉 Flux Descendant (Ordres et Procédés)

1. `FB_Modes` sélectionne la source légitime (Joystick en manuel, `FB_Cycle` en automatique) et transmet une structure `ST_AxisCmd` unifiée.
2. `FB_Winch` (A et B) reçoit la consigne, sollicite `FB_SpeedStep` pour positionner les contacteurs physiques et pilote le frein de levage via `FB_Brake`.
3. `FB_Translation` intercepte sa consigne de vitesse en %, applique la décélération à l'approche de la position cible et active l'arrêt exact sur capteur.
4. En phase de vidage, `FB_Bucket` applique une désynchronisation calculée aux treuils pour provoquer l'ouverture mécanique du godet.

### 🛡️ Flux Transverse de Sécurité (Priorité Absolue)

1. Dès qu'un défaut de cohérence, une valeur absurde ou un dépassement de la limite légale est détecté par `FB_Safety`, la variable **`SafeStop` passe à `TRUE**`.
2. Ce bit `SafeStop` est propagé immédiatement à l'entrée de tous les blocs opérationnels (`FB_Winch`, `FB_Translation`, `FB_Cycle`).
3. L'interaction est immédiate : coupure instantanée de toutes les sorties relais de vitesse/direction et collage instantané des freins à manque de courant.

---

## 🚦 5. Chaîne Logique d'Exécution (1 Cycle Automate)

```text
[1. ENTRÉES] ──► [2. SÉCURITÉ] ──► [3. FILTRAGE] ──► [4. DÉCISION] ──► [5. ACTION] ──► [6. SORTIES]
 Joystick         FB_Safety         FB_Modes         FB_Cycle         FB_Winch         Contacteurs
 Codeurs          (SafeStop?)       (Autorise?)      (Étape en cours) FB_Translation   Freins
 Capteurs TOR                                                         FB_Bucket        Variateur

```

⚠️ **Priorité Étape 2** : Si `FB_Safety` lève un défaut, toute la logique interne des étapes suivantes est ignorée pour figer les actionneurs dans l'état de repli le plus sûr.