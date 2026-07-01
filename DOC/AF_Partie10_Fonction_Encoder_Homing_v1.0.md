# 📋 Analyse Fonctionnelle — Partie 10 : Référencement Codeur (Homing) & Commande Indépendante Treuils (v1.0)

> **Fonction métier** : permettre en **Maintenance N2** de piloter **M1 et M2 indépendamment**
> (montage/remplacement câble sur tambour) puis de **référencer** (« homer ») le codeur absolu de
> chaque treuil sur le plan d'eau, sans jamais exposer la chaîne de calcul à un **débordement
> (overflow)** de variable ni à un **saut brutal** de valeur codeur (rollover 0 ↔ max points).
> **Cible** : CODESYS 3.5 — document de **conception**, pas encore de code généré (voir §9).
> 🔗 Dépend de : [P1 Analyse Fonctionnelle v1.2](AF_Partie1_Analyse_Fonctionnelle_v1.2.md) §Initialisation,
> [P2 Architecture v2.5](AF_Partie2_Architecture_Programme_v2.5.md) (dossier `ENCODER`),
> [P3 Contrat FB v1.2](AF_Partie3_Template_FB_Commun_v1.2.md) §1bis (profils FB),
> [P4 Cycle v1.1](AF_Partie4_Cycle_Sequenceur_v1.1.md) §Initialisation/§3 Synchro,
> [P5 Modes v1.1](AF_Partie5_Modes_Maintenance_v1.1.md) §2 (MAINT_N2),
> [P9 Fonction Winch v1.0](AF_Partie9_Fonction_Winch_v1.0.md) (`FB_Winch` unitaire M1/M2).

---

## 🎯 1. Rôle métier

Lors du montage mécanique (câble neuf ou codeur remplacé), le câble est ré-enroulé sur le
tambour **treuil par treuil**. Il faut alors :

1. 🕹️ **Commander M1 ou M2 seul** (l'autre reste neutralisé ou géré séparément) — le pilotage
   synchronisé (`FB_WinchSync`) n'a ici aucun sens : on veut justement bouger **un seul** tambour.
2. 🌊 **Descendre** le tambour sélectionné jusqu'au **toucher d'eau** (plan de référence, constat
   **visuel opérateur** — pas de capteur dédié, cf. Partie1 §Initialisation).
3. 🎯 **Référencer** (« homer ») le codeur absolu de ce treuil à cet instant : le compteur brut
   EtherCAT est **repositionné** (preset) sur une valeur de consigne connue, choisie avec une
   **marge de sécurité** garantissant qu'aucun usage normal — ni même une dérive de maintenance
   raisonnable — ne rapproche jamais la mesure des bornes de la variable ou du compteur.
4. 🔁 **Répéter** pour l'autre treuil.

Ce document formalise ces deux briques manquantes : la **sélection treuil indépendante**
(§4) et le nouveau bloc **`FB_Encoder_Homing`** (§5). La cinématique câble/tambour et l'analyse
anti-débordement (§2/§3) sont le cœur du sujet — c'est ce qui rend le homing **sûr**, pas
seulement fonctionnel.

---

## 🧵 2. Cinématique câble/tambour — paramètres

Tambour **entraînement direct, ratio 1:1** avec le codeur absolu (COD1↔M1, COD2↔M2). Le câble de
traction s'enroule à **diamètre constant** (approximation acceptée du projet — pas de correction
multi-couche) : un tour de tambour = une longueur de câble fixe.

| Paramètre | Nom | Valeur (exemple site) | Rôle |
|-----------|-----|------------------------|------|
| Câble déroulé par tour | `CableM_PerRev` | **1.5 m/tour** | Constante cinématique tambour ↔ câble |
| Longueur câble max | `MaxCableM` | **≈ 100 m** | Plage utile totale de la machine |
| Tours tambour max utiles | `DrumRevsMax` | `MaxCableM / CableM_PerRev` ≈ **66.7 tours** | Dérivé — plage réellement parcourue |

```
DrumRevsMax = MaxCableM / CableM_PerRev = 100 / 1.5 ≈ 66.7 tours
```

📌 **`CableM_PerRev` est un paramètre** (RETAIN, réglable), pas une constante codée en dur — si le
diamètre de tambour change (autre machine, ré-étalonnage), un seul paramètre à revoir.

