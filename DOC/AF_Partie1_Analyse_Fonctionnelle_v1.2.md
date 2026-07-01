# 📋 Analyse Fonctionnelle — Partie 1 : Présentation & Fonctions (v1.2)

> Projet : **Excavatrice de dragage** — Automate CODESYS 3.5
> Périmètre : automatisme + analyse fonctionnelle (IHM hors scope)
> **v1.2** — Suite audit documentaire : suppression `CoupeEnable` (n'a jamais existé comme
> variable), modèle d'arrêt `SafeStop`/`StartStop` (voir Partie 3 v1.2), `SafeStop` **par métier**
> (pas de signal global), clarification séquence d'initialisation codeurs.
> **v1.1** — Mapping physique M1/M2/M3, paliers vitesse à masque 4 bits, sécurité électrique (automate jamais coupé).

---

## 🎯 Le projet en bref
Machine de **dragage en carrière noyée**.
Un godet descend sous l'eau, mord le fond, remonte plein, se déplace, vide.
Mon périmètre : **automatisme + analyse fonctionnelle** (IHM hors scope).

---

## 🗺️ Mapping physique des axes (référence projet)

| Axe | Repère | Équipement | Bus | Codeur |
|-----|--------|-----------|-----|--------|
| 🪝 Treuil 1 | **M1** | Moteur treuil levage 1 | — | **COD1** (codeur absolu tambour M1, EtherCAT) |
| 🪝 Treuil 2 | **M2** | Moteur treuil levage 2 | — | **COD2** (codeur absolu tambour M2, EtherCAT) |
| ↔️ Translation | **M3** | Variateur **AC600** axe transversal | EtherCAT | — (consigne vitesse %) |

🧭 **Règle de lecture** : `COD1` ⇒ codeur du treuil **M1**, `COD2` ⇒ codeur du treuil **M2**, `AC600` ⇒ variateur de l'axe transversal **M3**.

---

## 🔧 Équipements pilotés

| Axe | Matériel | Pilotage |
|-----|----------|----------|
| 🪝 Plongée/Extraction | 2 treuils identiques (M1, M2) | 2 contacteurs sens + **2×4 contacteurs vitesse** (5 paliers, masque 4 bits/palier) |
| 🧲 Position câble | 2 codeurs absolus tambour (COD1→M1, COD2→M2) | EtherCAT → déroulé en **mètres** |
| 🛑 Maintien charge | 2 freins manque-courant | Logique levage (frein colle au repos) |
| ↔️ Translation | 1 moteur sur variateur AC600 (M3) | EtherCAT, commande **vitesse %** |
| 🪣 Godet | (= désynchro des 2 treuils) | Pas de moteur propre |
| 🕹️ Commande | Joystick Hall → CANopen | 2 axes + bouton |
| 📡 Capteurs | Fond touché, fdc haut/bas, positions travail/vidange/maintenance | TOR + position |
| 🔌 Retour contacteurs | Contact auxiliaire par contacteur de puissance | TOR → surveillance collage |

---

## 🪜 Paliers de vitesse (masque 4 bits)

Chaque treuil dispose de **4 contacteurs de vitesse**. La vitesse se construit en **5 paliers**.

- Chaque palier porte un **masque de 4 bits** ⇒ on choisit **librement** quels contacteurs sont actifs (`bit0..bit3`).
- 🎛️ **Table indépendante par treuil** (M1 et M2 ont chacun leurs 5 masques).
- 🧭 L'ordre d'actionnement n'est pas implicite : il est **explicitement défini dans la table** de masques.

> Décodage assuré par `FB_SpeedStep` (voir Partie 2).

---

## 🧱 Fonctions principales (objets)

- 🕹️ **Joystick** → traduit le geste opérateur en consigne.
- 🪝 **Treuil** ×2 → cœur métier : direction, vitesse, frein, position, limites.
- ↔️ **Translation** → amène le pont sur la bonne position.
- 🪣 **Godet** → ouvre/ferme via désynchro des treuils.
- 🔄 **Cycle** → enchaîne les étapes en semi-auto.
- 🎚️ **Modes** → Manuel / Maint N1 / N2 / Semi-auto + autorisations.

---

## 🧩 Fonctions appelées (briques — RÉUTILISER l'existant)

⚠️ **Règle** : ne **jamais réimplémenter** une brique déjà fournie par CODESYS. Composer avec les librairies standard (notamment **Util**).

