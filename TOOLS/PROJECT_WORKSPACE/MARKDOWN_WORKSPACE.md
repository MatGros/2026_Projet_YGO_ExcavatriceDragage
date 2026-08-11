# MARKDOWN_WORKSPACE — Édition & cochage des fichiers Markdown

Mode d'emploi VS Code pour travailler les fichiers Markdown du projet
(specs `DOC/AF_Partie-*`, `PLAN_TASK`, **checklists** `DOC/CHECKLISTS/*`) :
**cocher des cases dans l'aperçu, sans extension dédiée**.

## 🎯 Rôle

Cette configuration permet de **cocher interactivement les `- [ ]`** d'un fichier
Markdown (checklists, plans de tâches) **dans l'aperçu**, puis de **sauvegarder** :
la modification est écrite dans le fichier texte source. Aucune extension checkbox
supplémentaire n'est nécessaire.

## 📦 Extensions VS Code à installer

| Extension | ID | Rôle |
|---|---|---|
| **Markdown Preview Enhanced** | `shd101wyy.markdown-preview-enhanced` | Aperçu riche + cochage des cases |
| **markdownlint** | `davidanson.vscode-markdownlint` | Linting : repère les cases / formats malformés |

🚫 **Pas besoin** de l'extension *Markdown Checkbox* (`bierner.markdown-checkbox`) :
le double affichage source/aperçu suffit.

### Installation sur un autre PC

1. Ouvrir le projet dans VS Code.
2. Ouvrir **Extensions** (`Ctrl+Shift+X`).
3. Rechercher **Markdown Preview Enhanced** (auteur Yiyi Wang) → Installer.
4. Rechercher **markdownlint** (auteur David Anson) → Installer.

## ▶️ Utilisation — cocher des cases

1. Ouvrir le fichier Markdown voulu (ex. une checklist de `DOC/CHECKLISTS/`).
2. Appuyer sur **`Ctrl+K V`**.
   → Le fichier s'affiche **sur deux fenêtres en parallèle** : édition (gauche) + aperçu (droite).
3. Dans l'**aperçu**, cliquer sur les cases à cocher : `- [ ]` → `- [x]`.
   → La case se met à jour **instantanément dans la fenêtre d'édition** (source).
4. **Sauvegarder** le fichier texte (`Ctrl+S`) — c'est le seul moment où le fichier est écrit.

Raccourcis utiles :

| Action | Raccourci |
|---|---|
| Aperçu côte à côte (2 fenêtres) | `Ctrl+K V` |
| Aperçu dans un onglet | `Ctrl+Shift+V` |
| Sauvegarder le fichier source | `Ctrl+S` |

## ⚙️ Notes de fonctionnement

- Le cochage se fait **dans l'aperçu**, jamais dans le code brut (moins d'erreurs de syntaxe).
- Le **linter markdownlint** signale en ambre les cases mal écrites
  (`[X]` au lieu de `[x]`, espaces manquants, liste non indentée…) → à corriger dans la source.
- Tant qu'on ne sauvegarde pas, **rien n'est écrit** sur le disque : on peut explorer
  librement l'aperçu, puis décider d'enregistrer ou non.
- Les deux fenêtres restent synchronisées en continu pendant la session.

## 🚫 Choix volontaire

- Aucune extension checkbox dédiée (la fonction est native via l'aperçu).
- Aucun outil externe : ni script, ni tâche VS Code.
- Le fichier source **Markdown seul** fait foi (versionné dans Git).
