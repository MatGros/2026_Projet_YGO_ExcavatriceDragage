# 🕵️ Troubleshooting — défaut AX3 au rebouclage

Date : 2026-09-06 · Situation : SITE · Statut : À VALIDER

## Contexte et symptôme

En cycle semi-auto, le rebouclage AX2 → AX3 produit `LatchedId=WORD#1024` puis `AX_STAB`.
La trace fournie identifie `StepAtError=AX3_WAIT_DIVE_START` et `instCauses[10]`.

## Arbre des causes

```text
AX3_WAIT_DIVE_START
└─ DiveStartTimeoutTimer.Q après 5 s
   └─ instCauses[10].Active
      └─ Fault.Error → ErrorEdge.Q → AX_STAB
```

Les entrées, sorties, protections PRG04/PRG06 et la condition physique de transition ne
créent pas ce défaut : AX4 reste conditionné par `DiveStartStopTimer.Q`, `DeadmanArmed` et
`JoystickPush`.

## Conclusion et correction

Cause racine confirmée : une attente mécanique normale était transformée en défaut latched
après un délai fixe de 5 s. Correction : timer de sanction désactivé et cause 10 réservée,
sans modifier le contrôle physique d'arrêt ni les modes maintenance.

## Validation

- Maintenir le joystick poussé pendant AX3.
- Attendre plus de 5 s : aucun `WORD#1024`, aucun `AX_STAB`.
- AX4 ne doit démarrer qu'après confirmation arrêt mécanique pendant 300 ms.
- Garde-fou : `G495_check_cycle_sat_contract.py`.

## Journal

- 2026-09-06 : diagnostic sur trace terrain, correction et garde-fou ajoutés.
