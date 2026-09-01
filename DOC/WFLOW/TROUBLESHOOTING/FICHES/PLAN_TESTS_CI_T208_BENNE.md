# 🧪 PLAN DE TESTS CI — T208 : cohérence ActiveOffsetM / état benne (faux MecaE)

> 📌 **Document de préparation** — décrit les TC bloquants à ajouter à
> `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st`
> **PAS encore écrits dans le .st** : ils dépendront de l'implémentation T208 finale.
> 🔌 Fiche : `DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md`
> 📄 Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T208_COHERENCE_BENNE.yaml`

## Contexte test actuel
- Le `test_fb_bucket.st` courant utilise `CoherenceLimitM = 5.0` (config locale).
- ⚠️ **Discordance confirmée (3 valeurs)** : 0.05 (AF_Partie-10:281) / 1.0 (GVL_PERSISTENT:70) / 5.0 (test_fb_bucket.st:7).
- **Valeur visée : 1.0** (visa humain V2 requis — voir §Points bloquants doc).

## TC bloquants (issus challenge T175 §4 — à ajouter)
| TC | Scénario | Préconditions | Assertions |
|---|---|---|---|
| **T2** | Boot : `IsOpen=TRUE` ET `IsClosed=TRUE` | Enable, Homed, position | `StateIncoherent=TRUE`, `ActiveOffsetValid=FALSE` ; au 1er mouvement pas de consigne 15m |
| **T3** | Boot : position réelle hors fenêtres → contradiction position/RETAIN | `CablePosM2` hors `[LastPosM2Open/Close ± CoherenceLimitM]` | `StateIncoherent=TRUE`, `ActiveOffsetValid=FALSE`, `IsOpen/IsClosed` non réécrits |
| **T5** | `M1_Busy` en BUSY | demande d'avortement | avortement + coupe M2 + latch |
| **T6** | `M2_Busy` en BUSY | demande d'avortement | **PAS d'avortement** (non-régression TC-P10-025.2) |
| **T7** | Refus BusyEdge | CloseReq/OpenReq pendant Busy | désarmées (aucun engagement différé) |

## TC de non-régression / AC1-AC9 (contrat T208)
| Id | Objectif | Assertion clé |
|---|---|---|
| AC1 | Boot hors-fenêtres | `StateIncoherent=TRUE`, `ActiveOffsetValid=FALSE`, sans réécrire IsOpen/IsClosed |
| AC2 | Boot TRUE/TRUE | `StateIncoherent=TRUE` (déjà TC-P10-047.2) |
| AC3 | `BucketStateCoherent := NOT StateIncoherent` | gate StartStop, PAS SafeStop |
| AC4 | Gate sur `HomedM1 AND HomedM2` | redondance avec Cause 4 tranchée |
| AC5 | Invariant anti-circulaire | grep `DeltaPosition_M` → 0 écriture vers IsOpen/IsClosed |
| AC8 | IHM StateIncoherent | message + action re-confirmation |
| AC9 | Non-régression | `TC-P10-023..048.1`, `T196-001/002` verts |

## Commande d'exécution (quand le .st sera rempli)
```powershell
python TOOLS/TEST_AUTO_CI/run_tests.py --domain H_TREUILS_BENNE
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
```

## ⚠️ Coordination
- Config `CoherenceLimitM` : 3 valeurs → mettre les 3 sources à l'identique (`1.0`) APRÈS visa V2.
- `test_fb_bucket.st` à mettre à jour pour utiliser `CoherenceLimitM = 1.0` (cohérent avec la cible).
