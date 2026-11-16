# RAPPORT D'INGÉNIERIE — ÉVALUATION COMPARATIVE DE FAISABILITÉ TECHNIQUE DES TÂCHES T417-D, T417-E ET T417-F

> **Projet** : Excavatrice de Dragage en Carrière Noyée (Automate CODESYS 3.5)  
> **Référence Tâche Parente** : `T417-C` (`DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/`)  
> **Auteur** : Cellule d'Ingénierie & Coordination Technique (teamwork_worker)  
> **Date** : 16 Novembre 2026  
> **Version** : 1.0 — Définitive  
> **Classification** : Sécurité Machine Réelle / Directive Machines 2006/42/CE / ISO 13849-1 / SIL-PLd / Voie C4  
> **Intégrité Code Source** : Lecture Seule Stricte sur `CODE/` (0 modification de code source)  

---

## 1. SYNTHÈSE EXÉCUTIVE & MATRICE COMPARATIVE

### 1.1 Contexte et Enjeux Industriels
Dans le cadre de la qualification du chariot de translation M3 de l'excavatrice de dragage en carrière noyée, l'analyse d'incident sur site (notamment la **Trace 27** à $10\text{ Hz}$, révélant un dépassement de came Trémie de $115\text{ ms}$ avec amorce d'impact butée) a conduit au partitionnement de la tâche d'investigation parente **`T417-C`** en trois tâches enfants spécialisées :
- **`T417-D`** : Modélisation physique réaliste et bancs de simulation automate (`C2`).
- **`T417-E`** : Verrouillage matériel, persistance et coupure de sécurité M3 (`C3/C4`).
- **`T417-F`** : Séquencement du cycle benne trémie et garde mécanique en mode automatique (`C3`).

Le présent rapport d'ingénierie délivre l'arbitrage exhaustif et déterministe sur la faisabilité technique, les verrous d'intégration, les prérequis physiques terrain et les stratégies de repli pour chacune de ces trois tâches, en vue d'autoriser ou d'encadrer leur lancement.

---

### 1.2 Matrice Comparative Globale

| Paramètre | T417-D (Simulation & Bancs M3) | T417-E (Sécurité M3 & Sorties) | T417-F (Cycle Benne Trémie Auto) |
| :--- | :--- | :--- | :--- |
| **Titre officiel** | Simulation Réaliste M3 & Bancs de Test | Sécurité Chariot M3 & Sorties Interlock | Séquenceur Cycle Benne Trémie & Init Auto |
| **Criticité Workflow** | `C2` (Outillage & Simulation) | `C3 / C4` (Sécurité Machine & Coupure Mouvement) | `C3` (Modes Opératoires & Automatismes) |
| **Périmètre Fichiers Déclaré** | `CODE/L_SIMULATION/**`<br>`TOOLS/TEST_AUTO_CI/.../AGY02_T417_M3_SANDBOX/**` | `CODE/M_MAIN/PRG_06_Outputs.st`<br>`CODE/M_MAIN/PRG_05_Translation.st`<br>`CODE/I_TRANSLATION/**` | `CODE/M_MAIN/PRG_03_Modes_Cycle.st`<br>`CODE/F_MODES/FB_Modes.st`<br>`CODE/G_CYCLE/FB_CycleSemiAuto.st`<br>`CODE/H_TREUILS_BENNE/**` |
| **Fichiers Réellement Nécessaires** | `L_SIMULATION/FB_Sim_PositionSensor.st`<br>`L_SIMULATION/GVL_Simulation.st`<br>`L_SIMULATION/FB_Sim_Translation.st`<br>`L_SIMULATION/FB_SimBench.st`<br>*(Hors PRG_02 avant J_FINAL)* | `M_MAIN/PRG_06_Outputs.st`<br>`M_MAIN/PRG_05_Translation.st`<br>`I_TRANSLATION/FB_Safety_Translation.st`<br>`I_TRANSLATION/FB_Translation_PositionDecoder.st`<br>`C_PERSISTENCE/GVL_PERSISTENT.st` | `M_MAIN/PRG_03_Modes_Cycle.st`<br>`F_MODES/FB_Modes.st`<br>`G_CYCLE/FB_CycleSemiAuto.st`<br>*(Lecture seule sur PRG_05)* |
| **Verdict Faisabilité** | **FAISABLE SOUS CONDITIONS** | **FAISABLE SOUS CONDITIONS STRICTES** | **FAISABLE SOUS CONDITIONS** |
| **Verrous Majeurs Identifiés** | 1. Rupture de câblage dans le contrat initial (omission de `FB_Sim_Translation` et `FB_SimBench`).<br>2. Échec du banc sandbox CI (`FB_TestHarnessT417_M3.st` forcé en `SEMI_AUTO`).<br>3. Écrêtage odométrique de production `CST_GainMax := 0.05` vs $k=0.0551$. | 1. **Bug critique de persistance volatile** dans `PRG_06_Outputs:97` + réinitialisation `01111` dans `PRG_05:327` (danger crash au reboot).<br>2. Anti-rebond $100\text{ ms}$ aveugle sur came $4\text{ cm}$ à $10\text{ Hz}$ ($72\text{ ms}$).<br>3. Risque piège `2#00000` en maintenance.<br>4. Absence de reset ergonomique au joystick. | 1. Micro-perte came physique $115\text{ ms}$ (Trace 27) résolue par `M3_AtTremieStable` (commit `aa20ed28`).<br>2. Diagnostic imprécis en `AX1_INIT`.<br>3. Capteur de niveau trémie non câblé physiquement sur machine. |
| **Statut d'Ordonnancement** | **Lancement Parallèle Immédiat** (Plan B Python actif immédiatement ; révision contrat ST requise) | **Lancement Parallèle Immédiat** sous condition d'intégration du patch `GVL_PERSISTENT` et levée mesures terrain | **Lancement Parallèle Immédiat** (Découplage total, interface `M3_AtTremieStable` déjà active) |

