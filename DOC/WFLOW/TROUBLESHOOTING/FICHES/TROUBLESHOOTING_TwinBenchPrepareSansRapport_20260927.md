# Session de Troubleshooting - TwinBench prepare sans rapport

Date : 2026-09-27 16:43 CEST - Situation : banc local Control Win - Statut : RESOLUE, recette humaine requise

## 1. Contexte fige

Le runner travaille uniquement dans `%LOCALAPPDATA%\TwinBenchControlWin`. Le projet source est protege par son empreinte SHA-256. Aucun PLC reel ni aucune variable PLC ne sont impliques.

## 2. Symptome

L'action `prepare` retourne immediatement `CODESYS n'a produit aucun rapport`.

## 3. Indices

- Import et inspection precedents reussis.
- Changement recent : lancement asynchrone ajoute pour afficher la progression.
- Journal : `'C:\Program' n'est pas reconnu en tant que commande`.
- Un nouvel import du meme fichier remettait aussi l'etat a `IMPORTED` et masquait l'historique de preparation.

## 4. Arbre des causes

| Hypothese | Preuve | Verdict |
|---|---|---|
| Projet CODESYS invalide | Aucun rapport ScriptEngine produit | Eliminee a ce stade |
| CODESYS plante pendant prepare | CODESYS n'est jamais lance | Eliminee |
| Chemin executable mal transmis | Le journal coupe `C:\Program Files` a `C:\Program` | Cause confirmee |
| Droits Control Win | L'echec precede toute connexion runtime | Eliminee |

## 5. Arbre vertical

```text
Menu prepare
  -> Start-Process cmd.exe
  -> ligne de commande recombinee
  -> chemin coupe a C:\Program
  -> CODESYS non lance
  -> rapport JSON absent
```

Resume : `[prepare] -> [CODESYS non lance] -> [rapport absent]`

## 6. Donnees et essais

- Log lu : `20260927_164320_prepare.log`.
- Manifest lu : etat `PREPARE_FAILED`, source SHA-256 conservee.

## 7. Conclusion

Cause racine : regression d'echappement introduite par l'intermediaire `cmd.exe` dans le suivi de progression.

## 8. Correction

- Definitif : lancer directement `CODESYS.exe` avec `Start-Process` et des arguments separes.
- Garde-fou : autotest interdisant le retour a `ComSpec` et exigeant l'executable direct.
- Ergonomie : un projet source deja importe avec la meme empreinte est reutilise sans reinitialiser son etat.

## 9. Verification

- Syntaxe PowerShell.
- Autotest du runner.
- Recette humaine : relancer uniquement l'option 2 sur la copie isolee.

## 10. Journal

- 2026-09-27 16:43 CEST : cause confirmee par lecture du journal.
- 2026-09-27 : correction et garde-fou appliques.
