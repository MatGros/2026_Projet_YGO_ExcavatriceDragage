# 📑 INDEX — Système Guardrails CODESYS

**Tous les fichiers du système de validation automatique.**

---

## 🎯 Pour commencer (2 min)

→ **[QUICK_START_CODESYS.md](QUICK_START_CODESYS.md)**

```
1. Extraire CODE
2. Demander modif (guardrails auto-chargés)
3. Valider avant injection
4. Réinjecter
```

---

## 📚 Documentation

| Fichier | Contenu |
|---------|---------|
| **[CLAUDE.md](../CLAUDE.md)** | Instructions projet + guardrails obligatoires |
| **[QUICK_START_CODESYS.md](QUICK_START_CODESYS.md)** | Workflow rapide (2 min) |
| **[guardrails-codesys.md](guardrails-codesys.md)** | Règles strictes + checklist complète |
| **[codesys-code-skill.md](codesys-code-skill.md)** | Documentation SKILL détaillée |
| **[SKILL-CODESYS-CODE.md](SKILL-CODESYS-CODE.md)** | Vue d'ensemble architecture |
| **[README-SKILL-CODESYS.md](README-SKILL-CODESYS.md)** | Guide complet utilisateur |

---

## 🛠️ Outils

| Fichier | Usage |
|---------|-------|
| **[tools/check-codesys-code.py](../tools/check-codesys-code.py)** | Audit validation avant injection |
| **[tools/extract.py](../tools/extract.py)** | Extraire CODE depuis CODESYS |
| **[tools/inject.py](../tools/inject.py)** | Réinjecter dans Device.export |

---

## 🔐 Guarantees

```
✓ Nommage PascalCase obligatoire
✓ Interface FB complète (Enable, SafeStop, ErrorId, etc.)
✓ Reset sur front obligatoire
✓ SafeStop prioritaire
✓ Pas de redémarrage auto après défaut
✓ Doutes signalés explicitement
✓ Code non-conforme refusé
```

---

## 🚀 Workflow Standard

### Avant chaque modification CODE/ :

```bash
# 1. Extraire
python tools/extract.py --clean

# 2. Demander (guardrails auto-chargés par Claude)
# Dans Claude Code: "Modifier FB_Joystick pour..."

# 3. Valider sortie
python tools/check-codesys-code.py CODE/FB_*.xml

# 4. Réinjecter
python tools/inject.py

# 5. Réimporter CODESYS (manuel)
```

---

## 📋 Checklist Conformité

Tracée automatiquement avant génération :

```
NOMMAGE
  ☐ PascalCase ?
  ☐ Sémantique ?
  ☐ Préfixes (ST_, E_, FB_) ?
  ☐ Suffixes unité si besoin ?

INTERFACE FB
  ☐ Entrées complètes ?
  ☐ Sorties complètes ?
  ☐ ErrorId bitfield ?
  ☐ Reset sur front ?
  ☐ SafeStop prioritaire ?

LOGIQUE
  ☐ 1 responsabilité ?
  ☐ État machine ?
  ☐ Pas d'auto-restart ?

SÉCURITÉ
  ☐ SafeStop indépendant ?
  ☐ Arrêt défaut séparé reset ?
  ☐ AU physique ?
```

---

## 🎓 Apprentissage

**Lire dans cet ordre :**

1. **QUICK_START_CODESYS.md** (5 min) — Vue d'ensemble
2. **CLAUDE.md** (10 min) — Règles projet
3. **guardrails-codesys.md** (15 min) — Détails guardrails
4. **DOC/NAMING_CONVENTION.md** (10 min) — Nommage
5. **DOC/AF_Partie3_Template_FB_Commun.md** (20 min) — Interface FB

---

## 🔧 Configuration

| Fichier | Rôle |
|---------|------|
| **.claude/settings.local.json** | Permissions + configuration |
| **.claude/CLAUDE.md** | Instructions project (auto-loaded) |

---

## ✅ État

- ✅ Guardrails créés et documentés
- ✅ Validation Python opérationnelle
- ✅ Instructions Claude intégrées
- ✅ SKILL documentée
- ✅ Workflow automatisé

---

**Version :** 1.0  
**Dernière MAJ :** 2026-06-30  
**Status :** 🚀 Opérationnel et prêt à l'emploi
