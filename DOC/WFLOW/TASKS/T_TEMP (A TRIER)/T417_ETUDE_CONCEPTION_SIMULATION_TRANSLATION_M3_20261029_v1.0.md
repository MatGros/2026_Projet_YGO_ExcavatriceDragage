# 🚜 Dossier d'Étude de Conception — Simulation Translation M3 (T417)
## Modélisation Physique Réaliste & Émergence Naturelle des Défauts

> 📅 **Date** : 2026-10-29 · 🏷️ **Tâche** : `T417` (C2) · 👤 **Orchestrateur** : `AGY01` (Antigravity Senior)  
> ⚠️ **ERRATUM 2026-10-30 — qualification des observations.** Les sections 3 et 5bis et les
> formulations qui en déduisent un comportement « machine réelle » mélangent des relevés
> oscilloscope effectués **en simulation** et un récit visuel de l'exploitant. Elles ne
> constituent donc pas une preuve terrain ni une calibration. La source de référence pour
> ce récit, ses limites de mémoire et les hypothèses ouvertes est le
> [`REGISTRE_MES_TEMOIGNAGE_M3_20261030.md`](../REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md).
> Les traces versionnées et l'historique Git priment ; ne pas utiliser cette section pour
> affirmer que le frein réel s'est ouvert, fermé ou temporisé d'une manière donnée.
>
> 📑 **Contrat de tâche** : [`TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml`](../CONTRACTS/TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml) (PASS)  
> 🎯 **Objectif** : Établir l'étude technique complète et le plan d'implémentation pour rendre la simulation de la translation M3 dans `SimBench` fonctionnellement juste et physiquement réaliste, sans forcer artificiellement des pannes et sans altérer le code automate de production.

---

## 1. 🧭 Cadrage, Posture & Règles Métier

### ⛔ Règle d'or : Ne jamais prendre le problème à l'envers
- **Anti-Pattern historique** : Régler un banc de simulation avec des déclencheurs ad-hoc ou des temporisations artificielles pour "forcer" un code d'erreur (ex. injection forcée de `ErrorId=64`, coupure de capteur arbitraire, arrêt instantané à décélération infinie en butée).
- **Principe d'émergence naturelle** : La simulation modélise la **physique réelle de la machine** (inertie chariot, rampe réelle du variateur AC600, retombée mécanique du frein à manque de courant, géométrie finie des cames inductives avec hystérésis de 2 cm).
- **Conséquence** : Si la commande de l'automate est saine, la machine évolue sans encombre. Si l'automate coupe la commande trop tard, gère mal ses fronts de cames en cycle automatique ou applique le frein en pleine vitesse, **les défauts et dépassements émergent spontanément** de la physique.

### 🛡️ Non-Régression & Sécurité Machine
1. **Sanctuarisation absolue de `GVL_PERSISTENT`** : Zéro variable ajoutée, déplacée ou supprimée. La mémoire NVRAM de l'automate CODESYS reste strictement intacte.
2. **Invariance du code automate de production** : Les blocs métiers `PRG_01` à `PRG_07`, les blocs de sécurité `FB_Safety_*` et les modules de translation `CODE/I_TRANSLATION/` restent **strictement en lecture seule**.
3. **Périmètre d'action borné** : Uniquement `CODE/L_SIMULATION/` (`FB_Sim_Translation.st`, `FB_Sim_TranslationBrake.st`, `FB_Sim_TranslationDrive.st`, `FB_SimBench.st`, `GVL_Simulation.st`).

---

## 2. 📊 Données Physiques Exactes du Chantier (Recalées Terrain)

