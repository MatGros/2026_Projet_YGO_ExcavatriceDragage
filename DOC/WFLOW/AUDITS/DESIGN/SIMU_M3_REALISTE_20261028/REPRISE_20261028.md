# 🔁 Point de reprise — chantier simu M3 réaliste (2026-10-28)

> Etat courant du chantier : T417 dans DOC/WFLOW/TASKS.yaml et son contrat lie. Ce document conserve le cadrage ou le bilan anterieur ; il ne vaut pas validation du lot courant.

> Branche `work/base-machine-simu` · plan : `PLAN_SIMU_M3_REALISTE.md` · experts : `SYNTHESE_EXPERTS_A_B.md`
> Règle du chantier : simuler la réalité, ne pas régler la simu pour obtenir le défaut. Programme machine touché seulement par L0.

## État courant après mise à jour dynamique

- Checkpoint humain **fd32b652** : L4/L5 et réglages précédents sauvegardés (14 ST/XML).
- Seul ST modifié depuis ce checkpoint : `FB_Sim_Translation`, correction du frottement
  numérique qui retournait une faible vitesse à 100 ms. Aucun réglage physique changé.
- **9/9 scénarios fonctionnels PASS** sur le ST réel ; review indépendante et DeepSeek
  `deepseek-v4.1-flash:cloud` favorables. Bundle complet et diff frais, **G200 PASS**.
- Palier C : **53/61 PASS**, 8 échecs déjà présents avant la correction
  (G300/G340/G430/G483/G503/G517/G518/G519). G390 fraîcheur corrigé par régénération.
- Mise en service précisée par l'exploitant : variateur réglé pour limiter la décélération,
  automate ensuite un peu plus doux. Garder l'arrêt piloté après mot zéro ; ne pas déduire
  une roue libre immédiate. Balancement secondaire conservé, aucun dépassement ciblé.
- Essais CODESYS utilisateur en attente : voir `BILAN_UPDATE_ET_ESSAIS.md` et contrat
  `CONTRACT_UPDATE_DYNAMIQUE_M3.yaml`. Correctif, essais et rapports non commités ; seul
  le checkpoint ci-dessus a été explicitement autorisé.

Les sections suivantes décrivent l'état transmis avant ce checkpoint ; cette section fait foi
pour la reprise actuelle.

## ✅ Fait et commité

| Commit | Contenu | Essai utilisateur |
|---|---|---|
| `0dcd676c` | Plan, synthèse experts, contrat T301 V2 | — |
| `ac17beef` | **L0** `FB_Translation_OdometryGain` : gain = \|P2−PV\| / (CalibFreq × CalibTime), mesure P2↔PV proposée jamais appliquée, positions réalistes 0/1,5/3,5/5/10, 2 persistantes ajoutées en fin (`_TranslationCalibFreq_Hz` 50, `_TranslationCalibTimeP2PV_S` 2,0). **L1** simu en source unique (positions GVL_PERSISTENT + gain effectif PRG_05), butées ±0,5 m, G518 réécrit | Manuel OK ; mesure 2,518 s @ 39,98 Hz → 0,01987 ; auto sans blocage |
| `ac7fe43e` | **L3** frein simulé physique (`SimM3BrakePhysicalActive`, 2 m/s²) + **L2** indicateurs `GVL_Simulation.SimM3Obs*` | Manuel P1 0,27 m ; auto Trémie 0,27 m ; auto P1 0,28 m |

## ⏳ Fait, NON commité (attend le verdict du challenge)

- **L4** chariot libre (frein ouvert + variateur sans couple → poussée benne r/(1−r)·g·θ, frottement 0,1, pente 0) — `SimM3CartFreeActive` TRUE.
- **L5** came capteurs spatiale (vu → perdu → retrouvé → fixe, deux sens, hystérésis bornes) — `SimM3SensorCamDropoutActive` TRUE, zone 0,02 + 0,04 m.
- `GVL_PERSISTENT` : `_TranslationSetFreq_Hz` défaut **50** (ex-40) ; `_TranslationAutoSpeedCap_Pct` commentée **RÉSERVE MORTE** (ne pas supprimer : mapping RETAIN).
- Essai : auto 50 Hz → Trémie −0,48 m (butée −0,5), P1 5,58 m ; auto 10 Hz → Trémie −0,22 m ; aucun défaut. Programme affiche figé 0/5 m en auto.

## 🚨 Remis en cause (challenger indépendant lancé, résultat NON reçu)

- ❌ Postulat de l'orchestrateur « mot à 0 ⇒ fréquence lue 0 ⇒ l'automate ne voit rien » : **faux** — la fréquence lue décroît ~0,7 s après le mot à 0 (trace 49).
- Mesuré sur 6 décélérations réelles (traces 04/09, 06/09, 23/09) : courbe en **S** reproductible à ±20-40 ms, même frein ouvert/fermé.
- ❓ Nature de la fréquence lue (sortie calculée vs estimation rotor) **non tranchée**. Web : estimation en roue libre possible (tension résiduelle) mais dépend du modèle et s'éteint vite ; doc **AC600 introuvable**.
- ⚠️ L4 renvoie 0 Hz à l'automate pendant la roue libre = hypothèse non fondée → **à revoir après le challenge**. Modèle variateur simu = rampe droite 25 Hz/s, réel = S.
- 👉 À la reprise : relancer le challenge (agent perdu avec la session) — mission : tableau de tous les passages mot→0 réels, verdict P1/P2/P3, affirmations à retirer, corrections simu, 1-3 essais site.

## ⏸️ Reporté / noté

- Treuils : roulis simulé `SimWinchCoast_M` 1,30 m appliqué aussi à M1 (7,5 → 8,8 m) → roulis par axe/sens réaliste.
- CI : G518 rouge (tests TC-T301-SRC à écrire), test `FB_Translation_OdometryGain` ne compile pas, tests simu à réaligner — **seulement sur demande**.
- Programme (T334, plus tard) : estimateur figé au retrait de demande, recalage 5 capteurs, 2 chemins frein aval FB_Brake (coupure Trémie, veto d'étape), `ArrivalStopConfirmed` non consommé, rampe interne sur la demande, `DelayMotorDecel` mort, seuil anomalie 0,5 m vs 2 m.
- TASKS.yaml : décisions en attente (T417/T366 à fusionner, nettoyage verrous/⏳) — l'utilisateur ne les a pas encore examinées.
- Traçabilité site : document à créer **seulement après validation**.

## 🧭 Prochaine étape

1. Challenge postulats fréquence → décision sur L4 (et modèle variateur en S).
2. Commit L4 + L5 si validés.
3. Puis chantier programme T334 testé en simu.
