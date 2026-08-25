# FB_Sim_Translation — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.3.md`](../AF_Partie-13_Fonction_Simulation_v2.3.md) §4.
> Rôle de **ce** document : modèle simulé des 5 capteurs de position M3 par progression continue —
> et **catalogue unique** des `TC-P13-040...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Translation.st` · instance `FB_SimBench.instSimTranslation`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Modèle de progression
4. Documents liés

## 🧪 Points de validation (`TC-P13-040...` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P13-040</code></nobr> | Ne publie que les 6 mots thermomètre valides de `FB_Translation_PositionDecoder` (`11111→00000`) | `💻 AUTO` |
| <nobr><code>TC-P13-041</code></nobr> | `Direction=+1` progresse vers Trémie, `-1` vers Maintenance, `0` maintient la position | `💻 AUTO` |
| <nobr><code>TC-P13-042</code></nobr> | Position bornée `[Trémie, Maintenance]` — jamais de dépassement | `💻 AUTO` |
| <nobr><code>TC-P13-043</code></nobr> | `Enable=FALSE` réinitialise sur la Trémie (0 m) — état de départ propre (REX 2026-08-21, était P2) | `💻 AUTO` |

---

## 1. Rôle et profil

🎯 Produit les cinq capteurs de position M3 par progression continue de Trémie vers Maintenance,
à une vitesse dérivée de `SpeedTgt_Pct`/`FullTravelTimeS`. Le modèle ne publie que les six mots
valides attendus par `FB_Translation_PositionDecoder` (Partie 11) — jamais un mot incohérent, ce
FB simule un capteur sain, pas un défaut câblage.

📏 **Convention position (REX 2026-08-21)** : `PositionProgress` interne en **mètres**,
`0 m = Trémie` … `30 m = Maintenance`. Seuils capteurs aux positions réelles, **distances
non-linéaires** : Trémie(0)→PV(5)=5 m, PV(5)→P2(15)=10 m, P2(15)→P1(20)=5 m, P1(20)→Maintenance(30)=10 m.

🔒 Source d'entrée confinée derrière `HwIn` : ne pilote aucune sortie réelle. Un éventuel override
manuel (`SimM3SensorsWordOverrideActive`) est appliqué par `FB_SimBench`, pas par ce FB — séparation
stricte entre le modèle dynamique et l'injection ponctuelle opérateur.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Modèle actif |
| `Direction` | INT | `+1` = vers Trémie, `-1` = vers Maintenance, `0` = maintien |
| `SpeedTgt_Pct` | REAL | Magnitude commande 0..100 %, bornée avant calcul |
| `FullTravelTimeS` | REAL | Temps complet Trémie→Maintenance à 100 % (simulation seulement, défaut 8.0s) |

| Sortie | Type | Sens |
|---|---|---|
| `PosTremie`/`PosPV`/`PosP2`/`PosP1`/`PosMaintenance` | BOOL | Bits 4→0 du mot capteurs (cumulatif thermomètre) |

---

## 3. Modèle de progression

Position interne `PositionProgress` (REAL, **mètres**, 0=Trémie … 30=Maintenance), incrémentée/
décrémentée chaque scan selon `SpeedPctBounded` et `FullTravelTimeS` (`FB_CycleTime` pour le pas
réel). À 100 %, le modèle parcourt les **30 m** de distance totale en `FullTravelTimeS`. Chaque
intervalle délimité par les positions réelles `[0;5[`, `[5;15[`… correspond à un seul mot
thermomètre valide — aucune zone transitoire à cheval sur deux mots. **Init déterministe sur la
Trémie (0 m)** au démarrage et sur `Enable=FALSE`.

Protection division : sous `CST_MinFullTravelTimeS` (0.1s), le modèle n'a plus de dynamique
(`PositionIncrement := 0.0`) plutôt qu'une division qui exploserait.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation, stimuli `SimM3SensorsWordOverrideActive` |
| AF11 / FB_Translation_PositionDecoder | Consommateur réel des 5 capteurs, table des 6 mots valides |
| Code | `CODE/L_SIMULATION/FB_Sim_Translation.st` |
