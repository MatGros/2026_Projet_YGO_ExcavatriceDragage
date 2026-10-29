# AUDIT CRITIQUE — Simulation M3 (T417)

## ⚠️ Cadrage honnête (à lire avant le verdict)

| Élément | État |
|---|---|
| Code fourni | Extrais **partiels** : `FB_Sim_Translation` = **en-tête VAR uniquement**, corps absent → aucun verdict sur la dynamique réelle |
| Fichiers lus | Aucun accès disque sur cette session → pas de `file:ligne`, pas de G200, pas de bundle |
| Doc de référence | `AF_Partie-13` **non lue** → contradictions doc/code = hypothèses, pas des faits |
| Preuves exécutables | **Aucune**. Verdict = lecture statique d'extraits |

➡️ **Verdict global : MAJOR** — rien d'isolément *cassé*, mais le banc **ne peut pas révéler les défauts qu'il est censé révéler**. 3 points de complaisance documentés en §« Devoirs d'alerte ».

---

## Q1 — Manques physiques de `FB_Sim_Translation`

**Fait structurant** : le modèle est **cinématique** (position = ∫ sens × gain × fréquence). Aucune notion de couple → toute défaillance mécanique réelle est **inexprimable** sauf par flag dédié.

| # | Manque | Impact banc | Sév. |
|---|---|---|---|
| M1 | **`SpeedFactor` ≠ changement d'échelle temporelle** : multiplie vitesse *et* fréquence retournée, mais `BrakeOpenDelayS/CloseDelayS`, `SensorStabilizationS`, `SensorElectricalDelayS`, `DriveTimeConstantS` restent en **temps réel** | À `SpeedFactor = 3`, les distances parcourues pendant les délais sont **×3 trop grandes**. Un banc validé à 3 ne prouve **rien** à 1,0. Aucune garde ne verrouille ce facteur | 🔴 |
| M2 | **Double modèle de charge** : `CartFreeActive` (L4 : masse, pente, frottement) **et** `LoadFrequencyDroopGain_Hz` (droop) coexistent. Aucune exclusivité mutuelle documentée | Si les deux sont actifs → **double comptage** de l'effet benne. Sinon → branche morte. Combinatoire `5 flags × 2 = 32` profils, **non testée** | 🔴 |
| M3 | **Butée = contact rigide** (`EndStopRecoilMax_M` défaut 0 → position **et vitesse figées**) | Choc à décélération infinie. `ObsEndStopImpactSpeed_Mps` est mesuré mais **sans effet** par défaut. Le variateur qui pousse en butée ne déclenche **aucun défaut** → cas réel (`State.ErrorId` en butée) non rejouable | 🟠 |
| M4 | **Pas de frottement statique** (Stribeck) : `RollingFriction_Mps2` constant. Un chariot à l'arrêt n'a aucune raison de rester bloqué sous faible poussée | Chariot bloqué mécaniquement **non simulable** (seul `BrakePhysicalActive` bloque) | 🟠 |
| M5 | **Pas de jeu mécanique (backlash)**, pas de **raideur de chaîne/câble** | Pas d'oscillation ni de dépassement d'inversion — or `ObsOvershootLast_M` existe, donc on cherche à mesurer ce que le modèle ne produit pas | 🟡 |
| M6 | **`ActualFrequency_Hz` n'est pas un retour moteur** : pas de glissement asynchrone, pas de temps de montée de flux, pas de **saturation couple / limitation de courant** | Un variateur qui **ne suit pas** la consigne (limite de courant) est **inexprimable** → `FB_Safety_Translation` (écart consigne/réel) ne peut jamais se déclencher sur ce cas | 🟠 |
| M7 | **Jitter capteur constant** (`0.01 m`) : non corrélé à la vitesse ni à l'entrefer. Pas de dérive thermique, pas de capteur **colmaté/noyé** (contexte drague en carrière noyée !) | 🟡 |
| M8 | **`REAL_TO_UINT` sans clamp** côté SimBench : fréquence négative (bruit autour de 0) → conversion non spécifiée en CODESYS | Risque valeur aberrante sur `M3_ActualFrequencyHz` | 🟡 |
| M9 | **40+ entrées, 5 couches L1..L5**, valeurs « HYPOTHÈSE sans mesure terrain » assumées | Dette : chaque couche ajoute une branche non couverte | 🟠 |

