 🎬 RAPPORT FINAL D'ARBITRAGE AUTOMATISME & MES — AUDIT EXHAUSTIF DES 10 DEVICES                                                            
                                                                                                                                              
  │ 📌 Mission /goal accomplie : Audit chirurgical des 10 équipements matériels (Devices D01 à D10), de la chaîne de sécurité ISO 13849, du   
  │ formateur IHM (FB_Hmi_BannerFormatter) et des séquenceurs.                                                                                
  │ 📁 Livrable pérenne consolidé : AUDIT_DEVICES_ALARMS.yaml                                                                                 
  ──────                                                                                                                                      
  ## 📊 1. BILAN CHIFFRÉ GLOBAL (10 DEVICES AUDITÉS)                                                                                          
                                                                                                                                              
   Organe / Device        │ Périmètre Matériel                    │ Total Défaut… │ Conformes │ Refus Silenc… │ Défauts Mort… │ Anomalies Af…
  ────────────────────────┼───────────────────────────────────────┼───────────────┼───────────┼───────────────┼───────────────┼───────────────
   D01 : Treuil M1        │ Retenue / Levage câble                │      24       │    11     │       4       │       4       │       3
   D02 : Treuil M2        │ Fermeture benne                       │      24       │    10     │       4       │       5       │       2
   D03 : Benne Godet      │ Cinématique & seuils géométriques     │      18       │     9     │       5       │       2       │       0
   D04 : Chariot M3       │ Translation & pont roulant            │      22       │     8     │       7       │       4       │       5
   D05 : Codeurs          │ Mesures position COD1/COD2/COD3       │      25       │    14     │       4       │       4       │       0
   D06 : Synchro M1/M2    │ Asservissement écart & discordance    │      12       │     2     │       4       │       2       │       4
   D07 : Sécurité & AU    │ Boucle physique & PowerCutOff         │      11       │     5     │       4       │       2       │       0
   D08 : Joystick Pupitre │ Manipulateur Hall JOY1 & Homme-Mort   │      18       │     3     │       8       │       4       │       3
   D09 : Réseaux & E/S    │ EtherCAT, CANopen, WAGO, Heartbeat    │      20       │     3     │       6       │       5       │       6
   D10 : Séquenceurs      │ Semi-Auto AX0..AX18 & Homing HX0..HX7 │      20       │     6     │       7       │       4       │       3
   TOTAL CONSOLIDÉ        │ Ensemble de l'Automate Excavatrice    │      194      │    71     │      53       │      36       │      26
  ──────                                                                                                                                      
  ## 🚨 2. TOP 7 DES VICES CACHÉS DÉCOUVERTS (RISQUE MES & SÉCURITÉ)                                                                          
                                                                                                                                              
  1. 💥 Masquage total et destructif des esclaves EtherCAT (D09) :                                                                            
      • DeviceEthercatMaster.Operational est un bête AND des esclaves. Dans FB_Hmi_BannerFormatter.st:902-910, les alarmes esclaves           
      spécifiques sont conditionnées par IF EcatBusValid AND NOT EncM1Valid....                                                               
      • Conséquence : Dès qu'un esclave décroche, EcatBusValid passe à FALSE. L'opérateur ne voit JAMAIS quel codeur ou variateur a sauté !   
      Les messages COD1, COD2 et AC600 sont du code mort.                                                                                     
  2. 💥 Double-masquage fatal des alarmes codeurs (D05 / D09) :                                                                               
      • Les alarmes Safety [M1/M2] ErrorID:02 - perte codeur sont conditionnées par AND EncM1Valid. Si un câble de codeur est arraché, la     
      machine subit un SafeStop immédiat mais le carrousel affiche 0 alarme codeur !                                                          
  3. 💥 Bit-Shift majeur dans le carrousel d'alarme du cycle process (D10) :                                                                  
      • Décalage binaire flagrant entre FB_CycleSemiAuto et FB_Hmi_BannerFormatter : une perte de com IHM (bit 3) est affichée comme [CYCLE]  
      ErrorID:04 - ecart codeurs remontee ! L'opérateur cherche un problème de câble alors que c'est l'écran qui ne répond plus.              
  4. 💥 Surchauffes thermiques Moteurs & Freins : Coupure puissance sans alarme active (D01 / D02 / D04) :                                    
      • Les défauts thermiques déclenchent PowerCutOff, mais sont qualifiés à tort de simples warnings dans le formateur. Le disjoncteur      
      général saute, et le carrousel affiche 0 alarme active !                                                                                
  5. 💥 L'illusion du manipulateur en mode boutons IHM (D08) :                                                                                
      • Si TglJoystickMaster = FALSE (mode boutons écran tactile), dévier le joystick physique fait afficher au bandeau §4 : [JOYSTICK]       
      Déplacement en cours alors que la machine reste immobile à 0.                                                                           
  6. 💥 Écart critique synchro M1/M2 (6 m) orphelin de SafeStop manuel (D06) :                                                                
      • SyncDeviationFault (seuil 2 critique 6m) n'est injecté que dans les cycles automatiques. En conduite manuelle ou maintenance, si un   
      treuil prend 6m d'avance sur l'autre, aucun SafeStop n'est déclenché !                                                                  
  7. 💥 Neutralisation des temporisations de garde d'étape (D10) :                                                                            
      • StepMaxTimer(IN := FALSE) est hardcodé à FALSE. Si la benne bute sur un rocher ou qu'un capteur coince, le cycle reste figé           
      indéfiniment sans jamais se mettre en défaut ni alerter l'opérateur.                                                                    
                                                                                                                                              
  ──────                                                                                                                                      
  ## ⚖ 3. ARBITRAGE POUR LA MISE EN SERVICE (BENEFICES vs RISQUES)                                                                            
                                                                                                                                              
  ### 🟢 PACK 1 : Correctifs IHM & Visibilité (GAIN MAXIMAL / RISQUE RÉGULATION = 0)                                                          
                                                                                                                                              
  Ce sont des modifications 100% cantonnées à la supervision et aux affichages (FB_Hmi_BannerFormatter.st, PRG_07_Supervision.st). Aucun      
  risque de perturber les mouvements ni la régulation.                                                                                        
                                                                                                                                              
  • 🛠 Démasquer les esclaves EtherCAT : retirer EcatBusValid des conditions de présence de COD1, COD2, AC600.                                 
  • 🛠 Supprimer le AND EncMxValid sur les alarmes filles de perte codeur.                                                                     
  • 🛠 Corriger le bit-shift du carrousel de cycle §5 (16#0008 = Perte com IHM, 16#0010 = Timeout).                                            
  • 🛠 Intégrer les surchauffes thermiques moteurs/freins dans le carrousel d'alarmes actives.                                                 
  • 🛠 Expliciter le refus d'armement Joystick : si ArmingPermitDenied = TRUE, afficher pourquoi l'armement est refusé (coupure puissance,     
  benne active, etc.) au lieu de répéter Appuyer homme-mort.                                                                                  
                                                                                                                                              
  ### 🟡 PACK 2 : Alignements Ergonomiques & Interlocks (GAIN CONFORT / RISQUE TRÈS FAIBLE)                                                   
                                                                                                                                              
  • ⚙ Harmoniser la commande tactile M3 : lever l'obligation absurde de tenir le bouton physique du manipulateur quand on clique sur l'écran  
  tactile pour translater M3 en maintenance.                                                                                                  
  • ⚙ Corriger l'inhibition synchro 4s : afficher [BENNE] Stabilisation en cours pendant les 4 secondes post-benne où la synchro est suspendue.
                                                                                                                                              
  ### 🔴 PACK 3 : Sanctuarisation du Cœur Fonctionnel (NE PAS TOUCHER POUR L'INSTANT)                                                         
                                                                                                                                              
  • 🔒 NE PAS TOUCHER aux lois de pilotage treuils / translation qui fonctionnent déjà sur banc et en carrière.                               
  • 🔒 NE PAS RÉACTIVER StepMaxTimer sans avoir mesuré au chronomètre réel le temps de chaque étape en carrière (risque d'avorter des cycles  
  normaux si le fond est très profond).                                                                                                       
  ──────                                                                                                                                      
  ## 🎯 4. PROCHAINES ÉTAPES PROPOSÉES                                                                                                        
                                                                                                                                              
  1. Option A (Recommandée) : Implémenter le PACK 1 (Correctifs IHM) pour que lors des prochains essais avec l'humain et les autres agents,   
  l'écran dise exactement la vérité sur chaque blocage physique.                                                                              
  2. Option B : Reprendre la coordination avec l'agent sur la T417 (Simulation fine M3) en lui fournissant ces clés de compréhension pour     
  clore la fiche d'arrêt à la trémie.                 