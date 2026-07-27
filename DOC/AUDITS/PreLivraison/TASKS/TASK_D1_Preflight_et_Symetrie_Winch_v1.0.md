# 🩺 FICHE DE TÂCHE — Lot D1 : `FB_Preflight` + `FB_WinchSymmetry`

> 🤖 **Agent d'implémentation externe — fiche autoportante.**
> 📅 2026-07-27 · **v1.0** · 🟢 risque faible : **deux observateurs purs, aucune logique existante modifiée**
> ⏱️ Prérequis : lots T80, L2→L8 appliqués (chantier simulation terminé).

---

## 1. 🏭 Contexte

Automate **CODESYS 3.5**, machine spéciale : **excavatrice de dragage** en carrière noyée, ~10 000
lignes de **ST**. 3 axes : **M1** treuil de retenue, **M2** treuil de benne, **M3** translation
(variateur AC600 EtherCAT). Sécurité : chaîne AU câblée + `PowerCutOff` logiciel redondant A/B,
blocs `FB_Safety_*` (gardes mécaniques Méca A→E).

Orchestration séquentielle, tâche 10 ms : `PRG_00_Inputs` → … → `PRG_10_Outputs` →
**`PRG_11_Troubleshooting`** (espion, **100 % lecture seule**, alimente `GVL_Troubleshooting`
par fonction machine et par couche : `Inputs_100` → `Commandes_200` → `Sécurités_300` →
`Autorisations_400` → `Sorties_500`).

⚠️ **Machine en cours de mise en service, livraison client imminente.**
⚠️ **L'utilisateur applique tout MANUELLEMENT** dans CODESYS. Tu ne compiles pas, tu ne déploies
pas, tu ne commites pas.

### 📚 Lectures obligatoires

`CLAUDE.md` · `DOC/NAMING_CONVENTION.md` · `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md` (contrat FB) ·
`CODE/MAIN/PRG_11_Troubleshooting.st` · `CODE/MAIN/PRG_00_Inputs.st` ·
`CODE/TREUILS/FB_Safety_Winch.st` · `DOC/REGISTRE_Suivi_MiseEnService_v1.0.md` (entrées MES-006 à MES-010)

---

## 2. 🎯 Bloc 1 — `FB_Preflight` : verdict d'état machine avant mouvement

### Le besoin

Aujourd'hui, on démarre la machine et on **découvre** les défauts en mouvement. Or **machine à
l'arrêt, aucune commande active, l'état de chaque retour est prévisible**. Ce bloc compare le réel
à l'attendu et rend un **verdict unique** avant de bouger.

C'est ce qui aurait détecté le bug **C1** (polarité de retour frein inversée) dès le premier
démarrage, au lieu de le laisser dormir jusqu'au câblage réel.

> 🎯 Différence avec `PRG_11` : `PRG_11` **montre** 40 valeurs, à l'opérateur de les interpréter.
> `FB_Preflight` **conclut**.

### Table des états attendus (machine à l'arrêt, aucune commande)

| Signal | Attendu | Bit d'anomalie si faux |
|---|---|---|
| `M1/M2/M3BrakeFeedback` (normalisé) | `TRUE` = frein **serré** | frein desserré au repos ou **polarité inversée** |
| `M1/M2FwdRevSpeedFeedbackOff` | `TRUE` = tous contacteurs retombés | **contacteur collé** |
| `M1/M2ThermalFeedback` | `TRUE` | thermique ou fil coupé |
| `BrakeThermalFeedback` | `TRUE` | thermique frein commun |
| `PhaseRotationOk` | `TRUE` | phases inversées/absentes |
| `SlackCableSwitch` | `TRUE` = câble tendu | mou de câble |
| Mot 5 capteurs M3 | **un des 6 codes valides** | incohérence de câblage |
| `EmergencyChain` ↔ `EmergencyStopOk` | cohérents entre eux | câblage AU |
| Codeurs M1/M2 | device `Operational`, position dans les bornes | bus ou référencement |
| `Homed` M1/M2 | à signaler si `FALSE` | référencement absent |

🔎 **Vérifie chaque nom et chaque polarité dans le code réel** avant de l'écrire. Ne devine aucune
convention : `PRG_00_Inputs` sort « TRUE = sain » pour les capteurs NC, mais certains consommateurs
inversent (ex. `PRG_03_Safety:42`). Tu observes les sorties de `PRG_00_Inputs`, pas les `_DI` bruts.

### Interface

