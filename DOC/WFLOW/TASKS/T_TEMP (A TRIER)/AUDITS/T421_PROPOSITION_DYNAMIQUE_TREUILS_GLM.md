# 🧭 Étude de Conception — Glissement inertiel Treuils M1/M2 & Benne (T421)

> ⚠️ **Consultation pure** : aucun fichier modifié, aucun gate à exécuter. Restitution ci-dessous = conception à valider avant toute écriture.

---

## 0. ⚡ TL;DR décisionnel

| # | Décision proposée |
|---|---|
| 1 | ❌ **Abandonner la réserve de points** (`CoastDistanceM`) : anti-pattern → remplacer par un **modèle d'état** (`v`, `dir`) intégré chaque cycle |
| 2 | ✅ Calcul **dans `FB_Sim_Encoder`**, jamais piloté depuis `FB_SimBench` (producteur unique du comptage) |
| 3 | ✅ Décélération **constante par sens** : `1.20 m/s²` montée / `0.93 m/s²` descente (calée sur les 2 mesures pleine vitesse) + `v0`-proportionnel par construction (`d = v0²/2a`) |
| 4 | ✅ Benne : **aucun modèle séparé, aucune référence AX15B** — l'inertie d'ouverture **émerge** du coast des 2 treuils |
| 5 | ⚠️ 2 données manquantes pour la calibration fine (§7) |

**Aberration actuelle démontrée :**

| Grandeur | Réel (Suivi_86) | Actuel (réserve 1.30 m @ palier 1) | Modèle d'état proposé |
|---|---|---|---|
| Glissement montée pleine v. | 0.543 m | 1.30 m (**×2.4**) | 0.543 m |
| Glissement descente | 1.205 m | 1.30 m | 1.205 m |
| Glissement jog | 0.021 m | 1.30 m (**×60 !**) | ~0.006 m |
| Vitesse à la coupure | continue | **saut 1.14 → 0.12 m/s** | continue ✅ |
| Durée du glissement | 0.65–1.06 s | ~10.8 s | 0.95–1.61 s |

---

## 1. 📐 Loi de décélération — analyse des mesures

**Calibration sur les distances** (seule mesure fiable : la durée "mesurée" est un *arrêt apparent* du codeur, cf. hypothèse §7) :

```text
d = v0² / (2·a_sens)         a_montée  = 1.14²/(2·0.543)  ≈ 1.20 m/s²
                             a_descente = 1.50²/(2·1.205) ≈ 0.93 m/s²
```

**La dissymétrie montée/descente est purement gravitaire** : en montée le poids s'ajoute aux pertes (freinage fort, 1.20), en descente il s'y retranche (freinage faible, 0.93). Aucun besoin d'un coefficient "sens" ad hoc : **une seule gravité équivalente + pertes** suffisent conceptuellement ; pour l'implémentation, les 2 constantes calibrées sont plus simple et identiquement fidèles.

**Proportionnalité à la vitesse : garantie par la forme, pas par un calcul auxiliaire.** Avec le modèle d'état, `d = v0²/(2a)` à chaque coupure :
- jog à 0.12 m/s → **6 mm** (mesuré 21 mm → écart ~15 mm, tous deux "quasi-instantané", dans le bruit du banc) ;
- 10× plus lent → 100× plus court. ✅ Aucun palier figé.

**Rigueur méthodo (devoir d'alerte)** : 3 mesures scalaires identifient **exactement** le modèle à décél constante par sens, et rien de plus. Un modèle physique plus riche `a(v) = a0 + k·|v| + s·G_eq` (pertes croissant avec la vitesse — comportement moteur) est **sous-identifié avec 3 scalaires** et donne des distances intégrées divergentes selon le jeu de coefficients (0.46 à 0.54 m en montée). C'est le lot **V2**, à caler uniquement sur les **courbes brutes** scan par scan, pas sur ces 3 nombres.

| | V1 (recommandée) | V2 (optionnelle) |
|---|---|---|
| Modèle | `a` constant par sens + `tcut` réglable | `a = a0 + k·|v| + s·G_eq` |
| Paramètres | 2 constants + 1 temps mort | 4 coeffes à régresser |
| Collage | montée/descente exactes, jog −15 mm | à déterminer sur courbes |
| Verdict | ✅ **livrable dès maintenant** | ⏳ après régression Suivi_86 |

---

## 2. 🤔 Réponse aux 4 questions

### Q1 — Où vit le calcul ? → **Dans `FB_Sim_Encoder`, en modèle d'état**

Piloter depuis `FB_SimBench` obligerait le banc à lire la vitesse/direction **internes** de chaque encodeur : rupture d'encapsulation (producteur unique du comptage = l'encodeur), duplication d'état, et impossibilité de paramétrer M1 ≠ M2 demain. Le banc ne **surcharge** rien par défaut : les défauts calibrés vivent dans le FB. `SimWinchCoast_M` (1.30 m en dur) → **supprimé, pas remplacé** (aucune constante en dur au banc).

