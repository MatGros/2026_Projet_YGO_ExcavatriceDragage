# 🧭 Dossier simulateur M3 (TwinBench) — état, preuves, plan à challenger

> Date : 2026-10-04 · Rédacteur : CC01 · Tâches : T415-B (lien), T415-G (TwinBench v2), T415-E1 (modèle)
> Dernier checkpoint : commit `95c9ed5d` (non poussé). Aucun code modifié depuis.
> Partie A = dossier factuel. Partie B = brief à copier-coller pour un challenger indépendant.

---

# PARTIE A — DOSSIER

## A1. 🎯 Objectif utilisateur (inchangé depuis le 2026-10-02)

Tester le **programme automate versionné** (`CODE/`) chargé dans **CODESYS Control Win**, avec le
chariot de translation **M3 simulé par OpenModelica (FMU)**, et **voir** ce qui se passe.

Règles posées par l'utilisateur :
- un seul code : la simulation vit dans le **SimBench** (`CODE/L_SIMULATION`), sélectionnée par bits ;
- le simulateur **simule** (dynamique, capteurs, frein, stimuli) et **ne gère aucune condition**
  (modes, autorisations, interlocks = PLC) ;
- il doit **au minimum se comporter comme le simulateur interne ST** (`FB_Sim_Translation`), puis
  on ajoute des fonctions une à une ;
- **ne pas toucher au code automate** hors SimBench (2026-10-04) ; **ne pas modifier le générateur**
  PLCopenXML (2026-10-02) ; ne pas changer les variables IHM existantes.

## A2. ✅ Ce qui est fait (avec preuves)

| # | Réalisation | Pourquoi | Preuve |
|---|---|---|---|
| 1 | Projet CODESYS unique : `Device` (CPU réel / simu IDE) + `Device_CtrlWinSim` (Control Win), créé par l'utilisateur (copie + *Update Device*), maîtres EtherCAT/CAN **désactivés**, `Local_Digital_IO` recréé avec une VH_0808ETP renommée | Supprimer la copie réécrite (HW_SIM) du lanceur v1 ; Control Win = vrai runtime | Build OK, devices grisés (constat utilisateur) |
| 2 | `FB_Sim_Translation_ExtLink` dans `CODE/L_SIMULATION` : lien UDP 10 ms vers la passerelle FMU, inerte hors bits de simulation | Un seul code ; le lien devient une brique SimBench (remplace le PRG prototype T409) | G200 PASS ; échanges ~96 trames/s, 0 rejet |
| 3 | Correctifs du lien : adresse loopback en littéral, types `RTS_IEC_*` sans préfixe, handle 0 = socket factice, vidage de file UDP, contrôle FIONBIO, coupure propre si simulation OFF, **règle de cohérence capteurs inversée corrigée** | Bugs prouvés un par un (voir A3) | Traces passerelle + PLC |
| 4 | Écho de l'état PLC dans la trame (octets 23..31) → journal `[PLC]` de la passerelle, colonnes trace CSV, panneau « ÉTAT PLC » de la vue | Diagnostiquer sans faire lire des variables à l'utilisateur | Test unitaire encodage/décodage ; vue chargée hors écran sans erreur QML ; 6/6 tests passerelle |
| 5 | Lanceur : choix 3 « simulation reliée au PLC », fenêtre de sélection au premier plan, menu sans boucle, confirmations par `1` | Retours d'ergonomie utilisateur | Tests automatiques (frappes simulées, EnumWindows) ; autotest 56/56 |
| 6 | Trace CODESYS `TB_M3_LINK` (39 variables) | Corréler PLC et plante | Trace `Suivi_92` exploitée |
| 7 | Tâches / contrats : T415-B (⏳), T415-G (⬜, 9 lots, 26 cas de test), proposition + challenge expert | Rendre le chantier délégable | `check_task_contract.py` PASS |

**Résultat validé** : liaison PLC ↔ Modelica fonctionnelle ; trajets P1→Trémie, Trémie→P1, accès
Maintenance (MAINT_N1 + bouton) → 30 m, confirmés par le journal `[PLC]` du 2026-10-04.

## A3. 🐞 Défauts trouvés et leur cause (preuves)

| Défaut constaté | Cause prouvée | Correction |
|---|---|---|
| Aucune trame reçue (simu IDE) | Simulation intégrée CODESYS : sockets factices (doc CODESYS) | Utiliser Control Win |
| Variables socket « non définies » à la compilation | Le générateur ignore les types préfixés par namespace | Types sans préfixe dans le FB |
| Trames envoyées vers `172.18.224.1` | Le générateur vide les constantes `STRING` → adresse vide | Adresse écrite en littéral |
| Lien perdu pendant tout trajet, saut capteurs en bout de course | Règle « mot capteurs incohérent » inversée (héritée du prototype) : seuls `11111`/`00000` acceptés | Règle corrigée, vérifiée sur les 6 mots valides et 5 invalides |
| « Impossible d'aller en Maintenance » | **Comportement PLC normal** : accès = MAINT_N1/N2 **ET** bouton ; verrou d'arrivée à P1 libéré seulement par un mouvement inverse (`FB_Translation.st:207-250`, `FB_Modes.st:413`) | Aucune (hors périmètre, documenté) |