---

## 2. ÉVALUATION TECHNIQUE DÉTAILLÉE DE T417-D (SIMULATION & BANCS M3)

### 2.1 Périmètre, Contrat et Objectifs
La tâche **`T417-D`** (`TASK_CONTRACT_T417-D.yaml`) vise à substituer au modèle historique de capteur de position à came infinie un modèle physique réaliste à came finie, complété de retombées de frein paramétrables et de gains odométriques calibrés sur les relevés site :
- **Entrées cibles** : `FiniteCamActive : BOOL`, `CamLength_M : REAL := 0.04`, `CloseDelay_S : REAL := 0.09 .. 0.30`, `k : REAL := 0.0200 .. 0.0551`.
- **Fichiers déclarés dans le contrat** : `CODE/L_SIMULATION/FB_Sim_PositionSensor.st`, `CODE/L_SIMULATION/GVL_Simulation.st`, et l'outillage sandbox sous `TOOLS/TEST_AUTO_CI/.../AGY02_T417_M3_SANDBOX/**`.

---

### 2.2 Analyse des Verrous Techniques

#### Verrou 1 : Rupture de Câblage Inter-Composants (Scope Disconnect)
L'audit de la chaîne d'appel CODESYS révèle une anomalie bloquante dans le dimensionnement du contrat `TASK_CONTRACT_T417-D.yaml` :
1. Dans l'architecture du projet, le composant `FB_Sim_PositionSensor.st` n'est **jamais** instancié directement par `PRG_02_Acquisition.st`.
2. Il est instancié 5 fois au sein de `FB_Sim_Translation.st` (lignes 427-465 : `instSensorTremie`, `instSensorPV`, `instSensorP2`, `instSensorP1`, `instSensorMaintenance`).
3. `FB_Sim_Translation` est lui-même instancié au sein de `FB_SimBench.st` (lignes 669-706 : `instSimTranslation`).
4. `FB_SimBench` est enfin instancié sous `PRG_02_Acquisition.st:29` (`instSimBench : FB_SimBench;`).

```text
[GVL_Simulation]
       │
       ▼ (Non câblé)
[PRG_02_Acquisition] ──(instSimBench)──► [FB_SimBench] ──(instSimTranslation)──► [FB_Sim_Translation] ──► [FB_Sim_PositionSensor x5]
                                                                                                      ▲
                                                                     (Contrat initial restreint ici) ─┘
```

**Conséquence technique** : Si le développeur applique strictement le périmètre de fichiers de `TASK_CONTRACT_T417-D.yaml`, les nouvelles variables ajoutées dans `GVL_Simulation` ne seront jamais propagées à travers `FB_SimBench` et `FB_Sim_Translation`. Elles constitueront des « entrées mortes » (*dead inputs*), et le banc automate continuera d'exécuter l'ancien modèle à came infinie.
De plus, raccorder ces signaux dans `PRG_02_Acquisition.st` dès la phase parallèle violerait la séparation des domaines en modifiant un POU d'acquisition racine `M_MAIN` de criticité `C3/C4`.

