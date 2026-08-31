# T197 — Limite légale neutralisée par le bypass de banc

Date : 2026-08-31  
Criticité : C4 — sécurité d'exploitation / descente sous cote légale  
Statut : correction source appliquée, validation CODESYS humaine requise

## Symptôme

En simulation, une descente restait possible alors que la position de câble
avait dépassé la cote légale `-15.0 m`. Le bypass IHM de limite légale n'était
pas supposé être activé.

## Chaîne causale confirmée

1. `GVL_Simulation.SimulationBypassActive` vaut `TRUE` par défaut.
2. `PRG_07_Supervision` transformait ce signal en `Bypass.Safety=TRUE` et
   `Bypass.Process=TRUE` sans gate explicite sur `SimulationModeActive` et
   `SimWinchActive`.
3. `PRG_04_Treuils_Benne` transmettait `BypassProcess` à `FB_Safety_Winch`.
4. Dans le calcul de `DescendPermit`, la condition de limite légale était
   `LimitLegalReached AND NOT (BypassProcess OR BypassLimitLegal)`.
5. Le bypass de groupe procédé du banc neutralisait donc aussi la cote légale,
   bien que les commentaires de simulation affirment le contraire.

La limite câble physique restait distincte (`BypassCableLimitSwitch`), ce qui
explique pourquoi la cote légale pouvait être franchie avant la limite câblée
à `-20.0 m`.

## Correction appliquée

- `FB_Safety_Winch.st` : la limite légale est désormais bloquée par
  `LimitLegalReached` sauf `BypassLimitLegal` dédié. `BypassProcess` ne peut
  plus lever ce verrou.
- `PRG_07_Supervision.st` : ajout de `SimulationBypassEffective`, égal à
  `SimulationModeActive AND SimWinchActive AND SimulationBypassActive`, avant
  les fronts de pilotage du bypass. Le défaut `TRUE` du stimulus est donc
  inopérant hors simulation treuil.
- Ajout de `TC-P10-052` : `BypassProcess=TRUE` + limite atteinte ⇒
  `DescendPermit=FALSE`.
- Ajout de `TC-P10-053` : seul `BypassLimitLegal=TRUE` autorise le scénario de
  mise en service.

## Vérifications locales

```text
FB_Safety_Winch : 17/17 PASS
  TC-P10-052 : PASS
  TC-P10-053 : PASS
Lint FB_Safety_Winch : clean
Contrat T197 : PASS
```

Le lint de `PRG_07_Supervision` est structurellement incomplet uniquement parce
que les types/POU inter-PRG ne sont pas chargés par ce lint isolé; il ne signale
aucun diagnostic sur la modification.

## Re-test CODESYS obligatoire

Après copie des sources et rebuild CODESYS :

1. Vérifier `GVL_Simulation.SimulationModeActive=TRUE`,
   `SimWinchActive=TRUE`, `SimulationBypassActive=TRUE`.
2. Vérifier que `GVL_IHM.Commun.Bypass.LimitLegal=FALSE`,
   `M1TreuilRetenue.Bypass.LimitLegal=FALSE` et
   `M2TreuilBenne.Bypass.LimitLegal=FALSE`.
3. Enregistrer les positions M1/M2 à `-14.9 m`, puis `-15.1 m`.
4. À `-15.1 m`, contrôler :
   - `GVL_IHM.Commun.LimitLegalReached=TRUE` ;
   - `PRG_04_Treuils_Benne.instSafetyWinchM1.DescendPermit=FALSE` ;
   - `PRG_04_Treuils_Benne.instSafetyWinchM2.DescendPermit=FALSE` ;
   - `Data.WinchM1FinalInterlockRequest.RequestedRelayRev=FALSE` et idem M2.
5. Refaire le même essai avec `SimulationModeActive=FALSE` : le stimulus de
   bypass ne doit produire aucun bypass effectif.

Tant que ce re-test humain n'est pas passé, la machine ne doit pas être
déclarée utilisable sous la cote légale.
