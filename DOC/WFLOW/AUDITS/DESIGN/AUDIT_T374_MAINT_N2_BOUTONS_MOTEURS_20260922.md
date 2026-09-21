# 🔴 T374 — audit MAINT_N2 boutons moteurs — 22/09/2026

## Verdict

Les six boutons IHM M1/M2/Both montée/descente sont déclarés, mais ne commandent aucun moteur dans `CODE/`. Leur seul lecteur est l'indicateur `ActiveForcing` de `PRG_07_Supervision.st:705-710`. La recherche sur l'ensemble de `CODE/` ne trouve aucune lecture dans `PRG_04_Treuils_Benne.st` ni `PRG_06_Outputs.st`. La présence du bouton et de l'indicateur ne prouve donc aucun mouvement.

## Chaînes relevées

| Fonction | Source | Consommateur final constaté | Verdict |
|---|---|---|---|
| M1/M2/Both × montée/descente | `ST_MaintenanceN2Cmd.st:9-14` | `PRG_07_Supervision.st:705-710` (`ActiveForcing`) | Rupture avant arbitrage moteur et sorties |
| Frein M1/M2/Both | `ST_MaintenanceN2Cmd.st:21-23` | `PRG_06_Outputs.st:320-331`, puis sorties `:375/:384` | Branche active, distincte du mouvement moteur |

Le frein est gardé côté PLC par `MAINT_N2`, chaîne AU fermée et contacteur de puissance engagé (`PRG_06_Outputs.st:320-329`). `AF_Partie-05_Modes_Maintenance_v2.1.md:168-170` attribue le mot de passe à l'IHM ; aucune vérification du mot de passe n'a été trouvée dans cette branche PLC. Le desserrage seul peut provoquer un mouvement gravitaire sous charge : procédure mécanique dédiée avant essai réel.

## Six cas de référence en simulation

En MAINT_N2, bouton maintenu puis relâché : `M1+`, `M1−`, `M2+`, `M2−`, `Both+`, `Both−`. Pour chacun, relever demande, relais de sens, palier 1, frein et sorties finales des moteurs visés, puis vérifier arrêt et absence de reprise spontanée au retour des permissions. Ajouter AU, sortie de N2, défaut, commandes opposées simultanées et coexistence joystick/cycle.

Ces six cas ne peuvent pas être déclarés verts avec le code actuel. Les résultats CODESYS et machine restent à mesurer par l'utilisateur après correction validée.

## Décisions avant plan de code

1. Matrice exacte des protections conservées en MAINT_N2 malgré la demande « quasiment sans interdiction ».
2. Politique de demandes contradictoires, de coexistence joystick/cycle et de frein desserré seul.
3. Homme-mort, maintien des boutons IHM, perte de communication et reprise après défaut.

T259 est historiquement marqué `✅` et « validé machine » dans `TASKS.yaml:4127+`, mais son critère moteur est contredit par le code actuel. Conserver cette contradiction comme anomalie de traçabilité jusqu'à revue des preuves d'essai ; T273 (cinématique maintenance) est distinct.

Phase A uniquement : aucun fichier `CODE/`, bundle ou test CI modifié. Contrat : `TASK_CONTRACT_T374_MAINT_N2_AUDIT.yaml`.
