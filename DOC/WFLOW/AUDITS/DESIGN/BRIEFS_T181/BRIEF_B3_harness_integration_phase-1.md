# BRIEF B3 — Spécifier le harness d'intégration ST (Phase -1, BLOQUANT)

> Pour codex terra. À COLLER TEL QUEL. Joindre : `subagent_preamble.md` +
> `PLAN_GEL_TREUIL_T181_CONSOLIDE.md`. SPÉCIFICATION SEULEMENT — pas de code produit,
> aucun fichier modifié, aucun commit.

---

## Préambule

Lis `subagent_preamble.md` (joint). Expert Senior Automatisme CODESYS 3.5 + test/CI industriel.
FR, concis, tableaux. Tu **spécifies** un harness de test ; tu n'écris pas son implémentation.

## Contexte

Excavatrice de dragage. Sous-système treuil : **paire M1 (retenue) + M2 (benne)**, câble commun,
benne portée par M2 → asymétrie de vitesse entre crans M1/M2 = risque télescopage / surtension câble.

Chaîne réelle (à faire tourner ENSEMBLE dans le harness) :
```
PRG_03_Modes_Cycle   (décision cycle, construit Data.ReqProgram.ReqWinchM1/M2 + ReqBucket)
   → PRG_04_Treuils_Benne  (orchestration paire : arbitrage §3, permits §5, clamp palier §6)
      → FB_Winch ×2  +  FB_Safety_Winch ×2  +  FB_WinchSync  +  FB_Winch_Symmetry
         → PRG_06 / FB_WinchOutputInterlock   (barrière finale)
```
Producteurs d'intention amont : `FB_Cycle` (Grafcet semi-auto X0-X13), `FB_DiveSearch` (plongée
Kobold), `FB_ExtractionSequence` (montée contrôlée), chaîne joystick (`FB_Joystick` →
`FB_AxisScale`), IHM directe (`GVL_IHM.M1TreuilRetenue.Cmd` …), `FB_Modes` (sélection couplé/M1/M2).

**Le problème** : le CI actuel (`TOOLS/TEST_AUTO_CI/`, STruCpp unitaire) teste chaque FB isolé.
**Aucun test ne fait tourner la chaîne PRG_03→PRG_04→FB_Winch×2→PRG_06 ensemble.** Les défauts
d'intégration (clamp M1≠M2, anti-traversée benne = chemin mort, `FinalInterlockGoverned`) passent
tous les contrôles unitaires = faux vert. Le plan T181 exige ce harness **en Phase -1, bloquant
tout le reste**.

## Ta mission — spécifier le harness `test_integ_winch_pair`

### 1. Périmètre & montage
- Quels POU instancier réellement, lesquels stubber, quelles E/S physiques simuler (capteurs
  position câble `CablePosM`, FDC, contacteurs + retour, homing 8,5 m, `MeasuredSpeedBand`).
- Modèle de temps : MainTask 10 ms — comment le harness cadence les cycles, combien de cycles
  par vecteur, gestion des tempos (`BusinessStepDelay`, interlocks directionnels, watchdog frein).
- Un modèle physique minimal de la paire (position M1/M2 intègrent la vitesse-cran, écart =
  déviation sync) : jusqu'où va-t-on ? (le strict nécessaire pour les oracles, pas un simulateur).
- Où ça se branche dans `TOOLS/TEST_AUTO_CI/` (va lire la structure : runner, format des cas,
  reporting JSON) — nouveau dossier ? nouveau type de cas ? intégration à `run_all_gates.py` ?

### 2. Catalogue EXHAUSTIF des vecteurs de test
Table : `id | scénario | entrées (mode, producteur, geste, capteurs) | séquence temporelle |
oracle (sortie attendue mesurable) | défaut qu'il attrape`.
Couvre au minimum :
- **Grafcet↔Winch** : chaque étape X1…X11 du cycle semi-auto → `{Direction, SpeedPct}` émis →
  `StepNumber` M1 et M2 résultants compte tenu des clamps (bordure, sync, homing approach).
- **Joystick↔Winch** : rampe de déflexion 0→100 % puis 100→0 → séquence `StepNumber`
  (avec / sans `MinStepDescent`), forme d'accostage (`StepNumber` ≤ +1 par cycle), relâche → 0
  immédiat.
- **Plongée Kobold** : effleurement joystick ~5 % avec plancher palier 3 → transitions
  `0→1→2→3` temporisées (anti-à-coup) ; interdiction palier 5 effective ; sortie de plongée.
- **Régression M1** : benne en jog lent (`M2_BucketJogLimit`) + M1 demande palier 4 → **M1
  reste à 4** (le clamp benne ne doit PAS brider M1).
- **Autorité des 2 interlocks** : nominal → `FinalInterlockGoverned` reste FALSE sur 100 % des
  vecteurs ; injection cadence > seuil safety en contournant l'instance `FB_Winch` → l'instance
  `PRG_06` coupe ; pas de double-freinage quand l'instance `FB_Winch` gouverne déjà.
- **Sync paire** : déviation injectée → `SyncDeviationWarn` → plafond palier 1 **sur M1 ET M2**.
- **Anti-traversée benne** : M1 et M2 en mouvement conflictuel → `M1_Busy`/`M2_Busy` réellement
  consommés bloquent le croisement (le TC actuel teste un chemin mort).
- **Sécurité** : `Enable=FALSE` → sorties sûres + latches OK ; watchdog frein ; temps morts
  directionnels ; coast-down borné (`CfgWinchCoastMax_M`).
- **Redémarrage à chaud** : `FirstScanDone` capture `CommandedDirection` — vérifier qu'un
  warm restart ne bypasse pas l'interlock direction.

### 3. Oracles
Pour chaque famille : comment on décide PASS/FAIL de façon déterministe et **sans HIL**. Ce que
le harness NE pourra pas prouver (à remonter comme limite explicite → essais site).

### 4. Effort & séquencement
Estimation (S/M/L) de l'implémentation du harness. Ordre de mise en place. Ce qui doit être prêt
avant de déclarer Phase -1 terminée (critère de sortie mesurable).

## Restitution

FR, tableaux, `fichier:ligne` pour tout renvoi au code réel (tu peux lire `CODE/` et
`TOOLS/TEST_AUTO_CI/`). Pas de code d'implémentation. Aucun commit, aucune écriture.
