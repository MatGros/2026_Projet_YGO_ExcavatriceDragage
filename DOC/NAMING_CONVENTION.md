# Convention de Nommage — Projet Excavatrice Dragage
 
## Principes
- **Sans hongrois** : le type se lit dans la déclaration, pas dans le nom.
- **Sémantique** : le nom décrit le rôle, l'unité ou l'état.
- **PascalCase** partout. Abréviations anglaises courtes acceptées.
- **Suffixes d'unité** : seule exception aux abréviations (pour lever ambiguïtés métier).
 
---
 
## Préfixes structurels (classification, non typage)
| Préfixe | Usage | Exemple |
|---------|-------|---------|
| `ST_` | Struct de données | `ST_AxisCmd`, `ST_WinchIO` |
| `E_` | Enum / énumération | `E_Mode`, `E_Error` |
| `FB_` | Function Block | `FB_Joystick`, `FB_Treuil` |
 
---
 
## Abréviations autorisées
```
Cmd = command          Sts / State = status        Pos = position
Spd = speed           Ref = consigne              Act = actual/mesuré
Min / Max / Lim       Fwd / Rev = forward/reverse  Up / Dn = haut/bas
En = enable           Rdy = ready                  Err = error / ErrorId
```
 
---
 
## Nommage par catégorie
 
### Entrées de commande
```
Enable, Start, Stop, Reset
SafeStop, SafetyOk
```
 
### Consignes (références)
```
SpeedRef          → consigne de vitesse
CablePosRef       → position câble consignée
```
 
### Mesures (actual)
```
SpeedAct          → vitesse mesurée
CablePosAct       → position câble mesurée (déroulé)
DrumPos           → position tambour codeur
```
 
### Sorties d'état / feedback
```
Ready, Done, Busy, Moving
Error, ErrorId    → code erreur numérique
```
 
### Sorties physiques / actionneurs
```
RelayFwd, RelayRev           → contacteurs direction
OutSpeed, OutSpeedCmd        → commande variateur (%)
SoftStartRampActive          → gestion rampe soft-start
```
 
### Booléens : convention d'état
**Entrées** → verbe d'action :
```
Start, Stop, Reset, Enable
```
 
**Sorties** → état/propriété :
```
Ready, Busy, Done, Error
IsOverload, HasFault
```
 
---
 
## Suffixes d'unité (exceptions tolérées)
Utilisé si l'unité lève une ambiguïté métier ou pour précision :
```
CablePosM         → position en mètres (2 déc)
SpeedPct          → vitesse en % nominal
RampTimeMs        → temps de rampe en ms
DrumRevs          → rotations tambour
```
 
---
 
## Nommage des instances (objets instanciés en Ladder)
Rôle métier clair, court :
```
WinchA, WinchB             → les deux treuils
Translation                → axe transversal
Bucket                     → godet
Joystick                   → manette
Watchdog, Sync, Safety     → fonctions critiques
```
 
---
 
## Structures : exemple CODESYS
```codesys
(* Consigne joystick *)
TYPE ST_AxisCmd :
STRUCT
    Enable      : BOOL;       (* Autorisation *)
    Start       : BOOL;       (* Lancer action *)
    SpeedRef    : REAL;       (* Consigne vitesse 0..100% *)
    Direction   : INT;        (* -1=Rev, 0=Neutre, +1=Fwd *)
    SafetyOk    : BOOL;       (* Coherence capteurs OK *)
END_STRUCT
END_TYPE
 
(* Status treuil *)
TYPE ST_WinchIO :
STRUCT
    Ready       : BOOL;
    Done        : BOOL;
    Error       : BOOL;
    ErrorId     : INT;
    CablePosAct : REAL;       (* m *)
    SpeedAct    : REAL;       (* % *)
    RelayFwd    : BOOL;
    RelayRev    : BOOL;
END_STRUCT
END_TYPE
```
 
---
 
## En Ladder : lisibilité flux
```
[FB_Joystick]     →  (.Done)  →  [FB_Treuil.Enable]
     ↓ SpeedRef        + Start     ↓ SpeedRef
[FB_Encodeur]     ←  (.CablePosAct)
```
→ Chaînes d'instance, flux d'info immédiatement visible pour maintenance. ✅
 
---
 
## Résumé règles
1. ❌ Pas de `bFlag`, `iCounter`, `rValue`.
2. ✅ `Enable`, `Ready`, `CablePosM`, `SpeedPct`.
3. Type se découvre dans l'IDE → le nom parle du rôle.
4. Instances = noms métier courts.
5. Structures + Enums = organisation, pas typage du nom.
 