Formule générale de conversion points → mètres (déjà actée Partie2 §4, `FB_Encoder_Scale` via
`LIN_TRAFO`) :

```
PointsPerM  = PointsPerRev / CableM_PerRev
CablePosM   = (RawPos − HomingRefRaw) × (CableM_PerRev / PointsPerRev)
```

`PointsPerRev` = résolution codeur (points par tour, tour unique) — **caractéristique matérielle**
du modèle COD1/COD2 retenu, à confirmer fiche technique (voir exemple chiffré §3.3).

---

## 🧮 3. Analyse anti-débordement (overflow) — cœur du sujet

C'est le point de vigilance explicitement soulevé : ~100 m de câble représente peu de tours
(≈ 67), donc peu de « points » réels comparé à la capacité totale d'un codeur absolu multitour —
mais il faut le **démontrer par le calcul**, pas le supposer.

### 3.1 Bornes des types utilisés

| Donnée | Type retenu | Bornes | Pourquoi |
|--------|-------------|--------|----------|
| `RawPos` (valeur brute codeur, lue EtherCAT) | `UDINT` | 0 .. 4 294 967 295 | Format natif habituel des codeurs absolus multitour (registre 32 bits **non signé**) — ne pas convertir en `DINT` avant soustraction (voir 3.2) |
| `HomingRefRaw` (valeur de préréglage au homing) | `UDINT` (RETAIN) | idem | Même type que `RawPos` — la soustraction se fait **entre deux `UDINT` proches**, jamais sur la valeur brute complète |
| `RawPos − HomingRefRaw` (écart depuis référence) | `DINT` | ±2 147 483 647 | Signé : le câble peut descendre sous la référence (marge négative tolérée, cf. §3.4) |
| `CablePosM` (position affichée) | `REAL` | ±3.4×10³⁸, mantisse 24 bits (~7 chiffres significatifs) | Largement suffisant pour ±100 m à 2 décimales (10 000 centièmes ≪ 2²⁴) |

⚠️ **Piège à éviter** : si `RawPos` natif est un `UDINT` 32 bits pleine échelle, **la moitié de
cette plage (2 147 483 648) dépasse déjà la borne haute d'un `DINT` signé** (2 147 483 647). Un
préréglage naïf « au milieu de la plage codeur » calculé puis stocké/comparé en `DINT` peut donc
**lui-même provoquer un dépassement silencieux**, indépendamment du codeur. Règle retenue :
- `RawPos` et `HomingRefRaw` restent en `UDINT` de bout en bout.
- Seul l'**écart** `RawPos − HomingRefRaw` (toujours petit par construction, voir 3.3) est
  converti en `DINT` puis `REAL`.

### 3.2 Principe : ne jamais rapprocher la mesure des bornes matérielles

