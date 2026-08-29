# 📘 Rapport — Banc de test interactif FB_Cycle (T173) & chaîne simulation

**Date** : 2026-08-28 · **Auteur** : DeepSeek (DSH) · **Branche** : `WT3_TEST_AUTO_CI`
**Périmètre** : `TOOLS/TEST_AUTO_CI/**` (aucune modification `CODE/`)
**Prérequis** : Python 3.x, g++ (MinGW/WinLibs), STruCpp (`TOOLS/COMPILER_ST2C_STruCpp`, fourni)

---

## 1. Objectif

Permettre de **tester le programme (FB_Cycle)** en pilotant **manuellement** les transitions
du cycle (joystick, armement homme-mort, capteurs, StartCycle, Reset, mode) contre le
**binaire compilé du FB**, et d'en observer les décisions (étapes, ordres actionneurs).
L'animation classique (T171) est un *lecteur de trace* (playback scripté) ; le banc (T173)
est un **outil interactif de test** où l'utilisateur **conduit** le cycle.

> ⚠️ **Principe architecturel non négociable** : **zéro logique métier en JavaScript**.
> Les décisions (transitions, ordres actionneurs) viennent exclusivement du binaire compilé.
> Le JS navigateur n'**envoie** que des stimuli et n'**affiche** que des sorties ; il simule
> uniquement l'**environnement physique** (position treuil qui évolue). Certifié par
> `guard_animation_no_business_logic.py`.

---

## 2. Architecture générale & modules

```
┌─────────────────────────┐      HTTP /scan      ┌──────────────────────────────┐
│  NAVIGATEUR (UI)        │ ────────────────▶   │  SERVEUR local (Python)      │
│  cycle_bench.html       │  {stimuli: {...}}   │  cycle_bench_server.py       │
│                         │                      │                              │
│  • joystick virtuel     │                      │  POST /scan  → stdin        │
│  • homme-mort           │                      │  POST /reset                 │
│  • capteurs/ordre       │                      │  port défaut 8090 (+ fallback)│
│  • scène SVG machine    │ ◀────────────────   │  ouvre le navigateur         │
└─────────────────────────┘  {outputs: {...}}    └──────────────┬───────────────┘
                                                                 │ stdin/stdout
                                                          ┌─────▼──────────────┐
                                                          │ MOTEUR (C++)       │
                                                          │ cycle_engine.exe   │
                                                          │ = FB_Cycle COMPILÉ │
                                                          │ (WORKING_COPY)     │
                                                          └────────────────────┘
```

### Modules

| Module | Type | Rôle |
|---|---|---|
| `engine/cycle_engine.cpp` | C++ compilé → `.exe` | Instancie `FB_Cycle` (binaire STruCpp/g++). Ligne en entrée (`key=value` stimuli), ligne en sortie (`key=value` sorties). **Processus persistant** : l'état du FB (R_TRIG, timers, `STATE`) est conservé entre les scans. Source = `WORKING_COPY` (jamais `CODE/`). |
| `anim_bench/build_cycle_engine.py` | Build tool | Chaîne : `convert_codesys_to_iec.py` (ST→IEC) → `strucpp` (IEC→C++) → `g++` (C++→`.exe`). |
| `anim_bench/cycle_bench_server.py` | Serveur HTTP (stdlib) | Spawn le moteur en sous-processus, expose `POST /scan` (exécute 1 scan) et `POST /reset` (relance le moteur). Port défaut **8090** avec fallback automatique (évite 8080/8081 souvent occupés), ouvre le navigateur, en-têtes `no-cache`. |
| `engine/cycle_bench.html` | UI web | Panneau de commande : joystick virtuel, homme-mort, stimuli d'entrée, scène SVG machine live, panneau de sorties, barre de position. |
| `anim_bench/guard_animation_no_business_logic.py` | Garde (CI) | Certifie l'absence de logique métier en JS (analyse AST-lite + fraîcheur SHA trace). |
| `anim_bench/run_ci_gates.py` | Gate CI | Point d'entrée : harnais 6/6 + négatifs 3/3 + garde animation (branché **G460**). |

