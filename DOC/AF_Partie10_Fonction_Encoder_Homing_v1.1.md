# 📋 Analyse Fonctionnelle — Partie 10 : Référencement Codeur (Homing) & Commande Indépendante Treuils (v1.1)

> **v1.1** — Suite retour terrain (opérateur/mainteneur) et revue technique automatisme :
> - 🔢 Résolution codeur **confirmée** (8192 pts/tour × 4096 tours, plage totale 33 554 432 pts) —
>   n'est plus un exemple hypothétique (§3.3). Cible de homing nominal = **centre exact** de la
>   plage (16 777 216 pts = 0.00 m) : marge symétrique maximale, aucun risque de rebouclage.
> - 🎯 **Deux flux de homing distincts** : nominal (les 2 treuils ensemble, godet ouvert, cible
>   fixe 0.00 m, `MAINT_N1` suffit) vs unitaire maintenance (1 treuil seul, cible **paramétrable**,
>   `MAINT_N2` requis) — voir §5.
> - 🖥️ **Confirmation déportée à l'IHM** : `Home` devient une entrée BOOL unique (front) — mot de
>   passe et message de confirmation gérés côté IHM, plus de `ConfirmHome` au niveau FB (§5).
> - 🛑 **Condition d'arrêt fiabilisée** : `WinchSpeedNull` (dérivé du codeur qu'on référence,
>   fragile) remplacé par une confirmation **contacteurs + frein** (retours d'état câblés réels,
>   §7).
> - 📏 **Bornage absolu de position** ajouté : `CablePosM` doit rester dans **[-99.00 ; +99.00] m**
>   — toute valeur hors plage est **invalide**, jamais affichée (§3.6).
> - 🔁 **Détection d'incohérence au redémarrage** (§3.7) : comparaison au dernier point brut connu
>   avant coupure — couvre le démontage masqué / rotation hors tension > demi-tour codeur, cas
>   qu'un simple `Homed` persistant ne couvrait pas.
> - ⏱️ Détection de saut incohérent (§3.5) : confirmation sur **3 cycles EtherCAT consécutifs**
>   (12 ms) — perte de quelques trames jugée sans risque temporel, évite les fausses alarmes.
> - 🧩 **`FB_Safety_Winch` scindé en 2 instances indépendantes** (`WinchM1`/`WinchM2`) — lève
>   l'ambiguïté relevée en revue (§7).
> - 📝 Note hors périmètre : variateur **AC600 (M3, translation)** — sur perte de communication,
>   comportement pressenti **roue libre sans rampe** (proche d'un STO) ≠ comportement treuil
>   (contacteurs/frein). À traiter dans un futur document dédié `FB_Translation`/Partie2 (§9).
>
> **v1.0** — Version initiale (cinématique câble/tambour, analyse anti-débordement générique,
> sélection treuil indépendante, `FB_Encoder_Homing`).

> **Fonction métier** : permettre en **Maintenance** de piloter **M1 et M2 indépendamment**
> (montage/remplacement câble sur tambour) puis de **référencer** (« homer ») le codeur absolu de
> chaque treuil, sans jamais exposer la chaîne de calcul à un **débordement (overflow)** de
> variable ni à un **saut brutal** de valeur codeur (rollover 0 ↔ max points).
> **Cible** : CODESYS 3.5 — document de **conception**, pas encore de code généré (voir §9).
> 🔗 Dépend de : [P1 Analyse Fonctionnelle v1.2](AF_Partie1_Analyse_Fonctionnelle_v1.2.md) §Initialisation,
> [P2 Architecture v2.5](AF_Partie2_Architecture_Programme_v2.5.md) (dossier `ENCODER`),
> [P3 Contrat FB v1.2](AF_Partie3_Template_FB_Commun_v1.2.md) §1bis (profils FB),
> [P4 Cycle v1.1](AF_Partie4_Cycle_Sequenceur_v1.1.md) §Initialisation/§3 Synchro,
> [P5 Modes v1.1](AF_Partie5_Modes_Maintenance_v1.1.md) §2 (`MAINT_N1`/`MAINT_N2`),
> [P9 Fonction Winch v1.0](AF_Partie9_Fonction_Winch_v1.0.md) (`FB_Winch` unitaire M1/M2).

---

## 🎯 1. Rôle métier

Lors du montage mécanique (câble neuf ou codeur remplacé), deux situations distinctes :

1. 🌊 **Homing nominal (routine)** : les 2 treuils descendent **synchronisés** (`FB_WinchSync`
   actif, fonctionnement `MAINT_N1` normal), godet **ouvert**, jusqu'au **toucher d'eau** (constat
   visuel opérateur — un capteur de contact fond existe mais reste **indicatif**, voir §5). Un
   seul appui IHM référence **les deux codeurs simultanément** à une cible fixe (0.00 m).
2. 🔧 **Homing unitaire (maintenance lourde)** : un seul treuil est mobilisé (câble/codeur remplacé
   sur un seul tambour) — nécessite la **sélection treuil indépendante** (§4, `MAINT_N2`) et
   autorise une cible de préréglage **paramétrable** (pas forcément 0.00 m).

Ce document formalise ces deux flux, la cinématique câble/tambour et l'analyse anti-débordement
(§2/§3) — c'est ce qui rend le homing **sûr**, pas seulement fonctionnel.

---

## 🧵 2. Cinématique câble/tambour — paramètres

Tambour **entraînement direct, ratio 1:1** avec le codeur absolu (COD1↔M1, COD2↔M2). Le câble de
traction s'enroule à **diamètre constant** (approximation acceptée du projet — pas de correction
multi-couche) : un tour de tambour = une longueur de câble fixe.

