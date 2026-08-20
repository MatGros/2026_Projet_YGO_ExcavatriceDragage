# Fiche Composant : FB_WinchLoadEstimator (v1.0)

> **Rôle** : Estimation empirique de la charge retenue/soulevée par un treuil.  
> **Catégorie** : Brique de diagnostic & supervision informative (sans effet de commande).  
> **Code Source** : `CODE/H_TREUILS_BENNE/FB_WinchLoadEstimator.st`  

---

## 📐 1. Description Fonctionnelle

`FB_WinchLoadEstimator` croise le **palier de vitesse commandé** (1..5) et la **bande de vitesse mesurée réelle** (1..5) avec une table matricielle 2D empirique (`ST_WinchLoadEstimateTable`) pour estimer le pourcentage de charge du treuil.

Il permet à l'opérateur sur l'IHM d'avoir un retour visuel informatif du taux d'effort, notamment au démarrage et en montée.

---

## 🔌 2. Contrat d'Interface ST

```pascal
FUNCTION_BLOCK PUBLIC FB_WinchLoadEstimator
VAR_INPUT
    Enable                 : BOOL;                        // Activation de l'estimateur
    Reset                  : BOOL;                        // Acquit défaut
    PowerContactorEngaged  : BOOL;                        // Puissance engagée
    Mode                   : E_Mode;                      // Mode de fonctionnement
    ActiveSpeedStep        : INT;                         // Palier commandé (0..5)
    MeasuredSpeedMps       : REAL;                        // Vitesse mesurée (m/s)
    MeasuredSpeedSignedMps : REAL;                        // Vitesse signée (positive = montée)
    SpeedConfig            : ST_WinchSpeedConfig;         // Configuration des plages de vitesse
    LoadTable              : ST_WinchLoadEstimateTable;   // Table d'estimation 5x5
END_VAR
VAR_OUTPUT
    Ready                  : BOOL;
    Busy                   : BOOL;
    Done                   : BOOL;
    Error                  : BOOL;
    ErrorId                : WORD;                        // bit0 : table non configurée ou invalide
    State                  : E_State;
    StateAtError           : E_State;
    SpeedBand              : INT;                         // Bande de vitesse courante (0..5)
    EstimatedLoadPct       : REAL;                        // Estimation de la charge (0..100 %)
    Configured             : BOOL;                        // TRUE si la table a été validée
    Ascending              : BOOL;                        // TRUE uniquement en montée mesurée
END_VAR
```

---

## 🛡️ 3. Règle Métier & Sécurité

- **Informatif pur** : Cette estimation n'est jamais utilisée par les blocs `FB_Safety_Winch` ni `FB_WinchOutputInterlock`.
- **Montée uniquement** : L'estimation de charge n'est active que si `MeasuredSpeedSignedMps > 0` (montée). En descente ou à l'arrêt, `EstimatedLoadPct` est maintenu à 0.0 %.
