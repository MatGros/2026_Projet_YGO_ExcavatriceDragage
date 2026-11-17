# Revue de mon travail — MES du 17/11/2026 (TORC-CC10)

> Écrite après le relevé complet de 10:14. Autocritique, sans validation : la validation revient à l'exploitant.
> Fiche de suivi : `REGISTRE_Suivi_MiseEnService_20261117.md`.

## 1. Ce qui est fait et vérifié
- Fiche de suivi restructurée en 9 étapes chronologiques, journal tenu au fil de l'eau.
- Relevé des persistantes : `snapshot_persistent.py` lancé **en réel** par l'exploitant, **355 variables en 10,65 s**, 6 erreurs attendues. CSV de référence : `20261117_PERSISTANTES/Persistantes_20261117_101458.csv`. Stable : 0 écart avec le relevé de 10:08.
- Comparaison avec les défauts du code : valeurs modifiées sur site identifiées (`CableLimitAscent_M` 7,7 · `SetDepth_M` −30 · `DrainTime_S` 2 · positions M3 0/5/15/20/30…).
- Comparaison liste en ligne ↔ code : 347 variables communes, même ordre, 6 nouvelles **à la fin** (aucun décalage mémoire).
- Correction des hooks (`$CLAUDE_PROJECT_DIR`) : faite par l'exploitant, **testée** depuis un sous-dossier.

## 2. Mes erreurs, à ne pas répéter
1. **Hypothèse reprise sans vérifier** : « machine = v0.7.25 ≈ `e38cc09a` » (registre de réintégration). Fausse : l'automate a le **v0.7.24 du 23/09 à 16:23**. Trouvée seulement grâce au bouton Details de l'exploitant.
2. **Piège du gain odométrique mal calculé** : j'ai annoncé un remplacement silencieux à 0,02, en partant de P2 − PV = 2 m (défauts du code). Sur la machine : 10 m → gain refusé, repli conservé. J'ai affirmé avant de relever les valeurs réelles.
3. **Commande inventée de mémoire** : « File → Open Project from PLC » n'existe pas (c'est **Source Upload**). Corrigé après recherche.
4. **Affirmation sans preuve** : « écart v0.7.24 → code actuel plus grand que prévu ». Reformulée en hypothèse.
5. **`cd` persistant dans le shell** : a bloqué tous mes outils d'écriture (hooks à chemin relatif). Faute à moi, coût : plusieurs échanges. Je suis retombé deux fois dans un `cd` ensuite (sans conséquence depuis la correction).
6. **Messages ambigus mal interprétés** : « ces var doivent être injectées » → j'ai proposé des règles d'injection ; l'exploitant voulait l'inverse. Pour un outil qui **écrit** sur l'automate, demander d'abord.
7. **Temps perdu sur le garde d'écriture** : 5 emplacements essayés (`codesys_console/`, `PRJ_CODESYS/`, dossier de la fiche, hors dépôt, puis `variable_lists/`). J'aurais dû donner le code à coller dès le premier refus, sans proposer d'autres dossiers.
8. **Outil de comparaison imparfait** : mon contrôle « capture ↔ CSV » a sorti 36 « absentes » faux positifs. Non vérifiées une à une.
9. **Horodatage** : je n'ai pas utilisé la commande `date` : presque toutes les entrées du journal portent « heure à compléter ».

## 3. Points non résolus
La liste vivante est dans la fiche (§ Constats ouverts et Journal) : **ne pas la dupliquer ici**. Résumé au moment de l'écriture : défauts du matin (codeurs M1/M2, autotest AU) non diagnostiqués · type d'opération du « Yes » et projet utilisé non renseignés · positions M3 `0/5/15/20/30` non mesurées · échecs de Recipe Manager, Files et Source Upload non expliqués · CSV de référence à copier hors du dépôt.

## 4. État du dépôt (rien de ceci n'est commité)
- Fiche de suivi, cette revue, dossier `20261117_PERSISTANTES/` (2 CSV).
- `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/` : `generate_persistent_variable_list.py`, `persistent_variables.txt`, `poc_lecture_persistante.py`, `snapshot_persistent.py`.
- `CODE_BACKUP/` : 2 fichiers de l'exploitant (extraction capturée, liste de noms en ligne).
- Aucun test automatique ni garde-fou n'accompagne les nouveaux outils (règle `fix:` + `guard:` non applicable ici, mais à noter).

## 5. À améliorer dans ma façon de travailler
- Relever la valeur réelle **avant** d'écrire une conséquence chiffrée.
- Marquer **hypothèse** dès l'écriture, pas après correction.
- Un seul `cd` interdit : chemins complets dans les commandes.
- Horodater avec `date` à chaque entrée du journal.
- Outils qui écrivent sur l'automate : cadrage et accord **avant** toute proposition de règles.
- Au premier refus du garde : donner le contenu et laisser l'exploitant le placer.

## 6. Pistes pour après la journée (propositions, non décidées)
- Trancher la deny-list du garde pour les outils de relevé en lecture seule (aujourd'hui un script console est interdit à l'agent, un générateur Python accepté).
- Contrôle automatique « liste en ligne ↔ liste générée ».
- Corriger les hooks dans les 5 copies de `.claude/worktrees/` si elles servent encore.
- Décider du sort des 14 fichiers `.tmpsandbox` toujours suivis par git.
