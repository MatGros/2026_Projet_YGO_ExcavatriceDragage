# T300 — Test Design SimBench M3

Statut : oracles pré-code. Les tolérances marquées `R0` seront chiffrées après identification matérielle ; les tests correspondants restent `BLOCKED_DATA`, jamais artificiellement PASS.

## Tests composants

| TC | Exigence | Stimulus | Oracle mesurable |
|---|---|---|---|
| TC-T300-DRV-010 | Retard boucle | Changement sortie finale au scan N | aucune réaction SimBench en N ; prise en compte en N+1 ± un scan |
| TC-T300-DRV-020 | Rampe fréquence | 0→40 Hz puis 40→0 Hz | pente nominale 20 Hz/s, chaque pente dans [18;20] Hz/s, plateau 40,00 Hz ±1 LSB PDO |
| TC-T300-DRV-025 | Passage GV→PV | retour initial 28,29 Hz, cible 10 Hz | cible 10,00 Hz dès DI PV=FALSE ; convergence en 1,09 s ±0,20 s avec pente 16,8 Hz/s |
| TC-T300-DRV-027 | Réponse variateur | échelon/rampes connus, pas 10 ms et 100 ms | premier ordre tau=0,15 s ; erreur à chaque point ≤1 LSB + erreur discrétisation calculée |
| TC-T300-DRV-030 | Charge distincte fréquence | même consigne, vide puis chargé | fréquence PDO conforme à sa sémantique ; vitesse mécanique/position peuvent diverger selon modèle, erreur estimateur mesurée |
| TC-T300-DRV-040 | StatusWord | séquence arrêt/marche/défaut | chaque bit suit la table constructeur R0 ; aucun bit dérivé directement de la seule demande |
| TC-T300-DRV-050 | Pas d'intégration 100 ms | tâche VISU_TASK ou cycle simulé de 100 ms | rampe 20 Hz/s : progression de 2 Hz par cycle, sans ralentissement artificiel ; délais sub-100 ms exclus de cette preuve |
| TC-T300-BRK-010 | Desserrage | front `ReleaseCmd` | bobine, ouverture mécanique, contact dans cet ordre ; chaque délai dans `[Cfg; Cfg+Δt]` |
| TC-T300-BRK-020 | Serrage/perte puissance | fréquence atteint zéro puis ordre retombe | fermeture/contact après 80–100 ms, jamais avant 80 ms ; perte puissance testée séparément |
| TC-T300-BRK-025 | Desserrage | ordre de marche avec fréquence nulle | ouverture dans [0;100] ms ; commande électrique, état mécanique et contact traçables séparément |
| TC-T300-BRK-030 | Pannes | bloqué fermé puis ouvert | mouvement interdit ou arrêt/fault observé conformément aux blocs de production ; défaut détecté |
| TC-T300-MEC-010 | Équilibre | zéro excitation, états nuls | dérive ≤1 mm/60 s, énergie non créée |
| TC-T300-MEC-020 | Convergence | scénario identique à h et h/2 | position max diff ≤1 mm, transitions capteurs diff ≤Δt |
| TC-T300-MEC-030 | Pendule synthétique | L=1 m puis 2 m, faible angle | période proche de `2π√(L/g)` à tolérance numérique R1 ; amortissement décroissant |
| TC-T300-MEC-040 | Couplage charge | accélération vide/chargé | réaction modifie la trajectoire sans ajout direct de l'angle aux capteurs |
| TC-T300-SEN-010 | Table capteur | balayage lent dans deux sens | polarité/fenêtre/hystérésis conformes à la table R0, fronts comptés une fois |
| TC-T300-SEN-020 | Recroisement | arrêt près seuil avec oscillation | DI suit chaque franchissement mécanique échantillonné, aucune transition inventée |
| TC-T300-SEN-030 | Intermittence | profil synthétique graine fixe | ≥2 transitions, dernière ≤1 s+Δt, stabilité 2 s ; 3 replays identiques |
| TC-T300-SEN-031 | Recroisements pendant épisode | franchissements alternés avant la fin d'un épisode | le chronomètre ne redémarre pas sur ses propres recroisements ; extinction ≤ durée configurée + Δt |
| TC-T300-SEN-040 | Impulsion sous-scan | impulsion <Δt déphasée | capture seulement si présente au scan d'acquisition ; aucune capture idéale |

## Tests intégration et estimateur

