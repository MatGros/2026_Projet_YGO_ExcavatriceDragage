# Fiche Composant : FB_SpeedStep (v1.0)

> **Rôle** : Décodeur de consigne de vitesse analogique (0..100 %) vers les 4 contacteurs de palier discrets d'un treuil.
> **Catégorie** : Brique technique de commande mouvement (composée à l'intérieur de `FB_Winch`).
> **Code Source** : `CODE/H_TREUILS_BENNE/FB_SpeedStep.st`

---

## 📐 1. Description Fonctionnelle

`FB_SpeedStep` convertit une consigne de vitesse continue (% rampée par le joystick ou le cycle) en ordres discrets pour les 4 contacteurs de résistances d'un treuil (Paliers 1 à 5).

Chaque treuil dispose de sa propre instance et de sa propre table de réglage (`ST_SpeedStepTable`).
Le bloc intègre :
1. **Sélection par hystérésis** (`Util.HYSTERESIS`) pour éviter les battements de contacteurs au franchissement des seuils.
2. **Plafonnement dynamique** (`MaxStepNumber`, 1..5) permettant de restreindre le palier maximal (ex. descente sous charge).
3. **Garde-fou vitesse mesurée** (`SpeedGuardEnable`, `MeasuredSpeedBand`) qui empêche le passage aux paliers supérieurs si la vitesse réelle câble n'a pas atteint le palier intermédiaire (évite de faire caler/disjoncter les moteurs en charge).
4. **Validation de table & Sécurité** : Vérification de la stricte croissance des seuils. En cas de table invalide, les sorties sont neutralisées et `ConfigError` passe à `TRUE`.

---

## 🔌 2. Contrat d'Interface ST

```pascal
FUNCTION_BLOCK PUBLIC FB_SpeedStep
VAR_INPUT
    Enable            : BOOL;               // FALSE = Treuil à l'arrêt (Palier 0, tous contacteurs FALSE)
    SpeedTgt_Pct       : REAL;                // Consigne vitesse 0..100 % rampée
    Table             : ST_SpeedStepTable;   // Table de réglage des 5 paliers propre au treuil
    HystMargin        : REAL := 2.0;         // Marge anti-battement (% consigne)
    MaxStepNumber     : INT := 5;            // Plafond de palier autorisé (1..5)
    MeasuredSpeedBand : INT := 0;            // Palier correspondant à la vitesse mesurée réelle
    SpeedGuardEnable  : BOOL := FALSE;       // Activation du garde-fou vitesse mesurée
    SpeedGuardReady   : BOOL := FALSE;       // Signal de stabilité vitesse
END_VAR
VAR_OUTPUT
    Contactor1        : BOOL;                // Commande contacteur de vitesse 1
    Contactor2        : BOOL;                // Commande contacteur de vitesse 2
    Contactor3        : BOOL;                // Commande contacteur de vitesse 3
    Contactor4        : BOOL;                // Commande contacteur de vitesse 4
    StepNumber        : INT;                 // N° de palier actif (0 = arrêt, 1..5)
    SpeedGuardLimited : BOOL;                // TRUE si le palier demandé a été bridé par le garde-fou
    ConfigError       : BOOL;                // TRUE si la table de configuration est invalide
    ConfigErrorId     : WORD;                // Code d'erreur de configuration (bit0 = table invalide)
END_VAR
```

---

## 🧱 3. Table de Configuration (`ST_SpeedStepTable`)

La structure `ST_SpeedStepTable` définit pour chaque palier (1 à 5) :
- Les seuils de vitesse de montée/descente de palier (en %).
- Les états booléens des contacteurs `P1R1..P1R4` jusqu'à `P5R1..P5R4`.

---

## 🛡️ 4. Règles de Sécurité

- Si `Enable = FALSE` ou `ConfigError = TRUE` : `Contactor1..4 := FALSE`, `StepNumber := 0`.
- Le palier 1 autorise l'état tout `FALSE` (résistances de démarrage insérées).
