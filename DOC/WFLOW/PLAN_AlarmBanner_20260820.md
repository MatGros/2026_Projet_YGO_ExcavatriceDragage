# 🚨 PLAN — Bandeau d'alarme défilant (FB_Hmi_BannerFormatter, champ supplémentaire)

**Date** : 2026-08-20
**Auteur** : DSH-02 (orchestrateur)
**Statut** : Plan validé pour délégation à un agent d'implémentation.
**Criticité** : C3 (affichage IHM, aucune action de sécurité directe — mais alimenté par des états safety).

---

## 1. 🎯 Objectif

Fournir à l'opérateur un **bandeau d'alarme textuel** qui liste les **défauts/warnings actifs de
toute la machine**, affichés **un à la fois en rotation (carrousel)** avec un **indicateur de
position `n/N`** (n = message courant, N = total). Textes **courts** : source (organe) + raison brève.

Il **complète** (n'écrase pas) le bandeau actuel à 4 champs statiques de `FB_Hmi_BannerFormatter`.

## 2. 📐 Décisions validées (utilisateur 2026-08-20)

| # | Décision |
|---|---|
| 1 | Tout défaut/warning/erreur s'ajoute au système. Texte **court** : organe (M1/M2/M3/benne/…) + raison brève. |
| 2 | **Carrousel** : un défaut à la fois, rotation 1→2→…→N→1, **index `n/N`**. |
| 3 | **Étendre** `FB_Hmi_BannerFormatter` d'un **champ supplémentaire** (pas de nouveau FB à l'appel). |
| 4 | **Scope = toute la machine** : safety M1/M2/M3, benne, synchro, cycle, dredging (dive/extraction), AU/armement. |
| 5 | **Hold time = 1 s par message, paramétrable** (ajustable sans recompile). |

## 3. 🧱 Architecture

- **Étendre** `ST_HmiBanner` d'un champ `AlarmBanner : ST_AlarmBanner`.
- **Étendre** `FB_Hmi_BannerFormatter` : nouveaux `VAR_INPUT` (états/défauts déjà produits) +
  sortie `Banner.AlarmBanner` remplie en interne (nouvelle sous-région §5).
- **1 FB = 1 responsabilité** : le formateur garde l'assemblage de l'affichage IHM ; le carrousel
  vit **dans** le formateur (il ne pilote rien, lecture seule du machine state).

## 4. 🗂️ Nouvelles structures

### 4.1 `ST_AlarmBanner` (nouveau `CODE/J_SUPERVISION/_TYPES/.../ST_AlarmBanner.st`)
```iecst
TYPE ST_AlarmBanner :
STRUCT
    HasAlarm  : BOOL;        // TRUE = au moins un défaut/warning actif
    Text      : STRING(120); // Texte du message courant
    Index     : INT;         // Position courante (1-based, 0 si aucun)
    Count     : INT;         // Nombre total de messages actifs
END_STRUCT
END_TYPE
```

### 4.2 `ST_HmiBanner` — ajouter un champ
```iecst
    // ... champs existants
    AlarmBanner : ST_AlarmBanner;   // 🚨 Défauts actifs en carrousel (index n/N)
```

## 5. 🔌 Nouveaux VAR_INPUT de `FB_Hmi_BannerFormatter`

| Input | Type | Source (PRG_07) |
|---|---|---|
| `WinchM1Safety` | `ST_SafetyWinch` | `GVL_IHM.M1TreuilRetenue.Safety` |
| `WinchM2Safety` | `ST_SafetyWinch` | `GVL_IHM.M2TreuilBenne.Safety` |
| `TranslationSafety` | `ST_SafetyTranslation` | `GVL_IHM.TranslationM3.Safety` |
| `BucketErrorId` | `WORD` | `GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId` |
| `SyncErrorId` | `WORD` | `GVL_IHM.M1M2Sync.State.ErrorId` |
| `DiveErrorId` | `WORD` | `GVL_IHM.DredgingAssist.State.DiveErrorId` |
| `ExtractionErrorId` | `WORD` | `GVL_IHM.DredgingAssist.State.ExtractionErrorId` |
| `EmergencyErrorId` | `WORD` | `PRG_06_Outputs.EmergencyDiag.ErrorId` |
| `CycleErrorId` | `WORD` | déjà présent (`instCycleSemiAuto.ErrorId`) |
| `AlarmHoldTime` | `TIME` | **paramétrable** (input, défaut `T#1s`) |