---

## Q2 — Fidélité de `FB_Sim_TranslationBrake`

### ✅ Ce qui est juste
- `CoilEnergized := ReleaseCmd AND NOT FaultCloseActive` → **jamais** « bobine énergisée ET frein serré ». Cohérent avec un électro-aimant à manque de courant.
- `ContactOpen` suit `MechanicallyOpen` avec `ContactDelay_S` → **contact auxiliaire réaliste**, distinct de la commande.
- **Timer partagé `MechanicalTimer_S` = VÉRIFIÉ, pas un bug** : chaque branche le remet à 0 hors transition, donc l'ouverture et la fermeture ne s'héritent jamais. Fragile, mais correct en l'état.

### 🔴 Défaut de fidélité majeur (assumé mais problématique)
```pascal
ELSIF FaultCloseActive OR PhysicalBrakeActive OR (ActualFrequency_Hz <= CST_StopFrequency_Hz) THEN
```
La fermeture nominale dépend **de la fréquence**, pas de la **perte de bobine**. Un frein à manque de courant retombe **CloseDelay après coupure bobine, quelle que soit la vitesse**. Autrement dit : **`PhysicalBrakeActive := FALSE` est physiquement faux par défaut**, et il recopie la logique PLC (garde 0,5 Hz) *dans l'usine simulée*.

➡️ Conséquence : si le PLC coupe la commande de frein alors que le variateur retourne encore 10 Hz, **le simulateur attend sagement** que ça retombe. Le banc **valide le PLC avec sa propre logique**. C'est exactement l'anti-pattern que la garde terrain a déjà révélé (trace 2026-09-04, 26,437 s).

### 🟡 Points mineurs
| # | Constat |
|---|---|
| B1 | **`FaultCloseWhileRunning` ment** : la faute s'applique **même à fréquence nulle** (`FaultTimer_S` non conditionné à `ActualFrequency_Hz > 0.5`). Le commentaire dit « la garde nominale n'est pas modifiée » — vrai pour la *valeur du seuil*, faux pour l'effet : la garde est **contournée** |
| B2 | `FaultTimer_S` court **même si `ReleaseCmd = FALSE`** → faute pouvant s'activer avant toute demande de mouvement |
| B3 | **`CoilEnergized := FALSE` est une hypothèse d'implémentation** de la faute (« câblage bobine défaillant »), pas la seule. La faute observée au terrain est un **contact** qui se ferme ; le nom devrait le dire |
| B4 | `CycleTime_S` en **VAR_INPUT (défaut 0,01)** : si l'appelant oublie ou si la tâche tourne à 20 ms → **tous les délais divisés par 2, silencieusement**. Aucune garde |
| B5 | **Pas d'hystérésis mécanique** : `ReleaseCmd` bruité (rebond) avec `f > 0,5` → timer remis à 0 à chaque cycle → frein **jamais fermé**. Physiquement un frein réel a une constante de temps qui amortit ; le modèle non |
| B6 | `CoilEnergized` est un **état logique**, pas une mesure de courant → bobine coupée (fil) non simulable |
| B7 | Pas de **couple de freinage progressif** : tout-ou-rien + `BrakeDecel_Mps2` constant → pic de décélération à l'impact **sous-estimé** |

---

## Q3 — Câblage capteurs + StatusWord dans `SimBench`

### 🟢 Points solides
- `Translation.M3_BrakeIsOpen_DI := instSimTranslation.BrakeContactOpen` → le PLC voit le **contact physique**, pas la commande. ✅ La faute frein **est** bien visible côté PLC. Bonne conception.
- Override manuel conservé **dans le même ordre de bits** que `FB_Translation_PositionDecoder` ; l'override reste borné au mot capteur, pas au modèle. ✅

