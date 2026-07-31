# Fiche FB_Acquisition_Preflight v1.0

> Verdict passif machine arrêtée (16 contrôles de cohérence).
> Profil AF03 : brique métier non-mouvement, observateur pur.
> Source : `CODE/COMMUN/FB_Acquisition_Preflight.st` · instance : `PRG_11_Troubleshooting.instPreflight`.

## 🎯 Rôle

Vérifie 16 conditions mécaniques/électriques quand la machine est arrêtée.
Aucune écriture de commande, sécurité ou mouvement. Observateur pur.

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Execute` | BOOL | `GVL_IHM.Commun.Preflight.BtnRun` (front IHM) |
| `MachineIsStill` | BOOL | `TonMachineStill.Q` (timer immobilitité) |
| `M1/M2/M3BrakeApplied` | BOOL | `PRG_INPUTS_LD` |
| `M1/M2ContactorsReleased` | BOOL | `PRG_INPUTS_LD` |
| `M1/M2ThermalOk` | BOOL | `PRG_INPUTS_LD` |
| `BrakeThermalOk` / `PhaseRotationOk` | BOOL | `PRG_INPUTS_LD` |
| `SlackCableTensioned` / `M3SensorWordIncoherent` | BOOL | `PRG_INPUTS_LD` |
| `EmergencyChainClosed` / `PowerContactorEngaged` | BOOL | `PRG_INPUTS_LD` |
| `EncoderM1/M2Operational` | BOOL | `FB_Diag_Ethercat` (via PRG_01) |
| `HomedM1/M2` / `M1/M2PositionInBounds` | BOOL | `FB_Encoder_Homing` / `FB_Encoder_Safety` |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `PreflightOk` | BOOL | IHM (`GVL_IHM.Commun.Preflight.PreflightOk`) |
| `PreflightDone` | BOOL | IHM |
| `PreflightBusy` | BOOL | IHM |
| `PreflightErrorId` | WORD | IHM (bitfield 16 bits) |

## 🔒 Impact machine

- **Aucun**. Verdict passif : informe l'opérateur, ne coupe rien.

## ❌ PreflightErrorId (16 bits)

| Bit | Contrôle |
|---|---|
| 0-2 | Frein M1/M2/M3 serré |
| 3-4 | Contacteurs M1/M2 retombés |
| 5-6 | Thermique M1/M2 OK |
| 7 | Thermique frein OK |
| 8 | Rotation phases OK |
| 9 | Câble M2 tendu |
| 10 | Capteurs M3 cohérents |
| 11 | Contacteur sans chaîne AU |
| 12-13 | Codeur M1/M2 opérationnel |
| 14-15 | Homé + position bornée M1/M2 |

## 📄 Docs liées

- `AF_Partie-11` §4 (flux) · `AF_Partie-14` (Troubleshooting)