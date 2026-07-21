# 📋 Analyse Fonctionnelle — Partie 12 : Fonction Benne (v1.4)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5
> **Rôle** : Spécification de la fonction métier Benne (ouverture/fermeture par désynchronisation M2) et intégration dans l'orchestration générale.
> **Version** : v1.4 (2026-07-08, Offset dynamique + butées dynamiques M2 — voir §4 point 8)
> 🔧 **Nettoyage documentaire (audit doc, 2026-07-09)** : harmonisation titre/nom de fichier (le
> titre affichait v1.2, le champ "Version" v1.3, alors que le contenu interne (§4 point 8)
> introduisait déjà une v1.4) + checklist de mise en service (§6) remplacée par un renvoi court
> vers `DOC/PLAN_TASK_v1.0.md` §3 (T27). Aucun changement de contenu fonctionnel.
> 🔗 **Dépend de** : [P2 Architecture v2.12](AF_Partie-02_Architecture_Programme_v2.12.md), [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md), [P4 Cycle v1.4](AF_Partie-04_Cycle_Sequenceur_v1.4.md) §6, [P9 Winch v1.7](AF_Partie-09_Fonction_Winch_v1.11.md) §9/§4quinquies.
>
> 🆕 **v1.3 (2026-07-08)** — Alignement sur la sécurité d'inhibition et ajout du référencement fermé : le benne est désactivé (`Enable := FALSE`) si le treuil M2 (fermeture) est inhibé en Maintenance N2, OU si l'un des deux codeurs de position M1 ou M2 est en défaut ou non référencé. Si seul M1 (retenue) est inhibé, le benne reste manœuvrable. Ajout de deux commandes de référencement manuel IHM à l'arrêt (`CmdConfirmOpenPosition` et `CmdConfirmClosePosition`) qui initialisent l'état mécanique (ouvert/fermé) et recalent de manière cohérente les positions mémorisées de boot en éliminant toutes les erreurs actives.
> 🔧 **v1.2 (2026-07-07)** — Ajout du garde-fou glissement M1 pendant un mouvement benne (Méca C
> couche 1, nouveau bit4 `ErrorId` + sortie `M1SlipDetected`) — voir §4bis nouveau ci-dessous.
> Escalade en couche 2 (bit9 `FB_Safety_Winch`, `PowerCutOff`) documentée dans Partie9 v1.5
> §4quinquies, hors périmètre de ce document.
> 🔧 **v1.1 (2026-07-07)** — REX terrain : inversion de la sémantique moteur M2 vis-à-vis du
> benne (relabeling `%Q0.0`/`%Q0.3`). Révision §2.A/§2.B (cinématique + geste joystick) et §4.A
> (commentaire `OffsetCloseM`). Voir bandeau REX ci-dessous.

---

## 🔴 REX Terrain — 2026-07-07 (inversion du sens moteur M2)

> 📌 **Constat terrain** : un ré-câblage / relabeling des sorties physiques `%Q0.0`
> (*"+1 Sens ENROULAGE MONTEE EXTRACTION"*) et `%Q0.3` (*"-1 Sens DEROULAGE DESCENTE PLONGEE"*)
> côté association benne a révélé que les libellés `OUVERTURE BENNE`/`FERMETURE BENNE`
> associés à ces canaux étaient inversés. Après correction des libellés :
> - **ENROULAGE M2** (`Direction=+1`, `RelayFwd`, "montée") **FERME** désormais le benne
>   (avant : on pensait que ça l'ouvrait).
> - **DEROULAGE M2** (`Direction=-1`, `RelayRev`, "descente") **OUVRE** désormais le benne
>   (avant : on pensait que ça le fermait).
>
> Rien ne change côté treuil **M1**, ni côté mapping I/O réel montée/descente — **seule
> l'association métier avec le benne s'inverse**.
>
> **Fichiers impactés** (code déjà corrigé, validé utilisateur — voir `CODE/` pour le détail,
> pas de recopie ici) :
> - [`CODE/TREUILS/BENNE/FB_Bucket.st`](../CODE/TREUILS/BENNE/FB_Bucket.st) — validation joystick homme-mort
>   (`CloseReq`/`OpenReq`), commande `M2_Direction` en état BUSY, conditions d'arrêt automatique
>   (comparaisons `CablePosM2` vs `CablePosM1 + Offset...M`) — tout inversé en cohérence avec le
>   nouveau modèle physique.
> - [`CODE/GVL_PERSISTENT.st`](../CODE/GVL_PERSISTENT.st) — signe de
>   `BucketConfig.OffsetCloseM` inversé (`-1.5` → `+10.0`), **et amplitude corrigée** : la course
>   réelle de fermeture est bien plus grande que l'estimation initiale, environ **10 m** (au lieu
>   de 1.5 m). `OffsetOpenM` reste `0.0` (référence neutre, M2 = M1).
>
> ⚠️ **Amplitude encore approximative** : `OffsetCloseM ≈ 10.0 m` est une valeur terrain
> approximative (ordre de grandeur), pas encore mesurée précisément ; `OffsetOpenM = 0.0 m` reste
> la référence neutre. **À affiner au premier essai réel du benne.**