```
FB_Preflight        // 🧱 brique réduite (Partie 3 §1bis) — diagnostic, pas de StartStop/SafeStop
VAR_INPUT
    Execute          : BOOL;   // front montant = lance le contrôle
    MachineIsStill   : BOOL;   // aucune commande de mouvement active
VAR_OUTPUT
    PreflightOk      : BOOL;   // ✅ tous les contrôles conformes
    PreflightDone    : BOOL;   // contrôle exécuté (verdict disponible)
    PreflightErrorId : WORD;   // bitfield ≤ 16 anomalies (doctrine projet)
    PreflightBusy    : BOOL;
```

### Règles

| # | Règle |
|---|---|
| **R1** | **Contrôle uniquement machine à l'arrêt.** Si `MachineIsStill = FALSE` → `PreflightBusy := FALSE`, aucun verdict, `PreflightDone := FALSE` |
| **R2** | **INFORMATIF, JAMAIS BLOQUANT.** Ce bloc ne déclenche aucun `SafeStop`, aucun `PowerCutOff`, n'écrit dans aucune variable métier, ne bloque aucun mouvement |
| **R3** | Déclenché **sur front** de `Execute` (bouton IHM) **et une fois au boot**. Jamais en boucle |
| **R4** | Le résultat reste affiché jusqu'au contrôle suivant (pas d'effacement automatique) |
| **R5** | Documenter chaque bit d'`ErrorId` en commentaire, avec l'attendu et la cause probable |

### Intégration

- Instancier dans **`PRG_11_Troubleshooting`** (déjà le programme de diagnostic lecture seule).
- Alimenter depuis les sorties de `PRG_00_Inputs` / `PRG_02_Encoders` — **réutilise ce que
  `GVL_Troubleshooting` rassemble déjà** plutôt que de refaire une collecte.
- Publier vers l'IHM : `PreflightOk`, `PreflightErrorId`, `PreflightDone` dans `GVL_IHM.Commun`
  (nouvelle sous-struct dédiée) + un bouton `BtnPreflightRun`.
- ⚠️ **N'ajoute aucun champ à `ST_IHM_MANU`** (table figée, transmise à un tiers).

---

## 3. 🎯 Bloc 2 — `FB_WinchSymmetry` : détecter une dissymétrie M1 / M2

### Le besoin (constat terrain réel)

`MES-008` : *« L'opérateur constate une différence de comportement à l'arrêt entre M1 et M2. Il est
nécessaire de lever l'ambiguïté entre une dissymétrie de commande automate et un retard
mécanique/hydraulique propre au frein d'un des treuils. »*

Objectif : **détecter de façon sûre, avant la mise en service, un pilotage incohérent ou un
décalage entre les deux treuils.**

### Mesures — par axe, puis en écart

| Mesure | Comment | Ce que l'écart révèle |
|---|---|---|
| `StartDelay_Ms` | commande relais → premier mouvement codeur détecté | un treuil démarre après l'autre |
| `BrakeReleaseTime_Ms` | `BrakeCmd` desserrage → `BrakeFeedback` desserré | **frein lent, usé ou mal réglé** |
| `BrakeApplyTime_Ms` | `BrakeCmd` serrage → `BrakeFeedback` serré | idem, côté serrage |
| `StopDistance_M` | position à la coupure de commande → position finale stabilisée | un treuil glisse plus que l'autre |
| `StopTime_Ms` | coupure de commande → vitesse nulle | décélération dissymétrique |
| `MaxSyncDeviation_M` | pire `DeltaPosM` atteint depuis le reset | amplitude réelle du désynchronisme |

**Sorties d'écart** (le cœur du bloc) : `DeltaStartDelay_Ms`, `DeltaBrakeReleaseTime_Ms`,
`DeltaBrakeApplyTime_Ms`, `DeltaStopDistance_M`, `DeltaStopTime_Ms`.

**Verdict** : `SymmetryOk : BOOL` — `FALSE` si un écart dépasse son seuil.
Seuils **réglables** en `PERSISTENT` (valeurs initiales à proposer, à confirmer sur site).

### Règles

| # | Règle |
|---|---|
| **R1** | **Mesure passive.** Aucun asservissement, aucun défaut, aucun blocage de mouvement. Jamais utilisé comme condition de sécurité |
| **R2** | **Mesures valides uniquement sur mouvement franc** : une commande maintenue au-delà d'un seuil de durée et de vitesse. Les micro-déplacements et les à-coups sont **ignorés**, sinon les chiffres sont du bruit |
| **R3** | Écarts calculés **uniquement quand les deux treuils ont été sollicités de façon comparable** (même sens, mode couplé ou séquence équivalente). Sinon `SymmetryValid := FALSE` |
| **R4** | Conserver **dernière valeur** et **valeur max** de chaque mesure, avec un reset explicite sur front (`BtnSymmetryReset`) |
| **R5** | Les valeurs max survivent au redémarrage → `PERSISTENT` |

