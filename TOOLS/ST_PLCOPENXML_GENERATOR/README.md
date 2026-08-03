# ST PLCopenXML Generator

## Rôle

Outil autonome de conversion des sources `CODE/**/*.st` vers PLCopenXML importable dans CODESYS 3.5.

```text
CODE/*.st
   ↓
ST_PLCOPENXML_GENERATOR
   ↓
CODE/CODE_Bundle.xml
   ↓
Import PLCopenXML dans CODESYS
```

Cet outil est indépendant de `TOOLS/AGENT_WORKFLOW/` et peut être exécuté seul.

## Utilisation

Depuis ce dossier :

```powershell
python -m pytest
python -c "from generator.cli import main; import sys; sys.exit(main(['--bundle', 'CODE_Bundle', '--project-name', 'MGS_vX.Y.Z']))"
```

Les chemins par défaut sont calculés depuis l'emplacement de l'outil :

- source : `CODE/`
- sortie : `CODE/`

Pour un autre projet ou un autre emplacement :

```powershell
python -c "from generator.cli import main; import sys; sys.exit(main(['--code-dir', 'C:/Projet/CODE', '--out-dir', 'C:/Projet/CODE', '--bundle', 'CODE_Bundle', '--project-name', 'Projet']))"
```

### Générer uniquement un domaine (`--folder`)

Plutôt que de régénérer `CODE_Bundle.xml` en entier (tout le projet), on peut cibler un
sous-dossier `CODE/<DOMAINE>/` — pratique pour importer/tester un seul lot dans CODESYS.

```powershell
# Lister les domaines disponibles et leur nombre d'objets
python -m generator.cli --list-folders

# Générer un bundle isolé pour un seul domaine (ex. TREUILS)
python -m generator.cli --folder TREUILS --bundle CODE_TREUILS_Bundle --project-name TestTreuils

# Combiner plusieurs domaines dans un même bundle
python -m generator.cli --folder AU --folder TRANSLATION --bundle CODE_AU_TRANSLATION_Bundle

# Combiner un domaine + des objets nommés explicitement
python -m generator.cli --folder AU PRG_09_Supervision --bundle CODE_AU_Plus_Bundle
```

⚠️ `--folder` sélectionne uniquement les objets **déclarés physiquement** dans ce dossier — la
clôture de dépendances (types, FB appelés, etc.) reste automatique via `--no-deps` (désactivé
par défaut). Si le domaine référence des types hors dossier (GVL globales, DUT partagés), ils
sont importés automatiquement dans le bundle.

## Contenu

- `generator/` : code Python du convertisseur
- `tests/` : tests unitaires, intégration et golden
- `samples_reference_codesys/` : exports CODESYS de référence
- `test_import_poc/` : preuve de concept d'import réel
- `docs/PLCOPENXML_FORMAT.md` : documentation technique détaillée

## Validation

```powershell
python -m pytest
```

La compilation finale et l'import restent à confirmer dans CODESYS 3.5.

## Scripts CLI modulaires (`scripts/`)

En plus du générateur monolithique (`generator/cli.py`), des scripts indépendants permettent
de générer de **petits bouts** individuellement. Chaque script réutilise la logique existante
de `generator/` (pas de réécriture) et produit un artefact PLCopenXML focalisé.

| Script | Rôle | Usage |
|---|---|---|
| `scripts/st_to_ld.py` | Convertit un fichier `PRG_*_LD.st` en un `<pou>` en `<LD>` | `python scripts/st_to_ld.py CODE/MAIN/PRG_OUTPUTS_LD.st -o output.xml` |
| `scripts/st_to_pou.py` | Convertit un fichier `.st` (FB ou PROGRAM) en un `<pou>` en `<ST>` | `python scripts/st_to_pou.py CODE/AU/FB_Safety_EmergencyManagement.st -o output.xml` |
| `scripts/cfc_extract.py` | Extrait un `<pou>` CFC d'un XML natif (nettoyage namespaces, alignement ObjectIds) | `python scripts/cfc_extract.py CODE/MAIN/PRG_ACQUISITION_CFC.xml -o output.xml` |
| `scripts/st_to_dut.py` | Convertit un fichier `.st` (STRUCT ou ENUM) en un `<dataType>` | `python scripts/st_to_dut.py CODE/SUPERVISION/ST_Safety_Emergency_HmiState.st -o output.xml` |
| `scripts/build_bundle.py` | Orchestre un bundle `<project>` complet depuis fichiers/dossiers | `python scripts/build_bundle.py CODE/AU/ CODE/MAIN/PRG_OUTPUTS_LD.st -o bundle.xml` |

### Exemples

```powershell
# Générer juste un Ladder depuis un PRG_*_LD
python scripts/st_to_ld.py CODE/MAIN/PRG_OUTPUTS_LD.st -o /tmp/test_ld.xml

# Générer juste un POU ST
python scripts/st_to_pou.py CODE/AU/FB_Safety_EmergencyManagement.st -o /tmp/test_pou.xml

# Extraire juste un CFC natif
python scripts/cfc_extract.py CODE/MAIN/PRG_ACQUISITION_CFC.xml -o /tmp/test_cfc.xml

# Générer un bundle complet depuis un dossier + un fichier
python scripts/build_bundle.py CODE/AU/ CODE/MAIN/PRG_OUTPUTS_LD.st -o /tmp/test_bundle.xml
```

Chaque script dispose de `--help` et gère les erreurs proprement (exit code 1 avec message).
Le script `st_to_ld.py` rejette les fichiers qui ne sont pas des `PRG_*_LD` avec un message clair.