---

## 🎯 1. Rôle métier & Principe cinématique

Le benne n'ayant pas de moteur propre, sa fermeture et son ouverture sont réalisées en modifiant la longueur relative du câble du **Treuil M2** (fermeture) par rapport au **Treuil M1** (levage/immobile) :

* **Fermeture** : Un enroulement contrôlé de M2 seul (M1 à l'arrêt) ferme les mâchoires du benne. 🔧 *(REX 2026-07-07 : c'était décrit comme un déroulement en v1.0 — inversé.)*
* **Ouverture** : Un déroulement contrôlé de M2 seul (M1 à l'arrêt) rouvre les mâchoires. 🔧 *(REX 2026-07-07 : c'était décrit comme un enroulement en v1.0 — inversé.)*
* **Mouvement synchrone** : Lorsque le benne est dans un état stable (ouvert ou fermé), toute consigne de plongée ou de remontée doit faire tourner les deux treuils ensemble (M1 + M2) en maintenant l'écart requis (offset).

---

## ⚙️ 2. Logique de commande (IHM + Joystick)

Toute modification de l'état du benne combine une sélection sur la supervision (IHM) et une action physique de l'opérateur (Joystick) agissant comme validation homme-mort.

```
       [ IHM ]                              [ JOYSTICK ]
Demande Ouv/Ferm Benne  ──────►  Validation physique Homme-mort (Y)  ──────►  Mouvement M2 seul
```

### A. Phase de Fermeture 🔧 *(REX 2026-07-07 — cinématique et geste joystick inversés vs v1.0)*
1. **Sélection IHM** : L'opérateur demande la fermeture du benne.
2. **Validation Joystick** : L'opérateur doit pousser/tirer le joystick (axe Y) vers le **HAUT**
   (**enrouler / montée**, `JoystickY_Direction = 1`).
3. **Comportement treuils** :
   * Le treuil **M1 reste immobile** (`RelayFwd := FALSE`, `RelayRev := FALSE`, freins serrés).
   * Le treuil **M2 monte** (enroule, `RelayFwd`) en vitesse lente.
4. **Vitesse lente stricte** :
   * La vitesse doit être minimale.
   * **Aucun des 4 contacteurs de vitesse de M2 ne doit s'allumer** (`Contactor1..4 := FALSE`). Seul le sens de rotation (`RelayFwd := TRUE`) et le contacteur de ligne de puissance sont enclenchés.
5. **Arrêt automatique** : Le mouvement s'arrête de lui-même dès que M2 a assez enroulé pour atteindre la position de fermeture cible (`CablePosM2 >= CablePosM1 + OffsetCloseM`).
6. **Mémorisation** : Une fois la position atteinte, la logique de commande coupe le mouvement et mémorise l'état **Benne Fermé**.

### B. Phase d'Ouverture 🔧 *(REX 2026-07-07 — cinématique et geste joystick inversés vs v1.0)*
1. **Sélection IHM** : L'opérateur demande l'ouverture du benne.
2. **Validation Joystick** : L'opérateur doit pousser le joystick (axe Y) vers le **BAS**
   (**dérouler / descente**, `JoystickY_Direction = -1`).
3. **Comportement treuils** :
   * Le treuil **M1 reste immobile**.
   * Le treuil **M2 descend** (déroule, `RelayRev`) en vitesse lente (aucun contacteur de vitesse, juste le sens `RelayRev := TRUE`).
4. **Arrêt automatique** : Le mouvement s'arrête dès que M2 a assez déroulé pour atteindre la position d'ouverture cible (`CablePosM2 <= CablePosM1 + OffsetOpenM`).
5. **Mémorisation** : Une fois la position atteinte, le mouvement est coupé et l'état **Benne Ouvert** est mémorisé.

