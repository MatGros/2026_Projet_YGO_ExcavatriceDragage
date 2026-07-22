# 📐 Analyse Fonctionnelle — Partie 11 : Translation M3 (v1.10)

> Complément fonctionnel à `AF_Partie-11_Fonction_Translation_v1.9.md`.
> Les règles et interfaces non modifiées restent celles de v1.9.

## 🆕 Sous-mode positionneur en maintenance

En `MAINT_N1` ou `MAINT_N2`, l'opérateur choisit explicitement le sous-mode avec
`GVL_IHM.M3Translation.PositioningSelect` :

| `PositioningSelect` | Sous-mode | `SelectedTargetNum` | Arrêt |
|---|---|---|---|
| `FALSE` | Jog manuel | Ignoré, forcé à 0 dans `PRG_07_TranslationControl` | Fins de course extrêmes uniquement |
| `TRUE` | Positionneur manuel | 1=Trémie, 2=P2, 3=P1, 4=Maintenance | Sur le capteur cible, via `TargetReached` puis `ArrivalLock` |

- Le sens et la vitesse restent des commandes manuelles : boutons IHM `ReqFwd`/`ReqRev`
  ou joystick selon `JoystickSelect`.
- Le positionneur ne calcule pas le sens vers cible. L'opérateur doit choisir le sens
  cohérent ; il peut toujours s'éloigner de la cible.
- La cible 4 reste autorisée uniquement lorsque `MaintenanceTargetEnable=TRUE`
  (`MAINT_N2`).
- `SEMI_AUTO` est inchangé : le cycle fournit sa cible et utilise toujours le positionneur.

## 🖥️ Retour IHM

| Champ | Type | Direction | Rôle |
|---|---|---|---|
| `PositioningSelect` | BOOL | IHM→PLC | Sélection explicite jog (`FALSE`) / positionneur (`TRUE`) en maintenance |
| `PositionReached` | BOOL | PLC→IHM | `TRUE` si le positionneur est actif (SEMI_AUTO ou `PositioningSelect`) et que `FB_Translation.TargetReached` est vrai. Information non mémorisée : s'éteint dès la sortie de la cible ou le retour en jog. |

`FB_Translation.Done` ne constitue pas un retour d'arrivée : il reste à `FALSE` dans
l'implémentation actuelle. L'IHM doit afficher `PositionReached` pour informer l'opérateur.

## 🛡️ Arbitrage commandes boutons / joystick

Quand `JoystickSelect=FALSE`, seuls `ReqFwd` et `ReqRev` définissent le sens.
Sans requête bouton, le sens est forcé à 0 : aucune direction joystick ne peut être reprise
implicitement. L'homme-mort `DeadmanArmed` reste obligatoire pour tout mouvement.

## 📂 Sources CODESYS

- `CODE/SUPERVISION/ST_TranslationHMI.st`
- `CODE/MAIN/PRG_00_Inputs.st`
- `CODE/MAIN/PRG_07_TranslationControl.st`
- `CODE/MAIN/PRG_09_Supervision.st`

## 🔧 Application CODESYS 3.5

Importer le bundle complet `CODE/CODE_Bundle.xml` à la racine de l'application. Sur l'IHM,
lier un sélecteur Jog/Positionneur à `GVL_IHM.M3Translation.PositioningSelect` et un voyant
"Position atteinte" à `GVL_IHM.M3Translation.PositionReached`.
