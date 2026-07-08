# 📋 Analyse Fonctionnelle — Partie 1 : Présentation & Fonctions (v1.5)

> 📦 **Programme CODESYS associé** : `v0.4.0_SimNoHardware` — voir [VERSION_HISTORY.md](VERSION_HISTORY.md)

> Projet : **Excavatrice de dragage** — Automate CODESYS 3.5
> Périmètre : automatisme + analyse fonctionnelle (IHM hors scope)
> **v1.6** — Alignment on latest changes (2026-07-08): Arming sequence safety (cannot start if contactor already closed) and arming failure detection (`EmergencyArmingFailed` active after 2s confirmation timeout).
> **v1.5** — Retour terrain 2026-07-07 : refonte complète de la section **§Sécurité électrique**.
> 3 signaux distincts désormais identifiés autour de la chaîne AU (`EmergencyChain_DI` boucle
> physique, `EmergencyStopOk_DI` contacteur de puissance réellement engagé, `EmergencyArming_RQ`
> commande de réarmement) là où la v1.4 ne parlait que d'« `EmergencyStopOk` = info machine en
> AU », confusion aujourd'hui levée. **Correctif critique de polarité** sur `PowerCutOff_A_RQ`/
> `B_RQ` : architecture **à commande maintenue** (fail-safe) — la 1ère version codée avait la
> polarité inversée (bug documenté ci-dessous en bandeau REX, pour ne jamais reproduire l'erreur).
> Ajout de la **séquence de réarmement** (impulsion 1 s + verrouillage 5 s, commande IHM
> uniquement, jamais automatique) et d'une **casuistique exhaustive** de tous les cas de figure
> de la chaîne de coupure de puissance. Voir `DOC/AF_Partie9_Fonction_Winch_v1.7.md` §4quinquies
> pour le détail des **Safety Mouvement** (3 aujourd'hui, d'autres pourront s'ajouter — catégorie
> ouverte, non limitée à un nombre fixe) qui peuvent déclencher une coupure logicielle — non
> re-décrits ici, seulement référencés. ⚠️ Remarque nommage (retour utilisateur 2026-07-07) :
> le nommage précédent par lettre (utilisé jusqu'ici dans le code) est **abandonné comme
> vocabulaire** — ni parlant, ni évolutif à l'arrivée d'autres cas futurs — voir encadré dédié
> plus bas dans ce document.
> **v1.4** — Renommage terminologique (demande utilisateur, 2026-07-02) : Godet→Grappin
> (ouverture/fermeture, prévention gravats), Translation→Chariot (axe transversal M3, objet
> métier qui se déplace) — préfixe I/O physique M3 inchangé.
> **v1.3** — Retour terrain 2026-07-02 : le câble mécanique de position haute extrême a été
> **retiré de la chaîne AU matérielle** — c'est désormais l'automate qui gère la coupure via
> `PowerCutOff` à partir d'un capteur TOR lu en entrée (voir §Sécurité électrique). Seuls les
> boutons coup-de-poing opérateur restent un AU **purement matériel**. Ce capteur sert aussi de
> référence répétable pour le homing (voir Partie 10).
> **v1.2** — Suite audit documentaire : suppression `CoupeEnable` (n'a jamais existé comme
> variable), modèle d'arrêt `SafeStop`/`StartStop` (voir Partie 3 v1.2), `SafeStop` **par métier**
> (pas de signal global), clarification séquence d'initialisation codeurs.
> **v1.1** — Mapping physique M1/M2/M3, paliers vitesse à masque 4 bits, sécurité électrique (automate jamais coupé).

---

## 🎯 Le projet en bref
Machine de **dragage en carrière noyée**.
Un grappin descend sous l'eau, mord le fond, remonte plein, se déplace, vide.
Mon périmètre : **automatisme + analyse fonctionnelle** (IHM hors scope).

---

## 🗺️ Mapping physique des axes (référence projet)

| Axe | Repère | Équipement | Bus | Codeur |
|-----|--------|-----------|-----|--------|
| 🪝 Treuil 1 | **M1** | Moteur treuil levage 1 | — | **COD1** (codeur absolu tambour M1, EtherCAT) |
| 🪝 Treuil 2 | **M2** | Moteur treuil levage 2 | — | **COD2** (codeur absolu tambour M2, EtherCAT) |
| ↔️ Chariot | **M3** | Variateur **AC600** axe transversal | EtherCAT | — (consigne vitesse %) |

🧭 **Règle de lecture** : `COD1` ⇒ codeur du treuil **M1**, `COD2` ⇒ codeur du treuil **M2**, `AC600` ⇒ variateur de l'axe transversal **M3**.

---

## 🔧 Équipements pilotés

| Axe | Matériel | Pilotage |
|-----|----------|----------|
| 🪝 Plongée/Extraction | 2 treuils identiques (M1, M2) | 2 contacteurs sens + **2×4 contacteurs vitesse** (5 paliers, masque 4 bits/palier) |
| 🛗 Position câble | 2 codeurs absolus tambour (COD1→M1, COD2→M2) | EtherCAT → déroulé en **mètres** |
| 🛑 Maintien charge | 2 freins manque-courant | Logique levage (frein colle au repos) |
| ↔️ Chariot | 1 moteur sur variateur AC600 (M3) | EtherCAT, commande **vitesse %** |
| 🣣 Grappin | (= désynchro des 2 treuils) | Pas de moteur propre |
| 🕹️ Commande | Joystick Hall → CANopen | 2 axes + bouton |
| 📡 Capteurs | Fond touché, fdc haut/bas, positions travail/vidange/maintenance | TOR + position |
| 🔌 Retour contacteurs | Contact auxiliaire par contacteur de puissance | TOR → surveillance collage |

---

## 🪜 Paliers de vitesse (masque 4 bits)

Chaque treuil dispose de **4 contacteurs de vitesse**. La vitesse se construit en **5 paliers**.

- Chaque palier porte un **masque de 4 bits** ⇒ on choisit **librement** quels contacteurs sont actifs (`bit0..bit3`).
- 🎛️ **Table indépendante par treuil** (M1 et M2 ont chacun leurs 5 masques).
- 🧭 L'ordre d'actionnement n'est pas implicite : il est **explicitement défini dans la table** de masques.

> Décodage assuré par `FB_SpeedStep` (voir Partie 2).

---

## 🧱 Fonctions principales (objets)

- 🕹️ **Joystick** → traduit le geste opérateur en consigne.
- 🪝 **Treuil** ×2 → cœur métier : direction, vitesse, frein, position, limites.
- ↔️ **Chariot** → amène le pont sur la bonne position.
- 🣣 **Grappin** → ouvre/ferme via désynchro des treuils.
- 🔄 **Cycle** → enchaîne les étapes en semi-auto.
- 🎚️ **Modes** → Manuel / Maint N1 / N2 / Semi-auto + autorisations.

---

## 🧩 Fonctions appelées (briques — RÉUTILISER l'existant)

⚠️ **Règle** : ne **jamais réimplémenter** une brique déjà fournie par CODESYS. Composer avec les librairies standard (notamment **Util**).

- 📐 Scaling → `LIN_TRAFO` (pts↔m, %↔variateur, analogiques).
- 📈 Rampes → `RAMP_REAL` (anti-à-coups).
- 🎛️ Régulation arrêt → `PID_FIXCYCLE`.
- 🪜 Paliers vitesse → `HYSTERESIS`.
- 🚧 Bornes/limites → `LIMITALARM`.
- 🛗 Codeur éclaté → Lecture / Mise à l'échelle / **Référencement** / Diag.

---

## 🔗 Interactions (flux de données)

```
Joystick ──consigne %──► Cycle/Modes ──StartStop──► Treuil + Chariot
Codeur ──position m──► Treuil ──limite──► ralentit/arrête
Treuil ──pilote──► Frein + Contacteurs
Safety métier (par domaine) ──SafeStop──► FB de mouvement concerné ──► rampe décélération RAPIDE (Enable maintenu)
Safety ──PowerCutOff──► contacteur général amont (si collage détecté)
```

🧭 **Tout passe par Modes + Safety avant d'agir.** L'arrêt sûr logiciel = **`SafeStop`** (sortie
d'un bloc safety **métier**, une par domaine) reçu en entrée par le(s) FB de mouvement concerné(s)
→ **rampe de décélération rapide**, le FB restant `Enable`. `Enable = FALSE` reste un mécanisme
**distinct** : neutralisation complète (coupure des sorties du FB). Voir Partie 2 v2.5 §6 et
Partie 3 v1.2 §1/§7.

---

## 🛡️ Sécurité (priorité absolue)
- Cohérence capteurs, valeurs absurdes, conditions de marche.
- 🪝 Frein = séquence stricte intégrant les temps physiques (relâche après établissement moteur, colle après décélération — voir Partie 4 §Frein).
- 🔴 Tout défaut process détecté par un bloc safety métier → il lève **son** `SafeStop` → le(s) FB de mouvement concerné(s) passent en **rampe de décélération rapide** (`Enable` maintenu), puis freins collés. Voir Partie 2 v2.5 §6.

> 🚫 **Limite légale ≠ sécurité** : l'interdiction de draguer sous une cote imposée est une
> **interdiction normale** (réglementaire), appliquée par **`FB_Modes`** en semi-auto/descente,
> **pas** par un bloc safety. Signalisation seule en maintenance. Voir Partie 6 §3.

### 🔌 Sécurité électrique — automate jamais coupé
L'automate **reste alimenté en permanence** (pas de coupure électrique générale du contrôleur).
Seule la **puissance moteurs** est coupée par un contacteur général amont, via une **boucle AU
matérielle** en série (boutons coup-de-poing) **et** un canal piloté par l'automate lui-même
(`PowerCutOff_A_RQ`/`B_RQ`, voir plus bas). L'automate continue de surveiller et de piloter le
réarmement, il n'est jamais la cible de la coupure.

#### 🧭 Les 3 signaux distincts (REX 2026-07-07)

Avant ce REX, un seul signal `EmergencyStopOk_DI` était utilisé et compris comme « la boucle AU ».
L'analyse terrain a montré qu'il fallait en réalité **3 signaux séparés**, chacun avec un rôle
précis :

| Signal | Sens | Rôle | Conditionné en |
|--------|------|------|-----------------|
| **`EmergencyChain_DI`** | Entrée TOR (NC, 1=sain) | Retour de la **boucle AU physique elle-même** : boutons coup-de-poing opérateur **en série ET** le canal `PowerCutOff` piloté par le PLC, tous deux insérés dans cette même boucle matérielle. `TRUE` = boutons relâchés **ET** pas de coupure PLC en cours. C'est une **précondition à l'armement**, **PAS** le portail maître du programme. | `PRG_00_Inputs.EmergencyChain` |
| **`EmergencyStopOk_DI`** | Entrée TOR (contact auxiliaire NO, 1=actif) | Confirmation que le **contacteur de puissance est réellement engagé** — la garantie la plus forte possible (« la puissance coule vraiment »). Reste le **portail maître** utilisé par tout le programme (`EmergencyStopOk` en entrée de chaque FB, contrat standard Partie 3 §1). Nom conservé tel quel pour ne pas casser l'interface FB partout dans le code. | `PRG_00_Inputs.EmergencyStopOk` |
| **`EmergencyArming_RQ`** | Sortie TOR (impulsion) | Commande PLC de **réarmement** du contacteur de puissance (mécanisme à ressort, un pulse suffit). | `PRG_10_Outputs` (voir séquence ci-dessous) |

⚠️ **Ne pas confondre** : `EmergencyChain` dit « les conditions permettant d'armer sont réunies »,
`EmergencyStopOk` dit « la puissance est effectivement là ». Les deux peuvent diverger
temporairement : boucle saine (`EmergencyChain=TRUE`) mais contacteur toujours ouvert
(`EmergencyStopOk=FALSE`) tant que l'opérateur n'a pas réarmé via l'IHM — c'est l'état normal
juste après une remise en route ou un AU relâché (voir scénarios ci-dessous).

> 🏷️ **Rappel — « Safety Mouvement ».** Il s'agit d'une **catégorie ouverte** de protections
> logicielles de `FB_Safety_Winch`, capables de déclencher une coupure de puissance (détail
> technique complet en `DOC/AF_Partie9_Fonction_Winch_v1.7.md` §4quinquies, non re-décrit ici).
> **3 existent aujourd'hui**, nommées par leur **rôle** (voir remarque de nommage plus bas pour
> pourquoi un simple suffixe de lettre est délibérément évité — d'autres cas viendront s'ajouter
> à cette liste avec le temps, sans limite de nombre) :
> - **Safety Mouvement — Mouvement non commandé** (`ErrorId` bit7 de `FB_Safety_Winch`) — le codeur
>   détecte un déplacement alors que tout est confirmé physiquement à l'arrêt (contacteurs **et**
>   frein serrés). Typiquement : une charge qui glisse/tombe malgré le frein.
> - **Safety Mouvement — Pilotage sans commande opérateur** (`ErrorId` bit8) — le moteur reste
>   piloté (contacteurs engagés) alors que l'opérateur n'envoie plus aucune commande (perte
>   joystick ou manette au neutre) depuis un temps anormalement long.
> - **Safety Mouvement — Glissement grappin** (`ErrorId` bit9) — pendant un mouvement grappin, le
>   treuil censé rester immobile (M1) dérive de sa position au-delà d'un seuil, signe que la
>   synchronisation grappin/treuil ne tient plus.
>
> Tous sont des **défenses en profondeur** (cas rares, contacteurs/frein déjà censés être fiables)
> — c'est précisément parce qu'ils ne devraient normalement jamais se déclencher que, s'ils le
> font, la réponse est la plus forte possible : coupure de puissance (`PowerCutOff`), pas un
> simple `SafeStop`.
>
> ℹ️ **`FB_Safety_Winch` n'est pas la seule source possible — mais la seule active aujourd'hui.**
> `PowerCutOff_A_RQ` agrège en réalité **3 sources** (voir formule ci-dessous) : les 2 instances de
> `FB_Safety_Winch` (M1 et M2, qui portent les 3 Safety Mouvement ci-dessus) **et**
> `FB_Safety_Chariot` (M3). Ce 3ᵉ bloc participe déjà à la formule agrégée mais **ne câble
> aujourd'hui aucun Safety Mouvement réel** : sa sortie `PowerCutOff` reste codée en dur à `FALSE`
> (TBD — voir `CODE/CHARIOT/FB_Safety_Chariot.st`, en attente d'un `ST_ContactorCheck` de puissance
> pour M3, même limitation que `FB_Safety_Winch` avant l'ajout de ses 3 Safety Mouvement actuels).
> Tout Safety Mouvement futur pour le Chariot viendrait donc naturellement s'ajouter **côté
> `FB_Safety_Chariot`**, pas forcément côté Winch.
>
> ℹ️ **Le Grappin n'a pas de bloc safety dédié — cohérent avec « pas de moteur propre » (voir
> §Fonctions principales ci-dessus).** Sa protection contre le glissement est répartie sur
> **2 couches distinctes** : **couche 1** dans `FB_Grappin` lui-même (`M1SlipDetected`, tolérance
> 1.0 m) → alimente `SafeStop` (pas `PowerCutOff`) ; **couche 2** = le Safety Mouvement
> « Glissement grappin » ci-dessus, câblé **uniquement dans l'instance M1** de `FB_Safety_Winch`
> (`GrappinHoldStillActive` sur `instGrappin.Busy`, toujours `FALSE` côté M2) → peut escalader
> jusqu'à `PowerCutOff` si la couche 1 n'a pas suffi. Donc **oui**, `FB_Safety_Winch` couvre bien
> indirectement le Grappin (via son instance M1), mais il n'existe pas de `FB_Safety_Grappin`
> séparé — voir `DOC/AF_Partie12_Fonction_Grappin_v1.2.md` pour la couche 1 et Partie9 §4quinquies
> pour la couche 2.
>
> ⚠️ **Remarque de nommage (retour utilisateur 2026-07-07, confirmé/renforcé en cours de
> relecture)** : un suffixe alphabétique séquentiel n'est **ni parlant** (il faut aller lire la
> définition pour savoir de quoi il s'agit) **ni évolutif** — l'utilisateur a explicitement demandé
> de **ne plus utiliser cette lettre par cas** dans la documentation, d'autres cas étant appelés à
> s'ajouter à l'avenir sans qu'une suite de lettres soit une bonne façon de les désigner. Ce
> document adopte donc **exclusivement** le vocabulaire « Safety Mouvement — \<Rôle\> » (ci-dessus),
> qui n'a par construction **aucune limite de nombre** : un futur cas reçoit simplement un nouveau
> nom descriptif, sans dépendre d'un rang alphabétique. **Le code actuel** (`FB_Safety_Winch.st`,
> `PRG_03_Safety.st`, `ST_WinchHMI.st`, ainsi que `AF_Partie9_Fonction_Winch`) utilise encore en
> interne l'ancien nom par lettre pour ces 3 cas — un renommage effectif en `CODE/` (identifiants,
> commentaires) est une **proposition à valider séparément**, hors périmètre de cette révision
> Partie 1 qui reste **documentaire uniquement**. Nommage cible suggéré pour ce renommage futur,
> préfixé `SafetyMotion` (cohérent avec le préfixe `FB_Safety_<Metier>` déjà en usage dans le
> projet) : `SafetyMotionUncommandedMotion`, `SafetyMotionUncommandedDrive`,
> `SafetyMotionGrappinSlip`.

