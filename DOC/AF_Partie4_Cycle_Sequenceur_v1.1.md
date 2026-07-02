# 📋 Analyse Fonctionnelle — Partie 4 : Cycle & Séquenceur (v1.1)

> **Version 1.1** — Suite audit documentaire : le passage à une étape **sans mouvement** se fait
> par **`StartStop := FALSE`** (décélération normale, `Enable` reste actif) — **plus** par retrait
> d'`Enable` (`CoupeEnable` n'a jamais existé, voir Partie 2 v2.5). `ERROR_HOLD` est déclenché par
> `SafeStop` (bloc safety **métier** concerné), pas un signal global. Interlock `FB_WinchSync`
> **suspendue** explicitement pendant la phase godet (§3bis).
> **Version 1.0** — Définition du séquenceur semi-automatique : `E_CycleStep`,
> séquence d'initialisation, synchronisation des treuils, séquence frein,
> translation, cinématique godet et stratégie de rampes.
>
> 🔗 Dépend de : Partie 2 v2.5 (architecture), Partie 3 v1.2 (contrat FB), Partie 5 (modes).

---

## 🎯 0. Principe

Le cycle est un **pseudo-Grafcet** : chaque étape est une **mémoire** (un état de
`E_CycleStep`). `FB_Cycle` émet `Enable` / `StartStop` / Sens / SpeedRef vers les treuils et la
translation selon l'étape active. Le passage à une étape **sans mouvement** met **`StartStop :=
FALSE`** → **rampe de décélération normale** (`Enable` reste actif, synchro ou non selon l'étape).

⚠️ Toute commande de mouvement passe **toujours** par une validation joystick de l'opérateur
(homme-mort / intention), même en semi-automatique. La vitesse résulte de la position joystick,
bornée par la vitesse max autorisée à l'étape (voir §Rampes).

---

## 🔢 1. Énumération `E_CycleStep`

```codesys
TYPE E_CycleStep :
ENUM
  INIT                 := 0;   (* Vérifs cohérence états + sécurités, mise en position init *)
  WORK_POS_SELECT      := 1;   (* Choix opérateur pos travail 1/2 + déplacement validé joystick *)
  DESCENDING_OPEN      := 2;   (* Plongée godet déjà ouvert, M1+M2 synchro, asserv si dérive *)
  BOTTOM_TOUCH_WAIT    := 3;   (* Attente info BOOL capteur "fond touché" *)
  SYNCHRO_ADJUST       := 4;   (* Désynchro M2 petite vitesse (offset X) → fermeture godet *)
  CTRL_ASCENDING       := 5;   (* Remontée lente de contrôle (risque relâchement si godet mal fermé) *)
  ASCENDING_LOADED     := 6;   (* Après X m param., remontée charge rampe + vitesse ∝ joystick *)
  DRAINING_PAUSE       := 7;   (* Égouttage temporisé (durée RETAIN) + message opérateur *)
  TRANSLATION_MOVE     := 8;   (* Déplacement pont vers vidage, validation + vitesse joystick *)
  DESCENDING_OPEN_DUMP := 9;   (* Descente arrêt position param. + demande user → ouverture godet (M2 inverse X) *)
  RETURN_WORK_POS      := 10;  (* Retour position travail, remontée treuils synchro *)
  READY                := 11;  (* Cycle terminé, prêt à reboucler *)
  ERROR_HOLD           := 12;  (* Arrêt sûr figé sur défaut (SafeStop du métier concerné) — sortie par reset + maintenance *)
