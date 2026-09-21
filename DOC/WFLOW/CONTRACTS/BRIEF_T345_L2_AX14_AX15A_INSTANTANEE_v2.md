=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → RELAIS T345-L2 (même acteur, verrou déjà posé) ===
=== SUPERSEDE BRIEF_T345_L2_DEMANDE_SURVIT_ARRET.md (verdict BLOCK levé, périmètre étendu) ===

## 1. Contexte

Le 1er audit read-only de T345-L2 a posé un verdict BLOCK : `SeenNeutral` jugé
indispensable pour prouver la sûreté mais hors périmètre initial, verrous
T345/T347/T358 actifs. **Les verrous sont levés.** Le périmètre est
officiellement étendu pour inclure ce verrou de sûreté. Ce document remplace
l'ancien brief — il a été rédigé par une 2e étude experte, en lecture seule,
qui a challengé et corrigé le 1er audit sur un point technique important
(§3 ci-dessous).

## 2. Objectif

`FB_CycleSemiAuto.st`, état `AX14_TRANSLATE_DUMP` (ligne ~1486) : la
transition vers `AX15A_DUMP_ARRIVE` doit basculer DÈS que le capteur
d'arrivée trémie est confirmé (`Translation_At_Tremie AND
TranslationStopTimer.Q`), **sans attendre le passage par neutre du
joystick** (aujourd'hui : `AND NOT JoystickDeflected` en plus, à retirer).

But métier : arrivée physique détectée → changement d'état immédiat, plus
d'attente artificielle avant l'étape suivante.

## 3. Faille de sûreté identifiée — mécanisme exact, pas une impression

`FB_CycleSemiAuto.st:1509-1512` (état `AX15A_DUMP_ARRIVE`) :
```
IF DeadmanArmed AND JoystickPush THEN
    State := AX15B_DUMP_OPEN;
