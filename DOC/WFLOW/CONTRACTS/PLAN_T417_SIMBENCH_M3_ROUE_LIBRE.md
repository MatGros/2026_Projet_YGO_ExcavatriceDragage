# 🧭 Plan technique T417 — SimBench M3 : 50 Hz + roue libre (BROUILLON, avant challenge)

> Vérité = code déployé en mise en service + registres MES. Aucun code écrit. Validation humaine requise avant implémentation.
> Principe : le plus petit changement qui rend le comportement ressenti en réel. Zéro mécanisme décoratif.

## 🎯 Constat à corriger (relevé dans le code)
| # | Écart sim ↔ réel | Où |
|---|---|---|
| E1 | Sim : `Hz = Pct × 0,4`, borné à 40. Réel : `Pct = f/50×100`. 20 Hz réel → 16 Hz sim | `FB_Sim_Translation.st` `FrequencyTarget_Hz`, `FB_Sim_TranslationDrive.st` `CST_MaxFrequency_Hz` |
| E2 | Commande retirée : sim = rampe contrôlée 20 Hz/s. Réel = `CommandWord 0` = roue libre | `FB_Sim_Translation.st` (FrequencyTgt=0 → rampe) |
| E3 | Sim : `IF NOT BrakeMechanicallyOpen THEN VelocityTrue := 0` instantané | `FB_Sim_Translation.st` |

## 🔧 L1 — Échelle (E1)
`FrequencyTarget_Hz := LIMIT(0, SpeedTgt_Pct × MaxFreq_Hz / 100, MaxFreq_Hz)` avec `MaxFreq_Hz` en entrée (défaut 50,0), alimentée par `FB_SimBench` depuis `GVL_PERSISTENT._TranslationMaxFreq_Hz`. `CST_MaxFrequency_Hz` du Drive passe de 40 à 50. Gain 0,02 m/(Hz·s) inchangé (30/(40×37,5), G518).
⚠️ Changement du comportement par défaut : c'est une correction de fidélité, pas un interrupteur. Vérifier que TC-T300 et G518 restent verts, sinon les tests supposaient 40 Hz et sont à corriger, pas le sim.

## 🧲 L2 — Roue libre (E2, E3)
**Déclencheur** : `CoastOnCommandLoss` (interrupteur, défaut FALSE) ET `DirectionSign = 0` ET `|ActualFrequency| > 0,5 Hz` ET frein mécaniquement ouvert.

**Modèle retenu (proposition)** : décélération **constante** `CoastDecel_Mps2` (un seul paramètre), vitesse → 0 :
`v ← v − sign(v) · a · Ts` (borné à 0). La fréquence rapportée suit la vitesse : `fAct = |v| / 0,02`. Le frein se ferme sous 0,5 Hz (garde existante, déjà validée trace du 04/09), donc `v` est déjà ≈ 0,01 m/s à la fermeture : E3 devient sans conséquence et **n'est pas modifié**.

**Pourquoi constante plutôt que visqueuse** : distance d = v²/(2a) → croît en v² (cohérent avec l'aggravant mesuré T334 H3, +56 % entre 40 % et 100 %). Frottement visqueux donnerait d ∝ v. Un paramètre, pas deux.

**Valeur initiale** : à 20 Hz, v = 0,4 m/s ; dépassement cible 0,20–0,40 m → `a` ≈ 0,2 à 0,4 m/s². Défaut proposé 0,3 m/s², à recaler.

**Intégration minimale** :
- `FB_Sim_TranslationDrive` : entrée `FreeCoast : BOOL` + `CoastFrequency_Hz : REAL`. Si `FreeCoast` : `FrequencyCmd_Hz := ElectricalFrequency_Hz := ActualFrequency_Hz := CoastFrequency_Hz` (pas de rampe, pas de saut à la reprise).
- `FB_Sim_Translation` : bloc de ~10 lignes calculant `v` en roue libre et `CoastFrequency_Hz := |v|/0,02`.
- `GVL_Simulation` : `SimM3CoastOnCommandLoss : BOOL := FALSE`, `SimM3CoastDecel_Mps2 : REAL := 0.3`.
- `FB_SimBench` : câblage de ces deux variables.
- Aucun changement à `FB_Sim_SuspendedLoad` : l'accélération du chariot lui est déjà transmise (le pendule réagira naturellement à la décélération).

## ✅ Non-régression
Interrupteur FALSE → sorties identiques à la v0.7.33 (hors correction L1). Scénarios figés avant modif.

## 🔒 Garde-fou
Gate fixant la liste des lecteurs de `GVL_Simulation` (liste actuelle, pas de nouveau lecteur).

## ❓ Points à challenger
1. Que rapporte réellement l'AC600 (`ActualFrequencyHz`) quand la modulation est coupée en mouvement ? Décroissance progressive (estimation) ou chute immédiate à 0 ? Si chute immédiate, le frein PLC se ferme à 0,5 Hz presque aussitôt et la distance vient du délai frein, pas du frottement.
2. Une décélération constante est-elle réaliste pour un chariot de translation chargé (charge suspendue, roulement) ? Faut-il un terme visqueux ?
3. La trace réelle `Suivi_90_MES_SoirDisj_M3_20260923` (fréquence + DI capteurs + `BrakeIsOpen_DI`) permet-elle d'en tirer `a` sans position en mètres (v = 0,02 × f) ?
4. Y a-t-il un risque de sur-complexité ? Que couper ?
