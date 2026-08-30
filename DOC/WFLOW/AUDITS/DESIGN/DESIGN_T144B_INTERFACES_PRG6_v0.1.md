# 🧨 DESIGN_T144B — Assainir les interfaces inter-PRG (D1/D2/D3)

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-29 · 🎯 Challenger et simplifier les contrats
> d'interface entre les PRG, au premier chef la chaîne winch **M1/M2** (`PRG_03 → PRG_04 → PRG_06`),
> pour garantir une interface **simple, non surchargée et efficace** après le refactor M1/M2.
> 🔗 Complète `DESIGN_T144_ASSAINIR_PRG06_v0.1.md` (faits ①② → déjà résolus par T121) ;
> recentre sur ③ (commande drive M3) + un constat neuf (boucle de lecture arrière PRG_04↔PRG_06).
> 🔗 Recoupe **T181-01** (autorité 2 interlocks + bus diag `FinalInterlockGoverned`).

---

## 1. Constat — ce qui doit être challengé

| # | Constat | Code | Sévérité |
|---|---|---|---|
| **D1** | `PRG_04` (amont) **relit les sorties de la barrière avale** `PRG_06_Outputs` (instance + agrégats safety) pour les re-publier dans son bus et l'IHM. | `PRG_04:979-990`, `PRG_04:1104-1106` | 🔴 haute |
| **D2** | Le même signal **`PowerCutOff`/`SafeStop`** circule **2 fois** sur `ST_WinchInterPrg` (dans `…FinalInterlockRequest` **et** `…Safety`). | `ST_WinchFinalInterlockRequest.PowerCutOff` + `ST_SafetyWinch.PowerCutOff` | 🟠 moyenne |
| **D3** | Commande drive **M3 absente du bus `Data`** ; exposée en `VAR_OUTPUT` plat « cible mapping E/S » (raccordement registres PDO `%QW6/%QW7` manuel CODESYS). | `PRG_06:51-52,270-271`, `ST_OutputsInterPrg` | 🟠 moyenne |

### 1.1 Détail de D1 — la boucle PRG_04 ↔ PRG_06

```
PRG_04 (exécuté position 4)                          PRG_06 (position 6)
  produit Data.WinchM1FinalInterlockRequest  ──────►   écrit Q/PDO + Data
  (Enable/Reset/…/RequestedRelayFwd/Rev…)              |
  produit Data.WinchM1Safety (champs bruts)    ──────►  agrège M1PowerCutOffSafetyInfo…
                                                       |
  ◄────────────── relit instWinchOutputInterlockM1.{BrakeCmd,State,Reason,Error,ErrorId,
                  RestartInhibit,BrakeTimeoutElapsed,RestartDelayElapsed,StepDelayElapsed}
  ◄────────────── relit M1PowerCutOffSafetyInfo / M1SafeStopSafetyInfo / M1BlockedBySafety
  → republie dans WinchM1State.FinalInterlock* et WinchM1Safety.{PowerCutOffSafety,SafeStopSafety,BlockedBySafety}
  → GVL_IHM.M1TreuilRetenue.State/Safety := WinchM1State/M1Safety (copie bloc, PRG_07:384-387)
```

**Conséquences concrètes :**
1. **Latence 1 scan garantie** : PRG_06 s'exécute **après** PRG_04 → le diag d'interlock que PRG_04 lit est celui du **scan N‑1**.
2. **Couplage à l'implémentation interne** : `instWinchOutputInterlockM1/M2` est une **instance** de FB, pas un contrat de bus → casse l'encapsulation T142.
3. **Aller‑retour en doublon** : `PowerCutOff`/`ErrorMecaA…` partent de PRG_04 → PRG_06 (agrégation) → reviennent dans PRG_04 → repartent à l'IHM. Même donnée transite 2× sur le bus à chaque scan.

---

## 2. Architecture cible — PRG_06 publie son propre bus de diagnostic

Le principe directeur : **la donnée vit à l'aval, là où elle est produite.** L'état final
de la barrière (interlock) appartient à PRG_06, pas à PRG_04. PRG_04 reste **producteur exclusif
des demandes** ; PRG_06 devient **producteur exclusif des états finaux barrière/diag**.

### 2.1 Nouveau bus de sortie PRG_06 : `Data.Diag`

