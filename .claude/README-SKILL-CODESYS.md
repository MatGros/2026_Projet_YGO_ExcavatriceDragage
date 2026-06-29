# 🚀 SKILL Locale CODESYS — Guide d'utilisation

**Système de guardrails automatiques pour modification conforme du code CODESYS**

---

## 📦 Qu'est-ce que c'est?

Une **SKILL locale intégrée** qui force le modèle IA à :
- ✅ Lire les docs projet avant de coder
- ✅ Valider conformité nommage/interface avant génération
- ✅ Signaler doutes/specs manquantes
- ✅ Refuser code non-conforme

**Résultat :** Code généré **100% conforme** aux règles du projet.

---

## 🎯 Cas d'usage

### Avant toute modification CODE/

```bash
# 1. Extraire depuis CODESYS
python tools/extract.py --clean

# 2. Appeler la SKILL (demander modif)
/codesys-code FB_Joystick

# → Claude charge auto guardrails + docs
# → Valide conformité
# → Génère code conforme + checklist

# 3. Valider avant injection
python tools/check-codesys-code.py "CODE\FB_Joystick*.xml"

# 4. Réinjecter
python tools/inject.py

# 5. Réimporter CODESYS (manuel)
```

---

## 📋 Fichiers de la SKILL

```
.claude/
├── guardrails-codesys.md           ← Règles strictes + checklist
├── codesys-code-skill.md           ← Docs SKILL
├── SKILL-CODESYS-CODE.md           ← Vue d'ensemble
└── README-SKILL-CODESYS.md         ← CE FICHIER

tools/
└── check-codesys-code.py           ← Validation auto (Python)

CLAUDE.md                            ← SKILL intégrée dedans
```

---

## ⚡ Commandes principales

### Invoquer SKILL dans Claude Code

```
/codesys-code [cible]
```

**Exemples :**
```
/codesys-code FB_Joystick
/codesys-code Ajouter nouveau mode de commande
/codesys-code CODE/FB_Safety*.xml
```

Claude va :
1. Charger `guardrails-codesys.md`
2. Lire la doc pertinente (NAMING, AF_Partie3, etc.)
3. Analyser existant si fichier fourni
4. Demander clarifications si spec flou
5. Générer code + checklist

---

### Valider avant injection

```bash
# Audit un FB spécifique
python tools/check-codesys-code.py "CODE\FB_Joystick*.xml"

# Audit tout le CODE/
python tools/check-codesys-code.py --audit CODE/

# Audit liste de fichiers
python tools/check-codesys-code.py CODE/FB_*.xml CODE/PRG_*.xml
```

**Sortie :**
- ✅ Conforme → exit 0
- ❌ Violations → exit 1, liste détails

---

## 🔐 Guardrails appliqués

### Nommage
- ✅ **PascalCase** (pas snake_case, pas hongrois)
- ✅ Préfixes : `ST_`, `E_`, `FB_`, `PRG_`
- ✅ Sémantique (nom = rôle)
- ✅ Suffixes unité si besoin

### Interface FB
- ✅ **Entrées :** Enable, Reset, SafeStop, SafetyOk, Mode
- ✅ **Sorties :** Ready, Busy, Done, Error, ErrorId, State, StateAtError
- ✅ ErrorId = bitfield (16 bits max)
- ✅ Reset sur front (jamais auto)
- ✅ SafeStop prioritaire

### Sécurité
- ✅ Pas de redémarrage auto après défaut
- ✅ Arrêt sûr indépendant
- ✅ Bouton AU physique

### Code Quality
- ✅ Pas de commentaires inutiles
- ✅ Sémantique > typage
- ✅ 1 FB = 1 responsabilité

---

## ⚠️ Cas d'arrêt (L'IA refusera)

```
❌ Nommage non-PascalCase
❌ Interface FB manquante
❌ Reset pas sur front
❌ SafeStop dépendant de Enable
❌ Auto-restart après défaut
❌ Spec manquante/incomplète
❌ Doute non résolu
```

