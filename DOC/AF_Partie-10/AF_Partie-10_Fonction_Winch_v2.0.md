# Analyse Fonctionnelle — Partie 10 : Fonction Winch M1/M2 (v2.0)

> Rôle : mouvement treuils M1 (Retenue) / M2 (Benne), safety métier, synchro, benne, barrière finale.
> **Détail technique par FB** : voir les 5 fiches dédiées (§1). Ce chapô reste au niveau machine
> + intégration programme + TBD Lot 4 — il ne recopie pas les interfaces/`TC-` des fiches.
> Source code : `CODE/TREUILS/*.st` · instances dans `Treuils (CFC)` (mouvement), `Safety (CFC)` (safety), `Outputs (Ladder)` (finale).
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Winch_Extraction_Code_v1.0.md`.
> v1.14 archivée : `ARCHIVES/Doc/AF_Partie-09_Fonction_Winch_v1.14.md`.

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôle machine
3. DUT et bus
4. Intégration programme
5. Alertes et écarts (transverses)
6. TBD — Commande vitesse par palier (Lot 4)
7. Documents liés

## 🧪 Points de validation

Catalogue `TC-P10-*` **réparti dans les 5 fiches FB** (propriétaire unique par fiche, pas
dupliqué ici) :

| Fiche | TC couverts |
|---|---|
| [`FB_Winch`](AF_Partie-10_FB_Winch_v1.0.md) | TC-P10-011, 017, 018, 019 |
| [`FB_Safety_Winch`](AF_Partie-10_FB_Safety_Winch_v1.0.md) | TC-P10-001 à 010 |
| [`FB_WinchSync`](AF_Partie-10_FB_WinchSync_v1.0.md) | TC-P10-014, 015, 016 |
| [`FB_WinchOutputInterlock_LD`](AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md) | TC-P10-012, 013, 020, 021, 022 |
| [`FB_Bucket`](AF_Partie-10_FB_Bucket_v1.0.md) | TC-P10-023 à 034 |

---

## 1. Composition — fiches FB dédiées

| Fiche | FB détaillé | Contenu |
|---|---|---|
| [`AF_Partie-10_FB_Winch_v1.0.md`](AF_Partie-10_FB_Winch_v1.0.md) | `FB_Winch` (+ `FB_SpeedStep`, `FB_Brake` résumés) | Mouvement, rampe, palier, sens, frein |
| [`AF_Partie-10_FB_Safety_Winch_v1.0.md`](AF_Partie-10_FB_Safety_Winch_v1.0.md) | `FB_Safety_Winch` | 7 mécanismes A-G, masques, bypass |
| [`AF_Partie-10_FB_WinchSync_v1.0.md`](AF_Partie-10_FB_WinchSync_v1.0.md) | `FB_WinchSync` | Synchro niveau 1, couplage croisé |
| [`AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md`](AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md) | `FB_WinchOutputInterlock_LD` | Barrière finale, watchdog frein, anti-redémarrage |
| [`AF_Partie-10_FB_Bucket_v1.0.md`](AF_Partie-10_FB_Bucket_v1.0.md) | `FB_Bucket` (+ `FB_DiveSearch`, `FB_ExtractionSequence`) | Benne, désynchronisation M1/M2, glissement, assistants |

`FB_WinchLoadEstimator` (diagnostic charge informatif, pas de safety) : voir extraction code,
pas de fiche dédiée (faible enjeu).

```text
FB_Winch (mouvement, ×2)
 ├─ FB_SpeedStep    (palier → 4 contacteurs)
 ├─ FB_Brake        (séquence frein manque-courant, partagé Translation)
 └─ FB_Ramp         (accel/décel)