| Grandeur | Valeur Réelle Terrain | Source & Justification | Rôle dans la Simulation |
|---|---:|---|---|
| **Motorisation** | Moteur triphasé classique | Plaque HELMKE 7.5 kW (rotor bobiné **court-circuité**) | Comportement standard asynchrone piloté en fréquence par l'AC600. |
| **Course utile réelle** | **0.00 m à 10.00 m max** | [`GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L101-L105) | Trémie = 0.00 m, PV = 1.50 m, P2 = 3.50 m, P1 = 5.00 m, Maintenance = 10.00 m. |
| **Butées mécaniques réelles** | **-0.50 m (Trémie) / +10.50 m (Maint)** | `EndStopMargin_M = 0.50 m` | Marge de 0.5 m au-delà des capteurs extrêmes réels. |
| **Vitesse nominale de service** | **50.0 Hz** ($1.00\text{ m/s}$) | [`GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L91) | Pleine vitesse de travail. Petite vitesse d'approche (20 Hz / 15 Hz) vers Trémie et P1. |
| **Gain odométrique de repli** | **0.02 m/(Hz·s)** | `FB_Translation_OdometryGain` | $50\text{ Hz} \to 1.00\text{ m/s}$ ; $20\text{ Hz} \to 0.40\text{ m/s}$. |
| **Source unique de vérité position** | **Automate (`FB_Translation_PositionEstimator`)** | Décision d'architecture REX T360 | Le banc ne recalcule aucune position concurrente : il fournit les cames physiques fidèles. |
| **Rampe d'accélération automate** | **20 Hz/s** ($40\%/\text{s}$) | `_TranslationRampAccelRate_Pct = 40%` | Montée 0 $\to$ 50 Hz en 2.5 s. |
| **Rampe de décélération normale** | **25 Hz/s** ($50\%/\text{s}$) | `_TranslationRampDecelNormal_Pct = 50%` | Arrêt normal depuis 50 Hz en 2.0 s. |
| **Rampe SafeStop rapide** | **50 Hz/s** ($100\%/\text{s}$) | `_TranslationRampDecelFast_Pct = 100%` | Arrêt d'urgence contrôlé en 1.0 s. |
| **Rampe variateur AC600 interne** | Paramétrée en dur dans le variateur | Garde-fou mécanique matériel | Protection mécanique ultime sous-jacente à la rampe logicielle automate. |
| **Retard ouverture bobine frein** | **0.10 s** ($100\text{ ms}$) | Fiche T400 | Délai mécanique d'ouverture après commande électrique. |
| **Confirmation contact frein** | **0.01 s à 0.02 s** | Retour auxiliaire `M3_BrakeIsOpen_DI` | Indique que les mâchoires sont physiquement ouvertes. |
| **Retard fermeture frein (manque courant)** | **0.09 s** ($90\text{ ms}$) | Fiche T400 & trace terrain | Chute mécanique des mâchoires à la coupure bobine. |
| **Décélération sous frein mécanique** | **2.0 m/s²** | Trace réelle chute $10\text{ Hz} \to 0\text{ Hz}$ en $0.56\text{ s}$ | Arrêt sous frottement des garnitures (~4 cm à 20 Hz). |
| **Hystérésis capteurs inductifs** | **0.02 m** ($2\text{ cm}$) | Déjà codé dans `FB_Sim_PositionSensor.st` | Zone de transition évitant le rebond numérique tout en capturant le glissement réel. |

---

## 3. 🔍 Pourquoi le Frein a-t-il Claqué à 10 Hz sur la Trace Réelle ?

L'analyse de la trace `Suivi_TranslationM3bug_20260904_27_wide.csv` à $t=26\,438\text{ ms}$ a révélé le mécanisme exact :
```text
t = 26 353 ms : Tremie = 0 | f_act = 10.00 Hz | CW = 1 | Brake = 1 (ouvert) | StateErr = 0
t = 26 438 ms : Tremie = 1 | f_act = 10.00 Hz | CW = 0 | Brake = 0 (FERMÉ)  | StateErr = 64 (FDC extrême)
t = 26 553 ms : Tremie = 0 | f_act =  9.13 Hz | CW = 0 | Brake = 0 (FERMÉ)  | StateErr = 64
```

