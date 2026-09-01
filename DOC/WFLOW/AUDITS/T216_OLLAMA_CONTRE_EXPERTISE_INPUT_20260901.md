# Dossier de contre-expertise — T216 permis directionnels uniques

Mission lecture seule. Aucun accès direct au dépôt n'est disponible : les faits suivants sont les seules preuves à évaluer. Ne pas inventer de référence.

## Politique validée

- Un axe et un sens ont un seul permis effectif, positif (`TRUE = autorisé`), effectivement consommé par la commande et projeté identiquement à l'IHM/diagnostic.
- M1/M2 Both : deux départs ou aucun. Les mouvements unitaires et l'action benne M2 sont des exceptions explicites.
- Noms figés : `EffectivePermitM1_Ascent`, `EffectivePermitM1_Descend`, `EffectivePermitM2_Ascent`, `EffectivePermitM2_Descend`, `EffectivePermitM3_Tremie`, `EffectivePermitM3_Maintenance`.
- M3 peut se déplacer jusqu'à P1 sans accès autorisé à la zone Maintenance ; entrer au-delà de P1 doit être explicitement protégé.

## Faits M1/M2

- `FB_Safety_Winch` produit `AscentPermit` et `DescendPermit` par axe.
- `PRG_04` compose `EffectivePermitM1/M2_*`, les affiche et les transmet à `FB_Winch`.
- `FB_Winch` coupe la rampe sur refus directionnel, mais son plancher `MinStepDown` est appliqué ensuite sans condition `NOT EffectiveSafeStop` : test de régression prouve `DescendPermit=FALSE + MinStepDown=1 -> StepNumber=1`.
- `FB_WinchCmdArbitrationM1` bloque un sens synchro ; M2 consomme le même flag en sens inverse. Avec `_SyncSoftStopEnable=TRUE`, une commande Both peut demander un seul treuil, volontairement pour rattrapage.
- Les deux `FB_WinchOutputInterlock` ont des états frein/redémarrage indépendants. Aucun état final commun ne bloque aujourd'hui Both avant les DQ.
- `ArmingPermit` est un OR des quatre permis M1/M2 et de l'état M3 ; il ignore sélection et direction demandées.

## Faits M3

- `FB_Safety_Translation` produit `TremiePermit := NOT LimitSwitchTremie` et `MaintenancePermit := MaintenanceM3TargetEnable AND NOT LimitSwitchMaintenance`.
- `PRG_05` calcule `EffectivePermitM3_Tremie/Maintenance` pour IHM/trace, mais `FB_Translation` reçoit les permis safety bruts.
- `FB_Translation` coupe la rampe vers Trémie si `TremiePermit=FALSE`, mais ne coupe pas le sens Maintenance afin de préserver P1.
- Le gate hauteur et l'interlock final frein peuvent encore stopper en aval sans être reflétés par les permis affichés.

## Benne/cycle

- `ProcessPermitBucket_Open` et `ProcessPermitBucket_Close` sont actuellement tous deux `JoystickDeflected AND DeadmanArmed`.
- Ouverture et fermeture doivent néanmoins rester bornées séparément par leurs fins de course logicielles.
- `FB_Cycle` contient huit `ProcessPermit` presque identiques ; `ProcessPermitM3_Maintenance` est déclaré/calculé mais non consommé.

## Questions de challenge

1. Où séparer sécurité directionnelle, droit process, disponibilité finale et commande sans créer de veto opaque ?
2. Quelle politique sûre pour Both lorsqu'un interlock final n'est pas prêt ou lorsqu'un rattrapage synchro est requis ?
3. Comment préserver P1 sans afficher un permis M3 mensonger ?
4. Quelles exigences IHM, AF, tests CI et conventions de nommage sont indispensables ?
5. Quels risques la proposition sous-estime-t-elle ?

Restituer en français : verdict `BLOCK`, `MAJOR`, `MINOR` ou `PASS`, objections hiérarchisées, décisions exigées et tests de recette. Pas de code.
