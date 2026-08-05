# Analyse Fonctionnelle — Partie 11 : Fonction Translation M3 (v2.1)

> Rôle : positionnement chariot/pont (AC600 EtherCAT), sécurité mouvement, barrière finale.
> Domaine autonome : programme propre (`Translation`), `FB_Safety_Translation` dédié.
> **Détail technique par FB** : voir les 4 fiches dédiées (§1). Ce chapô reste au niveau machine
> + intégration programme — il ne recopie pas les interfaces/`TC-` des fiches.
> Source code : `CODE/TRANSLATION/*.st` · instances dans `PRG_TRANSLATION_CFC.st`, `PRG_SAFETY_CFC.st`, `PRG_OUTPUTS_LD.st` (ST/Ladder actuels).
> Cible de migration CFC native : **une seule page** `PRG_05_Translation.xml` — elle absorbe la partie M3 de `PRG_SAFETY_CFC`. Aucune page safety séparée n'est une cible.
> 🗺️ Architecture cible faisant foi : `DOC/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Translation_Extraction_Code_v1.0.md`.
> v2.0 archivée : `ARCHIVES/Doc/AF_Partie-11_Fonction_Translation_v2.0.md` (§5 audit 2026-08-05 ajouté ici, reste inchangé).

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôle machine
3. DUT et bus
4. Intégration programme
5. Alertes et écarts
6. Documents liés

## 🧪 Points de validation

Catalogue `TC-P11-*` **réparti dans les 4 fiches FB** (propriétaire unique par fiche, pas
dupliqué ici) :

| Fiche | TC couverts |
|---|---|
| [`FB_Translation_PositionDecoder`](AF_Partie-11_Fonction_Translation/FB_Translation_PositionDecoder_v1.0.md) | TC-P11-001, 002 |
| [`FB_Safety_Translation`](AF_Partie-11_Fonction_Translation/FB_Safety_Translation_v1.0.md) | TC-P11-002, 010, 011, 014 |
| [`FB_Translation`](AF_Partie-11_Fonction_Translation/FB_Translation_v1.0.md) | TC-P11-003, 004, 005, 013 |
| [`FB_TranslationOutputInterlock_LD`](AF_Partie-11_Fonction_Translation/FB_TranslationOutputInterlock_LD_v1.0.md) | TC-P11-006, 007, 008, 009 |

TC-P11-012 (Cible Maintenance refusée hors MAINT_N2) et TC-P11-015 (Terrain) restent au niveau
chapô (transverses Modes/terrain).

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P11-012 | Cible Maintenance refusée hors MAINT_N2 | `⚡ AUTO_PLC` |
| TC-P11-015 | Terrain : 5 capteurs réels, watchdog 500ms mesuré, temps réponse variateur | `🟢 SITE` |

---

## 1. Composition — fiches FB dédiées

| Fiche | FB détaillé | Contenu |
|---|---|---|
| [`FB_Translation_PositionDecoder_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Translation_PositionDecoder_v1.0.md) | `FB_Translation_PositionDecoder` | 5 capteurs → mot, butées extrêmes, incohérence |
| [`FB_Safety_Translation_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Safety_Translation_v1.0.md) | `FB_Safety_Translation` | 8 bits ErrorId, Méca A/B, masques, bypass |
| [`FB_Translation_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Translation_v1.0.md) | `FB_Translation` (+ `FB_Brake`, `FB_Ramp`) | Mouvement, rampe, mot AC600, ralentissement PV |
| [`FB_TranslationOutputInterlock_LD_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_TranslationOutputInterlock_LD_v1.0.md) | `FB_TranslationOutputInterlock_LD` | Barrière finale, watchdog frein, anti-redémarrage |

```text
FB_Translation_PositionDecoder ──► FB_Safety_Translation ──► FB_Translation ──► FB_TranslationOutputInterlock_LD
   (5 capteurs, Acquisition)          (safety, Safety)         (mouvement, Translation)   (barrière, Outputs)
```

Un seul axe M3 — pas d'instances ×2 comme Winch.

---

## 2. Rôle machine

