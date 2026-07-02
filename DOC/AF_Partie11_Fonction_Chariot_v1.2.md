# 📋 Analyse Fonctionnelle — Partie 11 : Fonction Chariot (v1.2)

> **v1.2 (2026-07-02)** — Renommage **Translation → Chariot** suite à la liste I/O réelle reçue de
> l'utilisateur (terminologie officielle du matériel). Périmètre strictement terminologique : tous
> les identifiants (`FB_Translation`→`FB_Chariot`, `FB_Safety_Translation`→`FB_Safety_Chariot`,
> `E_TranslationCommMode`→`E_ChariotCommMode`, `GVL_Translation_M3_Stub`→`GVL_Chariot_M3_Stub`,
> `instTranslationM3`→`instChariotM3`, `instSafetyTranslationM3`→`instSafetyChariotM3`) et les
> mentions dans le corps du texte sont renommés — **aucune logique métier modifiée**. Ancienne
> version conservée telle quelle dans `DOC/Archives/AF_Partie11_Fonction_Translation_v1.1.md`.

> **Fonction métier** : chaîne de commande Joystick (axe X) → `FB_Chariot` → variateur AC600
> (axe M3), avec **deux modes de communication** sélectionnables manuellement : `ETHERCAT`
> (nominal, mot commande/état + consigne fréquence proportionnelle) et `DEGRADED_IO` (relais de
> sens + présélection vitesse PV/GV en TOR, vitesse et rampes réglées localement sur le
> variateur) — motivé par une panne de communication EtherCAT constatée sur le variateur AC600.
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔴 **Document de réflexion / squelette** : la partie `ETHERCAT` porte des inconnues protocolaires
> (layout exact des mots commande/état AC600) volontairement **non comblées par approximation**
> (règle projet : ne jamais deviner). La partie `DEGRADED_IO` est fonctionnellement complète
> (corrigée v1.1) mais reste conditionnée à la confirmation du bornier réel et du paramétrage
> AC600 (§4bis) avant tout essai machine en charge.
> 🔗 Dépend de : [P2 Architecture v2.5](AF_Partie2_Architecture_Programme_v2.5.md), [P3 Contrat FB v1.2](AF_Partie3_Template_FB_Commun_v1.2.md) §1bis, [P4 Cycle v1.2](AF_Partie4_Cycle_Sequenceur_v1.2.md) §5, [P9 Winch v1.0](AF_Partie9_Fonction_Winch_v1.0.md) (patterns réutilisés : interlock sens, `FB_Brake`, `FB_Safety_<Metier>`).
>
> ℹ️ **Numérotation** : la branche `claude/encoder-homing-winch-control-h6ef89` (non fusionnée
> dans `main` à la rédaction) occupe déjà `AF_Partie10_Fonction_Encoder_Homing_v1.1.md` — ce
> document prend donc le numéro **11** pour éviter toute collision au moment du merge.
>
> **v1.1** — Correctifs suite revue automatisme/mise en service 2026-07-02 (périmètre strictement
> limité à `FB_Chariot`/`FB_Safety_Chariot`/`E_ChariotCommMode`, aucun autre bloc du
> projet touché) :
> - 🔴 **[F1, bloquant, corrigé]** En `DEGRADED_IO`, la coupure des relais de sens sur arrivée
>   capteur (§9bis) dépendait de la rampe **logicielle** `SpeedRamp.Current`, sans lien avec la
>   vitesse physique réelle en tout-ou-rien (PV/GV) → jusqu'à ~2,5 s de roulage à pleine vitesse
>   après passage sur le capteur. Corrigé : coupure **immédiate**, découplée de la rampe
>   (`DegradedMoveAuthorized`, voir `CODE/FB_Chariot.st`).
> - 🟠 **[F5, corrigé]** `CommMode` est désormais **verrouillé** (`CommModeLocked`) tant qu'un
>   mouvement est en cours — un changement de mode pendant `Busy=TRUE` n'est plus pris en compte.
> - 🟠 **[F7, clarifié]** Les paramètres de rampe ne pilotent une vitesse physique réelle qu'en
>   `ETHERCAT`. Nouveau paramètre `DegradedStopSettleTime` (délai physique réel) remplace la rampe
>   comme confirmation d'arrêt pour l'interlock de sens en `DEGRADED_IO`.
> - 🟠 **[F2, F3, F4, F6]** Ajout §4bis (paramétrage AC600 à vérifier avant essai), avertissement
>   double commande EtherCAT/relais (§4bis), note de portée sur Partie2 §5 (§4), checklist
>   "avant premier essai" (§7).

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (axe X, chariot) en commande physique du variateur
AC600 (M3), dans le respect strict de la précédence `Enable` > `SafeStop` > `StartStop`
(Partie3 §1bis) — **quel que soit le mode de communication actif**.

