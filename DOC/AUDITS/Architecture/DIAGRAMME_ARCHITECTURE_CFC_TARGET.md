# 🏗️ Diagramme architecture cible — blocs & flux (d'après les specs AF)

> **Ce que c'est** : diagramme des blocs et de leurs liens (flux DUT / bus) comme ils doivent
> apparaître dans la page CFC cible, **strictement dérivé des specs** :
> `AF_Partie-02` §2/§4 (ordre MainTask) · `AF_Partie-06` §1/§2/§2bis/§2ter (frontière + contrats DUT).
> **Ce que ce n'est pas** : aucun élément inventé — chaque flux cite sa référence de spec.
> **Généré** : 2026-08-03. En cas d'écart avec une spec, la spec fait foi.

---

## 🔎 Légende

| Symbole | Sens |
|---|---|
| `──►` | Flux de données typé (DUT) entre producteur → lecteur |
| `==>` | Flux `PowerCutOff` (demandes de coupure agrégées en `PRG_06`) |
| `⇢` | Bascule réel/simulé (une seule par domaine, dans le CFC) |

---

## 1. Vue d'ensemble MainTask — ordre cible (AF02 §4)

```mermaid
flowchart LR
    A["🪜 01 PRG_01_Inputs_LD<br/>TOR réelles qualifiées<br/>(FB_Input, polarité+filtre)"]
    B["📥 02 PRG_02_Acquisition_CFC<br/>frontière E/S · sélection<br/>Joystick · Codeurs M1/M2 ·<br/>PosDecoder M3 · diag devices<br/>état AU"]
    C["🎚️ 03 PRG_03_Modes_Cycle_CFC<br/>FB_Modes · FB_Cycle"]
    D["🪝 04 PRG_04_Treuils_Benne_CFC<br/>M1/M2 + synchro + benne<br/>+ safety M1/M2 + homing"]
    E["↔️ 05 PRG_05_Translation_CFC<br/>M3 + safety M3"]
    F["⚡ 06 PRG_06_Outputs_LD<br/>barrières · agrégation PowerCutOff"]
    G["🔎 07 PRG_07_Supervision_CFC<br/>IHM · alarmes · bypass<br/>(lecture seule)"]

    A -->|ST_InputsQualified| B
    B -->|ST_EncoderMeasurements<br/>HwIn · faits qualifiés| C
    B -->|ST_EncoderMeasurements<br/>HwIn · faits qualifiés| D
    B -->|HwIn · faits qualifiés M3| E
    B -->|faits qualifiés| F
    C -->|Auth : autorisations| D
    C -->|Auth : autorisations| E
    D -->|demandes| F
    E -->|demandes| F
    D ==|PowerCutOff M1/M2| F
    E ==|PowerCutOff M3| F
    F -->|commandes physiques + état| G
```

> **Source** : AF02 §4 (liste 01→07), AF06 §2bis (frontière/absorptions), AF06 §2ter (DUT), AF02 §2 (autorisations Modes→procédés).

---

## 2. Zoom `PRG_02_Acquisition_CFC` — frontière interne (AF06 §1/§2) — vue générale

```mermaid
flowchart LR
    subgraph S1["Source réelle"]
        TOR["E/S TOR réelles (device)"]
        PDO["PDO / mesures réelles<br/>CANopen · EtherCAT"]
    end
    subgraph L1["🪜 PRG_01_Inputs_LD"]
        FBIN["FB_Input × 21<br/>polarité · filtre (réel)"]
    end
    subgraph A2["📥 PRG_02_Acquisition_CFC"]
        HR["HwReal : ST_HardwareImage<br/>(image brute device)"]
        SMB["FB_SimBench<br/>HwSim : ST_HardwareImage<br/>(image simulée)"]
        SEL["SEL × 4 (fonctions CODESYS)<br/>Winch · Translation ·<br/>Operator · Machine<br/>responsable : PRG_02"]
        HI["HwIn : ST_HardwareImage<br/>(image sélectionnée)"]
        JST["FB_Joystick"]
        COD["Chaîne codeurs M1/M2<br/>FB_Encoder_Abs · Scale ·<br/>Safety · SpeedMeasure"]
        DEC["FB_Translation_PositionDecoder<br/>(M3)"]
        DIA["instDiagCanOpen<br/>instDiagEthercat<br/>instIhmHeartbeat"]
        AU["État AU qualifié<br/>(acquis ici, agit en PRG_06)"]
    end
    subgraph DUT["Sorties publiques"]
        IQ["ST_InputsQualified"]
        EM["ST_EncoderMeasurements (M1·M2)"]
        HW["HwIn / faits qualifiés"]
        JAX["ST_Joystick_AxisCmd<br/>(X/Y, PAS DeadmanArmed)"]
        DDEV["ST_Diag_Device<br/>+ E_Diag_State<br/>(par device)"]
        AUF["ST_HwMachine<br/>(état AU brut qualifié)"]
    end

    TOR --> FBIN
    FBIN -->|ST_InputsQualified<br/>AF06 §2ter| SEL
    PDO --> HR
    HR -->|image brute| SEL
    SMB -->|HwSim| SEL
    SEL -->|HwIn par domaine<br/>AF06 §2| HI
    HI --> JST
    HI --> COD
    HI --> DEC
    HI --> DIA
    HI --> AU
    COD -->|ST_EncoderMeasurements<br/>AF06 §2ter| EM
    SEL -.->|ST_InputsQualified =<br/>réel des domaines TOR| IQ
    HI --> HW
    JST -->|"ST_Joystick_AxisCmd (X/Y)<br/>+ DeadmanArmed (BOOL séparé)"| JAX
    DIA -->|ST_Diag_Device<br/>AF12| DDEV
    AU -->|ST_HwMachine<br/>fait brut| AUF
```

