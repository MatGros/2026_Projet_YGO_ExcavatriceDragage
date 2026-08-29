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
