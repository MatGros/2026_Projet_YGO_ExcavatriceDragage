# 🔍 Audit Automatisme Industriel — v1.0

> **Périmètre** : audit du point de vue automatisme industriel (PLC/IHM, machines spéciales et
> lourdes), incluant l'ergonomie maintenance et utilisateur.
> **Focus principal** : chaîne **Joystick → Treuils (M1) → Relais → Grappin/Godet**.
> **Passe rapide séparée** : chariot (translation M3) et équipements annexes.
> **Base auditée** : branche `claude/industrial-automation-audit-h92eqi` (commit `75fa126`),
> `CODE/*.st`, `DOC/AF_Partie1..9`, briques extraites de `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export`
> (`FB_Ramp`, `FB_CycleTime` — nécessaires pour valider le comportement dynamique réel).
> ⚠️ **Audit seul** : aucun fichier `CODE/` ni spec existante modifié.

---

## 🧭 0. Contexte du lot audité

Lot courant = test **banc** de la chaîne M1 en **Maintenance N1**, **sans codeur**, **sans matériel**
(GVL stub + miroir des retours contacteurs). Les stubs (`Enable`, `EmergencyStopOk`, `Mode`, `Reset`)
sont **clairement marqués** dans `PRG_MAIN.st` — c'est un point fort, l'audit n'y revient que
lorsqu'un stub a un impact ergonomique immédiat (F07).

**Échelle de gravité** :
- 🔴 **Critique** — à corriger **avant tout essai avec moteur réel**, même en banc supervisé.
- 🟠 **Majeur** — à corriger avant câblage matériel réel / duplication M2.
- 🟡 **Mineur / dette** — à planifier.
- 🔵 **Ergonomie** — conduite, IHM, maintenance.

---

## 📊 1. Synthèse des constats

| ID | Gravité | Domaine | Constat (résumé) |
|----|---------|---------|------------------|
| F01 | 🔴 | FB_Winch | Inversion de sens joystick en mouvement → le treuil **continue dans l'ancien sens** à la vitesse commandée |
| F02 | 🔴 | FB_Winch | Rampe interne non gelée sur `Error` → **redémarrage brutal à palier élevé** dès l'acquittement |
| F03 | 🟠 | FB_Winch | Diagnostic incohérent pendant défaut → cascade de **défauts secondaires** masquant la cause racine |
| F04 | 🟠 | Safety | Contacteur **collé** : détecté mais **aucune parade** dans ce lot (`PowerCutOff` = FALSE en dur) — seule protection = AU physique |
| F05 | 🟠 | Joystick/CAN | Trame joystick **figée** (nœud vivant, valeur bloquée) non détectée — l'homme-mort ne protège pas de ce cas |
| F06 | 🟠 | Paramétrage | « RETAIN » annoncé mais **absent** : table paliers M1 + temporisations frein perdues au download/reset froid |
| F07 | 🟠 | Ergonomie banc | `Reset` non câblé nulle part → **tout défaut fugitif est définitif** (SafeStop verrouillé à vie) |
| F08 | 🟡 | Dynamique | **Double rampe en série** (Joystick + Winch) + contradiction Partie4 §7 sur le profil de décélération normale |
| F09 | 🟡 | Frein | Fenêtre **« ni couple ni frein »** de 500 ms à l'arrêt (charge suspendue libre) — point de mise en service |
| F10 | 🟡 | PRG_MAIN | `FB_Safety` transverse calculé mais **jamais consommé** ; diag EtherCAT stubbé — code mort = fausse confiance |
| F11 | 🟡 | FB_Joystick | Sorties non neutralisées sur `Error` (Partie3 §9 é7) ; `Busy` toujours TRUE ; aval ne consulte ni `Error` ni `Done` |
| F12 | 🟡 | Traçabilité | 3 noms pour le POU principal : `PLC_PRG_MAIN` (docs), `PRG_MAIN` (code), `FB_MAIN_MACHINE` (commit) |
| F13 | 🟡 | Traçabilité | Briques critiques **non versionnées** dans `CODE/` (`FB_Ramp`, `FB_CycleTime`, `FB_AxisScale`, `FB_Filter_PT1`, `FB_Safety`, `FB_Diag*`, `ST_DeviceDiag`) |
| F14 | 🔵 | Modes | Pas d'état « repos » : `E_Mode` démarre implicitement à `MANUEL` (=0) au boot |
| F15 | 🔵 | IHM/Maint. | Pas de struct `Hmi` (Partie3 §8) ; pas de **catalogue des défauts** (bit → cause → remède) hors commentaires code |
| F16 | 🔵 | Conduite | Affectation des axes non figée (Y = treuils ; X = ?) ; règle des commandes **diagonales** non définie |
| G01–G03 | 🟡/🔵 | Godet | Points d'attention spec `FB_Bucket` (non codé) — voir §3 |
| T01–T04 | 🟡 | Chariot | Passe rapide translation M3 — voir §4 |
| E01–E04 | 🟡 | Annexes | Codeurs, fdc, tâches, watchdog — voir §4 |

