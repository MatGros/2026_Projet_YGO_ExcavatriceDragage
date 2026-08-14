# 🧪 Analyse Fonctionnelle — Partie 13 : Simulation (v2.2)

> **Projet** : Excavatrice de dragage — CODESYS 3.5
> **Statut** : référence active · décision documentaire préalable au retrait de `PRG_01/FB_Input`
> **Sources** : `CODE/SIMULATION/FB_SimBench.st`, `CODE/MAIN/PRG_02_Acquisition.st` (ST propriétaire),
> `AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md`,
> `CHECKLISTS/CHECKLIST_MiseEnRoute_Simulation_v1.0.md`.

---

## 1. 🎯 Rôle et doctrine

La simulation fournit au programme une image d'entrée plausible lorsque le matériel est absent.
Elle n'est ni un bypass, ni un forçage d'état sain, ni une autorisation de sécurité.

| Besoin | Outil | Règle |
|---|---|---|
| Ignorer un défaut sur matériel présent | 🔒 Bypass IHM | MAINT_N2, tracé et maintenu explicitement |
| Fabriquer une valeur pour matériel absent | 🧪 Simulation | Banc PLC confiné derrière la frontière d'entrée |
| Injecter une panne ponctuelle | 🖐️ Force natif CODESYS | Vue instance, temporaire, jamais dans la logique |

🚫 La simulation ne complète jamais une entrée réelle par `OR`. Un domaine est réel **ou** simulé.

## 2. 🏗️ Frontière unique

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>E/S Physiques [%IX / PDO]</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Acquisition réelle (HwReal)</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Signaux physiques réels</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #fbbf24; padding:6px 10px; border-radius:4px; font-size:12px;">
    🕹️ &nbsp;<b>FB_SimBench</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Génération image de simulation (HwSim)</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Sélection par domaine dans PRG_02_Acquisition</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    ⚙️ &nbsp;<b>Image HwIn</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Consommation unique par la logique métier</span>
  </div>
</div>

`PRG_02_Acquisition` est la frontière unique réelle/simulée. Il acquiert aussi les codeurs,
les diagnostics devices/bus et les retours auxiliaires :

1. il acquiert chaque E/S brute dans `HwReal : ST_HardwareImage` ;
2. il évalue `GetDeviceState()` et publie `InputModuleFault` ;
3. `instSimBench` construit les sous-images simulées ;
4. `HwSim : ST_HardwareImage` les expose pour observation ;
5. les sélecteurs par domaine choisissent `HwReal` ou `HwSim` dans `HwIn` ;
6. `HwIn` alimente la logique métier.

`PRG_01_Inputs_LD`, `FB_Input` et `ST_InputsQualified` sont en retrait documentaire et ne doivent
plus recevoir de nouveau consommateur. Leur suppression effective intervient après le remappage
et la preuve du filtrage matériel ou logiciel.

`HwIn` est la seule image consommée par le programme métier. Aucun FB métier ne lit
`GVL_Simulation` ni `HwSim`.

## 3. 🎛️ Commande de simulation

`GVL_Simulation` est lu uniquement par l'acquisition ST actuelle, le banc et les publications/diagnostics
autorisés. Polarité positive : `TRUE = simulation/stimulus actif`; tous les flags sont `FALSE` au démarrage.

| Signal | Domaine ou rôle |
|---|---|
| `SimulationModeActive` | 🔑 bit maître : front montant active les 4 domaines ; front descendant les désactive et remet les stimuli au nominal |
| `SimWinchActive` | M1/M2 : codeurs, contacteurs, freins, thermiques, haut, câble |
| `SimTranslationActive` | AC600 M3, fréquence, cinq capteurs et frein |
| `SimOperatorActive` | joystick CANopen, axes bruts et homme-mort |
| `SimSafetyActive` | chaîne AU, contacteur, réarmement, phases, thermiques, Kobold et auxiliaires communs |

Le sélecteur est atomique par domaine : `HwIn.<Domaine> := HwSim.<Domaine>` ou
`HwReal.<Domaine>`. Il interdit tout mélange réel/simulé dans un même domaine.

### Stimuli de banc