> **Lecture** : la frontière est **unique**. Tout ce qui entre dans les FB de `PRG_02` (joystick,
> codeurs, décodeur M3, diag, AU) passe par **`HwIn`** (ou `ST_InputsQualified` pour les TOR réelles).
> Rien ne lit un device brut hors de cette page. Les sorties de `PRG_02` sont des **faits typés**
> (structures DUT) consommés par les pages aval — détaillés dans les zooms ci-dessous.

### Règles du câblage (extraits AF06 §2, §2ter)

| # | Règle | Réf. spec |
|---|---|---|
| 1 | Aucun FB métier ne lit une E/S brute device : tout passe par `HwIn` | AF06 §2 (TC-P06-001) |
| 2 | Bascule réel/simulé **une seule fois par domaine**, dans le CFC | AF06 §2 (TC-P06-003) |
| 3 | `FB_Input` filtre le **réel uniquement** (Q1=A) ; le sim passe sans filtre | AF06 §2ter |
| 4 | `ST_InputsQualified` : réel pur, jamais de sim ; lu par `PRG_02` seul | AF06 §2ter |
| 5 | `ST_EncoderMeasurements` : producteur `PRG_02` unique ; lecteurs Treuils/Modes/Supervision | AF06 §2ter |
| 6 | `EncoderFault.<T> := NOT EncoderAvailable OR EncoderIncoherent` — agrégat calculé par `FB_Modes` | AF06 §2ter « Flux perte codeur » |
| 7 | Diagnostics devices/bus produits **ici** (supprime le POU legacy) | AF06 §2bis |
| 8 | État AU **acquis ici, agit en `PRG_06_Outputs_LD`** — jamais d'action ici | AF06 §2bis |

---

## 3. Zoom A — Joystick (AF08 §6, AF06 §1)

**Producteur** : `PRG_02_Acquisition_CFC.instJoystick`. **Sorties** : `ST_Joystick_AxisCmd` (X/Y)
**et** `DeadmanArmed` (BOOL séparé — **pas** dans le DUT).

```mermaid
flowchart LR
    subgraph ACQ["📥 PRG_02_Acquisition_CFC"]
        JOY["FB_Joystick<br/>Raw→AxisScale→Filter_PT1→Homme-mort<br/>AF08 §2"]
    end
    JOY -->|"ST_Joystick_AxisCmd<br/>AxisCmdX · AxisCmdY"| AX["ST_Joystick_AxisCmd<br/>(Enable·StartStop·SpeedRef·<br/>Direction·PowerContactorEngaged)"]
    JOY -->|DeadmanArmed| DA["DeadmanArmed<br/>(BOOL séparé)"]
    AX --> M3["PRG_03 · FB_Cycle<br/>CycleMotionPermit :=<br/>DeadmanArmed AND AxisCmdY.StartStop<br/>AF08 §6"]
    AX --> TR["PRG_04 · FB_Winch<br/>consigne + sélecteur treuil"]
    AX --> TL["PRG_05 · FB_Translation<br/>AxisCmdX + DeadmanArmed"]
    DA --> M3
    DA --> TR
    DA --> TL
    AX --> SUP["PRG_07 · Supervision<br/>mapping IHM JOY1Joystick.State"]
```