---

## ⚖️ 3. Intégration de la Synchronisation & Offsets

L'état physique du benne modifie directement les critères de surveillance de synchronisme des deux treuils :

### A. Suspension de la Synchro en mouvement
Pendant les phases actives de fermeture ou d'ouverture (lorsque M2 bouge seul), le bloc `FB_WinchSync` doit être **désactivé** (`Enable := FALSE` ou ignoré par interlock) pour éviter les faux défauts de synchronisation.

### B. Application d'Offsets de Synchronisation
Une fois le mouvement terminé et l'état stabilisé (ouvert ou fermé), la surveillance de synchronisme se réactive mais doit intégrer l'écart de position induit :

* **Si Benne Fermé** : L'écart surveillé devient :
  $$\Delta\text{Pos} = |\text{CablePosM1} - \text{CablePosM2} + \text{OffsetCloseM}|$$
* **Si Benne Ouvert** : L'écart surveillé devient :
  $$\Delta\text{Pos} = |\text{CablePosM1} - \text{CablePosM2} + \text{OffsetOpenM}|$$

Le bloc `FB_WinchSync` doit recevoir l'offset courant à appliquer (`ActiveOffsetM`) pour réaliser une comparaison correcte par rapport à la tolérance (`SyncToleranceM`).

> ℹ️ Les formules ci-dessus sont inchangées vs v1.0 — le **signe** et l'**amplitude** de la
> constante `OffsetCloseM` ont changé (`-1.5` → `+10.0`, voir bandeau REX), cohérent avec le
> nouveau modèle physique (Fermé = M2 plus enroulé/plus haut que M1) et la course réelle constatée.

---

## 🗂️ 4. Interface des blocs et types de données

### A. Structure de Configuration (`ST_BucketConfig`)
```pascal
TYPE ST_BucketConfig :
STRUCT
    OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres benne ouvert — référence neutre (M2 = M1) *)
    OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres benne fermé — POSITIF : M2 plus enroulé/plus haut que M1
                                   🔧 REX 2026-07-07 : signe + amplitude corrigés (-1.5 → +10.0), voir bandeau REX en tête de doc *)
    CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)
END_STRUCT
END_TYPE
```

*(Interface inchangée vs v1.0 — pas de nouveau champ, seule la description de `OffsetCloseM`
est mise à jour. Corps complet à jour dans [`CODE/TREUILS/BENNE/ST_BucketConfig.st`](../CODE/TREUILS/BENNE/ST_BucketConfig.st).)*

### B. Structure d'État (`ST_BucketState`)
```pascal
TYPE ST_BucketState :
STRUCT
    IsOpen          : BOOL;    (* TRUE = Benne ouvert mémorisé *)
    IsClosed        : BOOL;    (* TRUE = Benne fermé mémorisé *)
    LastPosM2Open   : REAL;    (* Dernière position M2 mémorisée ouvert *)
    LastPosM2Close  : REAL;    (* Dernière position M2 mémorisée fermé *)
    StateIncoherent : BOOL;    (* État non sûr (divergence boot/réel) *)
END_STRUCT
END_TYPE
```

*(Inchangée vs v1.0 — voir [`CODE/TREUILS/BENNE/ST_BucketState.st`](../CODE/TREUILS/BENNE/ST_BucketState.st).)*