**Origine du besoin** : le pilotage nominal du variateur via EtherCAT (mot de commande, consigne
fréquence) est actuellement **indisponible** (panne bus). Plutôt que d'immobiliser l'axe de
chariot, on prévoit une chaîne de secours par **relais TOR**, câblée en parallèle du bus
EtherCAT, activable manuellement le temps de fiabiliser la communication.

**Sélection du mode** : entrée `CommMode : E_ChariotCommMode` (`ETHERCAT` / `DEGRADED_IO`),
positionnée **manuellement** (maintenance/IHM) — **jamais de bascule automatique** en cours de
mouvement, cohérent avec le principe projet « jamais de redémarrage/bascule automatique sans
action consciente » (CLAUDE.md, guardrails).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdX ──► FB_Chariot(M3) ──┬─► [CommMode=ETHERCAT]    DriveControlWord + DriveFreqRefHz ──► AC600 (EtherCAT)
                                               ├─► [CommMode=DEGRADED_IO] RelayFwd/RelayRev + RelaySpeedGv (PV/GV) ──► AC600 (bornier TOR)
                                               └─► FB_Brake ──► BrakeCmd (séquence temporisée, indépendante du mode)

FB_Safety_Chariot ──► SafeStop ──► (entrée) FB_Chariot(M3)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_Chariot` | Assemble rampe interne, arbitrage `Enable > SafeStop > StartStop`, interlock sens, arrêt sur capteur, et sortie physique selon `CommMode` |
| `FB_Brake` | **Réutilisé tel quel** depuis `_COMMON` (même brique que le treuil) — nouvelle instance, nouveaux réglages RETAIN propres à M3. Partie4 §5 mentionne déjà un « frein à manque de courant » pour le chariot → pas de FB dédié nécessaire (Partie3 §0, anti-réinvention) |
| `FB_Safety_Chariot` | Bloc safety **métier** du domaine chariot : lève `SafeStop_Chariot` — périmètre minimal ce lot : perte joystick/CAN uniquement (comme `FB_Safety_Winch`, Partie9) |

> ♻️ **Réutilisation** (Partie3 §0) : `HYSTERESIS` (lib Util) pour la sélection PV/GV en
> `DEGRADED_IO` — **pas** `FB_SpeedStep` (table 5 paliers/4 relais disproportionnée pour un choix
> à 2 états). `FB_Ramp` + `FB_CycleTime` (déjà utilisés par `FB_Joystick`/`FB_Winch`) pour la
> rampe interne. `LIMIT` (IEC standard) pour le plafonnement vitesse d'approche.

---

## 🔌 3. Interface `FB_Chariot` (FB de mouvement, Partie3 §1bis)

**📥 Entrées communes**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) |
| `StartStop` / `SafeStop` | BOOL | Standard FB de mouvement (Partie3 §1bis) |
| `CommMode` | `E_ChariotCommMode` | Sélection manuelle `ETHERCAT`/`DEGRADED_IO` |
| `Direction` | INT | -1/0/+1 (axe X joystick) |
| `SpeedRefPct` | REAL | 0..100 % — proportionnel en `ETHERCAT`, sélecteur PV/GV (via `HYSTERESIS`) en `DEGRADED_IO` |
| `PositionSensorTarget` | BOOL | Capteur position cible courante (sélection de la cible = **hors périmètre** de ce FB, en amont IHM/`FB_Cycle`) |
| `BrakeFeedback` | BOOL | Retour contacteur bobine frein (circuit propre, indépendant du mode) |

**📥 Entrées spécifiques `ETHERCAT`**
| Entrée | Type | Rôle |
|--------|------|------|
| `DriveStatusWord` | WORD | 🔴 Mot d'état AC600 — **layout de bits TBD**, lu depuis l'image d'entrée EtherCAT |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée (pas de mesure de courant, Partie4 §5) |

**📥 Entrées spécifiques `DEGRADED_IO`**
| Entrée | Type | Rôle |
|--------|------|------|
| `ContactorFeedbackFwd` / `Rev` | BOOL | Retours d'état câblés contacteurs de sens |
| `DriveFaultFeedback` | BOOL | Retour TOR défaut variateur, **si câblé** sur une sortie relais dédiée (sinon `FALSE` côté appelant — ne jamais stubber un "pas de défaut" arbitraire) |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `DriveControlWord` / `DriveFreqRefHz` | WORD / REAL | 🔴 `ETHERCAT` — mot de commande (**TBD**) + consigne fréquence (calculée, échelle explicite en attendant vérif `LIN_TRAFO`) |
| `RelayFwd` / `RelayRev` / `RelaySpeedGv` | BOOL | `DEGRADED_IO` — contacteurs de sens + sélection GV (`FALSE`=PV, `TRUE`=GV) |
| `BrakeCmd` | BOOL | Commande bobine frein (`TRUE` = relâché) — indépendant du mode |
| `TargetReached` | BOOL | Capteur cible confirmé (debounce) |
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | État standard (Partie3 §1) |
| `FwdContactorCheck` / `RevContactorCheck` / `BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic détaillé (IHM) |

