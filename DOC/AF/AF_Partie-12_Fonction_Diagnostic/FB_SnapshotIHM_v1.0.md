# Fiche FB_SnapshotIHM v1.0

> Export CSV de l'échange IHM ↔ PLC (`GVL_IHM`) sur front d'un bit — aide au dépannage / mise en service.
> Profil AF03 : brique technique (non-mouvement, **lecture seule** + écriture fichier).
> Source : `CODE/DIAG/FB_SnapshotIHM.st` · instance : `PRG_07_Supervision.instSnapshotIHM`.

## 🎯 Rôle

Sur **front montant** d'un bit de déclenchement, écrit un **sous-ensemble des variables de `GVL_IHM`**
dans un **fichier CSV**. `GVL_IHM` porte l'échange **bidirectionnel** PLC ↔ IHM :
- **IHM → PLC** : commandes (`Btn*`, `Sel*`, `Set*`, `Tgl*`) — ce qu'on actionne sur l'écran.
- **PLC → IHM** : états, mesures, diagnostics (`Ready`, `Busy`, `State`, `Error`, positions…).

→ Permet de voir **ce qui est actionné côté IHM ET ce qu'on envoie à l'IHM**, quand l'IHM est raccordée.

## 🧪 Points de validation

| ID | Attendu | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P12-310</code></nobr> | Front trigger → fichier CSV créé | `Done=TRUE`, fichier présent | `SITE+AUTO` | <small>§Comportement</small> |
| <nobr><code>TC-P12-320</code></nobr> | CSV contient commandes IHM + états PLC | Ouvrir le CSV, comparer au Watch | `SITE` | <small>§Comportement</small> |
| <nobr><code>TC-P12-330</code></nobr> | Anti-rebond (temps min entre 2 snapshots) | Trigger répété → 1 seul CSV / délai | `AUTO` | <small>§Comportement</small> |
| <nobr><code>TC-P12-340</code></nobr> | Erreur écriture/chemin → `ErrorId` + handle fermé | `Error=TRUE`, bit ErrorId, pas de fuite handle | `AUTO` | <small>§ErrorId</small> |

## 📥 Entrées

| Port | Type | Producteur | Rôle |
|---|---|---|---|
| `Enable` | BOOL | `PRG_07` (TRUE fixe) | Active le FB |
| `Trigger` | BOOL | `GVL_IHM.<Domaine>.Cmd.TglSnapshotIHM` | Front montant = déclenche un snapshot |
| `CfgFileName` | STRING | constante de défaut (`Snapshot_IHM`) | Nom de base du fichier |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `Ready` / `Busy` / `Done` | BOOL | Conformité standard |
| `Error` / `ErrorId` | BOOL / WORD | IHM Diagnostic |
| `LastFile` | STRING | IHM Diagnostic (chemin du dernier CSV) |

## ⚙️ Comportement — machine d'état multi-scan

> ⚠️ **Écriture hors MainTask** : le FB s'exécute dans une **tâche 100 ms** (visu/trend), pas MainTask 10 ms.

```
IDLE ── front Trigger (anti-rebond 1 s) ──► OPEN (FileOpen "\PLC\<Nom>_<HHMMSS>.csv")
OPEN ── FileOpen OK ──► WRITE (1 chunk/scan : en-tête puis valeurs)
WRITE ── chunks terminés ──► CLOSE (FileClose)
CLOSE ── FileClose OK ──► DONE (1 scan) ──► IDLE
  └─ erreur ──► ERROR (ErrorId + close si open) ──► IDLE
```

- **1 chunk par scan** (1 valeur = 1 `FileWrite`) → pas de gros buffer STRING ni de blocage.
- `\PLC\` = chemin **virtuel** résolu par `CAA File`.

## 📚 Bibliothèque

**`CAA File`** (`FILE.Open` / `FILE.Read` / `FILE.Write` / `FILE.Close`) — **portable Win + Linux**, fourni avec le runtime, **sans licence**.
🚫 **Pas `SysFile`** (bas-niveau, chemins spécifiques, régressions embedded).
🚫 **Pas `CSV Utility`** (IIoT Libraries SL, à importer + licence) — retenu pour sa portabilité garantie, au prix de gérer le format CSV soi-même.
Test de présence : compilation conditionnelle ; sinon tester si `Open` réussit au runtime.

## 🗄️ Encodage CSV (figé)

- Séparateur : `;` · Décimale : `.` · Retour ligne : `CRLF`.
- ⚠️ Ouvrir via Import/Data si besoin.

## 🎯 Périmètre GVL_IHM (sous-ensemble)

> ⚠️ **Pas « tout » écrit à la main** (volume ~300-500 champs → dérive). **Sous-ensemble + table générée depuis les DUT.**

- **Inclure** : commandes (`Cmd`), états (`State`), `ErrorId`, mesures clés — l'échange actionné/envoyé.
- **Exclure** : `Cfg` (statiques), `Safety`, `Bypass` (majoritairement statiques), sauf besoin spécifique.
- **Table de colonnes générée depuis les DUT** via `TOOLS/ST_PLCOPENXML_GENERATOR` (anti-dérive : tout nouveau champ IHM est ajouté automatiquement).

## ❌ ErrorId (bitfield)

| Bit | Cause |
|---|---|
| 0 | Échec ouverture fichier (chemin invalide / disque plein) |
| 1 | Échec écriture (disque plein) — handle fermé |

> Chaque chemin d'erreur **ferme le handle**. Nom de fichier **unique** (`HHMMSS` + ms ou test d'existence).

## ⚠️ Dépendance cible — chemin selon la cible

> `\PLC\` est une **convention logique/IEC**, pas un chemin disque universel. Il faut un **chemin physique selon la cible** (basculement automatique).

| Cible | Chemin physique réel |
|---|---|
| Control Win (sim) | `C:\ProgramData\CODESYS\CODESYSControlWinV3x64\...\PlcLogic` |
| Embedded Linux (réel) | `/var/opt/codesys/PlcLogic` |

- **Stratégie** : chemin sélectionné par **compilation conditionnelle** (placeholders / type d'appareil) ou **paramètre PERSISTENT** réglable par cible.
- **Récupération** : File Transfer IDE (Control Win) · FTP/SMB (embedded).
- **À verrouiller sur la cible de mise en service** avant usage.

## 📄 Docs liées

- `AF_Partie-12_Fonction_Diagnostic_v1.0.md` (chapô) · `AF_Partie-07_Interface_IHM_v2.0.md` · `AF_Partie-14_Fonction_Troubleshooting_v1.2.md` · `AF_Partie-03` (profil brique technique)
- Bibliothèque : `CAA File` (CODESYS).
