# ⚙️ Guide de configuration de l'IDE CODESYS 3.5 (v1.0)

> 📌 **Guide pratique** de configuration de l'éditeur CODESYS 3.5 (raccourcis clavier, ergonomie
> d'édition des POU ST). Ne définit **aucune règle d'ingénierie** : il ne remplace ni
> `CODE_QUALITY_STANDARDS.md`, ni `NAMING_CONVENTION.md` — il décrit comment travailler plus vite
> dans l'IDE.

---

## 🎯 1. Raison d'être & Responsabilité Unique

- **Problème résolu** : les POU et FB ST longs (ex. `PRG_02_Acquisition`, `FB_Cycle`) sont
  structurés en Regions Pragma `{region "§N Rôle fonctionnel"}` / `{endregion}` (voir
  `CODE_QUALITY_STANDARDS.md §7bis`). Replier/déplier ces Regions à la main ou dans des menus
  profonds est pénible — des raccourcis clavier rendent la navigation instantanée.
- **Périmètre strict** : configuration **personnelle** de l'IDE. N'impose aucun raccourci au
  reste de l'équipe, ne modifie ni le code, ni le comportement automate.
- **Type de composant** : guide utilisateur / aide-mémoire IHM IDE.

---

## ⌨️ 2. Raccourcis clavier personnalisés

> ⚠️ Ces raccourcis sont **personnalisés** sur le poste de l'utilisateur. Ils ne sont pas les
> valeurs par défaut de CODESYS 3.5. Si un raccourci ne fonctionne pas, vérifier sa
> configuration au §3.

| Raccourci | Effet | Portée |
|---|---|---|
| `Ctrl + R` | **Réduire tout** — replie toutes les Regions du POU courant | Éditeur de texte ST |
| `Ctrl + E` | **Étendre tout** — déplie toutes les Regions du POU courant | Éditeur de texte ST |
| `Shift + Ctrl + C` | **Importer** un fichier XML (import PLCopenXML dans le projet) | Projet / Fichier |
| `Shift + Ctrl + V` | **Exporter** un fichier XML (export PLCopenXML du projet) | Projet / Fichier |

- Les Regions repliées ne montrent que le titre `§N Rôle fonctionnel` ; le contenu est masqué
  mais **toujours présent** dans le code (recherche texte et compilation incluses).
- Après import PLCopenXML (bundle), les pragmas `{region ...}` sont restaurés dans le corps ST.

---

## 🛠️ 3. Où configurer ces raccourcis dans CODESYS 3.5

Chemin de menu :

```
Outils > Personnaliser > Clavier
```

| Champ | Valeur |
|---|---|
| **Catégorie** | `Éditeur de texte` |
| **Commande** | `Développer tout` (Ctrl + E) · `Réduire tout` (Ctrl + R) |
| **Nouveau raccourci** | saisir la combinaison, cliquer **Affecter** |

> ⚠️ Si `Ctrl+R` / `Ctrl+E` entrent en conflit avec un raccourci existant de l'IDE, CODESYS
> l'indique à l'assignation : choisir alors des combinaisons libres (ex. `Ctrl+Alt+E` /
> `Ctrl+Alt+R`).

Les raccourcis **Importer** / **Exporter** XML (`Shift+Ctrl+C` / `Shift+Ctrl+V`) se configurent
dans la même boîte de dialogue :

| Champ | Valeur |
|---|---|
| **Catégorie** | `Fichier` |
| **Commande** | `Importer` (Shift+Ctrl+C) · `Exporter` (Shift+Ctrl+V) |
| **Nouveau raccourci** | saisir la combinaison, cliquer **Affecter** |

> 💡 Ces raccourcis couplent la boucle d'itération documentée dans `AGENTS.md` : édition ST →
> génération du bundle PLCopenXML → **importer** le XML dans CODESYS 3.5 → **exporter** un XML
> de contrôle, le tout sans naviguer dans les menus.

---

## 🧱 4. Lien avec la convention Regions Pragma

- Le code source ST utilise `{region "§N Rôle fonctionnel"}` / `{endregion}` pour découper
  visuellement les POU multi-responsabilités.
- Norme d'écriture : `DOC/STDS/CODE_QUALITY_STANDARDS.md §7bis`.
- Garde-fou automatique : `TOOLS/AGENT_WORKFLOW/tests/test_region_pragmas.py` (équilibrage,
  périmètre autorisé, POU sélectionnés).
- Ces raccourcis ne **créent** pas de Region : ils replient/déplient uniquement celles déjà
  écrites dans le code.

---

## 🖱️ 6. Ajouter un bouton de barre d'outils pour lancer un script Python

> 📌 Ajouté le 2026-08-16, utilisé pour les scripts `TOOLS/PLC_LIVE_READER/codesys_console/`
> (voir [`TOOLS/PLC_LIVE_READER/README.md`](../../../TOOLS/PLC_LIVE_READER/README.md) pour
> le détail des scripts eux-mêmes — cette section ne couvre que la config IDE générique,
> réutilisable pour n'importe quel script de scripting engine).

CODESYS permet d'ajouter un bouton personnalisé qui lance un script Python (moteur de
scripting IronPython intégré) directement, sans repasser par la console de scripting à
chaque fois.

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

---

## 📚 7. Documents liés

| Document | Rôle |
|---|---|
| [`DOC/STDS/CODE_QUALITY_STANDARDS.md §7bis`](DOC/STDS/CODE_QUALITY_STANDARDS.md) | Convention d'écriture des Regions Pragma |
| [`DOC/STDS/NAMING_CONVENTION.md`](DOC/STDS/NAMING_CONVENTION.md) | Nommage des sections commentées ST |
| [`DOC/WFLOW/CONTRACTS/TASK_CONTEXT_20260814_REGIONS_PRAGMA_PROJECT.yaml`](DOC/WFLOW/CONTRACTS/TASK_CONTEXT_20260814_REGIONS_PRAGMA_PROJECT.yaml) | Contrat du lot d'introduction des Regions |
| [`TOOLS/PLC_LIVE_READER/README.md`](../../../TOOLS/PLC_LIVE_READER/README.md) | Scripts concrets utilisant le bouton toolbar (§6) |
