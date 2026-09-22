# REX / Rapport Phase 0 — T306 Vérification défaut rotation de phase

- **Tâche** : T306 — `SECURITE / SIMULATION / CONTROLE_PHASES`
- **Date** : 2026-09-22 · **Agent** : DSH01 (vérification read-only) + audit parallèle challenge
- **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T306_VERIFICATION_DEFAUT_ROTATION_PHASE.yaml` (C2)
- **Brief** : `BRIEF_T306_ROTATION_PHASE_v1_TRANSMISSION.md`
- **Périmètre** : PHASE 0 uniquement — **vérification en lecture seule**, **aucune écriture** sur la chaîne de sécurité.
- **Méthode** : re-mesure de **première main** de chaque fichier:ligne (pas de confiance aveugle dans le brief ni dans l'audit parallèle).

---

## 0. Bloc G200 — Auto-vérification liaison (BLOQUANT)

`python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` — **PASS** (exit 0) :

```text
Auto-verification liaison (G200_check_linkage.py) ? PASS
  Linkage (L1-L7):    138 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 25 WARN
  L10 (Single prod):  1905 OK, 1627 WARN
  L11 (Polarity):     0 OK, 29 WARN
  L12 (Timing):       7 OK, 0 KO, 0 WARN
  L13 (Orphelins):    88 OK, 0 KO
  ... 2050 instance(s) verifiee(s)
Linkage check: PASS (0 erreur(s), 1681 avertissement(s), 2050 instance(s) verifiee(s))
```

> ⚠️ Les 1681 WARN sont **préexistants** (notamment L9 I/O mapping : convention de nommage CSV
> différente, sans lien avec cette tâche). Aucune KO.

---

## 1. Réponses Q1→Q5

### Q1 — Chaîne câblée de bout en bout jusqu'aux sorties ? → **VÉRIFIÉ** (avec **1 écart majeur M3**)

**Production / arbitrage unique** :
- `PRG_02_Acquisition.st:190` → `HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;` (affectation brute, **pas** une déclaration VAR_INPUT — écart au brief).
- Source brute : variable E/S globale `GVL_Device_IO.st:53` (`PhaseRotationOk_DI : BOOL`). VAR_INPUT de PRG_02 **vide** (`.st:14`).
- Arbitrage **producteur unique** : `PRG_02_Acquisition.st:446` `HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` — tous les consommateurs lisent `HwIn`.

**M1/M2 (treuils)** : chaîne **complète** → sortie physique.
`FB_Safety_Winch.st:302` (cond. bypass+phase) → `:303` latch → `:305` cause4 → `:498` `CausePhaseRotationActive` → `:516-521` agrégé `CausesSafeStopActive` → `:517` `SafeStop := TRUE` ; **exclu PowerCutOff** `:523-525`.
→ `PRG_04_Treuils_Benne.st:1062/1105/1596` (SafeStopM1_Active → `WinchM1FinalInterlockRequest.SafeStop`).
→ `PRG_06_Outputs.st:153/219` (câblage) → `FB_WinchOutputInterlock.st:393` `ELSIF SafeStop OR PermitFinalBlocked THEN` → `:402-403` `RelayFwd := FALSE; RelayRev := FALSE; Contactor1..4 := FALSE;` → `:487` `BrakeCmd := RelayFwd OR RelayRev;` → **freins serrés**.
→ physique : `PRG_06_Outputs.st:369-384`.

**M3 (translation)** : chaîne **effective en amont** MAIS **barrière finale NON indépendante** (écart majeur).
`FB_Safety_Translation.st:140` (cond.) → `:141` `PhaseRotationFault := TRUE` → `:143` cause2 → `:265` `SafeStop := TRUE` ; **exclu PowerCutOff** `:268` (masque `16#00F8`, bit2 hors).
→ `PRG_05_Translation.st:511-512/674` (→ `TranslationFinalInterlockRequest.SafeStop`).
→ arrêt réalisé **par `FB_Translation`** (`:270` `EffectiveSafeStop` → `:277-278` `RampTargetPct := 0.0` → `:286` rampe rapide → `:323-343` DriveControlWord=0).
→ 🚨 **`FB_TranslationOutputInterlock.st:15` : `SafeStop` déclaré en VAR_INPUT mais JAMAIS lu dans le corps** (grep → 1 seule occurrence). L'entrée est câblée (`PRG_06:438`) mais **inerte**. Contrairement aux treuils, **pas de coupure dure par SafeStop à la barrière finale**. Protection M3 repose sur un **seul** mécanisme (`FB_Translation`).

### Q2 — Défaut injectable en simu/CI ? → **NON** (structurellement impossible)

