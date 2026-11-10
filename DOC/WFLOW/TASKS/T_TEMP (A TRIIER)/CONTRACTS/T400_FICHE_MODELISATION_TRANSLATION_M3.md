# Translation M3 — fiche de référence pour la modélisation

Date : 2026-09-27 · Statut : **base de travail, fidélité terrain non validée**  
Tags : `[PLAQUE]` donnée fabricant · `[CODE PLC]` source exécutable · `[HYPOTHÈSE]` choix provisoire · `[ÉCART]` incohérence connue · `[À MESURER]` donnée manquante

## Périmètre et chaîne physique cible

M3 translate le chariot entre **Trémie** et **Maintenance**. Le PLC garde les commandes, rampes logiques, sécurités et interlocks ; OpenModelica porte uniquement la physique.

```text
Consigne/mesure variateur → moteur → inertie arbre → frein → réducteur → roue/rail → masse chariot
                                                                    ├→ 5 capteurs cumulés
                                                                    └→ 2 butées mécaniques
```

`[HYPOTHÈSE]` L'ordre exact frein/réducteur reste à confirmer physiquement. L'IHM PySide6/QML affiche et paramètre ; elle ne calcule aucun mouvement.

## Géométrie et capteurs

| Repère | Position | Mot capteurs en allant Trémie → Maintenance |
|---|---:|---:|
| Capteur Trémie | `[CODE PLC]` 0,00 m | `11111` |
| PV | `[CODE PLC]` 5,00 m | `01111` |
| P2 | `[CODE PLC]` 15,00 m | `00111` |
| P1 | `[CODE PLC]` 20,00 m | `00011` |
| Capteur Maintenance | `[CODE PLC]` 30,00 m | `00000` |
| Butée mécanique Trémie | `[HYPOTHÈSE]` −0,30 m | hors course capteurs |
| Butée mécanique Maintenance | `[HYPOTHÈSE]` 30,30 m | hors course capteurs |

`[ÉCART]` Le SimBench actuel borne encore la mécanique à **0…30 m** et place artificiellement les capteurs extrêmes à 0,05/29,95 m. Le futur modèle doit dissocier capteurs et butées, avec hystérésis, délai électrique et rebond paramétrables.

## Motorisation connue

| Donnée plaque | Valeur |
|---|---|
| Fabricant / modèle | `[PLAQUE]` HELMKE Germany · DSH160M-06-1G-035 · n° 119507 |
| Type / montage | `[PLAQUE]` triphasé, rotor bobiné · IMB3 · IP54 · classe F/B |
| Réseau stator | `[PLAQUE]` 50 Hz · 400 V Y |
| Puissance / courant | `[PLAQUE]` 7,5 kW · 17,5 A |
| Vitesse / cos φ / rendement | `[PLAQUE]` 963 min⁻¹ · 0,76 · 82 % |
| Service | `[PLAQUE]` S3-40 % |
| Rotor | `[PLAQUE]` 180 V Y · 26 A |
| Masse / année | `[PLAQUE]` 133 kg · 2014 |

`[À MESURER]` Rapport de réduction, diamètre roue/pignon, inerties, rendement transmission, masse chariot + charge suspendue, frottements rail, jeu mécanique, couple et emplacement du frein.

## Dynamique actuellement utilisée par le PLC

