# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : historique factuel des séances banc/terrain : ce qui a été fait, mesuré, constaté et décidé.
> 📌 **Source des actions à réaliser** : `DOC/PLAN_TASK_v1.0.md` §3 reste le registre maître des reliquats (`Txx`).
> 🚫 Ce registre ne remplace ni les checklists, ni la recette, ni une analyse de risque.

---

## 1. Règles d'utilisation

| Élément | Où le tracer |
|---|---|
| Test prévu et verdict Pass/Fail | Checklist métier ou `PLAN_TASK` §4 Recette |
| Mesure, anomalie, réglage, observation terrain | Ce registre |
| Code, câblage, paramètre ou décision à faire plus tard | Nouvelle ligne `Txx` dans `PLAN_TASK` §3, puis référence ici |
| Évolution code/DOC significative | `VERSION_HISTORY.md` |

**Une entrée = une séance ou un fait vérifiable.** Ne jamais effacer une entrée : ajouter une correction datée si nécessaire.

### Statuts

| Statut | Sens |
|---|---|
| 🟢 Validé | Mesure conforme, preuve disponible |
| 🟡 À surveiller | Fonctionne, seuil/comportement à confirmer |
| 🟠 Action ouverte | À réaliser, référencée par un `Txx` |
| 🔴 Bloquant | Interdit le mouvement ou la suite concernée |
| ⚪ Non testé | Pas encore exécuté |

---

## 2. Entrées de séance

### MES-010 — Mesure offset M1/M2 fermeture benne

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain |
| Périmètre | Benne (M2), désynchronisation offset ouverture/fermeture (`FB_Bucket.ActiveOffsetM`) |
| Statut | ⚪ Non testé (mesure brute, pas encore analysée) |
| Constat | Offset M1/M2 mesuré pour la fermeture benne : **≈ 15 m**. |
| Décision / Action | À comparer avec la valeur configurée de `ActiveOffsetM` (`PRG_06_WinchControl.instBucket`) et avec la doc `AF_Partie-12_Fonction_Benne_v1.4.md`. Pas encore déterminé si conforme au réglage attendu. |
| Action différée | Nouveau `Txx` à créer dans `PLAN_TASK_v1.0.md` si écart jugé anormal après analyse. |

---

### MES-009 — Mesure position haute capteur vs arrêt réel treuils

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain |
| Périmètre | Capteur position haute commun M1/M2 (TopPositionSensor), arrêt haut treuils |
| Statut | ⚪ Non testé (mesure brute, pas encore analysée) |
| Constat | Déclenchement physique du capteur de position haute mesuré à **8 m**. Arrêt réel du mouvement (rampe/mécanique) observé vers **≈ 7,5 m** — soit une marge d'environ 0,5 m avant déclenchement capteur. |
| Décision / Action | À comparer avec les cibles de homing configurées (`HomingTargetM1_M`/`HomingTargetM2_M`) et la distance de freinage attendue à la vitesse d'approche utilisée. Pas encore déterminé si cet écart de 0,5 m est normal (marge de sécurité voulue) ou à ajuster. |
| Action différée | Nouveau `Txx` à créer dans `PLAN_TASK_v1.0.md` si l'écart est jugé anormal après analyse. |

---

### MES-008 — Analyse comparative d'arrêt M1 vs M2 : Configuration d'un enregistrement Trace CODESYS

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain / Diagnostics d'arrêt treuils |
| Version CODE/DOC | Main branch — CODESYS Trace / `PRG_06_WinchControl.st`, `FB_Winch.st`, `FB_Brake.st` |
| Périmètre | Treuils M1/M2, Commandes relais, retours freins, positions codeurs |
| Statut | 🟠 Action ouverte (T79 à réaliser) |
| Constat / Demande | L'opérateur constate une différence de comportement à l'arrêt entre les deux treuils M1 (Retenue) et M2 (Benne). Il est nécessaire de lever l'ambiguïté entre une **dissymétrie de commande automate** et un **retard mécanique/hydraulique propre au frein d'un des treuils**. |
| Solution / Trace à configurer | Préparer une configuration d'outil **Trace CODESYS** (ou variables d'échantillonnage 10ms) enregistrant de façon synchrone pour M1 et M2 :<br>1. **Commandes PLC** : `RelayFwd`, `RelayRev`, `Contactor1..4`, `BrakeCmd` (sorties réelles).<br>2. **Retours physiques (Feedbacks)** : `BrakeFeedback` (contact de confirmation frein), `FwdRevSpeedFeedbackOff` (retombée contacteurs).<br>3. **Dynamique mécanique** : `SpeedRamp.Current` (rampe consigne), `CablePosM` (position mesurée par codeur), `MeasuredSpeedMps` (vitesse réelle).<br>4. **Écart relatif** : `DeltaPosM` et `SignedDeltaPosM` (`FB_WinchSync`). |
| Décision | Tâche `T79` créée pour préparer le modèle de Trace CODESYS de diagnostic d'arrêt différencié M1 vs M2. |

