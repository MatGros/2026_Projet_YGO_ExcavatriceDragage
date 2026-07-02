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
| `E_` | Enum / énumération | `E_Mode`, `E_State`, `E_CycleStep` |
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
Enable, Reset
StartStop            → BOOL : TRUE = rampe accélération, FALSE = rampe décélération normale
                        (FB de mouvement uniquement — Winch, Translation)
```

### Entrées sécurité / contexte
```
SafeStop             → BOOL : sortie d'un bloc safety MÉTIER, consommée en entrée
                        par les FB de mouvement de son domaine (1 SafeStop par métier,
                        pas de signal global unique). TRUE = rampe décélération RAPIDE.
                        Enable reste actif pendant SafeStop (≠ neutralisation).
EmergencyStopOk       → BOOL : chaîne de sécurité AU (arrêt d'urgence) réarmée / OK,
                        ou retour contacteur de puissance (source à définir par métier).
                        Anciennement nommé SafetyOk — renommé pour éviter l'ambiguïté
                        avec SafeStop.
Mode                  → E_Mode courant (autorisations)
```

> 🧭 **Hiérarchie de précédence** (du plus fort au plus faible) : `Enable` > `SafeStop` > `StartStop`.
> - `Enable = FALSE` → FB désactivé, **toutes les sorties coupées** (neutralisation dure).
> - `SafeStop = TRUE` (Enable actif) → **rampe de décélération rapide** (défaut process).
> - `StartStop = FALSE` (Enable actif, pas de SafeStop) → **rampe de décélération normale** (arrêt demandé).
 
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
Error, ErrorId    → ErrorId = bitfield WORD (bit n = défaut n), Error = miroir (ErrorId <> 0)
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
Reset, Enable, StartStop
```
 
**Sorties** → état/propriété :
```
Ready, Busy, Done, Error
IsOverload, HasFault
SafeStop            → sortie d'un bloc safety métier (état, pas une commande)
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
Sync, Safety               → fonctions critiques
```
 
---
 
## Structures : exemple CODESYS
```codesys
(* Consigne joystick *)
TYPE ST_AxisCmd :
STRUCT
    Enable      : BOOL;       (* Autorisation *)
    StartStop   : BOOL;       (* TRUE = rampe accel, FALSE = rampe decel normale *)
    SpeedRef    : REAL;       (* Consigne vitesse 0..100% *)
    Direction   : INT;        (* -1=Rev, 0=Neutre, +1=Fwd *)
    EmergencyStopOk : BOOL;   (* Chaine AU réarmée / contacteur puissance OK *)
END_STRUCT
END_TYPE
 
(* Status treuil *)
TYPE ST_WinchIO :
STRUCT
    Ready       : BOOL;
    Done        : BOOL;
    Error       : BOOL;
    ErrorId     : WORD;       (* bitfield : bit n = défaut n, pas un code numérique *)
    SafeStop    : BOOL;       (* sortie safety métier consommée par ce treuil *)
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
     ↓ SpeedRef        + StartStop ↓ SpeedRef
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
 