`ErrorId` : bit0 = défaut frein, bit1 = contacteur sens Fwd incohérent (`DEGRADED_IO`), bit2 =
contacteur sens Rev incohérent (`DEGRADED_IO`), bit3 = défaut variateur (`DriveFaultFeedback`,
si câblé — 🔴 TBD tant que le bit exact du mot d'état `ETHERCAT` n'est pas confirmé).

---

## 🛡️ 4. Sécurité

- **Précédence stricte** `Enable > SafeStop > StartStop`, identique aux autres FB de mouvement.
- **Interlock changement de sens** : même principe que `FB_Winch` — engagement initial
  neutre→un sens immédiat, arrêt et inversion directe exigent une confirmation d'arrêt
  (`IsStoppedConfirmed`, 🆕 v1.1) dont la source diffère par mode : rampe logicielle confirmée
  nulle en `ETHERCAT` (consigne réellement proportionnelle), **délai physique réel
  `DegradedStopSettleTime`** en `DEGRADED_IO` (la rampe logicielle n'y a aucun lien avec la
  vitesse réelle, cf. correctif F1/F7).
- **Arrêt exact sur capteur** (§9bis du code, 🆕 **comportement proposé, à valider avec
  l'utilisateur** — absent de toute doc existante) : le mouvement est verrouillé (`ArrivalLock`)
  tant que `PositionSensorTarget` (débounced) reste actif **et** que le sens commandé est le même
  que celui qui a mené à l'arrivée — permet de repartir immédiatement en sens inverse sans
  bloquer totalement l'axe sur la position atteinte. **Coupure immédiate des relais en
  `DEGRADED_IO`** depuis le correctif v1.1 (F1) — avant correction, la coupure réelle pouvait être
  retardée de plusieurs secondes.
- **Ralentissement auto à l'approche** (`ETHERCAT` uniquement, Partie4 §5) : après `ApproachTime`
  écoulé depuis le début du mouvement, la consigne est plafonnée à `ApproachSpeedPct`. **Non
  reproductible en `DEGRADED_IO`** (pas de consigne variable programmable) — le choix PV/GV y
  reste manuel, au joystick.
- **Frein** : séquence temporisée stricte (`FB_Brake`, réutilisé tel quel), pilotée par
  `MovementRequested`, commun aux deux modes.
- **Sortie sûre sur défaut** : `Error` force `DriveControlWord`/`DriveFreqRefHz`/`RelayFwd`/
  `RelayRev`/`RelaySpeedGv`/`BrakeCmd` à leur état sûr, conforme Partie3 §9 étape 7.

### ⚠️ Ce qui reste TBD (ne pas approximer)

| Point | Détail |
|-------|--------|
| Layout `DriveControlWord`/`DriveStatusWord` | Encodage bit à bit du protocole AC600 non disponible à la rédaction — **à confirmer sur la doc constructeur du variateur** avant tout collage CODESYS de la branche `ETHERCAT` |
| Interface `LIN_TRAFO` (Util) | Non vérifiée ici — le projet a déjà eu une mauvaise supposition d'interface sur `HYSTERESIS` (correctif `FB_SpeedStep` 2026-07-01). En attendant, mise à l'échelle %→Hz par calcul linéaire explicite dans `FB_Chariot.st`, à remplacer par `LIN_TRAFO` si son interface réelle est vérifiée |
| Bornier TOR réel `DEGRADED_IO` | Nombre exact d'entrées présélection vitesse dispo sur l'AC600, câblage physique — à valider à la mise en service (comme `ST_SpeedStepTable` pour le treuil) |
| `VariateurAvailable` (`FB_DiagEthercat` AC600/M3) | Diag EtherCAT non finalisé — `FB_Safety_Chariot` ne le surveille pas encore (bit réservé, non stubé), comme le codeur pour `FB_Safety_Winch` |

> 🧭 **Note de portée vs Partie2 §5** : la table "Dégradation par domaine" de
> [Partie2 §5](AF_Partie2_Architecture_Programme_v2.5.md) indique « Variateur M3 down →
> Chariot interdite ». Cette règle s'entend **hors activation volontaire de
> `CommMode := DEGRADED_IO`** — Partie2 n'a pas encore été mise à jour pour référencer ce mode
> (mise à jour transverse à faire lors d'une prochaine revue de cohérence documentaire, hors
> périmètre de ce lot qui ne touche que les fichiers Chariot).

---

## ⚡ 4bis. Paramétrage AC600 & câblage — à vérifier AVANT tout essai réel

🔴 **Cette section liste QUOI vérifier, pas les valeurs exactes** (numéros de paramètres/menu
propres au modèle AC600 exact installé — non disponibles à la rédaction, à relever sur la doc
constructeur ou l'étiquette du variateur).

| Vérification | Pourquoi | Type |
|---------------|----------|------|
| Fréquence PV (petite vitesse) réglée sur le variateur | Vitesse physique réelle en `DEGRADED_IO` quand `RelaySpeedGv = FALSE` — le PLC ne fait que sélectionner, pas moduler | Paramètre variateur |
| Fréquence GV (grande vitesse) réglée sur le variateur | Idem quand `RelaySpeedGv = TRUE` | Paramètre variateur |
| Rampes accel/decel **internes** au variateur | Déterminent la décélération physique réelle après coupure du relais de sens — c'est cette valeur, pas `RampDecelNormalRate`/`RampDecelFastRate` (paramètres PLC, sans effet physique en `DEGRADED_IO`), qui doit inspirer le réglage de `DegradedStopSettleTime` | Paramètre variateur |
| **Source de commande** (Terminal/bornier vs Communication/fieldbus) | 🔴 **Critique** : le câblage relais est prévu **en parallèle** du bus EtherCAT (§1). Tant que ce paramètre n'est pas verrouillé sur *Terminal* pendant `CommMode = DEGRADED_IO`, une reprise intermittente du bus EtherCAT peut produire un comportement imprévisible (le PLC écrit `DriveControlWord := 0`/`DriveFreqRefHz := 0.0` sur l'image EtherCAT en `DEGRADED_IO`, mais l'interprétation de ce "0" par le variateur dépend entièrement de ce paramètre) | Paramètre variateur — **à figer avant tout essai** |
| Sectionnement/isolement physique du bus EtherCAT (si possible) | Alternative plus sûre que le seul verrouillage logiciel du paramètre source de commande, tant que ce dernier n'est pas confirmé | Câblage |

**Procédure de réglage progressif recommandée pour le premier essai** (valeurs par défaut
`FB_Chariot.st` volontairement prudentes mais non validées terrain) :
1. Régler PV à une fréquence **très basse** sur le variateur (mouvement à peine perceptible).
2. Tester `RelayFwd` seul (axe **non chargé**, machine à l'arrêt) → valider le sens physique
   correspond bien à l'attendu joystick (sinon inverser le câblage moteur, pas la logique PLC).
3. Remonter PV progressivement jusqu'à une valeur d'exploitation confortable.
4. Régler GV en dernier, seulement une fois PV validée et le comportement d'arrêt sur capteur
   (§9bis) vérifié à vitesse PV.

---

## 🗺️ 5. Mapping E/S (à créer en I/O Mapping CODESYS, voir §7)

**`ETHERCAT`** (image process EtherCAT, rafraîchie par `EtherCatTask` 4ms)
| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M3_DriveControlWord` | Sortie | Mot de commande AC600 — 🔴 TBD layout |
| `M3_DriveFreqRefHz` | Sortie | Consigne fréquence |
| `M3_DriveStatusWord` | Entrée | Mot d'état AC600 — 🔴 TBD layout |
| `M3_DriveActualFreqHz` | Entrée | Fréquence réelle mesurée |

**`DEGRADED_IO`** (relais/TOR, I/O Mapping standard)
| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M3_RelayFwd` | Sortie | Contacteur sens avant M3 |
| `M3_RelayRev` | Sortie | Contacteur sens arrière M3 |
| `M3_RelaySpeedGv` | Sortie | Sélection vitesse (câblé sur entrée présélection AC600) |
| `M3_ContactorFeedbackFwd` / `Rev` | Entrée | Retours contacteurs de sens M3 |
| `M3_DriveFaultFeedback` | Entrée | Retour TOR défaut variateur, si câblé |

**Communs**
| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M3_BrakeCmd` | Sortie | Bobine frein chariot |
| `M3_BrakeFeedback` | Entrée | Retour contacteur bobine frein |
| `M3_PositionSensorTarget` | Entrée | Capteur position cible courante |

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier (unique)** — dossier `CODE/` :
- [`CODE/E_ChariotCommMode.st`](../CODE/E_ChariotCommMode.st) — nouveau type
- [`CODE/FB_Chariot.st`](../CODE/FB_Chariot.st) — 🔴 **squelette** : interface complète +
  corps ST fonctionnel pour tout ce qui est spécifié, sections TBD clairement isolées et
  commentées (ne pas les compléter par approximation)
- [`CODE/FB_Safety_Chariot.st`](../CODE/FB_Safety_Chariot.st) — nouveau bloc safety
  métier, périmètre minimal (perte joystick/CAN)

*(Pas de recopie du corps ici — voir les fichiers `CODE/` pour le ST complet, règle anti-doublon.)*

---

## 📝 7. Note d'application CODESYS 3.5 (manuel)

🔴 **Ce lot n'est pas prêt à être collé intégralement** : la branche `ETHERCAT` porte des TBD
protocolaires (§4). Deux options :

1. **Appliquer uniquement la branche `DEGRADED_IO`** dès maintenant (relais + PV/GV), en laissant
   `CommMode` figé à `DEGRADED_IO` et les entrées `ETHERCAT` (`DriveStatusWord`,
   `DriveActualFreqHz`) câblées à des stubs neutres (0) le temps de fiabiliser le bus — même
   logique que le stub `GVL_Winch_M1_Stub` de la Partie9 §7 Étape 9bis.
2. **Attendre la confirmation du protocole AC600** (doc constructeur) avant de coller
   `FB_Chariot` en entier, pour ne pas introduire un mot de commande erroné qui pourrait
   déclencher un comportement inattendu du variateur.

👉 **Recommandation** : option 1 — le besoin exprimé est justement de disposer d'un axe M3
opérationnel pendant que l'EtherCAT est en panne. Étapes (une fois validées) :
1. Créer `E_ChariotCommMode` (DUT Enumeration).
2. Créer dossier `CHARIOT` (si absent) → `FB_Chariot` (POU Function Block, ST).
3. Créer `FB_Safety_Chariot` dans `SAFETY` (dossier existant).
4. Câbler dans `PRG_MAIN` : `CommMode := E_ChariotCommMode.DEGRADED_IO` (figé, en attendant
   IHM/sélecteur maintenance), `DriveStatusWord := 0`, `DriveActualFreqHz := 0.0` (stubs neutres).
5. I/O Mapping : relais sens + PV/GV + retours (Mapping §5) sur les canaux physiques réels.
6. **Rebuild** — 0 erreur avant tout téléchargement automate.
7. **Paramétrage AC600 + verrouillage source de commande** (§4bis) — avant toute mise sous tension
   avec le PLC actif.

### ✅ Avant le premier essai réel (mouvement machine)

À faire **dans cet ordre**, avant tout essai en charge :
1. Vérifier §4bis entièrement réglé (PV très basse, source de commande verrouillée Terminal).
2. **Essai à vide** (axe débrayé si possible, ou machine non chargée) : valider `RelayFwd`/`RelayRev`
   séparément, sens physique conforme au joystick.
3. Valider l'interlock de sens : tenter une inversion directe Fwd→Rev en mouvement → doit être
   bloquée jusqu'à `DegradedStopSettleTime` écoulé après coupure relais.
4. Valider la double vérification contacteurs (`FwdContactorCheck`/`RevContactorCheck`) :
   débrancher volontairement un retour contacteur → `ErrorId` doit se lever, sorties coupées.
5. Valider l'arrêt sur capteur (§9bis) à vitesse **PV uniquement**, machine non chargée, avant
   tout essai à vitesse GV ou en charge.
6. Seulement après ces 5 points validés : essai en charge, montée progressive PV→GV.

---

## 🔁 8. Retour d'expérience (à compléter après test)

- [x] **Intégré dans `PRG_MAIN` (2026-07-02, revue par une 2ᵉ IA/session)** : `instSafetyChariotM3`
      + `instChariotM3`, `CommMode` figé `DEGRADED_IO`, câblé sur `FB_Joystick_0.AxisCmdX`.
      Stubs `GVL_Chariot_M3_Stub` (relais/retours/capteur cible), même principe que
      `GVL_Winch_M1_Stub`/`M2_Stub`.
- [ ] **Finding revue (2026-07-02)** : en mode `ETHERCAT`, `IsStoppedConfirmed` repose sur
      `ABS(SpeedRamp.Current) < 0.1` (rampe logicielle) — même classe de bug que celui corrigé
      dans `FB_Winch` (inversion joystick plus rapide que la décélération = fenêtre jamais
      atteinte, cf. `FB_Winch.st` §3/`DirectionChangePending`). **Non bloquant aujourd'hui**
      (`ETHERCAT` reste TBD/non câblé), mais **à corriger avant d'activer ce mode** — appliquer
      le même correctif que `FB_Winch` (forcer la cible de rampe à 0.0 dès qu'un changement de
      sens est en attente, indépendamment du signal joystick).
- [ ] Sens (Fwd/Rev) cohérent avec le joystick axe X (à vérifier au 1er essai, à vide — §7)
- [ ] Sélection PV/GV : seuils `DegradedGvThresholdHighPct`/`LowPct` à régler selon ressenti opérateur
- [ ] Arrêt sur capteur cible : comportement §9bis (verrouillage sens identique, déverrouillage sur inversion) — coupure relais **immédiate** depuis correctif v1.1 (F1), à confirmer en conditions réelles que `DegradedStopSettleTime` est suffisant compte tenu de la décélération physique réelle du variateur (§4bis)
- [ ] `DegradedStopSettleTime` : régler selon le temps d'arrêt physique réel observé (rampe interne AC600, §4bis) — valeur par défaut (1s) non validée terrain
- [ ] Frein chariot : mêmes réglages temporisés que le treuil, ou délais différents à ajuster (`BrakeDelay*`) ?
- [ ] Vérifier qu'un changement de `CommMode` pendant un mouvement est bien ignoré (`CommModeLocked`, correctif v1.1 F5)
- [ ] Une fois l'EtherCAT AC600 fiabilisé : lever les TBD §4 (protocole variateur), passer des tests en `CommMode := ETHERCAT`
- [ ] `FB_Safety_Chariot` : n'est validée que pour perte joystick/CAN ce lot — revoir avant mise en service définitive
- [ ] Paramètre "source de commande" AC600 (§4bis) confirmé verrouillé sur Terminal pendant `DEGRADED_IO` — vérifier qu'une reprise EtherCAT intermittente ne perturbe pas la commande relais

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (`FB_Chariot`, mapping M3/AC600).
- **Partie 3 v1.2** — Contrat FB (`StartStop`/`SafeStop`, ErrorId, reset, §1bis FB de mouvement).
- **Partie 4 v1.1** — Cycle (§5 Chariot — approche temporisée, arrêt sur capteur, source des paramètres `ApproachTime`/`ApproachSpeed`).
- **Partie 9 v1.0** — Fonction Winch (patterns réutilisés : interlock sens, `FB_Brake`, `FB_Safety_<Metier>`, `HYSTERESIS`).