---

### MES-007 — Alignement dynamique des rampes d'accélération Treuils M1/M2 en mode couplé (Both)

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain / Essais treuils |
| Version CODE/DOC | Main branch — `PRG_06_WinchControl.st`, `FB_Winch.st`, `GVL_PERSISTENT.st` |
| Périmètre | Treuils M1/M2, Rampes d'accélération `CfgRampAccelRate` |
| Statut | 🟠 Action ouverte (T78 à réaliser) |
| Constat / Demande | 1. **Réduction rampe d'accélération** : Passer la valeur nominale de rampe d'accélération de 50%/s à **10%/s** pour adoucir le démarrage des treuils.<br>2. **Synchronisation des rampes en couplage** : En mode couplé (Boutons IHM `Both` ou couplage automatique M1+M2), si les réglages de rampe de M1 et M2 sont différents, les deux treuils accélèrent à des vitesses différentes, créant une désynchronisation mécanique.<br>3. **Besoin** : Mettre en place une égalisation automatique dynamique des rampes d'accélération (`CfgRampAccelRate`) uniquement lorsque le mode `Both` / couplé est actif, tout en conservant leurs rampes réglables individuelles si chaque treuil est piloté séparément. |
| Décision / Action | Consigné pour implémentation au code. Tâche `T78` créée pour la synchronisation dynamique des rampes M1/M2 en pilotage couplé. |

---

### MES-006 — Compromis de freinage Treuils M1/M2 : Sensation de glissement vs Choc mécanique sur décélération

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain / Essais treuils |
| Version CODE/DOC | Main branch — `FB_Winch.st`, `FB_Brake.st`, `GVL_PERSISTENT.st` |
| Périmètre | Treuils M1/M2 (Retenue/Benne), pilotage freins et rampes de décélération |
| Statut | 🟡 À surveiller / Réglage terrain à affiner |
| Constat | Constat d'une sensation de "glissement" de la charge lorsque l'opérateur ramène le joystick au neutre en petite vitesse (palier minimum). |
| Analyse technique | 1. **Rampe de décélération (`CfgRampDecelNormalRate`)** : Le variateur/automate applique une rampe progressive pour éviter les chocs. L'automate maintient la commande tant que `SpeedRamp.Current > 0.1%`.<br>2. **Risque d'un arrêt trop court** : Réduire trop fortement la rampe pour couper net crée un risque d'à-coups mécaniques violents sur la flèche, les câbles et les réducteurs lors du relâchement du joystick.<br>3. **Levier recommandé** : Conserver la souplesse de la rampe de décélération tout en optimisant le temps de retombée du frein (`DelayMotorDecel` dans `FB_Brake.st`) dès que la vitesse s'annule pour verrouiller la charge sans choc ni glissade. |
| Décision | **Pas de modification des rampes d'urgence/normales au code actuellement** (maintien de la sécurité mécanique). L'ajustement fin du délai de fermeture frein sera effectué en présence du dragueur lors des essais en charge réels. |

---

### MES-005 — Défaut de conception architecture Diagnostics : Prétraitement logique externe vs Encapsulation POO

