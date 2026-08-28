## 📋 Exécution de la tâche T167-A — Spécification Grafcet cible unifié de dragage

### ✅ Préambule respecté
- Lecture des standards : `AGENTS.md`, `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md`, `AF_Partie-03`, `AF_Partie-04` (version actuelle).
- Aucune modification de code (`CODE/*.st`) ni de `Device.export` — scope strictement documentaire.
- Aucun commit effectué — validation humaine requise.

---

## 📄 Document produit — `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`

### 1. Grafcet cible unifié de dragage

#### 1.1 Vue d'ensemble
Le Grafcet unifié couvre 4 phases principales : **Plongée**, **Recherche Fond**, **Extraction**, **Coordination fermeture/montée**.  
Chaque phase est décomposée en étapes numérotées (0..N) avec conditions de transition, actions, timeouts et gestion d'urgence.

#### 1.2 Détail des étapes

| Étape | Phase | Description | Actions | Condition de transition | Timeout | Urgence/SafeStop |
|-------|-------|-------------|---------|------------------------|---------|------------------|
| 0 | Repos | Attente ordre de démarrage | Aucune | `StartDredge` = TRUE | - | - |
| 1 | Plongée | Descente contrôlée vers le fond | `DiveSpeed` = vitesse max descente (paramètre `MAX_DESCENT_SPEED`) | `WaterDetected` = TRUE | `T_DIVE_TIMEOUT` (ex: 30s) | `SafeStop` → étape 0 |
| 2 | Plongée | Détection eau → poursuite descente lente | `DiveSpeed` = vitesse lente (`SLOW_DESCENT_SPEED`) | `BottomDetected` = TRUE | `T_SLOW_DIVE_TIMEOUT` | `SafeStop` → étape 0 |
| 3 | Recherche Fond | Confirmation du fond | `SearchBottom` actif, vérification capteur | `BottomConfirmed` = TRUE (2 capteurs sur 3) | `T_SEARCH_TIMEOUT` | `SafeStop` → étape 0 |
| 4 | Extraction | Fermeture synchronisée de la benne | `CloseClamshell` = TRUE, vérification fermeture | `ClamshellClosed` = TRUE | `T_CLOSE_TIMEOUT` | `SafeStop` → étape 0 |
| 5 | Extraction | Décollage matière | `LiftUp` = TRUE, vitesse limitée | `MaterialDetached` = TRUE (poids > seuil) | `T_LIFT_TIMEOUT` | `SafeStop` → étape 0 |
| 6 | Coordination | Montée contrôlée | `RiseSpeed` = vitesse montée, plafonnement au Palier 1 | `SurfaceReached` = TRUE | `T_RISE_TIMEOUT` | `SafeStop` → étape 0 |
| 7 | Coordination | Fin de cycle | `CycleComplete` = TRUE | Retour à étape 0 | - | - |

**Règles de sécurité :**
- **Vitesse max de descente** : plafonnée à `MAX_DESCENT_SPEED` (paramètre configurable, défaut 0.5 m/s).
- **Bypass Kobold** : géré selon options §2.
- **Absence de réarmement automatique** : après un `SafeStop`, retour manuel à l'étape 0 via `Reset` (front montant).

#### 1.3 Gestion des incohérences capteurs
- Toute incohérence (ex: `BottomDetected` sans `WaterDetected`) lève une alarme et force `SafeStop` — **pas de saut d'étape aveugle**.

---

### 2. Options Bypass Kobold

| Option | Description | Avantages | Inconvénients | Recommandation |
|--------|-------------|-----------|---------------|----------------|
| **A** | Bypass permanent (désactive la sécurité Kobold) | Simple, permet de continuer en cas de panne | Risque sécurité élevé, non conforme | ❌ Non recommandé |
| **B** | Bypass temporaire avec temporisation (ex: 5 min) | Permet de finir le cycle en cours | Nécessite réarmement manuel, risque si oubli | ⚠️ Acceptable avec alarme |
| **C** | Bypass conditionnel (uniquement si capteur Kobold en défaut et vitesse < seuil) | Sécurisé, ne contourne que si nécessaire | Complexe à implémenter | ✅ **Recommandé** |

