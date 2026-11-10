# T428 J3 — Maillons ajoutés au snapshot, sans PLC

> 🟡 **Liste modifiée, lecture réelle en simulation à faire par l'exploitant.** Aucune ligne de `CODE/` n'a changé.

## 1. Résultat

| Mesure | Avant | Après |
|---|---:|---:|
| Chemins lus | 571 | **595** (+24) |
| Lots de lecture de 100 | 6 | **6** |
| Chemins non résolus dans le code (contrôle statique) | 0 | **0** |

Fichier modifié : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt`, avec 24 lignes en fin de liste. Le chargeur n'accepte ni commentaire ni titre : la mise en ordre se fera à J4.

⚠️ Ce changement a été embarqué dans le commit `2ccca204` du Veilleur (« checkpoint local changes »), avec la validation J1. Le contenu est correct ; seul le message du commit est trompeur.

## 2. Les 24 ajouts

| Zone | Chemin | Pourquoi |
|---|---|---|
| GÉNÉRAL Puissance | `PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff` | ⚠️ Bypass MES : le PLC ne fait jamais chuter l'AU. Absent jusqu'ici |
| GÉNÉRAL Puissance | `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest` | Bypass de l'auto-test A/B complet |
| M1 / M2 ét. 3 | `PRG_02_Acquisition.Data.EncoderM1/M2.HomedAndReliable` | Codeur disponible, référencé et cohérent |
| M1 / M2 ét. 7 | `PRG_04_Treuils_Benne.SafetyPermitM1/M2_Ascent/Descend` (4) | Vrai permis Safety ; la vue affiche le permis Effective sous ce nom |
| M1 / M2 ét. 9 | `GVL_IHM.IoHw.Out.M1/M2_BrakeRelease_RQ` | Image de la sortie frein physique, forçage N2 inclus |
| M1 / M2 ét. 9 | `GVL_IHM.IoHw.Out.M1/M2_SpeedContactor_2/3_DQ` (4) | Contacteurs de palier absents de la fiche |
| M3 ét. 8 | `PRG_06_Outputs.M3_TremieHardStopActive` | ⚠️ Coupure M3 par fin de course trémie, invisible jusqu'ici |
| M3 ét. 9 | `GVL_IHM.IoHw.Out.M3_CommandWord`, `M3_BrakeRelease_RQ` | Image des sorties physiques ; la vue affiche la demande |
| Couplage | `PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent` | Demandes physiques M1 et M2 cohérentes |
| Couplage | `PRG_04_Treuils_Benne.SyncOperationPermit` | Gate de la synchro ; remplace `H.Idx401`, jamais écrite |
| Benne | `PRG_04_Treuils_Benne.ManualBucketJogActive`, `M2_LimitShift` | Jog benne en maintenance, décalage des limites M2 |
| Cycle | `GVL_Troubleshooting.G_CycleSemiAuto.Idx207/212/222` (3) | Textes de cycle déclarés mais non lus |

`GVL_IHM.IoHw.Out` est recopiée par `PRG_07` à partir des sorties physiques de `PRG_06`. Ce choix est plus fidèle que `PRG_06.Data`. `PRG_07` est le dernier POU (AF-02 l. 371) ; l'ordre de la tâche en ligne reste à confirmer (AF-02 l. 532).

## 3. Contrôles

| Contrôle | Résultat |
|---|---|
| Résolution statique des 595 chemins dans les déclarations ST | ✅ 0 KO ; 3 chemins faux injectés sont bien détectés |
| Table J2 mise à jour : 24 `AJOUT_J3`, `H.Idx401` retirée au profit de `SyncOperationPermit` | ✅ 11/11 |
| Lots de lecture | ✅ 6, inchangé |
| Revue challenge : DeepSeek (sûreté) et gpt-oss (mainteneur) | ✅ 0 ajout faux ; 6 doutes, tous levés à la source (§4) |

## 4. Revue challenge

| Doute soulevé | Vérification à la source |
|---|---|
| `EncoderM2.HomedAndReliable` non montrée | `PRG_02:737`, comme M1 en `:682` |
| `WinchBothFinalRequestsCoherent` « indéterminée » (gpt-oss : FAUX) | Faux : affectée à chaque scan, hors `IF` (`PRG_04:1648-1656`) |
| `ManualBucketJogActive` sans condition de mode | Faux : MAINT_N1 ou MAINT_N2 exigé (`PRG_04:305-306`) |
| Origine du permis Safety | `FB_Safety_Winch:574`, permis de sécurité seul |
| Bypass dépendants de `GVL_BypassRetain` | Exact et voulu : on lit l'entrée appliquée au FB (`PRG_06:495-499`) |
| `IoHw.Out` montre l'ordre, pas le retour terrain | Exact et voulu : étape 9 = ordre, étape 10 = retour par les DI |

Sorties brutes : `generation/revue_ds.md`, `generation/revue_x.md`.

## 5. Reste à faire

| # | Action | Qui |
|---|---|---|
| 1 | Snapshot en simulation (projet normal, Device) : relever « Variables lues X / 595 » et le temps total | Exploitant |
| 2 | Critère : 0 KO. Durée de référence : 1,28 s en lecture réelle pour 541 variables | Orchestrateur |
| 3 | Rejeu des 5 incidents avec les nouvelles valeurs, seulement s'ils sont reproductibles en simulation : les anciens snapshots ne contiennent pas ces valeurs | Orchestrateur |
| 4 | Essai `BATCH_SIZE` : facultatif, inutile tant que 6 lots suffisent | — |
