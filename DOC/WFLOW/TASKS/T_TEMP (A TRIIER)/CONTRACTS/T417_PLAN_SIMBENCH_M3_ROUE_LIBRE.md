# 🧭 Plan technique T417 — SimBench M3 : échelle 50 Hz + rampe 25 Hz/s + rejeu T334 (V2)

> V2 après challenge expert : la **roue libre est abandonnée** (la trace réelle montre une rampe ~25 Hz/s).
> Vérité = code déployé en mise en service + registres MES + traces. Aucun code écrit. Go humain requis.
> Principe : le plus petit changement qui fait ressentir le comportement réel. Zéro mécanisme décoratif.

## 🎯 Écarts sim ↔ réel retenus
| # | Écart | Où |
|---|---|---|
| E1 | Sim : `Hz = Pct × 0,4` borné à 40. Réel : `Pct = f/50×100` → 20 Hz réel = 16 Hz sim | `FB_Sim_Translation.st` `FrequencyTarget_Hz` ; `FB_Sim_TranslationDrive.st` `CST_MaxFrequency_Hz` ; source réelle `PRG_02_Acquisition.st:341-347` |
| E2 | Décélération sim 20 Hz/s ; trace réelle ~25 Hz/s (rampe variateur F01.23 ≈ 2 s) | `FB_Sim_TranslationDrive.st` `DecelRate` |

Non retenu : roue libre, `VelocityTrue := 0` instantané (inchangé : le frein ne ferme que sous 0,5 Hz).

## 🔧 Lots
1. **L1 — échelle** : `FrequencyTarget_Hz := LIMIT(0, SpeedTgt_Pct × MaxFreq_Hz / 100, MaxFreq_Hz)` ; `MaxFreq_Hz` en entrée (défaut 50,0) alimentée par `FB_SimBench` depuis `GVL_PERSISTENT._TranslationMaxFreq_Hz` (lecture seule). `CST_MaxFrequency_Hz` du Drive 40 → 50. Gain 0,02 m/(Hz·s) inchangé (provisoire T301). Correction de fidélité, pas un interrupteur. Si TC-T300 / G518 (lit `CST_NominalFrequency_Hz`=40, ligne 108) cassent : on aligne le test, pas le sim.
2. **DecelRate 20 → 25 Hz/s** (un paramètre). Test de pente 25 ± 1 Hz/s (AC3).
3. **Rejeu T334 avec le vrai code** : scénario TEST_AUTO_CI qui fait tourner `FB_Translation` (non modifié) contre le sim sur un cycle d'approche P1/Trémie ; trace archivée (consigne PLC, consigne variateur, mot de commande, fAct, frein, DI). Question testée : le bond de consigne à la disparition du clamp 20 Hz suffit-il à reproduire le dépassement ? Réponse oui/non documentée, sans ajouter de modèle si non.
4. **Garde-fou AC8** : gate figeant la liste des lecteurs de `GVL_Simulation`, test négatif.

## ✅ Non-régression
Hors E1/E2, sorties identiques à la v0.7.33 (référence figée avant modif). `SimM3OpenModelicaActive` reste FALSE.

## 📏 Cibles de calibration
- Pente 25 ± 1 Hz/s (trace réelle).
- Dépassement à 20 Hz : 0,25 m ± 30 % (3 événements du 23/09 ; à confirmer par T348, gain 0,02 provisoire).

## ❓ Points ouverts
Cause exacte du dépassement du 25/09 (hors trace 23/09) ; cycle auto vs manuel des 3 événements ; T348 (trace 10 ms) non faite.

## 🚦 Prochaine étape
Go humain sur ce plan → implémentation Claude → bundle + G200 + gates → demande de review à l'utilisateur, qui transmet contrat + détail aux agents externes.
