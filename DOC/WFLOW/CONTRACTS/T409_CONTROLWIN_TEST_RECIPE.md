# T409 — Recette Control Win CW-00 : départ P1 par mémoire

## But

Prouver sur la copie Control Win que la FMU démarre à la position théorique P1 :
20,000 m et mot capteurs physique cumulatif 00011. La preuve PLC attendue est
M3_AtP1Stable à TRUE après la restauration de démarrage.

## CW-00 — ordre obligatoire

1. Lancer Start_T409_FmuGateway.ps1 et attendre le message FMU prête.
2. Dans la copie Control Win, faire Login puis Stop.
3. L'humain active manuellement SimulationModeActive, SimM3OpenModelicaActive
   et Enable du bridge. Aucun script ne les écrit.
4. Démarrer Run sans Reset intermédiaire.
5. Attendre 3 s puis lancer codesys_m3_t409_acceptance.py depuis Tools > Scripting.
6. Conserver la sortie console complète.

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
