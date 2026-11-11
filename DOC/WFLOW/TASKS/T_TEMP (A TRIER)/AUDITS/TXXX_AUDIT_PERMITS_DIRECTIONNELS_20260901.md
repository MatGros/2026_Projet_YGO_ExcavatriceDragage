# Audit C4 — Cartographie des permis directionnels

> Statut : **ANALYSE AVANT MODIFICATION** · 2026-09-01
>
> Règle de décision : aucune modification de `CODE/` ne découle de ce document sans validation humaine du plan et du contrat C4 associé.

## 1. Invariant à satisfaire

> Si l'IHM ou le diagnostic publie « sens non permis », aucune commande motrice ne doit pouvoir être maintenue dans ce sens.

Une information de *capacité de cible* qui ne couvre pas tout un sens ne doit pas s'appeler `...Permit` directionnel : sa portée doit être explicite.

```text
Fait capteur / règle métier
  -> permit safety (producteur unique)
  -> permit process, si une règle process distincte existe
  -> permit effectif par axe et sens
  -> gate de commande du mouvement
  -> barrière finale de sortie
  -> même niveau effectif vers IHM et diagnostic
```

`TRUE` signifie toujours « autorisé » (NC-100). Les niveaux peuvent être distincts ; ils ne doivent jamais contredire la commande réellement appliquée.

## 2. Cartographie réelle — production puis consommation

| Axe / niveau | Producteur et formule | Consommateur de mouvement | IHM / diagnostic | Verdict |
|---|---|---|---|---|
| M1/M2 safety | `FB_Safety_Winch` : `DescendPermit` couvre limite câble, cote câble, limite légale et mou de câble ; `AscentPermit` couvre TOP et limite haute logicielle | `PRG_04` recopie en `SafetyPermitM*_*` | non exposé brut | Cohérent comme source safety |
| M1/M2 process | `PRG_04` : Kobold, benne, vidage trémie, assistance extraction, synchronisation locale | fusionné avec safety | trace distincte | Rôle distinct, justifié |
| M1/M2 effectif | `PRG_04` : `ProcessAndSafetyPermit` + `NOT SafeStop` + couplage synchro | injecté dans `FB_Winch.AscentPermit/DescendPermit` | `ST_SafetyWinch`, IHM et trace | Intention cohérente, mais voir écart C4 §3 |
| M3 safety | `FB_Safety_Translation` : `TremiePermit := NOT LimitSwitchTremie`; `MaintenancePermit := MaintenanceM3TargetEnable AND NOT LimitSwitchMaintenance` | les deux sont passés à `FB_Translation` | non exposé brut | Deuxième signal ne couvre pas tout le sens -1 |
| M3 effectif | `PRG_05` : safety directionnel + `NOT M3_SafeStop_Aggregate` + `NOT PowerCutOff` | **pas consommé directement** par le FB mouvement | IHM, trace et checklist direction | Écart : niveau affiché différent du niveau réellement gaté |
| Cycle | `FB_Cycle` : 8 `ProcessPermit...` tous égaux à `JoystickDeflected AND DeadmanArmed` | commandes Cycle M1/M2/M3 | aucun niveau directionnel | 1 doublon mort M3 maintenance ; sujet T202-C |
| Assistants | `FB_DiveSearch.DescendPermit`, `FB_ExtractionAssist.AscentPermit` | recopiés dans le process treuil PRG_04 | indirect | Ce sont des permissions de séquence, pas des permits safety axe |
| Armement | `PRG_04.ArmingPermit` : au moins un axe disponible, puis `FB_Joystick` | armement homme-mort seulement | diagnostic joystick | Ne pas le confondre avec un permis directionnel |
| Homing | `PRG_02` calcule `HomingPermit` par axe à partir du mode, de la sélection treuil, du TOP et du cycle homing | `FB_Encoder` / `FB_Encoder_Homing` | diagnostic homing | Permission de référencement : hors chaîne de mouvement normal |
| Trace M3 globale | `PRG_05.TranslationTrace.MotionPermitEffective` = SafeStop, puissance, hauteur, variateur, barrière finale et faute FB | aucune — diagnostic uniquement | trace troubleshooting | Ne pas l'utiliser comme permit directionnel : elle ne sélectionne pas un sens |

## 3. Trajets moteur actuels

### M1/M2 — descente

```text
capteurs / limite légale / mou câble
  -> FB_Safety_Winch.DescendPermit
  -> PRG_04 : SafetyPermit + ProcessPermit + synchro = EffectivePermitM*_Descend
  -> FB_Winch : EffectiveSafeStop si permit FALSE
  -> RampTargetStep := 0
  -> [écart] MinStepDown peut ensuite relever RequestedStep à 1
  -> StepShaper -> RelayRev / contacteurs
  -> PRG_06 / FB_WinchOutputInterlock -> sortie physique
```

Preuve compilée : le test ad hoc `TROUBLESHOOT-02` échoue avec `DescendPermit=FALSE`, `StartStop=TRUE`, `Direction=-1`, `MinStepDown=1` : `StepNumber` vaut 1 au lieu de 0. Le contrôle sans plancher passe (`TROUBLESHOOT-03`).

### M3 — vers Trémie (+1)

```text
fin de course Trémie -> FB_Safety_Translation.TremiePermit
  -> PRG_05 : EffectivePermitM3_Tremie (IHM/trace)
  -> FB_Translation.EffectiveSafeStop si TremiePermit=FALSE
  -> rampe 0 -> mot variateur 0 -> interlock final -> sortie AC600
```

Ce trajet est homogène sous réserve des tests de la barrière finale.

### M3 — vers P1 / Maintenance (-1)

