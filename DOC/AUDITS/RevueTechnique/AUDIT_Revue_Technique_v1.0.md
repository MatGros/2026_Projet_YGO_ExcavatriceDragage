# 🔍 AUDIT — Revue technique automatisme / sécurité / IHM

**Version** : v1.0 · **Date** : 2026-07-26 · **État du code** : `9228faf` + 24 fichiers non committés (commentaires uniquement)
**Nature** : revue **lecture seule**. Aucun fichier `CODE/` modifié dans le cadre de cet audit.

---

## 1. 🎯 Périmètre réellement couvert

**Lu intégralement** (ligne à ligne) :
`PRG_03_Safety` · `PRG_10_Outputs` · `PRG_00_Inputs` · `FB_Safety_Winch` (560 l.) ·
`FB_Safety_EmergencyManagementLogic` · `FB_Winch` · `FB_Brake` · `FB_Ramp` · `FB_CycleTime` ·
`GVL_PLC_Tests` · `GVL_Simulation` · extraits `PRG_09_Supervision`, `PRG_01_Diagnostics`

**Non lu** (⚠️ à ne pas considérer comme audité) :
`FB_Cycle` (469 l.) · `FB_Bucket` (468 l.) · `FB_SpeedStep` · `FB_WinchSync` · `FB_Modes` ·
chaîne codeurs (`FB_Encoder_*`) · `FB_Joystick` · `FB_Translation` / `FB_Safety_Translation` ·
`FB_Diag*` · structures IHM détaillées

👉 **Couverture ≈ 35 % du code, mais ~80 % du chemin critique sécurité.** Les conclusions
ci-dessous valent pour ce qui a été lu ; l'absence de constat sur un FB non lu ne vaut pas quitus.

---

## 2. 📊 Synthèse

| # | Gravité | Constat | Fichier |
|---|---|---|---|
| **C1** | 🔴 **Critique** | Polarité du contrôle de cohérence frein **inversée** — défaut dormant, se réveillera au câblage réel | `FB_Brake.st:97-101` |
| **C2** | 🟠 Majeur | `ForbidAscent` non initialisé dans le gate `Enable=FALSE` → sortie non déterministe | `FB_Safety_Winch.st:242-265` |
| **C3** | 🟠 Majeur | Le contrôleur de style produit **36 faux positifs** → il ne détecte plus rien de réel | `check_code_style.py:14` |
| **C4** | 🟡 Moyen | `DelayMotorDecel` / `TonDecel` = **code mort**, l'interface promet une tempo qui n'existe pas | `FB_Brake.st:27,73,85` |
| **C5** | 🟡 Moyen | Méca A : seuil vitesse sans filtrage ni temporisation → risque de `PowerCutOff` intempestif | `FB_Safety_Winch.st:381,393` |
| **C6** | 🔵 Mineur | `FB_CycleTime` : débordement de `TIME()` à 49,7 jours non géré | `FB_CycleTime.st:33` |
| **C7** | 🔵 Mineur | Commentaire du masque `SafeStop` incomplet (bits 14/15 absents) | `FB_Safety_Winch.st:522` |

---

## 3. 🔴 C1 — Polarité du contrôle de cohérence frein inversée

### Le constat

Trois déclarations du même signal se contredisent :

| Fichier | Déclaration | Sémantique |
|---|---|---|
| `PRG_00_Inputs.st:36` | `M1BrakeFeedback : BOOL; // Retour frein M1 (NC) : TRUE=frein serré repos` | **TRUE = serré** |
| `FB_Safety_Winch.st:147` | `BrakeFeedback : BOOL; // Retour frein CE treuil (TRUE = serré/collé)` | **TRUE = serré** |
| `FB_Brake.st:100-101` | `StuckClosed := (NOT BrakeCmd AND ContactorFeedback); // commandé collé mais retour "relâché"` | **TRUE = relâché** ❌ |

`FB_Brake` est le seul des trois à interpréter `TRUE = relâché`. Le signal traverse pourtant
`PRG_00_Inputs.M1BrakeFeedback` → `PRG_06_WinchControl` → `FB_Winch.BrakeFeedback` →
`FB_Brake.ContactorFeedback` (`FB_Winch.st:280`) **sans aucune inversion**.

### La conséquence, table de vérité (avec `TRUE = serré`, la convention majoritaire)

