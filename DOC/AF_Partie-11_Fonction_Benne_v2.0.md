# Analyse Fonctionnelle — Partie 11 : Fonction Benne (v2.0)

> Rôle : ouverture/fermeture par désynchronisation contrôlée M1/M2 (M1 immobile, M2 seul bouge).
> **Sous-fonction du domaine Treuils** (AF10) — aucune I/O ni PRG propre. Voir §7 pour justification.
> Source code : `CODE/TREUILS/BENNE/*.st`, `CODE/CYCLE/FB_DiveSearch.st`, `FB_ExtractionSequence.st`.
> Instance unique `instBucket` dans `PRG_06_WinchControl` — annexe technique d'AF10.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Bucket_Extraction_Code_v1.0.md`.
> v1.4 archivée : `ARCHIVES/Doc/AF_Partie-12_Fonction_Benne_v1.4.md`.

## 🧭 Sommaire

1. Rôle et cinématique
2. FB_Bucket — machine d'état, offsets
3. Protection glissement M1 — 2 couches
4. FB_DiveSearch — qualification Kobold
5. FB_ExtractionSequence — fermeture + remontée
6. Bus et intégration programme
7. Pourquoi Benne reste séparée d'AF10
8. Alertes et écarts
9. Documents liés

## 🧪 Points de validation

| ID | Attendu | Type |
|---|---|---|
| TC-P11-001 | Fermeture seulement si `MotionDirection=1` ET `MotionRequestActive` | AUTO |
| TC-P11-002 | Ouverture seulement si `MotionDirection=-1` ET `MotionRequestActive` | AUTO |
| TC-P11-003 | Demande refusée si `M1_Busy OR M2_Busy` à l'entrée | AUTO |
| TC-P11-004 | Glissement M1>1.0m pendant BUSY ⇒ bit4 + `M1SlipDetected` + coupe M2 | AUTO |
| TC-P11-005 | `M1SlipDetected` force SafeStop sur M1 côté PRG_06 (couche 1) | AUTO |
| TC-P11-006 | Couche 2 (Méca C AF10, bit9) : dérive M1>2.0m ⇒ PowerCutOff | AUTO |
| TC-P11-007 | Recul (sens inverse) borné à la position de départ, jamais au-delà | AUTO |
| TC-P11-008 | `ConfirmOpenPosition`/`ClosePosition` : effet seulement MAINT_N1/N2, treuils arrêtés | AUTO |
| TC-P11-009 | Codeur(s) non référencé(s) ⇒ bit3 permanent, indépendant de Reset | AUTO |
| TC-P11-010 | Seule `FB_ExtractionSequence.Busy` préserve l'armement joystick en fin benne (`PreserveArmingAfterBucket`) ; `FB_DiveSearch` ne le fait pas | AUTO |
| TC-P11-011 | Butée haute M2 décalée de `OffsetCloseM` uniquement si fermé/en fermeture | AUTO |
| TC-P11-012 | Terrain : cinématique réelle en charge, amplitude offset validée | SITE |

---

## 1. Rôle et cinématique

Pas de moteur propre — effet de bord de la désynchronisation M1/M2 :
- **Fermeture** : M2 enroule (monte, `Direction=+1`)
- **Ouverture** : M2 déroule (descend, `Direction=-1`)
- Cible : `CablePosM2 >= CablePosM1 + OffsetCloseM` (fermeture) ou `<= CablePosM1 + OffsetOpenM` (ouverture)

**Offsets réels (RETAIN)** : `OffsetOpenM=0.0` (référence neutre, M2=M1) ; `OffsetCloseM=15.0` (⚠️ doc legacy dit 10.0, non validé en charge — voir §8).

---

## 2. FB_Bucket

| Entrée | Type | Sens |
|---|---|---|
| `MotionRequestActive`/`MotionDirection` | BOOL/INT | Intention déjà arbitrée (joystick/IHM, axe Y) |
| `CablePosM1/M2`, `HomedM1/M2` | — | Sortie Encodeurs |
| `M1_Busy`/`M2_Busy` | BOOL | Interlock avant armement demande |
| `M1SlipToleranceM` :=1.0 | REAL | Tolérance glissement (couche 1) |
| `ConfirmOpenPosition`/`ClosePosition` | BOOL (front) | Référencement manuel MAINT_N1/N2 |
| `Config` (ST_BucketConfig) | — | `OffsetOpenM`, `OffsetCloseM`, `CoherenceLimitM`(0.05m) |

**Sorties** : `Ready/Busy/Done/Error`, `ErrorId` (bit0 Timeout 30s, bit1 incohérence boot, bit2 limites dépassées, bit3 codeur non référencé, bit4 glissement M1), `M1SlipDetected`, `M2_StartStop`/`Direction`/`ForceSlowSpeed`.

**Machine d'état** :
- **DISABLED** si `NOT Enable OR NOT PowerContactorEngaged`
- **READY** : accepte requête seulement si `NOT M1_Busy AND NOT M2_Busy` (anti-traversée)
- **BUSY** : pilote M2 seul, vitesse forcée lente ; sens inverse toléré mais **borné** à la position de départ (`M2StartPosM`)
- **DONE** : attend relâchement demande pour repasser READY

---

## 3. Protection glissement M1 — 2 couches