| Paramètre | Nom | Valeur | Rôle |
|-----------|-----|--------|------|
| Câble déroulé par tour | `CableM_PerRev` | **1.5 m/tour** (site) | Constante cinématique tambour ↔ câble — paramètre RETAIN, réglable |
| Longueur câble max | `MaxCableM` | **≈ 100 m** | Plage utile totale de la machine |
| Tours tambour max utiles | `DrumRevsMax` | `MaxCableM / CableM_PerRev` ≈ **66.7 tours** | Dérivé |
| Résolution codeur (1 tour) | `PointsPerRev` | **8192 pts/tour** (13 bits) — **confirmé** | Caractéristique matérielle COD1/COD2 |
| Capacité multitour | `MultiTurnRevsMax` | **4096 tours** (12 bits) — **confirmé** | Caractéristique matérielle COD1/COD2 |

```
DrumRevsMax = MaxCableM / CableM_PerRev = 100 / 1.5 ≈ 66.7 tours
```

📌 `CableM_PerRev` reste un **paramètre** (RETAIN) — si le diamètre de tambour change, un seul
réglage à revoir. `PointsPerRev`/`MultiTurnRevsMax` sont désormais des **valeurs matérielles
confirmées** (fiche technique COD1/COD2), plus une hypothèse d'exemple.

Formule de conversion points → mètres (`FB_Encoder_Scale` via `LIN_TRAFO`, Partie2 §4) :

```
PointsPerM  = PointsPerRev / CableM_PerRev
CablePosM   = (RawPos − HomingRefRaw) × (CableM_PerRev / PointsPerRev)
```

`RawPos`/`HomingRefRaw` = valeur brute **combinée** (angle + tours), voir §3.1 — c'est la **source
de vérité et de sécurité unique** pour tout calcul de position. Un angle intra-tour et un compteur
de tours peuvent en être **dérivés séparément à titre informatif maintenance** (IHM), sans jamais
se substituer à la valeur combinée pour la sécurité (§6).

---

## 🧮 3. Analyse anti-débordement (overflow) — cœur du sujet

### 3.1 Bornes des types utilisés

| Donnée | Type retenu | Bornes | Pourquoi |
|--------|-------------|--------|----------|
| `RawPos` (valeur brute combinée codeur, lue EtherCAT) | `UDINT` | 0 .. 4 294 967 295 | Format natif habituel des codeurs absolus multitour — **source de vérité unique**, ne pas convertir en `DINT` avant soustraction |
| `HomingRefRaw` (valeur figée au dernier homing réussi) | `UDINT` (RETAIN) | idem | Même type que `RawPos` |
| `RawPos − HomingRefRaw` (écart depuis référence) | `DINT` | ±2 147 483 647 | Signé : le câble peut descendre sous la référence |
| `CablePosM` (position affichée) | `REAL` | ±3.4×10³⁸, mantisse 24 bits | Largement suffisant pour ±99 m à 2 décimales |

⚠️ **Piège à éviter** : ne jamais soustraire directement deux `UDINT` dont le résultat peut être
négatif (rebouclage silencieux vers une valeur proche de 2³²). Méthode retenue pour
l'implémentation CODESYS : **convertir les deux opérandes en `DINT` avant la soustraction**
(sûr ici car `RawPos` et `HomingRefRaw` restent, par construction de la marge §3.4, très en
dessous de 2³¹), puis effectuer l'écart en arithmétique **signée**. Ne jamais soustraire en
`UDINT` puis convertir après coup.

### 3.2 Principe : ne jamais rapprocher la mesure des bornes matérielles

Le compteur brut d'un codeur absolu multitour est borné (`0 .. MaxRawValue`) et **reboucle**
au-delà. Un « saut brutal de 0 à +points max » est la mesure qui **traverse cette frontière de
rebouclage** en usage normal.

