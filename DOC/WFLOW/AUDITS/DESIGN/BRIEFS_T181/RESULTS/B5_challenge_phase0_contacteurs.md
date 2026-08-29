# B5 — Challenge Phase 0/0b T181 + règle §3bis cadencement contacteurs

> Subagent Claude (general-purpose, accès dépôt). Relecture des 3 contrats T181-01 / T181-02_03 /
> T181-05, de `AF10_INTERFACE` §3/§3bis, du plan §1/§5/§13, du code réel.
> **F** = fait vérifié · **H** = hypothèse d'ingénierie · **I** = incertitude.

## Verdict : PAS ENCORE un socle sûr pour démarrer le code. 5 corrections.

---

## 1 · Règle §3bis « sens jamais relâché avant vitesse »

### 1.1 — Danger réel mais règle mal bornée (F + H)
- **Danger direct confirmé** : contacteur de **sens = statorique**, il coupe le courant ligne plein. L'ouvrir sous C1..4 fermés = arc AC-3 pleine charge, soudure du contacteur de sens, transitoire rotor. Séquence saine = ouvrir C1..4 (couple s'effondre, courant chute) **puis** ouvrir le sens à courant quasi nul.
- **Risque INVERSE non traité** : pendant la fenêtre de maintien, C1..4 tous ouverts = résistance rotor max = couple min, frein encore desserré. Sur M1 (treuil de retenue, porteur) : si couple stator à résistance rotor pleine < couple de charge → **la charge dévire** pendant toute la fenêtre.
- **Bornage inversé** (F, texte AF10 §3bis) : le niveau **filet** (`FB_WinchOutputInterlock`) est décrit « attente feedback `ContactorsAllOff` » **sans timeout**. C'est l'inverse : le filet doit continuer d'agir si le feedback ne vient jamais.
- `ContactorsAllOff` = **une seule DI** (`M1_ContactorsReleased_DI`, `PRG_06:749`), non monitorée. Collée « released » → filet lâche le sens tout de suite (retour arc). Collée « not released » → **sens maintenu indéfiniment, moteur sous tension, aucune coupure hors AU / `PowerCutOff`**.
- → règle à ré-énoncer : « sens avant vitesse, fenêtre bornée `T_max` ; à expiration → chute sens + latch `StuckClosed` + escalade définie ». **Timeout sur le filet**, pas le niveau gouvernant seul.

### 1.2 — CONFLIT DIRECT avec `FB_WinchOutputInterlock` §5 (F, BLOQUANT)
`MotorRequest := (RequestedStepClamped>0) AND (RequestedRelayFwd XOR RequestedRelayRev)` (`:122`).
Dès que `FB_Winch` met `StepNumber:=0` → `RequestedStep=0` → `MotorRequest=FALSE` **le même cycle**, même si `RequestedRelayFwd` est encore tenu.
En §5 (`:207-263`) : `:208` force `RelayFwd:=FALSE; RelayRev:=FALSE` en tête **inconditionnellement** ; la branche `ELSIF NOT MotorRequest` (`:225-231`) **ne réaffecte pas** les relais ; seule la branche `ELSE` (`:239+`) le fait, gardée `(AuthorizedStep>0) OR (RequestedStepClamped>0)` (`:248`).
→ **la barrière coupe `RelayFwd` physique le cycle même où la vitesse tombe à 0** — elle défait le maintien §3bis fait dans `FB_Winch`. La règle « 2 niveaux » n'est **pas implémentable** sans restructurer §5 de la barrière. Logique **C4** dont dépendent déjà TC-012/013/021/022.
Le contrat T181-05 met `FB_WinchOutputInterlock.st` dans le scope mais **AC6 ne teste que `FB_Winch`**.

