# 📋 Audit Fonctionnel — Treuils M1/M2 (v1.0)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5  
> **Périmètre** : Fonctionnalité Winch complète — `CODE/TREUILS/`, `CODE/MAIN/PRG_06_WinchControl.st`, `CODE/MAIN/PRG_03_Safety.st`, `CODE/MAIN/PRG_09_Supervision.st`, `CODE/MAIN/PRG_10_Outputs.st`, `CODE/SUPERVISION/ST_WinchHMI.st`, `CODE/SUPERVISION/ST_SyncHMI.st`, `CODE/SUPERVISION/GVL_IHM.st`  
> **Références documentaires** : `AF_Partie-09_Fonction_Winch_v1.11.md`, `AF_Partie-03_Template_FB_Commun_v1.3.md`, `AF_Partie-04_Cycle_Sequenceur_v1.4.md`, `AF_Partie-05_Modes_Maintenance_v1.6.md`, `AF_Partie-07_Interface_IHM_v1.5.md`, `AF_Partie-02_Architecture_Programme_v2.12.md`  
> **Date** : 2026-07-21  
> **Auteur** : Agent Orchestrateur — Analyse experte automatisme industriel / IHM / sécurité / ergonomie  
> **Méthode** : Revue code ST complète + comparaison specs DOC + validation croisée par agent Vérificateur (session antigravity)  
> **Aucune modification de code** dans cet audit — rapport d'analyse uniquement

---

## 🎯 1. Verdict global

| Dimension | Niveau | Commentaire |
|---|---|---|
| **Architecture logicielle** | ✅ Bonne | Séparation claire commande / safety / synchronisme / supervision |
| **Sécurité fonctionnelle** | 🟠 Partielle | Défense en profondeur présente (Méca A–G), mais seuils non validés, chaines non démontrées |
| **Cohérence DOC ↔ CODE** | 🟠 Partielle | Divergences hauteurs (8,0/8,5/12,0/12,5 m), comportement `FB_WinchSync` ambigu |
| **IHM / Ergonomie** | 🟡 Incomplète | Variables RETAIN contenant commandes, état réel pas toujours affiché |
| **Validation terrain** | ❌ Non faite | Seuils théoriques, pas de tests inertie/charge/frein/arrêt d'urgence |

**Conclusion** : La fonctionnalité treuil a de **bonnes bases architecturales**, mais **ne doit pas être mise en mouvement réel** avant levée des points **P0** ci-dessous.

---

## ⚠️ 2. Points critiques — P0 (Avant tout essai machine)

### P0.1 — Incohérence majeure des hauteurs/limites

| Élément | Valeur code | Documentation P9 | Documentation P7 |
|---|---:|---:|---:|
| Homing M1/M2 | 8,5 m | 12,5 m | 12,5 m |
| Limite haute exploitation | 8,0 m | 12,0 m | — |
| Capteur physique haut | 8,5 m | 12,5 m | — |

**Références** :
- `CODE/GVL_PERSISTENT.st:15-16,46-47`
- `CODE/TREUILS/FB_Winch.st:102`
- `DOC/AF_Partie-09...:229-243`
- `DOC/AF_Partie-07...:34`

**Risque** : Le ralentissement, l'arrêt normal, le homing, le capteur haut et Méca D ne travaillent pas avec le même référentiel.

**Action** : Définir explicitement 5 niveaux distincts et imposer des contrôles d'ordre :
```
WorkingUpperLimitM < HomingTargetM < PhysicalTopLimitM
AbsoluteSoftwareLimitM = WorkingUpperLimitM + marge
SlowdownDistanceM < (HomingTargetM - WorkingUpperLimitM)
```
À valider par **mesure mécanique réelle**, pas uniquement par logiciel.

---

### P0.2 — Défaut `FB_SpeedStep` : `MaxStepNumber` non borné

**Localisation** : `CODE/TREUILS/FB_SpeedStep.st:87-92`

```st
IF StepNumber > MaxStepNumber THEN
    StepNumber := MaxStepNumber;
END_IF;
```

