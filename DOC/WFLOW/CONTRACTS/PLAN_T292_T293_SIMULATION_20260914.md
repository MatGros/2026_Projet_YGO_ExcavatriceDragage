# T292 / T293 — Proposition de reprise

Date : 2026-09-14. Responsable : Codex. Criticité : C2. Stratégie : patch.
Statut : plan proposé, validation humaine avant édition ST.

## Décision de reprise

L'utilisateur demande une conception neuve à partir du code actuel, sans réutiliser
l'intégration retirée. Son historique reste consultable dans Git ; il ne conditionne
pas cette reprise. Aucun diagnostic historique n'est considéré comme démontré par
la seule absence d'écriture directe sur M1.

## T292 — Kobold automatique

- `SimKoboldAutoModeActive` dans `GVL_Simulation` : mis à TRUE à l'entrée en
  simulation avec SEMI_AUTO actif, ou à l'entrée SEMI_AUTO pendant la simulation.
  Mis à FALSE à la sortie SEMI_AUTO ou simulation. L'opérateur peut le désactiver
  pendant SEMI_AUTO : aucune réécriture TRUE à chaque scan.
- `SimKoboldAutoDepth_M` : altitude signée du fond, défaut -15.0 m.
- `SimKoboldPowerUpTime` : délai de réponse à l'alimentation, proposition T#50ms.
- `SimKoboldCoast_M` : roulis après coupure des relais lors de la plongée Kobold,
  proposition 1.0 m, dispersion bornée ±0.1 m par plongée, commune aux deux axes.
  Ce sont des paramètres de banc, pas des mesures terrain certifiées.
- Le modèle observe l'ordre final d'alimentation Kobold et la position M1 signée,
  référencée comme `FB_Encoder_Scale` (référence homing effective, pas ABS).
- Automatisme actif : DI=0 sans alimentation ; DI=1 après le délai si au-dessus
  du fond ; DI=0 dès PositionM1 <= seuil. Une activation déjà sous le fond ne
  fabrique pas une fausse impulsion d'immersion.
- Automatisme inactif : DI suit exclusivement `SimKoboldContactValue`, comme avant.
  Pas de OR du stimulus manuel dans le modèle automatique : il empêcherait le
  front descendant si le stimulus était resté TRUE.
- L'arrêt est effectué par le programme existant. Le banc continue à compter sur
  les ordres effectifs puis sur son roulis. Aucun gel ou repositionnement au seuil.
  La distance totale dépasse éventuellement le roulis paramétré : elle inclut les
  délais du programme et la distance parcourue avant la chute des relais.
- Un arrêt hors plongée Kobold conserve le roulis existant. Maintenir la distance
  armée jusqu'à son épuisement même si l'alimentation Kobold vient de tomber.

Références : `FB_CycleSemiAuto` AX5/AX6/AX7/AX8 ; 500 ms d'établissement,
500 ms de qualification du niveau haut, 100 ms de confirmation du niveau bas.
`PRG_06_Outputs` applique `M1_M2_KoboldMeasureEnable_DQ`.

## T293 — M2 plus lent, position continue

`SimM2CoupledDescentModelActive` : bit modifiable, défaut TRUE.
Pendant la descente BOTH effective, M2 est calculé principalement depuis M1 :

```text
M2_raw = M2_raw_départ + 0,9333 × (M1_raw - M1_raw_départ)
```

Les deux origines sont figées à l'entrée de la phase. L'écart initial est préservé
sans saut de position. Le calcul reste actif à toute profondeur, sans bornage à
-15 m, tant que l'intention BOTH et les deux relais de descente sont effectifs.
À la sortie, la dernière position est celle du codeur M2 simulé : le modèle
indépendant reprend donc sans discontinuité.

Justification : l'offset 1.1728 m dépend de la trajectoire et de la position
corrigée d'affichage de benne. Il n'est pas écrit dans le codeur brut. Les origines
ancrées conservent la géométrie présente. Aucun écrêtage caché de l'écart ne
neutralise les alarmes du vrai programme.

Le facteur 0,9333 est recalé sur l'essai terrain communiqué : environ 0,6 m d'écart
pour 9 m de descente (`1 - 0,6 / 9`). Il reste une hypothèse de simulation à valider
sur plusieurs plongées ; le RMSE
annoncé de 3 cm ne constitue pas une validation de la trajectoire simulée complète.
Une extrapolation à toute profondeur est demandée et peut
déclencher les protections de synchronisme existantes.

## Périmètre et conception

Modifier `CODE/L_SIMULATION/FB_SimBench.st`, `GVL_Simulation.st`, le câblage/reset
dans `CODE/M_MAIN/PRG_02_Acquisition.st`, la documentation AF13, les contrats,
les tests/garde-fous de simulation et le bundle généré.
Réutiliser `FB_Sim_Encoder` via ses paramètres existants si les essais le permettent.
La logique cycle, benne, protections et sorties physiques conserve ses algorithmes.

Nommage : `NAMING_CONVENTION.md` NC-030 impose `_M` pour les distances ; NC-080
place M2 juste après Sim dans la GVL plate ; NC-050 distingue la requête `Req`
du signal final `Cmd`. La simulation consomme ce dernier. La chaîne fonctionnelle
reste Req → Tgt → Cmd → Act : le codeur simulé fournit la mesure Act au vrai
programme ; une écriture de M2PositionCorrected contournerait cette chaîne.

## Preuves à produire après accord

1. Tests exécutant le ST : séquence DI alimentation/délai/fond/coupure,
   entrée/sortie SEMI_AUTO, désactivation manuelle persistante, seuils -5/-15/-25 m.
2. M2 : bit OFF comparé au modèle actuel, origines de phase, calcul positionnel
   à toute profondeur, bascules ON/OFF en mouvement, montée, M2 seul, homing et
   position/vitesse cohérentes.
3. Intégration : mouvement M1 observé, AX5→AX6→AX7→AX8 avec les vraies conditions
   joystick/paliers, DI basse au fond, position arrêtée après roulis, aucune
   neutralisation de défaut pour faire passer le test. Les deux fonctions sont
   testées séparément puis ensemble.
4. Garde-fou automatique sous `TOOLS/AGENT_WORKFLOW/scripts/` contre l'inversion
   de polarité, l'override discontinu de position et la modification des protections.
5. Bundle complet généré, diff bundle `CODE_DiffBundle.xml` contenant
   `FB_SimBench`, `GVL_Simulation`, `PRG_02_Acquisition`, G200 `--report`, G310,
   palier C et suite complète des gates. Les essais CODESYS manuels restent une
   étape distincte de la validation hors PLC.

Les critères des deux contrats sont réalignés sur ce plan proposé ; leurs sections
execution/validation historiques restent explicitement identifiées comme anciennes.
Ni code ST, ni bundle, ni commit ne sont produits à ce stade.
