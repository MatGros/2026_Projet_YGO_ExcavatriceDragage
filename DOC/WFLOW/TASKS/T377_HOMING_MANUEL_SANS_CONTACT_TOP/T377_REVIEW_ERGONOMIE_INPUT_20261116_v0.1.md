# T377 Review lecture seule — parcours mental du grafcet (effets de bord + ergonomie)

## Contexte
CODESYS dragage. T377 refactor homing : approche MANUELLE sans contact capteur TOP.
Ton travail : SIMULER MENTALEMENT le grafcet et l'usage operateur, trouver effets de
bord et pieges ergonomiques. Lecture seule, pas d'acces fichiers. Reponse concise :
constats numerotes + severite (BLOQUANT/MAJOR/MINEUR) + action en 1 ligne.

## Etat actuel du code (constate 16/11, preuves ligne)
- Entree cycle HX0 : (StartEdge IHM OU BtnValidationEdge) AND ModeIsMaint2.
  Mini-lot en application : ajoute AND NOT JoystickDeflected. BtnValidation devient
  IHM seul (JoyBtnRaw retire). BtnStart = IHM.
- HX1 : benne fermeture sous manche tire + homme-mort (BucketPermit), confirmation
  BtnConfirmHomingBucket IHM, manche neutre. WinchSel force 2.
- HX1a : WinchSel 0, interlock couplage 300 ms, arret mecanique requis.
- HX2 (nouveau) : montee couplee palier 1 SI ClimbPermit (homme-mort + manche tire)
  ET couple ET capteur libre ET pas de latch contact ET coherence M1/M2 (garde skew
  ajoutee). Contact capteur → latch + HX2A. Validation BtnValidationEdge acceptee
  SI 5 gardes : MAINT_N2, arret mecanique, capteur libre, manche neutre, pas de latch.
  Refus → latch refuse + compteur, rien d'ecrit.
- HX2A (nouveau) : montee INTERDITE (latch). Descente seule si DescendPermit
  (homme-mort + manche pousse) + couple, palier 1. Aucun HomeReq possible. Sortie :
  capteur libre + arret + neutre → retour HX2 (nouvelle approche). Reset conscient
  → HX0. Cause C8 non-latching visible pendant la fenetre.
- HX3 : un SEUL HomeReq M1+M2 a l'arret (preset 8,50 m deja cable). Timeout 60 s → HX7.
- HX4 : verif preset : both homed + arret + neutre + coherence M1/M2 (1,0 m) + bande
  asymetrique 8,50 +0,10/-0,10. Echec → UNE re-emission HomeReq puis HX7.
- HX5 : degagement, neutre + arret → HX6. HX6 : commit benne atomique + MachineHomed.
- HX7 : attente Reset conscient MAINT_N2.
- Permanents : M3Locked tant que cycle != HX0. CmdWinchSelect force (2 puis 0) tant que
  cycle actif — PRG_03:95-99 surcharge le selecteur. Palier 1 max partout. Perte datum
  en mouvement → cause 0 latchee + Reset requis. Cause C8 retombe au degagement.
- Terrain MAINT_N2 : PowerCutOff masquee (PRG_04:1632), contacteur sync bypass
  (PRG_06:355), BucketBusy/SyncBlocks neutralises (PRG_04:501). Barriere montee
  conservee (PRG_04:1126). Homing unitaire disponible hors cycle (BtnHome/BtnHomingAtZero).
- Budget montee ClimbTimer 300 s (garde de duree, remis a zero des que commande tombee).

## Parcours a simuler (dans l'ordre ; imaginer les gestes operateur et l'IHM)
1. Boot a froid, codeurs pret, manche en position quelconque : le cycle peut-il demarrer
   seul ? M3Locked ? Effet sur homing unitaire ?
2. Cycle nominal complet HX0→HX6 : gestes, attentes, messages ; le manche est-il
   sollicite longtemps (fatigue) ? Que se passe-t-il si l'operateur relache l'homme-mort
   en HX2 (montee en cours) ?
3. Contact fortuit du capteur en HX2 : sequence HX2A, gestion operateur, sortie, retour
   HX2 — combien de fois l'operateur peut-il recreer le contact ? Trace visible ?
4. Refus de validation (ex : validation sans avoir relache le manche, ou treuils non
   arretes) : feedback operateur, recuperation, risque de repetitions aveugles ?
5. Appui validation en HX1/HX1a/HX4/HX5 : l'appui BtnValidation declenche-t-il autre
   chose que la validation HX2 (ambiguite du bouton unique) ?
6. Coupure puissance / Enable FALSE / bascule de mode pendant HX1, HX2, HX3, HX4, HX2A :
   reprise ? Etats residuels ? Preset accidentel possible ?
7. M3/translation pendant le cycle : M3Locked empêche quoi exactement ? Un besoin
   legitime de translation pendant homing peut-il bloquer un chantier (ergonomie) ?
8. WinchSel surchargé par le cycle : qu'arrive-t-il si l'operateur bascule le selecteur
   treuil pendant HX2/HX2A (interlock couplage) — message ? risque d'erreur codeur ?
9. HX7 : chemin de sortie unique Reset ; que montre l'IHM ; l'operateur peut-il relancer
   le cycle sans rien reparer ?
10. Ergonomie general : confusion BtnValidate (IHM) vs homme-mort (BP manche) ; ordre
    des gestes ; visibilite du latch contact ; comprehension "retour HX2 apres degagement".

## Questions finales
A. Effets de bord non visibles dans les parcours (consommateurs du FB, bit IHM,
   checklist, simulation) ?
B. Top 5 recommandations de cadrage si besoin (courtes).