---

## 3. Flux de données détaillé

### 3.1. Un scan (boucle pas-à-pas)

1. **UI** — l'utilisateur agit : pousse le joystick, arme l'homme-mort, coche un capteur,
   modifie `StartCycle`, choisit le mode.
2. **JS `collectStimuli()`** — construit le dictionnaire de stimuli à partir des contrôles
   (booleans → `1/0`), des capteurs **dérivés de la position simulée** et des positions
   câble `M1_CABLEPOSM`/`M2_CABLEPOSM`.
3. **`POST /scan`** — le navigateur envoie `{stimuli:{...}}` au serveur.
4. **Serveur `_run_scan()`** — sérialise les stimuli en **une ligne** `key=value key=value…`,
   l'écrit sur `stdin` du moteur, lit la ligne de réponse sur `stdout`.
5. **Moteur** — positionne les champs sur l'instance `FB_Cycle`, appel `fb()`, émet la
   ligne de sorties (CycleStep, WinchM1Cmd/M2Cmd, TranslationCmd, BucketCmd, Fault,
   Lifecycle, OperatorAction, WaitingForOperator, SampleCount…).
6. **Serveur** — parse la ligne en `outputs:{...}`, répond en JSON.
7. **JS `render()` + `updateScene()`** — affiche les sorties et positionne la scène SVG
   (benn selon position simulée, pont selon capteurs translation, benne ouverte, gravier).

### 3.2. Simulation physique (le « monde », côté JS)

Le FB commande les treuils (`WinchM1Cmd`), mais le mouvement réel est **autorisé** par
l'opérateur. Après chaque scan, le JS met à jour les positions simulées `simM1`/`simM2` :

```
mouvement autorisé ⇔ WinchM1Cmd.StartStop=1 ET joyY d'accord (même sens) ET homme-mort armé
⇒ simM1/simM2 += Direction × vitesse × dt  (borné à [-10.5, +8.5] m)
```

Les capteurs **Top Haut** (≥ +8.5 m) et **Kobold Fond** (≤ −9.5 m) sont **dérivés de la
position** dans `collectStimuli()`. C'est la réponse du *monde*, jamais la logique du FB.

### 3.3. Protocole moteur (ligne `key=value`)

- Entrées : `ENABLE RESET POWERCONTACTORENGAGED MODE CYCLEMOTIONPERMIT DEADMANARMED
  HEARTBEATIHMOK STARTCYCLE ABORTCYCLE SELTARGET SETDEPTHM SETOFFSETM KOBOLDCONTACTFOND
  LIMITLEGALREACHED LIMITLEGALDEPTHM WINCHSYNCERROR WINCHSYNCDELTAM M1_CABLEPOSM M2_CABLEPOSM
  M1_MEASUREDSPEEDMPS M2_MEASUREDSPEEDMPS SPEEDMISMATCHTHRESHOLDMPS SPEEDMISMATCHTIMEOUT
  CABLELIMITM1ASCENTM TRANSLATION_AT_P1/TREMIE/MAINTENANCE TRANSLATION_BUSY/DONE
  BENNE_BUSY/DONE/ISOPEN/ISCLOSED/ISROUGHLYCLOSED HOMEDM1 HOMEDM2 TOPPOSITIONSENSOR
  HOMINGREQUEST SAMPLECOUNT` (IN_OUT).
- Sorties : `READY FAULT.* LIFECYCLE.* SPEEDMISMATCH* WINCHM1CMD.* WINCHM2CMD.*
  TRANSLATIONCMD.* BUCKETCMD.* CYCLESTEP CYCLESTATESTR CYCLESTEPATERROR OPERATORACTIONID
  OPERATORACTION EXPECTEDAXIS EXPECTEDDIRECTION WAITINGFOROPERATOR WAITINGFORPROCESS
  REQUESTACTIVE SAMPLECOUNT`.

