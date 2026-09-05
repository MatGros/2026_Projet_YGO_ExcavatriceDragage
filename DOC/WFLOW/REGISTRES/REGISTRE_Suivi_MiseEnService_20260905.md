# 🧾 Registre de Suivi Mise en Service — Séance 2026-09-05 (v1.0)

> 🎯 **Rôle** : Historique factuel de la séance banc du 2026-09-05 (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/WFLOW/TASKS.yaml` §3 (registre maître `Txx`).
> 🔗 **Séance précédente** : `REGISTRE_Suivi_MiseEnService_20260904.md` (objectifs ; séances longues, constats versés directement dans `T248`/`T249`/`T250`/`T251`/`T252`, **aucune entrée MES posée** → numérotation MES-046+ laissée libre).
> 🔢 **Numérotation entrées** : démarre aujourd'hui à **MES-046**.

---

## 1. ⚡ Règles & Statuts

### 🚦 Statuts
- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

| Élément | Emplacement |
|---|---|
| Mesure, anomalie, réglage terrain | 📍 Ce registre |
| Code, câblage, action différée | 📌 Ligne `Txx` dans `TASKS.yaml` §3 |
| Évolution CODE/DOC majeure | 📦 `VERSION_HISTORY.md` |

---

## 2. 🎯 Objectifs de séance — 2026-09-05

> Priorité : **boucler le registre `T252`** (points ouverts laissés volontairement le 2026-09-04 au soir), puis valider au banc les dev de nuit, puis reprendre le chantier offset-aware (`T250`).

| # | Objectif | Tâche | Statut entrée séance |
|---|----------|-------|----------------------|
| **1** | **Traces ciblées** : (a) a-coup à la fermeture benne au passage en couple WinchSel 2→0 (grille `WinchSelTransitionHold` / `DirectionChangePending` / `MeasuredSpeed`) ; (b) `[M2] ErrorID:16` en début de montée malgré timer 3 s (hypothèse séquence frein / seuil 0.02 m/s — tracer `MeasuredSpeedSignedMps`, `RelayFwd/Rev`, `BrakeCommandOpenConfirmed`) | `T252` pts 1–2 | 🟠 à tracer aujourd'hui |
| **2** | **Confirmations config après reload complet** (RETAIN) : SYNC 2.0/4.0 ; `OffsetOpenM=0.0` / `OffsetCloseM=15.0` / `CoherenceLimitM=1.0` / `LimitLegal=-19` / palier descente 4 ; `UncommandedDriftToleranceM=5.0` (MecaA) ; frein M3 800 ms / 2 s + test arrêt M3 dur sans défaut | `T252` pts 3–6 | 🟠 à confirmer |
| **3** | **Valider banc les dev de nuit 2026-09-05** : visibilite défaut survitesse M1/M2 → IHM + bandeau (`3a7d58c1`, boucle `T252` pt 7) ; double mesure vitesse codeur brute/filtrée (`3d646619`) ; **WIP non commité** réglages interlock/rampe (`CST_StepRampFloorDelay` 700→400 ms, `RestartDelay` 1500→750 ms, `DirectionInterlockDelayDescent` 400→200 ms, `StepRampDelay(Ascent)` 1000→900 ms) | `T252`, `T248`, `T251` | 🟠 essais en cours |
| **4** | **Offset-aware M2** : blockers B1–B5 (LimitLegal globale, coupure dure descente M2, anti-telescopage/fenêtre haute/AX11 du SEMI_AUTO) + contrat C3 à rédiger avant code | `T250` | ⬜ audit fait, non implémenté |
| **5** | **Homing benne OUVERTE ou FERMÉE** (preset HX3 offset-aware) + tests banc classifieur `T241` — rappel opérateur validé : `OffsetOpenM=0.0` / `OffsetCloseM=15.0` = vraies positions physiques, **ne jamais les modifier** (cf. revert `abbd0aa2` dans `T248`) | `T240`, `T241` | ⬜ / ⏳ |
| **6** | **M3** : bits « at position » trémie/P1/maintenance qui ne s'activent pas + banner/status M3 + bit IHM override trémie (`TglAllowWinchMoveAtTremie`) + renommage champ | `T242`, `T249` | ⬜ |
| **7** | *(si temps)* 1re exécution banc GRAFCET SEMI_AUTO (`T245`, bloqué par `T240`/`T241`) ; passe inventaire défauts (`T243`) ; test hors tension + reboot (`T244`) ; garde re-couplage couple M1/M2 (`T246`) ; reste `T248` (vraie cause NoMovement initiale, réduction `CST_T248TransitionSettle`, anticipations, TC CI) ; arrêt doux FdC haut (`T251`) | `T245` `T243` `T244` `T246` `T248` `T251` | ⬜ |

### Contexte version
- Branche `backup/mes-septembre-20260902`, HEAD `35fe44ff` (2026-09-05 01:37 — simulation roulis benne `FB_SimBench`).
- Commits nuit du 04→05/09 : `3a7d58c1` (survitesse IHM/bandeau), `3393b516` (audit tâches/contrats + script), `28fe37a9` (backup), `3d646619` (encodeur), `35fe44ff` (simulation).
- ⚠️ **WIP non commité** : `FB_WinchOutputInterlock.st` + `ST_fbWinch_Cfg.st` (réglages temps interlock/rampe, tuning banc en cours) + XML bundle régénéré. Pattern : commit `wip(treuils): ... [WIP]` avant essais longs.
- G200/bundle à revalider à la fin du premier lot.

---

## 3. 📝 Entrées de Séance

### MES-046 — Validation Manœuvre Complète Treuils M1/M2 (Descente, Benne, Synchro, Remontée)
- 📅 **Date** : 2026-09-05 08:20 | 📍 **Lieu** : Banc d'essais / Machine | 🏷️ **Version** : `backup/mes-septembre-20260902` (HEAD `35fe44ff` + tuning config)
- 🎯 **Périmètre** : `PRG_04_Treuils_Benne` (`FB_Winch` M1/M2, `FB_Bucket`, `FB_WinchSync`, `FB_Safety_Winch`, `FB_Joystick`)
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai (Trace CODESYS : `Suivi_WinchMatinDescMontee_20260905_29.trace`, 71.4 s / 715 scans)** :
  1. **Ouverture Benne ($t=10.5\text{s} \rightarrow 24.0\text{s}$)** : Descente M2 seule ($P_2: 24.0\text{m} \rightarrow 8.82\text{m}$, $P_1=9.0\text{m}$ fixe). $\Delta P$ passe de $15.0\text{m}$ à $0.0\text{m}$ sans à-coup.
  2. **Descente Synchro M1+M2 ($t=24.0\text{s} \rightarrow 36.5\text{s}$)** : Descente simultanée vers le fond ($P_1: 9.0\text{m} \rightarrow 1.64\text{m}$, $P_2: 8.82\text{m} \rightarrow 2.63\text{m}$). Vitesse max $1.73\text{ m/s}$ (seuil survitesse $2.0\text{ m/s}$ respecté). Écart synchro max $0.99\text{ m}$ (bien sous le seuil d'alarme de $2.0\text{ m}$).
  3. **Inversion Point Bas ($t=36.5\text{s} \rightarrow 40.5\text{s}$)** : Zéro défaut d'inversion, bascule joystick propre.
  4. **Fermeture Benne ($t=40.5\text{s} \rightarrow 52.0\text{s}$)** : Remontée M2 seule ($P_2: 2.63\text{m} \rightarrow 16.54\text{m}$, $P_1=1.64\text{m}$ fixe). $\Delta P$ remonte linéairement de $0.99\text{m}$ à $14.89\text{m}$.
  5. **Remontée Synchro M1+M2 ($t=52.0\text{s} \rightarrow 57.8\text{s}$)** : Montée couplée parfaite ($P_1: 1.64\text{m} \rightarrow 7.57\text{m}$, $P_2: 16.54\text{m} \rightarrow 22.52\text{m}$). Vitesse stable $V_1 = V_2 = 1.47\text{ m/s}$, écart de synchronisation résiduel $< 0.10\text{ m}$.
  6. **Arrêt & Décélération ($t=57.8\text{s} \rightarrow 71.4\text{s}$)** : Ralentissement et retombée propre des freins sans glissement ($P_1$ stabilisé à $8.06\text{m}$, $P_2$ à $23.18\text{m}$).
  7. **Santé Automatisme** : **0 défaut actif** sur l'ensemble des 71.4 s (`Error=0`, `Safety.Error=0`, `RelayFwdMismatch=0`).
- 🛠️ **Solution / Décision** :
  - La dynamique de régulation, l'étagement des contacteurs (1 à 4) et le tracking différentiel $\Delta P$ de la benne sont validés en manœuvre réelle.
  - Absence de faux déclenchement de survitesse (max mesuré $1.95\text{ m/s}$ pour un seuil à $2.00\text{ m/s}$).
### MES-047 — Validation Ouverture Benne en Position Haute après Fin de Course
- 📅 **Date** : 2026-09-05 08:28 | 📍 **Lieu** : Banc d'essais / Machine | 🏷️ **Version** : `backup/mes-septembre-20260902` (HEAD `35fe44ff`)
- 🎯 **Périmètre** : `PRG_04_Treuils_Benne` (`FB_Bucket`, `FB_Winch` M2, `M1M2_TopPositionFree_DI`)
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai (Trace CODESYS : `Suivi_WinchOuvertureBenneApresFdcHaut_20260905_30.trace`, 22.9 s / 230 scans)** :
  1. **État Initial ($t=0.0\text{s}$)** : Treuils en position haute suite à manœuvre précédente ($P_1 = 8.06\text{ m}$, $P_2 = 23.18\text{ m}$, $\Delta P = 15.12\text{ m}$ = Benne fermée). `M1M2_TopPositionFree_DI = 1` (zone libre capteur haut).
  2. **Interlock & Filtrage ($t=2.6\text{s} \rightarrow 5.0\text{s}$)** :
     - Première sollicitation joystick courte ($t=2.6\text{s} \rightarrow 2.8\text{s}$, $Tgt < 10\%$) : non prise en compte (zone morte respectée).
     - Deuxième sollicitation ($t=3.4\text{s} \rightarrow 4.8\text{s}$, $Tgt = 33.8\%$) : le délai d'interlock de direction / redémarrage maintient le treuil à l'arrêt, puis à $t=4.9\text{s}$, ouverture du frein M2 et retombée au neutre à $t=5.2\text{s}$ sans à-coup.
  3. **Manœuvre d'Ouverture Complète ($t=9.0\text{s} \rightarrow 20.7\text{s}$)** :
     - Commande franche joystick descente M2 ($Tgt \approx 52\%$, pointe à $82\%$).
     - `M2_RelayDescent_Open_DQ = 1`, contacteurs commutés progressivement, vitesse de descente M2 stable à $1.55\text{ m/s}$.
     - $P_2$ descend de $22.66\text{ m}$ à $7.93\text{ m}$ pendant que $P_1$ reste rigoureusement fixe à $8.06\text{ m}$ ($V_1 = 0.00\text{ m/s}$).
     - Le delta position $\Delta P$ passe de $14.60\text{ m}$ à **$-0.13\text{ m}$** (Benne 100% ouverte).
  4. **Arrêt & Décélération ($t=20.7\text{s} \rightarrow 22.9\text{s}$)** : Arrêt net de M2 à $7.93\text{ m}$, maintien du frein, **0 défaut** sur tout l'essai.
### MES-048 — Validation Descente / Montée Pleine Vitesse à Vide (100% Joystick)
- 📅 **Date** : 2026-09-05 08:35 | 📍 **Lieu** : Banc d'essais / Machine | 🏷️ **Version** : `backup/mes-septembre-20260902` (HEAD `35fe44ff`)
- 🎯 **Périmètre** : `PRG_04_Treuils_Benne` (M1/M2 Pleine dynamique, Synchro, Survitesse, Zone d'arrêt haut)
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai (Trace CODESYS : `Suivi_Winch_D_M_PleineVitesse_Avide_20260905_31.trace`, 45.8 s / 459 scans)** :
  1. **Descente Synchro Pleine Vitesse ($t=1.8\text{s} \rightarrow 9.0\text{s}$)** :
     - Joystick poussé à $100\%$ (`Tgt = 100%`, Palier 4).
     - Descente M1+M2 depuis le haut ($P_1=8.06\text{m}$, $P_2=7.93\text{m}$, benne ouverte) jusqu'au fond ($P_1 = -0.21\text{m}$, $P_2 = 0.40\text{m}$).
     - Vitesse max mesurée : **$1.90\text{ m/s}$** sur M1 et **$1.61\text{ m/s}$** sur M2 (seuil survitesse à $2.00\text{ m/s}$ respecté sans déclenchement intempestif).
     - Écart synchro max pendant la descente : $0.62\text{ m}$ (tolérance d'alerte $2.0\text{ m}$ largement tenue).
  2. **Fermeture Benne au Fond ($t=10.8\text{s} \rightarrow 25.0\text{s}$)** :
     - Joystick tiré à $99.7\%$ en montée benne seule ($P_2 : 0.40\text{m} \rightarrow 14.59\text{m}$, $P_1 = -0.21\text{m}$ fixe).
     - Vitesse $V_2 = 1.36\text{ m/s}$, $\Delta P$ passe de $0.61\text{ m}$ à $14.80\text{ m}$ (Benne fermée).
  3. **Remontée Synchro Pleine Vitesse ($t=25.2\text{s} \rightarrow 32.2\text{s}$)** :
     - Montée à pleine vitesse ($Tgt = 99.7\%$).
     - Vitesse stabilisée : **$V_1 = V_2 = 1.51\text{ m/s}$** (couplage parfait).
     - Écart de synchronisation résiduel : **$< 0.06\text{ m}$** tout au long de la remontée !
  4. **Arrêt Anticipé / Fin de Course Haut ($t=32.2\text{s} \rightarrow 36.0\text{s}$)** :
     - Coupure des ordres de montée à $t=32.2\text{s}$ ($P_1 = 7.50\text{m}$, $P_2 = 22.46\text{m}$).
     - Stabilisation finale : $P_1 = 8.05\text{m}$, $P_2 = 23.02\text{m}$, $\Delta P = 14.97\text{m}$.
     - Retombée des freins et arrêt complet sans dépassement ni défaut.
  5. **Santé Automatisme** : **0 défaut actif** sur 45.8 s (`Error=0`, `Safety.Error=0`, `RelayFwdMismatch=0`).
- 🛠️ **Solution / Décision** :
  - La tenue en survitesse ($2.0\text{ m/s}$) et le comportement de la chaîne de contacteurs à $100\%$ de consigne sont validés sur l'ensemble de la course.
  - La synchronisation dynamique en montée pleine vitesse est exceptionnelle (écart de 4 à 6 cm).
- 📌 **Action différée** : Néant.

---

## 4. ✅ Procédure de Clôture `Txx`
1. Ajouter l'entrée `MES-XXX` avec preuve (snapshot / trace).
2. Mettre `✅` + réf MES dans `TASKS.yaml` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.
4. Pour tout **bypass granulaire** posé : ligne dans `T243` avec **date de réactivation** cible.
5. Point `T252` traité → cocher/annoter la ligne concernée dans `T252` (ne pas clôturer la tâche avant pts 1–9 soldés).
