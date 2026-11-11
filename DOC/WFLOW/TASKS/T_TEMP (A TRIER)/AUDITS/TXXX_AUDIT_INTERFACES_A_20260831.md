# 🔎 Audit A — Interfaces globales : homogénéité & optimisation

> 🗓️ **Date** : 2026-08-31
> 🎯 **Portée** : FBs d'arbitrage, FBs de mouvement, DUT/structs, PRG (code `CODE/`) vs
> `DOC/STDS/` (CODE_QUALITY_STANDARDS, NAMING_CONVENTION, AF_Partie-03 §profils).
> ✅ Échantillon : ~10 FBs lus en entier (WinchCmdArbitration M1/M2, BucketCmdArbitration,
> TranslationCmdArbitrationM3, Winch, Translation, WinchOutputInterlock, TranslationOutputInterlock,
> Winch_Symmetry, Joystick) + structs IHM/Cfg/Context + grep liaison PRG_04/PRG_05.

---

## 🧾 Synthèse verdicts

| # | Fait | Axe | Verdict | Safety |
|---|---|---|---|---|
| H1 | Barrière finale : `FB_WinchOutputInterlock` (défaut à plat) vs `FB_TranslationOutputInterlock` (`ST_Fault`) | Homogénéité | **À CORRIGER** | faible |
| H2 | `FB_Winch` (structs) vs `FB_Translation` (~13 scalaires `[CFG]`) | Homogénéité | **À CORRIGER** | nul |
| H3 | Sorties mouvement arbitrées : palier `INT` (Winch) vs `% REAL` + Positionning (M3) | Homogénéité | OK (justifié) | nul |
| O1 | `SpeedStepTable` inutilisé sur `FB_WinchCmdArbitrationM1` **et** M2 (+ PRG_04) | Optimisation | **À CORRIGER** | nul |
| O2 | `Mode : E_Mode` **inutilisé** sur `FB_Translation` | Optimisation | **À CORRIGER** | nul |
| O3 | `ST_fbWinchCmdArbitration_IHM` sur-dimensionnée par axe | Optimisation | à faire | nul |
| O4 | `Cfg` d'arbitrage assigné en dur dans PRG_04 (défauts déjà `5`/`1`) | Optimisation | observation | nul |
| S1 | `FB_Winch_Symmetry` : ni contrat `light` (Enable+Ready) ni `standard` | Standards | **À CORRIGER** | nul |
| S2 | `ST_fbModes_Autorisations` porte le préfixe `ST_fb*` mais est un bus multi-consommateurs | Standards | **À CORRIGER** | nul |
| S3 | FBs d'arbitrage en contrat `light` (pas de `Fault`) — cohérent | Standards | OK | — |
| P1 | Duplication `FB_WinchCmdArbitrationM1` ↔ M2 (~90 %) | POO | RISQUE | faible |
| P2 | Socle `FB_FaultCore` généralisé, structs NC-110, producteur unique | POO | OK | — |

---

## 📂 Axe 1 — Homogénéité des interfaces FB

### 🔴 H1 — Barrières finales : deux formes de défaut incompatibles
`FB_WinchOutputInterlock` (barrière frein/puissance M1/M2) expose le défaut **à plat legacy**
(`Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`, `Reason`), alors que
`FB_TranslationOutputInterlock` (barrière **même rôle**, M3) expose la **forme cible**
`Fault : ST_Fault` (+ `Reason`, sans `Busy/Done/Error`).
- **Verdict** : À CORRIGER.
- **Impact safety** : faible — la logique d'interlock reste intacte. Mais l'**inhomogénéité
  du contrat de défaut** entre deux blocs de rôle identique (même consommateur IHM/diag)
  crée un risque de dérive de maintenance et deux chemin d'acquittement différents.