| Champ | Valeur |
|---|---|
| Date | 2026-07-24 |
| Lieu / environnement | Mise en service terrain / Analyse d'architecture |
| Version CODE/DOC | Main branch — `PRG_01_Diagnostics.st`, `FB_DiagCanOpen.st`, `FB_DiagEthercat.st` |
| Périmètre | Diagnostics bus terrain (CANopen, EtherCAT), `PRG_01_Diagnostics` |
| Statut | 🟠 Action ouverte (Refactoring nécessaire) |
| Constat | Constat d'une alarme injustifiée `CANbusOnline = FALSE` sur le terrain alors que le bus CANopen et le joystick sont physiquement fonctionnels et en ligne. L'analyse révèle un vice de conception en contradiction avec les principes POO / encapsulation : le programme appelant `PRG_01_Diagnostics` effectue un pré-calcul logique complexe directement dans les paramètres d'entrée des FB (`(GetBusState() = 1) OR (SimulationModeActive AND NOT BusIsReal)...`). |
| Analyse technique | 1. **Violation POO / Encapsulation** : La logique métier de décision et de filtrage (gestion de la simulation, des bypass et des transitoires d'état) est sortie des Function Blocks et dupliquée en amont dans `PRG_01`.<br>2. **Aveuglement du FB** : `FB_DiagCanOpen` et `FB_DiagEthercat` ne reçoivent que des booléens prétraités (`TRUE`/`FALSE`). Ils sont incapables de distinguer un état transitoire légitime (`BUS_WARNING` / `PREOPERATIONAL` au boot) d'une vraie coupure réseau, provoquant le verrouillage d'alarmes intempestives.<br>3. **Fragilité terrain** : Toute modification d'un drapeau de simulation ou de bypass à l'extérieur fausse le calcul d'entrée du FB sans que le FB ne puisse contrôler la cohérence des vrais statuts système. |
| Décision / Solution cible | Confier le refactoring à un subagent dédié. La solution cible doit transmettre **les types/statuts bruts non interprétés** aux FB (`CANbus.GetBusState()`, `JOY1.GetDeviceState()`, `AC600.GetDeviceState()`, `SimulationModeActive`, `BypassGlobal`), et laisser chaque FB de diagnostic porter sa propre machine d'état et sa propre encapsulation POO. |
| Action différée | Nouvelle tâche `T77` à créer dans `PLAN_TASK_v1.0.md` pour le refactoring POO des FB de diagnostic. |

---

### MES-004 — Neutralisation & Purge des retours contacteurs/freins par le Bypass Global (M1, M2, M3)

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Essais terrain |
| Version CODE/DOC | Main branch — `PRG_06_WinchControl.st`, `PRG_07_TranslationControl.st`, `DOC/AUDITS/Bypass/AUDIT_BypassGlobal_Homogenization_v1.0.md` |
| Périmètre | Treuils M1/M2, Translation M3, `FB_Winch`, `FB_Translation`, `FB_Brake` |
| Statut | 🟢 Validé / Appliqué |
| Constat | Lors de l'enclenchement d'un Bypass Global d'axe (`Bypass.Global`), les sous-blocs `FB_Brake` et `FB_Winch` conservaient leurs erreurs `StuckOpen` / `StuckClosed` mémorisées avant l'activation du bypass, car leur entrée `BypassContactorCheck` n'était reliée qu'à la simulation. Le mouvement restait bloqué à 0 malgré le bypass. |
| Solution appliquée | Modification de l'alimentation de `BypassContactorCheck` sur les instances `instWinchM1`, `instWinchM2` (dans `PRG_06_WinchControl.st`) et `instTranslationM3` (dans `PRG_07_TranslationControl.st`) en y incluant la condition `OR GVL_IHM.Mx.Bypass.Global`. Désormais, le Bypass Global purge inconditionnellement et instantanément les erreurs contacteurs et freins résiduelles. |
| Observation sécurité | Constat d'un décalage de séquence sur M2 : alimenter les contacteurs de sens avant que le frein soit piloté/ouvert fait forcer/patiner le moteur sous frein serré. Nécessité d'ajouter un interverrouillage interdisant l'alimentation des contacteurs si le frein n'est pas piloté. |
| Preuves attendues | Succès de génération du bundle XML (`PASS`), validation sur terrain par déblocage immédiat de l'axe M3 et M2 lors de l'activation du Bypass. |

---

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Essais treuils |
| Version CODE/DOC | Version utilisée pendant la séance à confirmer |
| Périmètre | Winch M1/M2 |
| Statut | 🟠 Réglage temporaire d'essai |
| Réglage | Plafond de palier vitesse limité à `0` pour les essais treuils. |
| But | Réduire la vitesse/énergie pendant les premiers essais. |
| Vigilance | `0` n'est pas validé comme valeur d'exploitation. Vérifier le comportement réel du décodeur de paliers et les contacteurs effectivement commandés. |
| Action différée | `T64` : tracer le résultat, puis définir ou restaurer la valeur d'exploitation avant fonctionnement normal. |
| Preuves attendues | Version CODESYS, valeur IHM/PERSISTENT, paliers M1/M2 observés, états contacteurs, verdict opérateur. |

---

### MES-002 — Bypass ciblés et homing à 0 m

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Développement et préparation mise en service |
| Version CODE/DOC | Commit `96ef589` |
| Périmètre | Winch M1/M2, Translation M3, diagnostic réseau et codeurs |
| Statut | 🟡 À valider sur banc/terrain |
| Réalisé | Ajout de bypass globaux et ciblés par surveillance : Winch, Translation M3, synchronisme, benne et réseau. Persistance regroupée dans `GVL_BypassRetain`. |
| Homing | Cible d'homing unitaire M1 et M2 réglable, initialisée à `0,0 m`. Le homing à zéro ignore le capteur haut pour prendre la position courante comme référence. |
| Vigilance | Les bypass facilitent la mise en service mais masquent des protections. Vérifier leur état avant tout mouvement et les désactiver dès que le matériel concerné est validé. |
| À valider | Comportement de chaque bypass, persistance après redémarrage, homing M1/M2 à `0,0 m`, cohérence de la position et réarmement sûr. |
| Références | `96ef589`, `CODE/MAIN/GVL_BypassRetain.st`, `FB_Encoder_Homing.st`, `AF_Partie-13_Fonction_Simulation_v1.3.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md` |

---

### MES-001 — Registre initial

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Documentation projet, avant prochaine séance banc ou terrain |
| Version CODE/DOC | À renseigner avant essai (`VERSION_HISTORY.md`) |
| Périmètre | Création du registre de suivi MES/REX |
| Statut | ⚪ Non testé |
| Constat | Les checklists Joystick et Translation existent. Les reliquats sont centralisés dans `PLAN_TASK`, mais aucune fiche courte ne consigne encore les résultats réels de chaque séance. |
| Décision | Utiliser ce registre dès le prochain essai. Créer ou mettre à jour un `Txx` pour tout point qui impose une action ultérieure. |
| Références | `PLAN_TASK` §3, `PLAN_TASK` §4 |

---

## 3. Modèle à dupliquer

```md
### MES-XXX — Titre court

| Champ | Valeur |
|---|---|
| Date / heure | YYYY-MM-DD HH:MM |
| Lieu / environnement | Simulation CODESYS / banc / terrain |
| Intervenants | Initiales et rôle |
| Version CODE/DOC | Tag/version export CODESYS + version checklist |
| Périmètre | Fonction, axe ou chaîne testée |
| Statut | 🟢 / 🟡 / 🟠 / 🔴 / ⚪ |
| Conditions sûres | Mode, zone dégagée, charge, simulation, autorisations |
| Essai réalisé | Action concrète et ordre d'exécution |
| Mesures / preuves | Valeurs, captures, photos, log, signature |
| Constat | Résultat observé, sans interprétation ambiguë |
| Décision | Accepté / réglage / analyse / arrêt essai |
| Action différée | `Txx` existant ou nouveau `Txx` créé dans PLAN_TASK §3 |
| Références | Checklist, AF Partie, code, schéma électrique |
```

---

## 4. Clôture d'une action

Quand une action `Txx` est réalisée :

1. Ajouter une entrée MES avec la preuve de validation.
2. Mettre le statut `✅` et la référence MES dans `PLAN_TASK` §3.
3. Ajouter un jalon dans `VERSION_HISTORY.md` si code ou documentation significative ont évolué.

⚠️ Une action sécurité reste ouverte tant que la preuve terrain et le réarmement sûr ne sont pas validés.
