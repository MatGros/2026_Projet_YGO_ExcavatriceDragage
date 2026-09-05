# Registre d'actions — LOT C4 AU / Troubleshooting

| Date | Action | Résultat |
|---|---|---|
| 2026-08-14 | Contradiction constatée : `Step4_ContactorRedundancyOk` recopiait le retour contacteur. | Corrigé en `Step4_ContactorReleased`. |
| 2026-08-14 | Préconditions AF01 absentes de la vue unique. | Étape, verrouillage, erreur, coupure et maintiens A/B ajoutés en lecture seule. |
