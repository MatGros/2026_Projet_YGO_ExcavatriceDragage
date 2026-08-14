# TEST_DESIGN — LOT C4 AU / Troubleshooting

## Objectif
Vérifier que la vue `GVL_Troubleshooting.Safety` explique le refus ou la retombée du contacteur sans agir sur la sécurité.

## Essais Watch CODESYS

| ID | Stimulus | Attendu |
|---|---|---|
| C4-001 | Chaîne saine, contacteur ouvert, aucune tentative | `Step1..4=TRUE`, `Step5_ArmingAllowed=TRUE`, `ArmingStep=0`, `ArmingBusy=FALSE`, `PowerContactorEngaged=FALSE`. |
| C4-002 | Front `BtnEmergencyArming` | `ArmingStep` suit `1..6`, `ArmingBusy=TRUE`, puis contacteur confirmé ou `ArmingFailed=TRUE`. |
| C4-003 | Défaut A/B | `RedundancyTestFailed=TRUE`, `ArmingErrorId.0=TRUE`, `LockoutActive` selon temporisation ; aucun réarmement automatique. |
| C4-004 | Demande safety de coupure | `PowerCutOffActive=TRUE` et maintien A/B observables ; aucune écriture issue de Troubleshooting. |
| C4-005 | Contacteur retombé après armement | `PowerContactorEngaged=FALSE`, `Step4_ContactorReleased=TRUE`, cause visible via `ArmingErrorId`, `PowerCutOffActive`, `ArmingFailed` ou état chaîne. |

## Critère de sécurité
La vue est strictement passive. L'essai est interrompu si elle écrit une commande, modifie un interlock ou masque une cause.
