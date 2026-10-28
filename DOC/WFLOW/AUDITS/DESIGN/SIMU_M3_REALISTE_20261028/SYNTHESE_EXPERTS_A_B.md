# 🧑‍🔬 Synthèse — Experts A et B (simulation M3), 2026-10-28

> Deux sous-agents indépendants, lecture seule, branche `work/base-machine-simu` (HEAD a6b45c92).
> Rapports d'origine écrits dans le scratchpad de session, **perdus** au redémarrage : cette synthèse les reconstitue depuis la conversation.
> ✅ fait prouvé (fichier:ligne) · ❓ hypothèse.

## 1. ✅ Accord des deux experts

| # | Constat | Preuve |
|---|---|---|
| F1 | Vitesse chariot = f × gain, 1er ordre τ 0,15 s, **sans masse** | `FB_Sim_Translation.st:253-259` |
| F2 | Frein fermé ⇒ vitesse 0 instantanée | `FB_Sim_Translation.st:260-262` |
| F3 | Frein simulé ne retombe que si f ≤ 0,5 Hz : **logique PLC placée dans l'usine simulée** | `FB_Sim_TranslationBrake.st:69` |
| F4 | Butées 0 / 30 m, capteur Trémie 0,05, Maintenance 29,95 → dépassement écrasé | `FB_Sim_Translation.st:137-148,266-274` |
| F5 | Réaction pendule sur chariot quasi nulle (0,2 × angle × dt) | `FB_Sim_SuspendedLoad.st:46-48` |
| F6 | Bruit capteur ±1 cm < hystérésis 2 cm → aucun clignotement ; intermittence/blip OFF par défaut (politique T300) | `FB_Sim_Translation.st:57,63,324-333` |
| F7 | Aucun indicateur de dépassement publié | `FB_SimBench.st:636-637` |
| F8 | Garde-fou : banc seulement si `SimulationModeActive` + `SimTranslationActive`, `HwIn := SEL(HwReal, HwSim)` | `PRG_02_Acquisition.st:136,289,450-453` |

## 2. 🕰️ Historique « inertie »

- Aucune inertie massique M3 jamais codée.
- `fd12dc08` (T300-C3) : **mémoire de sens** pendant la décélération variateur — dans HEAD, à garder.
- T417 L2 « roue libre » : planifiée puis **abandonnée** (V2), la trace montre une rampe ~25 Hz/s (`PLAN_T417_SIMBENCH_M3_ROUE_LIBRE.md:3`).
- `SimWinchCoast_M` = roulis **treuils**, pas M3.
- Modelica `M3_POC.mo` : même garde 0,5 Hz, pas de masse.

## 3. 🔧 Côté programme (ce que la simu doit révéler)

| # | Fait | Preuve |
|---|---|---|
| M1 | Coupure dure Trémie sur DI brut, frein + mot 0, seulement si demande Trémie | `PRG_06_Outputs.st:428-450` |
| M2 | Veto SEMI_AUTO hors AX2/AX14 : frein FALSE + mot 0 en aval de `FB_Translation` | `PRG_05_Translation.st:399-409,700-706` |
| M3 | `FB_Brake` : MovementRequested = rampe interne > 0,1 OU f > 0,5 Hz (≤ 2 s) | `FB_Translation.st:312-332` |
| M4 | Incohérence commande/retour frein > 1000 ms → « Défaut séquence ou retour frein translation » | `FB_Brake.st:114-126`, `ST_fbTranslation_Cfg.st:35` |
| M5 | Watchdog final 500 ms (ouverture non confirmée) | `FB_TranslationOutputInterlock.st:85-110` |
| M6 | Calculateur de position : recalage sur **5 capteurs**, intégration seulement si demande active | `FB_Translation_PositionEstimator.st:145-165,196-202` |
| M7 | `ArrivalStopConfirmed` publié, consommé nulle part | `FB_Translation.st:381` |
| M8 | `FB_Brake.DelayMotorDecel` jamais utilisé | `FB_Brake.st:93,103` |

❓ Mécanisme probable du défaut frein (les deux experts) : `FB_Brake` croit encore commander l'ouverture pendant la rampe interne, alors que M1 ou M2 a fermé le frein → écart proche du timeout 1 s → « parfois ».

## 4. ⚖️ Divergences et arbitrage orchestrateur

| Sujet | Expert A | Expert B | Arbitrage |
|---|---|---|---|
| Priorité 1 | Frein physique + roue libre (inertie, pendule) | Frein physique + glissade ; roue libre non justifiée | Frein d'abord (L3), poussée benne ensuite (L4), à la demande de l'utilisateur |
| Pente rampe auto | — | 100 %/s → ≈ 1 s | Les deux : rapide tant que la demande vise un sens interdit, normale (50 %/s) après retrait |
| Tests | Harnais CI avec interlock réel, coupure Trémie, veto | Campagne T1-T5 ; T4 = changer la rampe | T4 d'B **écarté** : rampes figées par l'utilisateur |
| Clignotement | Émergent du chariot qui oscille | Oscillation pendule + rebond de came | Utilisateur : mécanisme **normal** de franchissement (vu → perdu → retrouvé → fixe) selon la position |

## 5. 🏆 Propositions retenues dans le plan

Frein physique (L3) · positions/échelle depuis `GVL_PERSISTENT` + marge butée 0,5 m (L1) · indicateurs (L2) · poussée benne (L4) · capteurs franchissement (L5) · harnais CI complété (`FB_TestLoopTranslation` : interlock réel, coupure Trémie, veto) · gate anti-lecteur `GVL_Simulation`/`instSimBench`.

## 6. 🗑️ Écarté par les experts

Modelica/TwinBench · modèle électrique AC600 · élasticité câbles · rebond élastique butée · bruit blanc DI · blip différent par capteur.