- **Preuve** : `FB_WinchOutputInterlock.st:44-73` (flat) vs `FB_TranslationOutputInterlock.st:26-39` (`Fault:ST_Fault`).
- **Action** : migrer `FB_WinchOutputInterlock` vers `Fault : ST_Fault` via une instance
  `FB_FaultCore` (déjà utilisé partout ailleurs), aligner sur T164-5. Le `StateAtError`/`Reason`
  restent portés par les enums dédiés.

### 🔴 H2 — FB de mouvement : Winch structuré vs Translation à scalaires
`FB_Winch` regroupe requête/mesures/config en `DriveRequest : ST_fbWinch_DriveRequest`,
`Sensors : ST_fbWinch_Sensors`, `Config : ST_fbWinch_Cfg`. `FB_Translation`, lui, ouvre
**~13 scalaires `[CFG]`** (`CfgRampAccelRate`, `CfgRampDecelNormalRate`, `CfgRampDecelFastRate`,
`DirectionInterlockDelay`, `ApproachSpeedTremie/Maintenance/P1_Hz`, `DriveFreqScaleMaxHz`,
`CaptorDebounce`, `BrakeDelayContactClose/Magnetise/MotorDecel`, `BrakeFeedbackTimeout`) + commandes
en scalaires (`StartStop`, `Direction`, `SpeedTgt_Pct`).
- **Verdict** : À CORRIGER.
- **Preuve** : `FB_Winch.st:19-35` (structs) vs `FB_Translation.st:40-58` (13 scalaires).
- **Impact** : contredit la règle §2quinquies / NAMING (`Cfg : ST_fb<Fb>_Cfg` — « un FB qui porte
  plusieurs paramètres de conditionnement/tuning les regroupe dans une seule entrée Cfg »).
  Lisibilité et homogénéité ; aucun impact safety direct.
- **Action** : regrouper les 13 scalaires + capteurs/bornes dans `Cfg : ST_fbTranslation_Cfg`
  (lot de migration, mapping IHM + persistence alignés), comme Winch/Joystick.

### 🟢 H3 — Sorties mouvement arbitrées : palier vs pourcentage
`FB_WinchCmdArbitrationM1/M2` → `StepTgt : INT` (palier 1..5) ; `FB_TranslationCmdArbitrationM3`
→ `SpeedPct : REAL` (0..100 %) + `PositioningActive` + `SelTarget`.
- **Verdict** : OK (justifié). La représentation suit le hardware (contacteurs à palier côté treuil,
  AC600 %/Hz côté translation). À noter comme **RISQUE de lisibilité** : deux vocabulaires pour
  « consigne vitesse arbitrée » — maintenir si un jour un axe homogénéise, sans le forcer.

---

## ⚙️ Axe 2 — Optimisation des interfaces

### 🔴 O1 — `SpeedStepTable` : paramètre mort sur les 2 arb. treuil
`SpeedStepTable : ST_SpeedStepTable` est **déclaré** sur `FB_WinchCmdArbitrationM1.st:28` et
`M2.st:29`, **jamais lu** dans le corps (« conservée pour compat interface ; plus de conversion
%→palier ici »), et **recâblé** depuis `PRG_04_Treuils_Benne.st:368` et `:391`
(`SpeedStepTable := _WinchSpeedStepTable`).
- **Verdict** : À CORRIGER.
- **Preuve** : grep `SpeedStepTable` → absent du corps des 2 FBs ; présent aux 2 call-sites.
- **Impact** : interface trompeuse + envoi inutile d'une structure à chaque scan ; viole
  `CODE_QUALITY §4` (variable déclarée jamais lue). Safety nul — la table reste utilisée par
  `FB_Winch` via `Config.SpeedStepTable` (`PRG_04:899/947`), donc le retrait est **sûr**.
- **Action** : supprimer l'entrée des 2 FBs et des 2 appels PRG_04.

### 🔴 O2 — `Mode : E_Mode` inutilisé sur `FB_Translation`
`Mode` est déclaré (`FB_Translation.st:19`) mais **aucune référence dans le corps** (grep : 1 seule
occurrence = la déclaration). La sélection de mode est déjà faite en amont par l'arbitrage.
- **Verdict** : À CORRIGER (retrait du paramètre mort) — même nature que O1.