Positionnement du chariot/pont par variateur AC600 sur EtherCAT. 5 positions par capteurs TOR
(Trémie, PV, P2, P1, Maintenance). Ralentissement automatique avant Trémie (capteur PV).
Frein à manque de courant. Sécurité par Méca A/B + butées extrêmes + incohérence capteurs.

---

## 3. DUT et bus

| DUT | Producteur | Consommateur |
|---|---|---|
| `ST_TranslationFinalInterlockRequest` | `Translation (CFC)` | `Outputs (Ladder)` |
| `ST_TranslationCmd` | IHM | `Translation` |
| `ST_TranslationState` | `Supervision` | IHM |
| `ST_SafetyTranslation` | `Supervision` | IHM |
| `ST_BypassTranslation` | IHM RETAIN | `Safety`, `Translation` |
| `ST_HwTranslation` | `Acquisition (CFC)` | `Acquisition` (HwIn) |
| `E_TranslationFinalInterlockReason` | `FB_TranslationOutputInterlock_LD` | IHM, Supervision (troubleshooting absorbé) |

📌 Correspondance des POU : `Acquisition` → `PRG_02_Acquisition` · `Safety` M3 + `Translation`
→ `PRG_05_Translation` · `Outputs` → `PRG_06_Outputs_LD` · `Supervision`/`Troubleshooting`
→ `PRG_07_Supervision`.

---

### 4.1 État actuel du code (ST, avant migration)

```text
Acquisition  instPositionDecoder (AVANT Safety)
Acquisition  instJoystick (AxisCmdX, DeadmanArmed)
Safety       instSafetyTranslationM3 — Enable inconditionnel, lit Direction de Translation (1 scan retard)
Modes        MaintenanceM3TargetEnable (Mode=MAINT_N2)
Cycle        CmdTranslationM3_Start/Target (SEMI_AUTO)
Translation  instTranslationM3 → publie TranslationFinalInterlockRequest
Outputs      instTranslationOutputInterlock_LD (Q finales PDO + frein)
```

⚠️ **Ce schéma décrit une cible antérieure, pas l'état réel constaté au code actuel** — voir
§5 alerte 5 : `instSafetyTranslationM3` n'existe dans aucun `.st` du dépôt à ce jour (audit
2026-08-05). Ne pas s'y fier pour évaluer ce qui est câblé.

### 4.2 Cible — `PRG_05_Translation` (rang 05 de la `MainTask`)

```text
02 PRG_02_Acquisition   instPositionDecoder (5 capteurs), instJoystick (AxisCmdX, DeadmanArmed)
03 PRG_03_Modes_Cycle   MaintenanceM3TargetEnable (MAINT_N2), CmdTranslationM3_Start/Target (SEMI_AUTO)
05 PRG_05_Translation   instSafetyTranslationM3 câblé EN PARALLÈLE VISIBLE de instTranslationM3
                            → publie TranslationFinalInterlockRequest + sa demande PowerCutOff M3
06 PRG_06_Outputs_LD        instTranslationOutputInterlock_LD (Q finales PDO + frein), agrégation PowerCutOff
```

⚠️ **Aucune sémantique safety ne change** : Méca A/B, bit 6 butées extrêmes, bit 7 mot capteurs
incohérent, masques, bypass, seuils et polarités restent ceux de `FB_Safety_Translation`. Seule
**l'affectation POU** change.

✅ **Effet attendu de la cible** : la safety M3 et le mouvement M3 étant sur la même page, ils
partagent le même ordre topologique CFC. Le cycle `Safety ↔ Translation` et le retard d'un scan
sur la lecture de `Direction` (§5 alerte 4) disparaissent par construction. ⚠️ Cette suppression
est un **objectif du lot M4**, pas un fait acquis : elle doit être prouvée par `check_linkage.py`
avant clotûre du lot.

