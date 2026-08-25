# Fiche FB_Acquisition_Preflight v1.2

> Verdict passif machine arrêtée (16 contrôles de cohérence).
> Profil AF03 : brique métier non-mouvement, observateur pur.
> Source : `CODE/A_COMMUN/FB_Acquisition_Preflight.st` · instance : `PRG_07_Supervision.instPreflight` (ST pur, lecture seule stricte).
> Rôle machine : [`AF_Partie-06_Acquisition_Qualification_IO_v2.4.md`](../AF_Partie-06_Acquisition_Qualification_IO_v2.4.md) §7.

## 🎯 Rôle

Vérifie 16 conditions mécaniques/électriques quand la machine est arrêtée.
Aucune écriture de commande, sécurité ou mouvement. Observateur pur.

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Execute` | BOOL | `GVL_IHM.Commun.Preflight.BtnRun` (front IHM) |
| `MachineIsStill` | BOOL | `TonMachineStill.Q` (timer immobilitité) |
| `M1/M2/M3BrakeApplied` | BOOL | `PRG_02_Acquisition.HwIn` |
| `M1/M2ContactorsReleased` | BOOL | `PRG_02_Acquisition.HwIn` |
| `M1/M2ThermalOk` | BOOL | `PRG_02_Acquisition.HwIn` |
| `BrakeThermalOk` / `PhaseRotationOk` | BOOL | `PRG_02_Acquisition.HwIn` |
| `SlackCableTensioned` / `M3SensorWordIncoherent` | BOOL | `PRG_02_Acquisition.HwIn` / acquisition status |
| `EmergencyChainClosed` / `PowerContactorEngaged` | BOOL | `PRG_02_Acquisition.HwIn` |
| `EncoderM1/M2Operational` | BOOL | diagnostics device publiés par `PRG_02_Acquisition` |
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

## 📜 Suivi historique

| Version | Date | Changement |
|---|---|---|
| v1.2 | 2026-08-26 | Ajout du lien explicite vers le chapô AF-06 (rôle machine) |
| v1.1 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## 📄 Docs liées

- `AF_Partie-06_Acquisition_Qualification_IO` §7 (chapô, rôle machine)
- `AF_Partie-11` (flux Translation — ⚠️ réf `§4` retirée 2026-08-26, section inexistante dans AF-11 v2.2 ; à corriger précisément quand AF-11 sera traité) · `AF_Partie-14` (Troubleshooting)