### 1.3 — Frein : séquencement non tranché (F)
`BrakeCmd := RelayFwd OR RelayRev` (`FB_WinchOutputInterlock.st:275` + `PRG_06:141,214`).
→ le frein reste desserré tant que le relais de sens est tenu → il colle **APRÈS** la coupure du sens, après `DropConfirmDelay`. Pendant cette fenêtre : frein ouvert + rotor résistance max + charge possiblement motrice = **exposition dérive D16 / T178, aggravée par §3bis**. Aucun doc ne relie §3bis à D16.
Séquence usuelle treuil de levage : réduire paliers → **appliquer frein** → attendre `BrakeFeedback` fermé → **puis** ouvrir le contacteur de sens. Impose que `BrakeCmd` ait sa propre logique (candidat **T181-06**).

### 1.4 — Temps morts directionnels (F)
Orthogonaux à §3bis (extinction vs redémarrage), pas de double tempo. `DropConfirmDelay` ne doit **pas** réutiliser `DeadTime*` ni `DirectionInterlockDelay*` (répéterait D10).

---

## 2 · T181-01 (barrière + interlock cadence 2 niveaux)
- B4-S1 confirmé : `StepDelay(IN:=FALSE)` aux 6 sites, `.Q` jamais lu, `AuthorizedStep := RequestedStepClamped` direct (`:246`). **Aucun interlock de cadence** → T181-01 le CRÉE.
- Contrat insuffisant : AC1 ne liste que TC-012/013/021/022 (watchdog/latches/temps morts) — aucune cadence. Ticket = **4 livrables sous un patch C4** : (a) 4 TC verts interface figée, (b) FB safety 2-niveaux neuf, (c) §13#4 (PLr / indépendance / non-bypass), (d) refonte §5 pour §3bis.
- `FinalInterlockGoverned=FALSE` en nominal : **faux positif AC4** si la barrière passe `Busy`/`Governed` pendant l'attente confirmation vitesse (à chaque relâche joystick). Clause compagnon manquante : `DirectionDropBlocked` transitoire ≠ gouvernance.
- Cadence de montée : base physique = thermique résistances rotoriques + choc couple, mais valeur = datasheet + facteur de marche → **empirique / essai site**. T181-01 veut figer les constantes en Phase 0 alors que « seuils, valeurs ? » est ouvert T181-06 (plan §7.1). AC3 doit les marquer **provisoires**.
- `bloque_par:[T175]` toujours absent du fichier. T175 (⏳, autre agent) porte TC-021/022 AC2 = même code.

---

## 3 · T181-02+03 et T181-05
- Fusion 02+03 : **acceptable** (sections différentes de `FB_Winch.st`). Réserve : si le vrai FAIL TC-011 est dans la chaîne `CommandedDirection` / 1er scan (`:165-168,211`) = même région que D18/§3bis → pattern commit-2-temps.
- Perte diag `StuckClosed` Phase 0→A : `instCauses[1]` (`:123`) → `FB_Winch.Fault` retiré. **Trancher par écrit** : `FB_Safety_Winch.StuckClosed` déclenche une **action** (`SafeStop`/`PowerCutOff`) ou juste du diag ? AC5 exige un TC mais **pas l'action protectrice**.
- T181-05 « interface inchangée » + retrait `Mode` : contradiction **corrigée dans le contrat** (AC8), mais reste fausse dans le plan §7 et l'en-tête AF10 §3 — requalifier partout (§13#2).
- D18 cible bien le front d'Enable pas `FirstScanDone` : **correct dans le contrat** (AC2).
- **D18 + §3bis dans un ticket C3 = mismatch de criticité** : D18 = comportement sécurité C4, §3bis = séquencement actionneurs C4 + édition barrière C4. Répète l'erreur B4 sur D18.
- `FB_WinchStepShaper` extrait : reversal **défendable** (brique safety-relevant : porte la « retombée vitesse immédiate »). Condition : FB minimal (1 TON + 1 compteur), up-ramp **strictement iso** (AC5).
- `+T#100ms` en dur (`:248`) : « justifier par commentaire » = magic number avec cache-sexe. **Fondre dans `StepRampDelay`**.

---

