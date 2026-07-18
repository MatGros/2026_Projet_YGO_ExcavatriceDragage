# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (v2.12)

> **v2.12 (2026-07-18)** — Intégration des décisions client : architecture M3, codage des capteurs,
> périmètre auxiliaires et préparation du cycle semi-auto.
>
> **v2.11 (2026-07-09)** — Nettoyage documentaire (audit doc) : la note "priorités de tâches à
> définir" (§2) était une remarque organisationnelle (TBD) — remplacée par un renvoi court vers
> `DOC/PLAN_TASK_v1.0.md` §3 (T5), qui centralise désormais ce reliquat. Aucun changement
> fonctionnel.
>
> **v2.10 (2026-07-07)** — REX terrain (voir Partie 9) : l'exemple §3 citant
> `PRG_00_Inputs.M1ContactorFeedbackFwd` (retour individuel par sens) est mis à jour — ce signal
> est **supprimé côté câblage réel** pour les treuils M1/M2, remplacé par un retour unique par
> treuil `M1FwdRevSpeedFeedbackOff`. Aucun autre changement vs v2.9. Détail complet :
> `DOC/AF_Partie-09_Fonction_Winch_v1.10.md`.
>
> **v2.9** — Correctif documentaire (voir Partie 13) : `GVL_DEBUG` (§2bis) a été supprimé et
> remplacé par `GVL_Simulation` (bit maître `SimulationModeActive` + granularité par device
> `<Device>_IsReal`) — la table §2bis et la description de `PRG_09_Supervision` (§4) reflètent
> désormais ce remplacement. Aucun autre changement vs v2.8.
>
> **v2.8** — Refonte du modèle d'orchestration (décision utilisateur, session 2026-07-04) :
> abandon du modèle **`PLC_PRG_MAIN` unique + FB composés** (v2.5-v2.7) au profit du modèle
> **« Programmes ST Autonomes »** : chaque étape de la tâche `MainTask` est un `PROGRAM`
> **numéroté** (`PRG_00_Inputs` → `PRG_10_Outputs`), appelé **directement dans la liste d'appel
> de la tâche CODESYS** — pas de `PROGRAM` racine unique qui les enchaîne en interne.
>
> **Motivation** (rapportée par l'utilisateur) : suppression de la dépendance aux GVL d'E/S
> brutes (`GVL_IN`/`GVL_OUT`), réduction des ambiguïtés de nommage, et **visibilité immédiate
> de l'ordre d'exécution** dans la configuration de tâche CODESYS (plus besoin d'ouvrir le
> corps d'un `PLC_PRG_MAIN` de plusieurs centaines de lignes pour connaître la séquence).
>
> **Contrainte du modèle** : chaque `PROGRAM` numéroté expose ses données via des
> `VAR_OUTPUT` (lecture seule pour les consommateurs) ou reçoit ses commandes via
> `VAR_INPUT` (écrites par l'appelant) — l'architecture reste **typée et vérifiable à la
> compilation** (pas de GVL fourre-tout).
>
> 🗂️ Historique : v2.5→v2.7 = modèle `PLC_PRG_MAIN` + arborescence `COMMUN/_TYPES/_DIAG/
> JOYSTICK/WINCH/ENCODER/TRANSLATION/BENNE/SAFETY/SEQUENCE` (voir `ARCHIVES/Doc/`, gitignoré,
> ne pas s'y référer). **v2.8 = seule référence à jour.**

---

> 🆕 **Décision client — Translation M3** : cinq capteurs sont lus dans l'ordre
> `Trémie | PV | P2 | P1 | Maintenance`. Le mot valide progresse de `11111`
> (extrême gauche / Trémie) à `00000` (extrême droite / Maintenance) :
> `11111 → 01111 → 00111 → 00011 → 00001 → 00000`. Toute autre combinaison
> est incohérente. `PV` assure le ralentissement avant l'arrêt sur `Trémie`.
> `Maintenance` est accessible uniquement en `MAINT_N2`.

## 🧭 0. Principes directeurs

| # | Décision | Conséquence |
|---|----------|-------------|
| 1 | **Programmes ST autonomes numérotés** (`PRG_00_Inputs` … `PRG_10_Outputs`) dans `MainTask` | Pas de `PLC_PRG_MAIN`/`FB_MAIN_MACHINE` racine ; l'ordre d'appel = l'ordre visible dans la config tâche CODESYS |
| 2 | **Pas de `GVL_IN`/`GVL_OUT`** pour les E/S brutes | `PRG_00_Inputs` expose les E/S conditionnées en `VAR_OUTPUT` ; `PRG_10_Outputs` reçoit les commandes en `VAR_INPUT`. Les autres programmes lisent `PRG_00_Inputs.<Signal>` directement (appel séquentiel, même cycle) |
| 3 | **Pas de `GVL_BusHealth`/`E_DegradationLevel`** | Chaque programme lit **directement** la sortie du programme/FB producteur ; dégradation = `FB_Modes` + interlocks `Enable`/`Ready` |
| 4 | **Modèle d'arrêt à 3 niveaux** : `Enable` > `SafeStop` > `StartStop` | Inchangé depuis v2.5 — voir §6 |
| 5 | **`SafeStop` = 1 par bloc safety métier**, pas de signal global | `PRG_03_Safety` centralise les **instances** (`FB_Safety_Winch` ×2, `FB_Safety_Translation`), chacune garde son `SafeStop` propre |
| 6 | **AU = chaîne matérielle indépendante** ; **`PowerCutOff`** = coupure puissance amont, **redondance 1oo2** | Voir §6. Signal logique unique calculé dans `PRG_03_Safety`, **dédoublé en sortie physique** par `PRG_10_Outputs` (`PowerCutOff_A_RQ`/`PowerCutOff_B_RQ`, 2 cartes I/O, contacts série) |
| 7 | **`FB_SpeedStep` en masque 4 bits**, table par treuil (`ST_SpeedStepTable`) | Inchangé |
| 8 | **Quelques GVL « d'échange » survivent** (IHM, persistance, stubs de mise en service) | Ce ne sont **pas** des GVL d'état interne machine (voir §2bis) — rôle différent des anciennes `GVL_IN`/`GVL_OUT` supprimées |
| 9 | **Pas de `FB_Watchdog` applicatif** | Périodicité des tâches surveillée par la **fonction système CODESYS** (config tâche) |

🔎 **Pourquoi ce changement vs v2.7 ?** Le modèle précédent (1 seul POU + FB composés en
cascade) rendait l'ordre d'exécution **invisible** sans lire le corps du POU racine. Le modèle
« Programmes autonomes » rend cet ordre **explicite dans la liste d'appel de tâche** — chaque
`PRG_N_<Nom>` porte son numéro d'ordre dans son propre nom et son en-tête de fichier.

---

## 🗺️ 1. Mapping physique (référence, inchangé)

| Repère | FB / PRG concerné | Équipement physique | Bus |
|--------|--------------------|----------------------|-----|
| **M1** | `FB_Winch` (instance M1, dans `PRG_06_WinchControl`) + `FB_Encoder_Abs` **COD1** (`PRG_02_Encoders`) | Treuil retenue 1 + codeur absolu tambour 1 | EtherCAT |
| **M2** | `FB_Winch` (instance M2, dans `PRG_06_WinchControl`) + `FB_Encoder_Abs` **COD2** (`PRG_02_Encoders`) | Treuil benne 2 + codeur absolu tambour 2 | EtherCAT |
| **M3** | `FB_Translation` (dans `PRG_07_TranslationControl`) | Translation AC600 + capteurs Trémie/PV/P2/P1/Maintenance | EtherCAT + E/S TOR |

🧭 `COD1`=codeur **M1**, `COD2`=codeur **M2**, `AC600`=variateur **M3**.

---

## ⏱️ 2. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | à définir¹ | **4 ms** | Rafraîchit images process EtherCAT : codeurs M1/M2 (COD1/COD2), variateur AC600 (M3) |
| 🔌 **CanTask** | à définir¹ | **20 ms** | Rafraîchit **uniquement** l'image process CANopen (joystick Hall). Le **traitement** (`FB_Joystick` dans `PRG_01_Diagnostics`) s'exécute dans `MainTask` (10 ms) |
| 🧠 **MainTask** | à définir¹ | **10 ms** | Exécute **séquentiellement** `PRG_00_Inputs` → `PRG_10_Outputs` (liste d'appel §3) |

> ¹ **Priorités** en configuration CODESYS — critère : les tâches bus rafraîchissent l'image
> process **avant** que `MainTask` ne la consomme. 📌 Suivi : voir `DOC/PLAN_TASK_v1.0.md` §3 (T5).

⏲️ **Surveillance périodicité des tâches** : fonction système CODESYS (seuil **200 ms**), **pas de programme applicatif dédié**.

---

## 🌳 3. Liste d'appel `MainTask` (ordre = numéro du programme)

```text
MainTask (10 ms)
 0.  PRG_00_Inputs              — CODE/MAIN/         — Acquisition/conditionnement E/S TOR (FB_Input), expose en VAR_OUTPUT
 1.  PRG_01_Diagnostics         — CODE/MAIN/         — FB_DiagCanOpen, FB_DiagEthercat ×3, FB_Joystick
 2.  PRG_02_Encoders            — CODE/MAIN/         — FB_Encoder_Abs → Scale → Homing → Safety (COD1/M1, COD2/M2)
 3.  PRG_03_Safety              — CODE/MAIN/         — FB_Safety_Winch ×2, FB_Safety_Translation → SafeStop/PowerCutOff
 4.  PRG_04_Modes               — CODE/MAIN/         — FB_Modes : arbitrage des modes et autorisations
5.  PRG_05_Cycle               — CODE/MAIN/         — FB_Cycle : séquenceur semi-auto ; E/S Kobold dédiées (%IX0.5/%QX0.6)
 6.  PRG_06_WinchControl        — CODE/MAIN/         — FB_Winch M1/M2, FB_WinchSync, FB_Bucket
 7.  PRG_07_TranslationControl  — CODE/MAIN/         — FB_Translation M3 et arbitrage des cibles
 8.  PRG_08_AuxiliaryControl    — CODE/MAIN/         — Diagnostic thermique hydraulique uniquement ; aucune commande auxiliaire
 9.  PRG_09_Supervision          — CODE/MAIN/         — Mapping GVL_IHM ↔ GVL_PERSISTENT, états et diagnostics
10.  PRG_10_Outputs              — CODE/MAIN/         — Écriture E/S physiques et PowerCutOff redondant A/B
```

`PRG_IP` (`CODE/MAIN/PRG_IP.st`) est un programme annexe actuellement stub/commenté,
hors séquence principale. Les programmes de validation PLC sont regroupés sous
`CODE/SIMULATION/PLC_TESTS/` et ne font pas partie du flux machine nominal.

### 3bis. Translation M3 — codage des positions

| Zone | Mot valide (`Trémie|PV|P2|P1|Maintenance`) | Rôle |
|---|---:|---|
| Extrême gauche / Trémie | `11111` | Arrêt safety + déchargement |
| Entre Trémie et PV | `01111` | Approche rapide |
| Entre PV et P2 | `00111` | Translation intermédiaire |
| Entre P2 et P1 | `00011` | Zone de travail |
| Entre P1 et Maintenance | `00001` | Approche Maintenance |
| Extrême droite / Maintenance | `00000` | Arrêt safety, accès `MAINT_N2` uniquement |

Tout autre mot est incohérent et doit être diagnostiqué. `PV` déclenche le ralentissement
avant l'arrêt répétable sur `Trémie`. Le décodage du mot capteurs, l'estimation de position,
les deux limites extrêmes et le diagnostic d'incohérence relèvent du domaine Translation.

> 📌 Chaque programme **lit directement** les sorties des programmes précédents dans la liste
> (ex. `PRG_06_WinchControl` lit `PRG_00_Inputs.M1FwdRevSpeedFeedbackOff`, `PRG_03_Safety.instSafetyWinchM1.SafeStop`,
> `PRG_04_Modes.instModes.Mode`) — pas d'agrégateur GVL entre les deux.
> ⚠️ `PRG_09_Supervision` (position 9) calcule `MachineReset_IHM`, consommé par `PRG_01` à `PRG_07`
> (positions **antérieures** dans la liste) : ce `Reset` centralisé est donc lu avec **1 cycle de
> retard** par tous ses consommateurs — accepté (cohérent avec le principe déjà admis pour
> `EncoderFaultPresent`→`FB_Modes`, Partie10 §9bis), mais à garder en tête pour tout nouveau
> câblage transverse.

---

## 🧱 4. Rôle de chaque programme

### `PRG_00_Inputs` (position 0)
Instancie `FB_Input` (brique `COMMUN`, interface réduite Partie3 §1bis) pour **chaque** entrée
TOR : sécurités communes (`EmergencyStopOk`, `TopPositionSensor`, `SlackCableSwitch`,
`PhaseRotationOk`), retours contacteurs/thermique/frein M1+M2, capteurs position Translation M3.
Expose tout en `VAR_OUTPUT` — **lecture seule** pour le reste du programme.

### `PRG_01_Diagnostics` (position 1)
`FB_DiagCanOpen` (bus CAN + nœud joystick), `FB_DiagEthercat` (×3 : COD1/COD2/AC600),
`FB_Joystick_0` (calibration/deadband/filtre PT1/rampe/homme-mort — traitement complet, bien
que l'image CAN soit rafraîchie à 20 ms).

### `PRG_02_Encoders` (position 2)
Pipeline codeur complet par treuil : `FB_Encoder_Abs` (lecture bus + preset) → `FB_Encoder_Scale`
(points→mètres) → `FB_Encoder_Homing` (référencement) → `FB_Encoder_Safety` (bornage/incohérence).
Expose `EncoderFaultPresent` (agrégat M1 OR M2) en `VAR_OUTPUT`, consommé par `PRG_04_Modes`
avec 1 cycle de retard (dépendance croisée assumée, voir §3).

### `PRG_03_Safety` (position 3)
Instancie les blocs safety **par métier** : `instSafetyWinchM1`/`instSafetyWinchM2`
(`FB_Safety_Winch`, défini dans `CODE/TREUILS/`), `instSafetyTranslationM3` (`FB_Safety_Translation`,
défini dans `CODE/TRANSLATION/`). Chaque instance calcule son propre `SafeStop`/`ForbidDescent`/
`ForbidAscent`/`PowerCutOff` — pas de signal global agrégé ici.

### `PRG_04_Modes` (position 4)
`FB_Modes` : arbitre `Mode` (diffusé à tous les consommateurs en aval), refuse `SEMI_AUTO` si
défaut codeur, refuse `MAINT_N2` sans mot de passe, calcule `SyncEnable` (MAINT_N1 ou N2).

### `PRG_05_Cycle` (position 5)
`FB_Cycle` : séquenceur `E_CycleStep` (13 étapes, Partie4). Émet des commandes discrètes
(`CmdWinchM1/M2_StartStop/Direction/SpeedPct`, `CmdTranslationM3_Start/Target`,
`CmdBucket_Open/Close`) consommées par `PRG_06_WinchControl`/`PRG_07_TranslationControl` **en
mode SEMI_AUTO uniquement** (arbitrage dans les programmes de contrôle, pas ici).

### `PRG_06_WinchControl` (position 6)
Arbitre la source de commande (Joystick en manuel, `PRG_05_Cycle` en semi-auto/auto) pour M1/M2,
instancie `FB_WinchSync` (surveillance écart + cohérence de commande), `FB_Bucket` (désynchro
M2), et les 2 instances `FB_Winch`. Calcule les limites de descente actives (limite légale +
limite physique) et le `ForbidDescent`/`ForbidAscent` effectifs par treuil.

### `PRG_07_TranslationControl` (position 7)
Arbitre la source de commande pour M3 (Joystick vs `PRG_05_Cycle`), sélectionne la cible
(`Trémie`, `PV`, `P2`, `P1`, `Maintenance`) et son code capteurs, puis instancie `FB_Translation`
(`CommMode` figé `DEGRADED_IO` à ce jour — voir Partie11 §7).

### `PRG_08_AuxiliaryControl` (position 8)
Ne commande plus le casque, la grille ni la centrale hydraulique. Conserve uniquement le
retour thermique de la centrale hydraulique pour diagnostic IHM. Toute commande auxiliaire
est hors périmètre automate.

### `PRG_09_Supervision` (position 9)
Mapping bidirectionnel complet `GVL_IHM` ↔ programmes métier ↔ `GVL_PERSISTENT` : lecture des
commandes IHM (boutons, sélecteurs), initialisation au boot depuis les valeurs persistées,
propagation des réglages IHM vers `GVL_PERSISTENT`, calcul de `MachineReset_IHM` (OR de tous
les boutons reset), calcul de `LimitLegalReached`, propagation de l'état simulation effectif par
device (`GVL_Simulation`, voir Partie 13) vers `GVL_IHM`.

### `PRG_10_Outputs` (position 10)
Instancie `FB_Output` (brique `COMMUN`) pour chaque sortie physique (relais sens/vitesse
M1/M2, freins M1/M2/M3) et écrit les canaux Q réels. Calcule et écrit la coupure puissance
**redondante** : `PowerCutOff_A_RQ`/`PowerCutOff_B_RQ` (signal logique unique, dédoublé sur 2
cartes I/O — voir §6).

---

## 🔌 2bis. GVL survivantes vs supprimées

Le modèle « Programmes autonomes » **n'élimine pas toutes les GVL** — seules les GVL d'**état
interne machine brut** (E/S) ont disparu. Distinction stricte à conserver :

| GVL | Rôle | Statut |
|-----|------|--------|
| `GVL_IHM` (`SUPERVISION`) | Échange bidirectionnel IHM (mesures, commandes, RETAIN) — **1 struct par objet métier** (`ST_WinchHMI`, `ST_BucketHMI`…), voir Partie 7 | ✅ Conservée — usage IHM, pas état interne |
| `GVL_PERSISTENT` (racine `CODE/`) | Paramètres/calibrations survivant coupure secteur + Download (`PERSISTENT RETAIN`) | ✅ Conservée — rôle distinct, jamais lue par un autre FB comme bus d'état cyclique |
| `GVL_Simulation` (`SIMULATION`) | Bit maître `SimulationModeActive` + granularité par device (`<Device>_IsReal`) — voir Partie 13 | ✅ Conservée — remplace `GVL_DEBUG` (supprimée), mise en service uniquement |
| `GVL_Modes_Stub` (`MODES`) | Stub sélecteur mode/mot de passe (pas de vrai IHM câblé ce lot) | ✅ Conservée — temporaire, à terme absorbée par `GVL_IHM` |
| `GVL_Encoder_Stub` | Ancien stub homing/codeur | ❌ Absent du code actuel — ne pas référencer comme GVL active |
| `GVL_Translation_M3_Stub` (`TRANSLATION`) | Stub sélecteur position test et reliquats M3 | ⚠️ Conservée temporairement — à réduire après migration du décodage cinq capteurs |
| `GVL_PLC_Tests` / `GVL_PLC_Tests_Const` (`SIMULATION/PLC_TESTS`) | Commandes, états et constantes du framework de validation PLC | ✅ Conservées — uniquement simulation/tests |
| ~~`GVL_IN`~~ / ~~`GVL_OUT`~~ | Ancien bus d'E/S brutes partagé | ❌ **Supprimées** — remplacées par `PRG_00_Inputs`(`VAR_OUTPUT`)/`PRG_10_Outputs`(`VAR_INPUT`) |
| ~~`GVL_BUS`~~ (`SYSTEM`) | Ancien `GVL_BusHealth`/`E_DegradationLevel` | ❌ **Supprimé (2026-07-15)** — fichier vide, jamais référencé |
| ~~`GVL_Machine_Stub`~~ (`SYSTEM`) | Ancien porteur de `MachineReset_IHM` | ❌ **Supprimé (2026-07-15)** — `MachineReset_IHM` est calculé et exposé par `PRG_09_Supervision.FaultMachineReset_IHM` |

---

## 🚦 5. Arrêt d'urgence (AU) vs `SafeStop` vs `PowerCutOff` (inchangé sur le fond, redondance ajoutée)

| Couche | Élément | Nature | Action |
|--------|---------|--------|--------|
| Matérielle | Bouton coup-de-poing (opérateur) | Câblé | Coupe le **contacteur de puissance** → moteurs OFF + freins collés **brutalement**. Automate non coupé. |
| Matérielle ⟵ Logiciel | `PowerCutOff` — **redondance 1oo2** | Cmd PLC → 2 relais | Signal logique unique calculé dans `PRG_03_Safety` (OR des 3 instances safety) ; `PRG_10_Outputs` l'écrit en double : `PowerCutOff_A_RQ` (carte I/O n°1) et `PowerCutOff_B_RQ` (carte I/O n°2). **Câblage physique** : contacts des 2 relais en **série** — si un relais reste collé, l'autre assure la coupure. |
| Logicielle | `SafeStop` (sortie d'un bloc safety **métier**, 1 par domaine) | Variable interne | Rampe de décélération rapide (`Enable` maintenu). Calculée dans `PRG_03_Safety`, consommée directement par `FB_Winch`/`FB_Translation` dans `PRG_06`/`PRG_07`. |
| Logicielle | `EmergencyStopOk` | Info | Exposée par `PRG_00_Inputs` (VAR_OUTPUT), lue directement par les programmes consommateurs. |

---

## 📌 6. Notes d'implémentation — types (déclarés par domaine, pas de `_TYPES` central)

Contrairement au modèle v2.7 (`_TYPES` unique), chaque type est déclaré **dans le dossier de
son domaine fonctionnel** :

| Type | Dossier | Rôle |
|------|---------|------|
| `E_Mode` | `MODES` | Modes de marche |
| `E_State` | `COMMUN` | Machine d'état standard (Partie3 §2) |
| `E_CycleStep` | `CYCLE` | 13 étapes du séquenceur |
| `E_TranslationCommMode` | `TRANSLATION` | `ETHERCAT`/`DEGRADED_IO` |
| `E_DiagState` | `DIAG` | États diagnostic bus |
| `ST_AxisCmd` | `JOYSTICK` | Consigne Enable/StartStop/SpeedRef/Direction |
| `ST_ContactorCheck` | `COMMUN` | Diag commande/retour contacteur |
| `ST_SpeedStepTable` | `WINCH` | 5 paliers masque 4 bits |
| `ST_EncoderCalib` | `ENCODERS` | RETAIN homing (Homed, HomingRefRaw, LastKnownRawPos) |
| `ST_BucketConfig` / `ST_BucketState` | `BENNE` | Offsets + mémoire mécanique |
| `ST_DiagDevice` | `DIAG` | Diag esclave bus générique |
| `ST_*HMI` (Winch/Benne/Sync/Joystick/Modes/Encoder/Translation/NetworkDiag) | `SUPERVISION` | Structs d'échange `GVL_IHM`, voir Partie 7 |

`COMMUN` reste le dossier des **briques génériques réutilisables** (`FB_Brake`, `FB_Input`,
`FB_Output`, `FB_Ramp`) — il ne contient **pas** de logique métier.

---

## 🛡️ 7. Tableau de synthèse des Gardes-fous Sécurité (Méca A à E)

Afin d'assurer la défense en profondeur, l'automate implémente des surveillances de sécurité réparties par équipement :

| **Mécanisme** | **Dénomination** | **Équipement** | **Condition d'armement** | **Condition de déclenchement** | **Conséquence** |
|:---:|---|:---:|---|---|---|
| **Méca A** | Mouvement non commandé | **Treuils M1/M2** | Contacteurs et frein fermés (repos) | Dérive $> 2.0\text{ m}$ ou vitesse $> 0.02\text{ m/s}$ | SafeStop + **PowerCutOff** |
| | | **Translation M3** | Consigne neutre + frein serré | Vitesse réelle variateur $> 0.5\text{ Hz}$ pendant $> 1.0\text{ s}$ | SafeStop + **PowerCutOff** |
| **Méca B** | Incohérence à l'arrêt / sans commande | **Treuils M1/M2** | Joystick au neutre ou com CAN perdue | Contacteurs ou frein restent actifs après $> 3.0\text{ s}$ | SafeStop + **PowerCutOff** |
| | | **Translation M3** | Joystick au neutre | Variateur reste actif ou frein reste ouvert après $> 3.0\text{ s}$ | SafeStop + **PowerCutOff** |
| **Méca C** | Glissement inter-axe | **Treuil M1** | Cycle benne actif (M1 censé rester immobile) | Dérive M1 $> 2.0\text{ m}$ (escalade couche 2) | SafeStop + **PowerCutOff** |
| **Méca D** | Dépassement Fdc haut non maîtrisé | **Treuils M1/M2** | Butée haute atteinte (physique ou virtuelle) | Frein non fermé ou contacteurs collés après $> 3.0\text{ s}$ | SafeStop + **PowerCutOff** |
| **Méca E** | Écart synchro critique | **Treuils M1/M2** | Mode synchro actif | Écart $M1 \leftrightarrow M2 > 2.0\text{ m}$ (immédiat ou non arrêté après $3.0\text{ s}$) | SafeStop (bit 12) + **PowerCutOff** (bit 13) |

> [!NOTE]
> La conséquence **PowerCutOff** déclenche la coupure physique immédiate de la puissance amont (ouverture de la boucle d'arrêt d'urgence) car la mécanique est en dérive ou les organes de commande locale ont échoué.

---

## 📚 Documents liés
- **Partie 1** — Présentation & équipements.
- **Partie 3** — Contrat FB commun : interface (`Enable/Reset/EmergencyStopOk/Mode`, `StartStop`), état, ErrorId, reset, AU/PowerCutOff.
- **Partie 4** — Cycle & séquenceur : `E_CycleStep`, INIT, synchro, frein, translation, benne, rampes.
- **Partie 5** — Modes & maintenance : Manuel/N1/N2/SemiAuto, AU/`SafeStop`/`PowerCutOff`, limite légale (`FB_Modes`).
- **Partie 6** — Conditionnement E/S : `FB_Input`, `FB_Output`, `PRG_00_Inputs`/`PRG_10_Outputs`.
- **Partie 7** — Interface IHM (`GVL_IHM`, structs `ST_*HMI`).
- **Partie 13** — Simulation (`GVL_Simulation`, `CODE/SIMULATION/FB_Sim_*`).
