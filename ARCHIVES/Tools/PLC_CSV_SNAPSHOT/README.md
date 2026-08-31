# PLC_CSV_SNAPSHOT — lecture live variables CODESYS pour dépannage

> 🎯 Objectif : lire en live des variables du programme (HW réel ou simulation) et produire un
> CSV pour un agent de dépannage.
>
> Remplace l'ancien `FB_SnapshotTroubleshooting` (export CSV côté PLC, FB supprimé — voir
> `ARCHIVES/Doc/AF_Partie-12_Fonction_Diagnostic/FB_SnapshotTroubleshooting_v1.0.md`) : ces
> scripts lisent en direct depuis l'extérieur, sans avoir besoin de déclencher un snapshot PLC.
>
> 🗄️ **Encodage CSV** (figé) : séparateur `;` · décimale `.` · fin de ligne `CRLF`.

## 📁 Organisation

```
PLC_CSV_SNAPSHOT/
├── codesys_console/        scripts a executer DANS la console de scripting CODESYS
│                           (Tools > Scripting > execfile(...)) — mode Simulation interne
│   ├── config.json         configuration des Script Commands CODESYS (bouton toolbar / Ctrl+W)
│   └── codesys_snapshot_*.py
├── external_python/        scripts a executer dans un terminal classique (python ...)
│                           — mode Control Win / automate reel, via OPC UA
├── _poc/                   fichiers ayant servi a batir le POC, gardes pour reference
│                           (pas a relancer tels quels en usage courant)
├── variable_lists/         generate_variable_list.py (utilitaire python standard) +
│                           export Symbol Configuration source (.xml) +
│                           troubleshooting_variables.txt / ihm_variables.txt (listes generees,
│                           input des scripts codesys_console)
└── RESULTS/                 CSV produits (sortie)
    ├── snapshot/            un instant T, sur declenchement manuel
    └── acquisition/         serie periodique (plusieurs instants dans un seul CSV)
```

⚠️ Les CSV de `RESULTS/snapshot/` et `RESULTS/acquisition/` sont **trackés en Git** (historisation) —
sans tri, ils s'accumulent indéfiniment. À la clôture d'une fiche de troubleshooting, la skill
`troubleshooting` (étape 8) déplace les CSV produits pendant la session vers
`ARCHIVES/Tools/PLC_CSV_SNAPSHOT/RESULTS/<Sujet>_<date>/` (miroir racine, voir `ARCHIVES/Tools/`).

## ⚠️ Deux modes distincts — diagnostiqué le 2026-08-16 sur ce projet

| Mode | Comment le reconnaître | Où lancer les scripts |
|---|---|---|
| **A — Simulation interne à l'IDE** (mode actif actuellement) | Icône "Simulation" enfoncée dans la barre d'outils CODESYS. Aucun port réseau ouvert (ni 4840 OPC UA, ni 502 Modbus). | `codesys_console/` — coller/`execfile()` dans **Tools → Scripting**, projet en ligne (Login fait). Aucune installation, pas de pip. |
| **B — Runtime externe (Control Win ou automate réel)** | Service Windows `CODESYS Control Win V3` démarré, ou automate physique en réseau. Port 4840 (OPC UA) ouvert. | `external_python/` — `python script.py` depuis un terminal classique, aucune interaction avec l'IDE. Nécessite `pip install -r external_python/requirements.txt`. |

👉 Le nom de fichier indique le mode : préfixe `codesys_` = **doit** s'exécuter dans la console
CODESYS (mode A), jamais en `python script.py` classique — les objets globaux qu'il utilise
(`projects`, `online`, `system`) n'existent que dans ce contexte.

⚠️ Le mode B a été testé une fois avec succès côté réseau (port OPC UA ouvert), mais bloqué sur
un refus d'accès anonyme (`BadUserAccessDenied`, réglage "Allow anonymous login" côté Device
à activer) — mis de côté pour l'instant, à reprendre **sur place avec le matériel réel** plutôt
qu'en poursuivant sur la simulation.

## ✅ Mode A — scripts `codesys_console/`

Rien à installer. Projet ouvert, **Login fait** (Online), puis **Tools → Scripting**, coller :

```python
execfile(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_snapshot_all.py")
```

