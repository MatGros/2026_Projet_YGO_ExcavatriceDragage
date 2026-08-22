# 🧹 LINTER_ST

Linter ST CODESYS 3.5 : remonte les **vraies** erreurs de compilation (types non déclarés,
incompatibilités, etc.) en JSON structuré, exploitable par un éditeur (Problems panel) ou un
agent IA. Basé sur [STruCpp](https://github.com/Autonomy-Logic/STruCpp) (compilateur ST → C++17
actif, 2026), vendoré en copie locale.

🔒 **Outil 100% encapsulé** — aucune dépendance d'exécution vers `TOOLS/COMPILER_ST2C_STruCpp/`
ni tout autre dossier de `TOOLS/`. Binaire `strucpp.exe` et moulinette de conversion sont des
copies propres à ce dossier (consigne 2026-08-23 : chaque outil porte sa responsabilité, pas de
lien inter-outils).

🎯 **Priorité absolue : zéro faux positif.** Si une dépendance de type ne peut pas être résolue,
le linter **ne remonte aucune alerte** plutôt que de signaler une fausse erreur — préférence
explicite de l'utilisateur (mieux vaut un silence qu'une fausse alerte).

## 📦 Contenu

| Fichier | Rôle |
|---|---|
| `resolve_deps.py` | Scan `CODE/` une fois, résout récursivement les dépendances (types/FB) d'un `.st` cible |
| `linter_st_convert_codesys_to_iec.py` | Convertit les idiomes CODESYS 3.5 (enum, pragmas, qualificatifs `PUBLIC`, `END_xxx` manquant) vers IEC standard |
| `lint.py` | Orchestrateur : résolution deps → conversion → compilation STruCpp → diagnostics JSON |
| `bin/win32-x64/strucpp.exe` | Compilateur ST→C++17 vendoré (copie, v0.6.2) |

## 🚀 Utilisation

```powershell
python TOOLS/LINTER_ST/lint.py CODE/D_JOYSTICK/FB_Joystick.st
```

Sortie JSON sur stdout :

```json
{
  "status": "clean",
  "target": "CODE/D_JOYSTICK/FB_Joystick.st",
  "diagnostics": [],
  "unresolved_types": []
}
```

**Codes de sortie** :
- `0` = propre, 0 erreur
- `1` = vraies erreurs trouvées (dans `diagnostics`)
- `2` = analyse incomplète — une dépendance de type n'a pas pu être résolue (voir
  `unresolved_types`) ; **aucune fausse alerte n'est émise dans ce cas**
- `3` = erreur d'usage (fichier introuvable, `strucpp.exe` absent, ...)

### Résoudre seulement les dépendances

```powershell
python TOOLS/LINTER_ST/resolve_deps.py CODE/D_JOYSTICK/FB_Joystick.st
```

## ⚠️ Comment le filtre anti-faux-positif fonctionne

`resolve_deps.py` calcule d'abord la liste des types référencés mais absents de l'index `CODE/`
(`unresolved`, avant toute compilation). Seuls **ces noms-là** sont filtrés si STruCpp les
signale ensuite comme `Undefined type`. Un `Undefined type` sur un nom que `resolve_deps.py`
n'avait **pas** identifié comme manquant à l'avance (ex : typo hors des préfixes `ST_`/`E_`/`FB_`
surveillés) est un signal fort de vraie erreur → toujours remonté comme diagnostic réel, jamais
avalé silencieusement. Vérifié empiriquement (session 2026-08-23, typo `INT_INCONNU`).

## 🧪 Validation effectuée (session 2026-08-23)

7 FB réels testés `clean`, 0 faux positif : `FB_Joystick`, `FB_Encoder`, `FB_Modes`,
`FB_Safety_EmergencyManagement`, `FB_Bucket`, `FB_Ramp`, `FB_FbStatus`. Cas négatif contrôlé
(typo dans une copie hors `CODE/`) → erreur remontée avec ligne/colonne exactes.

## 📌 Limites connues

