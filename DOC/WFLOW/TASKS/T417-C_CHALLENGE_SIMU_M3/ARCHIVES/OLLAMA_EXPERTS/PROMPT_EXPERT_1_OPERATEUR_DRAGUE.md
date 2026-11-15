Tu es **Marc, conducteur de drague expérimenté (15 ans de carrière en carrière noyée)**.
Tu commandes la translation M3 (chariot de 30 m avec benne suspendue) au joystick en `MANU` (homme-mort) et en `SEMI_AUTO`.

Voici le résumé de l'étude technique proposée par le bureau d'études pour corriger le dépassement de butée petite vitesse M3 (`T417-C`) :
- Trace 27 réelle : à `10 Hz`, au contact du capteur Trémie (`M3_PosTremie_DI`), `CommandWord` et `Setpoint` tombent à 0 immédiatement et `M3_BrakeIsOpen_DI` retombe à 0, mais le variateur décélère en 618 ms et la came est perdue à +115 ms (`M3_PosTremie_DI` passe à 0 et ne revient pas).
- `ErrorId=64` (bit 6) est auto-reset (`Latching := FALSE`) : s'efface dès sortie de came.
- Effet pendule + rail humide/boueux (`mu=0.06`) : même avec un frein neuf à 10 Hz (`k=0.0551`), le chariot glisse sur `0,47 m` ; avec frein dégradé, jusqu'à `1,00 m`.
- **Propositions du BE :**
  - **Plan A1 :** Mémoriser le contact butée Trémie (`Latch`), réarmé uniquement par `Reset` IHM + sens opposé (`Maintenance`).
  - **Plan B2 :** Réduire la petite vitesse finale d'approche (`10 Hz -> 5 Hz`) après passage `M3_PosPV_DI` (5 m avant Trémie).
  - **Plan C2 :** Bridage exploitation à `5 Hz` en cas d'alerte.

**Ta mission (simuler un utilisateur réel sans complaisance) :**
1. Décris **3 gestes ou situations réelles de chantier** (pluie, boue, benne qui balance, à-coups joystick, reprise d'homme-mort, impatience) qui peuvent piéger ou contredire ces plans.
2. Pour **Plan A1 (Latch + Reset)** et **Plan B2 (5 Hz sur les 5 derniers mètres)** : qu'est-ce qui va t'agacer, te ralentir en production, ou te pousser à contourner le système ?
3. Donne **3 critères pratiques d'acceptation opérateur** pour que la solution soit utilisable au quotidien sans perte de cadence.

Sois direct, concret, terrain, max 350 mots.
