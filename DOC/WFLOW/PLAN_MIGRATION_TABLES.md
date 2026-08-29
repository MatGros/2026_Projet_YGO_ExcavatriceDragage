# PLAN — Migration des tableaux AF vers les formats de templates figés

> **Statut** : actif — 2026-08-29
> **Contexte** : les 4 templates sont figés et validés (subagent indépendant PASS) :
> `AF_SPEC_TEMPLATE`, `FB_SPEC_TEMPLATE`, `AF_ARCHITECTURE_PROGRAMME_TEMPLATE`, `AF_FICHE_PRG_TEMPLATE`.
> Format cible : HTML rigide (colgroup, IDs verticaux, TC couvrants horizontaux, police 14px/11.5px).

## 🎯 Objectif

Migrer les tableaux de **toutes** les fiches AF vers les formats de templates, **par type de document**,
en 3 phases. Chaque lot est vérifié et présenté pour validation humaine.

## 🗂️ Types de documents (par template)

| Template | Documents concernés |
|---|---|
| `AF_SPEC_TEMPLATE` | Fiches principales `AF_Partie-XX_*.md` (AF-01 à -14) |
| `FB_SPEC_TEMPLATE` | Sous-fiches `AF_Partie-XX_*/FB_*.md` |
| `AF_ARCHITECTURE_PROGRAMME_TEMPLATE` | `AF_Partie-02_Architecture_Programme_v3.2.md` |
| `AF_FICHE_PRG_TEMPLATE` | `AF_Partie-02_Architecture_Programme/AF_Fiche_PRG_*.md` |

## 🔄 Phase 1 — MISE EN PAGE seule (lossless)

Pour chaque type de document, dans l'ordre (AF_SPEC → FB_SPEC → AF_ARCHITECTURE → AF_FICHE_PRG) :

1. **Table des fonctions** : convertir au format HTML du template (colgroup 40/140/calc/110/50/90/50/40,
   ID vertical, TC couvrants horizontal, police 14px/11.5px). Supprimer les colonnes inutiles.
2. **Table des points de validation** : convertir au format HTML du template (colgroup 28/50/calc/45/26/36,
   ID vertical, police 14px/11.5px). Supprimer la colonne Preuve.
3. **SANS changer le contenu** : ne pas réécrire les libellés, ne pas inventer d'étapes, ne pas modifier
   les valeurs. Migration purement de mise en page (lossless).

## 🔍 Phase 2 — REVUE (perte de données)

- Vérifier via l'**historique Git** qu'aucune donnée n'a été perdue (comparer le contenu avant/après).
- Vérifier la conformité au format des templates (subagent indépendant).
- Vérifier l'encodage (pas de mojibake).

## 🧪 Phase 3 — REFORMATAGE DU CONTENU (agents experts)

Avec des agents experts en **automatisme industriel / sécurité machine (ISO 13849) / tests** :

- Vérifier et enrichir les tests dans les tables des points de validation.
- Structure de tests requise :
  1. **Test global nominal** (cycle complet sans perturbation).
  2. **Test avec défaut classique** (panne réaliste qui peut arriver).
  3. **Tests granulaires** (cas limites, fronts, timeouts, bascules de mode).

## 📦 Livrables

- Chaque lot de migration (par type de document) vérifié et présenté.
- Revue de perte de données (Phase 2).
- Contenu des tests reformaté et validé (Phase 3).
- Validation humaine finale.

---

## 🗓️ Journal d'exécution

### P1 — MISE EN PAGE (~achevée)

| Lot | Périmètre | Commits | Contrôle |
|---|---|---|---|
| Fiches AF mains (AF-01..14) | Table fonctions HTML + Points de validation HTML/macro + titres « (non détaillé) » | `38275611` (01-03), `b8808005` (04-14), `da70b09b` (macro 6 cols AF-13/14), `43f760ee` (état NV AF-14) | sweep 14/14 : 0 ligne vide, tags équilibrés, 0 mojibake |
| Fiches FB (28/33) | Points de validation HTML (contenu verbatim) + légendes État réparées | `da05c3a9`, `64e37f6c`, `7f027f13`, `58ed9f7b`, `10e6d738` | 105 TC convertis, sweep orchestrateur par lot (th/td/blank/tags) |
| Fiche PRG-02 | HTML 3 cols, colonne Preuve supprimée (acté) | `7f027f13` | — |
| Pas de tableau TC | FB_DriftGuard, FB_SpeedStep, FB_WinchLoadEstimator, FB_Winch_Symmetry, FB_Diag_CanOpen | — | rien à convertir |

### P2 — REVUE anti-perte (✅ soldée)

- Méthode : comparaison ensembliste AVANT (`git show` markdown) / APRÈS (HTML déséchappé) sur 40 fichiers, 3983→4020 cellules.
- Verdict : 33/40 PASS strict ; pertes toutes actées (Preuve PRG-02, `V-I`→`NV` AF-14, liens AF-10) **ou restaurées** — 9 raccourcis de libellés (AF-11/12/13) restaurés verbatim (`5140b0d4`), vérifiés Select-String, matrice régénérée. **0 perte non actée.**

### 🔧 Régression consommateur détectée & corrigée (`56d36a43`)

- `extract_functions_matrix.py` ne lisait que le markdown → extraction **vide** après P1 (matrice de traçabilité, viewer, G450 coupés).
- Fix : parseur HTML (gabarits) + markdown ; garde-fou unitaire `test_extract_sections_html_tables` ; matrice `af_traceability_matrix.yaml` régénérée (diff sémantique : 0 perte, rafraîchissement d'artefact).
- Tests consommateurs : 7/7 PASS.

### P3-0 — typographie/gabarit (en cours, sous-agents)

- a) 33 fiches FB : titre gabarit `🧪 Table des points de validation (détail)` (déplacement du suffixe « propriétaire unique » en note, jamais perdu), entêtes `Etat`→`État`, légendes manquantes, table fonctions de `FB_Acquisition_Preflight` → HTML.
- b) PRG-02 au gabarit `AF_FICHE_PRG` + cohérence titres/emoji des fiches AF mains.
- Garde : regex consommateurs (`Points de validation`) et extracteur (`etat`/`état`) restent satisfaits.

## 🔒 Règles verrouillées pour P3 (fond)

1. **ID TC intouchables** : jamais renommer/déplacer un ID existant (`TC-Pxx-NNN`, suffixes `.n`) — la matrice de traçabilité et G450 en dépendent. La granularisation crée des IDs suffixés nouveaux (`.N+1`).
2. **Anti-duplication** : le détail des TC vit dans la fiche FB (propriétaire unique) ; les chapôs AF gardent des macro-tables.
3. **Pipeline obligatoire après chaque lot** : `extract_functions_matrix.py` + tests consommateurs 7/7 + regen matrice + sweep d'orchestrateur + `G340_check_doc_links.py` + commit restreint. Le reformatage fond passe TOUJOURS par des agents experts avec lecture du diff par l'orchestrateur.
4. **Grille de tests par TC** : nominal (cycle complet) → défaut classique (panne réaliste) → granulaires (fronts, timeouts, cas limites, bascules de mode) ; lecteur ISO 13849/DSEAR-style sur les TC safety ; aucune validation de complaisance.
5. **Jamais de push** sans relecture du diff par l'humain et accord explicite.
