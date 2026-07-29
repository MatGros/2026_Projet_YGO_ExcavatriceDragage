# Audit READ-ONLY — Encapsulation Safety/Commandes M1/M2

## 1) Chemin réel commande + safety

**Commande M1/M2** :
`PRG_01 (FB_Joystick)/GVL_IHM boutons → PRG_06_WinchControl (arbitrage manuel/auto/benne, gates sync)
→ instWinchM1/instWinchM2 (FB_Winch, calcule RelayFwd/RelayRev/ContactorX/BrakeCmd)
→ PRG_06 §8 recopie directe dans PRG_10_Outputs.M1RelayFwd... (VAR_INPUT)
→ PRG_10_Outputs (FB_Output) → sorties physiques %QX (M1_RelayFwd_Up_DQ, etc.)`

**Safety M1/M2** :
`PRG_00_Inputs (acquisition + filtre 20ms + normalisation) → PRG_03_Safety (instSafetyWinchM1/M2 = FB_Safety_Winch, calcule SafeStop/ForbidAscent/ForbidDescent/PowerCutOff/ErrorId)
→ PRG_06_WinchControl (relit ces sorties, calcule SafeStopMx_Active avec couplage croisé sync + réinjecte en VAR_INPUT de FB_Winch)
→ FB_Winch applique EffectiveSafeStop sur la rampe et coupe RelayFwd/RelayRev.`

`PowerCutOff` : `PRG_03_Safety.instSafetyWinchM1/M2.PowerCutOff` → agrégé dans `PRG_10_Outputs.PowerCutOffReq` → `instSafetyEmergencyManagement` → `PowerKeepAlive_A/B_RQ` (sorties physiques coupure amont).

## 2) Points où une commande relais peut être écrite/contournée

- **`PRG_06_WinchControl.st:520-545`** — `PRG_10_Outputs.M1RelayFwd := instWinchM1.RelayFwd;` etc. : PRG_10_Outputs expose ces variables en `VAR_INPUT` (donc publiques, écrivables par n'importe quel autre POU) mais **un seul écrivain identifié** (PRG_06 §8). Aucune protection structurelle CODESYS n'empêche un autre PRG d'écrire ces mêmes `VAR_INPUT` — violation potentielle de propriétaire unique si un futur PRG y touche (pas de `private`/README qui l'interdise, seul le commentaire REX 2026-07-07 documente l'intention).
- **`GVL_IHM.M1TreuilRetenue.Bypass.Global` / `.MecaA..E` / `Safety` / `Process`** — bypass safety pilotable directement depuis l'IHM (RETAIN), consommé dans `PRG_03_Safety.st` (BypassGlobal OR BypassMecaX). Aucun garde-fou logiciel visible limitant ces bypass à un mode MAINT_N2 dans PRG_03 lui-même (la restriction de mode doit être imposée en amont côté FB_Safety_Winch — non vérifié ici, hors fichiers audités) : **risque de contournement complet via IHM sans confirmation de mode** si FB_Safety_Winch ne revalide pas le Mode en interne.
- **`GVL_IHM.M1TreuilRetenue.Bypass.Global`** est aussi utilisé directement dans `PRG_06_WinchControl` pour lever `ForbidDescentM1_Raw`/`ForbidAscentM1_Raw` ET pour autoriser `M1_StartStop_Active` en boutons IHM (`OR GVL_IHM.M1TreuilRetenue.Bypass.Global`, ligne ~300) — **double usage du même bypass** (safety ET permission de commande homme-mort) : un opérateur activant Bypass.Global pour désactiver un capteur obtient *en même temps* la possibilité de bouger sans homme-mort joystick. Couplage non intentionnel documenté nulle part.
- **`instSimBench`** (PRG_00_Inputs §0bis) lit en entrée les sorties calculées de PRG_10_Outputs (`M1RelayFwd`, `M1BrakeCmd`...) pour simuler le comportement — dépendance croisée PRG_00→PRG_10 alors que PRG_00 s'exécute en position 0 et PRG_10 en position 10 (donc lit l'état du **scan précédent**, latence 1 cycle non documentée comme risque ici mais cohérente avec le reste du style REX).
- **`PRG_11_Troubleshooting`** est déclaré 100% lecture seule — vérifié : uniquement des affectations vers `GVL_Troubleshooting.*`, aucune écriture sur PRG_00/03/06/10. Conforme.

## 3) Défauts/signaux safety et consommation effective

