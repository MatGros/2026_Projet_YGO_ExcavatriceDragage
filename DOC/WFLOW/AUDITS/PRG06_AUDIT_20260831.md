# 🔍 AUDIT APPROFONDI — `PRG_06_Outputs` (barrière finale matérielle)

> 🎯 **Objet** : Audit sécurité machine (ISO 13849), interlocks finaux, lisibilité du POU de barrière finale.
> 📅 **Date** : 2026-08-31 · 📊 **Verdict global** : 🟢 **Structure SÛRE** — aucune voie actionneur non protégée identifiée ; ❗ deux **incohérences doc/code** à solder (une décision de conception + une variable morte), un **bug de câblage diagnostic** confirmé.

---

## 0 · Périmètre et sources lues (source de vérité `CODE/` actif)

| Fichier | Rôle |
|---|---|
| `CODE/M_MAIN/PRG_06_Outputs.st` | **Barrière finale** (objet de l'audit) |
| `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | Interlock final M1/M2 |
| `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st` | Interlock final M3 |
| `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement{,.Logic,.Output}.st` | Chaîne AU / PowerCutOff |
| `DOC/AF/AF_Partie-01_…_v2.1.md` + fiche `FB_Safety_EmergencyManagement_v1.2` | Spec AU |
| `DOC/AF/AF_Partie-10_…/FB_WinchOutputInterlock_v1.0` | Spec interlock treuils |
| `DOC/AF/AF_Partie-11_…/FB_TranslationOutputInterlock_v1.1` | Spec interlock M3 |
| `AF_Fiche_PRG_06_Outputs_v1.0` | Fiche du POU |
| `DOC/STDS/CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md` | Référentiels |

---

## 1 · Verdict par axe

| Axe | Verdict | Synthèse |
|---|---|---|
| 🔒 **Sécurité machine (chaîne finale / AU / PowerCutOff)** | 🟢 **SÛR** | Chaîne AU fail-safe, double gate, watchdog frein 500ms, anti-redémarrage — robuste. 1 point à arbitrer (A1). |
| 🛡️ **Interlocks finaux M1/M2/M3** | 🟢 **SÛR** / ⚠️ M1/M2 | M3 = conforme spec (gate double). M1/M2 = écart spec (gate frein), voir A1. |
| 📖 **Lisibilité** | 🟢 **Bonne** | 333 lignes, organisé par fonction, lisible d'un coup d'œil. Variable morte + sortie jamais écrite encombrent l'interface (A2/A3). |

---

## 2 · 🔒 Sécurité machine — impact safety réel

### ✅ Points solides (confirmés)
- **Chaîne AU fail-safe** : `MaintainA/B_RQ` en polarité "maintien actif à l'état sain" (FALSE=retombée). Perte alimentation PLC, arrêt tâche, ou watchdog → retombée des canaux → ouverture du contacteur de puissance → `PowerContactorEngaged=FALSE`. Conforme AF01 §7.1.
- **Redondance A/B auto-testée** à chaque réarmement (test croisé canal par canal, preuve runtime) + autotest de démarrage (boucle fermée ET contacteur au repos).
- **`PowerCutOffReq` agrégé** (M1∨M2∨M3) coupe A+B immédiatement **sans** séquence de réarmement. Conforme TC-P01-001/008.
- **Abort séquence** sur `BtnEmergencyCutOff` (volontaire, sans alarme) et sur `PowerCutOff` (alarme + lockout 5s).
- **Double gate des axes** : les 3 interlocks coupent toutes sorties si `NOT Enable OR NOT PowerContactorEngaged` ; `PowerContactorEngaged` est le retour **physique** (DI) rebouclé dans chaque request.
- **Watchdog frein 500ms** sur M1/M2/M3 ; latches défaut/`RestartInhibit` **préservés hors Enable** (jamais de redémarrage auto, Reset sur front) — TRÈS bon.
- **M3 (AC600)** : gate correcte — `DriveControlWord`/fréquence autorisés **seulement** si `BrakeReleaseRequest AND BrakeCommandOpenConfirmed`. Clamp fréquence `MAX(0.0,…)`, mise à l'échelle WORD bornée. Conforme TC-P11-008.

### ⚠️ A1 — Écart spec vs code sur la **gate frein des treuils** M1/M2 (modéré, décision de conception)
- **Spec** (`FB_WinchOutputInterlock_v1.0 §3`) : gate finale **double condition obligatoire** — `RelayFwd/Rev`+`Contactor1..4` autorisés **seulement si** `MovementRequested AND BrakeReleaseRequest AND BrakeCommandOpenConfirmed` (i.e. frein confirmé ouvert avant puissance).
- **Code** (`FB_WinchOutputInterlock.st §5 ELSE`) : `RelayFwd/Rev`/`Contactor1..4` positionnés **= demande**, **sans** conditionner `BrakeFeedback`. `BrakeCmd := RelayFwd OR RelayRev` → **frein et puissance commandés simultanément** (1 scan), mouvement autorisé avant confirmation de desserrage. Le watchdog 500ms couvre le cas frein collé.
- **Contradiction interne de la spec** : §3 (gate double) **vs** TC-P10-039.1 / §2bis (couplé direct « jamai de divergence »). Le code applique le **couplé direct**.
- **Impact safety réel** : fenêtre ≤500ms où le moteur est alimenté sans confirmation de desserrage. En frein manque-courant, si la bobine ne décolle pas (frein reste serré) → effort/stress mécanique + échauffement moteur, mais **la charge reste TENUE** (aucune perte de maintien de charge) ; le watchdog coupe ensuite → `RestartInhibit`. **Mode de défaillance non catastrophique mais évitable**, et **incohérent avec M3** (plus strict).
- **Recommandation (à trancher)** : aligner M1/M2 sur M3 (imposer `BrakeFeedback` avant d'autoriser `RelayFwd/Rev`) **OU** acter explicitement le couplé direct comme dérogation documentée et lever la contradiction §3 vs TC-P10-039.1. **Décision safety requise**, pas une simple réécriture.

### ℹ️ A5 — Kobold (alimentation capteur fond) hors barrière (assumé)
`M1_M2_KoboldMeasureEnable_DQ` n'est pas sous `PowerCutOff` — commandé par l'arbitrage `PRG_04`. **Conforme** à la fiche PRG_06 phase 3 (Auxiliaires) : ce n'est pas un actionneur de mouvement. RAS, mais à garder explicite (sortie puissance non coupée).

**Conclusion sécurité** : 🟢 Aucun chemin de commande actionneur non protégé identifié pour les axes M1/M2/M3. La **barrière fonctionne** ; l'enjeu n°1 est une **cohérence de conception** (A1) et **d'écriture doc/code** (A2).

---

## 3 · 🛡️ Interlocks finaux — polarité fail-safe

| Critère | M1/M2 (`FB_WinchOutputInterlock`) | M3 (`FB_TranslationOutputInterlock`) |
|---|---|---|
| Gate dur `Enable/PowerContactorEngaged` | ✅ coupe tous DQ + `BrakeCmd` | ✅ motive/fréquence 0 + `BrakeCmd` FALSE |
| Latch défaut hors Enable | ✅ préservé (`ErrorId`/`RestartInhibit`), acquittement conscience | ✅ (`Fault`/`RestartInhibit`) |
| Reset sur front | ✅ | ✅ |
| **Gate frein pré-confirmation** | ⚠️ **NON** (couplé direct) | ✅ OUI (mouvement seulement si frein confirmé ouvert) |
| Watchdog frein 500ms | ✅ | ✅ |
| Resync coupure même scan du défaut | ✅ (§6ter) | — |
| Anti-redémarrage (neutre puis nouvelle demande) | ✅ | ✅ |
| Sortie aux actionneurs | ✅ | ✅ |

**Verdict** : les interlocks appliquent correctement les verrous et la **polarité fail-safe** (coupure sur perte de condition ⇒ sorties à FALSE). Seul point de divergence = gate frein M1/M2 (A1).

---

## 4 · 📖 Lisibilité / charge

- ✅ **PRG_06 lisible** : organisation **fonctionnelle** claire (§1 M1 / §2 M2 / §3 M3 / §4 Kobold / §5 AU), commentaires explicatifs ("d'un coup d'œil"), flux `conditions → interlock → ordres → DQ → bus`.
- ✅ Duplication M1/M2 des chaînes de safety (`MxPowerCutOffSafetyInfo` / `MxSafeStopSafetyInfo` = 6–9 `OR`) : **acceptable**, inhérente à 2 treuils, purement **diagnostic**. **Ne pas abstraire** (risque/lisibilité > gain).
- ⚠️ **Pas de logique inline à forte valeur d'extraction** ; aucun refactor demandé côté logique.
- ⚠️ Nettoyage d'interface nécessaire : A2 (variable morte) + A3 (sortie jamais écrite).

---

## 5 · Actions prioritaires (classées)

| # | Sév. | Action | Impact | Type |
|---|---|---|---|---|
| **1** | 🟠 **P2** | **Arbitrer la gate frein des treuils** (A1) : aligner M1/M2 sur la gate double de M3 OU documenter le couplé direct comme dérogation + lever la contradiction spec. *(Décision de conception safety — pas seul un écrit ST.)* | Conformité spec + cohérence M1/M2/M3. Fenêtre ≤500ms puissance avant confirm. frein. | Conception + doc |
| **2** | 🟠 **P2** | **Vider `SafetyStructureNotValidated`** (A2) : soit le câbler en gate réel de mise en service, soit (le plus probable, lot safety soldé) **supprimer la variable** + corriger en-tête `PRG_06` ligne 7 + fiche `AF_Fiche_PRG_06_Outputs §1`. | Supprime le **faux garde-fou documenté** ; évite un faux sentiment de sécurité en lecture. | Doc + code (hygiène sécurité) |
| **3** | 🟡 **P3** | **Câbler `EmergencyArmingPulseActive`** (A3) : `EmergencyArmingPulseActive := instSafetyEmergencyManagement.ArmPulse_RQ;` dans PRG_06 §5. | Restaure l'info IHM « impulsion de réarmement » consommée par `PRG_07` (actuellement **toujours FALSE**). | Bug diagnostic confirmé |
| **4** | 🟡 **P3** | **Documenter les entrées `SafeStop` inutilisées** des 2 interlocks (A4) : marquer `/* interface standard — non consommé, SafeStop = rampe amont */`. | Clarté ; évite de croire que la barrière agit sur SafeStop. | Doc |
| **5** | ⚪ **P4** | Mettre à jour l'état `TC-P01-010` (AF01 §1) : le code gère désormais l'abort sur `BtnEmergencyCutOff` pendant la séquence — l'écart « non corrigé » semble levé. | Ré-alignement doc/code. | Doc |

---

## 6 · Conformité standards
- ✅ Nommage **PascalCase**, préfixes `[SAFE]`/`[HW]`/`[CMD]`/`[ACT]`, unités, polarité documentées (NC/RQ). RAS.
- ✅ `Reset` sur front partout ; jamais de redémarrage automatique ; `Enable > SafeStop > StartStop` respecté.
- ⚠️ Ligne 7 en-tête PRG_06 trompeuse (A2) — à corriger.

---

## 7 · Synthèse

> **Verdict global : 🟢 SÛR, sans défaut bloquant.** La barrière matérielle repose sur une chaîne AU fail-safe, des double gates `Enable∧PowerContactorEngaged`, des watchdogs frein et un anti-redémarrage rigoureux. **Aucun actionneur de mouvement n'a de chemin de commande non protégé.**
>
> Les 2 points à traiter en priorité sont des **écarts doc/conception** — non des failles exploitées :
> 1. **Arbitrer la gate frein des treuils** (couplé direct vs gate double) — décision safety réelle.
> 2. **Désactiver proprement `SafetyStructureNotValidated`** qui n'existe plus dans la logique mais que la doc décrit toujours comme actif (faux garde-fou).
>
> Bonus confirmé : **bug diagnostic** `EmergencyArmingPulseActive` jamais produite mais consommée par `PRG_07`.
>
> **Rappel mise en service** (source de vérité) : seules les sorties passant par les interlocks finaux sont physiquement actives ; `EmergencyArmingCmd` pilote réellement le pulse, `MaintainA/B` la tension. Aucune force ni aucun bypass n'est requis pour cet audit.
