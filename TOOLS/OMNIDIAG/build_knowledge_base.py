"""
===============================================================================
🧠 OMNIDIAG — Générateur de la Knowledge Base (Preflight + 71 Alarmes Bloquantes)
===============================================================================
🎯 Rôle : Alimente knowledge_base.json avec une rigueur absolue :
   - ZÉRO mot 'cabine' -> 'poste de conduite' ou 'pupitre de commande'.
   - ZÉRO 'appeler la maintenance' -> actions directes physiques.
   - Polarité EDM rigoureuse : contacts miroirs NC fermés en série = 24V sur %IX0.0/%IX0.2.
   - Zéro capteur physique sur mâchoires/disques de frein (recopies contacteurs armoire).
   - Format des points de test normalisé :
     [LOCALISATION & ADRESSE] ➔ [MESURE ÉLECTRIQUE ATTENDUE] ➔ [CONDITION NORMALE]
===============================================================================
"""

import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# --- 1. LOT PREFLIGHT RÉVISÉ (PRE_01 à PRE_16) ---
kb_data = {
  "PRE_01": {
    "cause_racine": "⚡ Contacteur frein M1 resté enclenché en armoire ou contact de recopie bloqué (aucun capteur sur treuil).",
    "action_conducteur": "🕹️ Mettre les manipulateurs au neutre sur le pupitre. Relancer le Preflight.",
    "action_maintenance": "🧰 Tester le contacteur frein KM_Frein_M1 en armoire. Mesurer 0V sur la bobine de défreinage à l'arrêt. Remplacer si contacts soudés.",
    "points_test": "VH_0008ER · Relais %QX27.0 (M1_BrakeRelease_RQ) ➔ Mesure : Continuité contact sec C0/NO0 ➔ Attendu repos : 0V / Contact ouvert | VH_0800END · Borne %IX225.0 (M1_BrakeIsOpen_DI) ➔ Attendu repos : 0V"
  },
  "PRE_02": {
    "cause_racine": "⚡ Contacteur frein M2 resté enclenché en armoire ou contact de recopie bloqué (aucun capteur sur treuil).",
    "action_conducteur": "🕹️ Mettre le manipulateur benne au neutre au pupitre. Relancer le Preflight.",
    "action_maintenance": "🧰 Tester le contacteur frein KM_Frein_M2 en armoire. Mesurer 0V sur la bobine de défreinage à l'arrêt. Remplacer si contacts soudés.",
    "points_test": "VH_0008ER · Relais %QX27.1 (M2_BrakeRelease_RQ) ➔ Mesure : Continuité contact sec C1/NO1 ➔ Attendu repos : 0V / Contact ouvert | VH_0800END · Borne %IX225.1 (M2_BrakeIsOpen_DI) ➔ Attendu repos : 0V"
  },
  "PRE_03": {
    "cause_racine": "⚡ Contacteur/relais frein translation M3 resté enclenché en armoire (aucun capteur sur chariot).",
    "action_conducteur": "🕹️ Mettre le manipulateur translation au neutre au pupitre. Relancer le Preflight.",
    "action_maintenance": "🧰 Contrôler le relais frein KM_Frein_M3 en armoire. Mesurer 0V sur la bobine à l'arrêt.",
    "points_test": "VH_0008ER · Relais %QX27.2 (M3_BrakeRelease_RQ) ➔ Mesure : Continuité contact sec C2/NO2 ➔ Attendu repos : 0V / Contact ouvert | VH_0800END · Borne %IX225.2 (M3_BrakeIsOpen_DI) ➔ Attendu repos : 0V"
  },
  "PRE_04": {
    "cause_racine": "🚨 Contacteur de puissance sens/vitesse M1 resté collé fermé ou boucle de surveillance EDM ouverte.",
    "action_conducteur": "🛑 Ne pas enclencher la puissance. Condamner le pupitre de commande.",
    "action_maintenance": "⚠️ DANGER 400V : Consigner l'armoire + VAT. Contrôler les pôles de puissance KM_M1 et la chaîne des contacts miroirs NC en série. Remplacer le contacteur si soudé.",
    "points_test": "Local_Digital_IO · Borne %IX0.0 (M1_ContactorsReleased_DI) ➔ Mesure : 24Vcc / 0V entre borne et 0V carte ➔ Attendu repos : 24V (Contacts miroirs NC fermés en série)"
  },
  "PRE_05": {
    "cause_racine": "🚨 Contacteur de puissance sens/vitesse M2 resté collé fermé ou boucle de surveillance EDM ouverte.",
    "action_conducteur": "🛑 Ne pas enclencher la puissance. Condamner le pupitre de commande.",
    "action_maintenance": "⚠️ DANGER 400V : Consigner l'armoire + VAT. Contrôler les pôles de puissance KM_M2 et la chaîne des contacts miroirs NC en série. Remplacer le contacteur si soudé.",
    "points_test": "Local_Digital_IO · Borne %IX0.2 (M2_ContactorsReleased_DI) ➔ Mesure : 24Vcc / 0V entre borne et 0V carte ➔ Attendu repos : 24V (Contacts miroirs NC fermés en série)"
  },
  "PRE_06": {
    "cause_racine": "🔥 Disjoncteur magnétothermique moteur M1 déclenché ou sonde thermique bilame/PTC en surchauffe.",
    "action_conducteur": "⏳ Laisser refroidir 15 min. Vérifier visuellement l'absence d'obstacle mécanique sur le treuil M1.",
    "action_maintenance": "🧰 Contrôler disjoncteur moteur Q_M1 en armoire. Mesurer isolement enroulements et serrage bornes puissance. Réarmer Q_M1.",
    "points_test": "Local_Digital_IO · Borne %IX0.1 (M1_ThermalOk_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu normal : 24V (Contact NC disjoncteur fermé)"
  },
  "PRE_07": {
    "cause_racine": "🔥 Disjoncteur moteur M2 déclenché ou défaut moto-ventilation forcée.",
    "action_conducteur": "⏳ Laisser refroidir 15 min. Vérifier visuellement que la benne n'est pas bloquée.",
    "action_maintenance": "🧰 Contrôler disjoncteur moteur Q_M2 en armoire. Vérifier moto-ventilateur forcé et courant absorbé. Réarmer Q_M2.",
    "points_test": "Local_Digital_IO · Borne %IX0.3 (M2_ThermalOk_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu normal : 24V (Contact NC disjoncteur fermé)"
  },
  "PRE_08": {
    "cause_racine": "⚡ Disjoncteur protection freins déclenché en armoire (court-circuit bobine ou surchauffe redresseur).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvre treuils ou translation au pupitre.",
    "action_maintenance": "🧰 Armoire : mesurer résistance ohmique des bobines freins M1/M2/M3 et ponts redresseurs. Réarmer disjoncteur freins Q_Freins.",
    "points_test": "VH_0800END · Borne %IX225.3 (M1_M2_M3_BrakeThermalOk_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu normal : 24V (Contact NC fermé)"
  },
  "PRE_09": {
    "cause_racine": "🔌 Défaut alimentation réseau 400V : 2 phases inversées, phase manquante ou sous-tension.",
    "action_conducteur": "👀 Vérifier le voltmètre réseau au poste de conduite et la source d'alimentation (groupe ou réseau quai).",
    "action_maintenance": "🧰 Armoire tête : vérifier LEDs relais de surveillance phases. Mesurer 400Vac équilibré entre phases. Permuter 2 phases amont si inversion.",
    "points_test": "VH_0800END · Borne %IX225.4 (PhaseRotationOk_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu normal : 24V (Relais phases actif)"
  },
  "PRE_10": {
    "cause_racine": "🪢 Câble benne détendu (benne posée au sol ou au fond de l'eau) ou roulette palpeuse anti-mou bloquée.",
    "action_conducteur": "🕹️ Passer en manuel lent / dérogation au pupitre : retendre doucement le câble M2 jusqu'à extinction du voyant mou.",
    "action_maintenance": "🧰 Tambour M2 : contrôler liberté mécanique de la roulette palpeuse anti-mou et alignement du câble dans les gorges.",
    "points_test": "Local_Digital_IO · Borne %IX0.4 (M2_TensionedCable_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu câble tendu : 24V (Contact NC fermé)"
  },
  "PRE_11": {
    "cause_racine": "🪣 Benne détectée non fermée à la mise sous tension (état ouvert ou indéterminé).",
    "action_conducteur": "🕹️ Mettre sélecteur treuil sur Benne (M2). Actionner la commande de fermeture benne jusqu'au voyant benne fermée.",
    "action_maintenance": "💻 Vérifier cohérence valeur codeur M2 vs M1 (OffsetCloseM ~ 15 m) sur l'écran diagnostic IHM.",
    "points_test": "Diagnostic IHM · Variable _BucketState.IsClosed ➔ Attendu : TRUE après fermeture complète (Delta M2-M1 conforme)"
  },
  "PRE_12": {
    "cause_racine": "🚨 Arrêt d'urgence percuté sur le pupitre de commande ou chaîne de sécurité ouverte.",
    "action_conducteur": "👀 Vérifier et déverrouiller tous les coups de poing AU (pupitre, passerelle, armoire). Appuyer sur Réarmement AU.",
    "action_maintenance": "🧰 Contrôler tension 24V sur boucle de sécurité AU et retombée des canaux du bloc de sécurité.",
    "points_test": "VH_0800END · Borne %IX225.7 (EmergencyChainClosed_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu réarmé : 24V"
  },
  "PRE_13": {
    "cause_racine": "📡 Joystick non détecté sur le bus CANopen (coupure alimentation 24V pupitre ou câble CAN coupé).",
    "action_conducteur": "🛑 Couper et réenclencher l'interrupteur d'alimentation du pupitre de commande. Relever le code d'erreur affiché.",
    "action_maintenance": "🧰 Contrôler 24Vcc sur connecteur manipulateur sous pupitre. Vérifier continuité CAN_H / CAN_L et résistance de terminaison 120 Ω.",
    "points_test": "Bus CANopen Pupitre ➔ Mesure : 24Vcc alim broches 1-2 | 60 Ω entre CAN_H et CAN_L ligne éteinte"
  },
  "PRE_14": {
    "cause_racine": "📡 Codeur absolu EtherCAT treuil M1 non opérationnel (câble M12 Ethernet débranché ou perte alimentation 24V).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvre treuil M1. Vérifier voyant bus sur l'écran IHM.",
    "action_maintenance": "🧰 Treuil M1 : contrôler LED d'état sur le codeur COD1 (L/A clignotante = trafic actif). Tester cordon M12 et présence 24Vcc.",
    "points_test": "Codeur COD1 Treuil M1 ➔ Port M12 IN (EtherCAT) ➔ Attendu : LED L/A Verte clignotante, 24Vcc présent sur broches d'alimentation"
  },
  "PRE_15": {
    "cause_racine": "📡 Codeur absolu EtherCAT treuil M2 non opérationnel (câble M12 Ethernet débranché ou perte alimentation 24V).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvre treuil M2. Vérifier voyant bus sur l'écran IHM.",
    "action_maintenance": "🧰 Treuil M2 : contrôler LED d'état sur le codeur COD2 (L/A clignotante = trafic actif). Tester cordon M12 et présence 24Vcc.",
    "points_test": "Codeur COD2 Treuil M2 ➔ Port M12 IN (EtherCAT) ➔ Attendu : LED L/A Verte clignotante, 24Vcc présent sur broches d'alimentation"
  },
  "PRE_16": {
    "cause_racine": "⚡ Variateur translation AC600 hors ligne ou en défaut (coupure réseau EtherCAT, disjoncteur variateur déclenché).",
    "action_conducteur": "🛑 Ne pas tenter de déplacer le chariot au pupitre. Relever le code variateur sur l'IHM.",
    "action_maintenance": "🧰 Armoire : vérifier affichage LED sur le variateur AC600. Contrôler disjoncteur drive Q_Drive et câble RJ45 EtherCAT.",
    "points_test": "Variateur AC600 ➔ Afficheur de façade (Attendu : état 'rdy' ou fréquence 0.0) | Câble RJ45 EtherCAT Port IN"
  }
}

