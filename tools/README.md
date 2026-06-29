# Outils extract / inject / clean — Device.export CODESYS

Trois scripts Python (stdlib uniquement, aucune dépendance) :
- **extract** : exporte chaque FB/PRG de Device.export vers CODE/
- **inject** : réinjecte les FB/PRG modifiés dans Device.export
- **clean** : archive CODE/ + Device.export, prépare slate clean pour réexport CODESYS

Wrapper `.bat` à la racine pour lancement facile : `extract.bat`, `inject.bat`, `clean.bat`

## Arborescence

```
PROJ_Full_ImportExport/Device.export      ← source de vérité (réexport CODESYS)
CODE/                                      ← fragments POUs (extract/inject)
  ├── FB_Filter_PT1__<GUID>.xml
  ├── PRG_JOY1__<GUID>.xml
  └── _archive_plcopen/                   (anciens fichiers)

tools/
  ├── extract.py          ← extrait POUs → CODE/
  ├── inject.py           ← réinjecte POUs modifiés de CODE/ → Device.export
  ├── clean.py            ← archive CODE/ + Device.export, slate clean
  ├── codesys_common.py   ← fonctions partagées
  └── README.md           ← ce fichier

ARCHIVES/                  ← historique des cycles
  ├── 20260630_011535/
  │   ├── CODE/            (snapshots anciens)
  │   └── Device.export.backup
  └── 20260701_120000/ …
```

## Workflow Édition (cycle unique)

1. **Exporter** depuis CODESYS → `PROJ_Full_ImportExport/Device.export`.

2. **Extraire** vers CODE/ :
   ```
   extract.bat --yes
   # ou : python tools/extract.py --yes
   ```
   Remplit `CODE/` avec un `.xml` par POU (`<Nom>__<GUID>.xml`).

3. **Modifier** : éditer directement les fichiers `.xml` dans `CODE/` (VS Code).
   - Section `<interface>` : déclaration VAR_INPUT, VAR_OUTPUT, VAR
   - Section `<implementation>` : corps ST ou graphique

4. **Réinjecter** dans Device.export :
   ```
   inject.bat
   # ou : python tools/inject.py
   ```
   - Détecte auto les blocs modifiés (ignore inchangés)
   - Confirmation `[o/N]` par bloc (ou `[t]out` pour tout accepter)
   - Met à jour Device.export + backup `.bak` horodaté
   - Valide XML complet avant écriture

5. **Réimporter** `Device.export` dans CODESYS.

## Cycle Complet (Restart / Nouveau Cycle CODESYS)

Quand tu termines une session (avant nouveau cycle d'export CODESYS) :

```
clean.bat
# ou : python tools/clean.py
```

Cela :
- Archive tout CODE/ → `ARCHIVES/<YYYYMMDD_HHMMSS>/CODE/`
- Archive Device.export → `ARCHIVES/<YYYYMMDD_HHMMSS>/Device.export.backup`
- Vide CODE/ (nouvelle extraction propre)
- Vide Device.export (prêt pour réexport CODESYS)
- Conserve le fichier Device.export vide (même nom/chemin)

Tu peux alors exporter depuis CODESYS sans collision.

## Garanties

- **Identité par GUID** : un POU n'est modifié que si son GUID existe et est unique
  dans Device.export. Le nom seul n'est jamais utilisé.
- **Round-trip exact** : extraire + réinjecter sans modif → fichier octet-pour-octet
  identique (MD5 préservé).
- **Backup automatique** : inject crée `Device.export.YYYYMMDD_HHMMSS.bak` avant chaque
  écriture. Clean les archive dans ARCHIVES/.
- **Validation XML** : Device.export revalidé complet avant écriture (rollback + restauration
  du `.bak` si erreur).
- **POUs Ladder/FBD** (PROGRAMME_IP, PRG_COD1, PRG_JOY1) : seule la déclaration VAR
  est éditable ; modification du corps graphique (NetworkList) déclenche avertissement.

## Options

| Commande | Effet |
|---|---|
| `extract.bat` | interactif (demande pour fichiers existants différents) |
| `extract.bat --yes` | écrase tout sans demander |
| `inject.bat` | interactif (demande `[o/N]` par bloc modifié) |
| `inject.bat --yes` | réinjecte tout sans demander |
| `clean.bat` | demande confirmation avant archivage |
| `clean.bat --dry-run` | affiche ce qui serait archivé (sans rien faire) |
| `python tools/extract.py --source X --out Y` | chemins personnalisés |
| `python tools/inject.py --source X --target Y` | chemins personnalisés |

## Sécurités (refus volontaires)

- Fragment XML mal formé → refusé (ne rentre pas en Device.export)
- GUID absent de Device.export → refusé
- GUID non unique → refusé
- LineInfoPersistence incohérent → avertissement (non bloquant)
- Fichier verrouillé (ouvert dans VS Code) → report (noté VERROUILLE)

## Workflow Typique Complet

```bash
# Jour 1 : Exporter et modifier
export                 # CODESYS → Device.export
extract.bat --yes      # Device.export → CODE/
# Éditer CODE/*.xml dans VS Code
inject.bat             # CODE/ → Device.export
# Réimporter dans CODESYS

# Jour N : Nouveau cycle, avant réexport CODESYS
clean.bat              # Archive CODE/ + Device.export → ARCHIVES/<timestamp>/
# Puis : export de CODESYS (Device.export vide, prêt)
extract.bat --yes
# etc.
```

L'historique complet reste dans ARCHIVES/.
