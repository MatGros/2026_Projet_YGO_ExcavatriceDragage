# 📦 RAPPORT T181-12 — Plancher de palier en plongée + câblage bug D12

> Rapport d'orchestration transmissible à l'agent orchestrateur.
> Date : 2026-08-30 · Criticité C3 · Stratégie patch · Worktree isolé `.mgs-worktrees/T181-12` (branche `T181-12`, base main `22fe2fdd` + état live réaligné).

---

## 1. Verdict de revue (défi orchestrateur)

| Axe | Verdict | Preuve |
|---|---|---|
| Liaison structurelle | ✅ PASS | G200 : symboles du lot 0 erreur ; seuls 2 WARN L10 (assignations multi-branches, pattern identique `ForceMinSpeedStep`) |
| Contrat FB / nommage | ✅ PASS | `MinStepDown : INT` PascalCase, commentaires `[STAT]`/`[CFG]`, vocabulaire `Min*` aligné roadmap |
| Encapsulation / producteur unique | ✅ PASS | producteur `FB_DiveSearch`, routage `PRG_03`, agrég. `PRG_04 §5ter`, champ `ReqBucket.MinStepDown` |
| Logique métier / sécurité | ✅ PASS | plancher gaté `DescentActive`+phases, 0 résiduel hors plongée, « plafond gagne » préservé |
| Critères structurels AC6/AC7 | ✅ PASS | fichier=POU, ST pur, aucun suffixe `_CFC`/`_LD` ajouté |
| Gates (non-régression) | ⚠️ VERT sur lot | 5 gates FAIL **tous préexistants/hors scope** (détail §5) ; 0 échec imputable à T181-12 |

**Verdict global : PASS.** Le lot livre le producteur du plancher + flux jusqu'à l'agrégateur §5ter, conforme AC1–AC7. La consommation physique dans FB_Winch est hors périmètre (FB_Winch interdit) → **T181-13**.

---

## 2. Contenu livré (diff réel, 4 fichiers scopés, +33/−2)

### Volet A — câblage D12 (`CurrentSpeedStep` enfin alimenté)
```st
// PRG_03 → instDiveSearch
CurrentSpeedStep := PRG_04_Treuils_Benne.Data.WinchM1State.StepNumber,
```
- **Porteur du palier M1 réel** : `PRG_04.Data.WinchM1State.StepNumber` = `instWinchM1.StepNumber` (palier actif, pilote contacteurs `Contactor1..4`).
- Le latch `Palier5ForbiddenFault` (§3) + cause `instCauses[3]` deviennent **effectifs** → interdiction palier 5 en plongée Kobold fonctionnelle.
- **Lag 1 scan assumé** (PRG_03 rang 03 lit PRG_04 du scan précédent), documenté — pratique existante du programme.

### Volet B — producteur + flux du plancher plongée
- `FB_DiveSearch` : sortie **`MinStepDown : INT`** (0 hors plongée) ; config `CfgDiveFloorStep : INT := 3` (défaut roadmap).
- Logique : `IF DescentActive AND (SEARCHING_IMMERSION OR SEARCHING_BOTTOM) THEN MinStepDown := CfgDiveFloorStep ELSE MinStepDown := 0` + remise à 0 au gate §2 (Enable off) → **aucun plancher résiduel**.
- `ST_ProgramBucketRequest` : champ `MinStepDown : INT`.
- PRG_03 : `ReqBucket.MinStepDown := instDiveSearch.MinStepDown` (MAINT), `0` (SEMI_AUTO/DISABLE).
- PRG_04 §5ter : `CommonMinStepDown := MAX(1, ReqBucket.MinStepDown)` ; `M2MinStepDown := CommonMinStepDown`.

### Forme retenue (INT vs BOOL+palier fixe)
**INT** transportant la valeur du palier, alimenté par `CfgDiveFloorStep` — plus simple/lisible, sans mapping BOOL→palier réinventé, aligné vocabulaire `MinStep*`/`Req→Tgt→Cmd`. Aucun seuil inventé (3 = roadmap).

---

## 3. AC4 — maintien joystick post-fond → aucun mouvement résiduel (confirmé)

1. `MinStepDown = 0` le **même scan** dès sortie de `SEARCHING_IMMERSION/BOTTOM` (BOTTOM_CONFIRMED / ERROR_HOLD / WAIT_PRECONDITIONS).
2. `KoboldBottomTouchLatched` (PRG_04 §5) coupe `EffectivePermit*_Descend` → FB_Winch reçoit `SafeStop` pour la descente → **aucun mouvement** possible, indépendant du plancher.
3. Lot ne consomme pas encore dans FB_Winch → **structurellement aucune voie** de forcer un palier/mouvement.

---

## 4. Règle « plafond gagne » — préservée
`MAX(1, source)` = plancher MAX des sources plancher ; plafond = borne imposée (clamp final aval, consommation FB_Winch). Jamais de palier forcé au-delà de `CommonMaxStepDown`.

---

## 5. Gates
- `generate_codesys_bundle.py` : **exit 0** (bundle frais, 208/208).
- G200 : seul KO = **orphelin préexistant `FB_WinchSpeedLearning`** (HEAD, hors périmètre) — non créé par le lot.
- `run_all_gates.py` : 26 PASS / 5 FAIL **tous préexistants/hors scope** : G200 (orphelin), G340 (5 liens `ld_builder.py` docs), G430 (commentaires T181 préexistants — l'apport du lot a été retiré), G481 (crash tooling `run_tests.py`), G484 (script absent).
- Aucun échec causé par le contenu fonctionnel de T181-12.

⚠️ Transparence : le bundle a **régénéré** `CODE_XML/*.xml` (artefacts) dans le worktree ; le worktree contient aussi les changements T181 préexistants non commités (FB_Winch*) — non touchés par le lot.

---

## 6. Points de challenge / recommandations orchestrateur
1. `CfgDiveFloorStep` reste un input FB avec défaut 3 — **non câblé depuis IHM/config** (hors scope). Si une mise à jour doit le rendre réglable IHM, lot dédié.
2. La **consommation physique** dans FB_Winch (port `MinStepDown`/`MinStepFloor` côté cible) est **absente** — c'est le cœur de **T181-13**, à confirmer dans ce lot.
3. AC3 (interdiction palier 5) n'a pas de TC dans ce lot (tests différés asynchrone) — à couvrir côté T181-13/harnais.

**Clôture : aucun commit effectué (interdit) · diff prêt à validation orchestrateur + intégration CODESYS manuelle.**
