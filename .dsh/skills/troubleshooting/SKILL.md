---
name: troubleshooting
description: Recherche de blocage / diagnostic de panne dans le programme CODESYS. Déclencher dès que l'utilisateur demande de chercher un blocage, une panne, un bug, « pourquoi ça bloque », « pourquoi ça ne marche pas », un diagnostic, ou un troubleshooting. Crée une fiche de session dans DOC/WFLOW/TROUBLESHOOTING/ et applique la méthode d'arbre de décision + traçage inverse.
---

# 🕵️ Skill Troubleshooting — Recherche de Blocage (Excavatrice Dragage)

Méthode de diagnostic d'un blocage/bug dans le programme CODESYS, **sans exécuter le PLC** (lecture de variables de diagnostic + raisonnement par arbre de décision).

📖 **Méthode complète** : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` (à lire en entier avant de commencer).

---

## ⛔ RÈGLE D'OR

**Ne jamais modifier le code ni forcer une variable sans validation humaine explicite.**
Cause racine **prouvée par lecture de variable**, jamais par inférence seule.
🚫 **Ne JAMAIS se baser sur `Device.export`** (souvent périmé, jamais une référence de contrôle).
Sources fiables : `CODE/*.st` + `GVL_Troubleshooting`.

---

## 🚦 Déclenchement

Déclencher sur : « cherche le blocage », « pourquoi ça bloque », « pourquoi ça ne marche pas », « diagnostic », « troubleshooting », « recherche de panne », « ça ne s'active pas », « ça ne se coupe pas ».

---

## 🚨 BANNIÈRE DE DÉCLENCHEMENT (OBLIGATOIRE)

Dès que la skill est déclenchée, **afficher immédiatement** ce texte clair en majuscules (dans le terminal / les échanges), avant toute autre action :

```
========================================
🕵️ MODE DÉPANNAGE / TROUBLESHOOTING ACTIF
========================================
```

Puis annoncer en 1 ligne le sujet du diagnostic (ex. « Diagnostic : DeadmanArmed tombe à 0 en commande descente »).

---

## 📋 Procédure

### Étape 0 — Créer la fiche de session
Créer `DOC/WFLOW/TROUBLESHOOTING/TROUBLESHOOTING_<Sujet>_<AAAA-MM-JJ>.md` depuis le gabarit `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`.

### Étape 1 — Remplir le contexte figé (§1 du prompt)
Lire la fiche existante si elle existe (contexte déjà figé). Sinon, demander UNE fois : situation (banc/site), mode, bits, référencement. **Ne pas re-demander ensuite.**

### Étape 2 — Collecter les indices (§2)
6 questions max (symptôme, permanent/intermittent, changements récents, déjà essayé, conditions, alarmes). Étiqueter la force des preuves (🟢/🟡/🔴).

### Étape 3 — Caractériser le symptôme (§3)
Type de symptôme (sortie ne s'émet pas / ne se coupe pas / valeur fausse / état bloqué / intermittent / aucune réaction).

### Étape 4 — Construire l'arbre des causes (§4)
Énumérer TOUTES les branches (6 catégories). Pour chaque nœud : variable de décision + où la lire + valeur attendue. **Pour l'exhaustivité & la vitesse** : déléguer l'exploration de branches **indépendantes** à des **sous-agents** (en parallèle), chacun remontant une branche jusqu'à sa source.

### Étape 5 — Tracage inverse + élimination par preuve (§5, §6)
Remonter du symptôme à la source. Lire les variables de décision dans `GVL_Troubleshooting` (lecture seule). Éliminer les branches par FAIT. S'arrêter au critère d'arrêt (§6).

### Étape 6 — Conclure + mettre à jour la fiche
Cause racine + correction proposée. Remplir la **section 8 (Proposition de correction)** : Option 1 (immédiat, sans code) + Option 2 (définitif) + validation requise. Mettre à jour la fiche (verdicts, journal, conclusion). **Ne pas modifier le code sans validation.**

### Étape 7 — Vérification / non-régression
Après correction (validée), remplir la **section 9** : le symptôme est-il résolu ? rien d'autre cassé ? (aligné `fix:` + `guard:`).

---

## 📚 Références

- Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`
- Gabarit : `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`
- **Guide de remplissage** : `DOC/WFLOW/TROUBLESHOOTING/GUIDE_Troubleshooting.md`
- Exemple : `DOC/WFLOW/TROUBLESHOOTING/TROUBLESHOOTING_DeadmanArmed_2026-08-15.md`
- Carte de lecture : `GVL_Troubleshooting` (ContexteMachineGlobal, BenneOuvertureFermeture, Joystick, LevageUnitaireM1/M2, TranslationPontM3, AssistanceDragage)
- Ordre d'exécution : `PRG_02 → PRG_03 → PRG_04/05 → PRG_06 → PRG_07`

## ✅ Checklist de restitution

- [ ] Fiche de session créée / mise à jour dans `DOC/WFLOW/TROUBLESHOOTING/`
- [ ] Contexte figé rempli (pas de re-questions)
- [ ] Arbre des causes complet (6 catégories)
- [ ] Hypothèses éliminées par PREUVE (lecture), pas par inférence
- [ ] Cause racine + correction proposée
- [ ] Aucun code modifié / aucune variable forcée sans validation
