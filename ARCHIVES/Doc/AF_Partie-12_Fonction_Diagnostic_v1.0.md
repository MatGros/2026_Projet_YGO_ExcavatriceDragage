# AF Partie 12 — Diagnostic & Supervision Bus (v1.0)

> Rôle : diagnostics de communication bus/devices et surveillance opérateur.
> Les FB diag publient des faits (`Online`, `Operational`, `State`, `ErrorId`).
> Les FB Safety aval **décident** d'agir (SafeStop) — aucun FB diag ne coupe directement.
> Source code : `CODE/DIAG/*.st` · instances dans `PRG_01_Diagnostics` et `PRG_TROUBLESHOOTING_CFC` (ST actuels).
> Cible : les diagnostics devices/bus rejoignent `PRG_02_Acquisition`, les observateurs passifs rejoignent `PRG_07_Supervision` — voir §5.
> Détail par FB : voir les fiches dédiées (§1).
> 🗺️ Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md` §2 et §4.

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
| [`FB_Diag_CanOpen`](AF_Partie-12_Fonction_Diagnostic/FB_Diag_CanOpen_v1.0.md) | `FB_Diag_CanOpen` | Diagnostic bus CANopen + esclave Joystick |
| [`FB_Diag_Ethercat`](AF_Partie-12_Fonction_Diagnostic/FB_Diag_Ethercat_v1.0.md) | `FB_Diag_Ethercat` | Diagnostic bus EtherCAT (variateur M3 + codeurs M1/M2) |
| [`FB_Diag_IhmHeartbeat`](AF_Partie-12_Fonction_Diagnostic/FB_Diag_IhmHeartbeat_v1.0.md) | `FB_Diag_IhmHeartbeat` | Surveillance bidirectionnelle IHM↔PLC |

> 📌 `FB_Acquisition_Preflight` (qualification E/S machine arrêtée) est documenté dans
> [`AF_Partie-06`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.0.md).
> `FB_Winch_Symmetry` (mesure M1/M2) est documenté dans
> [`AF_Partie-10`](AF_Partie-10_Fonction_Winch/FB_Winch_Symmetry_v1.0.md).

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
| `ST_Winch_SymmetryCfg` | Seuils (`DeltaStartDelay_Ms`, etc.) | GVL_PERSISTENT | `FB_Winch_Symmetry` |
| `ST_Winch_SymmetryData` | Mesures (`DeltaStartDelay_Ms`, `MaxSyncDeviation_M`, etc.) | `FB_Winch_Symmetry` | IHM, GVL_PERSISTENT |

---

## 4. Flux et consommateurs

### 4.1 État actuel du code (ST, avant migration)

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>FB_Diag_CanOpen & FB_Diag_Ethercat & FB_Diag_IhmHeartbeat</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Acquisition brutes device & santé communication bus/IHM</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Online / Operational & HeartbeatOk</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #f43f5e; padding:6px 10px; border-radius:4px; font-size:12px;">
    🛡️ &nbsp;<b>FB_Safety_Winch / FB_Safety_Translation</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Déclenchement SafeStop si perte communication ou défaut bus</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Signaux de diagnostic qualifiés</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    🖥️ &nbsp;<b>PRG_07_Supervision & IHM Network</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Publication des états de diagnostic, Preflight & Symétrie M1/M2</span>
  </div>
</div>

---

## 5. Intégration programme

### 5.1 État actuel du code (ST legacy, avant migration)

| Programme | Instances | Rôle |
|---|---|---|
| `PRG_01_Diagnostics` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` | Acquisition brutes + appel FB diag bus/comm |
| `PRG_TROUBLESHOOTING_CFC` | `instPreflight`, `instWinchSymmetry` | Observateurs passifs (doc : AF06 Preflight, AF10 Symmetry) |
| `PRG_SAFETY_CFC` | (consommateur) | Relaye `JoystickOnline/Operational`, `HeartbeatIhmOk`, `DriveOnline/Operational` vers `FB_Safety_Winch/Translation` |
| `PRG_SUPERVISION_CFC` | (consommateur) | Publie diagnostics vers IHM (Network, Preflight, Symmetry) |

### 5.2 Cible — architecture 7 POU

Il n'existe **plus de POU de diagnostic autonome** ni de POU safety global dans la cible : un
diagnostic device est un **fait d'entree qualifie**, donc il appartient a l'acquisition ; un
observateur passif est de l'observation, donc il appartient a la supervision.

| POU cible | Instances | Rôle |
|---|---|---|
| `PRG_02_Acquisition` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` | Acquisition brutes + appel FB diag bus/comm, **au meme endroit que le joystick et les codeurs qu'ils surveillent** |
| `PRG_04_Treuils_Benne` | (consommateur) | `FB_Safety_Winch` M1/M2 y est instancie : il consomme directement `JoystickOnline/Operational` et `HeartbeatIhmOk` |
| `PRG_05_Translation` | (consommateur) | `FB_Safety_Translation` y est instancie : il consomme `DriveOnline/Operational` et `HeartbeatIhmOk` |
| `PRG_07_Supervision` | `instPreflight`, `instWinchSymmetry` + (consommateur) | Observateurs passifs et publication IHM. Lecture seule stricte : n'ecrit ni commande, ni configuration, ni interlock |

⚠️ **Aucune semantique diagnostic ne change** : les bits `ErrorId` du §6, les etats `E_Diag_State`,
les seuils et les consommateurs restent identiques. Seule **l'affectation POU** change.

✅ Effet attendu : la duplication de `instJoystick` et le cycle prouve `Acquisition ↔ Diagnostics`
disparaissent (lot M1) ; le relais par un POU safety intermediaire disparait (lots M3/M4), chaque
`FB_Safety_*` lisant le fait diagnostic directement depuis l'acquisition.

📌 Lots de migration : **M1** (diagnostics dans l'acquisition) et **M6** (observateurs dans la
supervision) — migration 7 POU soldée, historique archivé (`ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`).

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

### FB_Acquisition_Preflight (PreflightErrorId)

> Documenté dans [`AF_Partie-06`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.0.md) — 16 bits de qualification E/S machine arrêtée.

### FB_Winch_Symmetry

> Documenté dans [`AF_Partie-10`](AF_Partie-10_Fonction_Winch/FB_Winch_Symmetry_v1.0.md) — mesures M1/M2 (MES-008).

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