### C. Interface du bloc Benne (`FB_Bucket`)
```pascal
(* Entrées *)
Enable              : BOOL;        // Standard
Reset               : BOOL;        // Standard (front)
EmergencyStopOk     : BOOL;        // Standard
Mode                : E_Mode;      // Standard
CmdOpen_IHM         : BOOL;        // Demande ouverture IHM
CmdClose_IHM        : BOOL;        // Demande fermeture IHM
JoystickY_StartStop : BOOL;        // Validation homme-mort (AxisCmdY.StartStop)
JoystickY_Direction : INT;         // Sens joystick (AxisCmdY.Direction) — 🔧 REX 2026-07-07 : Fermeture exige désormais +1 (haut/enrouler), Ouverture exige -1 (bas/dérouler)
CablePosM1          : REAL;        // Position réelle M1
CablePosM2          : REAL;        // Position réelle M2
HomedM1             : BOOL;        // 🆕 v1.2 (déjà codé, non documenté jusqu'ici) — Codeur M1 référencé (instHomingM1.Homed)
HomedM2             : BOOL;        // 🆕 v1.2 (idem) — Codeur M2 référencé (instHomingM2.Homed)
Config              : ST_BucketConfig; // Configuration RETAIN
TimeoutDuration     : TIME := T#30s;    // 🆕 v1.2 (déjà codé) — Timeout de mouvement configurable
M1SlipToleranceM    : REAL := 1.0;      // 🆕 v1.2 — tolérance glissement M1 pendant Busy (m), voir §4bis

(* Entrées/Sorties (VAR_IN_OUT) *)
BucketState        : ST_BucketState;  // État mémorisé (RETAIN)

(* Sorties *)
Ready               : BOOL;
Busy                : BOOL;
Done                : BOOL;
Error               : BOOL;
ErrorId             : WORD;        // bit0: Timeout mouvement, bit1: Incohérence boot, bit2: Limites dépassées, bit3: Codeur(s) M1/M2 non référencé(s) 🆕 v1.2, bit4: Glissement M1 pendant Busy 🆕 v1.2
M1SlipDetected      : BOOL;        // 🆕 v1.2 — miroir du bit4, à consommer côté PRG_06_WinchControl (force SafeStop M1) — voir §4bis
State               : E_State;
StateAtError        : E_State;
ActiveOffsetM       : REAL;        // Offset à injecter dans FB_WinchSync
M2_StartStop        : BOOL;        // Commande StartStop vers Winch M2
M2_Direction        : INT;         // Commande Direction vers Winch M2 — 🔧 REX 2026-07-07 : Fermeture := +1 (enroulage), Ouverture := -1 (déroulage)
M2_ForceSlowSpeed   : BOOL;        // Bloque les contacteurs de vitesse de M2
RemainingTravelM    : REAL;        // 🆕 v1.2 (déjà codé, non documenté jusqu'ici) — distance restante avant cible (m, jauge IHM), 0.0 hors mouvement
```

*(Signature du FB étendue en v1.2 : `HomedM1`/`HomedM2`/`TimeoutDuration`/`M1SlipToleranceM`
(entrées) et `M1SlipDetected`/`RemainingTravelM` (sorties) — certains de ces champs existaient déjà
dans `CODE/` avant ce lot (garde-fou homing, jauge IHM) mais n'avaient jamais été répercutés ici ;
seuls `M1SlipToleranceM`/`M1SlipDetected` sont réellement nouveaux dans le code (Méca C couche 1,
voir §4bis). Sémantique interne de `Direction` en Fermeture/Ouverture inversée depuis v1.1, voir
bandeau REX. Corps ST complet et à jour dans
[`CODE/TREUILS/BENNE/FB_Bucket.st`](../CODE/TREUILS/BENNE/FB_Bucket.st) — pas de recopie ici, règle
anti-doublon.)*

### 🆕 D. Méca C couche 1 — Glissement M1 pendant mouvement Benne (v1.2, 2026-07-07)

Pendant l'ouverture/fermeture (M2 bouge seul, M1 doit rester **immobile**) : la position `CablePosM1`
est mémorisée à l'entrée en état `Busy`. Si elle dérive de plus de `M1SlipToleranceM` (1.0 m,
défaut) pendant que `Busy` reste actif → bit4 `ErrorId` → `SevereError` (coupe `M2_StartStop`,
comme les autres causes graves de ce FB : timeout, limites, codeur non référencé) + sortie dédiée
**`M1SlipDetected`**.

`FB_Bucket` ne pilote pas M1 directement (seul `FB_Winch` instance M1 le fait) — `M1SlipDetected`
est donc **consommée côté `PRG_06_WinchControl.st`**, OR'ée dans `SafeStopM1_Raw` pour forcer un
`SafeStop` sur M1 spécifiquement (le couplage croisé M1/M2 existant, actif seulement si
`SyncActive`, ne suffit pas ici puisque le benne désactive volontairement la synchro).