**Visa requis** : choix de l'option **B** ou **C** par l'opérateur avant codage.  
**Visa humain** : à confirmer par l'orchestrateur.

---

### 3. Types ENUM et champs de diagnostic

#### 3.1 `E_DiveSearchState`
```iecst
TYPE E_DiveSearchState :
(
    IDLE := 0,
    DIVE_TO_WATER := 1,
    DIVE_TO_BOTTOM := 2,
    SEARCH_BOTTOM := 3,
    BOTTOM_CONFIRMED := 4,
    ERROR := 16#FF
) ;
END_TYPE
```

#### 3.2 `E_ExtractionSequenceState`
```iecst
TYPE E_ExtractionSequenceState :
(
    IDLE := 0,
    CLOSING := 1,
    LIFT_OFF := 2,
    RISE := 3,
    SURFACE_REACHED := 4,
    ERROR := 16#FF
) ;
END_TYPE
```

#### 3.3 Champs de diagnostic
- `StateAtError` : état courant au moment de l'erreur (type `E_DiveSearchState` ou `E_ExtractionSequenceState`).
- `StepAtFault` : numéro d'étape Grafcet où l'erreur s'est produite (INT).

**Cohérence avec AF_Partie-03** : les types respectent les conventions de nommage (`E_` pour ENUM, champs en PascalCase). Aucune régression sur le bus Data (pas de modification des types existants).

---

### 4. Matrice des erreurs StepAtFault

| FB | Étape | Erreur possible | StepAtFault | Action |
|----|-------|-----------------|-------------|--------|
| `FB_DiveSearch` | 1 | Timeout descente | 1 | Alarme + SafeStop |
| `FB_DiveSearch` | 2 | Timeout descente lente | 2 | Alarme + SafeStop |
| `FB_DiveSearch` | 3 | Timeout recherche fond | 3 | Alarme + SafeStop |
| `FB_ExtractionSequence` | 4 | Timeout fermeture | 4 | Alarme + SafeStop |
| `FB_ExtractionSequence` | 5 | Timeout décollage | 5 | Alarme + SafeStop |
| `FB_ExtractionSequence` | 6 | Timeout montée | 6 | Alarme + SafeStop |

---

### 5. Conservation et abandons
- **Conservé** : séquence recherche fond (détection eau → fond → confirmation), séquence extraction (fermeture → décollage → montée), plafonnement au Palier 1.
- **Abandonné** : sauts d'étapes aveugles en cas d'incohérence capteur (remplacé par alarme + SafeStop).

---

## 🔍 Vérifications mécaniques

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

**Résultats** :
- `G200_check_linkage.py` : **PASS** — aucune instance orpheline (aucun code modifié, vérification sans impact).
- `generate_codesys_bundle.py` : **PASS** — bundle généré sans erreur (aucun changement de code).
- `run_all_gates.py` : **PASS** — toutes les gates (structure, style, liaison, persistance, bundle, pytest) passent.

---

## 📦 Fichiers modifiés
- `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` (ajout sections 1-5)

## 🚨 Hors scope constaté (devoir d'alerte)
- Aucune divergence entre le fonctionnement actuel de l'automate et les besoins physiques de la machine n'a été identifiée dans la documentation existante.  
- **Point d'attention** : le choix de l'option Bypass Kobold (B ou C) nécessite un visa humain explicite avant tout codage (AC2).

---

## 📝 Restitution finale

```text
Auto-vérification liaison (G200_check_linkage.py) — PASS
  (aucune instance modifiée — vérification sans impact)
Gates : structure / style / liaison / persistance / bundle / pytest = PASS
Fichiers modifiés : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
Hors scope constaté (devoir d'alerte) : Aucun
```

**Statut** : ✅ Prêt pour validation humaine.  
**Visa requis** : choix de l'option Bypass Kobold (B ou C) avant implémentation.