```iecst
(* ST_OutputsDiag — Diagnostic de la barrière finale PRG_06, producteur unique PRG_06 *)
TYPE ST_OutputInterlockDiag :
STRUCT
    BrakeCmd            : BOOL;   // Ordre frein final validé
    State               : E_WinchFinalInterlockState;   // Etat machine d'etat interlock
    StateAtError        : E_WinchFinalInterlockState;   // Etat mémorisé au dernier défaut
    Reason              : E_WinchFinalInterlockReason;  // Cause de neutralisation/blocage
    Error               : BOOL;
    ErrorId             : WORD;
    RestartInhibit      : BOOL;
    BrakeTimeoutElapsed : TIME;
    RestartDelayElapsed : TIME;
    StepDelayElapsed    : TIME;
END_STRUCT

TYPE ST_OutputTransInterlockDiag :            (* symétrie M3 — enum translation *)
STRUCT
    BrakeCmd            : BOOL;
    State               : E_TranslationFinalInterlockReason;  (* réutilisé pour Cause + état *)
    Error               : BOOL;
    ErrorId             : WORD;
    RestartInhibit      : BOOL;
    BrakeTimeoutElapsed : TIME;
END_STRUCT

TYPE ST_OutputsDiag :
STRUCT
    WinchM1      : ST_OutputInterlockDiag;     // barrière finale treuil M1
    WinchM2      : ST_OutputInterlockDiag;     // barrière finale treuil M2
    TranslationM3: ST_OutputTransInterlockDiag;// barrière finale translation M3
    // Synthèses sécurité (déjà agrégées par PRG_06)
    M1PowerCutOffSafety : BOOL;
    M1SafeStopSafety    : BOOL;
    M1BlockedBySafety   : BOOL;
    M2PowerCutOffSafety : BOOL;
    M2SafeStopSafety    : BOOL;
    M2BlockedBySafety   : BOOL;
    M3PowerCutOffSafety : BOOL;
    M3SafeStopSafety    : BOOL;
    M3BlockedBySafety   : BOOL;
END_STRUCT
```

→ `PRG_06_Outputs` gagne `Diag : ST_OutputsDiag` (ou une extension de `ST_OutputsInterPrg`).

---

## 3. D1 — Supprimer la boucle PRG_04 → PRG_06

### 3.1 PRG_04_Treuils_Benne
- **Supprimer** les read-backs : `WinchM1State.{BrakeCmd,FinalInterlock*} := PRG_06_Outputs…` (L979-990) et `WinchM1Safety.{PowerCutOffSafety,SafeStopSafety,BlockedBySafety} := PRG_06_Outputs…` (L1104-1106), idem M2.
- **Retirer** des structs publics les champs désormais sans producteur amont :
  - `ST_WinchState` → `BrakeCmd`, `FinalInterlockState`, `FinalInterlockReason`, `FinalInterlockError`, `FinalInterlockErrorId`, `FinalRestartInhibit`, `FinalBrakeTimeoutElapsed`, `FinalRestartDelayElapsed`, `FinalStepDelayElapsed` (=> déplacés dans `ST_OutputInterlockDiag`).
  - `ST_SafetyWinch` → `PowerCutOffSafety`, `SafeStopSafety`, `BlockedBySafety` (=> déplacés dans `ST_OutputsDiag`).
- PRG_04 reste **producteur unique** des demandes et de l'état de contrôle (`ST_WinchInterPrg` allégé). Aucune dépendance à l'instance `PRG_06`.

### 3.2 PRG_06_Outputs
- Alimenter `Data.Diag.WinchM1/M2/TranslationM3` depuis les sorties des interlocks (`instWinchOutputInterlockM1/M2`, `instTranslationOutputInterlockM3`) **au scan courant**.
- Alimenter `Data.Diag.*Safety` depuis les agrégats déjà calculés (L100-116, L170-189, L243-256).

### 3.3 PRG_07_Supervision — assemblage IHM depuis 2 sources
Deux variantes (à trancher, cf. §7) :

