# 🧪 Analyse Fonctionnelle — Partie 13 : Simulation (v2.0)

> **Projet** : Excavatrice de dragage — CODESYS 3.5  
> **Statut** : référence active · 2026-07-27  
> **Sources** : `CODE/SIMULATION/FB_SimBench.st`, `CODE/MAIN/PRG_ACQUISITION_CFC.st` (ST actuel ; cible CFC native `PRG_02_Acquisition_CFC.xml` absente, rang 02 de la `MainTask` — voir `DOC/AF_Partie-02_Architecture_Programme_v3.0.md` §2),
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

```text
[%IX / PDO réels] ──► HwReal ─┐
                              ├──► HwIn ──► conditionnement + logique métier
[FB_SimBench]     ──► HwSim  ─┘
```

`PRG_ACQUISITION_CFC.st` est la frontière ST actuelle ; `PRG_02_Acquisition_CFC.xml` est sa cible CFC native, absente de `CODE/MAIN`. ⚠️ Dans la cible, cette page absorbe aussi les codeurs, les diagnostics devices/bus et les retours auxiliaires : la frontière réel/simulé ci-dessous **reste unique et inchangée** et couvre alors l'ensemble de ces entrées :

1. §0 acquiert chaque E/S brute dans `HwReal : ST_HardwareImage`.
2. `instSimBench` construit les quatre sous-images simulées.
3. `HwSim : ST_HardwareImage` les expose pour observation, sans alimenter la logique métier.
4. Les quatre `IF` de §0bis sélectionnent une structure complète dans `HwIn`.
5. §1 conditionne uniquement `HwIn` via `FB_Input`.

`HwIn` est la seule image consommée par le programme métier. Aucun FB métier ne lit
`GVL_Simulation` ni `HwSim`.

## 3. 🎛️ Commande de simulation

`GVL_Simulation` est lu uniquement par l'acquisition ST actuelle, le banc et les publications/diagnostics
autorisés. Polarité positive : `TRUE = simulation active`; tous les flags sont `FALSE` au démarrage.

| Signal | Domaine simulé |
|---|---|
| `SimulationModeActive` | 🔑 bit maître : aucune simulation sans lui |
| `SimWinchActive` | M1/M2 : codeurs, contacteurs, freins, thermiques, haut, câble |
| `SimTranslationActive` | AC600 M3, fréquence et cinq positions |
| `SimOperatorActive` | joystick CANopen et signaux bruts |
| `SimMachineActive` | chaîne AU, contacteur, réarmement, phases, Kobold, hydrauliques |

Le sélecteur est atomique par domaine : `HwIn.<Domaine> := HwSim.<Domaine>` ou
`HwReal.<Domaine>`. Il interdit tout mélange réel/simulé dans un même domaine.

## 4. 🧩 Modèle de banc

`FB_SimBench` est une brique réduite : ses entrées explicites reçoivent les commandes du scan
précédent, les stimuli et `HwReal`; il ne lit aucune GVL. Il compose :

| Bloc | Rôle | Convention critique |
|---|---|---|
| `FB_Sim_Encoder` ×2 | position COD1/COD2, presets et écart de synchro | les positions suivent les commandes treuil |
| `FB_Sim_Translation` | trajet, positions M3 et état AC600 | mot de cinq capteurs cohérent ou stimulus explicite |
| `FB_Sim_Joystick` | valeurs Hall et homme-mort simulables | neutre = 5000 ; le contrôle homme-mort reste actif |
| `FB_Sim_Safety` | chaîne AU, contacteur et réarmement | commande maintenue `PowerKeepAlive_A/B` |

### 🔒 Polarités

- `Mx_BrakeIsOpen_DI := Mx_BrakeCmd` : `TRUE` signifie **frein ouvert**. Aucun `NOT`.
- Retour contacteurs M1/M2 : `TRUE` seulement quand sens **et** paliers sont tous retombés.
- `PowerKeepAlive_A/B_RQ = TRUE` maintient la puissance; `FALSE` provoque la coupure fail-safe.

Le REX C1 : un retour de frein simulé inversé, ajouté à une logique aval elle-même erronée,
compensait les deux erreurs et masquait le défaut réel. La polarité est donc définie au modèle et
normalisée une seule fois par le conditionnement.

## 5. 🔍 Observation et diagnostic

En vue instance de l'acquisition ST actuelle, lire côte à côte les trois `ST_HardwareImage` homologues :

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

1. Importer le bundle unique `CODE/CODE_Bundle.xml` dans `Application` via
   **Project → Import PLCopenXML**.
2. En vue instance, ouvrir `PRG_ACQUISITION_CFC` (ST actuel) et comparer `HwReal`, `HwSim`, `HwIn`.
3. Machine arrêtée : activer le bit maître puis un seul domaine; contrôler que `HwIn` bascule
   entièrement sur l'image attendue.
4. Avant retour réel : désactiver les quatre domaines, puis `SimulationModeActive`; vérifier les
   bypass RETAIN et l'absence de défaut actif.

📌 Suivi organisationnel : `DOC/PLAN_TASK_v1.0.md`.