## 4 · Ce qui manque
| # | Manque |
|---|---|
| **M1** | Ordre intra-Phase 0 : T181-01 et T181-02_03 éditent tous deux `FB_Winch.st`, C4, `bloque_par:[00]` sans ordre mutuel. Sérialiser : **02+03 d'abord** (plus petit, répond à « TC-011 dans la chaîne direction ? » dont 05 dépend) puis 01. |
| **M2** | Modifs `FB_WinchOutputInterlock` non consolidées : 3 raisons concurrentes (T175, T181-01, T181-05) sur le FB le plus critique. **Consolider dans T181-01**, T175 fusionné/séquencé avant. |
| **M3** | Non-régression contre baseline rouge : T181-05 AC10 = « score >= baseline » masque un échange fix/casse. Faire comme T181-02 AC2 : vecteur pass/fail **par TC** figé par T181-00. |
| **M4** | Coordination T175 / T169-A non contractualisée : arêtes `bloque_par` absentes. T175 modifie `FB_Safety_Winch.st` que T181-03 édite aussi. Point de départ non figé (`.xml` treuil en `M`). |
| **M5** | §3bis ↔ D16/T178 : fenêtre `DropConfirmDelay` = frein desserré + rotor résistance max + charge motrice. Ajouter vecteur T181-00 « relâche joystick sous charge → dérive ≤ X cm pendant la fenêtre ». |
| **M6** | `FB_Winch.st:300-304` `IF Fault.Error THEN RelayFwd:=FALSE` coupe le sens **immédiatement** — contredit §3bis. §3bis doit préciser quels défauts gardent l'ordonnancement, lesquels coupent dur (AU / `PowerCutOff` = dur). La garde `G4xx_check_direction_after_speed` **échouera** sur ces `RelayFwd:=FALSE` non gardés si écrite littéralement. |
| **M7** | `DirectionChangeDelay.IN` gate sur `FwdRevSpeedFeedbackOff` (`:206`) : §3bis retarde cette retombée effective → armement du temps mort direction décalé. À vérifier au harnais. |

---

## 5 · Corrections priorisées
1. **Réconcilier §3bis avec `FB_WinchOutputInterlock` §5 AVANT de coder** — redéfinir `MotorRequest` / le chemin relais-off pour que la barrière tienne aussi le relais de sens jusqu'à `FwdRevSpeedFeedbackOff`. AC dédié (test barrière). **[M]**
2. **Borner §3bis** — fenêtre `T_max`, timeout sur le niveau **filet**, comportement pour les 2 états de panne de `ContactorsAllOff` (DI simple voie), escalade → `StuckClosed` + latch. **[S-M]**
3. **Trancher le séquencement du frein** (arrêt humain T181-06) — frein colle **avant** ouverture du sens ? Si oui `BrakeCmd` ≠ `RelayFwd OR RelayRev`. Croiser §3bis / D16 dans les vecteurs T181-00. **[M]**
4. **Requalifier T181-05 en C4** (ou extraire D18 + §3bis dans un ticket C4 dédié, T181-05 = pure extraction C3 bit-identique). **Consolider les modifs `FB_WinchOutputInterlock` dans T181-01.** Arêtes `bloque_par` réelles : `T181-01 ← [T181-00, T175]`, `T181-00 ← [T169-A]`. Sérialiser T181-01 vs T181-02_03. Rebaser sur HEAD propre. **[S]**
5. **Compléter les AC** — (a) T181-01 AC3 : constantes de cadence **provisoires / essai site** ; (b) T181-01 AC4 : `DirectionDropBlocked` transitoire ≠ gouvernance ; (c) T181-05 AC10 : non-régression **par TC** ; (d) T181-02_03 AC5 : asserter l'**action protectrice** de `FB_Safety_Winch.StuckClosed` ; (e) réconcilier `G4xx_check_direction_after_speed` avec les coupures dures légitimes (`NOT Enable`, `Fault.Error`, `PowerCutOff`). **[S]**

---

## Incertitudes à lever
- `FB_Safety_Winch.StuckClosed` → action (`SafeStop`/`PowerCutOff`) ou diag seul ?
- valeur cible de la cadence de montée (datasheet résistances rotoriques → essai site)
- origine / valeur du `+T#100ms`
- interaction §3bis ↔ armement `DirectionChangeDelay` (gate `FwdRevSpeedFeedbackOff`)
- config des tâches CODESYS (4/10/20 ms) non lue
