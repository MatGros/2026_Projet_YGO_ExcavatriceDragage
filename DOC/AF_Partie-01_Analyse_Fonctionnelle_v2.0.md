# Analyse Fonctionnelle - Partie 1 : Presentation et Fonctions (v2.0)

> Projet : Excavatrice de dragage - Automate CODESYS 3.5.
> Role : presenter la machine, ses fonctions et son modele de securite electrique.
> Perimetre : automatisme et contrat PLC-IHM ; graphisme et ergonomie IHM hors perimetre.
> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🧭 Sommaire rapide

1. Equipements principaux
2. Fonctions metier et transverses
3. Finalite operationnelle
4. Modele de commande et d'arret
5. Securite electrique et rearmement
6. Position et referencement
7. Responsabilites documentaires

## 🧪 Points de validation

Catalogue unique `TC-P01-*` : [`AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md`](AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md).
Cette partie ne duplique pas le tableau.

| Niveau machine (rappel) | Type |
|---|---|
| AU physique coupe moteurs/actionneurs ; automate reste vivant | SITE |
| Pas d'auto-rearmement ; acquittement defaut ≠ rearmement contacteur | SITE |
| Redondance A/B : auto-test integre au rearmement (un canal a la fois) + preuve cablage site | AUTO_PLC + SITE |

---

## 🏗️ 1. Equipements principaux

| Element | Role machine |
|---|---|
| 🪝 Treuil M1 | Levage/retenue, codeur absolu COD1, frein manque-courant. |
| 🪝 Treuil M2 | Levage/benne, codeur absolu COD2, frein manque-courant. |
| ↔️ Translation M3 | Deplace le chariot/pont ; variateur AC600 sur EtherCAT et frein manque-courant. |
| 🪣 Benne | Sans moteur propre : ouverture/fermeture par desynchronisation commandee de M1/M2. |
| 🕹️ Joystick Hall | Commande operateur CANopen, avec homme-mort. |
| ⚡ Contacteur puissance | Autorise ou coupe l'energie des moteurs et actionneurs ; il ne coupe pas l'automate. |

Chaque treuil utilise deux contacteurs de sens et quatre contacteurs de vitesse. Les cinq paliers
resultent d'une table de masques propre a chaque treuil. Le detail des tables, des mouvements et

---

## 🧩 2. Fonctions

### 🎯 Fonctions metier

| Fonction | Responsabilite |
|---|---|
| 🕹️ Joystick | Produit les demandes de mouvement : marche, direction et vitesse. Les modes et etats autorises determinent l'equipement effectivement commande. |
| 🪝 Treuils | Executent le mouvement, les paliers, le freinage, les limites et les retours de position. |
| ↔️ Translation | Execute le mouvement M3 et le positionnement du chariot/pont. |
| 🪣 Benne | Ordonne la desynchronisation M1/M2 necessaire a son ouverture ou sa fermeture. |
| 🎚️ Modes | Arbitre les droits de marche et les sources de commande. |
| 🔄 Cycle semi-automatique | Orchestre une sequence de production a partir des fonctions disponibles. |

### 🔧 Fonctions transverses

| Fonction | Responsabilite |
|---|---|
| 🖥️ Interface PLC-IHM | Expose des structures d'echange typees pour commandes autorisees, reglages, mesures, diagnostics et etats. |
| 💬 Information operateur | Fournit les etats de la machine et les informations d'action attendue. La presentation, la priorisation et le format des messages sont specifies par la Partie 07. |
| 🧪 Simulation | Permet les essais hors ligne et sans materiel, avec selection explicite des sources reelles ou simulees par domaine. |
| 📡 Diagnostic devices | Surveille les devices et bus requis pour une marche sure ; les pertes pertinentes sont transmises aux protections et aux modes. |
| 🛡️ Safety | Surveille les conditions dangereuses de mouvement et demande soit un arret rapide, soit une coupure de puissance selon le risque. |

---

## 🔄 3. Finalite operationnelle

La machine descend la benne, realise le prelevement, remonte la charge, la deplace vers une zone

Les modes maintenance permettent les manoeuvres necessaires hors cycle, dans les autorisations

---

## 🛑 4. Modele de commande et d'arret

| Niveau | Condition | Effet |
|---|---|---|
| 🟢 Marche et arret normal | `Enable=TRUE`, pas de `SafeStop` ; `StartStop` pilote la demande | Acceleration ou deceleration normale. |
| 🟠 Arret rapide logiciel | `SafeStop=TRUE`, `Enable=TRUE` | Deceleration rapide du mouvement ; le FB reste actif jusqu'a l'arret. |
| ⚪ Neutralisation | `Enable=FALSE` ou contacteur puissance non confirme | Sorties du FB neutralisees. |
| 🔴 Coupure de puissance | AU physique, perte du maintien PLC ou demande safety majeure | Coupure materielle de l'energie des moteurs et actionneurs. |

Precedence obligatoire : `Enable` > `SafeStop` > `StartStop`.

