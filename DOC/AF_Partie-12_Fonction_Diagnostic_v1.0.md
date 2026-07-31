# AF Partie 12 — Diagnostic & Supervision Bus (v1.0)

> Rôle : diagnostics de communication bus/devices et surveillance opérateur.
> Les FB diag publient des faits (`Online`, `Operational`, `State`, `ErrorId`).
> Les FB Safety aval **décident** d'agir (SafeStop) — aucun FB diag ne coupe directement.
> Source code : `CODE/DIAG/*.st` · instances dans `PRG_01_Diagnostics` et `PRG_11_Troubleshooting`.
> Détail par FB : voir les fiches dédiées (§1).

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôles et familles
3. DUT et bus
4. Flux et consommateurs
5. Intégration programme
6. ErrorId
7. Documents liés

---

## 1. Composition — fiches FB dédiées

| Fiche | FB | Contenu |
|---|---|---|
| [`FB_Diag_CanOpen`](AF_Partie-11_Fonction_Diagnostic/FB_Diag_CanOpen_v1.0.md) | `FB_Diag_CanOpen` | Diagnostic bus CANopen + esclave Joystick |
| [`FB_Diag_Ethercat`](AF_Partie-11_Fonction_Diagnostic/FB_Diag_Ethercat_v1.0.md) | `FB_Diag_Ethercat` | Diagnostic bus EtherCAT (variateur M3 + codeurs M1/M2) |
| [`FB_Diag_IhmHeartbeat`](AF_Partie-11_Fonction_Diagnostic/FB_Diag_IhmHeartbeat_v1.0.md) | `FB_Diag_IhmHeartbeat` | Surveillance bidirectionnelle IHM↔PLC |
| [`FB_Diag_Preflight`](AF_Partie-11_Fonction_Diagnostic/FB_Diag_Preflight_v1.0.md) | `FB_Diag_Preflight` | Verdict passif machine arrêtée (16 contrôles) |
| [`FB_Diag_WinchSymmetry`](AF_Partie-11_Fonction_Diagnostic/FB_Diag_WinchSymmetry_v1.0.md) | `FB_Diag_WinchSymmetry` | Mesure passive symétrie M1/M2 (MES-008) |

---

## 2. Rôles et familles

| Famille | Rôle | Coupe ? | Consommateurs |
|---|---|---|---|
| **Bus/Device** | Publie Online/Operational/State/ErrorId par device | Non (directement) | FB_Safety_Winch, FB_Safety_Translation, FB_Modes, IHM |
| **Comm opérateur** | Surveille toggle IHM, génère toggle PLC, détecte timeout | Non (directement) | FB_Safety_Winch, FB_Safety_Translation, Troubleshooting |
| **Observateur** | Verdict passif ou mesure sans rétroaction machine | Non | IHM uniquement |

> 📌 **Principe** : un FB diag ne pilote jamais SafeStop/PowerCutOff. Il publie des faits.
> Les FB_Safety_<Domaine> consomment ces faits et décident seuls de l'action.

---

## 3. DUT et bus

| DUT | Champs clés | Producteur | Consommateur |
|---|---|---|---|
| `ST_Diag_Device` | `Online`, `Operational`, `Error`, `ErrorId`, `State` (E_Diag_State), `StateAtError` | `FB_Diag_CanOpen`, `FB_Diag_Ethercat` | Safety, Modes, IHM, Troubleshooting |
| `E_Diag_State` | `DISABLED`, `READY`, `INIT`, `MONITORING`, `ERROR`, `SIMULATED` | FB diag | IHM, Modes |
| `ST_Diag_Winch_SymmetryCfg` | Seuils (`DeltaStartDelay_Ms`, etc.) | GVL_PERSISTENT | `FB_Diag_WinchSymmetry` |
| `ST_Diag_Winch_SymmetryData` | Mesures (`DeltaStartDelay_Ms`, `MaxSyncDeviation_M`, etc.) | `FB_Diag_WinchSymmetry` | IHM, GVL_PERSISTENT |

---

## 4. Flux et consommateurs

```text
PRG_01_Diagnostics (acquisition brutes device)
  ├── FB_Diag_CanOpen ──► DeviceJoystick.Online/Operational ──► FB_Safety_Winch/Translation (SafeStop)
  │                    ──► DeviceCanOpenMaster ──► IHM Network
  ├── FB_Diag_Ethercat ──► DeviceVariateur.Online/Operational ──► FB_Safety_Translation (SafeStop)
  │                    ──► DeviceEncoderM1/M2.Operational ──► FB_Diag_Preflight, IHM
  ├── FB_Diag_IhmHeartbeat ──► HeartbeatIhmOk ──► FB_Safety_Winch/Translation (SafeStop)
  │                        ──► TglHeartbeatPlc ──► IHM
  └── (sorties diag publiées vers IHM Network + Troubleshooting)

PRG_11_Troubleshooting (observateurs passifs)
  ├── FB_Diag_Preflight ──► PreflightOk/ErrorId ──► IHM uniquement
  └── FB_Diag_WinchSymmetry ──► SymmetryOk/Valid ──► IHM uniquement
```

---

## 5. Intégration programme

| Programme | Instances | Rôle |
|---|---|---|
| `PRG_01_Diagnostics` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` | Acquisition brutes + appel FB diag bus/comm |
| `PRG_11_Troubleshooting` | `instPreflight`, `instWinchSymmetry` | Observateurs passifs (verdict + mesure) |
| `PRG_03_Safety` | (consommateur) | Relaye `JoystickOnline/Operational`, `HeartbeatIhmOk`, `DriveOnline/Operational` vers `FB_Safety_Winch/Translation` |
| `PRG_09_Supervision` | (consommateur) | Publie diagnostics vers IHM (Network, Preflight, Symmetry) |

---

## 6. ErrorId

### FB_Diag_CanOpen (DeviceJoystick.ErrorId)
| Bit | Cause |
|---|---|
| 0 | Perte liaison CAN joystick |
| 1 | Joystick non opérationnel (pas RUNNING) |

### FB_Diag_Ethercat
| Device | Bit | Cause |
|---|---|---|
| DeviceVariateur | 4 | Perte liaison variateur M3 |
| DeviceEncoderM1 | 5 | Perte liaison codeur M1 |
| DeviceEncoderM2 | 6 | Perte liaison codeur M2 |

> ErrorId global synthétise par nibble : `0x00F0` = variateur, `0x0F00` = M1, `0xF000` = M2.

### FB_Diag_Preflight (PreflightErrorId)
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

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Architecture programme — frontières et flux |
| AF03 | Contrats composants — profil non-mouvement |
| AF06 | Acquisition qualifiée — diagnostics bus §3 |
| AF07 | Interface IHM — heartbeat, affichage diag |
| AF10/AF11 | FB_Safety_Winch / FB_Safety_Translation (consommateurs) |
| Code | `CODE/DIAG/*.st` |