> Les `ErrorId` WORD sont déjà **latches** par chaque FB producteur (persistent jusqu'au Reset) :
> le carrousel n'a pas besoin de re-latch.

## 6. 📖 Dictionnaire organe+raison (textes courts)

Format : `[ORGANE] raison_brève`. L'organe précède, la raison est courte.
⚠️ **Agent** : vérifier chaque bit à la lecture du FB source (les sémantiques ci-dessous sont
issues des déclarations FB ; compléter/corriger au besoin).

### 6.1 M1 / M2 — `[M1]` / `[M2]` (ST_SafetyWinch, champs décodés)
| Champ | Texte |
|---|---|
| `ErrorOperatorComm` | `perte com opérateur` |
| `ErrorEncoder` | `perte codeur` |
| `ThermalFault` | `surchauffe moteur` |
| `SlackCable` | `mou de câble` |
| `ErrorPhaseRotation` | `rotation phases` |
| `CableLimitDescent` | `limite basse câble` |
| `CableLimitAscent` | `butée haute` |
| `ErrorBrakeThermal` | `surchauffe frein` |
| `ErrorMecaA` | `mouvement non commandé` |
| `ErrorMecaB` | `non-arrêt sans commande` |
| `ErrorMecaC` | `glissement benne` |
| `ErrorMecaD` | `non-arrêt capteur haut` |
| `ErrorMecaE` | `écart synchro` |
| `ErrorOppositeDir` | `sens opposé` |
| `ErrorNoMovement` | `absence mouvement` |

### 6.2 M3 — `[M3]` (ST_SafetyTranslation)
| Champ | Texte |
|---|---|
| `ErrorOperatorComm` | `perte com opérateur` |
| `ErrorDriveComm` | `perte EtherCAT` |
| `ErrorPhaseRotation` | `rotation phases` |
| `ErrorBrakeThermal` | `surchauffe frein` |
| `ErrorMecaB` | `non-arrêt` |
| `ErrorMecaA` | `mouvement non commandé` |
| `ErrorLimitSwitch` | `butée extrême` |
| `ErrorSensorIncoherent` | `capteurs incohérents` |

### 6.3 Benne — `[BENNE]` (FB_Bucket.ErrorId, bit0-4)
| Bit | Texte (à confirmer à la lecture FB) |
|---|---|
| bit0 `16#0001` | `défaut benne` |
| bit1 `16#0002` | `timeout` |
| bit2 `16#0004` | `limites` |
| bit3 `16#0008` | `défaut séquence` |
| bit4 `16#0010` | `glissement M1` |

### 6.4 Synchro — `[SYNC]` (FB_WinchSync.ErrorId)
| Bit | Texte |
|---|---|
| bit0 `16#0001` | `écart M1/M2` |
| bit1 `16#0002` | `incohérence` |

### 6.5 Cycle semi-auto — `[CYCLE]` (FB_Cycle.ErrorId)
| Bit | Texte (à confirmer à la lecture FB) |
|---|---|
| selon FB | `défaut cycle` (agent : mapper chaque bit) |

### 6.6 Dredging — `[DIVE]` (FB_DiveSearch) / `[EXTRACTION]` (FB_ExtractionSequence)
| Source | Bits | Texte |
|---|---|---|
| `DiveErrorId` | bit0 precond, bit1 seq, bit2 cfg | `plongée : préconditions` / `plongée : séquence` / `plongée : config` |
| `ExtractionErrorId` | bit0 fond, bit1 ferme, bit2 ctrl, bit3 cfg | `extraction : fond` / `fermeture` / `contrôle` / `config` |

### 6.7 AU / armement — `[AU]` (EmergencyDiag.ErrorId)
| Bit | Texte |
|---|---|
| bit0 `16#0001` | `redondance contacteurs` |
| bit1 `16#0002` | `échec confirmation armement` |

## 7. ⏱️ Logique carrousel (pseudo-ST, §5 de FB_Hmi_BannerFormatter)

```iecst
// 5. BANDEAU D'ALARME — carrousel des défauts actifs (index n/N)
// Constante NB_MAX_ALARMES (ex. 32). HoldTime = AlarmHoldTime (input, paramétrable).

// 5a. Collecte : remplir AlarmArray[0..Count-1] (IF sur chaque bit/état du §6).

// 5b. Rotate
IF AlarmCount = 0 THEN
    AlarmIndex := 0;
    Banner.AlarmBanner.HasAlarm := FALSE;
    Banner.AlarmBanner.Text  := '';
    Banner.AlarmBanner.Index := 0;
    Banner.AlarmBanner.Count := 0;
    TonAlarmBanner(IN := FALSE);
ELSE
    Banner.AlarmBanner.HasAlarm := TRUE;
    TonAlarmBanner(IN := TRUE, PT := AlarmHoldTime);
    IF TonAlarmBanner.Q THEN
        AlarmIndex := (AlarmIndex + 1) MOD AlarmCount;
        TonAlarmBanner(IN := FALSE);
    END_IF;
    Banner.AlarmBanner.Text  := AlarmArray[AlarmIndex];
    Banner.AlarmBanner.Index := AlarmIndex + 1;   // 1-based
    Banner.AlarmBanner.Count := AlarmCount;
END_IF;
```

> Ordre d'ajout dans `AlarmArray` = **ordre déterministe fixe** (priorité/apparition).
> `MOD` robuste si `AlarmCount` change (index ≥ count → reborn à 0).

### Variables locales
- `AlarmArray : ARRAY[0..31] OF STRING(120);` (NB_MAX_ALARMES = 32)
- `AlarmCount : INT;` / `AlarmIndex : INT;`
- `TonAlarmBanner : TON;`
- `NB_MAX_ALARMES : INT := 32;` (constante)

## 8. 🔧 Câblage (PRG_07_Supervision.st, instHmiBannerFormatter)

Ajouter au call existant (les `ErrorId` WORD viennent des bus/structs IHM déjà présents) :
```iecst
    WinchM1Safety        := GVL_IHM.M1TreuilRetenue.Safety,
    WinchM2Safety        := GVL_IHM.M2TreuilBenne.Safety,
    TranslationSafety    := GVL_IHM.TranslationM3.Safety,
    BucketErrorId        := GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId,
    SyncErrorId          := GVL_IHM.M1M2Sync.State.ErrorId,
    DiveErrorId          := GVL_IHM.DredgingAssist.State.DiveErrorId,
    ExtractionErrorId    := GVL_IHM.DredgingAssist.State.ExtractionErrorId,
    EmergencyErrorId     := PRG_06_Outputs.EmergencyDiag.ErrorId,
    AlarmHoldTime        := T#1s,   // paramétrable (GVL ou IHM si voulu)
```
`GVL_IHM.Banner := instHmiBannerFormatter.Banner;` inchangé.

## 9. 🖥️ Consommation IHM
- Afficher `Banner.AlarmBanner.Text` + indicateur `"n/N"` (`Index` / `Count`).
- La rotation est **dans le PLC** (carrousel indexé) → l'IHM n'a pas besoin d'animation marquee.
- `HasAlarm=FALSE` → champ vide.

## 10. 🔭 Extensions futures (hors périmètre v1)
- **Warnings** non bloquants distincts des **défauts** bloquants (2 catégories visuelles).
- Historique / latches multi-occurrences (aujourd'hui : états latches des FB).

## 11. ✅ Vérification obligatoire (bloquante, exécutée par l'agent)
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
python TOOLS/PLC_LIVE_READER/variable_lists/generate_variable_list_from_code.py
```
Coller le bloc `Auto-vérification liaison` (G200) dans la restitution.

## 12. 📝 Doc & REX
- `ARCHIVES/Doc/AF/AF_Partie-07_Interface_IHM_v2.0.md` : nouveau champ + carrousel (§ bandeau).
- Versionner (`_v2.1`), archive `_v2.0` dans `ARCHIVES/Doc/`.
- `VERSION_HISTORY.md` : une ligne.

## 13. 🚫 Contraintes & interdits pour l'agent
- **Aucun commit/push** — validation humaine (orchestrateur).
- **Ne pas toucher** la logique safety (`FB_Safety_*`), le mouvement, ni les `Enable`.
- `FB_Hmi_BannerFormatter` reste **lecture seule** du machine state : ne pilote rien.
- Pas de `FB_Watchdog` applicatif, pas de `CoupeEnable`.
- Textes courts (§6), zéro "journal intime" dans les commentaires (G430).
- Vérifier chaque bit du §6 à la lecture du FB source avant de figer le texte.

## 14. 🔢 Paramètres
| Paramètre | Valeur | Note |
|---|---|---|
| `NB_MAX_ALARMES` | 32 | large (pas de limite pratique) |
| `AlarmHoldTime` | `T#1s` | **paramétrable** (input) |
| Scope v1 | toute la machine (§2 décision 4) | |