✅ **Parade** : le homing **repositionne activement** le compteur brut sur une cible fixe
(`HomingRefTargetNominal`) choisie **exactement au centre** de la plage totale, à **chaque**
référencement (pas seulement à la mise en service) — voir §3.3. La fenêtre parcourue en
exploitation (± `DrumRevsMax` en points) reste alors **toujours** loin des deux bornes.

### 3.3 Valeurs confirmées (codeur multitour 13 bits tour + 12 bits multitour)

| Grandeur | Formule | Valeur |
|----------|---------|--------|
| Résolution simple tour | `PointsPerRev` | **8192** pts/tour (confirmé fiche technique) |
| Tours mémorisables | `MultiTurnRevsMax` | **4096** tours (confirmé fiche technique) |
| Plage brute totale | `MaxRawValue = PointsPerRev × MultiTurnRevsMax` | **33 554 432** pts (0 .. ~33 554 431) |
| Points par mètre | `PointsPerM = PointsPerRev / CableM_PerRev` | 8192 / 1.5 ≈ 5461.3 pts/m |
| Points utiles (100 m) | `MaxCableM × PointsPerM` | ≈ 546 133 pts (**1.6 %** de la plage totale) |
| **Cible homing nominal** | `HomingRefTargetNominal = MaxRawValue / 2` | **16 777 216** pts (= 0.00 m, centre exact) |
| Marge disponible de chaque côté | `HomingRefTargetNominal` | ≈ 16.2 M pts, **≈ 30× la plage utile** |

✅ Ces valeurs sont **confirmées** (fiche technique COD1/COD2) — ce ne sont plus des hypothèses
d'exemple. La marge (~30×) valide largement la règle générique §3.4 (exigence ≥10×).

### 3.4 Règle générique de marge (rappel, validée par §3.3)

```
1. HomingRefTargetNominal := MaxRawValue / 2         (* centre exact — marge maximale symétrique *)
2. MargeDispo            := HomingRefTargetNominal    (* distance à chaque borne, par symétrie *)
3. PlageUtilePts          := MaxCableM × PointsPerRev / CableM_PerRev
4. EXIGER : MargeDispo >= 10 × PlageUtilePts          (* validé §3.3 : marge ≈ 30× *)
5. EXIGER : HomingRefTargetNominal converti en DINT reste < 2^31 − 1
```

### 3.5 Saut incohérent en exploitation (dérive maintenance, codeur mort, bruit bus)

`FB_Encoder_Safety` (Partie2 §4, responsabilité « cohérence position / limites ») détecte les
sauts par plausibilité de vitesse :

```
ΔRawPos_Cycle := |RawPos(k) − RawPos(k−1)|                    (* entre 2 cycles EtherCAT, 4 ms *)
ΔRawPos_Max   := VitesseTreuilMax_MPS × PointsPerM × 0.004     (* déplacement max physiquement possible en 4 ms *)

SI ΔRawPos_Cycle > ΔRawPos_Max × MargeBruit(ex. ×3)
   PENDANT 3 CYCLES CONSÉCUTIFS (12 ms) ALORS
    → ErrorId bit « saut codeur incohérent »
    → SafeStop_Winch<Mx> (instance du treuil concerné, §7)
    → RawPos/CablePosAct FIGÉS sur la dernière valeur plausible (pas de mise à jour de sortie —
      voir §6, principe « geler sur doute »)
    → Obligation de repasser par MAINT_N2 + re-homing (ou confirmation §3.7 selon le cas)
```

📌 **Confirmation sur 3 cycles consécutifs (12 ms)** : la perte ponctuelle d'une à trois trames
EtherCAT ne représente **aucun risque temporel réel** (déplacement négligeable sur 12 ms à la
vitesse treuil max) — ce délai filtre le bruit bus sans retarder dangereusement la détection d'un
vrai rebouclage/incohérence.

### 3.6 Bornage absolu de position (nouveau — [-99.00 ; +99.00] m)

Indépendamment de toute analyse de saut, `FB_Encoder_Safety` applique un **bornage physique dur** :

```
SI CablePosM_calculé < -99.00 OU CablePosM_calculé > +99.00 ALORS
    → valeur jugée IMPOSSIBLE (au-delà de toute réalité mécanique de la machine)
    → sortie NON mise à jour (gel sur dernière valeur plausible, §6)
    → ErrorId bit « position hors plage physique »
```

Ce même bornage s'applique en entrée à `HomingTargetM` (§5) : impossible de paramétrer une cible
de homing hors `[-99.00 ; +99.00]` m, y compris en `MAINT_N2`.

