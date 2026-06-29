# ⚡ QUICK START — Système Guardrails CODESYS

**L'IA charge automatiquement les guardrails. Tu demandes, elle valide.**

---

## 🚀 Utilisation (Super simple)

### 1. Extrait depuis CODESYS
```bash
python tools/extract.py --clean
```

### 2. Demande modification (guardrails auto-chargés)
```
Ajouter entrée "Gain" au FB_Filter_PT1
```
Ou :
```
Créer un nouveau FB_Rampe pour commands variateur
```
Ou :
```
Modifier FB_Joystick pour support nouveau stick
```

### 3. L'IA fait automatiquement :
- ✅ Charge `.claude/guardrails-codesys.md`
- ✅ Lis docs pertinentes
- ✅ Audit conformité
- ✅ Demande clarifs si besoin
- ✅ Génère code conforme + checklist

### 4. Valide avant injection
```bash
python tools/check-codesys-code.py "CODE\FB_*.xml"
```

### 5. Réinjecte
```bash
python tools/inject.py
```

### 6. Réimporte CODESYS (manuel)

---

## 📋 Ce qui est garanti

```
✓ Nommage PascalCase (pas hongrois, pas snake_case)
✓ Interface FB complète (Enable, SafeStop, ErrorId, etc.)
✓ Reset sur front obligatoire
✓ SafeStop prioritaire
✓ Pas de redémarrage auto
✓ Doutes signalés explicitement
✓ Code non-conforme refusé
```

---

## ❌ L'IA refusera si :

```
✗ Nommage non-PascalCase
✗ Interface FB incomplète
✗ Reset pas sur front
✗ SafeStop dépendant Enable
✗ Auto-restart après défaut
✗ Spec manquante/incomplète
```

→ L'IA **signale + demande clarification**

---

## 📚 Docs

- **Guardrails complets** : `.claude/guardrails-codesys.md`
- **Script validation** : `tools/check-codesys-code.py`
- **Instructions Claude** : `CLAUDE.md` (section "GUARDRAILS OBLIGATOIRES")
- **Guide détaillé** : `.claude/README-SKILL-CODESYS.md`

---

## 💡 Exemples

### ✅ Demandes CORRECTES

```
Modifier FB_Winch pour ajouter limite de courant
```
→ L'IA charge guardrails, audite, génère

```
Créer FB_Temporisation pour gestion égouttage
```
→ L'IA demande: durée? type temporizateur? puis génère

```
Ajouter mode manuel au cycle de dragage
```
→ L'IA audit architecture, propose interface

---

## 🎯 Workflow complet (1 modification)

```bash
# 1. Extraire
python tools/extract.py --clean

# 2. Demander modif (dans Claude Code)
# "Ajouter entrée Gain à FB_Filter_PT1"

# 3. L'IA valide + génère automatiquement

# 4. Valider avant injection
python tools/check-codesys-code.py CODE/FB_Filter_PT1*.xml

# 5. Réinjecter
python tools/inject.py

# 6. Réimporter CODESYS
```

---

**État :** ✅ Opérationnel  
**Version :** 1.0  
**Garantie :** Code généré 100% conforme aux règles
