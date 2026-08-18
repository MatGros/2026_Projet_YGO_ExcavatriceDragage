# 🔬 Préétude d'impact — `FB_IntentionDecoder` (v0.1)

> 🎯 **Objet** : mesurer l'impact d'appliquer un décodage d'intention joystick **standardisé et
> en amont** (`FB_IntentionDecoder`) à tout le programme, avant tout code.
> 📅 Session 2026-08-19 · 🔍 Phase étude/planification — **zéro code**.
> 📄 Références : `AF_Partie-08` (joystick), `AF_Partie-10` (winch/paliers), `AF_Partie-11` (translation),
> `AF_Partie-04` (cycle), `PLAN_TASK.md` T130/T131/T135.

---

## 1. Problème constaté

Le joystick produit déjà une intention normalisée (`AxisCmdX/Y` : Direction + SpeedRef %), mais
**chaque consommateur la re-décode en interne**, avec des « bidouilles » pour retrouver le sens :

| Consommateur | Décodage actuel | Problème |
|---|---|---|
| `FB_Cycle` | `CycleMotionPermit` (BOOL « défléchi ») + `Direction := 1` / `SpeedPct := 10` forcés | Le cycle **réinvente** le sens/la vitesse, ignore le geste réel |
| `PRG_04` §1 | `CoupledUserRequestDirection := AxisCmdY.Direction` | Dupliqué, inline |
| `PRG_04` §3 | `M1LogicRequestDirection/SpeedRef_Pct` (SEMI_AUTO / boutons / joystick) | 3 branches, % hardcodés (100/15) |
| `PRG_05` §1 | `M3_Direction_Active` / `M3_SpeedRef_Active` | Re-décode `JoystickDirectionX` |
| `FB_Winch` | `SpeedRefPct` (REAL %) → `FB_SpeedStep` → palier | Décodage palier **en aval**, pas en amont |

**Principe cible** : l'intention `{Direction, Palier}` est générée **une fois, en amont**
(`FB_IntentionDecoder`), puis **réutilisée** par le cycle et les FB mouvement. Relâchement =
arrêt instantané, structurel.

---

## 2. Cartographie des fichiers impactés

### 2.1 Nouveaux fichiers
| Fichier | Rôle |
|---|---|
| `FB_IntentionDecoder.st` | Décodage intention joystick → `{Direction, Palier}` (winch) + `{Direction, SpeedRef%}` (translation) |
| `ST_Intention.st` | DUT intention (Direction, Palier, Active) |
| `E_ActiveAxis.st` | Enum axe actif (NONE / WINCH / TRANSLATION) |

### 2.2 Fichiers modifiés (blast radius)

| Fichier | Changement | Criticité |
|---|---|---|
| `ST_WinchCmdDemand.st` | `SpeedPct` → `Palier : INT` (Option B) | 🔴 Interface |
| `PRG_02_Acquisition.st` | Instancier `FB_IntentionDecoder`, exposer `WinchIntention`/`TranslationIntention` | 🟠 |
| `PRG_03_Modes_Cycle.st` | `CycleMotionPermit` → transmettre l'intention au cycle | 🟠 |
| `FB_Cycle.st` | Remplacer `Direction := 1`/`SpeedPct := 10` par `WinchIntention` | 🔴 Sécurité |
| `PRG_04_Treuils_Benne.st` | §1/§3 : consommer `WinchIntention` au lieu de re-décoder | 🔴 Sécurité |
| `FB_Winch.st` | `SpeedRefPct` → `RequestedStep` (palier) | 🔴 Interface |
| `PRG_05_Translation.st` | §1 : consommer `TranslationIntention` | 🟠 |
| `PRG_07_Supervision.st` | `CycleM1SpeedRef_Pct` → `...Palier` | 🟢 |
| `FB_TroubleshootingView.st` | `M1LogicRequestSpeedRef_Pct` → palier | 🟢 |
| `FB_Sim_Joystick.st` / `FB_Sim_Translation.st` | Aligner sur la nouvelle intention | 🟢 |

---

## 3. Impact détaillé par zone

### 3.1 Chaîne treuil (M1/M2) — le cœur
```
FB_Joystick ─► AxisCmdY ─► FB_IntentionDecoder ─► WinchIntention {Direction, Palier}
                                                        │
                        ┌───────────────────────────────┤
                        ▼                               ▼
              FB_Cycle (test)                    PRG_04 §3
              (consomme l'intention)              (M1/M2LogicRequest)
                                                        │
                                                        ▼
                                                   FB_Winch
                                                   (RequestedStep = palier)
```

**Points sensibles** :
- `FB_Winch` passe de `SpeedRefPct` (REAL %) à `RequestedStep` (palier). **Mais** en mode manuel,
  le joystick fournit un % continu → le décodage palier doit aussi passer par
  `FB_IntentionDecoder`. → **Tous les modes passent par le décodeur** (pas seulement SEMI_AUTO).
- `M1LogicRequestSpeedRef_Pct` est publié à l'IHM (`WinchM1State.SpeedRef_Pct`) et lu par
  `FB_TroubleshootingView` → devient `StepNumber`/palier.
- `PRG_04` §3 a 3 branches (SEMI_AUTO / boutons / joystick). Le décodeur unifie le joystick ;
  les boutons IHM restent une source distincte (100% → palier max).