- Pas une preuve FAT/SAT — valide la syntaxe/typage, pas le comportement réel sur automate.
- `resolve_deps.py` ne suit que les préfixes `ST_`, `E_`, `FB_` (convention de nommage du
  projet, voir `DOC/STDS/NAMING_CONVENTION.md`) — un type qui ne suit pas cette convention ne
  serait pas résolu automatiquement.
- Binaire `strucpp.exe` vendoré = version figée. Mise à jour manuelle si besoin (voir
  [releases STruCpp](https://github.com/Autonomy-Logic/STruCpp/releases)).
- ⚠️ **GVL avec `{attribute 'qualified_only'}` (ex: `GVL_IHM`, `GVL_Global`)** : `resolve_deps.py`
  les trouve et les inclut désormais dans la compilation (elles n'ont aucun mot-clé de
  déclaration, indexées par nom de fichier), mais STruCpp lève ensuite `Undeclared variable
  'GVL_XXX'` en cascade sur les PRG qui y accèdent en écriture qualifiée. Cause probable :
  `linter_st_convert_codesys_to_iec.py` supprime `{attribute 'qualified_only'}` comme un pragma
  cosmétique, alors qu'il change la sémantique d'accès (`GVL_IHM.Membre` vs `Membre` nu). **Pas
  encore corrigé** (trouvé session 2026-08-23, sur `PRG_07_Supervision.st`) — un PRG qui lit/écrit
  une GVL qualifiée remonte des faux positifs "Undeclared variable" tant que ce n'est pas réglé.

## 🖥️ Extension VSCode (`vscode-extension/`)

Diagnostics live dans le panneau **Problems** à chaque sauvegarde d'un `.st` — pas de LSP, une
extension simple (`vscode.languages.createDiagnosticCollection`) qui appelle `lint.py` en
sous-processus. Un canal **Output → "Linter ST"** trace les analyses incomplètes (dépendance non
résolue) sans jamais afficher de fausse alerte.

### Tester en mode debug (F5)

```powershell
cd TOOLS/LINTER_ST/vscode-extension
npm install
npm run compile
```

Puis dans VSCode : **File → Open Folder** sur `TOOLS/LINTER_ST/vscode-extension/`, appuyer sur
**F5** → ouvre une fenêtre "Extension Development Host" avec le linter actif et le projet complet
chargé (racine du repo, pour que `CODE/` soit visible). Ouvrir un `.st`, sauvegarder (`Ctrl+S`) →
les erreurs apparaissent dans Problems.

### Installer en permanent (`.vsix`)

```powershell
npm install -g @vscode/vsce
cd TOOLS/LINTER_ST/vscode-extension
vsce package
```

Puis dans VSCode : `Ctrl+Shift+P` → **Extensions: Install from VSIX...** → sélectionner le
`.vsix` généré.

### Réglages (`Ctrl+,` → chercher "Linter ST")

| Réglage | Défaut | Rôle |
|---|---|---|
| `linterSt.pythonPath` | `python` | Interpréteur Python utilisé pour lancer `lint.py` |
| `linterSt.codeRoot` | `CODE` | Racine des sources ST, relative au workspace ouvert |

## 🗺️ Roadmap

- ✅ **Lot 1** : CLI Python (`resolve_deps.py`, `lint.py`) — fait, validé sur 7 FB réels + 4 cas
  d'erreur réels (typo type, commentaire cassé, `IF` mal fermé, caractère invalide).
- ✅ **Lot 2** : extension VSCode (diagnostics live) — **validé en conditions réelles** (F5,
  Extension Development Host, 2026-08-23) : erreur `IF`/`END_IF` détectée et affichée dans
  Problems à la sauvegarde. Reste en mode debug (F5) — packaging `.vsix` pour install permanente
  disponible mais pas encore fait (voir section ci-dessus).
- Si le besoin de feedback à la frappe (pas juste à la sauvegarde) se confirme → migrer vers un
  vrai LSP Python (`pygls`), pas anticipé pour l'instant.
