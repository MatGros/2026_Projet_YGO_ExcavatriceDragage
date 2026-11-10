# 🧭 Proposition — TwinBench v2 : « lancer la simulation », plus « fabriquer une copie »

> Date : 2026-10-02 · Auteur : CC01 · Statut : **PROPOSITION v1 — avant challenge expert**
> Aucun script modifié à ce stade.

---

## 1. 🎯 Pourquoi refondre

| Avant (TwinBench v1) | Constat 2026-10-02 |
|---|---|
| Le lanceur Control Win **copie** le `.project`, le **réécrit** en headless (adaptateur HW_SIM : `GetDeviceState()` → `RUNNING`, symboles E/S ajoutés à `GVL_Global`), compile, déploie. | 4 à 6 min par cycle, opaque, fragile (fenêtre de sélection cachée, menu en boucle, confirmations texte). La copie réécrite **interdit** d'importer `PRG_02`/`GVL_Global` dedans. |
| Le lien Modelica (passerelle UDP + vue) est rangé dans `90_PROTOTYPES/`, hors parcours. | C'est pourtant **la** fonction attendue : « tester le programme automate avec le chariot simulé ». |
| Rien n'indique à l'utilisateur si le PLC simulé parle au simulateur. | Question d'origine non résolue : « comment je vois si le PLC de simu est en run et prêt ». |

**Nouveau socle validé par l'utilisateur (2026-10-02)** : un **seul projet CODESYS**, deux devices :

| Device | Cible | Usage |
|---|---|---|
| `Device` | CPU réel | Terrain · ou simulation intégrée IDE (banc ST interne, **sans réseau**) |
| `Device_CtrlWinSim` | CODESYS Control Win V3 x64 | Vrai runtime sur le PC · banc ST interne **ou** simulateur externe Modelica (UDP) |

Faits prouvés le 2026-10-02 :
- La simulation intégrée IDE n'a **pas de sockets** (SysSocket factice, handle 0) → le lien Modelica exige Control Win.
- `Update Device` vers Control Win conserve EtherCAT, CANopen et les `VH_*` ; seul `Local_Digital_IO` (E/S intégrées du CPU) est perdu → recréé par l'utilisateur avec une carte `VH_0808ETP` renommée `Local_Digital_IO`, mêmes variables → **compile, sans toucher au code**.
- `Device_CtrlWinSim` chargé dans Control Win : le banc ST interne simule comme avant.

👉 Le rôle de l'outil devient : **démarrer / arrêter / surveiller la partie PC de la simulation**. Plus de copie, plus de réécriture.

---

## 2. 🗺️ Parcours utilisateur cible

```text
CODESYS (une fois par session)                 TwinBench (PC)
──────────────────────────────                 ───────────────────────────────
1. Set Active Application                      TwinBench.cmd
   → Device_CtrlWinSim                          1  Simulation M3 reliée au PLC
2. Login → Control Win → Run                       (passerelle FMU + vue M3)
3. GVL_Simulation :                             2  Simulation M3 seule (sans PLC)
   SimulationModeActive = 1                     3  Ouvrir le modèle (OMEdit)
   SimM3OpenModelicaActive = 1                  4  État / diagnostic
4. Lire SimM3LinkReady = TRUE                   5  Tout arrêter
                                                0  Quitter
```

Règles d'ergonomie (retours utilisateur 2026-10-02) :
- **Toute réponse = un chiffre.** Jamais un mot à taper.
- **Aucune fenêtre cachée** : toute boîte de dialogue au premier plan (owner TopMost).
- **Un seul point d'entrée** (`TwinBench.cmd`) ; les scripts techniques restent internes.
- **Chaque action affiche son verdict** : `[OK]` / `[ECHEC] cause + quoi faire`.
- **Pas de procédure à deviner** : la procédure CODESYS est un guide pas à pas avec captures attendues.

---

## 3. 📦 Proposition détaillée

### 3.1 Lanceur unique `TOOLS/TWINBENCH/TwinBench.cmd` (+ `TwinBench.ps1`)

| Choix | Action | Détail technique |
|---|---|---|
| **1** | Simulation M3 reliée au PLC | Démarre la passerelle FMU (port 29061, plante remise à P1) **puis** la vue M3 en lecture (port 29072). Si une passerelle tourne déjà : propose `1 = redémarrer à P1`, `2 = garder`. |
| **2** | Simulation M3 seule | Vue M3 + FMU locale, joystick à l'écran. Aucun PLC contacté. |
| **3** | Ouvrir le modèle | OMEdit sur `M3_POC.mo`. |
| **4** | État / diagnostic | Une seule page : Control Win démarré ? · passerelle active (PID, depuis quand) ? · **trames PLC reçues / rejetées / âge dernière trame** · vue M3 ouverte ? · dernière trace CSV. Chaque ligne = OK/KO + action conseillée. |
| **5** | Tout arrêter | Arrête **uniquement** les processus identifiés TwinBench (passerelle, vue), jamais CODESYS ni un Python étranger. |
| **0** | Quitter | — |