| Famille | Champs | Sémantique |
|---|---|---|
| ↔️ M3 | `SimM3SensorsWordOverrideActive`, `SimM3SensorsWord` | Override manuel uniquement ; bit4=Trémie, bit3=PV, bit2=PVP2, bit1=P1, bit0=Maintenance. Le modèle dynamique reste la source nominale. |
| 🕹️ Joystick | `SimJoystickLeftActive`, `SimJoystickRightActive`, `SimJoystickForwardActive`, `SimJoystickReverseActive` | Un seul bouton impose `0`/`5000`/`10000`. Plusieurs boutons ⇒ neutre. |
| 🕹️ Homme-mort | `SimJoystickRawButton` | TRUE simule le bouton brut ; le contrôle homme-mort de `FB_Joystick` reste actif. |
| 🪝 Synchronisation | `SimSyncDeviationInjectM1/M2`, `SimSyncDeviationOffset_M` | Front montant : saut persistant de position simulée afin de tester l'écart M1/M2. |

Au front descendant du bit maître, tous les flags de domaine et stimuli ci-dessus reprennent leurs
valeurs nominales. Les positions codeurs persistantes ne sont pas des stimuli et ne sont pas effacées.

## 4. 🧩 Modèle de banc

`FB_SimBench` est une brique réduite : ses entrées explicites reçoivent les commandes du scan
précédent, les stimuli et `HwReal`; il ne lit aucune GVL. Il compose :

| Bloc | Rôle | Convention critique |
|---|---|---|
| `FB_Sim_Encoder` ×2 | position COD1/COD2, presets et écart de synchro | les positions suivent les commandes treuil |
| `FB_Sim_Translation` | trajet continu M3, positions et état AC600 | ne publie que les six mots thermomètre valides ; progression à vitesse commandée |
| `FB_Sim_Joystick` | valeurs Hall et homme-mort simulables | neutre = 5000 ; le contrôle homme-mort reste actif |
| `FB_Sim_Safety` | chaîne AU, contacteur et réarmement | commande maintenue `PowerKeepAlive_A/B` |

### 🔒 Polarités

- `Mx_BrakeIsOpen_DI := Mx_BrakeCmd` : `TRUE` signifie **frein ouvert**. Aucun `NOT`.
- Retour contacteurs M1/M2 : `TRUE` seulement quand sens **et** paliers sont tous retombés.
- `PowerKeepAlive_A/B_RQ = TRUE` maintient la puissance; `FALSE` provoque la coupure fail-safe.

Le REX C1 : un retour de frein simulé inversé, ajouté à une logique aval elle-même erronée,
compensait les deux erreurs et masquait le défaut réel. La polarité est donc définie au modèle et normalisée une seule fois dans la frontière
`PRG_02_Acquisition` ou garantie par le mapping matériel — le simulé est normalisé au modèle
(les valeurs simulées traversent la sélection sans filtrage supplémentaire).

## 5. 🔍 Observation et diagnostic

En vue instance de `PRG_02_Acquisition`, lire côte à côte les trois `ST_HardwareImage` homologues :

| Image | Signification |
|---|---|
| `HwReal` | valeur brute reçue du matériel/PDO |
| `HwSim` | valeur calculée par le banc |
| `HwIn` | valeur réellement utilisée par le programme |

Cette lecture est un diagnostic humain : elle ne produit aucun verdict automatique, défaut,
compteur ni action. Pour les blocages fonctionnels, consulter `Troubleshooting` (lecture
seule).

## 6. 🧹 Historique et garde-fous

Ont été retirés : `GVL_PLC_Tests`, `FB_Sim_DigitalMirror`, les 25 flags `*IsReal` et les
injections dispersées. Motif : des expressions du type `DI OR (Simulation ... AND ...)` pouvaient
forcer un capteur sain et masquer une polarité erronée (REX C1).

Les gates Python interdisent désormais :

- toute dépendance exécutable à `GVL_Simulation` hors `SIMULATION`, acquisition ST actuelle,
  `Supervision` et `Troubleshooting` ;
- toute forme `OR (GVL_Simulation.<flag> AND ...)`, sans exception.

## 7. 📥 Application CODESYS 3.5

1. Importer le bundle unique `CODE_XML/CODE_Bundle.xml` dans `Application` via
   **Project → Import PLCopenXML**.
2. En vue instance, ouvrir `PRG_02_Acquisition` et comparer `HwReal`, `HwSim`, `HwIn`.
3. Machine arrêtée : activer le bit maître ; les quatre domaines sont activés automatiquement.
   Contrôler que chaque `HwIn.<Domaine>` bascule entièrement sur son image simulée.
4. Pour tester un domaine réel, désactiver explicitement son flag pendant la session.
5. Avant retour réel : désactiver `SimulationModeActive`; le front descendant remet tous les
   flags et stimuli au nominal. Vérifier les bypass RETAIN et l'absence de défaut actif.

📌 Suivi organisationnel : `DOC/WFLOW/PLAN_TASK.md`.
