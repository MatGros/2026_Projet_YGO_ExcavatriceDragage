# Audit de migration SimBench → OpenModelica — 2026-09-17

Statut : **travaux FMU historiques archivés · socle utilisateur recentré sur OMEdit par T314 · remplacement PLC interdit**.

## Décision d’architecture

```text
Sorties finales PLC (N-1)
  → adaptateur hors ligne / shadow
  → FMU Dredge.Plant
  → image HwSim typée + séquence + horodatage
  → aiguillage existant HwReal | HwSim → HwIn (PRG_02)
```

OpenModelica ne reçoit que des commandes finales et ne publie que des faits capteurs.
Le PLC reste propriétaire unique : sélection de source, safety M1/M2/M3, AU matériel,
`PowerCutOff`, réarmement, homme-mort qualifié et sorties physiques.

## Convention de signaux — revue et décision

Le standard [TWINBENCH_SIGNAL_CONVENTION_v1.0.md](../../STDS/TWINBENCH_SIGNAL_CONVENTION_v1.0.md)
est adopté pour les nouvelles interfaces FMU/IHM. Deux revues indépendantes ont refusé la première
taxonomie plate `CMD/CFG/STAT/DI/DIAG` : elle confondait la causalité Modelica, le flux PLC et la
nature d'affichage. Décision :

1. causalité Modelica : `input`/`output`/`parameter` ;
2. classe de flux : tags projet existants (`CMD`, `CFG`, `HW`, `SAFE`, `TST`, `STAT`, `ACT`, `DIAG`) ;
3. nature IHM : commande, configuration, mesure, retour discret, état device, diagnostic ou alarme.

Écarts L1 tracés : `reqTremie`/`reqMaintenance` et les retours numériques `Real 0/1` ne sont pas
le contrat cible. L'adaptateur les mappe ultérieurement vers `*Cmd`, `Boolean` et `UInt16` typés ;
aucun de ces écarts ne peut traverser directement `HwIn`.

| Verdict de revue | Décision |
|---|---|
| Remplacement direct SimBench dans PLC relié à la machine | **BLOCK** |
| Simulateur OpenModelica hors ligne | **PASS** |
| Banc PLC virtualisé, Q physiques prouvées neutralisées | **MAJOR** |
| Shadow lecture seule sur machine réelle | **MAJOR** |
| Pilotage machine réelle par OpenModelica | **BLOCK** |

## Parité tracée

Le contrat versionné [T314_SIMBENCH_PARITY.yaml](../CONTRACTS/T314_SIMBENCH_PARITY.yaml)
classe les **69 entrées** de `FB_SimBench` une fois et les cinq sorties contractuelles.

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_simbenc_parity.py
# PASS: 69 entrées FB_SimBench classifiées une fois; 5 sorties contractuelles.
```

| Domaine | SimBench actuel | État OpenModelica |
|---|---|---|
| M3 | commande finale, frein, fréquence, 5 DI, StatusWord | `Dredge.TranslationM3Plant` L1 : interface et capteurs, paramètres non calibrés |
| M1/M2 | codeurs/presets/contacteurs/freins/thermiques/roulis | L2 à construire |
| Benne/Kobold | delta, contact fond, délai, roulis | L3 différé |
| Chaîne machine | AU, contacteur, phases, thermiques | L4 : image banc seulement |
| Joystick | image brute CANopen, deadman | L5 : HID hors PLC ; qualification PLC conservée |

## Preuve d'exécution historique L1

Le runtime FMU Python et sa vérification ont servi à prouver la faisabilité, puis ont été
archivés lors du recentrage T314. Ils ne sont plus une dépendance ni une commande active.
La preuve utilisateur active est maintenant la simulation directe des classes `Dredge.Examples`
dans OMEdit. Résultats historiques du 2026-09-17 :

| Critère | Preuve |
|---|---|
| Repos neutre | `idle_is_neutral PASS` |
| Commande finale Maintenance → fréquence, frein, mouvement | `maintenance_final_command_to_sensor_image PASS` |
| Fermeture frein → arrêt observé | `brake_feedback_and_stop PASS` |
| Deux sens actifs → conflit explicite, zéro fréquence | `opposed_final_commands_reported PASS` |
| Course limitée à 30 m + DI Maintenance | `physical_travel_bound PASS` |

La projection de position dans `Dredge.mo` borne l'image à la course physique, y compris
au franchissement numérique d'un pas FMU. Les cotes et dynamiques sont toutefois encore des
hypothèses SimBench à calibrer.

## Preuves source

- SimBench reçoit les sorties post-interlocks et publie les images à `PRG_02` :
  `CODE/M_MAIN/PRG_02_Acquisition.st:262-351`.
- L’aiguillage atomique par domaine est le point de sûreté à conserver :
  `CODE/M_MAIN/PRG_02_Acquisition.st:399`.
- L’absence de mélange réel/simulé est imposée par AF13 :
  `DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md:271`.
- M1/M2 : synchronisation nominale <0,8 m, limite palier 1 <2,5 m, SafeStop au-delà :
  `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md:600`.
- M3 : la barrière de sortie force le frein fermé en défaut :
  `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st:137`.

## Invariants de sûreté avant L4

1. Perte, retard ou incohérence de passerelle => image externe invalide/neutre, jamais dernière commande conservée.
2. Aucun mélange partiel réel/simulé à l’intérieur d’un même domaine.
3. Aucun bypass, reset de latch safety, `SafeStop` ou `PowerCutOff` ne peut venir de la FMU.
4. Aucun redémarrage automatique après reset FMU, changement de scénario ou reconnexion.
5. Une suppression de `FB_SimBench` exige parité de scénarios, rejouage déterministe, gates PLC et recette humaine.

## Paramètres encore inconnus — interdit de comparer au réel

Masse/inertie, réducteurs, rayons de tambours, mouflage/nombre de brins, frottement et frein,
caractéristiques plaque moteur/rotor, cotes cinq capteurs M3, calibration codeurs, charge eau/sol
et traces machine de référence. Les valeurs POC servent uniquement à un comportement pédagogique.

## Étapes suivantes — décision T314

1. Calibrer M1/M2 et M3 avec des traces réelles horodatées.
2. Reproduire dans OMEdit les rebonds capteurs/frein et la transition fermeture-remontée.
3. Comparer comportement actuel et modèle corrigé avant toute discussion de FMU ou d'adaptateur.
4. Toute reprise d'une intégration PLC/SSP exige un nouveau contrat et une validation humaine.
