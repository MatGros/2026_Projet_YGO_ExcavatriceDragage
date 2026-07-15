# POC — Test d'import PLCopenXML (objets neufs, jetables)

> ⚠️ Ce dossier n'est ni de la doc fonctionnelle (`DOC/`) ni du code machine (`CODE/`). C'est
> un test ponctuel pour observer le comportement réel de CODESYS à l'import PLCopenXML.

## Contenu de `POC_ImportTest.xml`

Un fichier PLCopenXML minimal, conforme au schéma confirmé dans
`GUIDE_Conversion_ST_vers_PLCopenXML.md`, contenant 2 objets **tout neufs** :

- `ST_POC_ImportTest` (STRUCT, 3 membres : `Counter : INT`, `Label : STRING(20)`, `Ready : BOOL`)
- `FB_POC_ImportTest` (FUNCTION_BLOCK, utilise `ST_POC_ImportTest` en `VAR_IN_OUT`, logique
  volontairement triviale — incrémente `Counter` tant qu'`Enable` est actif)

Les deux objets sont regroupés dans un dossier `ProjectStructure` `_POC_IMPORT_TEST` (préfixe
`_` + majuscules pour qu'il saute aux yeux dans l'arbre, à ne confondre avec aucun dossier réel
type `WINCH`/`GRAPPIN`). Les noms `POC_`/`_POC_` ne peuvent entrer en collision avec aucun objet
existant du projet réel. Les deux `ObjectId` (GUID) ont été générés à la volée (`uuid4`), sans
lien avec quoi que ce soit de connu de CODESYS :
- `ST_POC_ImportTest` → `9ad121d0-f078-4915-a2d5-93ede69fb13e`
- `FB_POC_ImportTest` → `4afc4450-3037-4e62-8586-070b5c55100e`

## ✅ Résultats déjà observés (import réel effectué)

- **Import sélectif confirmé** : la boîte de dialogue d'import liste les objets du fichier avec
  des cases à cocher — on peut n'en importer qu'une partie, pas obligé de tout prendre.
- **Placement confirmé** : le dossier `<ProjectStructure><Folder Name="...">` du XML se crée
  **relativement au nœud sélectionné dans l'arbre du projet** au moment de lancer l'import (pas
  un chemin absolu depuis la racine). Résultat observé la 1ère fois : les objets ont atterri
  sous `_IMPORT` parce que ce nœud était sélectionné dans l'arbre à ce moment-là. **Pour
  reproduire l'organisation à plat de `CODE/` (dossiers directement sous `Application`, comme
  `WINCH`), sélectionner le nœud `Application` avant de lancer l'import.**
- GUID totalement inconnu (`uuid4` frais) : import accepté sans erreur ni avertissement.

## Encore à observer

## Pourquoi ce test

Le guide (§7 "Ce qui reste à vérifier") liste plusieurs points de **comportement** non
documentés officiellement par CODESYS, qui ne se vérifient qu'en testant un import réel. Ce
fichier sert à ça.

## Ce qu'il faut observer précisément lors de l'import

Dans CODESYS : sélectionner le nœud `Application` dans l'arbre, puis `Project → Import…`
(PLCopenXML), sélectionner `POC_ImportTest.xml`.

1. **Message affiché** : y a-t-il un résumé/rapport d'import (objets créés, avertissements) ?
   Le noter tel quel.
2. **Ré-import du même fichier, à l'identique** : importer `POC_ImportTest.xml` une seconde
   fois (GUID inchangé, noms déjà présents). CODESYS propose-t-il de nouveau les 3 choix
   **Replace / Rename / Skip** documentés officiellement ? Le comportement est-il le même pour
   la STRUCT et pour le FB ?
3. Bonus si testé : ré-importer après avoir modifié `Counter` ou le commentaire dans le
   fichier XML (toujours même nom/GUID) et choisir **Replace** — vérifier que le contenu est
   bien remplacé sans laisser de résidu de l'ancienne version.

Ces observations serviront à lever les TBD du §7 du guide et, si besoin, à ajuster la
stratégie du futur générateur (regroupement des dépendances dans un seul fichier, etc.).

## Nettoyage

Les 2 objets sont **100 % jetables** : aucune dépendance avec le reste du programme
(`WINCH`, `GRAPPIN`, etc.). Une fois le test terminé, supprimer le dossier `_POC_IMPORT_TEST`
directement dans l'arbre CODESYS (clic droit → Delete) ne casse rien ailleurs.