### 3.2 Chaîne translation (M3) — variateur, vitesse en Hz (hors décodeur)
```
FB_Joystick ─► AxisCmdX ─► FB_IntentionDecoder ─► TranslationIntention {Direction} (vitesse en Hz gérée par PRG_05)
                                                        │
                                                        ▼
                                              PRG_05 §1 (M3_Direction_Active / M3_SpeedRef_Active en Hz)
```
- M3 est un **variateur AC600** (fréquence continue), **pas** des paliers contacteurs.
- ✅ **Décision (c)** : la translation garde sa propre gestion de vitesse en **Hz**, hors `ST_Intention`.
- Le décodeur ne sort que `Direction` pour M3 ; `ST_Intention` reste **spécifique treuil** `{Direction, Palier}`.

### 3.3 Arbitrage « un seul axe actif »
- Le décodeur arbitre entre X (translation) et Y (treuil) : **un seul actif à la fois**.
- ⚠️ **Changement de comportement** : aujourd'hui, treuil et translation peuvent être commandés
  indépendamment (2 axes). Le décodeur impose la priorité. **À valider** (impact sur le pilotage manuel).

### 3.4 Relâchement = arrêt instantané
- Le décodeur sort `Direction=0`/`Palier=0` dès que l'axe est au neutre → coupure immédiate.
- Déjà partiellement géré par `PRG_04` §4 (repli homme-mort) et `FB_Winch` (coupure instantanée
  sur `Direction=0`). Le décodeur **centralise** cette garantie.

---

## 4. Risques

| # | Risque | Gravité | Mitigation |
|---|---|---|---|
| 1 | **Changement d'interface `FB_Winch`** (SpeedRefPct → RequestedStep) | 🔴 | Faire en T135 (séparé), tester en cycle d'abord |
| 2 | **Régression mode manuel** (joystick/boutons) | 🔴 | Tous les modes passent par le décodeur ; tests manuels |
| 3 | **Arbitrage « un seul axe »** change le pilotage manuel | 🟠 | Valider la priorité avec l'utilisateur |
| 4 | **`ST_Intention`** spécifique treuil `{Direction, Palier}` | 🟢 | Translation gère sa vitesse en Hz (décision c) |
| 5 | **IHM/Troubleshooting** lisent `SpeedRef_Pct` | 🟢 | Migrer vers palier/step |
| 6 | **Simulation** (`FB_Sim_*`) | 🟢 | Aligner sur la nouvelle intention |

---

## 5. Plan de migration (phases)

| Phase | Contenu | Risque |
|---|---|---|
| **P1** | `FB_IntentionDecoder` + `ST_Intention` + câblage dans `PRG_02_Acquisition` | Faible (nouveau FB, non branché) |
| **P2** | **Test cycle** : `FB_Cycle` consomme `WinchIntention` (remplace `Direction := 1`/`SpeedPct`) | 🔴 Sécurité — test en simu |
| **P3** | `ST_WinchCmdDemand` : `SpeedPct` → `Palier` (Option B) | 🔴 Interface |
| **P4** | `PRG_04` §1/§3 : consommer `WinchIntention` | 🔴 Sécurité |
| **P5** | `FB_Winch` : `SpeedRefPct` → `RequestedStep` | 🔴 Interface |
| **P6** | `PRG_05` : consommer `TranslationIntention` | 🟠 |
| **P7** | IHM/Troubleshooting/Simulation : aligner | 🟢 |

> ⚠️ **P2 (test cycle) est isolé** : on peut tester le décodeur dans le cycle **sans** toucher
> PRG_04/FB_Winch (T135). C'est la stratégie demandée : tester en cycle, refactor en parallèle.

---

## 6. Décisions actées (2026-08-19)

| # | Décision | Détail |
|---|---|---|
| **D1** | **Jamais de `SpeedRefPct`, pas de %** | `ST_Intention` = `{Direction, Palier}` uniquement. Le % est banni de l'intention. |
| **D2** | **Axe par axe (simple)** | Pas de contrainte client pour l'instant → décodage axe par axe. **Mais** le FB prévoit un **paramètre** (entrée, défaut 0) pour la commande **bi-axe** future : quand =1, on commande les 2 axes (translation + treuils). Même dans ce cas, si un axe passe par 0 (centre joystick), le mouvement de **cet axe** est coupé. |
| **D3** | **`FB_Winch` : `RequestedStep` seul** | Remplacer `SpeedRefPct` par `RequestedStep` (palier). Interface non-cassante abandonnée → refactor direct. |
| **D4** | **Boutons IHM passent par le décodeur** | Le décodeur est le **point d'entrée unique** de toute intention (joystick + boutons IHM). Standardise l'armement/homing des boutons. On entre dans le bloc, on ressort l'intention. |

### ✅ Décision — représentation vitesse translation (M3)

M3 est un **variateur AC600** (fréquence continue, pas de contacteurs de palier). D1 bannit le %.
**Comment exprime-t-on la vitesse translation ?**
- (a) **Palier 1-5** aussi (mappé → fréquence via config) — standardise tout sur paliers
- (b) Autre unité normalisée (ex. 0..1) sans le nom `SpeedRefPct`
- (c) La translation garde sa propre gestion de vitesse (hors `ST_Intention`)

> ✅ **DÉCIDÉ (2026-08-19) : (c)** — la translation garde sa propre gestion de vitesse en **Hz**,
> hors `ST_Intention`. Le `{Direction, Palier}` est **spécifique treuil**. Le décodeur ne sort que
> `Direction` pour M3.

---

## 7. Conclusion

L'impact est **réel mais maîtrisable** : ~10 fichiers, dont 2 interfaces critiques
(`ST_WinchCmdDemand`, `FB_Winch`). La stratégie **P2 isolé (test cycle)** permet de valider le
décodeur sans casser le reste. Le refactor complet (T135) est un chantier séparé, à faire après
validation du décodeur en cycle.

**Prochaine étape** : trancher D1-D4, puis rédiger le contrat de tâche T130.
