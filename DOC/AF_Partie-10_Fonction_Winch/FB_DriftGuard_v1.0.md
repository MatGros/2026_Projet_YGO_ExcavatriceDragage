# Fiche Composant : FB_DriftGuard (v1.0)

> **Rôle** : Détection de dérive de position de référence sous armement (Méca A & Méca C).  
> **Catégorie** : Brique technique de sécurité (utilisée exclusivement par `FB_Safety_Winch`).  
> **Code Source** : `CODE/TREUILS/FB_DriftGuard.st`  

---

## 📐 1. Description Fonctionnelle

`FB_DriftGuard` factorise la logique de capture de position de référence et de calcul de dérive utilisée par les mécanismes de sécurité **Méca A** (dérive sous frein treuil retenue) et **Méca C** (dérive sous frein treuil benne).

Lors du passage de `Arm` à `TRUE` (contacteur au repos et frein serré) :
1. Le bloc mémorise la position exacte au premier cycle (`RefPosM`).
2. Pendant toute la durée où `Arm = TRUE`, il calcule la dérive absolue `DriftM = ABS(PositionM - RefPosM)`.
3. Si `DriftM > ToleranceM`, le signal `Violation` passe immédiatement à `TRUE`.

---

## 🔌 2. Contrat d'Interface ST

```pascal
FUNCTION_BLOCK PUBLIC FB_DriftGuard
VAR_INPUT
    Arm         : BOOL;      // Signal d'armement (ex. contacteurs au repos AND frein serré)
    PositionM   : REAL;      // Position courante mesurée par le codeur (m)
    ToleranceM  : REAL;      // Tolérance maximale de dérive autorisée (m)
END_VAR
VAR_OUTPUT
    RefPosM     : REAL;      // Position de référence capturée à l'armement (m)
    DriftM      : REAL;      // Dérive absolue courante (m)
    Violation   : BOOL;      // TRUE si dérive > tolérance pendant l'armement
END_VAR
```

---

## 🛡️ 3. Portée & Dépendances

- Le bloc ne gère pas la vitesse (la vérification de vitesse minimale est faite en parallèle par le bloc appelant `FB_Safety_Winch`).
- À la désarmement (`Arm = FALSE`), `DriftM` est réinitialisé à `0.0` et `Violation` retombe à `FALSE`.
