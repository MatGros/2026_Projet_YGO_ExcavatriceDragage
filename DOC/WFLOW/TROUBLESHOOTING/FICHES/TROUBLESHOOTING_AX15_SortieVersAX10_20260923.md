# 🕵️ Session de Troubleshooting — sortie AX15 vers AX10

> 📅 Date : 2026-09-23 · 🧪 Situation : [SITE MACHINE RÉELLE — rapport utilisateur] · 📄 Statut : **CAUSE LOGICIELLE STATIQUE ÉTABLIE ; déclencheur terrain à horodater**

## 1. 🧊 Contexte figé

- Symptôme rapporté : le cycle passe de l’ouverture/fermeture de benne en `AX15` vers `AX10`, comportement déclaré inédit et non souhaité.
- Règle métier rapportée : hors retour vers P1, le G7 doit quitter le cycle vers `MANU`, non rejoindre `AX10`.
- Valeurs PLC horodatées au moment de l’évènement : **non fournies**. Aucune valeur n’est supposée.

## 2. 🎯 Symptôme

Transition non désirée `AX15B_DUMP_OPEN → AX10_CLOSE_BUCKET` en cycle semi-auto.

## 3. 🧩 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision / preuve | Valeur attendue | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Le G7 contient une transition directe AX15B → AX10. | `FB_CycleSemiAuto`, transition d’état. | Aucune si la règle métier exclut ce retour. | `IF DeadmanArmed AND JoystickPull THEN State := AX10_CLOSE_BUCKET`. `CODE/G_CYCLE/FB_CycleSemiAuto.st:1554-1569` | ✅ **Établi statiquement** |
| 2 | Un tirage Y+ sous homme-mort a déclenché cette transition sur site. | `DeadmanArmed` et `JoystickPull` au scan du saut. | Les deux `TRUE` pour la transition AX15B → AX10. | Non acquis. `JoystickPull` vient de `AxisY.DirectionPositive` : `CODE/M_MAIN/PRG_03_Modes_Cycle.st:212-215`. | ❓ À tracer |
| 3 | Un forçage IHM a placé AX10. | `GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt`. | `10` au scan du saut. | Non acquis. La valeur 10 cible explicitement AX10 et le forçage ne porte aucune garde de contexte : `CODE/G_CYCLE/FB_CycleSemiAuto.st:728-782`; entrée IHM : `CODE/M_MAIN/PRG_03_Modes_Cycle.st:205,282`. | ❓ À tracer |
| 4 | La sortie du SEMI_AUTO a réinitialisé le cycle vers AX10. | Branche `NOT Enable`. | État conservé en pause, commandes neutralisées. | Le code mémorise l’état courant dans `PausedState` et n’écrit pas AX10 dans cette branche : `CODE/G_CYCLE/FB_CycleSemiAuto.st:664-725`. | ❌ Éliminée statiquement |
| 5 | AX15A ou AX15C possède une sortie directe vers AX10. | CASE AX15A / AX15C. | Aucune. | AX15A ne sort que vers AX15B (`:1519-1532`) ; AX15C ne sort que vers AX15B (`:1603-1608`). | ❌ Éliminée statiquement |

## 4. 🗺️ Transitions effectives AX15

```text
AX15A
  └─ [neutre vu, puis DeadmanArmed + JoystickPush] → AX15B

AX15B
  ├─ [DeadmanArmed + JoystickPull] → AX10       ← chemin identifié
  ├─ [RepositionRequest] → AX15C
  └─ [DeadmanArmed + JoystickPush + Benne_Done + Benne_IsOpen] → AX18

AX15C
  └─ [NOT RepositionRequest] → AX15B

Tous états, hors porte de sécurité
  └─ [SetForceStepTgt = 10] → AX10

Sortie SEMI_AUTO / sécurité / défaut codeur
  └─ commandes neutres + mémorisation de l’état en pause ; pas de transition écrite vers AX10.
```

Sources : `CODE/G_CYCLE/FB_CycleSemiAuto.st:664-725`, `:728-801`, `:1519-1575`, `:1603-1608`.

## 5. 📊 Acquisition minimale nécessaire (une trace événementielle)

Pour attribuer le saut vu sur site sans interprétation :

1. `GVL_Troubleshooting.G_CycleSemiAuto.Idx206_Step`
2. `GVL_Troubleshooting.G_CycleSemiAuto.Idx104_DeadmanArmed`
3. `PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive`
4. `PRG_02_Acquisition.Data.Joystick.AxisY.DirectionNegative`
5. `GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt`
6. `GVL_Troubleshooting.G_CycleSemiAuto.Idx108_AbortCycleRequest`
7. `GVL_Troubleshooting.G_CycleSemiAuto.Idx215_WaitingResume`

Les variables 1, 2, 6 et 7 sont exposées dans la liste de snapshot : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt:133,137,147,154`. Les variables 3 à 5 ne le sont pas dans cette liste : une trace CODESYS est donc nécessaire pour capturer l’évènement court, pas un snapshot isolé.

## 6. 🏁 Conclusion

- **Cause du chemin AX15B → AX10 dans le code : établie.** La condition est `DeadmanArmed AND JoystickPull` et la transition est explicite (`CODE/G_CYCLE/FB_CycleSemiAuto.st:1567-1569`).
- **Cause de l’évènement terrain précis : non encore prouvée.** Les deux déclencheurs à départager sont le tirage Y+ sous homme-mort et un forçage IHM à valeur `10`.
- **Aucune modification de code, de forçage PLC ou de bypass réalisée.**

## 7. 📝 Journal

- 2026-09-23 : analyse statique de toutes les sorties AX15 et des chemins génériques de transition vers AX10.
