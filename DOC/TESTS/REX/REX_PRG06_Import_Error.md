# 🔬 REX — Bug import CODESYS PRG_06_Outputs_LD (multi-causes)

**Date** : 2026-08-04 (mis à jour 2026-08, LOT_STRUCTURE_INTERLOCKS_LD)  
**Version** : v1.1  
**Statut** : ✅ Résolu (import + ouverture + simulation OK)

---

## 📋 Problème

L'import du bundle `CODE_Bundle.xml` dans CODESYS V3.5 SP19 échouait :

```
[ERREUR] Échec de la création de l'objet « PRG_06_Outputs_LD ».
Cause : L'index se trouve en dehors des limites du tableau.   ← import
```

Puis, une fois l'import passé, crash à l'**ouverture** du POU :

```
System.ArgumentNullException: La valeur ne peut pas être null.
Nom du paramètre : key
   à TypeProvider.GetOperandDeclarationInfo(IOperand iop)
   à BoxTreeSymbolInfoSetter.VisitBox / VisitAssign
```

⚠️ **Le REX précédent (v0.5.4, "premier output câblé") était FAUX / insuffisant** :
il documentait une cause unique partielle. La réalité = **5 causes indépendantes** empilées,
chacune découvrable seulement après correction de la précédente.

---

## 🎯 Causes racines (par ordre de découverte)

| # | Cause | Symptôme | Correctif |
|---|-------|----------|-----------|
| 1 | **Parasites `Bundle_H*.xml`** (artefacts dichotomie REX) découverts comme POU natifs ; `Bundle_HB_ArmSeqStep.xml` contenait un POU `FB_Safety_EmergencyManagement` homonyme qui écrasait le vrai | Import imprévisible | `file_discovery.py` : filtre `f.name.startswith("Bundle_")` |
| 2 | **localId du bloc > localId de ses sources** | IndexOutOfRange à l'import | Réserver le `block_id` **AVANT** de créer les sources (oracle : block=3, sources=4-10) |
| 3 | **Motif `inVariable(expr=0) → outVariable(PowerCutOffReq)`** | IndexOutOfRange à l'import | Supprimé (absent de l'oracle) ; `PowerCutOffReq` = FALSE par défaut |
| 4 | **Coils vers variables `_DQ` non déclarées** (`M1_RelayFwd_Up_DQ` = sortie Device absente du bundle) | ArgumentNullException key=null à l'**ouverture** | Coils → variables **locales** du POU (`M1RelayFwd`), comme l'oracle |
| 5 | **Coil doublon sur output déjà assigné** (`ArmPulse_RQ` assigné dans le bloc + coil `EmergencyArming_RQ` externe = double assignement) | ArgumentNullException key=null à l'ouverture (VisitAssign→VisitBox) | Pas de coil après FB_Safety (l'oracle n'en a aucun) |

### Fausses pistes écartées (leçons)

