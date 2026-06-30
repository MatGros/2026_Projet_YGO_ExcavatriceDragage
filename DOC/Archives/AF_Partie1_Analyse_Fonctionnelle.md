# 📋 Analyse Fonctionnelle — Partie 1 : Présentation & Fonctions

> Projet : **Excavatrice de dragage** — Automate CODESYS 3.5
> Périmètre : automatisme + analyse fonctionnelle (IHM hors scope)

---

## 🎯 Le projet en bref
Machine de **dragage en carrière noyée**.
Un godet descend sous l'eau, mord le fond, remonte plein, se déplace, vide.
Mon périmètre : **automatisme + analyse fonctionnelle** (IHM hors scope).

---

## 🔧 Équipements pilotés

| Axe | Matériel | Pilotage |
|-----|----------|----------|
| 🪝 Plongée/Extraction | 2 treuils identiques | 2 contacteurs sens + 2×4 contacteurs vitesse (5 paliers) |
| 🧲 Position câble | 2 codeurs absolus tambour | EtherCAT → déroulé en **mètres** |
| 🛑 Maintien charge | 2 freins manque-courant | Logique levage (frein colle au repos) |
| ↔️ Translation | 1 moteur sur variateur | EtherCAT, commande **vitesse %** |
| 🪣 Godet | (= désynchro des 2 treuils) | Pas de moteur propre |
| 🕹️ Commande | Joystick Hall → CANopen | 2 axes + bouton |
| 📡 Capteurs | Fond touché, fdc haut/bas, positions travail/vidange/maintenance | TOR + position |

---

## 🧱 Fonctions principales (objets)

- 🕹️ **Joystick** → traduit le geste opérateur en consigne.
- 🪝 **Treuil** ×2 → cœur métier : direction, vitesse, frein, position, limites.
- ↔️ **Translation** → amène le pont sur la bonne position.
- 🪣 **Godet** → ouvre/ferme via désynchro des treuils.
- 🔄 **Cycle** → enchaîne les étapes en semi-auto.
- 🎚️ **Modes** → Manuel / Maint N1 / N2 / Auto + autorisations.

---

## 🧩 Fonctions appelées (briques)

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
Safety ──SafeStop──► TOUS les objets
```

🧭 **Tout passe par Modes + Safety avant d'agir.**

---

## 🛡️ Sécurité (priorité absolue)
- Cohérence capteurs, valeurs absurdes, conditions de marche.
- 🪝 Frein = séquence stricte (relâche après moteur, colle avant arrêt).
- 🚫 **Limite légale** : interdiction de draguer sous une cote imposée.
- 🔴 Tout défaut → arrêt **sûr** (contacteurs off, freins collés).

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