> **Contrat consommateur** : `AxisCmd*.StartStop` **et** `DeadmanArmed` combinés (TC-P08-013).
> Rampes laissées aux FB de mouvement aval (`FB_Winch`, `FB_Translation`) — AF08 §2.
> `DeadmanArmed` apparaît aussi dans `ST_JoystickState` (IHM) **pour affichage uniquement**.

---

## 4. Zoom B — Diagnostics devices / bus (AF12 §1, AF06 §3)

**Producteur** : `PRG_02_Acquisition_CFC` (`instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat`).
**DUT de sortie** : `ST_Diag_Device` (une instance par device) + `E_Diag_State`.

```mermaid
flowchart LR
    subgraph ACQ["📥 PRG_02_Acquisition_CFC"]
        CAN["instDiagCanOpen"]
        ETH["instDiagEthercat"]
        HBT["instIhmHeartbeat"]
    end
    CAN -->|"DeviceCanOpenMaster<br/>DeviceJoystick"| DD["ST_Diag_Device<br/>(Online·Operational·Error·<br/>ErrorId·State·StateAtError)"]
    ETH -->|"DeviceEthercatMaster<br/>DeviceVariateur<br/>DeviceEncoderM1/M2"| DD
    HBT -->|"heartbeat IHM<br/>(fait)"| HB["IhmHeartbeat"]
    DD --> SAF["FB_Safety_Winch /<br/>FB_Safety_Translation<br/>(via PRG_04/05)"]
    DD --> MOD["PRG_03 · Modes<br/>(dispo device)"]
    DD --> IHM["PRG_07 · IHM Network<br/>+ Troubleshooting"]
    HB --> MOD
```

> **Règle AF12 §2** : un FB diag **ne pilote jamais** `SafeStop`/`PowerCutOff` — il publie des faits ;
> les `FB_Safety_<Domaine>` consomment et décident seuls.

---

## 5. Zoom C — État AU & PositionDecoder M3 (AF06 §2bis, AF01, AF11 §4.2)

### 5.1 État AU — acquis ici (fait brut), qualifié/agissant en sortie

```mermaid
flowchart LR
    subgraph ACQ["📥 PRG_02_Acquisition_CFC"]
        AU["ST_HwMachine<br/>EmergencyChainClosed_DI<br/>PowerContactorEngaged_DI<br/>(faits bruts qualifiés)"]
    end
    subgraph OUT["⚡ PRG_06_Outputs_LD"]
        FBEM["FB_Safety_EmergencyManagement"]
        ST["ST_Safety_Emergency_State<br/>ChainOk·ContactorOk·Step·Armable·ArmingBusy"]
        DG["ST_Safety_Emergency_Diag<br/>Error·ErrorId·RedundancyFail·Lockout"]
    end
    AU -->|"EmergencyChainClosed<br/>PowerContactorEngaged<br/>(via PRG_02 qualifié)"| FBEM
    FBEM -->|fait| ST
    FBEM -->|fait| DG
    ST --> SUP["PRG_07 · Supervision / Troubleshooting"]
    DG --> SUP
```

> ⚠️ **Acquisition de l'état ≠ lieu d'action** : `PRG_02` acquiert `ST_HwMachine` (faits bruts
> qualifiés) ; le FB agit via `PRG_06_Outputs_LD` (barrière finale). La chaîne matérielle AU reste
> indépendante et prioritaire (Partie 01). DUT publics : `ST_Safety_Emergency_State` /
> `ST_Safety_Emergency_Diag` (AF01 fiche §8).

### 5.2 PositionDecoder M3 — décodage à la frontière, consommation en Translation

```mermaid
flowchart LR
    subgraph ACQ["📥 PRG_02_Acquisition_CFC"]
        DEC["FB_Translation_PositionDecoder<br/>5 capteurs → mot + butées + incohérence<br/>AF11 fiche §2"]
    end
    DEC -->|LimitSwitchFwd<br/>LimitSwitchRev| SAF["PRG_05 · FB_Safety_Translation<br/>butées extrêmes"]
    DEC -->|Incoherent| SAF
    DEC -->|mot de progression| TR["PRG_05 · FB_Translation<br/>position"]
```

