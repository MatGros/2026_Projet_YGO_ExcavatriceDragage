# 🔒 PREUVE T345 lot L1 — l'axe M3 possède son arrêt

> 🎫 Brief : `DOC/WFLOW/CONTRACTS/BRIEF_T345_L1_AXE_POSSEDE_SON_ARRET.md` (préambule `subagent_preamble.md` appliqué)
> 🧭 Plan parent : `DOC/WFLOW/CONTRACTS/PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` §3 (lot L1)
> 🏷️ Acteur : **DSH23** · 📅 2026-09-21 · 🔖 Ancre : HEAD `276fc11e` (les deux fichiers du lot étaient propres)
> 🚦 Statut : **IMPLÉMENTÉ, TESTÉ, NON COMMITÉ** — recette humaine (import CODESYS + essai machine) requise

---

## 1 · Le mécanisme du blocage, prouvé sur le code

Le plan fondait la correction sur `PRG_05_Translation.st:427` (`M3_PositionSensorTarget := FALSE`).
Vérification : cette ligne appartient à la branche `ELSE` du `CASE SelTarget`, c'est-à-dire au **jog manuel**
(`SelTarget = 0`). En `SEMI_AUTO`, `SelTarget` vaut **1** (AX14) ou **3** (AX2) :

| Fait | Preuve |
|---|---|
| Cible d'étape = `ReqTranslation.PositionTgt` | `FB_TranslationCmdArbitrationM3.st:65` — `SelTarget := ReqTranslation.PositionTgt;` |
| AX2 demande P1 (3) / AX14 demande Trémie (1) | `FB_CycleSemiAuto.st:967` et `:1465` |
| Donc la cible publiée est le **jeton**, pas la demande | `PRG_05_Translation.st:409-412` (branches 1 et 3 du `CASE`) |

Le défaut réel du chemin cycle est donc **la mémoire de sens du verrou d'arrivée** :

1. Le séquenceur retire sa demande dès le jeton d'arrivée : `FB_CycleSemiAuto.st:969-980` (AX2, `ReqStart := FALSE`)
   et `:1468-1470` (AX14).
2. Ce retrait remet à `FALSE` les deux locaux de sens : `FB_Translation.st:229-233`
   (`IF NOT (ReqTremie OR ReqMaintenance) THEN CommandedTremie := FALSE; CommandedMaintenance := FALSE;`).
3. Or l'armement du verrou n'arrive que **100 ms après** le jeton (`CaptorDebounce = T#100ms`,
   `ST_fbTranslation_Cfg.st:31` ; debounce `FB_Translation.st:175-176` ; armement `:179-183`), soit
   ~9 scans de 10 ms plus tard. À cet instant `CommandedTremie` et `CommandedMaintenance` sont **déjà à FALSE**.
4. Le verrou s'arme donc avec `ArrivalWasTremie = FALSE` **et** `ArrivalWasMaintenance = FALSE`, et la
   condition de relâchement `:202-204`
   (`ArrivalLock AND ((ReqTremie AND NOT ArrivalWasTremie) OR (ReqMaintenance AND NOT ArrivalWasMaintenance))`)
   devient satisfaite par une demande du **MÊME sens**.
5. La rampe est alors de nouveau autorisée (`:251`, terme `ArrivalLock` levé) : le chariot **repart**
   au-delà du point d'arrêt, `Translation_Busy` (`PRG_05:817`) repasse à `TRUE`, et
   `TranslationStopTimer` (`FB_CycleSemiAuto.st:361-365`, 500 ms **continus** de `At_Xxx AND NOT Busy`)
   **ne s'arme jamais** → blocage AX2/AX14 + dépassement, exactement le symptôme terrain.

Second défaut, chemin jog manuel : la perte de la demande effaçait la cible **au milieu du debounce**
(`PRG_05:426-428` avant correction), donc le verrou ne pouvait pas s'armer du tout.

## 2 · Ce que le lot change (diff réel)