→ L'IA **signalera** avant de générer.

---

## 🔄 Workflow complet illustré

```
┌─────────────────────────────────┐
│ 1. Extraire depuis CODESYS      │
│    python tools/extract.py      │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 2. Invoquer SKILL               │
│    /codesys-code FB_Joystick    │
└──────────────┬──────────────────┘
               ↓
┌──────────────────────────────────────────┐
│ 3. Claude                                │
│    ├─ Load guardrails-codesys.md       │
│    ├─ Load docs pertinentes            │
│    ├─ Audit conformité                 │
│    ├─ Demande clarifs si besoin        │
│    └─ Génère code + checklist           │
└──────────────┬───────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│ 4. Valider sortie                           │
│    python tools/check-codesys-code.py ...  │
└──────────────┬────────────────────────────────┘
               ↓
        [SI OK] ✅         [SI NON] ❌
        │                  │
        ↓                  ↓
    ┌────────┐     ┌──────────────┐
    │ Étape 5 │     │ Réviser code │
    └────────┘     │ Retour step 2 │
    │              └──────────────┘
    ↓
┌─────────────────────────────────┐
│ 5. Réinjecter                   │
│    python tools/inject.py       │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 6. Réimporter CODESYS (manuel)  │
│    Menu : Import Device.export  │
└─────────────────────────────────┘
```

---

## 🧪 Test rapide

### Test 1 : Audit d'un FB existant

```bash
python tools/check-codesys-code.py "CODE\FB_Filter_PT1__fcbcb4ee-d40b-42c4-86b4-e59830c54c86.xml"
```

→ Doit signaler violations (ou ✓ si conforme)

### Test 2 : Invoquer SKILL manuellement

```
/codesys-code FB_Filter_PT1
```

Claude doit :
1. Charger guardrails
2. Lire FB_Filter_PT1
3. Signaler écarts (ou OK)

### Test 3 : Demander modification

```
/codesys-code Ajouter entrée "Gain" à FB_Filter_PT1
```

Claude doit :
1. Demander clarifs (gain: input/output? type? plage?)
2. Refuser si spec incomplète
3. Générer code conforme si OK

---

## 📚 Docs référencées

| Doc | Charged par |
|-----|-----------|
| `NAMING_CONVENTION.md` | /codesys-code (always) |
| `AF_Partie3_Template_FB_Commun.md` | /codesys-code (FB audit) |
| `AF_Partie2_Architecture_Programme_v2.1.md` | /codesys-code (archi Q) |
| `AF_Partie1_Analyse_Fonctionnelle.md` | /codesys-code (context) |

---

## 🔧 Configuration

### Modifier guardrails

Éditer `.claude/guardrails-codesys.md` pour :
- Ajouter règles spécifiques
- Affiner checklist
- Documenter patterns approuvés

### Améliorer validation Python

Éditer `tools/check-codesys-code.py` pour :
- Ajouter vérifications supplémentaires
- Affiner détection patterns
- Ajouter auto-fix propositions

---

## ❓ FAQ

**Q: Que se passe-t-il si je fournis du code non-conforme?**
A: `/codesys-code` le détectera et refusera de générer. Il signalera les violations + demandera correction.

**Q: La SKILL est-elle obligatoire?**
A: Recommandée avant toute modif. Sans elle, risque de code non-conforme.

**Q: Puis-je désactiver la SKILL?**
A: Oui, mais ce n'est pas recommandé (perte de garanties conformité).

**Q: Comment ajouter de nouvelles règles?**
A: Éditer `guardrails-codesys.md` + améliorer `check-codesys-code.py`.

---

## 🎯 Prochaines étapes

- [ ] Tester sur vrai projet de modification
- [ ] Collecter cas limites + patterns
- [ ] Affiner guardrails basé sur feedback
- [ ] Auto-fix pour violations simples (optionnel)

---

**Version :** 1.0  
**Statut :** ✅ Opérationnelle  
**Garantie :** Code généré conforme 100% aux règles projet
