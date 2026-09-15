# Session de troubleshooting — T291-A M2 palier 5 bloqué

> Date : 2026-09-15 · Situation : machine réelle, essai surveillé · Statut : résolue sur machine, non-régression CI à finaliser

## 1. Contexte figé

- Mode : cycle `SEMI_AUTO`.
- Essai T291-A importé depuis le bundle XML du 2026-09-15.
- `GVL_IHM.CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial = TRUE` avant la descente.
- Référencement et autres états : non relevés, non nécessaires au verdict de plafonnement P4.

## 2. Symptôme

En AX7, M1 et M2 descendent au palier 4 ; M2 n'atteint jamais le palier 5. Le cycle déclenche : « palier 4 non confirmé sur M1 ou M2 », car T291-A attend M1=P4 et M2=P5.

## 3. Indices

- Changement récent : T291-A demande M2=P5 dans AX4..AX7.
- Observation opérateur : toggle à 1, descente effective P4/P4, aucun contacteur P5 M2.
- Alarme : défaut AX7 de confirmation du palier de plongée.

## 4. Arbre des causes

| # | Hypothèse | Variable / source | Attendu | Fait | Verdict |
|---|---|---|---|---|---|
| 1 | Toggle non lu | `CfgAutoDiveM2Step5Trial` | TRUE | Le cycle attend P5 et déclenche le défaut associé | Éliminée |
| 2 | Séquenceur demande encore P4 | `WinchM2Cmd.StepTgt` dans `FB_CycleSemiAuto` | 5 | Affecté à `DiveM2StepTgt=5` en T291-A | Éliminée statiquement |
| 3 | Arbitrage M2 remplace la demande | `FB_WinchCmdArbitrationM2.StepTgt` | passthrough | `StepTgt := ReqWinch.StepTgt` en SEMI_AUTO | Éliminée statiquement |
| 4 | Plafond commun borne M2 | `ReqM2Winch.MaxStepDown` | 5 pendant T291-A | Reçoit `M2MaxStepDown`, initialisé par `CommonMaxStepDescent=EffectiveMaxStepDescent=4` | Cause identifiée |
| 5 | Sortie/contacteur physique défectueux | contacteurs M2 | P5 | La demande est déjà bornée à P4 en logique | Non nécessaire au verdict actuel |

## 5. Traçage inverse

```text
TglAutoDiveM2Step5Trial=TRUE
  -> FB_CycleSemiAuto.DiveM2StepTgt=5
  -> ReqProgram.ReqWinchM2.StepTgt=5
  -> FB_WinchCmdArbitrationM2.StepTgt=5
  -> ReqM2Winch.SpeedStepReq=5
  -> ReqM2Winch.MaxStepDown=M2MaxStepDown=4
  -> FB_Winch.ActiveMaxStep=4
  -> FB_SpeedStep borne RequestedStep à 4
  -> M2 reste P4
  -> AX7 attend P5 et déclenche le défaut
```

Résumé : `[demande M2=5] -> [plafond descente M2=4] -> [palier appliqué=4] -> [défaut AX7]`.

## 6. Données et interactions

- `CODE/GVL_PERSISTENT.st` initialise `WinchMaxStepDescent := 4`.
- `PRG_04_Treuils_Benne` propage ce plafond commun vers M1 et M2.
- `FB_Winch` applique mécaniquement ce plafond via `MaxStepNumber := ActiveMaxStep`.

## 7. Conclusion

- **Cause racine** : T291-A modifie la cible M2 et le contrôle AX7, mais n'élève pas le plafond aval propre à M2. La cible 5 est donc écrêtée à 4.
- **Statut** : résolue sur machine ; correction minimale validée par l'utilisateur avec le plafond commun conservé à 4.

## 8. Proposition de correction

- **Option immédiate sans code** : aucune ; relever le paramètre commun autoriserait aussi M1=P5 et élargirait tous les modes, donc à ne pas faire.
- **Correction minimale** : uniquement lorsque `AutoDiveM1Step4M2Step5Active=TRUE`, autoriser `M2MaxStepDown` jusqu'à 5, après application des plafonds généraux, tout en conservant prioritaires les réductions fail-safe (codeurs non fiables, écart synchro, position maintenance, zone basse).
- **Validation reçue** : l'utilisateur demande de conserver le paramètre commun à 4 et d'autoriser M2 à P5.

## 9. Vérification prévue

- T291-A désactivé : P4/P4 inchangé — non-régression CI à finaliser.
- T291-A activé en AX4..AX7 : **PASS machine** — M1=P4 et M2=P5 avec `WinchMaxStepDescent=4`.
- Manuel/maintenance : inchangés.
- Caps de sécurité P1 : toujours prioritaires.
- Défaut AX7 de confirmation P4/P5 : absent lors de l'essai validé.

## 10. Journal

- 2026-09-15 : observation machine reçue ; traçage statique effectué ; cause de plafonnement P4 identifiée.
- 2026-09-15 : correctif ciblé appliqué dans le plafond propre M2 ; protections amont réduites conservées prioritaires.
- 2026-09-15 : validation utilisateur sur machine : paramètre commun à 4, M1 au palier 4, M2 au palier 5 ; fonctionnement jugé conforme.
