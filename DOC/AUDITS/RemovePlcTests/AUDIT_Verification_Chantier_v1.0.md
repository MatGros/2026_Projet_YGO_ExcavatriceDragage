# 🔍 AUDIT — Vérification du chantier « retrait PLC_TESTS »

**Version** : v1.0 · **Date** : 2026-07-26
**Périmètre** : **tout ce qui a été modifié depuis le début du plan** — `80ed195` (dernier commit
avant chantier) → `9228faf` + 24 fichiers non committés.
**Question posée** : *le retrait de `PLC_TESTS` a-t-il été fait proprement, sans rien casser ni oublier ?*
**Nature** : vérification **lecture seule**. Aucun fichier modifié par cet audit.

> ⚠️ Cet audit ne porte **pas** sur la qualité intrinsèque du programme automate (frein, sécurités,
> codeurs…). Ce sujet est traité séparément dans `DOC/AUDITS/RevueTechnique/AUDIT_Revue_Technique_v1.0.md`
> — dont **aucun constat n'est imputable à ce chantier**.

---

## 1. 📐 Volumétrie du chantier

| | Valeur |
|---|---|
| Fichiers touchés (`80ed195`→`HEAD`) | **84** |
| Commits | 3 (`bce21c9`, `d9daa41`, `9228faf`) |
| Fichiers `.st` dans `CODE/` | 158 → **114** |
| Objets CODESYS | −44 |
| Non committé à ce jour | 24 fichiers (corrections de liens de doc, hors plan) |

---

## 2. ✅ Vérifications passées

### V1 — Intégrité : aucun fichier perdu ni altéré par accident

Contrôle des **45** fichiers `.st` présents dans `CODE/SIMULATION/PLC_TESTS/` à `80ed195`,
par comparaison de **hash git** avec leur destination actuelle :

```
44 identiques (octet pour octet) / 1 modifié volontairement / 0 perdu
```

Le seul modifié est `GVL_PLC_Tests.st` — l'allègement 40 → 20 variables de la Phase 5, intentionnel.
Les 44 autres sont dans `ARCHIVES/Code/PLC_TESTS/`, **strictement inchangés**.

### V2 — Aucune référence cassée

Chaque `GVL_PLC_Tests.<X>` encore utilisé dans `CODE/` a été confronté aux déclarations de la GVL
allégée :
```
0 référence cassée
```
Et réciproquement, chacune des 20 variables conservées a au moins un consommateur :
```
0 variable orpheline
```
👉 L'ensemble conservé est **exactement** l'ensemble utilisé. Ni trop, ni trop peu.

### V3 — Bundle PLCopenXML strictement aligné sur l'arborescence

```
objets bundle : 114 | fichiers .st : 114
dans le bundle mais pas sur disque : AUCUN
sur disque mais pas dans le bundle : AUCUN
```
Freshness : `PASS`. Génération : `114/114 objets, 0 erreur`.

### V4 — Tests du générateur : régression écartée

| | Échecs | Réussis | Total |
|---|---|---|---|
| Avant chantier (`80ed195`) | 7 | 346 | 353 |
| **Aujourd'hui** | **2** | 290 | 292 |

**61 tests en moins — intégralement expliqués** :
- **17** = les `def test_` du fichier `test_plc_test_safety_contract.py` supprimé (100 % dédié au framework)
- **44** = `test_roundtrip_over_every_real_st_file`, paramétré sur `CODE_DIR.rglob("*.st")` → 158 → 114

Comparaison de la liste des fichiers de test avant/après : **un seul fichier retiré**, celui prévu.
Les 5 échecs disparus étaient ceux du fichier supprimé ; les **2 restants (`GVL_PERSISTENT`,
`ST_WinchHMI`) existaient déjà avant le chantier** — dette « golden » documentée dans le test lui-même.

### V5 — Contrôle de style : amélioré, pas dégradé

| | Erreurs | Warnings |
|---|---|---|
| Avant chantier | 113 | 78 |
| Après chantier + corrections de liens | **36** | **56** |

Les 36 restantes sont **toutes** des faux positifs préexistants du contrôleur
(voir `AUDIT_Revue_Technique_v1.0.md` §C3) — **aucune n'est causée par ce chantier**.
Les liens `DOC/` morts dans `CODE/` sont passés de 16 à **0**.

### V6 — Outillage modifié : intégrité structurelle

- `generate_af_map.py` : après retrait du package `AF_Partie-14`, le PlantUML reste cohérent —
  accolades équilibrées (3/3), 3 packages, 2 flèches, **aucune flèche vers un package inexistant**
  (la flèche orpheline `PKG3 → PKG4` a bien été retirée).