## A4. ⚠️ Problèmes encore ouverts

### Dans le périmètre (simulateur / vue)
| Id | Problème | Cause (preuve) |
|---|---|---|
| V1 | Courbes qui défilent trop vite, base de temps inexploitable | Fenêtre fixe 2 s (`app.py` : `deque(maxlen=201)`, axe `tMax-2.0`) |
| V2 | Accostage illisible ; « Capture butée » grisée la plupart du temps | Capture déclenchée **uniquement** au contact butée mécanique ; trace ±1 s de Hz seulement, sans position ni capteurs |
| V3 | Messages Qt « style does not support customization » à chaque lancement | Style natif Windows de Qt Quick Controls |
| M1 | En butée : vitesse 1,0 m/s et 50 Hz affichés alors que la position est figée ; drapeau butée qui clignote | Modèle FMU (`M3_POC.mo`) : vitesse non annulée à la butée, drapeau conditionné à la direction commandée |
| M2 | Écarts avec le simulateur interne : butées −0,30/30,30 m (interne 0/30), délais frein 0,20/0,10 s (interne 0,10/0,09), mot d'état, pas d'hystérésis ni délai capteur | Comparaison code `FB_Sim_Translation.st` ↔ `M3_POC.mo` |
| M3 | Forçage manuel des capteurs (`SimM3SensorsWordOverrideActive`) inopérant en mode externe | `FB_SimBench` : l'image externe écrase l'override |

### Hors périmètre (signalés, non touchés)
- Estimation de position PLC à 30,0 m au démarrage alors que le chariot est à P1 (recalage au 1er front).
- Stimuli joystick simulés : `SimJoystickRight_Fwd_MAINT_Active` produit une commande **vers la Trémie**.
- Accès zone Maintenance non autorisé en cycle (seulement MAINT_N1/N2).
- Visu CODESYS de `Device_CtrlWinSim` : erreur JS `reading 'ua'`.

## A5. 📐 Plan proposé (à challenger avant tout code)