END_IF;
```
Ceci est évalué dès le PREMIER SCAN d'entrée dans `AX15A`. Si on retire
l'exigence de neutre à la sortie d'AX14, rien n'empêche l'opérateur d'être
encore sur le manche (Y-bas, ou diagonale X+Y) au moment de l'arrivée : la
commande d'ouverture benne (`AX15B`, puis `BucketCmd.ReqOpen`) peut partir
**sans qu'aucun scan n'ait jamais vu le joystick neutre**.

⚠️ **Correction du 1er audit** : `SeenNeutral`, déjà utilisé dans
`FB_CycleMachineHoming.st:117,438,479` (T364), N'EST PAS RÉUTILISABLE ici
tel quel. Ce n'est pas un latch — juste un alias recalculé chaque scan
(`SeenNeutral := NOT JoystickDeflected`). Dans le homing ça marche car il
est ANDé avec des conditions qui n'impliquent jamais `JoystickPush` sur le
même scan. Ici, `JoystickPush` implique déjà `JoystickDeflected = TRUE` :
un AND direct entre les deux est **toujours FALSE, sur n'importe quel
scan**. Il faut un **vrai latch inter-scan**, mémorisant qu'un scan neutre
a été vu DEPUIS l'entrée en AX15A, consommé à un scan ultérieur où
`JoystickPush` redevient vrai.

## 4. Modifications précises

**Fichier unique** : `CODE/G_CYCLE/FB_CycleSemiAuto.st` — scope strict,
aucune autre modification.

**Variable à créer** :
```
SeenNeutralAfterArrival : BOOL;
```
Portée VAR interne (état, pas commande — pas de préfixe Req/Cmd, cf.
NC-010/NC-040). Sémantique : TRUE dès qu'un scan a vu `NOT
JoystickDeflected` (X ET Y neutres) depuis l'entrée dans
`AX15A_DUMP_ARRIVE`. Remise à FALSE à CHAQUE entrée dans cet état (front
d'entrée d'état — pattern déjà illustré ligne 385, `StepMaxPrevState`,
laissé au choix de l'agent : `R_TRIG` dédié ou comparaison `State <>
PrevState`).

1. **`AX14_TRANSLATE_DUMP` (ligne ~1486)** :
   ```
   IF Translation_At_Tremie AND TranslationStopTimer.Q THEN
       State := AX15A_DUMP_ARRIVE;
   END_IF;
   ```
   Retirer `AND NOT JoystickDeflected`. `TranslationStopTimer` inchangé
   (arrêt physique M3 confirmé, ne pas toucher).

2. **`AX15A_DUMP_ARRIVE` (ligne ~1491)** :
   - Détecter l'entrée d'état → `SeenNeutralAfterArrival := FALSE` sur ce
     front.
   - Chaque scan dans AX15A : `IF NOT JoystickDeflected THEN
     SeenNeutralAfterArrival := TRUE; END_IF;`
   - Transition existante (ligne 1510) devient :
     ```
     IF SeenNeutralAfterArrival AND DeadmanArmed AND JoystickPush THEN
         State := AX15B_DUMP_OPEN;
     END_IF;
     ```
   - `WaitingForOperator`/`OperatorAction` doivent refléter l'attente de
     relâchement tant que `SeenNeutralAfterArrival = FALSE` (message
     distinct de "pousser pour ouvrir" — ex. "Relâcher le joystick avant
     ouverture").

3. **Forçage diagnostic (`ForceStepCandidate = 15`, lignes ~761-764)** :
   AUCUNE modification nécessaire — le saut force `State := AX15A` sans
   émettre de commande sur ce scan (`StateExecutionInhibit`), le scan
   suivant exécute le même bloc CASE `AX15A` normalement. Le correctif du
   point 2 couvre déjà ce chemin. Vérifier seulement que
   `SeenNeutralAfterArrival` est bien FALSE au moment du saut forcé (init
   par défaut FALSE au démarrage FB — cohérent, rien à faire).

## 5. Hors périmètre — confirmé, ne pas toucher

- `AX2→AX3` (lignes ~955-1020) : pattern volontairement différent (geste
  continu unique, `JoystickPushOnly` exclut déjà X). Ce n'est **pas** un
  bug analogue, ne pas copier ce mécanisme ici.
- `TranslationStopTimer` : déjà correct (arrêt physique M3, lignes
  360-366).

## 6. Scénarios de test CI à couvrir

1. **Nominal** : arrivée capteur avec joystick neutre → transition
   immédiate AX14→AX15A, ouverture normale au premier push après neutre
   confirmé.
2. **Cas limite 1 — push Y maintenu à l'arrivée** : AX14→AX15A immédiat,
   MAIS AX15A→AX15B **refusé** tant que le joystick n'est pas passé par un
   neutre réel.
3. **Cas limite 2 — diagonale X+Y maintenue à l'arrivée** : même
   comportement que cas 1, aucune commande benne émise tant que neutre
   non vu.
4. **Cas limite 3 — forçage diagnostic (`StepForceTgt=15`)** : même garde
   active — un forçage suivi d'un `JoystickPush` déjà actif au scan du
   forçage ne doit PAS déclencher `AX15B` au scan suivant.
5. **Non-régression** : `AX2→AX3` et le reste du séquenceur inchangés
   (diff limité aux lignes AX14/AX15A décrites ci-dessus).

## 7. Pièges déjà identifiés — à éviter explicitement

- Ne PAS réutiliser `SeenNeutral` de `FB_CycleMachineHoming.st` tel quel
  (§3 ci-dessus — logiquement impossible ici).
- Ne pas oublier le reset de `SeenNeutralAfterArrival` à CHAQUE entrée
  dans AX15A (transition normale ET forçage) — sinon une valeur périmée
  TRUE pourrait survivre à un forçage répété.
- Ne pas toucher `TranslationStopTimer` ni `AX2/AX3`.
- Vérifier l'absence d'autre lecture de `State <> AX14_TRANSLATE_DUMP` qui
  dépendrait implicitement de l'ancien délai neutre avant transition.

## 8. Livrables

- Diff limité au fichier unique listé en §4.
- Preuve CI rouge-avant/vert-après sur les 5 scénarios §6.
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T345_L2_AX14_AX15A_INSTANTANEE.yaml`.

## 9. Contraintes non négociables

- Zéro affirmation non vérifiée — preuve fichier:ligne dans la même
  restitution.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro autre fichier touché.

## 10. Sources

`CODE/G_CYCLE/FB_CycleSemiAuto.st` (lignes 1465-1555, 743-793, 955-1020),
`CODE/G_CYCLE/FB_CycleMachineHoming.st` (lignes 117, 438, 479).