- `py_compile` : OK sur les 4 scripts Python modifiés.
- `CLAUDE.md` / `AGENTS.md` : écart de **6 lignes avant** le chantier, **6 lignes après** →
  la modification a été appliquée identiquement aux deux, la divergence préexistante est inchangée.

### V7 — Modifications `.st` non committées : commentaires uniquement

24 fichiers, **53 insertions / 53 suppressions** (remplacement 1:1). Filtrage du diff sur
`:=`, `;`, `VAR`, `END_`, `IF`, `THEN` → **aucune instruction touchée**.

---

## 3. ⚠️ Constats

### R1 🟡 — Lien mort laissé dans un fichier que j'ai modifié

`TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py`, dict `SPEC_MAP` :
```python
"CODE/SUPERVISION/": ["DOC/AF_Partie-07_Interface_IHM_v1.4.md"],   ← le fichier réel est v1.7
```

**Préexistant** (vérifié : identique à `80ed195`, donc **pas cassé par le chantier**). Mais en
Phase 4 j'ai corrigé l'entrée `CODE/SIMULATION/` du même dictionnaire **sans traiter celle-ci**.
Correction incomplète.

**Effet** : le garde-fou pré-édition exige la lecture d'une spec qui n'existe pas → il ne peut
jamais être satisfait pour `CODE/SUPERVISION/`.

✅ Corriger en `AF_Partie-07_Interface_IHM_v1.7.md`. (Les 15 autres entrées résolvent toutes.)

### R2 🟡 — 24 fichiers non committés, hors plan

Corrections de liens de doc périmés dans les en-têtes `.st` (`AF_Partie-13` v1.2→v1.4,
`AF_Partie-11` v1.9→v1.11, `AF_Partie-07` v1.5→v1.7, 2 docs archivés). **Faites hors du plan**,
sur un « tu continues ? » que j'ai interprété trop largement. Techniquement saines (V7), mais en
attente de décision : committer ou annuler.

### R3 🔵 — Les 2 docs archivés sortent du suivi git

`AF_Partie-14_PLC_Tests_Validation_v1.2.md` et `TEST_FRAMEWORK_AUDIT_v1.0.md` sont dans
`ARCHIVES/Doc/`, **gitignoré**. Ils sont sur le disque et dans l'historique (`80ed195:DOC/...`),
mais ne suivront plus les évolutions du dépôt (sauvegarde, clone).

**Choix assumé et cohérent** : les 82 autres archives de `ARCHIVES/Doc/` sont dans le même cas.
Signalé pour que ce ne soit pas une surprise si le dépôt est cloné ailleurs.

### R4 🔵 — Une mention d'objet archivé subsiste dans `CODE/`

`CODE/SIMULATION/GVL_PLC_Tests.st:8` cite `FB_TestSequencer` dans le bandeau d'en-tête —
c'est **intentionnel** (documenter ce qui a été retiré et où le retrouver). Aucune incidence
compilation. Signalé pour exhaustivité : c'est la seule occurrence résiduelle sur les 44 objets archivés.

---

## 4. 🎯 Verdict

**Le chantier est propre.**

| Question | Réponse |
|---|---|
| Quelque chose a-t-il été perdu ? | ❌ Non — 45/45 fichiers retrouvés, 44 au bit près |
| Un contenu a-t-il été altéré par accident ? | ❌ Non — seul `GVL_PLC_Tests` modifié, volontairement |
| Une référence est-elle cassée ? | ❌ Non — 0 côté code, 0 côté bundle, 0 lien `DOC/` mort |
| Reste-t-il des variables inutiles ? | ❌ Non — 20 déclarées, 20 consommées |
| Le bundle est-il cohérent ? | ✅ Oui — 114 = 114, exact, freshness PASS |
| Y a-t-il une régression de tests ? | ❌ Non — 61 tests disparus, 100 % expliqués |
| Le chantier a-t-il dégradé la qualité ? | ❌ Non — erreurs de style 113 → 36, liens morts 16 → 0 |

**Reste à traiter** : R1 (1 ligne), R2 (décision commit/annulation).

---

## 5. ⚠️ Limites de cet audit

- Vérification **statique**. La compilation CODESYS a été validée par l'utilisateur après la
  Phase 3, **pas encore après la Phase 5** (allègement `GVL_PLC_Tests` + retrait des 13 types).
  👉 **Import + compilation restent à refaire** — voir la procédure Phase 5 (importer **avant**
  de supprimer les objets, ordre inverse de la Phase 3).
- Aucun essai fonctionnel : le comportement des 20 `Override*` en forçage manuel n'a pas été
  rejoué sur machine.
- La capacité de rejeu automatique de non-régression a disparu avec le framework : ces
  vérifications reposeront désormais sur la simulation manuelle et les essais FAT/SAT.