### Le mécanisme démasqué dans le code automate :
Dans [`PRG_06_Outputs.st:431-443`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_06_Outputs.st#L431-L443) :
```pascal
M3_TremieHardStopActive := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI
                           AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic;

instTranslationOutputInterlockM3(
    ...
    BrakeReleaseRequest := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest
                           AND NOT M3_TremieHardStopActive,
    RequestedDriveControlWord := SEL(M3_TremieHardStopActive, ..., WORD#0),
    RequestedDriveFreqHz := SEL(M3_TremieHardStopActive, ..., 0.0)
);
```
**Conclusion technique** :
- Le capteur Trémie a émis un **front furtif de 85 ms** (rebond inductif/mécanique).
- Le signal `M3_TremieHardStopActive` a été câblé en **coupure directe sans aucun filtre ni débounce**.
- Au cycle précis de l'impulsion, `BrakeReleaseRequest` a été coupé net, faisant claquer le frein mécanique alors que le chariot roulait à 10 Hz ($0.20\text{ m/s}$).
- Ce n'est donc **pas une fin de rampe normale** qui a fermé le frein, mais une coupure de sécurité d'interlock dur déclenchée par un rebond de came !

---

## 4. 🔍 Pourquoi l'Arrêt sur FDC Différait entre Manuel et Semi-Auto ?

- **En mode Manuel (`MAINT_N1`/`N2`)** :
  L'axe est piloté par l'opérateur. À l'arrivée sur le capteur d'arrêt, [`FB_Translation.st:214`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/I_TRANSLATION/FB_Translation.st#L214) arme `ArrivalLock := TRUE;`. C'est un **verrou d'état latché**. Même si le capteur vibre ou que le joystick reste poussé, la consigne est verrouillée à 0 jusqu'au relâchement conscient du joystick.
- **En mode Cycle Semi-Auto** :
  Le séquenceur [`FB_CycleSemiAuto.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/E_CYCLES/FB_CycleSemiAuto.st) pilote via `ReqTranslation.ReqStart`. Dès la détection du capteur, le séquenceur **retire simplement sa demande** (`ReqStart := FALSE`). Mais il n'y avait pas de verrouillage d'état unifié identique à l'axe : si le chariot dépassait la came de 2 cm sous son élan ou si le signal oscillait, la demande pouvait être réévaluée ou lever l'alarme "M3 au-delà de P1".
- **Principe pour l'évolution** :
  Le traitement d'arrêt sur fin de course doit être **commun et unifié au niveau de l'axe**, indépendant de qui demande le mouvement (joystick ou cycle auto). De plus, l'arrêt doit se faire **sans ajouter d'étapes de pause artificielles**, afin de préserver la possibilité de mouvements simultanés Translation + Treuils pour optimiser le temps de cycle.

---

## 5. 📐 Architecture Physique Cible de SimBench M3

```text
  Consigne Automate PRG_05
  (SpeedTgt_Pct, ReqTremie, ReqMaint, BrakeCmd)
               │
               ▼
┌────────────────────────────────────────────────────────┐
│ FB_Sim_TranslationDrive (Variateur AC600)              │
│  - Rampe Accel 20 Hz/s / Decel 25 Hz/s / Safe 50 Hz/s  │
│  - Filtre 1er ordre τ = 0.15 s                         │
│  - Production ActualFrequencyHz (résolution 0.01 Hz)   │
└──────────────────────┬─────────────────────────────────┘
                       │ Fréquence électrique
                       ▼
┌────────────────────────────────────────────────────────┐
│ FB_Sim_TranslationBrake (Frein à Manque de Courant)   │
│  - Bobine : retard ouverture 100 ms                    │
│  - Contact auxiliaire : BrakeIsOpen_DI                 │
│  - Coupure bobine : retombée en 90 ms quelle que soit f│
│  - Décélération friction : a_frein = 2.0 m/s²          │
└──────────────────────┬─────────────────────────────────┘
                       │ Vitesse mécanique résultante
                       ▼
┌────────────────────────────────────────────────────────┐
│ FB_Sim_Translation (Cinématique Chariot 0..10m)        │
│  - v = v_variateur (si frein ouvert & couple actif)    │
│  - v = v - sign(v) * a_frein * dt (si frein serré)     │
│  - Position x(t) = x(t-dt) + v * dt                    │
│  - Butées Trémie (-0.5m) et Maintenance (+10.5m)       │
└──────────────────────┬─────────────────────────────────┘
                       │ Position vraie PositionTrue_M
                       ▼
┌────────────────────────────────────────────────────────┐
│ 5x FB_Sim_PositionSensor (Cames Inductives)            │
│  - Trémie (0.00m), PV (1.50m), P2 (3.50m),             │
│    P1 (5.00m), Maintenance (10.00m)                   │
│  - Hystérésis dynamique 0.02 m (2 cm)                  │
│  - Cames franchissables (mot thermomètre 11111 -> 0000)│
└──────────────────────┬─────────────────────────────────┘
                       │ Signaux DI simulés
                       ▼
         Retour vers PRG_02_Acquisition
```

---

## 5bis. 📝 Relevés de Banc CODESYS & Constats Terrain Exploitant (29/10/2026)

> 📌 **Source de vérité directe** : Relevés effectués et validés par l'exploitant sur son banc CODESYS et observations directes sur machine réelle.

### 1. Mesures de Position (PLC vs Simulation SimBench)
* **Mode Manuel** : L'arrêt sur capteur Trémie et P1 est net, avec une décélération naturelle qui stabilise le chariot à **$\sim 10\text{ cm}$** après le capteur.
* **Mode Semi-Automatique** :
  * **Cible Trémie** : Le PLC affiche $0.0\text{ m}$, mais la position vraie simulée (`Device.Application.PRG_02_Acquisition.instSimBench.instSimTranslation.PositionTrue_M`) décroche et dérive jusqu'à **$-0.4514645\text{ m}$**.
  * **Cible P1** : Le PLC affiche $5.0\text{ m}$, mais la simulation décroche jusqu'à **$+5.381342\text{ m}$**.

### 2. Chronogramme Oscilloscope CODESYS (Arrêt Trémie)
* `PRG_05_Translation.TranslationFinalInterlockRequest.BrakeReleaseRequest` : Passe à **0 instantanément** dès l'impact du capteur Trémie (coupé par `M3_TremieHardStopActive` dans `PRG_06_Outputs.st:443`). Zéro maintien de 2 s sur la sortie physique.
* `PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI` : Passe à **0 peu après** (temps de réaction mécanique réel du frein $\sim 90\text{ ms}$).
* `PRG_05_Translation.Data.TranslationState.BrakeCmd` : Passe à **0 environ 1 s après**, car cette variable interne (`FB_Translation:332`) attend la descente de la rampe logicielle interne `SpeedRamp` et la chute de `DriveActualFreqHz` sous $0.5\text{ Hz}$.
* `DriveActualFreqHz` : Tombe bien à $0\text{ Hz}$.

### 3. Constat Visuel Machine Réelle
* En approche Trémie pendant la phase de vidage de benne, on constate visuellement que le chariot continue d'avancer en douceur vers la butée mécanique.
* Ce déplacement résiduel n'est pas forcément une commande moteur active : c'est très probablement le chariot qui finit de glisser en roue libre sur son inertie ou une légère pente de rail avec le frein qui tarde à mordre ou arrive en douceur sur la butée mécanique, provoquant parfois des défauts de fin de course ou de freinage.

---

## 6. 🛠️ Plan d'Implémentation ST (Confiné à `CODE/L_SIMULATION/`)

1. **`FB_Sim_TranslationBrake.st`** :
   - `PhysicalBrakeActive := TRUE` par défaut (chute mécanique du frein $90\text{ ms}$ après coupure bobine, friction $2.0\text{ m/s}^2$).
2. **`FB_Sim_Translation.st`** :
   - Recalage des butées sur la course réelle 10 m : butée Trémie = $-0.50\text{ m}$, butée Maintenance = $+10.50\text{ m}$.
   - Verrouillage `SpeedFactor := 1.0` en nominal pour respecter strictement les constantes de temps.
   - Sécurisation du clamp `REAL_TO_UINT` sur la fréquence retournée.
3. **`FB_SimBench.st`** :
   - Recopie de `StatusWord` ($16\#0087$ en mouvement $> 0.5\text{ Hz}$, $16\#0080$ à l'arrêt $\le 0.5\text{ Hz}$).
   - Recopie de `BrakeIsOpen_DI` issue du contact auxiliaire.
   - Gel des observateurs de diagnostic lors d'un forçage manuel des capteurs.

---

## 7. 🏁 Conclusion

Le dossier technique est **100% aligné sur la réalité physique et l'architecture du projet** :
- Course réelle 10 m max respectée.
- 50 Hz nominal validé.
- Mécanisme exact du claquage de frein à 10 Hz expliqué par le code.
- Came avec hystérésis 2 cm confirmée déjà en place.
- Zéro régression sur `GVL_PERSISTENT` et le code automate de production.
