# 📋 Analyse Fonctionnelle — Partie 10 : Référencement Codeur (Homing) & Commande Indépendante Treuils (v1.4)

> **v1.4** — Nouvel export `Device.export` (2026-07-02) : le capteur de position haute est
> désormais câblé en **I/O Mapping réel**, sous le nom **`M1_M2_TopPositionSensor`** — cela
> répond à la clarification terminologique laissée ouverte en v1.3 (« nom neutre, terminologie
> exacte en cours de clarification »). `CODE/GVL_Homing_Stub.st` est **supprimé** (conflit de nom
> avec la variable réelle sinon) ; le port d'entrée `FB_Encoder_Homing.TopPositionSensor`
> **reste nommé ainsi** côté FB (seule la variable globale qui l'alimente dans `PRG_MAIN.st`
> change de nom). Renommage métier Translation→Chariot répercuté dans les renvois croisés
> (`FB_Chariot`, préfixe I/O physique M3 inchangé).
>
> **v1.3** — Retour terrain 2026-07-02 (correction implémentation) :
> - 🔧 **`TopPositionSensor` : UN SEUL capteur physique, COMMUN aux 2 treuils** — pas un par
>   treuil. Les 2 câbles (M1/M2) hissent ensemble le même ensemble mécanique qui vient toucher ce
>   capteur unique. L'implémentation précédente (`CODE/`) avait divergé : 2 variables séparées
>   (`M1_TopPositionSensor`/`M2_TopPositionSensor`, une par GVL stub Winch) et le commentaire
>   d'entrée `FB_Encoder_Homing.TopPositionSensor` disait à tort « CE TREUIL ». Corrigé :
>   `CODE/GVL_Homing_Stub.st` (nouveau à l'époque, variable unique `TopPositionSensor` — nom
>   **neutre**, sans préfixe métier, terminologie exacte de l'ensemble mécanique en cours de
>   clarification — voir note v1.4 ci-dessus, clarification arrivée),
>   câblée IDENTIQUEMENT sur `instHomingM1` ET `instHomingM2` dans `PRG_MAIN.st`. Voir §5/§7bis/§9
>   mis à jour ci-dessous. `TopSensorPositionM` (paramètre de calibration, distinct du capteur
>   lui-même) reste réglable indépendamment par treuil (asymétrie mécanique possible même avec un
>   capteur de déclenchement commun) — **inchangé**.
>
> **v1.2** — Retour terrain 2026-07-02 (câblage réel) :
> - 🔴➜🤖 **Capteur position haute retiré de la chaîne AU matérielle** : ce n'est plus le câble
>   mécanique qui coupe directement la puissance (voir Partie1 v1.3/Partie2 v2.6 §6) — c'est
>   désormais un **capteur TOR lu par l'automate**, à **double rôle** : (1) référence répétable
>   pour le homing (bien plus fiable que le « toucher d'eau » jugé visuellement, qui varie avec
>   le niveau d'eau réel) ; (2) hors mode référencement explicite, son activation déclenche
>   `PowerCutOff` (coupure de puissance pilotée logiciel — anti-survitesse/anti-débordement haut).
>   Seuls les boutons coup-de-poing opérateur restent un AU purement matériel.
> - ✅ **Flux homing nominal réglé (§1)** : le capteur haut est **le** déclencheur (cycle d'INIT,
>   les 2 treuils), référencé à `TopSensorPositionM` (paramétrable, **≈ 12.50 m** indicatif). Le
>   « toucher d'eau » **a toujours été un simple repère visuel** pour l'opérateur, **jamais** une
>   entrée automate (précision terrain 2026-07-02 — ne pas confondre avec le capteur de contact
>   fond, BOOL, Partie4 §`BOTTOM_TOUCH_WAIT`, qui est un capteur réel mais distinct, pour le
>   touché du fond de carrière en cycle de dragage, pas pour cette calibration) : il sert ici de
>   **procédure de calibration** de `TopSensorPositionM` (voir §7bis). Le homing unitaire par
>   treuil (§1 flux 2) reste disponible **en plus**, y compris pour la mise en service.
> - 📐 **`CableM_PerRev` confirmé terrain** : **2.0 m/tour** (périmètre tambour connu — remplace
>   l'hypothèse provisoire 1.5 m/tour), toujours réglable sur site (§2/§3.3 recalculés).
> - 🔴 **Nouveau point ouvert, non conçu** : en fonctionnement normal, les treuils doivent
>   ralentir/s'arrêter **avant** la position extrême du capteur haut (qui reste une protection
>   ultime, pas une butée courante) — voir §7bis, mécanisme exact à concevoir.
> - ✅ **Confirmé terrain** : `PresettTrigCmd := 2` (valeur, pas un masque de bits) déclenche le
>   référencement. `CodeSeqTrigCmd` reste de rôle inconnu (voir §9bis/`CODE/FB_Encoder_Abs.st`).
>
> **v1.1** — Suite retour terrain (opérateur/mainteneur) et revue technique automatisme :
> - 🔢 Résolution codeur **confirmée** (8192 pts/tour × 4096 tours, plage totale 33 554 432 pts) —
>   n'est plus un exemple hypothétique (§3.3). Cible de homing nominal = **centre exact** de la
>   plage (16 777 216 pts = 0.00 m) : marge symétrique maximale, aucun risque de rebouclage.
> - 🎯 **Deux flux de homing distincts** : nominal (les 2 treuils ensemble, grappin ouvert, cible
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
> - 📝 Note hors périmètre : variateur **AC600 (M3, chariot)** — sur perte de communication,
>   comportement pressenti **roue libre sans rampe** (proche d'un STO) ≠ comportement treuil
>   (contacteurs/frein). À traiter dans un futur document dédié `FB_Chariot`/Partie2 (§9).
>
> **v1.0** — Version initiale (cinématique câble/tambour, analyse anti-débordement générique,
> sélection treuil indépendante, `FB_Encoder_Homing`).

> **Fonction métier** : permettre en **Maintenance** de piloter **M1 et M2 indépendamment**
> (montage/remplacement câble sur tambour) puis de **référencer** (« homer ») le codeur absolu de
> chaque treuil, sans jamais exposer la chaîne de calcul à un **débordement (overflow)** de
> variable ni à un **saut brutal** de valeur codeur (rollover 0 ↔ max points).
> **Cible** : CODESYS 3.5 — acquisition + mise à l'échelle codées depuis le 2026-07-02
> (`FB_Encoder_Abs`/`FB_Encoder_Scale`/`ST_EncoderCalib`), homing (`FB_Encoder_Homing`) et
> sélection treuil (`E_WinchSelect`) restent conception seule (voir §9 pour le détail exact).
> 🔗 Dépend de : [P1 Analyse Fonctionnelle v1.2](AF_Partie1_Analyse_Fonctionnelle_v1.3.md) §Initialisation,
> [P2 Architecture v2.7](AF_Partie2_Architecture_Programme_v2.7.md) (dossier `ENCODER`),
> [P3 Contrat FB v1.3](AF_Partie3_Template_FB_Commun_v1.3.md) §1bis (profils FB),
> [P4 Cycle v1.2](AF_Partie4_Cycle_Sequenceur_v1.2.md) §Initialisation/§3 Synchro,
> [P5 Modes v1.2](AF_Partie5_Modes_Maintenance_v1.2.md) §2 (`MAINT_N1`/`MAINT_N2`),
> [P9 Fonction Winch v1.1](AF_Partie9_Fonction_Winch_v1.1.md) (`FB_Winch` unitaire M1/M2).

---

## 🎯 1. Rôle métier

Lors du montage mécanique (câble neuf ou codeur remplacé), deux situations distinctes :

1. 🔝 **Homing nominal (routine, cycle d'INIT)** — ✅ **flux réglé 2026-07-02** : les 2 treuils
   montent **synchronisés** (`FB_WinchSync` actif) jusqu'au **capteur de position haute unique et
   répétable** (§7bis) ; un seul appui IHM référence **les deux codeurs simultanément** à
   `TopSensorPositionM` (paramétrable, valeur indicative aujourd'hui **≈ 12.50 m** au-dessus du
   niveau d'eau). Le **déclencheur du homing a toujours été une action opérateur** (bouton IHM),
   jamais un capteur automatisé de niveau d'eau — le contact eau **reste ce qu'il a toujours
   été** : un repère **visuel** pour l'opérateur (voir procédure de calibration §7bis), pas une
   entrée automate. ⚠️ À ne pas confondre avec le **capteur de contact fond** (BOOL, indicatif,
   Partie4 §`BOTTOM_TOUCH_WAIT`) : celui-ci détecte le **touché du fond/terre de la carrière**
   (sous l'eau, en fin de descente du cycle de dragage), un événement **différent** et à une
   **profondeur différente** du simple contact visuel avec la surface de l'eau utilisé ici pour
   la calibration.
2. 🔧 **Homing unitaire (maintenance lourde ET mise en service)** — inchangé : un seul treuil est
   mobilisé (câble/codeur remplacé sur un seul tambour, ou réglage fin en mise en service) —
   nécessite la **sélection treuil indépendante** (§4, `MAINT_N2`) et autorise une cible de
   préréglage **paramétrable** (`HomingTargetM`, pas forcément 0.00 m ni `TopSensorPositionM`).
   Reste disponible **en plus** du flux nominal (1), pas remplacé par lui.

Ce document formalise ces deux flux, la cinématique câble/tambour et l'analyse anti-débordement
(§2/§3) — c'est ce qui rend le homing **sûr**, pas seulement fonctionnel.

---

## 🧵 2. Cinématique câble/tambour — paramètres

Tambour **entraînement direct, ratio 1:1** avec le codeur absolu (COD1↔M1, COD2↔M2). Le câble de
traction s'enroule à **diamètre constant** (approximation acceptée du projet — pas de correction
multi-couche) : un tour de tambour = une longueur de câble fixe.

| Paramètre | Nom | Valeur | Rôle |
|-----------|-----|--------|------|
| Câble déroulé par tour | `CableM_PerRev` | **2.0 m/tour** (périmètre tambour confirmé, 2026-07-02) | Constante cinématique tambour ↔ câble — paramètre RETAIN, réglable |
| Longueur câble max | `MaxCableM` | **≈ 100 m** | Plage utile totale de la machine |
| Tours tambour max utiles | `DrumRevsMax` | `MaxCableM / CableM_PerRev` ≈ **50 tours** | Dérivé |
| Résolution codeur (1 tour) | `PointsPerRev` | **8192 pts/tour** (13 bits) — **confirmé** | Caractéristique matérielle COD1/COD2 |
| Capacité multitour | `MultiTurnRevsMax` | **4096 tours** (12 bits) — **confirmé** | Caractéristique matérielle COD1/COD2 |

```
DrumRevsMax = MaxCableM / CableM_PerRev = 100 / 2.0 = 50 tours
```

📌 `CableM_PerRev` reste un **paramètre** (RETAIN) — si le diamètre de tambour change, un seul
réglage à revoir (toujours ajustable sur site, confirmé 2026-07-02). `PointsPerRev`/`MultiTurnRevsMax`
sont désormais des **valeurs matérielles confirmées** (fiche technique COD1/COD2), plus une
hypothèse d'exemple.

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
| Points par mètre | `PointsPerM = PointsPerRev / CableM_PerRev` | 8192 / 2.0 = **4096** pts/m |
| Points utiles (100 m) | `MaxCableM × PointsPerM` | **409 600** pts (**≈ 1.2 %** de la plage totale) |
| **Cible homing nominal** | `HomingRefTargetNominal = MaxRawValue / 2` | **16 777 216** pts (= 0.00 m, centre exact) |
| Marge disponible de chaque côté | `HomingRefTargetNominal` | ≈ 16.8 M pts, **≈ 41× la plage utile** |

✅ Ces valeurs sont **confirmées** (fiche technique COD1/COD2 + `CableM_PerRev` terrain) — ce ne
sont plus des hypothèses d'exemple. La marge (~41×) valide largement la règle générique §3.4
(exigence ≥10×).

### 3.4 Règle générique de marge (rappel, validée par §3.3)

```
1. HomingRefTargetNominal := MaxRawValue / 2         (* centre exact — marge maximale symétrique *)
2. MargeDispo            := HomingRefTargetNominal    (* distance à chaque borne, par symétrie *)
3. PlageUtilePts          := MaxCableM × PointsPerRev / CableM_PerRev
4. EXIGER : MargeDispo >= 10 × PlageUtilePts          (* validé §3.3 : marge ≈ 41× *)
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
maintenance (grappin, chariot) — hors périmètre détaillé de ce document, mais `FB_Modes` doit
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
| `Mode` | `E_Mode` | `MAINT_N1` autorise le flux **nominal** (cible `TopSensorPositionM`) ; `MAINT_N2` requis pour le flux **unitaire** (cible `HomingTargetM` libre) |
| `WinchSelect` | `E_WinchSelect` | Doit correspondre à ce treuil pour le flux **unitaire** ; sans objet (ignoré) pour le flux nominal (les 2 treuils référencés ensemble) |
| `Home` | BOOL | Demande de référencement (**front**, entrée **unique** — mot de passe + confirmation message déjà gérés côté **IHM** en amont) |
| `M1_M2_TopPositionSensor` | BOOL | 🔧 **2026-07-02** — État du capteur de position haute **UNIQUE, COMMUN aux 2 treuils** (§7bis), désormais **I/O Mapping réel** (`GVL_Homing_Stub` supprimé). Câblé IDENTIQUEMENT sur les 2 instances. Flux nominal : `Home` n'est accepté que si `TopPositionSensor = TRUE` (confirmation physique, pas seulement la demande opérateur — cohérent avec le principe « arrêt confirmé par retours réels », voir §7) |
| `TopSensorPositionM` | REAL (RETAIN) | ✅ **2026-07-02** — Cible imposée en flux **nominal** au déclenchement par `M1_M2_TopPositionSensor` (paramétrable, valeur indicative **≈ 12.50 m**, ajustée via la procédure de calibration §7bis) |
| `HomingTargetM` | REAL | Cible de position à imposer **en flux unitaire uniquement** (`MAINT_N2`), bornée **[-99.00 ; +99.00]** m (§3.6) — remplace l'ancien usage "flux nominal verrouillé à 0.00" (le flux nominal utilise désormais `TopSensorPositionM`, pas ce champ) |
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
| `PresetValue` | `UDINT` | Cible brute calculée depuis `HomingTargetM` (flux unitaire) ou `TopSensorPositionM` (flux nominal, ✅ 2026-07-02) |
| `Homed` | BOOL (RETAIN) | `TRUE` dès qu'un référencement a réussi — persiste, seul un nouveau homing réussi le réécrit |
| `HomingSuspect` | BOOL (RETAIN) | `TRUE` si incohérence détectée au redémarrage (§3.7) — `Homed` reste vrai mais **non fiable** tant que non levé |

`ErrorId` (bitfield, 10 bits utilisés sur 16 max) :
| Bit | Cause |
|-----|-------|
| 0 | `Home` demandé hors mode autorisé pour le flux visé (nominal hors `MAINT_N1`/`MAINT_N2`, unitaire hors `MAINT_N2`) |
| 1 | `WinchSelect` ne correspond pas à ce treuil (flux unitaire) |
| 2 | Arrêt non confirmé (contacteurs sens actifs ou frein non collé) |
| 3 | `EncoderAvailable = FALSE` |
| 4 | `HomingTargetM` hors bornage `[-99.00 ; +99.00]` m (flux unitaire) ; ou flux nominal demandé sans `TopPositionSensor = TRUE` (confirmation physique manquante) |
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

**Flux nominal** (routine, `MAINT_N1`, cycle d'INIT) — ✅ **réglé 2026-07-02** :
1. Monter les 2 treuils synchronisés jusqu'au capteur de position haute (`M1_M2_TopPositionSensor`
   actif sur les deux treuils).
2. Relâcher le joystick — arrêt confirmé (contacteurs + frein, ErrorId bit2 à 0).
3. Appuyer le bouton IHM unique « Réf/Homing COD1+COD2 » → `Home` sur **les deux instances**
   simultanément ; accepté seulement si `TopPositionSensor = TRUE` sur les deux (ErrorId bit4
   sinon) ; cible = `TopSensorPositionM` (paramétrable, ≈ 12.50 m). Confirmation mot de
   passe/message gérée par l'IHM en amont si le niveau l'exige.
4. `Done` sur les deux instances → affichage `CablePosM` ≈ `TopSensorPositionM` sur M1 **et** M2.
5. **Contrôle visuel de calibration** (voir §7bis) : descendre jusqu'au contact visuel de l'eau,
   vérifier `CablePosM` ≈ 0.00 m ; sinon ajuster `TopSensorPositionM` et refaire un homing.

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

### 7bis. Capteur de position haute — double rôle (2026-07-02, ⚠️ conception, pas codé)

⚠️ **Changement d'architecture sécurité** (voir aussi Partie1 v1.3/Partie2 v2.6 §6) : le capteur
mécanique de position haute extrême, **historiquement câblé directement dans la chaîne AU
matérielle**, en a été **retiré**. C'est désormais un **capteur TOR lu par l'automate**, avec
**deux usages distincts** :

1. **Référence de homing répétable** — ✅ **flux réglé 2026-07-02** (voir §1) : contrairement au
   « toucher d'eau » (jugé visuellement, varie avec le niveau d'eau réel), ce capteur haut donne
   une position mécanique **fixe et répétable** — c'est **le** déclencheur du homing nominal
   (cycle d'INIT, les 2 treuils). Référencé à `TopSensorPositionM` (RETAIN, paramétrable, valeur
   indicative **≈ 12.50 m** au-dessus du niveau d'eau — à ajuster sur site, voir procédure de
   calibration ci-dessous).
2. **Protection anti-débordement haut, hors mode référencement** : si ce capteur s'active alors
   que le treuil concerné n'est **pas** en train de faire un homing volontaire, l'automate
   déclenche `PowerCutOff` (coupure de puissance amont, même mécanisme que le cas « contacteur
   collé » — Partie2 v2.6 §6). C'est une **responsabilité logicielle** (plus un trip matériel
   direct) : la logique doit être fiable.

### 📏 Calibration de `TopSensorPositionM` (procédure opérateur, contrôle visuel)

Le « toucher d'eau » (repère visuel de surface, **n'a jamais été** une entrée automate — à ne
pas confondre avec le capteur de contact fond réel, BOOL, utilisé ailleurs pour le cycle de
dragage, Partie4 §`BOTTOM_TOUCH_WAIT`) sert de **contrôle visuel de calibration**, réalisé
manuellement par l'opérateur :

```
1. Référencer au capteur haut (flux nominal §1) → CablePosM = TopSensorPositionM (ex. 12.50 m)
2. Descendre les 2 treuils jusqu'au contact visuel réel de l'eau
3. Lire CablePosM à cet instant :
     SI CablePosM ≈ 0.00 m (tolérance à définir, ex. ±0.10 m) → TopSensorPositionM correct
     SINON → ajuster TopSensorPositionM de l'écart constaté (RETAIN, réglage mise en service),
             puis répéter la vérification
```

🧭 Cette procédure ne nécessite **aucun code** — c'est un réglage terrain classique (comme
`CableM_PerRev`), à documenter dans la note d'application/procédure opérateur une fois
`FB_Encoder_Homing` codé.

### ⏱️ Ralentissement/arrêt avant la position extrême (2026-07-02, ⚠️ conception, pas codé)

En fonctionnement **normal** (hors homing volontaire), les treuils doivent **ralentir et
s'arrêter avant** d'atteindre le capteur de position haute — celui-ci reste une limite
**extrême** (protection ultime → `PowerCutOff`), pas une butée de fonctionnement courant.

🔴 **Non conçu en détail** : nécessite une **limite haute « normale »**, plus basse que
`TopSensorPositionM`, avec une zone de ralentissement progressif (principe similaire à
l'approche temporisée de `FB_Chariot`, Partie4 §5) — probablement un paramètre RETAIN
supplémentaire (ex. `NormalTopLimitM`, à définir) consommé par `FB_Winch`/`FB_Cycle` en aval de
`CablePosM`. À concevoir dans le même lot que `FB_Encoder_Homing`/`FB_Encoder_Safety` — pas
avant, et pas improvisé ici sans validation explicite du mécanisme de ralentissement souhaité
(paliers vitesse existants réutilisables, ou rampe dédiée ?).

```
SI CapteurPositionHaute = TRUE ET NOT EnModeReferencement(CeTreuil) ALORS
    → PowerCutOff := TRUE   (FB_Safety_WinchM1/M2, selon le treuil concerné)
SINON (en mode référencement actif sur ce treuil)
    → capteur consommé par FB_Encoder_Homing comme référence, PAS de PowerCutOff
```

🧭 **Seuls les boutons coup-de-poing opérateur restent un AU purement matériel** — cette
protection-ci dépend entièrement de l'automate (alimentation continue de l'automate déjà acquise,
Partie1 §Sécurité électrique, mais la logique de coupure elle-même doit être irréprochable :
`EnModeReferencement` devra être une condition **fiable et univoque**, portée par `FB_Modes`/
`FB_Encoder_Homing`, pas une simple variable IHM non vérifiée).

🔴 **Non implémenté** : nécessite `FB_Encoder_Homing` (pour poser `EnModeReferencement` de façon
fiable) et l'extension `FB_Safety_Winch` correspondante (nouvelle entrée `M1_M2_TopPositionSensor` +
`InReferencingMode`, nouvelle logique `PowerCutOff`) — à faire dans le même lot que
`FB_Encoder_Homing` (§9), pas avant.

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

📌 **Lot "Codeur — acquisition + mise à l'échelle" démarré le 2026-07-02** (voir
`DOC/AF_Partie9_Fonction_Winch_v1.1.md` §9 pour le lien avec l'intégration M2).

- [ ] Créer `E_WinchSelect` (`_TYPES`) — pas dans ce lot (lié au sélecteur M1/M2/Les deux, hors périmètre acquisition/échelle)
- [x] Créer `ST_EncoderCalib` (`_TYPES`) — ✅ 2026-07-02 : géré en interne par `FB_Encoder_Homing`
      (`VAR RETAIN Calib`), plus par des instances séparées dans `PRG_MAIN` (`M1_EncoderCalib`/
      `M2_EncoderCalib` retirées, redondantes désormais).
- [x] Créer `FB_Encoder_Homing` (dossier `ENCODER`), 2 instances (M1/M2) — ✅ 2026-07-02, **flux
      NOMINAL uniquement** (capteur haut + bouton IHM). Flux unitaire (`WinchSelect`) toujours
      différé. `HomingRefRaw` ajouté en sortie explicite (extension vs interface §5 d'origine,
      nécessaire pour une cible non nulle — voir en-tête `CODE/FB_Encoder_Homing.st`).
- [x] Étendre `FB_Encoder_Abs` : `PresetRequest`/`PresetValue`/`PresetAck`/`PresetNak`,
      `AngleRaw`/`TurnCount` informatifs, principe « geler sur doute » (§6) — **✅ `PresetTriggerCmd
      := 2` confirmé terrain 2026-07-02** (déclenche le référencement) ; `CodeSeqTriggerCmd`
      reste à `0`, rôle **non identifié** (voir `CODE/FB_Encoder_Abs.st`)
- [ ] Étendre `FB_Encoder_Safety` : détection saut incohérent 3 cycles (§3.5), bornage absolu
      `[-99.00;+99.00]` m (§3.6) → `SafeStop_Winch<Mx>` — pas dans ce lot. 🔴 Note : l'ancienne
      composition `FB_Encoder_Safety` (survitesse) dans `FB_Encoder_Abs` a été retirée lors de
      la réécriture (Partie10 ne la demande pas) — `FB_Encoder_Safety` est **orphelin** tant que
      ce point n'est pas traité (fusion avec le "saut incohérent", ou reprise telle quelle,
      à trancher dans ce futur lot).
- [x] Scinder `FB_Safety_Winch` en instances `FB_Safety_WinchM1`/`FB_Safety_WinchM2` (§7) — **1
      seul TYPE FB `FB_Safety_Winch`, 2 INSTANCES** (`instSafetyWinchM1`/`instSafetyWinchM2`),
      chacune câblée sur l'`EncoderAvailable` de son treuil (composition, pas duplication de
      code) — interprétation retenue pour "scindé en 2 instances indépendantes"
- [ ] Étendre `FB_Modes` : `WinchSelect`, verrou de transition de mode (§4), interlock `SEMI_AUTO`
      vs `Homed`/`HomingSuspect` — pas dans ce lot (`FB_Modes` n'existe toujours pas)
- [ ] Confirmer le rôle de `CodeSeqTrigCmd` (`COD1_CodeSeqTrigCmd`/`COD2_CodeSeqTrigCmd`) — seul
      point encore inconnu de la séquence preset (`PresettTrigCmd`/`PresetValue` confirmés)
- [x] Flux homing nominal réglé (§1/§7bis, 2026-07-02) : capteur haut = déclencheur unique,
      `TopSensorPositionM` ≈ 12.50 m paramétrable, toucher d'eau = contrôle visuel de calibration
- [ ] Coder l'extension `FB_Safety_Winch` (§7bis) : `M1_M2_TopPositionSensor`, `InReferencingMode` →
      `PowerCutOff` — dépend de `FB_Encoder_Homing` (fournit `InReferencingMode` de façon fiable)
- [ ] Concevoir + coder la limite haute « normale » (ralentissement avant position extrême, §7bis)
      — mécanisme non défini (paliers existants réutilisables ou rampe dédiée ? à trancher)
- [x] `AF_Partie2_Architecture_Programme` bumpée en v2.6 (2026-07-02, correctif AU/PowerCutOff §6)

**➕ Ajout hors checklist initiale — intégration M2 (décision 2026-07-02, voir Partie9 §9)** :
`instWinchM2`/`instSafetyWinchM2` créés et **actifs**, consigne dupliquée sur l'axe Y du
joystick (même source que M1), **sans** `E_WinchSelect` ni `FB_WinchSync` réel — deux treuils
bougent ensemble sans régulation d'écart. Canaux `COD2_*` (I/O Mapping) **mappés 2026-07-02**
(miroir de `COD1_*`, voir §9bis point 9).

**Hors périmètre — à traiter séparément** :
- [ ] Variateur **AC600 (M3, chariot)** : comportement pressenti sur perte de communication =
      **roue libre sans rampe** (proche d'un STO), différent du comportement treuil
      (contacteurs+frein, rampe rapide `SafeStop`). À valider et documenter dans une future mise à
      jour de `AF_Partie2`/un document dédié `FB_Chariot` — pas traité ici (hors sujet codeur
      treuil).

---

## 📝 9bis. Note d'application CODESYS 3.5 (lot acquisition + mise à l'échelle, 2026-07-02)

> Référence code : `CODE/ST_EncoderCalib.st`, `CODE/FB_Encoder_Abs.st`, `CODE/FB_Encoder_Scale.st`,
> `CODE/FB_Safety_Winch.st` (mis à jour), `CODE/FB_Winch.st`/`CODE/GVL_Winch_M2_Stub.st` (M2),
> `CODE/PRG_MAIN.st` (mis à jour).

1. **`ST_EncoderCalib`** : DUT Structure (racine `Application`, comme `ST_SpeedStepTable`).
2. **`FB_Encoder_Abs`** : POU **existant** (dossier `CODEUR`) — remplacer ENTIÈREMENT déclaration
   + implémentation par `CODE/FB_Encoder_Abs.st` (réécriture complète, pas un ajout).
3. **`FB_Encoder_Scale`** : POU **existant** (dossier `CODEUR`) — remplacer ENTIÈREMENT, même
   principe.
4. **`FB_Safety_Winch`** : POU **existant** (dossier `SAFETY`) — mettre à jour (ajout entrée
   `EncoderAvailable` + logique bit1), ne pas recréer.
5. **`FB_Winch`** : aucun changement de code pour M2 (même TYPE, juste une 2ᵉ instance dans
   `PRG_MAIN`) — rien à recoller ici si déjà à jour.
6. **`GVL_Winch_M2_Stub`** : nouveau GVL, même procédure que `GVL_Winch_M1_Stub` (Partie9 §7
   Étape 9bis).
7. **`PRG_MAIN`** : remplacer déclaration + implémentation par `CODE/PRG_MAIN.st`.
8. **🔴 `PRG_COD1`** : POU legacy orphelin (dossier `CODEUR`) — **supprimer manuellement**
   (clic droit → Delete). Sa logique est remplacée par les instances directes dans `PRG_MAIN`.
9. **✅ I/O Mapping COD2 fait (2026-07-02)** : les canaux `COD2_PosValue`/`COD2_Alarms`/
   `COD2_Warnings`/`COD2_PresetValue`/`COD2_PresettTrigCmd`/`COD2_CodeSeqTrigCmd` sont mappés
   (miroir de `COD1_*`). `GVL_Encoder_M2_Stub` (temporaire, voir 9ter historique) est **retiré**
   du projet — supprimer aussi le GVL correspondant dans CODESYS s'il avait été créé (conflit de
   nom sinon avec les variables I/O Mapping).

### 9ter. *(Historique, résolu 2026-07-02)* Stub logiciel COD2
~~Si le mapping I/O réel de `COD2_CODEUR` n'est pas encore prêt, créer `GVL_Encoder_M2_Stub`~~ —
**plus nécessaire**, le mapping réel est fait (point 9 ci-dessus). Conservé ici uniquement comme
trace de la démarche suivie, au cas où un futur codeur non encore câblé se retrouve dans le même
cas (même principe que `GVL_Winch_M1_Stub`/`GVL_Winch_M2_Stub`, Partie9 §7 Étape 9bis).
10. **⚠️ Vérifier le type exact de `COD1_PosValue`/`COD2_PosValue`** dans CODESYS (Library/IO
    Mapping) avant de compiler : le code suppose `UDINT`. Si CODESYS l'a créé en `DWORD` (les
    deux occupent 32 bits mais restent des types distincts en IEC strict), ajouter une
    conversion explicite `DWORD_TO_UDINT(...)` au câblage `RawPosIn := ...` dans `PRG_MAIN`.
11. **Rebuild** : erreurs attendues avant l'étape 9 (I/O Mapping COD2) — normal, à corriger dans
    l'ordre indiqué.

### 9quater. Note d'application — `FB_Encoder_Homing` (lot Homing, 2026-07-02, mis à jour v1.4)

Référence code : `CODE/FB_Encoder_Homing.st`, `CODE/PRG_MAIN.st` — `M1_M2_TopPositionSensor`
est désormais **I/O Mapping réel** (plus de GVL à créer pour ce signal).

1. **`FB_Encoder_Homing`** : POU dossier `ENCODER` (comme `FB_Encoder_Abs`/`Scale`).
   `Add Object → POU...` → Name = `FB_Encoder_Homing`, Type = `Function block`, Language =
   `Structured Text (ST)` → coller déclaration + implémentation.
2. **🔴 `GVL_Homing_Stub` : SUPPRIMER** (clic droit → Delete dans l'arbre projet, s'il avait été
   créé v1.3) — `M1_M2_TopPositionSensor` est désormais une variable réelle créée par l'I/O
   Mapping (conflit de nom sinon). Vérifier dans l'onglet I/O Mapping du canal physique
   concerné que la colonne **Variable** contient bien `M1_M2_TopPositionSensor`.
3. **`PRG_MAIN`** : remplacer déclaration + implémentation en entier (câblage
   `TopPositionSensor := M1_M2_TopPositionSensor` sur `instHomingM1` ET `instHomingM2`).
4. **Rebuild.**

### 🧪 Procédure de test (COD1/COD2 réels, capteur position haute désormais réel)

`M1_M2_TopPositionSensor` étant câblé en I/O Mapping réel, la séquence se teste **physiquement**
(actionner le capteur) plutôt que par forçage logiciel :

```
1. Vérifier ArretConfirme : joystick au neutre (M1_RelayFwd/Rev = FALSE, M1_BrakeCmd = FALSE
   → collé), sinon Home sera rejeté (ErrorId bit2).
2. Actionner physiquement le capteur position haute (ou forcer M1_M2_TopPositionSensor := TRUE
   en vue instance CODESYS si le matériel n'est pas encore accessible) — capteur UNIQUE, un seul
   forçage/actionnement suffit pour les 2 instances M1/M2.
3. Basculer StubHomeButton_IHM : FALSE → TRUE → FALSE (simule l'appui bouton IHM, front).
4. Observer instHomingM1 : Busy doit passer TRUE brièvement, puis Done pulse à TRUE,
   Homed := TRUE, ErrorId reste à 0.
5. Observer instEncoderScaleM1.CablePosM : doit afficher ≈ M1_TopSensorPositionM (12.50 m par
   défaut) — CORRESPONDANCE ATTENDUE avec PresetValue = HomingRefTargetNominal (16 777 216 pts)
   sur instEncoderAbsM1.RawPos une fois PresetAck reçu (dépend du COD1 réel — si le codeur COD1
   n'accepte pas encore le preset réellement, PresetNak/timeout est attendu tant que
   CodeSeqTrigCmd n'est pas confirmé, voir points bloquants ci-dessous).
6. Répéter pour M2 (même capteur commun) — le même bouton IHM déclenche les deux.
```

⚠️ Sans le capteur `M1_M2_TopPositionSensor` actif (ou forcé), `Home` sera **systématiquement
rejeté** (`ErrorId` bit4) — c'est le comportement voulu, pas une erreur.

### 🔒 Points bloquants avant tout essai réel (pas des bugs, des TODO explicites)
- **Séquence preset** : `PresetTriggerCmd := 2` **confirmé terrain** (déclenche le
  référencement à `PresetValueOut`). Seul `CodeSeqTriggerCmd` reste de rôle **inconnu** (laissé
  à `0`, non piloté). `PresetRequest` est de toute façon figé `FALSE` dans `PRG_MAIN` pour
  l'instant (aucun risque immédiat, la séquence ne se déclenche jamais tant que
  `FB_Encoder_Homing` ne pilote pas `PresetRequest`).
- **`FB_Encoder_Safety` (survitesse) orphelin** : plus appelé depuis la réécriture de
  `FB_Encoder_Abs` — à trancher dans le lot dédié `FB_Encoder_Safety` (§9).
- **M1 et M2 bougent ensemble sans synchro** (voir Partie9 §9) — vigilance visuelle requise
  pendant tout essai avec les deux treuils actifs.

---

## 🔁 10. Retour d'expérience (à compléter après implémentation + test)

- [ ] `HomingRefTargetNominal` = 16 777 216 pts confirmé conforme à la fiche technique définitive ?
- [ ] Flux nominal (2 treuils, `MAINT_N1`) : `Home` refusé sans `M1_M2_TopPositionSensor` confirmé sur
      les deux, `CablePosM` ≈ `TopSensorPositionM` après homing, sur les deux treuils simultanément ?
- [ ] Calibration `TopSensorPositionM` (§7bis) : après homing haut, `CablePosM` ≈ 0.00 m au
      contact visuel réel de l'eau ? Sinon, ajustement du paramètre suffisant pour converger ?
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
- **Partie 2 v2.7** — Architecture (dossier `ENCODER`, à faire évoluer v2.6 après implémentation).
- **Partie 3 v1.3** — Contrat FB §1bis (profils : ce FB n'est **pas** un FB de mouvement) et §6
  (« acquitter ≠ redémarrer », appliqué ici à la confiance dans la référence, §3.7/§7).
- **Partie 4 v1.2** — Cycle & synchro (`FB_WinchSync`, suspension pendant phases sans mouvement commun).
- **Partie 5 v1.2** — Modes & maintenance (droits `MAINT_N1`/`MAINT_N2`, usages homing/maintenance lourde).
- **Partie 9 v1.1** — Fonction Winch (`FB_Winch` pilotable unitairement, base du pilotage indépendant).