### 🔴 Artificiellement figé — risque de validation complaisante

| # | Constat | Effet |
|---|---|---|
| S1 | **`AC600_DeviceState := DEVICE_STATE.RUNNING` en dur** + `M3_ThermalOK_DI := TRUE` en dur | **Aucun chemin de faute variateur simulable** : pas de FAULT, pas d'arrêt, pas de perte de comm, pas de défaut thermique. Or les codes de faute sont cités en propre commentaire (`State.ErrorId=64`) → le banc **ne peut pas rejouer le terrain** |
| S2 | **`StatusWord` à 2 valeurs** (0x0087 / 0x0080), seuil 0,5 Hz | Bit 0 = `f > 0,5 Hz` **au lieu de** « variateur enabled ». Deux conséquences : (a) **pas d'état « enabled à 0 Hz »** (maintien en couple avant fermeture frein) ; (b) « mouvement non commandé » que surveille Méca B est **structurellement indétectable** (variateur qui pousse alors que la consigne est coupée) |
| S3 | **Sémantique des bits incertaine** : `16#0087` = bits 0,1,2,7. Profil ABB Drives : bit 7 = **warning**, bit 3 = **fault**. Le commentaire dit « Bit 7 (Comm Ready) ». Incohérent avec le standard ABB → **à vérifier contre le manuel AC600 + `DOC/AF`** avant de conclure. Si bit 7 = warning, le PLC reçoit un **warning permanent en marche** | 🔴 incertitude, pas encore un bug |
| S4 | **`M3_RelayFwd := ReqTremie AND NOT ReqMaintenance`** : demande contradictoire **absorbée silencieusement** (aucun mouvement, aucun diagnostic) | Le banc ne peut **pas** révéler une séquence qui demande les deux sens → l'interlock mécanique réel n'est jamais éprouvé |
| S5 | Override capteurs actif **sans geler les observateurs** : le modèle continue de tourner, `M3ObsPositionError_M`, `ObsOvershoot*`, `ObsEndStopHitCount` continuent de s'incrémenter | Diagnostics **fictifs** pendant un test forcé → bruit d'analyse, faux positifs de comptage |
| S6 | **Pas de capteur « collé à 1 »** (failure to release) : seules la perte (intermittence, dropout) et la came sont modélisées | Panne réelle et **dangereuse** : PLC croyant le chariot en zone Trémie alors qu'il est ailleurs → refus de mouvement ou pire. Non simulable |
| S7 | `REAL_TO_UINT(f * 100.0)` : troncature et **pas de clamp** sur valeur négative | Voir M8 |
| S8 | Hystérésis capteur **unique** (0,02 m) pour 5 capteurs | Entrefer/came réels différents → transitions simultanées non physiques |

---

## Q4 — Recommandations architecturales (par ratio bénéfice/complexité)

