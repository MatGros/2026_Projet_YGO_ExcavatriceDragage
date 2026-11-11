# Audit T287 — M3 : commande sans joystick et butées

> 📅 2026-09-14 · 🔒 Analyse seulement : aucun fichier `CODE/` modifié.

## Verdict direct

🟢 Le défaut historique « M3 autorisé sans pilotage joystick, puis butée mécanique » est un
défaut de **chaîne de commande**, pas un défaut propre à `FB_Brake`.

🟠 T287 traite séparément l'escalade d'un mouvement persistant à une butée. Il ne doit pas
absorber une régression de commande sans joystick : celle-ci reste à surveiller comme risque
amont et deviendra une tâche distincte si les tests de chaîne révèlent un trou.

## Historique établi

| Date | Fait | Cause identifiée | Correctif historique |
|---|---|---|---|
| 2026-08-18 | M3 se déplaçait en Semi-Auto sans `Start`, atteignait une extrémité puis escaladait | direction/vitesse dérivées de `SelTarget`; simulation translation ne respectait pas `Start` | gate de direction et vitesse sur `TranslationCmd.Start` (`becb0dc5`) |
| 2026-09-06/07 | corrections cycle/joystick, puis autorisation AX2 dans les deux sens | évolution de la source de commande | permis AX2 séparés vers P1/Trémie et arbitrage M3 refactoré |

Le symptôme peut donc réapparaître lors d'une modification de cycle, d'arbitrage ou de simulation
même si `FB_Brake` est strictement inchangé.

## Chaîne courante analysée

```text
Joystick + homme-mort
  → FB_CycleSemiAuto : TranslationTremiePermit / TranslationP1Permit
  → TranslationCmd.ReqStart (AX2 ou AX14 seulement)
  → FB_TranslationCmdArbitrationM3 : RunRequest / ReqTremie / ReqMaintenance
  → PRG_05 : veto hors AX2/AX14
  → FB_Translation + FB_Safety_Translation
  → FB_TranslationOutputInterlock
  → sorties AC600 M3
```

Preuves dans le code courant :

- `FB_CycleSemiAuto` exige `DeadmanArmed` et axe X seul pour les deux permis translation.
- sa garde continue remet `TranslationCmd.ReqStart := FALSE` dès que le manche ou l'homme-mort
  n'est plus valide.
- `PRG_05_Translation` remet toutes les demandes M3 à faux hors étapes cycle AX2 et AX14.
- la barrière finale `FB_TranslationOutputInterlock` n'émet ni mot variateur ni fréquence sans
  permit directionnel et confirmation de desserrage frein.

## Risques résiduels et non-conformités à corriger plus tard

| Priorité | Constat | Effet | Action |
|---|---|---|---|
| 🔴 | `FB_Safety_Translation` et `FB_Translation` portent chacun une temporisation fin de course différente (1,5 s). | Deux sources d'escalade incohérentes. | T287 : une seule responsabilité, après visa tests. |
| 🔴 | `DriveStatusWord.0` est encore accepté comme preuve de mouvement dans Safety butée. | Faux positif possible variateur prêt mais immobile. | T287 : fréquence réelle seule. |
| 🟠 | `PRG_06_Outputs` a une barrière brute explicite Trémie ; la symétrie Maintenance/P1 reste à démontrer. | Défense finale inégale. | Décision / vérification avant code T287. |
| 🟠 | Les tests actuels ne verrouillent pas toute la chaîne « manche neutre / homme-mort relâché → aucune commande M3 ». | Régression possible lors d'un refactor cycle. | Créer une tâche dédiée si le test de chaîne n'existe pas ou échoue. |

## Décision de périmètre

`FB_Brake` reste **hors cause démontrée et hors modification**. Son ordre de frein ne doit pas
être forcé à faux par une future barrière de butée : la barrière doit neutraliser couple/fréquence,
et le frein garde sa séquence propriétaire.

## Critère de création d'une tâche ultérieure

Créer une tâche C3 « M3 zéro commande sans geste opérateur » si l'un des cas suivants est vrai :

- `ReqStart`, mot variateur ou fréquence M3 deviennent non nuls avec joystick neutre ou homme-mort relâché ;
- une demande cycle survit à une sortie d'AX2/AX14 ;
- la simulation diffère de la chaîne réelle sur ce gate.

