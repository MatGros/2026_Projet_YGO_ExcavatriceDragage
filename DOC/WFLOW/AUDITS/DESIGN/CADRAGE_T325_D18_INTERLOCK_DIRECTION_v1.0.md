# 🔀 Cadrage T325 — Interlock direction treuils (D18) : 3 défauts, correctifs proposés

> 📌 Livrable T325 (contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T325_D18_NEUTRE_ANALYSE_RISQUE.yaml`).
> **Aucune ligne de code ST modifiée par cette fiche** — un seul correctif (Défaut 1) est déjà
> committé et non testé (`6f708b22`), les deux autres (Défauts 2 et 3) sont proposés ici pour
> relecture croisée avant implémentation. Classement cible de l'implémentation future : **C4**.
>
> ⚠️ **Distinction avec T224** (précisée par Mathieu, 2026-09-20) : T224 décrit une commande
> **émise** vers les contacteurs puis bloquée par un interlock **aval** (joystick actionné
> rapidement, ordre présent mais refusé). Les Défauts A/B ci-dessous sont **différents** : la
> commande n'est **jamais formée** — `DirectionChangePending` bloqué en amont force
> `RampTargetStep=0` dans `FB_Winch` avant tout calcul d'ordre contacteur. Même symptôme côté
> opérateur (armé, aucun mouvement, aucun défaut), mécanismes distincts — à ne pas traiter comme
> un seul et même défaut lors du cadrage de l'implémentation C4.

---

## 🎯 1 · Fraîcheur des fiches AF (AC1)

| Fiche | Constat | Fait autorité ? |
|---|---|---|
| `AF_Partie-10_Fonction_Winch_v2.1.md` §1/§2ter | Documente `DirectionInterlockDelay=900ms montée/400ms descente`, `RestartDelay=1500ms` | ❌ Diverge du code (`800/500ms`, `500ms`) — pas mis à jour depuis, statut à revalider avec Mathieu |
| `DOC/AF/AF_Partie-10_Fonction_Winch/FB_WinchOutputInterlock_v1.0.md` | Documente `DeadTimeSameDir/OppositeDir=1s`, référence encore un interlock unique à 200ms (pré-v2.1) | ❌ Périmée par rapport à AF-10 v2.1 elle-même — deux fiches AF en désaccord entre elles |
| Code (`FB_WinchDirectionInterlock.st`, `FB_WinchOutputInterlock.st`) | `800/500ms`, `RestartDelay=500ms`, `DeadTimeSameDir/OppositeDir=500/700ms` | Source de vérité **de facto**, mais non documentée nulle part comme intentionnelle |

**Verdict AC1** : aucune fiche ne fait autorité seule. Les trois sources (AF-10 v2.1, fiche
`FB_WinchOutputInterlock_v1.0.md`, code) divergent entre elles. **Référence retenue pour cette
tâche** : le comportement fonctionnel explicitement défini par Mathieu (crédit systématique du
temps d'arrêt réel) — les fiches AF devront être mises à jour *après* que le correctif soit
validé et implémenté, jamais l'inverse.

---

## 🧩 2 · Les 3 défauts confirmés

| # | Nom | Fichier | Statut code | Preuve |
|---|---|---|---|---|
| **1** | D18 ne crédite pas le temps d'arrêt réel au neutre | `FB_WinchDirectionInterlock.st` | ✅ **Corrigé, committé** (`6f708b22`), non testé CODESYS | Trace 62/63 AX10→AX11 (~805ms ≈ `T#800ms`) ; trace 65 après correctif (raccordement AX10B en ~100ms) |
| **2** | `DeadTimeArmed` prioritaire sur `DirectionChangeDelay.Q`, purge inatteignable | `FB_WinchDirectionInterlock.st` L90/109/116/119 | ⬜ Non corrigé | Trace 67 : `DelayElapsed` grimpe à **2174ms** sans jamais que `Pending` retombe par adoption — seul le retour au neutre (~7s) puis Reset l'a résolu |
| **3** | Garde croisée M1/M2 — risque de livelock | `PRG_04_Treuils_Benne.st:1360-1361 / 1452-1453` | ⬜ Non corrigé | Mécanisme architectural confirmé par lecture code (pas encore observé en trace, à vérifier par Watch) |

Les défauts 2 et 3 sont **pré-existants** — vérifiés par `git diff dcb28019 HEAD -- FB_WinchDirectionInterlock.st` : code identique avant/après le correctif 1. Le correctif 1 ne les cause ni ne les aggrave.

---

## 🔬 3 · Défaut 2 — Purge de `DeadTimeArmed` inatteignable

### Mécanisme (code actuel, extrait)
```
:90   IF EnableRising AND RequestActive THEN DeadTimeArmed := TRUE; END_IF;
...
:109  IF NOT RequestActive THEN
:115      DeadTimeArmed := FALSE;                          // seule sortie automatique
:116  ELSIF DeadTimeArmed THEN
:118      DirectionChangePending := TRUE;                  // AUCUNE purge ici
:119  ELSIF DirectionChangeDelay.Q THEN
:124      DeadTimeArmed := FALSE;                           // ⛔ INATTEIGNABLE tant que :116 gagne
```
Une fois `DeadTimeArmed` armé (front `EnableRising` pendant une demande déjà active), la
cascade `IF/ELSIF` ne réévalue plus jamais `DirectionChangeDelay.Q` — le TON peut avoir
largement dépassé son `PT`, ça ne change rien : `Pending` reste `TRUE` indéfiniment. Seules
sorties : retour au neutre franc (`NOT RequestActive`) ou front `Reset`.

### Risque
Blocage **silencieux** (aucun `Fault`, `RampTargetStep=0` → `MotorRequest=FALSE` → barrière
finale `READY`/`Reason=NONE` — l'absence de défaut n'est pas une preuve d'innocence de D18).
Observé en mode MAINTENANCE ; le déclencheur (`EnableRising` pendant une demande déjà active)
peut survenir dans tout mode où `Enable` (= `StepNumber=0 AND ContactorsAllOff`, calculé côté
`FB_Winch`) toggle pendant qu'un axe reste sollicité.

### Correctif proposé
Évaluer `DirectionChangeDelay.Q` **avant** `DeadTimeArmed`, ou purger explicitement
`DeadTimeArmed` dès que le délai est satisfait :

```
ELSIF DirectionChangeDelay.Q THEN
    CommandedAscent := ReqAscent; CommandedDescend := ReqDescend;
    DirectionChangePending := FALSE; DeadTimeArmed := FALSE;
ELSIF DeadTimeArmed THEN
    DirectionChangePending := TRUE;
...
```
**Point d'attention** : si `DeadTimeArmed` existe précisément pour **empêcher** une adoption
immédiate après un front `Enable` (relecture du commentaire d'en-tête : *"pas de redémarrage
inrush"*), inverser l'ordre pourrait annuler cette protection dans le cas où le délai était
*déjà* écoulé avant même que `EnableRising` survienne. **À trancher par la relecture experte** :
le `DeadTimeArmed` doit-il imposer un délai **minimum incompressible** après `EnableRising`
(indépendant du crédit), ou est-ce un pur oubli de purge ?

---

## 🔬 4 · Défaut 3 — Garde croisée M1/M2, risque de livelock

### Mécanisme (code actuel, extrait)
```
PRG_04_Treuils_Benne.st:1360-1361 (volet M1)
IF WinchBothMotionActive AND (instWinchM2.DirectionChangePending OR instWinchM2.Fault.Latched) THEN
    ReqM1Winch.RunRequest := FALSE; ReqM1Winch.ReqAscent := FALSE; ReqM1Winch.ReqDescend := FALSE;
END_IF;

PRG_04_Treuils_Benne.st:1452-1453 (volet M2, symétrique)
IF WinchBothMotionActive AND (instWinchM1.DirectionChangePending OR instWinchM1.Fault.Latched) THEN
    ReqM2Winch.RunRequest := FALSE; ReqM2Winch.ReqAscent := FALSE; ReqM2Winch.ReqDescend := FALSE;
END_IF;
```
Intention documentée (commentaire d'origine) : si M1 est prêt mais M2 encore en dead-time D18,
geler M1 pour démarrer les deux ensemble une fois M2 prêt — évite qu'un treuil parte seul
(REX câble qui file).

### Risque
`DirectionChangeDelay(IN := Enable AND RequestActive AND DirectionChanged, ...)` : un `TON`
remet son `ET` à 0 dès que `RequestActive` retombe. Si **M1 et M2 sont `Pending` simultanément**,
le gel de M1 (déclenché par le pending de M2) coupe la requête de M1 → `RequestActive` de M1
retombe → son propre `ET` se réinitialise. Symétriquement pour M2. Selon le timing exact des deux
résolutions, chacun peut geler l'autre au moment précis où il allait aboutir — **livelock
auto-entretenu, sans défaut visible**, potentiellement indéfini.

### Correctif proposé
Découpler l'horloge D18 de `RequestActive` en mémorisant le temps déjà couru avant un gel, via
un mécanisme similaire à `RequestActiveRising`/`CapturedStoppedTime` déjà introduit pour le
Défaut 1 — le gel externe (garde croisée) ne doit **pas** remettre à zéro un reliquat déjà entamé,
contrairement à un vrai retour au neutre opérateur. Principe : distinguer explicitement
« neutre opérateur » (RequestActive=FALSE parce que le joystick est relâché) de « gel technique »
(RequestActive=FALSE parce qu'un autre organe l'a forcé) — seul le premier doit remettre à zéro
la mémoire de sens/délai.

**Alternative plus conservatrice** : ne pas toucher à D18, mais borner le temps de gel côté
`PRG_04` (garde-fou analogue à `CST_Ax10bHandoffWaitTime` d'AX10B) — si le gel croisé dépasse un
seuil, forcer un repli (arrêt complet des deux, nouvelle tentative depuis zéro) plutôt que de
laisser le livelock courir indéfiniment.

---

## ⚠️ 5 · Anomalie à vérifier par Watch (pas de modification code)

Trace 67 : `DirectionChangeDelayElapsed=591ms` mesuré sur une **descente**, alors que le plafond
théorique pour ce sens est `ChangeDelayDescent=500ms` (un `TON` ne peut jamais dépasser son
`PT`). Deux hypothèses : image PLC périmée par rapport au code source, ou override
IHM/persistant sur `M1WinchCfg.DirectionInterlockDelayDescent`. **À vérifier par Watch CODESYS
direct** (`PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayDescent`,
`instWinchM1.Config.DirectionInterlockDelayDescent`) avant toute conclusion — pourrait aussi
expliquer une partie du Défaut 2 si le délai réellement configuré diffère de celui lu dans le
source.

---

## 📐 6 · Table de vérité arrêt/reprise/inversion (référence minimale)

| Scénario | M1 seul | M2 seul | M1+M2 couplés | Comportement attendu |
|---|:---:|:---:|:---:|---|
| Reprise même sens, pause courte | ✅ | ✅ | ✅ | Immédiat (inchangé, hors D18) |
| Reprise même sens, pause longue | ✅ | ✅ | ✅ | Immédiat (inchangé) |
| Inversion, pause ≥ délai plein | ✅ | ✅ | ✅ | Immédiat (Défaut 1, corrigé) |
| Inversion, pause < délai plein | ✅ | ✅ | ✅ | Reliquat seul (Défaut 1, corrigé) |
| Inversion directe sans neutre | ✅ | ✅ | ✅ | Délai plein (inchangé, correct) |
| `EnableRising` pendant demande active | ✅ | ✅ | — | ⛔ Bloqué indéfiniment (Défaut 2, non corrigé) |
| M1 et M2 `Pending` simultanément | — | — | ✅ | ⚠️ Risque livelock (Défaut 3, non corrigé) |
| Retour frein retardé | ✅ | ✅ | ✅ | Barrière finale gère (hors périmètre D18) |
| Retour contacteur incohérent | ✅ | ✅ | ✅ | Barrière finale gère (hors périmètre D18) |
| Perte puis retour `Enable` | ✅ | ✅ | ✅ | Retombe en `EnableRising` → Défaut 2 potentiel |
| Cas réel AX10→AX11 (trace 65) | — | — | ✅ | Validé : raccordement ~100ms après correctif 1 |

Les lignes ⛔/⚠️ (Défauts 2 et 3) sont celles où le comportement observé diffère du comportement
attendu — elles définissent le périmètre de test de la future tâche d'implémentation.

---

## ✅ 7 · Vérification FB_Translation (AC — hors scope, signalement seulement)

`FB_Translation.st` porte sa propre temporisation directionnelle
(`DirectionInterlockDelay := T#200ms`, valeur **unique**, pas d'asymétrie montée/descente comme
D18). Le mécanisme n'est pas structurellement identique (pas de `DeadTimeArmed`/`EnableRising`
équivalent repéré dans une lecture rapide) — **non vérifié en profondeur**, à traiter par une
tâche séparée si un jour le même défaut conceptuel (non-crédit du neutre) devait y être suspecté.
Ne pas intégrer au scope ni au code de T325.

---

## 🎯 8 · Verdict et recommandation (AC3)

**Verdict** : les 3 défauts sont des **défauts de conception confirmés**, pas des comportements
volontaires justifiés par la documentation (aucune fiche AF ne documente ni la non-crédit du
neutre pré-correctif, ni la purge inatteignable de `DeadTimeArmed`, ni le risque de livelock de
la garde croisée).

**Recommandation** :
1. Défaut 1 (crédit neutre) : déjà implémenté, **en attente de test CODESYS réel** (trace, manuel,
   auto, simulation) avant validation finale.
2. Défauts 2 et 3 : **ne pas implémenter avant relecture croisée explicite** (Mathieu + expert
   externe) sur les points d'attention soulevés (Défaut 2 : le `DeadTimeArmed` a-t-il une raison
   d'être un délai incompressible ? Défaut 3 : préférer découpler l'horloge D18 du gel externe,
   ou un garde-fou temporisé côté `PRG_04` ?).
3. Classement **C4** pour la future tâche d'implémentation groupant les 3 défauts (même FB,
   même risque sécurité machine, même matrice de non-régression).
4. Contrat de conservation à rédiger pour cette future tâche C4 (hors scope C2 de T325).

**Zéro ligne de code ST modifiée par cette fiche.** Le correctif du Défaut 1 reste le seul
actuellement en place (commit `6f708b22`), non validé en essai machine réel.