| Situation | `BrakeCmd` | `Feedback` | Test `BrakeCmd <> Feedback` | Verdict du code | Réalité |
|---|---|---|---|---|---|
| Frein relâché, normal | TRUE | FALSE | **différent → DÉFAUT** | 🔴 défaut | ✅ sain |
| Frein serré, normal | FALSE | TRUE | **différent → DÉFAUT** | 🔴 défaut | ✅ sain |
| Frein collé alors que relâche commandée | TRUE | TRUE | identique → OK | ✅ sain | 🔴 **défaut réel non vu** |
| Frein relâché alors que serrage commandé | FALSE | FALSE | identique → OK | ✅ sain | 🔴 **défaut réel non vu** |

**Le test est exactement inversé.** Avec la polarité documentée, la condition de défaut devrait
être `BrakeCmd = ContactorFeedback`, pas `<>`.

### Pourquoi personne ne l'a vu

`GVL_Simulation.SensorM1ContactorFeedbackIsReal := FALSE` par défaut → `BypassContactorCheck = TRUE`
est propagé jusqu'à `FB_Brake` (`FB_Winch.st:283`) → **tout le bloc de contrôle est court-circuité**
(`FB_Brake.st:98`). Le défaut est **dormant**.

### 💥 Ce qui se passera le jour du câblage réel

Dès que `SensorM1ContactorFeedbackIsReal := TRUE` :
1. `TonFeedback` expire au bout de `FeedbackTimeout` (1 s) — **en permanence**, à l'arrêt comme en mouvement
2. `ErrorId` bit0 → `Error := TRUE`
3. `FB_Brake.st:128` : `IF Error THEN BrakeCmd := FALSE` → **le frein se serre**
4. `FB_Winch.st:266` : `BrakeSafetyOk := NOT Brake.Error` → **coupure des relais de sens**

👉 **Treuil inutilisable, et serrage de frein sous couple** — exactement le mécanisme de
l'incident d'échauffement frein documenté en `v0.4.27`.

### ✅ Recommandation

**Avant** de passer un `Sensor*ContactorFeedbackIsReal` à `TRUE` :
1. **Mesurer physiquement** la polarité du retour frein au multimètre, frein serré puis relâché
2. Aligner les trois déclarations sur le résultat de la mesure
3. Corriger `FB_Brake.st:97` en conséquence (`<>` ou `=`) **et** les libellés `StuckClosed`/`StuckOpen`
4. Vérifier que `FB_Safety_Winch` Méca A/B/D reste cohérent : il arme sur
   `FwdRevSpeedFeedbackOff AND BrakeFeedback` — logique **uniquement** si `TRUE = serré`

⚠️ Ce point conditionne la mise en service. À traiter avant tout essai en charge.

---

## 4. 🟠 C2 — `ForbidAscent` non déterministe quand la sécurité est désactivée

`FB_Safety_Winch.st:242-265`, gate `IF NOT Enable` :

```
SafeStop      := TRUE;    ✅ forcé
ForbidDescent := TRUE;    ✅ forcé
PowerCutOff   := FALSE;   ✅ forcé
ForbidAscent  :  ← ABSENT ❌
```

`ForbidAscent` **conserve sa dernière valeur** pendant toute la désactivation (`InhibitM1`/`InhibitM2`
en `MAINT_N2`). Sortie non déterministe, dépendante de l'historique.

**Impact réel limité** : `SafeStop = TRUE` domine dans `FB_Winch.EffectiveSafeStop` (`FB_Winch.st:188`).
Mais l'asymétrie avec `ForbidDescent` — forcé, lui — indique un oubli, pas un choix. Une sortie de
bloc sécurité doit être déterministe dans **toutes** ses branches.

✅ **Recommandation** : ajouter `ForbidAscent := TRUE;` dans le gate, par symétrie et par principe
de sécurité positive.

---

## 5. 🟠 C3 — Le contrôleur de style est aveugle depuis la refonte IHM

`check_code_style.py:14` :
```python
VAR_OUTPUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(Ready|Busy|Done|Error|ErrorId|State|StateAtError)\s*:=")
```

Depuis la restructuration `Cmd`/`State`/`Cfg` de `GVL_IHM` (2026-07-22/24), les écritures miroir
légitimes ont pris la forme :
```
GVL_IHM.M1TreuilRetenue.State.Ready := PRG_06_WinchControl.instWinchM1.Ready;   (PRG_09:313)
GVL_IHM.M1TreuilRetenue.Safety.Error := PRG_03_Safety.instSafetyWinchM1.Error;  (PRG_09:357)
```