### Intégration

- Instancier dans **`PRG_11_Troubleshooting`**.
- Entrées depuis `PRG_10_Outputs` (commandes), `PRG_00_Inputs` (retours frein/contacteurs),
  `PRG_02_Encoders` (positions), `PRG_06_WinchControl` (`instWinchSync.DeltaPosM`, `SpeedRamp`).
- Publier dans `GVL_IHM.Commun` (même sous-struct que Preflight) : les écarts + `SymmetryOk`.

---

## 3bis. 📌 Précisions (2026-07-27, suite au blocage de l'agent)

### A. 🐛 Correctif de libellé `PRG_11` — **inclus dans ce lot**

Incohérence confirmée : la déclaration annonce l'inverse de ce qui est publié.

```
ST_Chain_Winch_Inputs.st:6      Idx104_BrakeIsOpen_DI : BOOL;  // 1 = Frein Ouvert | 0 = Frein Serré
PRG_11_Troubleshooting.st:58    Idx104_BrakeIsOpen_DI := PRG_00_Inputs.M1BrakeFeedback;
                                                          └─ TRUE = frein SERRÉ (après normalisation)
```

👉 Le diagnostic **affiche l'inverse de la réalité**. À corriger avant de construire le Preflight
dessus.

**Correction retenue : aligner le NOM sur la valeur** (et non l'inverse), car toute la logique aval
(`FB_Safety_Winch` Méca A/B/D/E, `FB_Brake`, homing) raisonne en « TRUE = frein serré ». Introduire
une seconde convention dans le diagnostic recréerait le piège de C1.

| Fichier | Avant | Après |
|---|---|---|
| `ST_Chain_Winch_Inputs.st` | `Idx104_BrakeIsOpen_DI` — *« 1 = Frein Ouvert »* | **`Idx104_BrakeApplied`** — *« TRUE = frein SERRÉ (valeur normalisée `PRG_00_Inputs`, après `BrakeFeedbackInvertLogic`) »* |
| `ST_Chain_Translation_Inputs.st` | `Idx108_BrakeIsOpen_DI` | **`Idx108_BrakeApplied`** — même commentaire |
| `PRG_11` l. 58, 98, 160 | — | mettre à jour les 3 affectations |

⚠️ Le suffixe `_DI` est retiré : ce n'est plus la valeur brute d'entrée mais la valeur **normalisée**.
Ne touche à rien d'autre dans `PRG_11`.

### B. Définition de `MachineIsStill`

```
MachineIsStill :=     NOT (M1RelayFwd OR M1RelayRev OR M1SpeedContactor1..4)
                  AND NOT (M2RelayFwd OR M2RelayRev OR M2SpeedContactor1..4)
                  AND (M3_CommandWord = 0)
                  AND NOT M1BrakeCmd AND NOT M2BrakeCmd AND NOT TranslationBrakeCmd
```

Toutes ces variables sont des sorties de `PRG_10_Outputs` — **vérifie leurs noms exacts dans le
fichier**. Rappel : `BrakeCmd = TRUE` signifie **desserrage commandé**, donc `NOT BrakeCmd` =
frein commandé serré.

⏱️ La condition doit être **stable depuis 2 s** (`TON`) avant qu'un verdict soit rendu — sinon on
mesure un transitoire. M3 n'a plus de relais de sens en sortie (supprimés) : son activité se lit
**uniquement** sur `M3_CommandWord`.

### C. Seuils initiaux `FB_WinchSymmetry`

Valeurs de départ, **à confirmer sur site** — à placer en `PERSISTENT`, réglables sans recompiler.

| Seuil | Valeur initiale | Justification |
|---|---|---|
| `DeltaStartDelay_Ms` | **100 ms** | Un contacteur réel répond en ~40 ms ; 100 ms d'écart entre les deux treuils est déjà significatif |
| `DeltaBrakeReleaseTime_Ms` | **100 ms** | Temps de réponse frein documenté à 100–300 ms (`FB_Brake`) |
| `DeltaBrakeApplyTime_Ms` | **100 ms** | idem, côté serrage |
| `DeltaStopDistance_M` | **0,10 m** | La tolérance de synchro est de 0,25 m (`CfgSyncTolerance_M`) : 0,10 m est notable sans être alarmiste |
| `DeltaStopTime_Ms` | **200 ms** | Cohérent avec les rampes de décélération |

**Conditions de « mouvement franc »** (règle R2), également en `PERSISTENT` :

| Paramètre | Valeur initiale |
|---|---|
| Durée minimale de commande maintenue | **1 s** |
| Vitesse mesurée minimale | **0,05 m/s** (2,5× le seuil Méca A de 0,02 m/s, pour rester hors du bruit de quantification) |

⚠️ Ces valeurs sont des **points de départ pour la mise en service**, pas des valeurs validées.
Documente-les comme telles dans le code et dans ton rapport.

## 4. ⛔ Interdictions

- ❌ **Aucune modification de la logique existante** : ni `FB_Safety_*`, ni `FB_Winch`, ni
  `FB_Brake`, ni `FB_Cycle`, ni `PRG_00`→`PRG_10`. Seules exceptions : les appels d'instanciation
  dans `PRG_11` et la publication IHM dans `PRG_09`
- ❌ Aucun `SafeStop`, `PowerCutOff`, `ErrorId` métier déclenché par ces blocs
- ❌ Aucune écriture dans une variable de commande ou de sécurité
- ❌ Aucun champ dans `ST_IHM_MANU`
- ❌ Aucun renommage
- ❌ Aucun commit

---

## 5. 🛑 Pièges

| # | Piège |
|---|---|
| **P1** | **Polarités.** `PRG_00_Inputs` sort « TRUE = sain » / « TRUE = frein serré » (après inversion). Ne réinvente aucune convention : lis les commentaires de `PRG_00_Inputs` §1, ils la donnent signal par signal |
| **P2** | **Bruit de mesure.** Sans la règle R2, `StartDelay` et `StopDistance` seront pollués par les micro-mouvements et deviendront inexploitables — le bloc sera ignoré |
| **P3** | **Preflight non bloquant.** Un préflight bloquant sur faux positif immobiliserait la machine. En v1, il informe, un point c'est tout |
| **P4** | **Ordre d'exécution.** `PRG_11` s'exécute **après** `PRG_10` : tu lis des valeurs du **même** scan pour les entrées et les sorties. C'est voulu |
| **P5** | Le mot capteurs M3 a **6 codes valides** (`11111`, `01111`, `00111`, `00011`, `00001`, `00000`). Ne réimplémente pas le décodage : `FB_Translation_PositionDecoder` existe |

---

## 6. 🚨 Devoir d'alerte

Arrête-toi et signale — **sans rien modifier** — si tu constates :

- un état « attendu à l'arrêt » que le code contredit (⚠️ **cela peut révéler un vrai défaut de
  câblage ou de polarité : c'est précieux, signale-le explicitement**) ;
- une incohérence avec `DOC/AF_Partie-*.md` ou `CLAUDE.md` ;
- un écart aux standards d'automatisme (sécurité positive, reset sur front, état sûr en défaut) ;
- tout doute sur une chaîne de sécurité.

👉 **N'invente rien, ne devine aucune polarité ni aucun seuil.**

---

## 7. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_D1_v1.0.md` :

- interface complète des deux FB
- **table des bits d'`ErrorId` de `FB_Preflight`** : bit · signal · état attendu · cause probable
- pour chaque mesure de `FB_WinchSymmetry` : méthode de calcul, condition de validité, seuil proposé
- confirmation : aucune écriture métier, aucun blocage possible (donne la preuve)
- tes alertes

### ✅ Critères de sortie

- [ ] Deux observateurs purs : zéro écriture hors leurs propres sorties et la publication IHM
- [ ] `FB_Preflight` : verdict à l'arrêt seulement, sur front, informatif
- [ ] `FB_WinchSymmetry` : mesures gardées par la condition de mouvement franc (R2)
- [ ] Polarités vérifiées dans le code, aucune supposée
- [ ] `ErrorId` en bitfield ≤ 16, chaque bit documenté
- [ ] Style ST du projet : commentaires **français**, emoji, en-têtes `(* … *)`

### 🧪 Validation (par l'utilisateur)

1. Compilation 0 erreur
2. Machine saine à l'arrêt → `PreflightOk = TRUE`
3. Débrancher volontairement un retour → le bit correspondant se lève, **et la machine reste pilotable**
4. Mouvement M1 puis M2 dans les mêmes conditions → les écarts se remplissent, `SymmetryOk` cohérent
5. Mouvement couplé → `MaxSyncDeviation_M` plausible