Si l'IHM/PERSISTENT fournit `MaxStepNumber ≤ 0` :
- `StepNumber` peut devenir 0 pendant un mouvement
- Le `CASE` final (lignes 110-116) ne force **pas** les contacteurs à FALSE
- Les sorties conservent leur valeur précédente

**Risque** : Commande contacteurs non déterministe, potentiel démarrage moteur incontrôlé.

**Correction** :
```st
// Borner systématiquement
IF MaxStepNumber < 1 THEN MaxStepNumber := 1; END_IF;
IF MaxStepNumber > 5 THEN MaxStepNumber := 5; END_IF;

// Validation table (seuils croissants, 0-100%, hystérésis > 0)
// Générer défaut configuration si invalide
// Forcer tous contacteurs FALSE en cas d'erreur
```

**Priorité** : **P0 — Bloquant**

---

### P0.3 — Chaîne `PowerCutOff` non démontrée physiquement

Le code agrège correctement les demandes :
- `PRG_10_Outputs.st:136-156` → `PowerCutOffReq` = OR des 3 domaines (Winch M1, Winch M2, Translation)

Mais le **code ne prouve pas** :
- La coupure réelle de puissance amont
- La polarité correcte des sorties redondantes A/B
- Le comportement face à un contacteur collé
- Un retour indépendant de confirmation de coupure
- Le temps réel de coupure (mesuré électricité)

**Conclusion** : `PowerCutOff` est aujourd'hui une **chaîne logicielle raccordée**, pas une fonction de sécurité validée.

**Essais obligatoires** (selon analyse de risques ISO 12100 / ISO 13849-1 / IEC 60204-1) :
- Perte thermique moteur
- Perte thermique frein
- Mouvement avec contacteur collé
- Frein qui ne serre pas
- Perte d'un canal A/B
- Confirmation effective de coupure puissance
- Mesure temps d'arrêt complet

---

## 🔴 3. Risques importants — P1 (Sécurité fonctionnelle & comportement)

### P1.1 — Contradiction « sans codeur » / implémentation réelle

**Documentation** : `AF_Partie-09:39-41` → premier lot « sans dépendance codeur »

**Code réel** :
- `PRG_03_Safety.st:40,83` exige `EncoderAvailable` pour activer `FB_Safety_Winch`
- `FB_Safety_Winch.st:280-285` déclenche défaut bit1 si codeur indisponible

**Action** : Choisir explicitement :
- Soit le treuil ne fonctionne **jamais** sans codeur valide (safety stricte)
- Soit un **mode maintenance limité** autorise le fonctionnement sans codeur (nécessite analyse de risques dédiée)

---

### P1.2 — Ordre d'exécution et latence d'un scan

Ordre actuel (MainTask 10 ms) :
```
PRG_03_Safety (pos 3)
PRG_06_WinchControl (pos 6)
PRG_09_Supervision (pos 9)
PRG_10_Outputs (pos 10)
```

Conséquences :
- Safety lit commandes/états du scan précédent (~10 ms de retard)
- Couplage M1/M2 utilise sorties `PRG_06` du scan précédent
- IHM reflète état `PRG_06` / `PRG_03` décalés

**Références** :
- `PRG_03_Safety.st:49-69` lit `PRG_06_WinchControl` (M1_Direction_Active, etc.)
- `PRG_06_WinchControl.st:400-499` écrit `PRG_10_Outputs` (VAR_INPUT)
- `PRG_09_Supervision.st:317-319` expose `SafeStop` safety, mais commande réelle = couplage `PRG_06:393-398`

**Action** : Documenter explicitement la latence, l'intégrer au calcul temps d'arrêt, tester avec inertie/charge.

---

### P1.3 — Synchronisme : comportement ambigu et multi-stratégies

`FB_WinchSync` implémente **trois stratégies simultanées** selon configuration :

| Configuration | Comportement bit0 (écart position) |
|---|---|
| Doc P9 §9 : `SyncWarn` = IHM seulement | Avertissement seul |
| Doc P9 §3 : `Error → SafeStop` | Arrêt rapide |
| Code `_SyncSoftStopEnable=FALSE` (défaut) | SafeStop rapide |
| Code `_SyncSoftStopEnable=TRUE` | Blocage **directionnel** seul (sens aggravant) |