### 3.7 Cohérence au redémarrage (nouveau — démontage masqué / rotation hors tension)

Le `Homed` (RETAIN) ne garantit **pas à lui seul** que la référence reste valide : une rotation du
tambour **hors tension** de plus d'un demi-tour codeur (démontage masqué, manipulation non
tracée) peut produire, au rallumage, une valeur `RawPos` plausible en apparence mais **fausse** —
sans qu'aucun défaut ne se soit jamais déclenché.

**Parade** : conserver en continu (RETAIN, mis à jour à chaque cycle **valide**, jamais pendant un
doute — cohérent avec le principe « geler sur doute » §6) le dernier point brut connu :

```
LastKnownRawPos : UDINT (RETAIN)   (* mis à jour en continu tant que RawPos jugé valide *)

Au redémarrage (premier cycle EtherCAT opérationnel après coupure) :
  SI |DINT(RawPos) − DINT(LastKnownRawPos)| > RestartCoherenceTolerancePts ALORS
      → HomingSuspect := TRUE (RETAIN)         (* Homed n'est PAS remis à FALSE, mais signalé douteux *)
      → ErrorId bit « incohérence codeur au redémarrage »
      → SEMI_AUTO bloqué (Homed fiable requis, cf. §7) tant que non levé
  SINON
      → RAS, LastKnownRawPos continue d'être mis à jour normalement
```

`RestartCoherenceTolerancePts` : paramètre RETAIN, valeur de départ recommandée de l'ordre de
10-20 % de `PointsPerRev` (quelques cm équivalents) — à ajuster selon le jeu mécanique réel
observé sur site.

**Levée du doute** : une action opérateur dédiée `ConfirmCoherence` (front, disponible en
`MAINT_N1` **ou** `MAINT_N2`) permet d'accepter la position actuellement mesurée comme fiable
après vérification visuelle/manuelle — sans nécessiter un homing complet (pas de retour au
toucher d'eau). Un nouveau `Home` réussi (§5) lève également le doute (il réécrit `HomingRefRaw`
et `LastKnownRawPos` de toute façon).

🧭 Cette vérification est **complémentaire** à §3.5 : §3.5 détecte les sauts **pendant**
l'exploitation (codeur sous tension) ; §3.7 détecte les incohérences accumulées **pendant une
coupure** (ce que la surveillance en ligne ne peut pas voir).

---

## 🔌 4. Sélection treuil indépendante (`MAINT_N2`)

`FB_WinchSync` n'a pas de sens pendant le homing unitaire : un seul tambour doit bouger, l'autre
restant **strictement immobile**.

```codesys
TYPE E_WinchSelect :
ENUM
  NONE := 0;   (* Aucune sélection active — fonctionnement normal, FB_WinchSync opère normalement *)
  M1   := 1;   (* Consigne joystick/IHM routée vers M1 seul, M2 neutralisé *)
  M2   := 2;   (* Consigne joystick/IHM routée vers M2 seul, M1 neutralisé *)
END_ENUM
END_TYPE
```

| Règle | Détail |
|-------|--------|
| Sélection | Sélecteur IHM, actif **uniquement** en `MAINT_N2` |
| Routage | Consigne joystick (`ST_AxisCmd`) n'alimente **que** le `FB_Winch` correspondant à `WinchSelect` ; l'autre reçoit `Enable := FALSE` |
| Synchro | `FB_WinchSync.Enable := FALSE` tant que `WinchSelect <> NONE` (automatique — un seul treuil bouge, rien à synchroniser) |
| Homme-mort | Le joystick reste seul actionneur de mouvement — relâcher = arrêt rampe normale |
| **Transition de mode** | **Toute** sortie de `MAINT_N2` (vers `MANUEL`, `MAINT_N1` ou `SEMI_AUTO`) force `WinchSelect := NONE` **dans `FB_Modes`** (pas une simple consigne procédurale opérateur, un **verrou logiciel**) — évite qu'un treuil reste neutralisé silencieusement après un changement de mode précipité |
| Reprise mouvement | Cohérent Partie3 §6 (« acquitter ≠ redémarrer ») : un changement de mode ne doit **jamais** transporter une consigne de mouvement en cours — `StartStop` retombe à `FALSE` à chaque transition, un nouvel ordre explicite est requis dans le nouveau mode |
| `SEMI_AUTO` | Refusé si `WinchSelect <> NONE` (redondant avec la règle ci-dessus, gardée en double vérification) |

🧭 **Portée du principe** : la même logique de sélection/neutralisation croisée (et le même
verrou de transition de mode) s'applique par construction à d'autres actionneurs pilotables en
maintenance (godet, translation) — hors périmètre détaillé de ce document, mais `FB_Modes` doit
généraliser cet interlock, pas le réserver aux seuls treuils.