Le compteur brut d'un codeur absolu multitour **rebouclage compris** ne va pas de `-∞` à `+∞` : il
est borné (`0 .. MaxRawValue`) et **reboucle** (au-delà de `MaxRawValue` → retour à `0`, ou
l'inverse en dessous de `0`). Un « saut brutal de 0 à +points max » n'est rien d'autre que la
mesure qui **traverse cette frontière de rebouclage** pendant l'usage normal — exactement le cas
que l'utilisateur redoute.

✅ **Parade retenue** : le homing **repositionne activement** le compteur brut sur une valeur de
consigne fixe (`HomingRefTarget`) choisie **au milieu** de la plage utile du codeur, à **chaque**
référencement (pas seulement à la mise en service). Ainsi la fenêtre réellement parcourue en
exploitation (`± DrumRevsMax` en points, avec marge — §3.4) reste **toujours** loin des deux
bornes, quelle que soit la dérive accumulée lors des montages précédents.

### 3.3 Exemple chiffré (codeur multitour 13 bits tour + 12 bits multitour — À CONFIRMER fiche technique COD1/COD2)

| Grandeur | Formule | Valeur exemple |
|----------|---------|----------------|
| Résolution simple tour | `PointsPerRev` | 8192 pts/tour (13 bits) |
| Tours mémorisables | `MultiTurnRevsMax` | 4096 tours (12 bits) |
| Plage brute totale | `MaxRawValue = PointsPerRev × MultiTurnRevsMax − 1` | 33 554 431 (~33.5 M pts, 25 bits) |
| Points par mètre | `PointsPerM = PointsPerRev / CableM_PerRev` | 8192 / 1.5 ≈ 5461.3 pts/m |
| Points utiles (100 m) | `MaxCableM × PointsPerM` | ≈ 546 133 pts (**1.6 % seulement** de la plage totale) |
| Préréglage retenu | `HomingRefTarget = MaxRawValue / 2` | ≈ 16 777 215 |
| Marge disponible de chaque côté | `HomingRefTarget` (≈16.8 M pts) | ≈ **30× la plage utile** (546 133 pts) |

> ⚠️ Ces chiffres sont un **exemple plausible** (codeur multitour 13 bits/12 bits, format courant
> du marché) — **à remplacer par la fiche technique réelle** de COD1/COD2 avant mise en service.
> La méthode (§3.4, règle générique) reste valable quel que soit le modèle retenu.

### 3.4 Règle générique de marge (indépendante du modèle de codeur)

```
1. HomingRefTarget := MaxRawValue / 2                     (* milieu de plage — marge maximale symétrique *)
2. MargeDispo      := HomingRefTarget                     (* distance à chaque borne, par symétrie *)
3. PlageUtilePts   := MaxCableM × PointsPerRev / CableM_PerRev
4. EXIGER : MargeDispo >= FacteurSecurite × PlageUtilePts   (* FacteurSecurite retenu >= 10 *)
5. EXIGER : HomingRefTarget converti en DINT reste < 2^31 − 1  (* piège §3.1 *)
```

Si l'exigence 4 échoue (codeur bas de gamme, plage totale trop proche de la plage utile), c'est un
**signal d'alerte matériel** : le codeur choisi n'a pas assez de dynamique pour ce projet — à
remonter avant achat/câblage, pas à contourner en logiciel.

### 3.5 Et si un dépassement survient quand même ? (dérive maintenance, codeur mort, bruit bus)

La marge (§3.4) protège l'usage **normal**. En Maintenance N2, un opérateur peut malgré tout
dérouler bien au-delà de 100 m par erreur, ou un défaut bus/codeur peut renvoyer une valeur
aberrante. Parade : **limitation de plausibilité de vitesse**, dans `FB_Encoder_Safety` (bloc déjà
prévu Partie2 §4, responsabilité « cohérence position / limites ») :

```
ΔRawPos_Cycle := |RawPos(k) − RawPos(k−1)|          (* entre deux cycles EtherCAT, 4 ms *)
ΔRawPos_Max   := VitesseTreuilMax_MPS × PointsPerM × 0.004   (* déplacement physiquement possible en 4 ms *)

SI ΔRawPos_Cycle > ΔRawPos_Max × MargeBruit(ex. ×3) ALORS
    → ErrorId bit dédié « saut codeur incohérent »
    → SafeStop_Winch (bloc safety métier concerné, Partie3 §7bis)
    → RawPos figé sur la dernière valeur plausible (StateAtError)
    → Obligation de repasser par MAINT_N2 + re-homing
```

🧭 Cette limite de plausibilité est **indépendante** de la marge de préréglage : elle détecte
*toute* incohérence de saut (rebouclage réel, bruit EtherCAT, codeur défaillant), qu'elle vienne
ou non d'un franchissement de borne. C'est la **deuxième ligne de défense** — la marge (§3.4)
évite le problème dans 100 % des cas normaux, cette limite **rattrape** le reste.

---

## 🔌 4. Sélection treuil indépendante (MAINT_N2)

`FB_WinchSync` (Partie9 §2, Partie4 §3) n'a pas de sens pendant le homing : on veut bouger **un
seul** tambour, l'autre devant rester **strictement immobile** (câble déjà référencé, ou pas
encore installé). Nouvel élément d'arbitrage, à ajouter à `FB_Modes` (Partie5 §2 override N2) :

```codesys
TYPE E_WinchSelect :
ENUM
  NONE := 0;   (* Aucun treuil sélectionné — commande neutralisée des deux côtés *)
  M1   := 1;   (* Consigne joystick/IHM routée vers M1 seul *)
  M2   := 2;   (* Consigne joystick/IHM routée vers M2 seul *)
END_ENUM
END_TYPE
```