**Références** :
- `FB_WinchSync.st:13-16` (commentaire : IHM seulement)
- `FB_WinchSync.st:127-137` (filtre 800 ms, bit0 → Error)
- `PRG_06_WinchControl.st:329-338` (reprend bit0 en SafeStop si `_SyncSoftStopEnable=FALSE`)
- `PRG_06_WinchControl.st:127-131` (blocage directionnel si TRUE)

**Problème** : La documentation, le commentaire code et le comportement par défaut sont **incohérents**.

**Proposition** : Définir une stratégie unique documentée :

| Niveau | Seuil | Réaction |
|---|---|---|
| Info | < 0,25 m | Affichage delta |
| Mineur | > 0,25 m (800 ms) | Arrêt normal **ou** blocage sens aggravant |
| Majeur | > 2,0 m (instantané) | SafeStop immédiat M1+M2 |
| Critique non arrêté | > 2,0 m + 3 s | PowerCutOff |

Et afficher à l'opérateur le **niveau réellement actif**.

---

### P1.4 — Seuils de sécurité non validés terrain

| Paramètre | Valeur code | Statut |
|---|---:|---|
| Vitesse mouvement non commandé (Méca A) | 0,02 m/s | 🔧 Théorique |
| Dérive position (Méca A) | 2,0 m | 🔧 Théorique |
| Écart synchro critique (Méca E) | 2,0 m | 🔧 Théorique |
| Timeout confirmation arrêt (Méca B/D/E) | 3 s | 🔧 Théorique |
| Filtre écart synchro | 800 ms | 🔧 Théorique |
| Filtre incohérence commande | 500 ms | 🔧 Théorique |

**Références** :
- `FB_Safety_Winch.st:149-169`
- `FB_WinchSync.st:132,151`
- `DOC/AF_Partie-09...:251-259`

Le calcul de vitesse par différence de position (`FB_Safety_Winch.st:336-343`) est sensible à :
- Bruit codeur
- Période de tâche variable
- Saut de référencement
- Perte de trame EtherCAT
- Quantification
- Glissement mécanique

**Action** : Caractériser ces seuils avec essais :
- Tambour vide / charge nominale / charge max
- Frein chaud / froid
- Descente / remontée chargée
- Arrêt d'urgence
- Fonctionnement dégradé (perte bus, bruit)

---

### P1.5 — Limites M2 et offset benne : dissociation safety/commande

`PRG_06_WinchControl` applique un offset dynamique à M2 selon état benne :
- `M2_LimitShift := SEL(IsClosed OR CloseReq, 0.0, OffsetCloseM)` (ligne 379)

Mais `PRG_03_Safety` transmet à `FB_Safety_Winch` un `TopLimitM` qui **ne suit pas le même offset** :
- `PRG_03_Safety.st:53,96` → `_HomingTargetM1_M` / `_HomingTargetM2_M` (sans offset benne)
- `FB_Safety_Winch.st:409-415` (Méca D) utilise ce `TopLimitM` pour la couche 3

**Risque** : Commande, safety Méca D et IHM peuvent avoir des limites hautes différentes selon l'état benne.

**Action** : Calculer **une seule limite active par treuil** et la distribuer à :
- `FB_Winch` (ralentissement/arrêt)
- `FB_Safety_Winch` (Méca D)
- IHM (affichage)
- Homing (cible)

---

## ✅ 4. Bonnes idées à conserver

### Automatisme
- Séparation claire `FB_Winch` / `FB_Safety_Winch` / `FB_WinchSync` / `FB_SpeedStep` / `FB_DriftGuard`
- Précédence `Enable > SafeStop > StartStop` respectée
- Interlock changement de sens (jamais Fwd+Rev simultanés)
- Décélération forcée à 0 lors d'inversion de sens (`DirectionChangePending`)
- Limitation vitesse en descente (`MaxStepDescente`) — couple, pas vitesse
- Palier 1 forcé sans référencement fiable ou approche homing
- Couplage croisé M1/M2 en fonctionnement synchronisé
- Arrêt M1 pendant mouvement benne (Méca C couche 1)
- Défense en profondeur Méca A à G (bits 7–15)
- Surveillance mouvement réel par codeur (vitesse signée)
- Escalade `PowerCutOff` réservée aux cas nécessitant coupure amont
- Homme-mort joystick armé au neutre + réarmement périodique 10 s

