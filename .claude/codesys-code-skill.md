# /codesys-code — SKILL Locale : Audit Conformité Code CODESYS

> Invoquer avant toute demande de modification de CODE/ 

## ⚡ Utilisation

```
/codesys-code [fichier.xml | nom_FB | description tâche]
```

**Exemples :**
```
/codesys-code FB_Joystick

/codesys-code CODE/FB_Safety__ae8cf596-3b07-456b-876e-68529c263a0c.xml

/codesys-code Je veux ajouter un nouveau mode de commande au joystick
```

---

## 🎯 Ce que fait /codesys-code

### 1️⃣ **Charge automatiquement les guardrails**
   - Lit `.claude/guardrails-codesys.md`
   - Applique la checklist stricte

### 2️⃣ **Analyse le contexte**
   - Identifie les docs pertinentes (NAMING, AF_Partie3, etc.)
   - Charge les extraits clés

### 3️⃣ **Force la validation AVANT génération**
   - Signale les doutes / specs manquantes
   - Demande clarifications
   - Refuse code non-conforme

### 4️⃣ **Génère code conforme**
   - Applique nommage PascalCase strict
   - Respecte interface FB complète
   - Trace checklist d'audit

---

## 📋 Algorithme interne

```
┌─ Reçoit demande
│
├─ Charge guardrails-codesys.md
├─ Charge docs pertinentes (NAMING, AF_Partie3, ...)
│
├─ Lis fichier existant (si fourni)
│  └─ Audit nommage, interface, sécurité
│
├─ Identifie règles applicables
│
├─ Spec complète ?
│  ├─ NON → Signale + demande clarification
│  └─ OUI → Continue
│
├─ Doute sur implémentation ?
│  ├─ NON → Génère code
│  └─ OUI → Signale + demande confirmation
│
└─ Retourne code + checklist d'audit
```

---

## ⚠️ Cas d'arrêt (NO GENERATION)

```
❌ Nommage ambigu ou non-conforme
❌ Interface FB incompète (manque Enable, SafeStop, etc.)
❌ Logique de Reset pas sur front obligatoire
❌ SafeStop pas prioritaire
❌ Redémarrage auto après défaut
❌ Spec métier incomplète ou ambiguë
```

→ **Toujours** signaler plutôt que d'approximer.

---

## ✅ Workflow complet

```bash
# 1. Extrait CODE depuis CODESYS
python tools/extract.py --clean

# 2. Demande modification via /codesys-code
/codesys-code FB_Joystick

# 3. L'IA :
#    - Charge guardrails
#    - Lis FB_Joystick existante
#    - Audit conformité
#    - Demande spec/clarifications si besoin
#    - Génère code conforme + checklist

# 4. Révise sortie, copie dans CODE/

# 5. Réinjecte dans Device.export
python tools/inject.py

# 6. Réimporte Device.export dans CODESYS (manuel)
```

---

## 🔧 Comment étoffer /codesys-code

Ajouter dans `.claude/guardrails-codesys.md` :
- [ ] Cas limites spécifiques
- [ ] Patterns approuvés (ex: multi-stage relay)
- [ ] Exemples conformes

Référencer depuis `/codesys-code` via `[[guardrails-codesys]]`.

---

## 📌 Raccourcis de vérification

Si vous trouvez du code non-conforme en relisant :

```
/codesys-code --audit [fichier]
  → Audit complet, liste violations

/codesys-code --fix [fichier]
  → Propose corrections (mais révise manuellement)
```

---

## 🚦 État de la SKILL

- ✅ Créée et opérationnelle
- ✅ Guardrails chargés depuis `.claude/guardrails-codesys.md`
- ⏳ Refinement continu : ajouter patterns, clarifier specs