FB_Safety_Winch (×2)              ──► SafeStop / ForbidDescent / ForbidAscent / PowerCutOff
FB_WinchSync (×1)                 ──► DeltaPosM, SyncWarn (niveau 1, warning)
FB_Bucket (×1)                    ──► Benne (sous-fonction M2, désynchronisation)
FB_WinchOutputInterlock_LD (×2)   ──► Q finales (barrière, dans Outputs)
FB_WinchLoadEstimator (×2)        ──► diagnostic charge, informatif
```

Benne = sous-fonction M2 : aucune I/O propre, réutilise `FB_Winch` M2. Fiche dédiée dans ce dossier.

---

## 2. Rôle machine

Treuil M1 (Retenue) et M2 (Benne) : levage/retenue de charge par câble, 5 paliers de vitesse
par contacteurs discrets (pas de variateur continu), frein à manque de courant. Sécurité par
défense en profondeur (7 mécanismes détaillés dans la fiche `FB_Safety_Winch`).

---

## 3. DUT et bus

| DUT | Producteur | Consommateur |
|---|---|---|
| `ST_WinchFinalInterlockRequest` | `Treuils (CFC)` | `Outputs (Ladder)` |
| `ST_SpeedStepTable` | config IHM/RETAIN | `FB_Winch`/`FB_SpeedStep` |
| `ST_SafetyWinch` | `Supervision` (agrège) | IHM |
| `ST_BypassWinch` | IHM RETAIN | `FB_Safety_Winch` |
| `ST_ContactorCheck` (COMMUN) | `FB_Brake`/`FB_Winch` | `FB_Safety_Winch`, IHM |

---

## 4. Intégration programme

```text
Safety (CFC)        instSafetyWinchM1/M2, instSpeedMonitorM1/M2, instLoadEstimatorM1/M2
Treuils (CFC)
  §1  instBucket (Benne, appelé EN PREMIER — évite fenêtre de commande manuelle parasite)
  §2  Arbitrage M1 (SEMI_AUTO / MAINT / joystick / boutons)
  §3  Arbitrage M2 (Benne prioritaire > SEMI_AUTO > joystick/boutons)
  §3bis Assistance maintenance (DiveSearch/ExtractionSequence)
  §3ter Coupure immédiate M1/M2 en fin de cycle benne
  instWinchSync (lu 1 scan après arbitrage)
  §5  Limites basses + couplage croisé
  §6/7 Exécution instWinchM1/M2
  §8  Publication ST_WinchFinalInterlockRequest → Outputs