END_ENUM
END_TYPE
```

> 📌 `ERROR_HOLD` n'est pas une étape « normale » : c'est l'état de repli atteint dès qu'**un**
> `SafeStop` (du bloc safety métier impliqué dans l'étape en cours) est actif. La reprise exige
> cause disparue + reset (front) + nouvel ordre explicite (`StartStop`) — jamais de redémarrage
> automatique (voir Partie 3 §Reset).

### Transitions nominales

```
INIT ──(états cohérents)──► WORK_POS_SELECT ──(position atteinte)──► DESCENDING_OPEN
DESCENDING_OPEN ──(fond touché)──► BOTTOM_TOUCH_WAIT ──► SYNCHRO_ADJUST
SYNCHRO_ADJUST ──(godet fermé, ΔPos cible)──► CTRL_ASCENDING
CTRL_ASCENDING ──(X m remontés)──► ASCENDING_LOADED ──(haut atteint)──► DRAINING_PAUSE
DRAINING_PAUSE ──(tempo + validation)──► TRANSLATION_MOVE ──(position vidage)──► DESCENDING_OPEN_DUMP
DESCENDING_OPEN_DUMP ──(godet ouvert)──► RETURN_WORK_POS ──(position travail)──► READY ──► (reboucle) DESCENDING_OPEN
[à tout instant] SafeStop (bloc safety métier concerné par l'étape en cours) ──► ERROR_HOLD
```

---

## 🧭 2. Séquence d'initialisation (INIT) — *partiellement TBD*

> ⚠️ **TBD (To Be Defined)** : le détail fin de la séquence INIT reste à arrêter (voir
> `DOC/AUDIT_Coherence_Documentaire_v1.0.md` — décision D22, reportée).
> Le squelette ci-dessous fixe les vérifications **sûres et vérifiées** attendues.

`INIT` doit garantir un état machine **cohérent et vérifié** avant d'autoriser le cycle.

```
INIT — sous-états :
  1. Vérifier Translation en position d'init
       → capteur BOOL dédié (pas besoin de codeur)
       → si absent : commande petite vitesse pour l'atteindre (validation joystick)
  2. Vérifier état godet : FB_Bucket retourne une info SÛRE et vérifiée (ouvert attendu)
       → si incohérent (mémoire RETAIN vs codeurs) : blocage + demande maintenance
  3. Vérifier position treuils M1/M2 (position haute attendue, godet ouvert)
       → info fournie par des FB qui CONTRÔLENT et VALIDENT (pas une lecture brute)
       → si non conforme : demande déplacement manuel petite vitesse pour atteindre l'état
  4. Demande de vérification VISUELLE opérateur sur IHM (confirmation humaine)
  5. Tous critères OK ──► WORK_POS_SELECT
```

🧭 Principe : chaque condition d'init s'appuie sur une **information sûre et vérifiée** émise
par les FB concernés (codeurs validés, capteurs filtrés), jamais sur une donnée brute volatile.
Une **confirmation visuelle IHM** est prévue (sécurité supplémentaire au démarrage).

---

## ↕️ 3. Synchronisation des treuils (`FB_WinchSync`)

Lorsqu'on **plonge ou remonte** sans bouger l'ouverture godet, les deux treuils doivent
**partir ensemble** et tenir **la même vitesse**. Les codeurs mesurent l'écart de position ;
en cas de dérive, on régule.

### Principe de régulation

```
À chaque cycle (FB_WinchSync, actif hors phase godet — voir §3bis) :
  ΔPos := |PosM1 − PosM2|            (* écart position via codeurs *)
  ΔVit := |VitEstM1 − VitEstM2|      (* dérive vitesse estimée — pas de mesure courant *)

  1. Démarrage : M1 et M2 reçoivent Enable + StartStop + même consigne vitesse (synchro).

  2. Si ΔPos AUGMENTE :
       → identifier l'axe trop rapide
       → le RALENTIR via ses contacteurs de paliers, selon une RAMPE définie
       → l'autre axe garde sa consigne
       (régulation par paliers : pas de variateur, on agit sur les relais de vitesse)

  3. Si ΔPos > SEUIL_ARRET (param. IHM) :
       → ARRÊT des deux treuils (StartStop := FALSE, rampe normale)
       → repositionnement en PETITE VITESSE jusqu'à ΔPos < tolérance
       → TANT QUE le joystick reste sollicité (homme-mort maintenu, présence opérateur) :
            reprise AUTONOME de la *rampe de vitesse* des deux treuils
            (⚠️ "autonome" = la régulation rétablit seule la vitesse ; ce n'est PAS un
             mouvement sans opérateur — relâcher le joystick arrête le mouvement)

  4. Estimation d'effort (déséquilibre charge) :
       → un godet mal ouvert/fermé répartit mal le poids sur les 2 treuils
       → FB_WinchSync surveille aussi la vitesse de déplacement par les codeurs
       → si un treuil "force" (Δ hors plage param.) : signalisation IHM,
         voire arrêt des mouvements + demande d'action MAINTENANCE
```

> 🔧 **Pas de mesure de courant** sur les treuils (contacteurs + disjoncteurs uniquement).
> Le « forçage » est **déduit** de Δposition / Δvitesse, pas mesuré directement.

### 3bis. Interlock godet ↔ synchro (v1.1)

⚠️ **`FB_WinchSync` est suspendue pendant la phase godet** (`SYNCHRO_ADJUST` en fermeture,
`DESCENDING_OPEN_DUMP` en ouverture) : ces étapes désynchronisent **volontairement** M2 (offset
`OffsetClose`/`OffsetOpen`, voir §6) et **M1 ne bouge pas**. Il n'y a donc **aucun conflit** entre
la désynchro godet et la surveillance synchro : pas de mouvement M1 pendant la phase godet = rien
à synchroniser, la suspension est **automatique et sans risque** (ce n'est pas un override N2, cf.
Partie 5, mais une conséquence directe de l'absence de mouvement M1 durant ces étapes).

`FB_Cycle` réactive `FB_WinchSync` dès la sortie de ces étapes (retour à un mouvement synchrone
M1+M2 : `CTRL_ASCENDING`, `RETURN_WORK_POS`, etc.).

### Seuils (paramètres IHM, valeurs par défaut dans le FB)
| Paramètre | Rôle | Défaut indicatif |
|-----------|------|------------------|
| `SyncWarn` | Écart d'alerte (signalisation) | 0.5 m |
| `SyncStop` | Écart d'arrêt + repositionnement | 1.5 m |
| `ForceImbalance` | Déséquilibre vitesse → « un treuil force » | ~10 % |

> `FB_WinchSync` est **actif** dès que M1 et M2 sont censés bouger ensemble (au minimum pour
> informer), **suspendu automatiquement** en phase godet (§3bis). En maintenance N2, son
> contrôle peut en outre être **désactivé volontairement** par l'opérateur (codeur mort, etc.) —
> voir Partie 5.

---

## 🛑 4. Séquence frein (`FB_Brake`)

Le frein est à **manque de courant** (colle au repos = maintien charge). Le séquencement
doit intégrer les **temps physiques** des contacteurs et du moteur, sinon : fermeture du
frein en plein mouvement (usure/casse) ou relâchement trop tôt (charge qui retombe → à-coup).

### Au démarrage (arrêt → mouvement)
```
1. Commande automate moteur (contacteur sens + palier), StartStop := TRUE
2. Attente : temps contacteur de puissance (fermeture) + magnétisation moteur
3. SEULEMENT ALORS : ouvrir le frein (relâche)
   → si on relâche trop tôt, la charge retombe par son poids → à-coup
```

### À l'arrêt (mouvement → arrêt)
```
1. Couper la commande de mouvement : StartStop := FALSE (arrêt demandé, rampe normale)
   ou SafeStop actif (défaut process du métier, rampe rapide) — Enable reste actif dans les 2 cas
2. Le moteur ne s'arrête PAS instantanément ; le contacteur met X ms à s'ouvrir
3. Attendre la décélération / ouverture contacteur AVANT de fermer le frein
   → si on ferme le frein en plein mouvement → usure/casse mécanique
4. Fermer le frein (collage)
```

### Double vérification (retour d'état contacteurs)
`FB_Brake` est **autonome** : il prend des informations d'autres FB, **mais** réalise une
**double vérification avec les retours d'état des contacteurs de puissance**. Incohérence
commande vs feedback (au-delà d'un timeout) → `ErrorId` (bit dédié) → état ERROR.

### Paramètres (RETAIN, réglage mise en service)
| Paramètre | Rôle |
|-----------|------|
| `DelayMagnetise` | Délai magnétisation moteur avant ouverture frein |
| `DelayContactClose` | Temps fermeture contacteur de puissance |
| `DelayMotorDecel` | Délai décélération/ouverture contacteur avant collage frein |
| `FeedbackTimeout` | Délai max cohérence feedback contacteur sinon défaut |

---

## ↔️ 5. Translation (`FB_Translation`)

Le pont se déplace vers une **position cible** (travail 1, travail 2, ou vidage) via le
variateur AC600. L'opérateur valide et dose la vitesse au joystick.

### Approche & arrêt
```
Exemple : opérateur a choisi "position 2" à l'IHM, puis avance au joystick.
  1. La translation passe la position 1 SANS ralentir (ce n'est pas la cible).
  2. À l'approche de la position 2 :
       → après un TEMPS ESTIMÉ de déplacement (paramètre réglable),
         le mouvement RALENTIT à petite vitesse (PV).
  3. Arrêt EXACT sur le CAPTEUR de position (dérive négligeable),
       même si le joystick reste actionné (StartStop := FALSE à l'arrivée).
  4. Message opérateur "en position" si : capteur présent
       ET frein à manque de courant fermé mécaniquement.
```

> Le variateur AC600 fournit mot de commande/état, vitesse estimée et consigne fréquence,
> mais **pas** la mesure de courant. Le défaut variateur est lu via son mot d'état.

### Paramètres (RETAIN)
| Paramètre | Rôle |
|-----------|------|
| `ApproachTime` | Temps estimé avant déclenchement du ralentissement |
| `ApproachSpeed` | Vitesse réduite d'approche (PV) |
| `CaptorDebounce` | Filtrage capteur de position d'arrêt |

---

## 🪣 6. Cinématique godet (`FB_Bucket`)

Le godet n'a **pas de moteur propre** : il s'ouvre/ferme par **désynchronisation de M2**
(décalage de position relatif à M1, **M1 immobile** — voir §3bis).

### Fonctionnement
```
Fermeture (SYNCHRO_ADJUST) : M2 se décale de OffsetClose (X m ou points) → mâchoires se ferment
Ouverture (DESCENDING_OPEN_DUMP) : M2 déplacement INVERSE de OffsetOpen → mâchoires s'ouvrent
```

Les offsets sont des **paramètres accessibles en Maintenance N2** (réglés à la mise en service).

### Disponibilité de la fonction godet
- **En cycle** : ouverture/fermeture aux étapes prévues.
- **En maintenance** : on peut demander une ouverture/fermeture à une position donnée
  **à condition** que la sécurité ne soit pas remise en cause (longueur câble max, positions
  extrêmes, limites codeur…). Si les conditions ne sont **pas** remplies, la seule possibilité
  est de passer en **Maintenance N2** pour commander les treuils indépendamment, avec
  possibilité de **désactiver les contrôles synchro et godet** (message IHM).

### Mémoire & contrôle au boot
```
RETAIN : ST_BucketState (IsOpen, LastPosM2_Open, LastPosM2_Close)

Au démarrage :
  comparer position M2 réelle vs mémoire
  si écart > seuil ET incohérence état (ex: "fermé" annoncé mais position d'ouvert) :
     → signaler "état godet non sûr / non correct"
     → forcer Maintenance N1 + vitesse réduite pour remettre en ordre
```

> ⚠️ Un état godet mal défini répartit mal le poids total sur les deux treuils.
> `FB_WinchSync` peut alors détecter qu'un treuil force (contrôle vitesse via codeurs)
> et signaler/arrêter (voir §3), **une fois la phase godet terminée et la synchro réactivée**.

---

## 🎚️ 7. Stratégie de rampes & vitesse joystick

Le joystick commande une vitesse **de l'arrêt (vitesse min) jusqu'à la vitesse max AUTORISÉE
par le mode/l'étape**. Appuyer à fond en mode « petite vitesse » ne donne que la petite vitesse.

### Changement de plafond de vitesse entre étapes
```
Étape A : vitesse max autorisée = PV (petite vitesse)
  → joystick à fond ⇒ axe rampe jusqu'à PV seulement.

Étape B : vitesse max autorisée = GV (grande vitesse)
  → pour éviter une accélération brutale "sans rien comprendre",
    on DEMANDE à l'opérateur de revenir à une position joystick cohérente
    avant d'autoriser la montée en GV.
```

### Rampes internes (anti à-coups / anti-pompage)
- Toute consigne passe par une **rampe** (montée/descente) pour éviter les à-coups mécaniques
  et les oscillations (pompage), en particulier sur la charge.
- **Arrêt demandé** (`StartStop := FALSE`, fin d'étape ou opérateur) : rampe de **décélération
  normale** (même profil que l'accélération).
- **Défaut process** (`SafeStop` du bloc safety métier concerné : perte codeur, bus, joystick…) :
  arrêt sur une **rampe plus rapide mais non destructive** (`Enable` reste actif le temps du
  ralentissement maîtrisé, pas de coupure brutale), puis collage des freins (voir §4) — voir
  aussi Partie 5 §Pertes/Défauts.

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (orchestration, `FB_WinchSync`, `SafeStop`/`StartStop`, IO).
- **Partie 3 v1.2** — Contrat FB (`E_State`, `ErrorId`, reset, `StartStop`/`SafeStop`).
- **Partie 5** — Modes & maintenance (overrides N2, limite légale `FB_Modes`, pertes/défauts).
- **Partie 6** — Conditionnement E/S.