---

## 🪝 2. Chaîne Joystick → Treuil → Relais (audit détaillé)

### F01 🔴 Inversion de sens en mouvement : le treuil continue dans l'ancien sens

**Où** : `CODE/FB_Winch.st` §3 (arbitrage rampe) + §3bis (interlock).

**Mécanisme** : `RampTargetPct` ne dépend que de `SafeStop`/`StartStop` — **pas** du désaccord
`Direction ≠ CommandedDirection`. Or le changement de sens exige `ABS(SpeedRamp.Current) < 0,1 %`
maintenu 200 ms. Vérifié avec l'implémentation réelle de `FB_Ramp` (slew-rate simple, extraite du
`Device.export`) :

1. Opérateur en montée (`Direction=+1`, 60 %), il **inverse le geste** sans pause au neutre.
2. La rampe du joystick fait passer `SpeedRef` par ~0 puis remonte côté descente (`Direction=-1`).
3. Dans `FB_Winch` : `StartStop` redevient TRUE avec `SpeedRefPct` croissant → la rampe interne
   **repart à la hausse** avant d'avoir tenu 200 ms sous 0,1 % (elle quitte le seuil en ~2 ms).
4. `CommandedDirection` reste figé à **+1**, `RelayFwd` reste enclenché (`StepNumber > 0`), les
   paliers remontent → **le treuil accélère en montée alors que l'opérateur commande la descente**,
   et ce tant que le joystick est tenu.

Sur un levage, c'est le cas d'accident type : *l'opérateur pousse « descendre », la charge monte*.
Le seul échappatoire est une pause au neutre ≥ (temps de décél complet + 200 ms) — rien ne l'impose
ni ne le signale à l'opérateur.