Le frein est a manque-courant. Sa commande doit respecter les conditions physiques de desserrage et

La limite legale de profondeur est une interdiction d'exploitation geree par les modes ; elle n'est
pas, a elle seule, une fonction safety.

---

## ⚡ 5. Securite electrique et rearmement

> Detail FB, interfaces, sequence, polarites, IHM, sim et `TC-P01-*` :
> [`AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md`](AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md).

### 🧱 5.1 Principe

L'automate reste alimente. Une boucle materielle coupe le contacteur general de puissance des
moteurs et actionneurs. Cette boucle comprend les boutons d'arret d'urgence physiques et deux
canaux relais pilotes par le PLC. L'absence de maintien de l'un des canaux PLC doit ouvrir la
boucle : perte d'alimentation PLC, arret du programme ou depassement watchdog conduit donc a la
coupure de puissance.

| Role machine | Sens |
|---|---|
| Retour boucle AU | Boucle physique fermee ; precondition a l'armement — pas le portail mouvement. |
| Retour contacteur | Contacteur reellement engage ; portail maitre `PowerContactorEngaged` des mouvements. |
| Canaux maintien A/B | Deux voies PLC fail-safe : maintien actif a l'etat sain, ouverture = coupure. |
| Impulsion rearmement | Commande explicite operateur ; jamais d'auto-rearmement sur seule boucle saine. |

Une boucle AU saine ne prouve pas que la puissance est presente : apres coupure, la boucle peut
etre saine alors que le contacteur reste ouvert.

Implementation : un seul composite `FB_Safety_EmergencyManagement` en chaine sortie
(`PRG_OUTPUTS_LD`). Les safety metier (M1/M2/M3) **demandent** la coupure ; ce FB **execute**
la chaine electrique.

### 🧨 5.2 Sources de coupure

| Source | Effet |
|---|---|
| AU physique | Coupure materielle independante du PLC. |
| Perte maintien PLC / watchdog | Retombee des canaux A/B → coupure. |
| Demande safety domaine (treuil, translation) | Coupure via canaux PLC ; seuils proprietaires Parties 09/11. |
| Coupure IHM explicite | Ouverture des canaux PLC (detail FB). |

La benne n'a pas de safety dedie : couche 1 Benne (P12), escalade possible via safety M1 (P09).

### 🔁 5.3 Rearmement (regles machine)

- Jamais automatique.
- Front commande operateur seulement.
- Preconditions : boucle saine, contacteur non engage, pas de sequence/verrouillage actif.
- Auto-test des deux voies avant impulsion ; confirmation contacteur apres impulsion.
- Acquittement d'un defaut metier et rearmement du contacteur = **deux actions distinctes**.

Temporisations, etapes, latches, Reset conditionnel : **spec FB** (pas recopies ici).

### 🧑‍🔧 5.4 Actions operateur

| Situation | Action operateur |
|---|---|
| Demarrage froid / AU relache, contacteur ouvert | Demander le rearmement. |
| AU physique appuye | Relacher l'AU puis rearmer. |
| Coupure safety metier | Traiter et acquitter le defaut domaine, puis rearmer. |
| Perte PLC | Retablir le PLC puis rearmer. |
| Echec auto-test voies | Diagnostiquer la voie, puis acquitter, puis rearmer. |
| Contacteur non engage apres impulsion | Diagnostiquer le contacteur (regles Reset : spec FB). |

La redondance electrique se prouve par le cablage et un essai canal par canal, pas par deux
sorties logiques identiques.

---

## 📏 6. Position et referencement

Les codeurs absolus mesurent position et vitesse des cables. Ils servent a l'information de
profondeur/altimetrie, aux limites, au synchronisme M1/M2, aux protections de mouvement et aux
etats mecaniques deduits, dont certains etats de benne.

Le plan de reference affiche est le toucher eau : `0 m`. Le preset brut des codeurs reste positif
et est distinct de l'affichage. L'enroulement/remontee est positif ; la descente sous l'eau est
negative. Le processus de homing est specifie par la Partie 10.

---

## 📚 7. Responsabilites documentaires

| Sujet | Document proprietaire |
|---|---|
| Chaine electrique AU — regles machine (§5) | **Cette partie** |
| `FB_Safety_EmergencyManagement` + `TC-P01-*` | [`AF_Partie-01_FB_Safety_EmergencyManagement_v1.0`](AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md) |
| Architecture, taches et flux | Partie 02 |
| Contrats FB / DUT | Partie 03 |
| Cycle semi-automatique | Partie 04 |
| Modes et droits | Partie 05 |
| Conditionnement E/S | Partie 06 |
| Contrat PLC-IHM | Partie 07 |
| Joystick · Treuils · Codeurs · Translation · Benne · Sim · TS | Parties 08–14 |

Les autres parties renvoient a §5 pour le **role machine** et a la spec FB pour
**l'implementation et les tests**, sans recopier ni l'un ni l'autre.
