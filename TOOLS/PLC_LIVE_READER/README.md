# PLC_LIVE_READER — lecture live variables CODESYS pour dépannage

> 🎯 Objectif : lire en live des variables du programme (HW réel ou simulation) et produire un
> CSV pour un agent de dépannage.
>
> Complémentaire à `FB_SnapshotTroubleshooting` (export CSV côté PLC, déclenché par bit IHM,
> voir `DOC/AF/AF_Partie-12_Fonction_Diagnostic/FB_SnapshotTroubleshooting_v1.0.md`) : ces
> scripts lisent en direct depuis l'extérieur, sans avoir besoin de déclencher un snapshot PLC.

## 📁 Organisation

```
PLC_LIVE_READER/
├── codesys_console/        scripts a executer DANS la console de scripting CODESYS
│                           (Tools > Scripting > execfile(...)) — mode Simulation interne
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
execfile(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\codesys_console\codesys_snapshot_all.py")
```

| Script | Usage |
|---|---|
| `codesys_snapshot_troubleshooting.py` | Snapshot CSV `GVL_Troubleshooting` seul, à l'instant T → `RESULTS/snapshot/` |
| `codesys_snapshot_all.py` | **Script principal** — snapshot `GVL_Troubleshooting` + `GVL_IHM` en une seule exécution, un seul login → `RESULTS/snapshot/` |
| `codesys_delayed_snapshot_troubleshooting.py` | Attend 5 s puis lance le snapshot Troubleshooting (le temps de se mettre en situation dans la simu) |
| `codesys_acquisition_periodique_troubleshooting.py` | Acquisition 10 s / 1 lecture-s en un seul CSV large (une colonne par instant) → `RESULTS/acquisition/` — ⚠️ **bloque l'IDE** pendant la durée (le threading en arrière-plan a échoué avec une erreur `Pile vide`, non fiable en mode A, cf. `_poc/acquisition_periodique_background_ABANDONNE.py`) |

Référence API utilisée (stubs installés avec l'IDE, lues pour ce projet — pas devinées) :
`C:\Program Files\CODESYS 3.5.19.10\CODESYS\ScriptLib\Stubs\scriptengine\ScriptOnline.pyi`

### 🖱️ Confort — bouton de barre d'outils au lieu de `execfile()` manuel

CODESYS permet d'ajouter un bouton personnalisé qui lance un script Python directement,
sans repasser par la console de scripting à chaque fois.

**Emplacement** : `C:\Program Files\CODESYS 3.5.19.10\CODESYS\Script Commands\`
(alternative sans droits admin : `%LocalAppData%\CODESYS\Script Commands\`)

**Fichiers requis dans ce dossier** :
- `config.json` — décrit les boutons (max 16 par emplacement)
- `<nom>.ico` — icône 16x16 par bouton
- le script `.py` cible (chemin absolu ou relatif au dossier)

**Format `config.json`** (un objet par bouton) :
```json
[
    {
        "Name": "Snapshot Troubleshooting",
        "Desc": "Lance codesys_snapshot_troubleshooting.py",
        "Icon": "snapshot_troubleshooting.ico",
        "Path": "C:\\_MGS\\DEV\\2026_Projet_YGO_ExcavatriceDragage\\TOOLS\\PLC_LIVE_READER\\codesys_console\\codesys_snapshot_troubleshooting.py"
    }
]
```

**Procédure côté IDE** :
1. Relancer CODESYS après avoir écrit `config.json`.
2. **Outils → Personnaliser → Icônes de commande** → catégorie *Commandes du moteur de script*.
3. Onglet **Barres d'outils** → sélectionner/créer une barre → glisser la commande dessus.
4. Fermer la boîte de dialogue → cliquer l'icône → sortie visible dans la vue **Messages**.

⚠️ Écrire dans `Program Files` nécessite les droits admin (UAC) — préférer l'alternative
`%LocalAppData%\CODESYS\Script Commands\` si pas de droits admin.

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
pip install -r TOOLS/PLC_LIVE_READER/external_python/requirements.txt
```

### Étape 1 — trouver le NodeId exact de la variable

```powershell
python TOOLS/PLC_LIVE_READER/external_python/list_nodes.py opc.tcp://localhost:4840 --filter MaVariable
```

### Étape 2 — lecture d'une variable BOOL

```powershell
python TOOLS/PLC_LIVE_READER/external_python/read_bool.py opc.tcp://localhost:4840 "ns=4;s=|var|Application.GVL_Test.MaVariable"
```

`--watch` pour relire en boucle (1 s par défaut) — c'est la voie qui permettra une acquisition
non-bloquante et interactive, contrairement au mode A.

## 🔁 Régénérer les listes de variables

Si la structure de `GVL_Troubleshooting` ou `GVL_IHM` change dans le projet (nouveau champ,
nouvelle chaîne de diagnostic) : réexporter la Symbol Configuration depuis l'IDE, puis :

```powershell
python TOOLS/PLC_LIVE_READER/variable_lists/generate_variable_list.py "<export>.xml" --root "Application.GVL_Troubleshooting" --output "TOOLS/PLC_LIVE_READER/variable_lists/troubleshooting_variables.txt"
python TOOLS/PLC_LIVE_READER/variable_lists/generate_variable_list.py "<export>.xml" --root "Application.GVL_IHM" --output "TOOLS/PLC_LIVE_READER/variable_lists/ihm_variables.txt"
```

## 🚧 Statut

Mode A fonctionnel et validé (snapshot 974 variables en ~2,2 s). Mode B parké en attente de
test sur site avec le matériel réel.
