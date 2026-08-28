# 🔎 Revue indépendante — Banc interactif FB_Cycle (T173)

**Date** : 2026-08-28 · **Revue** : audit externe (Ollama/relecteur) · **Acceptée par** : DSH
**Objet** : `engine/cycle_bench.html` + `anim_bench/` (banc T173)

## Verdict
Bon prototype de test interactif de FB_Cycle, mais les informations affichées peuvent être
interprétées à tort comme celles de la **machine complète**.

## Points bloquants (vérifiés)
1. **Le moteur compile seulement FB_Cycle**, pas la chaîne réelle
   `PRG_02 → PRG_03 → PRG_04/05 → PRG_06 → sorties physiques`. Les « commandes contacteur »
   affichées sont des Req/Cmd du cycle, pas des sorties finales arbitrées par interlocks/sécurité.
2. **Le joystick IHM ne traverse pas FB_Joystick ni PRG_02_Acquisition** ; le JS déplace
   directement les positions si ordre FB + direction joystick + homme-mort.
3. **Homme-mort clic/toggle non fidèle au contrat réel** (FB_Joystick : bouton maintenu,
   temporisation d'armement, ArmingPermit, désarmement). Ici `DeadmanArmed` est injecté.
4. **« Reset moteur » relance le processus** ; ce n'est pas un test du Reset sur front ni de
   l'acquittement des défauts. Le champ `RESET` existe côté C++ mais l'IHM ne l'envoie pas.
5. **La scène SVG lit `TRANSLATION_AT_*` et `BENNE_ISOPEN` comme si elles venaient du moteur**,
   alors que `cycle_engine.cpp` ne les émet pas → affichage potentiellement incohérent. (CONFIRMÉ)
6. **Traçabilité insuffisante** : SHA-256 différents entre `CODE/` et `WORKING_COPY/`, exécutable
   non versionné, `run_banc.bat` ne recompile que si l'exe est absent.

## Marquage de provenance à imposer dans l'IHM
| Catégorie | Marquage |
|---|---|
| Sortie renvoyée par le binaire | 🟢 FB_Cycle compilé + SHA source/build |
| Position, vitesse, Kobold/Top dérivés par le navigateur | 🟡 Monde simulé JS |
| Cases cochées par l'utilisateur | 🟠 Injection manuelle hors programme |
| Interlocks, PRG_04/05/06, sortie contacteur matérielle non exécutés | 🔴 Non simulé / non vérifié |

## Renommages imposés
- `WinchM1Cmd` → **Demande FB_Cycle** (pas « moteur/treuil commandé »).
- `KoboldContactorCmd` → **Demande contacteur Kobold** (pas « contacteur actif »).
- Bandeau persistant : « Banc logiciel hors-ligne — aucune commande machine réelle —
  chaîne PRG_02/04/05/06 non exécutée. »

## Décision (choisie)
**Option 1 — « Banc interactif de décision FB_Cycle »** : conserver l'architecture, afficher
toutes les provenances, interdire les formulations « contacteur/axe réellement commandé ».
La **simulation de chaîne complète** (FB_Joystick, PRG_02..06 + couche « plante » séparée)
= **tâche C3/C4** future avec contrat, matrice des signaux et garde-fou de provenance.
