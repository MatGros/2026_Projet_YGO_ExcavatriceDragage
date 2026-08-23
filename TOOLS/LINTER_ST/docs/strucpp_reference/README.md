# 📖 Documentation officielle STruCpp — archive locale

Copies figées de 3 docs officielles [Autonomy-Logic/STruCpp](https://github.com/Autonomy-Logic/STruCpp)
(branche `development`), récupérées le **2026-08-23** pour croiser nos découvertes empiriques sur
les limites du compilateur avec ce que l'éditeur documente réellement. Archivées ici pour ne pas
dépendre d'un accès réseau à chaque relecture, et parce que la branche `development` évolue —
ces copies datent d'un instant précis.

⚠️ **La branche `development` est en avance sur les releases taggées.** Découvert en session :
`IEC_COMPLIANCE.md` annonçait l'initialiseur de struct/array par litéral nommé comme "Supported",
alors que notre binaire vendoré (v0.6.2) le rejetait. Vérifié empiriquement contre la release
`v0.6.3` (sortie 2026-08-18, 5 jours avant cette session) : **le bug était corrigé** dans cette
release. Le décalage version-doc était donc réel, pas une erreur d'interprétation de notre part —
`v0.6.3` a été adoptée comme binaire vendoré suite à cette vérification (voir
`linter_st_convert_codesys_to_iec.py`, section "BINAIRE VENDORE" du docstring).

## 📋 Fichiers

| Fichier | Contenu | Ce qu'on en a tiré |
|---|---|---|
| `IEC_COMPLIANCE.md` | Tableau supporté/non-supporté par catégorie (types, POU, opérateurs, control structures...) | Confirme la plupart de nos correctifs (init struct en déclaration, `ARRAY[..,..]` supporté, `PERSISTENT` absent) |
| `ARCHITECTURE.md` | Pipeline de compilation, modules, API publique | Révèle une **API JS/TS native** (`compile()`, `parse()`) — piste d'amélioration future non explorée (voir `README.md` principal) |
| `UNION_IMPLEMENTATION_PLAN.md` | Plan d'implémentation `UNION` (feature "Proposed", pas encore livrée) | Sans impact — `UNION` jamais utilisé dans `CODE/` |

## 🎯 Méthode retenue pour croiser doc ↔ comportement réel

Un simple constat "la doc dit X" **n'est jamais suffisant** pour trancher un comportement de
compilateur — la doc peut décrire une version pas encore livrée, ou un contexte différent de
celui testé. À chaque écart doc/empirique trouvé, la même méthode a été appliquée :

1. **Test isolé minimal** (2-3 lignes de ST) reproduisant exactement le cas — jamais sur le vrai
   `CODE/` du projet, pour éliminer les variables parasites (dépendances manquantes, etc.).
2. **Comparaison de version** si le résultat contredit la doc — vérifier si une release plus
   récente que le binaire vendoré existe et corrige l'écart (`strucpp.exe -v` vs
   [releases GitHub](https://github.com/Autonomy-Logic/STruCpp/releases)).
3. **Mise à jour du binaire vendoré uniquement après confirmation empirique** que ça corrige le
   cas visé sans casser les autres limites déjà connues (régression testée sur les 4 cas
   documentés dans le README principal AVANT/APRÈS la mise à jour).

C'est cette méthode — pas la lecture de la doc seule — qui a permis de supprimer une
transformation devenue inutile (`_strip_struct_default_init`) plutôt que de continuer à
"inhiber" une erreur que le compilateur ne produit plus.