**Structure du modèle d'état (remplace la réserve de points) :**

```iecst
(* --- FB_Sim_Encoder : ajouts --- *)
VAR_INPUT
    CoastDecelUp_Mps2     : REAL := 1.20;  (* calibre : mesure montée 1.14 m/s *)
    CoastDecelDown_Mps2   : REAL := 0.93;  (* calibre : mesure descente 1.50 m/s *)
    CoastCutTimeS         : REAL := 0.0;   (* temps mort contacteur, réglable *)
    MechanicStopEngaged   : BOOL;          (* butée mécanique benne/crochet *)
END_VAR
VAR_OUTPUT
    CoastActive           : BOOL;          (* observation / tests *)
END_VAR
VAR
    CoastSpeedMps         : REAL;          (* |v| pendant le roulis *)
    CoastDirPos           : BOOL;          (* sens du roulis *)
    T_CutLeftS            : REAL;
    CmdPrev               : BOOL;
(* CoastDistanceM : SUPPRIMÉ — plus aucune réserve de points *)
END_VAR
```

```iecst
Dt  := SimTaskCycleS;
cmd := RelayFwd XOR RelayRev;

IF cmd THEN
    (* contrôle vivant : roulis éteint, mémoriser v/sens pour l'amorçage *)
    CoastActive := FALSE;
    (* ... comptage normal existant, inchangé ... *)

ELSIF CoastActive THEN
    IF T_CutLeftS > 0.0 THEN
        T_CutLeftS := T_CutLeftS - Dt;     (* v inchangée pendant temps mort *)
    ELSE
        aSel := SEL(G:=CoastDirPos, IN0:=CoastDecelDown_Mps2, IN1:=CoastDecelUp_Mps2);
        vNew := CoastSpeedMps - aSel * Dt;
        IF vNew <= 0.0 THEN vNew := 0.0; CoastActive := FALSE; END_IF
        CoastSpeedMps := vNew;
        IF MechanicStopEngaged THEN CoastActive := FALSE; CoastSpeedMps := 0.0; END_IF
    END_IF
    (* comptage continue, même sens, v variable ; SpeedMps publiée = CoastSpeedMps *)

ELSIF CmdPrev AND (NOT cmd) THEN
    (* FRONT de coupure : amorçage uniquement si |v| > seuil (~5 mm/s) *)
    CoastActive   := TRUE;
    CoastDirPos   := <sens du dernier mouvement>;
    CoastSpeedMps := |v| du dernier cycle actif;
    T_CutLeftS    := CoastCutTimeS;
END_IF
CmdPrev := cmd;
```

### Q2 — Benne : l'inertie **émerge**, elle n'est pas modélisée

- L'ouverture = `f(M2 − M1)` (couche benne existante, à confirmer nom exact dans `CODE/`).
- À la coupure, M1 roulit avec `a_montée`, M2 avec `a_descente` → l'écart évolue **seul** → l'ouverture continue sur inertie. **Zéro paramètre benne, zéro référence à AX15B.**
- L'anticipation de 1.30 m est une loi de **commande** (savoir-faire opérateur / consigne séquence), pas de la physique → elle reste dans la couche commande.
- ✅ **L'exigence "manuel ≡ auto" est garantie par construction** : la simulation ne lit que `RelayFwd`/`RelayRev`, jamais le mode. Aucune correction "spéciale auto" ne doit jamais être ajoutée (test A/B en §6 la verrouille).

### Q3 — Cas limites

