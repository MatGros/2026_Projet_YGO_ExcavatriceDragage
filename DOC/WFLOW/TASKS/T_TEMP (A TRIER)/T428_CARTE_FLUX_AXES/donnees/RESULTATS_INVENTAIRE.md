# Inventaire troubleshooting / snapshot - resultats (2026-11-06)

Lecture seule du depot. Aucune recommandation de refonte. Interrompu sur demande du coordinateur : ce qui n'etait pas calcule est marque "inconnu".

Legende : **[M]** fait mesure (fichier, parse, CSV) - **[C]** calcul - **[I]** inference - **[?]** inconnu.

## 0. Perimetre et classement des donnees

- [M] 544 feuilles dans `GVL_Troubleshooting` (19 groupes), 100 % presentes dans `troubleshooting_inventory.csv`, colonnes obligatoires sans case vide.
- [M] CSV analyses : 94 snapshots + 1 acquisition (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/`).
- [I] Classement : REEL 54, SIM 38, INDETERMINE 2. Regle : `SimulationEnabled`, puis COD1 non nul. REEL = inference, pas une attestation.
- [M] Snapshots REEL : 6 jours seulement (2026-09-04 a 07, 09-22, 09-23).
- ARCHIVES/ : contenu NON lu (interdit par la mission). 62 CSV exclus : le critere "TOUS les CSV" est donc partiel. Les worktrees n'apportent aucun snapshot supplementaire.
- [M] 17 CSV de trace : usage releve, 20 colonnes TS seulement.

## 1. Tableau par groupe (ordre reel de lecture)

"Doublon" = feuille dont la source canonique est aussi exposee par une autre feuille. "Jamais chg" = valeur unique sur les snapshots REEL ; ne prouve pas l'inutilite.

| Rang | Groupe | Lignes liste | Feuilles | Octets | % doublons | % jamais chg REEL | % jamais chg SIM | Const. | Vides | Recalc. vue |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | A_ContexteMachineGlobal | 1-12 | 12 | 13 | 67 | 42 | 42 | 1 | 0 | 2 |
| 2 | B_Inputs | 13-53 | 41 | 66 | 37 | 49 | 61 | 0 | 0 | 0 |
| 3 | C_Safety | 54-80 | 27 | 31 | 26 | 48 | 56 | 0 | 0 | 1 |
| 4 | D_Joystick | 81-97 | 17 | 28 | 53 | 12 | 12 | 0 | 0 | 3 |
| 5 | E_HomingM1 | 98-113 | 16 | 17 | 50 | 19 | 38 | 0 | 0 | 4 |
| 6 | F_HomingM2 | 114-129 | 16 | 17 | 50 | 19 | 38 | 0 | 0 | 4 |
| 7 | G_CycleSemiAuto | 130-166 | 40 | 377 | 25 | 38 (sur 37) | 32 | 0 | 0 | 3 |
| 8 | H_LevageSynchroniseM1M2 | 167-181 | 15 | 36 | 47 | 33 | 40 | 0 | 5 | 0 |
| 9 | I_LevageUnitaireM1 | 182-250 | 69 | 113 | 42 | 38 | 42 | 1 | 0 | 2 |
| 10 | J_LevageUnitaireM2 | 251-319 | 69 | 113 | 42 | 38 | 42 | 0 | 0 | 2 |
| 11 | K_BenneOuvertureFermeture | 320-359 | 40 | 55 | 18 | 42 | 32 | 1 | 0 | 2 |
| 12 | L_TranslationPontM3 | 360-406 | 47 | 73 | 21 | 60 | 66 | 1 | 0 | 0 |
| 13 | N_MotionM1 | 407-425 | 19 | 25 | 58 | 32 | 5 | 0 | 0 | 9 |
| 14 | O_MotionM2 | 426-444 | 19 | 25 | 58 | 32 | 11 | 0 | 0 | 8 |
| 15 | P_MotionM3 | 445-463 | 19 | 25 | 32 | 63 | 63 | 2 | 0 | 10 |
| 16 | Q_TraceWinchM1 | 464-479 | 16 | 22 | 44 | 31 | 25 | 0 | 0 | 0 |
| 17 | R_TraceWinchM2 | 480-495 | 16 | 22 | 44 | 25 | 25 | 0 | 0 | 0 |
| 18 | S_TraceTranslation | 496-508 | 13 | 17 | 23 | 23 | 38 | 0 | 0 | 0 |
| 19 | T_Permits | 509-541 | 33 | 34 | 70 | 24 | 15 | 0 | 0 | 0 |
| | **Total** | 541 + 30 hors GVL | **544** | **1109** | **215 (40 %)** | **206/541 (38 %)** | 212 | 6 | 5 | 50 |

- [M] Ordre : la lettre M est absente (reserve). Les causes priorisees (Q/R/S/T) arrivent en lignes 464-541, apres le detail.
- [M] L'ordre d'ecriture de la vue differe de l'ordre GVL : A, H, I, J, K, L, E, F, C, D, N, O, P, B, G, Q, R, S, T.
- [M] Dans G, les Idx 217-222 sont declares entre 205 et 206 ; Idx221 est absent. Seul trou d'Idx de toute la GVL.
- [M] Classes d'expression : COPIE 465, RECALCUL_VUE 50, NEGATION 12, CONSTANTE 6, NON_AFFECTE 5, CONDITIONNEL_IF 4, CONVERSION 2.

## 2. Cout snapshot

| Point | Valeur | Statut |
|---|---|---|
| Variables lues | 571 (541 GVL + 28 PRG_06 + 2 PRG_04) ; +608 via `snapshot_all` (liste IHM) | [M] |
| Taille d'un snapshot | 40 587 octets, 71,1 octets/ligne (moyenne 94 fichiers : 38 181) | [M] |
| Repartition | chemins 86,4 %, valeurs 9,3 %, separateurs 4,3 % | [C] depuis [M] |
| Lots de lecture | 100 variables par appel, soit 6 lots | [M] code |
| Duree lecture reelle | periode mediane 1,276 s pour 541 variables, soit 2,36 ms/variable, ~128 scans de 10 ms | [M] periode ; [C] le reste ; [I] la periode est dominee par la lecture (elle depasse la cible de 1 s) |
| Duree lecture README | 974 variables en ~2,2 s, soit 2,26 ms/variable | [M] citee, contexte non date |
| Temps d'ecriture CSV | **non mesurable** : imprime en console uniquement, jamais conserve. Ecriture cote PC, pas automate | [?] |
| Frequence | manuelle (Ctrl+W), ecart median intra-jour 1365 s, 6,5 snapshots/jour median | [M] |
| Acquisition 1 Hz cible | reelle ~0,78 Hz ; 79 210 octets pour 11 lectures, ~4,0 Ko par lecture | [M] / [C] |
| Volume/min | ~188 Ko/min en format acquisition ; ~1,9 Mo/min si un CSV par lecture (theorique) ; ~1,8 Ko/min a la cadence manuelle mediane | [C] |
| Memoire GVL | 1109 octets somme brute ; 1214 si alignement naturel | [C] ; alignement [I] |
| Copie VAR_INPUT a chaque scan | ~2130 octets ; 432 affectations + 5 copies de struct | [C] ; [M] pour 432 |
| Temps CPU de la vue | **non mesurable** : aucune mesure dans le perimetre lu | [?] |
| Taille `DEVICE_STATE` | 2 octets par hypothese (4 feuilles) | [I] |

**Limite 12 Ko : non confirmee.** `SNAPSHOT-12KO` (`TASKS_ORCHESTRATOR.yaml:1508`) signifie "12 variables KO" (chemins perimes), pas 12 kilo-octets. Aucune limite de taille trouvee dans le README ni les docs snapshot.

**Le snapshot n'est pas une image coherente.** [M] 75 desaccords entre doublons de meme source dans un meme CSV : 17 groupes, 44 fichiers sur 94, 72 REEL, 3 INDETERMINE, 0 SIM.
- `Snapshot_Troubleshooting_20260906_202330.csv` : position M1 = 5,44 m et 5,06 m dans le meme fichier.
- Frein M1 TRUE/FALSE dans ce meme fichier.
- [I] Cause : lecture par lots etalee sur ~1,3 s.

## 3. Variables mortes ou suspectes

### Faits code et listes [M]

- **Jamais affectees (5)** : H `Idx201_JoyYRaw_Pct`, `Idx203_ArbitratedSpeed_Pct`, `Idx401_SyncMotionAllowed`, `Idx402_M1_SetpointSpeed_Pct`, `Idx403_M2_SetpointSpeed_Pct`.
- **Constantes (6)** : A `Idx203_BypassSensorsGlobal`, I `Idx307_SlackCablePhysical_DI`, K `Idx501_M2_CmdRev_DQ`, L `Idx502_CmdDriveFreq_Hz`, P `Step3_NotBusyOtherTask` (TRUE), P `SpeedContactor1Active`.
- **Ports cables, jamais lus (7)** : `HwReal`, `LocalDigitalIoOk`, `Vh0800EndOk`, `Vh0808EtpOk`, `SimWinchActive`, `SimTranslationActive`, `SimOperatorActive`.
  - Les observables de l'AF-14 sec. 6 (etat des cartes DI) ne sont donc pas publies dans la GVL.
  - `B_Inputs` ne contient que HwIn, malgre le commentaire "reelles / simulees".
- **Feuilles absentes de la liste (3)** : `Idx207_StepStr`, `Idx212_OperatorAction`, `Idx222_ForceStepResult`. Le regex du generateur ne reconnait pas `STRING(n)`.
- **GVL_BypassRetain** : 0 variable dans la liste malgre le code du generateur (le regex rate `:= valeur`). La liste regeneree est identique a l'actuelle.
- **Chemins inexistants** (parse ST, `list_path_check.csv`) :
  - `troubleshooting_variables.txt` 0/571
  - `ihm_variables.txt` 180/608
  - `troubleshooting_variables.generated.txt` 38/495 (non reference par les scripts snapshot)
  - `trace_treuils_charge_v1` 81/108
  - `trace_m3_modelica_link_v1` 5/39
  - `trace_ax10_ax11_expert_v2` 2/38
- **Commentaires perimes** : `FB_TroubleshootingView.st:159` dit Idx303-304 non cables (ils le sont, :155-156). L'en-tete dit "aucun calcul" pour 50 recalculs. AF-14 cite `GVL_Troubleshooting.Safety`, `.CycleSemiAuto`, `TraceM1/2` et 6 fonctions pour 19 groupes.

### Suspects de semantique

- **Demande affichee comme sortie** [M code] : H `Idx501/502_*_DQ`, I/J `Outputs_500.Idx501-504`, N/O `RelayFwdActive`, `RelayRevActive`, `SpeedContactor1Active` lisent la DEMANDE `FB_Winch`, pas l'ordre valide par la barriere.
  - `FB_TroubleshootingView.st:589-596` le dit ; `FB_WinchOutputInterlock` publie les sorties validees.
  - La fiche ManuelBoth les presente pourtant comme "reellement commandes".
  - Absentes de la liste : RelayFwd/Rev et Contactor1-4 de `FB_WinchOutputInterlock` (BrakeCmd et AuthorizedStep y sont).
- **`Idx407_FinalAuthorizedStep`** [M code] : source `WinchM1Ref.RequestedStep`, pas `Interlock.AuthorizedStep`.
- **`J.Idx323/324`** [M code + donnees] : calcul sans `M2_LimitShift`, alors que `FB_WinchStateProjection.st:226` l'applique. REEL : Idx323 TRUE 43/54, Idx324 TRUE 40/54, dont 4 avec `Idx306_AscentPermitEffective=TRUE`. SIM : 8 cas equivalents.
- **`N.Step2_ModeAuthorized`** [M] : FALSE par construction en SEMI_AUTO. `N.AllConditionsMet` TRUE 0/54 en REEL, y compris 3 snapshots SEMI_AUTO relais actifs. La regle "premier FALSE = cause" est trompeuse dans ce mode [I]. O et P ont la meme expression Step2 ; leurs donnees n'ont pas ete calculees [?].
- **Noms ambigus** [M code] :
  - `Idx102_PowerAndSafetyOk` = contacteur seul
  - `PowerCutOffRequest` = `PowerCutOffActive`
  - `D.NeutralXAct` = BOOL a seuils 4800-5200 en dur, homonyme d'une memoire de FB_Joystick
  - `Idx408_BrakeCommandOpenConfirmed` = DI frein
  - `C.AllConditionsMet` et `Step4` s'excluent (commentaire : etat final)
- **Piege de cablage** [M code] : `M1_ContactorsReleased_DI` lit l'entree physique M2 et inversement (`PRG_02_Acquisition.st:145-150`, compensation assumee).
- **Valeurs figees REEL a verifier** [M, pas de conclusion] : `HydraulicThermalOk_DI` FALSE 54/54 (TRUE en SIM) ; `ConveyorInfeedReady_DI`, `M3_BrakeIsOpen_DI` FALSE 54/54 ; frequence M3 = 0 54/54 (aucun snapshot M3 en mouvement [I]).
- **Producteurs non resolus (3)** : `I/J.Idx209_ArbitratedDirection` (partiel), `T_Permits.ExtractionAscentPermit` (partiel).

### Alerte securite (hors mission, liste fermee motif 1)

[M] `GVL_BypassRetain.BypassAuRedundancyTestA : BOOL := TRUE` (`GVL_BypassRetain.st:29`), consomme en `PRG_06_Outputs.st:497`, sous un bloc qui l'annonce "jamais production" et "non securise". `BypassTestA` vaut TRUE dans 7/7 snapshots REEL ou il est present. [?] Etat actuel sur la machine.

## 4. Utilite observee (sans conclure "inutile")

- [M] 206/541 jamais changees en REEL ; 212 en SIM ; 169 sur tous fichiers.
- [C] Typologie des 169 : 11 constantes ou vides, 77 de nature defaut/garde par mot-cle du nom, 81 autres. **Une variable de defaut figee est le cas attendu en marche normale.**
- [M] 27 varient en SIM seulement, 33 en REEL seulement : le choix du jeu de donnees change la reponse.
- [M] Distribution %changements REEL : 0 % = 206 ; <5 % = 47 ; <25 % = 155 ; >=25 % = 133.
- [M] Acquisition (seul fichier multi-instants, 14 s, un seul etat) : 511 fixes, 4 variables. Trop court pour juger.
- [M] Correlees a 100 % en REEL : 504 paires identiques (185 structurelles, 319 non) et 246 inversees. Les 319 non structurelles sont a traiter comme coincidences possibles.
- [M] `.trace` : 42 feuilles sur 544 utilisees dans 119 fichiers, surtout I (17), J (13), G (8). Top : `I.Idx104_BrakeApplied` (21 fichiers), `Idx103_ContactorsReleased_DI`, `Idx415_MotorRequest`.

## 5. Top des vrais doublons

[M] 84 groupes de meme source, 215 feuilles, 131 feuilles excedentaires, 187 octets. 81 groupes sont inter-groupes, 3 intra-groupe. 7 paires inversees. Detail : `redundancy_groups.csv`.

| Feuilles | Source | Groupes |
|---:|---|---|
| 11 | `HwIn.Machine.PowerContactorEngaged_DI` | A B C G N O P |
| 9 | `HwIn.Machine.EmergencyChainClosed_DI` | A B C H I J K L |
| 5 | `HwIn.Winch.M1M2_TopPositionFree_DI` | B E F I J |
| 4 | `Auth.Mode` | A I J L |
| 4 | `M1/M2_ContactorsReleased_DI` (2 groupes) | B E/F I/J |
| 4 | `HwIn.Operator.JoyYRaw_ANA2` | B D I J |
| 3 | `M1/M2_BrakeIsOpen_DI`, `JoyXRaw`, `JoyBtnRaw`, `Deflection Y` | B D E F I J L N O |
| 3 | `Position_M`, `StepNumber`, `RelayFwd`, `BrakeCmd`, `FinalInterlockReason`, `AscentPermit` (M1 et M2) | G H I J N O Q R T |

Symetrie axes [M] (`axis_pairs.csv`) :

| Paire | Champs | Symetrie voulue | Meme source (vraie redondance) | Autre |
|---|---:|---:|---:|---|
| I/J | 69 | 55 | 13 | 1 const. |
| E/F | 16 | 12 | 4 | 0 |
| N/O | 19 | 14 | 3 | 2 divergents voulus (`Step3`, `Step5`) |
| Q/R | 16 | 16 | 0 | 0 |

[M] 268 feuilles ont une source directe GVL_IHM ; 167 sont aussi dans `ihm_variables.txt`.

## 6. Incidents utilisables en replay A/B

[M] 49 fiches. [I] 15 fiches SITE (compte manuel des en-tetes). Seules 10 fiches lisent des valeurs TS, dont 2 SITE. La plupart des fiches SITE reposent sur traces, code ou observation.

| # | Fiche | Situation | Donnee | Groupes reellement utiles | Resultat |
|---|---|---|---|---|---|
| 1 | BenneOuverture_BlocageCouplage | SITE | Snapshot 20260905_120629 | A K T O | Partiel : barriere finale illisible (depuis ajoutee [I]) |
| 2 | SynchroPilotageBenne | SITE | Snapshot 20260907_122109 | G H J K T | Echec : snapshot post-defaut, manque `SyncOperationPermit`, `BucketActivityHold.Q` |
| 3 | AX12_Arret_737m | SIM | Snapshot 20260915_111950 | G H I J K | Cause confirmee |
| 4 | KoboldIhm | SIM | Snapshot 20260915_000306 | A B G H | Conclu |
| 5 | WINCHSEL_M2_OFFSET | SIM | Snapshots 20260906 22:23:34 et 22:24:01 | D H K | Cause identifiee |
| 6 | T338_PositionM2_Figee | SIM | 3 snapshots 20260920 (dont 172509) | A B F H I J O | Clos |
| 7 | CycleAX15_AX18 | SIM | Snapshots 20261015_033756, 035413 | G I K | Cause prouvee, defaut deja acquitte |
| 8 | Cycle_Error08_TranslationP1 | SIM rapporte | Snapshot 20260922_054918 | G H I J L | Echec : hors episode |
| 9 | Temporisation800ms / TrouAX10_AX11 | SITE | Traces Suivi_83, Suivi_84 | I J + `DirectionChangePending` (hors GVL) | Cause directe identifiee |
| 10 | PlongeeM2 / ContinuiteJoystick | SITE | Traces 35, 37 | variables de trace, G | Partiel |

- Non rejouables sur snapshot [M] : DefautVH0008ER et MonteeRampePaliers (snapshots 20260901_234514 et 20260902_160851 introuvables dans TOOLS ni ARCHIVES, par nom de fichier).
- Sans donnee rejouable : M3_FDC_Frein (cause non confirmee, pas de snapshot avant acquittement), FdcBasSilencieux, T291A, T334, T367, AX3, BandeauAlarme, AX15_SortieVersAX10 (acquisition demandee, 3 variables sur 7 hors liste).
- [I] Limite recurrente : le moment de capture. Fiches 2, 7, 8 et M3_FDC ont un snapshot pris apres ou hors episode.
- Mention groupee des fiches [I] : extraction par regex ; K, G, H, I, J arrivent en tete ; le statut "decisif" du tableau vient de la lecture des extraits, pas d'une lecture integrale des 49 fiches.

## 7. Limites et inconnues

- Non lus : ARCHIVES/ (62 CSV). Contenu des CSV de trace : 20 colonnes TS seulement.
- Producteur reel : remontee automatique bornee (10 ecrivains, profondeur 12), best-effort. Les pointeurs ne sont pas suivis.
- Une ligne de snapshot = un instant ; "% changement" compare des fichiers espaces, pas des scans.
- `dead_suspect.csv` prevu n'a pas ete produit : la section 3 sert de registre.
- Inconnus : temps d'ecriture CSV, temps CPU de la vue, etat actuel des bypass machine, version du programme derriere chaque snapshot, donnees N/O/P hors N.

## 8. Reproduire

Depuis ce dossier, avec `PYTHONDONTWRITEBYTECODE=1` et `PYTHONIOENCODING=utf-8`, dans cet ordre : `python 01_inventory.py`, `python 02_redundancy.py`, `python 03_snapshots.py`, `python 04_fiches.py`, `python 05_costs_order.py`. Relancer 02 apres 01 ; 03 lit `_rows.json`.