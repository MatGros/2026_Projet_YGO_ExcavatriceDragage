# T428 J5 — Guide de dépannage dans CODESYS

> 🟡 **Écrit, challengé, jugé à la source. Import et compilation CODESYS à faire par l'exploitant.** Contrat : [TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE](../../CONTRACTS/TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.md).

## 1. Livrable

| Élément | Valeur |
|---|---|
| Objet | `CODE/J_SUPERVISION/FB_TroubleshootingGuide.st`, FB `light`, appelé par `PRG_07` |
| Contenu | Sommaire, mode d'emploi, général, M1, M2, M3 en 10 étapes, fonctions, 25 cas par symptôme |
| Taille | 830 lignes de commentaires, 324 chemins cités |
| Garde-fou | G531 : chemins et noms abrégés présents dans la liste et le code, sections, 10 étapes, texte sans date ni commentaire bloc |
| Effet machine | Aucun : `Ready := Enable;` |

## 2. Chaîne de fiabilité

| Étape | Agents | Résultat |
|---|---|---|
| Rédaction | 5 DeepSeek, dossiers de faits extraits du code | 247 variables, 25 cas ; 74 chemins hors snapshot corrigés |
| Challenge 1 | GLM mainteneur, gpt-oss automaticien | 140 points, 104 faux : brief non évaluable |
| Challenge 2 | DeepSeek, gpt-oss ; citation exacte obligatoire, filtre mécanique | 32 points, 13 justes |
| Juge natif 1 | Claude, à la source | 223 corrections ; erreurs graves trouvées (§3) |
| Panel d'experts | Automaticien, mainteneur, sécurité machine, conducteur | 204 points ; juge natif 2 : 39 vrais, 14 partiels, 151 faux ; 39 corrections |

Leçon : un challenge sans définition stricte des types et sans preuve exigée produit surtout du bruit. La citation exacte du dossier, contrôlée par script, rend le challenge évaluable.

## 3. Erreurs graves corrigées avant livraison

| Variable | Erreur du brouillon |
|---|---|
| `L.Demandes_200.Idx208_BypassNetworkActive` | C'est le bypass global M3, qui ignore toutes les sécurités de la translation, pas un bypass réseau |
| `C_Safety.LockoutActive` | Valeur saine inversée |
| `C_Safety.Step5_ArmingAllowed`, `Step4_ContactorReleased` | FALSE est normal machine armée |
| `D_Joystick.DeadmanArmed` | L'armement se fait par appui maintenu, indépendamment du manche |
| `I.Safety_300.Idx330_BypassGlobalCommun` | Ce bypass n'est relayé à aucune sécurité (`PRG_04:972,1040`) |
| `I.Safety_300.Idx308_SlackCableBypassActive` | Il lève une dizaine de surveillances, pas seulement le mou de câble |
| Bypass, simulation, bypass AU d'ingénierie | Toujours signalés « à faire retirer par le responsable » |

## 4. Rejeu (AC6)

Même protocole que J1 à J4 : 5 incidents, 3 modèles, 15 diagnostics, deux passes, guide injecté dans le prompt.

| Mesure | Résultat, plus faible passe | Seuil proposé, non validé |
|---|---:|---:|
| Cause trouvée | **0 / 15** | 9 / 15 |
| Maillon bien situé | **2 / 15** | 12 / 15 |

❌ **Seuils manqués, publiés sans modification.** Le guide n'améliore pas le diagnostic des modèles sur les anciens snapshots. Ces snapshots ne contiennent ni les vraies valeurs ajoutées à J3 (sorties réelles, bypass AU, hard stop M3, vrais permis Safety) ni les corrections du lot 1 : le rejeu ne peut pas mesurer ce que J3 apporte. La mesure utile sera faite à J6, sur pannes injectées en simulation avec la liste J4.

## 5. Constats hors périmètre, à traiter à part

| Constat | Preuve | Proposition |
|---|---|---|
| `P_MotionM3.RequestedDirection` publie trémie = 1, maintenance = 0, repos = -1, contre +1 / -1 / 0 annoncés | `FB_TroubleshootingView.st:683-684`, `ST_MotionChecklist.st:20` | Tâche `fix:` + `guard:` ; le guide décrit les valeurs actuelles |
| `Commun.Bypass.Global` non relayé alors que le commentaire annonce un OR | `PRG_04_Treuils_Benne.st:971-972,1040` | Trancher : bypass mort à retirer ou câblage manquant |
| Commentaires de déclaration périmés : MANUEL, « Armer via Reset », bouton M1 pour M2, paliers 0..4 | `ST_ChainContextGlobal`, `ST_MotionChecklist`, `ST_HomingChecklist` | Corriger les commentaires |
| Polarité `TremieFull_OR_GateRaised_DI` à confirmer au câblage | `PRG_05:177` | Essai terrain |