| Couche | Condition | Conséquence |
|---|---|---|
| **1** (`FB_Bucket`, bit4) | `State=BUSY` ET `\|CablePosM1-M1RefPosM\| > 1.0m` | Coupe M2 (SevereError interne), `M1SlipDetected` exposé — **consommé** par PRG_06 : force SafeStop M1 |
| **2** (`FB_Safety_Winch`, Méca C bit9, AF10) | `BenneHoldStillActive` (M1 seul, câblé sur `instBucket.Busy`) | Dérive M1 > **2.0m** ⇒ **PowerCutOff** |

Défense en profondeur : si couche 1 (SafeStop M2, 1.0m) ne suffit pas à arrêter M1 physiquement (roue libre, contacteur collé), couche 2 coupe la puissance amont à 2.0m.

---

## 4. FB_DiveSearch (assistant MAINT_N1/N2)

Qualification Kobold avant descente : `WAIT_PRECONDITIONS → READY_TO_DESCEND → SEARCHING_IMMERSION → SEARCHING_BOTTOM → BOTTOM_CONFIRMED`.

- Précondition : `BucketIsOpen`, positions valides, Kobold non immergé.
- `SEARCHING_IMMERSION` : front montant Kobold **dans fenêtre** `[ImmersionLower_M;ImmersionUpper_M]` sur M1 **et** M2.
- `SEARCHING_BOTTOM` : front descendant Kobold → `BottomTouchConfirmed`.
- Lit `BucketIsOpen` en entrée seule — **ne pilote jamais** la benne.

---

## 5. FB_ExtractionSequence (assistant MAINT_N1/N2)

Fermeture benne puis remontée contrôlée : `WAIT_BOTTOM_CONFIRMATION → READY_TO_CLOSE → CLOSING_BUCKET → CONTROL_ASCENT → NOMINAL_ASCENT`.

- `WAIT_BOTTOM_CONFIRMATION` : Kobold (`instDiveSearch.BottomTouchConfirmed`) OU attestation manuelle IHM.
- `CLOSING_BUCKET` : produit `BucketCloseRequest` → `instBucket.CmdClose_IHM`. Transition vers `CONTROL_ASCENT` dès fermé.
- `CONTROL_ASCENT` : force palier 1 (`ForceMinSpeedStep`) sur M1/M2, sort après distance parcourue confirmée sur les deux.

**Lien homme-mort** : `PreserveArmingAfterBucket := instExtractionSequence.Busy` (câblé `PRG_01_Diagnostics`) — **seule** cette séquence préserve l'armement joystick en fin de fermeture pour enchaîner immédiatement palier 1, sous ses propres interlocks. `FB_DiveSearch` ne bénéficie pas de cette exception.

---

## 6. Bus et intégration programme

**Ordre `PRG_06_WinchControl`** (vérifié) :
1. §1 `instBucket` (**appelé en premier**, avant arbitrage M1/M2 — évite fenêtre de commande manuelle parasite)
2. §2/§3 Arbitrage M1/M2 — **Benne prioritaire absolue sur M2** si `instBucket.Busy`
3. §3bis Assistance maintenance (DiveSearch/ExtractionSequence, si benne non busy)
4. §3ter Coupure immédiate M1/M2 au scan exact de fin cycle benne
5. Synchro suspendue pendant `instBucket.Busy`
6. Butée haute M2 décalée de `OffsetCloseM` si fermé/en fermeture

**Consommateurs `instBucket.Busy/Done`** : PRG_06 (arbitrage), PRG_03_Safety (`BenneHoldStillActive`, Méca E), `FB_ExtractionSequence`, `FB_Joystick` (désarmement), PRG_09 (IHM).

**Homme-mort** : axe Y joystick, même axe que pilotage normal M1/M2 — pas d'axe dédié.

---

## 7. Pourquoi Benne reste séparée d'AF10

| Argument | Constat |
|---|---|
| Aucune I/O propre | Réutilise entièrement les Q de `FB_Winch` M2 |
| Couplage bidirectionnel fort | `FB_Bucket` a besoin de position/Homed M1+M2 ; `FB_WinchSync`/`FB_Safety_Winch` ont besoin en retour de `Busy`/`ActiveOffsetM`/`M1SlipDetected` |
| Organisation code déjà ainsi | `TREUILS/BENNE/`, appelé dans `PRG_06_WinchControl` — jamais remis en cause |
| Contenu propre suffisant | Offsets, Méca C couche 1, cinématique inversée, DiveSearch/ExtractionSequence — mérite sa fiche |

**Décision retenue** : AF11 séparée, **explicitement annexée** à AF10 (pas fusionnée — AF10 deviendrait trop volumineuse ; pas indépendante — pas de PRG/Safety propre comme Translation).

---

## 8. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P1 | `OffsetCloseM` : doc legacy 10.0, code réel 15.0, non validé en charge (MES-010) | Corrigé ici, terrain à confirmer |
| 2 | P1 | DiveSearch/ExtractionSequence absents doc v1.4 | Comblé §4/§5 |
| 3 | P2 | T57 : possible doublon logique limite haute M2 | Non vérifié en profondeur — TBD |
| 4 | info | T27/T89 : cinématique/offset jamais essayés en charge réelle | TBD terrain |

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF10 | Domaine parent — Treuils M1/M2, Méca C couche 2 |
| AF09 | Encodeurs — position/Homed consommés |
| AF04 | Cycle SEMI_AUTO — séquence dragage |
| AF05 | Modes — MAINT_N1/N2 requis pour assistants |
| Code | `CODE/TREUILS/BENNE/*.st`, `CODE/CYCLE/FB_DiveSearch.st`, `FB_ExtractionSequence.st` |