| Grandeur | Valeur active / conclusion |
|---|---|
| Cycle M3 / SimBench | `[CODE PLC]` 10 ms |
| Fréquence maximale | `[CODE PLC]` 50 Hz |
| Consigne opérateur par défaut | `[CODE PLC]` 40 Hz |
| Gain translation | `[CODE PLC — PROVISOIRE]` 0,02 m/(Hz·s), donc 50 Hz → 1,00 m/s et 40 Hz → 0,80 m/s |
| Temps idéal 0→30 m à 40 Hz établi | `[CODE PLC]` 37,5 s, hors accélération/freinage |
| Rampe accélération | `[CODE PLC]` 40 %/s = 20 Hz/s sur l'échelle 50 Hz |
| Décélération normale | `[CODE PLC]` 50 %/s = 25 Hz/s |
| Décélération SafeStop | `[CODE PLC]` 100 %/s = 50 Hz/s |
| Inversion de sens | `[CODE PLC]` délai minimal 200 ms à consigne nulle |
| Vitesses d'approche persistantes | `[CODE PLC]` 20 Hz vers Trémie, P1 et Maintenance |
| Mesure variateur | `[CODE PLC]` `M3_ActualFrequencyHz`, résolution transmise 0,01 Hz ; `M3_StatusWord` également acquis |

`[ÉCART]` Les défauts du type `ST_fbTranslation_Cfg` valent 20/40/100 %/s et 10 Hz, mais `PRG_05_Translation` les remplace réellement par les valeurs persistantes **40/50/100 %/s** et **20 Hz**. Le modèle doit utiliser les valeurs câblées, pas les défauts du type.

`[À MESURER]` Le gain 0,02 reste à calibrer par chrono + distance (T301). Les rampes internes du variateur AC600, sa réponse fréquence réelle/consigne et ses limitations de couple ne sont pas encore caractérisées.

## Frein et séquence de commande

- `[CODE PLC]` Au démarrage, ouverture du frein après `100 ms contacteur + 100 ms magnétisation`, soit 200 ms configurés.
- `[CODE PLC]` Confirmation du retour frein attendue sous 1 000 ms.
- `[CODE PLC]` À l'arrêt, la commande de fermeture du frein tombe immédiatement lorsque le mouvement n'est plus demandé.
- `[ÉCART CRITIQUE]` `BrakeDelayMotorDecel = 2 s` est configuré mais **sans effet** : `FB_Brake` remet le timer de décélération à zéro et ne lit jamais son résultat. Le modèle ne doit donc pas simuler ces 2 s comme une logique PLC active.
- `[À MESURER]` Temps mécanique réel d'ouverture/fermeture, vitesse résiduelle au collage, couple de freinage, glissement et comportement sur perte d'énergie.

## Interface minimale du modèle

**Entrées provenant des sorties finales PLC** : `M3_CommandWord`, `M3_SetpointFrequencyHz`, `M3_BrakeRelease_RQ`, validité/sequence/timestamp.  
**Sorties physiques simulées** : fréquence mesurée, status variateur, retour frein ouvert, cinq capteurs, position/vitesse vraies, contact butée, défauts simulés.  
**Traces obligatoires** : consigne Hz, fréquence mesurée, vitesse, position, rampes, commande/retour frein, mot capteurs, fronts capteurs, butées et événements de liaison.

## Critères avant de parler de modèle fidèle

1. Calibrer le rapport `Hz → m/s` sur machine.
2. Photographier/identifier la chaîne moteur–frein–réducteur–roue.
3. Mesurer les positions réelles des cinq cames et des deux butées.
4. Relever une accélération, un arrêt normal, un SafeStop et une approche à 20 Hz avec consigne + fréquence mesurée.
5. Identifier masse/inertie/frottement ou les ajuster sur une trace terrain dédiée.

Tant que ces cinq points ne sont pas acquis, le modèle est **fonctionnel et explicatif**, pas une preuve de comportement réel.

## Sources actives principales

- `CODE/GVL_PERSISTENT.st`
- `CODE/M_MAIN/PRG_05_Translation.st` et `PRG_06_Outputs.st`
- `CODE/I_TRANSLATION/FB_Translation.st`, `FB_Translation_PositionDecoder.st`, `FB_Translation_PositionEstimator.st`
- `CODE/A_COMMUN/FB_Brake.st`
- `CODE/L_SIMULATION/FB_Sim_Translation.st` et `FB_SimBench.st`
- `DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md`
- Plaque moteur transcrite par l'utilisateur le 2026-09-27