> **Pourquoi ici et pas en Translation** : décoder le mot brut 5 capteurs produit des **faits
> qualifiés** (qualification d'entrée, comme les codeurs). Il est exécuté **avant** Safety
> (`Acquisition.instPositionDecoder`), et ses sorties sont consommées par `FB_Safety_Translation`
> (bit7 → `SafeStop`+`PowerCutOff`, TC-P11-002). Cible : AF11 §4.2 ligne 103.

---

## 6. Flux perte codeur (P0) — un seul fait par treuil (AF06 §2ter)

```mermaid
flowchart LR
    CH["PRG_02 · chaîne codeur M1/M2"] --> AVAIL["EncoderAvailable"]
    CH --> INCOH["EncoderIncoherent"]
    AVAIL --> FAULT["EncoderFault<br/>= NOT Available OR Incoherent"]
    INCOH --> FAULT
    FAULT --> MODES["FB_Modes (M1 OR M2)<br/>refuse SEMI_AUTO<br/>Auth.ErrorId bit0"]
    FAULT --> SAF["FB_Safety_Winch M1/M2<br/>SafeStop bit2"]
    FAULT --> IHM["PRG_07 Supervision<br/>alarme / animation par treuil"]
    FAULT --> SYNC["Auth.SyncEnable refusé<br/>si l'un des 2 faux"]
```

> **Source** : AF06 §2ter « Flux perte codeur → Modes / Safety / Supervision / IHM » (tableau des consommateurs + formule).

---

## 7. Sommaire des structures publiées par `PRG_02` (et leur DUT)

| Sortie | DUT / type | Contenu | Réf. spec |
|---|---|---|---|
| TOR réelles qualifiées | `ST_InputsQualified` | 1 BOOL par TOR (`M1/M2/M3_*_DI`, `Machine_*`) | AF06 §2ter |
| Image sélectionnée | `ST_HardwareImage` (`HwIn`) | 4 sous-domaines `Winch`/`Translation`/`Operator`/`Machine` | AF06 §2ter |
| Mesures codeurs | `ST_EncoderMeasurements` | `M1`/`M2` : `RawPos`, `EncoderAvailable`, `CablePosM`, `CablePosMSafe`, `EncoderIncoherent`, `Speed_Mps`, `SignedSpeed_Mps`, `SpeedValid` | AF06 §2ter |
| Consigne joystick | `ST_Joystick_AxisCmd` | `Enable`, `StartStop`, `SpeedRef`, `Direction`, `PowerContactorEngaged` — **`DeadmanArmed` est hors DUT** (BOOL séparé) | AF08 §6, NAMING §Structures |
| Diagnostics devices | `ST_Diag_Device` (+ `E_Diag_State`) | par device : `Online`, `Operational`, `Error`, `ErrorId`, `State`, `StateAtError` | AF12 §1 |
| État AU brut qualifié | `ST_HwMachine` (sous-image) | `EmergencyChainClosed_DI`, `PowerContactorEngaged_DI`, … | AF06 §2ter, AF01 |
| État AU public / diag | `ST_Safety_Emergency_State` / `_Diag` | produit par `FB_Safety_EmergencyManagement` (en `PRG_06`), **pas** par `PRG_02` | AF01 fiche §8 |

---

## 8. Correspondance code legacy → cible (AF02 §4, AF06 §2bis)

| Legacy | Cible | Lot |
|---|---|---|
| `PRG_00_Inputs` / `PRG_INPUTS_LD` | `PRG_01_Inputs_LD` | M1 |
| `PRG_ACQUISITION_CFC` + `PRG_02_Encoders` + `PRG_01_Diagnostics` + `PRG_AUXILIARY_CFC` | `PRG_02_Acquisition_CFC` | M1 |
| `instPositionDecoder` (acquisition) | `PRG_02_Acquisition_CFC` — sorties lues par `PRG_05` | M1 |
| `PRG_MODES_CFC` + `PRG_05_Cycle` | `PRG_03_Modes_Cycle_CFC` | M2 |
| `PRG_TREUILS_CFC` + safety M1/M2 (`PRG_SAFETY_CFC`) | `PRG_04_Treuils_Benne_CFC` | M3 |
| `PRG_TRANSLATION_CFC` + safety M3 | `PRG_05_Translation_CFC` | M4 |
| `PRG_OUTPUTS_LD` (+ agrégat `PowerCutOff`) | `PRG_06_Outputs_LD` | M5 |
| `PRG_SUPERVISION_CFC` + `PRG_TROUBLESHOOTING_CFC` | `PRG_07_Supervision_CFC` | M6 |
| — (renumérotation + CFC natif) | — | M7/M8 |

📌 Détail des lots : `PLAN_EXECUTION_MIGRATION_7POU.md` · arbitrages : `REGISTRE_ARBITRAGES_MIGRATION.md`.