La regex capture `State` / `Safety` comme « nom d'instance ». Ces noms ne sont déclarés nulle part
dans le fichier → classés **cross-file illegal write**. Et la baseline
`KNOWN_VAR_OUTPUT_VIOLATIONS` liste encore les anciens chemins (`M1TreuilRetenue.Ready`,
`M2TreuilBucket.*`) qui n'existent plus.

**Résultat : 36 erreurs sur 36 sont des faux positifs.** Le contrôle ne peut plus détecter une
vraie écriture croisée — elle serait noyée dans le bruit. Un garde-fou qui crie tout le temps
n'est plus un garde-fou.

✅ **Recommandation** : exclure les chemins commençant par `GVL_IHM.` (miroirs de supervision,
Bridge Pattern assumé) et rafraîchir la baseline sur les noms actuels.

---

## 6. 🟡 C4 — `DelayMotorDecel` : paramètre fantôme

`FB_Brake` déclare `DelayMotorDecel : TIME := T#500ms` et la variable `TonDecel`. L'en-tête
annonce (l. 11-12) :

> ⏱️ Séquence arrêt : attend décélération/ouverture contacteur **AVANT** de coller
> (sinon usure/casse mécanique en plein mouvement).

**Or `TonDecel` est armé à `IN := FALSE` dans les deux branches** (l. 73 et l. 85). Il ne tourne
jamais. La branche `ELSE` fait `BrakeCmd := FALSE` immédiatement (l. 86, REX 2026-07-08
« fermeture immédiate », changement assumé).

Le paramètre est **propagé depuis `FB_Winch`** (`BrakeDelayMotorDecel := T#500ms`, l. 98 et 282) :
un technicien de mise en service peut le régler en croyant agir sur la mécanique. Il n'agit sur rien.

✅ **Recommandation** : soit supprimer `DelayMotorDecel` + `TonDecel` de l'interface, soit
réimplémenter la temporisation. Dans les deux cas, corriger l'en-tête qui décrit un comportement
que le code n'a plus. **Ne pas laisser un paramètre de sécurité sans effet.**

---

## 7. 🟡 C5 — Méca A : détection vitesse sans filtrage, escalade `PowerCutOff`

`FB_Safety_Winch.st:381` :
```
MeasuredSpeedSignedMps := (CablePosM - LastCablePosM) / CycleTimeCalc.CycleTimeS;
```
Dérivée brute, **sans filtre**, sur un cycle de 10 ms. Seuil Méca A : `0.02 m/s`
(`UncommandedSpeedThresholdMps`), soit **0,2 mm de variation en un cycle**.

`FB_Safety_Winch.st:393` : le dépassement déclenche le bit7 **immédiatement, sans temporisation**
→ `SafeStop` **et** `PowerCutOff` (masque `16#2F84`).

**Comparaison interne** : les contrôles voisins bits 14 et 15 (sens opposé, absence de mouvement)
utilisent tous deux une `TON` de confirmation (500 ms / 3 s). Méca A, dont l'escalade est
**plus sévère** (coupure de puissance), n'en a aucune.

**Risque** : un seul pas de quantification codeur, une glitch EtherCAT, un jitter de cycle
(`CycleTimeS` mesuré, pas constant) suffit à franchir le seuil un cycle → coupure de puissance
générale. La dérive position (`FB_DriftGuard`, 2,0 m) est robuste, mais elle est en **OU** avec
le check vitesse — le maillon faible impose son comportement.

✅ **Recommandation** : ajouter une `TON` de confirmation (100-200 ms) sur le terme vitesse, ou
filtrer `MeasuredSpeedMps` (PT1, le projet a déjà `FB_FilterPT1`). Les valeurs sont annotées
« théorique, à ajuster sur site » — **prévoir explicitement ce réglage au protocole de MES**.

---

## 8. 🔵 C6 / C7 — Points mineurs

**C6 — `FB_CycleTime.st:33`** : `TIME_TO_UDINT(TimeCurrent - TimeLast)` ne gère pas le bouclage de
`TIME()` (~49,7 jours). Au débordement, `CycleTimeS` prend une valeur aberrante pendant 1 cycle →
`StepX = Rate × CycleTimeS` fait sauter la rampe à sa cible. Borné par `LIMIT(±100)`, donc pas
dangereux, mais un à-coup possible sur une machine laissée en marche continue.
👉 Garde-fou simple : `IF DeltaTimeMs > 1000 THEN CycleTimeS := DefaultValueS;`

