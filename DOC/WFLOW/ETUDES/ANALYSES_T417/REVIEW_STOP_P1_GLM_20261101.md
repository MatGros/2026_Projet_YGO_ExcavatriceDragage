**⚠️ Alerte préalable (devoir d'alerte, contrat)** — aucune commande ni lecture n'étant possibles dans cette session, je ne dispose **d'aucun contenu** des 8 fichiers listés. Le contrat exige des refs `fichier:ligne` : les produire reviendrait à les inventer → je ne le fais pas. Marquage : **[F]** = fait fourni par l'énoncé (R12 = 10,5 s → 00111/P2 ; R9 = 15 s → 00001/Maintenance après jeton P1 ; écart brut **4,5 s**) ; **[H]** = hypothèse à vérifier sur sources. Heartbeat non journalisé : interaction interdite par le contrat lecture-seule — signalé.

## 1) 🔄 Contre-hypothèses au diagnostic « dépassement/dérive »

- **CH1 — Lags d'échantillonnage constants [H]** : le jeton P1 est observé 1 cycle après émission ; le code capteur est produit par le décodeur 1 cycle après franchissement de position. L'écart 4,5 s serait une **somme de retards fixes (k·dt)** : chronologie **décalée**, pas étirée. Aucune dérive.
- **CH2 — Attente d'une donnée hors-motion [H, la plus structurante]** : 00001 est étiqueté « Maintenance ». Si ce code est produit par une **autre chaîne productrice** (interlock/état maintenance) que la translation, aucun décalage temporel ne peut le faire apparaître : R9 expire car la donnée n'est **jamais produite**, pas parce qu'elle arrive tard.
- **CH3 — Bases de temps hétérogènes [H]** : TON évalués en temps tâche vs intégration pas-à-pas du modèle M3 (dt fixe du harnais) → décalage de phase **constant à l'initialisation**, interprété à tort comme dérive.

## 2) 🔗 Producteur → consommateur (où l'écart s'insère)

Chaîne [H, rôles présumés d'après les noms de fichiers] :

```
FB_SimBench / FB_CycleSemiAuto  (jeton P1)
   → FB_Sim_Translation         (intégration position, rampes)
   → FB_Translation + FB_Translation_PositionDecoder (quantification → codes capteurs)
   → harnais test_t417_m3_integrated.st / run_t417_m3_integrated.py (R9, R12, assertions)
```

Trois coutures candidates : **(a)** front jeton émis vsobservé ; **(b)** seuil/hystérésis du décodeur vs position simulée ; **(c)** démarrage TON vs observation du code. Le préambule impose de vérifier que la donnée atteint le **consommateur final** : c'est précisément l'objet de M1–M3. La couture fautive ne peut pas être désignée sans les sources.

## 3) 🎛️ Proposition instrumentée discriminante

| Instr. | Mesure | Signature attendue | Seuil dérivé |
|---|---|---|---|
| **M1** Horodatage | t(P1↑ émis), t(P1↑ consommé), t(code 00001→00111), t(R9.IN), t(R12.IN), dt/step | constant → CH1/CH3 ; croissant linéairement en t → dérive vraie | lag toléré ≤ **2·dt** (dt : constante harnais à lire) ; dérive si pente > 2·dt par tranche de 10 s |
| **M2** Forçage | Maintenance (producteur de 00001) forcé vrai **avant** P1 | écart s'effondre → CH2 | écart résiduel < 2·dt, sinon CH2 rejetée |
| **M3** Balayage vitesse | ×0,5 / ×1 / ×2 sur FB_Sim_Translation | invariant au temps mais ∝ distance → hystérésis décodeur ; invariant aux deux → condition logique ; ∝ temps seul → dérive | seuil hystérésis = h_décodeur / v_sim (constantes à lire) |

**Décision** : M1 constant + M2 efficace → **CH2** (producteur 00001 coupé/défaillant — recalibrer les timers serait un remède placebo). M1 constant + M2 sans effet → **CH1**. M1 croissant → diagnostic initial confirmé. **M2 d'abord** : test le plus économique.

## 4) ⚠️ Limites

- 0 ref `fichier:ligne` vérifiable : lecture impossible (contrat lecture-seule, zéro commande).
- Constantes **non vérifiées** : dt, hystérésis du décodeur, rampes de FB_Sim_Translation, presets R9/R12 → tous les seuils restent des **formules à caler**, volontairement sans valeurs numériques inventées.
- Sémantique 00111/00001 reprise telle quelle de l'énoncé ; mapping capteurs (AF_Partie) non recoupé.
- **Demande** : fournir les extraits des 8 fichiers (ou autoriser la lecture native, sans commande) pour citer précisément et clore l'audit contradictoire.

Aucun fichier modifié, aucune commande exécutée.