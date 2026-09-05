# 🚨 PLAN TECHNIQUE -- Masquage des Alarmes en Cascade & Qualification Materielle IHM (T163)

**Date** : 2026-08-26  
**Criticite** : C3 (Affichage IHM, carrousel d'alarmes et consignes operateur)  
**Normes de reference** : ISA-18.2 (Alarm Management), ISO 13849-1, CEI 61131-3  
**Statut** : Fige avec Annexe Exhaustive Ligne-a-Ligne

---

## 1. 🎯 Objectif Metier

Eliminer l'inondation de fausses alarmes (*Alarm Flooding*) et guider immediatement l'operateur vers la cause racine lorsqu'un equipement materiel (carte d'entrees/sorties, bus CANopen, bus EtherCAT, capteur intelligent) est deconnecte ou en panne.

Quand un equipement parent est HS, le systeme affiche l'alarme parente en priorite absolue et **masque l'ensemble des fausses alarmes filles** (contacts NF a 0V : thermiques moteurs, securites, fins de course, etc.) ainsi que les **doublons directs**.

---

## 2. 🛡️ Justification Securite Machine (Non-Impact sur les Arrets Physiques)

> 🔒 **Preuve d'Isolation Safety** : FB_Safety_Winch et FB_Safety_Translation declenchent et maintiennent leurs arrets de securite (SafeStop, PowerCutOff, DirectionBlocked) sur les valeurs brutes et fail-safe des capteurs (ex : contacts NF devenant FALSE) dans PRG_04 et PRG_05, independamment du masquage IHM.

Le present patch est une couche purement cosmetique/ergonomique de supervision (Display & Filtering) dans PRG_07. Il n'altere en aucun cas la reaction de securite physique de l'automate (ISO 13849-1) : l'operateur perd de l'information parasite, mais jamais la protection reelle.

---

## 3. 🛡️ Les Garde-Fous Industriels Integres