#### 🧨 Polarité fail-safe de `PowerCutOff_A_RQ` / `B_RQ`

`PowerCutOff_A_RQ`/`PowerCutOff_B_RQ` (2 canaux redondants, `PRG_10_Outputs.st`) forment le canal
**piloté par le PLC**, en série avec les boutons coup-de-poing dans la même boucle AU matérielle.

> 🔴🔧 **REX 2026-07-07 — correctif critique de polarité, à ne jamais reproduire.**
> La **1ère version codée** utilisait `PowerCutOff_A_RQ := TRUE` pour signifier « je demande la
> coupure ». C'est une **erreur de conception grave** : en cas de défaut réel détectant un
> problème (PLC plantant, tâche dépassant son watchdog, perte d'alimentation automate), le PLC
> ne peut **plus rien écrire du tout** — la sortie retombe à son état de repos (`FALSE` par
> défaut sur la plupart des cartes de sortie). Avec l'ancienne polarité (`TRUE=coupe`), un PLC
> mort aurait donc **maintenu la puissance active** au lieu de la couper : **le pire cas de
> figure possible** pour une fonction de sécurité.
>
> **Architecture corrigée, à commande maintenue (fail-safe)** : le PLC doit **maintenir**
> `PowerCutOff_A_RQ`/`B_RQ` à `TRUE` **en permanence** tant que tout va bien. Dès que le PLC
> **arrête** de les maintenir (transition `TRUE→FALSE`) — **volontairement** (un des Safety
> Mouvement de `FB_Safety_Winch` détecte un problème, voir §ci-dessus pour les noms descriptifs et
> `DOC/AF_Partie9_Fonction_Winch_v1.5.md` §4quinquies pour le détail technique, non re-décrit ici)
> **ou accidentellement** (PLC plante, perd
> l'alimentation, dépassement watchdog tâche) — le circuit AU s'ouvre et coupe le contacteur de
> puissance, exactement comme un bouton coup-de-poing. C'est la logique **inverse** de l'ancienne
> version : maintenant, l'absence de PLC = coupure, pas l'inverse.

```
PowerCutOff_A_RQ := NOT (instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff OR instSafetyChariotM3.PowerCutOff) AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
PowerCutOff_B_RQ := PowerCutOff_A_RQ;
```
(corps réel dans `CODE/MAIN/PRG_10_Outputs.st` — référencé ici, non recopié en détail).

#### 🔁 Séquence de réarmement du contacteur de puissance

Le réarmement n'est **jamais automatique**, même si `EmergencyChain` redevient sain tout seul —
c'est une **décision explicite de l'opérateur**, prise depuis l'IHM.

1. **Commande IHM** (`GVL_IHM.Modes.CmdEmergencyArming`, détectée sur **front montant**).
2. Le front ne déclenche l'impulsion **que si** `EmergencyChain = TRUE` (boucle saine) **ET**
   `EmergencyStopOk = FALSE` (bloqué/ignoré si déjà armé pour éviter une coupure intempestive lors de l'auto-test) **ET**
   qu'aucune impulsion ni verrouillage n'est déjà en cours.
3. **Impulsion de 1 seconde** sur `EmergencyArming_RQ` — le contacteur utilise un mécanisme à
   ressort, un pulse suffit à l'armer, pas besoin de maintenir la commande.
4. **Verrouillage de 5 secondes** après la fin de l'impulsion : toute nouvelle demande de
   réarmement est **ignorée** pendant cette fenêtre (contrainte mécanique du ressort, temps de
   recharge nécessaire avant une nouvelle tentative).
5. Retours exposés côté IHM (`GVL_IHM.Modes.*`, voir `CODE/SUPERVISION/ST_ModesHMI.st`) :
   `EmergencyChainOk` (boucle saine), `PowerContactorOk` (contacteur confirmé engagé, miroir de
   `EmergencyStopOk`), `EmergencyArmable` (réarmement possible **maintenant**),
   `EmergencyArmingBusy` (pulse ou verrouillage en cours — griser le bouton IHM pendant ce temps).

---

### 📖 Scénarios terrain pas-à-pas

#### (a) Mise en route normale à froid

1. Sectionneur général fermé → l'automate démarre (il n'est **jamais** coupé électriquement, y
   compris pendant que la puissance moteurs est encore absente).
2. Le contacteur de puissance est **encore ouvert** (pas armé depuis la dernière coupure/mise hors
   tension) → `EmergencyStopOk = FALSE`.
3. Toutes les conditions physiques sont vérifiées : boutons coup-de-poing relâchés, canal PLC
   `PowerCutOff_A_RQ`/`B_RQ` maintenu (aucun Safety Mouvement actif, PLC sain) → `EmergencyChain = TRUE`.
4. Côté IHM : `EmergencyChainOk = TRUE`, `PowerContactorOk = FALSE` (pas encore armé),
   `EmergencyArmable` passe à `TRUE` (chaîne saine, ni pulse ni verrouillage en cours).
5. L'opérateur presse le bouton de réarmement sur l'IHM (`CmdEmergencyArming`, front).
6. Impulsion de 1 s sur `EmergencyArming_RQ` → le contacteur de puissance s'enclenche
   (mécanisme à ressort).
7. Le contact auxiliaire confirme l'engagement → `EmergencyStopOk` passe à `TRUE`,
   `PowerContactorOk = TRUE` côté IHM.
8. Verrouillage de 5 s démarre (recharge mécanique) — sans impact ici, aucune nouvelle demande
   n'est nécessaire.
9. Machine opérationnelle : puissance présente, tous les FB de mouvement peuvent être `Enable`.

#### (b) Fonctionnement normal, arrêt d'urgence physique pressé

1. Machine en fonctionnement, `EmergencyChain = TRUE`, `EmergencyStopOk = TRUE`.
2. Un bouton coup-de-poing est pressé → la boucle AU matérielle s'ouvre **physiquement**.
3. Le contacteur de puissance retombe **immédiatement** — c'est une coupure **matérielle
   directe**, totalement **indépendante du PLC** (le PLC n'a rien décidé, rien à écrire, la
   coupure a déjà eu lieu électriquement au moment où le bouton s'est enfoncé).
4. `EmergencyChain` passe à `FALSE` (boucle ouverte) et `EmergencyStopOk` passe à `FALSE`
   (contacteur confirmé retombé) — quasi simultanément.
5. Tous les FB de mouvement perdent leur portail maître `EmergencyStopOk` → neutralisation
   complète des sorties (plus de puissance disponible de toute façon).
6. **Après relâchement** du bouton coup-de-poing : `EmergencyChain` repasse à `TRUE` (boucle à
   nouveau saine électriquement) **mais le contacteur reste ouvert** — `EmergencyStopOk` reste
   `FALSE` tant que l'opérateur n'a pas explicitement réarmé via l'IHM.
7. Côté IHM : `EmergencyChainOk = TRUE`, `PowerContactorOk = FALSE`, `EmergencyArmable = TRUE`
   → bouton de réarmement disponible.
8. L'opérateur presse le réarmement IHM → séquence identique aux points 5-9 du scénario (a).

#### (c) Fonctionnement normal, fonction sécurité logicielle demande une coupure

1. Machine en fonctionnement, `EmergencyChain = TRUE`, `EmergencyStopOk = TRUE`.
2. Un des Safety Mouvement de `FB_Safety_Winch` se déclenche (mouvement non commandé, pilotage
   sans commande opérateur, glissement grappin escaladé — détail en
   `DOC/AF_Partie9_Fonction_Winch_v1.5.md` §4quinquies) → `instSafetyWinchM1/M2.PowerCutOff` (ou
   `instSafetyChariotM3.PowerCutOff`, aujourd'hui toujours `FALSE`, voir remarque ci-dessus) passe
   à `TRUE`.
3. Le PLC **arrête volontairement** de maintenir `PowerCutOff_A_RQ`/`B_RQ` à `TRUE` (il les
   force à `FALSE` par le calcul même de la formule ci-dessus).
4. Le circuit AU s'ouvre **exactement comme au point 3 du scénario (b)** — mêmes conséquences
   électriques — mais **sans qu'aucun bouton physique n'ait été touché**.
5. `EmergencyChain` passe à `FALSE` (le canal PLC fait partie de la même boucle série) puis
   `EmergencyStopOk` passe à `FALSE` (contacteur confirmé retombé).
6. Contrairement au scénario (b), il y a ici un **défaut logiciel sous-jacent** (`ErrorId` bit7/8/9
   de `FB_Safety_Winch`) qui doit être **acquitté** en plus du réarmement du contacteur — ce sont
   **deux actions distinctes** (voir casuistique, cas 8).
7. Une fois la cause traitée et le défaut acquitté (front Reset + cause disparue, pattern standard
   Partie 3 §5), `EmergencyChain` peut redevenir sain → réarmement IHM nécessaire comme en (a)/(b).

---

### 📊 Casuistique exhaustive — chaîne AU / coupure de puissance

| # | Cas | Déclencheur | Comportement automate | État des signaux clés | Action opérateur pour sortir |
|---|-----|-------------|------------------------|-------------------------|-------------------------------|
| 1 | **Mise en route à froid** | Sectionneur fermé, contacteur jamais armé depuis coupure | Automate démarre, surveille, attend une demande de réarmement | `EmergencyChain=TRUE`, `EmergencyStopOk=FALSE`, `EmergencyArmable=TRUE` | Presser réarmement IHM (scénario a) |
| 2 | **AU physique pressé** | Bouton coup-de-poing enfoncé | Coupure **matérielle directe**, indépendante du PLC | `EmergencyChain=FALSE`, `EmergencyStopOk=FALSE` | Relâcher le bouton **puis** réarmer via IHM (scénario b) |
| 3 | **AU physique relâché, pas encore réarmé** | Suite au cas 2, bouton relâché | Boucle de nouveau saine, contacteur toujours ouvert (pas d'auto-réarmement) | `EmergencyChain=TRUE`, `EmergencyStopOk=FALSE`, `EmergencyArmable=TRUE` | Presser réarmement IHM |
| 4 | **Coupure logicielle — Safety Mouvement déclenché** | `FB_Safety_Winch` lève `PowerCutOff` (bit7/8/9) | PLC arrête de maintenir `PowerCutOff_A/B_RQ` → coupure identique à un AU physique | `EmergencyChain=FALSE`, `EmergencyStopOk=FALSE`, `ErrorId` bit7/8/9 actif | Traiter la cause, **acquitter le défaut** (Reset front), puis réarmer via IHM (2 actions distinctes, voir cas 8) |
| 5 | **PLC plante / perte alimentation / watchdog tâche dépassé** | Panne automate ou dépassement du seuil de surveillance tâche (fonction système CODESYS, 200 ms) | Le PLC ne peut plus **rien écrire** : les sorties (dont `PowerCutOff_A/B_RQ`) retombent à leur état de repos `FALSE` → coupure automatique, **aucune action logicielle nécessaire ni possible**. C'est le cas **le plus fail-safe** de tous : la sécurité ne dépend d'aucune décision du programme au moment du défaut. | `PowerCutOff_A/B_RQ` retombent à `FALSE` par absence d'écriture (pas par calcul) ; `EmergencyChain`/`EmergencyStopOk` suivent | Redémarrer/réparer l'automate, puis réarmer via IHM une fois le PLC de nouveau sain |
| 6 | **Tentative de réarmement pendant boucle AU non saine** | Appui `CmdEmergencyArming` alors que bouton encore pressé ou `PowerCutOff` PLC encore actif | La demande est **rejetée** : la garde `AND PRG_00_Inputs.EmergencyChain` en tête de la séquence de pulse bloque toute impulsion | `EmergencyChain=FALSE` → pas d'impulsion, `EmergencyArmable=FALSE` | Lever la cause (relâcher bouton / acquitter défaut) avant de pouvoir réarmer |
| 6bis | **Tentative de réarmement alors que déjà armé** | Appui `CmdEmergencyArming` alors que `EmergencyStopOk = TRUE` | La demande est **bloquée / ignorée** pour éviter une coupure intempestive lors de l'auto-test redondant | `EmergencyStopOk=TRUE` → pas d'impulsion, `EmergencyArmable=FALSE` | Aucune action (déjà armé) |
| 7 | **Tentative de réarmement pendant la fenêtre de verrouillage 5 s** | Appui `CmdEmergencyArming` juste après un pulse précédent | La demande est **ignorée** : garde `AND NOT EmergencyArmingLockoutActive` | `EmergencyArmingBusy=TRUE`, `EmergencyArmable=FALSE` | Attendre la fin des 5 s de verrouillage puis présenter la demande |
| 8 | **Défaut Safety Mouvement acquitté mais contacteur non réarmé** | Reset du défaut à l'origine de la coupure (front Reset + cause disparue) | Le défaut disparaît de `ErrorId`, mais **le contacteur reste ouvert** — reset du défaut et réarmement du contacteur sont **deux actions distinctes et indépendantes** | `ErrorId`=0, `EmergencyChain` can become `TRUE`, but `EmergencyStopOk` remains `FALSE` tant que le réarmement IHM n'a pas été fait | Presser en plus le réarmement IHM (2ᵉ action, après acquittement du défaut) |
| 9 | **Impulsion réarmement envoyée mais le contacteur ne s'enclenche pas** | Défaillance mécanique/électrique, pas de retour contacteur sous 2s | La séquence détecte l'absence de retour. La sortie `EmergencyArmingFailed` passe à `TRUE` pour signaler le défaut sur l'IHM | `EmergencyArmingFailed=TRUE`, `EmergencyStopOk=FALSE`, `EmergencyArmingBusy=FALSE` | Traiter la cause mécanique/électrique, acquitter via `FaultMachineReset_IHM`, puis retenter |
| 10 | **Redondance des 2 canaux A/B — un seul réellement câblé/fonctionnel** | Défaut de câblage ou de comportement mécanique faisant qu'un seul des 2 canaux physiques (`PowerCutOff_A_RQ`/`B_RQ`) coupe réellement le contacteur (l'un colle, l'autre pas) | ❓ **Question ouverte, non tranchée par le code.** Les 2 sorties logicielles sont strictement identiques (`PowerCutOff_B_RQ := PowerCutOff_A_RQ`) — la redondance dépend entièrement du câblage matériel réel (2 chemins électriques indépendants jusqu'au contacteur) et non d'une logique de vote/comparaison côté PLC. Si un seul canal est réellement câblé ou qu'un des deux relais colle sans que l'autre coupe, **rien dans le programme actuel ne le détecte** | Les deux sorties logicielles restent identiques quel que soit l'état réel du câblage — pas de signal de divergence | **À vérifier au câblage réel** sur site (essai de coupure canal par canal) ; envisager, si nécessaire, un retour de chaque canal en entrée pour détecter une divergence A/B |
| 11 | **Réarmement réussi (cas nominal)** | Séquence complète scénario (a)/(b)/(c) menée à bien | Contacteur confirmé engagé, machine opérationnelle | `EmergencyChain=TRUE`, `EmergencyStopOk=TRUE`, `EmergencyArmingBusy=FALSE`, `EmergencyArmable=FALSE` (déjà armé) | Aucune — état stable normal |
| 12 | **Coupure d'urgence à distance IHM** | Appui sur le bouton HMI `CmdEmergencyCutOff` | Coupe immédiatement les deux canaux `PowerCutOff_A_RQ` / `PowerCutOff_B_RQ` | `CmdEmergencyCutOff=TRUE`, `EmergencyChain=FALSE`, `EmergencyStopOk=FALSE` | Relâcher le bouton HMI (repasse à `FALSE`) **puis** réarmer via IHM (scénario a/b) |

> 🏷️ **Safety Mouvement** (cas 4 et 8 ci-dessus) = mouvement non commandé / pilotage sans commande
> opérateur / glissement grappin — voir le rappel plain-langage juste au-dessus de « Polarité
> fail-safe » pour le détail des 3, et Partie9 §4quinquies pour la technique complète.

---

## 🔄 Cycle type (semi-auto)

1. ⬇️ Descente grappin ouvert → 🌊 capteur **fond touché**.
2. 🔧 Synchro 2 treuils + recalage (petite vitesse).
3. ⬆️ Accélération → remontée grappin plein.
4. ⏱️ Temps d'égouttage en haut.
5. ↔️ Chariot vers zone de vidange.
6. ⬇️ Descente + 🪣 ouverture grappin (désynchro).
7. 🔁 Retour position travail.

⚠️ Cycle = **indicatif**, pas figé.

---

## 🧭 Initialisation (référencement codeurs)
1. Descente 2 treuils synchro, grappin ouvert.
2. 🌊 Toucher l'eau = **plan 0**.
3. Mode maintenance → preset codeurs à une **valeur positive** (offset brut choisi assez grand
   pour que la position mesurée ne devienne jamais négative en usage normal — c'est une valeur
   **interne** au codeur, pas ce qui est affiché).
4. Affichage 0 m à ce plan de référence (l'échelle **affichée** est recalée à 0, indépendamment
   de l'offset brut du point 3) ; ⬆️ enroulé = +m, ⬇️ sous l'eau = −m.

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (orchestration, flux `SafeStop`/`StartStop`, `PowerCutOff`).
- **Partie 3 v1.2** — Contrat FB : interface (`Enable/Reset/EmergencyStopOk/Mode`), `StartStop`, `SafeStop`.
- **Partie 4** — Cycle & séquenceur.
- **Partie 5** — Modes & maintenance : limite légale (`FB_Modes`).
- **Partie 6** — Conditionnement E/S.
- **Partie 9 v1.5** — Fonction Winch : détail des Safety Mouvement (§4quinquies) qui peuvent
  déclencher une coupure logicielle de puissance (voir §Sécurité électrique ci-dessus).
