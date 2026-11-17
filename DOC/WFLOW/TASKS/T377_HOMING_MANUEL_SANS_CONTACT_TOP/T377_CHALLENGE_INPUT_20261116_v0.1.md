# T377 Challenge indepandant — inputs (lecture seule, pas de code)

## Contexte
Projet : automate CODESYS 3.5, machine de dragage (securite machine reelle).
Tache T377 : homing N1 manuel SANS contact capteur TOP : approche manuelle sous
joystick + homme-mort (palier 1), reference haute VALIDEe VISUELLEMENT par
l'operateur avant le capteur (preset 8,50 m deja cable), capteur TOP = barriere
seule (contact => AUCUNE reference ecrite, latch, degagement, pas de FAIL).

## Brief de synchro (5 questions posees a l'agent RT)
Cadrage avant mise en service site. Lot terrain deja code local (non commite,
hors fichiers T377) : ST_CycleCmd, ST_TranslationFinalInterlockRequest, FB_Modes,
FB_CycleSemiAuto, FB_Translation, FB_TranslationCmdArbitrationM3, PRG_03, PRG_04,
PRG_05, PRG_06. En MAINT_N2 desormais :
- FB_Modes passe JoystickWinchSelectRequest directement ; mais PRG_03:95-99 impose
  MachineHoming.CmdWinchSelect quand MachineHoming.Active, et PRG_03 route
  CmdWinchM1/M2 + CmdBucket* du cycle.
- PRG_04:1126-1129 : M1M2_TopPositionFree_DI reste sur EffectivePermit*_Ascent
  (sauf bypass explicite).
- MAINT_N2 : PRG_04:501-514 neutralise BucketBusy/SyncBlocksAscent/Descent ;
  PRG_04:1632 (et jumeau M2 ~:1653) masque instSafetyWinch*.PowerCutOff par
  "AND NOT MaintN2" ; PRG_06:355-356 bypass instSyncContactorFinal.
Questions posees : 1) pret vs bloque pour implementation ; 2) compatibilite du
grafcet propose avec MAINT_N2 inconditionnel + gestion escalation PowerCutOff ;
3) deux defauts identifies dans le brouillon (latch refus validation ; effet de
bord Cause 8/Fault.Latched) ; 4) liste fichiers + duree/risque tests site ;
5) integrer maintenant ou apres le premier test M3/MAINT_N2.

## Reponse (5 points) de l'agent RT a challenger
1. Pret : cadrage complet (sequence arbitree hybrid sans FAIL, brouillon ST,
   alignement contrat AC1-AC7). Bloque : D1 (l'escalade PowerCutOff AC3 n'a AUCUN
   chemin cable : FB homing n'a pas de sortie PowerCutOff, c'est FB_Safety_Winch
   qui la produit) ; amendement contrat (AC2 4=>5 gardes MAINT_N2 seul, AC3 nomme
   SafetyPermit_Ascent qui n'existe pas => AscentPermit, AC4 23,5 m = reference
   benne pas homing, typos). D2=A descente sous joystick, D3=renommages etats,
   D5 bande asymetrique +0,10/-0,10. D4 (translation sans homing, 0 occurrence de
   MachineHomed dans CODE/I_TRANSLATION/) = hors perimetre, tache dediee.
2. Compatibilite MAINT_N2 : PRG_03 override cycle intact => compatible. Barriere
   conservee PRG_04:1126 => stop au contact independant du grafcet (fondement de
   "pas de FAIL"). MAIS PRG_04:1632 masque PowerCutOff exactement dans le mode du
   homing => AC3 inobservable en MAINT_N2 => recommandation basculee en D1=C
   (amender AC3 : pas d'escalade automatique routee en MAINT_N2 ; le FB expose
   l'evenement via cause C8 + instruction IHM ; barriere physique = AU + stop
   contact PRG_04:1126).
3. Deux defauts confirmes : LastValidationRefused TRUE/FALSE meme scan => raté par
   IHM, correction = latch jusqu'au prochain appui (compteur restant correct).
   Cause 8 non-latching retombe sans residu au retour HX2 ; risque = fenetre HX2A
   Fault.Latched=TRUE expose le FB a ses consommateurs hors checklist => fallback :
   retirer cause 8, garder sorties dediees + libelle.
4. Fichiers : enum, Cfg, FB_CycleMachineHoming, PRG_02, PRG_07, ST_HomingChecklist,
   FB_TroubleshootingView, GVL_Troubleshooting (+ ST_MachineHoming si renommages).
   SimBench 6 scenarios + 13 TC adaptes (hyp : 1/2-1 j). Capteur fragile : nouveau
   grafcet plus tolerant + garde manche-neutre anti-declenchement accidentel.
5. Avis : T377 APRES le premier test M3/MAINT_N2 (les deux lots changent les memes
   gardes => imputation impossible ; T377 = protocole de referencement, pre-requis
   de tout essai ; re-test homing seul 15-30 min ensuite).

## Inquiétude de l'exploitant a challenger aussi
L'agent implementateur du diff ST risque d'implementer les etapes du grafcet mais
de NE PAS MAPlER les peripheries critiques : synchronisation M1/M2, vitesses
(StepTgt), contacteurs, chaines de permis — bref que le grafcet soit "ecrit" mais
pas reellement relie. L'exploitant veut au moins pouvoir tester sur site : au
demarrage machine, on ne rentre PAS dans le cycle homing par hasard (garde
manche-neutre), et le geste habituel inchange.

## Questions au challengeur
1. Chaque point 1-5 ci-dessus est-il juste ? Quelles erreurs ou omissions ?
2. Risques indirectes non evidents (usure, meteor, facteur humain, mode commun,
   capteur shunte/fragile, redemarrage, IHM) sur ce design ?
3. Le decoupage "implanter les etapes / mapper les peripheries separement" est-il
   sain ? Comment garantir que le grafcet N'EST PAS relie tant que le mapping
   criticque n'est pas fait (pour interdire le site-test d'un demi-produit) ?
4. Que tester sur site au minimum avant d'accepter le lot (liste courte, factuel) ?