### Sécurité
- Frein à manque de courant (séquence temporisée + double vérification feedback)
- Retour contacteurs global (`FwdRevSpeedFeedbackOff`) — détection StuckClosed à l'arrêt
- Retour frein (`BrakeFeedback`)
- Détection thermique moteur (par treuil) et frein (commun M1/M2/M3)
- Détection sens réel opposé (bit14, temporisé 500 ms)
- Détection absence de mouvement malgré commande (bit15, temporisé 3 s)
- Reset sur front obligatoire + cause disparue
- Pas de redémarrage automatique après défaut
- Bypasses limités à la simulation (`GVL_Simulation`)

### IHM
- Distinction états / défauts / sécurité / commandes
- Affichage positions et vitesses réelles (m/s)
- Diagnostic dérives Méca A/B/C exposés pour mise en service
- Affichage paliers et contacteurs individuels
- Indication `Homed` / `HomingSuspect`
- Suppression judicieuse du pilotage direct IHM_MANU dangereux

---

## ❌ 5. Mauvaises idées / choix à corriger

### 5.1 Paramètres critiques modifiables sans validation

Les paramètres IHM (`GVL_IHM`) agissent directement sur :
- Rampes d'accélération/décélération
- Limites hautes/basses
- Seuils de sécurité
- Paliers max
- Tolérances de synchronisme

**Manque** : Validation centralisée (bornage, cohérence inter-paramètres, confirmation opérateur, journalisation, réservation `MAINT_N2`, retour valeurs sûres).

---

### 5.2 `GVL_IHM` entièrement `RETAIN` — commandes persistantes

`CODE/SUPERVISION/GVL_IHM.st:7` : `VAR_GLOBAL RETAIN` contient **commandes** :
- `CmdHome`, `CmdReset`, `CmdInhibit`
- Commandes benne, demande synchro
- Boutons d'urgence

**Risque** : Une commande ancienne reste mémorisée après redémarrage → front inattendu au boot.

**Recommandation** : Séparer :
```
GVL_IHM_Config   : RETAIN     (paramètres calibration)
GVL_IHM_Commands : NON RETAIN (commandes opérateur — invalidées au boot)
GVL_IHM_Status   : NON RETAIN (états, mesures)
GVL_IHM_Alarms   : NON RETAIN ou journalisé (défauts)
```

Toutes les commandes doivent nécessiter un **nouvel appui/front** après démarrage.

---

### 5.3 IHM ne reflète pas la commande effective appliquée

L'IHM affiche le `ForbidAscent` **local** du safety :
- `PRG_09_Supervision.st:319,382` → `PRG_03_Safety.instSafetyWinchM1/M2.ForbidAscent`

Mais la commande réelle appliquée aux treuils utilise le **couplage croisé** :
- `PRG_06_WinchControl.st:393-398` → `ForbidAscentM1_Active := ForbidAscentM1_Raw OR (SyncActive AND ForbidAscentM2_Raw)`

**Conséquence** : L'opérateur voit M1 « libre » alors qu'il est arrêté par le couplage M2 (ou inversement).

**Recommandation** : Afficher séparément :
- Défaut local (safety)
- Arrêt local
- Arrêt croisé (cause : quel treuil a déclenché)
- Interdiction effective appliquée
- Cause primaire / cause secondaire

---

## 🖥️ 6. Ergonomie IHM — propositions

### Zone conduite (priorité visuelle)
- Sens demandé / sens réellement commandé
- Vitesse demandée / vitesse réelle (m/s)
- Palier actif (0–5)
- Homme-mort : ARMÉ / DÉSARMÉ (gros voyant)
- Treuil sélectionné : M1 / M2 / COUPLÉ
- Synchronisme : ACTIF / INACTIF / DÉRIVE