#### Verrou 2 : Invalidation de l'Oracle de Recette CI Sandbox (`run_m3_sandbox.py`)
L'exécution de la suite de tests automatisés CI dédiée :
```powershell
python TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/run_m3_sandbox.py
```
aboutit à un échec immédiat (`Code 1`) :
```text
FAIL SANDBOX-M3-01 Approche Manu vers Tremie (baseline simu)
ASSERT_TRUE: FB.M3ATTREMIE expected TRUE, got FALSE -- Capteur Tremie atteint
```
L'analyse causale dans le banc de test mock `TOOLS/TEST_AUTO_CI/MOCKS/FB_TestHarnessT417_M3.st:207` montre que le mode machine est initialisé à :
```iecst
ModesAuth.Mode := E_Mode.SEMI_AUTO;
```
Or, dans `CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st:63`, lorsque le mode est `SEMI_AUTO`, les consignes manuelles issues du manipulateur (`JoystickLeft`) sont **strictement inhibées** si aucun ordre de cycle automatique (`ReqTranslation.ReqStart`) n'est présent. Le chariot reste immobilisé à $5,0\text{ m}$ (P1) et n'atteint jamais la Trémie. L'oracle de test est donc faussé par un défaut d'initialisation de son propre banc mock.

#### Verrou 3 : Écrêtage Odométrique dans l'Estimateur de Production
Le profil d'essai le plus sévère (`WORST_CASE_SITE`) impose un glissement de roues avec gain $k = 0,0551\text{ m/(Hz}\cdot\text{s)}$.
Or, dans `CODE/I_TRANSLATION/FB_Translation_OdometryGain.st:57`, le régulateur intègre une constante de garde :
```iecst
CST_GainMax : REAL := 0.05;
```
Tout gain dynamique supérieur à $0,0500$ injecté sur le bus automate est impérativement écrêté par l'estimateur de position de `PRG_05_Translation`. Une simulation en boucle fermée à $k = 0,0551$ ne peut donc pas fonctionner fidèlement sans lever ce verrou dans le domaine `T417-E`.

---

### 2.3 Prérequis Machine et Terrain
L'ajustement du simulateur automate dépend de grandeurs physiques réelles mesurables sur site :
1. **Longueur physique de la lame de came Trémie ($L_{\text{came}}$)** : Mesure au réglet métallique sur le rail de guidage. Hypothèse actuelle : $0,04\text{ m}$ ($40\text{ mm}$), issue du temps de survol de $115\text{ ms}$ à $10\text{ Hz}$.
2. **Marge mécanique de tampon ($D_{\text{tampon}}$)** : Distance d'accostage entre le front montant du détecteur inductif Trémie et la butée élastomère finale en compression maximale (nominale : $0,50\text{ m}$).
3. **Chronométrage dynamique $P2 \leftrightarrow PV$** : Relevé chronométrique précis du franchissement de l'entraxe de $2,0\text{ m}$ à vitesse nominale $10\text{ Hz}$ sous charge pour trancher formellement entre le gain nominal d'étude ($k \approx 0,0200$) et le gain glissant constaté ($k \approx 0,0551$).
4. **Contrôle mécanique du frein M3** : Mesure de l'entrefer au jeu de cales après consignation électrique, et relevé du temps mécanique de retombée (nominal $0,09\text{ s}$ vs usé/dégradé $0,30\text{ s}$).
5. **Mode d'arrêt du variateur AC600** : Vérification du paramètre constructeur (décélération active sur rampe de $16,2\text{ Hz/s}$ vs coupure roue libre *coast-to-stop*).

---

### 2.4 Analyse des Cascades de Repli (Plan A / B / C)

```text
[Plan A0 : ST dans L_SIMULATION]
       │
       ├─► (Échec compilation ou blocage câblage PRG_02)
       │
       ▼
[Plan B : Modèle Analytique Python (100% OPÉRATIONNEL)]
       │
       ├─► Fournit les tables d'arrêt et de pénétration à T417-E et T417-F
       │
       ▼
[Plan C : Butée d'urgence par coupure matérielle / Thermomètre PRG_06]
```

- **Plan A0 (Automate ST)** : Faisable uniquement après extension du contrat à `FB_Sim_Translation.st` et `FB_SimBench.st`.
- **Plan B (Simulation Python isolée)** : **100 % opérationnel, éprouvé et déterministe**. Les scripts `be_dynamic_study.py` et `plan_abc_matrix.py` fournissent immédiatement les résultats physiques exacts :
  - Vitesse nominale $10\text{ Hz}$ sans verrou : pénétration butée $0,5003\text{ m}$ (`hit: True`, choc à $0,2\text{ m/s}$).
  - Vitesse nominale $10\text{ Hz}$ avec verrou T417-E : pénétration $0,0486\text{ m}$ (`hit: False`, arrêt sécurisé).
  - Vitesse réduite $5\text{ Hz}$ (Plan B2) : pénétration maximale $0,1178\text{ m}$ (`hit: False`, marge restante $> 0,38\text{ m}$).
