# 🕵️ Session de Troubleshooting — Écart contacteurs vitesse au Top Ascent

> 📅 Date : 2026-09-15 · 🧊 Situation : [SIMULATION BANC] avec risque à confirmer sur [SITE] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé

### Texte de contexte

En pilotage couplé M1/M2, la remontée vers la limite haute logicielle nominale de 7,5 m montre un décalage des contacteurs de vitesse. Les contacteurs de sens et les commandes de frein paraissent, eux, tomber ensemble. L'utilisateur signale sur machine réelle une désynchronisation résiduelle en position haute et une tendance de la benne à chuter lors d'une nouvelle commande. Le référencement, le mode exact et les bypass actifs pendant la trace restent à confirmer avant conclusion terrain.

### Variables & valeurs

| Élément | Variable complète | Valeur | Horodatage trace |
|---|---|---:|---:|
| Position M1 à l'arrêt haut | `M1TreuilRetenue.State.Position_M` | 7,5134 m | 111490 ms |
| Position M2 corrigée à l'arrêt haut | `M2TreuilBenne.Bucket.State.M2PositionCorrected` | 7,0610 m | 111490 ms |
| Écart résiduel M1-M2 corrigé | calcul trace | 0,4524 m | 111490 ms |
| Première coupure vitesse M1 | `M1_SpeedContactor_1_DQ..4_DQ` | FALSE | 110988 ms |
| Coupure vitesse M2 | `M2_SpeedContactor_1_DQ..4_DQ` | FALSE | 111490 ms |
| Coupure sens montée M1/M2 | `M1_RelayAscent_DQ` / `M2_RelayAscent_Close_DQ` | FALSE ensemble | 111490 ms |
| Commande frein M1/M2 | `M1_BrakeRelease_RQ` / `M2_BrakeRelease_RQ` | FALSE ensemble | 111490 ms |

Source : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_53_SimBench_EcartContacteurSpeedTop_20260915.trace`.

## 2. 🎯 Symptôme

En montée couplée, M1 réduit individuellement sa vitesse environ 0,5 s avant M2 au voisinage du seuil haut ; l'arrêt de sens et la retombée des commandes de frein restent atomiques, mais la benne termine avec environ 0,45 m d'écart corrigé dans cette simulation.

## 3. 🧩 Indices / historique

- 🟢 Trace : M1 entre dans la zone de ralentissement à 7,033 m, cohérent avec `CfgCableLimitAscent_M=7.5` et `WinchSlowdownDistanceTop_M=0.5`.
- 🟢 Code : `FB_Winch` calcule `InTopSlowdownZone` par position propre à chaque treuil et applique `SlowdownMaxStep` individuellement.
- 🟢 Trace : M1 coupe ses quatre commandes de vitesse à 110988 ms ; M2 les conserve jusqu'à 111490 ms.
- 🟢 Trace : les relais de montée et les commandes de frein M1/M2 tombent ensemble à 111490 ms.
- 🟢 Code : le frein est structurellement `RelayFwd OR RelayRev` dans `PRG_06_Outputs` ; son synchronisme apparent est donc attendu.
- 🟢 Code : `instSyncContactorFinal : FB_SyncContactor` est appelé avec `Enable := TRUE`, compare les vecteurs finaux et filtre les discordances pendant 500 ms.
- 🟡 La trace ne contient que `RelayFwdMismatch`, pas `Step1Mismatch..Step4Mismatch`, `Data.ContactorMismatch` ni `MismatchLevel` : l'absence d'alarme de contacteur n'est pas encore prouvée par la bonne variable.
- 🟡 Rapport terrain : tendance à la chute au redémarrage après arrêt haut ; aucune acquisition terrain corrélant frein, sens, vitesse et position n'est encore fournie.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Positions M1/M2 différentes à l'approche du haut | positions M1 / M2 corrigée | Écart réel possible, AF-10 §7.3bis | 0,88 m vers 7,0 m puis 0,45 m à l'arrêt | ✅ confirmée en simulation |
| 2 | Ralentissement haut calculé séparément | `InTopSlowdownZone` de chaque `FB_Winch` | Vrai selon la position propre, `FB_Winch` §3 | M1 ralentit ~502 ms avant M2 | ✅ confirmée par code + trace |
| 3 | Sens/freins commandés séparément à l'arrêt | sorties sens/frein M1/M2 | Arrêt Both atomique ; frein = OR sens, AF-10 §2bis | quatre sorties tombent ensemble | ❌ éliminée sur cette trace |
| 4 | `FB_SyncContactor` non activé | appel `instSyncContactorFinal.Enable` | TRUE, `PRG_06_Outputs` §2quinquies | `Enable := TRUE` | ❌ éliminée statiquement |
| 5 | Discordance vitesse tolérée par le debounce | `Step1..4Mismatch`, `ContactorMismatch`, `MismatchLevel` | alarme si discordance maintenue ≥500 ms, fiche FB | durée trace ≈502 ms ; variables absentes | ❓ très probable, à prouver |
| 6 | Simulation seule responsable de l'écart | positions/vitesses et sorties sur site | même architecture de seuils individuels | pas de trace site | ❓ non testée |
| 7 | Chute au redémarrage causée par séquence frein/contacteur | retours freins, contacteurs, vitesse signée, distance de recul | aucun mouvement non maîtrisé, AF-10 §2bis/2ter | pas de trace site | ❓ critique, non testée |
| 8 | Paramètre/persistance/bypass modifie la surveillance | config + bypass M1/M2/synchro | valeurs nominales et bypass FALSE | non capturé | ❓ non testée |
| 9 | Retard de scan masque la discordance | `ContactorMismatch` + chronologie PRG04/PRG06 | propagation N→N+1 documentée AF-02 | non capturé | ❓ à vérifier |

## 5. 📊 Arbre vertical des hypothèses

```text
Commande BOTH montée
├─ positions M1/M2 différentes ✅
│  ├─ seuil ralentissement M1 = TopLimitM1 - 0,5 m
│  ├─ seuil ralentissement M2 = TopLimitM2 - 0,5 m
│  └─ FB_Winch indépendants → paliers différents ~502 ms ✅
├─ arrêt haut M1
│  └─ permits Both → relais sens M1/M2 OFF ensemble ✅
│     └─ BrakeCmd = RelayFwd OR RelayRev → freins OFF ensemble ✅
├─ surveillance contacteurs
│  ├─ FB présent et Enable=TRUE ✅
│  ├─ mismatch paliers instantané attendu ✅
│  └─ debounce 500 ms à la frontière de la durée observée ❓
└─ chute réelle au redémarrage
   ├─ retours freins/contacteurs non corrélés ❓
   ├─ couple avant desserrage/prise mécanique non prouvé ❓
   └─ recul mécanique/élasticité câble non discriminé ❓
