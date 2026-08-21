# 🧭 T146 — Traçage décisions & actions : Référencement / Homing des codeurs

> 📅 Démarrage 2026-08-21 · 📄 **ÉTUDE PUR (zéro code, rien n'est modifié)**
> 🎯 Suivi « tout ce qu'on dit, tout ce qu'on veut faire, tout ce qu'on acte » pour T146
> (référencement/homing codeurs : états incohérent/suspect/référencé + fiabilité de la mesure).
> 📎 Tâche : [`../PLAN_TASK.md`](../PLAN_TASK.md) → T146 · Docs liées : [`REVUE_REFERENCEMENT_CODEURS_v0.1.md`](REVUE_REFERENCEMENT_CODEURS_v0.1.md) · [`REVUE_SYNCHRO_TREUILS_v0.1.md`](REVUE_SYNCHRO_TREUILS_v0.1.md)

---

## ✅ Décisions actées

| # | Décision | Détail |
|---|---|---|
| D-A1 | **Étude pure** | Aucune modification de code tant que l'étude T146 n'est pas validée. |
| D-A2 | **Responsabilité des états codeur → `FB_Encoder_Homing`** | Toute la chaîne état codeur / mesure fiable doit être **produite par `FB_Encoder_Homing`** (le bloc responsable de la mesure fiable), pas assemblée dans `PRG_02`. |
| D-A2bis | **`HomedAndReliable` produit par un helper pur `FB_EncoderReliability`** | ⚠️ **Révisé (revue externe + décision utilisateur)** : PAS dans `FB_Encoder_Homing` (dépendance circulaire : Homing→Safety via `HomingSuspect`, et Homing←Safety via `EncoderIncoherent`). Un helper pur prend `EncoderAvailable` + `Homed` + `EncoderIncoherent` en entrée et sort le bit. **Scinde les responsabilités** : Homing = référencement, Safety = cohérence, `FB_EncoderReliability` = « le codeur est fiable ». |
| D-A10 | **Créer un `FB_Encoder` facade par treuil (M1/M2)** | ⚠️ **Décision utilisateur 2026-08-21** : asymétrie avec `FB_Joystick` (1 FB) vs 5 `FB_Encoder_*` fragmentés (10 instances + ~40 lignes de câblage dans PRG_02). Créer un **facade `FB_Encoder`** derrière **une interface**. **Contrat FINALISÉ (revues + clarifications)**. **3 compléments contractuels** : **(a)** étendre `ST_EncoderMeasurement` avec `HomingStatus` + `AbsStatus` (`ST_FbStatus`) + ré-exposer `HomingRefRaw` (consommateurs abandonnent les instances privées) ; **(b)** arbitrer bus plat vs `Data.Encoders` (migration complète ou miroirs) + migrer les lecteurs `*_EncoderInconsistent` (PRG_05:76-77, PRG_07:359-360) ; **(c)** calculer le gate `EncoderFault` **avant** `Speed` (même scan, purge vitesse) + unifier la validité (`NOT Data.Encoders.*.EncoderFault` = producteur unique). <br>**🛡️ Clauses RETAIN & composition (non négociables, revue)** : ① `Calib` reste une **globale RETAIN externe** (`_CalibM1/_CalibM2` dans GVL_PERSISTENT), passée en `VAR_IN_OUT` puis relayée à `Homing` — **jamais** une variable membre de la façade. ② La façade est une **pure composition/câblage** (chaque sous-FB garde sa responsabilité et reste testable isolément) — **pas** une fusion de logique. <br>**🔧 RÉVISÉ (décision 2026-08-21, Option B)** : la façade compose la **chaîne de mesure pure** `Abs→Scale→Safety→Speed` + gate `EncoderFault` — **SANS `FB_Encoder_Homing`**. Le homing reste **`instHomingM1/M2` dans `PRG_04_Treuils_Benne`** (conforme AF-09 §4.2) : il lit `Mode`/`UnitaryMode`/`WinchSelected` produits par `PRG_03_Modes` (rang 03), et l'inclure à la façade (rang 02) réintroduirait la **violation d'ordonnancement producteur-avant-consommateur** interdite par AF02 §4. La façade reçoit `HomingRefRaw` (sortie Homing, PRG_04) en entrée pour alimenter `Scale` — retard bénin déjà assumé (A-01 bis). |
| D-A11 | **Gate de fiabilité : `EncoderFault` (revue experte)** | AF06 §2ter : `EncoderFault := NOT EncoderAvailable OR EncoderIncoherent` — **SANS `Homed`** (décision 2026-07-31 « non-référencé ≠ incohérent », sinon bloque le référencement). `Homed` reste un état **diag** (force palier 1). L'interlock hauteur M3, lui, exige `Homed` (gate strict spécifique). |
| D-A3 | **Bit unique `HomedAndReliable`** (par treuil) | `HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent`. Lisible : « disponible sur bus **ET** référencé **ET** pas incohérent ». ⚠️ **Revue experte : voir D-A11** — le gate général devrait être `EncoderFault` (sans `Homed`) ; `HomedAndReliable` (avec `Homed`) = gate strict pour l'interlock hauteur M3 uniquement. |
| D-A4 | **Bit global `M1M2_HomedAndReliable`** | `M1M2_HomedAndReliable := M1_HomedAndReliable AND M2_HomedAndReliable` (pour bouger les 2 treuils). |
| D-A5 | **Regrouper incohérent/suspect** | `EncoderIncoherent` reste le bit de sortie « ne pas faire confiance », avec plusieurs causes possibles derrière. Cohérent, à garder groupé. |
| D-A6 | **`CablePosMSafe` est trompeur → à corriger** | C'est un passthrough pur (`CablePosMSafe := CablePosM`), le nom laisse croire qu'il est validé. → renommer ou rendre réellement safe (gel dernière valeur fiable). À trancher (C3). |
| D-A7 | **Cas de démarrage → signaler à l'opérateur** | Exposer « référencé » / « doute » au démarrage pour que l'opérateur décide (demander un référencement si non valide). |
| D-A8 | **Nettoyage consommateur par cas** | Traiter les sites de consommation un par un : comprendre chaque usage, choisir le bon bit, supprimer les recompositions. |

### Décisions Permits (volet associé)

| # | Décision | Détail |
|---|---|---|
| D-P1 | **Bannir le nom `_Raw`** | « Brut » est trompeur. ⚠️ **Justification révisée** : `_Raw` n'est PAS « déjà de la safety » — il contient du **process** (Kobold, benne, dump). Il faut **extraire** (séparer), pas renommer. |
| D-P2 | **Découpage Safety / Process / Résultat** | `SafetyPermit` (safety pure), `ProcessPermit` (process pur), résultat = **`ProcessAndSafetyPermit`** (décision utilisateur, D-P11). |
| D-P3 | **La synchro est une coordination croisée** | Elle combine les `ProcessAndSafetyPermit` des DEUX treuils (anti-télescopage) → étape `EffectivePermit`, pas une condition d'un seul FB. |
| D-P4 | **IHM : exposer les 3** | `SafetyPermit`, `ProcessPermit`, `ProcessAndSafetyPermit` (résultat) → l'opérateur voit l'origine et le résultat de l'autorisation. |
| D-P5 | **Annotation « où c'est généré »** | Dans le code/commentaires, indiquer le FB / PRG qui génère chaque permit (retrouver facilement sa provenance). |
| D-P6 | **Refaire le Troubleshooting permits** | Afficher les bits côte à côte (SafetyPermit / ProcessPermit / résultat) pour comprendre **pourquoi on bloque**. |
| D-P7 | **Revoir les noms IHM** | Aligner les libellés IHM sur le nouveau nommage (Safety / Process / résultat). |
| D-P8 | **`SafeStop` reste un bit clair, PAS dans la taxonomie permit** | Décision utilisateur : pour le mouvement, « permit » est clair ; pour `SafeStop`, « permit » n'a pas de sens. `SafeStop` = 1 actif, inchangé. |
| D-P9 | **`SyncActive` TRUE par défaut = normal** | N1 = couplé ; N2 = agir sur 1 treuil / benne. À afficher dans le troubleshooting (D-P6). |
| D-P10 | **Étude du bloc synchro (`FB_WinchSync`)** | → **doc dédiée** [`REVUE_SYNCHRO_TREUILS_v0.1.md`](REVUE_SYNCHRO_TREUILS_v0.1.md) + **revue indépendante** [`REVUE_EXPERTE_SYNCHRO_TREUILS_v0.1.md`](REVUE_EXPERTE_SYNCHRO_TREUILS_v0.1.md) (verrou sécurité). ⚠️ **`SyncSurveillanceOK` (proposé par la revue experte) REJETÉ** (décision utilisateur : pas de multiplication de bits — `SyncActive` reste l'autorisation de couplage, le problème est porté par Warn/Fault). |
| D-P11 | **Nom du résultat permit : `ProcessAndSafetyPermit`** | Décision utilisateur : le résultat = exclusivement issu de Safety + Process → `ProcessAndSafetyPermitM1` (au lieu de `PermitActive`). |

---

## 🗺️ Schéma de flux des autorisations (Permit)

```text
┌──────────────────────────────────────────────────────────────────────┐
│ ① SAFETY  ─ FB_Safety_Winch  (instSafetyWinchM1/M2)                 │
│    SafetyPermit = AscentPermit / DescendPermit                       │
│    (fdc haut/bas, mou câble, position, contacteur puissance)         │
│    → GÉNÉRÉ ICI (PRG_04 appelle FB_Safety_Winch)                     │
└──────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│ ② PROCESS ─ PRG_04 (interlocks process)                              │
│    ProcessPermit = Kobold fond / benne / vidage trémie / anticipation │
│    → GÉNÉRÉ ICI (PRG_04)                                             │
└──────────────────────────────────────────────────────────────────────┘
                                      │
                    SafetyPermit AND ProcessPermit
                                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│ ③ ProcessAndSafetyPermit (par treuil) — PRG_04                       │
│    ProcessAndSafetyPermitM1 := SafetyPermitM1 AND ProcessPermitM1    │
│    → GÉNÉRÉ ICI (PRG_04)                                             │
└──────────────────────────────────────────────────────────────────────┘
                                      │
        ProcessAndSafetyPermitM1 AND (NOT SyncActive OR ProcessAndSafetyPermitM2)
                    (couplage anti-télescopage, coordonnée par FB_WinchSync)
                                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│ ④ EffectivePermit (par treuil) — PRG_04                             │
│    EffectivePermitM1 := ProcessAndSafetyPermitM1 AND (NOT SyncActive OR ProcessAndSafetyPermitM2) │
│    → GÉNÉRÉ ICI (PRG_04)                                            │
└──────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
        Consommateurs : FB_Winch (instWinchM1/M2) · GVL_IHM.<Domaine>.Safety.<Permit>
```

> ⚙️ **Intégration de la synchro** : `FB_WinchSync` fournit `SyncActive` (mode couplé) → entrée du couplage
> en ④ (`EffectivePermit`). (`DeviationActive` est une variable **locale** non exposée.) La synchro ne crée ni
> `SafetyPermit` ni `ProcessPermit` : elle **combine** les `ProcessAndSafetyPermit` des deux treuils (anti-télescopage).

---

## 🔍 Actions en cours / à faire

- [ ] Auditer les sites de consommation (PRG_05 interlock hauteur, PRG_04 PositionsValid, PRG_07 Homed/InBounds, FB_Winch, FB_Bucket, FB_Sync, FB_Safety_Winch).
- [ ] Définir où `HomedAndReliable` est exposé (probablement `FB_Encoder_Homing` → `Data` bus PRG_02).
- [ ] Trancher D-A6 (`CablePosMSafe`) et la question `Homed` vs `EncoderIncoherent` dans l'interlock hauteur M3.
- [ ] Cartographier les `Permit` : passage `Raw/_Active` → `SafetyPermit/ProcessPermit/ProcessAndSafetyPermit/EffectivePermit`.
- [ ] Proposer l'exposition IHM minimale des états codeur (référencé / doute / fiable).
- [ ] Refonte Troubleshooting permits (D-P6) + libellés IHM (D-P7).
- [ ] **Refonte Troubleshooting codeurs (D-A9)** : garder `EncoderAvailable` / `Homed` / `EncoderIncoherent` / `HomingSuspect` visibles **séparément** en plus de `HomedAndReliable` (FALSE = 4 causes possibles : bus perdu / jamais homé / hors bornes / dérive boot) — symétrique à D-P6 pour les permits.
- [ ] **`FB_Bucket.HoldOffset` (prérequis bloquant synchro)** : correctif offset (gel à l'écart réel en position intermédiaire non référencée) — **obligatoire AVANT** la refonte `FB_SyncDeviation` (sinon on migre sur un `ActiveOffsetM` encore bugué en saut). TODO non encore codé.

### 🚀 Phase 1 — Lot `FB_Encoder` facade (contrat finalisé)
- [ ] Créer `FB_Encoder` (facade) par treuil : compose Abs→Homing→Scale→Safety→Speed + gate.
- [ ] Gate `EncoderFault := NOT EncoderAvailable OR EncoderIncoherent` (sans `Homed`) ; calculer **avant** `Speed` (même scan).
- [ ] Struct `ST_EncoderMeasurement` : + `HomingStatus`/`AbsStatus` (`ST_FbStatus`) + `HomingRefRaw` ré-exposé (complément a).
- [ ] `ST_EncoderMeasurements` = `Data.Encoders` dans le bus (sortie PRG_02).
- [ ] Arbitrer bus plat vs `Data.Encoders` (migration complète ou miroirs) + migrer les lecteurs `*_EncoderIncoherent` (complément b).
- [ ] PRG_02 → 2 instances `instEncoderM1/M2` ; consommateurs lisent `Data.Encoders.*` (plus d'accès privés).
- [ ] Renommer `CablePosMSafe` → `CablePosM` (via `Data.Encoders`), retrait du passthrough.
- [ ] Bundle + G200 + gates verts ; validation humaine.

---

## 📌 Questions ouvertes

- C1 : **Deux gates à deux usages (clarifié pour éviter D2)** — `EncoderFault := NOT EncoderAvailable OR EncoderIncoherent` (sans `Homed`) = gate **général** de la fiabilité mesure (vitesse, mouvements, PositionsValid). `HomedAndReliable` (avec `Homed`) = gate **strict** réservé à l'**interlock hauteur M3** (on ne translate pas si hauteur inconnue). Consommateur → bit : vitesse/mouvement → `EncoderFault` ; interlock M3 → `Homed`/`HomedAndReliable`. Déblocage homing + `BtnConfirmCoherence` (MAINT_N1 ou N2).
- C3 : `CablePosMSafe` → renommer ou geler ? (à trancher)
- C5 : `HomedAndReliable` produit par un helper FB → **RÉSOLU** : `FB_EncoderReliability` (helper pur).
- C-P3 : la synchro reste en étape `EffectivePermit` → **VALIDÉ** (anti-télescopage, compare le permit complet des 2 treuils).
- C-P8 : `SafeStop` → **RÉSOLU** : reste un bit clair, pas dans la taxonomie permit.
- C-P10 : étude du bloc synchro (`FB_WinchSync`) → à faire (sorties réelles à clarifier).

---

## 🗒️ Journal

- 2026-08-21 : ouverture T146. Revue initiale `REVUE_REFERENCEMENT_CODEURS_v0.1.md` créée. Décisions D-A1 à D-A8 actées.
- 2026-08-21 : volet Permits exploré. Décisions D-P1 à D-P4 actées (`Raw` banni, Safety/Process/PermitActive, EffectivePermit synchro, IHM 3 étages).
- 2026-08-21 : **revue externe** (agent automatisme) — verdict MIXTE, 3 verrous conceptuels + 8 écarts doc. Décisions utilisateur : helper `FB_EncoderReliability` (D-A2bis), `SafeStop` hors taxonomie (D-P8), `SyncActive` normal (D-P9), étude synchro (D-P10), contrat interlock validé (C1).


