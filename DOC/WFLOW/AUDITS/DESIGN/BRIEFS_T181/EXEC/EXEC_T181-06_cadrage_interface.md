# CONSIGNE D'EXÉCUTION — T181-06 : Cadrage de l'interface `ST_fbWinch_DriveRequest`

**Pour : Codex Terra ou Claude (tâche doc/analyse).** À coller tel quel.
**ARRÊT VALIDATION HUMAINE** en fin de tâche — aucune écriture `CODE/`, aucun commit.

---

## 1 · Rôle & règles

- Expert Senior Automatisme CODESYS 3.5 + POO/FB + sécurité machine. FR, concis, tableaux.
- Lis **d'abord** : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
- **Aucune écriture dans `CODE/`.** Livrable = **note de cadrage** + **section AF-10** (docs uniquement).
- Tu **ne réinventes pas** l'interface : elle est déjà spécifiée (doc #1 ci-dessous). Tu la mets au propre, tu tranches les 6 points ouverts, tu produis l'AF.
- Incohérence / point non tranchable → **remonter**, ne pas deviner.

## 2 · Contrat (référence de succès)

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-06_DRIVEREQUEST_CADRAGE.yaml` — **AC1 à AC8 + AC7b/AC7c**.

## 3 · Documents de référence

| # | Document | Pour |
|---|---|---|
| 1 | `DOC/WFLOW/AUDITS/DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` | **la spécification d'interface — FAIT FOI.** DUT, sous-FB, nommage, principes P1-P8, §7 = les 6 points à trancher |
| 2 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md` §4 + §13 | contrat de flux, amendements A/B/C/D, corrections B2 |
| 3 | `DOC/WFLOW/AUDITS/DESIGN/BRIEFS_T181/RESULTS/B2_challenge3_resultat.md` §4.3 | override benne (tranche proposée) |
| 4 | `DOC/WFLOW/AUDITS/DESIGN/BRIEFS_T181/RESULTS/B4_review_independante.md` §3.2 | `FB_WinchSync`/`Symmetry` hors périmètre — à cadrer |
| 5 | `DOC/STDS/NAMING_CONVENTION.md` (NC-050, NC-090, NC-110, chaîne `Req/Tgt/Cmd/Act`) | validation des noms |
| 6 | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` + `DOC/AF/AF_Partie-10_Fonction_Winch/FB_Winch_v1.0.md` | format AF (tables HTML), fiche actuelle |
| 7 | `CODE/H_TREUILS_BENNE/FB_Winch.st`, `FB_SpeedStep.st`, `CODE/M_MAIN/PRG_04_Treuils_Benne.st` §3 et §6 | l'existant à faire évoluer |
| 8 | `CODE/H_TREUILS_BENNE/FB_WinchSync.st`, `FB_Winch_Symmetry.st` | dépendances non cadrées |

## 4 · Objectif mesurable

### Livrable A — note de cadrage à créer : `CADRAGE_T181-06_DRIVEREQUEST.md` dans le dossier `DOC/WFLOW/AUDITS/DESIGN/`

1. **DUT champ par champ** : `ST_fbWinch_DriveRequest`, `ST_fbWinch_Sensors`, `ST_fbWinch_Cfg`, `ST_WinchFinalInterlockReq` — nom (PascalCase, NC-050), type, unité (`_M`/`_Mps`, NC-030), polarité, producteur, consommateur. Repris de doc #1, mis au format contrat.
2. **Tableau des sources de borne de clamp** : ≥ 8 sources × { sens Asc/Desc | portée commun M1=M2 / M2-propre | lieu de calcul }. Aucune case vide. (Amendement A.)
3. **Règle de précédence Min/Max** en pseudo-code + cas limite `MinStepDown=3 & MaxStepDown=1 → 1`. Garde `FB_SpeedStep : LIMIT(1, MinStepNumber, MaxStepClamped)` après plafond, avant `CASE`. (Amendement B.)
4. **Flux `MinStepDown`** : schéma `FB_DiveSearch (instancié PRG_03) → PRG_03.ReqProgram → PRG_04 → DriveRequest`. **Intra-cycle, zéro latence** (exécution séquentielle mono-tâche — ne PAS écrire « 3 tâches »). Gating sur front `DescentActive` + cas « maintien descente joystick post-fond ». (Amendement C + correction B2-§4.1.)
5. **`MinStepNumber` agit sur `RequestedStep`** (cible), lissé par le `TON` inline de rampe (pas de FB séparé). Interdiction d'affecter `StepNumber` directement. (Amendement D.)
6. **Matrice d'interconnexion** producteur → `DriveRequest` : 8 lignes (Cycle, PRG_03, DiveSearch, ExtractionSequence, Joystick, Modes, IHM, Bucket) — mapping OK / gap / impossible + commentaire.
7. **Les 6 points de doc #1 §7 tranchés** : (a) valeurs des 2 constantes de seuil de `FB_WinchRateInterlock` ; (b) D13 (garder/supprimer `M2_SpeedStepTableActive`) ; (c) forme de ré-alimentation `ContactorsCheck.StuckClosed` depuis `FB_Safety_Winch` ; (d) `BucketJogStep : INT` (pas de %) ; (e) structure RETAIN table apprentissage + bornes de plausibilité par palier + procédure 1ʳᵉ mise en service ; (f) ordre d'import CODESYS incluant `PRG_07` + `_TYPES` supervision.
8. **Cadrage `PRG_04 ↔ instWinchSync`** : où reste l'arbitrage sync (`SafeStopMx_Active` couplé, `EffectivePermit`, `SyncDeviationWarn` → clamp) quand l'agrégateur de clamp T181-10 est écrit. `FB_Winch_Symmetry` (mesure passive) : reste hors interface `FB_Winch`, noté.
9. **Place de l'override benne** : branche `IF instBucket.Busy` de `PRG_04 §3` écrit `DriveRequest.{StartStop,Direction}` de M2 (reste §3) ; `15.0` → `Config`/`BucketJogStep`. (AC7b.)

### Livrable B — section AF-10

Rédiger une nouvelle fiche `FB_Winch` v2.0 dans le dossier `DOC/AF/AF_Partie-10_Fonction_Winch/` (format des fiches sœurs du dossier) : rôle, profil, interface (les 4 DUT + `FB_Winch` IN/OUT), consommateurs, TC couvrants (référencer les TC HARN et les `TC-P10-*` existants), suivi historique. Cohérente avec la note de cadrage.

## 5 · Restitution

- Les 2 fichiers (contenu complet).
- Sortie de `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-06_DRIVEREQUEST_CADRAGE.yaml` (doit rester PASS).
- Sortie de `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py`.
- Liste des points où tu as dû interpréter → pour l'orchestrateur.
- **STOP — validation humaine avant tout code aval (T181-07/08/...).** Aucun commit.
