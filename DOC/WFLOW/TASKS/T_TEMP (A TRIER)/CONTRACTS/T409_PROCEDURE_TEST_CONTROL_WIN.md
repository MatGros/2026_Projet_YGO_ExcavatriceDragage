# T409 — Recette Control Win CW-00 : départ P1 par mémoire

## But

Prouver sur la copie Control Win que la FMU démarre à la position théorique P1 :
20,000 m et mot capteurs physique cumulatif 00011. La preuve PLC attendue est
M3_AtP1Stable à TRUE après la restauration de démarrage.

## CW-00 — ordre obligatoire

1. Dans la copie Control Win, faire Login puis Stop.
2. Démarrer Run, puis mettre manuellement uniquement `SimulationModeActive=TRUE`.
   `SimM3OpenModelicaActive` et `Enable` du bridge sont automatiques dans le POC isolé.
3. Lancer `Start_T409_M3_Integration.cmd` pour ouvrir la FMU et la vue.
4. Vérifier que l'écran affiche `P1`, `20,000 m`, capteurs `00011`, puis que les mesures
   évoluent lorsque le joystick de l'IHM PLC commande un mouvement.
5. Attendre 3 s puis lancer `codesys_m3_t409_acceptance.py` depuis Tools > Scripting.
6. Conserver la sortie console complète. Aucun script miroir n'est nécessaire pour la vue.

## CW-01 — reprise communication

1. Pendant le fonctionnement, arrêter la passerelle FMU : `Timeout=TRUE`, `LinkReady=FALSE`
   et image M3 OM neutralisée sont attendus.
2. Relancer `Start_T409_M3_Integration.cmd` (une passerelle existante est réutilisée ; sinon
   elle redémarre). Ne retoucher ni `SimulationModeActive`, ni le pont.
3. Vérifier que `LinkReady=TRUE`, `Timeout=FALSE`, puis que position, fréquence et capteurs
   reprennent. Répéter après fermeture/redémarrage complet de la passerelle pour couvrir le
   compteur de séquence remis à zéro.

## Verdicts

| Verdict | Sens |
|---|---|
| PASS_MEMOIRE | LinkReady stable 2 s, candidat=3, mot=3, AtP1=TRUE, AtMaintenance=FALSE, persistance P1=TRUE. |
| PASS_FRONT_ORDRE_KO | État final P1 correct, mais la restauration mémoire n'a pas été prouvée. Rejouer CW-00 après un arrêt propre. |
| FAIL | Liaison, bits simulation, chemins symboles ou état P1 non conformes. Ne pas conclure. |

## Hypothèse à vérifier humainement

Un Reset peut remettre les flags simulation et les variables de boot à leur valeur
par défaut. Ce comportement doit être observé dans la copie Control Win ; il n'est
pas supposé par cette recette.

## Option C3 à décider, sans code dans ce lot

Modifier PRG_05_Translation afin de ne pas restaurer AtPosition tant que la
simulation M3 OpenModelica est active et que LinkReady est FALSE.

- Impact : évite qu'un mot 00000 de liaison absente soit interprété comme Maintenance.
- Risque : modifie une logique de positionnement C3 et son démarrage.
- Pré-requis : nouvelle tâche, contrat C3, analyse AF-11 et validation humaine.
- Décision : non prise ; aucun fichier CODE n'est modifié ici.