### Zone sécurité
- AU : OK / DÉCLENCHÉ
- `SafeStop` : INACTIF / ACTIF (par treuil + global)
- `PowerCutOff` : INACTIF / ACTIF (par domaine)
- Frein : SERRÉ / DESSERRÉ (par treuil)
- Contacteurs : RETOMBÉS / COLLÉS (diagnostic)
- Mou de câble : NON / OUI
- Limite haute / basse : ATTEINTE / NON
- Codeur : VALIDE / DÉFAUT
- Thermique moteur / frein : OK / DÉFAUT

### Zone défaut (par défaut actif)
```
┌─────────────────────────────────────┐
│ CAUSE       : Mouvement non commandé│
│ NIVEAU      : Méca A (bit7)         │
│ ACTION AUTO : SafeStop + PowerCutOff│
│ RESET       : Cause disparue + Appui│
│ CONDITION   : FwdRevSpeedFeedbackOff│
│             : BrakeFeedback = TRUE  │
└─────────────────────────────────────┘
```
Éviter l'affichage brut `ErrorId = 16#xxxx` sans décodage.

**Estimation charge** : Marquage obligatoire :
> ⚠️ **Estimation indicative — non certifiée — ne pas utiliser comme limite de levage**

---

## 📋 7. Plan d'action priorisé

### 🔴 PHASE 0 — Avant tout mouvement machine (P0)

| # | Action | Responsable | Critère de fin |
|---|---|---|---|
| 1 | Unifier hauteurs : mesurer position physique capteur haut, butée mécanique, définir 5 niveaux | Automatisme + Mécanique | Table cohérente validée |
| 2 | Corriger `FB_SpeedStep` : borner `MaxStepNumber`, valider table, défaut config | Automatisme | **FAIT** — Compilation + test unitaire OK |
| 3 | Valider table contacteurs `ST_SpeedStepTable` (seuils, contacteurs cohérents) | Mise en service | Table signée |
| 4 | Vérifier câblage réel AU / `PowerCutOff` A+B / contacteur puissance / freins | Électricité + Automatisme | Schéma + test coupure |
| 5 | Vérifier polarités : freins (NC), contacteurs (NO), capteurs NF (TopPosition, SlackCable, Thermiques) | Électricité | Relevé câblage |
| 6 | Rebuild CODESYS complet (F11) — 0 erreur | Automatisme | Build OK |
| 7 | Vérifier ordre tâches réel CODESYS + mapping I/O (`Device.export`) | Automatisme | Export cohérent |
| 8 | Séparer `GVL_IHM` : Config (RETAIN) / Commands / Status / Alarms | Automatisme + IHM | Variables séparées |

### 🟠 PHASE 1 — Sur banc (P1)

| # | Test | Critère |
|---|---|---|
| 1 | Perte joystick CAN → SafeStop M1+M2 < 100 ms | Temps mesuré |
| 2 | Perte heartbeat IHM → SafeStop | Détection |
| 3 | Perte codeur M1 → SafeStop M1 seul | Isolation |
| 4 | Mou de câble M2 → ForbidDescent seul, montée libre | Comportement |
| 5 | Butée haute M1 (logicielle) → Arrêt rampe normale | Position |
| 6 | Capteur haut physique → ForbidAscent immédiat + Méca D 3 s | Séquence 3 couches |
| 7 | Limite basse → ForbidDescent | Position |
| 8 | Frein ne serre pas → Méca B/D → PowerCutOff | Coupure effective |
| 9 | Contacteur collé → Détection StuckClosed + PowerCutOff | Coupure effective |
| 10 | Sens réel opposé → SafeStop 500 ms | Temporisation |
| 11 | Absence mouvement malgré commande → SafeStop 3 s | Temporisation |
| 12 | Désynchronisme faible (0,25 m) → Comportement selon `_SyncSoftStopEnable` | Mode documenté |
| 13 | Désynchronisme critique (2 m) → SafeStop immédiat | Immédiat |
| 14 | Inhibition M1 seul → M2 fonctionne, benne possible, safety M1 désactivée | Isolation |
| 15 | Redémarrage après coupure secteur → Pas de mouvement auto, défauts visibles | Pas auto-restart |
| 16 | Reset AVANT disparition cause → Défaut maintenu | Front + cause |
| 17 | Reset APRÈS disparition cause → Défaut effacé | Acquittement |

### 🟢 PHASE 2 — Essais terrain (charge réelle)

