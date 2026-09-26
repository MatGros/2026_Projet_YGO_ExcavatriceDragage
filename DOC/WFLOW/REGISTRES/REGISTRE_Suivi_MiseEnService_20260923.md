# 🧾 Mise en service — Journal et Clôture du 23/09/2026

> **Date :** 2026-09-23  
> **Branche :** `main` (Tag Git : `MES_FIN_20260923`, Commit de clôture : `44c2b368`)  
> **Nature :** Journal exhaustif des correctifs appliqués, testés et validés sur machine réelle en clôture de mise en service.

---

## 1. Synthèse des Correctifs Validés sur Machine Réelle

### 1. ✅ Inversion matérielle DI M1/M2 terrain ([`PRG_02_Acquisition.st:145-153`](../../CODE/M_MAIN/PRG_02_Acquisition.st))
- **Constat d'origine (22/09) :** Lors de la bascule `AX10 → AX10B → AX11`, blocage systématique de ~800 ms (timeout de concordance contacteurs), M2 coupait et générait un mou de câble.
- **Cause racine identifiée :** Les contacts auxiliaires de retombée contacteurs (DI) pour M1 et M2 étaient physiquement permutés sur le bornier des cartes d'entrées TOR de l'automate CODESYS.
- **Correctif appliqué :** Compensation logicielle au niveau de l'acquisition matérielle brute §1 :
  ```pascal
  // Inversion des retours contacteurs physiques (compensation cablage terrain DI M1 <-> M2)
  HwReal.Winch.M1_ContactorsReleased_DI := M2_ContactorsReleased_DI;
  HwReal.Winch.M1_ThermalOk_DI          := M1_ThermalOk_DI;
  HwReal.Winch.M1_BrakeIsOpen_DI        := M1_BrakeIsOpen_DI;

  HwReal.Winch.M2_ContactorsReleased_DI := M1_ContactorsReleased_DI;
  HwReal.Winch.M2_ThermalOk_DI          := M2_ThermalOk_DI;
  HwReal.Winch.M2_BrakeIsOpen_DI        := M2_BrakeIsOpen_DI;
  ```
- **Résultat terrain :** **Bascule immédiate en 21 ms** (au lieu de 800 ms), synchronisation parfaite, zéro mou de câble. Correctif conservé et actif.

---

### 2. ✅ Suppression du saut pirate vers AX10 ([`FB_CycleSemiAuto.st:1568-1576`](../../CODE/G_CYCLE/FB_CycleSemiAuto.st))
- **Constat d'origine :** En phase de vidage à la trémie (`AX15B_DUMP_OPEN`), le fait de tirer sur le manche (action inverse opérateur) provoquait un saut intempestif et dangereux vers `AX10_CLOSE_BUCKET` (fermeture benne au fond de l'eau).
- **Décision d'ingénierie :** Interdiction absolue de quitter la trémie pour aller au fond de l'eau. Aucune sortie d'étape vers l'arrière n'est autorisée. Si l'opérateur tire sur le manche, la benne se referme sur place sans bouger les treuils ni la translation.
- **Correctif appliqué :**
  - Suppression intégrale de la ligne `State := E_AutoCycleStep.AX10_CLOSE_BUCKET;`.
  - Intégration du micro-step `AX15D_DUMP_BUCKET_JOG` permettant de moduler l'ouverture/fermeture benne sur place à la trémie.
  - La seule sortie du vidage reste l'achèvement nominal `AX18_DONE_SYNC` (➔ retour translation P1 `AX2_TRANSLATE_P1`), ou la sortie vers MANU via le sélecteur de mode.

---

### 3. ✅ Déblocage verrou translation M3 à P1 (T392, [`FB_Translation.st`](../../CODE/I_TRANSLATION/FB_Translation.st))
- **Constat d'origine :** Chariot M3 bloqué en SEMI_AUTO à l'étape `AX14_TRANSLATE_DUMP` au passage par P1. Tous les permis de translation étaient verts (100%), mais la consigne `RampTargetPct` restait figée à 0.
- **Cause racine :** Le verrou anti-rebond `ArrivalLock` s'armait indûment sur l'arrêt intermédiaire P1 en l'assimilant à une fin de course extrême (`ArrivalWasTremie`), bloquant toute progression ultérieure vers la trémie.
- **Correctif appliqué :** Restriction de l'armement d'`ArrivalLock` aux seules extrémités réelles (Trémie / Maintenance) via `ArrivalIsExtreme`. P1 redevient un arrêt intermédiaire transparent. Déblocage terrain confirmé par l'opérateur.

---

### 4. ✅ Filtrage anti-rebond capteurs translation M3 ([`PRG_05_Translation.st`](../../CODE/M_MAIN/PRG_05_Translation.st))
- **Correctif :** Stabilisation des drapeaux `AtTremie` et `AtMaintenance` par jeton d'état insensible aux rebonds mécaniques et variations de contact lors des approches du chariot.

---

### 5. ✅ Compteurs horaires et métrologie de cycle ([`PRG_07_Supervision.st`](../../CODE/M_MAIN/PRG_07_Supervision.st))
- **Correctif :** Intégration et raccordement des compteurs de temps de fonctionnement moteur M1, M2, M3 et machine générale, ainsi que la correction du chronomètre de cycle auto en supervision.

---

## 2. Validation Mécanique & Traçabilité Git

| Contrôle | Outil / Script | Résultat |
|---|---|---|
| **Liaison des variables** | `G200_check_linkage.py --report` | **PASS (0 erreur)** sur 2070 instances vérifiées |
| **Bundle complet** | `generate_codesys_bundle.py` | `CODE_XML/CODE_Bundle.xml` généré et à jour |
| **Diff bundle ciblé** | `generate_codesys_diff_bundle.py` | `CODE_XML/CODE_DiffBundle.xml` prêt pour import CODESYS (`FB_CycleSemiAuto` + `PRG_02_Acquisition`) |
| **Commit Git récapitulatif** | `git commit` | `420e2eea` (merge) & `44c2b368` (docs history) |
| **Tag immuable** | `git tag` | `MES_FIN_20260923` |
| **Synchronisation GitHub** | `git push origin main --tags` | Aligné 100%, working tree clean |

---

*Ce document fait foi de l'état final de la machine et du programme au terme de la séance de mise en service du 23/09/2026.*