---

## 🧩 5. Nouveau FB : `FB_Encoder_Homing` (brique standard — **pas** un FB de mouvement)

⚠️ Ce FB **ne pilote aucun actionneur** — il écrit une valeur de calibration, le treuil étant
**déjà à l'arrêt confirmé**. Il **n'a donc pas** `StartStop`/`SafeStop` (Partie3 §1bis). Une
instance par treuil : `FB_Encoder_HomingM1` (COD1), `FB_Encoder_HomingM2` (COD2).

### 🔌 Interface

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | Standard |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Standard |
| `Mode` | `E_Mode` | `MAINT_N1` autorise le flux **nominal** (cible fixe 0.00 m) ; `MAINT_N2` requis pour le flux **unitaire** (cible paramétrable) |
| `WinchSelect` | `E_WinchSelect` | Doit correspondre à ce treuil pour le flux **unitaire** ; sans objet (ignoré) pour le flux nominal |
| `Home` | BOOL | Demande de référencement (**front**, entrée **unique** — mot de passe + confirmation message déjà gérés côté **IHM** en amont) |
| `HomingTargetM` | REAL | Cible de position à imposer, bornée **[-99.00 ; +99.00]** m (§3.6). Verrouillée à **0.00** en flux nominal (`MAINT_N1`) — écart toléré ε rejeté sinon (défense en profondeur, même si l'IHM ne doit normalement pas exposer ce champ hors `MAINT_N2`) |
| `ConfirmCoherence` | BOOL | Action opérateur (**front**) levant un doute §3.7, disponible `MAINT_N1` **ou** `MAINT_N2` |
| `RawPos` | `UDINT` | Valeur brute codeur courante (sortie `FB_Encoder_Abs`) |
| `EncoderAvailable` | BOOL | État bus (sortie `FB_DiagEthercat`/`FB_Encoder_Abs`) |
| `ContactorFeedbackFwd` / `Rev` | BOOL | Retours contacteurs de sens (sortie `FB_Winch`/`FB_Output_Relay`) — **arrêt confirmé** si les deux à `FALSE` |
| `BrakeFeedback` | BOOL | Retour contacteur frein — **collé** = confirmation mécanique d'arrêt |
| `PresetAck` | BOOL | Acquittement bus de l'écriture preset (sortie `FB_Encoder_Abs`, §6) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready`/`Busy`/`Done`/`Error`/`ErrorId`/`State`/`StateAtError` | — | Standard — pas de `STOPPING` (pas un FB de mouvement) |
| `PresetRequest` | BOOL | Commande vers `FB_Encoder_Abs` : déclenche l'écriture bus |
| `PresetValue` | `UDINT` | Cible brute calculée depuis `HomingTargetM` (ou `HomingRefTargetNominal` en flux nominal) |
| `Homed` | BOOL (RETAIN) | `TRUE` dès qu'un référencement a réussi — persiste, seul un nouveau homing réussi le réécrit |
| `HomingSuspect` | BOOL (RETAIN) | `TRUE` si incohérence détectée au redémarrage (§3.7) — `Homed` reste vrai mais **non fiable** tant que non levé |

`ErrorId` (bitfield, 10 bits utilisés sur 16 max) :
| Bit | Cause |
|-----|-------|
| 0 | `Home` demandé hors mode autorisé pour le flux visé (nominal hors `MAINT_N1`/`MAINT_N2`, unitaire hors `MAINT_N2`) |
| 1 | `WinchSelect` ne correspond pas à ce treuil (flux unitaire) |
| 2 | Arrêt non confirmé (contacteurs sens actifs ou frein non collé) |
| 3 | `EncoderAvailable = FALSE` |
| 4 | `HomingTargetM` hors bornage `[-99.00 ; +99.00]` m, ou ≠ 0.00 en flux nominal |
| 5 | Écriture preset refusée par le bus (`PresetAck` jamais reçu, timeout) |
| 6 | Relecture post-preset incohérente (`RawPos ≠ PresetValue` au-delà d'une tolérance) |
| 7 | Position hors bornage absolu pendant fonctionnement (§3.6, remontée depuis `FB_Encoder_Safety`) |
| 8 | Saut codeur incohérent détecté (§3.5, confirmé 3 cycles) |
| 9 | Incohérence codeur au redémarrage (§3.7) — `HomingSuspect` actif |

### 🚦 Machine d'état

```
DISABLED → (Enable) → INIT
INIT     → compare RawPos vs LastKnownRawPos (§3.7) → HomingSuspect si écart → READY
READY    → (front Home, conditions ErrorId 0/1/2/3/4 OK) → BUSY (écriture preset + attente PresetAck)
BUSY     → (PresetAck reçu + RawPos == PresetValue) → DONE → Homed:=TRUE, HomingSuspect:=FALSE,
                                                             HomingRefRaw:=PresetValue,
                                                             LastKnownRawPos:=PresetValue → READY
BUSY     → (timeout / incohérence) → ErrorId set → READY (Homed inchangé)
READY    → (front ConfirmCoherence, Mode IN MAINT_N1/N2) → HomingSuspect:=FALSE (Homed inchangé,
                                                             pas de réécriture de HomingRefRaw)
```

### 📋 Procédure opérateur

**Flux nominal** (routine, `MAINT_N1`) :
1. Descendre les 2 treuils synchronisés, godet **ouvert**, jusqu'au toucher d'eau (constat visuel
   — le capteur de contact fond, s'il existe, reste **indicatif**, ne verrouille pas le homing).
2. Relâcher le joystick — arrêt confirmé (contacteurs + frein, ErrorId bit2 à 0).
3. Appuyer le bouton IHM unique « Réf/Homing COD1+COD2 » → `Home` sur **les deux instances**
   simultanément, `HomingTargetM := 0.00` (verrouillé). Confirmation mot de passe/message gérée
   par l'IHM en amont si le niveau l'exige.
4. `Done` sur les deux instances → affichage `CablePosM` = 0.00 m sur M1 **et** M2.

**Flux unitaire** (maintenance lourde, `MAINT_N2`) :
1. Passer en `MAINT_N2` (mot de passe IHM).
2. `WinchSelect := M1` (ou `M2`) — l'autre treuil se neutralise automatiquement (§4).
3. Manœuvrer le treuil sélectionné au joystick jusqu'à la position de référence voulue.
4. Relâcher le joystick — arrêt confirmé.
5. Saisir `HomingTargetM` (IHM, paramétrable, borné §3.6) si différent de 0.00, puis appuyer
   « Réf/Homing » (IHM gère mot de passe/confirmation) → `Home` sur l'instance sélectionnée.
6. `Done` → affichage `CablePosM` = `HomingTargetM` sur le treuil concerné.
7. Répéter pour l'autre treuil si nécessaire, puis `WinchSelect := NONE` avant tout retour en
   `MANUEL`/`SEMI_AUTO` (verrou automatique §4 de toute façon).

---

## 🔧 6. Extension `FB_Encoder_Abs` (accès bus, écriture preset, principe « geler sur doute »)

L'accès EtherCAT reste **centralisé** dans `FB_Encoder_Abs` (1 FB = 1 responsabilité **d'accès
bus**) ; `FB_Encoder_Homing` orchestre la procédure, ne parle jamais EtherCAT directement.

Nouvelles entrées/sorties (prochaine itération code, §9) :

| Ajout | Type | Rôle |
|-------|------|------|
| `PresetRequest` (entrée) | BOOL | Reçu de `FB_Encoder_Homing` — déclenche l'écriture SDO/CoE |
| `PresetValue` (entrée) | `UDINT` | Valeur à écrire dans le compteur brut du codeur |
| `PresetAck` (sortie) | BOOL | Écriture bus confirmée (pulse) |
| `PresetNak` (sortie) | BOOL | Écriture bus refusée/timeout (abort SDO) |
| `AngleRaw` (sortie, **informatif**) | `UINT` | `RawPos MOD PointsPerRev` — angle intra-tour, **maintenance uniquement** |
| `TurnCount` (sortie, **informatif**) | `UDINT` | `RawPos / PointsPerRev` — nombre de tours, **maintenance uniquement** |

⚠️ **Principe « geler sur doute »** (résout l'ordonnancement `FB_Encoder_Safety` ↔ `FB_WinchSync`
relevé en revue) : si une lecture est jugée **transitoirement fausse ou invalide** (bus douteux,
saut §3.5, hors bornage §3.6), `FB_Encoder_Abs`/`FB_Encoder_Safety` **ne met pas à jour** ses
sorties de position (`RawPos` exposé, `CablePosAct`) — elles restent figées sur la **dernière
valeur plausible**. Tout consommateur aval (`FB_WinchSync`, `FB_Cycle`) ne voit donc **jamais** de
valeur transitoire fausse, quel que soit l'ordre d'appel exact dans `PLC_PRG_MAIN` — pas besoin
d'imposer un ordonnancement strict entre blocs pour ce cas.

> ⚠️ Objet CoE exact (index/subindex du preset) dépendant du modèle COD1/COD2 — à confirmer fiche
> technique. Ne **jamais réimplémenter** un recalage manuel si le codeur fournit une fonction
> preset native (Partie3 §0, réutilisation).

---

## 🛡️ 7. Sécurité / interlocks spécifiques

- **Autorisation par flux** : nominal `MAINT_N1` suffit (cohérent Partie5 §2 : « positionnement
  init après démarrage » est un usage N1 explicite) ; unitaire paramétrable **exige** `MAINT_N2`
  (maintenance lourde, cohérent Partie5 §2 : « changement de treuil/câble »).
- **Arrêt confirmé par retours d'état réels** (pas par le codeur qu'on référence) :
  `ContactorFeedbackFwd = FALSE` **ET** `ContactorFeedbackRev = FALSE` **ET** `BrakeFeedback` =
  collé. Ces retours (contacteurs sens, frein, **et disjoncteurs** — tous câblés, `ST_ContactorCheck`)
  sont des informations physiques indépendantes de la mesure que l'on s'apprête à recalibrer —
  bien plus robustes qu'une estimation de vitesse dérivée du codeur lui-même.
- **`Home` unique, confirmation IHM en amont** : le double contrôle (mot de passe + message de
  confirmation) est porté par l'IHM, pas dupliqué au niveau FB — le FB reste néanmoins le
  **dernier verrou** (vérifie `Mode`/`WinchSelect`/arrêt confirmé/bornage) en défense en
  profondeur, indépendamment de ce que l'IHM autorise ou non.
- **Bornage absolu `[-99.00 ; +99.00]` m** (§3.6) : toute valeur hors plage, en mesure comme en
  cible de homing, est rejetée — pas de risque de valeur « impossible » propagée en aval.
- **`Homed` gate `SEMI_AUTO`** : `FB_Modes` interdit `SEMI_AUTO` tant qu'un treuil a `Homed = FALSE`
  **ou** `HomingSuspect = TRUE` (référence non fiable, §3.7) — les deux conditions comptent.
- **`HomingSuspect` ≠ perte de `Homed`** : contrairement à la v1.0, une incohérence détectée ne
  remet pas `Homed` à `FALSE` (la référence n'est pas *effacée*, elle est *mise en doute*) — elle
  bloque `SEMI_AUTO` jusqu'à levée explicite (`ConfirmCoherence` ou nouveau `Home`), cohérent avec
  Partie3 §6 (« acquitter ≠ redémarrer ») appliqué ici à la **confiance dans la donnée**, pas
  seulement à l'état de mouvement.
- **`SafeStop` treuil scindé par instance** : deux blocs indépendants `FB_Safety_WinchM1` /
  `FB_Safety_WinchM2` (plutôt qu'un unique `FB_Safety_Winch` partagé) — chacun lève son propre
  `SafeStop` selon le mode et la sélection utilisateur en cours ; un défaut sur COD1/M1 n'arrête
  pas M2 sans raison si M2 est sain et non concerné (cohérent avec le pilotage unitaire déjà acté
  Partie9 — lève l'ambiguïté relevée en revue).
- **Perte codeur pendant le homing** → ErrorId bit3, retour `READY`, aucune écriture engagée côté
  `FB_Encoder_Homing` — la robustesse de la non-écriture **côté bus** (`FB_Encoder_Abs`, en cas de
  coupure pendant la fenêtre SDO elle-même) reste un point d'implémentation à vérifier fiche
  technique/tests (comportement du firmware codeur sur SDO abort en cours d'écriture).

---

## 🗺️ 8. Mapping E/S (à créer, IHM + variables)

| Élément | Variable (exemple) | Rôle |
|---------|---------------------|------|
| Sélecteur treuil (IHM, `MAINT_N2`) | `WinchSelect_IHM` | Écrit `E_WinchSelect` |
| Bouton référencement nominal (IHM) | `HomeNominalButton_IHM` | → `Home` des deux instances, `HomingTargetM:=0.00` |
| Bouton référencement unitaire (IHM, `MAINT_N2`) | `HomeUnitaireButton_IHM` | → `Home` de l'instance sélectionnée |
| Champ cible paramétrable (IHM, `MAINT_N2`) | `HomingTargetM_IHM` | → `HomingTargetM`, bornée §3.6 |
| Bouton confirmation cohérence (IHM) | `ConfirmCoherenceButton_IHM` | → `ConfirmCoherence` |
| Voyant référencé (IHM) | `HomedM1_Lamp` / `HomedM2_Lamp` | ← `Homed` |
| Voyant doute (IHM) | `HomingSuspectM1_Lamp` / `HomingSuspectM2_Lamp` | ← `HomingSuspect` |
| Affichage position | `CablePosM1_Display` / `CablePosM2_Display` | ← `FB_Encoder_Scale`, format `xx.xx` m signé |
| Affichage maintenance (angle/tours) | `AngleRawM1_Display` / `TurnCountM1_Display` (+ M2) | ← `FB_Encoder_Abs`, informatif seulement |

---

## 💻 9. État d'avancement / prochaine itération

📌 **Ce document est une conception validée fonctionnellement (v1.1), pas encore de code produit.**

- [ ] Créer `E_WinchSelect` (`_TYPES`)
- [ ] Créer `ST_EncoderCalib` (`_TYPES`) — RETAIN :
      `{ HomingRefRaw : UDINT ; LastKnownRawPos : UDINT ; RestartCoherenceTolerancePts : UDINT ;
         Homed : BOOL ; HomingSuspect : BOOL }`
- [ ] Créer `FB_Encoder_Homing` (dossier `ENCODER`), 2 instances (M1/M2)
- [ ] Étendre `FB_Encoder_Abs` : `PresetRequest`/`PresetValue`/`PresetAck`/`PresetNak`,
      `AngleRaw`/`TurnCount` informatifs, principe « geler sur doute » (§6)
- [ ] Étendre `FB_Encoder_Safety` : détection saut incohérent 3 cycles (§3.5), bornage absolu
      `[-99.00;+99.00]` m (§3.6) → `SafeStop_Winch<Mx>`
- [ ] Scinder `FB_Safety_Winch` en `FB_Safety_WinchM1`/`FB_Safety_WinchM2` (§7)
- [ ] Étendre `FB_Modes` : `WinchSelect`, verrou de transition de mode (§4), interlock `SEMI_AUTO`
      vs `Homed`/`HomingSuspect`
- [ ] Confirmer objet CoE preset exact (index/subindex) COD1/COD2 → détail implémentation §6
- [ ] Une fois codé et testé : bump `AF_Partie2_Architecture_Programme` en v2.6 (nouveaux blocs)

**Hors périmètre — à traiter séparément** :
- [ ] Variateur **AC600 (M3, translation)** : comportement pressenti sur perte de communication =
      **roue libre sans rampe** (proche d'un STO), différent du comportement treuil
      (contacteurs+frein, rampe rapide `SafeStop`). À valider et documenter dans une future mise à
      jour de `AF_Partie2`/un document dédié `FB_Translation` — pas traité ici (hors sujet codeur
      treuil).

---

## 🔁 10. Retour d'expérience (à compléter après implémentation + test)

- [ ] `HomingRefTargetNominal` = 16 777 216 pts confirmé conforme à la fiche technique définitive ?
- [ ] Flux nominal (2 treuils, `MAINT_N1`) : affichage 0.00 m cohérent au toucher d'eau réel, sur
      les deux treuils simultanément ?
- [ ] Flux unitaire (`MAINT_N2`, cible paramétrable) testé sur un seul treuil, l'autre restant
      bien immobile (neutralisation croisée effective) ?
- [ ] Arrêt confirmé (contacteurs + frein) : pas de faux positif/négatif en usage réel ?
- [ ] Bornage absolu `[-99.00;+99.00]` m : jamais déclenché en usage normal, bien bloquant si
      valeur aberrante simulée ?
- [ ] Détection de saut incohérent (3 cycles) : ni fausse alarme sur à-coup treuil en charge, ni
      détection manquée sur rebouclage simulé ?
- [ ] Détection d'incohérence au redémarrage (§3.7) testée (rotation simulée hors tension) →
      `HomingSuspect` levé, `SEMI_AUTO` bloqué, `ConfirmCoherence` fonctionnelle en `MAINT_N1`/`N2` ?
- [ ] Verrou de transition de mode (`WinchSelect:=NONE` forcé en sortie `MAINT_N2`) vérifié sur
      tous les chemins de sortie (bascule brutale, perte mot de passe, etc.) ?
- [ ] Si validé → figer les paramètres définitifs, clôturer cette v1.1.

---

## 📚 Documents liés
- **Partie 1 v1.2** — §Initialisation (référencement codeurs, description d'origine).
- **Partie 2 v2.5** — Architecture (dossier `ENCODER`, à faire évoluer v2.6 après implémentation).
- **Partie 3 v1.2** — Contrat FB §1bis (profils : ce FB n'est **pas** un FB de mouvement) et §6
  (« acquitter ≠ redémarrer », appliqué ici à la confiance dans la référence, §3.7/§7).
- **Partie 4 v1.1** — Cycle & synchro (`FB_WinchSync`, suspension pendant phases sans mouvement commun).
- **Partie 5 v1.1** — Modes & maintenance (droits `MAINT_N1`/`MAINT_N2`, usages homing/maintenance lourde).
- **Partie 9 v1.0** — Fonction Winch (`FB_Winch` pilotable unitairement, base du pilotage indépendant).
