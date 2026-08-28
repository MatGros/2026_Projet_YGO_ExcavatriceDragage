# Contrat inter‑PRG — PRG_02 données qualifiées (v1.0-proposal)

> **À FIGER PAR VISA HUMAIN.** Ce document spécifie la frontière publique attendue ; il n'autorise
> aucune modification de code à lui seul.

## 🎯 Responsabilité

`PRG_02_Acquisition` est le producteur unique de :

- `HwReal` : image physique brute, diagnostic uniquement ;
- `HwSim` : image du banc, diagnostic uniquement ;
- `HwIn` : image qualifiée/arbitrée utilisée par les métiers ;
- `Data` : résultats fonctionnels qualifiés et diagnostics structurés.

Il ne choisit pas le mode de marche, ne fusionne pas manuel/programme et ne produit aucune commande
moteur, frein ou translation. Les commandes de protocole codeur nécessaires au homing restent
l'exception déjà documentée.

## 📦 Forme publique cible

```iecst
VAR_OUTPUT
    Data   : ST_AcquisitionInterPrg;
    HwReal : ST_HardwareImage;
    HwSim  : ST_HardwareImage;
    HwIn   : ST_HardwareImage;
END_VAR
```

`ST_AcquisitionInterPrg` conserve les mesures et diagnostics actuels, et remplace les scalaires
joystick dispersés par deux sous-structures :

```iecst
TYPE ST_AcquisitionJoystickQualified :
STRUCT
    AxisX               : ST_fbJoystick_AxisCmd;
    AxisY               : ST_fbJoystick_AxisCmd;
    DeadmanArmed        : BOOL;
    AtNeutralXY         : BOOL;
    ArmingPermitDenied  : BOOL;
    Ready               : BOOL;
    Fault               : ST_Fault;
    NeutralXAct         : INT;
    NeutralYAct         : INT;
END_STRUCT
END_TYPE

TYPE ST_AcquisitionNetworkDiagnostics :
STRUCT
    CanOpenMaster   : ST_Diag_Device;
    Joystick        : ST_Diag_Device;
    EthercatMaster  : ST_Diag_Device;
    EncoderM1       : ST_Diag_Device;
    EncoderM2       : ST_Diag_Device;
    DriveM3         : ST_Diag_Device;
END_STRUCT
END_TYPE

TYPE ST_AcquisitionEncoderQualified :
STRUCT
    Measurement              : ST_fbEncoder_Measurement;
    Ready                    : BOOL;
    Fault                    : ST_Fault;
    Homed                    : BOOL;
    HomingSuspect            : BOOL;
    EncoderFault             : BOOL;
    HomedAndReliable         : BOOL;
    PresetConfirmationFailed : BOOL;
    HwOut                    : ST_fbEncoder_HwOut;
END_STRUCT
END_TYPE
```

Champs ajoutés au bus :

```iecst
Joystick : ST_AcquisitionJoystickQualified;
Network  : ST_AcquisitionNetworkDiagnostics;
EncoderM1 : ST_AcquisitionEncoderQualified;
EncoderM2 : ST_AcquisitionEncoderQualified;
```

Les alarmes et warnings utilisés par le métier proviennent de `HwIn.Winch`, jamais de `HwReal`.
`EncoderM*.HwOut` reste une vue en lecture seule de l'ordre preset propriétaire de `PRG_02` pour le
banc et le diagnostic ; elle ne devient jamais une seconde source de commande.

Les anciens `Data.Encoders.M1/M2`, gates `M1/M2_*` et scalaires joystick sont des compatibilités
temporaires : ils sont supprimés seulement après preuve de zéro consommateur en T165-B2.

## 🔤 Sémantique et polarité

| Chemin | Rôle | Unité / polarité | Invalidité |
|---|---|---|---|
| `Data.Joystick.AxisX/Y` | geste qualifié | `SpeedTgt` 0..100 %, bits de direction positifs | `StartStop=FALSE`, `SpeedTgt=0`, directions FALSE, neutre TRUE |
| `.DeadmanArmed` | validation opérateur | TRUE = armé | FALSE |
| `.AtNeutralXY` | état geste | TRUE = deux axes neutres | TRUE |
| `.ArmingPermitDenied` | diagnostic | TRUE = bouton appuyé sans permission | FALSE si aucun appui |
| `.Ready` | disponibilité traitement | TRUE = bloc actif et données qualifiées | FALSE |
| `.Fault` | diagnostic façade | `ST_Fault` standard | socle `FB_FaultCore` |
| `.NeutralXAct/YAct` | calibration visible | points ADC | dernière calibration valide |
| `Data.Network.*` | diagnostic bus/device | `ST_Diag_Device` | Online/Operational FALSE |
| `Data.EncoderM1/M2` | façade codeur qualifiée | copie exacte des sorties `FB_Encoder` | gate du producteur |
| `HwIn.*` | faits terrain/simulation sélectionnés | polarités définies dans `ST_HardwareImage` | politique du producteur, jamais recalcul consommateur |

`Direction` et `Deflection` dans `ST_fbJoystick_AxisCmd` sont des vues dérivées. Les interlocks
utilisent les bits de direction et `StartStop`, sans redécoder le joystick brut.

## 👥 Matrice consommateurs

| Consommateur | Lit dans la cible | Ne lit plus |
|---|---|---|
| `PRG_03` | `Data`, `HwIn`, retours publics aval N‑1 | `instJoystick`, `instEncoder*`, `instDiag*` |
| `PRG_04` | `Data.Joystick.AxisY`, `Data.EncoderM1/M2`, `Data.Network`, `HwIn.Winch/Machine` | tous les internals PRG_02 |
| `PRG_05` | `Data.Joystick.AxisX`, `Data.Network`, `Data.EncoderM1/M2`, `HwIn.Translation/Machine` | tous les internals PRG_02 |
| `PRG_06` | `HwIn.Machine` et demandes aval | `HwReal`, `HwSim`, internals PRG_02 |
| `PRG_07` | `Data`, `HwIn`; `HwReal` seulement pour vue explicitement physique | tous les internals PRG_02 |

## ⏱️ Fraîcheur

- `HwReal`, diagnostics, `HwIn`, joystick et codeurs : scan courant de `PRG_02` ;
- `PRG_03.Auth` lu par homing : N‑1, nommé ;
- retours `PRG_04/05/06` vers banc simulation : N‑1, nommé ;
- aucun retour N‑1 ne réalise une coupure ou une sécurité physique courante.

## 🛡️ Conservation fonctionnelle PRG_02

- aiguillage réel/simulé par domaine inchangé ;
- valeurs, seuils, polarités, temporisations et filtres joystick/codeur inchangés ;
- deadman sans réarmement automatique ;
- commandes codeur/homing inchangées hors tâche dédiée ;
- comportement manuel M1/M2/M3 inchangé pendant le seul remappage ;
- `ArmingPermit := TRUE` reste une dette visible et bloque la validation safety finale.

## ✅ Critères de gel du contrat

1. chaque variable lue par `PRG_03/04/05/07` est présente dans `Data` ou `HwIn` avec type exact ;
2. aucun consommateur ne lit un `inst*` de `PRG_02` ;
3. un seul producteur écrit chaque champ ;
4. les scalaires legacy sont supprimés après `rg` zéro consommateur ;
5. tests avant/après démontrent les mêmes directions, vitesses et arrêts manuels ;
6. G200, palier C, tous gates, bundle frais et compilation ST2C/StruCpp ciblée sont verts.
7. la perte bus **et** l'incohérence de mesure produisent le même fait codeur qualifié pour chaque consommateur safety validé.