- **Verdict Technique T417-D** : **FAISABLE SOUS CONDITIONS**.

---

## 3. ÉVALUATION TECHNIQUE DÉTAILLÉE DE T417-E (SÉCURITÉ M3 & SORTIES INTERLOCK)

### 3.1 Clarification d'Architecture : Inexistence de `PRG_00_Safety.st`
L'intitulé de mission cite régulièrement l'entité `PRG_00_Safety`.
L'audit complet de l'arborescence (`CODE/` et `DOC/`) confirme de manière irréfutable :
1. **Aucun fichier `PRG_00_Safety.st` n'existe dans le projet.**
2. Conformément à la norme d'architecture directrice `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md` (§3 et §5), la tâche périodique principale `MainTask` orchestre uniquement 6 programmes applicatifs :
   - `PRG_02_Acquisition` ➔ `PRG_03_Modes_Cycle` ➔ `PRG_04_Treuils_Benne` ➔ `PRG_05_Translation` ➔ `PRG_06_Outputs` ➔ `PRG_07_Supervision`.
3. La fonction de sécurité logique de translation est portée par `FB_Safety_Translation` (`CODE/I_TRANSLATION/FB_Safety_Translation.st`), instanciée au cœur de `PRG_05_Translation.st`.
4. La barrière ultime de coupure matérielle des sorties variateur est portée par l'instance `instTranslationOutputInterlockM3` au sein de `CODE/M_MAIN/PRG_06_Outputs.st`.
Créer un `PRG_00_Safety` constituerait une régression architecturale sévère et violerait le standard `AF_Partie-02`.

---

### 3.2 Analyse des Verrous Techniques Critiques

#### Verrou 1 : Faille Critique de Persistance au Reboot (Power-up Overtravel Crash)
Le commit `8fc65110` a introduit un verrou directionnel dans `CODE/M_MAIN/PRG_06_Outputs.st` :
```iecst
// Ligne 97 :
M3_TremieHardStopLatched : BOOL; // Déclaré en VAR locale simple (VOLATILE !)

// Lignes 433-435 :
IF PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI OR GVL_PERSISTENT._TranslationAtTremiePersisted THEN
    M3_TremieHardStopLatched := TRUE;
END_IF;
```
En parallèle, `CODE/M_MAIN/PRG_05_Translation.st:327` traite le mot de position du chariot :
```iecst
CASE instPosDecoderM3.SensorsWord OF
    2#11111:
        GVL_PERSISTENT._TranslationAtTremiePersisted := TRUE;
    2#01111:
        GVL_PERSISTENT._TranslationAtTremiePersisted := FALSE; // <--- DÉSACTIVATION EN ZONE DE GLISSEMENT !
```

