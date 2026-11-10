# ↔️ T108 — Interlock Translation M3 si Trémie pleine / grille levée

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T108 — interdire la Translation M3 vers
> la **Trémie** quand `TremieFull_OR_GateRaised_DI` est actif (trémie pleine OU grille levée).
> Source : `PRG_05_Translation.st`, `PRG_02_Acquisition.st`, `FB_Translation.st`.
> 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T108.

---

## 1. Constat (vérifié code)

| Élément | État actuel |
|---|---|
| **Signal** `TremieFull_OR_GateRaised_DI` | **Déclaré** (`ST_HwMachine.st:15`) + **qualifié** (`PRG_02_Acquisition.st:160` `HwReal.Machine.TremieFull_OR_GateRaised_DI := ...`) + simulé `FALSE` (`FB_SimBench.st:342`) — mais **PAS consommé** (commentaire : « pas encore câblé électriquement, l'interdiction translation M3→Trémie est une tâche à part ») |
| Sens M3 | `Direction = +1` = **vers Trémie** (Fwd), `-1` = vers Maintenance (voir FB_Sim_Translation) |
| Arrêt Trémie | `M3_AtTremieStable` (`PRG_05:123`), cible `SelTarget=1` |

**Risque** : si la trémie est pleine (ou la grille levée), déverser/déplacer M3 vers la trémie peut
causer un débordement ou une collision → il faut **bloquer la marche avant vers Trémie**.

---

## 2. Interlock proposé

**Règle** : `TremieFull_OR_GateRaised_DI = TRUE` → **interdire la Translation M3 vers Trémie**
(Direction = +1 / Fwd), en gardant la sortie de Trémie autorisée (Direction = -1 / Rev, pour
dégager).

### Point d'injection (design, à confirmer)

Le blocage doit agir **en amont de la demande de mouvement**, dans `PRG_05_Translation.st` où
`M3_Direction_Active` est calculé (L156-176) et où `TranslationFinalInterlockRequest` est publié
(L364-372). Deux options :

| Option | Injection | Effet |
|---|---|---|
| **A (recommandé)** | Forcer `M3_Direction_Active` vers 0 quand `TremieFull_OR_GateRaised_DI` ET direction demandée = +1 (vers Trémie) | blocage directionnel « vers Trémie » seul, sortie libre |
| B | Ajouter un interlock dans la chaîne final (comme `HeightInterlockBlocking`) | blocage global M3 (plus large) |

> ⚠️ **Cohérence** : le blocage doit être **directionnel** (vers Trémie uniquement), pas un blocage
> total de M3 — pour pouvoir quitter la trémie si on y est déjà. Polarité positive (NC-100) :
> `TremieFull_OR_GateRaised_DI = TRUE` = bloqué vers Trémie.

### Propagation diagnostic
Exposer l'interlock dans la raquette `TranslationPontM3` (comme `HeightInterlockBlocking`,
`Idx308`) pour diagnostiquer le blocage — cohérent avec T129.

---

## 3. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Injection **A** (directionnel, recommandé) ou **B** (bloc complet M3) ? |
| 2 | Faut-il bloquer aussi le **cycle semi-auto** vers Trémie (le cycle utilise `SelTarget=1` → Trémie) ? |
| 3 | Le signal est-il câblé **électriquement** en réalité ? (commentaire ST_HwMachine : « pas encore câblé électriquement ») — validation terrain requise |
| 4 | Implémentation (code `PRG_05` + éventuel `ST_TranslationState`) → **validation humaine** |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T108 |
| Câblage | `CODE/M_MAIN/PRG_05_Translation.st` (PR_156-235, L364-372) · `PRG_02_Acquisition.st:160` |
| Signal | `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_HwMachine.st:15` |
| Simulation | `CODE/L_SIMULATION/FB_SimBench.st:342` (simulé FALSE) |
| Convention | `DOC/STDS/NAMING_CONVENTION.md` (polarité NC-100) |