Outputs (Ladder)    instWinchOutputInterlockM1/M2_LD (Q finales)
```

**Dépendances** : Joystick (`AxisCmdY`, `DeadmanArmed`), Modes (`JoystickWinchSelectArbitrated`,
`InhibitM1/M2`, `SyncEnable`), Encodeurs (`CablePosM`, `Homed`, vitesse), Cycle (SEMI_AUTO).

---

## 5. Alertes et écarts (transverses)

| # | Gravité | Point | Détail |
|---|---|---|---|
| 1 | info | 7 mécanismes (A-G), pas 5 | `FB_Safety_Winch` §6 |
| 2 | info | Doc AF02 legacy décrit CFC générique ≠ PRG réels | Architecture cible à part |

Écarts spécifiques à un FB (double délai palier, `DelayMotorDecel` code mort, garde-fou non
persistant) : voir la fiche FB concernée (§7 de chaque fiche) et §6 ci-dessous.

---

## 6. TBD — Commande vitesse par palier (Lot 4, étude requise avant code)

> ⛔ **Décision explicitement différée** (`PLAN_TASK.md` Lot 4) : *"Étude montée/descente AVANT
> code ; ne pas choisir arbitrairement le sort de `DelayMotorDecel`"*. Cette section documente
> la **cible fonctionnelle proposée** et les **questions ouvertes** — ce n'est ni une spec figée
> ni une autorisation de coder. Essais en charge réels requis avant tout choix (T91).

### 6.1 Constat actuel (vérifié code)

| Mécanisme | État réel | Détail |
|---|---|---|
| Accélération/décélération | `FB_Ramp` générique, %/s | `FB_Winch` §7 |
| Hausse palier | Deux délais empilés (1s500ms + 1s250ms) | `FB_Winch` §7, `FB_WinchOutputInterlock_LD` §4 |
| Coupure finale (freinage) | `DelayMotorDecel` code mort | `FB_Winch` §6 |
| Garde-fou vitesse mesurée | Existe, désactivé, non persistant | `FB_Winch` §5 |
| Bandes de vitesse par palier | Théoriques, jamais mesurées | Voir §6.3 |

### 6.2 Cible proposée (discussion utilisateur, non tranchée)

**Montée en palier (accélération)** — doit rester **progressive** :
- Remplacer la rampe %/s par une **temporisation par palier** (temps de maintien avant hausse), potentiellement **différente par palier** (démarrage en charge = le plus critique)
- Conditionner la hausse à un **régime minimal mesuré** (garde-fou vitesse, déjà présent mais désactivé)

**Arrêt (relâchement joystick)** — doit être **rapide**, pas une rampe symétrique à l'accélération :
- Proposition : coupure en cascade des 4 contacteurs de vitesse, ex. **~100 ms par contacteur** (total configurable, ex. 500 ms), pas une décélération lissée façon variateur
- Distincte de la séquence frein (`FB_Brake`), qui reste pilotée séparément

**Ce découpage confirme et précise T91 (asymétrie montée/descente) et T93 (tempo par palier au lieu de rampe %/s).**

### 6.3 TBD — Apprentissage vitesse par palier (nouveau, T96)

**Constat** : `SpeedBandMaxMps` est aujourd'hui rempli à la main avec des valeurs théoriques.
Aucun mécanisme de mesure/calibration automatique n'existe (T95 mentionne "étendre
`FB_WinchSymmetry`" sans détailler de mécanisme).

**Besoin exprimé** :

| Élément | Détail |
|---|---|
| Déclencheur | Mode maintenance dédié : "Apprentissage à vide" et "Apprentissage en charge" (2 jeux de bandes distincts) |
| Capture | Sur chaque palier, après stabilité (~1-2 s), mesure vitesse peu filtrée (évite un pic transitoire) |
| Stockage | Remplace/alimente `SpeedBandMaxMps[1..5]`, un jeu par condition (vide/charge) |
| Robustesse | Valeur brute jamais utilisée telle quelle : **offset réglable** (marge) avant utilisation comme seuil de garde-fou |
| Cas d'usage cité | Alimentation groupe électrogène vs secteur → vitesse réelle différente à charge égale ; l'apprentissage évite une calibration manuelle poste par poste |

**TBD à trancher avant code** :
- Bit unique (sélection vide/charge par ailleurs) ou 2 bits dédiés distincts ?
- Portée : par treuil (M1/M2 séparés) — cohérent avec `SpeedBandMaxMps` déjà par instance
- Durée de stabilité et fenêtre de mesure (lien `FB_Encoder_SpeedMeasure`, déjà fenêtre 50 ms — probablement insuffisant seul, agrégation supplémentaire à définir)
- FB dédié proposé (nom informatif, pas engageant) : `FB_WinchSpeedLearning`

Suivi pilotage : `PLAN_TASK.md` T96.

### 6.4 Ne pas faire sans étude terrain (rappel)

- Ne pas trancher `DelayMotorDecel` (supprimer vs implémenter) sans les essais MES-006
- Ne pas activer `SpeedGuardEnable` avant calibration réelle (T94 dépend de T95)
- Ne pas remplacer la rampe %/s sans valider l'impact sur `FB_Cycle`, IHM, `GVL_PERSISTENT`

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF01 | AU/PowerCutOff — chaîne électrique |
| AF03 | Contrat FB mouvement |
| AF05 | Modes — InhibitM1/M2, SyncEnable |
| AF06 | E/S physiques treuils |
| AF09 | Codeurs — Homed, position, vitesse |
| PLAN_TASK | Lot 4 (T87/T91/T93/T94/T95/T96) — décision non prise, étude terrain requise |
| Code | `CODE/TREUILS/*.st`, `CODE/MAIN/Treuils (CFC).st` |