| Règle | Détail |
|-------|--------|
| Sélection | Sélecteur IHM (bouton/rotatif) `WinchSelect`, actif **uniquement** en `MAINT_N2` |
| Routage | La consigne joystick (`ST_AxisCmd`) n'alimente **que** le `FB_Winch` correspondant à `WinchSelect` ; l'autre reçoit `Enable := FALSE` (neutralisé, pas juste `StartStop := FALSE`) |
| Synchro | `FB_WinchSync.Enable := FALSE` tant que `WinchSelect <> NONE` (cohérent avec l'override déjà prévu Partie5 §2 — ici **automatique**, pas une case à cocher séparée, puisque un seul treuil bouge) |
| Homme-mort | Le joystick reste la seule source de mouvement — relâcher = arrêt rampe normale (`StartStop := FALSE`), comme partout ailleurs (Partie3 §Règles socle) |
| Retour à la normale | `WinchSelect := NONE` avant tout retour en `MANUEL`/`SEMI_AUTO` (interlock `FB_Modes` : `SEMI_AUTO` refusé si `WinchSelect <> NONE`) |

---

## 🧩 5. Nouveau FB : `FB_Encoder_Homing` (brique standard — **pas** un FB de mouvement)

⚠️ **Audit guardrail respecté** : ce FB **ne pilote aucun actionneur** — il écrit une valeur de
calibration dans la chaîne de mesure, le treuil étant **déjà à l'arrêt** au moment du homing. Il
**n'a donc pas** `StartStop`/`SafeStop` (Partie3 §1bis, réservé aux FB de mouvement `FB_Winch`/
`FB_Translation`). Une instance par treuil : `FB_Encoder_HomingM1` (COD1), `FB_Encoder_HomingM2` (COD2).