**C7 — `FB_Safety_Winch.st:522-524`** : le commentaire du masque `SafeStop` énumère les bits
0/1/2/3/4/7/8/9/10/11/12/13 mais le masque `16#FF9F` inclut **aussi les bits 14 et 15**
(cohérent avec l'en-tête l. 65-66). Documentation à compléter, code correct.

---

## 9. ✅ Points solides relevés

Il serait malhonnête de ne lister que des défauts. Ce qui est bien fait :

- **Sécurité positive** cohérente : frein à manque de courant, capteurs NC, `Enable=FALSE` →
  sorties coupées, `IF Error THEN` sorties forcées à l'état sûr en fin de bloc (`FB_Winch:356`,
  `FB_Brake:127`).
- **`BypassGlobal` ne masque jamais `EmergencyStopOk`** : `SafeStop` reste forcé à `TRUE` si le
  contacteur de puissance est ouvert (`FB_Safety_Winch:525`), quel que soit le bypass. Bien vu.
- **Défense en profondeur réelle** : Méca A→E ne sont pas décoratifs — chaque couche a une
  condition d'armement distincte et une escalade graduée (`SafeStop` d'abord, `PowerCutOff` seulement
  si l'arrêt n'est pas confirmé). Le choix de ne PAS mettre bit12 en `PowerCutOff`, mais bit13
  (son escalade), est juste.
- **Reset sur front avec cause disparue** : le motif `IF cause THEN set ELSIF ResetEdge.Q THEN clear`
  garantit structurellement qu'un acquittement ne peut pas effacer un défaut encore présent —
  la règle du projet est respectée partout où j'ai regardé.
- **`ForbidAscent` non acquittable tant que le capteur haut est physique** (`FB_Safety_Winch:540`) :
  l'alarme peut être acquittée pour permettre la descente, la protection physique reste. Subtil et juste.
- **Auto-test de redondance AU** (`FB_Safety_EmergencyManagementLogic`) : test séquentiel des deux
  canaux avant réarmement, avec verrouillage 5 s en cas d'échec. C'est du vrai 1oo2 testé.
- **Séparation `PRG_00` (entrées) / `PRG_10` (sorties)** avec `VAR_OUTPUT`/`VAR_INPUT` : le flux de
  données est traçable, pas de GVL fourre-tout.
- **`KoboldContactor_DQ` gardé par `EmergencyStopOk AND EmergencyChain`** (`PRG_10:122`) : coupure
  prioritaire câblée en dur dans la logique de sortie.

---

## 10. 📋 Plan d'action proposé

| Priorité | Action | Quand |
|---|---|---|
| 🔴 **1** | **C1** — mesurer la polarité réelle du retour frein, aligner les 3 déclarations, corriger `FB_Brake` | **Avant tout essai en charge** |
| 🟠 2 | **C2** — forcer `ForbidAscent := TRUE` dans le gate | Prochain lot code |
| 🟠 3 | **C3** — réparer le contrôleur de style (sinon il ne sert plus à rien) | Prochain lot outillage |
| 🟡 4 | **C4** — trancher sur `DelayMotorDecel` : supprimer ou implémenter | Prochain lot code |
| 🟡 5 | **C5** — temporiser/filtrer le terme vitesse Méca A + inscrire le réglage au protocole MES | Avant essais dynamiques |
| 🔵 6 | **C6/C7** — garde-fou `FB_CycleTime`, commentaire masque | Opportuniste |

---

## 11. ⚠️ Réserves

- Audit **statique** : aucune exécution, aucun essai. Les conclusions sur les temporisations et les
  seuils demandent une validation sur machine.
- **65 % du code non lu** (§1). Notamment `FB_Cycle`, `FB_Bucket` et toute la chaîne codeur —
  dont dépendent pourtant `CablePosM` et donc Méca A/C/E.
- La polarité physique réelle des retours (frein, contacteurs, thermiques) **n'est pas vérifiable
  depuis le code**. C1 démontre une **incohérence interne** ; c'est la mesure terrain qui dira
  quel côté corriger.
- Depuis le retrait du framework de tests in-PLC (`v0.5.1`), aucun rejeu automatique ne couvre ces
  points : leur vérification repose entièrement sur la simulation manuelle et les essais FAT/SAT.
