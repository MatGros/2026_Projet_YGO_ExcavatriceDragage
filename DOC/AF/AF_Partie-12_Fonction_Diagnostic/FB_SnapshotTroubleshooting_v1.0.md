# Fiche FB_SnapshotTroubleshooting v1.0

> Export CSV de l'état machine (`GVL_Troubleshooting`) sur front d'un bit — aide au dépannage / mise en service.
> Profil AF03 : brique technique (non-mouvement, **lecture seule** + écriture fichier).
> Source : `CODE/DIAG/FB_SnapshotTroubleshooting.st` · instance : `PRG_07_Supervision.instSnapshotTroubleshooting`.

## 🎯 Rôle

Sur **front montant** d'un bit de déclenchement, écrit les **valeurs courantes** des structures utiles
du `GVL_Troubleshooting` dans un **fichier CSV** sur le filesystem de la cible. Permet de **figer un état
machine** pour analyse hors-ligne (dépannage, mise en service), en sim comme sur le réel.

## 🧪 Points de validation

| ID | Attendu | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P12-210</code></nobr> | Front trigger → fichier CSV créé | `Done=TRUE`, fichier présent | `SITE+AUTO` | <small>§Comportement</small> |
| <nobr><code>TC-P12-220</code></nobr> | Valeurs du CSV = état courant de la machine | Ouvrir le CSV, comparer au Watch | `SITE` | <small>§Comportement</small> |
| <nobr><code>TC-P12-230</code></nobr> | Anti-rebond (temps min entre 2 snapshots) | Trigger répété → 1 seul CSV / délai | `AUTO` | <small>§Comportement</small> |
| <nobr><code>TC-P12-240</code></nobr> | Erreur écriture/chemin → `ErrorId` + handle fermé | `Error=TRUE`, bit ErrorId, pas de fuite handle | `AUTO` | <small>§ErrorId</small> |

## 📥 Entrées

| Port | Type | Producteur | Rôle |
|---|---|---|---|
| `Enable` | BOOL | `PRG_07` (TRUE fixe) | Active le FB |
| `Trigger` | BOOL | `GVL_IHM.<Domaine>.Cmd.TglSnapshotTroubleshooting` | Front montant = déclenche un snapshot |
| `CfgFileName` | STRING | constante de défaut (`Snapshot_Troubleshooting`) | Nom de base du fichier |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `Ready` / `Busy` / `Done` | BOOL | Conformité standard |
| `Error` / `ErrorId` | BOOL / WORD | IHM Diagnostic |
| `LastFile` | STRING | IHM Diagnostic (chemin du dernier CSV) |

## ⚙️ Comportement — machine d'état multi-scan

> ⚠️ **Écriture hors MainTask** : le FB s'exécute dans une **tâche 100 ms** (visu/trend), pas MainTask 10 ms → pas de jitter sur le contrôle.

```
IDLE ── front Trigger (anti-rebond 1 s) ──► OPEN (FileOpen "\PLC\<Nom>_<HHMMSS>.csv")
OPEN ── FileOpen OK ──► WRITE (1 chunk/scan : en-tête puis valeurs)
WRITE ── chunks terminés ──► CLOSE (FileClose)
CLOSE ── FileClose OK ──► DONE (1 scan) ──► IDLE
  └─ erreur (open/write/close) ──► ERROR (ErrorId + close si open) ──► IDLE
```

- **1 chunk par scan** (1 valeur = 1 `FileWrite`) → pas de gros buffer STRING ni de blocage.
- `\PLC\` = chemin **virtuel** résolu par `CAA File` sur chaque cible.

## 📚 Bibliothèque

**`CAA File`** (`FILE.Open` / `FILE.Read` / `FILE.Write` / `FILE.Close`) — **portable Win + Linux**, fourni avec le runtime, **sans licence**.
🚫 **Pas `SysFile`** (bas-niveau, chemins spécifiques, régressions embedded).
🚫 **Pas `CSV Utility`** (IIoT Libraries SL, à importer + licence) — retenu pour sa portabilité garantie, au prix de gérer le format CSV soi-même.
Test de présence : compilation conditionnelle (placeholders / type d'appareil) ; sinon tester si `Open` réussit au runtime.

## 🗄️ Encodage CSV (figé)

- Séparateur de colonnes : `;` · Décimale : `.` · Retour ligne : `CRLF`.
- ⚠️ Ouvrir via Import/Data (Excel FR) si besoin de `;`/`,`.

## ❌ ErrorId (bitfield)

| Bit | Cause |
|---|---|
| 0 | Échec ouverture fichier (chemin invalide / disque plein) |
| 1 | Échec écriture (disque plein) — handle fermé |

> Chaque chemin d'erreur **ferme le handle** (pas de fuite). Nom de fichier **unique** (`HHMMSS` + ms ou test d'existence) pour éviter la collision.

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

- `AF_Partie-12_Fonction_Diagnostic_v1.0.md` (chapô) · `AF_Partie-14_Fonction_Troubleshooting_v1.2.md` (source `GVL_Troubleshooting` via `FB_TroubleshootingView`) · `AF_Partie-03` (profil brique technique)
- Bibliothèque : `CAA File` (CODESYS).