---

## 4. Fonctionnalités du banc

| Fonction | Détail |
|---|---|
| **Joystick virtuel** | Pousser haut/bas = monter/descendre les treuils, intensité proportionnelle (0–100 %). |
| **Homme-mort (armement)** | Autorise l'effet du joystick ; sans lui, le binaire neutralise les mouvements. |
| **Auto-scan** | Boucle continue (~200 ms) pour « conduire » la machine en temps réel. |
| **Vitesse simulée** | Ajuste la vitesse de déplacement de la position câble (m/s). |
| **Stimuli** | Mode, Enable, PowerContactor, CycleMotionPermit, Heartbeat, StartCycle (front), AbortCycle, SelTarget, capteurs translation, benne, homing. |
| **Scène SVG machine** | Benne qui monte/descend avec la position, pont M3 qui suit les capteurs translation, benne ouverte si `BENNE_ISOPEN`, gravier si benne chargée (étapes 6–10). |
| **Sorties** | Étape + OperatorAction, Treuil M1/M2 (StartStop/Direction/SpeedPct), Translation, Benne, Kobold contacteur, Fault, Lifecycle, SampleCount, attente opérateur. |
| **Barre de position** | Repère visuel −10.5 m → +8.5 m. |
| **Reset moteur** | Relance le binaire (état FB remis à zéro) + remet la position à 7.0 m. |
| **Responsive** | Fenêtre large : sorties à gauche / commandes à droite ; étroite : empilement propre. |

---

## 5. Mise en route

```powershell
cd C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\WT3_TEST_AUTO_CI
.\run_banc.bat
```
Le `.bat` : (1) trouve Python (fallbacks), (2) compile le moteur **si absent**,
(3) démarre le serveur → ouvre le navigateur sur `http://127.0.0.1:8090`.

### Comment tester un cycle (exemple)
1. **StartCycle** (coche) : X0 → X1.
2. **Joystick ▼ + homme-mort** : descendre la benne jusqu'au fond (Kobold) → transition.
3. Enchaîner les étapes selon les conditions indiquées dans `OperatorAction`.
4. **Reset** pour repartir.

---

## 6. Validation & CI

| Contrôle | Résultat |
|---|---|
| `anim_bench/run_ci_gates.py` | G-CI-1 harnais 6/6 · G-CI-2 négatifs 3/3 (défauts F1/F2/F6 prouvés sur CODE/ original) · G-CI-3 garde PASS |
| `guard_animation_no_business_logic.py --html cycle_bench.html --no-freshness` | PASS (zéro logique métier JS) |
| `node --check` (JS du banc) | PASS |
| Gates `run_all_gates.py --palier C` | **17/17 PASS** (dont **G460** = chaîne CI TEST_AUTO_CI) |
| G200 liaison (bundle) | PASS (0 erreur) |

---

## 7. Contexte lié (T171 / T172) — pour un relecteur

- **T171 (clôturé)** : animation pilotée par le code compilé — harnais de tests 6/6 +
  trace scan-par-scan `trace_semi_auto_cycle.json` (15 scans) + animation pur lecteur
  (garde-fou PASS) + audit indépendant Ollama **CONFORME**.
- **T172 (proposé, non appliqué)** : rebouclage `X13 → X2` (homing conservé, pas d'attente
  StartCycle) — diff `PROPOSAL_WT3-T172_X13_X2_20260828.md`, **en attente de visa**.
- **REX** `REX_Harnais_StruCpp_InOut_Trace_20260828.md` : codegen STruCpp = `VAR_IN_OUT`
  copy-in seul ; 3 causes de troncature Ollama (timeout/`num_predict`/`num_ctx`).

---

*Livrables versionnés sur `WT3_TEST_AUTO_CI` — aucun push vers `origin/main` sans relecture du diff et accord explicite.*
