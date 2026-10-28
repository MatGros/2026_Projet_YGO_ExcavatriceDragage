# Mise à jour dynamique M3 — bilan et essais courts

> Etat courant du chantier : T417 dans DOC/WFLOW/TASKS.yaml et son contrat lie. Ce document conserve le cadrage ou le bilan anterieur ; il ne vaut pas validation du lot courant.

## Décisions de l'exploitant

- Même mécanique en manuel et automatique, commandes finales après interlocks.
- En mise en service, rampe automate rendue brutale pour régler la décélération limite
  du variateur ; rampe automate ensuite réglée légèrement plus douce. Le modèle conserve
  une décélération pilotée après retrait du mot, sans roue libre immédiate.
- Vitesse estimée 1 m/s à 50 Hz ; positions 0 / 1,5 / 3,5 / 5 / 10 m et marge de butée
  0,5 m acceptées comme hypothèses. Came spatiale 2 cm + 4 cm conservée.
- Balancement conservé avec son faible effet sous contrôle variateur. Ni amplification
  pour obtenir un dépassement, ni plafond artificiel de distance.
- Frein de parking normalement commandé à très basse fréquence. Le banc exécute aussi
  une fermeture en mouvement si la bobine finale le commande : aucune garde basse fréquence
  ajoutée dans la mécanique pour masquer cette situation.
- À 0,5 Hz et avec le gain estimé, 90 ms représentent 0,9 mm à vitesse constante.

## Correction et sauvegarde

Checkpoint avant correction : `fd32b652`, 14 fichiers ST/XML du chantier L4/L5.

Seul ST modifié depuis ce checkpoint : `CODE/L_SIMULATION/FB_Sim_Translation.st`.
Le frottement est appliqué comme une impulsion dissipative bornée à zéro après la
poussée externe. Il ne peut plus retourner une vitesse faible à lui seul ; une poussée
opposée suffisante peut toujours produire une inversion réelle. Aucune interface publique
ni aucun réglage physique modifié.

Avant : vitesse +0,004 m/s, frottement 0,1 m/s², pas 100 ms → −0,006 m/s artificiellement.
Après : arrêt à zéro dans les deux sens. Le balancement, la came et le frein restent présents.

## Vérification fonctionnelle

Garde rejouable : `py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_sim_m3_dynamics.py`.
Il compile et exécute neuf scénarios sur les vrais FB ST avec STruCpp, sans copie Python
du modèle ni CI globale. Cela ne remplace pas une compilation CODESYS.

| Scénario | Observation attendue |
|---|---|
| 010 / 020 | Retrait à 20 / 50 Hz : fréquence décroissante, sens conservé, arrêt final |
| 030 / 040 | Frottement dans les deux sens à 100 / 10 ms, sans inversion numérique |
| 050 / 060 | Adhérence au repos et inversion possible sous poussée opposée suffisante |
| 070 | Fermeture mécanique du frein après coupure bobine, même avec fréquence non nulle |
| 080 | Pendule présent, contribution secondaire sous contrôle et oscillations amorties |
| 090 | Came spatiale dans les deux sens, sans intermittence temporelle ajoutée |

Résultat initial : 8/9, seul 030 échoue. Résultat corrigé : 9/9.
Revue indépendante : PASS ; seconde revue `deepseek-v4.1-flash:cloud` : PASS avec demande
de rendre explicite le frottement des tests, remarque appliquée. L'orchestrateur a vérifié
la valeur réelle 0,1 et conserve la responsabilité des résultats d'exécution et de liaison.

Preuves : `SCENARIOS_AVANT_UPDATE.txt`, `SCENARIOS_APRES_UPDATE.txt`,
`REVIEW_DEEPSEEK_V41.md`, `LIAISON_APRES_UPDATE.txt` et comparaison des gates avant/après.

## Essai CODESYS — projet de simulation

1. Importer `CODE_XML/CODE_DiffBundle.xml`, compiler, puis activer la simulation comme
   habituellement. Le bundle complet est aussi disponible. GVL_PERSISTENT est géré séparément
   par CODESYS et n'est pas modifié par le correctif.
2. Garder le facteur vitesse du banc à 1 et les réglages retenus. Intermittence temporelle
   et blips capteurs désactivés ; came et frein physique restent actifs.
3. Manuel : un trajet vers P1, un vers Trémie ; noter l'arrêt puis le relâchement du joystick.
4. Auto : un trajet vers P1, un vers Trémie, sans changer la mécanique simulée.
5. Pour chaque trajet : noter **arrêt propre / dépassement / butée / défaut affiché**.

