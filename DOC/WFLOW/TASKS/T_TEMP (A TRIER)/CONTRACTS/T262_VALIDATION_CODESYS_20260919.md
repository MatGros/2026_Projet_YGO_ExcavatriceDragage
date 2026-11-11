# T262 — Validation CODESYS AX10 → AX10B → AX11

## But

Vérifier en simulation en ligne que la fermeture de benne ne crée pas de trou de
commande entre M2 et le démarrage coordonné M1+M2.

## Préconditions

- Importer `CODE_XML/CODE_DiffBundle.xml`, puis compiler le projet.
- Mode `SEMI_AUTO`, chaîne de sécurité valide, homme-mort opérationnel.
- Conserver les paramètres de simulation validés par l’utilisateur.
- Ne pas forcer les sorties physiques ni inhiber les interlocks.

## Variables de trace

Tracer au minimum :

```text
PRG_07_Supervision.CycleStep
PRG_03_Modes_Cycle.CycleSemiAuto.BucketCmd.ReqHoldAscentP1AfterClose
PRG_03_Modes_Cycle.CycleSemiAuto.WinchM1Cmd.RunRequest
PRG_03_Modes_Cycle.CycleSemiAuto.WinchM2Cmd.RunRequest
PRG_03_Modes_Cycle.CycleSemiAuto.WinchM1Cmd.StepTgt
PRG_03_Modes_Cycle.CycleSemiAuto.WinchM2Cmd.StepTgt
PRG_04_Treuils_Benne.Data.BucketCloseReached
PRG_06_Outputs.Data.M1AscentStartReady
PRG_06_Outputs.Data.M1BrakeCmd
PRG_06_Outputs.Data.M2BrakeCmd
PRG_06_Outputs.Data.M1RelayFwd
PRG_06_Outputs.Data.M2RelayFwd
```

## Séquence

1. Démarrer un cycle automatique normal jusqu’à `AX10_CLOSE_BUCKET`.
2. Maintenir le joystick en demande de fermeture.
3. Vérifier que M2 ferme la benne avec le plafond AX10 prévu (P1/P2).
4. À `BucketCloseReached`, vérifier le passage à `AX10B_RACCORDEMENT_P1`.
5. Vérifier que M2 reste en montée P1 pendant l’attente M1.
6. Lorsque `M1AscentStartReady = TRUE`, vérifier sur le même scan :
   - `M1.RunRequest = TRUE` et `M2.RunRequest = TRUE` ;
   - `M1.StepTgt = 1` et `M2.StepTgt = 1` ;
   - même sens de montée ;
   - aucun front d’arrêt frein/contacteur entre les deux demandes.
7. Au scan suivant, vérifier `AX11_CTRL_ASCENT` et le plafond commun configuré
   (P1 ou P2 selon `CtrlAscentMaxStep`).

## Critères

**PASS** si le transfert est M1=P1 / M2=P1 sans trou, puis AX11 reprend avec le
plafond commun.

**FAIL** si M2 retombe à zéro, si un frein/contacteur tombe entre les deux scans,
si M1 démarre seul, ou si le vecteur M1=P1 / M2=P2 apparaît.

## Repli à vérifier

Si `M1AscentStartReady` reste faux, l’attente est bornée à 2 s. Le repli sûr
historique doit alors s’exécuter ; aucun redémarrage automatique ne doit apparaître.

