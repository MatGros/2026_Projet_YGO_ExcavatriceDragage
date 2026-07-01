# 📋 Analyse Fonctionnelle — Partie 1 : Présentation & Fonctions (v1.1)

> Projet : **Excavatrice de dragage** — Automate CODESYS 3.5
> Périmètre : automatisme + analyse fonctionnelle (IHM hors scope)
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

## 🪜 Paliers de vitesse (nouveau principe — masque 4 bits)

Chaque treuil dispose de **4 contacteurs de vitesse**. La vitesse se construit en **5 paliers**.

- ❌ **Ancien** : palier N ⇒ N contacteurs (cumul figé : 1, 2, 3, 4).
- ✅ **Nouveau** : chaque palier porte un **masque de 4 bits** ⇒ on choisit **librement** quels contacteurs sont actifs (`bit0..bit3`).
- 🎛️ **Table indépendante par treuil** (M1 et M2 ont chacun leurs 5 masques).
- 🧭 L'ordre d'actionnement n'est plus implicite : il est **explicitement défini dans la table** de masques.

> Décodage assuré par `FB_SpeedStep` (voir Partie 2).

---

## 🧱 Fonctions principales (objets)

- 🕹️ **Joystick** → traduit le geste opérateur en consigne.
- 🪝 **Treuil** ×2 → cœur métier : direction, vitesse, frein, position, limites.
- ↔️ **Translation** → amène le pont sur la bonne position.
- 🪣 **Godet** → ouvre/ferme via désynchro des treuils.
- 🔄 **Cycle** → enchaîne les étapes en semi-auto.
- 🎚️ **Modes** → Manuel / Maint N1 / N2 / Auto + autorisations.

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
Joystick ──consigne %──► Cycle/Modes ──ordre──► Treuil + Translation
Codeur ──position m──► Treuil ──limite──► ralentit/arrête
Treuil ──pilote──► Frein + Contacteurs
Safety ──CoupeEnable──► PLC_PRG_MAIN retire les Enable ──► objets en repli sûr
Safety ──PowerCutOff──► contacteur général amont (si collage détecté)
```

🧭 **Tout passe par Modes + Safety avant d'agir.** L'arrêt sûr logiciel = **retrait de l'`Enable`**
(`CoupeEnable`), pas un `SafeStop` propagé. Voir Partie 2 v2.4 §6 et Partie 3 §7.

---

## 🛡️ Sécurité (priorité absolue)
- Cohérence capteurs, valeurs absurdes, conditions de marche.
- 🪝 Frein = séquence stricte intégrant les temps physiques (relâche après établissement moteur, colle après décélération — voir Partie 4 §Frein).
- 🔴 Tout défaut process → `FB_Safety` lève `CoupeEnable` → retrait des `Enable` → arrêt **sûr propre** (contacteurs off, freins collés). Voir Partie 2 v2.4 §6.

> 🚫 **Limite légale ≠ sécurité** : l'interdiction de draguer sous une cote imposée est une
> **interdiction normale** (réglementaire), appliquée par **`FB_Modes`** en semi-auto/descente,
> **pas** par `FB_Safety`. Signalisation seule en maintenance. Voir Partie 6 §3.

### 🔌 Sécurité électrique — automate jamais coupé
L'automate **reste alimenté en permanence** (pas de coupure électrique générale du contrôleur).
Conséquence : la mise en sécurité ne peut pas compter sur l'extinction de l'API. Il faut une **chaîne de coupure puissance pilotée + surveillée** :
- Chaque contacteur de puissance possède un **retour d'état** (contact auxiliaire) lu en entrée.
- `FB_Safety` compare en permanence **commande vs retour**.
- Si l'API commande l'ouverture (arrêt moteur) mais que le contacteur **reste collé** (retour incohérent) → `FB_Safety` lève une **sortie de coupure puissance** dédiée qui **coupe électriquement** la puissance en amont.

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
3. Mode maintenance → preset codeurs à une **valeur positive**.
4. Affichage 0 m ; ⬆️ enroulé = +m, ⬇️ sous l'eau = −m.
