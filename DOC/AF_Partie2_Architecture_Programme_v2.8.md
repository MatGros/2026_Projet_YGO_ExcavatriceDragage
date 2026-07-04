# 📋 Analyse Fonctionnelle — Partie 2 : Architecture Programme (v2.8)

> **v2.8** — Refonte du modèle d'orchestration (décision utilisateur, session 2026-07-04) :
> abandon du modèle **`PLC_PRG_MAIN` unique + FB composés** (v2.5-v2.7) au profit du modèle
> **« Programmes ST Autonomes »** : chaque étape de la tâche `MainTask` est un `PROGRAM`
> **numéroté** (`PRG_0_Inputs` → `PRG_10_Outputs`), appelé **directement dans la liste d'appel
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
> 🗂️ Historique : v2.5→v2.7 = modèle `PLC_PRG_MAIN` + arborescence `_COMMON/_TYPES/_DIAG/
> JOYSTICK/WINCH/ENCODER/CHARIOT/GRAPPIN/SAFETY/SEQUENCE` (voir `DOC/Archives/`, gitignoré,
> ne pas s'y référer). **v2.8 = seule référence à jour.**

---

## 🧭 0. Principes directeurs

| # | Décision | Conséquence |
|---|----------|-------------|
| 1 | **Programmes ST autonomes numérotés** (`PRG_0_Inputs` … `PRG_10_Outputs`) dans `MainTask` | Pas de `PLC_PRG_MAIN`/`FB_MAIN_MACHINE` racine ; l'ordre d'appel = l'ordre visible dans la config tâche CODESYS |
| 2 | **Pas de `GVL_IN`/`GVL_OUT`** pour les E/S brutes | `PRG_0_Inputs` expose les E/S conditionnées en `VAR_OUTPUT` ; `PRG_10_Outputs` reçoit les commandes en `VAR_INPUT`. Les autres programmes lisent `PRG_0_Inputs.<Signal>` directement (appel séquentiel, même cycle) |
| 3 | **Pas de `GVL_BusHealth`/`E_DegradationLevel`** | Chaque programme lit **directement** la sortie du programme/FB producteur ; dégradation = `FB_Modes` + interlocks `Enable`/`Ready` |
| 4 | **Modèle d'arrêt à 3 niveaux** : `Enable` > `SafeStop` > `StartStop` | Inchangé depuis v2.5 — voir §6 |
| 5 | **`SafeStop` = 1 par bloc safety métier**, pas de signal global | `PRG_3_Safety` centralise les **instances** (`FB_Safety_Winch` ×2, `FB_Safety_Chariot`), chacune garde son `SafeStop` propre |
| 6 | **AU = chaîne matérielle indépendante** ; **`PowerCutOff`** = coupure puissance amont, **redondance 1oo2** | Voir §6. Signal logique unique calculé dans `PRG_3_Safety`, **dédoublé en sortie physique** par `PRG_10_Outputs` (`PowerCutOff_A_RQ`/`PowerCutOff_B_RQ`, 2 cartes I/O, contacts série) |
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
| **M1** | `FB_Winch` (instance M1, dans `PRG_6_WinchControl`) + `FB_Encoder_Abs` **COD1** (`PRG_2_Encoders`) | Treuil levage 1 + codeur absolu tambour 1 | EtherCAT |
| **M2** | `FB_Winch` (instance M2) + `FB_Encoder_Abs` **COD2** | Treuil levage 2 + codeur absolu tambour 2 | EtherCAT |
| **M3** | `FB_Chariot` (dans `PRG_7_ChariotControl`) | Variateur **AC600** axe transversal | EtherCAT |

🧭 `COD1`=codeur **M1**, `COD2`=codeur **M2**, `AC600`=variateur **M3**.

---

## ⏱️ 2. Cadencement & Gestion des Tâches (Tasks)

| Tâche | Priorité | Cadence | Contenu & Rôle |
| --- | --- | --- | --- |
| ⚡ **EtherCatTask** | à définir¹ | **4 ms** | Rafraîchit images process EtherCAT : codeurs M1/M2 (COD1/COD2), variateur AC600 (M3) |
| 🔌 **CanTask** | à définir¹ | **20 ms** | Rafraîchit **uniquement** l'image process CANopen (joystick Hall). Le **traitement** (`FB_Joystick` dans `PRG_1_Diagnostics`) s'exécute dans `MainTask` (10 ms) |
| 🧠 **MainTask** | à définir¹ | **10 ms** | Exécute **séquentiellement** `PRG_0_Inputs` → `PRG_10_Outputs` (liste d'appel §3) |

> ¹ **Priorités à définir** en configuration CODESYS (TBD — voir `DOC/AUDIT_Coherence_Documentaire_v1.0.md` Q7, jamais tranché). Critère : les tâches bus rafraîchissent l'image process **avant** que `MainTask` ne la consomme.

⏲️ **Surveillance périodicité des tâches** : fonction système CODESYS (seuil **200 ms**), **pas de programme applicatif dédié**.

---

## 🌳 3. Liste d'appel `MainTask` (ordre = numéro du programme)

```text
MainTask (10 ms)
 0.  PRG_0_Inputs           — CODE/IO/            — Acquisition/conditionnement E/S TOR (FB_Input), expose en VAR_OUTPUT
 1.  PRG_1_Diagnostics      — CODE/DIAG/          — FB_DiagCanOpen, FB_DiagEthercat ×3, FB_Joystick (traitement complet)
 2.  PRG_2_Encoders         — CODE/ENCODERS/      — FB_Encoder_Abs → Scale → Homing → Safety (COD1/M1, COD2/M2)
 3.  PRG_3_Safety           — CODE/SAFETY/        — FB_Safety_Winch ×2 (M1/M2), FB_Safety_Chariot → SafeStop/ForbidX/PowerCutOff par domaine
 4.  PRG_4_Modes            — CODE/MODES/         — FB_Modes : arbitrage Mode + OverrideSync
 5.  PRG_5_Cycle            — CODE/CYCLE/         — FB_Cycle : séquenceur E_CycleStep (13 étapes)
 6.  PRG_6_WinchControl     — CODE/CONTROL/       — FB_Winch M1/M2, FB_WinchSync, FB_Grappin ; arbitrage manuel/auto
 7.  PRG_7_ChariotControl   — CODE/CONTROL/       — FB_Chariot (M3) ; arbitrage manuel/auto, sélection cible
 8.  PRG_8_AuxiliaryControl — CODE/CONTROL/       — Auxiliaires hors-axe (hydraulique, crible…) — stubs neutres à ce jour
 9.  PRG_9_Supervision      — CODE/SUPERVISION/   — Mapping bidirectionnel GVL_IHM ↔ GVL_PERSISTENT, boot init, MachineReset_IHM
10.  PRG_10_Outputs         — CODE/IO/            — Écriture E/S physiques (FB_Output), PowerCutOff redondant A/B
```

> 📌 Chaque programme **lit directement** les sorties des programmes précédents dans la liste
> (ex. `PRG_6_WinchControl` lit `PRG_0_Inputs.M1ContactorFeedbackFwd`, `PRG_3_Safety.instSafetyWinchM1.SafeStop`,
> `PRG_4_Modes.instModes.Mode`) — pas d'agrégateur GVL entre les deux.
> ⚠️ `PRG_9_Supervision` (position 9) calcule `MachineReset_IHM`, consommé par `PRG_1` à `PRG_7`
> (positions **antérieures** dans la liste) : ce `Reset` centralisé est donc lu avec **1 cycle de
> retard** par tous ses consommateurs — accepté (cohérent avec le principe déjà admis pour
> `EncoderFaultPresent`→`FB_Modes`, Partie10 §9bis), mais à garder en tête pour tout nouveau
> câblage transverse.

---

## 🧱 4. Rôle de chaque programme

### `PRG_0_Inputs` (position 0)
Instancie `FB_Input` (brique `_COMMON`, interface réduite Partie3 §1bis) pour **chaque** entrée
TOR : sécurités communes (`EmergencyStopOk`, `TopPositionSensor`, `SlackCableSwitch`,
`PhaseRotationOk`), retours contacteurs/thermique/frein M1+M2, capteurs position Chariot M3.
Expose tout en `VAR_OUTPUT` — **lecture seule** pour le reste du programme.

### `PRG_1_Diagnostics` (position 1)
`FB_DiagCanOpen` (bus CAN + nœud joystick), `FB_DiagEthercat` (×3 : COD1/COD2/AC600),
`FB_Joystick_0` (calibration/deadband/filtre PT1/rampe/homme-mort — traitement complet, bien
que l'image CAN soit rafraîchie à 20 ms).

### `PRG_2_Encoders` (position 2)
Pipeline codeur complet par treuil : `FB_Encoder_Abs` (lecture bus + preset) → `FB_Encoder_Scale`
(points→mètres) → `FB_Encoder_Homing` (référencement) → `FB_Encoder_Safety` (bornage/incohérence).
Expose `EncoderFaultPresent` (agrégat M1 OR M2) en `VAR_OUTPUT`, consommé par `PRG_4_Modes`
avec 1 cycle de retard (dépendance croisée assumée, voir §3).

### `PRG_3_Safety` (position 3)
Instancie les blocs safety **par métier** : `instSafetyWinchM1`/`instSafetyWinchM2`
(`FB_Safety_Winch`, défini dans `CODE/WINCH/`), `instSafetyChariotM3` (`FB_Safety_Chariot`,
défini dans `CODE/CHARIOT/`). Chaque instance calcule son propre `SafeStop`/`ForbidDescent`/
`ForbidAscent`/`PowerCutOff` — pas de signal global agrégé ici.

### `PRG_4_Modes` (position 4)
`FB_Modes` : arbitre `Mode` (diffusé à tous les consommateurs en aval), refuse `SEMI_AUTO` si
défaut codeur, refuse `MAINT_N2` sans mot de passe, calcule `OverrideSync` (MAINT_N1 ou N2).

### `PRG_5_Cycle` (position 5)
`FB_Cycle` : séquenceur `E_CycleStep` (13 étapes, Partie4). Émet des commandes discrètes
(`CmdWinchM1/M2_StartStop/Direction/SpeedPct`, `CmdChariotM3_Start/Target`,
`CmdGrappin_Open/Close`) consommées par `PRG_6_WinchControl`/`PRG_7_ChariotControl` **en
mode SEMI_AUTO uniquement** (arbitrage dans les programmes de contrôle, pas ici).

### `PRG_6_WinchControl` (position 6)
Arbitre la source de commande (Joystick en manuel, `PRG_5_Cycle` en semi-auto/auto) pour M1/M2,
instancie `FB_WinchSync` (surveillance écart + cohérence de commande), `FB_Grappin` (désynchro
M2), et les 2 instances `FB_Winch`. Calcule les limites de descente actives (limite légale +
limite physique) et le `ForbidDescent`/`ForbidAscent` effectifs par treuil.

### `PRG_7_ChariotControl` (position 7)
Arbitre la source de commande pour M3 (Joystick vs `PRG_5_Cycle`), sélectionne le capteur de
position cible actif (`PosFosse1/2`, `PosMaintenance`, `PosTremie`), instancie `FB_Chariot`
(`CommMode` figé `DEGRADED_IO` à ce jour — voir Partie11 §7).

### `PRG_8_AuxiliaryControl` (position 8)
Regroupe les commandes hors-axes (hydraulique, crible, grille, casque). **Stubs neutres
uniquement à ce jour** (aucune logique métier — portée hors périmètre actuel, voir Partie11 §5bis).

### `PRG_9_Supervision` (position 9)
Mapping bidirectionnel complet `GVL_IHM` ↔ programmes métier ↔ `GVL_PERSISTENT` : lecture des
commandes IHM (boutons, sélecteurs), initialisation au boot depuis les valeurs persistées,
propagation des réglages IHM vers `GVL_PERSISTENT`, calcul de `MachineReset_IHM` (OR de tous
les boutons reset), calcul de `LimitLegalReached`, propagation des bypass banc de test
(`GVL_DEBUG`) vers `GVL_IHM`.

### `PRG_10_Outputs` (position 10)
Instancie `FB_Output` (brique `_COMMON`) pour chaque sortie physique (relais sens/vitesse
M1/M2, freins M1/M2/M3) et écrit les canaux Q réels. Calcule et écrit la coupure puissance
**redondante** : `PowerCutOff_A_RQ`/`PowerCutOff_B_RQ` (signal logique unique, dédoublé sur 2
cartes I/O — voir §6).

---

## 🔌 2bis. GVL survivantes vs supprimées

Le modèle « Programmes autonomes » **n'élimine pas toutes les GVL** — seules les GVL d'**état
interne machine brut** (E/S) ont disparu. Distinction stricte à conserver :

| GVL | Rôle | Statut |
|-----|------|--------|
| `GVL_IHM` (`SUPERVISION`) | Échange bidirectionnel IHM (mesures, commandes, RETAIN) — **1 struct par objet métier** (`ST_WinchHMI`, `ST_GrappinHMI`…), voir Partie 7 | ✅ Conservée — usage IHM, pas état interne |
| `GVL_PERSISTENT` (`SYSTEM`) | Paramètres/calibrations survivant coupure secteur + Download (`PERSISTENT RETAIN`) | ✅ Conservée — rôle distinct, jamais lue par un autre FB comme bus d'état cyclique |
| `GVL_DEBUG` (`MAIN`) | Bypass banc de test (`DBG_*Bypass_TEST`) — **toujours `FALSE` en exploitation réelle** | ✅ Conservée — mise en service uniquement |
| `GVL_Modes_Stub` (`MODES`) | Stub sélecteur mode/mot de passe (pas de vrai IHM câblé ce lot) | ✅ Conservée — temporaire, à terme absorbée par `GVL_IHM` |
| `GVL_Encoder_Stub` (`ENCODERS`) | Stub boutons homing/reset codeur + `TopSensorPositionM` | ✅ Conservée — même statut que ci-dessus |
| `GVL_Chariot_M3_Stub` (`CHARIOT`) | Stub sélecteur position test + signaux M3 non câblés | ✅ Conservée — même statut |
| ~~`GVL_IN`~~ / ~~`GVL_OUT`~~ | Ancien bus d'E/S brutes partagé | ❌ **Supprimées** — remplacées par `PRG_0_Inputs`(`VAR_OUTPUT`)/`PRG_10_Outputs`(`VAR_INPUT`) |
| `GVL_BUS` (`SYSTEM`) | Ancien `GVL_BusHealth`/`E_DegradationLevel` | 🗑️ **Fichier vide, vestige** — conservé « pour archive de structure » par son propre en-tête, non référencé. Candidat suppression définitive |
| `GVL_Machine_Stub` (`SYSTEM`) | Ancien porteur de `MachineReset_IHM` | 🗑️ **Orphelin** — `MachineReset_IHM` est maintenant calculé et exposé par `PRG_9_Supervision` ; ce fichier n'est référencé par aucun autre `.st` |

---

## 🚦 5. Arrêt d'urgence (AU) vs `SafeStop` vs `PowerCutOff` (inchangé sur le fond, redondance ajoutée)

| Couche | Élément | Nature | Action |
|--------|---------|--------|--------|
| Matérielle | Bouton coup-de-poing (opérateur) | Câblé | Coupe le **contacteur de puissance** → moteurs OFF + freins collés **brutalement**. Automate non coupé. |
| Matérielle ⟵ Logiciel | `PowerCutOff` — **redondance 1oo2** | Cmd PLC → 2 relais | Signal logique unique calculé dans `PRG_3_Safety` (OR des 3 instances safety) ; `PRG_10_Outputs` l'écrit en double : `PowerCutOff_A_RQ` (carte I/O n°1) et `PowerCutOff_B_RQ` (carte I/O n°2). **Câblage physique** : contacts des 2 relais en **série** — si un relais reste collé, l'autre assure la coupure. |
| Logicielle | `SafeStop` (sortie d'un bloc safety **métier**, 1 par domaine) | Variable interne | Rampe de décélération rapide (`Enable` maintenu). Calculée dans `PRG_3_Safety`, consommée directement par `FB_Winch`/`FB_Chariot` dans `PRG_6`/`PRG_7`. |
| Logicielle | `EmergencyStopOk` | Info | Exposée par `PRG_0_Inputs` (VAR_OUTPUT), lue directement par tous les programmes en aval. |

---

## 📌 6. Notes d'implémentation — types (déclarés par domaine, pas de `_TYPES` central)

Contrairement au modèle v2.7 (`_TYPES` unique), chaque type est déclaré **dans le dossier de
son domaine fonctionnel** :

| Type | Dossier | Rôle |
|------|---------|------|
| `E_Mode` | `MODES` | Modes de marche |
| `E_State` | `_COMMON` | Machine d'état standard (Partie3 §2) |
| `E_CycleStep` | `CYCLE` | 13 étapes du séquenceur |
| `E_ChariotCommMode` | `CHARIOT` | `ETHERCAT`/`DEGRADED_IO` |
| `E_DiagState` | `SYSTEM` | États diagnostic bus |
| `ST_AxisCmd` | `JOYSTICK` | Consigne Enable/StartStop/SpeedRef/Direction |
| `ST_ContactorCheck` | `_COMMON` | Diag commande/retour contacteur |
| `ST_SpeedStepTable` | `WINCH` | 5 paliers masque 4 bits |
| `ST_EncoderCalib` | `ENCODERS` | RETAIN homing (Homed, HomingRefRaw, LastKnownRawPos) |
| `ST_GrappinConfig` / `ST_GrappinState` | `GRAPPIN` | Offsets + mémoire mécanique |
| `ST_DeviceDiag` | `SYSTEM` | Diag esclave bus générique |
| `ST_*HMI` (Winch/Grappin/Sync/Joystick/Modes/Encoder/Chariot/NetworkDiag) | `SUPERVISION` | Structs d'échange `GVL_IHM`, voir Partie 7 |

`_COMMON` reste le dossier des **briques génériques réutilisables** (`FB_Brake`, `FB_Input`,
`FB_Output`, `FB_Ramp`) — il ne contient **pas** de logique métier.

---

## 📚 Documents liés
- **Partie 1** — Présentation & équipements.
- **Partie 3** — Contrat FB commun : interface (`Enable/Reset/EmergencyStopOk/Mode`, `StartStop`), état, ErrorId, reset, AU/PowerCutOff.
- **Partie 4** — Cycle & séquenceur : `E_CycleStep`, INIT, synchro, frein, chariot, grappin, rampes.
- **Partie 5** — Modes & maintenance : Manuel/N1/N2/SemiAuto, AU/`SafeStop`/`PowerCutOff`, limite légale (`FB_Modes`).
- **Partie 6** — Conditionnement E/S : `FB_Input`, `FB_Output`, `PRG_0_Inputs`/`PRG_10_Outputs`.
- **Partie 7** — Interface IHM (`GVL_IHM`, structs `ST_*HMI`).