| Fichier | Changement |
|---|---|
| `CODE/I_TRANSLATION/FB_Translation.st` | `LastMoveDirection : INT` — mémoire de sens du dernier mouvement commandé, mise à jour en tête de §4 (avant la lecture du front d'arrivée) et **jamais** remise à zéro par la perte de la demande ; le sens d'arrivée est qualifié sur cette mémoire quand `Commanded*` est déjà retombé. Nouveau `VAR_OUTPUT ArrivalStopConfirmed` = `ArrivalLock AND NOT Fault.Error AND (ABS(DriveActualFreqHz) <= 0.5) AND NOT BrakeReleaseRequest`, remis à `FALSE` dans la gate `NOT Enable` |
| `CODE/M_MAIN/PRG_05_Translation.st` | `M3_TargetCodeSel : INT` — mémoire de **code de cible** : le code n'est réécrit que tant qu'une demande est présente, la cible publiée étant le jeton du point mémorisé (elle retombe d'elle-même dès qu'un autre point est franchi). `M3_MaintN2` (origine `Auth.Mode`) — garde de mode posée aux **deux** points de consommation du bypass de fin de course (`instSafetyTranslationM3` et `instTranslationM3`) |

Invariants conservés (contrat `conservation.must_survive`) : relâchement par sens inverse uniquement,
armement par détection qualifiée + front de fin de course, verrous bistables de FdC libérés par le seul
sens inverse, coupure dure inchangée, restauration RETAIN des bypass non touchée.

## 3 · Preuves CI (rouge avant / vert après)

| Contrôle | Avant correctif | Après correctif |
|---|---|---|
| `run_tests.py --fb FB_Translation` | **39/41** — `TC-P11-036` : `RESTARTSEEN expected FALSE, got TRUE` (le chariot **repart** après le verrou) · `TC-P11-037` : `ARRIVALSTOPCONFIRMED expected TRUE, got FALSE` (verrou effacé par la re-demande du même sens) | **41/41 PASS** |
| `run_tests.py --fb PRG_05_Translation` | 4/4 (cas préexistants) | **6/6 PASS** (TC-P05-T345-01 mémoire de cible, TC-P05-T345-02 garde MAINT_N2 des deux voies de la cause 6) |
| `G519_check_t345_axis_owns_stop.py` | — | **PASS** + `--selftest` 7/7 mutations rejetées |
| `G200_check_linkage.py --report` | — | **PASS**, 138 OK / 0 KO, 2046 instances |
| `run_all_gates.py --palier C` | 4 échecs préexistants | **53/57**, **mêmes 4 échecs** (G300, G340, G430, G483) — `G430` compte identique avant/après : **136** |

Le rouge a été obtenu par **mutation contrôlée** (retour temporaire de la capture de sens à `Commanded*`),
puis correctif restauré et vérifié vert.

## 4 · Limites déclarées (aucune preuve surévaluée)

- **Le harnais M_MAIN est un STUB miroir** : `run_tests.py` compile `entry["sources"]` et n'utilise
  `source_prg` que pour le rapport (ligne 419), donc `PRG_05_Translation.st` **n'est pas exécuté** par la
  CI. Les deux cas M_MAIN prouvent les expressions miroir ; la preuve mécanique portant sur le **vrai**
  fichier est le garde-fou `G519`.
- **`ArrivalStopConfirmed` est vacuement vrai au banc** : `M3_ActualFrequencyHz = 0` en permanence, donc
  `ABS(fAct) <= 0.5` est toujours satisfait. Le critère se prouve **par injection d'entrée**
  (`DriveActualFreqHz := 5.0`, cas `TC-P11-039`) et devra être **confirmé sur trace terrain**.
- **Aucune preuve machine réelle** : le lot n'a pas été importé dans CODESYS ni essayé sur la machine.

## 5 · Alertes remontées à l'orchestrateur (non traitées ici)

| # | Fait vérifié | Conséquence |
|---|---|---|
| A1 | Le verrou `T331/DSH09` annoncé **actif** par le brief est **libéré** depuis `2026-09-21T05:14` (`TASK_LOCKS.json`, entrée `T331`) | Le blocage D5 de L2 est levé, mais **aucune extension de périmètre** n'a été décidée : L2 reste à ouvrir par un GO explicite |
| A2 | La collision annoncée `T361` sur `PRG_05_Translation.st` est **fausse** (aucune entrée `T361` dans `TASK_LOCKS.json`, statut ⬜, agent `—` ; périmètre réel = simulateur/estimateur) — mais `T361` **travaille sans verrou** (4 fichiers `CODE/` modifiés + `G518_check_m3_odometry_scale.py` déjà créé et câblé) | Le numéro `G518` était pris : le garde-fou de ce lot est **`G519`**. Un chantier actif sans verrou reste un risque de collision |
| A3 | `PRG_05:176-180` consomme encore `Bypass.LimitSwitch` / `Bypass.Global` **sans garde de mode** (blocage process Trémie), comme `:485`/`:601-602` (retour frein, contrôle contacteur) et les 10 bypass de la safety `:493-503` | La garde demandée par D1 a été posée **aux deux points cités par le plan Q4** ; les autres points restent ouverts et sont listés ici pour décision |
| A4 | Le `RETAIN` des bypass reste un piège : un boot **en MAINT_N2** restaure des bits actifs | Le boot en `MAINT_N2` reste la seule fenêtre où ces bypass agissent — tâche dédiée (hors lot) |
| A5 | `G340` signale **tous** les `BRIEF_*.md` du dépôt (« document sans titre H1 », format `=== PRÉAMBULE OBLIGATOIRE ===` imposé par le workflow) | Incompatibilité systémique format de brief / gate, à trancher au niveau outillage |
| A6 | Suppression de `TOOLS/AGENT_WORKFLOW/scripts/G499_check_t291b_top_authority.py` présente dans l'arbre de travail **avant** ce lot (renommage `G499` → `G505`, chantier T291-B) | Constatée, signalée, **non touchée** (aucune suppression n'est imputable à ce lot) |

## 6 · Prerequis d'ouverture de L2

1. Publier `ArrivalStopConfirmed` dans `ST_TranslationInterPrg` (`CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/`) —
   hors périmètre L1, et nécessaire pour que la porte de cycle puisse consommer le fait.
2. Câbler ce champ `PRG_05` → `PRG_03` → `FB_CycleSemiAuto.Translation_...` (entrée à déclarer).
3. Alors seulement : conserver demande + cible jusqu'à l'arrêt confirmé, avec le **timeout armé** (invariant I7).