- **Variante A (pureté producteur)** — `GVL_IHM.M1TreuilRetenue` n'est plus rempli par **une copie bloc** unique :
  - `GVL_IHM.M1TreuilRetenue.State := PRG_04.Data.WinchM1State;` (état de contrôle) **+**
  - `GVL_IHM.M1TreuilRetenue.FinalInterlockDiag := PRG_06.Data.Diag.WinchM1;` (nouveau champ IHM)
  - `GVL_IHM.M1TreuilRetenue.SafetyBlockedBy := PRG_06.Data.Diag.M1BlockedBySafety;` …
  - → chaque struct n'a **qu'un seul producteur**, IHM lit 2 bus **au scan courant** (PRG_07 s'exécute après PRG_06).
- **Variante B (moins intrusif)** — conserver les champs dans `ST_WinchState`/`ST_SafetyWinch`, mais les remplir **dans PRG_07** depuis `PRG_06.Data.Diag` (PRG_04 ne les touche plus).
  - ⚠️ viole « producteur unique » au niveau du champ (PRG_04 + PRG_07 remplissent la même struct).

> ✅ Recommandation : **Variante A** — elle seule élimine réellement le doublon et garde la pureté
> producteur, en accord avec T142 / CQS §2. Le coût (assemblage IHM sur 2 bus) est localisé à PRG_07.

---

## 4. D2 — Source de vérité unique pour `PowerCutOff`/`SafeStop`

Aujourd'hui le même fait (coupure/safestop) part de `instSafetyWinchM1.PowerCutOff` (PRG_04:1090) et
est publié **2 fois** : `WinchM1FinalInterlockRequest.PowerCutOff` (consommé PRG_06 L295-297 aggregation
`PowerCutOffReq`) **et** `WinchM1Safety.PowerCutOff` (consommé PRG_06 L100 diag).

| Option | Principe | Effet |
|---|---|---|
| **D2-A (recommandée)** | `PowerCutOff` vit **uniquement** dans `ST_WinchFinalInterlockRequest` (c'est la *demande brute* d'interlock → cohérent avec le rôle de la struct). `ST_SafetyWinch` ne garde que **`BlockedBySafety`** (synthèse IHM, alimentée par `ST_OutputsDiag` côté PRG_06). PRG_06 calcule les diag depuis la même source. | 1 seule source du fait, plus de doublon ni risque de désynchronisation. |
| D2-B | Inverser : `PowerCutOff` uniquement dans `ST_SafetyWinch`, PRG_06 lit la gate depuis `.Safety.PowerCutOff`. | Symétrique, mais la struct *demande* perd le signal de coupure qui la caractérise. |

> ✅ Recommandation : **D2-A** (respect du rôle des structs : *Request* porte la demande brute,
> *Safety* porte le diagnostic synthétique).

---

## 5. D3 — Commande drive M3 : monter sur le bus `Data`

| Option | Description | Effet |
|---|---|---|
| **D3-A (recommandée, esprit T142/T144)** | Ajouter à `ST_OutputsInterPrg` (ou `ST_OutputsDiag`/struct dédiée) les champs **`M3DriveControlWord : WORD`** et **`M3DriveFreqCmdWord : WORD`** (producteur unique PRG_06) ; `FB_SimBench` et le mapping E/S lisent **un seul bus**. | Bus auto-consistant, source sim + mapping = un seul endroit. **Impact mapping E/S CODESYS** : le geste manuel `%QW6/%QW7` reste, mais la source devient le bus Data. |
| D3-B | Laisser les 2 `VAR_OUTPUT` plats « cible mapping E/S ». | Zéro refactor, mais persiste l'asymétrie M3 vs M1/M2 (les ordres M1/M2 sont sur Data, pas M3). |

> ✅ Recommandation : **D3-A** — aligne M3 sur M1/M2 (esprit bus), tout en documentant que le
> raccordement PDO reste un geste CODESYS manuel (cf. `TROUBLESHOOTING_Translation_M3_v1.0.md` §8).

---

## 6. Impact fichier par fichier

| Fichier | Changement |
|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | ⬇️ suppression read-backs L979-990, L1104-1106 |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchState.st` | ⬇️ retrait des champs `FinalInterlock*`/`BrakeCmd` (si Var.A) |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_SafetyWinch.st` | ⬇️ retrait `PowerCutOffSafety`/`SafeStopSafety`/`BlockedBySafety` (si Var.A) |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchFinalInterlockRequest.st` | — (reste source de vérité de `PowerCutOff`, D2-A) |
| `CODE/M_MAIN/PRG_06_Outputs.st` | ⬆️ ajout `Data.Diag : ST_OutputsDiag`, alimentation interlocks + `*Safety` |
| Nouveau : `ST_OutputsDiag.st`, `ST_OutputInterlockDiag.st`, `ST_OutputTransInterlockDiag.st` | ⬆️ (dans `_TYPES/1_TREUILS_BENNE/` + `2_TRANSLATION/`) |
| `CODE/M_MAIN/PRG_07_Supervision.st` | 🔄 assemblage IHM depuis PRG_04.Data + PRG_06.Data.Diag |
| `GVL_IHM` / DUT `M1TreuilRetenue`/`M2TreuilBenne`/`TranslationM3` | 🔄 + champs diag barrière |
| `ST_OutputsInterPrg.st` | 🔄 + `M3DriveControlWord`/`M3DriveFreqCmdWord` (D3-A) |
| `CODE/J_SUPERVISION/FB_TroubleshootingView.st` | 🔄 vérifier lecture des nouveaux champs diag |
| `TOOLS/TEST_AUTO_CI/...` (voir §7) | 🔄 mises à jour des harnais & tests |

> ⚠️ Le périmètre **safety-adjacent** (PRG_06, interlocks) impose : contrat de tâche (C2), validation
> humaine, gates mécaniques (G200 liaison, G310, 21 gates), bundle frais.

---

## 7. Couverture tests / impact CI

| Test / Harnais | Impact |
|---|---|
| `test_prg_06_outputs.st` | ✅ + assertions `Diag.WinchM1/M2` et `*Safety` |
| `FB_TestHarness_PRG_06.st` | 🔄 expose `Data.Diag` |
| `test_prg_04_treuils_benne.st` | 🔄 retirer les assertions sur le read-back supprimé |
| `FB_TestHarness_PRG_04.st` | 🔄 ne lit plus `instWinchOutputInterlockMx` |
| `test_prg_07_supervision.st` | 🔄 vérifier `GVL_IHM` assemblé depuis 2 bus |
| `FB_Main_EndToEnd.st` / HARN-51/52 | 🔄 vérifier `FinalInterlockGoverned` via bus PRG_06 (recoupe T181-01) |
| `FB_Acquisition_Preflight` (invariant AF-06 §6 « seul PRG_06 écrit les Q ») | ✅ inchangé |

**Non-régression exigée** : logique métier M1/M2 intacte (seul le transport du diag change), exécutable
identique sur la partie barrière, `G200 0 erreur`, palier C 15/15.

---

## 8. Risques & points à valider humain

| # | Question | Impact si non tranché |
|---|---|---|
| Q1 | **Variante A ou B** pour l'assemblage IHM (pureté producteur vs intrusivité) ? | Structure de `GVL_IHM`/DUT IHM |
| Q2 | **D2-A ou D2-B** (où vit `PowerCutOff`) ? | Contrat `FinalInterlockRequest` vs `SafetyWinch` |
| Q3 | **D3-A ou D3-B** (drive M3 sur bus vs VAR_OUTPUT plat) ? | `ST_OutputsInterPrg` + mapping E/S |
| Q4 | Faut-il **fusionner** ce design avec **T181-01** (bus diag `FinalInterlockGoverned`) pour éviter 2 refactors du même `PRG_06` ? | Séquencement & effort |
| Q5 | Latence 1 scan du diag IHM : acceptable (10 ms) mais à **acté par écrit** quel que soit le choix. | — |

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| Tâches | T144 · T142 · T121 · T181-01 |
| Design précédent | `DESIGN_T144_ASSAINIR_PRG06_v0.1.md` |
| AF | `AF_Partie-06…IO_v2.4.md` §6 · `AF-10` (winch) · `AF-11` (translation) · `AF_Fiche_PRG_06_Outputs_v1.0.md` |
| Standard | `CODE_QUALITY_STANDARDS.md` §2 (producteur unique) · `NAMING_CONVENTION.md` NC-050 |
| Troubleshooting M3 | `TROUBLESHOOTING_Translation_M3_v1.0.md` §8 (mapping E/S manuel) |
