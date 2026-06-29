# Outils extract / inject — Device.export CODESYS

Deux scripts Python (stdlib uniquement, aucune dépendance) pour éditer les
Function Blocks et Programmes hors de CODESYS, puis les réinjecter.

## Arborescence

```
PROJ_Full_ImportExport/Device.export      <- export depuis CODESYS (source de vérité)
tools/extract.py       <- extrait chaque POU en .xml individuel
tools/inject.py        <- réinjecte les POU modifiés par GUID
tools/codesys_common.py<- fonctions partagées
extraction/            <- sortie de extract.py (1 fichier par POU)
import/                <- fragments modifiés à réinjecter (copier depuis extraction/)
```

## Workflow

1. **Exporter** depuis CODESYS → `PROJ_Full_ImportExport/Device.export`.
2. **Extraire** :
   ```
   python tools/extract.py --clean
   ```
   Remplit `extraction/` avec un `.xml` par POU (`<Nom>__<GUID>.xml`).
3. **Modifier** : copier le(s) POU à changer depuis `extraction/` vers `import/`,
   les éditer dans VS Code (déclaration VAR et/ou corps ST).
4. **Réinjecter** :
   ```
   python tools/inject.py
   ```
   Contrôles → confirmation `[o/N]` → met à jour `Device.export` (+ backup `.bak`).
5. **Réimporter** `Device.export` dans CODESYS.

## Garanties

- **Identité par GUID** : un POU n'est modifié que si son GUID existe et est
  unique dans `Device.export`. Le nom seul n'est jamais utilisé.
- **Round-trip exact** : extraire puis réinjecter sans modif laisse le fichier
  **octet-pour-octet identique** (testé via MD5).
- **Backup automatique** horodaté avant chaque écriture (`Device.export.AAAAMMJJ_HHMMSS.bak`).
- **Validation XML** du fichier complet avant écriture (rollback si invalide).
- **POUs Ladder/FBD** (PROGRAMME_IP, PRG_COD1, PRG_JOY1) : seule leur
  déclaration VAR est destinée à l'édition ; toute modif du corps graphique
  (NetworkList) déclenche un avertissement.

## Options

| Commande | Effet |
|---|---|
| `python tools/extract.py --clean` | vide `extraction/` avant d'extraire |
| `python tools/extract.py --source X --out Y` | chemins personnalisés |
| `python tools/inject.py --yes` | sans confirmation interactive |
| `python tools/inject.py --imports X --target Y` | chemins personnalisés |

## Refus volontaires (sécurité)

- Fragment XML mal formé → refusé.
- GUID absent de `Device.export` → refusé.
- GUID en double → refusé.
- `LineInfoPersistence` ne référençant pas le GUID → avertissement.