### 🔌 Interface

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | Standard (Partie3 §1) |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Standard |
| `Mode` | `E_Mode` | Doit valoir `MAINT_N2` pour autoriser le homing (bit ErrorId sinon) |
| `WinchSelect` | `E_WinchSelect` | Doit correspondre **à ce treuil** (M1 pour l'instance M1, etc.) |
| `Home` | BOOL | Demande de référencement (**front**) — verbe, cf. convention |
| `ConfirmHome` | BOOL | Confirmation (**front**, fenêtre de validité courte — anti-appui accidentel) |
| `RawPos` | `UDINT` | Valeur brute codeur courante (sortie `FB_Encoder_Abs`) |
| `EncoderAvailable` | BOOL | État bus (sortie `FB_DiagEthercat` / `FB_Encoder_Abs`) |
| `WinchSpeedNull` | BOOL | Confirmation vitesse treuil ≈ 0 (sortie `FB_Winch`/estimation codeur) |
| `HomingRefTarget` | `UDINT` | Valeur brute cible à imposer (paramètre figé §3.4, identique COD1/COD2 si même modèle) |
| `PresetAck` | BOOL | Acquittement bus de l'écriture preset (sortie `FB_Encoder_Abs`, voir §6) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready`/`Busy`/`Done`/`Error`/`ErrorId`/`State`/`StateAtError` | — | Standard (Partie3 §1) — pas de `STOPPING` (pas un FB de mouvement) |
| `PresetRequest` | BOOL | Commande vers `FB_Encoder_Abs` : déclenche l'écriture bus (§6) |
| `PresetValue` | `UDINT` | = `HomingRefTarget`, transmis à `FB_Encoder_Abs` |
| `Homed` | BOOL (RETAIN) | `TRUE` dès qu'un référencement a réussi pour ce treuil — persiste (survit coupure secteur), remis à `FALSE` uniquement par un nouveau homing raté... non : **jamais remis à `FALSE` automatiquement**, seul un nouveau homing réussi le réécrit. Utilisé par `FB_Modes` pour interdire `SEMI_AUTO` tant que `Homed = FALSE` |

`ErrorId` (bitfield, 7 bits utilisés sur 16 max) :
| Bit | Cause |
|-----|-------|
| 0 | `Home` demandé hors `MAINT_N2` (droit refusé) |
| 1 | `WinchSelect` ne correspond pas à ce treuil |
| 2 | Vitesse treuil non nulle (`WinchSpeedNull = FALSE`) au moment de la demande |
| 3 | `EncoderAvailable = FALSE` |
| 4 | `ConfirmHome` absent ou hors délai (timeout) |
| 5 | Écriture preset refusée par le bus (`PresetAck` jamais reçu, timeout) |
| 6 | Relecture post-preset incohérente (`RawPos ≠ HomingRefTarget` au-delà d'une tolérance) |

### 🚦 Machine d'état (sous-ensemble de `E_State`, pas de `STOPPING`)

```
DISABLED  → (Enable) → INIT → READY
READY     → (front Home, toutes conditions §ErrorId OK) → BUSY (attente ConfirmHome)
BUSY      → (front ConfirmHome dans le délai) → BUSY (écriture preset + attente PresetAck)
BUSY      → (PresetAck reçu + RawPos == HomingRefTarget) → DONE → Homed := TRUE → READY
BUSY      → (timeout / incohérence) → ErrorId set → READY (Homed inchangé)
```

### 📋 Procédure opérateur (pas à pas, mise à jour de Partie1 §Initialisation)

1. Passer en `MAINT_N2` (mot de passe).
2. `WinchSelect := M1` (ou `M2`) — l'autre treuil se neutralise automatiquement (§4).
3. Descendre le treuil sélectionné au joystick jusqu'au **toucher d'eau** (constat visuel).
4. Relâcher le joystick — vitesse confirmée nulle (`WinchSpeedNull`).
5. Appuyer `Home` (front) puis `ConfirmHome` (front, double validation anti-erreur).
6. `FB_Encoder_HomingMx` vérifie les conditions, écrit le preset (§6), relit et confirme → `Done`,
   `Homed := TRUE`. Affichage `CablePosM` = 0.00 m à cet instant (§2, formule).
7. Répéter pour l'autre treuil (`WinchSelect := M2`, étapes 3 à 6).
8. `WinchSelect := NONE` avant de repasser en `MANUEL`/`SEMI_AUTO`.

---

## 🔧 6. Extension `FB_Encoder_Abs` (écriture preset bas niveau)

Pour ne pas dupliquer l'accès bus (déjà centralisé dans `FB_Encoder_Abs`, Partie2 §4 : « lecture
points bruts EtherCAT + validation »), l'écriture du preset **reste dans `FB_Encoder_Abs`** — 1 FB
= 1 responsabilité **d'accès bus**, `FB_Encoder_Homing` orchestre, ne parle pas EtherCAT lui-même.

Nouvelles entrées/sorties à ajouter (prochaine itération code, voir §9) :

| Ajout | Type | Rôle |
|-------|------|------|
| `PresetRequest` (entrée) | BOOL | Reçu de `FB_Encoder_Homing` — déclenche l'écriture SDO/CoE |
| `PresetValue` (entrée) | `UDINT` | Valeur à écrire dans le compteur brut du codeur |
| `PresetAck` (sortie) | BOOL | Écriture bus confirmée (pulse) |
| `PresetNak` (sortie) | BOOL | Écriture bus refusée/timeout (abort SDO) |

> ⚠️ **Objet CoE exact (index/subindex du preset) dépendant du modèle COD1/COD2 retenu** — à
> confirmer fiche technique fabricant avant implémentation. Certains codeurs exposent un objet
> standard CiA 406 (« Position preset value »), d'autres une fonction fabricant équivalente. Ne
> **jamais réimplémenter** un calcul de recalage manuel si le codeur fournit cette fonction native
> (règle Partie3 §0, réutilisation).

---

## 🛡️ 7. Sécurité / interlocks spécifiques

- **Autorisation stricte `MAINT_N2`** : `Home` ignoré (ErrorId bit0) dans tout autre mode — évite
  un référencement accidentel en exploitation (perte totale de la référence position).
- **Treuil à l'arrêt obligatoire** (`WinchSpeedNull`) : un preset pendant un mouvement rendrait la
  mesure incohérente pendant la fenêtre d'écriture.
- **Double front** (`Home` + `ConfirmHome`) : un référencement erroné n'est pas un simple défaut
  réversible par reset — c'est une **perte de la position réelle** tant que l'opérateur n'a pas
  revérifié visuellement le toucher d'eau. D'où la confirmation à deux étapes, au-delà du simple
  `Reset` front (Partie3 §5) qui, lui, reste dédié à l'acquittement défaut.
- **`Homed` gate `SEMI_AUTO`** : `FB_Modes` interdit le mode semi-automatique tant qu'un des deux
  treuils n'a pas `Homed = TRUE` (position non fiable → cycle automatique dangereux).
- **Perte codeur pendant le homing** (`EncoderAvailable` tombe entre `Home` et `ConfirmHome`) →
  ErrorId bit3, retour `READY`, aucune écriture partielle.
- **`Homed` n'est jamais remis à `FALSE` par un défaut transitoire** (perte codeur momentanée) :
  seule une **nouvelle procédure de homing réussie** le met à jour — cohérent avec le principe
  Partie3 §6 « acquitter ≠ redémarrer » : la référence reste valable tant qu'un nouveau
  référencement n'a pas eu lieu ou que le codeur n'a pas été physiquement démonté (procédure
  maintenance, pas un simple reset logiciel).

---

## 🗺️ 8. Mapping E/S (à créer, IHM + variables)

| Élément | Variable (exemple) | Rôle |
|---------|---------------------|------|
| Sélecteur treuil (IHM) | `WinchSelect_IHM` | Écrit `E_WinchSelect` |
| Bouton homing M1/M2 (IHM) | `HomeButtonM1_IHM` / `HomeButtonM2_IHM` | → `Home` de l'instance correspondante |
| Bouton confirmation (IHM) | `ConfirmHomeButton_IHM` | → `ConfirmHome` |
| Voyant référencé (IHM) | `HomedM1_Lamp` / `HomedM2_Lamp` | ← `Homed` |
| Affichage position | `CablePosM1_Display` / `CablePosM2_Display` | ← `FB_Encoder_Scale` (sortie déjà prévue) |

---

## 💻 9. État d'avancement / prochaine itération

📌 **Ce document est une conception validée fonctionnellement, pas encore de code produit.**
Prochaine itération (workflow `codesys-workflow`, une fois ce document relu/validé) :

- [ ] Créer `E_WinchSelect` (`_TYPES`)
- [ ] Créer `ST_EncoderCalib` (`_TYPES`) — RETAIN : `{ HomingRefTarget : UDINT ; Homed : BOOL }`
- [ ] Créer `FB_Encoder_Homing` (dossier `ENCODER`), 2 instances (M1/M2)
- [ ] Étendre `FB_Encoder_Abs` : `PresetRequest`/`PresetValue`/`PresetAck`/`PresetNak` (§6)
- [ ] Étendre `FB_Encoder_Safety` : détection saut incohérent (§3.5) → `SafeStop_Winch`
- [ ] Étendre `FB_Modes` : `WinchSelect`, neutralisation croisée (§4), interlock `SEMI_AUTO` vs `Homed`
- [ ] Confirmer fiche technique COD1/COD2 (résolution réelle, objet CoE preset) → recalculer §3.3
- [ ] Une fois codé et testé : bump `AF_Partie2_Architecture_Programme` en v2.6 (nouveaux blocs)

---

## 🔁 10. Retour d'expérience (à compléter après implémentation + test)

- [ ] `HomingRefTarget` calculé avec la fiche technique réelle (pas l'exemple §3.3) ?
- [ ] Marge validée (`MargeDispo >= 10× PlageUtilePts`, règle §3.4) ?
- [ ] Sélection treuil (`WinchSelect`) : neutralisation croisée effective, pas de mouvement croisé possible ?
- [ ] Homing M1 puis M2 : affichage 0.00 m cohérent au toucher d'eau réel ?
- [ ] Détection de saut incohérent (§3.5) testée (simulation coupure/rebond bus) → `SafeStop` déclenché ?
- [ ] `SEMI_AUTO` bien refusé tant qu'un treuil n'est pas `Homed` ?
- [ ] Si validé → figer `HomingRefTarget` définitif, clôturer cette v1.0.

---

## 📚 Documents liés
- **Partie 1 v1.2** — §Initialisation (référencement codeurs, description d'origine).
- **Partie 2 v2.5** — Architecture (dossier `ENCODER`, à faire évoluer v2.6 après implémentation).
- **Partie 3 v1.2** — Contrat FB §1bis (profils : ce FB n'est **pas** un FB de mouvement).
- **Partie 4 v1.1** — Cycle & synchro (`FB_WinchSync`, suspension pendant phases sans mouvement commun).
- **Partie 5 v1.1** — Modes & maintenance (droits `MAINT_N2`, overrides).
- **Partie 9 v1.0** — Fonction Winch (`FB_Winch` pilotable unitairement, base du pilotage indépendant).
