# 📨 MESSAGE À TRANSMETTRE À L'AGENT — LOT T387 « BENNE » (3 défauts)
## v1 — à copier/coller tel quel · 2026-09-22 · émetteur : DSH01 (orchestrateur)

---

**CONSIGNE : T387 couvre 3 défauts benne constatés en session. Ne PAS créer de tâche séparée (T388 est absorbée). Phase 0 = lecture seule, puis ARRÊT et restitution AVANT toute écriture.**

**Brief à lire en entier (fait partie du lot)** : `DOC/WFLOW/CONTRACTS/BRIEF_T388_BENNE_BORNES_SANS_DATUM_v1.md`

---

### DÉFAUT 1 — Benne qui ne se ferme pas au FDC haut
*(le périmètre déjà en cours : fenêtre benne / MecaB / `AscentPermit`)*

### DÉFAUT 2 — Bornes RELATIVES appliquées avec un **datum invalide** (jog benne bridé au boot)
```text
PRG_04_Treuils_Benne.st:787-789
   ManualBucketLimitsActive := TglManualBucketLimits
     AND (Auth.JoystickWinchSelectArbitrated = 2)
     AND NOT Auth.CoupledBucketPhaseLocked          <-- AUCUN controle de referencement !
PRG_04_Treuils_Benne.st:807 / :818   bornes RELATIVES a M1 :
   M2_CablePosM <= M1_CablePosM + OffsetOpenM + OpenAnticipationM      (ouverture)
   M2_CablePosM >= M1_CablePosM + OffsetCloseM - CloseAnticipationM   (fermeture)
```
**Constat exploitant** : boot `HX0` (M1/M2 non référencés) + `TglManualBucketLimits=1` + `WinchSel=2` ⇒ **jog benne bridé**.
**Correctif attendu** : gater **la seule activation** des bornes relatives par la validité du datum — **réutiliser** `HomedAndReliableM1/M2` et/ou `BucketState.BucketReferenced` (`FB_Bucket.st:36/37`, `:419-420`) — **sans** nouvelle variable d'état.
⛔ **LA LIMITE PHYSIQUE `RecoilLimitActive` (`FB_Bucket.st:114-115`) DOIT RESTER ACTIVE** : c'est la condition de sécurité du lot.

### DÉFAUT 3 — `1/1 [BENNE] ErrorID:05 - codeurs treuils non référencés` **PENDANT le homing**
```text
FB_Bucket.st:291-296   // Cause 4 : Non refere
   HomingMotionWithoutReference := (ReqAscent OR ReqDescend OR CmdOpen_IHM OR CmdClose_IHM
                                    OR ProgramBucketDriveActive)
     AND NOT MachineHomingActive          <-- LA GARDE D'INHIBITION EXISTE DEJA
     AND NOT (HomedM1 AND HomedM2);
Message : FB_Hmi_BannerFormatter.st:1059  '[BENNE] ErrorID:05 - codeurs treuils...'
```
**Conclusion à vérifier** : la garde existe ⇒ **le défaut levé est que `MachineHomingActive` est FAUX pendant le homing UNITAIRE** (`WinchSel=2`, `HX0`). Cause 4 **NON latchante** (`Latching := FALSE`) ⇒ elle tombe d'elle-même (pas de Reset).
**Correctif attendu** : l'inhibition doit être **effective pendant le homing** — ⛔ **sans supprimer la protection** : la cause 4 doit **toujours** se lever si un mouvement benne est commandé **hors contexte de homing** avec des codeurs non référencés.

---

### PHASE 0 — MESURER (lecture seule, obligatoire)
1. `WinchSel=2` + `TglManualBucketLimits=1`, **M1/M2 non référencés** : relever les **2 comparaisons** `:807`/`:818` avec les **valeurs réelles** de `EncoderM1/M2.Measurement.CablePosM` ⇒ prouver **pourquoi** le mouvement est refusé.
2. M1/M2 **référencés** : vérifier que les bornes se comportent **normalement** (non-régression).
3. Relever **`MachineHomingActive`** (valeurs scan par scan) pendant le homing unitaire ⇒ **confirmer** qu'il est FAUX.
**Livrable** : tableau (positions lues / comparaison / décision) + conclusion. ⛔ **ARRÊT HUMAIN avant toute écriture** (chemin de COMMANDE).

### PHASE 1-2 — CORRIGER puis PROUVER (après GO)
- **ROUGE avant / VERT après** + **test de MUTATION** (datum retiré ⇒ le test échoue).
- 3 cas à couvrir : *datum invalide ⇒ bornes relatives INACTIVES* · *datum valide ⇒ bornes ACTIVES* · **`RecoilLimitActive` actif dans LES DEUX cas**.
- **Révision ÉPINGLÉE** (`git hash-object` des fichiers touchés) + **`G200 --report` collé** + palier C sans rouge nouveau.

### ⛔ INTERDITS
`B_AU_SECURITE/**` · toute temporisation moteur/frein · tout **bypass** · les seuils `Offset*/anticipations` · `PRJ_CODESYS/**`, `Device.export`, `DOC/AF/**`, `DOC/STDS/**`.

### 🚨 UN SEUL ÉCRIVAIN
`PRG_04_Treuils_Benne.st` et `FB_Safety_Winch.st` sont **partagés** (T387 en cours, T381, T386-B, T269). Relire `git status` **juste avant** chaque écriture. **Jamais** de réécriture en bloc.

### ❓ QUESTIONS À RENDRE (réponse attendue)
1. Pourquoi le jog est-il **exactement** refusé (comparaison `:807` ou `:818`, avec les valeurs) ?
2. `MachineHomingActive` est-il **effectivement FAUX** pendant le homing unitaire ? Si oui, **pourquoi** (qui doit le poser) ?
3. La cause 4 reste-t-elle **capable de se lever hors homing** après le correctif ? **Preuve**.