**Correction recommandée** : si `Direction ≠ CommandedDirection` → forcer `RampTargetPct := 0`
(décélération normale, rapide si l'écart persiste) jusqu'à l'octroi effectif du changement de sens.
Ainsi l'inversion devient : décélération → arrêt confirmé → réengagement dans le nouveau sens —
comportement attendu d'un treuil à contacteurs.

### F02 🔴 Rampe non gelée sur `Error` → redémarrage brutal après acquittement

**Où** : `CODE/FB_Winch.st` §3 vs §10.

Pendant `Error`, le §10 coupe les sorties physiques, mais le §3 continue de faire suivre à
`SpeedRamp` la consigne joystick (jusqu'à 100 %). Conséquences :

- `State` affiche `BUSY` alors que rien ne bouge (IHM trompeuse, cf. F15) ;
- au front `Reset` (cause disparue), si le joystick est encore incliné : **réenclenchement immédiat**
  contacteur de sens + palier 4/5, sans repartir de zéro — à-coup mécanique majeur sur charge,
  et violation de l'esprit « acquitter ≠ redémarrer » (Partie3 §6 : *redémarrage = nouvel ordre
  explicite*). Le stub actuel `Reset := FALSE` rend le défaut dormant ; il se révélera dès que le
  bouton IHM sera câblé.

**Correction recommandée** : `Error` → `RampTargetPct := 0` + rampe forcée à 0 (coupure déjà brutale
au §10, autant refléter l'état réel) ; et exiger le **retour au neutre du joystick** avant de
réaccepter un mouvement post-acquittement (même principe que Partie4 §7, changement de plafond de
vitesse : « revenir à une position joystick cohérente »).

### F03 🟠 Diagnostic incohérent pendant défaut → défauts secondaires en cascade

**Où** : `CODE/FB_Winch.st` — ordre §5/§6/§7 (checks) puis §10 (coupure).

Les `ST_ContactorCheck` (§7) et l'appel `FB_Brake` (§6) sont calculés sur les **valeurs avant
coupure** : pendant un défaut, `Command = TRUE` alors que la sortie physique est FALSE. Avec du
matériel réel, les retours réels retombent → au bout des timeouts, on lève **StuckOpen sens** et
**défaut frein** *secondaires*, qui polluent `ErrorId` et compliquent le diagnostic de la cause
racine (le `StateAtError` aide, mais l'`ErrorId` cumule du bruit). En banc (miroirs), le problème
est invisible — il apparaîtra au premier défaut réel.

**Correction recommandée** : sur `Error`, geler la chaîne amont (forcer `CommandedDirection := 0`
et cible rampe 0 — cohérent avec F02), ou calculer les checks **après** l'étage de sortie sûre, sur
l'état réellement commandé.

### F04 🟠 Contacteur collé : détection sans parade dans ce lot

`FB_Winch` détecte `StuckClosed` → `ErrorId` → §10 coupe les **commandes**… ce qui est sans effet
sur un contacteur soudé. `PowerCutOff` est à FALSE en dur (`FB_Safety_Winch`), et `FB_Safety_Winch`
ne consomme pas les `ST_ContactorCheck` (il est d'ailleurs appelé **avant** `FB_Winch` dans le scan
— le rebouclage se fera sur les valeurs du cycle N-1, à acter). Dans ce lot, la **seule** parade
réelle contre un treuil parti sans commande est l'**AU physique**.

C'est cohérent avec le périmètre assumé (banc N1 supervisé), mais :
1. l'**acter explicitement** dans la checklist d'essai (AU testé et à portée de main avant le
   premier enclenchement moteur réel) ;
2. au lot suivant : reboucler `FwdContactorCheck`/`RevContactorCheck`/`BrakeContactorCheck`
   (cycle N-1) vers `FB_Safety_Winch` → `PowerCutOff`, et câbler la sortie sur le relais de
   coupure amont (Partie2 §6).

### F05 🟠 Trame joystick figée non détectée

`FB_DiagCanOpen` couvre `Online`/`Operational` (nœud mort). Il ne couvre pas le cas **nœud vivant,
payload figé** (firmware joystick planté, capteur Hall bloqué) : `RawY` reste à sa dernière valeur
→ le treuil **continue** son mouvement. L'homme-mort du projet est *la position du joystick
elle-même* — il ne protège donc pas de ce mode de défaillance, classique sur machine lourde.

**Recommandation** (au plus tard avant semi-auto, idéalement avant matériel réel) : compteur de vie
/ heartbeat applicatif dans la trame CAN si le joystick le permet, sinon contrôle de fraîcheur
(valeur strictement identique au point brut pendant N secondes **hors neutre** → défaut domaine
treuil → `SafeStop`). Le bouton joystick (`RawButton`, aujourd'hui inutilisé en aval) peut aussi
servir d'homme-mort actif véritable — à trancher.

### F06 🟠 « RETAIN » annoncé mais absent (réglages de mise en service perdus)

- `PRG_MAIN.st` : le commentaire de `M1_SpeedStepTable` dit « **RETAIN, réglable sans recompiler** »,
  mais la table est déclarée en `VAR` simple → tout réglage en ligne (les `P<palier>R<relais>` un
  par un, les seuils) est **perdu au download / reset froid**. Pendant une mise en service, c'est
  la garantie de refaire les réglages plusieurs fois.
- Partie4 §4 spécifie les temporisations frein en **RETAIN (réglage mise en service)** ; le code les
  porte en `VAR_INPUT` avec défauts, non câblées, non persistantes, non exposées IHM.

**Correction** : `VAR RETAIN` (ou `PERSISTENT` selon la politique projet) pour la table et les
temporisations, et prévoir leur exposition IHM (page maintenance N2).

### F07 🟠 `Reset` non câblé → tout défaut fugitif est définitif

Aucun des trois `Reset` (Joystick, Safety_Winch, Winch) n'est actionnable : une micro-coupure CAN
pendant l'essai verrouille `SafeStop` **définitivement** (jusqu'à re-download). Documenté « à
câbler », mais l'impact au premier essai banc est fort : machine muette, sans explication ni moyen
d'acquitter. **Pour le banc** : câbler au minimum une variable debug d'acquittement (même principe
que `GVL_DEBUG`), clairement marquée. C'est aussi le prérequis pour révéler F02 avant le matériel
réel.

### F08 🟡 Double rampe en série + contradiction de spec sur la décélération

La dynamique réelle vue par le moteur = composition de **deux rampes** (Joystick 50/150 %/s puis
Winch 50/150/400 %/s). Deux endroits à régler pour un seul comportement = confusion de mise en
service garantie (« j'ai changé l'accel et rien ne bouge »). Par ailleurs Partie4 §7 dit *« arrêt
demandé : rampe de décélération normale (même profil que l'accélération) »* alors que les défauts
codés sont 150 ≠ 50 %/s.

**Recommandation** : déclarer la rampe de `FB_Winch` comme **la** rampe de mouvement (celle qui
fait foi), réduire celle du joystick à un rôle de lissage court (voire la neutraliser pour l'axe
treuil), et trancher la valeur de décélération normale dans Partie4/Partie9 (v+1).

### F09 🟡 Fenêtre « ni couple ni frein » à l'arrêt (~500 ms)

Quand `SpeedRamp` passe sous 0,1 % : sens + paliers retombent au même scan ; `FB_Brake` colle
`DelayMotorDecel` (500 ms) plus tard. Pendant cette fenêtre, la charge suspendue n'a **ni couple
moteur ni frein** → dérive/redescente libre possible. C'est le compromis voulu par Partie4 §4 (ne
jamais coller en plein mouvement), mais sur treuil chargé la valeur est sensible.

**Point de mise en service** : mesurer la dérive réelle et ajuster `DelayMotorDecel` au plus court,
ou coller sur **retour d'ouverture des contacteurs** (information déjà câblée) plutôt que sur un
temps fixe — le REX Partie9 §8 devrait intégrer ce point explicitement.

### F10 🟡 `FB_Safety` transverse : calculé, jamais consommé

`instSafety` est appelé chaque cycle mais **aucune** de ses sorties n'est lue ; le joystick est gaté
sur `GVL_DEBUG` au lieu de ses sorties ; `instDiagEthercat` est stubbé (`LocalEthercatOk` toujours
FALSE). L'architecture v2.5 ne prévoit d'ailleurs **pas** de bloc safety global (1 bloc par métier).
Code mort = fausse confiance (« la sécurité tourne » alors qu'elle n'agit sur rien). **Clarifier** :
soit le retirer, soit définir son rôle résiduel (agrégation AU ?) et le câbler réellement.

### F11 🟡 `FB_Joystick` : écarts au contrat Partie3

- Sur `Error` (calib hors plage), les sorties `AxisCmdX/Y` restent **actives** (Partie3 §9 étape 7 :
  sorties sûres si `Error`). Impact réel faible (l'ancien neutre reste valide), mais contractuel.
- `Busy := TRUE` en permanence quand actif — sémantique `Busy` dévoyée (devrait refléter un
  traitement en cours, pas « FB vivant »).
- L'aval (`PRG_MAIN` → `FB_Winch`) ne consulte **ni** `FB_Joystick.Error` **ni** `Done` : la
  consigne est consommée aveuglément. À raccorder quand `FB_Modes` arbitrera les sources.
- L'entrée `SafeStop` vestige est déjà tracée (Partie8 §6bis) — pour mémoire.

### F12 🟡 Nommage du POU principal : trois noms en circulation

`PLC_PRG_MAIN` (CLAUDE.md, Partie2, Partie8), `PRG_MAIN` (`CODE/PRG_MAIN.st`, Partie9 §7 étape 8),
`FB_MAIN_MACHINE` (message du commit `5d739c2`). Pour la maintenance (et pour retrouver le POU dans
CODESYS en dépannage), fixer **un** nom et aligner docs + code + arborescence projet.

### F13 🟡 Briques critiques non versionnées dans `CODE/`

`FB_Ramp`, `FB_CycleTime`, `FB_AxisScale`, `FB_Filter_PT1`, `FB_Safety`, `FB_DiagCanOpen`,
`FB_DiagEthercat`, `ST_DeviceDiag` n'existent que dans le `Device.export` (cet audit a dû les en
extraire pour valider F01/F02). La sécurité de la chaîne dépend directement de `FB_Ramp` — son
source doit être revu/versionné comme le reste. Au passage : le projet contient encore
`FB_Filter_PT1` (underscore) alors que Partie8 v1.1 acte `FB_FilterPT1` — à aligner lors du
prochain lot code.

---

## 🪣 3. Grappin / Godet (`FB_Bucket` — non codé, audit de spec)

Le godet = désynchro M2 (pas de moteur propre). La spec (Partie4 §6, Partie2) est saine sur :
mémoire RETAIN + contrôle de cohérence au boot, suspension automatique de `FB_WinchSync` pendant
la phase godet, offsets réglables N2. Points d'attention **avant** codage :

- **G01 🟡 Report de charge sur M1 pendant l'ouverture sous charge** (`DESCENDING_OPEN_DUMP`) :
  quand M2 se décale pour ouvrir, la charge passe majoritairement sur M1 — sans mesure de courant,
  aucune surveillance ne couvre ce transitoire (WinchSync est suspendu, légitimement). Vérifier le
  dimensionnement frein/moteur M1 pour ce cas, et prévoir au minimum une limite de vitesse dédiée
  à la phase godet dans la spec `FB_Bucket`.
- **G02 🟡 Resynchronisation après intervention N2** : après un pilotage unitaire N2 (godet dans un
  état quelconque), la procédure de requalification de l'état godet (recalage `IsOpen`,
  `LastPosM2_*`) n'est spécifiée que partiellement (Partie4 §6 « forcer Maint N1 + vitesse
  réduite »). À détailler : qui recale la mémoire RETAIN, sur quelle confirmation opérateur.
- **G03 🔵 IHM godet** : l'état « godet non sûr » est le message le plus lourd de conséquences du
  cycle (blocage). Prévoir dès la spec l'affichage de la **raison** (écart mesuré vs mémoire, seuil)
  et de l'**action attendue** — pas seulement « état non sûr ».

---

## ↔️ 4. Passe rapide : chariot (translation M3) et équipements annexes

### Chariot — `FB_Translation` (non codé, audit de spec Partie4 §5)

- **T01 🟡 Approche « au temps » fragile** : le ralentissement est déclenché après `ApproachTime`
  (temps estimé) — sur un pont dont la vitesse réelle varie (charge, variateur), un temps fixe
  produit soit un ralentissement trop tôt (cycle lent) soit trop tard (arrivée en GV sur le
  capteur). L'AC600 fournit une **vitesse estimée** : préférer une annonce par capteur de
  pré-position ou une intégration de vitesse. Au minimum, spécifier le **cas du capteur d'arrêt
  manqué** (overshoot) : fdc extrêmes → `SafeStop` translation, aujourd'hui non écrit.
- **T02 🟡 Spec variateur incomplète** : mot de commande/état AC600 (séquence d'enclenchement,
  acquittement défaut variateur, comportement STO/coupure AU côté variateur) non spécifiés — à
  écrire avant le codage de `FB_Translation` (c'est le gros du travail réel de ce FB).
- **T03 🟡 Hériter des correctifs treuil** : `FB_Translation` porte la même interface
  `StartStop`/`SafeStop` et sera probablement calqué sur `FB_Winch` → **corriger F01/F02/F03 avant
  duplication**, sinon les défauts se propagent au deuxième FB de mouvement.
- **T04 🟡 Frein translation incohérent entre docs** : Partie4 §5 conditionne « en position » au
  *« frein à manque de courant fermé mécaniquement »*, mais l'inventaire équipements (Partie1)
  ne liste **aucun frein sur M3**. À trancher (frein pont existant ? maintien par le variateur ?)
  et aligner les deux docs.

### Équipements annexes

- **E01 🟡 Surcourse haute = câble AU seul** : sans codeur (lot actuel), il n'existe **aucune** fin
  de course logicielle (assumé, Partie9 §4). La seule protection contre l'enroulement excessif est
  le câble mécanique AU « montée excessive ». **Avant le premier essai avec câble réel** : tester
  fonctionnellement ce câble (déclenchement + réarmement), le noter dans la checklist Partie9 §8.
- **E02 🟡 Priorités de tâches TBD** (Q7 de l'audit documentaire) : à figer avant matériel réel —
  l'ordre bus → MainTask conditionne la fraîcheur d'image process consommée par la sécurité.
- **E03 🟡 Watchdog tâche 200 ms** : décision actée (fonction système, pas de FB) mais la
  **configuration effective** dans le projet CODESYS n'est pas vérifiable dans les exports fournis —
  à vérifier/documenter (copie d'écran de la config tâche dans la note d'application).
- **E04 🟡 Capteurs fdc haut/bas et positions** (Partie1) : listés à l'inventaire mais aucune spec
  de consommation logicielle (qui les lit ? `FB_Safety_Winch` ? conditionnés par `FB_Input_Digital` ?).
  À intégrer au lot « FB_Safety_Winch complet » — ce sont les seules protections de course
  indépendantes du codeur.

---

## 🖥️ 5. Ergonomie utilisateur & maintenance (transverse)

- **F14 🔵 Pas d'état « repos » des modes** : `E_Mode` démarre à `MANUEL` (=0). Au boot, dès que les
  `Enable` seront réels, la machine est *pilotable immédiatement*. Sur machine lourde, prévoir soit
  une valeur `OFF`/`INHIBIT` explicite en tête d'énum, soit l'exigence `FB_Modes` d'une **sélection
  volontaire de mode après chaque boot** (et après chaque AU).
- **F15 🔵 Catalogue des défauts absent** : les significations des bits `ErrorId` ne vivent que dans
  les commentaires du code. Pour l'intégrateur IHM et le dépanneur, créer une annexe DOC « table
  des défauts » par FB : *bit → libellé court IHM → cause probable → remède → acquittable ?*.
  De même, la struct `Hmi : ST_<Objet>Hmi` (Partie3 §8) n'existe dans aucun FB — à introduire au
  moment du lot IHM, mais la **réserver dès maintenant** dans les nouveaux FB évite un refactor.
- **F16 🔵 Cartographie des gestes joystick non figée** : Y = treuils (ce lot). X = translation ?
  godet ? Rien ne le fixe. À décider et documenter : affectation des axes par mode, comportement en
  **diagonale** (exclusivité d'axe recommandée sur levage : un seul mouvement à la fois hors
  semi-auto), et convention de sens (tirer = monter, standard grue/levage — le REX Partie9 §8 pose
  déjà la question, la trancher avant l'habitude prise).
- **🔵 Signalisation `STOPPING`/`SafeStop`** : l'opérateur doit distinguer à l'IHM « je décélère
  parce que j'ai relâché » (normal) de « la machine a décidé de s'arrêter » (`SafeStop`). Les
  informations existent (`State`, `SafeStop`) — prévoir le mapping couleur/message dès la première
  page IHM.

---

## ✅ 6. Points forts relevés (à conserver)

- Frein à **manque de courant** avec séquence temporisée dans les deux sens (relâche après
  magnétisation, collage après décélération) — conforme état de l'art levage.
- **Sortie sûre sur défaut** systématique (`FB_Winch` §10, `FB_Brake` §6), frein collé par défaut.
- **Reset sur front + cause disparue** appliqué partout ; `SafeStop` verrouillé jusqu'à
  acquittement (pas de redémarrage automatique).
- Interlock de sens (jamais Fwd+Rev), double vérification commande/retour avec timeout sur
  **tous** les contacteurs (sens + frein).
- Table de paliers **en données** (`P<palier>R<relais>` réglables un à un) + `HYSTERESIS` lib Util —
  excellente ergonomie de mise en service (une fois F06 corrigé).
- Ordre de scan **diag → sécurité → métier** respecté dans `PRG_MAIN`.
- Stubs debug **clairement marqués** avec leur remplacement cible ; documentation traçée,
  versionnée, avec REX par lot — rare et précieux sur ce type de projet.

---

## 🎯 7. Recommandations priorisées

### P0 — avant tout essai avec moteur réel (même banc supervisé)
1. **F01** — inversion de sens : forcer la décélération à 0 sur désaccord de sens.
2. **F02** — geler la rampe sur `Error` + retour joystick neutre exigé après acquittement.
3. **F07** — câbler un `Reset` (au moins debug) pour le banc.
4. **F04/E01** — acter dans la checklist d'essai : AU physique testé (bouton **et** câble montée
   excessive) et à portée de main ; c'est la seule parade contacteur collé / surcourse de ce lot.

### P1 — avant câblage matériel réel / duplication M2
5. **F03** — cohérence des diagnostics pendant défaut (éviter la cascade de défauts secondaires).
6. **F06** — RETAIN réel sur table paliers + temporisations frein.
7. **F05** — détection trame joystick figée (ou homme-mort actif via bouton).
8. **F09** — stratégie de collage frein (temps vs retour contacteur) à valider en mise en service.
9. **F10, F13** — purger/câbler `FB_Safety` transverse ; versionner les briques manquantes dans `CODE/`.
10. **F08** — trancher la rampe qui fait foi + corriger Partie4 §7 ou les défauts codés.

### P2 — avant N2 / semi-auto / translation
11. **T01–T04** — compléter la spec translation (approche, AC600, fdc, frein M3) **après** report
    des correctifs F01–F03 dans le futur `FB_Translation`.
12. **G01–G03** — compléter la spec `FB_Bucket` (report de charge M1, requalification N2, IHM).
13. **F14, F15, F16** — mode repos au boot, catalogue des défauts, cartographie des gestes.
14. **F12, E02, E03, E04** — nom unique du POU principal, priorités de tâches, preuve de config
    watchdog, spec de consommation des fdc.

---

## 📚 Documents liés
- `AUDIT_Coherence_Documentaire_v1.0.md` — audit précédent (cohérence docs, décisions D1–D22).
- Partie 3 v1.2 (contrat FB), Partie 4 v1.1 (frein/rampes/cycle), Partie 9 v1.0 (lot Winch M1).