| Cas | Comportement du modèle | Note |
|---|---|---|
| Réenclenchement, même sens | coast annulé, reprise continue : `v_coast ≠ v_cmd` impossible (le FB amorce au dernier `v` mesuré) | ✅ par construction |
| Réenclenchement, **sens inversé** | coast annulé ; démarrage inversé au palier 1. Le réel fait un contre-couple brutal — divergence assumée, à documenter | ⚠️ limite du modèle |
| Butée benne atteinte pendant roulis | `MechanicStopEngaged` coupe le coast des **deux** encodeurs (câble : benne bloquée ⇒ 2 tambours bloqués) | 🔧 câblage à concevoir + arbitrer : laisser filer (câbles flasques) vs blocage conservatif |
| Limite haute crochet | idem, via la même entrée depuis les limites d'axe existantes | 🔧 à vérifier l'existant |
| Coupure à v ≈ 0 | seuil d'amorçage (~5 mm/s) → aucun micro-roulis | ✅ |
| **Aucun à-coup de vitesse** | `v` continue par construction : amorcée à `v` du cycle précédent, décél continue, arrêt exact à 0.0 (pas de résidu ni oscillation) | ✅ anti-pattern évité : plus jamais de vitesse de palier pendant le coast |
| Dérive gravitaire en descente sans commande | **non simulée** (hypothèse : frein porte) | ⚠️ limite à documenter |

### Q4 — Schéma & rôle réduit de `FB_SimBench`

```text
FB_Sim_Encoder (x2)          Couche benne (existante)         Couche commande
┌──────────────────┐         ┌─────────────────────────┐     ┌──────────────────┐
│ RelayFwd/Rev     │         │ Ouv = f(M2 − M1)        │◄────│ Manuel / AX15B   │
│ → count, SpeedMps│────────►│ clamp [0 ; OuvMax]      │     │ (anticipation    │
│ + modèle d'état  │         │ → MechanicStopEngaged   │────►│  1.30 m ici)     │
└──────────────────┘  coast  └─────────────────────────┘     └──────────────────┘
     ↑ défauts calibrés        ↑ un seul signal Butée → 2 encodeurs
     (le banc ne surcharge PAS)
```

`FB_SimBench` : **suppression de l'injection 1.30 m, rien à la place**. Si surcharge nécessaire un jour → entrées de paramétrage explicites, jamais de constante cachée.

---

## 6. ✓ Critères d'acceptance à prévoir pour la future implémentation

1. **Rejouer les 3 scénarios Suivi_86** : glissement sim vs mesure — montée 0.54 m ±10 %, descente 1.21 m ±10 %, jog ≤ 25 mm.
2. **Continuité de vitesse** : |Δv| ≤ a·dt entre tout scan consécutif à travers la coupure (test unitaire).
3. **Test A/B** : commandes contacteurs identiques manuel/auto → `Ouv(t)` identique scan par scan ; assert : aucun paramètre du modèle benne ne dépend du mode.
4. **Butée pendant roulis** : comptage stoppé, aucun dépassement.
5. Gates minimum standard (bundle + G200) au jour de l'implémentation — **changement d'interface FB** (`CoastDistanceM` supprimé) ⇒ contrat `AF_Partie-03 §1bis` mis à jour **avant** le code.

---

## 7. 🚨 Points d'alerte & données manquantes (à arbitrer avant le contrat)

| # | Alerte / manque | Action demandée |
|---|---|---|
| A1 | **Durées mesurées (0.65 s / 1.06 s) incompatibles avec une décél constante** — interprétation : arrêt apparent (seuil de résolution du codeur), à vérifier sur les courbes brutes | Fournir `x(t)`/`v(t)` de Suivi_86, pas seulement les scalaires |
| A2 | **Aucune mesure de descente basse vitesse** → `a0` vs `G_eq` inséparables (V2 impossible sans elle) | Demander à l'exploitant un jog descente + une mesure à vitesse intermédiaire |
| A3 | **Coupure à basse vitesse en descente** : non caractérisée ; le modèle V1 clamps `a_desc` constant — comportement plausible mais non validé | Compléter Suivi_86 |
| A4 | **Choix butée pendant roulis** (blocage des 2 tambours vs laisser filer) non tranché | Arbitrage exploitant |
| A5 | `MechanicStopEngaged` : câblage depuis limites d'axe existantes à vérifier (inventaire avant contrat) | Lecture du code au jour de l'implémentation |

---

## Restitution

```text
Auto-vérification liaison (G200_check_linkage.py) : N/A — aucune modification
Gates : N/A  ·  Diff bundle : aucun
Fichiers modifiés : AUCUN (étude de conception, conformément à la mission)
Hors scope constaté (devoir d'alerte) : §7 A1–A5
```

**Validation attendue avant toute écriture** : ① V1 (décél constante par sens) au lieu de V2 ? ② défaut `CoastCutTimeS = 0.0` ? ③ choix butée A4 ? ④ dérive gravitaire confirmée hors périmètre ? Dès accord, j'écris le contrat d'interface (changement FB = contrats d'abord, code ensuite).