`FB_SimBench.st:690` : `Machine.PhaseRotationOk_DI := TRUE;` — lecture brute : **ligne sans commentaire** (le libellé `"(* ecrit a CHAQUE scan...*)"` du brief **n'existe pas** dans le code).
- Écrit **à chaque scan** quand `Enable=TRUE` (`:257`), **écrase tout forçage opérateur**.
- Aucun stimulus alternatif : `GVL_Simulation.st` sans variable rot. phase ; pas d'override `HwSim`.
- **CI** : couvert **M3 unitaire** uniquement (`test_fb_safety_translation.st:55-61`, `test_fb_translation.st:951-956`). **Aucun test M1/M2** (`test_fb_safety_winch.st : PhaseRotationOk toujours TRUE`). Aucun test au niveau banc/injection.

### Q3 — Réaction conforme (rampe+freins, SafeStop, Enable maintenu) ? → **CONFORME**

- Pas de `PowerCutOff` : causes rot. phase **exclues** `FB_Safety_Winch:523-525`, `FB_Safety_Translation:268`.
- `SafeStop` (cat.1) : rampe rapide + freins (M1/M2 ordre contacteurs→relais→frein ; M3 rampe AC600→frein).
- `Enable` reste TRUE ; **l'AU physique reste alimenté** (PowerKeepAlive). ⚠️ À confirmer sur machine que le mouvement ne réapparaît pas en flottement (voir AC4).

### Q4 — Verrouillage effectif (anti-redémarrage auto, Reset front) ? → **VÉRIFIÉ**

- Latch **SET seul** : `FB_Safety_Winch.st:303` / `FB_Safety_Translation.st:141` — retour `PhaseRotationOk=TRUE` n'efface **pas**.
- Reset **sur front** `R_TRIG` : `FB_Safety_Winch.st:181` / `FB_Safety_Translation.st:99` → effacement `:186`/`:102`.
- Re-verrouillage immédiat (cause persistante re-posée au scan suivant, socle `FB_FaultCore`).
- ⚠️ Nuance : `BypassGlobal` réarme les latches sans Reset (`:183`/`:101`) — contexte test uniquement.

### Q5 — Bypass encadrés ? → **⚠️ EN PARTIE** (2 lacunes significatives)

- **Non persistant** : `PhaseRotation` absent du `FB_MirrorBypassRetain` (`PRG_07:345-355`) → FALSE au boot. ✅
- **Gate MAINT_N2 ABSENT en code** : `PRG_04_Treuils_Benne.st:984` (M1) / `:1050` (M2) câblé "à nu" sur GVL_IHM, `:970` commenté "SANS gate de mode (dérogation MES 2026, tous modes)". `PRG_05_Translation.st:496` (M3) **non gaté** `M3_MaintN2`, alors que `:500` `BypassLimitSwitch := M3_MaintN2 AND (...)` L'est. ⚠️
- **Silencieux** : `FB_Hmi_BannerFormatter.st:430/441` bandeau "Bypass actif" alimenté **que** par `.Global` — un bypass PhaseRotation granulaire seul ne déclenche aucun signal. ⚠️
- Niveau écran IHM **INDÉTERMINÉ** (pas de `.vis` auditable hors `CODE/`).

---

## 2. Challenge de l'AUDIT PARALLÈLE

L'audit reçu en // a été **re-mesuré de première main** (pas de reprise de ses citations). Verdict : **globalement fiable, 2 affirmations fortes confirmées, 1 précision apportée.**

| Affirmation audit | Verdict | Preuve re-mesurée |
|---|---|---|
| `SafeStop` inerte dans `FB_TranslationOutputInterlock` | ✅ **CONFIRMÉE** | grep → 1 seule occurrence (`.st:15`) ; non consommé dans le corps. `FB_WinchOutputInterlock` lui le **consomme** `:335/:340/:393`. |
| Bypass PhaseRotation non gaté MAINT_N2 | ✅ **CONFIRMÉE** | `PRG_05:496` non gaté vs `:500` gate `M3_MaintN2` ; `PRG_04:970` "SANS gate de mode". |
| Comportements Q3/Q4/Q2 conformes | ✅ **CONFIRMÉE** (convergents) | mêmes mécanismes mesurés indépendamment. |
| Injection : proposer `SimPhaseRotationFault` | ✅ **Recommandation valide** (relève de la phase 1) | cohérent avec `GVL_Simulation` + `FB_SimBench:690`. |

**Précision / désaccord mineur** : l'audit classe Q5 "NON CONFORME", je nuance en **"EN PARTIE"** — l'**absence de persistance** du bypass est un vrai garde-fou acquis (retour FALSE au boot), ce que l'audit mentionne mais sous-pondère. Les **2 lacunes réelles** restent : (1) gate MAINT_N2 absent en code, (2) bypass silencieux à l'IHM.

**Réserve sur l'audit** : il annonce des références fichier:ligne sans preuve de lecture du code réel dans les extraits fournis ; je les ai toutes re-vérifiées => toutes exactes sauf les 2 écarts ci-dessus qui sont eux-mêmes issus du code réel.

---

## 3. Devoir d'alerte — écarts et risques (hors périmètre read-only, à arbitrer)

| # | Sévérité | Écart | Preuve | Suggestion (phase 2 si validée) |
|---|---|---|---|---|
| 1 | 🚨 **Majeur** | `SafeStop` inerte à la barrière finale M3 → **un seul** mécanisme de protection (pas de défense en profondeur) | `FB_TranslationOutputInterlock.st:15` (jamais lu), `PRG_06:438` (câblé) | Consommer `SafeStop` dans le FB (forcer `DriveControlWord := 0; BrakeCmd := FALSE;`) |
| 2 | ⚠️ Majeur-moderé | Bypass PhaseRotation **accessible sans gate MAINT_N2** en production | `PRG_04:970/984/1050`, `PRG_05:496` vs `:500` | Gate `MAINT_N2` sur les 3 axes |
| 3 | ⚠️ Modéré | Bypass PhaseRotation **silencieux** à l'IHM (aucun bandeau dédié) | `FB_Hmi_BannerFormatter:430/441` ; `FB_TroubleshootingView:211-216` | Signal dédié si bypass actif |
| 4 | Modéré | `BypassProcess` peut masquer la cause 4 (masquage croisé) | `FB_Safety_Winch.st:302`, `FB_Safety_Translation.st:140` | À traiter en phase 2 |
| 5 | Modéré | Brief : ligne 190 décrite comme "déclaration VAR_INPUT" → c'est une **affectation brute `HwReal`**, source = variable E/S globale | `PRG_02_Acquisition.st:190`, `GVL_Device_IO.st:53` | Corriger le brief (documentation) |
| 6 | Faible | Citations `(* bit ... *)` du brief absentes des lignes réelles (cosmétique) | `FB_Safety_Translation.st:143`, `FB_Safety_Winch.st:305/498`, `FB_SimBench.st:690` | Documentation |
| 7 | Faible | `ErrorID:05/03` = numéro de cause 1-based, **pas** valeur hex (bit4=`16#0010`) — convention à documenter | `FB_Hmi_BannerFormatter.st:924/972/1011` | Documenter |

---

## 4. Critères d'acceptation (AC1-AC8) — état après Phase 0

| AC | État | Statut |
|---|---|---|
| AC1 | 5 questions répondues avec preuve fichier:ligne + polarité fail-safe + producteur unique | ✅ VÉRIFIÉ |
| AC2 | G200 PASS + bloc `Auto-vérification liaison` collé | ✅ PASS (0 erreur) |
| AC3 | Défaut injectable en simu **sans** casser la prod | ❌ **NON — phase 1 requise** (bloqué `FB_SimBench:690`) |
| AC4 | M1/M2/M3 : SafeStop, freins serrés, relais/contacteurs FALSE par test | ⚠️ Pas de test M1/M2 ; M3 testé unitaire ; à prouver par test injection (phase 1) |
| AC5 | Aucun réarmement auto, Reset front, re-verrouillage | ✅ VÉRIFIÉ par lecture ; à prouver par test |
| AC6 | Bypass encadrés | ⚠️ EN PARTIE — 2 lacunes à arbitrer |
| AC7 | Chaîne AU physique intacte | ✅ — **aucune écriture**, `git diff` périmètre interdit = VIDE |
| AC8 | Messages IHM conformes | ✅ VÉRIFIÉ (ErrorID 05/03, `16#0100`) |

---

## 5. État du diff & périmètre interdit

- **Aucun fichier modifié** par cette tâche (read-only). `git diff --numstat` sur le périmètre de la tâche = **VIDE**.
- ⛔ Périmètre interdit **intact** : `CODE/B_AU_SECURITE/**`, AU physique, `DOC/AF/**`, `DOC/STDS/**`, `PRJ_CODESYS/**`, temporisations moteur/frein.
- ⚠️ Notes : le working tree présentait déjà des modifications **préexistantes non liées à T306** (G_CYCLE, banner, tests CI) — non touchées.

---

## 6. Ce qui reste à prouver / décider (action humaine — ARRÊT PHASE 0)

⛔ **ARRÊT HUMAIN obligatoire** avant toute écriture (phases 1-2).

1. **Arbitrage écarts** : valider/rejeter les 2 correctifs proposés (SafeStop M3, gate MAINT_N2) et le traitement de `BypassProcess`.
2. **GO Phase 1** : rendre le défaut injectable (`SimPhaseRotationFault` dans `GVL_Simulation` + `FB_SimBench:690`) → criticité **C4**, plan humain + double revue exigés avant écriture.
3. **Test injection** : ROUGE avant / VERT après sur M1/M2/M3 (exige la phase 1).
4. **Essai machine (phase 3, HUM)** : couper/inverser une phase sur armoire, vérifier l'arrêt 3 axes, acquittement front, absence de redémarrage auto. Non délégable.