**Couche de secours (défense en profondeur)** : si cette couche 1 ne suffit pas (dérive continue
au-delà de 1.0 m), une **couche 2** existe côté `FB_Safety_Winch` (bit9, tolérance
`BenneSlipToleranceM` = 2.0 m, armée uniquement via `BenneHoldStillActive` câblée sur
`instBucket.Busy` pour l'instance M1 seule) qui escalade jusqu'à `PowerCutOff` — voir
**Partie9 v1.5 §4quinquies** pour le détail complet de cette couche 2, hors périmètre de ce
document (règle anti-doublon : la couche 2 appartient au domaine Winch, pas Benne).

---

## 🔌 5. Note d'application CODESYS 3.5

1. **Persistance** : L'instance de `ST_BucketState` et `ST_BucketConfig` doivent être déclarées en variables persistantes (`VAR RETAIN`) dans `CODE/GVL_PERSISTENT.st` pour conserver la mémoire mécanique du benne après coupure de tension.
2. **Couplage Winch M2** : La commande de vitesse lente forcée (`M2_ForceSlowSpeed`) doit masquer la table de paliers ou forcer `MaxStepNumber := 0` ou un paramètre dédié sur le décodeur de paliers pour n'autoriser aucun contacteur de vitesse.
3. **Calcul de cohérence au boot** : Au premier cycle API, comparer `CablePosM2` avec `LastPosM2Open` ou `LastPosM2Close` (selon le dernier état mémorisé). Si l'écart dépasse `CoherenceLimitM`, forcer la sortie `StateIncoherent := TRUE` et exiger un référencement manuel.
4. 🔧 **REX 2026-07-07** : Le code `CODE/TREUILS/BENNE/FB_Bucket.st` et `CODE/GVL_PERSISTENT.st`
   sont **déjà à jour** avec le nouveau modèle (voir bandeau REX en tête de document) — aucune
   nouvelle recopie manuelle requise au-delà de ce qui a déjà été appliqué en session, sauf si
   une réimportation complète depuis `CODE/` est nécessaire suite à un nouvel export CODESYS.
5. 🆕 **v1.2 (2026-07-07, Méca C couche 1)** : Méca C couche 1 (bit4, `M1SlipDetected`) est **déjà codé et
   validé** dans `CODE/TREUILS/BENNE/FB_Bucket.st` et `CODE/MAIN/PRG_06_WinchControl.st` (voir §4.D) —
   également aucune nouvelle recopie manuelle requise ce lot.
6. 🆕 **v1.3 (2026-07-08, Inhibition)** : Le bloc benne est activé si le treuil M2 n'est pas inhibé, et que les deux codeurs de position M1 et M2 sont disponibles / en bonne santé (`Enable := NOT InhibitM2 AND EncoderAbsM1.EncoderAvailable AND EncoderAbsM2.EncoderAvailable` dans `PRG_06_WinchControl.st`). Si seul M1 (retenue) est inhibé, le benne reste manœuvrable puisque seul M2 se déplace pour ouvrir ou fermer (M1 restant verrouillé au frein). Cependant, le codeur M1 doit obligatoirement être disponible et référencé (`HomedM1 = TRUE`) pour permettre le calcul de fin de course du benne ; dans le cas contraire, le benne est bloqué en sécurité. De plus, si M1 est inhibé, la surveillance de glissement de M1 pendant le mouvement (`M1SlipDetected`, bit 4 de `ErrorId`) est automatiquement désactivée pour éviter tout déclenchement intempestif dû à des fluctuations ou une isolation de l'axe M1.
7. 🆕 **v1.3 (2026-07-08, Référencement)** : Deux boutons de référencement manuel sont prévus pour la mise en service du benne à l'arrêt. Pour simplifier les essais, ces commandes sont autorisées même si les codeurs de treuils M1/M2 ne sont pas encore référencés (`HomedM1/M2 = FALSE`) :
   * **`ConfirmOpenPosition`** (benne ouvert de visu) : Force `IsOpen := TRUE`, `IsClosed := FALSE`, initialise `LastPosM2Open := CablePosM2`, et calcule la position fermée théorique `LastPosM2Close := CablePosM2 - Config.OffsetOpenM + Config.OffsetCloseM`.
   * **`ConfirmClosePosition`** (benne fermé de visu) : Force `IsOpen := FALSE`, `IsClosed := TRUE`, initialise `LastPosM2Close := CablePosM2`, et calcule la position ouverte théorique `LastPosM2Open := CablePosM2 - Config.OffsetCloseM + Config.OffsetOpenM`.
   Ces deux commandes effacent complètement les défauts du benne (`ErrorId := 16#0000`) et recalent l'état mécanique sans exiger d'acquittement machine supplémentaire.
   *(Note : si les treuils ne sont pas homés, le défaut permanent bit 3 `16#0008` reviendra au scan suivant, mais la réinitialisation des variables persistantes de calibrage de boot aura bien été effectuée).*
8. 🆕 **v1.4 (2026-07-08, Offset dynamique et Butées dynamiques M2)** :
   * **Offset dynamique (`ActiveOffsetM`)** : Durant le mouvement (`State = E_State.BUSY`), `ActiveOffsetM` est calculé dynamiquement comme la différence réelle de câble (`CablePosM2 - CablePosM1`). Cela garantit que la position corrigée de M2 (`M2PositionCorrected := CablePosM2 - ActiveOffsetM` dans `PRG_09_Supervision.st`) reste parfaitement stable et égale à la position de M1 (la hauteur de charge réelle) pendant toute la manœuvre de fermeture ou d'ouverture. La jauge/bargraphe IHM reste stable, et la différence n'apparaît que sur la valeur brute de M2 qui reflète l'enroulement physique. À la fin du cycle, `ActiveOffsetM` reprend sa valeur fixe de configuration (`OffsetCloseM` ou `OffsetOpenM`) de manière transparente et sans saut d'affichage.
   * **Butée logicielle haute dynamique de M2** : Pour éviter que M2 ne soit bloqué prématurément par sa butée logicielle haute solo lors des cycles de fermeture à haute altitude, sa limite haute absolue (`TopLimitM` de `instWinchM2` et seuils de `ForbidAscentM2_Raw`) est décalée dynamiquement de la valeur de l'offset de fermeture (`OffsetCloseM`). Ce décalage n'est activé **que si le benne est fermé ou en cours de fermeture** (`BucketState.IsClosed` ou `CloseReq` actif). Si le benne est ouvert, la butée de M2 est ramenée à sa valeur standard (`HomingTargetM2_M`, soit 12.00m de butée virtuelle avec marge), assurant un arrêt propre et synchrone de M1 et M2 à 12m lors de la remontée normale.

9. 🆕 **v1.4 (2026-07-21, Mémoire longueur câble — discrimination désynchronisation)** :
   `_BucketState` (stocké dans `GVL_PERSISTENT`) mémorise les positions absolues de M2 en fin d'ouverture et de fermeture (`LastPosM2Open`, `LastPosM2Close`). Ces longueurs de câble persistentes permettent :
   * **Discrimination origine défaut** : En cas de défaut synchro au boot, comparer `CablePosM2` vs `LastPosM2*` permet de distinguer un glissement câble physique (les deux positions bougent ensemble) d'un décalage benne légitime (seul M2 a changé d'offset).
   * **Sécurité redondante** : Si `ABS(CablePosM2 - DeltaPosM - LastPosM2Close) > CoherenceLimitM` alors que l'état est `IsClosed`, un glissement M1/M2 est détectable indépendamment de `FB_WinchSync` — couche de défense supplémentaire (hors tolérance synchro, qui pourrait être masquée par un offset mal appliqué).
   * **Pas d'action directe** : Champ informationnel pour diagnostic IHM et datalog — pas de boucle d'arrêt automatique basée sur cette seule comparaison (l'initiative de mouvement reste à la logique cycle/opérateur).

---

## 🔁 6. Retour d'expérience

- [x] **2026-07-07** — Constat terrain : sens moteur M2 inversé vis-à-vis du benne (relabeling
      `%Q0.0`/`%Q0.3`) — code corrigé (`FB_Bucket.st`, `GVL_PERSISTENT.st`), documentation
      révisée (ce document).

📌 Suivi (essais de mise en service restants — cinématique enroulage/déroulage, amplitude des
offsets, ressenti joystick homme-mort, Méca C couches 1/2) : voir `DOC/PLAN_TASK_v1.0.md` §3
(T27).

---

## 📚 Documents liés
- **Partie 2 v2.7** — Architecture (mapping M1/M2, `FB_Bucket` dans l'arborescence `BENNE`).
- **Partie 3 v1.3** — Contrat FB (interface standard, `ErrorId`, reset).
- **Partie 4 v1.2** §6 — Cycle (intégration du benne dans la séquence de dragage).
- **Partie 9 v1.5** 🔧 v1.2 §9/§4quinquies — Fonction Winch (M2, dépendance directe :
  `M2_StartStop`/`M2_Direction` consommés par `FB_Winch` instance M2 ; couche 2 de l'escalade
  glissement M1, voir §4.D ci-dessus).