# --- 2. LES 71 ALARMES BLOQUANTES IHM (ALM_001 à ALM_071) ---
active_alarms_kb = {
  # FAMILLE 1 : BUS & MODULES MATÉRIELS (ALM_001 à ALM_011)
  "ALM_001": {
    "cause_racine": "🔌 Défaut de communication interne ou panne matérielle du module CPU Local_Digital_IO (Slot 1).",
    "action_conducteur": "🛑 Arrêt immédiat de la machine. Couper la commande au pupitre. Noter le code ALM_001.",
    "action_maintenance": "🧰 Armoire : vérifier voyant ERR/RUN sur la CPU VEICHI. Contrôler alimentation 24Vcc et connectique nappe de fond de panier.",
    "points_test": "Automate VEICHI · Slot 1 Local_Digital_IO ➔ Voyants CPU : RUN Vert fixe, ERR Éteint ➔ Mesure : 24Vcc entre bornes +24V et 0V"
  },
  "ALM_002": {
    "cause_racine": "🔌 Défaut de communication coupleur ou coupure 24V sur le module d'entrées VH_0800END (Slot 3).",
    "action_conducteur": "🛑 Couper les commandes au pupitre. Verrouiller le poste de conduite.",
    "action_maintenance": "🧰 Armoire : vérifier clip de verrouillage fond de panier Slot 3. Mesurer alimentation 24Vcc sur le bornier du module VH_0800END.",
    "points_test": "Automate VEICHI · Slot 3 VH_0800END ➔ Mesure : 24Vcc sur bornes d'alimentation module ➔ LED PWR allumée verte"
  },
  "ALM_003": {
    "cause_racine": "🔌 Défaut de communication ou panne d'alimentation du module mixte VH_0808ETP (Slot 2).",
    "action_conducteur": "🛑 Interdiction translation et treuils au pupitre. Relever le code ALM_003.",
    "action_maintenance": "🧰 Armoire : contrôler enfichage Slot 2 sur le rail DIN. Vérifier fusible protection 24Vcc de la carte VH_0808ETP.",
    "points_test": "Automate VEICHI · Slot 2 VH_0808ETP ➔ Mesure : 24Vcc sur bornes d'alimentation carte ➔ LED PWR allumée verte"
  },
  "ALM_004": {
    "cause_racine": "🔌 Défaut d'alimentation ou défaillance du module 8 sorties relais VH_0008ER (Slot 4 - Freins).",
    "action_conducteur": "🛑 Interdiction des commandes treuils et translation au pupitre de commande.",
    "action_maintenance": "🧰 Armoire : vérifier module Slot 4. Contrôler présence du 24Vcc sur les communs relais C0..C7 et la nappe interne.",
    "points_test": "Automate VEICHI · Slot 4 VH_0008ER ➔ Mesure : 24Vcc sur communs relais ➔ Vérifier étrier fond de panier bien enclenché"
  },
  "ALM_005": {
    "cause_racine": "🔌 Défaut de communication ou d'alimentation du module sorties relais VH_0008ER_1 (Slot 5 - Sécurité).",
    "action_conducteur": "🛑 Frapper l'arrêt d'urgence au pupitre. Condamner le poste de conduite.",
    "action_maintenance": "🧰 Armoire : vérifier Slot 5. Contrôler alimentation 24Vcc et boucle de maintien puissance PowerKeepAlive.",
    "points_test": "Automate VEICHI · Slot 5 VH_0008ER_1 ➔ Mesure : 24Vcc sur communs C6/C7 (%QX28.6/%QX28.7) ➔ Attendu : Relais fermés au réarmement puissance"
  },
  "ALM_006": {
    "cause_racine": "📡 Défaillance générale du bus CANopen maître CPU (câble blindé coupé, parasite sévère, bus éteint).",
    "action_conducteur": "🛑 Arrêt des commandes. Couper puis réenclencher l'alimentation générale du pupitre.",
    "action_maintenance": "🧰 Vérifier résistance 120 Ω à chaque extrémité du bus CAN. Contrôler le blindage et la continuité des lignes CAN_H et CAN_L.",
    "points_test": "Port CANopen CPU VEICHI ➔ Mesure hors tension : 60 Ω entre CAN_H et CAN_L ➔ Sous tension : ~2.5Vcc sur CAN_H et CAN_L par rapport au 0V"
  },
  "ALM_007": {
    "cause_racine": "📡 Joystick pupitre JOY1 non détecté sur le bus CANopen (Node ID 1 absent ou 24V pupitre coupé).",
    "action_conducteur": "🕹️ Mettre le joystick physique au neutre mécanique. Couper et réarmer le commutateur pupitre.",
    "action_maintenance": "🧰 Contrôler 24Vcc sur connecteur JOY1 sous pupitre. Vérifier l'état de la LED CANopen sous le manipulateur (Verte clignotante = Pre-Op).",
    "points_test": "Connecteur JOY1 sous pupitre ➔ Mesure : 24Vcc entre broche 1 (+) et broche 2 (0V) ➔ Câble CAN blindé 2 paires"
  },
  "ALM_008": {
    "cause_racine": "📡 Rupture de communication sur le maître EtherCAT automate (câble principal débranché ou perturbation CEM).",
    "action_conducteur": "🛑 Arrêt des commandes machine. Noter code ALM_008 au pupitre.",
    "action_maintenance": "🧰 Armoire : inspecter câble Ethernet blindé RJ45 partant du port EtherCAT CPU vers le premier esclave (variateur AC600).",
    "points_test": "Port EtherCAT CPU VEICHI ➔ LED Link/Act : Verte clignotante (trafic actif) ➔ Cordon Ethernet industriel blindé CAT5e/CAT6"
  },
  "ALM_009": {
    "cause_racine": "📡 Codeur absolu COD1 treuil levage M1 non détecté sur le bus EtherCAT (câble touret M12 coupé ou 24V manquant).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvrer le treuil M1. Rester au neutre au pupitre.",
    "action_maintenance": "🧰 Treuil M1 : contrôler voyants LED (PWR, L/A) sur connecteur M12 du codeur COD1. Tester continuité des 4 paires du cordon en chaîne porte-câbles.",
    "points_test": "Codeur COD1 (Treuil M1) ➔ Port M12 IN ➔ Attendu : 24Vcc broches 1-3, LED L/A Verte clignotante"
  },
  "ALM_010": {
    "cause_racine": "📡 Codeur absolu COD2 treuil benne M2 non détecté sur le bus EtherCAT (câble touret M12 coupé ou 24V manquant).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvrer le treuil M2. Rester au neutre au pupitre.",
    "action_maintenance": "🧰 Treuil M2 : contrôler voyants LED (PWR, L/A) sur connecteur M12 du codeur COD2. Tester cordon chaîne porte-câbles et disjoncteur 24V capteurs.",
    "points_test": "Codeur COD2 (Treuil M2) ➔ Port M12 IN ➔ Attendu : 24Vcc broches 1-3, LED L/A Verte clignotante"
  },
  "ALM_011": {
    "cause_racine": "📡 Variateur translation AC600 non détecté sur le bus EtherCAT (drive éteint ou câble RJ45 déconnecté).",
    "action_conducteur": "🛑 Translation M3 immobilisée. Ne pas insister sur les commandes.",
    "action_maintenance": "🧰 Armoire : vérifier disjoncteur alimentation Q_Drive variateur. Contrôler voyant LINK sur port RJ45 EtherCAT du drive AC600.",
    "points_test": "Variateur AC600 ➔ Port RJ45 EtherCAT IN ➔ Attendu : LED Link verte fixe/clignotante ➔ Disjoncteur drive enclenché"
  },

  # FAMILLE 2 : SÉCURITÉ MÉCANIQUE TREUIL M1 (ALM_012 à ALM_022)
  "ALM_012": {
    "cause_racine": "📡 Perte de communication avec le pupitre ou heartbeat IHM interrompu pendant la commande de levage M1.",
    "action_conducteur": "🕹️ Mettre les manipulateurs au neutre au pupitre. Vérifier l'écran IHM.",
    "action_maintenance": "🧰 Contrôler le réseau Ethernet IHM-PLC et l'alimentation 24V de la dalle tactile de supervision.",
    "points_test": "Port Ethernet IHM ➔ Ping IP automate VEICHI ➔ Diagnostic variable GVL_IHM.Commun.HeartbeatIhmOk"
  },
  "ALM_013": {
    "cause_racine": "📡 Perte de signal ou anomalie trame du codeur treuil M1 en mouvement (perte comptage position).",
    "action_conducteur": "🛑 Arrêt du treuil M1. Ne pas passer en mode automatique. Mettre au neutre.",
    "action_maintenance": "🧰 Vérifier fixation mécanique de l'axe codeur COD1 sur le tambour treuil M1. Contrôler connecteur M12 et blindage.",
    "points_test": "Codeur COD1 Treuil M1 ➔ Variable PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable ➔ Attendu : TRUE"
  },
  "ALM_014": {
    "cause_racine": "⚡ Détection d'une inversion de phase 400V ou coupure de phase pendant l'exploitation du treuil M1.",
    "action_conducteur": "🛑 Arrêt immédiat de la machine. Couper les commandes au pupitre.",
    "action_maintenance": "🧰 Contrôler le relais de surveillance des phases en armoire tête. Mesurer tension 400Vac entre phases L1, L2, L3.",
    "points_test": "VH_0800END · Borne %IX225.4 (PhaseRotationOk_DI) ➔ Attendu : 24Vcc normal ➔ 0V si défaut phase"
  },
  "ALM_015": {
    "cause_racine": "🚨 Dérive non commandée M1 (Meca A) : rotation du tambour détectée > 5.0m alors que les commandes et le frein sont coupés.",
    "action_conducteur": "🛑 NE TOUCHER À RIEN. Enclencher l'Arrêt d'Urgence coup de poing pupitre si le tambour continue de tourner sous la charge.",
    "action_maintenance": "⚠️ DANGER GRAVITATIONNEL : Interdire l'accès sous la flèche. Armoire : mesurer 0V sur bobine frein M1. Remplacer les garnitures si patinage mécanique.",
    "points_test": "VH_0008ER · %QX27.0 = 0 | VH_0800END · %IX225.0 = 0V ➔ Mesure bornier frein treuil M1 : 0V strict"
  },
  "ALM_016": {
    "cause_racine": "⏱️ Absence confirmation arrêt M1 (Meca B) : contacteurs ou frein restés enclenchés > 3s après retour au neutre du manipulateur.",
    "action_conducteur": "🕹️ Manipulateur M1 au neutre. Contrôler visuellement l'arrêt complet du tambour treuil.",
    "action_maintenance": "🧰 Armoire : vérifier si contacteur KM_M1 ou relais de défreinage reste mécaniquement coincé fermé. Contrôler varistance anti-arc.",
    "points_test": "Local_Digital_IO · %IX0.0 (M1_ContactorsReleased_DI) ➔ Attendu repos : 24V | VH_0800END · %IX225.0 (BrakeOpen) ➔ Attendu repos : 0V"
  },
  "ALM_017": {
    "cause_racine": "🚨 Glissement M1 pendant cycle benne (Meca C) : le treuil M1 a dérivé de plus de 2.0m alors qu'il devait maintenir la charge immobile.",
    "action_conducteur": "🛑 Arrêt immédiat de l'action benne. Mettre les manipulateurs au neutre au pupitre.",
    "action_maintenance": "🧰 Contrôler le couple de serrage du frein treuil M1. Vérifier si la bobine de défreinage M1 n'a pas reçu d'alimentation parasite.",
    "points_test": "Mesure multimètre DC aux bornes bobine frein M1 pendant fermeture benne : 0V strict ➔ MecaCDriftM > 2.0m"
  },
  "ALM_018": {
    "cause_racine": "🚨 Non-arrêt capteur haut M1 (Meca D) : le treuil a franchi le fin de course haut sans que l'arrêt ne soit confirmé sous 3s.",
    "action_conducteur": "🛑 ARRÊT IMMÉDIAT. Ne pas tenter de forcer la montée. Vérifier que la tête de flèche n'est pas en butée.",
    "action_maintenance": "🧰 Contrôler détecteur inductif fin de course haut M1M2_TopPositionFree_DI (%IX0.7). Vérifier la chaîne de coupure contacteurs montée.",
    "points_test": "Local_Digital_IO · Borne %IX0.7 (M1M2_TopPositionFree_DI) ➔ Attendu libre : 24V (Contact NC) | Ouvert en butée : 0V"
  },
  "ALM_019": {
    "cause_racine": "🚨 Écart critique synchronisation M1/M2 (Meca E) : décalage entre câbles > 7.0m en mouvement couplé solidaire.",
    "action_conducteur": "🕹️ Manipulateurs au neutre. Vérifier visuellement l'assiette et le comportement de la benne.",
    "action_maintenance": "🧰 Relever positions codeurs M1 et M2 sur l'IHM. Vérifier si un tambour patine ou si un câble a sauté d'une gorge.",
    "points_test": "IHM Synchro ➔ Écart brut ABS(CablePosM1 - CablePosM2 + ActiveOffsetM) > 7.0m ➔ TonMecaE = 3s avant coupure puissance"
  },
  "ALM_020": {
    "cause_racine": "🚨 Sens de rotation opposé M1 : le tambour tourne à l'envers de la commande demandée au manipulateur pendant plus de 1s.",
    "action_conducteur": "🕹️ Ramener le manipulateur au neutre au pupitre. Ne pas forcer la commande.",
    "action_maintenance": "🧰 Contrôler l'ordre des phases moteur sur contacteurs montée/descente KM1/KM2 en armoire. Vérifier polarité de comptage codeur COD1.",
    "points_test": "Codeur COD1 Treuil M1 ➔ Mesure : Vitesse signée SignedSpeed_Mps ➔ Attendu : Même polarité que l'ordre RelayFwd/RelayRev"
  },
  "ALM_021": {
    "cause_racine": "⏱️ Absence de mouvement M1 : commande active et freins ouverts mais aucune progression de câble mesurée après 3s.",
    "action_conducteur": "🕹️ Ramener manipulateur au neutre. Vérifier visuellement si le câble ou le tambour est bloqué mécaniquement.",
    "action_maintenance": "🧰 Armoire : vérifier disjoncteur moteur Q_M1 et présence tension 400Vac en sortie contacteurs de sens. Contrôler décollement mécanique frein.",
    "points_test": "Local_Digital_IO · Borne %IX0.1 (M1_ThermalOk_DI) ➔ Mesure : 400Vac bornes moteur ➔ Attendu repos : 24Vcc sur %IX0.1 et 400Vac en commande"
  },
  "ALM_022": {
    "cause_racine": "⚠️ Survitesse treuil M1 détectée par le codeur COD1 au-delà de la bande maximale autorisée (SafeStop déclenché).",
    "action_conducteur": "🕹️ Manipulateur M1 au neutre. Laisser le treuil s'immobiliser sous rampe contrôlée.",
    "action_maintenance": "🧰 Contrôler l'accouplement mécanique du codeur COD1. Vérifier si la charge n'entraîne pas le tambour au-delà de la vitesse nominale.",
    "points_test": "Diagnostic IHM ➔ Vitesse mesurée Speed_Mps > SpeedBandMaxMps[5] ➔ SafeStop actif sans PowerCutOff"
  },

  # FAMILLE 2 BIS : SÉCURITÉ MÉCANIQUE TREUIL M2 (ALM_023 à ALM_033)
  "ALM_023": {
    "cause_racine": "📡 Perte de communication opérateur ou coupure heartbeat IHM pendant la commande du treuil benne M2.",
    "action_conducteur": "🕹️ Ramener manipulateur benne au neutre au pupitre. Contrôler l'écran tactile.",
    "action_maintenance": "🧰 Contrôler le commutateur pupitre et la liaison Ethernet IHM-automate.",
    "points_test": "Port Ethernet IHM ➔ Ping IP automate VEICHI ➔ GVL_IHM.Commun.HeartbeatIhmOk"
  },
  "ALM_024": {
    "cause_racine": "📡 Perte de signal ou défaut de mesure du codeur absolu treuil M2 COD2.",
    "action_conducteur": "🛑 Arrêt des manœuvres benne. Manipulateurs au neutre au pupitre.",
    "action_maintenance": "🧰 Contrôler le câble blindé M12 et la fixation de l'axe codeur COD2 sur le tambour M2.",
    "points_test": "Codeur COD2 Treuil M2 ➔ Variable PRG_02_Acquisition.Data.EncoderM2.Measurement.EncoderAvailable ➔ Attendu : TRUE"
  },
  "ALM_025": {
    "cause_racine": "⚡ Inversion ou coupure d'une phase réseau 400V pendant l'exploitation du treuil benne M2.",
    "action_conducteur": "🛑 Arrêt immédiat de la machine. Couper les commandes au pupitre.",
    "action_maintenance": "🧰 Contrôler le relais de surveillance des phases en armoire tête. Mesurer tension triphasée 400Vac.",
    "points_test": "VH_0800END · Borne %IX225.4 (PhaseRotationOk_DI) ➔ Attendu : 24Vcc normal"
  },
  "ALM_026": {
    "cause_racine": "🚨 Dérive non commandée M2 (Meca A) : rotation du tambour treuil benne > 5.0m sans commande active.",
    "action_conducteur": "🛑 NE TOUCHER À RIEN. Enclencher l'Arrêt d'Urgence pupitre si la benne descend toute seule.",
    "action_maintenance": "⚠️ DANGER : Condamner le pupitre. Armoire : mesurer 0V sur bobine frein M2. Remplacer les garnitures si patinage mécanique.",
    "points_test": "VH_0008ER · %QX27.1 = 0 | VH_0800END · %IX225.1 = 0V ➔ Mesure bornier frein treuil M2 : 0V strict"
  },
  "ALM_027": {
    "cause_racine": "⏱️ Absence confirmation arrêt M2 (Meca B) : contacteurs ou frein M2 restés enclenchés > 3s après retour au neutre.",
    "action_conducteur": "🕹️ Manipulateur benne au neutre. Contrôler l'arrêt complet du tambour treuil M2.",
    "action_maintenance": "🧰 Armoire : contrôler retombée mécanique du contacteur KM_M2 et relais frein. Remplacer si contacts collés.",
    "points_test": "Local_Digital_IO · %IX0.2 (M2_ContactorsReleased_DI) ➔ Attendu repos : 24V | VH_0800END · %IX225.1 (BrakeOpen) ➔ Attendu : 0V"
  },
  "ALM_028": {
    "cause_racine": "🚨 Glissement M2 pendant benne figée (Meca C) : dérive anormale du tambour benne M2.",
    "action_conducteur": "🛑 Arrêt immédiat de la manœuvre. Mettre les manipulateurs au neutre au pupitre.",
    "action_maintenance": "🧰 Vérifier étanchéité et réglage entrefer frein M2. Mesurer absence de tension sur bobine frein M2.",
    "points_test": "Bornier frein treuil M2 ➔ Mesure : Tension bobine frein ➔ Attendu : 0Vcc et dérive MecaCDriftM < 2.0m"
  },
  "ALM_029": {
    "cause_racine": "🚨 Non-arrêt capteur haut M2 (Meca D) : treuil benne ayant dépassé le fin de course haut sans s'arrêter sous 3s.",
    "action_conducteur": "🛑 ARRÊT IMMÉDIAT. Ne pas forcer la montée. Vérifier que le câble n'est pas en butée contre le tambour.",
    "action_maintenance": "🧰 Contrôler détecteur inductif fin de course haut M1M2_TopPositionFree_DI (%IX0.7) et contacteurs montée M2.",
    "points_test": "Local_Digital_IO · Borne %IX0.7 (M1M2_TopPositionFree_DI) ➔ Attendu libre : 24V | Ouvert : 0V"
  },
  "ALM_030": {
    "cause_racine": "🚨 Écart critique synchronisation M2/M1 (Meca E) : dérive différentielle des treuils > 7.0m en marche couplée.",
    "action_conducteur": "🕹️ Manipulateurs au neutre au pupitre. Vérifier l'état visuel des câbles sur le ponton.",
    "action_maintenance": "🧰 Contrôler valeurs de position COD1 et COD2 sur IHM. Vérifier absence de glissement câble dans les tambours.",
    "points_test": "Diagnostic IHM Synchro ➔ Écart absolu > 7.0m ➔ TonMecaE = 3s avant coupure puissance"
  },
  "ALM_031": {
    "cause_racine": "🚨 Sens de rotation opposé M2 : rotation du tambour à l'envers de la commande demandée pendant plus de 1s.",
    "action_conducteur": "🕹️ Manipulateur au neutre au pupitre de commande.",
    "action_maintenance": "🧰 Contrôler câblage phases puissance moteur M2 sur contacteurs KM_M2. Vérifier sens comptage codeur COD2.",
    "points_test": "Codeur COD2 Treuil M2 ➔ Mesure : Vitesse signée SignedSpeed_Mps ➔ Attendu : Même polarité que l'ordre RelayFwd/RelayRev"
  },
  "ALM_032": {
    "cause_racine": "⏱️ Absence de mouvement M2 : commande active et frein ouvert mais aucune rotation mesurée après 3s.",
    "action_conducteur": "🕹️ Manipulateur au neutre. Contrôler visuellement si la benne ou le tambour est coincé.",
    "action_maintenance": "🧰 Armoire : contrôler disjoncteur moteur Q_M2 et présence 400Vac aux bornes moteur. Contrôler défreinage mécanique.",
    "points_test": "Local_Digital_IO · Borne %IX0.3 (M2_ThermalOk_DI) ➔ Mesure : 400Vac bornes moteur ➔ Attendu repos : 24Vcc sur %IX0.3 et 400Vac en commande"
  },
  "ALM_033": {
    "cause_racine": "⚠️ Survitesse treuil M2 détectée par codeur COD2 au-delà du palier 5 (SafeStop activé).",
    "action_conducteur": "🕹️ Manipulateur benne au neutre. Attendre l'arrêt complet sous rampe.",
    "action_maintenance": "🧰 Contrôler l'accouplement du codeur COD2. Vérifier absence d'emballement sous le poids de la benne.",
    "points_test": "Diagnostic IHM ➔ Vitesse mesurée Speed_Mps > SpeedBandMaxMps[5] ➔ SafeStop actif"
  },

  # FAMILLE 3 : TRANSLATION PORTIQUE M3 (ALM_034 à ALM_044)
  "ALM_034": {
    "cause_racine": "📡 Perte de communication opérateur pupitre pendant la commande de translation portique M3.",
    "action_conducteur": "🕹️ Mettre le manipulateur translation au neutre au pupitre de commande.",
    "action_maintenance": "🧰 Contrôler bus CANopen JOY1 et heartbeat supervision IHM.",
    "points_test": "Bus CANopen Pupitre ➔ Diagnostic trames CAN ➔ Attendu : NMT Operational et HeartbeatIhmOk = TRUE"
  },
  "ALM_035": {
    "cause_racine": "📡 Perte de communication bus EtherCAT avec le variateur translation VEICHI AC600.",
    "action_conducteur": "🛑 Translation bloquée. Mettre les commandes au neutre au pupitre.",
    "action_maintenance": "🧰 Contrôler cordon RJ45 EtherCAT reliant l'automate au variateur AC600. Vérifier alimentation commande drive.",
    "points_test": "Variateur AC600 ➔ Port EtherCAT IN ➔ Attendu : Câble RJ45 connecté, LED Link/Act verte clignotante"
  },
  "ALM_036": {
    "cause_racine": "⚡ Rotation de phase 400V incorrecte ou perte de phase sur l'alimentation de la translation.",
    "action_conducteur": "🛑 Arrêt immédiat de la machine au pupitre.",
    "action_maintenance": "🧰 Armoire : vérifier relais de phases et tension 400Vac en amont du variateur AC600.",
    "points_test": "VH_0800END · Borne %IX225.4 (PhaseRotationOk_DI) ➔ Attendu : 24Vcc normal"
  },
  "ALM_037": {
    "cause_racine": "⏱️ Absence confirmation arrêt translation (Meca B) : variateur ou frein M3 toujours actifs > 3s après stop.",
    "action_conducteur": "🕹️ Manipulateur translation au neutre. Vérifier visuellement l'immobilisation du portique.",
    "action_maintenance": "🧰 Armoire : vérifier contacteur frein translation KM_Frein_M3 et sortie fréquence variateur AC600.",
    "points_test": "VH_0800END · Borne %IX225.2 (M3_BrakeIsOpen_DI) ➔ Attendu arrêt : 0V | Variateur AC600 : Fréquence < 0.5 Hz"
  },
  "ALM_038": {
    "cause_racine": "🚨 Mouvement non commandé translation (Meca A) : déplacement portique détecté sans consigne active après 1s.",
    "action_conducteur": "🛑 Frapper l'Arrêt d'Urgence pupitre si le portique dérive le long des rails sous l'effet du vent.",
    "action_maintenance": "⚠️ DANGER : Condamner le portique avec cales rail. Armoire : mesurer 0V sur bobine frein translation. Remplacer patins de frein si usés.",
    "points_test": "Bornier armoire frein M3 ➔ Mesure : 0V strict ➔ Variateur AC600 : Fréquence mesurée > 0.5 Hz sans commande"
  },
  "ALM_039": {
    "cause_racine": "🚨 Fin de course extrême translation actionné (dépassement zone Trémie ou Maintenance).",
    "action_conducteur": "🛑 Ne plus avancer vers la butée. Passer en dérogation au pupitre pour reculer hors de la zone.",
    "action_maintenance": "🧰 Vérifier palpeur inductif came extrême sur voie de roulement. Contrôler boîte de raccordement chariot.",
    "points_test": "VH_0808ETP · Borne %IX224.0 (Trémie) ou %IX224.4 (Maintenance) ➔ Mesure : 24Vcc sur la came concernée"
  },
  "ALM_040": {
    "cause_racine": "📐 Combinaison de cames translation physiquement impossible (ex: Trémie et Maintenance actives en même temps).",
    "action_conducteur": "🛑 Arrêt des commandes translation au pupitre. Relever la position visuelle approximative du portique.",
    "action_maintenance": "🧰 Inspecter les 5 capteurs inductifs de cames translation le long des rails (boue, graviers, câbles blessés).",
    "points_test": "VH_0808ETP · Bornes %IX224.0 à %IX224.4 ➔ Mesure 24Vcc : Une seule came active autorisée à la fois"
  },
  "ALM_041": {
    "cause_racine": "⚡ Défaut séquence / retour frein translation M3 (discordance entre ordre défreinage et recopie armoire).",
    "action_conducteur": "🕹️ Manipulateur translation au neutre au pupitre.",
    "action_maintenance": "🧰 Armoire : tester contacteur relais frein KM_Frein_M3. Mesurer tension bobine défreinage en manœuvre.",
    "points_test": "VH_0008ER · Relais %QX27.2 (Cmd) vs VH_0800END · Borne %IX225.2 (Retour %IX225.2) ➔ Concordance exigée sous 500 ms"
  },
  "ALM_042": {
    "cause_racine": "⚡ Défaut variateur translation AC600 (surcharge, surintensité, sous-tension bus continu ou défaut thermique).",
    "action_conducteur": "🕹️ Manipulateur translation au neutre au pupitre. Patienter 5 min pour refroidissement.",
    "action_maintenance": "🧰 Armoire : relever le code affiché sur le bandeau digital du variateur AC600 (ex: E.OC, E.OL, E.LU). Contrôler résistance de freinage.",
    "points_test": "Afficheur variateur AC600 ➔ Code défaut | Mesure bus DC : ~560Vcc entre bornes (+) et (-)"
  },
  "ALM_043": {
    "cause_racine": "🛑 Butée mécanique finale de translation atteinte (arrêt immédiat sur bordure de voie).",
    "action_conducteur": "🕹️ Inverser le manipulateur pour dégager le portique en sens inverse.",
    "action_maintenance": "🧰 Contrôler amortisseurs de fin de course rail et état mécanique du linguet de déclenchement.",
    "points_test": "VH_0808ETP · Bornes %IX224.0 ou %IX224.4 ➔ Mesure : 24Vcc entre borne et 0V ➔ Attendu hors butée : 0V (Détecteur inductif NO libre)"
  },
  "ALM_044": {
    "cause_racine": "🔒 Barrière finale translation active : interlock frein ou redémarrage engagé nécessitant un acquittement explicite.",
    "action_conducteur": "🕹️ Ramener le manipulateur au neutre. Appuyer sur le bouton Acquittement / Reset au pupitre.",
    "action_maintenance": "💻 Vérifier mot d'état TranslationFinalInterlockErrorId sur l'écran de diagnostic IHM.",
    "points_test": "Pupitre / IHM ➔ Diagnostic variable TranslationFinalInterlockErrorId ➔ Attendu : Valeur 0 après front montant bouton Reset"
  },

  # FAMILLE 4 : GÉOMÉTRIE BENNE, SYNCHRO & PLONGÉE (ALM_045 à ALM_062)
  "ALM_045": {
    "cause_racine": "⚙️ Configuration géométrie benne invalide (offset fermé inférieur ou égal à l'offset ouvert en mémoire).",
    "action_conducteur": "🛑 Ne pas tenter de manœuvrer la benne au pupitre.",
    "action_maintenance": "💻 IHM Réglages : vérifier paramètres géométrie benne. L'offset fermé doit être supérieur à l'offset ouvert (nominal 15.0m > 0.0m).",
    "points_test": "IHM Réglages Benne ➔ Variables OffsetCloseM vs OffsetOpenM ➔ Attendu : OffsetCloseM (nom. 15.0m) strictement supérieur à OffsetOpenM (0.0m)"
  },
  "ALM_046": {
    "cause_racine": "🪣 Dépassement écart maximum autorisé benne : décalage M2 - M1 hors plage physique plausible (> 17m ou < -1m).",
    "action_conducteur": "🕹️ Passer en mode Manuel Dérogation : ramener visuellement la benne dans une position intermédiaire normale.",
    "action_maintenance": "🧰 Vérifier position codeurs M1 et M2. Vérifier absence de glissement de câble ou de mou exagéré.",
    "points_test": "IHM Benne ➔ Écart mesuré CablePosM2 - CablePosM1 ➔ Attendu : Compris dans l'intervalle [-1.0m .. 17.0m]"
  },
  "ALM_047": {
    "cause_racine": "⏱️ Timeout déplacement benne : la benne n'a pas atteint sa position ouverte ou fermée sous 60 secondes.",
    "action_conducteur": "🕹️ Ramener manipulateur au neutre. Vérifier visuellement si la benne est coincée dans le matériau.",
    "action_maintenance": "🧰 Contrôler vitesse treuil M2 et état mécanique des poulies de fermeture benne.",
    "points_test": "Bloc FB_Bucket ➔ Temporisateur interne TonTimeout ➔ Attendu : Temps écoulé ET < CfgTimeoutDuration (T#60s)"
  },
  "ALM_048": {
    "cause_racine": "🚨 Glissement treuil M1 détecté pendant manœuvre benne (> 1.0m de mouvement flèche non autorisé).",
    "action_conducteur": "🛑 Arrêt de la commande benne. Ramener au neutre au pupitre.",
    "action_maintenance": "🧰 Contrôler frein treuil M1 et absence de rotation parasite pendant l'actionnement du treuil M2.",
    "points_test": "Treuil M1 ➔ Écart position ABS(CablePosM1 - M1RefPosM) ➔ Attendu : Dérive < 1.0m pendant manœuvre benne"
  },
  "ALM_049": {
    "cause_racine": "📍 Codeurs treuils non référencés pour la séquence benne (homing machine non validé après mise sous tension).",
    "action_conducteur": "🕹️ Effectuer la procédure de référencement machine (Homing) au pupitre de commande.",
    "action_maintenance": "💻 Vérifier drapeaux HomedM1 et HomedM2 sur la page diagnostic superviseur.",
    "points_test": "Supervision IHM / PLC ➔ Variables HomedAndReliableM1 et HomedAndReliableM2 ➔ Attendu : État TRUE sur les deux axes"
  },
  "ALM_050": {
    "cause_racine": "⚠️ Écart de synchronisation M1/M2 supérieur à 6.0m en marche couplée (SafeStop activé).",
    "action_conducteur": "🕹️ Manipulateurs au neutre au pupitre. Vérifier visuellement la planéité des câbles.",
    "action_maintenance": "🧰 Contrôler vitesse respective des tambours M1 et M2. Recaler l'assiette en pilotage unitaire si nécessaire.",
    "points_test": "FB_SyncDeviation ➔ Écart calculé DeltaPosM ➔ Attendu : DeltaPosM < 6.0m (seuil d'arrêt)"
  },
  "ALM_051": {
    "cause_racine": "🔀 Discordance contacteurs M1/M2 en marche synchronisée (un treuil commandé et pas l'autre ou paliers différents).",
    "action_conducteur": "🕹️ Manipulateurs au neutre au pupitre de commande.",
    "action_maintenance": "🧰 Armoire : vérifier la chaîne de commande des contacteurs de sens et paliers M1 et M2. Contrôler relais de sortie.",
    "points_test": "FB_SyncContactor ➔ Variable ContactorMismatch ➔ Attendu repos / marche couplée : FALSE (Vecteurs identiques)"
  },
  "ALM_052": {
    "cause_racine": "⏱️ Timeout immersion cycle automatique : temps d'atteinte de la surface d'eau dépassé.",
    "action_conducteur": "🕹️ Repasser en mode Manuel au pupitre. Remonter la benne en surface.",
    "action_maintenance": "💻 Vérifier réglage altimétrique du plan d'eau (ImmersionUpper_M) sur l'IHM cycle.",
    "points_test": "Bloc FB_CycleSemiAuto ➔ Temporisateur phase plongée ➔ Attendu : Atteinte plan d'eau avant expiration T#Timeout"
  },
  "ALM_053": {
    "cause_racine": "⏱️ Timeout détection fond : la benne descend sous l'eau sans toucher le fond dans le temps alloué.",
    "action_conducteur": "🕹️ Stopper la descente automatique. Repasser en manuel au pupitre.",
    "action_maintenance": "🧰 Contrôler fonctionnement palpeur Kobold ou seuil altimétrique de profondeur fond.",
    "points_test": "Bloc FB_CycleSemiAuto ➔ Temporisateur descente fond ➔ Attendu : Contact fond avant seuil temps alloué"
  },
  "ALM_054": {
    "cause_racine": "🛑 Limite basse de plongée atteinte : la benne a atteint la profondeur maximale autorisée.",
    "action_conducteur": "🕹️ Inverser la commande pour remonter la benne au pupitre de commande.",
    "action_maintenance": "💻 Vérifier seuil de profondeur légale CfgCableLimitDescentM sur la page configuration IHM.",
    "points_test": "Codeur COD1 Treuil M1 ➔ Variable CablePosM1 ➔ Attendu : Position supérieure à CfgCableLimitDescentM (-50.0m)"
  },
  "ALM_055": {
    "cause_racine": "🌊 Contact fond perdu pendant l'extraction (glissement de la benne dans la boue ou perte signal Kobold).",
    "action_conducteur": "🕹️ Arrêter la montée rapide. Passer en manuel lent pour assurer la fermeture.",
    "action_maintenance": "🧰 Contrôler capteur palpeur Kobold (%IX0.5) et liaison électrique touret.",
    "points_test": "Local_Digital_IO · Borne %IX0.5 (KoboldBottomTouch_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu : 24V reposée au fond (0V en suspension)"
  },
  "ALM_056": {
    "cause_racine": "🪢 Perte tension câble benne M2 sous l'eau (mou de câble détecté par la roulette palpeuse).",
    "action_conducteur": "🕹️ Passer en manuel dérogation au pupitre : retendre doucement le câble M2.",
    "action_maintenance": "🧰 Vérifier mécanique bras palpeur anti-mou sur tambour M2 et propreté de l'interrupteur.",
    "points_test": "Local_Digital_IO · Borne %IX0.4 (M2_TensionedCable_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu câble tendu : 24V (Contact NC fermé)"
  },
  "ALM_057": {
    "cause_racine": "⚠️ Anomalie de vitesse treuils pendant la phase de plongée (dérive d'accélération sous l'eau).",
    "action_conducteur": "🕹️ Ramener commandes au neutre au pupitre. Laisser la charge se stabiliser.",
    "action_maintenance": "🧰 Contrôler régularité vitesse codeurs M1 et M2 en plongée.",
    "points_test": "Codeurs COD1/COD2 ➔ Dérivée d(Speed_Mps)/dt en plongée ➔ Attendu : Accélération stable dans le gabarit défini"
  },
  "ALM_058": {
    "cause_racine": "⚙️ Configuration de plongée invalide (paramètres altimétriques immersion / fond incohérents).",
    "action_conducteur": "🛑 Cycle semi-auto refusé. Relever paramètres IHM au pupitre.",
    "action_maintenance": "💻 Vérifier cohérence paramètres cycle plongée sur le superviseur.",
    "points_test": "IHM Recettes Dragage ➔ Variables GVL_IHM.CycleSemiAuto.Cfg ➔ Attendu : Cohérence altimétrique Fond < Immersion < Crête"
  },
  "ALM_059": {
    "cause_racine": "🌊 Défaut contact fond pendant la phase d'extraction des matériaux.",
    "action_conducteur": "🕹️ Repasser en manuel au pupitre. Vérifier tension des câbles.",
    "action_maintenance": "🧰 Contrôler capteur de fond et seuil d'effort sur treuils.",
    "points_test": "Local_Digital_IO · Borne %IX0.5 (KoboldBottomTouch_DI) ➔ Mesure : 24Vcc entre borne et 0V carte ➔ Attendu : 24V au fond"
  },
  "ALM_060": {
    "cause_racine": "🪣 Défaut fermeture benne pendant l'extraction (benne n'atteignant pas l'état fermé sous l'eau).",
    "action_conducteur": "🕹️ Repasser en commande manuelle benne M2 pour forcer la fermeture au pupitre.",
    "action_maintenance": "🧰 Contrôler absence d'enrochement coincé dans les mâchoires de la benne.",
    "points_test": "Supervision IHM ➔ Variable _BucketState.IsClosed ➔ Attendu : Confirmation TRUE sous 60s max"
  },
  "ALM_061": {
    "cause_racine": "⏱️ Défaut contrôle vitesse montée lors de l'extraction initiale (distance de contrôle non franchie).",
    "action_conducteur": "🕹️ Ramener manipulateur au neutre au pupitre.",
    "action_maintenance": "🧰 Vérifier passage au palier 1 pendant la traversée de la zone ExtractionControlDistance_M.",
    "points_test": "Contacteurs Paliers Vitesse ➔ Relais palier 1 KM_P1 (%QX27.4) ➔ Attendu : Enclenchement exclusif du Palier 1 dans zone décollement"
  },
  "ALM_062": {
    "cause_racine": "⚙️ Configuration extraction cycle automatique invalide.",
    "action_conducteur": "🛑 Bloquer cycle auto au pupitre.",
    "action_maintenance": "💻 Revoir paramètres de la phase extraction sur l'écran IHM.",
    "points_test": "IHM Recettes Dragage ➔ Variables GVL_IHM.CycleSemiAuto.Cfg ➔ Attendu : Cohérence paramètres d'extraction"
  },

  # FAMILLE 5 : SÉCURITÉ MACHINE & CHAÎNE D'URGENCE (ALM_063 à ALM_065)
  "ALM_063": {
    "cause_racine": "🚨 Discordance redondance contacteurs de puissance ligne ou relais de sécurité AU (contact miroir non retombé).",
    "action_conducteur": "🛑 COUPURE GÉNÉRALE. Frapper coup de poing Arrêt d'Urgence pupitre. Condamner le poste de conduite.",
    "action_maintenance": "⚠️ DANGER DE MORT 400V : Consigner la source quai/groupe + VAT. Contrôler les contacts miroirs NC du contacteur de ligne KM_Power et blocs auxiliaires de sécurité.",
    "points_test": "VH_0800END · Bornes %IX225.6 et %IX225.7 ➔ Mesure : 24Vcc / 0V entre bornes et 0V carte ➔ Attendu réarmé : 24Vcc sur les deux voies"
  },
  "ALM_064": {
    "cause_racine": "🚨 Échec confirmation armement puissance (le contacteur de ligne ne s'enclenche pas sous 2s après commande).",
    "action_conducteur": "🛑 Relâcher le bouton Réarmement. Vérifier que tous les AU sont déverrouillés au pupitre.",
    "action_maintenance": "🧰 Armoire : vérifier bobine contacteur ligne KM_Power, fusible commande 24V et module sécurité AU.",
    "points_test": "VH_0008ER_1 · Relais %QX28.6/%QX28.7 (PowerKeepAlive) ➔ Mesure : 24Vcc sur bobine KM_Power ➔ Attendu : 24Vcc après appui réarmement"
  },
  "ALM_065": {
    "cause_racine": "🚨 Échec autotest démarrage chaîne d'urgence (défaut de retombée d'un canal lors du test d'initialisation).",
    "action_conducteur": "🛑 Redémarrage puissance refusé. Condamner le pupitre de commande.",
    "action_maintenance": "🧰 Contrôler les contacts de recopie de tous les relais de sécurité en armoire électrique.",
    "points_test": "Bloc Sécurité FB_Safety_EmergencyManagement ➔ Contrôle retombée des canaux d'urgence ➔ Attendu : 0V strict sur toutes les lignes avant réarmement"
  },

  # FAMILLE 6 : SUPERVISION CYCLE & PROCESS (ALM_066 à ALM_071)
  "ALM_066": {
    "cause_racine": "🛑 Profondeur limite légale atteinte en cycle automatique (arrêt fond de fouille autorisé).",
    "action_conducteur": "🕹️ Inverser les commandes au pupitre pour remonter la benne. Ne pas descendre plus bas.",
    "action_maintenance": "💻 Vérifier valeur de la limite légale autorisée sur l'écran réglages IHM.",
    "points_test": "IHM Configuration Cycle ➔ Variable CablePosM1 vs LimitLegalDepthMinAllowed_M ➔ Attendu : CablePosM1 supérieur à la limite légale"
  },
  "ALM_067": {
    "cause_racine": "⚠️ Défaut de synchronisation des treuils en cours de cycle automatique.",
    "action_conducteur": "🕹️ Stopper le cycle semi-auto au pupitre. Repasser en manuel.",
    "action_maintenance": "🧰 Contrôler équilibrage de charge et vitesses relatives M1/M2.",
    "points_test": "Supervision Cycle ➔ Mot CycleErrorId bit 1 ➔ Attendu : Écart M1/M2 dans le gabarit cycle semi-auto"
  },
  "ALM_068": {
    "cause_racine": "⚠️ Écart codeurs excessif constaté pendant la phase de remontée de charge.",
    "action_conducteur": "🕹️ Ramener commandes au neutre au pupitre. Vérifier assiette benne.",
    "action_maintenance": "🧰 Contrôler absence de glissement mécanique sur l'un des deux tambours de treuil.",
    "points_test": "Codeurs COD1/COD2 ➔ Mot CycleErrorId bit 3 ➔ Attendu : Écart codeurs en montée inférieur au seuil critique"
  },
  "ALM_069": {
    "cause_racine": "⚠️ Écart de vitesse confirmé entre treuils M1 et M2 en déplacement couplé.",
    "action_conducteur": "🕹️ Mettre les manipulateurs au neutre au pupitre de commande.",
    "action_maintenance": "🧰 Contrôler contacteurs de paliers de vitesse en armoire (KM_P1 à KM_P5).",
    "points_test": "Supervision Moteurs ➔ Mot CycleErrorId bit 4 ➔ Attendu : Concordance des vitesses treuils en marche couplée"
  },
  "ALM_070": {
    "cause_racine": "📡 Perte de communication avec le pupitre IHM pendant le déroulement d'un cycle automatique.",
    "action_conducteur": "🛑 Le cycle s'interrompt en sécurité. Vérifier l'écran IHM au poste de conduite.",
    "action_maintenance": "🧰 Contrôler câble réseau Ethernet blindé et switch réseau armoire.",
    "points_test": "Liaison Ethernet IHM ➔ Mot CycleErrorId bit 5 ➔ Attendu : HeartbeatIhmOk maintenu actif en continu"
  },
  "ALM_071": {
    "cause_racine": "⏱️ Timeout d'étape cycle automatique : l'étape active du cycle a dépassé sa durée maximale allouée.",
    "action_conducteur": "🕹️ Repasser en mode Manuel au pupitre de commande. Dégager la machine si nécessaire.",
    "action_maintenance": "💻 Contrôler le numéro d'étape bloquée E_AutoCycleStep sur la page de supervision.",
    "points_test": "FB_CycleSemiAuto ➔ Temporisateur d'étape active ➔ Attendu : Transition d'étape accomplie avant expiration timeout"
  },
}

# Fusion des deux dictionnaires
kb_data.update(active_alarms_kb)

output_file = Path(__file__).resolve().parent / "knowledge_base.json"
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(kb_data, f, indent=2, ensure_ascii=False)

print(f"✅ knowledge_base.json généré avec succès ! Total entrées : {len(kb_data)}")