**Scénario d'accident majeur avéré** :
1. Le chariot approche de la trémie à $10\text{ Hz}$. Sous l'effet du glissement ($k=0,0551$), il survole et dépasse la came de $40\text{ mm}$ en s'immobilisant sur la zone tampon ($d \in [0,05 ; 0,45\text{ m}]$).
2. Dans cette zone, le capteur Trémie est retombé (`M3_PosTremie_DI = FALSE`), et le mot capteurs est `2#01111` (les 4 autres cames restant actives).
3. `PRG_05_Translation.st:327` s'exécute à l'arrêt et réinitialise `GVL_PERSISTENT._TranslationAtTremiePersisted := FALSE;`.
4. **Survient alors une coupure de tension** (arrêt d'urgence coupant le 24V, disjonction secteur ou redémarrage automate).
5. Au réarmement de l'automate :
   - `M3_PosTremie_DI` vaut `FALSE` (chariot situé au-delà de la came).
   - `GVL_PERSISTENT._TranslationAtTremiePersisted` vaut `FALSE` (écrasé à l'étape 3).
   - `M3_TremieHardStopLatched` s'initialise à `FALSE` car il est en mémoire volatile !
   - L'expression ligne 433 évalue `FALSE OR FALSE = FALSE`. Le verrou ne s'arme pas !
   - Ligne 444 : `M3_TremieHardStopActive` reste à `FALSE`.
   - Lignes 452-454 : La permission de mouvement `EffectivePermitM3_Tremie` passe à `TRUE`.
6. **L'opérateur ou le cycle automatique peut immédiatement ré-enclencher la marche avant** : le chariot est précipité à pleine puissance dans la butée mécanique finale ou plonge dans le plan d'eau.

Ce comportement est inacceptable pour un système de sécurité machine et viole les principes de l'ISO 13849-1. La persistance doit obligatoirement être transférée dans `GVL_PERSISTENT` et découplée de l'état instable `01111`.

#### Verrou 2 : Incohérence Dynamique du Filtre Anti-Rebond (100 ms vs 72 ms)
Le critère AC1 exige l'intégration d'un filtre anti-rebond d'environ $100\text{ ms}$ (`TonM3TremieConfirm`).
Or, les calculs dynamiques cinématiques démontrent :
$$\Delta t_{\text{survol}} = \frac{L_{\text{came}}}{v} = \frac{0,04\text{ m}}{0,0551 \cdot 10\text{ Hz}} = \frac{0,04}{0,551} \approx 0,0726\text{ s} = 72,6\text{ ms}$$
Si un bloc `TON` de $100\text{ ms}$ est placé directement en coupure du signal capteur à $10\text{ Hz}$, l'impulsion physique de $72\text{ ms}$ retombe avant l'échéance du timer. **La came n'est jamais vue par l'automate, aucun arrêt n'est commandé, et le chariot s'écrase sur la butée.**
L'activation d'un filtre de $100\text{ ms}$ impose donc impérativement l'application préalable du **Plan B2** (réduction de vitesse à $5\text{ Hz}$, portant le temps de traversée à $145\text{ ms}$) ou un armement immédiat sur front montant `R_TRIG` avant confirmation.

#### Verrou 3 : Le Piège du Mot Capteurs `2#00000` en Maintenance (Plan A2)
Dans `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st:88` :
```iecst
LimitSwitchMaintenance := (NOT Incoherent) AND (SensorsWord = 2#00000);
```
Un mot capteurs `2#00000` correspond non seulement à la butée extrême de Maintenance, mais également à une rupture de câble bus, à la perte de l'alimentation 24V des détecteurs ou à l'arrachement d'un bornier. Si un verrouillage dur bloque tout mouvement dès l'état `2#00000`, une coupure d'alimentation en pleine voie immobilisera définitivement la drague sans possibilité de dégagement motorisé, forçant les techniciens à ponter sauvagement les sécurités au bornier.

#### Verrou 4 : Lacune Ergonomique du Réarmement
Ligne 438 de `PRG_06_Outputs.st`, le déverrouillage exige `PRG_07_Supervision.FaultMachineReset_IHM`. Forcer l'exploitant à lâcher ses manipulateurs et à quitter son poste de pilotage pour réarmer sur l'écran tactile à chaque approche trémie incite au contournement des sécurités. Le signal `PRG_07_Supervision.JoystickReset_CMD` (front sur bouton manipulateur) doit être admis en alternative.

---

### 3.3 Prérequis Machine, Terrain et Gouvernance C4
1. **Chaîne d'Arrêt d'Urgence Indépendante** : La sécurité logicielle dans CODESYS ne remplace pas la boucle matérielle d'Arrêt d'Urgence (`PowerCutOff`, contacteur général).
2. **Mesures Physiques Préalables** : Exécution sur site de la procédure de contrôle (~15 min) : mesure de $L_{\text{came}}$, entrefer frein M3, vérification de l'absence de jeu dans les galets de roulement.
3. **Respect de la Safety Lane C4** : La tâche modifiant la coupure de puissance de translation, elle relève de la procédure C4 (`WORKFLOW.md` §118) : double revue de code indépendante A/B et validation écrite explicite de l'exploitant.

---

### 3.4 Analyse des Cascades de Repli (Plan A / B / C)

| Cascade | Description | Efficacité / Distance d'Arrêt | Risque / Limite |
| :--- | :--- | :--- | :--- |
| **Plan A (A1 + A2)** | Latch `RETAIN` + anti-rebond accordé + reset joystick | Réduit la pénétration de $0,5003\text{ m}$ à $0,0486\text{ m}$ ($< 5\text{ cm}$). | Défaillant si non persisté dans `GVL_PERSISTENT` ou si came traversée en $< 100\text{ ms}$. |
| **Plan B (B2 + B1)** | Décélération à $5\text{ Hz}$ sur les 2 derniers mètres + contrôle frein | Énergie cinétique divisée par 4 ($E \propto v^2$). Pénétration maximale de $0,1178\text{ m}$ même avec frein très dégradé ($0,30\text{ s}$). Marge tampon $> 38\text{ cm}$. | Augmente le temps de translation d'environ $1,8\text{ s}$ sur l'approche trémie (impact cadence négligeable). |
| **Plan C (C1 + C2)** | Verrouillage de transition thermomètre `11111 → 01111` hors ordre Maintenance + bridage $5\text{ Hz}$ | Filet de sécurité absolu contre la destruction de capteur ou le survol non détecté. | Nécessite un discriminateur parfait sur la commande de Maintenance pour éviter les faux positifs. |

- **Verdict Technique T417-E** : **FAISABLE SOUS CONDITIONS STRICTES**.

---

## 4. ÉVALUATION TECHNIQUE DÉTAILLÉE DE T417-F (CYCLE BENNE TRÉMIE & MODES AUTO)

### 4.1 Clarification d'Architecture : Périmètre `PRG_03_Modes_Cycle`
L'audit formel établit que :
1. `PRG_07_Supervision.st` n'exécute aucun cycle de mouvement (POU d'IHM pure).
2. Aucun bloc nommé `FB_CycleTremie.st` n'existe.
3. La gestion complète du cycle de vidage trémie est orchestrée par `PRG_03_Modes_Cycle.st` au travers de :
   - `instModes : FB_Modes` (`CODE/F_MODES/FB_Modes.st`) : arbitrage des autorisations de mode et sélecteur de treuils.
   - `instCycleSemiAuto : FB_CycleSemiAuto` (`CODE/G_CYCLE/FB_CycleSemiAuto.st`) : graphe d'états séquentiel (`AX14_TRANSLATE_DUMP` ➔ `AX15A_DUMP_ARRIVE` ➔ `AX15B_DUMP_OPEN` ➔ `AX15C_DUMP_REPOSITION`).

---

### 4.2 Analyse des Verrous Techniques

#### Verrou 1 : Micro-perte de Came Physique 115 ms (Garde Benne Trémie)
Dans `CODE/F_MODES/FB_Modes.st:364-375`, lorsque le chariot est à la trémie, la garde mécanique force l'interdiction du couplage des treuils :
```iecst
IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
    Auth.JoystickWinchSelectArbitrated := 2; // Forçage Treuil Benne Seul (interdiction couple 0)
```
Si le signal `M3AtTremie` retombe à `0` (comme constaté sur la Trace 27 après $115\text{ ms}$ de survol), la garde se relâchait instantanément, autorisant le couplage accidentel des treuils au-dessus de la trémie (risque de chute de benne ou d'accrochage de structure).
**Résolution déjà intégrée** : Le commit `aa20ed28` a apporté la solution Plan A dans `PRG_03_Modes_Cycle.st:111-113` :
```iecst
M3AtTremie := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie
              OR PRG_05_Translation.Data.M3_AtTremieStable;
```
Le signal `M3_AtTremieStable` est généré dans `PRG_05_Translation.st:248` et reste verrouillé tant que le chariot n'a pas amorcé un mouvement avéré vers la zone de Maintenance. Ce verrou est donc techniquement résolu.

#### Verrou 2 : Diagnostics d'Armement Initial en `AX1_INIT`
Dans `CODE/G_CYCLE/FB_CycleSemiAuto.st:925-948`, si les treuils ne sont pas en position haute (`CycleWinchesAtTopOk = FALSE`) ou si la benne n'est pas qualifiée fermée/ouverte, le message d'erreur est générique :
`16#0401 : AX1 - Posture depart incorrecte (M3, FDC haut M1 ou benne)`.
Un diagnostic distinct par composant (M1, M2, benne, chariot M3) doit être intégré pour éviter les temps d'arrêt injustifiés en exploitation.

---

### 4.3 Prérequis Machine et Terrain
1. **Référencement Machine Réalisé (`MachineHomed = TRUE`)** : Le mode `SEMI_AUTO` refuse formellement l'engagement de cycle si les codeurs de treuils M1/M2 n'ont pas fait l'objet d'un homing valide (`FB_Modes.st:251`).
2. **Qualification Mécanique de Benne** : L'automate exige un état net `MechState.IsOpen` ou `MechState.IsClosed` via `FB_Bucket`.
3. **Surveillance Humaine du Niveau Trémie** : L'entrée physique `TremieFull_OR_GateRaised_DI` (carte `VH_0808ETP · 5`) étant réservée et non raccordée sur la drague (`AF_Partie-06:472`), aucune coupure automatique sur trémie pleine n'est possible. La surveillance visuelle demeure une responsabilité humaine d'exploitation.

---

### 4.4 Analyse des Cascades de Repli (Plan A / B / C)
- **Plan A (Automatisme nominal durci)** : Mémorisation `M3AtTremieStable` + clarification des messages d'erreur `AX1_INIT` + passage par le neutre `SeenNeutralAfterArrival` en `AX15A`.
- **Plan B (Secours Semi-Auto)** : Forçage d'étape contrôlé sur IHM (`GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt`) sécurisé par `compare-and-clear`.
- **Plan C (Secours Manuel / Maintenance)** : Dégagement direct en `MAINT_N1` avec assistant `DumpAtTremie` ou pilotage joystick sélecteur `WinchSel = 2`.
- **Verdict Technique T417-F** : **FAISABLE SOUS CONDITIONS**.

---

## 5. ANALYSE COMPARATIVE CROISÉE & MATRICE D'ÉTANCHÉITÉ

### 5.1 Matrice d'Étanchéité des Fichiers Source
Pour garantir l'absence totale de conflit lors de l'exécution en branches parallèles, les périmètres d'écriture doivent présenter une intersection strictement nulle :

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARBORESCENCE DU PROJET                            │
├──────────────────────────────┬──────────────────────────────┬───────────────┤
│           T417-D             │            T417-E            │    T417-F     │
│   (Simulation & Bancs)       │    (Sécurité & Sorties)      │ (Cycle & Mode)│
├──────────────────────────────┼──────────────────────────────┼───────────────┤
│ CODE/L_SIMULATION/           │ CODE/M_MAIN/                 │ CODE/M_MAIN/  │
│  ├── FB_Sim_PositionSensor   │  ├── PRG_06_Outputs.st       │  └── PRG_03   │
│  ├── GVL_Simulation.st       │  └── PRG_05_Translation.st   │ CODE/F_MODES/ │
│  ├── FB_Sim_Translation.st   │ CODE/I_TRANSLATION/          │  └── FB_Modes │
│  ├── FB_Sim_TranslationBrake │  ├── FB_Safety_Translation   │ CODE/G_CYCLE/ │
│  └── FB_SimBench.st          │  ├── FB_PosDecoderM3         │  └── FB_Cycle │
│ TOOLS/TEST_AUTO_CI/...       │  └── FB_OdometryGain         │ CODE/H_TREUILS│
│  └── AGY02_T417_M3_SANDBOX/  │ CODE/C_PERSISTENCE/          │  └── (Benne)  │
│                              │  └── GVL_PERSISTENT.st       │               │
└──────────────────────────────┴──────────────────────────────┴───────────────┘
```

**Constat formel d'étanchéité** :
- $\text{Périmètre}(T417-D) \cap \text{Périmètre}(T417-E) = \emptyset$
- $\text{Périmètre}(T417-D) \cap \text{Périmètre}(T417-F) = \emptyset$
- $\text{Périmètre}(T417-E) \cap \text{Périmètre}(T417-F) = \emptyset$

**Zéro risque de conflit Git** : Aucun fichier source `.st` n'est partagé en écriture entre les trois tâches.

---

### 5.2 Dépendances Croisées Fonctionnelles et Interfaces

Bien que disjoints en écriture, les composants échangent des données via des interfaces publiques qui doivent être gelées :
1. **Flux T417-D ➔ T417-E** :
   - T417-D fournit le banc de test et le modèle de simulation dynamique à T417-E.
   - *Règle de gestion* : Le Plan B (scripts Python `be_dynamic_study.py` et `plan_abc_matrix.py`) étant 100 % opérationnel, T417-E peut démarrer **immédiatement** sans attendre la livraison du bundle CODESYS de T417-D.
2. **Flux T417-E ➔ T417-F** :
   - T417-F consomme `PRG_05_Translation.Data.M3_AtTremieStable`.
   - *Règle de gestion* : Cette variable est déjà présente et fonctionnelle dans `PRG_05_Translation.st:73, 248, 887`. T417-F opère en **lecture seule stricte** sur `PRG_05`. T417-E a interdiction de modifier le nom ou la sémantique de cette variable d'interface.
3. **Point d'Intégration Unique (`PRG_02_Acquisition.st`)** :
   - Le raccordement de `GVL_Simulation` à `instSimBench` dans `PRG_02_Acquisition.st` ne doit être réalisé par aucun des sous-agents pendant la phase parallèle. Il est expressément réservé à l'étape finale de convergence `J_FINAL`.

---

## 6. RECOMMANDATIONS D'ORDONNANCEMENT ET D'ARBITRAGE

### 6.1 Opportunité d'un Lancement Parallèle vs Isolé

L'analyse comparative conduit à recommander formellement le **LANCEMENT PARALLÈLE IMMÉDIAT** des trois tâches selon le schéma arborescent défini dans `BRIEF_COORDINATEURS_PARALLELES.md`.

**Justification technico-économique** :
1. **Élimination des goulots d'étranglement** : Le travail analytique Python (Plan B) ayant déjà été validé par la cellule d'exploration, le dimensionnement physique de T417-E et T417-F ne dépend plus de la compilation de T417-D.
2. **Indépendance stricte des équipes** : Les 3 coordinateurs opèrent sur des dossiers et des couches logicielles distinctes (Simulation / Contrôle-Commande / Séquencement).
3. **Gain de temps critique pour la mise en service** : Traiter ces trois chantiers en séquence ajouterait plusieurs jours de délai, alors que le découpage modulaire permet une exécution concurrente sécurisée.

---

### 6.2 Protocole de Synchronisation Recommandé (En 3 Phases)

```text
PHASE 0 : PRÉ-REQUIS TERRAIN & CALIBRAGE NUMÉRIQUE (~15 min)
  ├── Contrôle site : Mesure Lcame, Dtampon, entrefer frein M3, chronométrage P2<->PV
  └── Activation Plan B Python (Valeurs de référence validées)
        │
        ▼
PHASE 1 : EXÉCUTION PARALLÈLE ÉTANCHE (3 Coordinateurs)
  ├── Coordinateur T417-D (C2) :
  │     ├── Extension contrat : Intégration FB_Sim_Translation.st et FB_SimBench.st
  │     ├── Correction harness mock : ModesAuth.Mode := E_Mode.MANU
  │     └── Livraison modèle came finie dans CODE/L_SIMULATION/
  │
  ├── Coordinateur T417-E (C3/C4) :
  │     ├── Transfert du latch de sécurité dans GVL_PERSISTENT._M3TremieHardStopLatched (RETAIN)
  │     ├── Découplage de _TranslationAtTremiePersisted en zone 01111
  │     ├── Implémentation Plan B2 (vitesse d'approche 5 Hz sur les 2 derniers mètres)
  │     └── Intégration reset manipulateur (JoystickReset_CMD)
  │
  └── Coordinateur T417-F (C3) :
        ├── Maintien du raccordement M3_AtTremieStable dans PRG_03_Modes_Cycle.st
        ├── Amélioration des messages de diagnostic en AX1_INIT (isolation M1/M2/Benne/M3)
        └── Validation des étapes AX14/AX15 en lecture seule sur PRG_05
        │
        ▼
PHASE 2 : CONVERGENCE TECHNIQUE ET VALIDATION « J_FINAL »
  ├── 1. Raccordement final des signaux de simulation dans PRG_02_Acquisition.st
  ├── 2. Génération du bundle complet : python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
  ├── 3. Contrôle de liaison déterministe : python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
  ├── 4. Exécution de la suite complète des gates : python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
  └── 5. Revue formelle Safety Lane C4 avec signature de l'exploitant avant chargement automate.
```

---

## 7. CONCLUSION GÉNÉRALE & VERDICT FORMEL

| Tâche | Verdict d'Ingénierie | Décision Immédiate |
| :---: | :---: | :--- |
| **T417-D** | **FAISABLE SOUS CONDITIONS** | **AUTORISÉ AU DÉMARRAGE** sous réserve de réviser le contrat pour inclure `FB_Sim_Translation.st` et `FB_SimBench.st`. |
| **T417-E** | **FAISABLE SOUS CONDITIONS STRICTES** | **AUTORISÉ AU DÉMARRAGE** en simulation avec obligation de corriger la persistance `RETAIN` dans `GVL_PERSISTENT` et d'intégrer le Plan B2 ($5\text{ Hz}$) avant validation machine. |
| **T417-F** | **FAISABLE SOUS CONDITIONS** | **AUTORISÉ AU DÉMARRAGE IMMÉDIAT**, la garde trémie étant déjà stabilisée par `M3_AtTremieStable`. |

L'architecture logicielle du projet `2026_Projet_YGO_ExcavatriceDragage` permet d'engager les travaux de front avec une étanchéité parfaite. L'équipe d'ingénierie dispose de l'ensemble des éléments déterministes pour garantir la sécurité des personnes, l'intégrité de la machine et l'excellence opérationnelle de l'installation.