### 🟠 O3 — `ST_fbWinchCmdArbitration_IHM` sur-dimensionnée par axe
La struct partagée porte les boutons des **2 axes** (`BtnUpM1/BtnDownM1/BtnUpM2/BtnDownM2`) + both ;
`FB_…M1` ne consomme que `BtnUpM1/BtnDownM1`, `FB_…M2` que `BtnUpM2/BtnDownM2`. Les champs « both »
de la struct (`BtnWinchBothUp/Down`) ne sont même pas lus : l'intention both arrive via
`BothIntent` (source PRG_03).
- **Verdict** : optimisation mineure (un struct d'axe `BtnUp/BtnDown` par FB + both via `BothIntent`).

### 🟡 O4 — `Cfg` d'arbitrage assigné en dur dans PRG_04
`ArbM1Cfg.BtnStepTgt := 5` / `ArbM2Cfg.BucketOverrideStepTgt := 1` (`PRG_04:353-355`) redondent les
défauts `:= 5` / `:= 1` du DUT `ST_fbWinchCmdArbitration_Cfg.st:14-15`. Assignation morte.
- **Verdict** : observation — retirer ou passer par une vrai config persistante si les paliers
  devaient devenir réglables (sinon fixés par conception).

---

## 📐 Axe 3 — Conformité standards

### 🔴 S1 — `FB_Winch_Symmetry` hors contrat (`light`/`standard`)
Interface sans `Enable` ni `Ready` (ni l'un ni l'autre), avec `Reset` seul + `Config` struct
(`FB_Winch_Symmetry.st:10-42`). Ne relève ni du contrat `light` (Enable+Ready) ni du `standard`
(Enable+Reset+Ready+Fault).
- **Verdict** : À CORRIGER. Observeur **pur** (aucune écriture de commande) → au minimum documenter
  un contrat dédié ou ajouter `Enable`/`Ready` (préférable pour cohérence Watch/guard G315).
- **Impact safety** : nul (bloc passe-observateur).

### 🔴 S2 — `ST_fbModes_Autorisations` : préfixe `ST_fb*` sur un bus multi-consommateurs
`NC-110` réserve `ST_fb<NomFb>_` aux DUT « référencé dans l'interface d'**exactement un** FB ».
Or `ST_fbModes_Autorisations` est consommé par **≥6 domaines** (Cycle, Safety, Treuils, Translation,
Supervision, Acquisition) — c'est un **bus public de domaine**, qui devrait être `ST_Modes_Autorisations`.
- **Verdict** : À CORRIGER (renommage en lot dédié, NC-090/NC-110). Non bloquant.

### 🟢 S3 — FBs d'arbitrage en contrat `light` : cohérent
Les FBs d'arbitrage (Winch M1/M2, Bucket, Translation M3) exposent `Enable`+`Ready`=Enable, `Fault`
**absent** — correct : ils ne remontent aucun défaut, ne pilotent pas d'organe → `light`/pas de
`ST_Lifecycle`. Aucune occurrence fautive de `SafeStop`/`StartStop` hors FB de mouvement (vérifié).

> ✅ Bonne nouvelle : plus aucun FB ne porte `Status : ST_Status` (grep : seule la **définition de
> type** `ST_Status.st` reste). La migration des 17 FB legacy documentée en v2.4 est **effective sur
> le code courant**. Point fort confirmé.

---

## 🧩 Axe 4 — Vue globale POO

### 🟠 P1 — Duplication `FB_WinchCmdArbitrationM1` ↔ M2
~90 % du corps commun (same structure Enable→SEMI_AUTO→manuel→gating StartStop). Seules différences :
bouton d'axe (M1/M2), valeur `Select` (1/2), inversion des blocs synchro (M1 up-sync↔M2 down-sync),
et le **chemin benne** présent sur M2 seul.
- **Verdict** : **RISQUE** (pas une faute). Le refactor POO a bien délégué la décision du PRG dans
  les FBs, mais a **dupliqué** au lieu de factoriser. À rapprocher d'un `FB_WinchCmdArbitration`
  unique paramétré par axe (+ chemin benne conditionnel) à terme — **ne pas forcer maintenant**
  (comportement bit-identique assumé, priorité au safety).
- Impact safety : faible (doublon = risque de divergence future d'un correctif appliqué à M1 et
  oublié sur M2).

### 🟢 P2 — Architecture globalement saine
- `FB_FaultCore` socle **généralisé** (Winch, Translation, Joystick, Bucket, Encoder, Safety, Cycle…)
  → remplissage `Fault : ST_Fault` standardisé. ✅
- Structs récentes conformes `NC-110` (`ST_fbWinch_Cfg`, `ST_fbJoystick_Cfg`,
  `ST_fbWinchCmdArbitration_*`, `ST_fbWinch_Symmetry_Cfg/Data`). ✅
- **Producteur unique** respecté : `Auth` produit par `FB_Modes` (PRG_03), `ReqProgram` par PRG_03,
  `BothIntent` `ST_WinchBothIntent` produit par PRG_03, consommé lire-seule par les arb. ✅
- Arbitrage **delegué dans le FB** (« décision dans le FB, plus dans le PRG », `PRG_04 §3`) ✅.

### 🟡 P3 — `Auth` sur-dimensionné pour le mouvement
`ST_fbModes_Autorisations` contient 7 autorisations + 3 **faits publiés** (`ModeChangePendingBlocked`,
`HomingRequiredM1/M2`, commentés « faits, pas des autorisations »). Passé tel quel aux FBs d'arbitrage
mouvement, qui ne lisent que `Mode`/`JoystickWinchSelectArbitrated`. Léger — voir S2 (renommage) pour
séparer les 3 faits IHM du bus d'autorisation.

### 🟡 P4 — Nom de fichier ≠ nom de type
`CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_OperatorCoupledIntent.st` contient `TYPE ST_WinchBothIntent`
(incohérence nom fichier / contenu). Mineur, à corriger à l'occasion d'un lot de renommage.

---

## 🎯 Actions prioritaires

1. **Supprimer les paramètres morts** : `SpeedStepTable` (FB_WinchCmdArbitrationM1/M2 + PRG_04:368/391)
   et `Mode : E_Mode` (`FB_Translation`). → optimisation immédiate, non bloquant, aucun risque
   (`table` encore consommée par FB_Winch). *Prévoir pour `Mode` : confirmer qu'aucun consommateur
   externe ne lit `instTranslation.Mode` avant retrait (grep G200).*
2. **Migration `FB_WinchOutputInterlock` vers `Fault : ST_Fault`** (aligner la barrière M1/M2 sur la
   barrière M3, forme cible T164-5) — plus gros chantier d'homogénéité, sécurité non défaite mais
   contrat à unifier avant toute évolution de la chaîne barrière.
3. **Regrouper la config `FB_Translation` dans `Cfg : ST_fbTranslation_Cfg`** (13 scalaires `[CFG]`)
   pour aligner sur Winch/Joystick (§2quinquies / NAMING). Lot de migration avec mapping persistence/IHM.
4. **Corriger `FB_Winch_Symmetry`** : ajouter `Enable`/`Ready` (ou documenter un contrat dédié) pour
   sortir du hors-contrat G315.
5. **Renommage `ST_fbModes_Autorisations` → `ST_Modes_Autorisations`** (bus multi-consommateurs ≠ NC-110).
6. **À planifier (pas urgent)** : factoriser `FB_WinchCmdArbitrationM1/M2` en un FB paramétré (P1) ;
   retirer l'assignation `Cfg` en dur redondante (O4).

> Règles citées : `CODE_QUALITY_STANDARDS.md §2quinquies, §4, §5, §9` · `NAMING_CONVENTION.md NC-110,
> NC-090` · `AF_Partie-03 §3 (profils light/standard), §4`.
