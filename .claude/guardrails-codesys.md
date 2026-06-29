# ⚔️ GUARDRAILS CODESYS — Avant tout modification de code

## 🔴 RÈGLES STRICTES (No Exceptions)

### 1. **Nommage**
- [ ] **PascalCase partout** (aucun `snake_case`, aucun hongrois `iCounter`, `bFlag`)
- [ ] Préfixes : `ST_` struct, `E_` enum, `FB_` function block
- [ ] Entrées booléen = verbe (`Enable`, `Start`), sorties = état (`Ready`, `Done`)
- [ ] Suffixes unité si ambigu : `_M` (mètres), `_Pct` (%), `_Ms` (ms)

### 2. **Interface FB (AF_Partie3_Template_FB_Commun.md)**
- [ ] **Entrées** : `Enable`, `Reset`, `SafeStop`, `SafetyOk`, `Mode`
- [ ] **Sorties** : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`
- [ ] `ErrorId` = bitfield (max 16 défauts)
- [ ] **Reset sur front obligatoire** : cause disparue + appui reset pour effacer
- [ ] **Jamais redémarrage auto** après défaut

### 3. **Sécurité**
- [ ] `SafeStop` prioritaire sur `Enable`
- [ ] Bouton AU physique (réarmement manuel séparé de l'acquittement IHM)
- [ ] Test séparé : "le défaut est-il disparu ?" AVANT réarmement auto

### 4. **Code Quality**
- [ ] Pas de commentaire inutile (seule exception : **pourquoi** non-évident)
- [ ] Sémantique > typage (le nom doit parler du rôle)
- [ ] 1 FB = 1 responsabilité

---

## ✅ AVANT CHAQUE MODIFICATION

```
1. [ ] Lis la doc pertinente (NAMING_CONVENTION.md, AF_Partie3)
2. [ ] Identifie les règles qui s'appliquent
3. [ ] Compris la spec complète OU SIGNALE si manque
4. [ ] Trace la checklist ci-dessous
5. [ ] Génère le code
6. [ ] Relis : respecte checklist ?
```

---

## ⚠️ SI DOUTE OU SPEC MANQUANTE

**ARRÊTE.** Ne génère PAS de code approximatif.

Signale à l'utilisateur :
```
❌ Doute détecté : [description]
   → Besoin clarification : [question précise]
   → Référence doc : [chemin]
```

---

## 🧠 Checklist de conformité (copie avant commit)

```
Code à examiner : [fichier / fonction]

NOMMAGE
  [ ] PascalCase ? (pas snake_case, pas hongrois)
  [ ] Sémantique ? (le nom décrit le rôle)
  [ ] Préfixes corrects ? (ST_, E_, FB_)
  [ ] Suffixes unité si besoin ?

INTERFACE FB (si applicable)
  [ ] Entrées : Enable, Reset, SafeStop, SafetyOk, Mode ?
  [ ] Sorties : Ready, Busy, Done, Error, ErrorId, State ?
  [ ] ErrorId bitfield ? (16 bits max)
  [ ] Reset sur front ? (pas auto-reset)
  [ ] SafeStop prioritaire ?

LOGIQUE
  [ ] 1 responsabilité ?
  [ ] État machine claire ?
  [ ] Pas de redémarrage auto après défaut ?

CODE
  [ ] Commentaires = "pourquoi", pas "quoi" ?
  [ ] Pas d'abstraction prématurée ?
  [ ] Pas d'error-handling inutile ?

SÉCURITÉ
  [ ] SafeStop indépendant ?
  [ ] Défaut → arrêt, puis reset manuel ?
```

---

## 📚 Docs pertinentes

| Besoin | Doc |
|--------|-----|
| Nommage général | `NAMING_CONVENTION.md` |
| Contrat FB (interface, sécurité) | `AF_Partie3_Template_FB_Commun.md` |
| Architecture tâches | `AF_Partie2_Architecture_Programme_v2.1.md` |
| Contexte métier | `AF_Partie1_Analyse_Fonctionnelle.md` |

---

## 🚀 À faire AVANT de demander modification

```bash
# Extrait CODE depuis CODESYS
python tools/extract.py --clean

# Édite dans VS Code
# → Passe CODE/ à l'IA avec checklist
# → L'IA valide + applique guardrails
# → L'IA génère ou SIGNALE les doutes

# Réinjecte (GUID-protected, backup auto)
python tools/inject.py

# Réimporte Device.export dans CODESYS (manuel)
```