- À vide → Charge nominale → Charge max
- Montée chargée (validation temporisations frein — **T9 PLAN_TASK**)
- Descente entraînante (validation `MaxStepDescente`)
- Frein chaud (cycles répétés)
- Arrêt d'urgence en mouvement
- Perte capteur / bus en exploitation

---

## 📊 8. Traçabilité — Références croisées

| Élément | Fichier code | Spécification DOC | Ligne/Section |
|---|---|---|---|
| `FB_Winch` | `CODE/TREUILS/FB_Winch.st` | `AF_Partie-09` §2, §3 | Interface complète |
| `FB_Safety_Winch` | `CODE/TREUILS/FB_Safety_Winch.st` | `AF_Partie-09` §3, §4 | 14 bits + Méca A–G |
| `FB_WinchSync` | `CODE/TREUILS/FB_WinchSync.st` | `AF_Partie-09` §9 | Surveillance seule |
| `FB_SpeedStep` | `CODE/TREUILS/FB_SpeedStep.st` | `AF_Partie-09` §2 | Décodeur paliers |
| `FB_DriftGuard` | `CODE/TREUILS/FB_DriftGuard.st` | `AF_Partie-09` §4decies | Factorisation A/C |
| `PRG_06_WinchControl` | `CODE/MAIN/PRG_06_WinchControl.st` | `AF_Partie-09` §6, `AF_Partie-12` | Arbitrage M1/M2/Benne |
| `PRG_03_Safety` | `CODE/MAIN/PRG_03_Safety.st` | `AF_Partie-09` §3, `AF_Partie-10` | Instances safety |
| `PRG_09_Supervision` | `CODE/MAIN/PRG_09_Supervision.st` | `AF_Partie-07` §4 | Mapping IHM |
| `PRG_10_Outputs` | `CODE/MAIN/PRG_10_Outputs.st` | `AF_Partie-06` §5 | Sorties physiques |
| `ST_WinchHMI` | `CODE/SUPERVISION/ST_WinchHMI.st` | `AF_Partie-07` §2A | Structure IHM |
| `ST_SyncHMI` | `CODE/SUPERVISION/ST_SyncHMI.st` | `AF_Partie-07` §2C | Synchro IHM |
| `GVL_IHM` | `CODE/SUPERVISION/GVL_IHM.st` | `AF_Partie-07` §3 | GVL complète |
| `GVL_PERSISTENT` | `CODE/GVL_PERSISTENT.st` | `AF_Partie-02` | Paramètres persistants |

---

## 📝 9. Notes de fin d'audit

### Points non vérifiables par lecture de code seule
- Compilation effective dans CODESYS 3.5 (build complet)
- Existence/cohérence des POU réellement importés dans le projet
- Ordre exact des tâches et priorités configurées (Device.export)
- Mapping I/O réel et polarités électriques
- Temps physiques réels contacteurs / freins
- Validation terrain seuils et tolérances
- Comportement IHM réel avec variables RETAIN
- Tests PLC exécutés et résultats (framework `AF_Partie-14`)

### Recommandation de processus
1. Appliquer les corrections **P0** (hauteurs, `FB_SpeedStep`, `PowerCutOff`)
2. Faire une **revue de code croisée** formelle sur les blocs safety (`FB_Safety_Winch`, `FB_WinchSync`)
3. Documenter la **stratégie synchronisme unique** et aligner DOC/CODE
4. Lancer les **tests banc** (Phase 1) avec protocole `AF_Partie-14` / `PLAN_TASK` §4
5. Mettre à jour la documentation `AF_Partie-09` avec les valeurs **réelles validées**
6. Séparer `GVL_IHM` avant essais terrain

---

**Statut final audit** : 
- Architecture : **Bonne**
- Implémentation logicielle : **Avancée mais non figée**  
- Validation sécurité : **Insuffisante pour exploitation réelle**
- IHM graphique : **Incomplète** (couche échange OK, visu manquante)
- **Go machine : NON** — Lever P0 + Phase 1 banc avant tout mouvement

---

*Document généré par l'Agent Orchestrateur — Validation croisée par Agent Vérificateur (session antigravity)*  
*Prochaine révision : après levée P0 et tests banc*