- 📐 Scaling → `LIN_TRAFO` (pts↔m, %↔variateur, analogiques).
- 📈 Rampes → `RAMP_REAL` (anti-à-coups).
- 🎛️ Régulation arrêt → `PID_FIXCYCLE`.
- 🪜 Paliers vitesse → `HYSTERESIS`.
- 🚧 Bornes/limites → `LIMITALARM`.
- 🧲 Codeur éclaté → Lecture / Mise à l'échelle / **Référencement** / Diag.

---

## 🔗 Interactions (flux de données)

```
Joystick ──consigne %──► Cycle/Modes ──StartStop──► Treuil + Translation
Codeur ──position m──► Treuil ──limite──► ralentit/arrête
Treuil ──pilote──► Frein + Contacteurs
Safety métier (par domaine) ──SafeStop──► FB de mouvement concerné ──► rampe décélération RAPIDE (Enable maintenu)
Safety ──PowerCutOff──► contacteur général amont (si collage détecté)
```

🧭 **Tout passe par Modes + Safety avant d'agir.** L'arrêt sûr logiciel = **`SafeStop`** (sortie
d'un bloc safety **métier**, une par domaine) reçu en entrée par le(s) FB de mouvement concerné(s)
→ **rampe de décélération rapide**, le FB restant `Enable`. `Enable = FALSE` reste un mécanisme
**distinct** : neutralisation complète (coupure des sorties du FB). Voir Partie 2 v2.5 §6 et
Partie 3 v1.2 §1/§7.

---

## 🛡️ Sécurité (priorité absolue)
- Cohérence capteurs, valeurs absurdes, conditions de marche.
- 🪝 Frein = séquence stricte intégrant les temps physiques (relâche après établissement moteur, colle après décélération — voir Partie 4 §Frein).
- 🔴 Tout défaut process détecté par un bloc safety métier → il lève **son** `SafeStop` → le(s) FB de mouvement concerné(s) passent en **rampe de décélération rapide** (`Enable` maintenu), puis freins collés. Voir Partie 2 v2.5 §6.

> 🚫 **Limite légale ≠ sécurité** : l'interdiction de draguer sous une cote imposée est une
> **interdiction normale** (réglementaire), appliquée par **`FB_Modes`** en semi-auto/descente,
> **pas** par un bloc safety. Signalisation seule en maintenance. Voir Partie 6 §3.

### 🔌 Sécurité électrique — automate jamais coupé
L'automate **reste alimenté en permanence** (pas de coupure électrique générale du contrôleur).
Seul l'**arrêt d'urgence physique** (bouton coup-de-poing ou câble mécanique de position haute
extrême) **coupe brutalement la puissance** via un gros contacteur ; l'automate continue de
surveiller en permanence (il dispose d'une **info « machine en AU »**, voir Partie 3 §1
`EmergencyStopOk`). Conséquence pour le logiciel :
- Chaque contacteur de puissance possède un **retour d'état** (contact auxiliaire) lu en entrée.
- Le bloc safety concerné compare en permanence **commande vs retour**.
- Si l'API commande l'ouverture (arrêt moteur) mais que le contacteur **reste collé** (retour incohérent) → une **sortie de coupure puissance** dédiée (`PowerCutOff`) **coupe électriquement** la puissance en amont.

---

## 🔄 Cycle type (semi-auto)

1. ⬇️ Descente godet ouvert → 🌊 capteur **fond touché**.
2. 🔧 Synchro 2 treuils + recalage (petite vitesse).
3. ⬆️ Accélération → remontée godet plein.
4. ⏱️ Temps d'égouttage en haut.
5. ↔️ Translation vers zone de vidange.
6. ⬇️ Descente + 🪣 ouverture godet (désynchro).
7. 🔁 Retour position travail.

⚠️ Cycle = **indicatif**, pas figé.

---

## 🧭 Initialisation (référencement codeurs)
1. Descente 2 treuils synchro, godet ouvert.
2. 🌊 Toucher l'eau = **plan 0**.
3. Mode maintenance → preset codeurs à une **valeur positive** (offset brut choisi assez grand
   pour que la position mesurée ne devienne jamais négative en usage normal — c'est une valeur
   **interne** au codeur, pas ce qui est affiché).
4. Affichage 0 m à ce plan de référence (l'échelle **affichée** est recalée à 0, indépendamment
   de l'offset brut du point 3) ; ⬆️ enroulé = +m, ⬇️ sous l'eau = −m.

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (orchestration, flux `SafeStop`/`StartStop`, `PowerCutOff`).
- **Partie 3 v1.2** — Contrat FB : interface (`Enable/Reset/EmergencyStopOk/Mode`), `StartStop`, `SafeStop`.
- **Partie 4** — Cycle & séquenceur.
- **Partie 5** — Modes & maintenance : limite légale (`FB_Modes`).
- **Partie 6** — Conditionnement E/S.