### Lot V — Vue Modelica (TOOLS uniquement : `app.py`, `Main.qml`)
| Point | Proposition | Critère testable |
|---|---|---|
| V1 | Fenêtre live **20 s** ; tampon 2001 points (10 ms), tracé décimé ≤ 600 points ; courbes Hz consigne/mesure + **position** ; fronts capteurs marqués (`P1↓`, `Trémie↑`…) | Test hors écran : 20 s visibles, nombre de points tracés ≤ 600, marqueurs = fronts réels de la trace |
| V2 | Remplacer « Capture butée » par **« Dernier accostage »** : capture automatique à **chaque arrêt complet** (de 0,5 s avant le départ à 0,5 s après l'arrêt). Synthèse : point d'arrêt, dernier front capteur + position, **dépassement en cm**, vitesse/Hz au franchissement, durée de décélération, contact butée oui/non | Rejouer une trace passerelle réelle (`fmu_20261004_060611`) : la synthèse calculée = valeurs relues dans le CSV (tolérance 1 cm / 10 ms) |
| V3 | Style Qt « Fusion » | Plus aucun message « customization » |

### Lot M — Plante Modelica, parité avec le simulateur interne (`M3_POC.mo`, FMU)
| Point | Proposition | Critère testable |
|---|---|---|
| M1 | Vitesse nulle en butée ; drapeau butée = contact mécanique, indépendant de la commande | Scénario poussée en butée : v = 0, drapeau stable |
| M2 | Butées 0 / 30 m, délais frein 0,10 / 0,09 s, mot d'état comme l'interne, hystérésis 2 cm + délai 10 ms capteurs | Test de parité automatique : même scénario sur `FB_Sim_Translation` et la FMU, comparaison capteurs/frein/Hz |
| M3 | Override capteurs aussi en mode externe (`FB_SimBench`, SimBench) | Override actif → le PLC reçoit le mot forcé |
| — | **Décision humaine** : fréquence max — Modelica suit la consigne réelle (50 Hz) ou s'aligne sur le plafond 40 Hz de l'interne ? | — |

### Ordre proposé
V1 → V2 → V3 (aucun risque PLC, gain immédiat de lisibilité), puis M1 → M3 → M2 (parité).

---

# PARTIE B — BRIEF CHALLENGER (à copier-coller tel quel)

```text
→ NOUVEL AGENT

[Coller d'abord TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md]

OBJECTIF
- Challenger, en LECTURE SEULE, le plan de la Partie A5 du dossier
  DOC/WFLOW/ORCHESTRATION_RAPPORTS/DOSSIER_SIMULATEUR_M3_ETAT_ET_PLAN_2026-10-04.md
  (simulateur Modelica du chariot M3 relié au PLC CODESYS Control Win).
- Dire si le plan répond au besoin réel de l'utilisateur : VOIR et COMPRENDRE un accostage
  (ralentissement, front capteur, arrêt, dépassement, butée), et disposer d'une plante qui se
  comporte au minimum comme le simulateur interne ST.

PÉRIMÈTRE / INTERDITS
- Lecture seule. Aucune écriture, aucun commit.
- Fichiers à lire : le dossier ci-dessus ; TOOLS/TWINBENCH/02_SIM/modelica/live_poc/app.py et Main.qml ;
  TOOLS/TWINBENCH/02_SIM/modelica/M3_POC.mo ; CODE/L_SIMULATION/FB_Sim_Translation.st,
  FB_Sim_Translation_ExtLink.st, FB_SimBench.st ; traces %LOCALAPPDATA%\TwinBenchT409\fmu_*.trace.csv.
- Hors scope : toute logique automate (PRG_03/04/05/06, FB_Translation, safety, modes, IHM),
  le générateur PLCopenXML.

PHASES ET POINTS D'ARRÊT
1. Lire le dossier et le code réel cité.
2. Vérifier chaque constat A3/A4 contre le code ou la trace (confirmé / infirmé / non vérifiable).
3. Challenger A5 : manques, erreurs, alternatives plus simples, risques.
4. S'arrêter : restituer, ne rien implémenter.

CRITÈRES TESTABLES (à juger)
- Chaque point V/M a-t-il un critère vérifiable automatiquement ? Lesquels manquent ?
- La synthèse « dernier accostage » couvre-t-elle ce qu'un automaticien regarde en mise en service ?
- La parité M2 est-elle complète vis-à-vis de FB_Sim_Translation (citer fichier:ligne) ?

SOUS-AGENTS AUTORISÉS
- Aucun écrivain. Un spécialiste IHM/ergonomie et un spécialiste mise en service en lecture seule si utile.

PREUVES ATTENDUES
- Références fichier:ligne ou extraits de trace pour chaque affirmation ; sinon la marquer « hypothèse ».

RESPONSABILITÉ DU PRINCIPAL
- Tu restes garant de tes conclusions ; ne recopie pas le dossier comme preuve.

FORMAT DE RESTITUTION
1. Verdict (GO / GO avec réserves / NO GO) en 2 lignes.
2. Constats A3/A4 : confirmé / infirmé / non vérifiable, avec preuve.
3. Problèmes du plan : id, gravité (BLOQUANT/MAJEUR/MINEUR), constat, recommandation.
4. Ce qui manque au plan.
5. Max 5 questions fermées à l'utilisateur.
```

---

## C. Avancement 2026-10-04 — lots M1 + M2 faits (plante en parité)

| Quoi | Fait | Preuve |
|---|---|---|
| Plante `M3_POC.TranslationM3` réécrite en pas discret 10 ms, même ordre que `FB_Sim_Translation` (variateur → frein → sens mémorisé → mouvement/butées → cames) | ✅ | `live_poc/test_plant_parity.py` : écart **0** (position, Hz, frein, capteurs, statut) sur 120 s |
| Frein : retombe seulement sous 0,5 Hz, 100 ms ouverture / 90 ms fermeture, contact +10 ms | ✅ | frein retombé à 0,29 Hz (avant : ~19,6 Hz) |
| Décélération 20 Hz/s, τ 0,15 s, statut 16#87 si > 0,5 Hz | ✅ | `check_twinbench_m3_poc_structure.py` impose les 16 valeurs de parité |
| Cames 0,05 / 29,95 m + hystérésis 0,02 m, butées 0 / 30 m, vitesse nulle en butée | ✅ | idem |
| Consigne PLC réelle suivie jusqu'à 50 Hz (Q2) | ✅ | hors parité, voulu |
| Non reproduit (volontaire) : charge suspendue, bruit, intermittence, blip, défaut frein, recul | ⏸️ | lot ultérieur si besoin |

Contournement technique : OpenModelica 1.27 n'exporte pas en FMU un `when` algorithmique sur des Real → calcul dans des fonctions, état empaqueté en vecteur.
Tests : parité, `test_auto_cycle` (50 cycles), roundtrip passerelle, protocole, vues offscreen, `validate_M3_POC.mos` → PASS.
Reste : V2 (capture accostage), M3 (forçage capteurs), Q3 (transmettre mots incohérents), Q5 (colonne frein PLC).
