# Excavatrice de Dragage — Guide Claude Code

Automate CODESYS 3.5 pour machine de dragage en carrière noyée.

---

## 🎯 **Avant de coder : LIRE CECI**

### 1. **[Convention de Nommage](DOC/NAMING_CONVENTION.md)** ← ESSENTIEL
- **PascalCase partout**, aucun hongrois (`bFlag` ❌, `iCounter` ❌)
- Préfixes : `ST_` (struct), `E_` (enum), `FB_` (function block)
- Booléens entrée = verbe (`Enable`, `Start`), sortie = état (`Ready`, `Done`)
- Suffixes unité si besoin : `_M` (mètres), `_Pct` (%), `_Ms` (ms)

### 2. **[Analyse Fonctionnelle Partie 3](DOC/AF_Partie3_Template_FB_Commun.md)** ← Contrat FB
Chaque Function Block doit respecter :
- Interface : `Enable`, `Reset`, `SafeStop`, `SafetyOk`, `Mode` (entrées)
- Sorties : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`
- `ErrorId` = bitfield (max 16 défauts)
- **Reset = front obligatoire** : cause disparue + appui reset pour effacer
- Jamais autoriser le redémarrage automatique après défaut

### 3. **[Architecture](DOC/AF_Partie2_Architecture_Programme_v2.1.md)** ← Pour comprendre
Tâches, arborescence CODESYS, flux données.

---

## 📋 **Principes Clés**

| Règle | Pourquoi |
|-------|----------|
| Sémantique > Typage | Le type se lit en déclaration, le nom parle du **rôle** |
| Reset = front | Évite réarmement accidentel, garantit conscient du défaut |
| SafeStop prioritaire | Arrêt sûr indépendant, pas bloqué par une autre erreur |
| AU physique | Bouton dur, réarmement manuel et séparé de l'acquittement IHM |
| 1 FB = 1 responsabilité | Composition > héritage, clair et maintenable |

---

## 🛠️ **Workflow Édition**

Toute modif passe par la skill **[`codesys-workflow`](.claude/skills/codesys-workflow.md)** (chargement auto) :

0. 📚 Lire règles `DOC/` + STOP si spec incomplète
1. 🔍 Comprendre architecture + devices (`Device.export`)
2. 🔬 Analyser variables / PRG / FB existants
3. 🧩 Plan **groupé par concept** → validation user
4. 💻 Code ST commenté FR + emoji + **note d'application manuelle**
5. 🔁 REX → maj specs `DOC/` versionnées `vX.X`
6. 🔄 Nouvel export user → rebouclage

⚠️ L'utilisateur applique **tout manuellement** dans CODESYS 3.5 (copie du ST).

---

## 🏗️ **Arborescence CODESYS**

```
Application (PLC_PRG)
├── _COMMON        (FB_FilterPT1, FB_Brake)
├── _TYPES         (Structures, Enums)
├── JOYSTICK       (Acquisition + traitement)
├── WINCH          (2 treuils × FB_Winch)
├── ENCODER        (Codeurs tambour)
├── TRANSLATION    (Moteur variateur)
├── BUCKET         (Cinématique godet)
├── SAFETY         (Superviseur défauts)
└── SEQUENCE       (Modes + Cycle)
```

---

## 📐 **Tâches Cadencées**

| Tâche | Priorité | Cadence | Contenu |
|-------|----------|---------|---------|
| **EtherCatTask** | 0 (haute) | Bus | Codeurs, variateur |
| **CanTask** | 1 | 10 ms | Joystick Hall |
| **MainTask** | 10 | 20 ms | Logique métier, cycle |

👉 Couche basse rafraîchit (bus) → MainTask consomme.

---

## 🔄 **Cycle de Dragage**

1. ⬇️ Descente godet ouvert
2. 🌊 Capteur fond touché
3. 🔧 Synchro 2 treuils
4. ⬆️ Remontée à vitesse variable
5. ⏱️ Égouttage temporisé
6. ↔️ Translation vers vidange
7. ⬇️ Ouverture godet (désynchro treuils)
8. 🔁 Retour position travail

---

## 📖 **Documentation Complète**

Tous les docs dans **`DOC/`** :
- [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md) — Nommage strict
- [AF_Partie1_Analyse_Fonctionnelle.md](DOC/AF_Partie1_Analyse_Fonctionnelle.md) — Équipements & fonctions
- [AF_Partie2_Architecture_Programme_v2.1.md](DOC/AF_Partie2_Architecture_Programme_v2.1.md) — Architecture détaillée
- [AF_Partie3_Template_FB_Commun.md](DOC/AF_Partie3_Template_FB_Commun.md) — Contrat FB & sécurité

---

## 🔒 **GUARDRAILS OBLIGATOIRES — AVANT TOUTE MODIF CODE/**

**Si l'utilisateur demande modification CODE/, FB_, PRG_, ou "codesys" :**

1. ✅ **Charger automatiquement** la skill `.claude/skills/codesys-workflow.md`
2. ✅ **Lire docs pertinentes** : NAMING_CONVENTION.md, AF_Partie3_Template_FB_Commun.md
3. ✅ **Vérifier spec complète** → Sinon demander clarifications
4. ✅ **Auditer conformité** : nommage PascalCase, interface FB, sécurité
5. ✅ **Tracer checklist** avant génération
6. ✅ **Refuser code non-conforme** → Ne JAMAIS approximer

**Cas d'arrêt (refuse génération) :**
- Nommage ambigu ou non-PascalCase
- Interface FB incomplète
- Reset pas sur front
- SafeStop dépendant de Enable
- Redémarrage auto après défaut
- Spec manquante/incomplète

---

### 📖 **Skill Obligatoire**

Workflow défini dans [`.claude/skills/codesys-workflow.md`](.claude/skills/codesys-workflow.md) (chargement auto).

Demande simplement :
```
Modifier FB_Joystick pour [description]
Créer nouveau FB_ pour [description]
Analyser [partie] du programme automate
```

L'IA charge les règles DOC + valide avant de générer.

---

## ✅ **Checklist Avant de Coder**

- [ ] Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)
- [ ] Lire [AF_Partie3](DOC/AF_Partie3_Template_FB_Commun.md) si nouveau FB
- [ ] Vérifier que le nom suit : **PascalCase, sémantique, sans hongrois**
- [ ] `ErrorId` = bitfield ? Reset = front obligatoire ?
- [ ] `SafeStop` prioritaire sur Enable ?

### Avant de demander modification code

1. **Décrire** : spec complète du besoin
2. **L'IA charge guardrails** : audit nommage, interface, sécurité
3. **L'IA valide** : conform spec
4. **Si doute** : signale + demande clarification
5. **Sinon** : génère code + checklist
6. **Réimporter dans CODESYS** (manuel)

---

**État du projet :** Main branch clean, documentation complète, guardrails actifs. Nouvelle procédure en cours. 🚀
