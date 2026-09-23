# 🕵️ Session de Troubleshooting — Temporisation 800 ms / inversion treuils (AX10 → AX10b → AX11)

> 📌 **Emplacement** : DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_Temporisation800ms_InversionTreuils_20260923.md
> 📅 Date : 2026-09-23 (maj) · 🧊 Situation : [SITE] + comparatif [SIMU] · 📄 Statut : [EN COURS]
> 🔗 Fiches liées : `NOTE_TECHNIQUE_AX11_D18_RETOURS_CONTACTEURS_20260923.md`,
> `TROUBLESHOOTING_TrouAX10_AX11_SiteVsBureau_20260922.md`,
> contrat `TASK_CONTRACT_DIAG_AX11_PAUSE_800MS_20260922.yaml` (COMPLETED, validation PENDING)
>
> ⚠️ **DOUBLON CONSTATÉ (à trier par l'humain, aucun fichier déplacé ni supprimé par l'agent)** :
> la fiche `TROUBLESHOOTING_InversionTreuilM1M2_TempsMort_20260923.md` (autre session DSH du
> 2026-09-23) traite **le même mécanisme D18** observé à une **autre transition** (AX8→AX9 au lieu
> d'AX10→AX11). Les deux fiches ne se contredisent pas — elles doivent être **fusionnées** : celle-ci
> apporte la localisation exacte du 800 ms, l'arbre de coupure, les traces importables et la matrice
> de bypass ; l'autre apporte le budget nominal (H7) et la matrice d'essai E1. Le protocole de trace
> du §4 couvre les deux transitions (l'étape est tracée).

---

## 1. 🧊 Contexte figé

Demande : « pas de coupure entre les étapes X10/X10 (AX10 → AX11) ; il y a une temporisation de
800 ms sur M1 au moment de démarrer parce qu'il y a inversion de sens (plongée → extraction),
sauf qu'il est arrêté depuis plus de 800 ms — ce n'est pas normal. Où est cette temporisation ?
Que peut-on by-passer ? Et faisons une trace pour arrêter de chercher à l'aveugle. »

Machine : excavatrice de dragage, treuils M1 (retenue) / M2 (benne). Cycle SEMI_AUTO.

---

## 2. 🎯 Réponse directe — OÙ est la temporisation d'inversion (chaîne fichier:ligne)

| # | Maillon | Fichier:ligne | Rôle |
|---|---|---|---|
| 1 | **Valeur** `T#800ms` | `CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinch_Cfg.st:19` (`DirectionInterlockDelayAscent`) | défaut de type |
| 2 | **Assignation runtime M1** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1452` | ← **la valeur réellement appliquée** |
| 3 | **Assignation runtime M2** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1518` | idem M2 |
| 4 | **Appel de D18** | `CODE/H_TREUILS_BENNE/FB_Winch.st:197-205` | `Enable := (StepNumber = 0) AND Sensors.ContactorsAllOff` |
| 5 | **Logique du crédit d'arrêt** | `CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st:76-79` (capture), `:93-97` (reliquat), `:114-121` (TON) | `RemainingDelay = 800 ms − CapturedStoppedTime` |
| 6 | **Source du crédit (le point dur)** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1424` → `HwIn.Winch.M1_ContactorsReleased_DI` | si ce DI n'est pas TRUE, **aucun crédit** → 800 ms pleines |
| 7 | **Garde d'atomicité couplée** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1405-1409` (M1) et `:1499-1501` (M2) | M2 est **aussi** figé tant que M1 est en `DirectionChangePending` |
| 8 | **Barrière finale** | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:351-430` | coupe `AuthorizedStep` (défaut, `RestartInhibit`, `SafeStop/Permit`, `RestartRequired/DeadTime`) |

**Cause du « plus de 800 ms »** : les 800 ms ne sont pas « trop longues » en soi — elles sont
appliquées **en entier** parce que le crédit d'arrêt physique est nul (`CapturedStoppedTime = 0`).
Ce crédit est nul parce que `Enable` exige `(StepNumber = 0) AND M1_ContactorsReleased_DI`, et ce
DI est FALSE alors que M2 travaille seul (§3, hypothèse 1 — **déjà confirmée par trace** dans la
note D18 : « le DI M1 empêche le crédit d'arrêt »). S'y ajoute le maillon 7 qui **coupe M1 ET M2
ensemble**, d'où la perception d'un trou global supérieur à 800 ms.

---

## 3. 🌳 Arbre « QU'EST-CE QUI PEUT COUPER ? » — 6 catégories, statut bypass

| # | Catégorie | Variable / point de coupure | Fichier:ligne | Bypassable ? |
|---|---|---|---|---|
| C1 | **Séquence** | `AX10B` neutralise M1 explicitement (`WinchM1Cmd.RunRequest := FALSE`) | `FB_CycleSemiAuto.st:1342` | ✖ (séquence) |
| C1b | **Repli AX10b** | `Ax10bFallbackStopActive` + `Ax10bHandoffWaitTimer` (2 s max) relâche le maintien M2 P1 | `FB_CycleSemiAuto.st:256-258, 1347-1351` | ✖ (`[LOC]`) |
| C2 | **D18 inversion** | `DirectionChangePending` → 800 ms si crédit nul | `FB_WinchDirectionInterlock.st` | 🚫 **aucun bypass n'existe** |
| C3 | **Garde couplée** | `WinchBothMotionReady` gèle la commande des DEUX axes | `PRG_04:1405-1409, 1499-1501, 1541` | 🚫 **aucun bypass n'existe** |
| C4 | **Permis / safety** | `SafeStopM1/M2_Active`, `EffectivePermitM1_Ascent` | `FB_Safety_Winch.st:66-81` + `PRG_04:972-991` | ✅ `Bypass.Safety` / `.Process` |
| C5 | **Barrière finale** | `Error`, `RestartInhibit`, `ContactorStuckLatched`, `SafeStop OR PermitFinalBlocked`, `RestartRequired OR DeadTimePending` | `FB_WinchOutputInterlock.st:351-430` | 🚫 partiel seulement (via C4) |
| C6 | **Position / limites** | butée haute, limite légale, câble, mou de câble | `PRG_04:866-875` | ✅ `Commun.Bypass.*` |
| C7 | **Réseau / E-S** | 5 modules E-S, CAN, EtherCAT | `PRG_02:203-216` | ✅ `Network.Bypass.Global` |

> ⚠️ **Le trou qui nous occupe est en C2 + C3 : aucune variable de bypass n'existe pour ces deux
> maillons.** C'est la réponse honnête à « peut-on by-passer ? » : on peut shunter la sécurité et
> les limites de position, **pas le délai d'inversion ni la garde d'atomicité**.

---

## 4. 🧪 Protocole de trace (outil existant, prêt à importer)

**Outil** : `TOOLS/PLC_CSV_SNAPSHOT/scripts/generate_trace_template.py` (T372 — transformateur de
`.trace` réel, import CODESYS déjà prouvé). Règles de traçabilité : `docs/TRACE_FORMAT_T372.md §4`.

| Feuille | Fichier `.trace` généré | Liste source | Var. |
|---|---|---|---|
| **A — « QUI COUPE ? »** | `TOOLS/PLC_CSV_SNAPSHOT/scripts/examples/Example_AX10_AX11_Cause.trace` | `variable_lists/trace_ax10_ax11_cause_v1.txt` | **30** |
| **B — « COMMENT ÇA BOUGE ? »** | `TOOLS/PLC_CSV_SNAPSHOT/scripts/examples/Example_AX10_AX11_Physique.trace` | `variable_lists/trace_ax10_ax11_physique_v1.txt` | **16** |

- Modèle utilisé : `RESULTS/trace/Suivi_84_AX10_11_ARRET_20260922.trace` (trace **réelle** du même
  runtime) · `RecordName` : `AX10_AX11_Cause` / `AX10_AX11_Physique` · `TraceData` vide.
- **Réglage** : tâche `MainTask`, `EveryNCycles` = **2 (≈20 ms)** — 10 ms si le buffer le permet ;
  durée ≥ 60 s (couvre un cycle complet). ⚠️ Une trace à 100 ms ne suffit pas à qualifier un
  enchaînement relais/DI de quelques dizaines de ms.
- **Scénario** : 3 cycles complets identiques, SEMI_AUTO, une trame par cycle, sans rien forcer.
- **Post-traitement** : `python TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py <fichier>`.

### 4.1 Matrice de décision (lecture des 2 feuilles)

| Signature lue | Verdict |
|---|---|
| `DirectionChangePending M1` ≈ 800 ms **et** `Id103_ContactorsReleased_DI` M1 = 0 pendant l'arrêt | ✅ **C2 prouvé** : crédit d'arrêt nul (cause = DI/retour contacteurs M1) |
| `DirectionChangePending M1` < 800 ms **et** DI M1 = 1 | ✅ C2 crédité correctement → chercher ailleurs (C1b repli AX10b) |
| `RelayAscent_RQ M2` = 0 **pendant** que `DirectionChangePending M1` = 1, sans `FinalInterlockReason` M2 | ✅ **C3 prouvé** : garde d'atomicité couplée (coupure des 2 axes) |
| `Id406_FinalInterlockReason` M1/M2 ≠ NONE, ou `Id416_RestartRequired` = 1 | ✅ **C5** : barrière finale (verrou anti-redémarrage / dead-time) |
| `Id306_AscentPermitEffective` = 0 ou `Idx302_SafeStopActive` = 1 | ✅ **C4** : permis / safety |
| Étape bloquée en `AX10b` > 2 s sans `M1AscentStartReady` | ✅ **C1b** : repli AX10b (M2 relâché, trou long) |
| `T_Permits.BothBlocked` = 1 / `BothBlockReason` ≠ NONE | 🧩 cause nommée par le code lui-même |

> 🧭 **Hypothèse concurrente à trancher en même temps (budget nominal)** : l'arrêt peut aussi être la
> **somme DESIGN** — relâchement direction 50 ms (`FB_WinchOutputInterlock.st:46`) + retombée/frein
> + stabilisation 500 ms (`FB_CycleSemiAuto.st:264`) + résidu directionnel + 1ᵉʳ cran 400 ms
> (`FB_WinchOutputInterlock.st:136`) ≈ 0,8–1,2 s — **sans aucun défaut**. La feuille B tranche : si
> `DirectionChangeDelayElapsed` ne monte que de < 300 ms après le front de demande, c'est le budget
> nominal ; s'il monte jusqu'à ≈ 800 ms, c'est le crédit cassé (C2).

### 4.2 ⛔ Ce qui N'EST PAS traçable (et pourquoi le protocole est conçu ainsi)

Prouvé par **test d'import réel** : un seul symbole non traçable fait échouer **toute** la trace
(`Parameter 0x2`). Sont non traçables (VAR interne `[LOC]`, non publiée) :

`instWinchM1.DirectionInterlock.StoppedTimer.ET`, `.CapturedStoppedTime`, `.RemainingDelay`,
`.DeadTimeArmed`, `PRG_04.WinchBothMotionReady` (`PRG_04:82`), `FB_CycleSemiAuto.Ax10bFallbackStopActive`,
`.Ax10bHandoffWaitTimer.ET`.

➡️ **Correctif de méthode (challenge du §8.3 de la note D18)** : sa recommandation « reprendre la
trace de `StoppedTimer.ET`, `CapturedStoppedTime` et `RemainingDelay` » **n'est pas exécutable en
l'état** — ces 3 symboles sont des `VAR` internes. Les 3 faits sont **déduits** par les feuilles A/B
(crédit = f(DI) · garde = f(Pending M1 ET M2) · repli = f(durée AX10b sans Ready)).

---

## 5. 🎚️ Matrice de bypass — ce qui est possible aujourd'hui, et à quel prix

| Besoin | Levier existant | Effet | Risque |
|---|---|---|---|
| Travailler sans coupure de **sécurité/process** | `GVL_IHM.M1TreuilRetenue.Bypass.Safety` + `.Process` (idem M2) | inhibe Meca A-E, NoMovement, OppositeDir | 🔴 lève des surveillances machine réelles |
| Travailler sans **retours contacteurs** | `…Bypass.ContactorFeedback` | lève le contrôle de cohérence contacteurs | 🟡 **ne change PAS `ContactorsAllOff`** → **ne lève PAS D18** (important) |
| Travailler sans **limites de position** | `GVL_IHM.Commun.Bypass.TopLimitSoftware` / `.TopLimitSwitch` / `.LimitLegal` / `.CableLimitSwitch` / `.SlackCable` | lève butées logicielle, capteur, légale, câble | 🔴 plus aucune butée haute |
| Travailler sans **surveillance d'écart M1/M2** | `GVL_IHM.M1M2Sync.Bypass.Global` | neutralise `FB_SyncDeviation` / `FB_SyncContactor` | 🟠 risque de télescopage |
| Travailler sans **défauts de treuil** | `GVL_IHM.M1TreuilRetenue.Bypass.Global` (idem M2) | force `ErrorId = 0`, ignore erreurs | 🔴 masque tout défaut |
| Travailler sans **diagnostic réseau** | `GVL_IHM.Network.Bypass.Global` | neutralise bus + 5 modules E-S | 🔴 la machine tourne « aveugle » |
| **Lever D18 (800 ms)** | ❌ **n'existe pas** | — | il faudrait un patch (voir §6) |
| **Lever la garde d'atomicité M1/M2** | ❌ **n'existe pas** | — | il faudrait un patch (voir §6) |

> ⚠️ **Deux pièges à connaître avant de toucher aux bypass**
> 1. Les bypass IHM sont **miroités en RETAIN** (`GVL_BypassRetain.st` + `PRG_07:342-355`) : un
>    bypass activé aujourd'hui **revient au prochain démarrage**. À remettre à zéro *et* à vérifier
>    dans `GVL_BypassRetain`.
> 2. En simulation, `PRG_07:369-381` **arme automatiquement** `Bypass.Safety/Process` +
>    `Commun.Bypass.TopLimit*` (front `SimulationBypassEffective`). Vérifier
>    `GVL_Troubleshooting.A_ContexteMachineGlobal.Idx102_SimulationEnabled` avant de conclure quoi
>    que ce soit d'un essai.
> ❌ **À ne pas toucher** : `GVL_BypassRetain.BypassAu*` (chaîne d'arrêt d'urgence physique).
> 🚫 **Ne PAS forcer `M1_ContactorsReleased_DI`** : c'est une entrée, elle est réécrite à chaque
> scan — et la neutraliser supprimerait justement la preuve cherchée.

---

## 6. 🛠️ Propositions de correction (⚠️ validation humaine obligatoire — aucun CODE/ écrit)

**Option 1 — immédiat, sans code (recommandée pour la journée de débug)**
1. Lancer les **2 traces** du §4 sur 3 cycles (machine sécurisée) → la matrice §4.1 nomme la cause.
2. En parallèle, appliquer la **matrice d'essai D18** (`NOTE_TECHNIQUE_AX11_D18… §8.2`) : relevé
   mécanique + LED canal + variable brute + `HwReal` + `HwIn` du retour contacteurs M1 **et** M2,
   pour chaque état (M1 seul / M2 seul / les deux). C'est le seul moyen de prouver le
   croisement/permutation des retours M1/M2.
3. Aucune variable forcée, aucun bypass armé à ce stade.

**Option 2 — patch de DIAGNOSTIC pur (si la trace ne suffit pas à trancher)**
> Publier en `VAR_OUTPUT` les 4 internes de D18 (`StoppedTimer.ET`, `CapturedStoppedTime`,
> `RemainingDelay`, `DeadTimeArmed`) → miroir `ST_WinchState` → `PRG_04.Data.WinchM1State.*`.
> ≈ 6 lignes dans `FB_WinchDirectionInterlock.st` + 4 dans `FB_Winch.st` + 4 dans `ST_WinchState.st`,
> **lecture seule, aucun impact conduite**. Rend le §8.3 de la note D18 réellement exécutable.
> Coût : recompilation + download. **À cadrer (C2) et valider avant écriture.**

**Option 3 — bypass de diagnostic « tout by-passer pour voir » (à cadrer, C3/C4)**
> Ajouter un bypass explicite de la garde d'atomicité et/ou du délai d'inversion.
> ⚠️ **Touche la conduite et la protection anti-inversion** — jamais en production, jamais sans
> arbitrage humain, et seulement *après* la trace (sinon on détruit la preuve).
> **Recommandation de l'agent : différer cette option.** Elle ne doit venir qu'après C1/C2 prouvés.

**Option 4 — correction définitive (ordre conservé de la note D18)**
1. Corriger le **DI / son mapping** (chaque retour = son axe).
2. **Conserver D18** : avec un retour correct, les 800 ms sont créditées pendant l'arrêt → pas de
   pause ajoutée à AX11.
3. Renforcer ensuite **AX10b** : vérifier explicitement la disponibilité de l'interlock amont avant
   de publier le transfert P1/P1 (changement de sécurité → à cadrer).

---

## 7. 🏁 Conclusion

À ce stade : **cause directe confirmée** (D18 M1 à 800 ms pleines + garde couplée = disparition
simultanée des commandes M1/M2 à AX11), **cause racine probable** (retour `M1_ContactorsReleased_DI`
ne correspond pas à l'axe → crédit d'arrêt nul). Ce qui manque n'est plus une hypothèse mais **une
mesure sur machine réelle avec les bonnes variables** : c'est l'objet du §4.

---

## 8. 📝 Journal

- 2026-09-23 : analyse statique de la chaîne D18 + garde couplée + barrière finale ; identification
  exacte de la temporisation 800 ms (§2) ; constat que **C2/C3 ne sont pas bypassables** (§5).
- 2026-09-23 : **garde-fou de traçabilité** — vérification par test d'import réel que les internes de
  D18 sont `[LOC]` non traçables ; le §8.3 de la note D18 est corrigé en conséquence (§4.2).
- 2026-09-23 : génération de **2 traces importables** (30 + 16 variables) via
  `generate_trace_template.py`, listes sources versionnées, matrice de décision §4.1.
  **Aucun fichier `CODE/` modifié, aucune variable forcée.**
- ⬜ À faire (humain, CODESYS) : lancer les 2 traces sur 3 cycles, renvoyer les `.trace`/CSV.
- ⬜ À faire : matrice d'essai terrain des retours contacteurs (`NOTE_TECHNIQUE_AX11_D18 §8.2`).

## 9. ❓ Questions ouvertes / validation requise

1. **GO** pour le patch *diagnostic* §6-Option 2 si les traces ne tranchent pas ? (recompilation + download)
2. Le retour `M1_ContactorsReleased_DI` a-t-il déjà été contrôlé au bornier (matrice §8.2) ?
3. Confirmer qu'aucun bypass n'est armé **avant** la campagne de trace (sinon la preuve est perdue).