```text
MaintenanceM3TargetEnable + fin de course Maintenance
  -> FB_Safety_Translation.MaintenancePermit
  -> PRG_05 : EffectivePermitM3_Maintenance (IHM/trace = FALSE si maintenance interdite)
  -> FB_Translation : le gate exclut volontairement Direction=-1
  -> rampe et mot variateur restent possibles jusqu'à P1
```

Cette exception protège l'accès à P1 quand la zone Maintenance est interdite, mais elle rend faux le libellé « permis directionnel vers Maintenance » dans la checklist lorsqu'il est interprété comme « le sens -1 est bloqué ».

## 4. Non-homogénéités factuelles

1. **M1/M2** : le permit effectif est bien produit et affiché, mais `MinStepDown` le contourne après la gate. Défaut de priorité de commande, prouvé par test.
2. **M3** : l'AF P11 §3bis décrit un gate des deux sens, tandis que le code de `FB_Translation` gate seulement `Direction>0`. C'est une non-conformité AF/code.
3. **M3** : `MaintenancePermit` mélange « accès à la cible Maintenance » et « autorisation de tout le mouvement -1 ». Ce ne sont pas la même chose puisque le trajet jusqu'à P1 reste légitime.
4. **Cycle** : les huit `ProcessPermit...` ne sont ni par axe ni par sens : ils sont tous l'homme-mort. `ProcessPermitM3_Maintenance` n'est jamais lu.
5. **Barrières finales** : elles reçoivent principalement `SafeStop` et une demande de commande ; elles ne refont pas le calcul des permits directionnels. Elles ne compensent donc pas un ordre qui a déjà été réintroduit en amont.
6. **Simulation** : `SimTopPositionActive` est un stimulus capteur réellement consommé par `FB_SimBench`. À l'inverse, M2 est forcé « câble tendu » et les deux champs IHM `SimTopSensorBypassActive` / `SimSlackCableBypassActive` indiquent seulement le domaine simulation actif. Leur nom laisse croire à un bypass de capteur : ils ne doivent pas servir de preuve de la cause d'un permit.

## 5. Étude d'impact des corrections envisagées

| Correction envisagée | Comportement voulu | Risque si mal réalisée | Conservation obligatoire |
|---|---|---|---|
| Gater `MinStepDown` par l'absence d'`EffectiveSafeStop` | une perte de permit descente mène à palier 0 | casser la plongée Kobold nominale | avec permit TRUE, `MinStepDown=1` conserve le palier 1 ; arrêt joystick et SafeStop restent inchangés |
| Gater directement M3 -1 par `MaintenancePermit` | interdire la zone Maintenance | empêche aussi le trajet normal vers P1 | **à exclure** sans séparation de sémantique ; P1 doit rester atteignable si Maintenance est interdite |
| Séparer P1 et Maintenance | rendre le signal exact pour le segment demandé | modifier sélection cible, arrival-lock ou ralentissements | direction, cible, interlocks limite, anti-télescopage et absence de redémarrage auto doivent rester inchangés |
| Dédoublonner `FB_Cycle` | 1 seul homme-mort interne | changer un ordre par erreur de remplacement | valeurs de toutes les sorties Cycle identiques à état égal ; traiter dans T202-C |
| Ajouter garde-fou CI | empêcher la réapparition d'un permit décoratif | faux positifs sur permits de séquence | classifier Safety / Process / Effectif / Armement avant toute règle statique |

## 6. Matrice minimale de recette avant tout déploiement

| Cas | Attendu non négociable |
|---|---|
| M1 seul, M2 inhibé, descente, permit M2 tombe | `StepNumber=0`, relais descente retombé selon la temporisation de sortie, aucune reprise tant que permit faux |
| M1/M2, plongée Kobold, permit vrai | palier minimal conservé, pas de régression de recherche fond |
| M1/M2, relâche joystick | arrêt normal, aucun maintien indéfini du relais de sens |
| M3 vers Trémie, permit Trémie faux | rampe et mot variateur à 0 |
| M3 vers P1, Maintenance interdite | trajet P1 autorisé et arrêt à P1 |
| M3 demande Maintenance, Maintenance interdite | aucun franchissement P1 vers Maintenance ; IHM décrit exactement le blocage |
| M3 défaut / SafeStop / PowerCutOff | les deux sens indisponibles et pas de redémarrage automatique |
| Simulation | TOP reste stimulus granulaire ; absence de stimulus mou câble est documentée, jamais masquée comme un bypass réel |

## 7. Décisions humaines requises avant contrat de correction

1. Valider la sémantique cible : `MaintenancePermit` signifie-t-il « zone Maintenance accessible » (recommandé), ou « tout déplacement -1 autorisé » ?
2. Si la première définition est retenue : valider l'ajout d'un permis de mouvement -1 dépendant de la cible/du segment, distinct du permis d'accès à la zone Maintenance.
3. Valider le correctif C4 M1/M2 : le plancher ne peut jamais vaincre un permit ou un SafeStop.
4. Valider le découpage : C4 mouvement/permits puis T202-C bit-identique ; pas de grand refactor unique.

## 8. Références de preuve

- `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` §3 ; `CODE/H_TREUILS_BENNE/FB_Winch.st` §3 et §5.
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` §5bis, §6, §7 ; `CODE/M_MAIN/PRG_06_Outputs.st` §2.
- `CODE/I_TRANSLATION/FB_Safety_Translation.st` §3 ; `CODE/I_TRANSLATION/FB_Translation.st` §4bis-§6 ; `CODE/M_MAIN/PRG_05_Translation.st` §0-§4.
- `CODE/G_CYCLE/FB_Cycle.st` ; `DOC/WFLOW/TASKS.yaml` T202-C et T204.
- `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md`, `AF_Partie-11_Fonction_Translation_v2.3.md`, `AF_Partie-13_Fonction_Simulation_v2.5.md`.