- ❌ "Premier output câblé" (REX v0.5.4) : **pas** la cause réelle
- ❌ Nombre d'outputs du bloc FB_Safety
- ❌ Types non-BOOL (INT, WORD) dans les outputs
- ❌ Forme câblée vs expression sur les outputs
- ❌ Nombre de réseaux (2, 3, 15 réseaux passaient dès la structure correcte)
- ❌ 6 vs 5 `inVariable` (test 6invar → OK)
- ❌ Texte dans les commentaires LD (PRG_01 en a, s'ouvre bien)

---

## ✅ Structure réseau conforme (validée par oracle + simulation)

Par réseau FB_Output, **dans cet ordre** :

```
leftPowerRail(0) → comment(1) → vendorElement(2) → block(3, localId RÉSERVÉ avant)
→ contact(4) → inVariable(5-10, vides, inputs non connectés) → coil(11)
```

Règles tirées des oracles `PRG_06_Outputs_LD.xml` / `PRG_Oracle_Nested.xml` :

| Règle | Détail |
|---|---|
| TRUE / FALSE | = **contact** `<variable>TRUE</variable>` (pas inVariable expr) |
| Variable qualifiée (`PRG_07_Supervision.X`) | = **contact** |
| Input non connecté | = `inVariable` vide, créé **avant** le bloc |
| Output assigné | = `<expression>target</expression>` **DANS** `outputVariables` du bloc |
| 1er output (Ready) | = câblé `<connectionPointOut />` sans expression |
| Coil | connectée au bloc avec `formalParameter` ; 1 comment+vendorElement par réseau |
| localId bloc | **plus petit** que ses sources |
| Doublons d'output | ⛔ interdits (1 assignement max par output) |
| ObjectId | conservé (sinon POU importé hors de MAIN) |

**Format commentaire** (avec texte, fonctionnel) :

```xml
<comment localId="1" height="0" width="0" xmlns:html="http://www.w3.org/1999/xhtml">
  <position x="0" y="0" />
  <content><html:xhtml>Relais M1 Marche Avant (Montée)</html:xhtml></content>
</comment>
```

---

## 🧪 Validation finale

- ✅ Import CODESYS : aucun POU en erreur
- ✅ Ouverture PRG_06 : réseaux LD visibles, commentaires affichés
- ✅ Simulation PRG_01 + PRG_06 : OK
- ✅ Bundle frais : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` → PASS

---

## 🆕 Cause #6 (2026-08, LOT_STRUCTURE_INTERLOCKS_LD) — Contact externe mal référencé sur broche de sortie de bloc

**Contexte** : ajout des barrières finales `FB_WinchOutputInterlock_LD` (×2) et
`FB_TranslationOutputInterlock_LD` visibles en réseaux LD séparés, avec tentative
de rendre chaque sortie physique (`RelayFwd`, `BrakeCmd`...) visible via un
réseau extérieur dédié (contact sur la broche de sortie du bloc → coil),
séparément du bloc lui-même.

**Symptome** : import CODESYS échoué, `«référence de l'objet non définie»`.

**Cause racine** : un `<contact>` câblé sur une broche de sortie précise d'un
bloc (`connection refLocalId=<block_id> formalParameter=<Output>`) DOIT porter
une `<variable>` dont le texte correspond **exactement** à la référence source
attendue par CODESYS pour cette connexion (ex. `instWinchOutputInterlockM1.RelayFwd`),
et non un simple alias local (`M1RelayFwd`). Un mismatch entre le libellé
affiché du contact et sa connexion réelle casse la résolution d'opérande à
l'ouverture/import, même si la structure XML est par ailleurs valide
(localId croissant, pas de doublon, etc. — les règles 1-5 ci-dessus passaient).

**Correctif retenu (règle #6, définitive)** : ne JAMAIS câbler un contact
externe directement sur une broche de sortie de bloc (`formalParameter`) pour
«ré-exposer» une sortie. Assigner la sortie **directement par `<expression>`
dans le bloc lui-même** (`outputVariables/variable/connectionPointOut/expression`
→ variable locale du POU). La variable locale reste ensuite consultable/visible
via son propre réseau séparé (ex. coil de recopie `GVL_Global.*`), jamais via un
contact pointé sur la broche du bloc producteur.

**Fichier concerné** : `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py`
(fonctions `_build_winch_interlock_network` / `_build_translation_interlock_network`
— assignation directe par expression ; la fonction intermédiaire
`_build_interlock_output_networks` / `_make_contact_from_block_output`, source
du bug, a été retirée).

**Preuve de non-régression** : vérifier après toute génération qu'aucun
`<contact>` du bundle ne porte `connection[@formalParameter]` pointant vers un
`<block>` (recherche automatisable — zéro occurrence attendue pour PRG_06).

---

## 🎓 Leçons apprises

1. **Un seul message d'erreur ≠ une seule cause** : l'IndexOutOfRange / ArgumentNullException masquaient une **pile de 5 bugs**. Le REX v0.5.4 concluait trop vite.
2. **Les variables Device (`_DQ`) ne sont PAS dans le bundle** : un POU importable ne peut pas y écrire directement → passer par variables locales du POU.
3. **Double assignement d'un output FB = crash** : en LD, 1 output = 1 cible. Le ST (`a := fb.X; b := fb.X;`) n'est pas transposable tel quel.
4. **Dichotomie systématique** : chaque test (6invar, 2networks, nocoil180, minimal) a isolé une variable. Indispensable.
5. **Oracle CODESYS = seul référentiel fiable** : exporter depuis CODESYS pour chaque pattern (jamais `Device.export`).

---

## 📎 Fichiers modifiés (fix complet)

| Fichier | Rôle |
|---|---|
| `TOOLS/ST_PLCOPENXML_GENERATOR/generator/file_discovery.py` | filtre `Bundle_*` (cause #1) |
| `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py` | coils→blocs, outputs dans bloc (causes 2-3) |
| `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py` | script oracle : localId bloc, coils locales, pas de doublon, commentaires textuels |
| `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/prg06_oracle_postprocess.py` | injection dans le bundle + ObjectId conservé |
| `TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py` | applique le postprocess |
| `TOOLS/AGENT_WORKFLOW/scripts/check_bundle_freshness.py` | vérifie le bundle frais |
| `CODE/MAIN/PRG_06_Outputs_LD.st` | outputs directs du FB (au lieu de chemins nested) |

---

## 🔗 Références

- Oracles CODESYS : `TOOLS/ST_PLCOPENXML_GENERATOR/samples_reference_codesys/PRG_06_Outputs_LD.xml`, `PRG_Oracle_Nested.xml`
- Tests dichotomiques : `CODE/CODE_Bundle_{6invar,2networks,3networks,nocoil180,minimal}.xml`
- Spec PLCopenXML : `DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md`

---

**Rédigé par** : Agent Pi (orchestrateur)  
**Validé par** : Utilisateur (import + ouverture + simulation PRG_01/PRG_06 OK)  
**Date de validation** : 2026-08-04
