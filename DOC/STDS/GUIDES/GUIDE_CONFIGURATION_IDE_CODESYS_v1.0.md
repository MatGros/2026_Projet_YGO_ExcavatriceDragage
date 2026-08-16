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

## 📚 5. Documents liés

| Document | Rôle |
|---|---|
| [`DOC/STDS/CODE_QUALITY_STANDARDS.md §7bis`](DOC/STDS/CODE_QUALITY_STANDARDS.md) | Convention d'écriture des Regions Pragma |
| [`DOC/STDS/NAMING_CONVENTION.md`](DOC/STDS/NAMING_CONVENTION.md) | Nommage des sections commentées ST |
| [`DOC/WFLOW/CONTRACTS/TASK_CONTEXT_20260814_REGIONS_PRAGMA_PROJECT.yaml`](DOC/WFLOW/CONTRACTS/TASK_CONTEXT_20260814_REGIONS_PRAGMA_PROJECT.yaml) | Contrat du lot d'introduction des Regions |
