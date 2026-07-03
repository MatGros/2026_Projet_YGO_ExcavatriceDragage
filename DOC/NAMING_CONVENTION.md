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
                        (FB de mouvement uniquement — Winch, Chariot)
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

### 🔒 Polarité des booléens I/O : sécurité vs information vs commande

Trois familles, ne pas les confondre — c'est précisément ce qui a coûté une session de débogage
complète sur ce projet (voir incident ci-dessous).

| Famille | Convention | Exemples | Pourquoi |
|---|---|---|---|
| **Capteur de sécurité** (entrée brute, suffixe `Ok` ou assimilé fail-safe) | `TRUE` = état OK/nominal ; `FALSE` = défaut | `EmergencyStopOk`, `GVL_IN.SlackCableSwitch`, `GVL_IN.PhaseRotationOk`, `GVL_IN.TopPositionSensor` (sain si non atteint), `GVL_IN.DriveFaultOk` | Câblage NF/energized-to-run : une coupure de câble ou un contact ouvert retombe naturellement à `FALSE` → détecté comme défaut sans câblage supplémentaire. |
| **Information / état classique** (entrée brute) | `FALSE` = repos ; `TRUE` = capteur atteint/déclenché | `ChariotPosFosse1/Fosse2/Maintenance/Tremie` | Logique directe : "je suis arrivé à la position" = `TRUE`. Pas d'enjeu fail-safe. |
| **Sortie de COMMANDE d'un bloc Safety** (calculée, PAS un capteur) | `TRUE` = **déclenche** l'action | `SafeStop` (déclenche décél. rapide), `ForbidDescent` (déclenche l'interdiction), `PowerCutOff` (déclenche la coupure) | Nom = un verbe d'action, pas un état de capteur — c'est l'inverse de la famille "sécurité" ci-dessus, volontairement. |

⚠️ **Confusion réelle vécue sur ce projet** (retour terrain, session mise en service) :
l'utilisateur a **forcé manuellement `instWinchM1.SafeStop` à `TRUE`**, en pensant — par analogie
avec la famille "capteur de sécurité" — qu'un "organe de sécurité" devait être en permanence à `1`.
Résultat : `SafeStop` (sortie de COMMANDE, pas un capteur) forcé à `TRUE` = décélération rapide
imposée en permanence, mouvement totalement bloqué, alors que `FB_Safety_Winch` calculait
correctement `FALSE` (aucun défaut). Diagnostic long car le câblage était irréprochable — seul un
Force expliquait la divergence entre la sortie calculée et l'entrée reçue.
**Règle** : ne JAMAIS forcer manuellement une sortie de COMMANDE (`SafeStop`, `ForbidDescent`,
`PowerCutOff`) — elle est TOUJOURS calculée par son bloc Safety. Si un test banc nécessite de
neutraliser une condition, forcer/bypasser l'entrée CAPTEUR en amont (ex. `GVL_IN.PhaseRotationOk`,
ou un `GVL_DEBUG.DBG_*Bypass_TEST` dédié), jamais la sortie de commande elle-même.

⚠️ **Deux bugs de câblage réels sur ce projet** (voir `AUDIT_Coherence_Documentaire_v1.0.md` §27
D72a et §29 D74), famille "capteur de sécurité" :
- `GVL_IN.SlackCableSwitch` câblé **sans inversion** alors que le contact est NF (`TRUE`=pas de mou)
  → jamais détecté un vrai mou de câble. Corrigé : `SlackCableDetected := NOT GVL_IN.SlackCableSwitch`.
- `GVL_IN.PhaseRotationOk` déclaré **sans valeur initiale** → un `BOOL` non initialisé démarre à
  `FALSE` (IEC 61131-3) = "défaut" par défaut → `SafeStop` bloqué en permanence tant que le vrai
  capteur n'est pas câblé, sans aucun vrai défaut.

**Règle à appliquer systématiquement** (famille "capteur de sécurité" UNIQUEMENT — ne s'applique
PAS aux sorties de commande, qui ne s'initialisent pas, elles se calculent) : toute variable de la
famille "sécurité" (suffixe `Ok`, ou toute entrée capteur consommée par un `FB_Safety_<Metier>`)
doit être **initialisée explicitement à `TRUE`** dans sa déclaration (`VAR_GLOBAL`/`VAR_INPUT`),
jamais laissée à la valeur par défaut du langage — sinon un capteur "pas encore câblé" se lit
comme "défaut détecté". La famille "information classique" n'a pas ce besoin : son repos naturel
(`FALSE`) est déjà la bonne valeur par défaut.

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
Chariot                    → axe transversal
Grappin                    → grappin (prévention gravats)
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
 