Identification des processus : par **port + nom de script** (`udp_m3_fmu_gateway.py`, `app.py`), indépendamment du dossier — corrige le refus du 2026-10-02 (ancienne instance lancée depuis un chemin déplacé, non reconnue).

### 3.2 Indicateur « PLC relié » dans la vue M3 (question d'origine)

Bandeau permanent en haut de la vue, alimenté par la passerelle :

| État | Condition (passerelle) | Couleur |
|---|---|---|
| `PLC RELIÉ` | trame PLC acceptée depuis < 1 s | vert |
| `PLC MUET` | passerelle prête, aucune trame depuis > 1 s | orange |
| `TRAMES REJETÉES` | trames reçues mais rejetées | rouge |
| `PASSERELLE ARRÊTÉE` | aucune donnée UDP 29072 | gris |

Côté CODESYS, la vérité reste `GVL_Simulation.SimM3LinkReady` / `SimM3LinkTimeout` / `SimM3LinkInvalid` (lot T415-B L1, déjà livré).

### 3.3 Restructuration des dossiers

| Actuel | Cible | Motif |
|---|---|---|
| `00_START.cmd`, `10_PROJECT.cmd`, `20_SIM.cmd` | `TwinBench.cmd` unique | Un seul point d'entrée |
| `01_PROJECT/controlwin_runner/` (copie + HW_SIM + déploiement headless) | `ARCHIVES/` **après décision humaine** | Remplacé par `Device_CtrlWinSim` ; savoir HW_SIM transféré dans le guide |
| `90_PROTOTYPES/m3_link/` (passerelle, protocole, tests) | `02_SIM/m3_link/` | Promu : c'est le chemin nominal |
| `02_SIM/modelica/` | inchangé | — |
| `03_TRANSPORT/udp_native/` (banc T408) | `90_PROTOTYPES/` | Benchmark, hors parcours |
| `90_PROTOTYPES/m3_telemetry/` | `90_PROTOTYPES/` (inchangé) | Démo |

### 3.4 Environnement Python unique

Aujourd'hui : passerelle = Python **global** (doit contenir `OMSimulator`) ; vue = venv `%LOCALAPPDATA%\TwinBenchM3Live\Python` (PySide6). Deux environnements, deux sources de panne.
→ Un seul venv TwinBench, créé/vérifié par le lanceur (`PySide6`, `OMSimulator`), avec diagnostic clair si OpenModelica est absent.

### 3.5 Documentation

| Document | Contenu |
|---|---|
| `TOOLS/TWINBENCH/README.md` | Réécrit : 3 modes (réel / IDE / Control Win), le menu, « que faire si… » |
| `TOOLS/TWINBENCH/GUIDE_DEVICE_CTRLWINSIM.md` (nouveau) | Pas à pas : copier `Device` → `Update Device` Control Win V3 x64 → remplacer `Local_Digital_IO` (VH_0808ETP renommée, mêmes variables) → librairies `SysSocket` + `SysTypes2 Interfaces` → Build → Set Active Application → Communication Settings → Login. Règle **import XML ×2**. Règle **report manuel des modifs matérielles**. Garde-fous. |
| `DOC/AF/AF_Partie-13` | Ajout fiche `FB_Sim_Translation_ExtLink` (après validation POC — décision 2026-10-02 : spec après POC) |
| Notes T404/T409 | Marquées « historiques », renvoi vers v2 |

### 3.6 Garde-fous sécurité

- Loopback `127.0.0.1` uniquement (passerelle et PLC).
- Le PLC simulé n'est jamais le CPU réel : `Device_CtrlWinSim` a un type de cible Control Win (CODESYS refuse un download vers une cible d'un autre type — **à vérifier par essai**, cf. challenge).
- Le bit `SimM3OpenModelicaActive` reste opérateur ; le FB ne l'écrit jamais.
- Perte de liaison : image gelée + `SimM3LinkTimeout` ; jamais de saut capteurs.
- Le lanceur ne tue que ce qu'il a identifié ; il ne télécharge rien dans aucun automate.

### 3.7 Outillage de contrôle à mettre à jour

`check_t407_udp_m3_link.py`, `check_t408_native_udp_poc.py`, `check_twinbench_m3_live_poc.py`, `check_twinbench_m3_poc_structure.py`, `check_dredge_signal_catalog.py` référencent les anciens chemins → mise à jour ou retrait coordonné.

---

## 4. ❓ Points ouverts (à trancher)

1. Archivage effectif de `controlwin_runner/` (et de `codesys_headless.py`, 476 lignes) — décision humaine.
2. Double copie du code (`Device` / `Device_CtrlWinSim`) : accepter l'import ×2, ou chantier « code partagé au niveau projet » ?
3. Faut-il un contrôle automatique de divergence entre les deux Applications ?
4. Le bandeau « PLC relié » doit-il aussi lire `SimM3LinkReady` côté PLC (OPC UA / symbol config) ou rester côté passerelle ?