| Script | Usage |
|---|---|
| `codesys_snapshot_troubleshooting.py` | Snapshot CSV `GVL_Troubleshooting` seul, à l'instant T → `RESULTS/snapshot/` |
| `codesys_snapshot_all.py` | **Script principal** — snapshot `GVL_Troubleshooting` + `GVL_IHM` en une seule exécution, un seul login → `RESULTS/snapshot/` |
| `codesys_delayed_snapshot_troubleshooting.py` | Attend 5 s puis lance le snapshot Troubleshooting (le temps de se mettre en situation dans la simu) |
| `codesys_acquisition_periodique_troubleshooting.py` | Acquisition 10 s / 1 lecture-s en un seul CSV large (une colonne par instant) → `RESULTS/acquisition/` — ⚠️ **bloque l'IDE** pendant la durée (le threading en arrière-plan a échoué avec une erreur `Pile vide`, non fiable en mode A, cf. `_poc/acquisition_periodique_background_ABANDONNE.py`) |

Référence API utilisée (stubs installés avec l'IDE, lues pour ce projet — pas devinées) :
`C:\Program Files\CODESYS 3.5.19.10\CODESYS\ScriptLib\Stubs\scriptengine\ScriptOnline.pyi`

### 🖱️ Confort — bouton de barre d'outils & raccourci clavier direct

- **Fichier de configuration source** : [`TOOLS/PLC_CSV_SNAPSHOT/codesys_console/config.json`](codesys_console/config.json).
- **Déploiement / Mise à jour dans CODESYS** :
  Copier simplement ce fichier `config.json` vers le dossier Script Commands de CODESYS :
  - Soit `C:\Program Files\CODESYS 3.5.19.10\CODESYS\Script Commands\config.json` (système, demande confirmation admin)
  - Soit `%LocalAppData%\CODESYS\Script Commands\config.json` (utilisateur, sans droits admin)
- **Raccourci clavier** : `Ctrl + W` configuré pour déclencher immédiatement `codesys_snapshot_troubleshooting.py` (export instantané de `GVL_Troubleshooting` vers `RESULTS/snapshot/`).
- **Guide complet de configuration IDE** : voir [`DOC/STDS/GUIDES/GUIDE_CONFIGURATION_IDE_CODESYS_v1.0.md §6`](../../DOC/STDS/GUIDES/GUIDE_CONFIGURATION_IDE_CODESYS_v1.0.md).

## 🅱️ Mode B — scripts `external_python/`, pour plus tard (test sur site avec HW réel)

### Prérequis manuels CODESYS IDE

1. **Device → OPC UA Server** : "Enabled".
2. **Device → Communication Settings → Change Runtime Security Policy** : cocher "Allow
   anonymous login" (sinon `BadUserAccessDenied` au moment de la connexion Python).
3. **Application → Symbol Configuration** : cocher la/les variables à exposer.
4. Build + Login (Control Win ou réel) pour publier les symboles.
5. Endpoint : sim Control Win = `opc.tcp://localhost:4840`, réel = `opc.tcp://<IP_PLC>:4840`.

### Installation

```powershell
pip install -r TOOLS/PLC_CSV_SNAPSHOT/external_python/requirements.txt
```

### Étape 1 — trouver le NodeId exact de la variable

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/list_nodes.py opc.tcp://localhost:4840 --filter MaVariable
```

### Étape 2 — lecture d'une variable BOOL

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/read_bool.py opc.tcp://localhost:4840 "ns=4;s=|var|Application.GVL_Test.MaVariable"
```

`--watch` pour relire en boucle (1 s par défaut) — c'est la voie qui permettra une acquisition
non-bloquante et interactive, contrairement au mode A.

## 🔁 Régénérer les listes de variables

Si la structure de `GVL_Troubleshooting` ou `GVL_IHM` change dans le projet (nouveau champ,
nouvelle chaîne de diagnostic) : réexporter la Symbol Configuration depuis l'IDE, puis :

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/variable_lists/generate_variable_list.py "<export>.xml" --root "Application.GVL_Troubleshooting" --output "TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt"
python TOOLS/PLC_CSV_SNAPSHOT/variable_lists/generate_variable_list.py "<export>.xml" --root "Application.GVL_IHM" --output "TOOLS/PLC_CSV_SNAPSHOT/variable_lists/ihm_variables.txt"
```

## 🚧 Statut

Mode A fonctionnel et validé (snapshot 974 variables en ~2,2 s). Mode B parké en attente de
test sur site avec le matériel réel.