Observation utile en ligne : `GVL_Simulation.SimM3ObsPositionTrue_M`,
`SimM3ObsPositionError_M`, `SimM3ObsOvershootLast_M` et `SimM3ObsEndStopHitCount`.
Le dernier dépassement n'est actualisé qu'à l'arrêt. Un zéro instantané de vitesse dans
une oscillation libre n'est pas une preuve d'immobilisation définitive.

L'apparition d'un défaut reste un résultat à analyser, pas une cible. La validation
utilisateur dans CODESYS reste en attente.

## Gates et limites de validation

Palier C : 9 échecs sur 61 avant correction, 8 après régénération du bundle :
**53/61 PASS**, G390 fraîcheur désormais PASS. Les huit gates restant en échec étaient
déjà rouges : G300, G340, G430, G483, G503, G517, G518, G519. Aucun nouveau gate en échec.
Le lot n'est pas déclaré globalement vert. G518 signale deux scénarios source unique
T301 absents des anciens tests ; leur chantier et la réparation de ces gates restent distincts.

Le runner du palier C a actualisé le rapport WINCH_INTEG existant. Ce rapport et les annexes
préexistantes restent sur disque, sans nettoyage ni intégration dans le checkpoint ST/XML.

## Auto-vérification liaison

```text
Auto-verification liaison (G200_check_linkage.py) — PASS
  Linkage (L1-L7):    140 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 25 WARN
  L10 (Single prod):  2021 OK, 1663 WARN
  L11 (Polarity):     0 OK, 29 WARN
  L12 (Timing):       7 OK, 0 KO, 0 WARN
  L13 (Orphelins):    89 OK, 0 KO
  OK  instFault : FB_FaultCore — declaree CODE/A_COMMUN/FB_Brake.st:49 · appelee :84
  OK  instCloseThreshold : FB_BucketCloseThreshold — declaree CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:151 · appelee :615
  OK  instFault : FB_FaultCore — declaree CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:145 · appelee :303
  OK  instFault : FB_FaultCore — declaree CODE/G_CYCLE/FB_CycleMachineHoming.st:103 · appelee :363
  OK  instFault : FB_FaultCore — declaree CODE/G_CYCLE/FB_CycleSemiAuto.st:268 · appelee :559
  OK  instAbs : FB_Encoder_Abs — declaree CODE/E_CODEURS/FB_Encoder.st:71 · appelee :117
  OK  instFault : FB_FaultCore — declaree CODE/E_CODEURS/FB_Encoder.st:77 · appelee :109
  OK  instHoming : FB_Encoder_Homing — declaree CODE/E_CODEURS/FB_Encoder.st:72 · appelee :131
  OK  instRel : FB_EncoderReliability — declaree CODE/E_CODEURS/FB_Encoder.st:75 · appelee :176
  OK  instSafety : FB_Encoder_Safety — declaree CODE/E_CODEURS/FB_Encoder.st:74 · appelee :164
  OK  instScale : FB_Encoder_Scale — declaree CODE/E_CODEURS/FB_Encoder.st:73 · appelee :155
  OK  instSpeed : FB_Encoder_SpeedMeasure — declaree CODE/E_CODEURS/FB_Encoder.st:76 · appelee :184
  ... 2156 autres verifiees
  !   [L9] CODE/M_MAIN/PRG_02_Acquisition.st: Data — Not found in I/O map by exact name — verifier manuellement contre le nom de canal brut du CSV (convention de nommage differente)
  !   [L9] CODE/M_MAIN/PRG_02_Acquisition.st: HwReal — Not found in I/O map by exact name — verifier manuellement contre le nom de canal brut du CSV (convention de nommage differente)
  !   [L9] CODE/M_MAIN/PRG_02_Acquisition.st: HwSim — Not found in I/O map by exact name — verifier manuellement contre le nom de canal brut du CSV (convention de nommage differente)
  !   [L9] CODE/M_MAIN/PRG_02_Acquisition.st: HwIn — Not found in I/O map by exact name — verifier manuellement contre le nom de canal brut du CSV (convention de nommage differente)
  !   [L9] CODE/M_MAIN/PRG_06_Outputs.st: Data — Not found in I/O map by exact name — verifier manuellement contre le nom de canal brut du CSV (convention de nommage differente)
```