| TC | Scénario | Oracle |
|---|---|---|
| TC-T300-INT-010 | Simulation OFF/ON/OFF | réel et simulé jamais mélangés ; HOLD mécanique ; stimuli remis au repos |
| TC-T300-INT-020 | Override ON puis OFF, deux sens | DI forcées pendant override ; mécanique continue ; reprise DI courantes sans saut de position |
| TC-T300-INT-030 | Ordre amont bloqué par interlock | sortie finale nulle, drive non excité, position vraie immobile hors dynamique résiduelle |
| TC-T300-INT-040 | Extrême Trémie puis Maintenance | arrêt directionnel même scan de consommation ; sens de dégagement disponible ; escalades aux délais réels |
| TC-T300-INT-050 | Oscillation capteur | tous fronts traversent HwSim→HwIn→decoder→mémoires ; incohérences traitées par le code existant |
| TC-T300-EST-010 | fréquence/position chargée | `e=x_est-x_true`, RMS/max produits ; limites R0, aucun oracle tiré de l'estimateur |
| TC-T300-EST-020 | fronts répétés près seuil | recense chaque recalage ; détecte recalages multiples indésirables, attendu métier à valider R0 |
| TC-T300-EST-030 | deux sens, cinq capteurs | front physique utilisé pour recalage explicitement défini par capteur/sens ; écart après recalage mesuré |
| TC-T300-MUT-010 | 8 mutations Q13 injectées une à une | chacune fait échouer au moins un TC nommé ; aucun survivant inexpliqué |

## Matrice d'intégration

Campagne minimale : `2 sens × 2 charges × 3 régimes × 4 perturbations = 48 scénarios`. Chaque scénario publie graine, configuration, pas, commandes finales, fréquence, frein électrique/mécanique/contact, position/vitesse vraie, angle, cinq DI, mot décodé, position estimée, erreur et verdict. Robustesse : 100 graines, bornes respectées et premier échec conservé.

Couverture automatique actuellement executable : `TC-T300-CAM-100` parcourt les 4 800 cas (48 profils synthétiques × 100 graines) et controle à chaque pas les bornes de course, les bornes du retour variateur et, hors intermittence explicitement demandée, le mot thermometre. La trace CODESYS reste necessaire pour les memoires/decodeur/estimateur reels et la calibration terrain.

## Règles d'indépendance

Les TC et oracles sont revus avant ST. Un échec de code ne permet pas de changer l'attendu. Une correction d'oracle exige la preuve de l'erreur, l'ancien/nouveau résultat et un visa. `ASSERT_TRUE(TRUE)` reste un rappel manuel et ne compte jamais comme preuve automatisée. Les rapports existants ne constituent une baseline qu'après exécution fraîche.

## Gates d'entrée en code

- R0 : questions matérielles résolues ou profil explicitement SYNTHETIQUE accepté.
- R1 : interfaces, équations, ownership et budget CPU approuvés.
- R2 : chaque TC ci-dessus porte statut `READY` ou `BLOCKED_DATA`; zéro oracle ambigu dans la partie codée.
- Baseline fraîche des suites `FB_Sim_Translation`, `FB_SimBench`, `FB_Translation_PositionEstimator`, `FB_TranslationOutputInterlock`.

## Etat executable T300 au 2026-09-16

Cette section prevaut sur les libelles de plan pre-code et les identifiants d'integration proposes plus haut.

| TC execute | Preuve exacte | Limite explicite |
|---|---|---|
| `TC-T300-INT-030` | Relai representatif `SimBench.Translation -> image locale HwIn -> FB_Translation_PositionDecoder`, P1 `00011` puis Maintenance `00000` | Ce n'est pas l'appel ordonnance PRG_02/PRG_05 |
| `TC-T300-INT-031` | Traverse P1 vers Maintenance avec episode 1 s, graine fixe : perte, reprise, stabilisation et decodeur observes scan par scan | Ne couvre ni memoires PRG_05 ni `FB_Safety_Translation` |
| `TC-T300-SEN-011` | Depuis P1, commande vers Trémie : PV initialement 0 puis passe à 1 au franchissement du seuil 5 m | Horizon 700 scans à 10 ms ; seuil synthétique à confirmer terrain |
| `TC-T300-SAF-060` | FDC atteint sans requete persistante : aucune escalade ni coupure puissance apres 1,6 s | Test unitaire du FB safety, pas une trace CODESYS |
| `TC-T300-SAF-061` | Requete persistante au FDC avec frequence nulle mais bit0 du mot variateur actif (`16#0081`) : escalade `ErrorId=64` apres 1,5 s | Le mot d'etat reel AC600 doit encore etre confirme par la trace terrain |
| `TC-T300-CAM-100` | 48 profils synthetiques x 100 graines, 960000 pas, invariants bornes/frequence/mot hors episode | Ce ne sont pas 4800 configurations terrain independantes |
| `TC-T300-INT-050` | Non executable hors CODESYS : trace `HwSim -> HwIn -> instPosDecoderM3 -> TranslationState` | `BLOCKED_TRACE_CODESYS` |
