# 🧾 Mise en service — journal du 21/09/2026 et préparation du 22/09

> État initial : préparation. Les cases vides ne valent ni validation logicielle ni recette machine.
> Responsable des essais et des manœuvres électriques : équipe habilitée sur site.

## 1. Changement d'alimentation prévu le 22/09

| Point | À renseigner sur site |
|---|---|
| Intervention | Déconnexion du groupe électrogène ; alimentation par câble de puissance du distributeur |
| Responsable, habilitations, heure, consignation |  |
| Schéma et protections vérifiés par l'équipe électrique |  |
| Tension, fréquence, ordre des phases, terre et protections mesurés avant remise sous tension |  |
| Variateurs et paramètres vérifiés après remise sous tension |  |
| Décision d'autoriser les essais moteurs |  |

⚠️ La nouvelle source peut changer les chutes de tension et la réponse des entraînements. Relever les mesures et les comportements réels ; aucune hypothèse de couple ou de freinage supplémentaire n'est validée à ce stade. Les essais en mouvement restent conditionnés à la vérification électrique et aux protections machine par les responsables sur site.

## 2. Priorités logicielles avant essais réels

| Priorité | Sujet | Preuve attendue | Simulation | Machine |
|---|---|---|---|---|
| P0 | MAINT_N2 : M1 seul, M2 seul, M1+M2, chaque sens ; desserrage freins | Trace bouton IHM → arbitrage → barrière finale → sorties, avec conditions de refus explicites | ⬜ | ⬜ |
| P0 | Graphe homing T364 | Graphe HX0..HX7 relu et accepté, puis cas nominaux/échecs/reprises | ⬜ | ⬜ |
| P0 | AX14→AX15A T345-L2 et transitions P1 | Cas maintien joystick, neutre, diagonale, arrêt/reprise et non-régression AX2 | ⬜ | ⬜ |

Référence de test existante : [TEST_SIMU_T364_T345L2_20260921.md](../CONTRACTS/TEST_SIMU_T364_T345L2_20260921.md). Les résultats restent à relever ; ne pas convertir cette feuille en « PASS » par déduction du code.

## 3. Journal des essais et anomalies

| Date/heure | Banc / machine | Version PLC / bundle | Tâche | Action et conditions initiales | Résultat observé | Attendu | Décision / responsable |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

Pour un échec, conserver l'étape (`State`/`SeqStep`), le message IHM exact, les commandes et retours contacteurs, l'état des freins, les positions et un extrait de trace horodaté. Aucun forçage de sécurité n'est implicite dans ce journal.

## 4. Décisions de fin de journée

| Sujet | Décision, auteur et heure | Preuve associée | À reporter au catalogue |
|---|---|---|---|
| Alimentation électrique |  |  |  |
| MAINT_N2 |  |  |  |
| Homing |  |  |  |
| AX14 / P1 |  |  |  |