| Signal | Produit par | Consommé par |
|---|---|---|
| `EmergencyStopOk` | PRG_00 (`instEmergencyStopOk`, PowerContactorEngaged_DI) | PRG_03 (Enable de tous les FB safety), PRG_06 (Enable instWinchM1/M2, instDiveSearch...), PRG_10 (`M1_M2_KoboldMeasureEnable_DQ`, `instSafetyEmergencyManagement`) |
| `EmergencyChain` | PRG_00 | PRG_10 (`M1_M2_KoboldMeasureEnable_DQ`, `instSafetyEmergencyManagement.EmergencyChain`) — **pas consommé par PRG_03/PRG_06 pour couper directement M1/M2** (aucune référence trouvée dans PRG_03/PRG_06 à `EmergencyChain` sauf usage IHM/troubleshooting) → si la boucle AU s'ouvre sans que `EmergencyStopOk` (contacteur puissance) retombe immédiatement, M1/M2 pourraient continuer une fraction de temps avant coupure amont physique (dépend du câblage réel, hors ST) — **à vérifier terrain**, potentiel écart avec doctrine "AU physique indépendant".
| `SlackCableSwitch` | PRG_00 | PRG_03 (`SlackCableDetected := NOT ...`) → `ForbidDescent`, consommé PRG_06 |
| `TopPositionSensor` | PRG_00 | PRG_03 → `ForbidAscent` |
| `BrakeThermalFeedback` | PRG_00 | PRG_03 (3 instances Winch M1/M2/Translation) → `SafeStop`+`PowerCutOff` |
| `M1/M2FwdRevSpeedFeedbackOff` | PRG_00 | PRG_03 (Méca A/C) |
| `M1/M2BrakeFeedback` | PRG_00 | PRG_03 (Méca A/B/D/E), PRG_06 (`instWinchM1/M2.BrakeFeedback`), PRG_11 (diag) |
| `instSafetyWinchM1/M2.SafeStop` | PRG_03 | PRG_06 (`SafeStopM1_Raw`, couplage croisé sync) → `instWinchM1.SafeStop` |
| `instSafetyWinchM1/M2.PowerCutOff` | PRG_03 | PRG_10 (`PowerCutOffReq`) uniquement — **pas relu par PRG_06/FB_Winch** (cohérent : PowerCutOff = coupure amont indépendante, pas censée agir sur RelayFwd directement) |
| `ForbidAscent/ForbidDescent` M1/M2 | PRG_03 | PRG_06 (`ForbidAscentMx_Raw/Active`, couplage croisé) → `instWinchM1/M2.ForbidAscent/ForbidDescent` |

Chaîne globalement cohérente et tracée. Point notable : **couplage croisé synchro (§5bis PRG_06)** ajoute une logique safety supplémentaire *en dehors* de FB_Safety_Winch (dans le PRG lui-même) — dilution de la responsabilité safety hors du FB dédié (violation légère du principe "1 FB = 1 responsabilité").

## 4) Violations POO / propriétaire unique confirmées

- **PRG_10_Outputs.M1RelayFwd/M1RelayRev/... sont des `VAR_INPUT` publics** alimentés par un seul écrivain (PRG_06 §8) mais sans mécanisme empêchant une seconde écriture ailleurs — violation du principe encapsulation stricte (pas de FB propriétaire, juste une convention documentée en commentaire).
- **Logique safety dupliquée hors FB_Safety_Winch** : `SafeStopM1_Raw/Active`, `ForbidAscentM1_Raw/Active`, `SyncMinorDeviationBlocksUp/Down` calculés directement dans `PRG_06_WinchControl` (pas encapsulés dans un FB) — mélange orchestration + décision safety dans un PROGRAM, alors que la doctrine du projet impose FB_Safety_<Metier> comme seul propriétaire du calcul SafeStop.
- **`Bypass.Global` à double rôle** (safety bypass + homme-mort override) dans PRG_06 — un seul flag GVL contrôle deux responsabilités distinctes (sécurité capteurs ET autorisation de mouvement sans homme-mort), violation SRP au niveau donnée.
- **`GVL_IHM` = état mutable partagé global**, lu/écrit par de nombreux PRG (00,03,06,10,11) sans propriétaire unique par variable — modèle GVL/PLC classique, acceptable dans ce paradigme mais à noter comme risque structurel (pas de contrôle d'accès formel).

## 5) Classement

**Bloquant** :
- Aucun défaut fonctionnel confirmé cassant la sécurité machine dans le code lu ; mais **EmergencyChain non relié directement à une coupure SafeStop/PowerCutOff dans PRG_03/PRG_06** mérite vérification urgente (si le seul chemin de coupure sur ouverture AU est `EmergencyStopOk`/contacteur puissance et le hardware AU, à confirmer que ce dernier suffit sans dépendance logicielle).

**Important** :
- `Bypass.Global` double-rôle (safety + homme-mort) dans PRG_06 — à séparer en deux flags distincts.
- Logique SafeStop/Forbid calculée hors FB_Safety_Winch (couplage croisé synchro dans PRG_06) — à encapsuler ou au moins documenter formellement comme extension safety assumée hors FB.
- `PRG_10_Outputs.M1RelayFwd` etc. en `VAR_INPUT` public sans garde d'écriture unique — risque si un futur PRG écrit dessus par erreur.

**Amélioration** :
- Documenter clairement la latence 1-scan `instSimBench` (PRG_00 lit PRG_10 du scan précédent).
- Ajouter un commentaire explicite d'interdiction d'écriture sur les VAR_INPUT PRG_10 ailleurs que PRG_06.
