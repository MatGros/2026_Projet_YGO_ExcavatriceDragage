# ⛔ Fiche 3 — Blocage socle : le type `ST_FbStatus` n'existe pas

> 📅 2026-08-20 · 🤖 `CC-01` · 🔍 Read-only
> 🎯 **But** : expliquer pourquoi `T136` et `T137` ne peuvent pas avancer en l'état.
> 📏 Référentiel : `DOC/STDS/CODE_QUALITY_STANDARDS.md` §2quinquies

---

## 🔍 Le constat

Le standard décrit un contrat d'interface obligatoire pour les blocs fonctionnels « métier » :

> §2quinquies — contrat `standard`, sortie : `Status : ST_FbStatus` — **forme cible**

Cette structure est spécifiée en détail : **six membres exactement** (`Busy`, `Done`, `Error`,
`ErrorId`, `State`, `StateAtError`).

**Or le fichier de définition de ce type n'existe nulle part dans `CODE/`.**

| Ce qui existe | Ce qui manque |
|---|---|
| La spécification écrite (`CODE_QUALITY_STANDARDS.md` §2quinquies) | ❌ Le fichier `ST_FbStatus.st` |
| Le contrôle automatique qui sait le reconnaître (`G315`) | ❌ La moindre utilisation dans un bloc |
| La tâche de migration planifiée (`T137`) | ❌ Le type à migrer *vers* |

---

## 🧩 Pourquoi personne ne l'a vu

Trois mécanismes se sont additionnés :

1. **Le contrôle passe au vert.** `G315_check_fb_interface.py` accepte volontairement les deux
   formes — la *cible* (`Status : ST_FbStatus`) et l'*héritée* (les six membres déclarés à plat),
   au titre de la « tolérance transitoire » du §2quinquies. Comme les 53 blocs sont en forme
   héritée, il annonce **PASS** sans jamais signaler que la cible est introuvable.

2. **La tâche `T136` est déclarée implémentée.** Sa fiche liste : contrats documentés, doublon
   résolu, déduplication faite, garde-fou créé et validé. **Quatre livrables sur cinq.**
   Le cinquième — le type lui-même — n'apparaît dans aucun critère.

3. **La tâche `T137` mesure son avancement sur le mauvais indicateur.** Elle annonce
   « 0 cible / 21 héritée » comme un *point de départ de migration*. C'est exact, mais la lecture
   naturelle est « il reste 21 blocs à migrer », alors que la réalité est
   « **il n'y a rien vers quoi migrer** ».

> 💡 Le garde-fou ne ment pas : il mesure la conformité des blocs, pas l'existence du type.
> Personne ne lui a demandé de vérifier que la cible existe.

---

## ⚠️ Conséquence pratique

`T137` est planifiée comme un lot de migration mécanique, avec un pilote identifié
(`FB_Translation`, ~10 lignes) et un impact IHM chiffré à zéro. **Ce plan est correct** — mais il
ne peut pas démarrer : sa première étape réelle n'est pas « migrer le pilote », c'est
**« créer le type »**.

Si un agent prend `T137` en l'état, il découvrira le manque au moment d'écrire, et créera le type
*à la volée* — sans revue, au milieu d'un lot de migration. Un type socle destiné à 21 blocs
fonctionnels mérite d'être créé et validé **seul**.

---

## ✅ Correction proposée

Découper en deux, au lieu d'un seul lot :

| Étape | Contenu | Criticité |
|---|---|:---:|
| **A** | Créer le type `ST_FbStatus` conformément au §2quinquies (six membres, ni plus ni moins), le ranger avec les autres types transverses, vérifier qu'il est repris dans le paquet d'import | C2 — création pure, aucun bloc modifié |
| **B** | `T137` migration : pilote `FB_Translation`, puis généralisation bloc par bloc | C3 — touche des interfaces |

**Bénéfice de la coupure** : l'étape A est revue pour elle-même. Si le type est mal formé, l'erreur
est corrigée avant d'avoir contaminé 21 blocs.

## 🔒 Point de vigilance sur l'étape B

`T137` note elle-même le risque, et il est justifié :

> *« Ne pas mélanger avec T130/T135 : les deux tapent lourdement dans `PRG_04`, le différentiel
> deviendrait illisible — impossible de distinguer un renommage mécanique d'un vrai changement de
> logique. Rédhibitoire sur du code de sécurité. »*

Cette contrainte doit être tenue : **un seul de ces trois lots ouvert à la fois** sur `PRG_04`.

---

## ❓ Décisions attendues

| # | Question | Enjeu |
|---|---|---|
| Q7 | Valide-t-on la coupure A / B ? | Créer un type socle au milieu d'un lot de migration, c'est le créer sans revue |
| Q8 | Faut-il durcir `G315` pour signaler « type cible introuvable » ? | Sans ça, la même classe d'erreur — un standard écrit sans son support — repassera au vert |
| Q9 | La « tolérance transitoire » doit-elle porter une échéance ? | Formulée « levée à la clôture de T137 », elle est aujourd'hui sans fin puisque T137 ne peut pas démarrer |
