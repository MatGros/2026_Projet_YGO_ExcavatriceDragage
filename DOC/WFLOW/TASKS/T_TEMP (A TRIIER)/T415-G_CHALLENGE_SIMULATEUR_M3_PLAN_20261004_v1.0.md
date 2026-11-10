# 🧪 Challenge — Plan simulateur M3 (2026-10-04)

> Challenger indépendant, lecture seule, sur `DOSSIER_SIMULATEUR_M3_ETAT_ET_PLAN_2026-10-04.md`.
> Verdict : 🟠 **GO avec réserves** — lot V partable après correction des critères ; lot M incomplet.

## Constats du dossier
| Id | Statut | Preuve |
|---|---|---|
| Règle capteurs corrigée | ✅ | `FB_Sim_Translation_ExtLink.st:270-276` |
| Littéral loopback / types | ✅ | `ExtLink.st:222`, `:50` |
| V1 fenêtre 2 s | ✅ | `app.py:42`, `Main.qml:441-442` |
| V2 capture jamais déclenchée | ✅ pire que décrit | seuils codés `-0.299/30.299` (`app.py:145-146`) ; trace `060611` : 0 butée sur 699 042 échantillons, max 30,165 m |
| V3 style Qt | ✅ cause | aucun style imposé (`Main.qml:1-3`) |
| M1 vitesse non nulle en butée | ✅ | `M3_POC.mo:260` (vitesse avant bornage `:218-224`) |
| M1 drapeau butée | ✅ cause | `M3_POC.mo:271-272` dépend de `direction.y` |
| M2 délais frein | ⚠️ infirmé | ouverture réelle **0,60 s** (1er ordre seuil 95 %, `M3_POC.mo:78-80`), fermeture ~5 ms |
| M3 override écrasé | ✅ | `FB_SimBench.st:625-637` puis `:664-665` |

## Problèmes du plan
| Id | Gravité | Constat | Recommandation |
|---|---|---|---|
| P1 | 🔴 | Frein FMU irréaliste : vitesse multipliée par l'état frein (`M3_POC.mo:249`), frein fermé à la retombée de commande → arrêt 0,4 m/s→0 en 10 ms à la Trémie | Garde fermeture ≤ 0,5 Hz, délai fixe, contact auxiliaire 10 ms, décélération libre (`FB_Sim_TranslationBrake.st:69`) ; **pas de synthèse V2 avant** |
| P2 | 🔴 | Butées 0/30 sans déplacer les capteurs (FMU 30 m strict, interne 0,05/29,95 m `FB_Sim_Translation.st:127,135`) → chaque accostage Maintenance finirait en butée | Capteurs 0,05/29,95 m + critère « accostage nominal sans butée » |
| P3 | 🟠 | Vue : butées codées en dur | Butées issues de la FMU / config unique + test de non-régression |
| P4 | 🟠 | Parité incomplète : décel 25 vs 20 Hz/s, τ variateur 0,15 s, statut 0x87 conditionné au frein, contact frein, charge suspendue, glissement, bruit, intermittence, blip, défaut frein, recul | Matrice de parité paramètre par paramètre (aligné / reporté / non pertinent) |
| P5 | 🟠 | Le lien rejette les mots capteurs incohérents → impossible de tester la détection PLC | Ne valider que l'intégrité de trame ; transmettre les capteurs bruts (décision Q3) |
| P6 | 🟠 | Critère V2 non représentatif (trace `060611` : 3 mouvements, pas de Trémie ni butée) | Rejouer aussi `033319` + scénario butée synthétique, valeurs attendues figées |
| P7 | 🟡 | Hz mesurée oscille ±0,2 Hz (limiteur de pente, pas 10 ms) | Rampe explicite ou filtrage vue |
| P8 | 🟡 | 40/50 Hz mal posé : l'interne recalcule la consigne | FMU suit la consigne réelle ; exclu de la parité |
| P9 | 🟡 | Critères V3 et M2 non outillés | Préciser outil, signaux, tolérances ; M3 doit passer `G502_check_simbench_m3_boundary.py` |

## Manques (mise en service)
Synthèse d'accostage : début du ralentissement (50→20 Hz), distance/durée en petite vitesse, délai front→retrait commande, délai retrait→frein serré, écart position PLC/réelle, fréquence à la fermeture du frein · colonne trace « commande frein PLC » (`Tx[14]`) · définition du déclencheur « arrêt complet » et cas d'inversion sans arrêt · ordre : V1 → V3 → M1+M2 → V2 → M3.

## Hors périmètre signalé
À la Trémie, le PLC retire la commande frein à 19,6 Hz (trace `033319`), à la Maintenance il attend l'arrêt variateur. Voulu (coupure extrémité) ou défaut PLC : non vérifié.

## Questions
1. Le frein réel peut-il retomber variateur en marche (Trémie) ? 2. FMU suit la consigne réelle jusqu'à 50 Hz ? 3. Le lien transmet-il les mots capteurs incohérents ? 4. Capteurs FMU 0,05/29,95 m, butées 0/30 m ? 5. Colonne « commande frein PLC » dans la trace avant V2 ?