| P | Action | Coût | Bénéfice |
|---|---|---|---|
| **P0** | **`PhysicalBrakeActive := TRUE` par défaut** ; renommer l'ancien mode `LegacyPlcMirror` (explicite, réservé au rejeu de traces) | ~0 (défaut) | Supprime la complaisance n°1 : le banc peut enfin voir « frein serré / variateur qui pousse » |
| **P0** | **Un seul modèle de charge** : rendre `CartFreeActive` et `LoadFrequencyDroopGain_Hz` **mutuellement exclusifs** (assertion ou `IF/ELSE` explicite), documenter la matrice 32 profils dans `AF_Partie-13`, et un gate qui vérifie chaque flag consommé | 0,5 j | Élimine M2 |
| **P0** | **Séparer `SpeedFactor` du temps physique** : soit `TimeScale` global (dt divisé), soit **interdire** `SpeedFactor ≠ 1` en essai de validation | 1 j | Élimine M1 — sinon **aucun essai accéléré n'est probant** |
| **P1** | **`FB_Sim_AC600_Status`** : petit FB, entrées `SimFaultCode`, `SimCommLoss`, `SimThermalTrip`, `SimEnabled` ; StatusWord **construit bit à bit** depuis un DUT de bits nommés ; `DeviceState` piloté. Défaut = nominal → non-régression | 1,5 j | Débloque S1/S2/S3 : devient le **seul** moyen de tester les chemins de sécurité variateur |
| **P1** | **Butee ressort-amortisseur** `F = k·pen + c·v` (2 paramètres) + **faute variateur en butée** | 0,5 j | M3, et rend `ObsEndStopImpactSpeed_Mps` cohérent |
| **P1** | **`SensorStuckActive`** (collage à 1, index capteur) + jitter corrélé au gradient | 0,5 j | S6 |
| **P2** | Timers frein **distincts** + sortie `TransitionActive` ; `CycleTime_S` mesuré (`TimeNow - LastTime`) ou garde d'égalité ; `FaultClose` conditionné à `f > 0,5` et renommé | 0,5 j | B1..B4 |
| **P2** | `REAL_TO_UINT(MAX(0.0, f) * 100.0 + 0.5)` (clamp + arrondi) | 5 min | M8/S7 |
| **P2** | Diagnostic **demande contradictoire** M3 (au lieu du masquage silencieux) | 0,5 j | S4 |
| **P2** | Geler les observateurs pendant l'override capteurs | 0,5 j | S5 |
| **P3** | **`ST_SimM3Config` en `VAR_IN_OUT`** unique + 3 profils figés (Nominal / Legacy / Stress) au lieu de ~40 flags libres | 1 j | M9 : interface relisible, gate possible par champ |

**Principe directeur** : ne pas ajouter de couches L6/L7. Le FB a déjà 5 couches empilées derrière des flags `FALSE` — **la combinatoire est le vrai risque**, pas le manque de réalisme. Consolider > empiler.

---

## 🚨 Devoirs d'alerte (hors scope, non corrigés)

1. **Complaisance du frein** : `PhysicalBrakeActive := FALSE` par défaut = logique PLC recopiée dans le modèle. Le banc valide le PLC **avec sa propre garde**. *(impacte tout essai de séquence frein/variateur)*
2. **`DEVICE_STATE.RUNNING` + `ThermalOK := TRUE` figés** : aucun chemin de faute variateur n'est testable. Or le terrain en produit (`ErrorId=64`).
3. **Sémantique `16#0087`** : conflit entre le commentaire (« Bit 7 = Comm Ready ») et le profil ABB (bit 7 = warning). **À trancher contre le manuel AC600** avant qu'un relecteur ne valide un warning permanent comme normal.
4. **`SpeedFactor`** : paramètre de confort d'essai qui **invalide physiquement** les temporisations. S'il est utilisé en validation, les preuves de validation sont nulles.

---

## Preuves manquantes / ce qu'il me faut pour conclure

```text
Auto-vérification liaison (G200_check_linkage.py) — NON EXÉCUTÉ
  Raison : aucun accès outillage sur cette mission (lecture d'extraits uniquement)
  À produire : G200_check_linkage.py --report sur bundle frais
Gates : NON EXÉCUTÉS (structure / style / liaison / persistance / bundle / pytest)
Diff bundle : non produit
Contrat de tâche : ABSENT — critères d'acceptation non fournis (tâche ≥ C2)
```

Pour passer de **MAJOR (lecture statique)** à un verdict opposable, il me faut :
1. Le **corps complet** de `FB_Sim_Translation` (intégration position/vitesse, ordre clamp butée/capteurs, usage réel de `SpeedFactor`).
2. L'appel **`FB_Sim_Translation → FB_Sim_TranslationBrake`** avec le câblage effectif de `CycleTime_S`.
3. `DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md` (contrat censé définir L1..L5) + le mapping officiel des bits StatusWord AC600.
4. Le **contrat de tâche T417** avec critères testables.

Sans (1) et (4), je ne peux pas certifier la dynamique — seulement les interfaces et le câblage.