1. **⏱️ Boot Inhibit (Garde de Demarrage)** :
   - Au demarrage automate, les bus EtherCAT et CAN mettent 2 a 5 s a passer en etat RUNNING.
   - Une temporisation TON(PT := T#4s) dans PRG_07_Supervision inhibe les alarmes de perte reseau IHM pendant la phase d'initialisation.
2. **🌊 Anti-Chattering (Filtrage Bagotement)** :
   - Un maintien TOF(PT := T#1.5s) sur l'invalidation evite le clignotement epileptique entre l'alarme parent et les alarmes filles lors de micro-coupures ou vibrations.
3. **🧪 Producteur Unique & Mode Simulation :**
   - PRG_02_Acquisition est le PRODUCTEUR UNIQUE de la qualification des modules et bus (LocalDigitalIoOk, Vh0800EndOk, Vh0808EtpOk, CanError, EcatError).
   - PRG_02 surcharge deja ces validites a TRUE en mode simulation (MachineInputSourceSimulated, SimBypassActive, SystemBypass).
   - **ZERO AJOUT DE LOGIQUE DE SIMULATION dans FB_Hmi_BannerFormatter** : le formateur consomme Network.InputModules.*Ok et operational tels quels, sans re-filtrer ni re-deviner.

---

## 4. 🎯 Hierarchie Stricte des Messages Operateur (OperatorActionText)

Pour eviter toute occultation au detriment de l'AU ou de la puissance, l'ordre des consignes sera **strictement fige comme suit** :

`pascal
// 1. ETAPES AU (Priorite Absolue -- Chaine independante)
IF NOT EmergencyChainClosed THEN
    OperatorActionCandidate := '[PUPITRE] Boucle urgence ouverte - rearmer';
ELSIF RedundancyTestFailed THEN
    OperatorActionCandidate := '[AU] Defaut redondance contacteurs - rearmer';
ELSIF EmergencyArmingFailed THEN
    OperatorActionCandidate := '[AU] Echec rearmement contacteur - rearmer';

// 2. ETAPE PUISSANCE GENERALE (KM1)
ELSIF NOT PowerContactorEngaged OR PowerCutOffActiveAny THEN
    OperatorActionCandidate := '[PUPITRE] Rearmer AU et puissance';

// 3. DEFAUTS MATERIELS ES/INFRASTRUCTURE (NOUVEAU)
ELSIF NOT Network.InputModules.LocalDigitalIoOk OR NOT Network.InputModules.Vh0800EndOk OR NOT Network.InputModules.Vh0808EtpOk THEN
    OperatorActionCandidate := '[IO] Defaut module E/S - verifier alimentation/coupleur';
ELSIF Network.CanError OR NOT Network.Joystick.Operational THEN
    OperatorActionCandidate := '[CAN] Joystick non detecte - verifier liaison';
ELSIF NOT Network.EncoderM1.Operational OR NOT Network.EncoderM2.Operational THEN
    OperatorActionCandidate := '[ECAT] Codeurs non detectes - verifier liaison';
ELSIF NOT Network.VariateurM3.Operational THEN
    OperatorActionCandidate := '[ECAT] Variateur non detecte - verifier liaison';

// 4. SECURITES PROCEDE, INTERLOCKS & CONDUITE EXISTANTES
ELSIF SafeStopActive THEN
    OperatorActionCandidate := '[PUPITRE] Acquitter SafeStop';
ELSIF DirectionBlocked THEN
    // ... descente/montee interdite
ELSIF ... // Cycle Semi-Auto, Homing, Homme-Mort, Mode DISABLE, etc.
`

---

## 5. 📖 ANNEXE EXHAUSTIVE : Tableau de Garde Ligne-a-Ligne du Carrousel (§5)

> Source de verite materielle : AF_Partie-06_Acquisition_Qualification_IO_v2.4.md (§4bis et §5).

### 5.0 NOUVELLES ALARMES PARENTES MATERIELLES (Ajoutees en tete de carrousel)
| # | Condition d'activation | Texte alarme genere |
|---|---|---|
| P1 | NOT Network.InputModules.LocalDigitalIoOk | [IO] Defaut module Local IO (DI8) |
| P2 | NOT Network.InputModules.Vh0800EndOk | [IO] Defaut module VH0800END (DI8) |
| P3 | NOT Network.InputModules.Vh0808EtpOk | [IO] Defaut module VH0808ETP (DI8/DO8) |
| P4 | Network.CanError OR NOT Network.Joystick.Operational | [CAN] Joystick JOY1 non detecte |
| P5 | NOT Network.EncoderM1.Operational | [M1] Codeur absolu non detecte (ECAT) |
| P6 | NOT Network.EncoderM2.Operational | [M2] Codeur absolu non detecte (ECAT) |
| P7 | NOT Network.VariateurM3.Operational | [M3] Variateur AC600 non detecte (ECAT) |

---

### 5.1 TREUIL M1 (WinchM1Safety.*)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 360 | [M1] perte com operateur | AND Network.Joystick.Operational | Masque si Joystick absent (doublon P4) |
| 363 | [M1] perte codeur | AND Network.EncoderM1.Operational | Masque si Codeur absent (doublon P5) |
| 366 | [M1] surchauffe moteur | AND Network.InputModules.LocalDigitalIoOk | M1_ThermalOk_DI est sur Local_Digital_IO · 1 |
| 369 | [M1] mou de cable | AND Network.InputModules.LocalDigitalIoOk | Contact portage E/S local |
| 372 | [M1] rotation phases | AND Network.InputModules.Vh0800EndOk | PhaseRotationOk_DI est sur VH_0800END · 4 |
| 375 | [M1] limite basse cable | AND Network.EncoderM1.Operational | Calcule sur position codeur M1 |
| 378 | [M1] butee haute | AND Network.InputModules.LocalDigitalIoOk AND Network.EncoderM1.Operational | M1M2_TopPositionFree_DI sur Local_Digital_IO · 7 + Codeur M1 |
| 381 | [M1] surchauffe frein | AND Network.InputModules.Vh0800EndOk | M1_M2_M3_BrakeThermalOk_DI est sur VH_0800END · 3 |
| 384 | [M1] MecaA - deplacement sans commande | AND Network.EncoderM1.Operational | Calcule sur vitesse codeur M1 |
| 387 | [M1] MecaB - arret non confirme apres stop | AND Network.EncoderM1.Operational | Calcule sur vitesse codeur M1 |
| 390 | [M1] MecaC - glissement pendant benne figee | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart positions codeurs M1/M2 |
| 393 | [M1] MecaD - non-arret au capteur haut | AND Network.InputModules.LocalDigitalIoOk AND Network.EncoderM1.Operational | Inductif haut Local_Digital_IO · 7 + Codeur M1 |
| 396 | [M1] MecaE - ecart synchro M1/M2 critique | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart codeurs M1/M2 |
| 399 | [M1] sens oppose | AND Network.EncoderM1.Operational | Calcule sur signe vitesse codeur M1 |
| 402 | [M1] absence mouvement | AND Network.EncoderM1.Operational | Calcule sur vitesse codeur M1 sous commande |

---

### 5.2 TREUIL M2 (WinchM2Safety.*)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 407 | [M2] perte com operateur | AND Network.Joystick.Operational | Masque si Joystick absent (doublon P4) |
| 410 | [M2] perte codeur | AND Network.EncoderM2.Operational | Masque si Codeur absent (doublon P6) |
| 413 | [M2] surchauffe moteur | AND Network.InputModules.LocalDigitalIoOk | M2_ThermalOk_DI est sur Local_Digital_IO · 3 |
| 416 | [M2] mou de cable | AND Network.InputModules.LocalDigitalIoOk | M2_TensionedCable_DI est sur Local_Digital_IO · 4 |
| 419 | [M2] rotation phases | AND Network.InputModules.Vh0800EndOk | PhaseRotationOk_DI est sur VH_0800END · 4 |
| 422 | [M2] limite basse cable | AND Network.EncoderM2.Operational | Calcule sur position codeur M2 |
| 425 | [M2] butee haute | AND Network.InputModules.LocalDigitalIoOk AND Network.EncoderM2.Operational | M1M2_TopPositionFree_DI sur Local_Digital_IO · 7 + Codeur M2 |
| 428 | [M2] surchauffe frein | AND Network.InputModules.Vh0800EndOk | M1_M2_M3_BrakeThermalOk_DI est sur VH_0800END · 3 |
| 431 | [M2] MecaA - deplacement sans commande | AND Network.EncoderM2.Operational | Calcule sur vitesse codeur M2 |
| 434 | [M2] MecaB - arret non confirme apres stop | AND Network.EncoderM2.Operational | Calcule sur vitesse codeur M2 |
| 437 | [M2] MecaC - glissement pendant benne figee | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart codeurs M1/M2 |
| 440 | [M2] MecaD - non-arret au capteur haut | AND Network.InputModules.LocalDigitalIoOk AND Network.EncoderM2.Operational | Inductif haut Local_Digital_IO · 7 + Codeur M2 |
| 443 | [M2] MecaE - ecart synchro M1/M2 critique | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart codeurs M1/M2 |
| 446 | [M2] sens oppose | AND Network.EncoderM2.Operational | Calcule sur signe vitesse codeur M2 |
| 449 | [M2] absence mouvement | AND Network.EncoderM2.Operational | Calcule sur vitesse codeur M2 sous commande |

---

### 5.3 TRANSLATION M3 (TranslationSafety.*)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 454 | [M3] perte com operateur | AND Network.Joystick.Operational | Masque si Joystick absent (doublon P4) |
| 457 | [M3] perte EtherCAT | AND Network.VariateurM3.Operational | Masque si Variateur absent (doublon P7) |
| 460 | [M3] rotation phases | AND Network.InputModules.Vh0800EndOk | PhaseRotationOk_DI est sur VH_0800END · 4 |
| 463 | [M3] surchauffe frein | AND Network.InputModules.Vh0800EndOk | M1_M2_M3_BrakeThermalOk_DI est sur VH_0800END · 3 uniquement (*Note : M3_ThermalOK_DI moteur sur Local_IO·6 non présent dans FB_Safety_Translation.ErrorId, hors scope T163*) |
| 466 | [M3] MecaB - arret non confirme apres stop | AND Network.VariateurM3.Operational | Calcule sur retour vitesse/frequence AC600 |
| 469 | [M3] MecaA - deplacement sans commande | AND Network.VariateurM3.Operational | Calcule sur retour frequence AC600 |
| 472 | [M3] butee extreme | AND Network.InputModules.Vh0808EtpOk | Inductifs cames M3 sur VH_0808ETP · 0..4 |
| 475 | [M3] capteurs incoherents | AND Network.InputModules.Vh0808EtpOk | Inductifs cames M3 sur VH_0808ETP · 0..4 |

---

### 5.4 BENNE (BucketErrorId)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 480 | [BENNE] timeout mouvement | *Non modifiee* | Timeout interne machine d'etat benne |
| 483 | [BENNE] incoherence etat | *Non modifiee* | Incoherence logique interne |
| 486 | [BENNE] limites depassees | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur position absolue M1/M2 |
| 489 | [BENNE] codeurs non references | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Concerne homing sur codeurs valides |
| 492 | [BENNE] glissement M1 | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart positions codeurs M1/M2 |

---

### 5.5 SYNCHRO M1/M2 (SyncErrorId)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 497 | [SYNC] ecart M1/M2 | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Calcule sur ecart positions codeurs M1/M2 |
| 500 | [SYNC] incoherence commande | *Non modifiee* | Incoherence logique commande M1/M2 |

---

### 5.6 PLONGEE / EXTRACTION (DiveErrorId / ExtractionErrorId)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 505-513 | [DIVE] preconditions / sequence / config | *Non modifiees* | Erreurs d'enchainement sequence/config |
| 514 | [EXTRACTION] fond | AND Network.InputModules.LocalDigitalIoOk | Capteur Kobold sur Local_Digital_IO · 5 |
| 517-525 | [EXTRACTION] fermeture / controle / config | *Non modifiees* | Erreurs d'enchainement sequence/config |

---

### 5.7 AU & CYCLE SEMI-AUTO (EmergencyErrorId / CycleErrorId)
| Ligne code | Alarme fille existante | Condition de garde requise | Justification materielle AF06 |
|---|---|---|---|
| 528-536 | [AU] redondance / confirmation / autotest | *Non modifiees* | Diagnostics boucle securite interne PRG_06 |
| 539 | [CYCLE] limite legale atteinte | AND Network.EncoderM1.Operational | Position codeur M1 vs limite legale |
| 542 | [CYCLE] defaut synchro treuils | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Ecart synchro codeurs |
| 545 | [CYCLE] ecart codeurs remontee | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Ecart codeurs |
| 548 | [CYCLE] ecart vitesse confirme | AND Network.EncoderM1.Operational AND Network.EncoderM2.Operational | Ecart vitesse codeurs |
| 551 | [CYCLE] perte communication IHM | *Non modifiee* | Diagnostic Watchdog IHM |
| 554 | [CYCLE] timeout etape | *Non modifiee* | Timeout etape cycle |

---

### 5.8 NOTE SUR LES GARDES DOUBLES (Signaux a Detection Redondante)
Pour `CableLimitAscent` (lignes 378/425) et `MecaD` (lignes 393/440), le calcul interne dans `FB_Safety_Winch.st:359-362` combine par OU le capteur inductif physique (`M1M2_TopPositionFree_DI` sur `Local_Digital_IO · 7`) et le depassement de seuil calcule par le codeur (`CablePosM >= TopLimitM`).
- Si le module E/S physique est HS, l'alarme parente `[IO] Defaut module Local IO` est levee.
- Si le codeur est HS, l'alarme parente `[M1/M2] Codeur absolu non detecte` est levee.
- La double condition `AND Network.InputModules.LocalDigitalIoOk AND Network.EncoderM*.Operational` garantit que l'alarme fille `butee haute` / `MecaD` n'apparait que si l'ensemble de la chaine de mesure redondante est saine, eliminant tout faux positif numerique issu d'un codeur non synchronise.

---

## 6. 🧪 Validation & Tests CI Attendus

1. **Tests Unitaires CI (FB_Hmi_BannerFormatter_test.st)** :
   - *Test 1 (Module VH0800END HS)* : Affiche [IO] Defaut module VH0800END, masque thermiques frein/rotation phases.
   - *Test 2 (Module Local_Digital_IO HS)* : Affiche [IO] Defaut module Local IO, masque thermiques moteurs, mou cable, butee haute.
   - *Test 3 (Perte Codeur M1)* : Affiche [M1] Codeur absolu non detecte (ECAT), masque perte codeur fille (doublon), ecart synchro et derives Meca.
   - *Test 4 (Perte Variateur AC600)* : Affiche [M3] Variateur AC600 non detecte (ECAT), masque perte EtherCAT fille (doublon) et MecaA/B.
   - *Test 5 (Boot Inhibit TON 4s)* : Aucune alarme materielle reseau levee pendant les 4 premieres secondes.
   - *Test 6 (Anti-Bagotement TOF 1.5s)* : Micro-coupure < 1.5s ne bagote ni l'alarme parente ni les alarmes filles.
2. **Suite mecanique 21 Gates (
un_all_gates.py)** : 100% PASS
3. **Bundle PLCopenXML** : fraichement regenere