📌 Lot de migration : **M4** de `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).
Contrat agent prêt (réécrit 2026-08-05) : `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml`.

**Arbitrage Translation** :
- **SEMI_AUTO** : cible/vitesse depuis Cycle, `StartStop` exige `DeadmanArmed AND AxisCmdX.StartStop`
- **MAINT_N1/N2** : boutons IHM OU joystick (`TglJoystickMaster`) — `DeadmanArmed` exigé **même pour boutons IHM**
- Cible Maintenance (4) refusée hors MAINT_N2
- `InvertDirection` inverse le sens après arbitrage, tous modes

⚠️ Le point « `DeadmanArmed` exigé même pour boutons IHM » ci-dessus est la **cible**, pas
l'état actuel : voir §5 alerte 7, code réel constaté 2026-08-05.

---

## 5. Alertes et écarts

| # | Gravité | Point | Détail |
|---|---|---|---|
| 1 | info | `PowerCutOff M3 codé FALSE` cité par audits historiques — **faux**, calcul réel | Voir `FB_Safety_Translation` §5 |
| 2 | P2 | `PostRampTimeout`(3s)/Méca A(1s) non paramétrables | Voir `FB_Safety_Translation` §7 |
| 3 | P2 | `ApproachSpeedPct` etc. non câblés RETAIN | Voir `FB_Translation` §10 |
| 4 | info | Dépendance croisée Safety↔Translation (1 scan retard) dans le code ST actuel | Clarifié §4.1 ; supprimée par construction dans la cible §4.2 (lot M4) |
| 5 | 🔴 P0 | **`FB_Safety_Translation` n'est instancié nulle part dans `CODE/`** (audit 2026-08-05). `TranslationFinalInterlockRequest.SafeStop` ne reçoit que `PRG_02_Acquisition.InputModuleFault` (1 cause sur 8) ; aucun `PowerCutOff` M3 n'existe. `PRG_06_Outputs_LD.st` (§1 tête de fichier) documente déjà cet écart et maintient `SafetyStructureNotValidated := TRUE` en garde-fou tant qu'aucun lot safety validé ne le retire. C'est le lot **M4** ci-dessus (§4.2), pas encore réalisé. Contrat : `TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml` | PLAN_TASK T104 |
| 6 | 🔴 P0 | **La commande moteur AC600 calculée par `FB_TranslationOutputInterlock_LD` (`DriveControlWord`/`DriveFreqRefHz`) n'est écrite vers aucune sortie physique EtherCAT** (audit 2026-08-05). Seul `BrakeCmd` atteint `PRG_06_Outputs_LD` (`M3_BrakeRelease_RQ`). M3 ne peut physiquement pas bouger même une fois `SafetyStructureNotValidated` levé. Dépendance croisée avec l'alerte 5 : câbler cette sortie sans la safety M3 (alerte 5) ferait bouger le moteur sans les 8 protections. Contrat : `TASK_CONTEXT_LOT2_TRANSLATION_M3_AC600_OUTPUT.yaml` | PLAN_TASK T105 |
| 7 | P1 | **`DeadmanArmed` n'est lu nulle part dans `PRG_05_Translation.st`** (audit 2026-08-05). L'arbitrage `M3_StartStop_Active` cible décrit en §4.2 ci-dessus n'est pas implémenté : ni en SEMI_AUTO, ni en MAINT_N1/N2 boutons IHM. Écart probablement identique côté Winch M1/M2, à vérifier séparément. Contrat : `TASK_CONTEXT_LOT3_TRANSLATION_M3_DEADMAN.yaml` | PLAN_TASK T106 |
| 8 | P1 | **`FB_Diag_IhmHeartbeat` (producteur de `HeartbeatIhmOk`) n'est instancié nulle part** (trouvé en creusant l'alerte 5, audit 2026-08-05). `HeartbeatIhmOk` est lu par `FB_Cycle`, `FB_Safety_Winch` et `FB_Safety_Translation` sans jamais être calculé — prérequis bloquant de l'alerte 5 : câbler la safety M3 sur cette entrée sans ce lot reviendrait à la brancher sur du vide. Contrat : `TASK_CONTEXT_LOT0_DIAG_IHM_HEARTBEAT.yaml` | PLAN_TASK T107 |

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| AF01 | AU/PowerCutOff |
| AF03 | Contrat FB mouvement |
| AF05 | Modes — MAINT_N2 |
| AF06 | 5 capteurs TOR M3 |
| Code | `CODE/TRANSLATION/*.st` |