```

**Résumé une ligne** : `[BothUp=1] → [M1Pos=7,033] → [M1SpeedContactors=0, M2=1 pendant ~502ms] → [M1Pos=7,513] → [Sens+Freins M1/M2=0] → [Delta≈0,452m]`.

## 6. 📊 Données / interactions & chronogramme

| Événement | Position M1 | Position M2 corrigée | Vitesses M1/M2 | Sens montée M1/M2 | Freins M1/M2 |
|:---:|---:|---:|:---:|:---:|:---:|
| M1 entre en ralentissement, 110988 ms | 7,033 m | 6,150 m | OFF / ON | ON / ON | ON / ON |
| Approche seuil, 111390 ms | 7,413 m | 6,911 m | OFF / ON | ON / ON | ON / ON |
| Arrêt haut, 111490 ms | 7,513 m | 7,061 m | OFF / OFF | OFF / OFF | OFF / OFF |

## 7. 🏁 Conclusion provisoire

- **Cause du décalage simulé prouvée** : le ralentissement haut est calculé par chaque `FB_Winch` à partir de sa propre position ; avec des positions/vitesses différentes, les vecteurs de contacteurs de vitesse divergent avant l'arrêt Both.
- **`FB_SyncContactor`** : présent et activé ; sa réaction n'est pas démontrée par cette trace, car les bits de mismatch de palier et sa sortie de niveau 1 ne sont pas enregistrés.
- **Cause de la chute réelle** : non prouvée. Le décalage final constitue un facteur plausible, mais il faut distinguer commande automate, retour physique frein/contacteur et élasticité mécanique.
- **Statut** : À VALIDER — diagnostic simulation solide, causalité terrain ouverte.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : ne pas conclure à un défaut frein depuis cette trace ; capturer sur site les sorties ET retours physiques lors de l'arrêt/reprise, machine sécurisée et sans personne dans la zone dangereuse.
- **Option 2 (architecture candidate)** : en commande Both, calculer une unique cible de palier et une unique transition de ralentissement à partir de la position de référence M1, puis appliquer exactement le même vecteur de vitesse à M1 et M2. Conserver séparément toutes les surveillances M2 (FDC physique, limite logicielle de secours, dérive/synchronisme, retours contacteurs/frein) et faire gagner immédiatement toute interdiction individuelle sur les deux axes.
- **⚠️ Validation requise** : humaine + automaticien/safety. Toute évolution est au moins C3, potentiellement C4 si elle modifie les barrières de fin de course ou l'escalade `PowerCutOff`.

## 9. ✅ Vérification de la correction / non-régression

- À définir après validation du plan : test Both montée avec écart initial et vitesses M1/M2 différentes ; vecteurs vitesse strictement identiques ; arrêt commun sur M1 ; arrêt immédiat commun sur FDC physique ; escalade si mouvement persistant ; aucun redémarrage automatique après défaut.
- Livrable `fix:` + garde-fou CI `guard:` obligatoire si un bug est confirmé.

## 10. 📝 Journal

- 2026-09-15 : analyse statique du code actif et lecture de la trace CODESYS fournie.
- 2026-09-15 : confirmation du ralentissement individuel M1 puis M2, avec arrêt sens/frein commun.
- 2026-09-15 : confirmation de l'instanciation de `FB_SyncContactor`; preuve live de ses bits de palier encore manquante.

